import 'draw_op.dart';

/// One frame of the flipbook. Draw operations are grouped per layer -
/// `layerOps[i]` holds the ops (strokes and fills, in chronological
/// order) on layer `i` (matched by index against the project's
/// `List<LayerInfo>`).
class FrameData {
  final List<List<DrawOp>> layerOps;

  FrameData({int layerCount = 1})
      : layerOps = List.generate(layerCount, (_) => <DrawOp>[]);

  FrameData._raw(this.layerOps);

  /// Build a frame directly from existing per-layer op lists.
  factory FrameData.fromLayers(List<List<DrawOp>> layerOps) =>
      FrameData._raw(layerOps);

  /// Deep-ish copy so edits to the duplicate never mutate the
  /// original. Stroke points are copied; fill images (immutable) are
  /// shared by reference.
  FrameData clone() => FrameData._raw(
        layerOps.map((ops) => ops.map(_cloneOp).toList()).toList(),
      );

  static DrawOp _cloneOp(DrawOp op) {
    if (op is StrokeDrawOp) {
      return StrokeDrawOp(op.stroke.copyWith(points: List.of(op.stroke.points)));
    }
    if (op is FillDrawOp) {
      return FillDrawOp(op.image);
    }
    if (op is ImageDrawOp) {
      return ImageDrawOp(op.image);
    }
    if (op is ShapeDrawOp) {
      return op; // fully immutable (all fields final, value types) - safe to share
    }
    if (op is TextDrawOp) {
      return op; // fully immutable (all fields final, value types) - safe to share
    }
    throw StateError('Unknown DrawOp type: $op');
  }

  /// Inserts a new empty layer's op list. Called whenever a layer is
  /// added to the project, to keep every frame in sync.
  void addLayer({int? atIndex}) {
    if (atIndex == null) {
      layerOps.add(<DrawOp>[]);
    } else {
      layerOps.insert(atIndex, <DrawOp>[]);
    }
  }

  void removeLayerAt(int index) {
    if (index >= 0 && index < layerOps.length) {
      layerOps.removeAt(index);
    }
  }

  void moveLayer(int oldIndex, int newIndex) {
    final ops = layerOps.removeAt(oldIndex);
    layerOps.insert(newIndex, ops);
  }
}
