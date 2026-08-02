import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records a voiceover clip to a file in app-private storage using the
/// device microphone. One instance per recording session - call
/// [start], then [stop] when done, which returns the recorded file's
/// path (or null if nothing was recorded).
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/imported_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final path = '${audioDir.path}/voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
  }

  Future<String?> stop() => _recorder.stop();

  Future<bool> isRecording() => _recorder.isRecording();

  Future<void> dispose() => _recorder.dispose();
}
