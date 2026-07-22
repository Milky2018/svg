// ============================================================================
// Aspect Ratio utilities
// ============================================================================

///|
/// Apply aspect ratio to calculate width from height.
/// Returns width if aspect_ratio is defined, otherwise returns None.
pub fn apply_aspect_ratio_width(
  height : Double,
  aspect_ratio : Double?,
) -> Double? {
  match aspect_ratio {
    Some(ar) if ar > 0.0 => Some(height * ar)
    _ => None
  }
}

///|
/// Apply aspect ratio to calculate height from width.
/// Returns height if aspect_ratio is defined, otherwise returns None.
pub fn apply_aspect_ratio_height(
  width : Double,
  aspect_ratio : Double?,
) -> Double? {
  match aspect_ratio {
    Some(ar) if ar > 0.0 => Some(width / ar)
    _ => None
  }
}

///|
/// Resolve dimensions with aspect ratio.
/// Given known dimension (width or height), aspect_ratio, and min/max constraints,
/// returns the final (width, height) pair.
///
/// - If width is known, height = width / aspect_ratio
/// - If height is known, width = height * aspect_ratio
/// - If both are known, aspect_ratio overrides the height
/// - Min/max constraints are applied after aspect ratio calculation
pub fn resolve_dimensions_with_aspect_ratio(
  width : Double?, // Known width (or None)
  height : Double?, // Known height (or None)
  aspect_ratio : Double?, // aspect_ratio = width / height
  min_width : Double, // 0.0 if no constraint
  max_width : Double, // Infinity if no constraint
  min_height : Double, // 0.0 if no constraint
  max_height : Double, // Infinity if no constraint
) -> (Double?, Double?) {
  match aspect_ratio {
    None => (width, height)
    Some(ar) if ar <= 0.0 => (width, height)
    Some(ar) =>
      match (width, height) {
        (Some(w), Some(_)) => {
          // Both known: aspect ratio overrides height
          let h = w / ar
          let h = clamp(h, min_height, max_height)
          (Some(w), Some(h))
        }
        (Some(w), None) => {
          // Width known: calculate height
          let h = w / ar
          let h = clamp(h, min_height, max_height)
          (Some(w), Some(h))
        }
        (None, Some(h)) => {
          // Height known: calculate width
          let w = h * ar
          let w = clamp(w, min_width, max_width)
          (Some(w), Some(h))
        }
        (None, None) => (None, None)
      }
  }
}

///|
/// Clamp a value between min and max
/// CSS spec: min takes precedence over max when they conflict
/// So apply max first (value cannot exceed max), then min (value cannot go below min)
pub fn clamp(value : Double, min_val : Double, max_val : Double) -> Double {
  // First apply max constraint
  let clamped = if value > max_val { max_val } else { value }
  // Then apply min constraint (min wins if min > max)
  if clamped < min_val {
    min_val
  } else {
    clamped
  }
}
