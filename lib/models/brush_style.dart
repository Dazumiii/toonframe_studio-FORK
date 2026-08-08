/// A stroke's rendering style. Distinct from [DrawTool] - all four of
/// these live under the pen tool; this just changes how a pen stroke
/// looks (opacity, thickness multiplier, cap shape), not the gesture
/// used to draw it.
enum BrushStyle { pencil, pen, marker, highlighter }
