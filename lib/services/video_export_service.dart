import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/animation_project.dart';
import 'export_service.dart';

/// Encodes the project into an MP4 by rendering a PNG frame sequence
/// and stitching it together with ffmpeg (via the ffmpeg_kit_flutter_new
/// plugin - see the README for a note on package availability).
///
/// Uses the `mpeg4` codec rather than `libx264`: many ffmpeg-kit builds
/// ship without the GPL-licensed x264 encoder, so mpeg4 (built into
/// even minimal/LGPL builds) is the safer default for broad
/// compatibility. Quality/compression won't match H.264, but it plays
/// back fine in any standard video player.
class VideoExportService {
  static Future<File> exportProjectAsMp4(AnimationProject project) async {
    final tempDir = await getTemporaryDirectory();
    final frameDir = Directory(
      '${tempDir.path}/toonframe_export_${DateTime.now().millisecondsSinceEpoch}',
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

      final dir = await getApplicationDocumentsDirectory();
      final outFile = File(
        '${dir.path}/${project.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      final command = '-y -framerate ${project.fps} -i "${frameDir.path}/frame_%04d.png" '
          '-c:v mpeg4 -q:v 3 -pix_fmt yuv420p "${outFile.path}"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString();
        throw Exception('ffmpeg failed (code $returnCode):\n$logs');
      }

      return outFile;
    } finally {
      if (await frameDir.exists()) {
        await frameDir.delete(recursive: true);
      }
    }
  }
}
