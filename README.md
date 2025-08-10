# SnapSnap

(Written By Claude, not human

A macOS application that detects finger snap and middle finger gestures using computer vision and machine learning to trigger customizable hotkeys.

## Features

- **Gesture Detection**: Real-time detection of snap gestures and middle finger poses
- **Custom Hotkeys**: Configurable keyboard shortcuts for both gesture types
- **Dev Mode**: Live camera view for debugging and testing gesture detection
- **Status Bar Integration**: Runs quietly in the background with status bar controls
- **Tabbed Settings**: Easy-to-use settings interface with separate tabs for snap and middle finger configuration

## Current Model

The application uses **SnapModel5** which supports 3 gesture labels:
- `SnapReady`: Hand positioned for snap detection (thumb and middle finger close together)
- `MiddleFinger`: Middle finger extended gesture
- `Incorrect`: No valid gesture detected or hand not properly positioned

## Configuration

### Settings Service
The app uses a centralized `SettingsService` that manages:
- **Snap Hotkey**: Customizable key combination for snap gestures
- **Middle Finger Hotkey**: Customizable key combination for middle finger gestures
- **Processing FPS**: Frame processing rate (default: 15fps)
- **Middle Finger Hold Duration**: How long to hold the gesture before triggering (0.5-2.0 seconds)

### Configuration Service
The `ConfigurationService` protocol provides:
- **Performance Settings**: Processing FPS, camera FPS, frame intervals
- **Model Settings**: Model name, confidence thresholds
- **Gesture Detection**: Hold durations, cooldown periods
- **Hand Tracking**: Joint confidence thresholds, velocity parameters

Default configuration:
- Camera FPS: 15fps
- Model: SnapModel5
- Confidence Threshold: 95%
- Snap Cooldown: 0.8 seconds
- Middle Finger Cooldown: 2.0 seconds

## Usage

1. **First Launch**: Grant camera and accessibility permissions when prompted
2. **Status Bar**: Click the hand icon in the status bar to access controls
3. **Settings**: Configure hotkeys and gesture timing in the tabbed settings window
4. **Run/Pause**: Toggle gesture detection on/off
5. **Dev Mode**: Open camera view to see live gesture detection and confidence levels

### Gesture Detection
- **Snap**: Position thumb and middle finger close together, then snap apart quickly
- **Middle Finger**: Extend middle finger and hold for the configured duration

## Development

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Camera capture and video processing
- **Vision**: Hand pose detection
- **Core ML**: Custom gesture classification
- **Combine**: Reactive programming for settings updates

### Key Components
- `CameraManager`: Handles camera capture and ML inference
- `SettingsService`: Centralized settings with UserDefaults persistence
- `ConfigurationService`: Protocol-based configuration with dependency injection
- `HotkeyRecorderWindow`: Tabbed settings interface

### Building
```bash
xcodebuild -project SnapSnap.xcodeproj -scheme SnapSnap -configuration Debug build
```

## Known Issues

⚠️ **Dev Mode Window Crash**: The application may crash when closing the Dev Mode window. This is a known issue related to window lifecycle management.

## Requirements

- macOS 14.0+
- Camera access permission
- Accessibility permission (for hotkey simulation)
- Xcode 15+ (for building from source)

## Privacy

SnapSnap processes camera data locally on your device. No video or gesture data is transmitted to external servers. All processing happens using Apple's on-device Vision and Core ML frameworks.
