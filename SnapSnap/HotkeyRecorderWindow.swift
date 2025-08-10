import SwiftUI
import AppKit
import Combine
import ApplicationServices

class HotkeyRecorderWindow: NSWindowController {
    private static var shared: HotkeyRecorderWindow?
    
    static func show() {
        if shared == nil {
            shared = HotkeyRecorderWindow()
        }
        shared?.showWindow(nil)
        shared?.window?.center()
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.minSize = NSSize(width: 520, height: 400)
        window.maxSize = NSSize(width: 800, height: 1000)
        
        super.init(window: window)
        
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: HotkeyRecorderView())
        
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HotkeyRecorderWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        HotkeyRecorderWindow.shared = nil
    }
}

struct SnapHotkeySettingsView: View {
    @ObservedObject var recorder: HotkeyRecorder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Snap Hotkey Configuration")
                .font(.headline)
            
            Text("Triggered when finger snapping is detected")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HotkeyDropdown(
                    title: "Key 1:",
                    selection: $recorder.key1,
                    isFirst: true
                )
                
                HotkeyDropdown(
                    title: "Key 2:",
                    selection: $recorder.key2,
                    isFirst: false
                )
                .disabled(recorder.key1.isEmpty)
                
                HotkeyDropdown(
                    title: "Key 3:",
                    selection: $recorder.key3,
                    isFirst: false
                )
                .disabled(recorder.key2.isEmpty)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Combination:")
                    .font(.subheadline)
                
                Text(recorder.currentCombination.isEmpty ? "No keys selected" : recorder.currentCombination)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                    .font(.monospaced(.body)())
            }
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct MiddleFingerHotkeySettingsView: View {
    @ObservedObject var recorder: HotkeyRecorder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Middle Finger Hotkey Configuration")
                .font(.headline)
            
            Text("Triggered when middle finger gesture is held for specified duration")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Firing time selector
            HStack {
                Text("Hold Duration:")
                    .frame(width: 100, alignment: .leading)
                
                MiddleFingerTimePicker(
                    selection: $recorder.middleFingerHoldDuration
                )
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HotkeyDropdown(
                    title: "Key 1:",
                    selection: $recorder.middleKey1,
                    isFirst: true
                )
                
                HotkeyDropdown(
                    title: "Key 2:",
                    selection: $recorder.middleKey2,
                    isFirst: false
                )
                .disabled(recorder.middleKey1.isEmpty)
                
                HotkeyDropdown(
                    title: "Key 3:",
                    selection: $recorder.middleKey3,
                    isFirst: false
                )
                .disabled(recorder.middleKey2.isEmpty)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Combination:")
                    .font(.subheadline)
                
                Text(recorder.currentMiddleFingerCombination.isEmpty ? "No keys selected" : recorder.currentMiddleFingerCombination)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                    .font(.monospaced(.body)())
            }
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct MiddleFingerTimePicker: View {
    @Binding var selection: Double
    
    private let timeOptions: [Double] = [0.5, 1.0, 1.5, 2.0]
    
    var body: some View {
        Menu {
            ForEach(timeOptions, id: \.self) { time in
                Button("\(time, specifier: "%.1f") sec") {
                    selection = time
                }
            }
        } label: {
            HStack {
                Text("\(selection, specifier: "%.1f") sec")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
        }
        .frame(width: 80)
    }
}

struct HotkeyRecorderView: View {
    @StateObject private var recorder = HotkeyRecorder()
    @State private var accessibilityPermissionGranted = false
    @State private var showingPermissionAlert = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Settings")
                    .font(.title2)
                    .padding(.top, 8)
                
                // Accessibility Permission Status
                HStack {
                    Image(systemName: accessibilityPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(accessibilityPermissionGranted ? .green : .orange)
                    
                    Text(accessibilityPermissionGranted ? "Accessibility Permission Granted" : "Required for hotkey simulation")
                        .font(.caption)
                        .foregroundColor(accessibilityPermissionGranted ? .green : .orange)
                    
                    if !accessibilityPermissionGranted {
                        Button("Grant") {
                            requestAccessibilityPermission()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Tabs
            TabView(selection: $selectedTab) {
                // Snap Tab
                ScrollView {
                    VStack(spacing: 16) {
                        SnapHotkeySettingsView(recorder: recorder)
                        
                        // Quick action buttons for Snap
                        HStack {
                            Button("Clear") {
                                recorder.clearSnapKeys()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("⌘+Space") {
                                recorder.setQuickSnapCombo(["⌘", "Space"])
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                        }
                    }
                    .padding(16)
                }
                .tabItem {
                    Image(systemName: "hand.point.up.left")
                    Text("Snap")
                }
                .tag(0)
                
                // Middle Finger Tab
                ScrollView {
                    VStack(spacing: 16) {
                        MiddleFingerHotkeySettingsView(recorder: recorder)
                        
                        // Quick action buttons for Middle Finger
                        HStack {
                            Button("Clear") {
                                recorder.clearMiddleKeys()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("⌘+M") {
                                recorder.setQuickMiddleCombo(["⌘", "M"])
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                        }
                    }
                    .padding(16)
                }
                .tabItem {
                    Image(systemName: "hand.point.up.braille")
                    Text("Middle Finger")
                }
                .tag(1)
            }
            
            // Bottom section with FPS and Save
            VStack(spacing: 12) {
                Divider()
                
                // FPS Settings
                HStack {
                    Text("Processing FPS:")
                    FPSPicker(
                        selection: $recorder.processingFPS,
                        label: "fps"
                    )
                    
                    Spacer()
                    
                    Button("Save All Settings") {
                        recorder.saveHotkey()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            checkAccessibilityPermission()
            startPeriodicPermissionCheck()
        }
        .alert("Accessibility Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open System Preferences") {
                openSystemPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable SnapSnap in System Preferences > Security & Privacy > Privacy > Accessibility to allow hotkey simulation.")
        }
    }
    
    private func checkAccessibilityPermission() {
        accessibilityPermissionGranted = AXIsProcessTrusted()
    }
    
    private func requestAccessibilityPermission() {
        // Try to prompt for accessibility permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if accessibilityEnabled {
            accessibilityPermissionGranted = true
        } else {
            // If the system prompt doesn't appear, show our custom alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !AXIsProcessTrusted() {
                    showingPermissionAlert = true
                }
            }
        }
        
        // Update permission status
        checkAccessibilityPermission()
    }
    
    private func openSystemPreferences() {
        let prefPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefPaneURL)
    }
    
    private func startPeriodicPermissionCheck() {
        // Check permission status every 2 seconds to detect when user grants permission
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkAccessibilityPermission()
        }
    }
}

struct HotkeyDropdown: View {
    let title: String
    @Binding var selection: String
    let isFirst: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 50, alignment: .leading)
            
            KeyInputPicker(selection: $selection, isFirst: isFirst)
                .frame(maxWidth: .infinity)
        }
    }
}

struct FPSPicker: View {
    @Binding var selection: Int
    let label: String
    
    private let fpsOptions = [5, 10, 15, 20]
    
    var body: some View {
        Menu {
            ForEach(fpsOptions, id: \.self) { fps in
                Button("\(fps) fps") {
                    selection = fps
                }
            }
        } label: {
            HStack {
                Text("\(selection) \(label)")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
        }
        .frame(width: 80)
    }
}

struct KeyInputPicker: View {
    @Binding var selection: String
    let isFirst: Bool
    @State private var isListening = false
    
    private let modifierKeys = ["⌃", "⌥", "⇧", "⌘", "fn"]
    private let specialKeys = ["Space", "Tab", "Enter", "Escape", "Delete"]
    private let letterKeys = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
                             "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    
    var body: some View {
        Menu {
            Button("None") { selection = "" }
            
            Divider()
            
            // Modifier keys
            Section("Modifiers") {
                ForEach(modifierKeys, id: \.self) { key in
                    Button(keyDisplayName(key)) {
                        selection = key
                    }
                }
            }
            
            // Special keys  
            Section("Special Keys") {
                ForEach(specialKeys, id: \.self) { key in
                    Button(key) {
                        selection = key
                    }
                }
            }
            
            // Letter keys
            Section("Letters") {
                ForEach(letterKeys, id: \.self) { key in
                    Button(key) {
                        selection = key
                    }
                }
            }
            
        } label: {
            HStack {
                Text(selection.isEmpty ? "Select Key" : keyDisplayName(selection))
                    .foregroundColor(selection.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private func keyDisplayName(_ key: String) -> String {
        switch key {
        case "⌃": return "⌃ Control"
        case "⌥": return "⌥ Option"
        case "⇧": return "⇧ Shift"
        case "⌘": return "⌘ Command"
        case "fn": return "fn Function"
        default: return key
        }
    }
}

class HotkeyRecorder: ObservableObject {
    @Published var key1 = ""
    @Published var key2 = ""
    @Published var key3 = ""
    @Published var middleKey1 = ""
    @Published var middleKey2 = ""
    @Published var middleKey3 = ""
    
    private let settingsService: SettingsService
    
    // Computed properties that bind to SettingsService
    var processingFPS: Int {
        get { settingsService.processingFPS }
        set { settingsService.processingFPS = newValue }
    }
    
    var middleFingerHoldDuration: Double {
        get { settingsService.middleFingerHoldDuration }
        set { settingsService.middleFingerHoldDuration = newValue }
    }
    
    var currentCombination: String {
        let keys = [key1, key2, key3].filter { !$0.isEmpty }
        return keys.isEmpty ? "No keys selected" : keys.joined(separator: " + ")
    }
    
    var currentKeysArray: [String] {
        return [key1, key2, key3].filter { !$0.isEmpty }
    }
    
    var currentMiddleFingerCombination: String {
        let keys = [middleKey1, middleKey2, middleKey3].filter { !$0.isEmpty }
        return keys.isEmpty ? "No keys selected" : keys.joined(separator: " + ")
    }
    
    var currentMiddleKeysArray: [String] {
        return [middleKey1, middleKey2, middleKey3].filter { !$0.isEmpty }
    }
    
    init(settingsService: SettingsService = .shared) {
        self.settingsService = settingsService
        loadSavedHotkeys()
        
        // Listen for settings changes to update UI
        settingsService.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func loadSavedHotkeys() {
        // Load snap hotkey from settings service
        let snapKeys = settingsService.snapHotkey
        if snapKeys.count > 0 { key1 = snapKeys[0] }
        if snapKeys.count > 1 { key2 = snapKeys[1] }
        if snapKeys.count > 2 { key3 = snapKeys[2] }
        
        // Load middle finger hotkey from settings service
        let middleKeys = settingsService.middleFingerHotkey
        if middleKeys.count > 0 { middleKey1 = middleKeys[0] }
        if middleKeys.count > 1 { middleKey2 = middleKeys[1] }
        if middleKeys.count > 2 { middleKey3 = middleKeys[2] }
    }
    
    func setQuickSnapCombo(_ keys: [String]) {
        clearSnapKeys()
        if keys.count > 0 { key1 = keys[0] }
        if keys.count > 1 { key2 = keys[1] }
        if keys.count > 2 { key3 = keys[2] }
    }
    
    func setQuickMiddleCombo(_ keys: [String]) {
        clearMiddleKeys()
        if keys.count > 0 { middleKey1 = keys[0] }
        if keys.count > 1 { middleKey2 = keys[1] }
        if keys.count > 2 { middleKey3 = keys[2] }
    }
    
    func clearAll() {
        clearSnapKeys()
        clearMiddleKeys()
    }
    
    func clearSnapKeys() {
        key1 = ""
        key2 = ""
        key3 = ""
    }
    
    func clearMiddleKeys() {
        middleKey1 = ""
        middleKey2 = ""
        middleKey3 = ""
    }
    
    func saveHotkey() {
        let snapKeys = currentKeysArray
        let middleKeys = currentMiddleKeysArray
        
        // Save through settings service (automatically persists)
        settingsService.setSnapHotkey(snapKeys)
        settingsService.setMiddleFingerHotkey(middleKeys)
        // processingFPS and middleFingerHoldDuration are already bound to settingsService
        
        // Register global snap hotkey
        HotkeyManager.shared.registerHotkey(snapKeys)
        
        // Validate settings
        let validationIssues = settingsService.validateSettings()
        
        // Show confirmation
        let alert = NSAlert()
        if validationIssues.isEmpty {
            alert.messageText = "Settings Saved Successfully"
            var message = "All settings have been saved and applied."
            if !snapKeys.isEmpty {
                message += "\nSnap hotkey: \(currentCombination)"
            }
            if !middleKeys.isEmpty {
                message += "\nMiddle finger hotkey: \(currentMiddleFingerCombination)"
            }
            message += "\nProcessing FPS: \(processingFPS)"
            message += "\nHold duration: \(middleFingerHoldDuration)s"
            alert.informativeText = message
            alert.alertStyle = .informational
        } else {
            alert.messageText = "Settings Saved with Warnings"
            alert.informativeText = "Issues found:\n" + validationIssues.joined(separator: "\n")
            alert.alertStyle = .warning
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    private var currentKeys: [String] = []
    private var globalMonitor: Any?
    
    private init() {}
    
    func registerHotkey(_ keys: [String]) {
        unregisterHotkey()
        currentKeys = keys
        
        guard !keys.isEmpty else {
            print("No keys to register")
            return
        }
        
        // Monitor both keyDown and flagsChanged for modifier-only combinations
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.checkHotkeyMatch(event)
        }
        
        print("Registered hotkey: \(keys.joined(separator: " + "))")
    }
    
    private func checkHotkeyMatch(_ event: NSEvent) {
        guard !currentKeys.isEmpty else { return }
        
        var pressedKeys: [String] = []
        let flags = event.modifierFlags
        
        // Check modifiers
        if flags.contains(.control) { pressedKeys.append("⌃") }
        if flags.contains(.option) { pressedKeys.append("⌥") }
        if flags.contains(.shift) { pressedKeys.append("⇧") }
        if flags.contains(.command) { pressedKeys.append("⌘") }
        if flags.contains(.function) { pressedKeys.append("fn") }
        
        // For keyDown events, add the character
        if event.type == .keyDown {
            if let keyChar = event.charactersIgnoringModifiers?.uppercased() {
                if keyChar == " " {
                    pressedKeys.append("Space")
                } else {
                    pressedKeys.append(keyChar)
                }
            }
        }
        
        // Check if pressed combination matches registered hotkey
        if pressedKeys == currentKeys {
            print("Hotkey matched: \(pressedKeys.joined(separator: " + "))")
            handleHotkeyPressed()
        }
    }
    
    private func unregisterHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
            print("Unregistered hotkey monitor")
        }
        currentKeys.removeAll()
    }
    
    private func handleHotkeyPressed() {
        print("Hotkey triggered!")
        NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
    }
    
    deinit {
        unregisterHotkey()
    }
}

extension Notification.Name {
    static let hotkeyPressed = Notification.Name("hotkeyPressed")
    static let middleFingerHotkeyPressed = Notification.Name("middleFingerHotkeyPressed")
    static let fpsSettingsChanged = Notification.Name("fpsSettingsChanged")
    static let middleFingerSettingsChanged = Notification.Name("middleFingerSettingsChanged")
}

