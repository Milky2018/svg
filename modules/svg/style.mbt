///|
priv struct StyleDeclaration {
  name : String
  value : String
}

///|
priv enum StyleChoice {
  StyleInitial
  StyleInherited
  StyleSpecified(String)
}

///|
fn is_custom_property(name : String) -> Bool {
  name.length() >= 3 && name[0] == '-' && name[1] == '-'
}

///|
fn find_winning_declaration(
  declarations : Array[StyleDeclaration],
  name : String,
) -> StyleDeclaration? {
  for declaration in declarations {
    if declaration.name == name {
      return Some(declaration)
    }
  }
  None
}

///|
fn declarations_are_same(
  left : StyleDeclaration,
  right : StyleDeclaration,
) -> Bool {
  left.name == right.name && left.value == right.value
}

///|
fn custom_property_get(
  properties : Array[(String, String)],
  name : String,
) -> String? {
  for i = properties.length() - 1; i >= 0; i = i - 1 {
    if properties[i].0 == name {
      return Some(properties[i].1)
    }
  }
  None
}

///|
fn custom_properties_as_pairs(
  properties : Map[String, String],
) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  for name, value in properties {
    pairs.push((name, value))
  }
  pairs
}

///|
fn find_var_function(value : String) -> Int {
  let lower = value.to_lower()
  for i in 0..<(lower.length() - 3) {
    if lower[i] == 'v' &&
      lower[i + 1] == 'a' &&
      lower[i + 2] == 'r' &&
      lower[i + 3] == '(' {
      return i
    }
  }
  -1
}

///|
fn find_matching_parenthesis(value : String, open : Int) -> Int {
  let mut depth = 0
  for i in open..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == '(' {
      depth += 1
    } else if c == ')' {
      depth -= 1
      if depth == 0 {
        return i
      }
    }
  }
  -1
}

///|
fn find_top_level_comma(value : String) -> Int {
  let mut depth = 0
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == '(' {
      depth += 1
    } else if c == ')' {
      depth -= 1
    } else if c == ',' && depth == 0 {
      return i
    }
  }
  -1
}

///|
fn resolve_css_variables(
  value : String,
  properties : Array[(String, String)],
  stack : Array[String],
  depth : Int,
) -> String? {
  if depth > 32 {
    return None
  }
  let start = find_var_function(value)
  if start < 0 {
    return Some(value)
  }
  let open = start + 3
  let close = find_matching_parenthesis(value, open)
  if close < 0 {
    return None
  }
  let inner = build_substring(value, open + 1, close)
  let comma = find_top_level_comma(inner)
  let name = trim_string(
    if comma < 0 {
      inner
    } else {
      build_substring(inner, 0, comma)
    },
  )
  if !is_custom_property(name) {
    return None
  }
  let fallback : String? = if comma < 0 {
    None
  } else {
    Some(trim_string(build_substring(inner, comma + 1, inner.length())))
  }
  let replacement = if stack.contains(name) {
    match fallback {
      Some(fallback_value) =>
        resolve_css_variables(fallback_value, properties, stack, depth + 1)
      None => None
    }
  } else {
    match custom_property_get(properties, name) {
      Some(custom_value) => {
        let next_stack = stack.copy()
        next_stack.push(name)
        match
          resolve_css_variables(custom_value, properties, next_stack, depth + 1) {
          Some(resolved) => Some(resolved)
          None =>
            match fallback {
              Some(fallback_value) =>
                resolve_css_variables(
                  fallback_value,
                  properties,
                  stack,
                  depth + 1,
                )
              None => None
            }
        }
      }
      None =>
        match fallback {
          Some(fallback_value) =>
            resolve_css_variables(fallback_value, properties, stack, depth + 1)
          None => None
        }
    }
  }
  match replacement {
    Some(resolved) => {
      let before = build_substring(value, 0, start)
      let after = build_substring(value, close + 1, value.length())
      resolve_css_variables(
        before + resolved + after,
        properties,
        stack,
        depth + 1,
      )
    }
    None => None
  }
}

///|
fn resolve_style_choice(
  declarations : Array[StyleDeclaration],
  properties : Array[(String, String)],
  property : ComputedStyleProperty,
) -> StyleChoice {
  let default_choice = if property.is_inherited() {
    StyleInherited
  } else {
    StyleInitial
  }
  match find_winning_declaration(declarations, property.name()) {
    Some(declaration) =>
      match resolve_css_variables(declaration.value, properties, [], 0) {
        Some(resolved) =>
          match trim_string(resolved).to_lower() {
            "inherit" => StyleInherited
            "initial" => StyleInitial
            "unset" => default_choice
            "revert" | "revert-layer" => default_choice
            _ => StyleSpecified(trim_string(resolved))
          }
        None => default_choice
      }
    None => default_choice
  }
}

///|
fn apply_resolved_noncomputed_attributes(
  node : SVGNode,
  attrs : Array[(String, String)],
  declarations : Array[StyleDeclaration],
  properties : Array[(String, String)],
) -> Unit {
  for attr in attrs {
    let name = attr.0
    if name != "style" && !is_computed_style_property(name.to_lower()) {
      match resolve_css_variables(attr.1, properties, [], 0) {
        Some(value) => apply_presentation_attribute(node, name, value)
        None => ()
      }
    }
  }
  for declaration in declarations {
    if !is_custom_property(declaration.name) &&
      !is_computed_style_property(declaration.name) {
      match find_winning_declaration(declarations, declaration.name) {
        Some(winner) if declarations_are_same(winner, declaration) =>
          match resolve_css_variables(winner.value, properties, [], 0) {
            Some(value) => apply_attribute(node, winner.name, value)
            None => ()
          }
        _ => ()
      }
    }
  }
}

///|
fn resolve_computed_style(
  node : SVGNode,
  attrs : Array[(String, String)],
  cascaded : @css_cascade.CascadedValues,
  parent : InheritedStyle,
  apply_noncomputed : Bool,
) -> InheritedStyle {
  let (css_style, custom_property_map) = @css.compute_style_with_vars(
    cascaded,
    @css_computed.ComputeContext::with_parent_and_vars(
      parent.css_style,
      parent.custom_properties,
    ),
  )
  let declarations = cascaded_style_declarations(cascaded)
  let custom_properties = custom_properties_as_pairs(custom_property_map)
  node.fill = parent.fill
  node.fill_rule = parent.fill_rule
  node.fill_opacity = parent.fill_opacity
  node.stroke = parent.stroke
  node.stroke_opacity = parent.stroke_opacity
  node.color = Some(parent.color)
  node.paint_order = parent.paint_order
  node.opacity = css_style.opacity
  node.marker_start = parent.marker_start
  node.marker_mid = parent.marker_mid
  node.marker_end = parent.marker_end
  node.image_sampling = parent.image_sampling
  let mut stop_color = parent.stop_color
  let mut stop_opacity = parent.stop_opacity
  if apply_noncomputed {
    apply_resolved_noncomputed_attributes(
      node, attrs, declarations, custom_properties,
    )
  }
  match resolve_style_choice(declarations, custom_properties, StyleFill) {
    StyleInitial => node.fill = SolidColor(Color::black())
    StyleInherited => ()
    StyleSpecified(value) => node.fill = parse_paint(value)
  }
  match resolve_style_choice(declarations, custom_properties, StyleFillRule) {
    StyleInitial => node.fill_rule = NonZero
    StyleInherited => ()
    StyleSpecified(value) => node.fill_rule = parse_fill_rule(value)
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleFillOpacity) {
    StyleInitial => node.fill_opacity = 1.0
    StyleInherited => ()
    StyleSpecified(value) => node.fill_opacity = parse_number(value)
  }
  match resolve_style_choice(declarations, custom_properties, StyleStroke) {
    StyleInitial => node.stroke = { ..node.stroke, paint: None }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, paint: parse_paint(value) }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeWidth) {
    StyleInitial => node.stroke = { ..node.stroke, width: 1.0 }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, width: parse_length(value) }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeLinecap) {
    StyleInitial => node.stroke = { ..node.stroke, linecap: Butt }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, linecap: parse_linecap(value) }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeLinejoin) {
    StyleInitial => node.stroke = { ..node.stroke, linejoin: Miter }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, linejoin: parse_linejoin(value) }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeMiterlimit) {
    StyleInitial => node.stroke = { ..node.stroke, miterlimit: 4.0 }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, miterlimit: parse_number(value) }
  }
  match resolve_style_choice(declarations, custom_properties, StyleColor) {
    StyleInitial => node.color = Some(Color::black())
    StyleInherited => ()
    StyleSpecified(value) =>
      if value.to_lower() == "currentcolor" {
        node.color = Some(parent.color)
      } else {
        node.color = Some(parse_color(value))
      }
  }
  match resolve_style_choice(declarations, custom_properties, StyleStopColor) {
    StyleInitial => stop_color = Color::black()
    StyleInherited => ()
    StyleSpecified(value) =>
      if value.to_lower() == "currentcolor" {
        stop_color = node.color.unwrap_or(Color::black())
      } else {
        stop_color = parse_color(value)
      }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStopOpacity) {
    StyleInitial => stop_opacity = 1.0
    StyleInherited => ()
    StyleSpecified(value) => stop_opacity = parse_number(value)
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeDasharray) {
    StyleInitial => node.stroke = { ..node.stroke, dasharray: None }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, dasharray: parse_dasharray(value) }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeDashoffset) {
    StyleInitial => node.stroke = { ..node.stroke, dashoffset: 0.0 }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, dashoffset: parse_number(value) }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleStrokeOpacity) {
    StyleInitial => node.stroke_opacity = 1.0
    StyleInherited => ()
    StyleSpecified(value) => node.stroke_opacity = parse_number(value)
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleVectorEffect) {
    StyleInitial => node.stroke = { ..node.stroke, non_scaling: false }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = {
        ..node.stroke,
        non_scaling: trim_string(value).to_lower() == "non-scaling-stroke",
      }
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleImageRendering) {
    StyleInitial => node.image_sampling = Bilinear
    StyleInherited => ()
    StyleSpecified(value) => node.image_sampling = parse_image_sampling(value)
  }
  match resolve_style_choice(declarations, custom_properties, StylePaintOrder) {
    StyleInitial => node.paint_order = PaintOrder::default()
    StyleInherited => ()
    StyleSpecified(value) => node.paint_order = parse_paint_order(value)
  }
  match
    resolve_style_choice(declarations, custom_properties, StyleMarkerStart) {
    StyleInitial => node.marker_start = None
    StyleInherited => ()
    StyleSpecified(value) => node.marker_start = parse_marker_ref(value)
  }
  match resolve_style_choice(declarations, custom_properties, StyleMarkerMid) {
    StyleInitial => node.marker_mid = None
    StyleInherited => ()
    StyleSpecified(value) => node.marker_mid = parse_marker_ref(value)
  }
  match resolve_style_choice(declarations, custom_properties, StyleMarkerEnd) {
    StyleInitial => node.marker_end = None
    StyleInherited => ()
    StyleSpecified(value) => node.marker_end = parse_marker_ref(value)
  }
  node.fill_is_set = true
  node.stroke_paint_is_set = true
  node.stroke_width_is_set = true
  node.color_is_set = true
  node.marker_start_is_set = true
  node.marker_mid_is_set = true
  node.marker_end_is_set = true
  inherited_style_from_node(
    node, css_style, custom_property_map, stop_color, stop_opacity,
  )
}
