// =============================================================================
// Helper functions
// =============================================================================

///|
pub fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

// =============================================================================
// Core Types
// =============================================================================

///|
/// 2D size with width and height
pub struct Size[T] {
  width : T
  height : T
}

///|
pub fn[T] Size::new(width : T, height : T) -> Size[T] {
  { width, height }
}

///|
pub impl[T : Show] Show for Size[T] with fn output(self, logger) {
  logger.write_string("Size { width: ")
  self.width.output(logger)
  logger.write_string(", height: ")
  self.height.output(logger)
  logger.write_string(" }")
}

///|
pub fn Size::zero() -> Size[Double] {
  { width: 0.0, height: 0.0 }
}

///|
pub fn[T, U] Size::map(self : Size[T], f : (T) -> U) -> Size[U] {
  { width: f(self.width), height: f(self.height) }
}

///|
/// 2D point with x and y coordinates
pub struct Point[T] {
  x : T
  y : T
}

///|
pub fn[T] Point::new(x : T, y : T) -> Point[T] {
  { x, y }
}

///|
pub impl[T : Show] Show for Point[T] with fn output(self, logger) {
  logger.write_string("Point { x: ")
  self.x.output(logger)
  logger.write_string(", y: ")
  self.y.output(logger)
  logger.write_string(" }")
}

///|
pub fn Point::zero() -> Point[Double] {
  { x: 0.0, y: 0.0 }
}

///|
pub fn[T, U] Point::map(self : Point[T], f : (T) -> U) -> Point[U] {
  { x: f(self.x), y: f(self.y) }
}

///|
/// Rectangle with left, right, top, bottom edges
/// Used for margin, padding, border, inset
pub(all) struct Rect[T] {
  left : T
  right : T
  top : T
  bottom : T
} derive(Debug, Eq)

///|
pub fn[T] Rect::new(left : T, right : T, top : T, bottom : T) -> Rect[T] {
  { left, right, top, bottom }
}

///|
pub impl[T : Show] Show for Rect[T] with fn output(self, logger) {
  logger.write_string("Rect { left: ")
  self.left.output(logger)
  logger.write_string(", right: ")
  self.right.output(logger)
  logger.write_string(", top: ")
  self.top.output(logger)
  logger.write_string(", bottom: ")
  self.bottom.output(logger)
  logger.write_string(" }")
}

///|
pub fn Rect::zero() -> Rect[Double] {
  { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
}

///|
/// Create a rect with all sides set to the same value
pub fn[T] Rect::all(value : T) -> Rect[T] {
  { left: value, right: value, top: value, bottom: value }
}

///|
pub fn[T, U] Rect::map(self : Rect[T], f : (T) -> U) -> Rect[U] {
  {
    left: f(self.left),
    right: f(self.right),
    top: f(self.top),
    bottom: f(self.bottom),
  }
}

///|
/// Sum of left and right (horizontal axis)
pub fn Rect::horizontal_sum(self : Rect[Double]) -> Double {
  self.left + self.right
}

///|
/// Sum of top and bottom (vertical axis)
pub fn Rect::vertical_sum(self : Rect[Double]) -> Double {
  self.top + self.bottom
}

///|
/// A line segment with start and end points
pub struct Line[T] {
  start : T
  end : T
}

///|
pub fn[T] Line::new(start : T, end : T) -> Line[T] {
  { start, end }
}

///|
pub impl[T : Show] Show for Line[T] with fn output(self, logger) {
  logger.write_string("Line { start: ")
  self.start.output(logger)
  logger.write_string(", end: ")
  self.end.output(logger)
  logger.write_string(" }")
}

// =============================================================================
// Easing
// =============================================================================

///|
/// Step timing function jump position.
pub(all) enum StepPosition {
  Start
  End
  JumpNone
  JumpBoth
} derive(Debug, Eq)

///|
pub impl Show for StepPosition with fn output(self, logger) {
  match self {
    StepPosition::Start => logger.write_string("Start")
    StepPosition::End => logger.write_string("End")
    StepPosition::JumpNone => logger.write_string("JumpNone")
    StepPosition::JumpBoth => logger.write_string("JumpBoth")
  }
}

///|
/// One point in a CSS `linear()` easing function.
pub(all) struct LinearEasingPoint {
  input : Double
  output : Double
} derive(Debug, Eq)

///|
pub impl Show for LinearEasingPoint with fn output(self, logger) {
  logger.write_string("LinearEasingPoint { input: ")
  self.input.output(logger)
  logger.write_string(", output: ")
  self.output.output(logger)
  logger.write_string(" }")
}

///|
pub fn LinearEasingPoint::new(
  input : Double,
  output : Double,
) -> LinearEasingPoint {
  { input, output }
}

///|
/// CSS easing/timing-function value without binding it to transitions or
/// animations. Consumers can sample it against normalized progress `[0, 1]`.
pub(all) enum Easing {
  Linear
  Ease
  EaseIn
  EaseOut
  EaseInOut
  EaseInSine
  EaseOutSine
  EaseInOutSine
  EaseInQuad
  EaseOutQuad
  EaseInOutQuad
  EaseInCubic
  EaseOutCubic
  EaseInOutCubic
  EaseInQuart
  EaseOutQuart
  EaseInOutQuart
  EaseInQuint
  EaseOutQuint
  EaseInOutQuint
  EaseInExpo
  EaseOutExpo
  EaseInOutExpo
  EaseInCirc
  EaseOutCirc
  EaseInOutCirc
  EaseInBack
  EaseOutBack
  EaseInOutBack
  EaseInElastic
  EaseOutElastic
  EaseInOutElastic
  EaseInBounce
  EaseOutBounce
  EaseInOutBounce
  LinearFunction(Array[LinearEasingPoint])
  CubicBezier(Double, Double, Double, Double)
  Steps(Int, StepPosition)
} derive(Debug, Eq)

///|
/// Eased value at one point in an interpolation sequence.
pub(all) struct EasingFrame {
  progress : Double
  eased_progress : Double
  value : Double
}

///|
pub impl Show for EasingFrame with fn output(self, logger) {
  logger.write_string("EasingFrame { progress: ")
  self.progress.output(logger)
  logger.write_string(", eased_progress: ")
  self.eased_progress.output(logger)
  logger.write_string(", value: ")
  self.value.output(logger)
  logger.write_string(" }")
}

///|
fn easing_variant_name(easing : Easing) -> String? {
  match easing {
    Linear => Some("Linear")
    Ease => Some("Ease")
    EaseIn => Some("EaseIn")
    EaseOut => Some("EaseOut")
    EaseInOut => Some("EaseInOut")
    EaseInSine => Some("EaseInSine")
    EaseOutSine => Some("EaseOutSine")
    EaseInOutSine => Some("EaseInOutSine")
    EaseInQuad => Some("EaseInQuad")
    EaseOutQuad => Some("EaseOutQuad")
    EaseInOutQuad => Some("EaseInOutQuad")
    EaseInCubic => Some("EaseInCubic")
    EaseOutCubic => Some("EaseOutCubic")
    EaseInOutCubic => Some("EaseInOutCubic")
    EaseInQuart => Some("EaseInQuart")
    EaseOutQuart => Some("EaseOutQuart")
    EaseInOutQuart => Some("EaseInOutQuart")
    EaseInQuint => Some("EaseInQuint")
    EaseOutQuint => Some("EaseOutQuint")
    EaseInOutQuint => Some("EaseInOutQuint")
    EaseInExpo => Some("EaseInExpo")
    EaseOutExpo => Some("EaseOutExpo")
    EaseInOutExpo => Some("EaseInOutExpo")
    EaseInCirc => Some("EaseInCirc")
    EaseOutCirc => Some("EaseOutCirc")
    EaseInOutCirc => Some("EaseInOutCirc")
    EaseInBack => Some("EaseInBack")
    EaseOutBack => Some("EaseOutBack")
    EaseInOutBack => Some("EaseInOutBack")
    EaseInElastic => Some("EaseInElastic")
    EaseOutElastic => Some("EaseOutElastic")
    EaseInOutElastic => Some("EaseInOutElastic")
    EaseInBounce => Some("EaseInBounce")
    EaseOutBounce => Some("EaseOutBounce")
    EaseInOutBounce => Some("EaseInOutBounce")
    LinearFunction(_) | CubicBezier(_, _, _, _) | Steps(_, _) => None
  }
}

///|
pub impl Show for Easing with fn output(self, logger) {
  match easing_variant_name(self) {
    Some(name) => logger.write_string(name)
    None =>
      match self {
        LinearFunction(points) => {
          logger.write_string("LinearFunction(")
          logger.write_string("[")
          for i = 0; i < points.length(); i = i + 1 {
            if i > 0 {
              logger.write_string(", ")
            }
            points[i].output(logger)
          }
          logger.write_string("]")
          logger.write_string(")")
        }
        CubicBezier(x1, y1, x2, y2) => {
          logger.write_string("CubicBezier(")
          x1.output(logger)
          logger.write_string(", ")
          y1.output(logger)
          logger.write_string(", ")
          x2.output(logger)
          logger.write_string(", ")
          y2.output(logger)
          logger.write_string(")")
        }
        Steps(count, position) => {
          logger.write_string("Steps(")
          count.output(logger)
          logger.write_string(", ")
          position.output(logger)
          logger.write_string(")")
        }
        _ => ()
      }
  }
}

///|
pub fn Easing::cubic_bezier(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Easing {
  CubicBezier(x1, y1, x2, y2)
}

///|
pub fn Easing::steps(count : Int, position : StepPosition) -> Easing {
  Steps(count, position)
}

///|
pub fn Easing::linear(points : Array[LinearEasingPoint]) -> Easing? {
  if points.length() < 2 {
    return None
  }
  for i = 1; i < points.length(); i = i + 1 {
    if points[i].input < points[i - 1].input {
      return None
    }
  }
  Some(LinearFunction(points.copy()))
}

///|
fn apply_eased_progress(
  start_value : Double,
  end_value : Double,
  eased_progress : Double,
) -> Double {
  start_value + (end_value - start_value) * eased_progress
}

///|
fn clamp_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn cubic_bezier_axis(t : Double, p1 : Double, p2 : Double) -> Double {
  let inv = 1.0 - t
  3.0 * inv * inv * t * p1 + 3.0 * inv * t * t * p2 + t * t * t
}

///|
fn cubic_bezier_axis_derivative(t : Double, p1 : Double, p2 : Double) -> Double {
  let inv = 1.0 - t
  3.0 * inv * inv * p1 + 6.0 * inv * t * (p2 - p1) + 3.0 * t * t * (1.0 - p2)
}

///|
fn solve_cubic_bezier_t(x : Double, x1 : Double, x2 : Double) -> Double {
  let mut t = x
  for _i = 0; _i < 8; _i = _i + 1 {
    let x_at_t = cubic_bezier_axis(t, x1, x2)
    let dx = x_at_t - x
    if dx.abs() < 0.000001 {
      return t
    }
    let d = cubic_bezier_axis_derivative(t, x1, x2)
    if d.abs() < 0.000001 {
      break
    }
    t = clamp_unit(t - dx / d)
  }
  let mut low = 0.0
  let mut high = 1.0
  t = x
  for _i = 0; _i < 16; _i = _i + 1 {
    t = (low + high) / 2.0
    let x_at_t = cubic_bezier_axis(t, x1, x2)
    if (x_at_t - x).abs() < 0.000001 {
      return t
    }
    if x_at_t < x {
      low = t
    } else {
      high = t
    }
  }
  t
}

///|
fn pow(value : Double, exponent : Double) -> Double {
  @math.pow(value, exponent)
}

///|
fn ease_in_out_power(t : Double, exponent : Double) -> Double {
  if t < 0.5 {
    pow(2.0 * t, exponent) / 2.0
  } else {
    (2.0 - pow(-2.0 * t + 2.0, exponent)) / 2.0
  }
}

///|
fn ease_out_bounce(t : Double) -> Double {
  let n1 = 7.5625
  let d1 = 2.75
  if t < 1.0 / d1 {
    n1 * t * t
  } else if t < 2.0 / d1 {
    let x = t - 1.5 / d1
    n1 * x * x + 0.75
  } else if t < 2.5 / d1 {
    let x = t - 2.25 / d1
    n1 * x * x + 0.9375
  } else {
    let x = t - 2.625 / d1
    n1 * x * x + 0.984375
  }
}

///|
fn sample_linear_function(
  points : Array[LinearEasingPoint],
  t : Double,
) -> Double {
  if points.length() < 2 {
    return t
  }
  let mut point_a_index = 0
  for i = 0; i < points.length(); i = i + 1 {
    if points[i].input <= t {
      point_a_index = i
    }
  }
  if point_a_index == points.length() - 1 {
    point_a_index = point_a_index - 1
  }
  let point_a = points[point_a_index]
  let point_b = points[point_a_index + 1]
  if point_a.input == point_b.input {
    point_b.output
  } else {
    let progress_between_points = (t - point_a.input) /
      (point_b.input - point_a.input)
    point_a.output + progress_between_points * (point_b.output - point_a.output)
  }
}

///|
fn sample_steps(count : Int, position : StepPosition, t : Double) -> Double {
  if count <= 0 || (position == StepPosition::JumpNone && count <= 1) {
    return t
  }
  let steps = count.to_double()
  let mut current_step = (t * steps).floor()
  match position {
    StepPosition::Start | StepPosition::JumpBoth =>
      current_step = current_step + 1.0
    StepPosition::End | StepPosition::JumpNone => ()
  }
  if current_step < 0.0 {
    current_step = 0.0
  }
  let jumps = match position {
    StepPosition::JumpNone => count - 1
    StepPosition::JumpBoth => count + 1
    StepPosition::Start | StepPosition::End => count
  }
  let jumps = jumps.to_double()
  if current_step > jumps {
    current_step = jumps
  }
  current_step / jumps
}

///|
/// Sample the easing at normalized progress. Input progress is clamped to
/// `[0, 1]`; cubic-bezier output may overshoot if its Y control points do.
pub fn Easing::sample(self : Easing, progress : Double) -> Double {
  let t = clamp_unit(progress)
  let one_minus_t = 1.0 - t
  match self {
    Linear => t
    Ease => CubicBezier(0.25, 0.1, 0.25, 1.0).sample(t)
    EaseIn => CubicBezier(0.42, 0.0, 1.0, 1.0).sample(t)
    EaseOut => CubicBezier(0.0, 0.0, 0.58, 1.0).sample(t)
    EaseInOut => CubicBezier(0.42, 0.0, 0.58, 1.0).sample(t)
    EaseInSine => 1.0 - @math.cos(t * @math.PI / 2.0)
    EaseOutSine => @math.sin(t * @math.PI / 2.0)
    EaseInOutSine => -(@math.cos(@math.PI * t) - 1.0) / 2.0
    EaseInQuad => t * t
    EaseOutQuad => 1.0 - one_minus_t * one_minus_t
    EaseInOutQuad => ease_in_out_power(t, 2.0)
    EaseInCubic => t * t * t
    EaseOutCubic => 1.0 - one_minus_t * one_minus_t * one_minus_t
    EaseInOutCubic => ease_in_out_power(t, 3.0)
    EaseInQuart => t * t * t * t
    EaseOutQuart => 1.0 - pow(one_minus_t, 4.0)
    EaseInOutQuart => ease_in_out_power(t, 4.0)
    EaseInQuint => t * t * t * t * t
    EaseOutQuint => 1.0 - pow(one_minus_t, 5.0)
    EaseInOutQuint => ease_in_out_power(t, 5.0)
    EaseInExpo => if t == 0.0 { 0.0 } else { pow(2.0, 10.0 * t - 10.0) }
    EaseOutExpo => if t == 1.0 { 1.0 } else { 1.0 - pow(2.0, -10.0 * t) }
    EaseInOutExpo =>
      if t == 0.0 {
        0.0
      } else if t == 1.0 {
        1.0
      } else if t < 0.5 {
        pow(2.0, 20.0 * t - 10.0) / 2.0
      } else {
        (2.0 - pow(2.0, -20.0 * t + 10.0)) / 2.0
      }
    EaseInCirc => 1.0 - (1.0 - t * t).sqrt()
    EaseOutCirc => (1.0 - (t - 1.0) * (t - 1.0)).sqrt()
    EaseInOutCirc =>
      if t < 0.5 {
        (1.0 - (1.0 - pow(2.0 * t, 2.0)).sqrt()) / 2.0
      } else {
        ((1.0 - pow(-2.0 * t + 2.0, 2.0)).sqrt() + 1.0) / 2.0
      }
    EaseInBack => {
      let c1 = 1.70158
      let c3 = c1 + 1.0
      c3 * t * t * t - c1 * t * t
    }
    EaseOutBack => {
      let c1 = 1.70158
      let c3 = c1 + 1.0
      1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
    }
    EaseInOutBack => {
      let c1 = 1.70158
      let c2 = c1 * 1.525
      if t < 0.5 {
        pow(2.0 * t, 2.0) * ((c2 + 1.0) * 2.0 * t - c2) / 2.0
      } else {
        (pow(2.0 * t - 2.0, 2.0) * ((c2 + 1.0) * (t * 2.0 - 2.0) + c2) + 2.0) /
        2.0
      }
    }
    EaseInElastic =>
      if t == 0.0 {
        0.0
      } else if t == 1.0 {
        1.0
      } else {
        let c4 = 2.0 * @math.PI / 3.0
        -pow(2.0, 10.0 * t - 10.0) * @math.sin((t * 10.0 - 10.75) * c4)
      }
    EaseOutElastic =>
      if t == 0.0 {
        0.0
      } else if t == 1.0 {
        1.0
      } else {
        let c4 = 2.0 * @math.PI / 3.0
        pow(2.0, -10.0 * t) * @math.sin((t * 10.0 - 0.75) * c4) + 1.0
      }
    EaseInOutElastic =>
      if t == 0.0 {
        0.0
      } else if t == 1.0 {
        1.0
      } else {
        let c5 = 2.0 * @math.PI / 4.5
        if t < 0.5 {
          -(pow(2.0, 20.0 * t - 10.0) * @math.sin((20.0 * t - 11.125) * c5)) /
          2.0
        } else {
          pow(2.0, -20.0 * t + 10.0) * @math.sin((20.0 * t - 11.125) * c5) / 2.0 +
          1.0
        }
      }
    EaseInBounce => 1.0 - ease_out_bounce(1.0 - t)
    EaseOutBounce => ease_out_bounce(t)
    EaseInOutBounce =>
      if t < 0.5 {
        (1.0 - ease_out_bounce(1.0 - 2.0 * t)) / 2.0
      } else {
        (1.0 + ease_out_bounce(2.0 * t - 1.0)) / 2.0
      }
    LinearFunction(points) => sample_linear_function(points, t)
    CubicBezier(x1, y1, x2, y2) =>
      if t == 0.0 || t == 1.0 {
        t
      } else {
        let bezier_t = solve_cubic_bezier_t(t, x1, x2)
        cubic_bezier_axis(bezier_t, y1, y2)
      }
    Steps(count, position) => sample_steps(count, position, t)
  }
}

///|
/// Apply the easing to a numeric range at normalized progress.
pub fn Easing::apply(
  self : Easing,
  start_value : Double,
  end_value : Double,
  progress : Double,
) -> Double {
  apply_eased_progress(start_value, end_value, self.sample(progress))
}

///|
/// Build one frame with the clamped input progress, eased progress and value.
pub fn Easing::frame(
  self : Easing,
  start_value : Double,
  end_value : Double,
  progress : Double,
) -> EasingFrame {
  let progress = clamp_unit(progress)
  let eased_progress = self.sample(progress)
  {
    progress,
    eased_progress,
    value: apply_eased_progress(start_value, end_value, eased_progress),
  }
}

///|
/// Build evenly spaced frames across the easing range. The sequence includes
/// both endpoints when `count >= 2`.
pub fn Easing::frames(
  self : Easing,
  start_value : Double,
  end_value : Double,
  count : Int,
) -> Array[EasingFrame] {
  let frames : Array[EasingFrame] = []
  if count <= 0 {
    return frames
  }
  if count == 1 {
    frames.push(self.frame(start_value, end_value, 0.0))
    return frames
  }
  let last_index = count - 1
  let denominator = last_index.to_double()
  for i = 0; i < count; i = i + 1 {
    let progress = i.to_double() / denominator
    frames.push(self.frame(start_value, end_value, progress))
  }
  frames
}

///|
fn parse_easing_number(value : String) -> Double? {
  Some(@string.parse_double(value.trim().to_owned())) catch {
    _ => None
  }
}

///|
fn parse_easing_int(value : String) -> Int? {
  Some(@string.parse_int(value.trim().to_owned())) catch {
    _ => None
  }
}

///|
fn parse_function_args(value : String, prefix : String) -> Array[String]? {
  if !value.has_prefix(prefix) || !value.has_suffix(")") {
    return None
  }
  let inner = value.unsafe_substring(
    start=prefix.length(),
    end=value.length() - 1,
  )
  Some(inner.split(",").map(fn(part) { part.trim().to_owned() }).collect())
}

///|
priv struct LinearStop {
  output : Double
  inputs : Array[Double]
}

///|
priv struct PendingLinearPoint {
  input : Double?
  output : Double
}

///|
fn parse_easing_percentage(value : String) -> Double? {
  let value = value.trim().to_owned()
  if !value.has_suffix("%") {
    return None
  }
  let number = value.unsafe_substring(start=0, end=value.length() - 1)
  match parse_easing_number(number) {
    Some(v) => Some(v / 100.0)
    None => None
  }
}

///|
fn parse_linear_stop(value : String) -> LinearStop? {
  let tokens = value
    .split(" ")
    .map(fn(token) { token.trim().to_owned() })
    .filter(fn(token) { !token.is_empty() })
  let inputs : Array[Double] = []
  let mut output : Double? = None
  for token in tokens {
    match parse_easing_percentage(token) {
      Some(input) => inputs.push(input)
      None =>
        match parse_easing_number(token) {
          Some(value) =>
            match output {
              Some(_) => return None
              None => output = Some(value)
            }
          None => return None
        }
    }
  }
  if inputs.length() > 2 {
    return None
  }
  match output {
    Some(output) => Some({ output, inputs })
    None => None
  }
}

///|
fn resolve_pending_linear_points(
  pending : Array[PendingLinearPoint],
) -> Array[LinearEasingPoint]? {
  let points : Array[LinearEasingPoint] = []
  let mut index = 0
  while index < pending.length() {
    match pending[index].input {
      Some(input) => {
        points.push(LinearEasingPoint::new(input, pending[index].output))
        index = index + 1
      }
      None => {
        if points.length() == 0 {
          return None
        }
        let previous_input = points[points.length() - 1].input
        let run_start = index
        let mut run_end = index
        while run_end < pending.length() && pending[run_end].input is None {
          run_end = run_end + 1
        }
        if run_end >= pending.length() {
          return None
        }
        let next_input = match pending[run_end].input {
          Some(v) => v
          None => return None
        }
        let denominator = (run_end - run_start + 1).to_double()
        for i = run_start; i < run_end; i = i + 1 {
          let ratio = (i - run_start + 1).to_double() / denominator
          let input = previous_input + (next_input - previous_input) * ratio
          points.push(LinearEasingPoint::new(input, pending[i].output))
        }
        index = run_end
      }
    }
  }
  Some(points)
}

///|
fn create_linear_easing_function(stops : Array[LinearStop]) -> Easing? {
  if stops.length() < 2 {
    return None
  }
  let pending : Array[PendingLinearPoint] = []
  let mut largest_input = 0.0
  let mut has_largest_input = false
  let last_stop_index = stops.length() - 1
  for i = 0; i < stops.length(); i = i + 1 {
    let stop = stops[i]
    if stop.inputs.length() > 0 {
      let input = if has_largest_input && stop.inputs[0] < largest_input {
        largest_input
      } else {
        stop.inputs[0]
      }
      pending.push({ input: Some(input), output: stop.output })
      largest_input = input
      has_largest_input = true
      if stop.inputs.length() == 2 {
        let input = if stop.inputs[1] < largest_input {
          largest_input
        } else {
          stop.inputs[1]
        }
        pending.push({ input: Some(input), output: stop.output })
        largest_input = input
      }
    } else if i == 0 {
      pending.push({ input: Some(0.0), output: stop.output })
      largest_input = 0.0
      has_largest_input = true
    } else if i == last_stop_index {
      let input = if has_largest_input && largest_input > 1.0 {
        largest_input
      } else {
        1.0
      }
      pending.push({ input: Some(input), output: stop.output })
    } else {
      pending.push({ input: None, output: stop.output })
    }
  }
  match resolve_pending_linear_points(pending) {
    Some(points) => Easing::linear(points)
    None => None
  }
}

///|
fn parse_linear_function(value : String) -> Easing? {
  match parse_function_args(value, "linear(") {
    Some(parts) if parts.length() >= 2 => {
      let stops : Array[LinearStop] = []
      for part in parts {
        match parse_linear_stop(part) {
          Some(stop) => stops.push(stop)
          None => return None
        }
      }
      create_linear_easing_function(stops)
    }
    _ => None
  }
}

///|
fn parse_cubic_bezier(value : String) -> Easing? {
  match parse_function_args(value, "cubic-bezier(") {
    Some(parts) if parts.length() == 4 =>
      match
        (
          parse_easing_number(parts[0]),
          parse_easing_number(parts[1]),
          parse_easing_number(parts[2]),
          parse_easing_number(parts[3]),
        ) {
        (Some(x1), Some(y1), Some(x2), Some(y2)) =>
          if x1 >= 0.0 && x1 <= 1.0 && x2 >= 0.0 && x2 <= 1.0 {
            Some(CubicBezier(x1, y1, x2, y2))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_steps(value : String) -> Easing? {
  match parse_function_args(value, "steps(") {
    Some(parts) if parts.length() == 1 =>
      match parse_easing_int(parts[0]) {
        Some(count) if count > 0 => Some(Steps(count, StepPosition::End))
        _ => None
      }
    Some(parts) if parts.length() == 2 =>
      match parse_easing_int(parts[0]) {
        Some(count) if count > 0 => {
          let position = match parts[1].to_lower() {
            "start" | "jump-start" => Some(StepPosition::Start)
            "end" | "jump-end" => Some(StepPosition::End)
            "jump-none" => Some(StepPosition::JumpNone)
            "jump-both" => Some(StepPosition::JumpBoth)
            _ => None
          }
          match position {
            Some(StepPosition::JumpNone) if count <= 1 => None
            Some(pos) => Some(Steps(count, pos))
            None => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn remove_all(value : String, separator : String) -> String {
  value.split(separator).map(fn(part) { part.to_owned() }).collect().join("")
}

///|
fn normalize_easing_name(value : String) -> String {
  let lower = value.trim().to_lower().to_owned()
  remove_all(remove_all(remove_all(lower, "-"), "_"), " ")
}

///|
fn parse_named_easing(value : String) -> Easing? {
  match normalize_easing_name(value) {
    "linear" => Some(Linear)
    "ease" => Some(Ease)
    "easein" => Some(EaseIn)
    "easeout" => Some(EaseOut)
    "easeinout" => Some(EaseInOut)
    "stepstart" => Some(Steps(1, StepPosition::Start))
    "stepend" => Some(Steps(1, StepPosition::End))
    "easeinsine" => Some(EaseInSine)
    "easeoutsine" => Some(EaseOutSine)
    "easeinoutsine" => Some(EaseInOutSine)
    "easeinquad" => Some(EaseInQuad)
    "easeoutquad" => Some(EaseOutQuad)
    "easeinoutquad" => Some(EaseInOutQuad)
    "easeincubic" => Some(EaseInCubic)
    "easeoutcubic" => Some(EaseOutCubic)
    "easeinoutcubic" => Some(EaseInOutCubic)
    "easeinquart" => Some(EaseInQuart)
    "easeoutquart" => Some(EaseOutQuart)
    "easeinoutquart" => Some(EaseInOutQuart)
    "easeinquint" => Some(EaseInQuint)
    "easeoutquint" => Some(EaseOutQuint)
    "easeinoutquint" => Some(EaseInOutQuint)
    "easeinexpo" => Some(EaseInExpo)
    "easeoutexpo" => Some(EaseOutExpo)
    "easeinoutexpo" => Some(EaseInOutExpo)
    "easeincirc" => Some(EaseInCirc)
    "easeoutcirc" => Some(EaseOutCirc)
    "easeinoutcirc" => Some(EaseInOutCirc)
    "easeinback" => Some(EaseInBack)
    "easeoutback" => Some(EaseOutBack)
    "easeinoutback" => Some(EaseInOutBack)
    "easeinelastic" => Some(EaseInElastic)
    "easeoutelastic" => Some(EaseOutElastic)
    "easeinoutelastic" => Some(EaseInOutElastic)
    "easeinbounce" => Some(EaseInBounce)
    "easeoutbounce" => Some(EaseOutBounce)
    "easeinoutbounce" => Some(EaseInOutBounce)
    _ => None
  }
}

///|
/// Parse a CSS easing keyword or basic timing function.
pub fn parse_easing(value : String) -> Easing? {
  let normalized = value.trim().to_lower().to_owned()
  match parse_named_easing(normalized) {
    Some(easing) => Some(easing)
    None =>
      match parse_linear_function(normalized) {
        Some(easing) => Some(easing)
        None =>
          match parse_cubic_bezier(normalized) {
            Some(easing) => Some(easing)
            None => parse_steps(normalized)
          }
      }
  }
}

///|
/// CSS comparison/math function selector for min() / max() / clamp().
pub(all) enum MathOp {
  Min
  Max
  Clamp
} derive(Eq, Debug)

///|
/// Apply a min()/max()/clamp() reduction over already-resolved scalar values.
/// clamp expects exactly 3 values (lo, val, hi); other lengths fall back to the
/// first value (or 0.0 when empty) so callers never panic on malformed input.
pub fn apply_math_op(op : MathOp, vals : Array[Double]) -> Double {
  match op {
    Clamp =>
      if vals.length() == 3 {
        // CSS: clamp(MIN, VAL, MAX) == max(MIN, min(VAL, MAX)). This stays
        // correct even when MIN > MAX (it returns MIN), unlike ordered ifs.
        let lo = vals[0]
        let mid = vals[1]
        let hi = vals[2]
        let inner = if mid < hi { mid } else { hi }
        if lo > inner {
          lo
        } else {
          inner
        }
      } else if vals.length() > 0 {
        vals[0]
      } else {
        0.0
      }
    _ => {
      if vals.is_empty() {
        return 0.0
      }
      let mut acc = vals[0]
      for k = 1; k < vals.length(); k = k + 1 {
        match op {
          Min => if vals[k] < acc { acc = vals[k] }
          _ => if vals[k] > acc { acc = vals[k] }
        }
      }
      acc
    }
  }
}

///|
/// CSS dimension value: length, percentage, auto, or intrinsic sizing keywords
pub(all) enum Dimension {
  Length(Double)
  Percent(Double) // 0.0 to 1.0
  Auto
  MinContent // Intrinsic minimum content size
  MaxContent // Intrinsic maximum content size
  FitContent(Double) // fit-content(length) - clamp between min-content and max-content
  // Mixed calc() carrying both a fixed length (px) and a percentage ratio,
  // e.g. calc(100% - 20px) => Calc(px=-20.0, percent=1.0). Resolves to
  // `px + percent * basis` once a containing-block basis is known at layout
  // time. Pure-length / pure-percent calc() stay Length / Percent.
  Calc(Double, Double) // Calc(px, percent_ratio)
  // min()/max()/clamp() whose arguments mix length and percentage and so cannot
  // be ordered until a containing-block basis is known. Each argument is a
  // linear (px, percent_ratio) form. Resolved at layout time like Calc.
  MathFn(MathOp, Array[(Double, Double)])
} derive(Debug, Eq)

///|
/// Check if dimension equals a specific length value
pub fn Dimension::eq_length(self : Dimension, value : Double) -> Bool {
  match self {
    Length(v) => (v - value).abs() < 0.0001
    _ => false
  }
}

///|
/// Check if dimension equals a specific percent value
pub fn Dimension::eq_percent(self : Dimension, value : Double) -> Bool {
  match self {
    Percent(v) => (v - value).abs() < 0.0001
    _ => false
  }
}

///|
pub impl Show for Dimension with fn output(self, logger) {
  match self {
    Length(v) => {
      logger.write_string("Length(")
      v.output(logger)
      logger.write_string(")")
    }
    Percent(v) => {
      logger.write_string("Percent(")
      v.output(logger)
      logger.write_string(")")
    }
    Auto => logger.write_string("Auto")
    MinContent => logger.write_string("MinContent")
    MaxContent => logger.write_string("MaxContent")
    FitContent(v) => {
      logger.write_string("FitContent(")
      v.output(logger)
      logger.write_string(")")
    }
    Calc(px, pct) => {
      logger.write_string("Calc(")
      px.output(logger)
      logger.write_string(", ")
      pct.output(logger)
      logger.write_string(")")
    }
    MathFn(op, args) => {
      logger.write_string("MathFn(")
      logger.write_string(
        match op {
          Min => "Min"
          Max => "Max"
          Clamp => "Clamp"
        },
      )
      logger.write_string(", [")
      for i = 0; i < args.length(); i = i + 1 {
        if i > 0 {
          logger.write_string(", ")
        }
        let (px, pct) = args[i]
        logger.write_string("(")
        px.output(logger)
        logger.write_string(", ")
        pct.output(logger)
        logger.write_string(")")
      }
      logger.write_string("])")
    }
  }
}

///|
/// Resolve dimension to concrete value
/// context: parent size for percentage calculation
/// Note: MinContent, MaxContent, FitContent return None - they need intrinsic size calculation
pub fn Dimension::resolve(self : Dimension, context : Double) -> Double? {
  match self {
    Length(v) => Some(v)
    Percent(v) => Some(context * v)
    Calc(px, pct) => Some(px + pct * context)
    MathFn(op, args) =>
      if args.is_empty() {
        None
      } else {
        Some(apply_math_op(op, args.map(fn(a) { a.0 + a.1 * context })))
      }
    Auto => None
    MinContent => None // Requires intrinsic size calculation
    MaxContent => None // Requires intrinsic size calculation
    FitContent(_) => None // Requires intrinsic size calculation
  }
}

///|
/// Resolve with fallback value for Auto
///
/// Matches `self` directly rather than going through `resolve`, which returns a
/// `Double?` and so boxes a `Some(..)` on every call. This is on the hot layout
/// path (every width/height/padding/margin per element, plus all four sides via
/// `resolve_rect`), where the intermediate `Option` allocation dominated.
pub fn Dimension::resolve_or(
  self : Dimension,
  context : Double,
  fallback : Double,
) -> Double {
  match self {
    Length(v) => v
    Percent(v) => context * v
    Calc(px, pct) => px + pct * context
    MathFn(op, args) =>
      if args.is_empty() {
        fallback
      } else {
        apply_math_op(op, args.map(fn(a) { a.0 + a.1 * context }))
      }
    Auto => fallback
    MinContent => fallback // Requires intrinsic size calculation
    MaxContent => fallback
    FitContent(_) => fallback
  }
}

///|
/// Check if dimension is a definite value (Length or Percent)
pub fn Dimension::is_definite(self : Dimension) -> Bool {
  match self {
    Length(_) | Percent(_) | Calc(_, _) | MathFn(_, _) => true
    _ => false
  }
}

///|
/// Check if dimension requires intrinsic sizing
pub fn Dimension::is_intrinsic(self : Dimension) -> Bool {
  match self {
    MinContent | MaxContent | FitContent(_) => true
    _ => false
  }
}

///|
/// Resolve dimension to length, treating intrinsic keywords as fallback
pub fn Dimension::resolve_or_intrinsic(
  self : Dimension,
  context : Double,
  fallback : Double,
) -> Double {
  match self {
    Length(v) => v
    Percent(p) => context * p
    Calc(px, p) => px + context * p
    MathFn(op, args) =>
      if args.is_empty() {
        fallback
      } else {
        apply_math_op(op, args.map(fn(a) { a.0 + a.1 * context }))
      }
    Auto => fallback
    MinContent => fallback // Intrinsic sizing handled by layout engine
    MaxContent => fallback
    FitContent(_) => fallback
  }
}

///|
/// Resolve a Rect[Dimension] (margin/padding/border) to Rect[Double]
/// Uses parent_width for percentage resolution (CSS spec: percentages resolve against width)
pub fn resolve_rect(
  rect : Rect[Dimension],
  parent_width : Double,
) -> Rect[Double] {
  {
    left: rect.left.resolve_or(parent_width, 0.0),
    right: rect.right.resolve_or(parent_width, 0.0),
    top: rect.top.resolve_or(parent_width, 0.0),
    bottom: rect.bottom.resolve_or(parent_width, 0.0),
  }
}

///|
/// Resolve a dimension rect for intrinsic sizing
/// Percentages resolve to 0 in intrinsic sizing contexts
pub fn resolve_rect_intrinsic(rect : Rect[Dimension]) -> Rect[Double] {
  fn resolve_intrinsic(dim : Dimension) -> Double {
    match dim {
      Length(v) => v
      Percent(_) => 0.0
      Calc(px, _) => px // percent resolves to 0 in intrinsic context; keep px
      MathFn(op, args) =>
        // intrinsic context: percentages resolve to 0, so keep px parts only
        if args.is_empty() {
          0.0
        } else {
          apply_math_op(op, args.map(fn(a) { a.0 }))
        }
      Auto => 0.0
      MinContent => 0.0 // Not applicable for margin/padding/border
      MaxContent => 0.0
      FitContent(_) => 0.0
    }
  }

  {
    left: resolve_intrinsic(rect.left),
    right: resolve_intrinsic(rect.right),
    top: resolve_intrinsic(rect.top),
    bottom: resolve_intrinsic(rect.bottom),
  }
}

///|
/// BoundingRect - the output of layout computation
/// Matches browser's getBoundingClientRect()
pub(all) struct BoundingRect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn BoundingRect::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> BoundingRect {
  { x, y, width, height }
}

///|
pub impl Show for BoundingRect with fn output(self, logger) {
  logger.write_string("BoundingRect { x: ")
  self.x.output(logger)
  logger.write_string(", y: ")
  self.y.output(logger)
  logger.write_string(", width: ")
  self.width.output(logger)
  logger.write_string(", height: ")
  self.height.output(logger)
  logger.write_string(" }")
}

///|
pub fn BoundingRect::zero() -> BoundingRect {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
/// Get the right edge (x + width)
pub fn BoundingRect::right(self : BoundingRect) -> Double {
  self.x + self.width
}

///|
/// Get the bottom edge (y + height)
pub fn BoundingRect::bottom(self : BoundingRect) -> Double {
  self.y + self.height
}

///|
/// Calculate the area of the bounding rect
pub fn BoundingRect::area(self : BoundingRect) -> Double {
  self.width * self.height
}

///|
/// Calculate union of two bounding rects
pub fn BoundingRect::union(
  self : BoundingRect,
  other : BoundingRect,
) -> BoundingRect {
  let x = min(self.x, other.x)
  let y = min(self.y, other.y)
  let right = max(self.right(), other.right())
  let bottom = max(self.bottom(), other.bottom())
  { x, y, width: right - x, height: bottom - y }
}

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
