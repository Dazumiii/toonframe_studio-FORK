/// What an [AudioTrack] is for - purely descriptive (affects the icon
/// shown in the audio panel), doesn't change playback behavior.
enum AudioTrackType { music, sfx, voiceover }

/// One audio clip attached to the project: background music, a sound
/// effect, or a recorded voiceover. Multiple tracks can play at once,
/// each starting at its own point in the timeline.
class AudioTrack {
  String name;
  final String filePath;
  final AudioTrackType type;
  double volume; // 0.0 - 1.0
  bool muted;

  /// Which timeline frame this track starts playing at. 0 = plays
  /// from the very start of the animation loop.
  int startFrameIndex;

  AudioTrack({
    required this.name,
    required this.filePath,
    required this.type,
    this.volume = 1.0,
    this.muted = false,
    this.startFrameIndex = 0,
  });
}
