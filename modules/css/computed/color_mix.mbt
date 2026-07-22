///|
/// `color-mix()` (CSS Color 5) evaluation. Parses
/// `color-mix(in <space>, <color> <p>?, <color> <p>?)` and mixes the two colors
/// in the requested interpolation color space. Hue interpolation method
/// (shorter/longer/...) is not
/// yet honored; the shortest arc is always used.

///|
/// Split `s` into segments at occurrences of `sep` that sit at parenthesis
/// depth 0 (so commas / spaces inside nested color functions are preserved).
fn split_depth0(s : String, sep : Char) -> Array[String] {
  let res : Array[String] = []
  let mut depth = 0
  let mut start = 0
  let mut i = 0
  for c in s {
    if c == '(' {
      depth = depth + 1
    } else if c == ')' {
      if depth > 0 {
        depth = depth - 1
      }
    } else if c == sep && depth == 0 {
      res.push(view_to_string(s.view(start_offset=start, end_offset=i)))
      start = i + 1
    }
    i = i + 1
  }
  res.push(view_to_string(s.view(start_offset=start)))
  res
}

///|
/// Map a `color-mix` interpolation-space spec (`in <space> [<hue> hue]`) to a
/// ColorSpace. Returns None when the spec is malformed or the space is unknown.
fn parse_interpolation_space(spec : String) -> ColorInterpolationSpace? {
  let s = spec.trim().to_lower()
  if !s.has_prefix("in ") {
    return None
  }
  let rest = view_to_string(s.view(start_offset=3)).trim().to_owned()
  // The first token is the color space; any remainder is the hue method.
  let tokens = split_depth0(rest, ' ').filter(fn(x) { x.trim().length() > 0 })
  if tokens.length() == 0 {
    return None
  }
  match tokens[0].trim().to_owned() {
    "srgb" => Some(Srgb)
    "oklab" => Some(Oklab)
    "oklch" => Some(Oklch)
    "lab" => Some(Lab)
    "lch" => Some(Lch)
    _ => None
  }
}

///|
/// Parse one `color-mix` component: `<color> <percentage>?` (in either order).
/// Returns the resolved color (None if unresolved) and the optional weight as a
/// fraction (30% => 0.3).
fn parse_mix_component(part : String) -> (@types.Color?, Double?) {
  let tokens = split_depth0(part.trim().to_owned(), ' ').filter(fn(x) {
    x.trim().length() > 0
  })
  let mut percent : Double? = None
  let color_tokens : Array[String] = []
  for tok in tokens {
    let t = tok.trim().to_owned()
    if t.has_suffix("%") {
      let num = view_to_string(
        t.view(start_offset=0, end_offset=t.length() - 1),
      )
      percent = Some(parse_number(num) / 100.0)
    } else {
      color_tokens.push(t)
    }
  }
  if color_tokens.length() == 0 {
    return (None, percent)
  }
  // Re-join color tokens (e.g. a function whose args were space-separated).
  let sb = StringBuilder::new()
  for i = 0; i < color_tokens.length(); i = i + 1 {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(color_tokens[i])
  }
  (parse_color_value(sb.to_string()).get_color(), percent)
}

///|
/// Parse and evaluate a `color-mix()` value. Returns None when it is not a
/// color-mix or cannot be resolved (so the caller falls through).
fn parse_color_mix(v : String) -> CssColorValue? {
  if !v.has_prefix("color-mix(") || !v.has_suffix(")") {
    return None
  }
  let inner = view_to_string(v.view(start_offset=10, end_offset=v.length() - 1))
  let parts = split_depth0(inner, ',')
  if parts.length() != 3 {
    return None
  }
  let space = match parse_interpolation_space(parts[0]) {
    Some(sp) => sp
    None => return None
  }
  let (c1, p1) = parse_mix_component(parts[1])
  let (c2, p2) = parse_mix_component(parts[2])
  match (c1, c2) {
    (Some(col1), Some(col2)) => {
      // Resolve the two weights to fractions summing the mix ratio.
      let (w1, w2) = match (p1, p2) {
        (None, None) => (0.5, 0.5)
        (Some(a), None) => (a, 1.0 - a)
        (None, Some(b)) => (1.0 - b, b)
        (Some(a), Some(b)) => (a, b)
      }
      let total = w1 + w2
      if total <= 0.0 {
        return None
      }
      let t = w2 / total
      Some(Resolved(interpolate_color_in(space, col1, col2, t)))
    }
    _ => None
  }
}
