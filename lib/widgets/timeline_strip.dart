import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/frame_data.dart';
import '../models/layer_info.dart';
import 'frame_painter.dart';

/// Visual timeline: tap a thumbnail to select, drag (long-press) to
/// reorder, tap the "⋮" badge for copy/paste/insert/delete, tap + to
/// append a blank frame. Thumbnails composite all visible layers, same
/// as the main canvas. Also owns the inline FPS slider.
class TimelineStrip extends StatelessWidget {
  final List<FrameData> frames;
  final List<LayerInfo> layers;
  final int currentIndex;
  final int fps;
  final bool hasClipboard;

  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final void Function(int) onDuplicate;
  final void Function(int) onDelete;
  final void Function(int) onCopy;
  final void Function(int) onPaste;
  final void Function(int) onInsertBefore;
  final void Function(int) onInsertAfter;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onFpsChanged;

  const TimelineStrip({
    super.key,
    required this.frames,
    required this.layers,
    required this.currentIndex,
    required this.fps,
    required this.hasClipboard,
    required this.onSelect,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onCopy,
    required this.onPaste,
    required this.onInsertBefore,
    required this.onInsertAfter,
    required this.onReorder,
    required this.onFpsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFpsRow(),
          const Divider(color: Colors.white12, height: 1),
          SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemCount: frames.length,
                    onReorder: onReorder,
                    itemBuilder: (context, index) => _FrameThumb(
                      key: ObjectKey(frames[index]),
                      index: index,
                      frame: frames[index],
                      layers: layers,
                      selected: index == currentIndex,
                      onTap: () => onSelect(index),
                      onMenu: () => _showFrameMenu(context, index),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Add frame',
                    child: Material(
                      color: Colors.orangeAccent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onAdd,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.add, color: Colors.black, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFpsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          const Icon(Icons.speed, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          const Text('FPS', style: TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(
            child: Slider(
              value: fps.toDouble(),
              min: 1,
              max: 24,
              divisions: 23,
              activeColor: Colors.orangeAccent,
              label: '$fps fps',
              onChanged: (v) => onFpsChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$fps',
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showFrameMenu(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy frame'),
              onTap: () {
                Navigator.pop(context);
                onCopy(index);
              },
            ),
            ListTile(
              enabled: hasClipboard,
              leading: Icon(Icons.content_paste, color: hasClipboard ? null : Colors.white24),
              title: Text(
                'Paste after this frame',
                style: TextStyle(color: hasClipboard ? null : Colors.white24),
              ),
              onTap: hasClipboard
                  ? () {
                      Navigator.pop(context);
                      onPaste(index);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate frame'),
              onTap: () {
                Navigator.pop(context);
                onDuplicate(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: const Text('Insert blank frame before'),
              onTap: () {
                Navigator.pop(context);
                onInsertBefore(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_bottom),
              title: const Text('Insert blank frame after'),
              onTap: () {
                Navigator.pop(context);
                onInsertAfter(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete frame'),
              onTap: () {
                Navigator.pop(context);
                onDelete(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameThumb extends StatelessWidget {
  final int index;
  final FrameData frame;
  final List<LayerInfo> layers;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const _FrameThumb({
    super.key,
    required this.index,
    required this.frame,
    required this.layers,
    required this.selected,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Colors.orangeAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CustomPaint(
                  painter: FramePainter(
                    frame: frame,
                    layers: layers,
                    canvasWidth: kCanvasWidth,
                    canvasHeight: kCanvasHeight,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 3,
              top: 2,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: onMenu,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
                  ),
                  child: const Icon(Icons.more_vert, size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
