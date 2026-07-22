///|
fn apply_clip_path(
  ctx : RenderState,
  clip : ClipPath,
  element_transform : Transform,
  bbox_local : BoundingBox,
  resources : RenderResources,
) -> RenderState {
  let mask = build_clip_path_coverage(
    clip,
    element_transform,
    bbox_local,
    ctx.width,
    ctx.height,
    resources,
    0,
  )
  if mask.width == 0 || mask.height == 0 {
    let setter : ColorSink = { set: fn(_, _, _) { () } }
    return { ..ctx, setter, }
  }
  let inner = ctx.setter
  let setter : ColorSink = {
    set: fn(x, y, color) {
      let coverage = mask.get_device(x, y)
      if coverage > 0 {
        inner.pixel(
          x,
          y,
          if coverage == 65535 {
            color
          } else {
            apply_coverage(color, coverage)
          },
        )
      }
    },
  }
  { ..ctx, setter, }
}

///|
fn clip_shape_contours(
  shape : Shape,
  transform : Transform,
) -> Array[Array[(Double, Double)]] {
  let commands = match shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      if width > 0.0 && height > 0.0 {
        rect_path_commands(x, y, width, height, rx, ry)
      } else {
        []
      }
    Circle(cx~, cy~, r~) =>
      if r > 0.0 {
        ellipse_path_commands(cx, cy, r, r)
      } else {
        []
      }
    Ellipse(cx~, cy~, rx~, ry~) =>
      if rx > 0.0 && ry > 0.0 {
        ellipse_path_commands(cx, cy, rx, ry)
      } else {
        []
      }
    Polyline(points~) | Polygon(points~) => points_path_commands(points, true)
    Path(commands~) => commands
    Text(x~, y~, text~, font_size~) =>
      rect_path_commands(
        x,
        y - font_size,
        font_size * 0.6 * text.length().to_double(),
        font_size,
        0.0,
        0.0,
      )
    Line(..) | Image(..) | Group => []
  }
  let contours : Array[Array[(Double, Double)]] = []
  for polyline in path_to_polylines(commands, device_path_flatness(transform)) {
    contours.push(polyline.map(fn(point) { transform.apply(point.0, point.1) }))
  }
  contours
}

///|
fn build_clip_node_coverage(
  node : SVGNode,
  parent_transform : Transform,
  width : Int,
  height : Int,
  resources : RenderResources,
  depth : Int,
) -> CoverageMask {
  if depth >= 32 {
    return { origin_x: 0, origin_y: 0, width: 0, height: 0, values: [] }
  }
  let base_transform = parent_transform.multiply(node.transform)
  let transform = match
    (node.view_box, node.viewport_width, node.viewport_height) {
    (Some(vb), Some(vw), Some(vh)) =>
      base_transform.multiply(
        vb.get_transform(vw, vh, node.preserve_aspect_ratio),
      )
    _ => base_transform
  }
  let mut result = build_coverage_mask(
    clip_shape_contours(node.shape, transform),
    node.clip_rule,
    width,
    height,
  )
  for child in node.children {
    result = union_coverage_masks(
      result,
      build_clip_node_coverage(
        child,
        transform,
        width,
        height,
        resources,
        depth + 1,
      ),
    )
  }
  match node.clip_path_id {
    Some(id) =>
      match resources.clips.get(id) {
        Some(nested) => {
          let local_bounds = compute_bounds_without_self_transform(
            node,
            Transform::identity(),
          )
          result = intersect_coverage_masks(
            result,
            build_clip_path_coverage(
              nested,
              transform,
              local_bounds,
              width,
              height,
              resources,
              depth + 1,
            ),
          )
        }
        None => ()
      }
    None => ()
  }
  result
}

///|
fn build_clip_path_coverage(
  clip : ClipPath,
  element_transform : Transform,
  bbox_local : BoundingBox,
  width : Int,
  height : Int,
  resources : RenderResources,
  depth : Int,
) -> CoverageMask {
  let base_transform = match clip.units {
    UserSpaceOnUse => element_transform
    ObjectBoundingBox => {
      if bbox_local.is_empty() {
        return { origin_x: 0, origin_y: 0, width: 0, height: 0, values: [] }
      }
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      element_transform.multiply(translate.multiply(scale))
    }
  }
  let combined = base_transform.multiply(clip.transform)
  if clip.content.is_empty() {
    return build_coverage_mask(
      clip_shape_contours(clip.shape, combined),
      clip.clip_rule,
      width,
      height,
    )
  }
  let mut result : CoverageMask = {
    origin_x: 0,
    origin_y: 0,
    width: 0,
    height: 0,
    values: [],
  }
  for child in clip.content {
    result = union_coverage_masks(
      result,
      build_clip_node_coverage(
        child,
        combined,
        width,
        height,
        resources,
        depth + 1,
      ),
    )
  }
  result
}

///|
fn render_masked_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  mask : Mask,
  parent_color : Color,
) -> Unit {
  let bbox = compute_bounds(node, parent_transform)
  if bbox.is_empty() {
    return
  }
  let bbox_local = compute_bounds_without_self_transform(
    node,
    Transform::identity(),
  )
  let element_transform = parent_transform.multiply(node.transform)
  let min_x = floor_to_int(bbox.min_x)
  let min_y = floor_to_int(bbox.min_y)
  let max_x = ceil_to_int(bbox.max_x)
  let max_y = ceil_to_int(bbox.max_y)
  let width = max_x - min_x
  let height = max_y - min_y
  if width <= 0 || height <= 0 {
    return
  }
  let image = Image::new(width, height)
  let image_ctx = make_image_context(image, width, height, ctx)
  let offset = Transform::translate(-min_x.to_double(), -min_y.to_double())
  let image_parent = offset.multiply(parent_transform)
  render_node(node, image_parent, image_ctx, resources, false, parent_color)
  let mask_image = Image::new(width, height)
  let mask_ctx = make_image_context(mask_image, width, height, ctx)
  let mask_bounds_local = mask.get_mask_bounds(bbox_local)
  let mask_region_transform = offset.multiply(element_transform)
  let mask_ctx = match
    apply_transformed_rect_clip(
      mask_ctx, mask_bounds_local, mask_region_transform,
    ) {
    Some(clipped) => clipped
    None => return
  }
  let mask_parent = match mask.mask_content_units {
    ObjectBoundingBox => {
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let object_transform = element_transform.multiply(
        translate.multiply(scale),
      )
      offset.multiply(object_transform)
    }
    UserSpaceOnUse => offset.multiply(element_transform)
  }
  for content_node in mask.content {
    render_node(
      content_node, mask_parent, mask_ctx, resources, false, parent_color,
    )
  }
  let masked = apply_mask_to_image(image, mask_image, mask.mask_type)
  blit_image_to_context(masked, ctx, min_x, min_y)
}

///|
fn make_image_context(
  image : Image,
  width : Int,
  height : Int,
  parent : RenderState,
) -> RenderState {
  let setter = make_image_compositing_setter(image)
  {
    setter,
    width,
    height,
    flatness: parent.flatness,
    clip: None,
    text_to_paths: parent.text_to_paths,
    image_resolver: parent.image_resolver,
    target_image: Some(image),
    blend_pixel: parent.blend_pixel,
    diagnostics: parent.diagnostics,
  }
}

///|
fn make_image_compositing_setter(image : Image) -> ColorSink {
  {
    set: fn(x, y, source) {
      let backdrop = image.get_pixel(x, y)
      image.set_pixel(x, y, blend_colors(backdrop, source))
    },
  }
}

///|
fn blit_image_to_context(
  image : Image,
  ctx : RenderState,
  offset_x : Int,
  offset_y : Int,
) -> Unit {
  let setter = match ctx.clip {
    Some(clip) => ctx.setter.with_clip(clip)
    None => ctx.setter
  }
  for y in 0..<image.height {
    for x in 0..<image.width {
      let color = image.get_pixel(x, y)
      if color.a > 0 {
        setter.pixel(x + offset_x, y + offset_y, color)
      }
    }
  }
}

///|
fn floor_to_int(value : Double) -> Int {
  value.floor().to_int()
}

///|
fn ceil_to_int(value : Double) -> Int {
  let i = value.to_int()
  if value > i.to_double() {
    i + 1
  } else {
    i
  }
}

///|
