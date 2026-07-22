///|
/// Parse a dimension value from string
pub fn parse_dimension(value : String) -> @types.Dimension {
  let v = value.trim()
  if v == "auto" || v == "none" {
    return Auto
  }
  // Intrinsic sizing keywords
  if v == "min-content" {
    return MinContent
  }
  if v == "max-content" {
    return MaxContent
  }
  // fit-content(<length-percentage>)
  if v.has_prefix("fit-content(") && v.has_suffix(")") {
    // Extract content between "fit-content(" and ")"
    let v_str = v.to_owned()
    let inner = v_str.unsafe_substring(start=12, end=v_str.length() - 1)
    // Parse the inner value as a length
    match inner.strip_suffix("px") {
      Some(num_str) => {
        let n = @string.parse_double(num_str.to_owned()) catch {
          _ => return Auto
        }
        return FitContent(n)
      }
      None => ()
    }
    // Try percentage
    match inner.strip_suffix("%") {
      Some(num_str) => {
        let n = @string.parse_double(num_str.to_owned()) catch {
          _ => return Auto
        }
        // For fit-content, percentage is relative to available space
        // Store as negative to differentiate from length
        return FitContent(n)
      }
      None => ()
    }
    return Auto
  }
  // Try to parse as length (px)
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return Auto
      }
      return Length(n)
    }
    None => ()
  }
  // Try to parse as percentage
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return Auto
      }
      return Percent(n / 100.0)
    }
    None => ()
  }
  // Try to parse as plain number (treated as px)
  let n = @string.parse_double(v.to_owned()) catch {
    _ => return Auto
  }
  Length(n)
}

///|
/// Extract border width from shorthand value
/// Handles formats like "3px", "solid 3px", "1px solid red", "none", etc.
pub fn extract_border_width(value : String) -> @types.Dimension {
  let v = value.trim()

  // Handle "none" case
  if v == "none" || v == "0" {
    return Length(0.0)
  }

  // Split by whitespace and look for a dimension value
  let parts = split_whitespace(v.to_owned())
  let mut has_visible_style = false
  for part in parts {
    let lower = part.to_lower()
    match lower {
      "thin" => return Length(1.0)
      "medium" => return Length(3.0)
      "thick" => return Length(5.0)
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
      "none" | "hidden" => continue
      _ => ()
    }
    // Check if this part looks like a dimension (ends with px or is a number)
    if part.has_suffix("px") {
      match part.strip_suffix("px") {
        Some(num_str) => {
          let n = @string.parse_double(num_str.to_owned()) catch {
            _ => continue
          }
          return Length(n)
        }
        None => continue
      }
    }
    // Try plain number
    let first_char = part[0].to_int()
    if first_char >= '0'.to_int() && first_char <= '9'.to_int() {
      let n = @string.parse_double(part) catch { _ => continue }
      return Length(n)
    }
  }

  // Compatible default for style-only shorthand like "border: solid".
  if has_visible_style {
    Length(1.5)
  } else {
    // Default: no border
    Length(0.0)
  }
}

///|
/// Split string by whitespace into parts
fn split_whitespace(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ' ' || c == '\t' || c == '\n' {
      if current.to_string().length() > 0 {
        result.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }
  result
}

///|
