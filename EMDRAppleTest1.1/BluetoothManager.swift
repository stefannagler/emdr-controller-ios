import CoreBluetooth
import UIKit

extension Notification.Name {
    static let batteryLevelUpdated = Notification.Name("batteryLevelUpdated")
}

class BluetoothManager: NSObject, ObservableObject {
    private var peripheralManager: CBPeripheralManager!
    private var characteristics: [String: CBMutableCharacteristic] = [:]
    private var connectedCentrals: Set<CBCentral> = []
    private var currentValues: [String: UInt8] = [:]
    
    @Published var isAdvertising = false
    @Published var battery1Level: Int = 0
    @Published var battery2Level: Int = 0
    @Published var connectedDeviceCount: Int = 0
    @Published var currentSide: Bool = false // false = left, true = right
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var showBluetoothAlert: Bool = false
    @Published var showLowBatteryAlert: Bool = false
    @Published var lowBatteryDevice: String = ""
    
    // Service UUID
    private let serviceUUID = CBUUID(string: "e3223000-9445-4e96-a4a1-85358c4046a2")
    
    // All Characteristic UUIDs
    private let speedCharacteristicUUID = CBUUID(string: "e3223006-246e-459b-ae10-5dbea099f9f0")
    private let onOffCharacteristicUUID = CBUUID(string: "e3223007-246e-459b-ae10-5dbea099f9f0")
    private let startStopFlagCharacteristicUUID = CBUUID(string: "e3223025-246e-459b-ae10-5dbea099f9f0")
    private let tapperOnOffFlagUUID = CBUUID(string: "e3223026-246e-459b-ae10-5dbea099f9f0")
    private let tapperBuzzFlagUUID = CBUUID(string: "e3223027-246e-459b-ae10-5dbea099f9f0")
    private let tapperBuzzIntensityUUID = CBUUID(string: "e3223028-246e-459b-ae10-5dbea099f9f0")
    private let tapperBuzzOtherUUID = CBUUID(string: "e3223029-246e-459b-ae10-5dbea099f9f0")
    private let tapperLightFlagUUID = CBUUID(string: "e3223030-246e-459b-ae10-5dbea099f9f0")
    private let tapperLightIntensityUUID = CBUUID(string: "e3223031-246e-459b-ae10-5dbea099f9f0")
    private let tapperLightOtherUUID = CBUUID(string: "e3223032-246e-459b-ae10-5dbea099f9f0")
    private let tapperSoundFlagUUID = CBUUID(string: "e3223033-246e-459b-ae10-5dbea099f9f0")
    private let tapperSoundIntensityUUID = CBUUID(string: "e3223034-246e-459b-ae10-5dbea099f9f0")
    private let tapperSoundOtherUUID = CBUUID(string: "e3223035-246e-459b-ae10-5dbea099f9f0")
    private let tapperPressureFlagUUID = CBUUID(string: "e3223036-246e-459b-ae10-5dbea099f9f0")
    private let tapperPressureIntensityUUID = CBUUID(string: "e3223037-246e-459b-ae10-5dbea099f9f0")
    private let tapperPressureOtherUUID = CBUUID(string: "e3223038-246e-459b-ae10-5dbea099f9f0")
    private let stringLightFunctionUUID = CBUUID(string: "e3223039-246e-459b-ae10-5dbea099f9f0")
    private let sendToPhoneUUID = CBUUID(string: "e3223040-246e-459b-ae10-5dbea099f9f0")
    private let spare1UUID = CBUUID(string: "e3223041-246e-459b-ae10-5dbea099f9f0")
    private let vbat1PerChargeUUID = CBUUID(string: "e3223046-246e-459b-ae10-5dbea099f9f0")
    private let vbat2PerChargeUUID = CBUUID(string: "e3223047-246e-459b-ae10-5dbea099f9f0")
    
    // Add timer for speed-based updates
    private var speedTimer: Timer?
    
    // Add queue for BLE operations
    private let bleQueue = DispatchQueue(label: "com.emdr.blequeue", 
                                       qos: .userInteractive,  // Highest priority
                                       attributes: .concurrent)  // Allow concurrent execution
    private var autoReconnectTimer: Timer?
    
    // Add storage for previous states
    private var previousStates: [String: Bool] = [
        "buzzEnabled": false,
        "lightEnabled": false,
        "soundEnabled": false
    ]
    
    // Add background task ID
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskTimeout: TimeInterval = 25.0 // End task before 30s limit
    
    // Add heartbeat tracking
    @Published var leftCentralConnected = false
    @Published var rightCentralConnected = false
    
    private var lastLeftHeartbeat: Date?
    private var lastRightHeartbeat: Date?
    private let heartbeatTimeout: TimeInterval = 12.0 // Consider central disconnected after 12s without heartbeat
    
    // Add heartbeat timer
    private var heartbeatTimer: Timer?
    
    // Add warning states instead of connection states
    @Published var leftHeartbeatMissing = false
    @Published var rightHeartbeatMissing = false
    
    // Add MAC address tracking
    private var knownCentrals: [UUID: String] = [:] // Store central IDs and their roles
    
    // Add connection state tracking
    private struct CentralState {
        var isConnected: Bool
        var lastHeartbeat: Date?
        var role: String // "left" or "right"
    }
    private var centralStates: [UUID: CentralState] = [:]
    
    // Add these properties to BluetoothManager
    private var reconnectAttempts: [UUID: Int] = [:]
    private let maxReconnectAttempts = 3
    private let reconnectDelay: TimeInterval = 1.0
    
    override init() {
        super.init()
        setupHeartbeatMonitor()
        let options: [String: Any] = [
            CBPeripheralManagerOptionRestoreIdentifierKey: "EMDRControllerPeripheralManager",
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ]
        // Use high priority queue for BLE operations
        peripheralManager = CBPeripheralManager(delegate: self, 
                                              queue: bleQueue,
                                              options: options)
        setupAutoReconnect()
        registerBackgroundTask()
    }
    
    private func setupHeartbeatMonitor() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let now = Date()
            
            // Check left central
            if let lastLeft = self.lastLeftHeartbeat {
                let missing = now.timeIntervalSince(lastLeft) > self.heartbeatTimeout
                if missing != self.leftHeartbeatMissing {
                    DispatchQueue.main.async {
                        self.leftHeartbeatMissing = missing
                    }
                    if missing {
                        debugPrint("⚠️ Left heartbeat missing for >12s")
                    }
                }
            }
            
            // Check right central
            if let lastRight = self.lastRightHeartbeat {
                let missing = now.timeIntervalSince(lastRight) > self.heartbeatTimeout
                if missing != self.rightHeartbeatMissing {
                    DispatchQueue.main.async {
                        self.rightHeartbeatMissing = missing
                    }
                    if missing {
                        debugPrint("⚠️ Right heartbeat missing for >12s")
                    }
                }
            }
        }
    }
    
    // Add background task support
    private func registerBackgroundTask() {
        // End any existing task first
        endBackgroundTask()
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            debugPrint("Background task expiring...")
            self?.endBackgroundTask()
        }
        
        // Set timer to end task before system timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundTaskTimeout) { [weak self] in
            debugPrint("Ending background task after \(self?.backgroundTaskTimeout ?? 0)s")
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            debugPrint("Ending background task: \(backgroundTaskID)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func setupService() {
        // Remove any existing services first
        peripheralManager.removeAllServices()
        
        // Create the service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create characteristics array
        var characteristicsArray: [CBMutableCharacteristic] = []
        
        // Add characteristics in the same order as the ESP32
        let characteristicConfigs: [(String, CBUUID)] = [
            ("speed", speedCharacteristicUUID),
            ("onOff", onOffCharacteristicUUID),
            ("startStop", startStopFlagCharacteristicUUID),
            ("tapperOnOff", tapperOnOffFlagUUID),
            ("buzzFlag", tapperBuzzFlagUUID),
            ("buzzIntensity", tapperBuzzIntensityUUID),
            ("buzzOther", tapperBuzzOtherUUID),
            ("lightFlag", tapperLightFlagUUID),
            ("lightIntensity", tapperLightIntensityUUID),
            ("lightOther", tapperLightOtherUUID),
            ("soundFlag", tapperSoundFlagUUID),
            ("soundIntensity", tapperSoundIntensityUUID),
            ("soundOther", tapperSoundOtherUUID),
            ("pressureFlag", tapperPressureFlagUUID),
            ("pressureIntensity", tapperPressureIntensityUUID),
            ("pressureOther", tapperPressureOtherUUID),
            ("stringLightFunction", stringLightFunctionUUID),
            ("sendToPhone", sendToPhoneUUID),
            ("spare1", spare1UUID),
            ("vbat1PerCharge", vbat1PerChargeUUID),
            ("vbat2PerCharge", vbat2PerChargeUUID)
        ]
        
        for (key, uuid) in characteristicConfigs {
            let characteristic = CBMutableCharacteristic(
                type: uuid,
                properties: [.read, .write, .notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            characteristicsArray.append(characteristic)
            characteristics[key] = characteristic
        }
        
        // Add characteristics to service
        service.characteristics = characteristicsArray
        
        // Add service
        peripheralManager.add(service)
        debugPrint("Service setup with \(characteristicsArray.count) characteristics")
    }
    
    func startAdvertising() {
        // Make sure we're advertising with the correct name and service UUID
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "ESP32",  // Must match exactly
            CBAdvertisementDataIsConnectable: true
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        debugPrint("Started advertising as 'ESP32' with service UUID: \(serviceUUID)")
    }
    
    // Add this debug function
    private func debugCharacteristics() {
        debugPrint("=== Characteristics Debug ===")
        for (key, characteristic) in characteristics {
            debugPrint("\(key): \(characteristic.uuid)")
            if let value = currentValues[key] {
                debugPrint("  Current value: \(value)")
            }
        }
        debugPrint("=========================")
    }
    
    // Update sendStartAndTapperFlags with more debug info
    func sendStartAndTapperFlags(_ isStarted: Bool) {
        debugPrint("Sending Start/Stop and Tapper flags...")
        
        let value = UInt8(isStarted ? 1 : 0)
        let data = Data([value])
        
        // Store values
        updateCurrentValue(value, for: "startStop")
        updateCurrentValue(value, for: "tapperOnOff")
        
        // Send flags in sequence with delays
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Start/Stop flag
            if let startStopChar = self.characteristics["startStop"] {
                let startSuccess = self.peripheralManager.updateValue(data, for: startStopChar, onSubscribedCentrals: nil)
                debugPrint("1. Start/Stop flag sent: \(value) - \(startSuccess ? "✅" : "❌")")
                
                // 2. Tapper On/Off flag
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                    if let tapperOnOffChar = self.characteristics["tapperOnOff"] {
                        let tapperSuccess = self.peripheralManager.updateValue(data, for: tapperOnOffChar, onSubscribedCentrals: nil)
                        debugPrint("2. Tapper On/Off flag sent: \(value) - \(tapperSuccess ? "✅" : "❌")")
                        
                        // 3. If starting, ensure buzz flag is set
                        if isStarted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                                if let buzzFlagChar = self.characteristics["buzzFlag"] {
                                    let buzzSuccess = self.peripheralManager.updateValue(data, for: buzzFlagChar, onSubscribedCentrals: nil)
                                    debugPrint("3. Buzz flag set: \(value) - \(buzzSuccess ? "✅" : "❌")")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func sendHapticIntensity(_ intensity: Int) {
        guard let characteristic = characteristics["buzzIntensity"] else { return }
        let value = UInt8(min(255, max(0, intensity)))
        updateCurrentValue(value, for: "buzzIntensity")
        let data = Data([value])
        
        debugPrint("Haptic intensity: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Haptic intensity sent: \(success ? "✅" : "❌")")
    }
    
    func sendSelectLeftRight(_ isRight: Bool) {
        guard let characteristic = characteristics["sendToPhone"] else { return }
        let value = UInt8(isRight ? 1 : 0)
        let data = Data([value])
        
        debugPrint("Sending SelectLeftRight: \(isRight ? "Right" : "Left")")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Left/Right selection sent: \(success ? "✅" : "❌")")
    }
    
    func sendLightOnOff(_ isOn: Bool) {
        guard let characteristic = characteristics["lightFlag"] else { return }
        let value = UInt8(isOn ? 1 : 0)
        let data = Data([value])
        
        debugPrint("Light flag: \(isOn ? "ON" : "OFF")")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Light flag sent: \(success ? "✅" : "❌")")
    }
    
    func sendLightIntensity(_ intensity: Int) {
        guard let characteristic = characteristics["lightIntensity"] else { return }
        let value = UInt8(min(255, max(0, intensity)))
        updateCurrentValue(value, for: "lightIntensity")
        let data = Data([value])
        
        debugPrint("Light intensity: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Light intensity sent: \(success ? "✅" : "❌")")
    }
    
    func sendSoundOnOff(_ isOn: Bool) {
        guard let characteristic = characteristics["soundFlag"] else { return }
        let value = UInt8(isOn ? 1 : 0)
        let data = Data([value])
        
        debugPrint("Sound flag: \(isOn ? "ON" : "OFF")")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Sound flag sent: \(success ? "✅" : "")")
    }
    
    func sendSoundIntensity(_ intensity: Int) {
        guard let characteristic = characteristics["soundIntensity"] else { return }
        let value = UInt8(min(255, max(0, intensity)))
        let data = Data([value])
        
        debugPrint("Sound intensity: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Sound intensity sent: \(success ? "✅" : "❌")")
    }
    
    func sendPressureOnOff(_ isOn: Bool) {
        guard let characteristic = characteristics["pressureFlag"] else { return }
        let value = UInt8(isOn ? 1 : 0)
        let data = Data([value])
        
        debugPrint("Pressure flag: \(isOn ? "ON" : "OFF")")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Pressure flag sent: \(success ? "✅" : "❌")")
    }
    
    func sendPressureIntensity(_ intensity: Int) {
        guard let characteristic = characteristics["pressureIntensity"] else { return }
        let value = UInt8(min(255, max(0, intensity)))
        let data = Data([value])
        
        debugPrint("Pressure intensity: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Pressure intensity sent: \(success ? "✅" : "❌")")
    }
    
    func saveSettings(speed: Int, buzzIntensity: Int, lightIntensity: Int, soundIntensity: Int, pressureIntensity: Int) {
        let defaults = UserDefaults.standard
        defaults.set(speed, forKey: "speed")
        defaults.set(buzzIntensity, forKey: "buzzIntensity")
        defaults.set(lightIntensity, forKey: "lightIntensity")
        defaults.set(soundIntensity, forKey: "soundIntensity")
        defaults.set(pressureIntensity, forKey: "pressureIntensity")
        debugPrint("Settings saved")
    }
    
    func loadSettings() -> (speed: Int, buzzIntensity: Int, lightIntensity: Int, soundIntensity: Int, pressureIntensity: Int) {
        let defaults = UserDefaults.standard
        return (
            speed: defaults.integer(forKey: "speed"),
            buzzIntensity: defaults.integer(forKey: "buzzIntensity"),
            lightIntensity: defaults.integer(forKey: "lightIntensity"),
            soundIntensity: defaults.integer(forKey: "soundIntensity"),
            pressureIntensity: defaults.integer(forKey: "pressureIntensity")
        )
    }
    
    func sendBuzzDuration(_ duration: Int) {
        guard let characteristic = characteristics["buzzOther"] else { return }
        let value = UInt8(min(10, max(1, duration)))
        let data = Data([value])
        
        debugPrint("Buzz duration: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Buzz duration sent: \(success ? "✅" : "❌")")
    }
    
    func sendLightDuration(_ duration: Int) {
        guard let characteristic = characteristics["lightOther"] else { return }
        let value = UInt8(min(10, max(1, duration)))
        let data = Data([value])
        
        debugPrint("Light duration: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Light duration sent: \(success ? "✅" : "❌")")
    }
    
    func sendSoundDuration(_ duration: Int) {
        guard let characteristic = characteristics["soundOther"] else { return }
        let value = UInt8(min(10, max(1, duration)))
        let data = Data([value])
        
        debugPrint("Sound duration: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Sound duration sent: \(success ? "✅" : "❌")")
    }
    
    func sendPressureDuration(_ duration: Int) {
        guard let characteristic = characteristics["pressureOther"] else { return }
        let value = UInt8(min(10, max(1, duration)))
        let data = Data([value])
        
        debugPrint("Pressure duration: \(value)")
        
        let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        debugPrint("Pressure duration sent: \(success ? "✅" : "❌")")
    }
    
    private func characteristicKeyForUUID(_ uuid: CBUUID) -> String {
        switch uuid.uuidString {
        case "E3223006-246E-459B-AE10-5DBEA099F9F0": return "speed"
        case "E3223007-246E-459B-AE10-5DBEA099F9F0": return "onOff"
        case "E3223025-246E-459B-AE10-5DBEA099F9F0": return "startStop"
        case "E3223026-246E-459B-AE10-5DBEA099F9F0": return "tapperOnOff"
        case "E3223027-246E-459B-AE10-5DBEA099F9F0": return "buzzFlag"
        case "E3223028-246E-459B-AE10-5DBEA099F9F0": return "buzzIntensity"
        case "E3223029-246E-459B-AE10-5DBEA099F9F0": return "buzzOther"
        case "E3223030-246E-459B-AE10-5DBEA099F9F0": return "lightFlag"
        case "E3223031-246E-459B-AE10-5DBEA099F9F0": return "lightIntensity"
        case "E3223032-246E-459B-AE10-5DBEA099F9F0": return "lightOther"
        case "E3223033-246E-459B-AE10-5DBEA099F9F0": return "soundFlag"
        case "E3223034-246E-459B-AE10-5DBEA099F9F0": return "soundIntensity"
        case "E3223035-246E-459B-AE10-5DBEA099F9F0": return "soundOther"
        case "E3223036-246E-459B-AE10-5DBEA099F9F0": return "pressureFlag"
        case "E3223037-246E-459B-AE10-5DBEA099F9F0": return "pressureIntensity"
        case "E3223038-246E-459B-AE10-5DBEA099F9F0": return "pressureOther"
        case "E3223039-246E-459B-AE10-5DBEA099F9F0": return "stringLightFunction"
        case "E3223040-246E-459B-AE10-5DBEA099F9F0": return "sendToPhone"
        case "E3223041-246E-459B-AE10-5DBEA099F9F0": return "spare1"
        case "E3223046-246E-459B-AE10-5DBEA099F9F0": return "vbat1PerCharge"
        case "E3223047-246E-459B-AE10-5DBEA099F9F0": return "vbat2PerCharge"
        default: return "unknown"
        }
    }
    
    // Update send functions to use high priority dispatch
    public func sendSpeed(_ speed: Double) {
        bleQueue.async(qos: .userInteractive) { [weak self] in
            guard let self = self else { return }
            
            // Send speed value
            guard let characteristic = self.characteristics["speed"] else { return }
            let value = UInt8(max(0, min(50, Int(speed))))
            let data = Data([value])
            
            let success = self.peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
            bleDebug("Speed set to \(value)", success: success)
            
            // Update timer and UI properties on main queue
            DispatchQueue.main.async {
                // Calculate interval exactly as ESP32 does
                let interval = Double(1200 - Int(speed) * 1000 / 50) / 1000.0
                
                self.speedTimer?.invalidate()
                self.speedTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    
                    self.bleQueue.async {
                        // Toggle side and send on background queue
                        DispatchQueue.main.async {
                            self.currentSide.toggle() // Update @Published property on main thread
                        }
                        
                        if let selectLeftRightChar = self.characteristics["sendToPhone"] {
                            let data = Data([UInt8(self.currentSide ? 1 : 0)])
                            let success = self.peripheralManager.updateValue(data, for: selectLeftRightChar, onSubscribedCentrals: nil)
                            if !success {
                                // Retry on failure
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                                    _ = self.peripheralManager.updateValue(data, for: selectLeftRightChar, onSubscribedCentrals: nil)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func sendTapperOnOff(_ isOn: Bool) {
        // Send Buzz Flag
        if let buzzFlagChar = characteristics["buzzFlag"] {
            let value = UInt8(isOn ? 1 : 0)
            let data = Data([value])
            let success = peripheralManager.updateValue(data, for: buzzFlagChar, onSubscribedCentrals: nil)
            debugPrint("Buzz flag sent: \(value) - \(success ? "✅" : "❌")")
        }
    }
    
    private func checkBatteryLevel(_ level: Int, device: String) {
        if level <= 10 {
            updateOnMain {
                self.lowBatteryDevice = device
                self.showLowBatteryAlert = true
            }
        }
    }
    
    private func sendWithRetry(data: Data, 
                             characteristic: CBMutableCharacteristic, 
                             description: String, 
                             retryCount: Int = 3,
                             targetCentral: CBCentral? = nil) {
        func attempt(remainingAttempts: Int) {
            let success = peripheralManager.updateValue(data, 
                                                      for: characteristic, 
                                                      onSubscribedCentrals: targetCentral != nil ? [targetCentral!] : nil)
            
            if !success && remainingAttempts > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                    attempt(remainingAttempts: remainingAttempts - 1)
                }
            }
        }
        attempt(remainingAttempts: retryCount)
    }
    
    func sendDebugTestValues() {
        debugPrint("=== Debug Test Button Pressed ===")
        debugPrint("Current stored values before debug test:")
        for (key, value) in currentValues {
            debugPrint("  \(key): \(value)")
        }
        
        // Store the values we're about to send
        updateCurrentValue(1, for: "startStop")
        updateCurrentValue(1, for: "tapperOnOff")
        updateCurrentValue(1, for: "buzzFlag")
        updateCurrentValue(127, for: "buzzIntensity")
        updateCurrentValue(2, for: "buzzOther")
        updateCurrentValue(1, for: "lightFlag")
        updateCurrentValue(127, for: "lightIntensity")
        updateCurrentValue(2, for: "lightOther")
        updateCurrentValue(1, for: "soundFlag")
        updateCurrentValue(127, for: "soundIntensity")
        updateCurrentValue(2, for: "soundOther")
        updateCurrentValue(0, for: "pressureFlag") // Keep pressure disabled
        updateCurrentValue(2, for: "pressureIntensity")
        updateCurrentValue(2, for: "pressureOther")
        updateCurrentValue(25, for: "speed")
        
        debugPrint("Sending debug test values...")
        
        // Send all values in sequence with pressure disabled
        sendAllValues(
            startStop: true,
            buzzEnabled: true,
            lightEnabled: true,
            soundEnabled: true,
            pressureEnabled: false,
            buzzIntensity: 127,
            lightIntensity: 127,
            soundIntensity: 127,
            pressureIntensity: 2,
            buzzDuration: 2,
            lightDuration: 2,
            soundDuration: 2,
            pressureDuration: 2,
            speed: 25,
            reason: "Debug Test Button"
        )
        
        debugPrint("=== Debug Test Complete ===")
    }
    
    // Add this function to resend all current settings
    func resendAllSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Send flags first with small delays between
            if let startStopChar = self.characteristics["startStop"] {
                let startStopData = Data([self.currentValues["startStop"] ?? 0])
                self.sendWithRetry(data: startStopData, characteristic: startStopChar, description: "Reconnect - Start/Stop flag")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                    if let tapperOnOffChar = self.characteristics["tapperOnOff"] {
                        let tapperData = Data([self.currentValues["tapperOnOff"] ?? 0])
                        self.sendWithRetry(data: tapperData, characteristic: tapperOnOffChar, description: "Reconnect - Tapper On/Off")
                        
                        // Send mode flags and values
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                            // Buzz settings
                            if let buzzFlagChar = self.characteristics["buzzFlag"] {
                                let buzzData = Data([self.currentValues["buzzFlag"] ?? 0])
                                self.sendWithRetry(data: buzzData, characteristic: buzzFlagChar, description: "Reconnect - Buzz flag")
                            }
                            if let buzzIntensityChar = self.characteristics["buzzIntensity"] {
                                let intensityData = Data([self.currentValues["buzzIntensity"] ?? 127])
                                self.sendWithRetry(data: intensityData, characteristic: buzzIntensityChar, description: "Reconnect - Buzz intensity")
                            }
                            
                            // Light settings
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                                if let lightFlagChar = self.characteristics["lightFlag"] {
                                    let lightData = Data([self.currentValues["lightFlag"] ?? 0])
                                    self.sendWithRetry(data: lightData, characteristic: lightFlagChar, description: "Reconnect - Light flag")
                                }
                                if let lightIntensityChar = self.characteristics["lightIntensity"] {
                                    let intensityData = Data([self.currentValues["lightIntensity"] ?? 127])
                                    self.sendWithRetry(data: intensityData, characteristic: lightIntensityChar, description: "Reconnect - Light intensity")
                                }
                                
                                // Sound settings
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                                    // ... similar pattern for sound settings
                                    
                                    // Finally, speed and current side
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                                        if let speedChar = self.characteristics["speed"] {
                                            let speedData = Data([self.currentValues["speed"] ?? 25])
                                            self.sendWithRetry(data: speedData, characteristic: speedChar, description: "Reconnect - Speed")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Add this function to send all current values
    func sendAllCurrentValues(startStop: Bool = true, 
                            buzzEnabled: Bool = true,
                            lightEnabled: Bool = true,
                            soundEnabled: Bool = true,
                            pressureEnabled: Bool = false,
                            buzzIntensity: Int = 127,
                            lightIntensity: Int = 127,
                            soundIntensity: Int = 127,
                            pressureIntensity: Int = 2,
                            buzzDuration: Int = 2,
                            lightDuration: Int = 2,
                            soundDuration: Int = 2,
                            pressureDuration: Int = 2,
                            speed: Int = 25) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Helper function for sending with delay
            func sendWithDelay(_ block: @escaping () -> Void, delay: Double = 0.01) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
            }
            
            // Send flags first
            if let startStopChar = self.characteristics["startStop"] {
                self.sendWithRetry(data: Data([UInt8(startStop ? 1 : 0)]), 
                                 characteristic: startStopChar, 
                                 description: "Start/Stop flag")
            }
            
            // Send other values with delays
            sendWithDelay {
                if let tapperOnOffChar = self.characteristics["tapperOnOff"] {
                    self.sendWithRetry(data: Data([UInt8(startStop ? 1 : 0)]), 
                                     characteristic: tapperOnOffChar, 
                                     description: "Tapper On/Off")
                }
                
                // Send mode flags and values
                sendWithDelay {
                    // Buzz settings
                    if let buzzFlagChar = self.characteristics["buzzFlag"] {
                        self.sendWithRetry(data: Data([UInt8(buzzEnabled ? 1 : 0)]), 
                                         characteristic: buzzFlagChar, 
                                         description: "Buzz flag")
                    }
                    if let buzzIntensityChar = self.characteristics["buzzIntensity"] {
                        self.sendWithRetry(data: Data([UInt8(buzzIntensity)]), 
                                         characteristic: buzzIntensityChar, 
                                         description: "Buzz intensity")
                    }
                    
                    // Continue with other settings...
                    // Each with its own sendWithDelay block
                }
            }
        }
    }
    
    // Add this function to send all values in sequence
    func sendAllValues(
        startStop: Bool,
        buzzEnabled: Bool,
        lightEnabled: Bool,
        soundEnabled: Bool,
        pressureEnabled: Bool,
        buzzIntensity: Int,
        lightIntensity: Int,
        soundIntensity: Int,
        pressureIntensity: Int,
        buzzDuration: Int,
        lightDuration: Int,
        soundDuration: Int,
        pressureDuration: Int,
        speed: Int,
        reason: String = "Unknown",
        targetCentral: CBCentral? = nil
    ) {
        debugPrint("=== Sending All Values - Reason: \(reason) ===")
        if let central = targetCentral {
            debugPrint("Target Central: \(central.identifier)")
        }
        debugPrint("• Start/Stop: \(startStop)")
        debugPrint("• Buzz: enabled=\(buzzEnabled), intensity=\(buzzIntensity), duration=\(buzzDuration)")
        debugPrint("• Light: enabled=\(lightEnabled), intensity=\(lightIntensity), duration=\(lightDuration)")
        debugPrint("• Sound: enabled=\(soundEnabled), intensity=\(soundIntensity), duration=\(soundDuration)")
        debugPrint("• Pressure: enabled=\(pressureEnabled), intensity=\(pressureIntensity), duration=\(pressureDuration)")
        debugPrint("• Speed: \(speed)")
        
        func sendWithDelay(_ block: @escaping () -> Void, delay: Double = 0.01) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
        }
        
        // 1. Start/Stop and Tapper flags
        if let startStopChar = characteristics["startStop"] {
            sendWithRetry(data: Data([UInt8(startStop ? 1 : 0)]), 
                         characteristic: startStopChar, 
                         description: "Start/Stop flag",
                         targetCentral: targetCentral)
        }
        
        sendWithDelay {
            if let tapperOnOffChar = self.characteristics["tapperOnOff"] {
                self.sendWithRetry(data: Data([UInt8(startStop ? 1 : 0)]), 
                                 characteristic: tapperOnOffChar, 
                                 description: "Tapper On/Off",
                                 targetCentral: targetCentral)
            }
            
            // 2. Buzz settings
            sendWithDelay {
                if let buzzFlagChar = self.characteristics["buzzFlag"] {
                    self.sendWithRetry(data: Data([UInt8(buzzEnabled ? 1 : 0)]), 
                                     characteristic: buzzFlagChar, 
                                     description: "Buzz flag",
                                     targetCentral: targetCentral)
                }
                
                sendWithDelay {
                    if let buzzIntensityChar = self.characteristics["buzzIntensity"] {
                        self.sendWithRetry(data: Data([UInt8(buzzIntensity)]), 
                                                 characteristic: buzzIntensityChar, 
                                                 description: "Buzz intensity",
                                                 targetCentral: targetCentral)
                    }
                    
                    sendWithDelay {
                        if let buzzOtherChar = self.characteristics["buzzOther"] {
                            self.sendWithRetry(data: Data([UInt8(buzzDuration)]), 
                                             characteristic: buzzOtherChar, 
                                             description: "Buzz duration",
                                             targetCentral: targetCentral)
                        }
                        
                        // 3. Light settings
                        sendWithDelay {
                            if let lightFlagChar = self.characteristics["lightFlag"] {
                                self.sendWithRetry(data: Data([UInt8(lightEnabled ? 1 : 0)]), 
                                                 characteristic: lightFlagChar, 
                                                 description: "Light flag",
                                                 targetCentral: targetCentral)
                            }
                            
                            sendWithDelay {
                                if let lightIntensityChar = self.characteristics["lightIntensity"] {
                                    self.sendWithRetry(data: Data([UInt8(lightIntensity)]), 
                                                     characteristic: lightIntensityChar, 
                                                     description: "Light intensity",
                                                     targetCentral: targetCentral)
                                }
                                
                                sendWithDelay {
                                    if let lightOtherChar = self.characteristics["lightOther"] {
                                        self.sendWithRetry(data: Data([UInt8(lightDuration)]), 
                                                         characteristic: lightOtherChar, 
                                                         description: "Light duration",
                                                         targetCentral: targetCentral)
                                    }
                                    
                                    // 4. Sound settings
                                    sendWithDelay {
                                        if let soundFlagChar = self.characteristics["soundFlag"] {
                                            self.sendWithRetry(data: Data([UInt8(soundEnabled ? 1 : 0)]), 
                                                             characteristic: soundFlagChar, 
                                                             description: "Sound flag",
                                                             targetCentral: targetCentral)
                                        }
                                        
                                        sendWithDelay {
                                            if let soundIntensityChar = self.characteristics["soundIntensity"] {
                                                self.sendWithRetry(data: Data([UInt8(soundIntensity)]), 
                                                                 characteristic: soundIntensityChar, 
                                                                 description: "Sound intensity",
                                                                 targetCentral: targetCentral)
                                            }
                                            
                                            sendWithDelay {
                                                if let soundOtherChar = self.characteristics["soundOther"] {
                                                    self.sendWithRetry(data: Data([UInt8(soundDuration)]), 
                                                                     characteristic: soundOtherChar, 
                                                                     description: "Sound duration",
                                                                     targetCentral: targetCentral)
                                                }
                                                
                                                // 5. Pressure settings
                                                sendWithDelay {
                                                    if let pressureFlagChar = self.characteristics["pressureFlag"] {
                                                        self.sendWithRetry(data: Data([UInt8(pressureEnabled ? 1 : 0)]), 
                                                                         characteristic: pressureFlagChar, 
                                                                         description: "Pressure flag",
                                                                         targetCentral: targetCentral)
                                                    }
                                                    
                                                    sendWithDelay {
                                                        if let pressureIntensityChar = self.characteristics["pressureIntensity"] {
                                                            self.sendWithRetry(data: Data([UInt8(pressureIntensity)]), 
                                                                             characteristic: pressureIntensityChar, 
                                                                             description: "Pressure intensity",
                                                                             targetCentral: targetCentral)
                                                        }
                                                        
                                                        sendWithDelay {
                                                            if let pressureOtherChar = self.characteristics["pressureOther"] {
                                                                self.sendWithRetry(data: Data([UInt8(pressureDuration)]), 
                                                                                 characteristic: pressureOtherChar, 
                                                                                 description: "Pressure duration",
                                                                                 targetCentral: targetCentral)
                                                            }
                                                            
                                                            // 6. Finally, speed
                                                            sendWithDelay {
                                                                if let speedChar = self.characteristics["speed"] {
                                                                    self.sendWithRetry(data: Data([UInt8(speed)]), 
                                                                                     characteristic: speedChar, 
                                                                                     description: "Speed",
                                                                                     targetCentral: targetCentral)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Add function to store current values
    private func updateCurrentValue(_ value: UInt8, for key: String) {
        currentValues[key] = value
        debugPrint("Stored \(key): \(value)")
    }
    
    // Add reconnect function
    private func setupAutoReconnect() {
        autoReconnectTimer?.invalidate()
        autoReconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if !self.isAdvertising && self.bluetoothState == .poweredOn {
                debugPrint("Auto-reconnecting BLE...")
                self.bleQueue.async {
                    self.startAdvertising()
                }
            }
        }
    }
    
    // Add this helper function to ensure main thread updates
    private func updateOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    // Update debug prints
    private func bleDebug(_ message: String, success: Bool? = nil) {
        if let success = success {
            print("📱 BLE: \(message) - \(success ? "✅" : "❌")")
        } else {
            print("📱 BLE: \(message)")
        }
    }
    
    // Add function to handle pressure mode
    func handlePressureMode(enabled: Bool, 
                           buzzEnabled: inout Bool, 
                           lightEnabled: inout Bool, 
                           soundEnabled: inout Bool) {
        if enabled {
            // Store current states
            previousStates["buzzEnabled"] = buzzEnabled
            previousStates["lightEnabled"] = lightEnabled
            previousStates["soundEnabled"] = soundEnabled
            
            // Turn off other modes
            buzzEnabled = false
            lightEnabled = false
            soundEnabled = false
            
            // Send BLE updates with retry
            func sendWithRetryAndDelay(_ block: @escaping () -> Void, description: String, delay: Double = 0.003) {
                func attempt(remainingAttempts: Int) {
                    var success = false
                    
                    if let characteristic = self.characteristics[description] {
                        let data = Data([UInt8(0)]) // Turn off
                        success = self.peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
                    }
                    
                    debugPrint("\(description): \(success ? "✅" : "❌")")
                    
                    if !success && remainingAttempts > 0 {
                        debugPrint("⚠️ Retrying \(description) - Attempts left: \(remainingAttempts)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt(remainingAttempts: remainingAttempts - 1)
                        }
                    }
                }
                attempt(remainingAttempts: 3)
            }
            
            // Send each flag with retry
            sendWithRetryAndDelay({ self.sendTapperOnOff(false) }, description: "buzzFlag")
            sendWithRetryAndDelay({ self.sendLightOnOff(false) }, description: "lightFlag")
            sendWithRetryAndDelay({ self.sendSoundOnOff(false) }, description: "soundFlag")
            sendWithRetryAndDelay({ 
                if let pressureFlagChar = self.characteristics["pressureFlag"] {
                    let data = Data([UInt8(1)]) // Turn on pressure
                    _ = self.peripheralManager.updateValue(data, for: pressureFlagChar, onSubscribedCentrals: nil)
                }
            }, description: "pressureFlag")
            
            debugPrint("🔄 Pressure mode ON - stored previous states")
        } else {
            // Restore previous states
            buzzEnabled = previousStates["buzzEnabled"] ?? false
            lightEnabled = previousStates["lightEnabled"] ?? false
            soundEnabled = previousStates["soundEnabled"] ?? false
            
            // Send BLE updates
            if let pressureFlagChar = characteristics["pressureFlag"] {
                let data = Data([UInt8(0)]) // Turn off pressure
                _ = peripheralManager.updateValue(data, for: pressureFlagChar, onSubscribedCentrals: nil)
            }
            
            // Restore other modes if they were on
            if buzzEnabled {
                sendTapperOnOff(true)
            }
            if lightEnabled {
                sendLightOnOff(true)
            }
            if soundEnabled {
                sendSoundOnOff(true)
            }
            
            debugPrint("🔄 Pressure mode OFF - restored previous states")
        }
    }
    
    // Fix initial state by sending values in onAppear
    func sendInitialState(speed: Int,
                         buzzEnabled: Bool,
                         lightEnabled: Bool,
                         soundEnabled: Bool,
                         pressureEnabled: Bool,
                         buzzIntensity: Int,
                         lightIntensity: Int,
                         soundIntensity: Int,
                         pressureIntensity: Int) {
        // Send all current values
        sendAllValues(
            startStop: false, // Start in stopped state
            buzzEnabled: buzzEnabled,
            lightEnabled: lightEnabled,
            soundEnabled: soundEnabled,
            pressureEnabled: pressureEnabled,
            buzzIntensity: buzzIntensity,
            lightIntensity: lightIntensity,
            soundIntensity: soundIntensity,
            pressureIntensity: pressureIntensity,
            buzzDuration: 2,
            lightDuration: 2,
            soundDuration: 2,
            pressureDuration: 2,
            speed: speed,
            reason: "App Initial State"
        )
    }
    
    // Add function to handle UI interruptions
    private func handleUIInterruption() {
        registerBackgroundTask()
        
        // Re-register more frequently
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) { [weak self] in
            self?.endBackgroundTask()
            self?.registerBackgroundTask()
        }
    }
    
    // Add this function to handle reconnection attempts
    private func handleReconnection(for central: CBCentral) {
        guard let state = centralStates[central.identifier] else { return }
        
        // Increment reconnect attempts
        reconnectAttempts[central.identifier, default: 0] += 1
        
        if reconnectAttempts[central.identifier, default: 0] <= maxReconnectAttempts {
            debugPrint("📱 Attempting reconnect for \(state.role) central - Attempt \(reconnectAttempts[central.identifier, default: 0])/\(maxReconnectAttempts)")
            
            // Resend current state with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
                guard let self = self else { return }
                self.resendCurrentState(to: central)
            }
        } else {
            debugPrint("❌ Max reconnect attempts reached for \(state.role) central")
            reconnectAttempts[central.identifier] = 0
        }
    }
    
    // Update peripheralManager(_:central:didSubscribeTo:) to include reconnection handling
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        updateOnMain {
            if let role = self.knownCentrals[central.identifier] {
                debugPrint("📱 Reconnected known central (\(role)): \(central.identifier)")
                
                // Reset reconnect attempts on successful connection
                self.reconnectAttempts[central.identifier] = 0
                
                // Update state
                self.centralStates[central.identifier] = CentralState(
                    isConnected: true,
                    lastHeartbeat: Date(),
                    role: role
                )
                
                // Resend current state with delay to ensure central is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.resendCurrentState(to: central)
                }
            } else {
                debugPrint("📱 New central connected: \(central.identifier)")
            }
            
            self.connectedCentrals.insert(central)
            self.connectedDeviceCount = self.connectedCentrals.count
        }
    }
    
    // Add function to store all current UI values
    func storeCurrentUIState(
        buzzEnabled: Bool,
        lightEnabled: Bool,
        soundEnabled: Bool,
        pressureEnabled: Bool,
        buzzIntensity: Int,
        lightIntensity: Int,
        soundIntensity: Int,
        pressureIntensity: Int,
        buzzDuration: Int,
        lightDuration: Int,
        soundDuration: Int,
        pressureDuration: Int,
        speed: Int
    ) {
        // Store all current UI values
        updateCurrentValue(UInt8(buzzEnabled ? 1 : 0), for: "buzzFlag")
        updateCurrentValue(UInt8(lightEnabled ? 1 : 0), for: "lightFlag")
        updateCurrentValue(UInt8(soundEnabled ? 1 : 0), for: "soundFlag")
        updateCurrentValue(UInt8(pressureEnabled ? 1 : 0), for: "pressureFlag")
        
        updateCurrentValue(UInt8(buzzIntensity), for: "buzzIntensity")
        updateCurrentValue(UInt8(lightIntensity), for: "lightIntensity")
        updateCurrentValue(UInt8(soundIntensity), for: "soundIntensity")
        updateCurrentValue(UInt8(pressureIntensity), for: "pressureIntensity")
        
        updateCurrentValue(UInt8(buzzDuration), for: "buzzOther")
        updateCurrentValue(UInt8(lightDuration), for: "lightOther")
        updateCurrentValue(UInt8(soundDuration), for: "soundOther")
        updateCurrentValue(UInt8(pressureDuration), for: "pressureOther")
        
        updateCurrentValue(UInt8(speed), for: "speed")
        
        debugPrint("=== Stored Current UI State ===")
        debugPrint("Flags - Buzz: \(buzzEnabled), Light: \(lightEnabled), Sound: \(soundEnabled), Pressure: \(pressureEnabled)")
        debugPrint("Intensities - Buzz: \(buzzIntensity), Light: \(lightIntensity), Sound: \(soundIntensity), Pressure: \(pressureIntensity)")
    }
}

extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = peripheral.state
            self.isAdvertising = false
            self.showBluetoothAlert = peripheral.state != .poweredOn
        }
        
        debugPrint("Peripheral manager state updated: \(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .poweredOn:
            debugPrint("BLE powered ON - setting up service")
            setupService()
            debugPrint("Starting advertising")
            startAdvertising()
            DispatchQueue.main.async {
                self.isAdvertising = true
                self.showBluetoothAlert = false
            }
            
        case .poweredOff, .unauthorized, .unsupported:
            debugPrint("BLE state changed: \(peripheral.state)")
            DispatchQueue.main.async {
                self.isAdvertising = false
                self.showBluetoothAlert = true
            }
            
        default:
            debugPrint("BLE state: \(peripheral.state.rawValue)")
            DispatchQueue.main.async {
                self.isAdvertising = false
                self.showBluetoothAlert = true
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        updateOnMain {
            self.connectedCentrals.remove(central)
            self.connectedDeviceCount = self.connectedCentrals.count
        }
        debugPrint("Central disconnected: \(central.identifier)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value, let firstByte = value.first {
                let central = request.central
                if firstByte == 1 {
                    // Left central heartbeat
                    knownCentrals[central.identifier] = "left"
                    centralStates[central.identifier]?.lastHeartbeat = Date()
                    centralStates[central.identifier]?.role = "left"
                } else if firstByte == 2 {
                    // Right central heartbeat
                    knownCentrals[central.identifier] = "right"
                    centralStates[central.identifier]?.lastHeartbeat = Date()
                    centralStates[central.identifier]?.role = "right"
                }
                
                let characteristicKey = characteristicKeyForUUID(request.characteristic.uuid)
                debugPrint("📥 Received write for \(characteristicKey): \(Array(value))")
                
                switch request.characteristic.uuid {
                case spare1UUID:
                    // Update heartbeat timestamp without debug prints
                    if firstByte == 1 {
                        lastLeftHeartbeat = Date()
                        updateOnMain {
                            self.leftCentralConnected = true
                        }
                    } else if firstByte == 2 {
                        lastRightHeartbeat = Date()
                        updateOnMain {
                            self.rightCentralConnected = true
                        }
                    }
                    
                case vbat1PerChargeUUID:
                    updateOnMain {
                        self.battery1Level = Int(firstByte)
                        self.checkBatteryLevel(Int(firstByte), device: "Left")
                        NotificationCenter.default.post(
                            name: .batteryLevelUpdated,
                            object: nil,
                            userInfo: ["isLeft": true]
                        )
                    }
                    
                case vbat2PerChargeUUID:
                    updateOnMain {
                        self.battery2Level = Int(firstByte)
                        self.checkBatteryLevel(Int(firstByte), device: "Right")
                        NotificationCenter.default.post(
                            name: .batteryLevelUpdated,
                            object: nil,
                            userInfo: ["isLeft": false]
                        )
                    }
                    
                default:
                    break
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    // Add this method to handle state restoration
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        debugPrint("Restoring peripheral manager state")
        
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
            debugPrint("Restored \(services.count) services")
            for service in services {
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        if let mutableCharacteristic = characteristic as? CBMutableCharacteristic {
                            let key = characteristicKeyForUUID(mutableCharacteristic.uuid)
                            self.characteristics[key] = mutableCharacteristic
                        }
                    }
                }
            }
        }
    }
    
    // Add function to resend state to specific central
    private func resendCurrentState(to central: CBCentral) {
        // Send all current values but only to this central
        sendAllValues(
            startStop: currentValues["startStop"] == 1,
            buzzEnabled: currentValues["buzzFlag"] == 1,
            lightEnabled: currentValues["lightFlag"] == 1,
            soundEnabled: currentValues["soundFlag"] == 1,
            pressureEnabled: currentValues["pressureFlag"] == 1,
            buzzIntensity: Int(currentValues["buzzIntensity"] ?? 127),
            lightIntensity: Int(currentValues["lightIntensity"] ?? 127),
            soundIntensity: Int(currentValues["soundIntensity"] ?? 127),
            pressureIntensity: Int(currentValues["pressureIntensity"] ?? 2),
            buzzDuration: Int(currentValues["buzzOther"] ?? 2),
            lightDuration: Int(currentValues["lightOther"] ?? 2),
            soundDuration: Int(currentValues["soundOther"] ?? 2),
            pressureDuration: Int(currentValues["pressureOther"] ?? 2),
            speed: Int(currentValues["speed"] ?? 25),
            reason: "Reconnect: \(central.identifier)",
            targetCentral: central
        )
    }
} 