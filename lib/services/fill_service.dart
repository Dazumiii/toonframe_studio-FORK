import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../constants.dart';
import '../models/draw_op.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../rendering/frame_renderer.dart';

/// Handles the paint-bucket tool: rasterizes a layer's current
/// artwork, flood-fills the tapped region, and hands back a new raster
/// image to be stored as a [FillDrawOp].
class FillService {
  /// How different a pixel's color can be from the seed pixel and
  /// still count as the same fillable region. Keeps fills from leaking
  /// past anti-aliased line edges while still covering them cleanly.
  static const double _threshold = 35;

  /// Rasterizes a single layer's ops (strokes + any earlier fills) to
  /// a full canvas-resolution image, ignoring layer opacity/visibility
  /// - the fill tool always works against the layer's full-strength
  /// artwork.
  static Future<ui.Image> rasterizeOps(List<DrawOp> ops) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kCanvasWidth, kCanvasHeight),
      Paint()..color = Colors.white,
    );
    final tempFrame = FrameData.fromLayers([List.of(ops)]);
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

  /// Flood-fills [source] starting at ([seedX], [seedY]) with
  /// [fillColor]. Returns null if the seed point is out of bounds or
  /// already effectively that color (nothing to do).
  static Future<ui.Image?> floodFill(
    ui.Image source, {
    required int seedX,
    required int seedY,
    required Color fillColor,
  }) async {
    if (seedX < 0 || seedY < 0 || seedX >= source.width || seedY >= source.height) {
      return null;
    }

    final byteData = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();

    final image = img.Image.fromBytes(
      width: source.width,
      height: source.height,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    final seedPixel = image.getPixel(seedX, seedY);
    final target = img.ColorRgba8(
      fillColor.red,
      fillColor.green,
      fillColor.blue,
      fillColor.alpha,
    );

    final alreadySameColor = (seedPixel.r - target.r).abs() < 2 &&
        (seedPixel.g - target.g).abs() < 2 &&
        (seedPixel.b - target.b).abs() < 2 &&
        (seedPixel.a - target.a).abs() < 2;
    if (alreadySameColor) return null;

    img.fillFlood(
      image,
      x: seedX,
      y: seedY,
      color: target,
      threshold: _threshold,
    );

    final outBytes = image.getBytes(order: img.ChannelOrder.rgba);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      outBytes,
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
