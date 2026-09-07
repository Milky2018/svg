///|
fn create_node_for_tag(tag_name : String) -> SVGNode {
  let node = match tag_name {
    "rect" =>
      SVGNode::new(Rect(x=0.0, y=0.0, width=0.0, height=0.0, rx=0.0, ry=0.0))
    "circle" => SVGNode::new(Circle(cx=0.0, cy=0.0, r=0.0))
    "ellipse" => SVGNode::new(Ellipse(cx=0.0, cy=0.0, rx=0.0, ry=0.0))
    "line" => SVGNode::new(Line(x1=0.0, y1=0.0, x2=0.0, y2=0.0))
    "polyline" => SVGNode::new(Polyline(points=[]))
    "polygon" => SVGNode::new(Polygon(points=[]))
    "path" => SVGNode::new(Path(commands=[]))
    _ => SVGNode::new(Group) // svg, g, defs, etc. are groups
  }
  node
}

///|
fn apply_attributes(node : SVGNode, attrs : Array[(String, String)]) -> Unit {
  for attr in attrs {
    if attr.0 != "style" {
      apply_presentation_attribute(node, attr.0, attr.1)
    }
  }
  for attr in attrs {
    if attr.0 == "style" {
      apply_style_attributes(node, attr.1)
    }
  }
  match node.shape {
    Rect(..) as rect => {
      let has_rx = get_attr(attrs, "rx") is Some(_)
      let has_ry = get_attr(attrs, "ry") is Some(_)
      if has_rx && !has_ry {
        node.shape = Rect(
          x=rect.x,
          y=rect.y,
          width=rect.width,
          height=rect.height,
          rx=rect.rx,
          ry=rect.rx,
        )
      } else if has_ry && !has_rx {
        node.shape = Rect(
          x=rect.x,
          y=rect.y,
          width=rect.width,
          height=rect.height,
          rx=rect.ry,
          ry=rect.ry,
        )
      }
    }
    _ => ()
  }
}

///|
fn apply_attribute(
  node : SVGNode,
  name : String,
  value : String,
  length_context? : LengthContext,
) -> Unit {
  fn length(axis : LengthAxis) -> Double {
    match length_context {
      Some(context) => parse_length_with_context(value, axis, context)
      None => parse_length(value)
    }
  }
  match name {
    "id" => node.id = value
    "style" => apply_style_attributes(node, value)
    "viewBox" => node.view_box = parse_view_box(value)
    "preserveAspectRatio" => {
      node.preserve_aspect_ratio = parse_preserve_aspect_ratio(value)
      node.preserve_aspect_ratio_is_set = true
    }
    "clip-path" =>
      if parse_url_ref(value) is Some(id) {
        node.set_clip_path(id)
      }
    "mask" => if parse_url_ref(value) is Some(id) { node.set_mask(id) }
    "requiredExtensions" => node.opacity = 0.0
    "x" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=length(Horizontal),
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=length(Horizontal),
            y=i.y,
            width=i.width,
            height=i.height,
            href=i.href,
          )
        _ => ()
      }
    "y" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=length(Vertical),
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=length(Vertical),
            width=i.width,
            height=i.height,
            href=i.href,
          )
        _ => ()
      }
    "width" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=length(Horizontal),
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=i.y,
            width=length(Horizontal),
            height=i.height,
            href=i.href,
          )
        _ => ()
      }
    "height" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=length(Vertical),
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=i.y,
            width=i.width,
            height=length(Vertical),
            href=i.href,
          )
        _ => ()
      }
    "rx" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=length(Horizontal),
            ry=r.ry,
          )
        Ellipse(..) as e =>
          node.shape = Ellipse(cx=e.cx, cy=e.cy, rx=length(Horizontal), ry=e.ry)
        _ => ()
      }
    "ry" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=length(Vertical),
          )
        Ellipse(..) as e =>
          node.shape = Ellipse(cx=e.cx, cy=e.cy, rx=e.rx, ry=length(Vertical))
        _ => ()
      }
    "cx" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=length(Horizontal), cy=c.cy, r=c.r)
        Ellipse(..) as e =>
          node.shape = Ellipse(cx=length(Horizontal), cy=e.cy, rx=e.rx, ry=e.ry)
        _ => ()
      }
    "cy" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=c.cx, cy=length(Vertical), r=c.r)
        Ellipse(..) as e =>
          node.shape = Ellipse(cx=e.cx, cy=length(Vertical), rx=e.rx, ry=e.ry)
        _ => ()
      }
    "r" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=c.cx, cy=c.cy, r=length(Diagonal))
        _ => ()
      }
    "x1" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=length(Horizontal), y1=l.y1, x2=l.x2, y2=l.y2)
        _ => ()
      }
    "y1" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=length(Vertical), x2=l.x2, y2=l.y2)
        _ => ()
      }
    "x2" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=l.y1, x2=length(Horizontal), y2=l.y2)
        _ => ()
      }
    "y2" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=l.y1, x2=l.x2, y2=length(Vertical))
        _ => ()
      }
    "d" =>
      match node.shape {
        Path(..) => node.shape = Path(commands=parse_path(value))
        _ => ()
      }
    "points" =>
      match node.shape {
        Polyline(..) => node.shape = Polyline(points=parse_points(value))
        Polygon(..) => node.shape = Polygon(points=parse_points(value))
        _ => ()
      }
    "fill" => {
      node.fill = parse_paint(value)
      node.fill_is_set = true
    }
    "color" => {
      node.color = Some(parse_color(value))
      node.color_is_set = true
    }
    "paint-order" => node.paint_order = parse_paint_order(value)
    "image-rendering" => node.image_sampling = parse_image_sampling(value)
    "stroke" => {
      node.stroke = {
        paint: parse_paint(value),
        width: node.stroke.width,
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
        non_scaling: node.stroke.non_scaling,
      }
      node.stroke_paint_is_set = true
    }
    "stroke-width" => {
      node.stroke_width_is_set = true
      node.stroke = {
        paint: node.stroke.paint,
        width: length(Diagonal),
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
        non_scaling: node.stroke.non_scaling,
      }
    }
    "opacity" => node.opacity = parse_number(value)
    "fill-opacity" => node.fill_opacity = parse_number(value)
    "stroke-opacity" => node.stroke_opacity = parse_number(value)
    "filter" => node.filter_graph_id = parse_url_ref(value)
    "mix-blend-mode" => node.blend_mode = parse_blend_mode(value)
    "isolation" => node.isolation = parse_isolation(value)
    "transform" => node.transform = parse_transform(value)
    // Stroke detail attributes
    "stroke-linecap" =>
      node.stroke = { ..node.stroke, linecap: parse_linecap(value), }
    "stroke-linejoin" =>
      node.stroke = { ..node.stroke, linejoin: parse_linejoin(value), }
    "stroke-miterlimit" =>
      node.stroke = { ..node.stroke, miterlimit: parse_number(value), }
    "stroke-dasharray" =>
      node.stroke = {
        ..node.stroke,
        dasharray: match length_context {
          Some(context) => parse_dasharray(value, length_context=context)
          None => parse_dasharray(value)
        },
      }
    "stroke-dashoffset" =>
      node.stroke = { ..node.stroke, dashoffset: length(Diagonal), }
    "vector-effect" =>
      node.stroke = {
        ..node.stroke,
        non_scaling: trim_string(value).to_lower() == "non-scaling-stroke",
      }
    "marker-start" => {
      node.marker_start = parse_marker_ref(value)
      node.marker_start_is_set = true
    }
    "marker-mid" => {
      node.marker_mid = parse_marker_ref(value)
      node.marker_mid_is_set = true
    }
    "marker-end" => {
      node.marker_end = parse_marker_ref(value)
      node.marker_end_is_set = true
    }
    "marker" =>
      match parse_marker_ref(value) {
        Some(id) => {
          node.marker_start = Some(id)
          node.marker_mid = Some(id)
          node.marker_end = Some(id)
          node.marker_start_is_set = true
          node.marker_mid_is_set = true
          node.marker_end_is_set = true
        }
        None => {
          node.marker_start = None
          node.marker_mid = None
          node.marker_end = None
          node.marker_start_is_set = true
          node.marker_mid_is_set = true
          node.marker_end_is_set = true
        }
      }
    // Fill rule
    "fill-rule" => node.fill_rule = parse_fill_rule(value)
    "clip-rule" => node.clip_rule = parse_fill_rule(value)
    _ => () // Ignore unknown attributes
  }
}

///|
fn parse_blend_mode(value : String) -> BlendMode {
  match trim_string(value).to_lower() {
    "multiply" => Multiply
    "screen" => Screen
    "overlay" => Overlay
    "darken" => Darken
    "lighten" => Lighten
    "color-dodge" => ColorDodge
    "color-burn" => ColorBurn
    "hard-light" => HardLight
    "soft-light" => SoftLight
    "difference" => Difference
    "exclusion" => Exclusion
    "hue" => Hue
    "saturation" => Saturation
    "color" => ColorMode
    "luminosity" => Luminosity
    _ => Normal
  }
}

///|
fn parse_isolation(value : String) -> Isolation {
  if trim_string(value).to_lower() == "isolate" {
    Isolate
  } else {
    Auto
  }
}

///|
fn apply_presentation_attribute(
  node : SVGNode,
  name : String,
  value : String,
) -> Unit {
  if name == "marker" {
    return
  }
  apply_attribute(node, name, value)
}

///|
fn parse_marker_ref(value : String) -> String? {
  let v = trim_string(value)
  if v.length() == 0 || v == "none" {
    return None
  }
  parse_url_ref(v)
}

///|
fn apply_style_attributes(node : SVGNode, value : String) -> Unit {
  let declarations = parse_inline_style_declarations(value)
  for declaration in declarations {
    let name = declaration.name
    let winner = find_winning_declaration(declarations, name)
    if name == "style" || is_custom_property(name) {
      continue
    }
    match winner {
      Some(_) => apply_attribute(node, name, declaration.value)
      _ => ()
    }
  }
}

///|
fn apply_style_attributes_filtered(node : SVGNode, value : String) -> Unit {
  let declarations = parse_inline_style_declarations(value)
  for declaration in declarations {
    let name = declaration.name
    let winner = find_winning_declaration(declarations, name)
    if name == "style" ||
      is_custom_property(name) ||
      name == "transform" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" {
      continue
    }
    match winner {
      Some(_) => apply_attribute(node, name, declaration.value)
      _ => ()
    }
  }
}

///|
fn apply_presentation_attributes(
  node : SVGNode,
  attrs : Array[(String, String)],
) -> Unit {
  for attr in attrs {
    let name = attr.0
    if name == "id" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href" ||
      name == xlink_href_attribute_name ||
      name == "transform" ||
      name == "style" {
      continue
    }
    apply_presentation_attribute(node, name, attr.1)
  }
  for attr in attrs {
    if attr.0 == "style" {
      apply_style_attributes_filtered(node, attr.1)
    }
  }
}

///|
fn apply_paint_order_recursive(node : SVGNode, order : PaintOrder) -> Unit {
  node.paint_order = order
  for child in node.children {
    apply_paint_order_recursive(child, order)
  }
}

///|
fn get_attr(attrs : Array[(String, String)], name : String) -> String? {
  for attr in attrs {
    if attr.0 == name {
      return Some(attr.1)
    }
  }
  None
}

///|
fn get_href_attr(attrs : Array[(String, String)]) -> String? {
  match get_attr(attrs, "href") {
    Some(value) => Some(value)
    None => get_attr(attrs, xlink_href_attribute_name)
  }
}

///|
fn parse_url_ref(value : String) -> String? {
  let v = trim_string(value)
  if v.length() == 0 {
    return None
  }
  if string_starts_with(v, "url(") && string_ends_with(v, ")") {
    let inner = build_substring(v, 4, v.length() - 1)
    let trimmed = trim_string(inner)
    if trimmed.length() > 0 && Int::unsafe_to_char(trimmed[0].to_int()) == '#' {
      return Some(build_substring(trimmed, 1, trimmed.length()))
    }
    return Some(trimmed)
  }
  if Int::unsafe_to_char(v[0].to_int()) == '#' {
    return Some(build_substring(v, 1, v.length()))
  }
  None
}

///|
fn parse_number_list(value : String) -> Array[Double] {
  let nums : Array[Double] = []
  let mut buf = StringBuilder()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        nums.push(parse_number(buf.to_string()))
        buf = StringBuilder()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    nums.push(parse_number(buf.to_string()))
  }
  nums
}

///|
fn split_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut buf = StringBuilder()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        tokens.push(buf.to_string())
        buf = StringBuilder()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    tokens.push(buf.to_string())
  }
  tokens
}

///|
fn parse_view_box(value : String) -> ViewBox? {
  let nums = parse_number_list(value)
  if nums.length() < 4 {
    return None
  }
  Some({ min_x: nums[0], min_y: nums[1], width: nums[2], height: nums[3], })
}

///|
fn parse_preserve_aspect_ratio(value : String) -> PreserveAspectRatio {
  let v = trim_string(value)
  if v.length() == 0 {
    return PreserveAspectRatio::default()
  }
  let tokens = split_tokens(v)
  if tokens.length() == 0 {
    return PreserveAspectRatio::default()
  }
  if tokens[0] == "none" {
    return { align: None, meet_or_slice: Meet, }
  }
  let align = match tokens[0] {
    "xMinYMin" => XMinYMin
    "xMidYMin" => XMidYMin
    "xMaxYMin" => XMaxYMin
    "xMinYMid" => XMinYMid
    "xMidYMid" => XMidYMid
    "xMaxYMid" => XMaxYMid
    "xMinYMax" => XMinYMax
    "xMidYMax" => XMidYMax
    "xMaxYMax" => XMaxYMax
    _ => XMidYMid
  }
  let meet_or_slice = if tokens.length() > 1 {
    match tokens[1] {
      "slice" => Slice
      _ => Meet
    }
  } else {
    Meet
  }
  { align, meet_or_slice, }
}

///|
fn parse_mask_units(value : String) -> MaskUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_clip_path_units(value : String) -> ClipPathUnits {
  match trim_string(value) {
    "objectBoundingBox" => ObjectBoundingBox
    _ => UserSpaceOnUse
  }
}

///|
fn parse_mask_type(value : String) -> MaskType {
  match trim_string(value) {
    "alpha" => Alpha
    _ => Luminance
  }
}
