import 'package:flutter/material.dart';
import '../models/animation_project.dart';

/// Bottom-sheet UI for managing the project's layer stack.
/// Layers are shown topmost-first (matching how most drawing apps list
/// them), even though they're stored bottom-first internally.
///
/// This widget doesn't decide whether adding a layer is allowed (the
/// soft cap in [kMaxLayers]) or perform the merge itself - it just
/// asks the parent via [onAddLayerRequested] / [onMergeDownRequested]
/// and refreshes itself afterward. That keeps that logic in one place
/// (the editor screen) instead of duplicated here.
class LayersPanel extends StatefulWidget {
  final AnimationProject project;
  final int activeLayerIndex;
  final int maxLayers;
  final ValueChanged<int> onSelectLayer;
  final VoidCallback onAddLayerRequested;
  final Future<void> Function(int index) onMergeDownRequested;

  /// Called after any mutation so the parent screen (which owns the
  /// canvas/timeline showing this same data) can rebuild.
  final VoidCallback onChanged;

  const LayersPanel({
    super.key,
    required this.project,
    required this.activeLayerIndex,
    required this.maxLayers,
    required this.onSelectLayer,
    required this.onAddLayerRequested,
    required this.onMergeDownRequested,
    required this.onChanged,
  });

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  bool _merging = false;

  void _notify() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.project.layers;
    final atLimit = layers.length >= widget.maxLayers;

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 460),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Text('Layers',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(
                    '${layers.length}/${widget.maxLayers}',
                    style: TextStyle(color: atLimit ? Colors.orangeAccent : Colors.white38, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.orangeAccent),
                    tooltip: 'Add layer',
                    onPressed: () {
                      widget.onAddLayerRequested();
                      widget.onSelectLayer(widget.project.layers.length - 1);
                      _notify();
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: layers.length,
                onReorder: (oldDisplayIndex, newDisplayIndex) {
                  final n = layers.length;
                  final oldIndex = n - 1 - oldDisplayIndex;
                  final adjustedNewDisplay =
                      newDisplayIndex > oldDisplayIndex ? newDisplayIndex - 1 : newDisplayIndex;
                  final newIndex = n - 1 - adjustedNewDisplay;
                  widget.project.reorderLayer(oldIndex, newIndex);
                  _notify();
                },
                itemBuilder: (context, displayIndex) {
                  final index = layers.length - 1 - displayIndex;
                  final layer = layers[index];
                  final selected = index == widget.activeLayerIndex;
                  final canMergeDown = index > 0;

                  return Container(
                    key: ObjectKey(layer),
                    color: selected ? Colors.orangeAccent.withOpacity(0.14) : Colors.transparent,
                    child: ListTile(
                      onTap: () {
                        widget.onSelectLayer(index);
                        _notify();
                      },
                      leading: IconButton(
                        icon: Icon(
                          layer.visible ? Icons.visibility : Icons.visibility_off,
                          color: layer.visible ? Colors.white : Colors.white38,
                        ),
                        tooltip: 'Toggle visibility',
                        onPressed: () {
                          layer.visible = !layer.visible;
                          _notify();
                        },
                      ),
                      title: Text(
                        layer.name,
                        style: TextStyle(color: selected ? Colors.orangeAccent : Colors.white),
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.opacity, size: 14, color: Colors.white38),
                          Expanded(
                            child: Slider(
                              value: layer.opacity,
                              activeColor: Colors.orangeAccent,
                              onChanged: (v) {
                                layer.opacity = v;
                                _notify();
                              },
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canMergeDown)
                            IconButton(
                              icon: const Icon(Icons.call_merge, color: Colors.white70),
                              tooltip: 'Merge down into layer below',
                              onPressed: _merging
                                  ? null
                                  : () async {
                                      setState(() => _merging = true);
                                      await widget.onMergeDownRequested(index);
                                      if (mounted) setState(() => _merging = false);
                                      _notify();
                                    },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Delete layer',
                            onPressed: layers.length <= 1
                                ? null
                                : () {
                                    final wasActive = index == widget.activeLayerIndex;
                                    widget.project.removeLayer(index);
                                    if (wasActive || widget.activeLayerIndex >= widget.project.layers.length) {
                                      widget.onSelectLayer(widget.project.layers.length - 1);
                                    }
                                    _notify();
                                  },
                          ),
                          ReorderableDragStartListener(
                            index: displayIndex,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.drag_handle, color: Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_merging)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Merging layers...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
