//
//  ContentView.swift
//  EMDRAppleTest1.1
//
//  Created by Stefan Nagler on 26/11/2024.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var speed: Int = 75
    @State private var isRunning: Bool = false
    @State private var showSettings: Bool = false
    
    // Control mode states
    @State private var buzzEnabled: Bool = false
    @State private var buzzIntensity: Int = 25
    @State private var buzzDuration: Int = 3
    
    @State private var lightEnabled: Bool = false
    @State private var lightIntensity: Int = 100
    @State private var lightDuration: Int = 3
    
    @State private var soundEnabled: Bool = false
    @State private var soundIntensity: Int = 50
    @State private var soundDuration: Int = 3
    
    @State private var pressureEnabled: Bool = false
    @State private var pressureIntensity: Int = 2
    @State private var pressureDuration: Int = 2
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    StatusBarView(bluetoothManager: bluetoothManager)
                    
                    CircleVisualizationView()
                        .environmentObject(bluetoothManager)
                    
                    SpeedControlView(
                        speed: $speed,
                        onSpeedChange: { [weak bluetoothManager] newSpeed in
                            bluetoothManager?.sendSpeed(Double(newSpeed))
                        }
                    )
                    
                    // Mode Controls
                    VStack(spacing: 15) {
                        ModeControlView(
                            title: "Buzz",
                            enabled: $buzzEnabled,
                            intensity: $buzzIntensity,
                            duration: $buzzDuration,
                            intensityRange: 5...250,
                            durationRange: 1...4,
                            onToggle: { isOn in
                                self.bluetoothManager.sendTapperOnOff(isOn)
                            },
                            onIntensityChange: { intensity in
                                self.bluetoothManager.sendHapticIntensity(intensity)
                            },
                            onDurationChange: { duration in
                                self.bluetoothManager.sendBuzzDuration(duration)
                            }
                        )
                        
                        ModeControlView(
                            title: "Light",
                            enabled: $lightEnabled,
                            intensity: $lightIntensity,
                            duration: $lightDuration,
                            intensityRange: 5...250,
                            durationRange: 1...4,
                            onToggle: { isOn in
                                self.bluetoothManager.sendLightOnOff(isOn)
                            },
                            onIntensityChange: { intensity in
                                self.bluetoothManager.sendLightIntensity(intensity)
                            },
                            onDurationChange: { duration in
                                self.bluetoothManager.sendLightDuration(duration)
                            }
                        )
                        
                        ModeControlView(
                            title: "Sound",
                            enabled: $soundEnabled,
                            intensity: $soundIntensity,
                            duration: $soundDuration,
                            intensityRange: 5...250,
                            durationRange: 1...4,
                            onToggle: { isOn in
                                self.bluetoothManager.sendSoundOnOff(isOn)
                            },
                            onIntensityChange: { intensity in
                                self.bluetoothManager.sendSoundIntensity(intensity)
                            },
                            onDurationChange: { duration in
                                self.bluetoothManager.sendSoundDuration(duration)
                            }
                        )
                        
                        ModeControlView(
                            title: "Pressure",
                            enabled: $pressureEnabled,
                            intensity: $pressureIntensity,
                            duration: $pressureDuration,
                            intensityRange: 1...4,
                            durationRange: 1...4,
                            onToggle: { isOn in
                                bluetoothManager.handlePressureMode(
                                    enabled: isOn,
                                    buzzEnabled: &buzzEnabled,
                                    lightEnabled: &lightEnabled,
                                    soundEnabled: &soundEnabled
                                )
                            },
                            onIntensityChange: { intensity in
                                bluetoothManager.sendPressureIntensity(intensity)
                            },
                            onDurationChange: { duration in
                                bluetoothManager.sendPressureDuration(duration)
                            }
                        )
                    }
                    .padding()
                    
                    StartStopButtonView(
                        isRunning: $isRunning,
                        bluetoothManager: bluetoothManager,
                        speed: $speed
                    )
                    
                    Button(action: {
                        // Set local state
                        isRunning = true
                        buzzEnabled = true
                        lightEnabled = true
                        soundEnabled = true
                        pressureEnabled = false
                        
                        // Set intensities
                        buzzIntensity = 127
                        lightIntensity = 127
                        soundIntensity = 127
                        pressureIntensity = 2
                        
                        // Set durations
                        buzzDuration = 2
                        lightDuration = 2
                        soundDuration = 2
                        pressureDuration = 2
                        
                        // Send all values via BLE
                        bluetoothManager.sendDebugTestValues()
                    }) {
                        Text("Debug Test")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 30)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationBarTitle("EMDR Controller", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            )
        }
        .navigationViewStyle(.stack)
        .alert("Bluetooth Required", isPresented: .constant(bluetoothManager.bluetoothState != .poweredOn)) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable Bluetooth to use this app")
        }
        .alert("Low Battery Warning", isPresented: $bluetoothManager.showLowBatteryAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(bluetoothManager.lowBatteryDevice) device battery is below 10%. Please charge soon.")
        }
        .onAppear {
            let settings = bluetoothManager.loadSettings()
            if settings.speed > 0 {
                speed = settings.speed
                buzzIntensity = settings.buzzIntensity
                lightIntensity = settings.lightIntensity
                soundIntensity = settings.soundIntensity
                pressureIntensity = settings.pressureIntensity
            }
            
            // Send initial state
            bluetoothManager.sendInitialState(
                speed: speed,
                buzzEnabled: buzzEnabled,
                lightEnabled: lightEnabled,
                soundEnabled: soundEnabled,
                pressureEnabled: pressureEnabled,
                buzzIntensity: buzzIntensity,
                lightIntensity: lightIntensity,
                soundIntensity: soundIntensity,
                pressureIntensity: pressureIntensity
            )
        }
        .onChange(of: speed) { _ in
            bluetoothManager.saveSettings(
                speed: speed,
                buzzIntensity: buzzIntensity,
                lightIntensity: lightIntensity,
                soundIntensity: soundIntensity,
                pressureIntensity: pressureIntensity
            )
        }
        .onChange(of: lightIntensity) { _ in
            bluetoothManager.storeCurrentUIState(
                buzzEnabled: buzzEnabled,
                lightEnabled: lightEnabled,
                soundEnabled: soundEnabled,
                pressureEnabled: pressureEnabled,
                buzzIntensity: buzzIntensity,
                lightIntensity: lightIntensity,
                soundIntensity: soundIntensity,
                pressureIntensity: pressureIntensity,
                buzzDuration: buzzDuration,
                lightDuration: lightDuration,
                soundDuration: soundDuration,
                pressureDuration: pressureDuration,
                speed: speed
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            ContentView()
                .previewDevice("iPhone 13")
        } else {
            ContentView()
        }
    }
}
