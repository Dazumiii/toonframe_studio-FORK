import 'dart:math' as math;
import 'dart:typed_data';

/// Generates tiny synthesized sound-effect clips as raw WAV bytes,
/// entirely in Dart at runtime - no bundled audio files, so nothing
/// here is a copy of anyone else's recording. See the README's note
/// on the audio library for why it works this way instead of shipping
/// a real SFX pack.
class WavSynth {
  static const int sampleRate = 22050;

  static Uint8List _toWav(List<double> samples) {
    final pcm = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      pcm[i] = (clamped * 32767).round();
    }
    final dataBytes = pcm.buffer.asUint8List();
    const bitsPerSample = 16;
    const numChannels = 1;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;

    final header = BytesBuilder();
    void writeString(String s) => header.add(s.codeUnits);
    void writeUint32(int v) => header.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void writeUint16(int v) => header.add([v & 0xff, (v >> 8) & 0xff]);

    writeString('RIFF');
    writeUint32(36 + dataBytes.length);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16); // PCM fmt chunk size
    writeUint16(1); // PCM format
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeString('data');
    writeUint32(dataBytes.length);

    final result = BytesBuilder();
    result.add(header.toBytes());
    result.add(dataBytes);
    return result.toBytes();
  }

  /// Simple attack/release envelope, 0.0-1.0.
  static double _envelope(double t, double duration, {double attack = 0.01, double release = 0.1}) {
    if (t < attack) return t / attack;
    final remaining = duration - t;
    if (remaining < release) return (remaining / release).clamp(0.0, 1.0);
    return 1.0;
  }

  /// Short percussive click (filtered noise burst).
  static Uint8List click() {
    const duration = 0.06;
    final n = (sampleRate * duration).round();
    final rand = math.Random(1);
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final env = math.exp(-t * 60);
      return (rand.nextDouble() * 2 - 1) * env * 0.6;
    });
    return _toWav(samples);
  }

  /// Plain sine beep.
  static Uint8List beep({double frequency = 880}) {
    const duration = 0.2;
    final n = (sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final env = _envelope(t, duration, attack: 0.01, release: 0.08);
      return math.sin(2 * math.pi * frequency * t) * env * 0.5;
    });
    return _toWav(samples);
  }

  /// Bell-like ding with a few decaying harmonics.
  static Uint8List ding() {
    const duration = 0.6;
    final n = (sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final decay = math.exp(-t * 4);
      final wave = math.sin(2 * math.pi * 660 * t) * 0.6 +
          math.sin(2 * math.pi * 990 * t) * 0.3 +
          math.sin(2 * math.pi * 1320 * t) * 0.1;
      return wave * decay * 0.5;
    });
    return _toWav(samples);
  }

  /// Frequency sweep with a little noise mixed in ("whoosh").
  static Uint8List whoosh() {
    const duration = 0.4;
    final n = (sampleRate * duration).round();
    final rand = math.Random(2);
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final progress = t / duration;
      final freq = 200 + 1800 * math.sin(progress * math.pi); // rises then falls
      final env = _envelope(t, duration, attack: 0.05, release: 0.15);
      final tone = math.sin(2 * math.pi * freq * t);
      final noise = (rand.nextDouble() * 2 - 1) * 0.3;
      return (tone * 0.6 + noise * 0.4) * env * 0.5;
    });
    return _toWav(samples);
  }

  /// Quick descending pop/blip.
  static Uint8List pop() {
    const duration = 0.12;
    final n = (sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final freq = 400 - 300 * (t / duration);
      final env = math.exp(-t * 25);
      return math.sin(2 * math.pi * freq * t) * env * 0.6;
    });
    return _toWav(samples);
  }
}
