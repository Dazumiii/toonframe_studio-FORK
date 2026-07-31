import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../models/animation_project.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../rendering/frame_renderer.dart';

class ExportService {
  /// Rasterizes a single frame into a [ui.Image] at the fixed canvas
  /// resolution, compositing every visible layer (strokes + fills)
  /// via the same [FrameRenderer] used by the live canvas.
  static Future<ui.Image> renderFrameToImage(FrameData frame, List<LayerInfo> layers) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kCanvasWidth, kCanvasHeight),
      Paint()..color = Colors.white,
    );

    FrameRenderer.paintFrame(canvas, frame, layers, scaleX: 1, scaleY: 1);

    final picture = recorder.endRecording();
    return picture.toImage(kCanvasWidth.toInt(), kCanvasHeight.toInt());
  }

  /// Renders every frame in the project (all visible layers
  /// composited) and encodes them into an animated GIF saved to the
  /// app's documents directory. Returns the saved file.
  static Future<File> exportProjectAsGif(AnimationProject project) async {
    final encoder = img.GifEncoder();

    for (final frame in project.frames) {
      final uiImage = await renderFrameToImage(frame, project.layers);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = byteData!.buffer.asUint8List();

      final imgFrame = img.Image.fromBytes(
        width: uiImage.width,
        height: uiImage.height,
        bytes: bytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // GIF delay is in hundredths of a second.
      encoder.addFrame(imgFrame, duration: (100 / project.fps).round());
    }

    final gifBytes = encoder.finish();
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${project.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.gif';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(gifBytes!);
    return file;
  }

  /// Renders every frame and zips them up as a numbered PNG sequence
  /// (frame_0001.png, frame_0002.png, ...). This is the recommended
  /// path to an actual video file: it has no native/platform
  /// dependencies (unlike an in-app ffmpeg plugin, which as of this
  /// writing has real Android build compatibility problems - see the
  /// README). Turn it into an MP4 with ffmpeg on any machine you
  /// control:
  /// `ffmpeg -framerate <fps> -i frame_%04d.png -pix_fmt yuv420p out.mp4`
  static Future<File> exportPngSequenceZip(AnimationProject project) async {
    final archive = Archive();

    int index = 1;
    for (final frame in project.frames) {
      final uiImage = await renderFrameToImage(frame, project.layers);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = byteData!.buffer.asUint8List();
      final imgFrame = img.Image.fromBytes(
        width: uiImage.width,
        height: uiImage.height,
        bytes: bytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final pngBytes = img.encodePng(imgFrame);
      final fileName = 'frame_${index.toString().padLeft(4, '0')}.png';
      archive.addFile(ArchiveFile(fileName, pngBytes.length, pngBytes));
      index++;
    }

    final zipBytes = ZipEncoder().encode(archive);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${project.name.replaceAll(' ', '_')}_frames_${DateTime.now().millisecondsSinceEpoch}.zip';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(zipBytes!);
    return file;
  }
}
