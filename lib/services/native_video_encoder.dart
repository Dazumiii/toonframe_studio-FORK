import 'package:flutter/services.dart';

/// Talks to the native Android side (see android_native/Mp4Encoder.kt)
/// over a MethodChannel to encode a directory of numbered PNG frames
/// into an MP4, using the device's built-in MediaCodec/MediaMuxer H.264
/// encoder - no ffmpeg, no third-party native plugin, nothing that can
/// go stale independently of the OS itself.
///
/// This only works if the native Kotlin side has been added to the
/// Android project - see the README's "In-app MP4 export" section. If
/// it hasn't, calls here fail with a [MissingPluginException] and the
/// caller should fall back to the PNG-sequence export.
class NativeVideoEncoder {
  static const _channel = MethodChannel('toonframe_studio/mp4_encoder');

  /// Encodes `frame_0001.png`, `frame_0002.png`, ... (1-indexed,
  /// 4-digit zero-padded) found in [framesDir] into an MP4 at
  /// [outputPath]. Returns the output path on success.
  static Future<String> encodeMp4({
    required String framesDir,
    required int frameCount,
    required int fps,
    required int width,
    required int height,
    required String outputPath,
  }) async {
    final result = await _channel.invokeMethod<String>('encodeMp4', {
      'framesDir': framesDir,
      'frameCount': frameCount,
      'fps': fps,
      'width': width,
      'height': height,
      'outputPath': outputPath,
    });
    if (result == null) {
      throw PlatformException(code: 'null_result', message: 'Native encoder returned no output path');
    }
    return result;
  }
}
