import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_track.dart';

/// Picks an audio file from the device (music, an SFX file the user
/// already has, etc.) and copies it into app-private storage, so the
/// project doesn't break if the original file gets moved or deleted
/// from wherever the user picked it from.
class AudioImportService {
  /// Returns null if the user cancelled the picker.
  static Future<AudioTrack?> pickAudioFile({required AudioTrackType type}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final sourcePath = picked.path;
    if (sourcePath == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/imported_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    final destPath = '${audioDir.path}/$fileName';
    await File(sourcePath).copy(destPath);

    return AudioTrack(
      name: picked.name,
      filePath: destPath,
      type: type,
    );
  }
}
