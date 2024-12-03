# EMDR Controller App

Mobile application for controlling EMDR (Eye Movement Desensitization and Reprocessing) therapy devices via Bluetooth LE.

## Features
- Bluetooth LE peripheral mode
- Multiple stimulation modes:
  - Haptic (Buzz)
  - Light
  - Sound
  - Pressure
- Speed control (0-50 Hz)
- Battery level monitoring
- Connection status tracking
- Settings persistence
- Automatic reconnection

## Technical Details
- iOS Version: iOS 14.0+
- Flutter Version: Flutter 3.16.0+
- Bluetooth: Core Bluetooth / Flutter Blue Plus
- State Management: SwiftUI/@StateObject / Provider
- Data Persistence: UserDefaults / SharedPreferences

## Setup Instructions

### iOS Version
1. Clone repository: 