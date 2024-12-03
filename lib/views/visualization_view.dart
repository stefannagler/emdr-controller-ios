import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/bluetooth_manager.dart';

class LinearVisualizationView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothManager>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        children: [
          // Battery warning
          if (bluetoothManager.battery1Level <= 10 || bluetoothManager.battery2Level <= 10)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Low Battery Warning',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ),
          
          // Linear animation
          Container(
            width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
            height: 60,
            child: Stack(
              children: [
                // Background line
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Moving dot
                AnimatedAlign(
                  alignment: Alignment(
                    bluetoothManager.currentSide ? 1.0 : -1.0,
                    0
                  ),
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Left marker
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Right marker
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 