// =============================================================================
// Multi-column / Fragmentation Parsing
// =============================================================================

///|
fn parse_column_count(value : String) -> Int? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() || trimmed == "auto" {
    return None
  }
  try {
    let parsed = @string.parse_int(trimmed)
    if parsed >= 1 {
      Some(parsed)
    } else {
      None
    }
  } catch {
    _ => None
  }
}

///|
fn parse_column_width(value : String, ctx : ComputeContext) -> @types.Dimension {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() || trimmed == "auto" {
    return Auto
  }
  let dim = resolve_dimension_with_calc_percent_fallback(trimmed, ctx)
  match dim {
    Length(v) =>
      if v > 0.0 {
        Length(v)
      } else {
        Auto
      }
    Percent(v) =>
      if v > 0.0 {
        Percent(v)
      } else {
        Auto
      }
    Calc(px, pct) =>
      if px > 0.0 || pct > 0.0 {
        Calc(px, pct)
      } else {
        Auto
      }
    MathFn(op, args) => MathFn(op, args)
    Auto
    | MinContent
    | MaxContent
    | FitContent(_) => Auto
  }
}

///|
fn parse_column_fill(value : String) -> @style.ColumnFill {
  match value.trim().to_owned() {
    "auto" => Auto
    _ => Balance
  }
}

///|
fn parse_break_before(value : String) -> @style.BreakBefore {
  match value.trim().to_owned() {
    "column" => Column
    "avoid" => Avoid
    _ => Auto
  }
}

///|
fn parse_break_inside(value : String) -> @style.BreakInside {
  match value.trim().to_owned() {
    "avoid" => Avoid
    _ => Auto
  }
}

///|
fn parse_column_span(value : String) -> @style.ColumnSpan {
  match value.trim().to_owned() {
    "all" => All
    _ => None
  }
}

///|
fn parse_columns_shorthand(
  value : String,
  ctx : ComputeContext,
) -> (Int?, @types.Dimension)? {
  let parts : Array[StringView] = value
    .trim()
    .split(" ")
    .filter(fn(s) { !s.is_empty() })
    .collect()
  if parts.length() == 0 {
    return None
  }
  let mut count : Int? = None
  let mut width = @types.Dimension::Auto
  for part in parts {
    let token = part.to_owned()
    if token == "auto" {
      continue
    }
    if count is None {
      match parse_column_count(token) {
        Some(v) => {
          count = Some(v)
          continue
        }
        None => ()
      }
    }
    let parsed_width = parse_column_width(token, ctx)
    match parsed_width {
      Auto => ()
      _ => width = parsed_width
    }
  }
  Some((count, width))
}

// =============================================================================
// Containment Parsing
// =============================================================================

///|
/// Parse contain-intrinsic-inline-size / contain-intrinsic-block-size.
/// Returns a content-box fallback length in px, or None for none/auto.
fn parse_contain_intrinsic_axis(
  value : String,
  ctx : ComputeContext,
) -> Double? {
  let v = resolve_all_vars(value, ctx).trim().to_owned()
  if v.is_empty() || v == "none" || v == "auto" {
    return None
  }
  match resolve_dimension(v, ctx) {
    Length(length) => if length > 0.0 { Some(length) } else { Some(0.0) }
    _ => None
  }
}

///|
/// Parse contain-intrinsic-size shorthand.
/// One value applies to both inline/block axes; two values map to inline then block.
fn parse_contain_intrinsic_size(
  value : String,
  ctx : ComputeContext,
) -> (Double?, Double?)? {
  let v = resolve_all_vars(value, ctx).trim().to_owned()
  if v.is_empty() {
    return None
  }
  let axis_values : Array[Double?] = []
  let parts = v.split(" ")
  for part in parts {
    let p = part.to_owned().trim().to_owned()
    if p.is_empty() || p == "auto" {
      continue
    }
    if p == "none" {
      axis_values.push(None)
      continue
    }
    match parse_contain_intrinsic_axis(p, ctx) {
      Some(length) => axis_values.push(Some(length))
      None => ()
    }
  }
  if axis_values.length() == 0 {
    None
  } else if axis_values.length() == 1 {
    Some((axis_values[0], axis_values[0]))
  } else {
    Some((axis_values[0], axis_values[1]))
  }
}

///|
/// Parse contain property
fn parse_contain(value : String) -> @style.Contain {
  let v = value.trim().to_owned()
  // Handle keywords
  if v == "none" {
    return @style.Contain::none()
  }
  if v == "strict" {
    return @style.Contain::strict()
  }
  if v == "content" {
    return @style.Contain::content()
  }
  // Parse space-separated values
  let mut result = @style.Contain::none()
  let parts = v.split(" ")
  for part in parts {
    let p = part.to_owned().trim()
    if p == "size" {
      result = { ..result, size: true }
    } else if p == "inline-size" {
      result = { ..result, inline_size: true }
    } else if p == "layout" {
      result = { ..result, layout: true }
    } else if p == "paint" {
      result = { ..result, paint: true }
    } else if p == "style" {
      result = { ..result, style: true }
    }
  }
  result
}

///|
fn merge_contain(
  base : @style.Contain,
  extra : @style.Contain,
) -> @style.Contain {
  let merged : @style.Contain = {
    size: base.size || extra.size,
    inline_size: base.inline_size || extra.inline_size,
    layout: base.layout || extra.layout,
    paint: base.paint || extra.paint,
    style: base.style || extra.style,
  }
  if merged.size {
    { ..merged, inline_size: false }
  } else {
    merged
  }
}

///|
/// Parse container-type into implied contain bits.
/// Supported: normal | size | inline-size
fn parse_container_type(value : String) -> @style.Contain? {
  match value.trim().to_owned() {
    "normal" => Some(@style.Contain::none())
    "size" => Some({ ..@style.Contain::none(), size: true, style: true })
    "inline-size" =>
      Some({ ..@style.Contain::none(), inline_size: true, style: true })
    _ => None
  }
}

// Paint Property Parsing
// =============================================================================

///|
/// Parse visibility property
fn parse_visibility(value : String) -> @style.Visibility {
  match value.trim().to_owned() {
    "visible" => Visible
    "hidden" => Hidden
    "collapse" => Collapse
    _ => Visible
  }
}

///|
fn parse_pointer_events(value : String) -> @style.PointerEvents {
  match value.trim().to_owned() {
    "none" => None
    _ => Auto
  }
}

///|
/// Parse vertical-align property
fn parse_vertical_align(value : String) -> @style.VerticalAlign {
  match value.trim().to_owned() {
    "baseline" => Baseline
    "top" => Top
    "middle" => Middle
    "bottom" => Bottom
    "text-top" => TextTop
    "text-bottom" => TextBottom
    "sub" => Sub
    "super" => Super
    _ => Baseline
  }
}

///|
/// Parse z-index property
fn parse_z_index(value : String) -> @style.ZIndex {
  let trimmed = value.trim().to_owned()
  if trimmed == "auto" {
    Auto
  } else {
    try {
      let v = @string.parse_int(trimmed)
      Value(v)
    } catch {
      _ => Auto
    }
  }
}

///|
/// Parse opacity property (0.0 to 1.0)
fn parse_opacity(value : String) -> Double {
  let trimmed = value.trim().to_owned()
  try {
    let v = @string.parse_double(trimmed)
    // Clamp to valid range
    if v < 0.0 {
      0.0
    } else if v > 1.0 {
      1.0
    } else {
      v
    }
  } catch {
    _ => 1.0
  }
}
