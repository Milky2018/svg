///|
/// Parse border-collapse value
fn parse_border_collapse(value : String) -> @style.BorderCollapse {
  match value.trim() {
    "collapse" => @style.Collapse
    "separate" => @style.Separate
    _ => @style.Separate
  }
}

///|
/// Border style keywords that suppress used border width.
fn is_none_border_style_enum(style : @style.BorderStyle) -> Bool {
  style == @style.BorderStyle::None || style == @style.BorderStyle::Hidden
}

///|
fn is_none_border_style(value : String) -> Bool {
  let v = value.trim().to_lower()
  v == "none" || v == "hidden"
}

///|
fn extract_border_color_from_shorthand(
  value : String,
  ctx : ComputeContext,
) -> @types.Color {
  let parts = split_whitespace(value)
  for part in parts {
    let lower = part.to_lower()
    // Skip border-style keywords and width keywords/values
    match lower {
      "none"
      | "hidden"
      | "dotted"
      | "dashed"
      | "solid"
      | "double"
      | "groove"
      | "ridge"
      | "inset"
      | "outset"
      | "thin"
      | "medium"
      | "thick" => continue
      _ => ()
    }
    // Skip numeric values (border width)
    if lower.length() > 0 && lower[0] >= '0' && lower[0] <= '9' {
      continue
    }
    if lower == "0" {
      continue
    }
    // Try to parse as color
    let color_val = parse_color_with_ctx(part, ctx)
    match color_val.get_color() {
      Some(c) => return c
      None => ()
    }
  }
  @types.Color::black() // CSS default: currentColor → approximate as black
}

///|
fn extract_border_style_from_shorthand(value : String) -> @style.BorderStyle {
  let parts = split_whitespace(value)
  let mut found_style = false
  let mut result = @style.BorderStyle::None
  for part in parts {
    let lower = part.to_lower()
    match lower {
      "none"
      | "hidden"
      | "dotted"
      | "dashed"
      | "solid"
      | "double"
      | "groove"
      | "ridge"
      | "inset"
      | "outset" => {
        found_style = true
        result = parse_border_style_value(part)
      }
      _ => ()
    }
  }
  if found_style {
    result
  } else {
    @style.BorderStyle::Solid // Default when only width/color specified
  }
}

///|
fn parse_border_style_value(value : String) -> @style.BorderStyle {
  match value.trim().to_lower() {
    "none" => @style.BorderStyle::None
    "hidden" => @style.BorderStyle::Hidden
    "dotted" => @style.BorderStyle::Dotted
    "dashed" => @style.BorderStyle::Dashed
    "solid" => @style.BorderStyle::Solid
    "double" => @style.BorderStyle::Double
    "groove" => @style.BorderStyle::Groove
    "ridge" => @style.BorderStyle::Ridge
    "inset" => @style.BorderStyle::Inset
    "outset" => @style.BorderStyle::Outset
    _ => @style.BorderStyle::None
  }
}

///|
/// Resolve border width from width/style/color shorthand tokens.
/// Falls back to the existing default 1.5px for style-only shorthands.
fn resolve_border_width(
  value : String,
  ctx : ComputeContext,
) -> @types.Dimension {
  let v = value.trim().to_lower()
  if v == "none" || v == "hidden" || v == "0" {
    return @types.Length(0.0)
  }

  let mut has_visible_style = false
  let mut has_none_style = false

  let parts = v
    .split(" ")
    .map(fn(part) { part.to_owned().trim().to_owned() })
    .filter(fn(part) { !part.is_empty() })
    .collect()

  for part in parts {
    match part {
      "none" | "hidden" => {
        has_none_style = true
        continue
      }
      "thin" => return @types.Length(1.0)
      "medium" => return @types.Length(3.0)
      "thick" => return @types.Length(5.0)
      "solid"
      | "dotted"
      | "dashed"
      | "double"
      | "groove"
      | "ridge"
      | "inset"
      | "outset" => {
        has_visible_style = true
        continue
      }
      _ => ()
    }

    // Length-like token found in shorthand.
    match resolve_dimension(part, ctx) {
      @types.Length(px) => return @types.Length(px)
      _ => ()
    }
  }

  if has_none_style {
    @types.Length(0.0)
  } else if has_visible_style {
    @types.Length(1.5)
  } else {
    @types.Length(0.0)
  }
}

///|
/// Parse table-layout value
fn parse_table_layout(value : String) -> @style.TableLayout {
  match value.trim() {
    "fixed" => @style.TableLayout::Fixed
    "auto" => @style.Auto
    _ => @style.Auto
  }
}

///|
/// Parse caption-side value
fn parse_caption_side(value : String) -> @style.CaptionSide {
  match value.trim() {
    "top" => @style.CaptionSide::Top
    "bottom" => @style.CaptionSide::Bottom
    _ => @style.CaptionSide::Top
  }
}

///|
/// Parse margin-trim value
fn parse_margin_trim(value : String) -> @style.MarginTrim {
  match value.trim().to_lower() {
    "none" => @style.MarginTrim::None
    "block-start" => @style.MarginTrim::BlockStart
    "block-end" => @style.MarginTrim::BlockEnd
    "block" => @style.MarginTrim::Block
    "inline-start" => @style.MarginTrim::InlineStart
    "inline-end" => @style.MarginTrim::InlineEnd
    "inline" => @style.MarginTrim::Inline
    _ => @style.MarginTrim::None
  }
}

///|
/// Parse border-spacing value (single value or two values)
fn parse_border_spacing(
  value : String,
  ctx : ComputeContext,
) -> (Double, Double) {
  let v = value.trim()
  // Split by whitespace
  let parts : Array[StringView] = v
    .split(" ")
    .filter(fn(s) { !s.is_empty() })
    .collect()
  if parts.length() == 0 {
    return (0.0, 0.0)
  }
  let horizontal = match resolve_dimension(parts[0].to_owned(), ctx) {
    @types.Length(px) => px
    _ => 0.0
  }
  let vertical = if parts.length() >= 2 {
    match resolve_dimension(parts[1].to_owned(), ctx) {
      @types.Length(px) => px
      _ => horizontal
    }
  } else {
    horizontal
  }
  (horizontal, vertical)
}

///|
/// Parse border-radius shorthand (1-4 values)
/// Returns (top-left, top-right, bottom-right, bottom-left) in px
fn resolve_border_radius(
  value : String,
  ctx : ComputeContext,
) -> (Double, Double, Double, Double) {
  let v = value.trim()
  // Handle slash syntax (horizontal / vertical) - take only horizontal for now
  let effective = if v.contains("/") {
    let slash_parts : Array[StringView] = v.split("/").collect()
    slash_parts[0].to_owned().trim()
  } else {
    v
  }
  let parts : Array[StringView] = effective
    .split(" ")
    .filter(fn(s) { !s.is_empty() })
    .collect()
  if parts.length() == 0 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let values : Array[Double] = parts.map(fn(p) {
    let dim = resolve_dimension(p.to_owned(), ctx)
    match dim {
      @types.Percent(pct) => -pct // Negative encodes percentage (fraction) for render-time resolution
      _ => resolve_dimension_to_px(dim)
    }
  })
  match values.length() {
    1 => (values[0], values[0], values[0], values[0])
    2 => (values[0], values[1], values[0], values[1])
    3 => (values[0], values[1], values[2], values[1])
    _ => (values[0], values[1], values[2], values[3])
  }
}
