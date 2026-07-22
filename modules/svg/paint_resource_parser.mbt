///|
fn is_paint_server_context(parent_tag : String) -> Bool {
  parent_tag == "svg" || parent_tag == "defs" || parent_tag == "symbol"
}

///|
fn parse_pattern_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    return
  }
  parse_pattern_with_content(attrs, [], ctx)
}

///|
fn parse_pattern(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let temp = SVGNode::new(Group)
  apply_attributes(temp, attrs)
  let style = resolve_element_computed_style(
    temp,
    tag_name,
    attrs,
    ctx,
    ctx.current_style(),
    true,
  )
  parse_children(parser, temp, tag_name, attrs, ctx, style)
  parse_pattern_with_content(attrs, temp.children, ctx)
}

///|
fn parse_marker_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  _parent_tag : String,
) -> Unit {
  let node = SVGNode::new(Group)
  apply_attributes(node, attrs)
  let _ = resolve_element_computed_style(
    node,
    "marker",
    attrs,
    ctx,
    ctx.current_style(),
    true,
  )
  parse_marker_with_content(attrs, node, ctx)
}

///|
fn parse_marker(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  _parent_tag : String,
) -> Unit {
  let temp = SVGNode::new(Group)
  apply_attributes(temp, attrs)
  let style = resolve_element_computed_style(
    temp,
    tag_name,
    attrs,
    ctx,
    ctx.current_style(),
    true,
  )
  parse_children(parser, temp, tag_name, attrs, ctx, style)
  parse_marker_with_content(attrs, temp, ctx)
}

///|
fn parse_marker_with_content(
  attrs : Array[(String, String)],
  content : SVGNode,
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let mut ref_x = 0.0
  let mut ref_y = 0.0
  let mut marker_width = 3.0
  let mut marker_height = 3.0
  let mut marker_units = MarkerUnits::StrokeWidth
  let mut orient = MarkerOrient::Angle(0.0)
  let mut view_box : ViewBox? = None
  let mut preserve_aspect_ratio = PreserveAspectRatio::default()
  let mut overflow_visible = false
  if get_attr(attrs, "refX") is Some(v) {
    ref_x = parse_length(v)
  }
  if get_attr(attrs, "refY") is Some(v) {
    ref_y = parse_length(v)
  }
  if get_attr(attrs, "markerWidth") is Some(v) {
    marker_width = parse_length(v)
  }
  if get_attr(attrs, "markerHeight") is Some(v) {
    marker_height = parse_length(v)
  }
  if get_attr(attrs, "markerUnits") is Some(v) {
    marker_units = parse_marker_units(v)
  }
  if get_attr(attrs, "orient") is Some(v) {
    orient = parse_marker_orient(v)
  }
  if get_attr(attrs, "viewBox") is Some(v) {
    view_box = parse_view_box(v)
  }
  if get_attr(attrs, "preserveAspectRatio") is Some(v) {
    preserve_aspect_ratio = parse_preserve_aspect_ratio(v)
  }
  if get_attr(attrs, "overflow") is Some(v) {
    overflow_visible = trim_string(v) == "visible"
  }
  content.viewport_width = Some(marker_width)
  content.viewport_height = Some(marker_height)
  // Marker viewBox is handled by marker transform, not by content node.
  content.view_box = None
  content.preserve_aspect_ratio = PreserveAspectRatio::default()
  content.preserve_aspect_ratio_is_set = false
  // Marker viewport clipping is handled at render time.
  content.clip_overflow = false
  let clip_overflow = !overflow_visible
  let marker = {
    ..Marker::new(id, content),
    ref_x,
    ref_y,
    marker_width,
    marker_height,
    marker_units,
    orient,
    view_box,
    preserve_aspect_ratio,
    clip_overflow,
  }
  ctx.markers.add(marker)
}

///|
fn parse_marker_units(value : String) -> MarkerUnits {
  match trim_string(value) {
    "userSpaceOnUse" => MarkerUnits::UserSpaceOnUse_
    "strokeWidth" => MarkerUnits::StrokeWidth
    _ => MarkerUnits::StrokeWidth
  }
}

///|
fn parse_marker_orient(value : String) -> MarkerOrient {
  let v = trim_string(value)
  if v == "auto" {
    MarkerOrient::Auto
  } else if v == "auto-start-reverse" {
    MarkerOrient::AutoStartReverse
  } else {
    let angle = if string_ends_with(v, "deg") {
      parse_number(build_substring(v, 0, v.length() - 3))
    } else {
      parse_number(v)
    }
    MarkerOrient::Angle(angle)
  }
}

///|
fn parse_pattern_with_content(
  attrs : Array[(String, String)],
  content : Array[SVGNode],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let reference = match get_attr(attrs, "href") {
    Some(v) => parse_url_ref(v)
    None =>
      match get_attr(attrs, "xlink:href") {
        Some(v) => parse_url_ref(v)
        None => None
      }
  }
  let mut x = 0.0
  let mut y = 0.0
  let mut width = 0.0
  let mut height = 0.0
  if get_attr(attrs, "x") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    x = val
  }
  if get_attr(attrs, "y") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    y = val
  }
  if get_attr(attrs, "width") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    width = val
  }
  if get_attr(attrs, "height") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    height = val
  }
  let pattern_units = match get_attr(attrs, "patternUnits") {
    Some(v) => parse_pattern_units(v)
    None => ObjectBoundingBox
  }
  let pattern_content_units = match get_attr(attrs, "patternContentUnits") {
    Some(v) => parse_pattern_units(v)
    None => UserSpaceOnUse
  }
  let transform = match get_attr(attrs, "patternTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let view_box = match get_attr(attrs, "viewBox") {
    Some(v) => parse_view_box(v)
    None => None
  }
  let preserve_aspect_ratio = match get_attr(attrs, "preserveAspectRatio") {
    Some(v) => parse_preserve_aspect_ratio(v)
    None => PreserveAspectRatio::default()
  }
  let pattern = {
    ..Pattern::new(id, width, height, content),
    x,
    y,
    pattern_units,
    pattern_content_units,
    transform,
    view_box,
    preserve_aspect_ratio,
  }
  let mut specified = 0
  if get_attr(attrs, "x") is Some(_) {
    specified = specified | 1
  }
  if get_attr(attrs, "y") is Some(_) {
    specified = specified | 2
  }
  if get_attr(attrs, "width") is Some(_) {
    specified = specified | 4
  }
  if get_attr(attrs, "height") is Some(_) {
    specified = specified | 8
  }
  if get_attr(attrs, "patternUnits") is Some(_) {
    specified = specified | 16
  }
  if get_attr(attrs, "patternContentUnits") is Some(_) {
    specified = specified | 32
  }
  if get_attr(attrs, "patternTransform") is Some(_) {
    specified = specified | 64
  }
  if get_attr(attrs, "viewBox") is Some(_) {
    specified = specified | 128
  }
  if get_attr(attrs, "preserveAspectRatio") is Some(_) {
    specified = specified | 256
  }
  if !content.is_empty() {
    specified = specified | 512
  }
  ctx.patterns.add_definition(pattern, reference, specified)
}
