import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/draw_op.dart';
import '../models/draw_tool.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import '../models/shape_kind.dart';
import '../models/stroke.dart';
import '../rendering/onion_layer.dart';
import 'frame_painter.dart';

/// The main drawing surface.
/// - [DrawTool.pen]/[DrawTool.eraser]: pan gestures build up a
///   freehand [Stroke].
/// - [DrawTool.shape]: drag from a start point to an end point;
///   released, it becomes a [ShapeDrawOp] of [shapeKind].
/// - [DrawTool.fill]: a single tap reports the canvas-space point via
///   [onFillTap].
/// - [DrawTool.text]: a single tap reports the canvas-space point via
///   [onTextTap] (the parent shows a dialog to enter the text itself).
///
/// Coordinates are converted from screen space into the fixed internal
/// canvas space. New strokes/shapes are always added to the active
/// layer, chosen by the parent.
class DrawingCanvas extends StatefulWidget {
  final FrameData frame;
  final List<LayerInfo> layers;
  final List<OnionLayer> onionLayers;
  final Color color;
  final double strokeWidth;
  final DrawTool tool;
  final ShapeKind shapeKind;
  final bool shapeFilled;
  final ValueChanged<Stroke> onStrokeFinished;
  final ValueChanged<Offset> onFillTap;
  final ValueChanged<ShapeDrawOp> onShapeFinished;
  final ValueChanged<Offset> onTextTap;

  const DrawingCanvas({
    super.key,
    required this.frame,
    required this.layers,
    required this.onionLayers,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    required this.shapeKind,
    required this.shapeFilled,
    required this.onStrokeFinished,
    required this.onFillTap,
    required this.onShapeFinished,
    required this.onTextTap,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<Offset> _currentPoints = [];
  Offset? _shapeStart;
  Offset? _shapeEnd;

  bool get _isShapeTool => widget.tool == DrawTool.shape;
  bool get _isFillTool => widget.tool == DrawTool.fill;
  bool get _isTextTool => widget.tool == DrawTool.text;

  Offset _toCanvasCoords(Offset local, Size size) {
    final sx = kCanvasWidth / size.width;
    final sy = kCanvasHeight / size.height;
    return Offset(local.dx * sx, local.dy * sy);
  }

  void _handlePanStart(Offset point) {
    setState(() {
      if (_isShapeTool) {
        _shapeStart = point;
        _shapeEnd = point;
      } else {
        _currentPoints = [point];
      }
    });
  }

  void _handlePanUpdate(Offset point) {
    setState(() {
      if (_isShapeTool) {
        _shapeEnd = point;
      } else {
        _currentPoints = List.of(_currentPoints)..add(point);
      }
    });
  }

  void _handlePanEnd() {
    if (_isShapeTool) {
      final start = _shapeStart;
      final end = _shapeEnd;
      if (start != null && end != null && start != end) {
        widget.onShapeFinished(ShapeDrawOp(
          kind: widget.shapeKind,
          start: start,
          end: end,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
          filled: widget.shapeFilled,
        ));
      }
      setState(() {
        _shapeStart = null;
        _shapeEnd = null;
      });
    } else {
      if (_currentPoints.isNotEmpty) {
        widget.onStrokeFinished(Stroke(
          points: _currentPoints,
          color: widget.color,
          width: widget.strokeWidth,
          isEraser: widget.tool == DrawTool.eraser,
        ));
      }
      setState(() => _currentPoints = []);
    }
  }

  FramePainter? _buildForegroundPainter() {
    if (_currentPoints.isNotEmpty) {
      return FramePainter(
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
      );
    }
    if (_shapeStart != null && _shapeEnd != null) {
      return FramePainter(
        frame: FrameData.fromLayers([
          [
            ShapeDrawOp(
              kind: widget.shapeKind,
              start: _shapeStart!,
              end: _shapeEnd!,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
              filled: widget.shapeFilled,
            ),
          ],
        ]),
        layers: [LayerInfo(name: 'preview')],
        canvasWidth: kCanvasWidth,
        canvasHeight: kCanvasHeight,
        paintBackground: false,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
            final isTapTool = _isFillTool || _isTextTool;
            return GestureDetector(
              onTapUp: isTapTool
                  ? (details) {
                      final point = _toCanvasCoords(details.localPosition, size);
                      if (_isFillTool) {
                        widget.onFillTap(point);
                      } else {
                        widget.onTextTap(point);
                      }
                    }
                  : null,
              onPanStart: isTapTool
                  ? null
                  : (details) => _handlePanStart(_toCanvasCoords(details.localPosition, size)),
              onPanUpdate: isTapTool
                  ? null
                  : (details) => _handlePanUpdate(_toCanvasCoords(details.localPosition, size)),
              onPanEnd: isTapTool ? null : (_) => _handlePanEnd(),
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
                  foregroundPainter: _buildForegroundPainter(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
