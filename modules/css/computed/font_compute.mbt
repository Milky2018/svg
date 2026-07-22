///|
/// Parse font-size value and return computed value in pixels
fn parse_font_size(value : String, ctx : ComputeContext) -> Double {
  let v = value.trim()

  // Handle rem units (relative to root font-size) first.
  // "1rem" also ends with "em", so ordering matters.
  match v.strip_suffix("rem") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch { _ => 1.0 }
      return n * ctx.root_font_size
    }
    None => ()
  }

  // Handle em units (relative to parent font-size)
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch { _ => 1.0 }
      return n * ctx.font_size
    }
    None => ()
  }

  // Handle px units
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return ctx.font_size
      }
      return n
    }
    None => ()
  }

  // Handle pt units (1pt = 1.333px)
  match v.strip_suffix("pt") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return ctx.font_size
      }
      return n * 1.333
    }
    None => ()
  }

  // Handle percent (relative to parent font-size)
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return ctx.font_size
      }
      return n / 100.0 * ctx.font_size
    }
    None => ()
  }

  let plain_number = @string.parse_double(v) catch { _ => -1.0 }
  if plain_number == 0.0 {
    return 0.0
  }

  // Handle keyword values
  match v {
    "xx-small" => 9.0
    "x-small" => 10.0
    "small" => 13.0
    "medium" => 16.0
    "large" => 18.0
    "x-large" => 24.0
    "xx-large" => 32.0
    "smaller" => ctx.font_size * 0.833
    "larger" => ctx.font_size * 1.2
    _ => ctx.font_size // Default to inherited font-size
  }
}

///|
/// Parse line-height value and return computed value in pixels
fn parse_line_height(
  value : String,
  font_size : Double,
  root_font_size? : Double = 16.0,
) -> Double {
  let v = value.trim()

  // Handle unitless number (multiplier of font-size)
  // Check if it's a pure number
  let is_pure_number = {
    let mut pure = true
    for i = 0; i < v.length(); i = i + 1 {
      let c = v[i].to_int().unsafe_to_char()
      if c != '.' && !(c >= '0' && c <= '9') {
        pure = false
        break
      }
    }
    pure
  }
  if is_pure_number && !v.is_empty() {
    let n = @string.parse_double(v.to_owned()) catch { _ => 1.0 }
    return n * font_size
  }

  // Handle px units
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return font_size
      }
      return n
    }
    None => ()
  }

  // Handle rem units
  match v.strip_suffix("rem") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return font_size
      }
      return n * root_font_size
    }
    None => ()
  }

  // Handle em units
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return font_size
      }
      return n * font_size
    }
    None => ()
  }

  // Handle percent (relative to font-size)
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_owned()) catch {
        _ => return font_size
      }
      return n / 100.0 * font_size
    }
    None => ()
  }

  // "normal" = 1.2 * font-size typically
  if v == "normal" {
    return font_size * 1.2
  }

  // Default to font-size
  font_size
}

///|
priv struct ParsedFontShorthand {
  font_size : Double
  line_height : Double
  font_weight : Double
  font_family : String
}

///|
/// Parse font shorthand and extract font-size and line-height
/// Supports: [style] [variant] [weight] size[/line-height] family
fn parse_font_shorthand(
  value : String,
  ctx : ComputeContext,
) -> ParsedFontShorthand {
  let v = value.trim()

  // Split by whitespace
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  let mut in_quotes = false
  for c in v.iter() {
    if c == '"' || c == '\'' {
      in_quotes = !in_quotes
      current.write_char(c)
    } else if (c == ' ' || c == '\t') && !in_quotes {
      let s = current.to_string()
      if s.length() > 0 {
        parts.push(s)
      }
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  let s = current.to_string()
  if s.length() > 0 {
    parts.push(s)
  }

  // Find the part with font-size (and optional /line-height)
  // Font-size is required and comes before font-family
  // Look for a part that starts with a digit or contains 'px', 'em', 'rem', '%'
  let mut font_size = ctx.font_size
  let mut line_height = ctx.font_size
  let mut font_weight = 400.0
  let mut size_index = -1
  for idx = 0; idx < parts.length(); idx = idx + 1 {
    let part = parts[idx]
    // Check if this part contains size/line-height
    if part.contains("/") {
      // Split by /
      let mut slash_idx = -1
      for i = 0; i < part.length(); i = i + 1 {
        if part[i] == '/' {
          slash_idx = i
          break
        }
      }
      if slash_idx > 0 {
        let size_part = part.unsafe_substring(start=0, end=slash_idx)
        let lh_part = part.unsafe_substring(
          start=slash_idx + 1,
          end=part.length(),
        )
        font_size = parse_font_size(size_part, ctx)
        line_height = parse_line_height(
          lh_part,
          font_size,
          root_font_size=ctx.root_font_size,
        )
        size_index = idx
        break
      }
    } else {
      // Check if it's a size value (starts with digit or contains unit)
      let first_char = if part.length() > 0 { part[0] } else { ' ' }
      if first_char >= '0' && first_char <= '9' {
        font_size = parse_font_size(part, ctx)
        line_height = font_size // Default line-height = font-size (ratio 1)
        size_index = idx
        break
      }
    }
  }
  if size_index > 0 {
    for idx = 0; idx < size_index; idx = idx + 1 {
      let part = parts[idx].trim().to_lower().to_owned()
      if part == "normal" ||
        part == "bold" ||
        part == "bolder" ||
        part == "lighter" {
        font_weight = parse_font_weight(part)
        continue
      }
      let parsed_weight = @string.parse_double(part) catch { _ => -1.0 }
      if parsed_weight >= 1.0 && parsed_weight <= 1000.0 {
        font_weight = parsed_weight
      }
    }
  }
  let font_family = if size_index >= 0 && size_index + 1 < parts.length() {
    let family_parts : Array[String] = []
    for idx = size_index + 1; idx < parts.length(); idx = idx + 1 {
      family_parts.push(parts[idx])
    }
    parse_font_family(family_parts.join(" "))
  } else {
    ""
  }
  { font_size, line_height, font_weight, font_family }
}
