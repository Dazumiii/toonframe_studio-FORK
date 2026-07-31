import 'package:flutter/material.dart';
import '../models/onion_skin_settings.dart';

/// Bottom-sheet UI for onion skin settings: on/off, how many frames to
/// ghost before and after the current one, and overall opacity.
class OnionSkinPanel extends StatefulWidget {
  final OnionSkinSettings settings;

  /// Called after any mutation so the parent screen (which owns the
  /// canvas rendering these same settings) can rebuild.
  final VoidCallback onChanged;

  const OnionSkinPanel({super.key, required this.settings, required this.onChanged});

  @override
  State<OnionSkinPanel> createState() => _OnionSkinPanelState();
}

class _OnionSkinPanelState extends State<OnionSkinPanel> {
  void _notify() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.motion_photos_on, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                const Text('Onion Skin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: s.enabled,
                  activeColor: Colors.orangeAccent,
                  onChanged: (v) {
                    s.enabled = v;
                    _notify();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Previous frames', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 18),
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Next frames', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            _buildSlider(
              label: 'Frames before',
              value: s.framesBefore.toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              display: '${s.framesBefore}',
              onChanged: (v) {
                s.framesBefore = v.round();
                _notify();
              },
            ),
            _buildSlider(
              label: 'Frames after',
              value: s.framesAfter.toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              display: '${s.framesAfter}',
              onChanged: (v) {
                s.framesAfter = v.round();
                _notify();
              },
            ),
            _buildSlider(
              label: 'Opacity',
              value: s.opacity,
              min: 0.1,
              max: 0.8,
              divisions: 14,
              display: '${(s.opacity * 100).round()}%',
              onChanged: (v) {
                s.opacity = v;
                _notify();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Colors.orangeAccent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(display, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white))),
      ],
    );
  }
}
