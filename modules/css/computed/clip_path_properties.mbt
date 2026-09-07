///|
/// Parse CSS clip property value
/// Supports: auto, rect(top, right, bottom, left)
/// Note: This is a deprecated property but widely used for accessibility
pub fn parse_clip(value : String) -> @types.ClipRect {
  let v = value.trim().to_lower()
  if v == "auto" || v == "initial" || v == "unset" {
    return Auto
  }
  // Parse rect(top, right, bottom, left)
  if v.has_prefix("rect(") && v.has_suffix(")") {
    // Extract the content inside rect()
    let content = view_to_string(
      v.view(start_offset=5, end_offset=v.length() - 1),
    ).trim()
    // Split by comma or space (both are valid in CSS)
    let parts : Array[String] = []
    let mut current = StringBuilder()
    for c in content.iter() {
      if c == ',' || c == ' ' {
        let s = current.to_string().trim().to_owned()
        if !s.is_empty() {
          parts.push(s)
        }
        current = StringBuilder()
      } else {
        current.write_char(c)
      }
    }
    let last = current.to_string().trim().to_owned()
    if !last.is_empty() {
      parts.push(last)
    }
    if parts.length() == 4 {
      let top = parse_clip_value(parts[0])
      let right = parse_clip_value(parts[1])
      let bottom = parse_clip_value(parts[2])
      let left = parse_clip_value(parts[3])
      return Rect(top~, right~, bottom~, left~)
    }
  }
  Auto
}

///|
/// Parse the supported subset of CSS clip-path.
/// Supports: none, inset(<top> <right> <bottom> <left>), circle(<r> at <x> <y>).
pub fn parse_clip_path(value : String) -> @style.ClipPath {
  let raw_v = value.trim().to_owned()
  let v = raw_v.to_lower()
  if v == "none" || v == "initial" || v == "unset" || v.is_empty() {
    return None
  }
  if v.has_prefix("inset(") && v.has_suffix(")") {
    let raw_content = view_to_string(
        v.view(start_offset=6, end_offset=v.length() - 1),
      )
      .trim()
      .to_owned()
    let content = match raw_content.find("round") {
      Some(idx) =>
        raw_content.unsafe_substring(start=0, end=idx).trim().to_owned()
      None => raw_content
    }
    let parts = split_clip_path_values(content)
    if parts.length() > 0 {
      let values = parts.map(parse_clip_path_inset_value)
      match values.length() {
        1 => {
          let v = values[0]
          return Inset(v, v, v, v)
        }
        2 => {
          let vertical = values[0]
          let horizontal = values[1]
          return Inset(vertical, horizontal, vertical, horizontal)
        }
        3 => return Inset(values[0], values[1], values[2], values[1])
        _ => return Inset(values[0], values[1], values[2], values[3])
      }
    }
  }
  if v.has_prefix("rect(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=5, end_offset=v.length() - 1),
      )
      .trim()
      .to_owned()
    return parse_clip_path_rect(content)
  }
  if v.has_prefix("xywh(") && v.has_suffix(")") {
    let raw_content = view_to_string(
        v.view(start_offset=5, end_offset=v.length() - 1),
      )
      .trim()
      .to_owned()
    let content = match raw_content.find("round") {
      Some(idx) =>
        raw_content.unsafe_substring(start=0, end=idx).trim().to_owned()
      None => raw_content
    }
    return parse_clip_path_xywh(content)
  }
  if v.has_prefix("circle(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=7, end_offset=v.length() - 1),
      )
      .trim()
      .to_owned()
    return parse_clip_path_circle(content)
  }
  if v.has_prefix("ellipse(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=8, end_offset=v.length() - 1),
      )
      .trim()
      .to_owned()
    return parse_clip_path_ellipse(content)
  }
  if v.has_prefix("polygon(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=8, end_offset=v.length() - 1),
      )
      .trim()
      .to_owned()
    return parse_clip_path_polygon(content)
  }
  if v.has_prefix("path(") && v.has_suffix(")") {
    let content = view_to_string(
        raw_v.view(start_offset=5, end_offset=raw_v.length() - 1),
      )
      .trim()
      .to_owned()
    return parse_clip_path_path(content)
  }
  None
}

///|
fn parse_clip_path_rect(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() < 4 {
    return None
  }
  let top = parse_clip_path_shape_value(parts[0]) catch { _ => return None }
  let right = parse_clip_path_shape_value(parts[1]) catch { _ => return None }
  let bottom = parse_clip_path_shape_value(parts[2]) catch { _ => return None }
  let left = parse_clip_path_shape_value(parts[3]) catch { _ => return None }
  Rect(top, right, bottom, left)
}

///|
fn parse_clip_path_xywh(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() < 4 {
    return None
  }
  let x = parse_clip_path_shape_value(parts[0]) catch { _ => return None }
  let y = parse_clip_path_shape_value(parts[1]) catch { _ => return None }
  let width = parse_clip_path_shape_value(parts[2]) catch { _ => return None }
  let height = parse_clip_path_shape_value(parts[3]) catch { _ => return None }
  Xywh(x, y, width, height)
}

///|
fn parse_clip_path_circle(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() == 0 {
    return None
  }
  let mut at_index = -1
  for i in 0..<parts.length() {
    if parts[i] == "at" {
      at_index = i
      break
    }
  }
  let mut radius = -0.5
  let mut center_x = -0.5
  let mut center_y = -0.5
  if at_index == 0 {
    if parts.length() < 3 {
      return None
    }
    center_x = parse_clip_path_shape_value(parts[1]) catch { _ => return None }
    center_y = parse_clip_path_shape_value(parts[2]) catch { _ => return None }
  } else if at_index > 0 {
    radius = parse_clip_path_shape_value(parts[0]) catch { _ => return None }
    if parts.length() <= at_index + 2 {
      return None
    }
    center_x = parse_clip_path_shape_value(parts[at_index + 1]) catch {
      _ => return None
    }
    center_y = parse_clip_path_shape_value(parts[at_index + 2]) catch {
      _ => return None
    }
  } else {
    radius = parse_clip_path_shape_value(parts[0]) catch { _ => return None }
  }
  Circle(radius, center_x, center_y)
}

///|
fn parse_clip_path_ellipse(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() == 0 {
    return None
  }
  let mut at_index = -1
  for i in 0..<parts.length() {
    if parts[i] == "at" {
      at_index = i
      break
    }
  }
  let mut radius_x = -0.5
  let mut radius_y = -0.5
  let mut center_x = -0.5
  let mut center_y = -0.5
  if at_index == 0 {
    if parts.length() < 3 {
      return None
    }
    center_x = parse_clip_path_shape_value(parts[1]) catch { _ => return None }
    center_y = parse_clip_path_shape_value(parts[2]) catch { _ => return None }
  } else if at_index > 0 {
    if at_index < 2 || parts.length() <= at_index + 2 {
      return None
    }
    radius_x = parse_clip_path_shape_value(parts[0]) catch { _ => return None }
    radius_y = parse_clip_path_shape_value(parts[1]) catch { _ => return None }
    center_x = parse_clip_path_shape_value(parts[at_index + 1]) catch {
      _ => return None
    }
    center_y = parse_clip_path_shape_value(parts[at_index + 2]) catch {
      _ => return None
    }
  } else {
    if parts.length() < 2 {
      return None
    }
    radius_x = parse_clip_path_shape_value(parts[0]) catch { _ => return None }
    radius_y = parse_clip_path_shape_value(parts[1]) catch { _ => return None }
  }
  Ellipse(radius_x, radius_y, center_x, center_y)
}

///|
fn parse_clip_path_polygon(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  let values : Array[Double] = []
  for part in parts {
    if part == "evenodd" || part == "nonzero" {
      continue
    }
    let v = parse_clip_path_shape_value(part) catch { _ => return None }
    values.push(v)
  }
  if values.length() < 6 || values.length() % 2 != 0 {
    return None
  }
  let points : Array[(Double, Double)] = []
  let mut i = 0
  while i + 1 < values.length() {
    points.push((values[i], values[i + 1]))
    i = i + 2
  }
  Polygon(points)
}

///|
fn parse_clip_path_path(content : String) -> @style.ClipPath {
  let path_data = match extract_clip_path_path_string(content) {
    Some(v) => v
    None => return None
  }
  parse_clip_path_path_data(path_data)
}

///|
fn extract_clip_path_path_string(content : String) -> String? {
  match extract_clip_path_path_string_with_quote(content, '"') {
    Some(v) => Some(v)
    None => extract_clip_path_path_string_with_quote(content, '\'')
  }
}

///|
fn extract_clip_path_path_string_with_quote(
  content : String,
  quote : Char,
) -> String? {
  let out = StringBuilder()
  let mut in_quote = false
  for c in content.iter() {
    if in_quote {
      if c == quote {
        return Some(out.to_string())
      }
      out.write_char(c)
    } else if c == quote {
      in_quote = true
    }
  }
  None
}

///|
fn parse_clip_path_path_data(path_data : String) -> @style.ClipPath {
  let tokens = tokenize_clip_path_path_data(path_data)
  let points : Array[(Double, Double)] = []
  let mut i = 0
  let mut command = ""
  let mut current_x = 0.0
  let mut current_y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  let mut has_quadratic_control = false
  let mut quadratic_control_x = 0.0
  let mut quadratic_control_y = 0.0
  let mut has_cubic_control = false
  let mut cubic_control_x = 0.0
  let mut cubic_control_y = 0.0
  while i < tokens.length() {
    let token = tokens[i]
    if is_clip_path_path_command(token) {
      if token == "Z" || token == "z" {
        current_x = start_x
        current_y = start_y
        has_quadratic_control = false
        has_cubic_control = false
        command = ""
        i += 1
        continue
      }
      command = token
      i += 1
      continue
    }
    match command {
      "M" | "m" => {
        if i + 1 >= tokens.length() {
          return None
        }
        let x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        if command == "m" {
          current_x += x
          current_y += y
        } else {
          current_x = x
          current_y = y
        }
        start_x = current_x
        start_y = current_y
        points.push((current_x, current_y))
        command = if command == "m" { "l" } else { "L" }
        has_quadratic_control = false
        has_cubic_control = false
        i += 2
      }
      "L" | "l" => {
        if i + 1 >= tokens.length() {
          return None
        }
        let x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        if command == "l" {
          current_x += x
          current_y += y
        } else {
          current_x = x
          current_y = y
        }
        points.push((current_x, current_y))
        has_quadratic_control = false
        has_cubic_control = false
        i += 2
      }
      "H" | "h" => {
        let x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        if command == "h" {
          current_x += x
        } else {
          current_x = x
        }
        points.push((current_x, current_y))
        has_quadratic_control = false
        has_cubic_control = false
        i += 1
      }
      "V" | "v" => {
        let y = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        if command == "v" {
          current_y += y
        } else {
          current_y = y
        }
        points.push((current_x, current_y))
        has_quadratic_control = false
        has_cubic_control = false
        i += 1
      }
      "Q" | "q" => {
        if i + 3 >= tokens.length() {
          return None
        }
        let control_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let control_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return None
        }
        let absolute_control_x = if command == "q" {
          current_x + control_x
        } else {
          control_x
        }
        let absolute_control_y = if command == "q" {
          current_y + control_y
        } else {
          control_y
        }
        let absolute_end_x = if command == "q" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "q" {
          current_y + end_y
        } else {
          end_y
        }
        append_quadratic_path_points(
          points, current_x, current_y, absolute_control_x, absolute_control_y, absolute_end_x,
          absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_quadratic_control = true
        quadratic_control_x = absolute_control_x
        quadratic_control_y = absolute_control_y
        has_cubic_control = false
        i += 4
      }
      "T" | "t" => {
        if i + 1 >= tokens.length() {
          return None
        }
        let end_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        let absolute_control_x = if has_quadratic_control {
          2.0 * current_x - quadratic_control_x
        } else {
          current_x
        }
        let absolute_control_y = if has_quadratic_control {
          2.0 * current_y - quadratic_control_y
        } else {
          current_y
        }
        let absolute_end_x = if command == "t" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "t" {
          current_y + end_y
        } else {
          end_y
        }
        append_quadratic_path_points(
          points, current_x, current_y, absolute_control_x, absolute_control_y, absolute_end_x,
          absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_quadratic_control = true
        quadratic_control_x = absolute_control_x
        quadratic_control_y = absolute_control_y
        has_cubic_control = false
        i += 2
      }
      "C" | "c" => {
        if i + 5 >= tokens.length() {
          return None
        }
        let control1_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let control1_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        let control2_x = match parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return None
        }
        let control2_y = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 4]) {
          Some(v) => v
          None => return None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 5]) {
          Some(v) => v
          None => return None
        }
        let absolute_control1_x = if command == "c" {
          current_x + control1_x
        } else {
          control1_x
        }
        let absolute_control1_y = if command == "c" {
          current_y + control1_y
        } else {
          control1_y
        }
        let absolute_control2_x = if command == "c" {
          current_x + control2_x
        } else {
          control2_x
        }
        let absolute_control2_y = if command == "c" {
          current_y + control2_y
        } else {
          control2_y
        }
        let absolute_end_x = if command == "c" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "c" {
          current_y + end_y
        } else {
          end_y
        }
        append_cubic_path_points(
          points, current_x, current_y, absolute_control1_x, absolute_control1_y,
          absolute_control2_x, absolute_control2_y, absolute_end_x, absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_cubic_control = true
        cubic_control_x = absolute_control2_x
        cubic_control_y = absolute_control2_y
        has_quadratic_control = false
        i += 6
      }
      "S" | "s" => {
        if i + 3 >= tokens.length() {
          return None
        }
        let control2_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let control2_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return None
        }
        let absolute_control1_x = if has_cubic_control {
          2.0 * current_x - cubic_control_x
        } else {
          current_x
        }
        let absolute_control1_y = if has_cubic_control {
          2.0 * current_y - cubic_control_y
        } else {
          current_y
        }
        let absolute_control2_x = if command == "s" {
          current_x + control2_x
        } else {
          control2_x
        }
        let absolute_control2_y = if command == "s" {
          current_y + control2_y
        } else {
          control2_y
        }
        let absolute_end_x = if command == "s" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "s" {
          current_y + end_y
        } else {
          end_y
        }
        append_cubic_path_points(
          points, current_x, current_y, absolute_control1_x, absolute_control1_y,
          absolute_control2_x, absolute_control2_y, absolute_end_x, absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_cubic_control = true
        cubic_control_x = absolute_control2_x
        cubic_control_y = absolute_control2_y
        has_quadratic_control = false
        i += 4
      }
      "A" | "a" => {
        if i + 6 >= tokens.length() {
          return None
        }
        let radius_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return None
        }
        let radius_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return None
        }
        let rotation_degrees = match
          parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return None
        }
        let large_arc_flag = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return None
        }
        let sweep_flag = match parse_clip_path_path_number(tokens[i + 4]) {
          Some(v) => v
          None => return None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 5]) {
          Some(v) => v
          None => return None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 6]) {
          Some(v) => v
          None => return None
        }
        let absolute_end_x = if command == "a" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "a" {
          current_y + end_y
        } else {
          end_y
        }
        append_arc_path_points(
          points,
          current_x,
          current_y,
          radius_x,
          radius_y,
          rotation_degrees,
          large_arc_flag != 0.0,
          sweep_flag != 0.0,
          absolute_end_x,
          absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_quadratic_control = false
        has_cubic_control = false
        i += 7
      }
      _ => return None
    }
  }
  if points.length() < 3 {
    return None
  }
  Polygon(points)
}

///|
fn tokenize_clip_path_path_data(path_data : String) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder()
  for c in path_data.iter() {
    if is_clip_path_path_command_char(c) {
      flush_clip_path_path_token(tokens, current)
      tokens.push(clip_path_path_char_to_string(c))
    } else if c == ',' || c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      flush_clip_path_path_token(tokens, current)
    } else if c == '-' || c == '+' {
      let current_text = current.to_string()
      if !current_text.is_empty() &&
        !current_text.has_suffix("e") &&
        !current_text.has_suffix("E") {
        flush_clip_path_path_token(tokens, current)
      }
      current.write_char(c)
    } else {
      current.write_char(c)
    }
  }
  flush_clip_path_path_token(tokens, current)
  tokens
}

///|
fn flush_clip_path_path_token(
  tokens : Array[String],
  current : StringBuilder,
) -> Unit {
  let token = current.to_string().trim().to_owned()
  if !token.is_empty() {
    tokens.push(token)
    current.reset()
  }
}

///|
fn append_quadratic_path_points(
  points : Array[(Double, Double)],
  start_x : Double,
  start_y : Double,
  control_x : Double,
  control_y : Double,
  end_x : Double,
  end_y : Double,
) -> Unit {
  let segments = 8
  for step in 1..<(segments + 1) {
    let t = step.to_double() / segments.to_double()
    let one_minus_t = 1.0 - t
    let x = one_minus_t * one_minus_t * start_x +
      2.0 * one_minus_t * t * control_x +
      t * t * end_x
    let y = one_minus_t * one_minus_t * start_y +
      2.0 * one_minus_t * t * control_y +
      t * t * end_y
    points.push((x, y))
  }
}

///|
fn append_cubic_path_points(
  points : Array[(Double, Double)],
  start_x : Double,
  start_y : Double,
  control1_x : Double,
  control1_y : Double,
  control2_x : Double,
  control2_y : Double,
  end_x : Double,
  end_y : Double,
) -> Unit {
  let segments = 8
  for step in 1..<(segments + 1) {
    let t = step.to_double() / segments.to_double()
    let one_minus_t = 1.0 - t
    let x = one_minus_t * one_minus_t * one_minus_t * start_x +
      3.0 * one_minus_t * one_minus_t * t * control1_x +
      3.0 * one_minus_t * t * t * control2_x +
      t * t * t * end_x
    let y = one_minus_t * one_minus_t * one_minus_t * start_y +
      3.0 * one_minus_t * one_minus_t * t * control1_y +
      3.0 * one_minus_t * t * t * control2_y +
      t * t * t * end_y
    points.push((x, y))
  }
}

///|
fn append_arc_path_points(
  points : Array[(Double, Double)],
  start_x : Double,
  start_y : Double,
  radius_x : Double,
  radius_y : Double,
  rotation_degrees : Double,
  large_arc : Bool,
  sweep : Bool,
  end_x : Double,
  end_y : Double,
) -> Unit {
  if (start_x == end_x && start_y == end_y) ||
    radius_x == 0.0 ||
    radius_y == 0.0 {
    points.push((end_x, end_y))
    return
  }
  let mut rx = if radius_x < 0.0 { -radius_x } else { radius_x }
  let mut ry = if radius_y < 0.0 { -radius_y } else { radius_y }
  let pi = 3.14159265358979323846
  let phi = rotation_degrees * pi / 180.0
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let dx = (start_x - end_x) / 2.0
  let dy = (start_y - end_y) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if lambda > 1.0 {
    let scale = lambda.sqrt()
    rx = rx * scale
    ry = ry * scale
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let denominator = rx2 * y1p2 + ry2 * x1p2
  if denominator == 0.0 {
    points.push((end_x, end_y))
    return
  }
  let sq = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / denominator
  let sq_abs = if sq < 0.0 { 0.0 } else { sq }
  let coef = sq_abs.sqrt() * (if large_arc == sweep { -1.0 } else { 1.0 })
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  let center_x = cos_phi * cxp - sin_phi * cyp + (start_x + end_x) / 2.0
  let center_y = sin_phi * cxp + cos_phi * cyp + (start_y + end_y) / 2.0
  let theta1 = clip_path_angle_between(
    1.0,
    0.0,
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
  )
  let mut dtheta = clip_path_angle_between(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  )
  if !sweep && dtheta > 0.0 {
    dtheta = dtheta - 2.0 * pi
  } else if sweep && dtheta < 0.0 {
    dtheta = dtheta + 2.0 * pi
  }
  let segments = clip_path_max_int((dtheta.abs() / pi * 8.0).to_int(), 2)
  for step in 1..<(segments + 1) {
    let t = step.to_double() / segments.to_double()
    let theta = theta1 + t * dtheta
    let cos_t = @math.cos(theta)
    let sin_t = @math.sin(theta)
    let x = cos_phi * rx * cos_t - sin_phi * ry * sin_t + center_x
    let y = sin_phi * rx * cos_t + cos_phi * ry * sin_t + center_y
    points.push((x, y))
  }
}

///|
fn clip_path_angle_between(
  ux : Double,
  uy : Double,
  vx : Double,
  vy : Double,
) -> Double {
  let dot = ux * vx + uy * vy
  let len_product = (ux * ux + uy * uy).sqrt() * (vx * vx + vy * vy).sqrt()
  if len_product == 0.0 {
    return 0.0
  }
  let mut cos_angle = dot / len_product
  if cos_angle > 1.0 {
    cos_angle = 1.0
  }
  if cos_angle < -1.0 {
    cos_angle = -1.0
  }
  let angle = @math.acos(cos_angle)
  let cross = ux * vy - uy * vx
  if cross < 0.0 {
    -angle
  } else {
    angle
  }
}

///|
fn clip_path_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn is_clip_path_path_command(token : String) -> Bool {
  token == "M" ||
  token == "m" ||
  token == "L" ||
  token == "l" ||
  token == "H" ||
  token == "h" ||
  token == "V" ||
  token == "v" ||
  token == "Q" ||
  token == "q" ||
  token == "T" ||
  token == "t" ||
  token == "C" ||
  token == "c" ||
  token == "S" ||
  token == "s" ||
  token == "A" ||
  token == "a" ||
  token == "Z" ||
  token == "z"
}

///|
fn is_clip_path_path_command_char(c : Char) -> Bool {
  c == 'M' ||
  c == 'm' ||
  c == 'L' ||
  c == 'l' ||
  c == 'H' ||
  c == 'h' ||
  c == 'V' ||
  c == 'v' ||
  c == 'Z' ||
  c == 'z' ||
  c == 'C' ||
  c == 'c' ||
  c == 'S' ||
  c == 's' ||
  c == 'Q' ||
  c == 'q' ||
  c == 'T' ||
  c == 't' ||
  c == 'A' ||
  c == 'a'
}

///|
fn clip_path_path_char_to_string(c : Char) -> String {
  let sb = StringBuilder()
  sb.write_char(c)
  sb.to_string()
}

///|
fn parse_clip_path_path_number(token : String) -> Double? {
  let value = @string.parse_double(token) catch { _ => return None }
  Some(value)
}

///|
fn split_clip_path_values(content : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current = StringBuilder()
  for c in content.iter() {
    if c == ',' || c == ' ' || c == '\t' || c == '\n' {
      let s = current.to_string().trim().to_owned()
      if !s.is_empty() {
        parts.push(s)
      }
      current = StringBuilder()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string().trim().to_owned()
  if !last.is_empty() {
    parts.push(last)
  }
  parts
}

///|
fn parse_clip_path_shape_value(value : String) -> Double raise Error {
  let v = value.trim().to_lower()
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned().trim())
      return -(n / 100.0)
    }
    None => ()
  }
  match v.strip_suffix("px") {
    Some(num_str) => @string.parse_double(num_str.to_owned().trim())
    None => @string.parse_double(v)
  }
}

///|
fn parse_clip_path_inset_value(value : String) -> Double {
  let v = value.trim().to_lower()
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned().trim()) catch {
        _ => return 0.0
      }
      return -(n / 100.0)
    }
    None => ()
  }
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned().trim()) catch {
        _ => return 0.0
      }
      return n
    }
    None => ()
  }
  @string.parse_double(v) catch {
    _ => 0.0
  }
}

///|
/// Parse a single clip rect value (auto or length)
fn parse_clip_value(value : String) -> Double {
  let v = value.trim().to_lower()
  if v == "auto" {
    // auto in clip rect context means 0 (no offset)
    return 0.0
  }
  // Parse px value
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned().trim()) catch {
        _ => return 0.0
      }
      return n
    }
    None => ()
  }
  // Parse plain number
  let n = @string.parse_double(v.to_owned()) catch { _ => return 0.0 }
  n
}
