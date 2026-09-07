///|
/// Parse box-sizing property
fn parse_box_sizing(tokens : ArrayView[@token.Token]) -> @types.BoxSizing? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "content-box" {
        Some(ContentBox)
      } else if s == "border-box" {
        Some(BorderBox)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Skip whitespace tokens and return remaining view
fn skip_whitespace(tokens : ArrayView[@token.Token]) -> ArrayView[@token.Token] {
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      Whitespace => i += 1
      _ => break
    }
  }
  tokens[i:]
}

///|
/// Parse CSS contain property
/// Supports: none, strict, content, size, inline-size, layout, paint, style
/// Multiple keywords can be combined (e.g., "layout paint")
fn parse_contain(tokens : ArrayView[@token.Token]) -> @style.Contain {
  let mut result = @style.Contain::none()
  let mut remaining = skip_whitespace(tokens)
  while remaining.length() > 0 {
    match remaining[0] {
      Ident(s) => {
        if s == "none" {
          return @style.Contain::none()
        } else if s == "strict" {
          return @style.Contain::strict()
        } else if s == "content" {
          return @style.Contain::content()
        } else if s == "size" {
          result = { ..result, size: true, }
        } else if s == "inline-size" {
          result = { ..result, inline_size: true, }
        } else if s == "layout" {
          result = { ..result, layout: true, }
        } else if s == "paint" {
          result = { ..result, paint: true, }
        } else if s == "style" {
          result = { ..result, style: true, }
        }
        remaining = skip_whitespace(remaining[1:])
      }
      Whitespace => remaining = skip_whitespace(remaining[1:])
      _ => break
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
    { ..merged, inline_size: false, }
  } else {
    merged
  }
}

///|
/// Parse CSS container-type property into implied containment bits.
/// Supported: normal | size | inline-size
fn parse_container_type(tokens : ArrayView[@token.Token]) -> @style.Contain? {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return None
  }
  match remaining[0] {
    Ident(s) =>
      if s == "normal" {
        Some(@style.Contain::none())
      } else if s == "size" {
        Some({ ..@style.Contain::none(), size: true, style: true, })
      } else if s == "inline-size" {
        Some({ ..@style.Contain::none(), inline_size: true, style: true, })
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse contain-intrinsic-inline-size / contain-intrinsic-block-size.
/// Returns a content-box fallback length in px, or None for none/auto.
fn parse_contain_intrinsic_axis(tokens : ArrayView[@token.Token]) -> Double? {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return None
  }
  match remaining[0] {
    Ident(s) =>
      if s == "none" || s == "auto" {
        None
      } else {
        match parse_dimension(remaining) {
          Some(Length(v)) => if v > 0.0 { Some(v) } else { Some(0.0) }
          _ => None
        }
      }
    _ =>
      match parse_dimension(remaining) {
        Some(Length(v)) => if v > 0.0 { Some(v) } else { Some(0.0) }
        _ => None
      }
  }
}

///|
/// Parse contain-intrinsic-size shorthand.
/// One value applies to both inline/block axes; two values map to inline then block.
fn parse_contain_intrinsic_size(
  tokens : ArrayView[@token.Token],
) -> (Double?, Double?)? {
  let mut remaining = skip_whitespace(tokens)
  let axis_values : Array[Double?] = []
  while remaining.length() > 0 {
    match remaining[0] {
      Whitespace => remaining = skip_whitespace(remaining[1:])
      Ident(s) =>
        if s == "auto" {
          remaining = skip_whitespace(remaining[1:])
        } else if s == "none" {
          axis_values.push(None)
          remaining = skip_whitespace(remaining[1:])
        } else {
          match parse_dimension(remaining) {
            Some(Length(v)) =>
              axis_values.push(Some(if v > 0.0 { v } else { 0.0 }))
            _ => ()
          }
          remaining = skip_whitespace(remaining[1:])
        }
      _ => {
        match parse_dimension(remaining) {
          Some(Length(v)) =>
            axis_values.push(Some(if v > 0.0 { v } else { 0.0 }))
          _ => ()
        }
        remaining = skip_whitespace(remaining[1:])
      }
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
/// Parse CSS transform property
/// Supports: translate(x, y), translateX(x), translateY(y), translate3d(x, y, z), none
fn parse_transform(tokens : ArrayView[@token.Token]) -> @style.Transform {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return @style.Transform::none()
  }
  // Check for "none"
  match remaining[0] {
    Ident(s) => if s == "none" { return @style.Transform::none() }
    _ => ()
  }
  // Reconstruct the value as string for parsing with the full transform parser
  // Since transform values like "translate(10px, 20px)" are complex,
  // we build the string and reuse the computed transform parser
  let sb = StringBuilder()
  for i = 0; i < remaining.length(); i = i + 1 {
    match remaining[i] {
      Ident(s) => sb.write_string(s)
      Function(name) => {
        sb.write_string(name)
        sb.write_char('(')
      }
      Dimension(value, unit) => {
        sb.write_string(value.to_string())
        sb.write_string(unit)
      }
      Percentage(value) => {
        sb.write_string(value.to_string())
        sb.write_char('%')
      }
      Number(value, _) => sb.write_string(value.to_string())
      Comma => sb.write_char(',')
      RightParen => sb.write_char(')')
      LeftParen => sb.write_char('(')
      Whitespace => sb.write_char(' ')
      _ => ()
    }
  }
  let value_str = sb.to_string()
  // Parse the reconstructed string
  parse_transform_string(value_str)
}

///|
fn parse_pointer_events(
  tokens : ArrayView[@token.Token],
) -> @style.PointerEvents {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return Auto
  }
  match remaining[0] {
    Ident(s) => if s == "none" { None } else { Auto }
    _ => Auto
  }
}

///|
/// Parse CSS transform from a string value
fn parse_transform_string(value : String) -> @style.Transform {
  let v = value.trim().to_lower()
  // Handle none
  if v == "none" || v.is_empty() {
    return @style.Transform::none()
  }
  let mut translate_x = @style.TranslateValue::Length(0.0)
  let mut translate_y = @style.TranslateValue::Length(0.0)
  let mut scale_x = 1.0
  let mut scale_y = 1.0
  let mut rotate_degrees = 0.0
  let mut skew_x_degrees = 0.0
  let mut skew_y_degrees = 0.0
  let mut has_matrix = false
  let mut matrix_a = 1.0
  let mut matrix_b = 0.0
  let mut matrix_c = 0.0
  let mut matrix_d = 1.0
  let mut matrix_e = 0.0
  let mut matrix_f = 0.0
  let mut matrix3d : Array[Double] = []
  // Parse transform functions
  let chars = v.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    // Skip whitespace
    while i < len && (chars[i] == ' ' || chars[i] == '\t') {
      i = i + 1
    }
    if i >= len {
      break
    }
    // Find function name
    let func_start = i
    while i < len && chars[i] != '(' {
      i = i + 1
    }
    if i >= len {
      break
    }
    let func_name = transform_chars_to_string(chars[func_start:i])
    i = i + 1 // Skip '('
    // Find function arguments (handle nested parens)
    let args_start = i
    let mut paren_depth = 1
    while i < len && paren_depth > 0 {
      if chars[i] == '(' {
        paren_depth = paren_depth + 1
      } else if chars[i] == ')' {
        paren_depth = paren_depth - 1
      }
      i = i + 1
    }
    let args_str = transform_chars_to_string(chars[args_start:i - 1])
    // Parse transform function
    match func_name.trim() {
      "translate" => {
        // translate(x) or translate(x, y)
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      "translatex" => translate_x = parse_translate_value(args_str)
      "translatey" => translate_y = parse_translate_value(args_str)
      "translate3d" => {
        // translate3d(x, y, z) - we only use x and y
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      "scale" => {
        // scale(x) or scale(x, y)
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          let sx = parse_scale_value(args[0])
          scale_x = scale_x * sx
          scale_y = scale_y * sx
        }
        if args.length() >= 2 {
          scale_y = parse_scale_value(args[1])
        }
      }
      "scalex" => scale_x = scale_x * parse_scale_value(args_str)
      "scaley" => scale_y = scale_y * parse_scale_value(args_str)
      "scale3d" => {
        // scale3d(x, y, z) - we only use x and y
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          scale_x = scale_x * parse_scale_value(args[0])
        }
        if args.length() >= 2 {
          scale_y = scale_y * parse_scale_value(args[1])
        }
      }
      "rotate" =>
        rotate_degrees = rotate_degrees + parse_rotate_degrees(args_str)
      "skewx" => skew_x_degrees += parse_rotate_degrees(args_str)
      "skewy" => skew_y_degrees += parse_rotate_degrees(args_str)
      "skew" => {
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          skew_x_degrees += parse_rotate_degrees(args[0])
        }
        if args.length() >= 2 {
          skew_y_degrees += parse_rotate_degrees(args[1])
        }
      }
      "matrix" => {
        let args = split_transform_args(args_str)
        if args.length() >= 6 {
          has_matrix = true
          matrix_a = parse_scale_value(args[0])
          matrix_b = parse_scale_value(args[1])
          matrix_c = parse_scale_value(args[2])
          matrix_d = parse_scale_value(args[3])
          matrix_e = parse_scale_value(args[4])
          matrix_f = parse_scale_value(args[5])
        }
      }
      "matrix3d" => {
        let args = split_transform_args(args_str)
        if args.length() >= 16 {
          // Keep a 2D affine approximation (a,b,c,d,e,f) for 2D consumers and
          // the full 16-element column-major matrix for 3D interpolation.
          has_matrix = true
          matrix_a = parse_scale_value(args[0])
          matrix_b = parse_scale_value(args[1])
          matrix_c = parse_scale_value(args[4])
          matrix_d = parse_scale_value(args[5])
          matrix_e = parse_scale_value(args[12])
          matrix_f = parse_scale_value(args[13])
          matrix3d = []
          for k = 0; k < 16; k = k + 1 {
            matrix3d.push(parse_scale_value(args[k]))
          }
        }
      }
      _ => () // Ignore unsupported functions like perspective.
    }
  }
  {
    translate_x,
    translate_y,
    scale_x,
    scale_y,
    rotate_degrees,
    skew_x_degrees,
    skew_y_degrees,
    has_matrix,
    matrix_a,
    matrix_b,
    matrix_c,
    matrix_d,
    matrix_e,
    matrix_f,
    matrix3d,
  }
}

///|
fn parse_rotate_degrees(value : String) -> Double {
  let v = value.trim().to_owned()
  if v.is_empty() {
    return 0.0
  }
  if v.has_suffix("deg") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 3)
    return @string.parse_double(num_str.trim()) catch { _ => 0.0 }
  }
  if v.has_suffix("turn") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 4)
    let turns = @string.parse_double(num_str.trim()) catch { _ => return 0.0 }
    return turns * 360.0
  }
  // `grad` must be checked before `rad`: it also ends with "rad".
  // 400grad = 360deg, so 1grad = 0.9deg.
  if v.has_suffix("grad") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 4)
    let gradians = @string.parse_double(num_str.trim()) catch {
      _ => return 0.0
    }
    return gradians * 0.9
  }
  if v.has_suffix("rad") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 3)
    let radians = @string.parse_double(num_str.trim()) catch { _ => return 0.0 }
    return radians * 57.29577951308232
  }
  @string.parse_double(v) catch {
    _ => 0.0
  }
}

///|
/// Parse a scale value (number, no unit)
fn parse_scale_value(value : String) -> Double {
  let v = value.trim()
  if v.is_empty() {
    return 1.0
  }
  @string.parse_double(v) catch {
    _ => 1.0
  }
}

///|
/// Parse a single translate value (can be length or percentage).
/// Tokenizes the value so every length unit (px/rem/em/pt/cm/in/vw/...) is
/// converted to px via dimension_unit_to_px, instead of only px/em/rem.
fn parse_translate_value(value : String) -> @style.TranslateValue {
  let v = value.trim()
  if v.is_empty() {
    return Length(0.0)
  }
  let tokens = skip_whitespace(@token.tokenize(v.to_owned())[:])
  if tokens.length() == 0 {
    return Length(0.0)
  }
  match tokens[0] {
    Dimension(n, raw_unit) => {
      let unit = raw_unit.to_lower()
      if unit == "%" {
        Percent(n / 100.0)
      } else {
        let px = match dimension_unit_to_px(n, unit) {
          Some(p) => p
          None => n
        }
        Length(px)
      }
    }
    Percentage(n) => Percent(n / 100.0)
    Number(n, _) => Length(n)
    _ => Length(0.0)
  }
}

///|
/// Split a value string into whitespace-separated, non-empty parts.
fn split_ws_parts(value : String) -> Array[String] {
  let parts : Array[String] = []
  for p in value.trim().split(" ") {
    let t = p.trim()
    if t.length() > 0 {
      parts.push(t.to_owned())
    }
  }
  parts
}

///|
/// Parse the `translate` property (`<len-pct>{1,3}`) into a Transform with the
/// translate components set (z is ignored; this engine is 2D).
pub fn parse_translate_property_from_string(value : String) -> @style.Transform {
  let parts = split_ws_parts(value)
  if parts.length() == 0 || value.trim().to_lower() == "none" {
    return @style.Transform::none()
  }
  let x = parse_translate_value(parts[0])
  let y = if parts.length() > 1 {
    parse_translate_value(parts[1])
  } else {
    Length(0.0)
  }
  { ..@style.Transform::none(), translate_x: x, translate_y: y, }
}

///|
/// Parse the `scale` property (`<number>{1,3}`) into a Transform with scale set.
/// A single value applies to both axes.
pub fn parse_scale_property_from_string(value : String) -> @style.Transform {
  let parts = split_ws_parts(value)
  if parts.length() == 0 || value.trim().to_lower() == "none" {
    return @style.Transform::none()
  }
  let sx = parse_scale_value(parts[0])
  let sy = if parts.length() > 1 { parse_scale_value(parts[1]) } else { sx }
  { ..@style.Transform::none(), scale_x: sx, scale_y: sy, }
}

///|
/// Parse the `rotate` property (`<angle>` or `[x|y|z|<vector>] <angle>`) into a
/// Transform with rotate set. Only the 2D z-rotation angle is kept.
pub fn parse_rotate_property_from_string(value : String) -> @style.Transform {
  let parts = split_ws_parts(value)
  if parts.length() == 0 || value.trim().to_lower() == "none" {
    return @style.Transform::none()
  }
  // The angle is the last part (an axis keyword / vector may precede it).
  let angle = parse_rotate_degrees(parts[parts.length() - 1])
  { ..@style.Transform::none(), rotate_degrees: angle, }
}

///|
/// Split string by comma (for transform arguments) - local version
fn split_transform_args(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder()
  for c in s {
    if c == ',' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string()
  if !last.is_empty() {
    result.push(last)
  }
  result
}

///|
/// Convert char array slice to string
fn transform_chars_to_string(chars : ArrayView[Char]) -> String {
  let sb = StringBuilder()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
}
