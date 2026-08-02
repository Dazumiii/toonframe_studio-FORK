import 'package:flutter/material.dart';
import '../models/audio_track.dart';
import '../services/audio_import_service.dart';
import '../services/audio_library_service.dart';

/// Bottom-sheet UI for the project's audio tracks: import music/SFX/
/// voiceover from the device, pick from the built-in sound library,
/// and adjust each track's volume/mute/start frame.
class AudioPanel extends StatefulWidget {
  final List<AudioTrack> tracks;
  final int currentFrameIndex;
  final VoidCallback onChanged;

  const AudioPanel({
    super.key,
    required this.tracks,
    required this.currentFrameIndex,
    required this.onChanged,
  });

  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  bool _isBusy = false;

  void _notify() {
    setState(() {});
    widget.onChanged();
  }

  Future<void> _importAudio(AudioTrackType type) async {
    setState(() => _isBusy = true);
    try {
      final track = await AudioImportService.pickAudioFile(type: type);
      if (track != null) {
        track.startFrameIndex = widget.currentFrameIndex;
        widget.tracks.add(track);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
      _notify();
    }
  }

  Future<void> _addLibraryItem(AudioLibraryItem item) async {
    setState(() => _isBusy = true);
    try {
      final path = await AudioLibraryService.resolveFilePath(item);
      widget.tracks.add(AudioTrack(
        name: item.label,
        filePath: path,
        type: AudioTrackType.sfx,
        startFrameIndex: widget.currentFrameIndex,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t add sound: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
      _notify();
    }
  }

  IconData _iconFor(AudioTrackType type) {
    return switch (type) {
      AudioTrackType.music => Icons.music_note,
      AudioTrackType.sfx => Icons.graphic_eq,
      AudioTrackType.voiceover => Icons.mic,
    };
  }

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  const Text('Audio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_isBusy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _importAudio(AudioTrackType.music),
                    icon: const Icon(Icons.library_music, size: 18),
                    label: const Text('Import music'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _importAudio(AudioTrackType.sfx),
                    icon: const Icon(Icons.graphic_eq, size: 18),
                    label: const Text('Import SFX'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _importAudio(AudioTrackType.voiceover),
                    icon: const Icon(Icons.mic, size: 18),
                    label: const Text('Import voiceover'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sound library', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: AudioLibraryService.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.play_circle_outline, size: 16, color: Colors.orangeAccent),
                      label: Text(item.label),
                      onPressed: _isBusy ? null : () => _addLibraryItem(item),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Colors.white12, height: 16),
            Flexible(
              child: widget.tracks.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No audio tracks yet', style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.tracks.length,
                      itemBuilder: (context, index) {
                        final track = widget.tracks[index];
                        return ListTile(
                          leading: IconButton(
                            icon: Icon(
                              track.muted ? Icons.volume_off : _iconFor(track.type),
                              color: track.muted ? Colors.white38 : Colors.white,
                            ),
                            tooltip: track.muted ? 'Unmute' : 'Mute',
                            onPressed: () {
                              track.muted = !track.muted;
                              _notify();
                            },
                          ),
                          title: Text(track.name, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.volume_up, size: 14, color: Colors.white38),
                                  Expanded(
                                    child: Slider(
                                      value: track.volume,
                                      activeColor: Colors.orangeAccent,
                                      onChanged: (v) {
                                        track.volume = v;
                                        _notify();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Starts at frame ${track.startFrameIndex + 1}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.my_location, size: 18, color: Colors.white54),
                                tooltip: 'Set start to current frame',
                                onPressed: () {
                                  track.startFrameIndex = widget.currentFrameIndex;
                                  _notify();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Remove track',
                                onPressed: () {
                                  widget.tracks.removeAt(index);
                                  _notify();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
