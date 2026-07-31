/// Fixed internal drawing-surface resolution.
/// All strokes are stored in this coordinate space and scaled
/// to fit whatever screen size the canvas is displayed at.
const double kCanvasWidth = 960;
const double kCanvasHeight = 720;

/// Layer caps for the free vs. premium tiers (see PremiumService).
/// The auto-created "Reference" layer used for rotoscoping is exempt
/// from this cap on purpose - importing a photo/video to trace over
/// should never be silently blocked by the layer limit. That means the
/// layer count shown in the UI can briefly read one over the cap (e.g.
/// "4/3") right after a reference import on a free plan that was
/// already at its limit; that's expected, not a bug.
const int kFreeMaxLayers = 3;
const int kPremiumMaxLayers = 10;
