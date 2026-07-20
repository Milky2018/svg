///|
priv struct StyleDeclaration {
  name : String
  value : String
  important : Bool
  inline_style : Bool
  order : Int
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
fn is_computed_style_property(name : String) -> Bool {
  match name {
    "fill" |
    "fill-rule" |
    "fill-opacity" |
    "stroke" |
    "stroke-width" |
    "stroke-linecap" |
    "stroke-linejoin" |
    "stroke-miterlimit" |
    "stroke-dasharray" |
    "stroke-dashoffset" |
    "stroke-opacity" |
    "color" |
    "paint-order" |
    "opacity" |
    "marker-start" |
    "marker-mid" |
    "marker-end" => true
    _ => false
  }
}

///|
fn strip_inline_important(value : String) -> (String, Bool) {
  let trimmed = trim_string(value)
  let lower = trimmed.to_lower()
  let suffix = "!important"
  if string_ends_with(lower, suffix) {
    let end = trimmed.length() - suffix.length()
    (trim_string(build_substring(trimmed, 0, end)), true)
  } else {
    (trimmed, false)
  }
}

///|
fn parse_inline_style_declarations(value : String) -> Array[StyleDeclaration] {
  let result : Array[StyleDeclaration] = []
  let pairs = parse_style_pairs(value)
  for i in 0..<pairs.length() {
    let raw_name = trim_string(pairs[i].0)
    let name = if is_custom_property(raw_name) {
      raw_name
    } else {
      raw_name.to_lower()
    }
    let (declaration_value, important) = strip_inline_important(pairs[i].1)
    result.push({
      name,
      value: declaration_value,
      important,
      inline_style: true,
      order: i,
    })
  }
  result
}

///|
fn declaration_is_better(
  candidate : StyleDeclaration,
  current : StyleDeclaration,
) -> Bool {
  if candidate.important != current.important {
    candidate.important
  } else if candidate.inline_style != current.inline_style {
    candidate.inline_style
  } else {
    candidate.order >= current.order
  }
}

///|
fn find_winning_declaration(
  declarations : Array[StyleDeclaration],
  name : String,
) -> StyleDeclaration? {
  let mut winner : StyleDeclaration? = None
  for declaration in declarations {
    if declaration.name == name {
      match winner {
        Some(current) =>
          if declaration_is_better(declaration, current) {
            winner = Some(declaration)
          }
        None => winner = Some(declaration)
      }
    }
  }
  winner
}

///|
fn collect_style_declarations(
  attrs : Array[(String, String)],
) -> Array[StyleDeclaration] {
  let declarations : Array[StyleDeclaration] = []
  let mut order = 0
  for attr in attrs {
    if attr.0 == "style" {
      for declaration in parse_inline_style_declarations(attr.1) {
        declarations.push({ ..declaration, order })
        order += 1
      }
    } else {
      let name = attr.0
      if name == name.to_lower() && is_computed_style_property(name) {
        declarations.push({
          name,
          value: trim_string(attr.1),
          important: false,
          inline_style: false,
          order,
        })
        order += 1
      }
    }
  }
  declarations
}

///|
fn inline_style_value(value : String, name : String) -> String? {
  let declarations = parse_inline_style_declarations(value)
  match find_winning_declaration(declarations, name) {
    Some(declaration) => Some(declaration.value)
    None => None
  }
}

///|
fn style_property_is_declared(
  attrs : Array[(String, String)],
  name : String,
) -> Bool {
  find_winning_declaration(collect_style_declarations(attrs), name) is Some(_)
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
fn custom_property_set(
  properties : Array[(String, String)],
  name : String,
  value : String,
) -> Unit {
  for i in 0..<properties.length() {
    if properties[i].0 == name {
      properties[i] = (name, value)
      return
    }
  }
  properties.push((name, value))
}

///|
fn custom_property_remove(
  properties : Array[(String, String)],
  name : String,
) -> Unit {
  let mut i = properties.length() - 1
  while i >= 0 {
    if properties[i].0 == name {
      let _ = properties.remove(i)
    }
    i -= 1
  }
}

///|
fn compute_custom_properties(
  parent : Array[(String, String)],
  declarations : Array[StyleDeclaration],
) -> Array[(String, String)] {
  let properties = parent.copy()
  for declaration in declarations {
    if is_custom_property(declaration.name) {
      match find_winning_declaration(declarations, declaration.name) {
        Some(winner) if winner.order == declaration.order => {
          let keyword = winner.value.to_lower()
          if keyword == "initial" {
            custom_property_remove(properties, winner.name)
          } else if keyword == "inherit" ||
            keyword == "unset" ||
            keyword == "revert" ||
            keyword == "revert-layer" {
            ()
          } else {
            custom_property_set(properties, winner.name, winner.value)
          }
        }
        _ => ()
      }
    }
  }
  properties
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
    if comma < 0 { inner } else { build_substring(inner, 0, comma) },
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
        match resolve_css_variables(
          custom_value,
          properties,
          next_stack,
          depth + 1,
        ) {
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
  name : String,
  inherited : Bool,
) -> StyleChoice {
  let default_choice = if inherited { StyleInherited } else { StyleInitial }
  match find_winning_declaration(declarations, name) {
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
  for attr in attrs {
    if attr.0 == "style" {
      let declarations = parse_inline_style_declarations(attr.1)
      for declaration in declarations {
        if !is_custom_property(declaration.name) &&
          !is_computed_style_property(declaration.name) {
          match find_winning_declaration(declarations, declaration.name) {
            Some(winner) if winner.order == declaration.order =>
              match resolve_css_variables(
                winner.value,
                properties,
                [],
                0,
              ) {
                Some(value) => apply_attribute(node, winner.name, value)
                None => ()
              }
            _ => ()
          }
        }
      }
    }
  }
}

///|
fn resolve_computed_style(
  node : SVGNode,
  attrs : Array[(String, String)],
  parent : InheritedStyle,
  apply_noncomputed : Bool,
) -> InheritedStyle {
  let declarations = collect_style_declarations(attrs)
  let custom_properties = compute_custom_properties(
    parent.custom_properties,
    declarations,
  )
  node.fill = parent.fill
  node.fill_rule = parent.fill_rule
  node.fill_opacity = parent.fill_opacity
  node.stroke = parent.stroke
  node.stroke_opacity = parent.stroke_opacity
  node.color = Some(parent.color)
  node.paint_order = parent.paint_order
  node.opacity = 1.0
  node.marker_start = parent.marker_start
  node.marker_mid = parent.marker_mid
  node.marker_end = parent.marker_end
  if apply_noncomputed {
    apply_resolved_noncomputed_attributes(node, attrs, custom_properties)
  }
  match resolve_style_choice(declarations, custom_properties, "fill", true) {
    StyleInitial => node.fill = SolidColor(Color::black())
    StyleInherited => ()
    StyleSpecified(value) => node.fill = parse_paint(value)
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "fill-rule",
    true,
  ) {
    StyleInitial => node.fill_rule = NonZero
    StyleInherited => ()
    StyleSpecified(value) => node.fill_rule = parse_fill_rule(value)
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "fill-opacity",
    true,
  ) {
    StyleInitial => node.fill_opacity = 1.0
    StyleInherited => ()
    StyleSpecified(value) => node.fill_opacity = parse_number(value)
  }
  match resolve_style_choice(declarations, custom_properties, "stroke", true) {
    StyleInitial => node.stroke = { ..node.stroke, paint: None }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, paint: parse_paint(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-width",
    true,
  ) {
    StyleInitial => node.stroke = { ..node.stroke, width: 1.0 }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, width: parse_length(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-linecap",
    true,
  ) {
    StyleInitial => node.stroke = { ..node.stroke, linecap: Butt }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, linecap: parse_linecap(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-linejoin",
    true,
  ) {
    StyleInitial => node.stroke = { ..node.stroke, linejoin: Miter }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, linejoin: parse_linejoin(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-miterlimit",
    true,
  ) {
    StyleInitial => node.stroke = { ..node.stroke, miterlimit: 4.0 }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, miterlimit: parse_number(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-dasharray",
    true,
  ) {
    StyleInitial => node.stroke = { ..node.stroke, dasharray: None }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, dasharray: parse_dasharray(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-dashoffset",
    true,
  ) {
    StyleInitial => node.stroke = { ..node.stroke, dashoffset: 0.0 }
    StyleInherited => ()
    StyleSpecified(value) =>
      node.stroke = { ..node.stroke, dashoffset: parse_number(value) }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "stroke-opacity",
    true,
  ) {
    StyleInitial => node.stroke_opacity = 1.0
    StyleInherited => ()
    StyleSpecified(value) => node.stroke_opacity = parse_number(value)
  }
  match resolve_style_choice(declarations, custom_properties, "color", true) {
    StyleInitial => node.color = Some(Color::black())
    StyleInherited => ()
    StyleSpecified(value) =>
      if value.to_lower() == "currentcolor" {
        node.color = Some(parent.color)
      } else {
        node.color = Some(parse_color(value))
      }
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "paint-order",
    true,
  ) {
    StyleInitial => node.paint_order = PaintOrder::default()
    StyleInherited => ()
    StyleSpecified(value) => node.paint_order = parse_paint_order(value)
  }
  match resolve_style_choice(declarations, custom_properties, "opacity", false) {
    StyleInitial => node.opacity = 1.0
    StyleInherited => node.opacity = parent.opacity
    StyleSpecified(value) => node.opacity = parse_number(value)
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "marker-start",
    true,
  ) {
    StyleInitial => node.marker_start = None
    StyleInherited => ()
    StyleSpecified(value) => node.marker_start = parse_marker_ref(value)
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "marker-mid",
    true,
  ) {
    StyleInitial => node.marker_mid = None
    StyleInherited => ()
    StyleSpecified(value) => node.marker_mid = parse_marker_ref(value)
  }
  match resolve_style_choice(
    declarations,
    custom_properties,
    "marker-end",
    true,
  ) {
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
  inherited_style_from_node(node, custom_properties)
}
