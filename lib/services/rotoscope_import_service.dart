import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../utils/image_utils.dart';

/// Handles picking media for rotoscoping: a single reference photo, or
/// a video that gets sampled into a sequence of reference frames.
class RotoscopeImportService {
  static final ImagePicker _picker = ImagePicker();

  /// Opens the gallery photo picker. Returns a canvas-fitted image, or
  /// null if the user cancelled.
  static Future<ui.Image?> pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return ImageUtils.fitBytesToCanvas(bytes);
  }

  /// Opens the gallery video picker. Returns the picked video's local
  /// path, or null if the user cancelled.
  static Future<String?> pickVideoPath() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    return file?.path;
  }

  /// Reads a video's duration without playing it.
  static Future<Duration?> probeDuration(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  /// Samples [frameCount] evenly-spaced frames across the video's
  /// [duration] and returns them as canvas-fitted images, in order.
  /// Uses native platform thumbnailing (no ffmpeg needed for this
  /// part), so it's relatively lightweight.
  static Future<List<ui.Image>> extractFrames(
    String path, {
    required int frameCount,
    required Duration duration,
  }) async {
    final results = <ui.Image>[];
    if (frameCount <= 0 || duration.inMilliseconds <= 0) return results;

    final stepMs = duration.inMilliseconds / frameCount;
    for (int i = 0; i < frameCount; i++) {
      final timeMs = (stepMs * i).round().clamp(0, duration.inMilliseconds - 1);
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.PNG,
        timeMs: timeMs,
        quality: 80,
      );
      if (bytes == null) continue;
      results.add(await ImageUtils.fitBytesToCanvas(bytes));
    }
    return results;
  }
}
