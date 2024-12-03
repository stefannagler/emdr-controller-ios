import 'package:flutter/material.dart';

class ModeControlView extends StatelessWidget {
  final String title;
  final bool enabled;
  final int intensity;
  final int duration;
  final RangeValues intensityRange;
  final RangeValues durationRange;
  final Function(bool) onToggle;
  final Function(int) onIntensityChange;
  final Function(int) onDurationChange;

  const ModeControlView({
    Key? key,
    required this.title,
    required this.enabled,
    required this.intensity,
    required this.duration,
    required this.intensityRange,
    required this.durationRange,
    required this.onToggle,
    required this.onIntensityChange,
    required this.onDurationChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.subtitle1,
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            
            if (enabled) ...[
              const SizedBox(height: 16),
              
              // Intensity slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Intensity: $intensity'),
                  Slider(
                    value: intensity.toDouble(),
                    min: intensityRange.start,
                    max: intensityRange.end,
                    divisions: (intensityRange.end - intensityRange.start).toInt(),
                    onChanged: (value) => onIntensityChange(value.toInt()),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Duration slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duration: $duration'),
                  Slider(
                    value: duration.toDouble(),
                    min: durationRange.start,
                    max: durationRange.end,
                    divisions: (durationRange.end - durationRange.start).toInt(),
                    onChanged: (value) => onDurationChange(value.toInt()),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
} 