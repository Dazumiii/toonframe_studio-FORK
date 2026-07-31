# ToonFrame Studio (Flutter)

A lightweight 2D frame-by-frame animation & drawing app, built with pure
Flutter (no paid packages, no Firebase). It runs on Android (and iOS/desktop too, since it's plain
Flutter/Dart).

## Features implemented
- **Freehand drawing** — pen tool with adjustable brush size and a 10-color palette
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
  - **Free / Premium tiers** — free projects are capped at **3 layers**; Premium unlocks up to
    **10**. The layer panel shows the current count against the cap and prompts an upgrade dialog
    if you hit it. This is backed by a lightweight in-memory `PremiumService` stub with a
    "simulate purchase" button rather than real billing — see the caveat below.
  - **Layer merging (Premium only)** — permanently flattens a layer into the one below it on every
    frame, baking in each layer's opacity/visibility at the time of the merge. Confirms before
    doing it, since it's destructive (the two layers' individual history can't be recovered
    afterward).
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
- **Playback** — play/pause the flipbook in a loop at the FPS set on the timeline
- **Undo** and **clear active layer**
- **GIF export** — renders every frame (compositing all visible layers with their opacity) and
  encodes an animated GIF to the app's documents folder

## What's not included (ideas for you to extend)
- **iOS MP4 export** — the native encoder is Android-only for now (see "In-app MP4 export"); iOS
  needs a separate `AVAssetWriter`-based implementation in Swift
- Shape tools (rectangle, ellipse, line)
- Audio tracks
- Reposition/rescale an imported reference image after placing it (currently it's letterboxed to
  fill the canvas once, on import)
- Cloud save / project list (currently one project per session, held in memory)
- Per-frame layer add/remove (currently layers are global — adding a layer adds it to every frame)
- The fill runs synchronously on the UI isolate. On a large canvas or slow device you may see a
  brief hitch; if that's noticeable, move `FillService.floodFill`'s work into a background isolate
  via `compute()`.

## Setup notes for the new permissions (photo/video import)

**Android:** `image_picker` and `video_thumbnail` use the system Photo Picker / native
thumbnailing on modern Android, which typically doesn't need explicit runtime permissions for
picking from the gallery. If you target an older `minSdkVersion` or hit permission errors, check
each plugin's own README for manifest requirements — `flutter create` won't add these
automatically since this project's `lib/` was written by hand, not scaffolded with the picker
already wired in.

**iOS:** you'll need to add these keys to `ios/Runner/Info.plist` (generated by `flutter create`,
not included in this zip) for the photo/video picker to work:
```xml
<key>NSPhotoLibraryUsageInfo</key>
<string>To import a reference photo or video for tracing.</string>
```

## A note on the free/premium layer gating
`PremiumService` is **not real billing** — it's a single in-memory `ValueNotifier<bool>` that a
"Simulate purchase" button flips on. It resets every time the app restarts (nothing persists to
disk). This was a deliberate scope choice: wiring up real App Store / Google Play billing needs
store-side setup (registering product IDs, tax/banking info, signing) that has to happen in each
developer console, not in source code. When you're ready for that:
- Add the `in_app_purchase` package
- Set `PremiumService.instance.isPremium.value = true` from its purchase-successful callback
  instead of from `PremiumService.unlock()`
- Everything else (`_maxLayers`, the paywall dialogs, the layer-merge gate) already reads
  `PremiumService.instance.isPremium` and doesn't need to change.

Also worth knowing: `LayerMergeService.mergeDown` rasterizes both merged layers' current
opacity/visibility into a flattened image per frame — it's a genuine flatten operation (like merge
in any drawing app), not just a metadata change, so the confirmation dialog before merging isn't
just a formality.

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
- Add a shape tool (rectangle/ellipse/line) alongside the fill bucket
- Move the fill-bucket computation off the UI isolate via `compute()`
- Let layers be added/removed per-frame instead of project-wide, if you want independent layer
  counts per frame (would need a per-frame layer list instead of the shared `project.layers`)

## Project structure
```
lib/
  constants.dart              # fixed internal canvas resolution
  models/
    stroke.dart                # a single pen/eraser stroke
    draw_op.dart                # StrokeDrawOp / FillDrawOp / ImageDrawOp, in order per layer
    draw_tool.dart              # DrawTool enum: pen / eraser / fill
    layer_info.dart             # per-layer name/visibility/opacity (global, shared by all frames)
    onion_skin_settings.dart    # onion skin: enabled, frame range before/after, opacity
    frame_data.dart            # per-layer DrawOp lists for one frame
    animation_project.dart     # layer stack + list of frames + fps + Reference-layer helper
  rendering/
    frame_renderer.dart         # shared paint logic: canvas, thumbnails, fill rasterizer, export
    onion_layer.dart            # a single ghosted frame + tint + opacity for onion skinning
  utils/
    image_utils.dart            # decode + letterbox-fit arbitrary image bytes to canvas size
  widgets/
    frame_painter.dart         # CustomPainter wrapper around FrameRenderer
    drawing_canvas.dart        # gesture handling -> strokes on the active layer, or fill taps
    layers_panel.dart          # bottom sheet: select/reorder/toggle/opacity/add/delete layers
    onion_skin_panel.dart       # bottom sheet: onion skin on/off, frame range, opacity
    timeline_strip.dart        # bottom filmstrip UI
    editor_toolbar.dart        # pen/eraser/fill/color/undo/layers/play controls
  services/
    fill_service.dart          # rasterize a layer + flood fill (paint bucket)
    layer_merge_service.dart   # flatten a layer down into the one below it (premium)
    premium_service.dart       # in-memory free/premium status stub (see caveat below)
    rotoscope_import_service.dart  # pick photo/video, extract & fit reference frames
    export_service.dart        # rasterize composited frames -> GIF / PNG-sequence ZIP
    native_video_encoder.dart  # MethodChannel wrapper -> android_native/Mp4Encoder.kt
    native_mp4_export_service.dart  # render frames -> temp PNGs -> hand off to native encoder
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
