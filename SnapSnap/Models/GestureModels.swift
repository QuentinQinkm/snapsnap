//
//  GestureModels.swift
//  SnapSnap
//
//  Created by Claude on 8/10/25.
//

import Foundation

// MARK: - Gesture Types
enum GestureType: String, CaseIterable {
    case snapReady = "SnapReady"
    case middleFinger = "MiddleFinger"
    case incorrect = "Incorrect"
    
    var displayName: String {
        switch self {
        case .snapReady:
            return "Snap Ready"
        case .middleFinger:
            return "Middle Finger"
        case .incorrect:
            return "Incorrect"
        }
    }
    
    var description: String {
        switch self {
        case .snapReady:
            return "Hand positioned for snap detection"
        case .middleFinger:
            return "Middle finger gesture detected"
        case .incorrect:
            return "No valid gesture detected"
        }
    }
}

// MARK: - Gesture Classification Result
struct GestureClassification {
    let type: GestureType
    let confidence: Double
    let timestamp: Date
    
    init(type: GestureType, confidence: Double) {
        self.type = type
        self.confidence = confidence
        self.timestamp = Date()
    }
    
    var isValid: Bool {
        confidence >= 0.95 // Move threshold to configuration later
    }
}

// MARK: - Hand Tracking Data
struct HandTrackingData {
    let thumbPosition: CGPoint
    let middleFingerPosition: CGPoint
    let wristPosition: CGPoint
    let fingerDistance: Double
    let handScale: Double
    let confidence: Float
    let timestamp: Date
    
    init(thumbPosition: CGPoint, middleFingerPosition: CGPoint, wristPosition: CGPoint, fingerDistance: Double, handScale: Double, confidence: Float) {
        self.thumbPosition = thumbPosition
        self.middleFingerPosition = middleFingerPosition
        self.wristPosition = wristPosition
        self.fingerDistance = fingerDistance
        self.handScale = handScale
        self.confidence = confidence
        self.timestamp = Date()
    }
    
    var normalizedDistance: Double {
        handScale > 0 ? fingerDistance / handScale : fingerDistance
    }
}

// MARK: - Detection State
enum DetectionState: String {
    case initializing = "Initializing..."
    case lookingForGesture = "Looking for Gesture"
    case snapReady = "Snap Ready - Tracking Distance"
    case middleFingerDetected = "Middle Finger Detected"
    case modelLoadFailed = "Model Load Failed"
    case cameraAccessDenied = "Camera Access Denied"
    case processing = "Processing..."
    
    var color: String {
        switch self {
        case .initializing, .processing:
            return "blue"
        case .lookingForGesture:
            return "gray"
        case .snapReady:
            return "green"
        case .middleFingerDetected:
            return "orange"
        case .modelLoadFailed, .cameraAccessDenied:
            return "red"
        }
    }
}