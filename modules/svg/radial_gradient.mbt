// ============================================================================
// RadialGradient
// ============================================================================

///|
/// Radial gradient definition
pub(all) struct RadialGradient {
  cx : Double // Center x (0.0-1.0 relative)
  cy : Double // Center y
  fx : Double // Focal point x
  fy : Double // Focal point y
  r : Double // Radius
  stops : Array[GradientStop]
  spread_method : SpreadMethod
  units : GradientUnits
  transform : Transform
}

///|
pub fn RadialGradient::new(
  cx : Double,
  cy : Double,
  r : Double,
  stops : Array[GradientStop],
) -> RadialGradient {
  {
    cx,
    cy,
    fx: cx,
    fy: cy,
    r,
    stops,
    spread_method: Pad,
    units: ObjectBoundingBox,
    transform: Transform::identity(),
  }
}

///|
fn interpolate_gradient_color(t : Double, stops : Array[GradientStop]) -> Color {
  if stops.is_empty() {
    return Color::black()
  }
  if stops.length() == 1 {
    return stops[0].color
  }
  if t < stops[0].offset {
    return stops[0].color
  }
  let mut left_index = 0
  for index in 1..<stops.length() {
    if stops[index].offset <= t {
      left_index = index
    } else {
      break
    }
  }
  if left_index == stops.length() - 1 {
    return stops[left_index].color
  }
  let left = stops[left_index]
  let right = stops[left_index + 1]
  if right.offset <= left.offset {
    return right.color
  }
  let amount = max(
    0.0,
    min(1.0, (t - left.offset) / (right.offset - left.offset)),
  )
  let left_color = PremulColor16::from_color(left.color)
  let right_color = PremulColor16::from_color(right.color)
  PremulColor16::{
    r: clamp_channel16(
      (left_color.r.to_double() * (1.0 - amount) +
      right_color.r.to_double() * amount)
      .round()
      .to_int(),
    ),
    g: clamp_channel16(
      (left_color.g.to_double() * (1.0 - amount) +
      right_color.g.to_double() * amount)
      .round()
      .to_int(),
    ),
    b: clamp_channel16(
      (left_color.b.to_double() * (1.0 - amount) +
      right_color.b.to_double() * amount)
      .round()
      .to_int(),
    ),
    a: clamp_channel16(
      (left_color.a.to_double() * (1.0 - amount) +
      right_color.a.to_double() * amount)
      .round()
      .to_int(),
    ),
  }.to_color()
}
