import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/draw_op.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../rendering/frame_renderer.dart';

class LassoCutResult {
  final ui.Image selectionImage;
  final ui.Image remainderImage;
  final Offset pivot;
  const LassoCutResult({
    required this.selectionImage,
    required this.remainderImage,
    required this.pivot,
  });
}

/// Handles the raster side of the lasso tool: rasterizing a layer's
/// current ops, splitting out the pixels inside a lasso path into a
/// standalone "selection" image, and leaving the rest as a
/// "remainder" image with that region erased.
class LassoService {
  /// Cuts the region inside [lassoPath] (canvas-space points, at least
  /// 3 for a meaningful area) out of [layerOps]'s rasterized content.
  static Future<LassoCutResult> cut(List<DrawOp> layerOps, List<Offset> lassoPath) async {
    final baseImage = await _rasterize(layerOps);

    final path = Path()..addPolygon(lassoPath, true);
    final bounds = path.getBounds();
    final pivot = bounds.center;

    // Selection = base image, clipped to just the lassoed area.
    final selRecorder = ui.PictureRecorder();
    final selCanvas = Canvas(selRecorder);
    selCanvas.save();
    selCanvas.clipPath(path);
    selCanvas.drawImage(baseImage, Offset.zero, Paint());
    selCanvas.restore();
    final selectionImage = await selRecorder
        .endRecording()
        .toImage(kCanvasWidth.toInt(), kCanvasHeight.toInt());

    // Remainder = base image with the lassoed area erased.
    final remRecorder = ui.PictureRecorder();
    final remCanvas = Canvas(remRecorder);
    remCanvas.drawImage(baseImage, Offset.zero, Paint());
    remCanvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
    final remainderImage = await remRecorder
        .endRecording()
        .toImage(kCanvasWidth.toInt(), kCanvasHeight.toInt());

    return LassoCutResult(selectionImage: selectionImage, remainderImage: remainderImage, pivot: pivot);
  }

  /// Renders [selectionImage] with a translate/rotate/scale transform
  /// baked in, pivoting around [pivot]. Called once, when the user
  /// confirms a move - not during interactive dragging, which is
  /// rendered live by a plain CustomPainter instead (see
  /// DrawingCanvas) to avoid re-rasterizing on every gesture tick.
  static Future<ui.Image> renderTransformed({
    required ui.Image selectionImage,
    required Offset pivot,
    required Offset translation,
    required double scale,
    required double rotation,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.save();
    canvas.translate(pivot.dx + translation.dx, pivot.dy + translation.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawImage(selectionImage, Offset.zero, Paint());
    canvas.restore();
    final picture = recorder.endRecording();
    return picture.toImage(kCanvasWidth.toInt(), kCanvasHeight.toInt());
  }

  static Future<ui.Image> _rasterize(List<DrawOp> layerOps) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final tempFrame = FrameData.fromLayers([List.of(layerOps)]);
    FrameRenderer.paintFrame(
      canvas,
      tempFrame,
      [LayerInfo(name: 'tmp')],
      scaleX: 1,
      scaleY: 1,
    );
    final picture = recorder.endRecording();
    return picture.toImage(kCanvasWidth.toInt(), kCanvasHeight.toInt());
  }
}
