import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/brush_style.dart';
import '../models/draw_op.dart';
import '../models/draw_tool.dart';
import '../models/frame_data.dart';
import '../models/lasso_selection.dart';
import '../models/layer_info.dart';
import '../models/shape_kind.dart';
import '../models/stroke.dart';
import '../rendering/onion_layer.dart';
import 'frame_painter.dart';

/// The main drawing surface.
/// - [DrawTool.pen]/[DrawTool.eraser]: pan gestures build up a
///   freehand [Stroke], rendered per [brushStyle] for pen strokes.
/// - [DrawTool.shape]: drag from a start point to an end point;
///   released, it becomes a [ShapeDrawOp] of [shapeKind].
/// - [DrawTool.fill]: a single tap reports the canvas-space point via
///   [onFillTap].
/// - [DrawTool.text]: a single tap reports the canvas-space point via
///   [onTextTap] (the parent shows a dialog to enter the text itself).
/// - [DrawTool.lasso]: drag a freeform loop; released, it reports the
///   path via [onLassoFinished]. Once [lassoSelection] is non-null,
///   pan/pinch gestures move/scale/rotate it instead, reported via
///   [onLassoTransformChanged].
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
  final BrushStyle brushStyle;
  final ShapeKind shapeKind;
  final bool shapeFilled;
  final LassoSelection? lassoSelection;
  final ValueChanged<Stroke> onStrokeFinished;
  final ValueChanged<Offset> onFillTap;
  final ValueChanged<ShapeDrawOp> onShapeFinished;
  final ValueChanged<Offset> onTextTap;
  final ValueChanged<List<Offset>> onLassoFinished;
  final void Function(Offset translation, double scale, double rotation) onLassoTransformChanged;

  const DrawingCanvas({
    super.key,
    required this.frame,
    required this.layers,
    required this.onionLayers,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    required this.brushStyle,
    required this.shapeKind,
    required this.shapeFilled,
    required this.lassoSelection,
    required this.onStrokeFinished,
    required this.onFillTap,
    required this.onShapeFinished,
    required this.onTextTap,
    required this.onLassoFinished,
    required this.onLassoTransformChanged,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<Offset> _currentPoints = [];
  Offset? _shapeStart;
  Offset? _shapeEnd;
  List<Offset> _lassoPoints = [];

  Offset? _gestureStartFocalPoint;
  Offset? _gestureStartTranslation;
  double? _gestureStartScale;
  double? _gestureStartRotation;

  bool get _isShapeTool => widget.tool == DrawTool.shape;
  bool get _isFillTool => widget.tool == DrawTool.fill;
  bool get _isTextTool => widget.tool == DrawTool.text;
  bool get _isLassoTool => widget.tool == DrawTool.lasso;
  bool get _hasFloatingSelection => widget.lassoSelection != null;

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
      } else if (_isLassoTool) {
        _lassoPoints = [point];
      } else {
        _currentPoints = [point];
      }
    });
  }

  void _handlePanUpdate(Offset point) {
    setState(() {
      if (_isShapeTool) {
        _shapeEnd = point;
      } else if (_isLassoTool) {
        _lassoPoints = List.of(_lassoPoints)..add(point);
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
    } else if (_isLassoTool) {
      if (_lassoPoints.length >= 3) {
        widget.onLassoFinished(_lassoPoints);
      }
      setState(() => _lassoPoints = []);
    } else {
      if (_currentPoints.isNotEmpty) {
        widget.onStrokeFinished(Stroke(
          points: _currentPoints,
          color: widget.color,
          width: widget.strokeWidth,
          isEraser: widget.tool == DrawTool.eraser,
          brushStyle: widget.brushStyle,
        ));
      }
      setState(() => _currentPoints = []);
    }
  }

  void _handleSelectionScaleStart(ScaleStartDetails details) {
    final selection = widget.lassoSelection;
    if (selection == null) return;
    _gestureStartFocalPoint = details.localFocalPoint;
    _gestureStartTranslation = selection.translation;
    _gestureStartScale = selection.scale;
    _gestureStartRotation = selection.rotation;
  }

  void _handleSelectionScaleUpdate(ScaleUpdateDetails details, Size size) {
    final startFocal = _gestureStartFocalPoint;
    final startTranslation = _gestureStartTranslation;
    final startScale = _gestureStartScale;
    final startRotation = _gestureStartRotation;
    if (startFocal == null || startTranslation == null || startScale == null || startRotation == null) {
      return;
    }
    final sx = kCanvasWidth / size.width;
    final sy = kCanvasHeight / size.height;
    final screenDelta = details.localFocalPoint - startFocal;
    final canvasDelta = Offset(screenDelta.dx * sx, screenDelta.dy * sy);

    widget.onLassoTransformChanged(
      startTranslation + canvasDelta,
      (startScale * details.scale).clamp(0.1, 8.0),
      startRotation + details.rotation,
    );
  }

  void _handleSelectionScaleEnd(ScaleEndDetails details) {
    _gestureStartFocalPoint = null;
    _gestureStartTranslation = null;
    _gestureStartScale = null;
    _gestureStartRotation = null;
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
              brushStyle: widget.brushStyle,
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

            return ClipRect(
              child: Stack(
                children: [
                  GestureDetector(
                    onTapUp: _hasFloatingSelection || !isTapTool
                        ? null
                        : (details) {
                            final point = _toCanvasCoords(details.localPosition, size);
                            if (_isFillTool) {
                              widget.onFillTap(point);
                            } else {
                              widget.onTextTap(point);
                            }
                          },
                    onPanStart: _hasFloatingSelection || isTapTool
                        ? null
                        : (details) => _handlePanStart(_toCanvasCoords(details.localPosition, size)),
                    onPanUpdate: _hasFloatingSelection || isTapTool
                        ? null
                        : (details) => _handlePanUpdate(_toCanvasCoords(details.localPosition, size)),
                    onPanEnd: _hasFloatingSelection || isTapTool ? null : (_) => _handlePanEnd(),
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
                  if (_lassoPoints.length > 1)
                    IgnorePointer(
                      child: CustomPaint(
                        size: size,
                        painter: _LassoPathPreviewPainter(
                          points: _lassoPoints,
                          canvasWidth: kCanvasWidth,
                          canvasHeight: kCanvasHeight,
                        ),
                      ),
                    ),
                  if (_hasFloatingSelection)
                    Positioned.fill(
                      child: GestureDetector(
                        onScaleStart: _handleSelectionScaleStart,
                        onScaleUpdate: (details) => _handleSelectionScaleUpdate(details, size),
                        onScaleEnd: _handleSelectionScaleEnd,
                        child: CustomPaint(
                          size: size,
                          painter: _LassoSelectionPainter(
                            selection: widget.lassoSelection!,
                            canvasWidth: kCanvasWidth,
                            canvasHeight: kCanvasHeight,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dashed, translucent-filled preview of an in-progress lasso path,
/// drawn while the user is still dragging it out.
class _LassoPathPreviewPainter extends CustomPainter {
  final List<Offset> points;
  final double canvasWidth;
  final double canvasHeight;

  _LassoPathPreviewPainter({
    required this.points,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final sx = size.width / canvasWidth;
    final sy = size.height / canvasHeight;

    final path = Path()..moveTo(points[0].dx * sx, points[0].dy * sy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * sx, points[i].dy * sy);
    }

    canvas.drawPath(path, Paint()..color = Colors.orangeAccent.withOpacity(0.15));
    _drawDashedPath(canvas, path, Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LassoPathPreviewPainter oldDelegate) => true;
}

/// Live view of a floating lasso selection, redrawn every gesture tick
/// with the current translate/rotate/scale applied directly at paint
/// time (no re-rasterizing while dragging - that only happens once, on
/// commit, via LassoService.renderTransformed).
class _LassoSelectionPainter extends CustomPainter {
  final LassoSelection selection;
  final double canvasWidth;
  final double canvasHeight;

  _LassoSelectionPainter({
    required this.selection,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / canvasWidth;
    final sy = size.height / canvasHeight;

    canvas.save();
    canvas.scale(sx, sy);
    canvas.translate(
      selection.pivot.dx + selection.translation.dx,
      selection.pivot.dy + selection.translation.dy,
    );
    canvas.rotate(selection.rotation);
    canvas.scale(selection.scale);
    canvas.translate(-selection.pivot.dx, -selection.pivot.dy);
    canvas.drawImage(selection.selectionImage, Offset.zero, Paint());
    canvas.restore();

    // Small marker at the pivot so the transform's center of rotation
    // is visible while dragging.
    final center = Offset(
      (selection.pivot.dx + selection.translation.dx) * sx,
      (selection.pivot.dy + selection.translation.dy) * sy,
    );
    canvas.drawCircle(center, 6, Paint()..color = Colors.orangeAccent);
  }

  @override
  bool shouldRepaint(covariant _LassoSelectionPainter oldDelegate) => true;
}
