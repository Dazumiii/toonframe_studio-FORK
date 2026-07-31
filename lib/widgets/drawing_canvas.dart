import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/draw_op.dart';
import '../models/draw_tool.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../models/stroke.dart';
import '../rendering/onion_layer.dart';
import 'frame_painter.dart';

/// The main drawing surface. For [DrawTool.pen]/[DrawTool.eraser] it
/// captures pan gestures as strokes; for [DrawTool.fill] it captures a
/// single tap and reports the canvas-space point via [onFillTap].
/// Coordinates are converted from screen space into the fixed internal
/// canvas space. New strokes are always added to the active layer,
/// chosen by the parent.
class DrawingCanvas extends StatefulWidget {
  final FrameData frame;
  final List<LayerInfo> layers;
  final List<OnionLayer> onionLayers;
  final Color color;
  final double strokeWidth;
  final DrawTool tool;
  final ValueChanged<Stroke> onStrokeFinished;
  final ValueChanged<Offset> onFillTap;

  const DrawingCanvas({
    super.key,
    required this.frame,
    required this.layers,
    required this.onionLayers,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    required this.onStrokeFinished,
    required this.onFillTap,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<Offset> _currentPoints = [];

  Offset _toCanvasCoords(Offset local, Size size) {
    final sx = kCanvasWidth / size.width;
    final sy = kCanvasHeight / size.height;
    return Offset(local.dx * sx, local.dy * sy);
  }

  @override
  Widget build(BuildContext context) {
    final isFillTool = widget.tool == DrawTool.fill;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: AspectRatio(
        aspectRatio: kCanvasWidth / kCanvasHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onTapUp: isFillTool
                  ? (details) => widget.onFillTap(_toCanvasCoords(details.localPosition, size))
                  : null,
              onPanStart: isFillTool
                  ? null
                  : (details) {
                      setState(() {
                        _currentPoints = [_toCanvasCoords(details.localPosition, size)];
                      });
                    },
              onPanUpdate: isFillTool
                  ? null
                  : (details) {
                      setState(() {
                        _currentPoints = List.of(_currentPoints)
                          ..add(_toCanvasCoords(details.localPosition, size));
                      });
                    },
              onPanEnd: isFillTool
                  ? null
                  : (_) {
                      if (_currentPoints.isNotEmpty) {
                        widget.onStrokeFinished(Stroke(
                          points: _currentPoints,
                          color: widget.color,
                          width: widget.strokeWidth,
                          isEraser: widget.tool == DrawTool.eraser,
                        ));
                      }
                      setState(() => _currentPoints = []);
                    },
              child: ClipRect(
                child: CustomPaint(
                  size: size,
                  painter: FramePainter(
                    frame: widget.frame,
                    layers: widget.layers,
                    onionLayers: widget.onionLayers,
                    canvasWidth: kCanvasWidth,
                    canvasHeight: kCanvasHeight,
                  ),
                  foregroundPainter: _currentPoints.isEmpty
                      ? null
                      : FramePainter(
                          frame: FrameData.fromLayers([
                            [
                              StrokeDrawOp(Stroke(
                                points: _currentPoints,
                                color: widget.color,
                                width: widget.strokeWidth,
                                isEraser: widget.tool == DrawTool.eraser,
                              )),
                            ],
                          ]),
                          layers: [LayerInfo(name: 'preview')],
                          canvasWidth: kCanvasWidth,
                          canvasHeight: kCanvasHeight,
                          paintBackground: false,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
