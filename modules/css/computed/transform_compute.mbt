///|
/// Parse CSS transform property
/// Supports translate, scale, rotate, and skew in the 2D hit-test subset.
fn parse_transform(value : String) -> @style.Transform {
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
  // We handle each function in sequence
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
    let func_name = chars_to_string(chars[func_start:i])
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
    let args_str = chars_to_string(chars[args_start:i - 1])
    // Parse transform function
    match func_name.trim() {
      "translate" => {
        // translate(x) or translate(x, y)
        let args = split_by_comma(args_str)
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
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      "scale" => {
        // scale(x) or scale(x, y)
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          let sx = parse_scale_value(args[0])
          scale_x = scale_x * sx
          scale_y = scale_y * sx // If only one arg, use same scale for both
        }
        if args.length() >= 2 {
          scale_y = scale_y /
            scale_x *
            parse_scale_value(args[1]) *
            scale_x /
            scale_x
          // Actually: if second arg provided, override scale_y
          scale_y = parse_scale_value(args[1])
        }
      }
      "scalex" => scale_x = scale_x * parse_scale_value(args_str)
      "scaley" => scale_y = scale_y * parse_scale_value(args_str)
      "scale3d" => {
        // scale3d(x, y, z) - we only use x and y
        let args = split_by_comma(args_str)
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
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          skew_x_degrees += parse_rotate_degrees(args[0])
        }
        if args.length() >= 2 {
          skew_y_degrees += parse_rotate_degrees(args[1])
        }
      }
      "matrix" => {
        let args = split_by_comma(args_str)
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
        let args = split_by_comma(args_str)
        if args.length() >= 16 {
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
  let v = value.trim()
  if v.is_empty() {
    return 0.0
  }
  if v.has_suffix("deg") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 3))
    return @string.parse_double(num_str.trim()) catch { _ => 0.0 }
  }
  if v.has_suffix("turn") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 4))
    let turns = @string.parse_double(num_str.trim()) catch { _ => return 0.0 }
    return turns * 360.0
  }
  // `grad` must be checked before `rad`: it also ends with "rad".
  // 400grad = 360deg, so 1grad = 0.9deg.
  if v.has_suffix("grad") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 4))
    let gradians = @string.parse_double(num_str.trim()) catch {
      _ => return 0.0
    }
    return gradians * 0.9
  }
  if v.has_suffix("rad") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 3))
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
/// Parse CSS zoom property
/// Supports: normal, number, percentage
fn parse_zoom(value : String) -> Double {
  let v = value.trim().to_lower()
  if v.is_empty() || v == "normal" {
    return 1.0
  }
  // Check for percentage (e.g., "150%")
  if v.has_suffix("%") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 1))
    let n = @string.parse_double(num_str.trim()) catch { _ => return 1.0 }
    return n / 100.0
  }
  // Parse as number (e.g., "1.5" or "2")
  @string.parse_double(v) catch {
    _ => 1.0
  }
}

///|
/// Parse a single translate value (can be length or percentage)
fn parse_translate_value(value : String) -> @style.TranslateValue {
  let v = value.trim()
  if v.is_empty() {
    return Length(0.0)
  }
  // Check for percentage
  if v.has_suffix("%") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 1))
    let n = @string.parse_double(num_str.trim()) catch {
      _ => return Length(0.0)
    }
    Percent(n / 100.0)
  } else if v.has_suffix("px") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 2))
    let n = @string.parse_double(num_str.trim()) catch {
      _ => return Length(0.0)
    }
    Length(n)
  } else if v.has_suffix("em") || v.has_suffix("rem") {
    // em/rem - convert to pixels assuming 16px base
    let suffix_len = if v.has_suffix("rem") { 3 } else { 2 }
    let num_str = view_to_string(v.view(end_offset=v.length() - suffix_len))
    let n = @string.parse_double(num_str.trim()) catch {
      _ => return Length(0.0)
    }
    Length(n * 16.0)
  } else {
    // Try parsing as plain number (assumed px)
    let n = @string.parse_double(v) catch {
      _ => return Length(0.0)
    }
    Length(n)
  }
}

///|
/// Split string by comma (for transform arguments)
fn split_by_comma(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
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
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// Check if a string is a flex-basis value (has units, % or is auto/content)
fn is_flex_basis_value(s : String) -> Bool {
  let v = s.trim().to_lower()
  if v == "auto" || v == "content" {
    return true
  }
  // Check for common dimension suffixes
  v.has_suffix("%") ||
  v.has_suffix("px") ||
  v.has_suffix("em") ||
  v.has_suffix("rem") ||
  v.has_suffix("dvw") ||
  v.has_suffix("svw") ||
  v.has_suffix("lvw") ||
  v.has_suffix("vw") ||
  v.has_suffix("dvh") ||
  v.has_suffix("svh") ||
  v.has_suffix("lvh") ||
  v.has_suffix("vh")
}

///|
fn strip_inline_important_marker(
  value : String,
) -> (String, @cascade.Importance) {
  let trimmed = value.trim().to_owned()
  let compact = strip_css_ascii_whitespace(trimmed.to_lower())
  if !compact.has_suffix("!important") {
    return (trimmed, Normal)
  }
  let important_len = 9
  if trimmed.length() <= important_len {
    return (trimmed, Normal)
  }
  let mut bang_pos = trimmed.length() - important_len
  while bang_pos > 0 {
    let c = trimmed[bang_pos - 1].to_int().unsafe_to_char()
    if is_css_ascii_whitespace(c) {
      bang_pos -= 1
    } else {
      break
    }
  }
  if bang_pos <= 0 {
    return (trimmed, Normal)
  }
  if trimmed[bang_pos - 1].to_int().unsafe_to_char() != '!' {
    return (trimmed, Normal)
  }
  let stripped = view_to_string(trimmed.view(end_offset=bang_pos - 1))
    .trim()
    .to_owned()
  if stripped.is_empty() {
    return (trimmed, Normal)
  }
  (stripped, Important)
}
