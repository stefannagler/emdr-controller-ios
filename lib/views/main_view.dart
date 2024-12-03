import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/bluetooth_manager.dart';
import 'status_bar_view.dart';
import 'controls/mode_control.dart';
import 'controls/speed_control.dart';

class MainView extends StatefulWidget {
  @override
  _MainViewState createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  bool isRunning = false;
  int speed = 25;
  bool buzzEnabled = false;
  bool lightEnabled = false;
  bool soundEnabled = false;
  bool pressureEnabled = false;
  
  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothManager>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMDR Controller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Show settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StatusBarView(),
          
          // Circle Visualization will go here
          
          SpeedControl(
            speed: speed,
            onSpeedChanged: (newSpeed) {
              setState(() => speed = newSpeed);
              bluetoothManager.sendSpeed(newSpeed.toDouble());
            },
          ),
          
          // Mode controls will go here
          
          // Start/Stop button will go here
        ],
      ),
    );
  }
} 