import '../models/brush_preset.dart';

/// Holds the user's custom brush presets for the app's current run.
///
/// This is **in-memory only** - there's no local persistence (e.g. the
/// `shared_preferences` package, or a small on-disk JSON file) wired
/// up, so saved brushes disappear when the app restarts. That's a
/// deliberate scope line, not an oversight: adding real persistence is
/// low-risk (shared_preferences is about as mainstream as Flutter
/// packages get) but it's still one more thing to wire up, and this
/// class is written so that swapping in real storage later only means
/// changing what's inside these three methods - nothing else in the
/// app needs to know how presets are stored.
class BrushPresetService {
  BrushPresetService._();
  static final BrushPresetService instance = BrushPresetService._();

  final List<BrushPreset> presets = [];

  void add(BrushPreset preset) => presets.add(preset);

  void removeAt(int index) {
    if (index >= 0 && index < presets.length) {
      presets.removeAt(index);
    }
  }
}
