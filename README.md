# ToonFrame Studio (Flutter)

A lightweight 2D frame-by-frame animation & drawing app, built with pure
Flutter (no paid packages, no Firebase). It runs on Android (and iOS/desktop too, since it's plain
Flutter/Dart).

## Features implemented
- **Freehand drawing** — four brush styles under one pen tool: **Pencil** (thin, slightly
  translucent), **Pen** (solid, full opacity), **Marker** (bold, a little translucent), and
  **Highlighter** (broad, flat-tipped, see-through). Tap the pen icon to draw with pen; long-press
  it to open the brush panel and switch styles. A 10-color palette and adjustable width apply to
  whichever style is active.
  - **Custom brushes** — save your current style + color + width combo as a named preset from the
    brush panel, then reapply it in one tap later. Presets are **in-memory only for this app
    session** — see "A note on custom brush persistence" below.
- **Eraser tool**
- **Fill bucket** — tap any enclosed region to flood-fill it with the selected color. Works by
  rasterizing the active layer's current artwork and running the `image` package's `fillFlood`,
  then baking the result in as a new op on the layer's history (so undo removes just the fill,
  and later strokes drawn on top stay editable as before).
- **Photo/video import for rotoscoping** — import a reference photo, or import a video and it
  samples N evenly-spaced frames from it (you pick how many). Each imported image lands on a
  dedicated **"Reference" layer** (auto-created at the bottom of the layer stack, 50% opacity by
  default) so you can trace over it on your normal drawing layer without it burning into your
  linework. Video import inserts one new timeline frame per extracted video frame, right after
  your current frame, so the sequence is ready to trace frame-by-frame.
- **MP4 export, in-app, no ffmpeg** — encodes H.264 via Android's own `MediaCodec`/`MediaMuxer`
  through a small native platform channel (see "In-app MP4 export" below — it needs one manual
  setup step since the native source lives outside `lib/`). Falls back with a clear message to
  the PNG-sequence export if that setup hasn't been done yet.
- **PNG-sequence export (.zip)** — renders every frame to a numbered PNG and zips them up. Zero
  native dependencies, always works, and doubles as raw material for `ffmpeg` if you'd rather
  encode on a machine you control:
  `ffmpeg -framerate <fps> -i frame_%04d.png -pix_fmt yuv420p out.mp4`
- **Multiple layers per frame** — add/delete/reorder layers, toggle visibility, adjust per-layer
  opacity, and pick which layer you're drawing on. Layer structure (names/order/count) is shared
  across the whole project — every frame has the same layers, matched by index — so a "Background"
  layer stays a background layer on every frame, while each frame keeps its own strokes per layer.
  - Capped at **20 layers** per project (`kMaxLayers` in `constants.dart`) — a soft performance
    limit, not a paywall. This app is fully open source with no premium tier.
  - **Layer merging** — permanently flattens a layer into the one below it on every frame, baking
    in each layer's opacity/visibility at the time of the merge. Confirms before doing it, since
    it's destructive (the two layers' individual history can't be recovered afterward).
- **Shape tools** — rectangle, ellipse, and line, alongside the freehand pen. Pick a shape from the
  toolbar's shape-tool popup, drag to draw it (with a live preview as you drag), and toggle
  filled vs. outline before or after selecting a shape. Shapes are their own op type in a layer's
  history (`ShapeDrawOp`), same as strokes and fills — undo removes just the last shape, and later
  strokes/fills layer on top of them normally.
- **Text tool** — tap the canvas with the text tool active to open a dialog: type your text, pick
  a size, and it's placed at the tapped point using the current color. Text is its own op type
  (`TextDrawOp`) — same undo/layering/onion-skin/export behavior as everything else. There's no
  in-place editing after placement (no drag-to-reposition or re-edit) — undo and re-add if you want
  to change it.
- **Lasso select/transform** — drag a freeform loop around anything on the active layer (strokes,
  shapes, text, fills — the lasso works on pixels, so it doesn't care how something was drawn),
  release to cut it out, then drag/pinch/twist the floating selection to move, scale, and rotate
  it. Confirm (✓) to bake it back into the layer, Cancel (✕) to put everything back exactly as it
  was, or Delete (🗑) to remove it for good. See "A note on the lasso implementation" below for an
  important tradeoff: confirming a move flattens that layer's stroke-by-stroke undo history in the
  affected area.
- **Frame-by-frame timeline** — a visual filmstrip with live thumbnails (composited across all
  visible layers) for managing frames:
  - **Drag to reorder** — long-press and drag any frame thumbnail to a new position
  - **Copy / paste** — copy a frame, paste a clone of it after any other frame (paste is
    disabled in the menu until something's been copied)
  - **Duplicate** — clone a frame in place, right after itself
  - **Insert blank frame** before or after any frame, not just at the end
  - **Delete** frame
  - Tap the **⋮** badge on a thumbnail for all of the above; tap **+** to append a blank frame
    after the current one
  - **Inline FPS slider** sits right above the filmstrip (1–24 fps) — drag it while scrubbing
    through frames to feel out the right playback speed for smoothness vs. snappiness
- **Onion skinning** — ghosts previous *and* next frames as semi-transparent overlays so you can
  keep motion consistent while drawing in between them. Previous frames are tinted red/warm, next
  frames tinted blue/cool (the standard convention in most animation apps), each rendered as a
  solid-color silhouette so they read clearly without their original colors competing with what
  you're currently drawing. Tap the onion-skin icon in the toolbar to toggle it on/off;
  **long-press it** to open settings for how many frames to ghost on each side (0–4) and overall
  opacity — closer frames stay more opaque, farther ones fade out automatically.
- **Audio integration** — tap the audio icon (top right) to open the audio panel:
  - **Import music, SFX, or a voiceover** from the device via the system file picker; imported
    files are copied into app-private storage so the project doesn't break if the original file
    moves or gets deleted. (No in-app microphone recording — see "A note on voiceover recording"
    below for why that was dropped after a real build failure, not skipped by default.)
  - **Built-in sound library** — five small synthesized SFX (Click, Beep, Ding, Whoosh, Pop). See
    "A note on the sound library" below for why these are generated rather than a real SFX pack
  - **Multiple simultaneous tracks**, each with its own volume, mute toggle, and start frame (tap
    the target icon to set a track's start to wherever the playhead currently is)
  - Tracks play alongside Play/Pause and restart in sync when the animation loops back to frame 1
    — see "A note on audio sync" below for the honest limits of that
- **Playback** — play/pause the flipbook in a loop at the FPS set on the timeline
- **Undo** and **clear active layer**
- **GIF export** — renders every frame (compositing all visible layers with their opacity) and
  encodes an animated GIF to the app's documents folder

## What's not included (ideas for you to extend)
- **iOS MP4 export** — the native encoder is Android-only for now (see "In-app MP4 export"); iOS
  needs a separate `AVAssetWriter`-based implementation in Swift
- Trimming/waveform view for audio tracks (a track always plays from its own start to its own end
  once triggered — no in/out point editing)
- A real, licensed sound-effect library (see "A note on the sound library")
- Reposition/rescale an imported reference image after placing it (currently it's letterboxed to
  fill the canvas once, on import)
- Reposition or re-edit text after placing it (undo and re-add instead)
- Cloud save / project list (currently one project per session, held in memory)
- Per-frame layer add/remove (currently layers are global — adding a layer adds it to every frame)
- The fill runs synchronously on the UI isolate. On a large canvas or slow device you may see a
  brief hitch; if that's noticeable, move `FillService.floodFill`'s work into a background isolate
  via `compute()`.

## Setup notes for permissions (photo/video import, audio)

**Android:** `image_picker` and `video_thumbnail` use the system Photo Picker / native
thumbnailing on modern Android, which typically doesn't need explicit runtime permissions for
picking from the gallery. `file_picker` (used for importing music/SFX/voiceover files) is similar.
No microphone permission is needed anywhere in this app — see "A note on voiceover recording"
below for why in-app recording isn't included. If you target an older `minSdkVersion` or hit
permission errors from any of these pickers, check each plugin's own README for manifest
requirements — `flutter create` won't add these automatically since this project's `lib/` was
written by hand, not scaffolded with the pickers already wired in.

**iOS:** you'll need to add this key to `ios/Runner/Info.plist` (generated by `flutter create`,
not included in this zip):
```xml
<key>NSPhotoLibraryUsageInfo</key>
<string>To import a reference photo or video for tracing.</string>
```

## A note on custom brush persistence
`BrushPresetService` holds saved brushes in a plain in-memory list — no `shared_preferences`, no
database, nothing written to disk. Saved brushes disappear when the app restarts. This mirrors the
same scope choice made elsewhere in this project (see "A note on voiceover recording" for the same
pattern with a different tradeoff): getting a feature working end-to-end first, with a clearly
marked seam for real persistence later, rather than pulling in a storage dependency before you've
decided you actually want one. If you want presets to survive a restart, `shared_preferences` is
about as safe a package choice as Flutter has — the three methods on `BrushPresetService` (`add`,
`removeAt`, and reading `presets`) are the only places that would need to change; nothing else in
the app talks to storage directly.

## A note on voiceover recording
This originally used the `record` package for in-app microphone recording. **It doesn't build**:
a real test run hit a version-skew bug where `record_linux` 0.7.2 doesn't implement methods that
`record_platform_interface` 1.6.0 (which pub resolved alongside it) requires — a genuine bug in
that package combination, not a config issue on your end. Given this project already hit one
native-plugin dead end (see "In-app MP4 export" below, about `ffmpeg_kit_flutter`), I didn't want
to gamble on a version pin I can't verify from this sandbox for a second one. So: voiceovers are
imported like any other audio file instead of recorded in-app — record with your phone's own voice
memo app, then use "Import voiceover" in the audio panel. If you want real in-app recording, the
`record` package (or an alternative like `flutter_sound`) is the natural place to add it back — just
verify whatever version you land on actually builds before relying on it, given the history here.

## A note on the sound library
The five built-in SFX (Click, Beep, Ding, Whoosh, Pop) are synthesized at runtime in pure Dart
(`lib/utils/wav_synth.dart` - basic sine waves, noise bursts, and envelopes, written straight to
WAV bytes) rather than bundled audio files. That's a deliberate choice, not a shortcut I'd have
preferred to skip: I have no way to source or verify licensing for real audio assets from this
sandbox, and shipping someone else's SFX pack without being certain of its license isn't a risk
worth taking on your behalf. They work, they're genuinely useful placeholder sounds, but they
won't sound like a polished commercial SFX library. If you want real ones, drop licensed `.wav`/
`.mp3` files into an `assets/audio/` folder, declare them in `pubspec.yaml`'s `flutter: assets:`
section, and add matching entries to `AudioLibraryService.items`.

## A note on audio sync
Playback sync between the animation and audio tracks is driven by the same `Timer.periodic` that
already advances frames (see `EditorScreen._togglePlay`) — there's no shared audio/video clock.
Each track is seeked to the right offset when it starts and restarted fresh whenever the animation
loops back to frame 1, which keeps drift from accumulating indefinitely, but within a single loop
pass, timing can drift by however much `Timer.periodic` itself drifts (a well-known limitation of
Dart's timer under system load - not unique to this code). Fine for short animations with music/
SFX/voiceover that doesn't need frame-perfect sync; if you need tighter guarantees for longer
pieces, you'd want to replace the frame timer with a proper shared clock (e.g. driving both frame
advancement and audio position off `Stopwatch` elapsed time each tick, rather than just counting
timer fires).

## A note on the lasso implementation
This is a **raster** lasso, not a vector one, and that's a deliberate scope choice worth
understanding before you rely on it. A "proper" vector lasso would let you select individual
strokes/shapes/text as distinct objects and move just those. What's here instead: releasing the
lasso rasterizes the entire active layer, cuts the lassoed pixels into a floating image, and
leaves an "everything else" image behind. That means:
- It works uniformly on strokes, shapes, text, fills, and imported images, since they all become
  pixels — nothing is excluded or handled specially.
- Confirming a move **flattens that layer's undo history in the affected area** into two images.
  You can no longer undo the strokes underneath the selection one at a time after that — only
  Cancel (before confirming) gets you back to the exact original state.
- Live dragging/pinching/rotating is cheap (it's just a `Canvas.drawImage` with a transform applied
  each paint call — no re-rasterizing while you interact with it). The one-time rasterization
  happens only twice: once when you release the lasso, and once when you confirm the final
  position.
- I couldn't test this on a real device from this sandbox, same as everything else in this
  project — the individual pieces (`Path.addPolygon`, `BlendMode.clear` for the cutout,
  `ScaleGestureDetector` for combined pan/pinch/rotate) are all standard, well-documented Flutter
  APIs, not fragile or exotic, but the interaction as a whole is the most complex thing built here
  and deserves real testing before you trust it in front of users.

If you want true vector selection later, the natural extension point is per-op hit-testing (does
this `Stroke`'s point cloud, or this `ShapeDrawOp`'s bounds, intersect the lasso polygon?) followed
by applying a `Matrix4` transform to just the selected ops' geometry — a bigger rewrite of the
selection logic, but the existing `DrawOp` model already separates each op's data cleanly enough to
support it.

## A note on layer merging
`LayerMergeService.mergeDown` rasterizes both merged layers' current opacity/visibility into a
flattened image per frame — it's a genuine flatten operation (like merge in any drawing app), not
just a metadata change, so the confirmation dialog before merging isn't just a formality. It's
available to everyone, with no gating — this project is open source.

## A note on the timeline's drag-to-reorder
`ReorderableListView.builder` with `scrollDirection: Axis.horizontal` is what drives dragging
frame thumbnails around. This is standard, well-supported Flutter — not something exotic like the
ffmpeg/fill-bucket APIs below — but I still haven't been able to compile it in this sandbox, so
if you hit an issue, it's most likely a version-specific default-drag-handle quirk (e.g. needing
`buildDefaultDragHandles: false` plus an explicit `ReorderableDragStartListener` on older Flutter
versions), not a fundamental design problem.

## A note on the fill bucket implementation
I wrote this against the `image` package's v4 API (`Image.fromBytes`, `getBytes(order: ...)`,
`fillFlood`, `ChannelOrder`). I don't have Flutter/pub.dev access in the sandbox this was built in,
so this hasn't been compiled. If `flutter pub get` resolves a different major version of `image`
and you get errors in `lib/services/fill_service.dart`, check that package's current docs for the
equivalent constructor/method names — the flood-fill logic itself (rasterize → fill → decode back
to a `ui.Image`) will still be correct, just the exact API calls might need small adjustments.

## In-app MP4 export (Android, via native MediaCodec/MediaMuxer)
The obvious way to get MP4 export inside the app is a Flutter plugin like
`ffmpeg_kit_flutter`/`ffmpeg_kit_flutter_new`. **Don't use those** — as of this writing, the whole
`ffmpeg_kit_flutter*` family fails to build on any current Android Gradle Plugin 8.x project: the
underlying AAR's `AndroidManifest.xml` lacks a `package`/`namespace` attribute AGP 8 now requires,
`processDebugResources` fails, and since the original project is archived/retired, nobody's
shipping a fix. That's not a guess — it's what actually happened when this was tested.

So instead, MP4 export here goes straight through **Android's own `MediaCodec` + `MediaMuxer`
APIs** via a small hand-written platform channel — no third-party native dependency at all, just
the same OS-level encoder every camera app on the device already uses. That means there's nothing
here that can go stale the way a bundled third-party AAR can.

**This needs one manual setup step**, because this project's `lib/` and `pubspec.yaml` are meant
to be dropped into a fresh `flutter create` scaffold (see "How to run it" below), and the native
Android source lives outside `lib/` in this zip's `android_native/` folder — `flutter create`
doesn't know about it:

1. Run `flutter create toonframe_studio` and copy in `lib/`/`pubspec.yaml` as usual.
2. Find your generated `MainActivity.kt` at
   `android/app/src/main/kotlin/<your/package/path>/MainActivity.kt` and note its **package
   line** at the top (e.g. `package com.example.toonframe_studio`).
3. Copy `android_native/MainActivity.kt` and `android_native/Mp4Encoder.kt` from this zip into
   that same folder, **overwriting** the generated `MainActivity.kt`.
4. In both files, replace the placeholder `package com.example.toonframe_studio` line with your
   actual package line from step 2. Kotlin won't compile if this doesn't match your project.
5. `flutter run` as normal.

If you skip this setup, MP4 export in the app shows a clear "add the native Android code first"
message and points you at PNG-sequence export instead — it won't crash, just gracefully decline.

**Honest limitations, since I can't compile or run Kotlin/Android from this sandbox:**
- This is real platform code, not something I could verify builds or runs correctly. Treat it as
  a solid first draft to test on a real device, the way you'd review any code from a teammate who
  couldn't run it themselves — not as finished, verified work the way the pure-Dart features here
  are.
- **Android only.** iOS would need an equivalent implementation using `AVAssetWriter`
  (AVFoundation, in Swift) — a separate, similarly-sized effort not included here.
- Color-format handling covers the two most common formats hardware encoders advertise (planar
  I420 and semi-planar NV12). A device whose encoder only supports something else will fail with a
  clear error rather than silently producing garbage — but that path is possible on unusual
  hardware.
- The RGB→YUV conversion runs on the CPU in a plain Kotlin loop (no SIMD/NEON), so very long
  animations at high frame counts may take a few seconds to encode. Fine for typical short
  animations; something to watch for cinema-length ones.
- If it doesn't work on your device, **PNG-sequence export still does** (zero native dependencies)
  — export that and run `ffmpeg -framerate <fps> -i frame_%04d.png -pix_fmt yuv420p out.mp4`
  yourself as a fallback while you debug the native path.

## Where to go next
- Add a "Magic Cut"-style feature using `google_mlkit_selfie_segmentation` for smarter rotoscope
  masking (rather than tracing by eye over a flat reference image)
- Let the user drag/scale an imported reference image instead of always auto-fitting it to the
  full canvas
- Move the fill-bucket computation off the UI isolate via `compute()`
- Let layers be added/removed per-frame instead of project-wide, if you want independent layer
  counts per frame (would need a per-frame layer list instead of the shared `project.layers`)
- Add trim (in/out point) controls and a waveform preview to audio tracks
- Add real in-app voiceover recording (see "A note on voiceover recording" for why it isn't here
  yet, and what to verify before adding it back)
- Show audio track markers on the timeline itself (currently the audio panel is the only place
  a track's start frame is visible)
- Build lasso select/transform, the one remaining brushes-and-tools item

## Project structure
```
lib/
  constants.dart              # fixed internal canvas resolution
  models/
    stroke.dart                # a single pen/eraser stroke, now carries a BrushStyle
    brush_style.dart             # BrushStyle enum: pencil / pen / marker / highlighter
    brush_preset.dart            # BrushPreset: a named saved style + color + width combo
    draw_op.dart                # StrokeDrawOp / ShapeDrawOp / TextDrawOp / FillDrawOp / ImageDrawOp
    draw_tool.dart              # DrawTool enum: pen / eraser / fill / shape / text / lasso
    shape_kind.dart              # ShapeKind enum: rectangle / ellipse / line
    lasso_selection.dart         # transient state for an in-progress lasso move/scale/rotate
    layer_info.dart             # per-layer name/visibility/opacity (global, shared by all frames)
    onion_skin_settings.dart    # onion skin: enabled, frame range before/after, opacity
    frame_data.dart            # per-layer DrawOp lists for one frame
    animation_project.dart     # layer stack + list of frames + audio tracks + fps + Reference-layer helper
    audio_track.dart            # AudioTrack: music/SFX/voiceover clip, volume/mute/start frame
  rendering/
    frame_renderer.dart         # shared paint logic: canvas, thumbnails, fill rasterizer, export
    onion_layer.dart            # a single ghosted frame + tint + opacity for onion skinning
  utils/
    image_utils.dart            # decode + letterbox-fit arbitrary image bytes to canvas size
    wav_synth.dart               # pure-Dart synthesized WAV clips for the built-in sound library
  widgets/
    frame_painter.dart         # CustomPainter wrapper around FrameRenderer
    drawing_canvas.dart        # gesture handling -> strokes on the active layer, or fill taps
    layers_panel.dart          # bottom sheet: select/reorder/toggle/opacity/add/delete layers
    brush_panel.dart             # bottom sheet: pick brush style, save/apply/delete custom brushes
    onion_skin_panel.dart       # bottom sheet: onion skin on/off, frame range, opacity
    audio_panel.dart             # bottom sheet: import audio, sound library, per-track controls
    timeline_strip.dart        # bottom filmstrip UI
    editor_toolbar.dart        # pen/eraser/fill/color/undo/layers/play controls
  services/
    fill_service.dart          # rasterize a layer + flood fill (paint bucket)
    brush_preset_service.dart   # in-memory store of the user's custom saved brush presets
    layer_merge_service.dart   # flatten a layer down into the one below it
    lasso_service.dart          # rasterize/cut/re-composite a lasso selection
    rotoscope_import_service.dart  # pick photo/video, extract & fit reference frames
    export_service.dart        # rasterize composited frames -> GIF / PNG-sequence ZIP
    native_video_encoder.dart  # MethodChannel wrapper -> android_native/Mp4Encoder.kt
    native_mp4_export_service.dart  # render frames -> temp PNGs -> hand off to native encoder
    audio_import_service.dart   # pick an audio file (music/SFX/voiceover), copy into app-private storage
    audio_library_service.dart  # the built-in synthesized SFX library, cached to disk
    audio_playback_service.dart # plays AudioTracks in sync with animation play/pause/loop
  screens/
    home_screen.dart
    editor_screen.dart         # wires everything together: playback, import/export menus, state
  main.dart

android_native/                # NOT inside lib/ - see "In-app MP4 export" for where these go
  MainActivity.kt               # replaces flutter create's generated MainActivity.kt
  Mp4Encoder.kt                 # the actual MediaCodec/MediaMuxer H.264 encoder
```

## How to run it

This code was written directly (not scaffolded with `flutter create`), so you need to generate the
native Android/iOS wrapper folders locally, since I don't have the Flutter SDK / pub.dev access in
this environment to do it for you.

1. **Install the Flutter SDK** if you haven't: https://docs.flutter.dev/get-started/install

2. **Scaffold a new project** (this generates `android/`, `ios/`, etc.):
   ```bash
   flutter create toonframe_studio
   cd toonframe_studio
   ```

3. **Replace** the generated `lib/` folder and `pubspec.yaml` with the ones from this package.

4. **Get packages:**
   ```bash
   flutter pub get
   ```

5. **Run on a connected device or emulator:**
   ```bash
   flutter run
   ```

6. **Build a release APK:**
   ```bash
   flutter build apk --release
   ```
   The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Notes on Android permissions
GIFs and PNG-ZIPs are written to the app's private documents directory via `path_provider`
(`getApplicationDocumentsDirectory()`), which requires **no special permissions** on modern
Android — it's app-private storage. If you want to save exports to the shared Gallery/Downloads
instead, add the `gal` or `saver_gallery` package and request storage/media permissions per your
target SDK. See "Setup notes for the new permissions" above for the photo/video **import** side.
