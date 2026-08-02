import 'package:flutter/material.dart';
import '../models/draw_tool.dart';
import '../models/shape_kind.dart';

class EditorToolbar extends StatelessWidget {
  final Color selectedColor;
  final DrawTool tool;
  final ShapeKind shapeKind;
  final bool shapeFilled;
  final double strokeWidth;
  final bool onionEnabled;
  final bool isPlaying;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<DrawTool> onSelectTool;
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
    required this.shapeKind,
    required this.shapeFilled,
    required this.strokeWidth,
    required this.onionEnabled,
    required this.isPlaying,
    required this.onColorSelected,
    required this.onSelectTool,
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
    return IconButton(
      icon: Icon(icon, color: selected ? Colors.orangeAccent : Colors.white54),
      tooltip: tooltip,
      onPressed: selected ? null : () => onSelectTool(value),
    );
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
                  _toolButton(Icons.edit, DrawTool.pen, 'Pen'),
                  _toolButton(Icons.auto_fix_normal, DrawTool.eraser, 'Eraser'),
                  _toolButton(Icons.format_color_fill, DrawTool.fill, 'Fill bucket'),
                  _toolButton(Icons.text_fields, DrawTool.text, 'Text'),
                  PopupMenuButton<ShapeKind>(
                    tooltip: 'Shape tool',
                    icon: Icon(
                      _shapeIcon(shapeKind),
                      color: shapeSelected ? Colors.orangeAccent : Colors.white54,
                    ),
                    onSelected: onSelectShape,
                    itemBuilder: (context) => ShapeKind.values.map((kind) {
                      return PopupMenuItem(
                        value: kind,
                        child: Row(
                          children: [
                            Icon(_shapeIcon(kind), size: 20),
                            const SizedBox(width: 10),
                            Text(_shapeLabel(kind)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  if (shapeSelected)
                    IconButton(
                      icon: Icon(
                        shapeFilled ? Icons.check_box : Icons.check_box_outline_blank,
                        color: Colors.orangeAccent,
                      ),
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
                      onChanged: (tool == DrawTool.fill || tool == DrawTool.text) ? null : onStrokeWidthChanged,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.undo, color: Colors.white), tooltip: 'Undo', onPressed: onUndo),
                  IconButton(icon: const Icon(Icons.layers_clear, color: Colors.white), tooltip: 'Clear active layer', onPressed: onClearFrame),
                  GestureDetector(
                    onLongPress: onOpenOnionSettings,
                    child: IconButton(
                      icon: Icon(Icons.motion_photos_on, color: onionEnabled ? Colors.orangeAccent : Colors.white38),
                      tooltip: 'Onion skin (long-press for settings)',
                      onPressed: onToggleOnionSkin,
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 30),
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
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Layer: $activeLayerName ($layerCount/$maxLayers)',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more, color: Colors.white38, size: 16),
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
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: palette.map((c) {
                  final selected = c.value == selectedColor.value;
                  return GestureDetector(
                    onTap: () => onColorSelected(c),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.orangeAccent : Colors.white24,
                          width: selected ? 3 : 1,
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
