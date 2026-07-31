import 'package:flutter/material.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../rendering/frame_renderer.dart';
import '../rendering/onion_layer.dart';

/// Renders a [FrameData] (composited across all visible layers) scaled
/// to fit the target [Size]. Optionally overlays onion-skin ghosts -
/// previous/next frames rendered as tinted silhouettes, farthest drawn
/// first so nearer frames (and the current frame itself) sit on top.
class FramePainter extends CustomPainter {
  final FrameData frame;
  final List<LayerInfo> layers;
  final List<OnionLayer> onionLayers;
  final double canvasWidth;
  final double canvasHeight;
  final bool paintBackground;

  FramePainter({
    required this.frame,
    required this.layers,
    this.onionLayers = const [],
    required this.canvasWidth,
    required this.canvasHeight,
    this.paintBackground = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / canvasWidth;
    final scaleY = size.height / canvasHeight;

    if (paintBackground) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    }

    for (final onion in onionLayers) {
      FrameRenderer.paintOnionFrame(
        canvas,
        onion.frame,
        layers,
        scaleX: scaleX,
        scaleY: scaleY,
        opacity: onion.opacity,
        tint: onion.tint,
      );
    }

    FrameRenderer.paintFrame(canvas, frame, layers, scaleX: scaleX, scaleY: scaleY);
  }

  @override
  bool shouldRepaint(covariant FramePainter oldDelegate) => true;
}
