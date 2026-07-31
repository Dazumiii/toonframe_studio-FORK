import 'dart:ui' as ui;
import '../constants.dart';
import '../models/animation_project.dart';
import '../models/draw_op.dart';
import '../models/frame_data.dart';
import '../rendering/frame_renderer.dart';

/// Merges the layer at [index] "down" into the layer below it
/// (`index - 1`), one frame at a time.
///
/// This is destructive by design (same as merging layers in any other
/// drawing app): each frame's content on both layers - including each
/// layer's own opacity/visibility at the time of the merge - is baked
/// into a single flattened raster image, which becomes the new content
/// of the layer below. The upper layer is then removed from the
/// project entirely. Undo history for strokes drawn before the merge
/// is lost for that layer, which is why the UI should confirm before
/// calling this.
class LayerMergeService {
  /// Returns false (and does nothing) if there's no layer below
  /// [index] to merge into.
  static Future<bool> mergeDown(AnimationProject project, int index) async {
    if (index <= 0 || index >= project.layers.length) return false;
    final belowIndex = index - 1;

    for (final frame in project.frames) {
      final tempFrame = FrameData.fromLayers([
        List.of(frame.layerOps[belowIndex]),
        List.of(frame.layerOps[index]),
      ]);
      final tempLayers = [project.layers[belowIndex], project.layers[index]];

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Deliberately no background fill here - unlike export/thumbnail
      // rendering, this raster becomes one layer among others, so
      // anything not drawn on either merged layer must stay
      // transparent, letting layers further down show through.
      FrameRenderer.paintFrame(canvas, tempFrame, tempLayers, scaleX: 1, scaleY: 1);
      final picture = recorder.endRecording();
      final mergedImage = await picture.toImage(kCanvasWidth.toInt(), kCanvasHeight.toInt());

      frame.layerOps[belowIndex]
        ..clear()
        ..add(ImageDrawOp(mergedImage));
    }

    project.layers.removeAt(index);
    for (final frame in project.frames) {
      frame.removeLayerAt(index);
    }
    return true;
  }
}
