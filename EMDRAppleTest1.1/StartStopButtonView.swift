import SwiftUI

struct StartStopButtonView: View {
    @Binding var isRunning: Bool
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var speed: Int
    
    var body: some View {
        VStack {
            Button {
                isRunning.toggle()
                if isRunning {
                    bluetoothManager.sendSpeed(Double(speed))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        debugPrint("=== Starting Sequence ===")
                        debugPrint("• Speed sent: \(speed)")
                        bluetoothManager.sendStartAndTapperFlags(true)
                    }
                } else {
                    debugPrint("=== Stopping Sequence ===")
                    bluetoothManager.sendStartAndTapperFlags(false)
                }
            } label: {
                Text(isRunning ? "Stop" : "Start")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(isRunning ? Color.red : Color.green)
                    .cornerRadius(10)
            }
            
            // Warning indicators (only show when heartbeat missing)
            if bluetoothManager.leftHeartbeatMissing || bluetoothManager.rightHeartbeatMissing {
                HStack(spacing: 20) {
                    if bluetoothManager.leftHeartbeatMissing {
                        Text("L")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    if bluetoothManager.rightHeartbeatMissing {
                        Text("R")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
} 