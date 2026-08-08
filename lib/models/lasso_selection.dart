import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'draw_op.dart';

/// A floating, in-progress lasso selection: the rasterized pixels the
/// user lassoed out of the active layer, plus how far they've moved,
/// scaled, and rotated it so far.
///
/// This is transient editing state, not part of a frame's permanent
/// history - it only becomes real (an [ImageDrawOp] baked onto the
/// layer) once the user confirms the move. Cancelling restores
/// [originalLayerOps] exactly as they were before the lasso cut.
class LassoSelection {
  /// Full canvas-resolution image: just the lassoed pixels, everything
  /// else transparent.
  final ui.Image selectionImage;

  /// The lasso path's own bounding-box center, in canvas coordinates -
  /// the pivot that scale and rotation are applied around.
  final Offset pivot;

  /// The active layer's ops exactly as they were before this lasso cut
  /// them out, so Cancel can restore them precisely.
  final List<DrawOp> originalLayerOps;

  Offset translation;
  double scale;
  double rotation;

  LassoSelection({
    required this.selectionImage,
    required this.pivot,
    required this.originalLayerOps,
    this.translation = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}
