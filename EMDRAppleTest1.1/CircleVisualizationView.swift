import SwiftUI

struct CircleVisualizationView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var lastBat1Update = Date()
    @State private var lastBat2Update = Date()
    @State private var showBatteryWarning = false
    let batteryTimeout: TimeInterval = 10
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            // Battery warning
            if showBatteryWarning {
                Text("Battery level update missing")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.bottom, 2)
            }
            
            // Ball animation
            HStack {
                ZStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 4)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .offset(x: bluetoothManager.currentSide ? 100 : -100)
                }
                .frame(width: 240, height: 40)
            }
        }
        .padding()
        .onReceive(timer) { _ in
            let now = Date()
            // Check if either battery hasn't updated in 10 seconds
            showBatteryWarning = (now.timeIntervalSince(lastBat1Update) > batteryTimeout) ||
                                (now.timeIntervalSince(lastBat2Update) > batteryTimeout)
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
} 