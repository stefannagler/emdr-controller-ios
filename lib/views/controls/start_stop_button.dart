import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bluetooth/bluetooth_manager.dart';

class StartStopButton extends StatelessWidget {
  final bool isRunning;
  final Function(bool) onToggle;
  final int speed;

  const StartStopButton({
    Key? key,
    required this.isRunning,
    required this.onToggle,
    required this.speed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothManager>(context);
    
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            final newState = !isRunning;
            onToggle(newState);
            
            if (newState) {
              bluetoothManager.sendSpeed(speed.toDouble());
              Future.delayed(Duration(milliseconds: 50), () {
                debugPrint('=== Starting Sequence ===');
                debugPrint('• Speed sent: $speed');
                bluetoothManager.sendStartAndTapperFlags(true);
              });
            } else {
              debugPrint('=== Stopping Sequence ===');
              bluetoothManager.sendStartAndTapperFlags(false);
            }
          },
          style: ElevatedButton.styleFrom(
            primary: isRunning ? Colors.red : Colors.green,
            minimumSize: Size(120, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            isRunning ? 'Stop' : 'Start',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        
        // Warning indicators
        if (bluetoothManager.leftHeartbeatMissing || 
            bluetoothManager.rightHeartbeatMissing)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (bluetoothManager.leftHeartbeatMissing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'L',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (bluetoothManager.rightHeartbeatMissing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'R',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
} 