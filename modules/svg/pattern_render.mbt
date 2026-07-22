///|
priv enum ResolvedPaint {
  None
  SolidColor(Color)
  LinearGrad(LinearGradient)
  RadialGrad(RadialGradient)
  Pattern(Pattern)
}

///|
fn resolve_paint_fallback(
  fallback : PaintFallback,
  node_color : Color,
) -> ResolvedPaint {
  match fallback {
    PaintFallback::NoPaint => ResolvedPaint::None
    PaintFallback::SolidColor(color) => ResolvedPaint::SolidColor(color)
    PaintFallback::CurrentColor => ResolvedPaint::SolidColor(node_color)
  }
}

///|
fn pattern_is_valid(pattern : Pattern) -> Bool {
  if pattern.width <= 0.0 || pattern.height <= 0.0 {
    return false
  }
  if !pattern.transform.is_invertible() {
    return false
  }
  pattern.content.length() > 0
}

///|
fn resolve_paint_for_render(
  paint : Paint,
  node_color : Color,
  resources : RenderResources,
) -> ResolvedPaint {
  match paint {
    None => ResolvedPaint::None
    SolidColor(color) => ResolvedPaint::SolidColor(color)
    LinearGrad(grad) =>
      if grad.stops.length() == 0 {
        ResolvedPaint::None
      } else {
        ResolvedPaint::LinearGrad(grad)
      }
    RadialGrad(grad) =>
      if grad.stops.length() == 0 {
        ResolvedPaint::None
      } else {
        ResolvedPaint::RadialGrad(grad)
      }
    CurrentColor => ResolvedPaint::SolidColor(node_color)
    PaintServerRef(id, fallback) =>
      match resources.gradients.resolve(id) {
        Some(Gradient::Linear(grad)) =>
          if !grad.transform.is_invertible() {
            resolve_paint_fallback(fallback, node_color)
          } else if grad.stops.length() == 0 {
            ResolvedPaint::None
          } else {
            ResolvedPaint::LinearGrad(grad)
          }
        Some(Gradient::Radial(grad)) =>
          if !grad.transform.is_invertible() {
            resolve_paint_fallback(fallback, node_color)
          } else if grad.stops.length() == 0 {
            ResolvedPaint::None
          } else {
            ResolvedPaint::RadialGrad(grad)
          }
        None =>
          match resources.patterns.resolve(id) {
            Some(pattern) =>
              if pattern_is_valid(pattern) {
                ResolvedPaint::Pattern(pattern)
              } else {
                resolve_paint_fallback(fallback, node_color)
              }
            None => resolve_paint_fallback(fallback, node_color)
          }
      }
  }
}

///|
fn render_paint_order(
  order : PaintOrder,
  draw_fill : () -> Unit,
  draw_stroke : () -> Unit,
  draw_markers : () -> Unit,
) -> Unit {
  for item in order.order {
    match item {
      Fill => draw_fill()
      Stroke => draw_stroke()
      Markers => draw_markers()
    }
  }
}

///|
priv struct PatternTile {
  image : Image
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
fn build_pattern_tile(
  pattern : Pattern,
  bbox : BoundingBox,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
) -> PatternTile? {
  if string_array_contains(resources.active_patterns, pattern.id) {
    ctx.diagnostics.push({
      kind: ResourceCycle,
      stage: Paint,
      resource: pattern.id,
      node_id: "",
    })
    return None
  }
  let bbox_width = bbox.width()
  let bbox_height = bbox.height()
  let (tile_x, tile_y, tile_width, tile_height) = match pattern.pattern_units {
    PatternUnits::UserSpaceOnUse =>
      (pattern.x, pattern.y, pattern.width, pattern.height)
    PatternUnits::ObjectBoundingBox =>
      (
        bbox.min_x + pattern.x * bbox_width,
        bbox.min_y + pattern.y * bbox_height,
        pattern.width * bbox_width,
        pattern.height * bbox_height,
      )
  }
  if tile_width <= 0.0 || tile_height <= 0.0 {
    return None
  }
  let effective_transform = transform.multiply(pattern.transform)
  let (scale_x, scale_y) = effective_transform.get_scale()
  let mut pixel_width = ceil_to_int(tile_width * scale_x)
  let mut pixel_height = ceil_to_int(tile_height * scale_y)
  if pixel_width < 1 {
    pixel_width = 1
  }
  if pixel_height < 1 {
    pixel_height = 1
  }
  pixel_width = min_int(pixel_width, 4096)
  pixel_height = min_int(pixel_height, 4096)
  let texel_count = pixel_width.to_double() * pixel_height.to_double()
  if texel_count > 16000000.0 {
    let reduction = (16000000.0 / texel_count).sqrt()
    pixel_width = max_int(
      1,
      (pixel_width.to_double() * reduction).floor().to_int(),
    )
    pixel_height = max_int(
      1,
      (pixel_height.to_double() * reduction).floor().to_int(),
    )
  }
  if ctx.width > 0 && pixel_width > ctx.width {
    pixel_width = ctx.width
  }
  if ctx.height > 0 && pixel_height > ctx.height {
    pixel_height = ctx.height
  }
  let cache_key = pattern.id +
    ":" +
    bbox.min_x.to_string() +
    ":" +
    bbox.min_y.to_string() +
    ":" +
    bbox.max_x.to_string() +
    ":" +
    bbox.max_y.to_string() +
    ":" +
    transform.a.to_string() +
    ":" +
    transform.b.to_string() +
    ":" +
    transform.c.to_string() +
    ":" +
    transform.d.to_string() +
    ":" +
    transform.e.to_string() +
    ":" +
    transform.f.to_string() +
    ":" +
    pixel_width.to_string() +
    ":" +
    pixel_height.to_string()
  match resources.pattern_tiles.get(cache_key) {
    Some(tile) => return Some(tile)
    None => ()
  }
  let image = Image::new(pixel_width, pixel_height)
  let active_patterns = resources.active_patterns.copy()
  active_patterns.push(pattern.id)
  let nested_resources = { ..resources, active_patterns, }
  let tile_ctx = {
    setter: make_image_compositing_setter(image),
    width: pixel_width,
    height: pixel_height,
    flatness: ctx.flatness,
    clip: None,
    text_to_paths: ctx.text_to_paths,
    image_resolver: ctx.image_resolver,
    target_image: Some(image),
    blend_pixel: None,
    diagnostics: ctx.diagnostics,
  }
  let pixel_scale = Transform::scale(
    pixel_width.to_double() / tile_width,
    pixel_height.to_double() / tile_height,
  )
  let content_transform = match pattern.view_box {
    Some(view_box) =>
      pixel_scale.multiply(
        view_box.get_transform(
          tile_width,
          tile_height,
          pattern.preserve_aspect_ratio,
        ),
      )
    None => {
      let tile_offset = Transform::translate(-tile_x, -tile_y)
      match pattern.pattern_content_units {
        PatternUnits::UserSpaceOnUse => pixel_scale.multiply(tile_offset)
        PatternUnits::ObjectBoundingBox =>
          pixel_scale.multiply(
            tile_offset.multiply(
              Transform::translate(bbox.min_x, bbox.min_y).multiply(
                Transform::scale(bbox_width, bbox_height),
              ),
            ),
          )
      }
    }
  }
  for child in pattern.content {
    render_node(
      child,
      content_transform,
      tile_ctx,
      nested_resources,
      true,
      Color::black(),
    )
  }
  let tile : PatternTile = {
    image,
    x: tile_x,
    y: tile_y,
    width: tile_width,
    height: tile_height,
  }
  resources.pattern_tiles.set(cache_key, tile)
  Some(tile)
}

///|
fn make_pattern_setter(
  pattern : Pattern,
  bbox : BoundingBox,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  opacity : Double,
  sampling : ImageSampling,
) -> ColorSink? {
  let tile = match
    build_pattern_tile(pattern, bbox, transform, ctx, resources) {
    Some(value) => value
    None => return None
  }
  let inverse = transform.inverse()
  let pattern_inverse = pattern.transform.inverse()
  Some({
    set: (x, y, coverage_color) => {
      if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
        return
      }
      let (local_x, local_y) = inverse.apply(
        x.to_double() + 0.5,
        y.to_double() + 0.5,
      )
      let (pattern_x, pattern_y) = pattern_inverse.apply(local_x, local_y)
      let tile_u = (pattern_x - tile.x) / tile.width
      let tile_v = (pattern_y - tile.y) / tile.height
      let u = tile_u - tile_u.floor()
      let v = tile_v - tile_v.floor()
      let color = sample_raster_color(
        tile.image,
        u * tile.image.width.to_double(),
        v * tile.image.height.to_double(),
        sampling,
        true,
      )
      if color.a > 0 {
        ctx.setter.pixel(
          x,
          y,
          apply_coverage(apply_opacity(color, opacity), coverage_color.a * 257),
        )
      }
    },
  })
}

///|
