import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/bluetooth_manager.dart';

class StatusBarView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothManager>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Left battery indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bluetoothManager.leftHeartbeatMissing ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'L: ${bluetoothManager.battery1Level}%',
                style: Theme.of(context).textTheme.caption,
              ),
            ],
          ),
          
          Spacer(),
          
          // Connection status
          Text(
            '${bluetoothManager.connectedDeviceCount} Connected',
            style: Theme.of(context).textTheme.caption?.copyWith(
              color: bluetoothManager.connectedDeviceCount > 0 ? Colors.green : Colors.red,
            ),
          ),
          
          Spacer(),
          
          // Right battery indicator
          Row(
            children: [
              Text(
                'R: ${bluetoothManager.battery2Level}%',
                style: Theme.of(context).textTheme.caption,
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bluetoothManager.rightHeartbeatMissing ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 