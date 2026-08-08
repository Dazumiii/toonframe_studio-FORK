import 'package:flutter/material.dart';
import '../models/brush_style.dart';
import '../models/draw_tool.dart';
import '../models/shape_kind.dart';

class EditorToolbar extends StatelessWidget {
  final Color selectedColor;
  final DrawTool tool;
  final BrushStyle brushStyle;
  final ShapeKind shapeKind;
  final bool shapeFilled;
  final double strokeWidth;
  final bool onionEnabled;
  final bool isPlaying;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<DrawTool> onSelectTool;
  final VoidCallback onOpenBrushPanel;
  final ValueChanged<ShapeKind> onSelectShape;
  final VoidCallback onToggleShapeFilled;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onToggleOnionSkin;
  final VoidCallback onOpenOnionSettings;
  final VoidCallback onUndo;
  final VoidCallback onClearFrame;
  final VoidCallback onTogglePlay;
  final VoidCallback onOpenLayers;
  final int layerCount;
  final int maxLayers;
  final String activeLayerName;

  const EditorToolbar({
    super.key,
    required this.selectedColor,
    required this.tool,
    required this.brushStyle,
    required this.shapeKind,
    required this.shapeFilled,
    required this.strokeWidth,
    required this.onionEnabled,
    required this.isPlaying,
    required this.onColorSelected,
    required this.onSelectTool,
    required this.onOpenBrushPanel,
    required this.onSelectShape,
    required this.onToggleShapeFilled,
    required this.onStrokeWidthChanged,
    required this.onToggleOnionSkin,
    required this.onOpenOnionSettings,
    required this.onUndo,
    required this.onClearFrame,
    required this.onTogglePlay,
    required this.onOpenLayers,
    required this.layerCount,
    required this.maxLayers,
    required this.activeLayerName,
  });

  static const List<Color> palette = [
    Colors.black, Colors.white, Colors.red, Colors.orange, Colors.yellow,
    Colors.green, Colors.blue, Colors.purple, Colors.brown, Colors.pink,
  ];

  Widget _toolButton(IconData icon, DrawTool value, String tooltip) {
    final selected = tool == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: 26),
        style: IconButton.styleFrom(
          foregroundColor: selected ? Colors.black : Colors.white54,
          backgroundColor: selected ? Colors.orangeAccent : Colors.transparent,
          minimumSize: const Size(52, 52),
        ),
        tooltip: tooltip,
        onPressed: selected ? null : () => onSelectTool(value),
      ),
    );
  }

  Widget _penButton() {
    final selected = tool == DrawTool.pen;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onLongPress: onOpenBrushPanel,
        child: IconButton(
          icon: Icon(_brushIconFor(brushStyle), size: 26),
          style: IconButton.styleFrom(
            foregroundColor: selected ? Colors.black : Colors.white54,
            backgroundColor: selected ? Colors.orangeAccent : Colors.transparent,
            minimumSize: const Size(52, 52),
          ),
          tooltip: '${_brushLabelFor(brushStyle)} (long-press to change brush)',
          onPressed: selected ? null : () => onSelectTool(DrawTool.pen),
        ),
      ),
    );
  }

  static IconData _brushIconFor(BrushStyle style) {
    return switch (style) {
      BrushStyle.pencil => Icons.edit,
      BrushStyle.pen => Icons.create,
      BrushStyle.marker => Icons.brush,
      BrushStyle.highlighter => Icons.border_color,
    };
  }

  static String _brushLabelFor(BrushStyle style) {
    return switch (style) {
      BrushStyle.pencil => 'Pencil',
      BrushStyle.pen => 'Pen',
      BrushStyle.marker => 'Marker',
      BrushStyle.highlighter => 'Highlighter',
    };
  }

  static IconData _shapeIcon(ShapeKind kind) {
    return switch (kind) {
      ShapeKind.rectangle => Icons.crop_square,
      ShapeKind.ellipse => Icons.circle_outlined,
      ShapeKind.line => Icons.horizontal_rule,
    };
  }

  static String _shapeLabel(ShapeKind kind) {
    return switch (kind) {
      ShapeKind.rectangle => 'Rectangle',
      ShapeKind.ellipse => 'Ellipse',
      ShapeKind.line => 'Line',
    };
  }

  @override
  Widget build(BuildContext context) {
    final shapeSelected = tool == DrawTool.shape;

    return Container(
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _penButton(),
                  _toolButton(Icons.auto_fix_normal, DrawTool.eraser, 'Eraser'),
                  _toolButton(Icons.format_color_fill, DrawTool.fill, 'Fill bucket'),
                  _toolButton(Icons.gesture, DrawTool.lasso, 'Lasso select'),
                  _toolButton(Icons.text_fields, DrawTool.text, 'Text'),
                  PopupMenuButton<ShapeKind>(
                    tooltip: 'Shape tool',
                    icon: Icon(
                      _shapeIcon(shapeKind),
                      size: 26,
                      color: shapeSelected ? Colors.orangeAccent : Colors.white54,
                    ),
                    iconSize: 26,
                    padding: const EdgeInsets.all(14),
                    onSelected: onSelectShape,
                    itemBuilder: (context) => ShapeKind.values.map((kind) {
                      return PopupMenuItem(
                        value: kind,
                        child: Row(
                          children: [
                            Icon(_shapeIcon(kind), size: 22),
                            const SizedBox(width: 12),
                            Text(_shapeLabel(kind), style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  if (shapeSelected)
                    IconButton(
                      icon: Icon(
                        shapeFilled ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 26,
                        color: Colors.orangeAccent,
                      ),
                      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                      tooltip: shapeFilled ? 'Filled' : 'Outline',
                      onPressed: onToggleShapeFilled,
                    ),
                  SizedBox(
                    width: 140,
                    child: Slider(
                      value: strokeWidth,
                      min: 1,
                      max: 40,
                      activeColor: Colors.orangeAccent,
                      onChanged: (tool == DrawTool.fill || tool == DrawTool.text || tool == DrawTool.lasso) ? null : onStrokeWidthChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.undo, color: Colors.white, size: 26),
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                    tooltip: 'Undo',
                    onPressed: onUndo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.layers_clear, color: Colors.white, size: 26),
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                    tooltip: 'Clear active layer',
                    onPressed: onClearFrame,
                  ),
                  GestureDetector(
                    onLongPress: onOpenOnionSettings,
                    child: IconButton(
                      icon: Icon(Icons.motion_photos_on, size: 26, color: onionEnabled ? Colors.orangeAccent : Colors.white38),
                      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                      tooltip: 'Onion skin (long-press for settings)',
                      onPressed: onToggleOnionSkin,
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 34),
                    style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                    tooltip: 'Play',
                    onPressed: onTogglePlay,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: onOpenLayers,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers, color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            'Layer: $activeLayerName ($layerCount/$maxLayers)',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more, color: Colors.white38, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (tool == DrawTool.fill) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.format_color_fill, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    const Text('Tap a region to fill', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  if (shapeSelected) ...[
                    const SizedBox(width: 12),
                    Icon(_shapeIcon(shapeKind), color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Text('Drag to draw a ${_shapeLabel(shapeKind).toLowerCase()}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  if (tool == DrawTool.text) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.text_fields, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    const Text('Tap to place text', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  if (tool == DrawTool.pen) ...[
                    const SizedBox(width: 12),
                    Icon(_brushIconFor(brushStyle), color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Text('${_brushLabelFor(brushStyle)} - long-press the pen icon to change',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  if (tool == DrawTool.lasso) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.gesture, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    const Text('Drag a loop to select, then move/pinch/twist it',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: palette.map((c) {
                  final selected = c.value == selectedColor.value;
                  return GestureDetector(
                    onTap: () => onColorSelected(c),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.orangeAccent : Colors.white24,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
