//
//  ContentView.swift
//  SnapSnap
//
//  Created by Kuangming Qin on 8/8/25.
//

import SwiftUI
import AVFoundation
import Vision
import CoreML
import Combine
import ApplicationServices

// MARK: - Legacy Configuration (to be removed gradually)
// This will be replaced by ConfigurationService
struct SnapDetectionConfig {
    // Keep for backward compatibility during transition
    static var processingFPS = 15
    static var middleFingerHoldDuration: TimeInterval = 1.0
    
    // Static getters that delegate to service
    static var frameProcessInterval: TimeInterval {
        return 1.0 / Double(processingFPS)
    }
}

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var isSnapDetected = false
    
    private let settingsService: SettingsService
    private let configService: any ConfigurationService
    
    init(cameraManager: CameraManager? = nil, settingsService: SettingsService = .shared, configService: (any ConfigurationService)? = nil) {
        self.settingsService = settingsService
        self.configService = configService ?? DefaultConfigurationService(settingsService: settingsService)
        
        // Use provided camera manager or create new one with services
        if let manager = cameraManager {
            self.cameraManager = manager
        } else {
            self.cameraManager = CameraManager(settingsService: settingsService, configService: self.configService)
        }
    }
    
    var body: some View {
        ZStack {
            CameraView(cameraManager: cameraManager)
            
            // Finger position overlay
            if cameraManager.showFingerPoints {
                FingerVisualizationView(
                    thumbPosition: cameraManager.thumbPosition,
                    middleFingerPosition: cameraManager.middleFingerPosition,
                    distance: cameraManager.fingerDistance,
                    isSnapReady: cameraManager.isSnapReady
                )
            }
            
            Rectangle()
                .stroke(isSnapDetected ? Color.red : Color.clear, lineWidth: 8)
                .animation(.easeInOut(duration: 0.1), value: isSnapDetected)
            
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    HStack {
                        Text(cameraManager.detectionState)
                            .foregroundColor(.white)
                            .padding()
                            .background(cameraManager.isSnapReady ? Color.green.opacity(0.8) : Color.blue.opacity(0.8))
                            .cornerRadius(8)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Model Confidence: \(String(format: "%.1f%%", cameraManager.modelConfidence * 100)) (Need: \(Int(configService.confidenceThreshold * 100))%)")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        Spacer()
                    }
                    
                    if cameraManager.isSnapReady {
                        HStack {
                            Text("Distance: \(String(format: "%.3f", cameraManager.fingerDistance))")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                            Spacer()
                        }
                    }
                }
                .padding()
            }
        }
        .onReceive(cameraManager.$snapDetected) { detected in
            if detected {
                isSnapDetected = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSnapDetected = false
                }
                cameraManager.snapDetected = false
            }
        }
    }
}

struct FingerVisualizationView: View {
    let thumbPosition: CGPoint
    let middleFingerPosition: CGPoint
    let distance: Double
    let isSnapReady: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Line between fingers
                Path { path in
                    let thumbPoint = CGPoint(
                        x: thumbPosition.x * geometry.size.width,
                        y: thumbPosition.y * geometry.size.height
                    )
                    let middlePoint = CGPoint(
                        x: middleFingerPosition.x * geometry.size.width,
                        y: middleFingerPosition.y * geometry.size.height
                    )
                    
                    path.move(to: thumbPoint)
                    path.addLine(to: middlePoint)
                }
                .stroke(isSnapReady ? Color.green : Color.yellow, lineWidth: 3)
                .animation(.easeInOut(duration: 0.2), value: isSnapReady)
                
                // Thumb tip marker
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                    .position(
                        x: thumbPosition.x * geometry.size.width,
                        y: thumbPosition.y * geometry.size.height
                    )
                
                // Middle finger tip marker
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .position(
                        x: middleFingerPosition.x * geometry.size.width,
                        y: middleFingerPosition.y * geometry.size.height
                    )
                
                // Distance label
                Text(String(format: "%.3f", distance))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .position(
                        x: (thumbPosition.x + middleFingerPosition.x) / 2 * geometry.size.width,
                        y: (thumbPosition.y + middleFingerPosition.y) / 2 * geometry.size.height - 20
                    )
            }
        }
    }
}

struct CameraView: NSViewRepresentable {
    let cameraManager: CameraManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        // Setup preview after a small delay to ensure camera session is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cameraManager.setupPreview(in: view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update preview layer frame when view bounds change
        if let previewLayer = cameraManager.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = nsView.bounds
            }
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private var snapClassifierModel: MLModel?
    
    // App state management
    @Published var isEnabled = true  // Can be controlled by run/pause
    @Published var isHotkeyMode = false  // Disable hotkeys in dev mode
    
    @Published var fingerDistance: Double = 0.0
    @Published var snapDetected = false
    @Published var modelConfidence: Double = 0.0
    @Published var isSnapReady = false
    @Published var isMiddleFingerDetected = false
    @Published var detectionState = "Initializing..."
    @Published var thumbPosition: CGPoint = .zero
    @Published var middleFingerPosition: CGPoint = .zero
    @Published var showFingerPoints = false
    
    private var previousDistance: Double = 0.0
    private var distanceHistory: [Double] = []
    private var lastSnapTime: Date = Date.distantPast
    private var velocityHistory: [Double] = []
    private var lastFrameProcessTime: Date = Date.distantPast
    
    // Middle finger detection state
    private var middleFingerStartTime: Date?
    private var lastMiddleFingerHotkeyTime: Date = Date.distantPast
    
    private let settingsService: SettingsService
    private let configService: any ConfigurationService
    
    init(settingsService: SettingsService = .shared, configService: (any ConfigurationService)? = nil) {
        self.settingsService = settingsService
        self.configService = configService ?? DefaultConfigurationService(settingsService: settingsService)
        
        super.init()
        
        // Start legacy notification bridge
        settingsService.startLegacyNotifications()
        
        loadModel()
        setupCamera()
        setupHotkeyListener()
    }
    
    // Legacy init for backward compatibility
    convenience override init() {
        self.init(settingsService: .shared, configService: nil)
    }
    
    private func setupHotkeyListener() {
        NotificationCenter.default.addObserver(
            forName: .hotkeyPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleHotkeyPressed()
        }
        
        NotificationCenter.default.addObserver(
            forName: .fpsSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFPSSettingsChanged(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .middleFingerHotkeyPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMiddleFingerHotkeyPressed()
        }
        
        NotificationCenter.default.addObserver(
            forName: .middleFingerSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMiddleFingerSettingsChanged(notification)
        }
    }
    
    private func handleHotkeyPressed() {
        guard isEnabled && !isHotkeyMode else { return }
        
        // Simulate a snap detection for hotkey
        DispatchQueue.main.async { [weak self] in
            self?.snapDetected = true
        }
    }
    
    private func handleFPSSettingsChanged(_ notification: Notification) {
        guard let fpsSettings = notification.object as? [String: Int],
              let processingFPS = fpsSettings["processingFPS"] else { return }
        
        // Update the legacy static configuration for backward compatibility
        SnapDetectionConfig.processingFPS = processingFPS
        
        print("📊 FPS Settings updated in CameraManager:")
        print("   Processing FPS: \(processingFPS)fps (interval: \(configService.frameProcessInterval)s)")
        print("   Camera FPS: \(configService.cameraFPS)fps")
    }
    
    private func handleMiddleFingerHotkeyPressed() {
        guard isEnabled && !isHotkeyMode else { return }
        
        // Simulate middle finger hotkey
        simulateMiddleFingerHotkey()
    }
    
    private func handleMiddleFingerSettingsChanged(_ notification: Notification) {
        guard let settings = notification.object as? [String: Any],
              let holdDuration = settings["holdDuration"] as? Double else { return }
        
        // Update the legacy static configuration for backward compatibility
        SnapDetectionConfig.middleFingerHoldDuration = holdDuration
        
        print("🖕 Middle finger hold duration updated: \(holdDuration)s")
    }
    
    private func loadModel() {
        let modelName = configService.modelName
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            DispatchQueue.main.async {
                self.detectionState = "Model not found"
            }
            print("Failed to find \(modelName).mlmodelc")
            return
        }
        
        do {
            snapClassifierModel = try MLModel(contentsOf: modelURL)
            DispatchQueue.main.async {
                self.detectionState = "Model loaded successfully"
            }
            print("Successfully loaded \(modelName) model")
            print("Model input description: \(snapClassifierModel?.modelDescription.inputDescriptionsByName ?? [:])")
            print("Model output description: \(snapClassifierModel?.modelDescription.outputDescriptionsByName ?? [:])")
        } catch {
            DispatchQueue.main.async {
                self.detectionState = "Model load failed: \(error.localizedDescription)"
            }
            print("Failed to load model: \(error)")
        }
    }
    
    private func setupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.configureCamera()
                    }
                } else {
                    print("Camera access denied")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted")
        @unknown default:
            print("Unknown camera authorization status")
        }
    }
    
    private func configureCamera() {
        captureSession.beginConfiguration()
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to get front camera, trying default camera")
            guard let camera = AVCaptureDevice.default(for: .video) else {
                print("No camera available")
                return
            }
            setupCameraInput(camera)
            return
        }
        
        setupCameraInput(camera)
    }
    
    private func setupCameraInput(_ camera: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                print("Camera input added successfully")
                
                // Configure camera FPS
                try camera.lockForConfiguration()
                if let format = camera.activeFormat.videoSupportedFrameRateRanges.first {
                    let fps = min(Double(configService.cameraFPS), format.maxFrameRate)
                    camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                    camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                }
                camera.unlockForConfiguration()
            } else {
                print("Cannot add camera input to session")
            }
        } catch {
            print("Failed to create camera input: \(error)")
            return
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("Video output added successfully")
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            print("Camera session started")
        }
    }
    
    func setupPreview(in view: NSView) {
        view.wantsLayer = true
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer?.addSublayer(previewLayer)
            
            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
                print("Preview layer frame set to: \(view.bounds)")
            }
        }
    }
    
    // Load FPS settings from UserDefaults and apply to camera
    func loadFPSSettings() {
        let savedFPS = UserDefaults.standard.integer(forKey: "CameraFPS")
        if savedFPS > 0 {
            print("Loading saved FPS setting: \(savedFPS)")
            // Apply FPS setting if camera is already configured
            if let camera = captureSession.inputs.first as? AVCaptureDeviceInput {
                applyFPSSetting(to: camera.device, fps: savedFPS)
            }
        }
    }
    
    // Update camera state based on isEnabled property
    func updateCameraState() {
        if isEnabled && !captureSession.isRunning {
            startCamera()
        } else if !isEnabled && captureSession.isRunning {
            stopCamera()
        }
    }
    
    // Start the camera session
    func startCamera() {
        guard !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            print("Camera session started")
        }
    }
    
    // Stop the camera session
    func stopCamera() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
            print("Camera session stopped")
        }
    }
    
    // Helper method to apply FPS settings to camera device
    private func applyFPSSetting(to camera: AVCaptureDevice, fps: Int) {
        do {
            try camera.lockForConfiguration()
            if let format = camera.activeFormat.videoSupportedFrameRateRanges.first {
                let targetFPS = min(Double(fps), format.maxFrameRate)
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
                print("Applied FPS setting: \(targetFPS)")
            }
            camera.unlockForConfiguration()
        } catch {
            print("Failed to apply FPS setting: \(error)")
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Don't process if disabled
        guard isEnabled else { return }
        
        let now = Date()
        
        // Frame processing debouncing - only process frames at specified interval
        guard now.timeIntervalSince(lastFrameProcessTime) >= configService.frameProcessInterval else { return }
        lastFrameProcessTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let observations = handPoseRequest.results else { return }
            
            for observation in observations {
                processHandPose(observation)
            }
        } catch {
            print("Failed to perform hand pose detection: \(error)")
        }
    }
    
    private func processHandPose(_ observation: VNHumanHandPoseObservation) {
        // Extract all hand pose points
        guard let handPosePoints = try? observation.recognizedPoints(.all) else {
            DispatchQueue.main.async {
                self.detectionState = "Failed to extract hand pose"
                self.isSnapReady = false
                self.isMiddleFingerDetected = false
                self.modelConfidence = 0.0
            }
            return
        }
        
        // Convert hand pose to model input format
        guard let poseArray = convertHandPoseToModelInput(handPosePoints) else {
            DispatchQueue.main.async {
                self.detectionState = "Failed to convert hand pose"
                self.isSnapReady = false
                self.isMiddleFingerDetected = false
                self.modelConfidence = 0.0
            }
            return
        }
        
        // Run ML model inference to classify the gesture
        classifyGesture(poseArray) { [weak self] confidence, gestureType in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.modelConfidence = confidence
                
                switch gestureType {
                case .snapReady:
                    self.isSnapReady = true
                    self.isMiddleFingerDetected = false
                    self.detectionState = "Snap Ready - Tracking Distance"
                    self.middleFingerStartTime = nil
                    
                case .middleFinger:
                    self.isSnapReady = false
                    self.isMiddleFingerDetected = true
                    self.detectionState = "Middle Finger Detected"
                    self.handleMiddleFingerDetection()
                    
                case .incorrect:
                    self.isSnapReady = false
                    self.isMiddleFingerDetected = false
                    self.detectionState = "Looking for Gesture"
                    self.fingerDistance = 0.0
                    self.showFingerPoints = false
                    self.middleFingerStartTime = nil
                }
            }
        }
        
        // Always track finger distance for snap detection (not dependent on SnapReady state)
        trackFingerDistance(observation)
    }
    
    private func trackFingerDistance(_ observation: VNHumanHandPoseObservation) {
        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let middleFingerTip = try? observation.recognizedPoint(.middleTip),
              let wrist = try? observation.recognizedPoint(.wrist),
              thumbTip.confidence > configService.minJointConfidence,
              middleFingerTip.confidence > configService.minJointConfidence,
              wrist.confidence > configService.minJointConfidence else {
            DispatchQueue.main.async {
                self.showFingerPoints = false
            }
            return
        }
        
        // Convert Vision coordinates to screen coordinates
        // Vision coordinates: (0,0) is bottom-left, (1,1) is top-right
        // Screen coordinates: (0,0) is top-left
        let thumbScreenPoint = CGPoint(
            x: thumbTip.location.x,
            y: 1.0 - thumbTip.location.y  // Flip Y coordinate
        )
        let middleScreenPoint = CGPoint(
            x: middleFingerTip.location.x,
            y: 1.0 - middleFingerTip.location.y  // Flip Y coordinate
        )
        
        // Calculate distances
        let fingerDistance = sqrt(pow(thumbTip.location.x - middleFingerTip.location.x, 2) + 
                                 pow(thumbTip.location.y - middleFingerTip.location.y, 2))
        
        // Calculate hand scale using wrist to middle finger distance as reference
        let handScale = sqrt(pow(wrist.location.x - middleFingerTip.location.x, 2) + 
                            pow(wrist.location.y - middleFingerTip.location.y, 2))
        
        // Update UI properties on main thread
        DispatchQueue.main.async {
            self.thumbPosition = thumbScreenPoint
            self.middleFingerPosition = middleScreenPoint
            self.showFingerPoints = true
            self.fingerDistance = fingerDistance
        }
        
        detectSnap(distance: fingerDistance, handScale: handScale)
    }
    
    private func detectSnap(distance: Double, handScale: Double) {
        let now = Date()
        
        // Check cooldown period - prevent multiple detections
        guard now.timeIntervalSince(lastSnapTime) > configService.snapCooldownPeriod else { return }
        
        // Normalize distance relative to hand size
        let normalizedDistance = handScale > 0 ? distance / handScale : distance
        
        distanceHistory.append(normalizedDistance)
        if distanceHistory.count > configService.historySize {
            distanceHistory.removeFirst()
        }
        
        guard distanceHistory.count == configService.historySize else { return }
        
        // Calculate velocity over the entire history using normalized distances
        let oldestDistance = distanceHistory[0]
        let currentDistance = distanceHistory.last!
        let totalChange = currentDistance - oldestDistance
        let velocity = totalChange / Double(configService.historySize)
        
        // Track velocity changes to detect rapid acceleration
        velocityHistory.append(velocity)
        if velocityHistory.count > 4 {
            velocityHistory.removeFirst()
        }
        
        // Only detect snaps if we have enough data
        guard velocityHistory.count >= 3 else { return }
        
        // Use configurable thresholds for snap detection
        let isRapidIncrease = velocity > configService.velocityThreshold && 
                             currentDistance > oldestDistance * configService.distanceChangeThreshold
        
        // Additional check: velocity should be accelerating (increasing over time)
        let velocityIncrease = velocityHistory.count >= 2 && 
                              velocityHistory.last! > velocityHistory[velocityHistory.count - 2] * configService.velocityAccelerationThreshold
        
        // Require both rapid distance increase AND velocity acceleration AND minimum distance
        let snapDetected = isRapidIncrease && velocityIncrease && currentDistance > configService.minNormalizedDistance
        
        // Debug output (reduced)
        if snapDetected {
            print("🔥 SNAP DETECTED! Normalized Distance: \(String(format: "%.4f", currentDistance)), Hand Scale: \(String(format: "%.4f", handScale)), Velocity: \(String(format: "%.4f", velocity))")
            DispatchQueue.main.async {
                self.snapDetected = true
            }
            
            // Simulate the registered hotkey when snap is detected (only if running and not in dev mode)
            if isEnabled && !isHotkeyMode {
                simulateRegisteredHotkey()
            } else {
                print("🔧 Snap detected but hotkey blocked - isEnabled: \(isEnabled), isHotkeyMode: \(isHotkeyMode)")
            }
            
            lastSnapTime = now
        }
        
        previousDistance = distance
    }
    
    private func simulateRegisteredHotkey() {
        guard let savedKeys = UserDefaults.standard.array(forKey: "SnapSnapHotkey") as? [String],
              !savedKeys.isEmpty else {
            print("No saved snap hotkey to simulate")
            return
        }
        simulateHotkey(savedKeys, type: "snap")
    }
    
    private func simulateMiddleFingerHotkey() {
        guard let savedKeys = UserDefaults.standard.array(forKey: "MiddleFingerHotkey") as? [String],
              !savedKeys.isEmpty else {
            print("No saved middle finger hotkey to simulate")
            return
        }
        simulateHotkey(savedKeys, type: "middle finger")
    }
    
    private func simulateHotkey(_ savedKeys: [String], type: String) {
        
        // Check if we have accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ Accessibility permission required to simulate hotkeys. Please enable in System Preferences > Security & Privacy > Accessibility")
            return
        }
        
        print("Simulating \(type) hotkey: \(savedKeys.joined(separator: " + "))")
        
        // Convert saved keys to CGEventFlags and key codes
        var flags: CGEventFlags = []
        var keyCodes: [CGKeyCode] = []
        
        for key in savedKeys {
            switch key {
            case "⌘": flags.insert(.maskCommand)
            case "⌃": flags.insert(.maskControl)
            case "⌥": flags.insert(.maskAlternate)
            case "⇧": flags.insert(.maskShift)
            case "fn": flags.insert(.maskSecondaryFn)
            case "Space": keyCodes.append(49)  // Space key code
            case "Tab": keyCodes.append(48)
            case "Enter": keyCodes.append(36)
            case "Escape": keyCodes.append(53)
            case "Delete": keyCodes.append(51)
            default:
                // Handle letter keys A-Z
                if key.count == 1, let char = key.first, char.isLetter {
                    let keyCode = CGKeyCode(char.uppercased().unicodeScalars.first!.value - 65)  // A=0, B=1, etc.
                    keyCodes.append(keyCode)
                }
            }
        }
        
        // Send the key combination
        if !keyCodes.isEmpty {
            for keyCode in keyCodes {
                // Key down event
                if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                    keyDownEvent.flags = flags
                    keyDownEvent.post(tap: .cghidEventTap)
                }
                
                // Key up event
                if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    keyUpEvent.flags = flags
                    keyUpEvent.post(tap: .cghidEventTap)
                }
            }
            print("\(type.capitalized) hotkey simulation completed")
        } else if !flags.isEmpty {
            // Handle modifier-only combinations (like just ⌘)
            if let event = CGEvent(source: nil) {
                event.flags = flags
                event.post(tap: .cghidEventTap)
            }
            print("Modifier-only \(type) hotkey simulation completed")
        }
    }
    
    private func convertHandPoseToModelInput(_ handPosePoints: [VNHumanHandPoseObservation.JointName : VNRecognizedPoint]) -> MLMultiArray? {
        // Create MLMultiArray with shape [1, 3, 21] for model input
        guard let multiArray = try? MLMultiArray(shape: [1, 3, 21], dataType: .float32) else {
            print("Failed to create MLMultiArray")
            return nil
        }
        
        // Define the joint order (21 points)
        let jointOrder: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        
        // Fill the array with hand pose data
        for (index, joint) in jointOrder.enumerated() {
            if let point = handPosePoints[joint], point.confidence > 0.1 {
                // x, y, confidence for each joint
                multiArray[[0, 0, index] as [NSNumber]] = NSNumber(value: Float(point.location.x))
                multiArray[[0, 1, index] as [NSNumber]] = NSNumber(value: Float(point.location.y))
                multiArray[[0, 2, index] as [NSNumber]] = NSNumber(value: Float(point.confidence))
            } else {
                // Use zero values if joint not detected
                multiArray[[0, 0, index] as [NSNumber]] = 0.0
                multiArray[[0, 1, index] as [NSNumber]] = 0.0
                multiArray[[0, 2, index] as [NSNumber]] = 0.0
            }
        }
        
        return multiArray
    }
    
    private func classifyGesture(_ poseArray: MLMultiArray, completion: @escaping (Double, GestureType) -> Void) {
        guard let model = snapClassifierModel else {
            print("Model not loaded")
            completion(0.0, .incorrect)
            return
        }
        
        // Create model input
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["poses": poseArray])
            let prediction = try model.prediction(from: input)
            
            var maxConfidence = 0.0
            var detectedGesture: GestureType = .incorrect
            
            // Method 1: Try labelProbabilities
            if let labelProbabilities = prediction.featureValue(for: "labelProbabilities")?.dictionaryValue {
                // Check for SnapReady
                if let snapReadyProb = labelProbabilities["SnapReady"] as? Double, snapReadyProb > maxConfidence {
                    maxConfidence = snapReadyProb
                    detectedGesture = .snapReady
                }
                
                // Check for MiddleFinger
                if let middleFingerProb = labelProbabilities["MiddleFinger"] as? Double, middleFingerProb > maxConfidence {
                    maxConfidence = middleFingerProb
                    detectedGesture = .middleFinger
                }
                
                // Check for Incorrect
                if let incorrectProb = labelProbabilities["Incorrect"] as? Double, incorrectProb > maxConfidence {
                    maxConfidence = incorrectProb
                    detectedGesture = .incorrect
                }
            }
            
            // Method 2: Try direct label output if probabilities not found
            if maxConfidence == 0.0, let label = prediction.featureValue(for: "label")?.stringValue {
                maxConfidence = 0.9 // Assume high confidence for direct label
                switch label {
                case "SnapReady":
                    detectedGesture = .snapReady
                case "MiddleFinger":
                    detectedGesture = .middleFinger
                default:
                    detectedGesture = .incorrect
                }
            }
            
            // Only accept detection if confidence is above threshold
            if maxConfidence >= configService.confidenceThreshold {
                completion(maxConfidence, detectedGesture)
            } else {
                completion(maxConfidence, .incorrect)
            }
            
        } catch {
            print("Model prediction failed: \(error)")
            completion(0.0, .incorrect)
        }
    }
    
    private func handleMiddleFingerDetection() {
        let now = Date()
        
        // Check cooldown period
        guard now.timeIntervalSince(lastMiddleFingerHotkeyTime) > configService.middleFingerCooldownPeriod else { 
            return 
        }
        
        if middleFingerStartTime == nil {
            // Start tracking middle finger hold
            middleFingerStartTime = now
            print("🖕 Middle finger detected - starting hold timer")
        } else if let startTime = middleFingerStartTime,
                  now.timeIntervalSince(startTime) >= configService.middleFingerHoldDuration {
            // Middle finger held for required duration
            print("🖕 Middle finger held for \(configService.middleFingerHoldDuration)s - triggering hotkey")
            
            if isEnabled && !isHotkeyMode {
                NotificationCenter.default.post(name: .middleFingerHotkeyPressed, object: nil)
            } else {
                print("🔧 Middle finger detected but hotkey blocked - isEnabled: \(isEnabled), isHotkeyMode: \(isHotkeyMode)")
            }
            
            lastMiddleFingerHotkeyTime = now
            middleFingerStartTime = nil
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsService.shared)
}
