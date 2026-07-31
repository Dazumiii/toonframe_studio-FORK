import 'package:flutter/material.dart';
import '../models/frame_data.dart';

/// One "ghost" frame to render behind the current frame during onion
/// skinning - which frame's content to show, tinted a solid color
/// (silhouette-style, like most animation apps) at a given opacity.
class OnionLayer {
  final FrameData frame;
  final Color tint;
  final double opacity;

  const OnionLayer({required this.frame, required this.tint, required this.opacity});
}
