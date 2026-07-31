/// Metadata for one layer in the project's layer stack.
/// Layer *structure* (name/visibility/opacity/order) is global — every
/// frame has the same number of layers, matched by index — but each
/// frame stores its own strokes per layer, so you can draw different
/// things on "Layer 1" in frame 3 vs frame 4.
class LayerInfo {
  String name;
  bool visible;
  double opacity;

  LayerInfo({
    required this.name,
    this.visible = true,
    this.opacity = 1.0,
  });

  LayerInfo clone() => LayerInfo(name: name, visible: visible, opacity: opacity);
}
