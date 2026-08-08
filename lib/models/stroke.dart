import 'package:flutter/material.dart';
import 'brush_style.dart';

/// A single continuous pen or eraser stroke, stored as a list of points
/// in the fixed internal canvas coordinate space.
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  /// Which brush look this stroke was drawn with (pencil/pen/marker/
  /// highlighter). Meaningless for eraser strokes - erasing always
  /// renders as opaque white regardless of this value.
  final BrushStyle brushStyle;

  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
    this.brushStyle = BrushStyle.pen,
  });

  Stroke copyWith({List<Offset>? points}) => Stroke(
        points: points ?? List.of(this.points),
        color: color,
        width: width,
        isEraser: isEraser,
        brushStyle: brushStyle,
      );
}
