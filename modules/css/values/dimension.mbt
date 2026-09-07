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
      Show::output(v, logger)
      logger.write_string(")")
    }
    Percent(v) => {
      logger.write_string("Percent(")
      Show::output(v, logger)
      logger.write_string(")")
    }
    Auto => logger.write_string("Auto")
    MinContent => logger.write_string("MinContent")
    MaxContent => logger.write_string("MaxContent")
    FitContent(v) => {
      logger.write_string("FitContent(")
      Show::output(v, logger)
      logger.write_string(")")
    }
    Calc(px, pct) => {
      logger.write_string("Calc(")
      Show::output(px, logger)
      logger.write_string(", ")
      Show::output(pct, logger)
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
        Show::output(px, logger)
        logger.write_string(", ")
        Show::output(pct, logger)
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
  { x, y, width, height, }
}

///|
pub impl Show for BoundingRect with fn output(self, logger) {
  logger.write_string("BoundingRect { x: ")
  Show::output(self.x, logger)
  logger.write_string(", y: ")
  Show::output(self.y, logger)
  logger.write_string(", width: ")
  Show::output(self.width, logger)
  logger.write_string(", height: ")
  Show::output(self.height, logger)
  logger.write_string(" }")
}

///|
pub fn BoundingRect::zero() -> BoundingRect {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
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
  { x, y, width: right - x, height: bottom - y, }
}

///|
pub extend BoundingRect with Show::{to_string, output}

///|
pub extend Dimension with Debug::{to_repr}

///|
pub extend Dimension with Eq::{not_equal, equal}

///|
pub extend Dimension with Show::{to_string, output}

///|
pub extend MathOp with Debug::{to_repr}

///|
pub extend MathOp with Eq::{not_equal, equal}
