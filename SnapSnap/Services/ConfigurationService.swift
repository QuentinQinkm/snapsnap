//
//  ConfigurationService.swift
//  SnapSnap
//
//  Created by Claude on 8/10/25.
//

import Foundation
import Combine

// MARK: - Configuration Protocol
protocol ConfigurationService: ObservableObject {
    // Performance Settings
    var processingFPS: Int { get }
    var cameraFPS: Int { get }
    var frameProcessInterval: TimeInterval { get }
    
    // Model Settings  
    var modelName: String { get }
    var confidenceThreshold: Double { get }
    
    // Gesture Detection Settings
    var middleFingerHoldDuration: TimeInterval { get }
    var middleFingerCooldownPeriod: TimeInterval { get }
    var snapCooldownPeriod: TimeInterval { get }
    
    // Hand Tracking Settings
    var minJointConfidence: Float { get }
    var historySize: Int { get }
    var velocityThreshold: Double { get }
    var distanceChangeThreshold: Double { get }
    var minNormalizedDistance: Double { get }
    var velocityAccelerationThreshold: Double { get }
}

// MARK: - Default Configuration Implementation
class DefaultConfigurationService: ConfigurationService, ObservableObject {
    private let settingsService: SettingsService
    private var cancellables = Set<AnyCancellable>()
    
    init(settingsService: SettingsService = .shared) {
        self.settingsService = settingsService
        
        // React to settings changes
        settingsService.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Dynamic Settings (from SettingsService)
    var processingFPS: Int {
        settingsService.processingFPS
    }
    
    var middleFingerHoldDuration: TimeInterval {
        settingsService.middleFingerHoldDuration
    }
    
    var frameProcessInterval: TimeInterval {
        1.0 / Double(processingFPS)
    }
    
    // MARK: - Static Settings (constants)
    var cameraFPS: Int { 15 }
    var modelName: String { "SnapModel5" }
    var confidenceThreshold: Double { 0.95 }
    
    // Gesture Detection Parameters
    var middleFingerCooldownPeriod: TimeInterval { 2.0 }
    var snapCooldownPeriod: TimeInterval { 0.8 }
    
    // Hand Tracking Parameters  
    var minJointConfidence: Float { 0.3 }
    var historySize: Int { 8 }
    var velocityThreshold: Double { 0.02 }
    var distanceChangeThreshold: Double { 1.25 }
    var minNormalizedDistance: Double { 0.15 }
    var velocityAccelerationThreshold: Double { 1.3 }
}

// MARK: - Test Configuration (for unit testing)
class TestConfigurationService: ConfigurationService, ObservableObject {
    var processingFPS: Int = 10
    var cameraFPS: Int = 15
    var frameProcessInterval: TimeInterval { 1.0 / Double(processingFPS) }
    
    var modelName: String = "TestModel"
    var confidenceThreshold: Double = 0.5
    
    var middleFingerHoldDuration: TimeInterval = 0.1
    var middleFingerCooldownPeriod: TimeInterval = 0.1
    var snapCooldownPeriod: TimeInterval = 0.1
    
    var minJointConfidence: Float = 0.1
    var historySize: Int = 3
    var velocityThreshold: Double = 0.01
    var distanceChangeThreshold: Double = 1.1
    var minNormalizedDistance: Double = 0.1
    var velocityAccelerationThreshold: Double = 1.1
}

// MARK: - Configuration Factory
struct ConfigurationFactory {
    static func createConfiguration(for environment: AppEnvironment = .production) -> any ConfigurationService {
        switch environment {
        case .production:
            return DefaultConfigurationService()
        case .testing:
            return TestConfigurationService()
        }
    }
}

enum AppEnvironment {
    case production
    case testing
}