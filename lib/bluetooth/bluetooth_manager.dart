import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager extends ChangeNotifier {
  // Service UUID - same as iOS
  final serviceUUID = "e3223000-9445-4e96-a4a1-85358c4046a2";
  
  // Characteristic UUIDs
  final Map<String, String> characteristicUUIDs = {
    'speed': "e3223006-246e-459b-ae10-5dbea099f9f0",
    'startStop': "e3223025-246e-459b-ae10-5dbea099f9f0",
    'tapperOnOff': "e3223026-246e-459b-ae10-5dbea099f9f0",
    'buzzFlag': "e3223027-246e-459b-ae10-5dbea099f9f0",
    'buzzIntensity': "e3223028-246e-459b-ae10-5dbea099f9f0",
    'buzzOther': "e3223029-246e-459b-ae10-5dbea099f9f0",
    'lightFlag': "e3223030-246e-459b-ae10-5dbea099f9f0",
    'lightIntensity': "e3223031-246e-459b-ae10-5dbea099f9f0",
    'lightOther': "e3223032-246e-459b-ae10-5dbea099f9f0",
    'soundFlag': "e3223033-246e-459b-ae10-5dbea099f9f0",
    'soundIntensity': "e3223034-246e-459b-ae10-5dbea099f9f0",
    'soundOther': "e3223035-246e-459b-ae10-5dbea099f9f0",
    'pressureFlag': "e3223036-246e-459b-ae10-5dbea099f9f0",
    'pressureIntensity': "e3223037-246e-459b-ae10-5dbea099f9f0",
    'pressureOther': "e3223038-246e-459b-ae10-5dbea099f9f0",
    'spare1': "e3223041-246e-459b-ae10-5dbea099f9f0",
    'vbat1PerCharge': "e3223046-246e-459b-ae10-5dbea099f9f0",
    'vbat2PerCharge': "e3223047-246e-459b-ae10-5dbea099f9f0",
  };
  
  // State variables
  bool isAdvertising = false;
  int battery1Level = 0;
  int battery2Level = 0;
  int connectedDeviceCount = 0;
  bool currentSide = false; // false = left, true = right
  
  // Current values storage
  final Map<String, int> currentValues = {};
  
  // Connected devices
  final Map<String, BluetoothDevice> connectedDevices = {};
  
  // Heartbeat tracking
  DateTime? lastLeftHeartbeat;
  DateTime? lastRightHeartbeat;
  bool leftHeartbeatMissing = false;
  bool rightHeartbeatMissing = false;
  
  // Constructor
  BluetoothManager() {
    _initBluetooth();
    _setupHeartbeatMonitor();
    _monitorConnectionState();
  }
  
  Future<void> _initBluetooth() async {
    try {
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        withServices: [Guid(serviceUUID)],
      );
      
      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.name == "ESP32") {
            debugPrint('Found ESP32 device: ${r.device.id}');
            _connectToDevice(r.device);
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
    }
  }
  
  void _setupHeartbeatMonitor() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      
      // Check left heartbeat
      if (lastLeftHeartbeat != null) {
        final missing = now.difference(lastLeftHeartbeat!).inSeconds > 12;
        if (missing != leftHeartbeatMissing) {
          leftHeartbeatMissing = missing;
          if (missing) {
            debugPrint('⚠️ Left heartbeat missing for >12s');
          }
          notifyListeners();
        }
      }
      
      // Check right heartbeat
      if (lastRightHeartbeat != null) {
        final missing = now.difference(lastRightHeartbeat!).inSeconds > 12;
        if (missing != rightHeartbeatMissing) {
          rightHeartbeatMissing = missing;
          if (missing) {
            debugPrint('⚠️ Right heartbeat missing for >12s');
          }
          notifyListeners();
        }
      }
    });
  }
  
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      print('Connected to ${device.name}');
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUUID) {
          _handleService(service);
        }
      }
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }
  
  // Add more BLE functionality...
  
  // Add sending methods
  Future<void> sendSpeed(double speed) async {
    final value = min(50, max(0, speed.toInt()));
    final data = Uint8List.fromList([value]);
    
    try {
      await _sendCharacteristicValue('speed', data);
      debugPrint('Speed set to $value');
      
      // Update timer for side switching
      _updateSpeedTimer(value);
    } catch (e) {
      debugPrint('Error sending speed: $e');
    }
  }
  
  Future<void> sendStartAndTapperFlags(bool isStarted) async {
    final value = isStarted ? 1 : 0;
    final data = Uint8List.fromList([value]);
    
    debugPrint('=== ${isStarted ? "Starting" : "Stopping"} Sequence ===');
    
    try {
      // Send start/stop flag
      await _sendCharacteristicValue('startStop', data);
      await Future.delayed(const Duration(milliseconds: 3));
      
      // Send tapper flag
      await _sendCharacteristicValue('tapperOnOff', data);
      
      // If starting, ensure buzz flag is set
      if (isStarted) {
        await Future.delayed(const Duration(milliseconds: 3));
        await _sendCharacteristicValue('buzzFlag', data);
      }
    } catch (e) {
      debugPrint('Error sending flags: $e');
    }
  }
  
  Future<void> sendHapticIntensity(int intensity) async {
    final value = min(255, max(0, intensity));
    final data = Uint8List.fromList([value]);
    await _sendCharacteristicValue('buzzIntensity', data);
  }
  
  Future<void> sendLightIntensity(int intensity) async {
    final value = min(255, max(0, intensity));
    final data = Uint8List.fromList([value]);
    await _sendCharacteristicValue('lightIntensity', data);
  }
  
  Future<void> sendSoundIntensity(int intensity) async {
    final value = min(255, max(0, intensity));
    final data = Uint8List.fromList([value]);
    await _sendCharacteristicValue('soundIntensity', data);
  }
  
  // Helper method for sending characteristic values
  Future<void> _sendCharacteristicValue(String characteristicKey, Uint8List data) async {
    final uuid = characteristicUUIDs[characteristicKey];
    if (uuid == null) {
      throw Exception('Unknown characteristic key: $characteristicKey');
    }
    
    for (var device in connectedDevices.values) {
      try {
        final services = await device.discoverServices();
        for (var service in services) {
          if (service.uuid.toString() == serviceUUID) {
            for (var characteristic in service.characteristics) {
              if (characteristic.uuid.toString() == uuid) {
                await characteristic.write(data);
                debugPrint('Sent $characteristicKey: ${data.first}');
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error sending $characteristicKey: $e');
      }
    }
  }
  
  // Speed timer for side switching
  Timer? _speedTimer;
  
  void _updateSpeedTimer(int speed) {
    _speedTimer?.cancel();
    
    // Calculate interval as ESP32 does
    final interval = Duration(
      milliseconds: ((1200 - speed * 1000 ~/ 50))
    );
    
    _speedTimer = Timer.periodic(interval, (timer) {
      currentSide = !currentSide;
      notifyListeners();
      
      // Send side selection
      final data = Uint8List.fromList([currentSide ? 1 : 0]);
      _sendCharacteristicValue('sendToPhone', data);
    });
  }
  
  // Add these methods to the BluetoothManager class

  // Handle mode controls
  Future<void> sendTapperOnOff(bool isOn) async {
    final value = isOn ? 1 : 0;
    final data = Uint8List.fromList([value]);
    
    try {
      // Send buzz flag
      await _sendCharacteristicValue('buzzFlag', data);
      debugPrint('Buzz flag sent: ${isOn ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('Error sending tapper flag: $e');
    }
  }

  Future<void> sendLightOnOff(bool isOn) async {
    final value = isOn ? 1 : 0;
    final data = Uint8List.fromList([value]);
    await _sendCharacteristicValue('lightFlag', data);
  }

  Future<void> sendSoundOnOff(bool isOn) async {
    final value = isOn ? 1 : 0;
    final data = Uint8List.fromList([value]);
    await _sendCharacteristicValue('soundFlag', data);
  }

  Future<void> sendPressureOnOff(bool isOn) async {
    final value = isOn ? 1 : 0;
    final data = Uint8List.fromList([value]);
    await _sendCharacteristicValue('pressureFlag', data);
  }

  // Handle service discovery and setup
  Future<void> _handleService(BluetoothService service) async {
    debugPrint('Found matching service: ${service.uuid}');
    
    // Set up notifications for characteristics
    for (var characteristic in service.characteristics) {
      final charKey = _characteristicKeyForUUID(characteristic.uuid.toString());
      
      // Set up notifications for battery and heartbeat characteristics
      if (charKey == 'vbat1PerCharge' || 
          charKey == 'vbat2PerCharge' || 
          charKey == 'spare1') {
        await characteristic.setNotifyValue(true);
        characteristic.value.listen((value) {
          if (value.isNotEmpty) {
            _handleCharacteristicUpdate(charKey, value.first);
          }
        });
      }
    }
  }

  // Handle characteristic updates
  void _handleCharacteristicUpdate(String key, int value) {
    switch (key) {
      case 'vbat1PerCharge':
        battery1Level = value;
        _checkBatteryLevel(value, isLeft: true);
        break;
        
      case 'vbat2PerCharge':
        battery2Level = value;
        _checkBatteryLevel(value, isLeft: false);
        break;
        
      case 'spare1':
        if (value == 1) {
          lastLeftHeartbeat = DateTime.now();
          leftHeartbeatMissing = false;
        } else if (value == 2) {
          lastRightHeartbeat = DateTime.now();
          rightHeartbeatMissing = false;
        }
        break;
    }
    notifyListeners();
  }

  // Battery level monitoring
  void _checkBatteryLevel(int level, {required bool isLeft}) {
    if (level <= 10) {
      debugPrint('⚠️ Low battery warning: ${isLeft ? "Left" : "Right"} device at $level%');
    }
  }

  // Helper for UUID lookup
  String _characteristicKeyForUUID(String uuid) {
    for (var entry in characteristicUUIDs.entries) {
      if (entry.value.toLowerCase() == uuid.toLowerCase()) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  // Add debug test function
  Future<void> sendDebugTestValues() async {
    debugPrint('=== Debug Test Button Pressed ===');
    
    // Send test values
    await sendStartAndTapperFlags(true);
    await sendHapticIntensity(127);
    await sendLightIntensity(127);
    await sendSoundIntensity(127);
    await sendSpeed(25);
    
    debugPrint('=== Debug Test Complete ===');
  }
  
  // Handle reconnection
  Future<void> handleReconnection(BluetoothDevice device) async {
    try {
      debugPrint('Attempting to reconnect to ${device.name}');
      
      // Try to connect
      await device.connect(timeout: const Duration(seconds: 5));
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUUID) {
          await _handleService(service);
          
          // Resend current state
          await _resendCurrentState();
          debugPrint('Successfully reconnected and restored state');
        }
      }
    } catch (e) {
      debugPrint('Error during reconnection: $e');
    }
  }

  // Resend current state
  Future<void> _resendCurrentState() async {
    // Send all current values in sequence
    for (var entry in currentValues.entries) {
      try {
        final data = Uint8List.fromList([entry.value]);
        await _sendCharacteristicValue(entry.key, data);
        await Future.delayed(const Duration(milliseconds: 3));
      } catch (e) {
        debugPrint('Error resending ${entry.key}: $e');
      }
    }
  }

  // Add connection state monitoring
  void _monitorConnectionState() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      for (var device in connectedDevices.values) {
        try {
          final isConnected = await device.isConnected;
          if (!isConnected) {
            debugPrint('Device ${device.name} disconnected, attempting reconnection...');
            await handleReconnection(device);
          }
        } catch (e) {
          debugPrint('Error checking connection: $e');
        }
      }
    });
  }
  
  @override
  void dispose() {
    _speedTimer?.cancel();
    super.dispose();
  }
} 