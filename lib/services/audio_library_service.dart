import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../utils/wav_synth.dart';

class AudioLibraryItem {
  final String key;
  final String label;
  final Uint8List Function() generate;
  const AudioLibraryItem({required this.key, required this.label, required this.generate});
}

/// The built-in "sound library" - a handful of synthesized SFX (see
/// [WavSynth] for why these are generated rather than bundled files).
/// Each clip is only generated once and then cached to disk, so
/// repeated taps in the library UI are instant.
class AudioLibraryService {
  static const List<AudioLibraryItem> items = [
    AudioLibraryItem(key: 'click', label: 'Click', generate: WavSynth.click),
    AudioLibraryItem(key: 'beep', label: 'Beep', generate: WavSynth.beep),
    AudioLibraryItem(key: 'ding', label: 'Ding', generate: WavSynth.ding),
    AudioLibraryItem(key: 'whoosh', label: 'Whoosh', generate: WavSynth.whoosh),
    AudioLibraryItem(key: 'pop', label: 'Pop', generate: WavSynth.pop),
  ];

  static Future<String> resolveFilePath(AudioLibraryItem item) async {
    final dir = await getApplicationSupportDirectory();
    final libraryDir = Directory('${dir.path}/sfx_library');
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }
    final file = File('${libraryDir.path}/${item.key}.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(item.generate());
    }
    return file.path;
  }
}
