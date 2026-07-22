///|
fn parse_linecap(value : String) -> LineCap {
  let v = trim_string(value)
  match v {
    "round" => Round
    "square" => Square
    _ => Butt // Default
  }
}

///|
fn parse_image_sampling(value : String) -> ImageSampling {
  match trim_string(value).to_lower() {
    "pixelated" | "crisp-edges" | "optimizespeed" => Nearest
    "optimizequality" => Bicubic
    _ => Bilinear
  }
}

///|
fn parse_linejoin(value : String) -> LineJoin {
  let v = trim_string(value)
  match v {
    "round" => Round
    "bevel" => Bevel
    _ => Miter // Default
  }
}

///|
fn parse_dasharray(value : String) -> Array[Double]? {
  let v = trim_string(value)
  if v == "none" || v.length() == 0 {
    return None
  }
  let result : Array[Double] = []
  let mut current = ""
  for c in v {
    if c == ',' || c == ' ' {
      if current.length() > 0 {
        result.push(parse_number(current))
        current = ""
      }
    } else {
      current = current + c.to_string()
    }
  }
  if current.length() > 0 {
    result.push(parse_number(current))
  }
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
fn parse_fill_rule(value : String) -> FillRule {
  let v = trim_string(value)
  match v {
    "evenodd" => EvenOdd
    _ => NonZero // Default
  }
}

///|
fn trim_string(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = Int::unsafe_to_char(s[start].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = Int::unsafe_to_char(s[end - 1].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  build_substring(s, start, end)
}

///|
fn string_starts_with(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if s[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
fn string_ends_with(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    return false
  }
  let start = s.length() - suffix.length()
  for i in 0..<suffix.length() {
    if s[start + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
fn find_first(s : String, target : Char) -> Int {
  for i in 0..<s.length() {
    if Int::unsafe_to_char(s[i].to_int()) == target {
      return i
    }
  }
  -1
}

///|
fn parse_length(s : String) -> Double {
  // Simple number parsing (strips common units)
  let s = trim_string(s)
  if string_starts_with(s, "var(") && string_ends_with(s, ")") {
    let inner = build_substring(s, 4, s.length() - 1)
    let comma = find_first(inner, ',')
    if comma >= 0 {
      let fallback = trim_string(
        build_substring(inner, comma + 1, inner.length()),
      )
      if fallback.length() > 0 {
        return parse_length(fallback)
      }
    }
    return 0.0
  }
  // Remove units
  let cleaned = if string_ends_with(s, "px") {
    build_substring(s, 0, s.length() - 2)
  } else if string_ends_with(s, "em") || string_ends_with(s, "pt") {
    build_substring(s, 0, s.length() - 2)
  } else if string_ends_with(s, "%") {
    build_substring(s, 0, s.length() - 1)
  } else {
    s
  }
  parse_number(cleaned)
}

///|
fn parse_length_or_percent(s : String) -> (Double, Bool) {
  let s = trim_string(s)
  if string_ends_with(s, "%") {
    let cleaned = build_substring(s, 0, s.length() - 1)
    (parse_number(cleaned) / 100.0, true)
  } else {
    (parse_length(s), false)
  }
}

///|
fn parse_mask_length(value : String, units : MaskUnits) -> (Double, Bool) {
  let (val, is_percent) = parse_length_or_percent(value)
  match units {
    ObjectBoundingBox => (val, false)
    UserSpaceOnUse => (val, is_percent)
  }
}

///|
fn parse_number(s : String) -> Double {
  let s = trim_string(s)
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  fn char_at(str : String, idx : Int) -> Char {
    Int::unsafe_to_char(str[idx].to_int())
  }
  // Sign
  if i < len && char_at(s, i) == '-' {
    sign = -1.0
    i = i + 1
  } else if i < len && char_at(s, i) == '+' {
    i = i + 1
  }
  // Integer part
  while i < len {
    let c = char_at(s, i)
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  // Fractional part
  if i < len && char_at(s, i) == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let c = char_at(s, i)
      if c >= '0' && c <= '9' {
        result = result + (c.to_int() - 48).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  sign * result
}

///|
fn parse_paint(value : String) -> Paint {
  let value = trim_string(value)
  let lower = value.to_lower()
  if value.length() == 0 {
    return None
  }
  if lower == "none" {
    return None
  }
  if lower == "currentcolor" {
    return CurrentColor
  }
  // Paint server with optional fallback: url(#id) <fallback>
  if string_starts_with(value, "url(") {
    let close_index = find_first(value, ')')
    if close_index >= 0 {
      let url_part = build_substring(value, 0, close_index + 1)
      let rest = trim_string(
        build_substring(value, close_index + 1, value.length()),
      )
      match parse_url_ref(url_part) {
        Some(id) => {
          let fallback = if rest.length() == 0 {
            PaintFallback::NoPaint
          } else {
            parse_paint_fallback(rest)
          }
          return PaintServerRef(id, fallback)
        }
        None => ()
      }
    }
  }
  // Parse color
  let color = parse_color(value)
  SolidColor(color)
}

///|
fn parse_paint_fallback(value : String) -> PaintFallback {
  let value = trim_string(value)
  let lower = value.to_lower()
  if value.length() == 0 || lower == "none" {
    return NoPaint
  }
  if lower == "currentcolor" {
    return CurrentColor
  }
  SolidColor(parse_color(value))
}

///|
fn parse_paint_order(value : String) -> PaintOrder {
  let v = trim_string(value)
  if v.length() == 0 || v == "normal" {
    return PaintOrder::default()
  }
  let tokens = split_tokens(v)
  if tokens.length() == 0 {
    return PaintOrder::default()
  }
  let order : Array[PaintOrderItem] = []
  for t in tokens {
    match t {
      "fill" => if !order.contains(Fill) { order.push(Fill) }
      "stroke" => if !order.contains(Stroke) { order.push(Stroke) }
      "markers" => if !order.contains(Markers) { order.push(Markers) }
      _ => ()
    }
  }
  if order.length() == 0 {
    return PaintOrder::default()
  }
  if !order.contains(Fill) {
    order.push(Fill)
  }
  if !order.contains(Stroke) {
    order.push(Stroke)
  }
  if !order.contains(Markers) {
    order.push(Markers)
  }
  { order, }
}

///|
fn parse_color(value : String) -> Color {
  match @css_computed.parse_color(value) {
    Resolved(color) =>
      Color::rgba(
        color.r,
        color.g,
        color.b,
        clamp_int((color.a * 255.0).round().to_int(), 0, 255),
      )
    CurrentColor
    | Inherit
    | Invalid => Color::black()
  }
}

///|
fn build_substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(Int::unsafe_to_char(s[i].to_int()))
  }
  buf.to_string()
}

///|
fn parse_points(value : String) -> Array[(Double, Double)] {
  // Parse space/comma separated list of x,y pairs
  let result : Array[(Double, Double)] = []
  let nums : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        nums.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    nums.push(parse_number(buf.to_string()))
  }
  // Pair up the numbers
  let mut i = 0
  while i + 1 < nums.length() {
    result.push((nums[i], nums[i + 1]))
    i = i + 2
  }
  result
}

///|
pub fn parse_transform(value : String) -> Transform {
  // Parse transform attribute: translate(x, y) scale(sx, sy) rotate(angle) etc.
  let mut result = Transform::identity()
  let mut i = 0
  while i < value.length() {
    // Skip whitespace
    while i < value.length() {
      let c = Int::unsafe_to_char(value[i].to_int())
      if c == ' ' || c == ',' {
        i = i + 1
      } else {
        break
      }
    }
    if i >= value.length() {
      break
    }
    // Read function name
    let name_start = i
    while i < value.length() {
      let c = Int::unsafe_to_char(value[i].to_int())
      if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
        i = i + 1
      } else {
        break
      }
    }
    let name = build_substring(value, name_start, i)
    // Find '('
    while i < value.length() && Int::unsafe_to_char(value[i].to_int()) != '(' {
      i = i + 1
    }
    i = i + 1 // Skip '('
    // Find ')' and parse arguments
    let args_start = i
    while i < value.length() && Int::unsafe_to_char(value[i].to_int()) != ')' {
      i = i + 1
    }
    let args_str = build_substring(value, args_start, i)
    i = i + 1 // Skip ')'
    // Parse arguments
    let args = parse_transform_args(args_str)
    // Apply transform
    let t = match name {
      "translate" =>
        if args.length() >= 2 {
          Transform::translate(args[0], args[1])
        } else if args.length() >= 1 {
          Transform::translate(args[0], 0.0)
        } else {
          Transform::identity()
        }
      "scale" =>
        if args.length() >= 2 {
          Transform::scale(args[0], args[1])
        } else if args.length() >= 1 {
          Transform::scale(args[0], args[0])
        } else {
          Transform::identity()
        }
      "rotate" =>
        if args.length() >= 3 {
          Transform::rotate_around(
            degrees_to_radians(args[0]),
            args[1],
            args[2],
          )
        } else if args.length() >= 1 {
          Transform::rotate(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "skewX" =>
        if args.length() >= 1 {
          Transform::skew_x(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "skewY" =>
        if args.length() >= 1 {
          Transform::skew_y(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "matrix" =>
        if args.length() >= 6 {
          Transform::matrix(
            args[0],
            args[1],
            args[2],
            args[3],
            args[4],
            args[5],
          )
        } else {
          Transform::identity()
        }
      _ => Transform::identity()
    }
    result = result.multiply(t)
  }
  result
}

///|
fn parse_transform_args(s : String) -> Array[Double] {
  let result : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i in 0..<s.length() {
    let c = Int::unsafe_to_char(s[i].to_int())
    if c == ' ' || c == ',' {
      if buf.to_string().length() > 0 {
        result.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    result.push(parse_number(buf.to_string()))
  }
  result
}
