/// User-configurable settings for onion skinning.
class OnionSkinSettings {
  bool enabled;

  /// How many previous frames to ghost (tinted red/warm).
  int framesBefore;

  /// How many upcoming frames to ghost (tinted blue/cool).
  int framesAfter;

  /// Opacity used for the frame immediately adjacent to the current
  /// one; frames further away fade out proportionally more (opacity /
  /// distance), so the effect naturally tapers off.
  double opacity;

  OnionSkinSettings({
    this.enabled = true,
    this.framesBefore = 1,
    this.framesAfter = 1,
    this.opacity = 0.35,
  });
}
