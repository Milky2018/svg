// =============================================================================
// Clip Rect (for legacy clip property)
// =============================================================================

///|
/// CSS clip property value
/// clip: rect(top, right, bottom, left) or auto
/// Note: This is a deprecated property, but still widely used for accessibility
pub(all) enum ClipRect {
  /// clip: auto (no clipping)
  Auto
  /// clip: rect(top, right, bottom, left)
  /// Values are offsets from the element's edges
  Rect(top~ : Double, right~ : Double, bottom~ : Double, left~ : Double)
} derive(Debug, Eq)

///|
pub impl Show for ClipRect with fn output(self, logger) {
  match self {
    Auto => logger.write_string("auto")
    Rect(top~, right~, bottom~, left~) => {
      logger.write_string("rect(")
      top.output(logger)
      logger.write_string(", ")
      right.output(logger)
      logger.write_string(", ")
      bottom.output(logger)
      logger.write_string(", ")
      left.output(logger)
      logger.write_string(")")
    }
  }
}

///|
pub fn ClipRect::default() -> ClipRect {
  Auto
}
