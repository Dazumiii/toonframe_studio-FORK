import 'audio_track.dart';
import 'frame_data.dart';
import 'layer_info.dart';

class AnimationProject {
  String name;
  List<LayerInfo> layers;
  List<FrameData> frames;
  List<AudioTrack> audioTracks;
  int fps;

  AnimationProject({required this.name, this.fps = 8})
      : layers = [LayerInfo(name: 'Layer 1')],
        frames = [FrameData(layerCount: 1)],
        audioTracks = [];

  /// Creates a new blank frame that already matches the current layer
  /// stack (same number of layers as every other frame).
  FrameData newFrame() => FrameData(layerCount: layers.length);

  /// Adds a new layer, unless [maxLayers] is given and the project is
  /// already at that limit (used to enforce the layer soft cap, see
  /// kMaxLayers). Returns whether a layer was added.
  bool addLayer({int? maxLayers}) {
    if (maxLayers != null && layers.length >= maxLayers) return false;
    layers.add(LayerInfo(name: 'Layer ${layers.length + 1}'));
    for (final frame in frames) {
      frame.addLayer();
    }
    return true;
  }

  void removeLayer(int index) {
    if (layers.length <= 1) return;
    layers.removeAt(index);
    for (final frame in frames) {
      frame.removeLayerAt(index);
    }
  }

  void reorderLayer(int oldIndex, int newIndex) {
    final layer = layers.removeAt(oldIndex);
    layers.insert(newIndex, layer);
    for (final frame in frames) {
      frame.moveLayer(oldIndex, newIndex);
    }
  }

  /// Finds the dedicated "Reference" layer used for rotoscoping
  /// (imported photos/video frames), creating it at the bottom of the
  /// stack - low opacity by default - if it doesn't exist yet.
  /// Returns the layer's index and whether it was just created (if it
  /// was, every existing layer's index shifted up by one, since the
  /// new layer is inserted at the bottom).
  ({int index, bool created}) ensureReferenceLayer() {
    final existing = layers.indexWhere((l) => l.name == 'Reference');
    if (existing != -1) return (index: existing, created: false);

    layers.insert(0, LayerInfo(name: 'Reference', opacity: 0.5));
    for (final frame in frames) {
      frame.addLayer(atIndex: 0);
    }
    return (index: 0, created: true);
  }
}
