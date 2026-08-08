import 'package:flutter/material.dart';
import '../models/brush_preset.dart';
import '../models/brush_style.dart';
import '../services/brush_preset_service.dart';

/// Bottom-sheet UI for picking a brush style and managing custom saved
/// brush presets (style + color + width bundled under a name).
class BrushPanel extends StatefulWidget {
  final BrushStyle currentStyle;
  final Color currentColor;
  final double currentWidth;
  final ValueChanged<BrushStyle> onSelectStyle;
  final ValueChanged<BrushPreset> onApplyPreset;

  const BrushPanel({
    super.key,
    required this.currentStyle,
    required this.currentColor,
    required this.currentWidth,
    required this.onSelectStyle,
    required this.onApplyPreset,
  });

  @override
  State<BrushPanel> createState() => _BrushPanelState();
}

class _BrushPanelState extends State<BrushPanel> {
  static IconData _iconFor(BrushStyle style) {
    return switch (style) {
      BrushStyle.pencil => Icons.edit,
      BrushStyle.pen => Icons.create,
      BrushStyle.marker => Icons.brush,
      BrushStyle.highlighter => Icons.border_color,
    };
  }

  static String _labelFor(BrushStyle style) {
    return switch (style) {
      BrushStyle.pencil => 'Pencil',
      BrushStyle.pen => 'Pen',
      BrushStyle.marker => 'Marker',
      BrushStyle.highlighter => 'Highlighter',
    };
  }

  static String _describeFor(BrushStyle style) {
    return switch (style) {
      BrushStyle.pencil => 'Thin, slightly translucent',
      BrushStyle.pen => 'Solid, full opacity',
      BrushStyle.marker => 'Bold and a little translucent',
      BrushStyle.highlighter => 'Broad, flat, see-through',
    };
  }

  Future<void> _saveCurrentAsPreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save current brush'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name this brush...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() {
      BrushPresetService.instance.add(BrushPreset(
        name: name.trim(),
        style: widget.currentStyle,
        color: widget.currentColor,
        width: widget.currentWidth,
      ));
    });
  }

  void _deletePreset(int index) {
    setState(() => BrushPresetService.instance.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final presets = BrushPresetService.instance.presets;

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.brush, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text('Brushes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...BrushStyle.values.map((style) {
                    final selected = style == widget.currentStyle;
                    return ListTile(
                      leading: Icon(_iconFor(style), color: selected ? Colors.orangeAccent : Colors.white70),
                      title: Text(_labelFor(style), style: TextStyle(color: selected ? Colors.orangeAccent : Colors.white)),
                      subtitle: Text(_describeFor(style), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      trailing: selected ? const Icon(Icons.check, color: Colors.orangeAccent) : null,
                      onTap: () => widget.onSelectStyle(style),
                    );
                  }),
                  const Divider(color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      presets.isEmpty ? 'No saved brushes yet' : 'Your saved brushes',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                  ...presets.asMap().entries.map((entry) {
                    final index = entry.key;
                    final preset = entry.value;
                    return ListTile(
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      title: Text(preset.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${_labelFor(preset.style)} · width ${preset.width.round()}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Delete brush',
                        onPressed: () => _deletePreset(index),
                      ),
                      onTap: () => widget.onApplyPreset(preset),
                    );
                  }),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saveCurrentAsPreset,
                  icon: const Icon(Icons.add),
                  label: const Text('Save current brush'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
