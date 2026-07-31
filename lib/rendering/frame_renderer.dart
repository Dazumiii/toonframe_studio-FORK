import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../constants.dart';
import '../models/draw_op.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../models/stroke.dart';

/// Shared rendering logic used by the live canvas painter, timeline
/// thumbnails, the fill tool's rasterizer, and GIF export - so all of
/// them stay pixel-identical. Handles layer visibility/opacity and
/// draws both vector strokes and baked-in fill rasters in order.
class FrameRenderer {
  static void paintFrame(
    Canvas canvas,
    FrameData frame,
    List<LayerInfo> layers, {
    required double scaleX,
    required double scaleY,
    double opacity = 1.0,
  }) {
    if (opacity <= 0) return;
    final bounds = Rect.fromLTWH(0, 0, kCanvasWidth * scaleX, kCanvasHeight * scaleY);

    final needsFrameLayer = opacity < 1.0;
    if (needsFrameLayer) {
      canvas.saveLayer(bounds, Paint()..color = Colors.white.withOpacity(opacity));
    }

    for (int i = 0; i < frame.layerOps.length; i++) {
      final info = i < layers.length ? layers[i] : null;
      if (info != null && !info.visible) continue;
      final layerOpacity = info?.opacity ?? 1.0;
      if (layerOpacity <= 0) continue;

      final needsLayerSave = layerOpacity < 1.0;
      if (needsLayerSave) {
        canvas.saveLayer(bounds, Paint()..color = Colors.white.withOpacity(layerOpacity));
      }
      _paintOps(canvas, frame.layerOps[i], scaleX, scaleY);
      if (needsLayerSave) canvas.restore();
    }

    if (needsFrameLayer) canvas.restore();
  }

  /// Renders [frame] as a solid-tinted silhouette (all visible ink
  /// recolored to [tint], preserving its shape/alpha) at [opacity] -
  /// the classic onion-skin look used by most animation apps, so a
  /// ghosted previous/next frame reads clearly without its original
  /// colors competing with the frame you're actually drawing on.
  static void paintOnionFrame(
    Canvas canvas,
    FrameData frame,
    List<LayerInfo> layers, {
    required double scaleX,
    required double scaleY,
    required double opacity,
    required Color tint,
  }) {
    if (opacity <= 0) return;
    final bounds = Rect.fromLTWH(0, 0, kCanvasWidth * scaleX, kCanvasHeight * scaleY);

    canvas.saveLayer(
      bounds,
      Paint()
        ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
        ..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
    );
    paintFrame(canvas, frame, layers, scaleX: scaleX, scaleY: scaleY);
    canvas.restore();
  }

  static void _paintOps(Canvas canvas, List<DrawOp> ops, double sx, double sy) {
    for (final op in ops) {
      switch (op) {
        case StrokeDrawOp():
          _paintStroke(canvas, op.stroke, sx, sy);
        case FillDrawOp():
          _paintRaster(canvas, op.image, sx, sy);
        case ImageDrawOp():
          _paintRaster(canvas, op.image, sx, sy);
      }
    }
  }

  static void _paintRaster(Canvas canvas, ui.Image image, double sx, double sy) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, kCanvasWidth * sx, kCanvasHeight * sy),
      Paint(),
    );
  }

  static void _paintStroke(Canvas canvas, Stroke stroke, double sx, double sy) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser ? Colors.white : stroke.color
      ..strokeWidth = stroke.width * ((sx + sy) / 2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      canvas.drawCircle(
        Offset(p.dx * sx, p.dy * sy),
        (stroke.width * ((sx + sy) / 2)) / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(stroke.points[0].dx * sx, stroke.points[0].dy * sy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx * sx, stroke.points[i].dy * sy);
    }
    canvas.drawPath(path, paint);
  }
}
