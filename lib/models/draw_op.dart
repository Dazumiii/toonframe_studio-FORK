import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Offset, Color;
import 'shape_kind.dart';
import 'stroke.dart';

/// A single drawing operation on a layer, stored in the order it was
/// performed. Either a vector [Stroke] (pen/eraser), a vector
/// [ShapeDrawOp] (rectangle/ellipse/line), a [TextDrawOp], or a
/// rasterized image (flood-fill result, or an imported reference
/// photo/video frame).
///
/// A fill/image op is baked into an image once, at the moment it's
/// created. That keeps things simple: later strokes/shapes just draw
/// on top of it in order, and undo can always just remove the most
/// recent op.
sealed class DrawOp {}

class StrokeDrawOp extends DrawOp {
  final Stroke stroke;
  StrokeDrawOp(this.stroke);
}

/// A rectangle, ellipse, or straight line, drawn by dragging from
/// [start] to [end] (both in the fixed internal canvas coordinate
/// space, same as [Stroke.points]). Stays a resizable-in-spirit vector
/// shape in the op history (though this app doesn't support editing a
/// shape after it's placed - only undoing it).
class ShapeDrawOp extends DrawOp {
  final ShapeKind kind;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  final bool filled;

  ShapeDrawOp({
    required this.kind,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });
}

/// A piece of text placed at [position] (the top-left anchor, in the
/// fixed internal canvas coordinate space). [fontSize] is stored in
/// that same canvas-space unit system (not screen pixels), scaled the
/// same way [Stroke.width] is, so text stays proportionally sized
/// however the canvas is displayed.
class TextDrawOp extends DrawOp {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;

  TextDrawOp({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  });
}

class FillDrawOp extends DrawOp {
  /// Full canvas-resolution (kCanvasWidth x kCanvasHeight) raster of
  /// the layer's artwork with the flood-fill baked in. dart:ui Images
  /// are immutable once created, so it's safe to share this reference
  /// when a frame is cloned.
  final ui.Image image;
  FillDrawOp(this.image);
}

/// An imported reference photo or extracted video frame, letterboxed
/// to fill the canvas. Used for rotoscoping - placed on a dedicated
/// low-opacity "Reference" layer so the artist can trace over it on
/// another layer. Renders the same way as [FillDrawOp] (a full-canvas
/// raster), kept as a distinct type so the UI/import code can reason
/// about "this op is a reference photo" separately from "this op is a
/// flood fill".
class ImageDrawOp extends DrawOp {
  final ui.Image image;
  ImageDrawOp(this.image);
}
