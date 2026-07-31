import 'package:flutter/material.dart';

/// A single continuous pen or eraser stroke, stored as a list of points
/// in the fixed internal canvas coordinate space.
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  Stroke copyWith({List<Offset>? points}) => Stroke(
        points: points ?? List.of(this.points),
        color: color,
        width: width,
        isEraser: isEraser,
      );
}
