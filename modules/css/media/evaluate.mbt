///|
/// CSS Media Query Evaluation
/// Evaluates media queries against viewport dimensions

///|
/// Color scheme preference
pub(all) enum ColorScheme {
  Light
  Dark
} derive(Eq, Debug)

///|
pub impl Show for ColorScheme with fn output(self, logger) {
  logger.write_string(
    match self {
      Light => "Light"
      Dark => "Dark"
    },
  )
}

///|
/// Environment for evaluating media queries
pub(all) struct MediaEnvironment {
  viewport_width : Double
  viewport_height : Double
  device_pixel_ratio : Double
  color_scheme : ColorScheme
}

///|
/// Create a default media environment for screen
pub fn MediaEnvironment::new(
  viewport_width : Double,
  viewport_height : Double,
) -> MediaEnvironment {
  {
    viewport_width,
    viewport_height,
    device_pixel_ratio: 1.0,
    color_scheme: Light,
  }
}

///|
/// Create a media environment with color scheme
pub fn MediaEnvironment::with_color_scheme(
  viewport_width : Double,
  viewport_height : Double,
  color_scheme : ColorScheme,
) -> MediaEnvironment {
  { viewport_width, viewport_height, device_pixel_ratio: 1.0, color_scheme }
}

///|
/// Evaluate a media query list against the environment
/// Returns true if ANY query in the list matches (OR semantics)
pub fn MediaQueryList::evaluate(
  self : MediaQueryList,
  env : MediaEnvironment,
) -> Bool {
  // Empty query list matches everything
  if self.queries.is_empty() {
    return true
  }
  // Any matching query makes the whole list match
  for query in self.queries {
    if query.evaluate(env) {
      return true
    }
  }
  false
}

///|
/// Evaluate a single media query
pub fn MediaQuery::evaluate(self : MediaQuery, env : MediaEnvironment) -> Bool {
  let result = self.evaluate_without_negation(env)
  if self.negated {
    !result
  } else {
    result
  }
}

///|
/// Evaluate a media query without considering negation
fn MediaQuery::evaluate_without_negation(
  self : MediaQuery,
  env : MediaEnvironment,
) -> Bool {
  // Check media type
  match self.media_type {
    Some(Print) => return false // We're rendering to screen
    Some(Speech) => return false
    Some(All) | Some(Screen) | None => ()
  }
  // Check all conditions (AND semantics)
  for condition in self.conditions {
    if !evaluate_feature(condition, env) {
      return false
    }
  }
  true
}

///|
/// Evaluate a single media feature
fn evaluate_feature(feature : MediaFeature, env : MediaEnvironment) -> Bool {
  match feature {
    // Width features
    Width(value) =>
      match value {
        Some(v) => compare_value(v, env.viewport_width, Eq, env)
        None => true // Boolean context: width exists
      }
    MinWidth(value) => compare_value(value, env.viewport_width, Ge, env)
    MaxWidth(value) => compare_value(value, env.viewport_width, Le, env)
    WidthRange(op, value) =>
      compare_value_with_op(value, env.viewport_width, op, env)
    // Height features
    Height(value) =>
      match value {
        Some(v) => compare_value(v, env.viewport_height, Eq, env)
        None => true
      }
    MinHeight(value) => compare_value(value, env.viewport_height, Ge, env)
    MaxHeight(value) => compare_value(value, env.viewport_height, Le, env)
    HeightRange(op, value) =>
      compare_value_with_op(value, env.viewport_height, op, env)
    // Aspect ratio
    AspectRatio(value) =>
      match value {
        Some(v) =>
          compare_aspect_ratio(v, env.viewport_width, env.viewport_height, Eq)
        None => true
      }
    MinAspectRatio(value) =>
      compare_aspect_ratio(value, env.viewport_width, env.viewport_height, Ge)
    MaxAspectRatio(value) =>
      compare_aspect_ratio(value, env.viewport_width, env.viewport_height, Le)
    // Orientation
    Orientation(value) =>
      match value.to_lower() {
        "portrait" => env.viewport_height >= env.viewport_width
        "landscape" => env.viewport_width > env.viewport_height
        _ => true
      }
    // Resolution
    Resolution(value) =>
      match value {
        Some(v) => compare_resolution(v, env.device_pixel_ratio, Eq)
        None => true
      }
    MinResolution(value) =>
      compare_resolution(value, env.device_pixel_ratio, Ge)
    MaxResolution(value) =>
      compare_resolution(value, env.device_pixel_ratio, Le)
    // Boolean features (always true for screen)
    Color => true
    ColorIndex => false
    ColorGamut => true
    Grid => false
    Hover => true // Assume hover is available
    Monochrome => false
    Pointer => true // Assume pointer is available
    Scripting => true
    Update => true
    // Discrete features
    DisplayMode(_) => true // Assume browser mode
    PrefersColorScheme(scheme) =>
      match scheme.to_lower() {
        "dark" => env.color_scheme == Dark
        "light" => env.color_scheme == Light
        _ => true // Unknown scheme matches any
      }
    PrefersReducedMotion(_) => true // Accept any motion preference
    // Unknown features default to true
    Custom(_, _) => true
  }
}

///|
/// Convert media value to pixels. Viewport-relative units (vw/vh/vmin/vmax)
/// resolve against `env`'s viewport, so `50vw` on a 1000px-wide viewport is
/// 500px regardless of which dimension the feature compares against.
fn to_pixels(value : MediaValue, env : MediaEnvironment) -> Double {
  match value {
    Number(n) => n
    Dimension(n, unit) =>
      match unit.to_lower() {
        "px" => n
        "em" | "rem" => n * 16.0 // Assume 16px base font size
        "vw" | "dvw" | "svw" | "lvw" => n * env.viewport_width / 100.0
        "vh" | "dvh" | "svh" | "lvh" => n * env.viewport_height / 100.0
        "vmin" => {
          let base = if env.viewport_width < env.viewport_height {
            env.viewport_width
          } else {
            env.viewport_height
          }
          n * base / 100.0
        }
        "vmax" => {
          let base = if env.viewport_width > env.viewport_height {
            env.viewport_width
          } else {
            env.viewport_height
          }
          n * base / 100.0
        }
        "pt" => n * 1.333333 // 1pt = 4/3 px
        "pc" => n * 16.0 // 1pc = 16px
        "in" => n * 96.0 // 1in = 96px
        "cm" => n * 37.8 // 1cm ≈ 37.8px
        "mm" => n * 3.78 // 1mm ≈ 3.78px
        _ => n
      }
    Ratio(_, _) => 0.0 // Ratios aren't pixel values
    Ident(_) => 0.0 // Identifiers aren't pixel values
  }
}

///|
/// Compare a media value against an actual value
/// For min-X: actual >= query (Le means query <= actual)
/// For max-X: actual <= query (Ge means query >= actual)
fn compare_value(
  query_value : MediaValue,
  actual : Double,
  op : RangeOp,
  env : MediaEnvironment,
) -> Bool {
  let query_pixels = to_pixels(query_value, env)
  match op {
    Eq => (actual - query_pixels).abs() < 0.01
    Lt => actual < query_pixels
    Le => actual <= query_pixels
    Gt => actual > query_pixels
    Ge => actual >= query_pixels
  }
}

///|
/// Compare value with explicit range-syntax operator (e.g., width >= 500px).
/// Identical semantics to `compare_value`; kept as a thin alias for clarity at
/// call sites that came from the parser's range syntax.
fn compare_value_with_op(
  query_value : MediaValue,
  actual : Double,
  op : RangeOp,
  env : MediaEnvironment,
) -> Bool {
  compare_value(query_value, actual, op, env)
}

///|
/// Compare aspect ratio
fn compare_aspect_ratio(
  query_value : MediaValue,
  width : Double,
  height : Double,
  op : RangeOp,
) -> Bool {
  if height == 0.0 {
    return false
  }
  let actual_ratio = width / height
  let query_ratio = match query_value {
    Ratio(w, h) => if h == 0 { 0.0 } else { w.to_double() / h.to_double() }
    Number(n) => n
    _ => 1.0
  }
  match op {
    Eq => (actual_ratio - query_ratio).abs() < 0.01
    Lt => actual_ratio < query_ratio
    Le => actual_ratio <= query_ratio
    Gt => actual_ratio > query_ratio
    Ge => actual_ratio >= query_ratio
  }
}

///|
/// Compare resolution (device pixel ratio)
fn compare_resolution(
  query_value : MediaValue,
  actual_dpr : Double,
  op : RangeOp,
) -> Bool {
  let query_dpr = match query_value {
    Number(n) => n
    Dimension(n, unit) =>
      match unit.to_lower() {
        "dppx" | "x" => n
        "dpi" => n / 96.0
        "dpcm" => n / 37.8
        _ => n
      }
    _ => 1.0
  }
  match op {
    Eq => (actual_dpr - query_dpr).abs() < 0.01
    Lt => actual_dpr < query_dpr
    Le => actual_dpr <= query_dpr
    Gt => actual_dpr > query_dpr
    Ge => actual_dpr >= query_dpr
  }
}
