import 'package:flutter/material.dart';

class SpeedControlView extends StatelessWidget {
  final int speed;
  final Function(int) onSpeedChanged;

  const SpeedControlView({
    Key? key,
    required this.speed,
    required this.onSpeedChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Speed value display
          Text(
            'Speed: $speed',
            style: Theme.of(context).textTheme.caption,
          ),
          const SizedBox(height: 8),
          
          // Slider with icons
          Row(
            children: [
              const Icon(Icons.directions_walk, size: 20),  // "tortoise" equivalent
              Expanded(
                child: Slider(
                  value: speed.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 50,
                  onChanged: (value) => onSpeedChanged(value.toInt()),
                ),
              ),
              const Icon(Icons.directions_run, size: 20),  // "hare" equivalent
            ],
          ),
        ],
      ),
    );
  }
} 