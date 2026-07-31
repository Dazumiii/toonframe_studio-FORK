import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../constants.dart';

/// Decodes arbitrary image bytes (JPEG/PNG/etc.) and fits them onto a
/// white kCanvasWidth x kCanvasHeight canvas ("contain" fit, centered,
/// letterboxed) so imported photos/video frames always line up with
/// the drawing canvas regardless of their original aspect ratio.
class ImageUtils {
  static Future<ui.Image> fitBytesToCanvas(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image data');
    }

    final canvasImg = img.Image(width: kCanvasWidth.toInt(), height: kCanvasHeight.toInt());
    img.fill(canvasImg, color: img.ColorRgba8(255, 255, 255, 255));

    final scale = math.min(
      kCanvasWidth / decoded.width,
      kCanvasHeight / decoded.height,
    );
    final destW = (decoded.width * scale).round().clamp(1, kCanvasWidth.toInt());
    final destH = (decoded.height * scale).round().clamp(1, kCanvasHeight.toInt());

    final resized = img.copyResize(
      decoded,
      width: destW,
      height: destH,
      interpolation: img.Interpolation.average,
    );

    final dstX = ((kCanvasWidth.toInt() - destW) / 2).round();
    final dstY = ((kCanvasHeight.toInt() - destH) / 2).round();
    img.compositeImage(canvasImg, resized, dstX: dstX, dstY: dstY);

    final outBytes = canvasImg.getBytes(order: img.ChannelOrder.rgba);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      outBytes,
      canvasImg.width,
      canvasImg.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
