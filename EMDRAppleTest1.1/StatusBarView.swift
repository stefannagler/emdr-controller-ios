import SwiftUI

struct StatusBarView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var lastBat1Update = Date()
    @State private var lastBat2Update = Date()
    let batteryTimeout: TimeInterval = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            // Left battery indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(isLeftBatteryMissing ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text("L: \(bluetoothManager.battery1Level)%")
            }
            
            Spacer()
            
            // Connection status
            Text("\(bluetoothManager.connectedDeviceCount) Connected")
                .foregroundColor(bluetoothManager.connectedDeviceCount > 0 ? .green : .red)
            
            Spacer()
            
            // Right battery indicator
            HStack(spacing: 4) {
                Text("R: \(bluetoothManager.battery2Level)%")
                Circle()
                    .fill(isRightBatteryMissing ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .onReceive(timer) { _ in
            let now = Date()
            // Update battery status indicators
            isLeftBatteryMissing = now.timeIntervalSince(lastBat1Update) > batteryTimeout
            isRightBatteryMissing = now.timeIntervalSince(lastBat2Update) > batteryTimeout
        }
        .onReceive(NotificationCenter.default.publisher(for: .batteryLevelUpdated)) { notification in
            if let isLeft = notification.userInfo?["isLeft"] as? Bool {
                if isLeft {
                    lastBat1Update = Date()
                } else {
                    lastBat2Update = Date()
                }
            }
        }
    }
    
    // Add state properties for battery status
    @State private var isLeftBatteryMissing = false
    @State private var isRightBatteryMissing = false
} 