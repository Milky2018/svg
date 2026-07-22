///|
fn parse_clip_path_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let clip_rule = match get_attr(attrs, "clip-rule") {
    Some(v) => parse_fill_rule(v)
    None => NonZero
  }
  let transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let units = match get_attr(attrs, "clipPathUnits") {
    Some(v) => parse_clip_path_units(v)
    None => ClipPathUnits::UserSpaceOnUse
  }
  let clip = ClipPath::{
    id,
    shape: Group,
    content: [],
    transform,
    clip_rule,
    units,
  }
  ctx.clips.add(clip)
}

///|
fn parse_clip_path(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
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
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let clip_rule = temp.clip_rule
  let transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let units = match get_attr(attrs, "clipPathUnits") {
    Some(v) => parse_clip_path_units(v)
    None => ClipPathUnits::UserSpaceOnUse
  }
  let mut shape : Shape = Group
  for child in temp.children {
    match child.shape {
      Group => ()
      _ => {
        shape = child.shape
        break
      }
    }
  }
  let clip = ClipPath::{
    id,
    shape,
    content: temp.children,
    transform,
    clip_rule,
    units,
  }
  ctx.clips.add(clip)
}

///|
fn parse_filter_matrix(value : String) -> FixedArray[Double]? {
  let numbers = parse_number_list(value)
  if numbers.length() != 20 {
    return None
  }
  Some([
    numbers[0],
    numbers[1],
    numbers[2],
    numbers[3],
    numbers[4],
    numbers[5],
    numbers[6],
    numbers[7],
    numbers[8],
    numbers[9],
    numbers[10],
    numbers[11],
    numbers[12],
    numbers[13],
    numbers[14],
    numbers[15],
    numbers[16],
    numbers[17],
    numbers[18],
    numbers[19],
  ])
}

///|
priv struct FilterPrimitiveChild {
  tag : String
  attrs : Array[(String, String)]
}

///|
fn parse_filter_channel(value : String) -> FilterChannel {
  match value {
    "R" => ChannelR
    "G" => ChannelG
    "B" => ChannelB
    _ => ChannelA
  }
}

///|
fn parse_component_transfer_function(
  attrs : Array[(String, String)],
) -> ComponentTransferFunction {
  match get_attr(attrs, "type").unwrap_or("identity") {
    "table" =>
      TransferTable(
        get_attr(attrs, "tableValues").map(parse_number_list).unwrap_or([]),
      )
    "discrete" =>
      TransferDiscrete(
        get_attr(attrs, "tableValues").map(parse_number_list).unwrap_or([]),
      )
    "linear" =>
      TransferLinear(
        slope=get_attr(attrs, "slope").map(parse_number).unwrap_or(1.0),
        intercept=get_attr(attrs, "intercept").map(parse_number).unwrap_or(0.0),
      )
    "gamma" =>
      TransferGamma(
        amplitude=get_attr(attrs, "amplitude").map(parse_number).unwrap_or(1.0),
        exponent=get_attr(attrs, "exponent").map(parse_number).unwrap_or(1.0),
        offset=get_attr(attrs, "offset").map(parse_number).unwrap_or(0.0),
      )
    _ => TransferIdentity
  }
}

///|
fn filter_child_attrs(
  children : Array[FilterPrimitiveChild],
  tag : String,
) -> Array[(String, String)]? {
  for child in children {
    if child.tag == tag {
      return Some(child.attrs)
    }
  }
  None
}

///|
fn parse_filter_light(children : Array[FilterPrimitiveChild]) -> FilterLight {
  for child in children {
    match child.tag {
      "fePointLight" =>
        return PointLight(
          x=get_attr(child.attrs, "x").map(parse_number).unwrap_or(0.0),
          y=get_attr(child.attrs, "y").map(parse_number).unwrap_or(0.0),
          z=get_attr(child.attrs, "z").map(parse_number).unwrap_or(0.0),
        )
      "feSpotLight" =>
        return SpotLight(
          x=get_attr(child.attrs, "x").map(parse_number).unwrap_or(0.0),
          y=get_attr(child.attrs, "y").map(parse_number).unwrap_or(0.0),
          z=get_attr(child.attrs, "z").map(parse_number).unwrap_or(0.0),
          points_at_x=get_attr(child.attrs, "pointsAtX")
            .map(parse_number)
            .unwrap_or(0.0),
          points_at_y=get_attr(child.attrs, "pointsAtY")
            .map(parse_number)
            .unwrap_or(0.0),
          points_at_z=get_attr(child.attrs, "pointsAtZ")
            .map(parse_number)
            .unwrap_or(0.0),
          exponent=get_attr(child.attrs, "specularExponent")
            .map(parse_number)
            .unwrap_or(1.0),
          limiting_cone_angle=get_attr(child.attrs, "limitingConeAngle").map(
            parse_number,
          ),
        )
      "feDistantLight" =>
        return DistantLight(
          azimuth=get_attr(child.attrs, "azimuth")
            .map(parse_number)
            .unwrap_or(0.0),
          elevation=get_attr(child.attrs, "elevation")
            .map(parse_number)
            .unwrap_or(0.0),
        )
      _ => ()
    }
  }
  DistantLight(azimuth=0.0, elevation=0.0)
}

///|
fn parse_filter_lighting_color(attrs : Array[(String, String)]) -> Color {
  parse_color(get_attr(attrs, "lighting-color").unwrap_or("white"))
}

///|
fn parse_filter_primitive(
  tag : String,
  attrs : Array[(String, String)],
  children : Array[FilterPrimitiveChild],
) -> FilterGraphPrimitive? {
  let input = get_attr(attrs, "in").unwrap_or("")
  let result = get_attr(attrs, "result").unwrap_or("")
  match tag {
    "feColorMatrix" =>
      if get_attr(attrs, "type").unwrap_or("matrix") != "matrix" {
        None
      } else {
        match get_attr(attrs, "values") {
          Some(value) =>
            parse_filter_matrix(value).map(fn(matrix) {
              GraphColorMatrix(input~, result~, matrix~)
            })
          None => None
        }
      }
    "feGaussianBlur" => {
      let values = get_attr(attrs, "stdDeviation")
        .map(parse_number_list)
        .unwrap_or([])
      let radius_x = if values.length() == 0 { 0.0 } else { values[0] }
      let radius_y = if values.length() < 2 { radius_x } else { values[1] }
      Some(GraphGaussianBlur(input~, result~, radius_x~, radius_y~))
    }
    "feOffset" =>
      Some(
        GraphOffset(
          input~,
          result~,
          dx=get_attr(attrs, "dx").map(parse_number).unwrap_or(0.0),
          dy=get_attr(attrs, "dy").map(parse_number).unwrap_or(0.0),
        ),
      )
    "feBlend" =>
      Some(
        GraphBlend(
          input~,
          input2=get_attr(attrs, "in2").unwrap_or(""),
          result~,
          mode=parse_blend_mode(get_attr(attrs, "mode").unwrap_or("normal")),
        ),
      )
    "feComposite" => {
      let operator = match get_attr(attrs, "operator").unwrap_or("over") {
        "in" => CompositeIn
        "out" => CompositeOut
        "atop" => CompositeAtop
        "xor" => CompositeXor
        "arithmetic" => CompositeArithmetic
        _ => CompositeOver
      }
      Some(
        GraphComposite(
          input~,
          input2=get_attr(attrs, "in2").unwrap_or(""),
          result~,
          operator~,
          k1=get_attr(attrs, "k1").map(parse_number).unwrap_or(0.0),
          k2=get_attr(attrs, "k2").map(parse_number).unwrap_or(0.0),
          k3=get_attr(attrs, "k3").map(parse_number).unwrap_or(0.0),
          k4=get_attr(attrs, "k4").map(parse_number).unwrap_or(0.0),
        ),
      )
    }
    "feFlood" => {
      let base = parse_color(get_attr(attrs, "flood-color").unwrap_or("black"))
      let opacity = get_attr(attrs, "flood-opacity")
        .map(parse_number)
        .unwrap_or(1.0)
      let alpha = (base.a.to_double() * opacity).round().to_int()
      Some(GraphFlood(result~, color={ ..base, a: alpha }))
    }
    "feMerge" => {
      let inputs : Array[String] = []
      for child in children {
        if child.tag == "feMergeNode" {
          inputs.push(get_attr(child.attrs, "in").unwrap_or(""))
        }
      }
      Some(GraphMerge(result~, inputs~))
    }
    "feComponentTransfer" =>
      Some(
        GraphComponentTransfer(
          input~,
          result~,
          red=filter_child_attrs(children, "feFuncR")
            .map(parse_component_transfer_function)
            .unwrap_or(TransferIdentity),
          green=filter_child_attrs(children, "feFuncG")
            .map(parse_component_transfer_function)
            .unwrap_or(TransferIdentity),
          blue=filter_child_attrs(children, "feFuncB")
            .map(parse_component_transfer_function)
            .unwrap_or(TransferIdentity),
          alpha=filter_child_attrs(children, "feFuncA")
            .map(parse_component_transfer_function)
            .unwrap_or(TransferIdentity),
        ),
      )
    "feMorphology" => {
      let radii = get_attr(attrs, "radius").map(parse_number_list).unwrap_or([])
      let radius_x = if radii.length() == 0 { 0.0 } else { radii[0] }
      let radius_y = if radii.length() < 2 { radius_x } else { radii[1] }
      Some(
        GraphMorphology(
          input~,
          result~,
          radius_x~,
          radius_y~,
          operator=if get_attr(attrs, "operator").unwrap_or("erode") == "dilate" {
            MorphologyDilate
          } else {
            MorphologyErode
          },
        ),
      )
    }
    "feConvolveMatrix" => {
      let order = get_attr(attrs, "order").map(parse_number_list).unwrap_or([])
      let order_x = if order.length() == 0 { 3 } else { order[0].to_int() }
      let order_y = if order.length() < 2 { order_x } else { order[1].to_int() }
      let kernel = get_attr(attrs, "kernelMatrix")
        .map(parse_number_list)
        .unwrap_or([])
      let kernel_sum = kernel.fold(init=0.0, (sum, value) => sum + value)
      let default_divisor = if kernel_sum.abs() <= 0.000001 {
        1.0
      } else {
        kernel_sum
      }
      Some(
        GraphConvolveMatrix(
          input~,
          result~,
          order_x~,
          order_y~,
          kernel~,
          divisor=get_attr(attrs, "divisor")
            .map(parse_number)
            .unwrap_or(default_divisor),
          bias=get_attr(attrs, "bias").map(parse_number).unwrap_or(0.0),
          target_x=get_attr(attrs, "targetX")
            .map(parse_number)
            .map(fn(v) { v.to_int() })
            .unwrap_or(order_x / 2),
          target_y=get_attr(attrs, "targetY")
            .map(parse_number)
            .map(fn(v) { v.to_int() })
            .unwrap_or(order_y / 2),
          edge_mode=match get_attr(attrs, "edgeMode").unwrap_or("duplicate") {
            "wrap" => EdgeWrap
            "none" => EdgeNone
            _ => EdgeDuplicate
          },
          preserve_alpha=get_attr(attrs, "preserveAlpha").unwrap_or("false") ==
            "true",
        ),
      )
    }
    "feDisplacementMap" =>
      Some(
        GraphDisplacementMap(
          input~,
          input2=get_attr(attrs, "in2").unwrap_or(""),
          result~,
          scale=get_attr(attrs, "scale").map(parse_number).unwrap_or(0.0),
          x_channel=parse_filter_channel(
            get_attr(attrs, "xChannelSelector").unwrap_or("A"),
          ),
          y_channel=parse_filter_channel(
            get_attr(attrs, "yChannelSelector").unwrap_or("A"),
          ),
        ),
      )
    "feTurbulence" => {
      let base = get_attr(attrs, "baseFrequency")
        .map(parse_number_list)
        .unwrap_or([])
      let base_x = if base.length() == 0 { 0.0 } else { base[0] }
      let base_y = if base.length() < 2 { base_x } else { base[1] }
      Some(
        GraphTurbulence(
          result~,
          base_x~,
          base_y~,
          octaves=get_attr(attrs, "numOctaves")
            .map(parse_number)
            .map(fn(v) { v.to_int() })
            .unwrap_or(1),
          seed=get_attr(attrs, "seed").map(parse_number).unwrap_or(0.0),
          stitch=get_attr(attrs, "stitchTiles").unwrap_or("noStitch") ==
            "stitch",
          fractal_noise=get_attr(attrs, "type").unwrap_or("turbulence") ==
            "fractalNoise",
        ),
      )
    }
    "feTile" => Some(GraphTile(input~, result~))
    "feImage" =>
      Some(
        GraphImage(
          result~,
          href=match get_attr(attrs, "href") {
            Some(value) => value
            None => get_attr(attrs, "xlink:href").unwrap_or("")
          },
          x=get_attr(attrs, "x").map(parse_number).unwrap_or(0.0),
          y=get_attr(attrs, "y").map(parse_number).unwrap_or(0.0),
          width=get_attr(attrs, "width").map(parse_number).unwrap_or(0.0),
          height=get_attr(attrs, "height").map(parse_number).unwrap_or(0.0),
        ),
      )
    "feDiffuseLighting" =>
      Some(
        GraphDiffuseLighting(
          input~,
          result~,
          surface_scale=get_attr(attrs, "surfaceScale")
            .map(parse_number)
            .unwrap_or(1.0),
          diffuse_constant=get_attr(attrs, "diffuseConstant")
            .map(parse_number)
            .unwrap_or(1.0),
          color=parse_filter_lighting_color(attrs),
          light=parse_filter_light(children),
        ),
      )
    "feSpecularLighting" =>
      Some(
        GraphSpecularLighting(
          input~,
          result~,
          surface_scale=get_attr(attrs, "surfaceScale")
            .map(parse_number)
            .unwrap_or(1.0),
          specular_constant=get_attr(attrs, "specularConstant")
            .map(parse_number)
            .unwrap_or(1.0),
          specular_exponent=get_attr(attrs, "specularExponent")
            .map(parse_number)
            .unwrap_or(1.0),
          color=parse_filter_lighting_color(attrs),
          light=parse_filter_light(children),
        ),
      )
    _ => None
  }
}

///|
fn parse_filter_primitive_children(
  parser : SVGParser,
  parent_tag : String,
) -> Array[FilterPrimitiveChild] {
  let children : Array[FilterPrimitiveChild] = []
  while !parser.is_end() {
    match parser.advance_event() {
      @xml.Event::Start(element) => {
        let tag = local_xml_name(element.name)
        children.push({ tag, attrs: element.attributes })
        skip_to_end_tag(parser, tag)
      }
      @xml.Event::Empty(element) =>
        children.push({
          tag: local_xml_name(element.name),
          attrs: element.attributes,
        })
      @xml.Event::End(name) => if local_xml_name(name) == parent_tag { break }
      @xml.Event::Eof => break
      _ => ()
    }
  }
  children
}

///|
fn parse_filter_graph(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
) -> Unit {
  let primitives : Array[FilterGraphPrimitive] = []
  while !parser.is_end() {
    match parser.advance_event() {
      @xml.Event::Start(element) => {
        let primitive_tag = local_xml_name(element.name)
        let primitive_children = parse_filter_primitive_children(
          parser, primitive_tag,
        )
        match
          parse_filter_primitive(
            primitive_tag,
            element.attributes,
            primitive_children,
          ) {
          Some(primitive) => primitives.push(primitive)
          None => ()
        }
      }
      @xml.Event::Empty(element) =>
        match
          parse_filter_primitive(
            local_xml_name(element.name),
            element.attributes,
            [],
          ) {
          Some(primitive) => primitives.push(primitive)
          None => ()
        }
      @xml.Event::End(name) => if local_xml_name(name) == tag_name { break }
      @xml.Event::Eof => break
      _ => ()
    }
  }
  let id = get_attr(attrs, "id").unwrap_or("")
  if id.length() == 0 {
    return
  }
  let units = match get_attr(attrs, "filterUnits") {
    Some(value) => parse_mask_units(value)
    None => MaskUnits::ObjectBoundingBox
  }
  let primitive_units = match get_attr(attrs, "primitiveUnits") {
    Some(value) => parse_mask_units(value)
    None => MaskUnits::UserSpaceOnUse
  }
  let (default_x, default_y, default_width, default_height) = match units {
    MaskUnits::ObjectBoundingBox => (-0.1, -0.1, 1.2, 1.2)
    MaskUnits::UserSpaceOnUse => (-0.1, -0.1, 1.2, 1.2)
  }
  let (x, x_is_percent) = match get_attr(attrs, "x") {
    Some(value) => parse_mask_length(value, units)
    None => (default_x, true)
  }
  let (y, y_is_percent) = match get_attr(attrs, "y") {
    Some(value) => parse_mask_length(value, units)
    None => (default_y, true)
  }
  let (width, width_is_percent) = match get_attr(attrs, "width") {
    Some(value) => parse_mask_length(value, units)
    None => (default_width, true)
  }
  let (height, height_is_percent) = match get_attr(attrs, "height") {
    Some(value) => parse_mask_length(value, units)
    None => (default_height, true)
  }
  ctx.filter_graphs.add({
    id,
    primitives,
    units,
    primitive_units,
    x,
    y,
    width,
    height,
    x_is_percent,
    y_is_percent,
    width_is_percent,
    height_is_percent,
  })
}

///|
fn parse_mask_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> Unit {
  parse_mask_with_content(attrs, [], ctx)
}

///|
fn parse_mask(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
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
  parse_mask_with_content(attrs, temp.children, ctx)
}

///|
fn parse_mask_with_content(
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
  let mask_units = match get_attr(attrs, "maskUnits") {
    Some(v) => parse_mask_units(v)
    None => MaskUnits::ObjectBoundingBox
  }
  let mask_content_units = match get_attr(attrs, "maskContentUnits") {
    Some(v) => parse_mask_units(v)
    None => MaskUnits::UserSpaceOnUse
  }
  let mask_type = match get_attr(attrs, "mask-type") {
    Some(v) => parse_mask_type(v)
    None => Luminance
  }
  let mut has_bounds = false
  let mut x = 0.0
  let mut y = 0.0
  let mut width = 0.0
  let mut height = 0.0
  let mut x_is_percent = false
  let mut y_is_percent = false
  let mut width_is_percent = false
  let mut height_is_percent = false
  if get_attr(attrs, "x") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    x = val
    x_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "y") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    y = val
    y_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "width") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    width = val
    width_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "height") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    height = val
    height_is_percent = is_percent
    has_bounds = true
  }
  let base = if has_bounds {
    Mask::with_bounds(id, content, x, y, width, height)
  } else {
    Mask::new(id, content)
  }
  let mask = if has_bounds {
    {
      ..base,
      x_is_percent,
      y_is_percent,
      width_is_percent,
      height_is_percent,
      mask_units,
      mask_content_units,
      mask_type,
    }
  } else {
    { ..base, mask_units, mask_content_units, mask_type }
  }
  ctx.masks.add(mask)
}
