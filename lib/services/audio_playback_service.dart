import 'package:audioplayers/audioplayers.dart';
import '../models/audio_track.dart';

/// Plays every unmuted [AudioTrack] in a project alongside the
/// animation's play/pause/loop, using one [AudioPlayer] per track.
///
/// Sync is "good enough for a hobby project", not frame-accurate: it's
/// driven by the same periodic [Timer] that advances animation frames
/// (see EditorScreen._togglePlay), not a shared audio/video clock, so
/// audio can drift slightly from the frame timer over a long playback
/// session. Fine for short animations; worth revisiting if you need
/// tighter sync for longer ones.
class AudioPlaybackService {
  final Map<String, AudioPlayer> _players = {};

  AudioPlayer _playerFor(AudioTrack track) {
    return _players.putIfAbsent(track.filePath, () => AudioPlayer());
  }

  /// Starts every unmuted track whose startFrameIndex is at or before
  /// [currentFrameIndex], seeking each to the correct offset given
  /// [fps]. Call [checkStarts] on every subsequent frame tick so
  /// tracks starting later in the timeline kick in on time.
  Future<void> playFrom({
    required List<AudioTrack> tracks,
    required int currentFrameIndex,
    required int fps,
  }) async {
    for (final track in tracks) {
      if (track.muted) continue;
      if (currentFrameIndex < track.startFrameIndex) continue;
      final player = _playerFor(track);
      await player.setVolume(track.volume);
      final offsetMs = ((currentFrameIndex - track.startFrameIndex) / fps * 1000).round();
      await player.play(
        DeviceFileSource(track.filePath),
        position: Duration(milliseconds: offsetMs < 0 ? 0 : offsetMs),
      );
    }
  }

  /// Starts any track whose startFrameIndex is exactly
  /// [currentFrameIndex] - meant to be called once per frame tick
  /// during playback so tracks starting mid-animation join in on time.
  Future<void> checkStarts({
    required List<AudioTrack> tracks,
    required int currentFrameIndex,
  }) async {
    for (final track in tracks) {
      if (track.muted) continue;
      if (track.startFrameIndex != currentFrameIndex) continue;
      final player = _playerFor(track);
      await player.setVolume(track.volume);
      await player.play(DeviceFileSource(track.filePath));
    }
  }

  Future<void> pauseAll() async {
    for (final p in _players.values) {
      await p.pause();
    }
  }

  Future<void> stopAll() async {
    for (final p in _players.values) {
      await p.stop();
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
