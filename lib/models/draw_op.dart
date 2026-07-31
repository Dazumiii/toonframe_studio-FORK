import 'dart:ui' as ui;
import 'stroke.dart';

/// A single drawing operation on a layer, stored in the order it was
/// performed. Either a vector [Stroke] (pen/eraser) or a rasterized
/// flood-fill result.
///
/// A fill is computed once, against whatever the layer looked like at
/// that moment, and baked into an image. That keeps things simple:
/// later strokes/fills just draw on top of it in order, and undo can
/// always just remove the most recent op.
sealed class DrawOp {}

class StrokeDrawOp extends DrawOp {
  final Stroke stroke;
  StrokeDrawOp(this.stroke);
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
