//
//  SnapSnapApp.swift
//  SnapSnap
//
//  Created by Kuangming Qin on 8/8/25.
//

import SwiftUI
import AppKit
import Combine

@main
struct SnapSnapApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppState: ObservableObject {
    private var statusItem: NSStatusItem?
    private var cameraManager: CameraManager?
    private var devWindow: NSWindow?
    private var devWindowCheckTimer: Timer?
    
    @Published var isRunning = false
    @Published var isDevMode = false
    
    // Services
    private let settingsService = SettingsService.shared
    private let configService: any ConfigurationService
    
    init() {
        self.configService = DefaultConfigurationService(settingsService: settingsService)
        self.cameraManager = CameraManager()
        
        // Setup status bar after app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupStatusBar()
            self.loadSavedHotkey()
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func loadSavedHotkey() {
        if let savedHotkey = UserDefaults.standard.array(forKey: "SnapSnapHotkey") as? [String] {
            HotkeyManager.shared.registerHotkey(savedHotkey)
        }
        
        // Load FPS settings - simple direct approach
        loadFPSSettings()
    }
    
    private func loadFPSSettings() {
        // Settings are automatically loaded by SettingsService
        // Legacy notifications are triggered by SettingsService.startLegacyNotifications()
        
        print("📊 Settings loaded in AppState: Processing: \(settingsService.processingFPS)fps, Middle finger hold: \(settingsService.middleFingerHoldDuration)s")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Try SF Symbol first, fallback to text if it doesn't work
            if let image = NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: "SnapSnap") {
                button.image = image
            } else {
                // Fallback to text if SF Symbol fails
                button.title = "✋"
            }
            button.action = #selector(statusBarClicked)
            button.target = self
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let runPauseItem = NSMenuItem(
            title: isRunning ? "Pause" : "Run",
            action: #selector(toggleRunPause),
            keyEquivalent: ""
        )
        runPauseItem.target = self
        menu.addItem(runPauseItem)
        
        let recordHotkeyItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openHotkeyRecorder),
            keyEquivalent: ""
        )
        recordHotkeyItem.target = self
        menu.addItem(recordHotkeyItem)
        
        let devModeItem = NSMenuItem(
            title: isDevMode ? "Exit Dev Mode" : "Dev Mode",
            action: #selector(toggleDevMode),
            keyEquivalent: ""
        )
        devModeItem.target = self
        menu.addItem(devModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let exitItem = NSMenuItem(
            title: "Exit",
            action: #selector(exitApp),
            keyEquivalent: ""
        )
        exitItem.target = self
        menu.addItem(exitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func statusBarClicked() {
        // Refresh menu items
        setupMenu()
    }
    
    @objc private func toggleRunPause() {
        isRunning.toggle()
        cameraManager?.isEnabled = isRunning
        // Camera state is handled automatically by isEnabled property
        setupMenu() // Refresh menu
    }
    
    @objc private func openHotkeyRecorder() {
        HotkeyRecorderWindow.show()
    }
    
    @objc private func toggleDevMode() {
        // Safer approach - only check isDevMode, not devWindow reference
        if isDevMode {
            // Already in dev mode, user wants to exit
            print("🔧 Exiting Dev Mode - Hotkeys re-enabled")
            closeDevWindow()
        } else {
            // Entering dev mode
            print("🔧 Entering Dev Mode - Hotkeys disabled")
            openDevWindow()
        }
        
        setupMenu() // Refresh menu
    }
    
    @objc private func exitApp() {
        // Clean up resources
        closeDevWindow()
        NSApplication.shared.terminate(nil)
    }
    
    private func openDevWindow() {
        // Clean up first
        closeDevWindow()
        
        // Switch to regular app mode so window can appear properly
        NSApp.setActivationPolicy(.regular)
        
        // Create a ContentView with the same camera manager
        guard let cameraManager = cameraManager else {
            print("⚠️ Camera manager not available, cannot open dev window")
            return
        }
        
        // Set dev mode state
        isDevMode = true
        cameraManager.isHotkeyMode = true
        
        let contentView = ContentView(cameraManager: cameraManager)
        
        devWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        devWindow?.contentView = NSHostingView(rootView: contentView)
        devWindow?.title = "SnapSnap - Dev Mode"
        devWindow?.center()
        
        // Ensure window appears on top
        devWindow?.level = .floating
        devWindow?.makeKeyAndOrderFront(nil)
        
        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Simple approach: Check if window is closed every second
        startDevWindowMonitoring()
    }
    
    private func closeDevWindow() {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.closeDevWindow()
            }
            return
        }
        
        // Stop monitoring timer first
        devWindowCheckTimer?.invalidate()
        devWindowCheckTimer = nil
        
        // Reset state flags
        isDevMode = false
        
        // Safely access camera manager
        if let cameraManager = cameraManager {
            cameraManager.isHotkeyMode = false
        }
        
        // Close window if it exists
        if let window = devWindow {
            window.close()
        }
        devWindow = nil
        
        // Switch back to accessory mode (background app)
        NSApp.setActivationPolicy(.accessory)
        
        print("🔧 Dev window cleaned up, switched back to accessory mode")
    }
    
    private func startDevWindowMonitoring() {
        // Simple timer-based approach - check every second if window still exists
        devWindowCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkDevWindowStatus()
        }
    }
    
    private func checkDevWindowStatus() {
        // Only check if we're supposed to be in dev mode
        guard isDevMode else { return }
        
        // Safer check: verify window exists and is visible
        guard let window = devWindow else {
            print("🔧 Dev window reference is nil - resetting state")
            DispatchQueue.main.async { [weak self] in
                self?.resetDevMode()
            }
            return
        }
        
        // Check if window is still visible (not closed by user)
        if !window.isVisible {
            print("🔧 Dev window closed by user - resetting state")
            DispatchQueue.main.async { [weak self] in
                self?.resetDevMode()
            }
        }
    }
    
    private func resetDevMode() {
        // Ensure we're on the main thread for UI updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.resetDevMode()
            }
            return
        }
        
        // Stop the timer first to prevent recursive calls
        devWindowCheckTimer?.invalidate()
        devWindowCheckTimer = nil
        
        // Reset state flags
        isDevMode = false
        
        // Safely access camera manager
        if let cameraManager = cameraManager {
            cameraManager.isHotkeyMode = false
        }
        
        // Clear window reference
        devWindow = nil
        
        // Switch back to accessory mode
        NSApp.setActivationPolicy(.accessory)
        
        // Update menu
        setupMenu()
        print("🔧 Dev mode state reset completed, switched back to accessory mode")
    }
}
