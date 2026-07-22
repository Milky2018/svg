///|
fn parse_pattern_units(value : String) -> PatternUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_gradient_units(value : String) -> GradientUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_linear_gradient_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    return
  }
  parse_linear_gradient_with_stops(attrs, [], ctx)
}

///|
fn parse_linear_gradient(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
  gradient_style : InheritedStyle,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let stops = parse_gradient_stops(parser, tag_name, attrs, ctx, gradient_style)
  parse_linear_gradient_with_stops(attrs, stops, ctx)
}

///|
fn parse_linear_gradient_with_stops(
  attrs : Array[(String, String)],
  stops : Array[GradientStop],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let reference = match get_href_attr(attrs) {
    Some(v) => parse_url_ref(v)
    None => None
  }
  let x1 = parse_gradient_coord(get_attr(attrs, "x1"), 0.0)
  let y1 = parse_gradient_coord(get_attr(attrs, "y1"), 0.0)
  let x2 = parse_gradient_coord(get_attr(attrs, "x2"), 1.0)
  let y2 = parse_gradient_coord(get_attr(attrs, "y2"), 0.0)
  let spread_method = match get_attr(attrs, "spreadMethod") {
    Some(v) => parse_spread_method(v)
    None => Pad
  }
  let units = match get_attr(attrs, "gradientUnits") {
    Some(v) => parse_gradient_units(v)
    None => ObjectBoundingBox
  }
  let transform = match get_attr(attrs, "gradientTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let grad = {
    ..LinearGradient::new(x1, y1, x2, y2, stops),
    spread_method,
    units,
    transform,
  }
  let mut specified = 0
  if get_attr(attrs, "x1") is Some(_) {
    specified = specified | 1
  }
  if get_attr(attrs, "y1") is Some(_) {
    specified = specified | 2
  }
  if get_attr(attrs, "x2") is Some(_) {
    specified = specified | 4
  }
  if get_attr(attrs, "y2") is Some(_) {
    specified = specified | 8
  }
  if get_attr(attrs, "spreadMethod") is Some(_) {
    specified = specified | 16
  }
  if get_attr(attrs, "gradientUnits") is Some(_) {
    specified = specified | 32
  }
  if get_attr(attrs, "gradientTransform") is Some(_) {
    specified = specified | 64
  }
  if !stops.is_empty() {
    specified = specified | 128
  }
  ctx.gradients.add_definition(id, Linear(grad), reference, specified)
}

///|
fn parse_radial_gradient_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    return
  }
  parse_radial_gradient_with_stops(attrs, [], ctx)
}

///|
fn parse_radial_gradient(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
  gradient_style : InheritedStyle,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let stops = parse_gradient_stops(parser, tag_name, attrs, ctx, gradient_style)
  parse_radial_gradient_with_stops(attrs, stops, ctx)
}

///|
fn parse_radial_gradient_with_stops(
  attrs : Array[(String, String)],
  stops : Array[GradientStop],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let reference = match get_href_attr(attrs) {
    Some(v) => parse_url_ref(v)
    None => None
  }
  let cx = parse_gradient_coord(get_attr(attrs, "cx"), 0.5)
  let cy = parse_gradient_coord(get_attr(attrs, "cy"), 0.5)
  let r = parse_gradient_coord(get_attr(attrs, "r"), 0.5)
  let fx = match get_attr(attrs, "fx") {
    Some(v) => parse_gradient_coord(Some(v), cx)
    None => cx
  }
  let fy = match get_attr(attrs, "fy") {
    Some(v) => parse_gradient_coord(Some(v), cy)
    None => cy
  }
  let spread_method = match get_attr(attrs, "spreadMethod") {
    Some(v) => parse_spread_method(v)
    None => Pad
  }
  let units = match get_attr(attrs, "gradientUnits") {
    Some(v) => parse_gradient_units(v)
    None => ObjectBoundingBox
  }
  let transform = match get_attr(attrs, "gradientTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let grad = {
    ..RadialGradient::new(cx, cy, r, stops),
    fx,
    fy,
    spread_method,
    units,
    transform,
  }
  let mut specified = 0
  if get_attr(attrs, "cx") is Some(_) {
    specified = specified | 1
  }
  if get_attr(attrs, "cy") is Some(_) {
    specified = specified | 2
  }
  if get_attr(attrs, "r") is Some(_) {
    specified = specified | 4
  }
  if get_attr(attrs, "fx") is Some(_) {
    specified = specified | 8
  }
  if get_attr(attrs, "fy") is Some(_) {
    specified = specified | 16
  }
  if get_attr(attrs, "spreadMethod") is Some(_) {
    specified = specified | 32
  }
  if get_attr(attrs, "gradientUnits") is Some(_) {
    specified = specified | 64
  }
  if get_attr(attrs, "gradientTransform") is Some(_) {
    specified = specified | 128
  }
  if !stops.is_empty() {
    specified = specified | 256
  }
  ctx.gradients.add_definition(id, Radial(grad), reference, specified)
}

///|
fn parse_gradient_coord(value : String?, default : Double) -> Double {
  match value {
    Some(v) => {
      let (val, _) = parse_length_or_percent(v)
      val
    }
    None => default
  }
}

///|
fn parse_spread_method(value : String) -> SpreadMethod {
  match trim_string(value) {
    "repeat" => Repeat
    "reflect" => Reflect
    _ => Pad
  }
}

///|
fn parse_gradient_stops(
  parser : SVGParser,
  parent_tag : String,
  parent_attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_style : InheritedStyle,
) -> Array[GradientStop] {
  let stops : Array[GradientStop] = []
  let depth = ctx.element_stack.length()
  let parent_element = if depth < ctx.selector_element_slots.length() {
    match ctx.selector_element_slots[depth] {
      Some(element) => element
      None => ctx.record_selector_element(parent_tag, parent_attrs)
    }
  } else {
    ctx.record_selector_element(parent_tag, parent_attrs)
  }
  ctx.element_stack.push(parent_element)
  ctx.style_stack.push(parent_style)
  ctx.sibling_index_stack.push(0)
  ctx.sibling_count_stack.push(count_direct_child_elements(parser, parent_tag))
  ctx.previous_sibling_stack.push(None)
  while !parser.is_end() {
    let (element, has_children) = match parser.advance_event() {
      Start(element) => (Some(element), true)
      Empty(element) => (Some(element), false)
      End(name) => {
        if name == parent_tag {
          break
        }
        (None, false)
      }
      Eof => break
      _ => (None, false)
    }
    match element {
      Some(element) => {
        let tag_name = element.name
        let attrs = element.attributes
        let current_index = ctx.sibling_index_stack.length() - 1
        ctx.sibling_index_stack[current_index] += 1
        let _ = ctx.record_selector_element(tag_name, attrs)
        if tag_name == "stop" {
          let temp = SVGNode::new(Group)
          let stop_cascaded = ctx.cascaded_style(tag_name, attrs)
          let stop_style = resolve_computed_style(
            temp,
            attrs,
            stop_cascaded,
            ctx.current_style(),
            false,
          )
          stops.push(parse_gradient_stop(attrs, stop_style))
        }
        let child_depth = ctx.element_stack.length()
        if child_depth < ctx.selector_element_slots.length() {
          ctx.previous_sibling_stack[current_index] = ctx.selector_element_slots[child_depth]
        }
        if has_children {
          skip_to_end_tag(parser, tag_name)
        }
      }
      None => ()
    }
  }
  let _ = ctx.previous_sibling_stack.pop()
  let _ = ctx.sibling_count_stack.pop()
  let _ = ctx.sibling_index_stack.pop()
  let _ = ctx.style_stack.pop()
  let _ = ctx.element_stack.pop()
  stops
}

///|
fn parse_gradient_stop(
  attrs : Array[(String, String)],
  style : InheritedStyle,
) -> GradientStop {
  let offset = match get_attr(attrs, "offset") {
    Some(v) => parse_gradient_offset(v)
    None => 0.0
  }
  let color = style.stop_color
  let mut opacity = style.stop_opacity
  if opacity < 0.0 {
    opacity = 0.0
  }
  if opacity > 1.0 {
    opacity = 1.0
  }
  let final_color = if opacity < 1.0 {
    Color::rgba(
      color.r,
      color.g,
      color.b,
      (color.a.to_double() * opacity).round().to_int(),
    )
  } else {
    color
  }
  { offset, color: final_color }
}

///|
fn parse_gradient_offset(value : String) -> Double {
  let v = trim_string(value)
  let t = if string_ends_with(v, "%") {
    let cleaned = build_substring(v, 0, v.length() - 1)
    parse_number(cleaned) / 100.0
  } else {
    parse_number(v)
  }
  if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
}
