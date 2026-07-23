///|
priv enum ComputedStyleProperty {
  StyleFill
  StyleFillRule
  StyleClipRule
  StyleFillOpacity
  StyleStroke
  StyleStrokeWidth
  StyleStrokeLinecap
  StyleStrokeLinejoin
  StyleStrokeMiterlimit
  StyleStrokeDasharray
  StyleStrokeDashoffset
  StyleStrokeOpacity
  StyleVectorEffect
  StyleImageRendering
  StyleColor
  StylePaintOrder
  StyleOpacity
  StyleMarkerStart
  StyleMarkerMid
  StyleMarkerEnd
  StyleStopColor
  StyleStopOpacity
  StyleFontSize
}

///|
fn computed_style_property(name : String) -> ComputedStyleProperty? {
  match name {
    "fill" => Some(StyleFill)
    "fill-rule" => Some(StyleFillRule)
    "clip-rule" => Some(StyleClipRule)
    "fill-opacity" => Some(StyleFillOpacity)
    "stroke" => Some(StyleStroke)
    "stroke-width" => Some(StyleStrokeWidth)
    "stroke-linecap" => Some(StyleStrokeLinecap)
    "stroke-linejoin" => Some(StyleStrokeLinejoin)
    "stroke-miterlimit" => Some(StyleStrokeMiterlimit)
    "stroke-dasharray" => Some(StyleStrokeDasharray)
    "stroke-dashoffset" => Some(StyleStrokeDashoffset)
    "stroke-opacity" => Some(StyleStrokeOpacity)
    "vector-effect" => Some(StyleVectorEffect)
    "image-rendering" => Some(StyleImageRendering)
    "color" => Some(StyleColor)
    "paint-order" => Some(StylePaintOrder)
    "opacity" => Some(StyleOpacity)
    "marker-start" => Some(StyleMarkerStart)
    "marker-mid" => Some(StyleMarkerMid)
    "marker-end" => Some(StyleMarkerEnd)
    "stop-color" => Some(StyleStopColor)
    "stop-opacity" => Some(StyleStopOpacity)
    "font-size" => Some(StyleFontSize)
    _ => None
  }
}

///|
fn ComputedStyleProperty::name(self : ComputedStyleProperty) -> String {
  match self {
    StyleFill => "fill"
    StyleFillRule => "fill-rule"
    StyleClipRule => "clip-rule"
    StyleFillOpacity => "fill-opacity"
    StyleStroke => "stroke"
    StyleStrokeWidth => "stroke-width"
    StyleStrokeLinecap => "stroke-linecap"
    StyleStrokeLinejoin => "stroke-linejoin"
    StyleStrokeMiterlimit => "stroke-miterlimit"
    StyleStrokeDasharray => "stroke-dasharray"
    StyleStrokeDashoffset => "stroke-dashoffset"
    StyleStrokeOpacity => "stroke-opacity"
    StyleVectorEffect => "vector-effect"
    StyleImageRendering => "image-rendering"
    StyleColor => "color"
    StylePaintOrder => "paint-order"
    StyleOpacity => "opacity"
    StyleMarkerStart => "marker-start"
    StyleMarkerMid => "marker-mid"
    StyleMarkerEnd => "marker-end"
    StyleStopColor => "stop-color"
    StyleStopOpacity => "stop-opacity"
    StyleFontSize => "font-size"
  }
}

///|
fn valid_svg_number(value : String, allow_length : Bool) -> Bool {
  let trimmed = trim_string(value)
  if allow_length {
    svg_length_number_text(trimmed) is Some(_)
  } else {
    parse_number_strict(trimmed) is Some(_)
  }
}

///|
fn svg_number_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut token = StringBuilder::new()
  for c in value {
    if c == ',' || c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      let current = token.to_string()
      if current.length() > 0 {
        tokens.push(current)
        token = StringBuilder::new()
      }
    } else {
      token.write_char(c)
    }
  }
  let current = token.to_string()
  if current.length() > 0 {
    tokens.push(current)
  }
  tokens
}

///|
fn valid_svg_paint(value : String) -> Bool {
  let trimmed = trim_string(value)
  let lower = trimmed.to_lower()
  if lower == "none" || lower == "currentcolor" {
    return true
  }
  if string_starts_with(lower, "url(") {
    let close = find_first(trimmed, ')')
    if close < 0 {
      return false
    }
    let reference = build_substring(trimmed, 0, close + 1)
    if parse_url_ref(reference) is None {
      return false
    }
    let fallback = trim_string(
      build_substring(trimmed, close + 1, trimmed.length()),
    )
    return fallback.length() == 0 || valid_svg_paint(fallback)
  }
  !(@css_computed.parse_color(trimmed) is Invalid)
}

///|
fn valid_svg_paint_order(value : String) -> Bool {
  let tokens = split_tokens(trim_string(value).to_lower())
  if tokens.length() == 0 {
    return false
  }
  for token in tokens {
    if token == "normal" {
      return tokens.length() == 1
    }
    if token != "normal" &&
      token != "fill" &&
      token != "stroke" &&
      token != "markers" {
      return false
    }
  }
  true
}

///|
fn valid_svg_dasharray(value : String) -> Bool {
  let normalized = trim_string(value)
  if normalized == "none" {
    return true
  }
  let tokens = svg_number_tokens(normalized)
  if tokens.length() == 0 {
    return false
  }
  for token in tokens {
    if !valid_svg_number(token, true) || parse_length(token) < 0.0 {
      return false
    }
  }
  true
}

///|
fn valid_svg_transform(value : String) -> Bool {
  let input = trim_string(value)
  if input == "none" {
    return true
  }
  let mut i = 0
  let mut functions = 0
  while i < input.length() {
    while i < input.length() {
      let c = Int::unsafe_to_char(input[i].to_int())
      if css_is_whitespace(c) || c == ',' {
        i += 1
      } else {
        break
      }
    }
    if i >= input.length() {
      break
    }
    let name_start = i
    while i < input.length() {
      let c = Int::unsafe_to_char(input[i].to_int())
      if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
        i += 1
      } else {
        break
      }
    }
    let name = build_substring(input, name_start, i)
    while i < input.length() &&
          css_is_whitespace(Int::unsafe_to_char(input[i].to_int())) {
      i += 1
    }
    if i >= input.length() || Int::unsafe_to_char(input[i].to_int()) != '(' {
      return false
    }
    i += 1
    let args_start = i
    while i < input.length() && Int::unsafe_to_char(input[i].to_int()) != ')' {
      if Int::unsafe_to_char(input[i].to_int()) == '(' {
        return false
      }
      i += 1
    }
    if i >= input.length() {
      return false
    }
    let args = svg_number_tokens(build_substring(input, args_start, i))
    for arg in args {
      if !valid_svg_number(arg, false) {
        return false
      }
    }
    let arity_ok = match name {
      "translate" | "scale" => args.length() == 1 || args.length() == 2
      "rotate" => args.length() == 1 || args.length() == 3
      "skewX" | "skewY" => args.length() == 1
      "matrix" => args.length() == 6
      _ => false
    }
    if !arity_ok {
      return false
    }
    functions += 1
    i += 1
  }
  functions > 0
}

///|
fn svg_property_value_is_valid(property : String, value : String) -> Bool {
  let trimmed = trim_string(value)
  if trimmed.to_lower().contains("var(") {
    return true
  }
  match property {
    "fill" | "stroke" => valid_svg_paint(trimmed)
    "color" | "stop-color" => !(@css_computed.parse_color(trimmed) is Invalid)
    "fill-rule" | "clip-rule" => trimmed == "nonzero" || trimmed == "evenodd"
    "fill-opacity" | "stroke-opacity" | "stop-opacity" | "opacity" =>
      valid_svg_number(trimmed, false)
    "stroke-width" =>
      valid_svg_number(trimmed, true) && parse_length(trimmed) >= 0.0
    "stroke-dashoffset" => valid_svg_number(trimmed, true)
    "stroke-miterlimit" =>
      valid_svg_number(trimmed, false) && parse_number(trimmed) >= 1.0
    "stroke-linecap" =>
      trimmed == "butt" || trimmed == "round" || trimmed == "square"
    "stroke-linejoin" =>
      trimmed == "miter" || trimmed == "round" || trimmed == "bevel"
    "stroke-dasharray" => valid_svg_dasharray(trimmed)
    "vector-effect" => trimmed == "none" || trimmed == "non-scaling-stroke"
    "image-rendering" =>
      match trimmed.to_lower() {
        "auto"
        | "optimizespeed"
        | "optimizequality"
        | "crisp-edges"
        | "pixelated" => true
        _ => false
      }
    "paint-order" => valid_svg_paint_order(trimmed)
    "marker-start" | "marker-mid" | "marker-end" | "marker" =>
      trimmed == "none" || parse_url_ref(trimmed) is Some(_)
    "x" | "y" | "cx" | "cy" | "x1" | "y1" | "x2" | "y2" =>
      valid_svg_number(trimmed, true)
    "width" | "height" | "rx" | "ry" | "r" =>
      valid_svg_number(trimmed, true) && parse_length(trimmed) >= 0.0
    "d" | "points" => trimmed.length() > 0
    "transform" => valid_svg_transform(trimmed)
    _ => true
  }
}

///|
fn svg_declaration_is_valid(
  property : String,
  value : @css_cascade.PropertyValue,
) -> Bool {
  match value {
    Value(value) => svg_property_value_is_valid(property, value)
    _ => true
  }
}

///|
fn ComputedStyleProperty::is_inherited(self : ComputedStyleProperty) -> Bool {
  match self {
    StyleOpacity | StyleVectorEffect => false
    _ => true
  }
}

///|
fn is_computed_style_property(name : String) -> Bool {
  computed_style_property(name) is Some(_)
}
