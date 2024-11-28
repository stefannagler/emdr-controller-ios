import SwiftUI

struct ControlsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var speed: Int
    @Binding var buzzEnabled: Bool
    @Binding var buzzIntensity: Int
    @Binding var buzzDuration: Int
    @Binding var lightEnabled: Bool
    @Binding var lightIntensity: Int
    @Binding var lightDuration: Int
    @Binding var soundEnabled: Bool
    @Binding var soundIntensity: Int
    @Binding var soundDuration: Int
    @Binding var pressureEnabled: Bool
    @Binding var pressureIntensity: Int
    @Binding var pressureDuration: Int
    
    var body: some View {
        VStack(spacing: 20) {
            // Speed Control
            VStack(spacing: 10) {
                Text("Speed: \(speed)")
                    .font(.caption)
                HStack {
                    Image(systemName: "tortoise")
                    Slider(
                        value: Binding(
                            get: { Double(speed) },
                            set: { speed = Int($0) }
                        ),
                        in: 1...150,
                        step: 1
                    ) { isEditing in
                        if !isEditing {
                            bluetoothManager.sendSpeed(Double(speed))
                        }
                    }
                    Image(systemName: "hare")
                }
            }
            .padding(.horizontal)
            
            // Mode Controls
            VStack(spacing: 15) {
                ModeControlView(
                    title: "Buzz",
                    enabled: $buzzEnabled,
                    intensity: $buzzIntensity,
                    duration: $buzzDuration,
                    intensityRange: 5...250,
                    durationRange: 1...4,
                    onToggle: { bluetoothManager.sendTapperOnOff($0) },
                    onIntensityChange: { bluetoothManager.sendHapticIntensity($0) },
                    onDurationChange: { bluetoothManager.sendBuzzDuration($0) }
                )
                
                ModeControlView(
                    title: "Light",
                    enabled: $lightEnabled,
                    intensity: $lightIntensity,
                    duration: $lightDuration,
                    intensityRange: 5...250,
                    durationRange: 1...4,
                    onToggle: { bluetoothManager.sendLightOnOff($0) },
                    onIntensityChange: { bluetoothManager.sendLightIntensity($0) },
                    onDurationChange: { bluetoothManager.sendLightDuration($0) }
                )
                
                ModeControlView(
                    title: "Sound",
                    enabled: $soundEnabled,
                    intensity: $soundIntensity,
                    duration: $soundDuration,
                    intensityRange: 5...250,
                    durationRange: 1...4,
                    onToggle: { bluetoothManager.sendSoundOnOff($0) },
                    onIntensityChange: { bluetoothManager.sendSoundIntensity($0) },
                    onDurationChange: { bluetoothManager.sendSoundDuration($0) }
                )
                
                ModeControlView(
                    title: "Pressure",
                    enabled: $pressureEnabled,
                    intensity: $pressureIntensity,
                    duration: $pressureDuration,
                    intensityRange: 1...4,
                    durationRange: 1...4,
                    onToggle: { bluetoothManager.sendPressureOnOff($0) },
                    onIntensityChange: { bluetoothManager.sendPressureIntensity($0) },
                    onDurationChange: { bluetoothManager.sendPressureDuration($0) }
                )
            }
            .padding()
        }
    }
} 