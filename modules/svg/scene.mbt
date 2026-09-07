///|
fn compute_bounds(node : SVGNode, parent_transform : Transform) -> BoundingBox {
  let transform = parent_transform.multiply(node.transform)
  let mut bbox = get_shape_bounds(node.shape)
  if !bbox.is_empty() {
    bbox = transform.apply_bbox(bbox)
  }
  for child in node.children {
    let child_bbox = compute_bounds(child, transform)
    bbox = bbox.union(child_bbox)
  }
  bbox
}

///|
/// Compute bounds without applying the node's own transform
fn compute_bounds_without_self_transform(
  node : SVGNode,
  parent_transform : Transform,
) -> BoundingBox {
  let transform = parent_transform
  let mut bbox = get_shape_bounds(node.shape)
  if !bbox.is_empty() {
    bbox = transform.apply_bbox(bbox)
  }
  for child in node.children {
    let child_bbox = compute_bounds(child, transform)
    bbox = bbox.union(child_bbox)
  }
  bbox
}

///|
fn get_shape_bounds(shape : Shape) -> BoundingBox {
  match shape {
    Rect(x~, y~, width~, height~, ..) =>
      if width <= 0.0 || height <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(x, y, width, height)
      }
    Circle(cx~, cy~, r~) =>
      if r <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(cx - r, cy - r, r * 2.0, r * 2.0)
      }
    Ellipse(cx~, cy~, rx~, ry~) =>
      if rx <= 0.0 || ry <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(cx - rx, cy - ry, rx * 2.0, ry * 2.0)
      }
    Line(x1~, y1~, x2~, y2~) => {
      let mut bbox = BoundingBox::empty()
      bbox = bbox.expand_by_point(x1, y1)
      bbox = bbox.expand_by_point(x2, y2)
      bbox
    }
    Polyline(points~) | Polygon(points~) => {
      let mut bbox = BoundingBox::empty()
      for p in points {
        bbox = bbox.expand_by_point(p.0, p.1)
      }
      bbox
    }
    Path(commands~) => path_bbox(commands)
    Text(x~, y~, text~, font_size~) => {
      // Approximate text bounds using character count
      // Each character is approximately 0.6 * font_size wide
      let char_width = font_size * 0.6
      let width = char_width * text.length().to_double()
      let height = font_size
      // y is baseline, so text extends upward
      BoundingBox::from_rect(x, y - height, width, height)
    }
    Image(x~, y~, width~, height~, ..) =>
      if width <= 0.0 || height <= 0.0 {
        BoundingBox::empty()
      } else {
        BoundingBox::from_rect(x, y, width, height)
      }
    Group => BoundingBox::empty()
  }
}

///|
/// Render context for drawing
priv struct RenderState {
  setter : ColorSink
  width : Int
  height : Int
  flatness : Double // For path flattening
  clip : ClipRect? // Optional clipping rectangle for culling
  /// Font callback: (codepoint, font_size) -> (path_commands, advance_width)
  text_to_paths : ((Int, Double) -> (Array[PathCommand], Double))?
  /// Host callback for resolving image references into decoded RGBA pixels.
  image_resolver : ((String) -> Image?)?
  target_image : Image?
  blend_pixel : ((Int, Int, Color, BlendMode) -> Unit)?
  diagnostics : Array[RenderDiagnostic]
}

///|
priv struct RenderResources {
  clips : ClipPathRegistry
  masks : MaskRegistry
  filter_graphs : FilterGraphRegistry
  patterns : PatternRegistry
  gradients : GradientRegistry
  markers : MarkerRegistry
  active_patterns : Array[String]
  pattern_tiles : Map[String, PatternTile]
  surface_pool : RenderSurfacePool
}

///|
/// Render a parsed SVG document with registered resources
fn SVGDocument::render(self : SVGDocument, ctx : RenderState) -> Unit {
  let resources = {
    clips: self.clips,
    masks: self.masks,
    filter_graphs: self.filter_graphs,
    patterns: self.patterns,
    gradients: self.gradients,
    markers: self.markers,
    active_patterns: [],
    pattern_tiles: Map([]),
    surface_pool: RenderSurfacePool::new(),
  }
  match self.root.view_box {
    Some(vb) => {
      let viewbox_transform = vb.get_transform(
        ctx.width.to_double(),
        ctx.height.to_double(),
        self.root.preserve_aspect_ratio,
      )
      render_node(
        self.root,
        viewbox_transform,
        ctx,
        resources,
        true,
        Color::black(),
      )
    }
    None =>
      render_node(
        self.root,
        Transform::identity(),
        ctx,
        resources,
        true,
        Color::black(),
      )
  }
}

///|
/// Check if a bounding box is visible within the render context
fn is_visible(bbox : BoundingBox, ctx : RenderState) -> Bool {
  match ctx.clip {
    Some(clip) => bbox.intersects(clip.to_bbox())
    None => {
      // Default: check against render context bounds
      let ctx_bbox = BoundingBox::from_rect(
        0.0,
        0.0,
        ctx.width.to_double(),
        ctx.height.to_double(),
      )
      bbox.intersects(ctx_bbox)
    }
  }
}

///|
fn intersect_clip(a : ClipRect, b : ClipRect) -> ClipRect? {
  let x0 = if a.x > b.x { a.x } else { b.x }
  let y0 = if a.y > b.y { a.y } else { b.y }
  let x1 = if a.x + a.width < b.x + b.width {
    a.x + a.width
  } else {
    b.x + b.width
  }
  let y1 = if a.y + a.height < b.y + b.height {
    a.y + a.height
  } else {
    b.y + b.height
  }
  let w = x1 - x0
  let h = y1 - y0
  if w <= 0 || h <= 0 {
    None
  } else {
    Some(ClipRect::new(x0, y0, w, h))
  }
}

///|
fn apply_transformed_rect_clip(
  ctx : RenderState,
  local_rect : BoundingBox,
  transform : Transform,
) -> RenderState? {
  if local_rect.is_empty() || !transform.is_invertible() {
    return None
  }
  let world_bbox = transform.apply_bbox(local_rect)
  let mut clip_x = floor_to_int(world_bbox.min_x)
  let mut clip_y = floor_to_int(world_bbox.min_y)
  let mut clip_w = ceil_to_int(world_bbox.max_x) - clip_x
  let mut clip_h = ceil_to_int(world_bbox.max_y) - clip_y
  if clip_x < 0 {
    clip_w = clip_w + clip_x
    clip_x = 0
  }
  if clip_y < 0 {
    clip_h = clip_h + clip_y
    clip_y = 0
  }
  if clip_x + clip_w > ctx.width {
    clip_w = ctx.width - clip_x
  }
  if clip_y + clip_h > ctx.height {
    clip_h = ctx.height - clip_y
  }
  if clip_w <= 0 || clip_h <= 0 {
    return None
  }
  let bounds_clip = ClipRect::new(clip_x, clip_y, clip_w, clip_h)
  let clip = match ctx.clip {
    Some(existing) =>
      match intersect_clip(existing, bounds_clip) {
        Some(value) => value
        None => return None
      }
    None => bounds_clip
  }
  let inverse = transform.inverse()
  let inner = ctx.setter.with_clip(clip)
  let setter : ColorSink = {
    set: fn(x, y, color) {
      let (local_x, local_y) = inverse.apply(
        x.to_double() + 0.5,
        y.to_double() + 0.5,
      )
      if local_x >= local_rect.min_x &&
        local_x < local_rect.max_x &&
        local_y >= local_rect.min_y &&
        local_y < local_rect.max_y {
        inner.pixel(x, y, color)
      }
    },
  }
  Some({ ..ctx, setter, clip: Some(clip), })
}

///|
fn render_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  allow_mask : Bool,
  parent_color : Color,
) -> Unit {
  // Skip invisible nodes
  if node.opacity <= 0.0 {
    return
  }
  let needs_group_opacity = match node.shape {
    Group => node.opacity < 1.0
    _ => false
  }
  let has_mask = node.mask_id is Some(_)
  let has_filter_graph = node.filter_graph_id is Some(_)
  let needs_surface_mask = has_mask &&
    (ctx.target_image is Some(_) || ctx.blend_pixel is Some(_))
  if allow_mask &&
    (
      needs_group_opacity ||
      !node.filters.is_empty() ||
      has_filter_graph ||
      needs_surface_mask ||
      node.blend_mode != Normal ||
      node.isolation == Isolate
    ) {
    render_isolated_node(node, parent_transform, ctx, resources, parent_color)
    return
  }
  let node_color = match node.color {
    Some(c) => c
    None => parent_color
  }
  let base_transform = parent_transform.multiply(node.transform)
  let transform = match
    (node.view_box, node.viewport_width, node.viewport_height) {
    (Some(vb), Some(w), Some(h)) =>
      base_transform.multiply(
        vb.get_transform(w, h, node.preserve_aspect_ratio),
      )
    _ => base_transform
  }
  // Apply clip path if present
  let ctx_for_node = match node.clip_path_id {
    Some(id) =>
      match resources.clips.get(id) {
        Some(clip) => {
          let bbox_local = match clip.units {
            ObjectBoundingBox =>
              compute_bounds_without_self_transform(node, Transform::identity())
            UserSpaceOnUse => BoundingBox::empty()
          }
          apply_clip_path(ctx, clip, transform, bbox_local, resources)
        }
        None => ctx
      }
    None => ctx
  }
  let ctx_for_node = match
    (node.clip_overflow, node.viewport_width, node.viewport_height) {
    (true, Some(vw), Some(vh)) => {
      let viewport_bbox = BoundingBox::from_rect(0.0, 0.0, vw, vh)
      match
        apply_transformed_rect_clip(ctx_for_node, viewport_bbox, base_transform) {
        Some(clipped) => clipped
        None => return
      }
    }
    _ => ctx_for_node
  }
  // Apply mask if present
  if allow_mask {
    match node.mask_id {
      Some(id) =>
        match resources.masks.get(id) {
          Some(mask) => {
            render_masked_node(
              node, parent_transform, ctx_for_node, resources, mask, node_color,
            )
            return
          }
          None => ()
        }
      None => ()
    }
  }
  // Early culling: check if node's bounding box is visible
  let shape_bbox = get_shape_bounds(node.shape)
  if !shape_bbox.is_empty() {
    let transformed_bbox = transform.apply_bbox(shape_bbox)
    if !is_visible(transformed_bbox, ctx_for_node) {
      // Node is outside visible area, but still need to check children
      // (they might have different transforms that make them visible)
      for child in node.children {
        render_node(child, transform, ctx_for_node, resources, true, node_color)
      }
      return
    }
  }
  // Render shape
  match node.shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      render_rect(
        x, y, width, height, rx, ry, node, transform, ctx_for_node, resources, node_color,
      )
    Circle(cx~, cy~, r~) =>
      render_circle(
        cx, cy, r, node, transform, ctx_for_node, resources, node_color,
      )
    Ellipse(cx~, cy~, rx~, ry~) =>
      render_ellipse(
        cx, cy, rx, ry, node, transform, ctx_for_node, resources, node_color,
      )
    Line(x1~, y1~, x2~, y2~) =>
      render_line(
        x1, y1, x2, y2, node, transform, ctx_for_node, resources, node_color,
      )
    Polyline(points~) =>
      render_polyline(
        points, node, transform, ctx_for_node, resources, node_color,
      )
    Polygon(points~) =>
      render_polygon(
        points, node, transform, ctx_for_node, node_color, resources,
      )
    Path(commands~) =>
      render_path(
        commands, node, transform, ctx_for_node, node_color, resources,
      )
    Text(x~, y~, text~, font_size~) =>
      render_text(
        x, y, text, font_size, node, transform, ctx_for_node, node_color, resources,
      )
    Image(x~, y~, width~, height~, href~) =>
      render_image(
        x,
        y,
        width,
        height,
        href,
        transform,
        ctx_for_node,
        node.preserve_aspect_ratio,
        node.preserve_aspect_ratio_is_set,
        node.image_sampling,
        node.opacity,
      )
    Group => ()
  }
  for child in node.children {
    render_node(child, transform, ctx_for_node, resources, true, node_color)
  }
}

///|
fn render_isolated_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  parent_color : Color,
) -> Unit {
  let bounds = isolated_node_region(node, parent_transform, ctx, resources)
  let origin_x = max_int(0, floor_to_int(bounds.min_x))
  let origin_y = max_int(0, floor_to_int(bounds.min_y))
  let end_x = min_int(ctx.width, ceil_to_int(bounds.max_x))
  let end_y = min_int(ctx.height, ceil_to_int(bounds.max_y))
  if end_x <= origin_x || end_y <= origin_y {
    return
  }
  let layer = resources.surface_pool.acquire(
    origin_x,
    origin_y,
    end_x - origin_x,
    end_y - origin_y,
    SRGB,
  )
  let layer_setter : ColorSink = {
    set: fn(x, y, color) {
      layer.composite_device(x, y, PremulColor16::from_color(color))
    },
  }
  let layer_blend = fn(x : Int, y : Int, color : Color, mode : BlendMode) {
    if layer.contains_device(x, y) {
      layer.set_device(
        x,
        y,
        PremulColor16::from_color(
          blend_with_mode(layer.get_device(x, y).to_color(), color, mode),
        ),
      )
    }
  }
  let layer_ctx = {
    ..ctx,
    setter: layer_setter,
    target_image: None,
    blend_pixel: Some(layer_blend),
  }
  let layer_node = node.clone()
  layer_node.opacity = 1.0
  layer_node.blend_mode = Normal
  layer_node.isolation = Auto
  layer_node.clear_filters()
  layer_node.filter_graph_id = None
  layer_node.mask_id = None
  render_node(
    layer_node, parent_transform, layer_ctx, resources, true, parent_color,
  )
  for filter in node.filters {
    let filtered = apply_filter(layer.to_image(), filter)
    layer.replace_from_image(filtered)
  }
  match node.filter_graph_id {
    Some(id) =>
      match resources.filter_graphs.get(id) {
        Some(graph) => {
          let result = evaluate_filter_graph(
            graph,
            layer.to_image(),
            compute_bounds(node, parent_transform),
            ctx.image_resolver,
            layer.origin_x,
            layer.origin_y,
          )
          layer.replace_from_image(result)
        }
        None => ()
      }
    None => ()
  }
  match node.mask_id {
    Some(id) =>
      match resources.masks.get(id) {
        Some(mask) =>
          apply_mask_to_isolated_surface(
            layer, node, parent_transform, ctx, resources, mask, parent_color,
          )
        None => ()
      }
    None => ()
  }
  layer.apply_opacity(node.opacity)
  composite_surface_to_context(layer, ctx, node.blend_mode)
  resources.surface_pool.release(layer)
}

///|
fn expand_effect_bounds(bounds : BoundingBox, amount : Double) -> BoundingBox {
  if bounds.is_empty() {
    bounds
  } else {
    {
      min_x: bounds.min_x - amount,
      min_y: bounds.min_y - amount,
      max_x: bounds.max_x + amount,
      max_y: bounds.max_y + amount,
    }
  }
}

///|
fn isolated_node_region(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
) -> BoundingBox {
  let mut bounds = compute_bounds(node, parent_transform)
  let (scale_x, scale_y) = parent_transform.multiply(node.transform).get_scale()
  if node.stroke.width > 0.0 {
    bounds = expand_effect_bounds(
      bounds,
      node.stroke.width * max(scale_x.abs(), scale_y.abs()) * 0.5 + 1.0,
    )
  }
  for filter in node.filters {
    match filter {
      Blur(radius) => bounds = expand_effect_bounds(bounds, radius * 3.0 + 1.0)
      DropShadow(dx, dy, radius, _) => {
        let shadow = expand_effect_bounds(bounds, radius * 3.0 + 1.0)
        bounds = bounds.union({
          min_x: shadow.min_x + dx,
          min_y: shadow.min_y + dy,
          max_x: shadow.max_x + dx,
          max_y: shadow.max_y + dy,
        })
      }
      _ => ()
    }
  }
  match node.filter_graph_id {
    Some(id) =>
      match resources.filter_graphs.get(id) {
        Some(graph) => bounds = bounds.union(graph.get_filter_bounds(bounds))
        None => ()
      }
    None => ()
  }
  let canvas = BoundingBox::from_rect(
    0.0,
    0.0,
    ctx.width.to_double(),
    ctx.height.to_double(),
  )
  {
    min_x: max(bounds.min_x, canvas.min_x),
    min_y: max(bounds.min_y, canvas.min_y),
    max_x: min(bounds.max_x, canvas.max_x),
    max_y: min(bounds.max_y, canvas.max_y),
  }
}

///|
fn apply_mask_to_isolated_surface(
  source : RenderSurface,
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  mask : Mask,
  parent_color : Color,
) -> Unit {
  let bbox_local = compute_bounds_without_self_transform(
    node,
    Transform::identity(),
  )
  if bbox_local.is_empty() {
    source.clear()
    return
  }
  let element_transform = parent_transform.multiply(node.transform)
  let mask_surface = resources.surface_pool.acquire(
    source.origin_x,
    source.origin_y,
    source.width,
    source.height,
    SRGB,
  )
  let mask_setter : ColorSink = {
    set: fn(x, y, color) {
      mask_surface.composite_device(x, y, PremulColor16::from_color(color))
    },
  }
  let mask_blend = fn(x : Int, y : Int, color : Color, mode : BlendMode) {
    if mask_surface.contains_device(x, y) {
      mask_surface.set_device(
        x,
        y,
        PremulColor16::from_color(
          blend_with_mode(mask_surface.get_device(x, y).to_color(), color, mode),
        ),
      )
    }
  }
  let base_mask_ctx = {
    ..ctx,
    setter: mask_setter,
    target_image: None,
    blend_pixel: Some(mask_blend),
  }
  let mask_bounds_local = mask.get_mask_bounds(bbox_local)
  let region_clip = ClipPath::with_transform(
    "mask-region",
    Rect(
      x=mask_bounds_local.min_x,
      y=mask_bounds_local.min_y,
      width=mask_bounds_local.width(),
      height=mask_bounds_local.height(),
      rx=0.0,
      ry=0.0,
    ),
    element_transform,
  )
  let mask_ctx = apply_clip_path(
    base_mask_ctx,
    region_clip,
    Transform::identity(),
    BoundingBox::empty(),
    resources,
  )
  let mask_parent = match mask.mask_content_units {
    ObjectBoundingBox => {
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      element_transform.multiply(translate.multiply(scale))
    }
    UserSpaceOnUse => element_transform
  }
  for content_node in mask.content {
    render_node(
      content_node, mask_parent, mask_ctx, resources, true, parent_color,
    )
  }
  for index in 0..<source.pixels.length() {
    let mask_color = mask_surface.pixels[index]
    let factor = match mask.mask_type {
      Alpha => mask_color.a
      Luminance =>
        clamp_channel16(
          round_div_nonnegative(
            mask_color.r.to_int64() * 2126L +
            mask_color.g.to_int64() * 7152L +
            mask_color.b.to_int64() * 722L,
            10000L,
          ),
        )
    }
    source.pixels[index] = source.pixels[index].scaled(factor)
  }
  resources.surface_pool.release(mask_surface)
}

///|
fn composite_surface_to_context(
  surface : RenderSurface,
  ctx : RenderState,
  mode : BlendMode,
) -> Unit {
  for local_y in 0..<surface.height {
    for local_x in 0..<surface.width {
      let color = surface.pixels[local_y * surface.width + local_x]
      if color.a == 0 {
        continue
      }
      let x = surface.origin_x + local_x
      let y = surface.origin_y + local_y
      let visible = match ctx.clip {
        Some(clip) => clip.contains(x, y)
        None => true
      }
      if !visible {
        continue
      }
      let source = color.to_color()
      if mode == Normal {
        ctx.setter.pixel(x, y, source)
      } else {
        match ctx.blend_pixel {
          Some(blend) => blend(x, y, source, mode)
          None =>
            match ctx.target_image {
              Some(target) =>
                target.set_pixel(
                  x,
                  y,
                  blend_with_mode(target.get_pixel(x, y), source, mode),
                )
              None => ctx.setter.pixel(x, y, source)
            }
        }
      }
    }
  }
}

///|
