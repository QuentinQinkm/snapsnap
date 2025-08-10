//
//  SettingsService.swift
//  SnapSnap
//
//  Created by Claude on 8/10/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Property Wrapper for UserDefaults
@propertyWrapper
struct UserDefault<T: Codable> {
    private let key: String
    private let defaultValue: T
    
    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            // Handle primitive types directly
            if T.self == String.self || T.self == Int.self || T.self == Double.self || T.self == Bool.self {
                return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
            }
            
            // Handle arrays of strings (our hotkey case) - check for array first
            if T.self == [String].self {
                return UserDefaults.standard.array(forKey: key) as? T ?? defaultValue
            }
            
            // Handle other Codable types with JSON
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValue
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Failed to decode \(key): \(error)")
                return defaultValue
            }
        }
        set {
            // Handle primitive types directly
            if T.self == String.self || T.self == Int.self || T.self == Double.self || T.self == Bool.self {
                UserDefaults.standard.set(newValue, forKey: key)
                return
            }
            
            // Handle arrays of strings (our hotkey case)
            if T.self == [String].self {
                UserDefaults.standard.set(newValue, forKey: key)
                return
            }
            
            // Handle other Codable types with JSON
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: key)
            } catch {
                print("Failed to encode \(key): \(error)")
            }
        }
    }
}

// MARK: - Settings Service
class SettingsService: ObservableObject {
    static let shared = SettingsService()
    
    // MARK: - Hotkey Settings
    @UserDefault(key: "SnapSnapHotkey", defaultValue: [])
    var snapHotkey: [String] {
        didSet {
            print("📝 SettingsService: snapHotkey changed to: \(snapHotkey)")
            objectWillChange.send()
            hotkeyChanged.send()
        }
    }
    
    @UserDefault(key: "MiddleFingerHotkey", defaultValue: [])  
    var middleFingerHotkey: [String] {
        didSet {
            print("📝 SettingsService: middleFingerHotkey changed to: \(middleFingerHotkey)")
            objectWillChange.send()
            middleFingerSettingsChanged.send()
        }
    }
    
    // MARK: - Performance Settings
    @UserDefault(key: "ProcessingFPS", defaultValue: 15)
    var processingFPS: Int {
        didSet {
            objectWillChange.send()
            performanceSettingsChanged.send()
        }
    }
    
    // MARK: - Middle Finger Settings
    @UserDefault(key: "MiddleFingerHoldDuration", defaultValue: 1.0)
    var middleFingerHoldDuration: Double {
        didSet {
            objectWillChange.send()
            middleFingerSettingsChanged.send()
        }
    }
    
    // MARK: - Publishers for reactive updates
    let hotkeyChanged = PassthroughSubject<Void, Never>()
    let middleFingerSettingsChanged = PassthroughSubject<Void, Never>()
    let performanceSettingsChanged = PassthroughSubject<Void, Never>()
    
    // MARK: - Combine Support
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load initial values to trigger any migrations if needed
        _ = snapHotkey
        _ = middleFingerHotkey  
        _ = processingFPS
        _ = middleFingerHoldDuration
    }
    
    // MARK: - Convenience Methods
    var snapHotkeyString: String {
        snapHotkey.isEmpty ? "No keys selected" : snapHotkey.joined(separator: " + ")
    }
    
    var middleFingerHotkeyString: String {
        middleFingerHotkey.isEmpty ? "No keys selected" : middleFingerHotkey.joined(separator: " + ")
    }
    
    func setSnapHotkey(_ keys: [String]) {
        snapHotkey = keys
    }
    
    func setMiddleFingerHotkey(_ keys: [String]) {
        middleFingerHotkey = keys
    }
    
    func clearSnapHotkey() {
        snapHotkey = []
    }
    
    func clearMiddleFingerHotkey() {
        middleFingerHotkey = []
    }
    
    func clearAllHotkeys() {
        snapHotkey = []
        middleFingerHotkey = []
    }
    
    // MARK: - Validation
    func validateSettings() -> [String] {
        var issues: [String] = []
        
        if snapHotkey.isEmpty && middleFingerHotkey.isEmpty {
            issues.append("No hotkeys configured")
        }
        
        if processingFPS < 5 || processingFPS > 30 {
            issues.append("Processing FPS should be between 5-30")
        }
        
        if middleFingerHoldDuration < 0.1 || middleFingerHoldDuration > 5.0 {
            issues.append("Hold duration should be between 0.1-5.0 seconds")
        }
        
        return issues
    }
}

// MARK: - Legacy Notification Support
extension SettingsService {
    func startLegacyNotifications() {
        // Bridge to old notification system during transition
        hotkeyChanged
            .sink { [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: Notification.Name("hotkeySettingsChanged"),
                    object: ["snapHotkey": self.snapHotkey]
                )
            }
            .store(in: &cancellables)
            
        performanceSettingsChanged
            .sink { [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: Notification.Name("fpsSettingsChanged"),
                    object: ["processingFPS": self.processingFPS]
                )
            }
            .store(in: &cancellables)
            
        middleFingerSettingsChanged
            .sink { [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: Notification.Name("middleFingerSettingsChanged"),
                    object: [
                        "holdDuration": self.middleFingerHoldDuration,
                        "hotkey": self.middleFingerHotkey
                    ]
                )
            }
            .store(in: &cancellables)
    }
}