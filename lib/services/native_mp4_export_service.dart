import 'dart:io';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../models/animation_project.dart';
import 'export_service.dart';
import 'native_video_encoder.dart';

/// In-app MP4 export via the platform's own H.264 encoder (see
/// [NativeVideoEncoder]) instead of a bundled ffmpeg binary. Renders
/// each frame to a temp PNG, hands the folder off to the native side,
/// then cleans the temp folder up.
class NativeMp4ExportService {
  static Future<File> exportProjectAsMp4(AnimationProject project) async {
    final tempDir = await getTemporaryDirectory();
    final frameDir = Directory(
      '${tempDir.path}/toonframe_mp4_${DateTime.now().millisecondsSinceEpoch}',
    );
    await frameDir.create(recursive: true);

    try {
      int index = 1;
      for (final frame in project.frames) {
        final uiImage = await ExportService.renderFrameToImage(frame, project.layers);
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
        await File('${frameDir.path}/$fileName').writeAsBytes(pngBytes);
        index++;
      }
      final frameCount = index - 1;

      final dir = await getApplicationDocumentsDirectory();
      final outputPath =
          '${dir.path}/${project.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final resultPath = await NativeVideoEncoder.encodeMp4(
        framesDir: frameDir.path,
        frameCount: frameCount,
        fps: project.fps,
        width: kCanvasWidth.toInt(),
        height: kCanvasHeight.toInt(),
        outputPath: outputPath,
      );

      return File(resultPath);
    } finally {
      if (await frameDir.exists()) {
        await frameDir.delete(recursive: true);
      }
    }
  }
}
