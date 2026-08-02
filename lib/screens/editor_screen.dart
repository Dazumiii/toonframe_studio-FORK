import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/animation_project.dart';
import '../models/draw_op.dart';
import '../models/draw_tool.dart';
import '../models/frame_data.dart';
import '../models/onion_skin_settings.dart';
import '../models/shape_kind.dart';
import '../models/stroke.dart';
import '../rendering/onion_layer.dart';
import '../services/audio_playback_service.dart';
import '../services/export_service.dart';
import '../services/fill_service.dart';
import '../services/layer_merge_service.dart';
import '../services/native_mp4_export_service.dart';
import '../services/rotoscope_import_service.dart';
import '../widgets/audio_panel.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/layers_panel.dart';
import '../widgets/onion_skin_panel.dart';
import '../widgets/timeline_strip.dart';

enum _ImportAction { photo, video }
enum _ExportAction { gif, mp4, pngZip }

class EditorScreen extends StatefulWidget {
  final AnimationProject project;
  const EditorScreen({super.key, required this.project});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late AnimationProject project;
  int currentIndex = 0;
  int activeLayerIndex = 0;

  Color color = Colors.black;
  double strokeWidth = 6;
  DrawTool tool = DrawTool.pen;
  ShapeKind shapeKind = ShapeKind.rectangle;
  bool shapeFilled = false;
  double textSize = 32;
  final OnionSkinSettings onionSettings = OnionSkinSettings();
  bool isPlaying = false;
  bool isFilling = false;
  FrameData? _clipboardFrame;
  Timer? _playTimer;
  final AudioPlaybackService _audioPlayback = AudioPlaybackService();

  @override
  void initState() {
    super.initState();
    project = widget.project;
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _audioPlayback.dispose();
    super.dispose();
  }

  FrameData get currentFrame => project.frames[currentIndex];

  /// Builds the list of ghosted onion-skin frames to render: previous
  /// frames tinted red/warm, next frames tinted blue/cool, each drawn
  /// farthest-first so nearer frames (and the current frame) end up on
  /// top. Opacity fades out with distance from the current frame.
  List<OnionLayer> get onionLayers {
    if (!onionSettings.enabled) return [];
    const previousTint = Color(0xFFE53935);
    const nextTint = Color(0xFF1E88E5);
    final result = <OnionLayer>[];

    for (int d = onionSettings.framesBefore; d >= 1; d--) {
      final idx = currentIndex - d;
      if (idx < 0) continue;
      result.add(OnionLayer(
        frame: project.frames[idx],
        tint: previousTint,
        opacity: (onionSettings.opacity / d).clamp(0.0, 1.0),
      ));
    }

    for (int d = onionSettings.framesAfter; d >= 1; d--) {
      final idx = currentIndex + d;
      if (idx >= project.frames.length) continue;
      result.add(OnionLayer(
        frame: project.frames[idx],
        tint: nextTint,
        opacity: (onionSettings.opacity / d).clamp(0.0, 1.0),
      ));
    }

    return result;
  }

  int get _safeActiveLayer =>
      activeLayerIndex < project.layers.length ? activeLayerIndex : project.layers.length - 1;

  // ---- Drawing ----

  void _addStroke(Stroke stroke) {
    setState(() => currentFrame.layerOps[_safeActiveLayer].add(StrokeDrawOp(stroke)));
  }

  void _addShape(ShapeDrawOp shape) {
    setState(() => currentFrame.layerOps[_safeActiveLayer].add(shape));
  }

  Future<void> _handleTextTap(Offset canvasPoint) async {
    final controller = TextEditingController();
    double localSize = textSize;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add text'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(hintText: 'Type something...'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Size', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: localSize,
                      min: 12,
                      max: 96,
                      divisions: 28,
                      label: localSize.round().toString(),
                      onChanged: (v) => setDialogState(() => localSize = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty || !mounted) return;

    setState(() {
      textSize = localSize;
      currentFrame.layerOps[_safeActiveLayer].add(TextDrawOp(
        text: result,
        position: canvasPoint,
        color: color,
        fontSize: textSize,
      ));
    });
  }

  Future<void> _handleFillTap(Offset canvasPoint) async {
    if (isFilling) return;
    setState(() => isFilling = true);
    try {
      final ops = currentFrame.layerOps[_safeActiveLayer];
      final baseImage = await FillService.rasterizeOps(ops);
      final filledImage = await FillService.floodFill(
        baseImage,
        seedX: canvasPoint.dx.round().clamp(0, kCanvasWidth.toInt() - 1),
        seedY: canvasPoint.dy.round().clamp(0, kCanvasHeight.toInt() - 1),
        fillColor: color,
      );
      if (filledImage == null || !mounted) return;
      setState(() => ops.add(FillDrawOp(filledImage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fill failed: $e')));
    } finally {
      if (mounted) setState(() => isFilling = false);
    }
  }

  void _undo() {
    final ops = currentFrame.layerOps[_safeActiveLayer];
    if (ops.isEmpty) return;
    setState(() => ops.removeLast());
  }

  void _clearActiveLayer() {
    setState(() => currentFrame.layerOps[_safeActiveLayer].clear());
  }

  // ---- Frames ----

  void _addFrame() {
    setState(() {
      project.frames.insert(currentIndex + 1, project.newFrame());
      currentIndex++;
    });
  }

  void _duplicateFrame(int index) {
    setState(() {
      project.frames.insert(index + 1, project.frames[index].clone());
      currentIndex = index + 1;
    });
  }

  void _deleteFrame(int index) {
    if (project.frames.length <= 1) return;
    setState(() {
      project.frames.removeAt(index);
      if (currentIndex >= project.frames.length) {
        currentIndex = project.frames.length - 1;
      }
    });
  }

  void _copyFrame(int index) {
    _clipboardFrame = project.frames[index].clone();
    setState(() {}); // refresh so the Paste menu item enables
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied frame ${index + 1}'), duration: const Duration(seconds: 1)),
    );
  }

  void _pasteFrameAfter(int index) {
    final clipboard = _clipboardFrame;
    if (clipboard == null) return;
    setState(() {
      project.frames.insert(index + 1, clipboard.clone());
      currentIndex = index + 1;
    });
  }

  void _insertBlankFrame(int index, {required bool before}) {
    setState(() {
      final insertAt = before ? index : index + 1;
      project.frames.insert(insertAt, project.newFrame());
      currentIndex = insertAt;
    });
  }

  void _reorderFrame(int oldIndex, int newIndex) {
    final movingFrame = project.frames[currentIndex];
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final frame = project.frames.removeAt(oldIndex);
      project.frames.insert(newIndex, frame);
      // Keep the selection following the same frame object, wherever
      // it ended up (simplest correct approach regardless of whether
      // the frame that moved was the selected one or not).
      currentIndex = project.frames.indexOf(movingFrame);
    });
  }

  void _togglePlay() {
    if (isPlaying) {
      _playTimer?.cancel();
      _audioPlayback.pauseAll();
      setState(() => isPlaying = false);
      return;
    }
    setState(() => isPlaying = true);
    _audioPlayback.playFrom(tracks: project.audioTracks, currentFrameIndex: currentIndex, fps: project.fps);
    final frameDuration = Duration(milliseconds: (1000 / project.fps).round());
    _playTimer = Timer.periodic(frameDuration, (_) {
      setState(() {
        final next = (currentIndex + 1) % project.frames.length;
        if (next == 0 && project.frames.length > 1) {
          // Looped back to the start - restart every track fresh
          // rather than letting them fall out of sync over time.
          _audioPlayback.stopAll();
          _audioPlayback.playFrom(tracks: project.audioTracks, currentFrameIndex: 0, fps: project.fps);
        } else {
          _audioPlayback.checkStarts(tracks: project.audioTracks, currentFrameIndex: next);
        }
        currentIndex = next;
      });
    });
  }

  void _openLayersPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LayersPanel(
        project: project,
        activeLayerIndex: _safeActiveLayer,
        maxLayers: kMaxLayers,
        onSelectLayer: (i) => activeLayerIndex = i,
        onAddLayerRequested: _requestAddLayer,
        onMergeDownRequested: _requestMergeDown,
        onChanged: () => setState(() {}),
      ),
    );
  }

  void _openAudioPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioPanel(
        tracks: project.audioTracks,
        currentFrameIndex: currentIndex,
        onChanged: () => setState(() {}),
      ),
    );
  }

  void _requestAddLayer() {
    final added = project.addLayer(maxLayers: kMaxLayers);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Layer limit reached ($kMaxLayers max)')),
      );
    }
  }

  Future<void> _requestMergeDown(int index) async {
    final confirmed = await _confirmMerge(index);
    if (!confirmed || !mounted) return;

    await LayerMergeService.mergeDown(project, index);
    if (!mounted) return;

    // The merge removed a layer at `index`; keep the active-layer
    // selection pointing at something sensible.
    if (activeLayerIndex >= project.layers.length) {
      activeLayerIndex = project.layers.length - 1;
    } else if (activeLayerIndex == index) {
      activeLayerIndex = index - 1; // merged into the layer below
    } else if (activeLayerIndex > index) {
      activeLayerIndex -= 1; // shifted down since a layer was removed
    }
    setState(() {});
  }

  Future<bool> _confirmMerge(int index) async {
    final below = project.layers[index - 1].name;
    final upper = project.layers[index].name;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge layers?'),
        content: Text(
          '"$upper" will be permanently combined into "$below" on every frame. '
          'This flattens both layers into one image and can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Merge')),
        ],
      ),
    );
    return result ?? false;
  }

  void _openOnionSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => OnionSkinPanel(
        settings: onionSettings,
        onChanged: () => setState(() {}),
      ),
    );
  }

  // ---- Rotoscope import ----

  Future<void> _handleImportAction(_ImportAction action) async {
    switch (action) {
      case _ImportAction.photo:
        await _importPhoto();
      case _ImportAction.video:
        await _importVideo();
    }
  }

  Future<void> _importPhoto() async {
    try {
      final image = await RotoscopeImportService.pickPhoto();
      if (image == null || !mounted) return; // user cancelled

      final result = project.ensureReferenceLayer();
      setState(() {
        if (result.created) activeLayerIndex += 1;
        currentFrame.layerOps[result.index]
          ..clear()
          ..add(ImageDrawOp(image));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo placed on the Reference layer - lower its opacity in Layers to trace over it')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo import failed: $e')));
    }
  }

  Future<void> _importVideo() async {
    bool progressShown = false;
    try {
      final path = await RotoscopeImportService.pickVideoPath();
      if (path == null || !mounted) return; // user cancelled

      final duration = await RotoscopeImportService.probeDuration(path);
      if (duration == null || duration.inMilliseconds <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that video\'s duration')),
        );
        return;
      }

      final maxFrames = duration.inSeconds.clamp(1, 60);
      if (!mounted) return;
      final frameCount = await _askFrameCount(maxFrames: maxFrames);
      if (frameCount == null || !mounted) return;

      progressShown = true;
      _showProgressDialog('Extracting $frameCount reference frames...');
      final images = await RotoscopeImportService.extractFrames(
        path,
        frameCount: frameCount,
        duration: duration,
      );

      if (!mounted) return;
      final result = project.ensureReferenceLayer();

      setState(() {
        if (result.created) activeLayerIndex += 1;
        int insertAt = currentIndex + 1;
        for (final image in images) {
          final frame = project.newFrame();
          frame.layerOps[result.index].add(ImageDrawOp(image));
          project.frames.insert(insertAt, frame);
          insertAt++;
        }
        currentIndex = currentIndex + 1;
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // close progress dialog
      progressShown = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${images.length} reference frames - draw on top to rotoscope')),
      );
    } catch (e) {
      if (!mounted) return;
      if (progressShown) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video import failed: $e')));
    }
  }

  Future<int?> _askFrameCount({required int maxFrames}) {
    int temp = maxFrames < 12 ? maxFrames : 12;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How many reference frames?'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$temp frames, evenly spaced across the video'),
              Slider(
                value: temp.toDouble(),
                min: 1,
                max: maxFrames.toDouble(),
                divisions: maxFrames > 1 ? maxFrames - 1 : 1,
                label: '$temp',
                onChanged: (v) => setDialogState(() => temp = v.round()),
              ),
              const Text(
                'Each frame is inserted as a new timeline frame with the video '
                'still on the Reference layer.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, temp), child: const Text('Import')),
        ],
      ),
    );
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ---- Export ----

  Future<void> _handleExportAction(_ExportAction action) async {
    _playTimer?.cancel();
    _audioPlayback.stopAll();
    setState(() => isPlaying = false);

    final String label = switch (action) {
      _ExportAction.gif => 'Exporting GIF...',
      _ExportAction.mp4 => 'Exporting MP4...',
      _ExportAction.pngZip => 'Exporting PNG sequence...',
    };
    _showProgressDialog(label);

    try {
      final file = switch (action) {
        _ExportAction.gif => await ExportService.exportProjectAsGif(project),
        _ExportAction.mp4 => await NativeMp4ExportService.exportProjectAsMp4(project),
        _ExportAction.pngZip => await ExportService.exportPngSequenceZip(project),
      };
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
    } on MissingPluginException {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MP4 export needs the native Android code added first - see the README\'s '
            '"In-app MP4 export" section. Try "Export PNG sequence" in the meantime.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(project.name),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.audiotrack, color: Colors.white70),
            tooltip: 'Audio',
            onPressed: _openAudioPanel,
          ),
          PopupMenuButton<_ImportAction>(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70),
            tooltip: 'Import for rotoscoping',
            onSelected: _handleImportAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: _ImportAction.photo, child: Text('Import photo')),
              PopupMenuItem(value: _ImportAction.video, child: Text('Import video (extract frames)')),
            ],
          ),
          PopupMenuButton<_ExportAction>(
            icon: const Icon(Icons.file_download, color: Colors.white70),
            tooltip: 'Export',
            onSelected: _handleExportAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: _ExportAction.gif, child: Text('Export as GIF')),
              PopupMenuItem(value: _ExportAction.mp4, child: Text('Export as MP4')),
              PopupMenuItem(value: _ExportAction.pngZip, child: Text('Export PNG sequence (.zip)')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Frame ${currentIndex + 1}/${project.frames.length}')),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DrawingCanvas(
                      frame: currentFrame,
                      layers: project.layers,
                      onionLayers: onionLayers,
                      color: color,
                      strokeWidth: strokeWidth,
                      tool: tool,
                      shapeKind: shapeKind,
                      shapeFilled: shapeFilled,
                      onStrokeFinished: _addStroke,
                      onFillTap: _handleFillTap,
                      onShapeFinished: _addShape,
                      onTextTap: _handleTextTap,
                    ),
                    if (isFilling)
                      Container(
                        color: Colors.black45,
                        child: const CircularProgressIndicator(color: Colors.orangeAccent),
                      ),
                  ],
                ),
              ),
            ),
          ),
          EditorToolbar(
            selectedColor: color,
            tool: tool,
            shapeKind: shapeKind,
            shapeFilled: shapeFilled,
            strokeWidth: strokeWidth,
            onionEnabled: onionSettings.enabled,
            isPlaying: isPlaying,
            layerCount: project.layers.length,
            maxLayers: kMaxLayers,
            activeLayerName: project.layers[_safeActiveLayer].name,
            onColorSelected: (c) => setState(() => color = c),
            onSelectTool: (t) => setState(() => tool = t),
            onSelectShape: (k) => setState(() {
              shapeKind = k;
              tool = DrawTool.shape;
            }),
            onToggleShapeFilled: () => setState(() => shapeFilled = !shapeFilled),
            onStrokeWidthChanged: (v) => setState(() => strokeWidth = v),
            onToggleOnionSkin: () => setState(() => onionSettings.enabled = !onionSettings.enabled),
            onOpenOnionSettings: _openOnionSettings,
            onUndo: _undo,
            onClearFrame: _clearActiveLayer,
            onTogglePlay: _togglePlay,
            onOpenLayers: _openLayersPanel,
          ),
          TimelineStrip(
            frames: project.frames,
            layers: project.layers,
            currentIndex: currentIndex,
            fps: project.fps,
            hasClipboard: _clipboardFrame != null,
            onSelect: (i) {
              _playTimer?.cancel();
              _audioPlayback.stopAll();
              setState(() {
                isPlaying = false;
                currentIndex = i;
              });
            },
            onAdd: _addFrame,
            onDuplicate: _duplicateFrame,
            onDelete: _deleteFrame,
            onCopy: _copyFrame,
            onPaste: _pasteFrameAfter,
            onInsertBefore: (i) => _insertBlankFrame(i, before: true),
            onInsertAfter: (i) => _insertBlankFrame(i, before: false),
            onReorder: _reorderFrame,
            onFpsChanged: (v) => setState(() => project.fps = v),
          ),
        ],
      ),
    );
  }
}
