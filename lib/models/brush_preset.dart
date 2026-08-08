import 'package:flutter/material.dart';
import 'brush_style.dart';

/// A user-saved combination of brush style, color, and width, so a
/// favorite setup (e.g. "thin red pencil for corrections") can be
/// reapplied in one tap instead of resetting each control by hand.
class BrushPreset {
  final String name;
  final BrushStyle style;
  final Color color;
  final double width;

  const BrushPreset({
    required this.name,
    required this.style,
    required this.color,
    required this.width,
  });
}
