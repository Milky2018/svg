///|
/// SVG Scene Graph Management
/// Optimized for games and animations with dirty tracking and transform caching

///|
/// Scene represents a renderable SVG scene with optimization support
pub(all) struct Scene {
  root : SVGNode
  mut dirty : Bool
}

///|
/// Create a new scene from a root SVGNode
pub fn Scene::new(root : SVGNode) -> Scene {
  { root, dirty: true }
}

///|
/// Animation manager for coordinating multiple tweens
pub(all) struct AnimationManager {
  tweens : Array[Tween]
}

///|
pub fn AnimationManager::new() -> AnimationManager {
  { tweens: [] }
}

///|
/// Add a new tween animation
pub fn AnimationManager::add(self : AnimationManager, tween : Tween) -> Unit {
  self.tweens.push(tween)
}

///|
/// Create and add a simple translate animation
pub fn AnimationManager::animate_translate(
  self : AnimationManager,
  target_id : String,
  x : Double,
  y : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  self.add(Tween::new(target_id, Translate(x, y), duration, easing))
}

///|
/// Create and add a simple opacity animation
pub fn AnimationManager::animate_opacity(
  self : AnimationManager,
  target_id : String,
  opacity : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  self.add(Tween::new(target_id, Opacity(opacity), duration, easing))
}

///|
/// Create and add a simple scale animation
pub fn AnimationManager::animate_scale(
  self : AnimationManager,
  target_id : String,
  scale : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  self.add(Tween::new(target_id, ScaleUniform(scale), duration, easing))
}

///|
/// Update all animations with delta time
/// Returns true if any animations are still running
pub fn AnimationManager::update(
  self : AnimationManager,
  dt : Double,
  scene : Scene,
) -> Bool {
  let mut any_running = false
  // Update each tween
  for tween in self.tweens {
    if !tween.is_complete() {
      match scene.find_node(tween.target_id) {
        Some(node) => if tween.update(dt, node) { any_running = true }
        None => () // Node not found, skip
      }
    }
  }
  // Mark scene dirty if any animations ran
  if any_running {
    scene.mark_dirty()
  }
  any_running
}

///|
/// Remove completed animations
pub fn AnimationManager::cleanup(self : AnimationManager) -> Unit {
  // Remove completed tweens (iterate backwards to avoid index issues)
  let mut i = self.tweens.length() - 1
  while i >= 0 {
    if self.tweens[i].is_complete() {
      let _ = self.tweens.remove(i)
    }
    i = i - 1
  }
}

///|
/// Check if any animations are running
pub fn AnimationManager::is_animating(self : AnimationManager) -> Bool {
  for tween in self.tweens {
    if !tween.is_complete() {
      return true
    }
  }
  false
}

///|
/// Clear all animations
pub fn AnimationManager::clear(self : AnimationManager) -> Unit {
  self.tweens.clear()
}

///|
/// Create an empty scene with a group root
pub fn Scene::empty() -> Scene {
  Group |> SVGNode::new |> Scene::new
}

///|
/// Mark the scene as dirty (needs re-render)
pub fn Scene::mark_dirty(self : Scene) -> Unit {
  self.dirty = true
}

///|
/// Check if scene needs re-render
pub fn Scene::is_dirty(self : Scene) -> Bool {
  self.dirty
}

///|
/// Clear the dirty flag
pub fn Scene::clear_dirty(self : Scene) -> Unit {
  self.dirty = false
}

///|
/// Get the root node
pub fn Scene::get_root(self : Scene) -> SVGNode {
  self.root
}

///|
/// Update a node by ID (returns true if found and updated)
pub fn Scene::update_node(
  self : Scene,
  id : String,
  updater : (SVGNode) -> SVGNode,
) -> Bool {
  let found = update_node_recursive(self.root, id, updater)
  if found {
    self.mark_dirty()
  }
  found
}

///|
fn update_node_recursive(
  node : SVGNode,
  id : String,
  updater : (SVGNode) -> SVGNode,
) -> Bool {
  if node.id == id {
    let updated = updater(node)
    // Copy updated fields to node (mutation)
    node.shape = updated.shape
    node.transform = updated.transform
    node.view_box = updated.view_box
    node.preserve_aspect_ratio = updated.preserve_aspect_ratio
    node.fill = updated.fill
    node.fill_rule = updated.fill_rule
    node.fill_opacity = updated.fill_opacity
    node.stroke = updated.stroke
    node.stroke_opacity = updated.stroke_opacity
    node.opacity = updated.opacity
    node.blend_mode = updated.blend_mode
    node.isolation = updated.isolation
    node.filters = updated.filters
    node.filter_graph_id = updated.filter_graph_id
    node.mask_id = updated.mask_id
    return true
  }
  for child in node.children {
    if update_node_recursive(child, id, updater) {
      return true
    }
  }
  false
}

///|
/// Find a node by ID
pub fn Scene::find_node(self : Scene, id : String) -> SVGNode? {
  find_node_recursive(self.root, id)
}

///|
fn find_node_recursive(node : SVGNode, id : String) -> SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    match find_node_recursive(child, id) {
      Some(found) => return Some(found)
      None => continue
    }
  }
  None
}

///|
/// Add a child to a node by parent ID
pub fn Scene::add_child(
  self : Scene,
  parent_id : String,
  child : SVGNode,
) -> Bool {
  let found = add_child_recursive(self.root, parent_id, child)
  if found {
    self.mark_dirty()
  }
  found
}

///|
fn add_child_recursive(
  node : SVGNode,
  parent_id : String,
  child : SVGNode,
) -> Bool {
  if node.id == parent_id {
    node.children.push(child)
    return true
  }
  for c in node.children {
    if add_child_recursive(c, parent_id, child) {
      return true
    }
  }
  false
}

///|
/// Remove a node by ID
pub fn Scene::remove_node(self : Scene, id : String) -> Bool {
  let found = remove_node_recursive(self.root, id)
  if found {
    self.mark_dirty()
  }
  found
}

///|
fn remove_node_recursive(node : SVGNode, id : String) -> Bool {
  let mut found_idx : Int? = None
  for i, child in node.children {
    if child.id == id {
      found_idx = Some(i)
      break
    }
  }
  match found_idx {
    Some(idx) => {
      let _ = node.children.remove(idx)
      true
    }
    None => {
      for child in node.children {
        if remove_node_recursive(child, id) {
          return true
        }
      }
      false
    }
  }
}

///|
/// Compute the bounding box of the entire scene
pub fn Scene::get_bounds(self : Scene) -> BoundingBox {
  compute_bounds(self.root, Transform::identity())
}

///|
/// Compute the dirty region (union of all dirty node bounds)
pub fn Scene::get_dirty_region(self : Scene) -> BoundingBox {
  compute_dirty_region(self.root, Transform::identity())
}

///|
fn compute_dirty_region(
  node : SVGNode,
  parent_transform : Transform,
) -> BoundingBox {
  let transform = parent_transform.multiply(node.transform)
  let mut dirty_bbox = BoundingBox::empty()
  // If this node is dirty, include its current and previous bounds
  if node.node_dirty {
    let current_bbox = get_shape_bounds(node.shape)
    if !current_bbox.is_empty() {
      let transformed_bbox = transform.apply_bbox(current_bbox)
      dirty_bbox = dirty_bbox.union(transformed_bbox)
    }
    // Include previous bounds if available
    if node.prev_bounds is Some(prev) {
      dirty_bbox = dirty_bbox.union(prev)
    }
  }
  // Recurse to children
  for child in node.children {
    let child_dirty = compute_dirty_region(child, transform)
    dirty_bbox = dirty_bbox.union(child_dirty)
  }
  dirty_bbox
}

///|
/// Render only nodes that intersect with the dirty region
pub fn Scene::render_dirty(self : Scene, ctx : RenderContext) -> BoundingBox {
  let dirty_region = self.get_dirty_region()
  if dirty_region.is_empty() {
    // Nothing dirty
    return dirty_region
  }
  // Create a clipped render context
  let clip = ClipRect::new(
    dirty_region.min_x.to_int(),
    dirty_region.min_y.to_int(),
    (dirty_region.max_x - dirty_region.min_x).to_int(),
    (dirty_region.max_y - dirty_region.min_y).to_int(),
  )
  let clipped_ctx = {
    ..ctx,
    setter: ctx.setter.with_clip(clip),
    clip: Some(clip),
  }
  let resources = RenderResources::empty()
  let base_transform = match self.root.view_box {
    Some(vb) =>
      vb.get_transform(
        ctx.width.to_double(),
        ctx.height.to_double(),
        self.root.preserve_aspect_ratio,
      )
    None => Transform::identity()
  }
  // Render nodes, update bounds, and clear dirty flags
  render_and_update_dirty(self.root, base_transform, clipped_ctx, resources)
  self.clear_dirty()
  dirty_region
}

///|
fn render_and_update_dirty(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
) -> Unit {
  let transform = parent_transform.multiply(node.transform)
  // Update previous bounds and clear dirty
  let current_bbox = get_shape_bounds(node.shape)
  if !current_bbox.is_empty() {
    node.prev_bounds = Some(transform.apply_bbox(current_bbox))
  }
  node.node_dirty = false
  // Render the node (existing render_node logic will handle clipping)
  render_node(node, parent_transform, ctx, resources, true, Color::black())
  // Note: render_node already recurses into children
}

///|
/// Mark a node and its ancestors as dirty
pub fn Scene::mark_node_dirty(self : Scene, id : String) -> Bool {
  match self.find_node(id) {
    Some(node) => {
      node.mark_dirty()
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
/// Clear all dirty flags in the scene
pub fn Scene::clear_all_dirty(self : Scene) -> Unit {
  clear_dirty_recursive(self.root)
  self.clear_dirty()
}

///|
fn clear_dirty_recursive(node : SVGNode) -> Unit {
  node.node_dirty = false
  for child in node.children {
    clear_dirty_recursive(child)
  }
}

///|
/// Set z_index of a node by ID
pub fn Scene::set_z_index(self : Scene, id : String, z_index : Int) -> Bool {
  match self.find_node(id) {
    Some(node) => {
      node.z_index = z_index
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
/// Bring a node to front (set z_index higher than all siblings)
pub fn Scene::bring_to_front(self : Scene, id : String) -> Bool {
  match find_parent_and_node(self.root, id) {
    Some((parent, node)) => {
      let max_z = get_max_z_index(parent.children)
      node.z_index = max_z + 1
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
/// Send a node to back (set z_index lower than all siblings)
pub fn Scene::send_to_back(self : Scene, id : String) -> Bool {
  match find_parent_and_node(self.root, id) {
    Some((parent, node)) => {
      let min_z = get_min_z_index(parent.children)
      node.z_index = min_z - 1
      self.mark_dirty()
      true
    }
    None => false
  }
}

///|
fn find_parent_and_node(node : SVGNode, id : String) -> (SVGNode, SVGNode)? {
  for child in node.children {
    if child.id == id {
      return Some((node, child))
    }
    match find_parent_and_node(child, id) {
      Some(result) => return Some(result)
      None => continue
    }
  }
  None
}

///|
fn get_max_z_index(nodes : Array[SVGNode]) -> Int {
  if nodes.is_empty() {
    return 0
  }
  let mut max_z = nodes[0].z_index
  for i in 1..<nodes.length() {
    if nodes[i].z_index > max_z {
      max_z = nodes[i].z_index
    }
  }
  max_z
}

///|
fn get_min_z_index(nodes : Array[SVGNode]) -> Int {
  if nodes.is_empty() {
    return 0
  }
  let mut min_z = nodes[0].z_index
  for i in 1..<nodes.length() {
    if nodes[i].z_index < min_z {
      min_z = nodes[i].z_index
    }
  }
  min_z
}

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
pub(all) struct RenderContext {
  setter : PixelSetter
  width : Int
  height : Int
  flatness : Double // For path flattening
  clip : ClipRect? // Optional clipping rectangle for culling
  /// Font callback: (codepoint, font_size) -> (path_commands, advance_width)
  text_to_paths : ((Int, Double) -> (Array[PathCommand], Double))?
  /// Host callback for resolving image references into decoded RGBA pixels.
  image_resolver : ((String) -> Image?)?
  target_image : Image?
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
}

///|
fn RenderResources::empty() -> RenderResources {
  {
    clips: ClipPathRegistry::new(),
    masks: MaskRegistry::new(),
    filter_graphs: FilterGraphRegistry::new(),
    patterns: PatternRegistry::new(),
    gradients: GradientRegistry::new(),
    markers: MarkerRegistry::new(),
    active_patterns: [],
  }
}

///|
/// Render a parsed SVG document with registered resources
pub fn SVGDocument::render(self : SVGDocument, ctx : RenderContext) -> Unit {
  let resources = {
    clips: self.clips,
    masks: self.masks,
    filter_graphs: self.filter_graphs,
    patterns: self.patterns,
    gradients: self.gradients,
    markers: self.markers,
    active_patterns: [],
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
/// Render the scene to a pixel setter
pub fn Scene::render(self : Scene, ctx : RenderContext) -> Unit {
  let resources = RenderResources::empty()
  let base_transform = match self.root.view_box {
    Some(vb) =>
      vb.get_transform(
        ctx.width.to_double(),
        ctx.height.to_double(),
        self.root.preserve_aspect_ratio,
      )
    None => Transform::identity()
  }
  render_node(self.root, base_transform, ctx, resources, true, Color::black())
  self.clear_dirty()
}

///|
/// Render the scene with a camera transform
pub fn Scene::render_with_camera(
  self : Scene,
  ctx : RenderContext,
  camera : Camera,
) -> Unit {
  let camera_transform = camera.get_transform()
  let resources = RenderResources::empty()
  render_node(self.root, camera_transform, ctx, resources, true, Color::black())
  self.clear_dirty()
}

///|
/// Render the scene with viewBox coordinate mapping
pub fn Scene::render_with_viewbox(
  self : Scene,
  ctx : RenderContext,
  viewbox : ViewBox,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Unit {
  let viewbox_transform = viewbox.get_transform(
    ctx.width.to_double(),
    ctx.height.to_double(),
    preserve_aspect_ratio,
  )
  let resources = RenderResources::empty()
  render_node(
    self.root,
    viewbox_transform,
    ctx,
    resources,
    true,
    Color::black(),
  )
  self.clear_dirty()
}

///|
/// Render the scene with both viewBox and camera
pub fn Scene::render_with_viewbox_and_camera(
  self : Scene,
  ctx : RenderContext,
  viewbox : ViewBox,
  preserve_aspect_ratio : PreserveAspectRatio,
  camera : Camera,
) -> Unit {
  let viewbox_transform = viewbox.get_transform(
    ctx.width.to_double(),
    ctx.height.to_double(),
    preserve_aspect_ratio,
  )
  let camera_transform = camera.get_transform()
  // Apply viewBox first, then camera
  let combined = viewbox_transform.multiply(camera_transform)
  let resources = RenderResources::empty()
  render_node(self.root, combined, ctx, resources, true, Color::black())
  self.clear_dirty()
}

///|
/// Check if a bounding box is visible within the render context
fn is_visible(bbox : BoundingBox, ctx : RenderContext) -> Bool {
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
  ctx : RenderContext,
  local_rect : BoundingBox,
  transform : Transform,
) -> RenderContext? {
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
  let setter : PixelSetter = {
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
  Some({ ..ctx, setter, clip: Some(clip) })
}

///|
fn render_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
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
  let needs_image_mask = has_mask && ctx.target_image is Some(_)
  if allow_mask &&
    (
      needs_group_opacity ||
      !node.filters.is_empty() ||
      has_filter_graph ||
      needs_image_mask ||
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
            ClipPathUnits::ObjectBoundingBox =>
              compute_bounds_without_self_transform(node, Transform::identity())
            ClipPathUnits::UserSpaceOnUse => BoundingBox::empty()
          }
          apply_clip_path(ctx, clip, transform, bbox_local)
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
        node.opacity,
      )
    Group => ()
  }
  // Render children sorted by z_index (lower z_index first = back to front)
  let sorted_children = sort_by_z_index(node.children)
  for child in sorted_children {
    render_node(child, transform, ctx_for_node, resources, true, node_color)
  }
}

///|
fn render_isolated_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  parent_color : Color,
) -> Unit {
  let layer = Image::new(ctx.width, ctx.height)
  let layer_ctx = {
    ..ctx,
    setter: make_image_compositing_setter(layer),
    target_image: Some(layer),
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
  let mut result = layer
  for filter in node.filters {
    result = apply_filter(result, filter)
  }
  match node.filter_graph_id {
    Some(id) =>
      match resources.filter_graphs.get(id) {
        Some(graph) =>
          result = evaluate_filter_graph(
            graph,
            result,
            compute_bounds(node, parent_transform),
            ctx.image_resolver,
          )
        None => ()
      }
    None => ()
  }
  match node.mask_id {
    Some(id) =>
      match resources.masks.get(id) {
        Some(mask) =>
          result = apply_mask_to_isolated_layer(
            result, node, parent_transform, ctx, resources, mask, parent_color,
          )
        None => ()
      }
    None => ()
  }
  for y in 0..<result.height {
    for x in 0..<result.width {
      let color = result.get_pixel(x, y)
      if color.a > 0 {
        result.set_pixel(x, y, apply_opacity(color, node.opacity))
      }
    }
  }
  composite_image_to_context(result, ctx, 0, 0, node.blend_mode)
}

///|
fn filter_source_alpha(source : Image) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let alpha = source.get_pixel(x, y).a
      if alpha > 0 {
        result.set_pixel(x, y, Color::rgba(0, 0, 0, alpha))
      }
    }
  }
  result
}

///|
fn resolve_filter_graph_input(
  name : String,
  source : Image,
  source_alpha : Image,
  previous : Image,
  named : Map[String, Image],
) -> Image {
  match name {
    "SourceGraphic" => source
    "SourceAlpha" => source_alpha
    "" => previous
    _ => named.get(name).unwrap_or(Image::new(source.width, source.height))
  }
}

///|
fn offset_filter_image(source : Image, dx : Double, dy : Double) -> Image {
  let result = Image::new(source.width, source.height)
  let offset_x = dx.round().to_int()
  let offset_y = dy.round().to_int()
  for y in 0..<source.height {
    for x in 0..<source.width {
      let color = source.get_pixel(x, y)
      if color.a > 0 {
        result.set_pixel(x + offset_x, y + offset_y, color)
      }
    }
  }
  result
}

///|
fn blur_filter_image_xy(
  source : Image,
  radius_x : Double,
  radius_y : Double,
) -> Image {
  let rx = ceil_to_int(if radius_x < 0.0 { 0.0 } else { radius_x })
  let ry = ceil_to_int(if radius_y < 0.0 { 0.0 } else { radius_y })
  if rx == 0 && ry == 0 {
    return source
  }
  let result = Image::new(source.width, source.height)
  let sample_count = (rx * 2 + 1) * (ry * 2 + 1)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let mut alpha_sum = 0
      let mut red_premultiplied = 0
      let mut green_premultiplied = 0
      let mut blue_premultiplied = 0
      for offset_y in -ry..<=ry {
        for offset_x in -rx..<=rx {
          let color = source.get_pixel(x + offset_x, y + offset_y)
          alpha_sum = alpha_sum + color.a
          red_premultiplied = red_premultiplied + color.r * color.a
          green_premultiplied = green_premultiplied + color.g * color.a
          blue_premultiplied = blue_premultiplied + color.b * color.a
        }
      }
      if alpha_sum > 0 {
        result.set_pixel(
          x,
          y,
          Color::rgba(
            red_premultiplied / alpha_sum,
            green_premultiplied / alpha_sum,
            blue_premultiplied / alpha_sum,
            alpha_sum / sample_count,
          ),
        )
      }
    }
  }
  result
}

///|
fn transfer_filter_value(
  function : ComponentTransferFunction,
  value : Double,
) -> Double {
  match function {
    TransferIdentity => value
    TransferTable(values) => {
      if values.length() == 0 {
        return value
      }
      if values.length() == 1 {
        return clamp_filter_unit(values[0])
      }
      let position = clamp_filter_unit(value) *
        (values.length() - 1).to_double()
      let lower = position.floor().to_int()
      let upper = if lower + 1 < values.length() { lower + 1 } else { lower }
      let fraction = position - lower.to_double()
      clamp_filter_unit(
        values[lower] * (1.0 - fraction) + values[upper] * fraction,
      )
    }
    TransferDiscrete(values) => {
      if values.length() == 0 {
        return value
      }
      let mut index = (clamp_filter_unit(value) * values.length().to_double())
        .floor()
        .to_int()
      if index >= values.length() {
        index = values.length() - 1
      }
      clamp_filter_unit(values[index])
    }
    TransferLinear(slope~, intercept~) =>
      clamp_filter_unit(slope * value + intercept)
    TransferGamma(amplitude~, exponent~, offset~) =>
      clamp_filter_unit(amplitude * @math.pow(value, exponent) + offset)
  }
}

///|
fn component_transfer_filter_image(
  source : Image,
  red : ComponentTransferFunction,
  green : ComponentTransferFunction,
  blue : ComponentTransferFunction,
  alpha : ComponentTransferFunction,
) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let color = source.get_pixel(x, y)
      result.set_pixel(
        x,
        y,
        Color::rgba(
          (transfer_filter_value(red, color.r.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
          (transfer_filter_value(green, color.g.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
          (transfer_filter_value(blue, color.b.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
          (transfer_filter_value(alpha, color.a.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
        ),
      )
    }
  }
  result
}

///|
fn morphology_filter_image(
  source : Image,
  radius_x : Double,
  radius_y : Double,
  operator : MorphologyOperator,
) -> Image {
  let rx = ceil_to_int(if radius_x < 0.0 { 0.0 } else { radius_x })
  let ry = ceil_to_int(if radius_y < 0.0 { 0.0 } else { radius_y })
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let initial = if operator == MorphologyDilate { 0 } else { 255 }
      let mut r = initial
      let mut g = initial
      let mut b = initial
      let mut a = initial
      for offset_y in -ry..<=ry {
        for offset_x in -rx..<=rx {
          let color = source.get_pixel(x + offset_x, y + offset_y)
          if operator == MorphologyDilate {
            r = if r > color.r { r } else { color.r }
            g = if g > color.g { g } else { color.g }
            b = if b > color.b { b } else { color.b }
            a = if a > color.a { a } else { color.a }
          } else {
            r = if r < color.r { r } else { color.r }
            g = if g < color.g { g } else { color.g }
            b = if b < color.b { b } else { color.b }
            a = if a < color.a { a } else { color.a }
          }
        }
      }
      result.set_pixel(x, y, Color::rgba(r, g, b, a))
    }
  }
  result
}

///|
fn convolve_sample(
  source : Image,
  x : Int,
  y : Int,
  edge_mode : FilterEdgeMode,
) -> Color {
  if x >= 0 && x < source.width && y >= 0 && y < source.height {
    return source.get_pixel(x, y)
  }
  match edge_mode {
    EdgeNone => Color::transparent()
    EdgeDuplicate => {
      let sample_x = if x < 0 {
        0
      } else if x >= source.width {
        source.width - 1
      } else {
        x
      }
      let sample_y = if y < 0 {
        0
      } else if y >= source.height {
        source.height - 1
      } else {
        y
      }
      source.get_pixel(sample_x, sample_y)
    }
    EdgeWrap => {
      let mut sample_x = x % source.width
      let mut sample_y = y % source.height
      if sample_x < 0 {
        sample_x = sample_x + source.width
      }
      if sample_y < 0 {
        sample_y = sample_y + source.height
      }
      source.get_pixel(sample_x, sample_y)
    }
  }
}

///|
fn convolve_filter_image(
  source : Image,
  order_x : Int,
  order_y : Int,
  kernel : Array[Double],
  divisor : Double,
  bias : Double,
  target_x : Int,
  target_y : Int,
  edge_mode : FilterEdgeMode,
  preserve_alpha : Bool,
) -> Image {
  if order_x <= 0 || order_y <= 0 || kernel.length() != order_x * order_y {
    return source
  }
  let safe_divisor = if divisor.abs() <= 0.000001 { 1.0 } else { divisor }
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let mut red = 0.0
      let mut green = 0.0
      let mut blue = 0.0
      let mut alpha = 0.0
      for kernel_y in 0..<order_y {
        for kernel_x in 0..<order_x {
          let sample = convolve_sample(
            source,
            x + kernel_x - target_x,
            y + kernel_y - target_y,
            edge_mode,
          )
          let weight = kernel[(order_y - 1 - kernel_y) * order_x +
            order_x -
            1 -
            kernel_x]
          red = red + sample.r.to_double() * weight
          green = green + sample.g.to_double() * weight
          blue = blue + sample.b.to_double() * weight
          alpha = alpha + sample.a.to_double() * weight
        }
      }
      fn output_channel(value : Double) -> Int {
        (clamp_filter_unit(value / safe_divisor / 255.0 + bias) * 255.0)
        .round()
        .to_int()
      }
      result.set_pixel(
        x,
        y,
        Color::rgba(
          output_channel(red),
          output_channel(green),
          output_channel(blue),
          if preserve_alpha {
            source.get_pixel(x, y).a
          } else {
            output_channel(alpha)
          },
        ),
      )
    }
  }
  result
}

///|
fn filter_channel_value(color : Color, channel : FilterChannel) -> Double {
  match channel {
    ChannelR => color.r.to_double() / 255.0
    ChannelG => color.g.to_double() / 255.0
    ChannelB => color.b.to_double() / 255.0
    ChannelA => color.a.to_double() / 255.0
  }
}

///|
fn displacement_filter_image(
  source : Image,
  displacement : Image,
  scale_x : Double,
  scale_y : Double,
  x_channel : FilterChannel,
  y_channel : FilterChannel,
) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let map_color = displacement.get_pixel(x, y)
      let source_x = x.to_double() +
        scale_x * (filter_channel_value(map_color, x_channel) - 0.5)
      let source_y = y.to_double() +
        scale_y * (filter_channel_value(map_color, y_channel) - 0.5)
      result.set_pixel(
        x,
        y,
        source.get_pixel(source_x.round().to_int(), source_y.round().to_int()),
      )
    }
  }
  result
}

///|
fn smooth_noise_fraction(value : Double) -> Double {
  value * value * (3.0 - 2.0 * value)
}

///|
fn filter_noise_hash(x : Int, y : Int, seed : Double) -> Double {
  let value = @math.sin(
      x.to_double() * 12.9898 + y.to_double() * 78.233 + seed * 37.719,
    ) *
    43758.5453
  let fraction = value - value.floor()
  if fraction < 0.0 {
    fraction + 1.0
  } else {
    fraction
  }
}

///|
fn filter_value_noise(x : Double, y : Double, seed : Double) -> Double {
  let x0 = x.floor().to_int()
  let y0 = y.floor().to_int()
  let tx = smooth_noise_fraction(x - x0.to_double())
  let ty = smooth_noise_fraction(y - y0.to_double())
  let top = filter_noise_hash(x0, y0, seed) * (1.0 - tx) +
    filter_noise_hash(x0 + 1, y0, seed) * tx
  let bottom = filter_noise_hash(x0, y0 + 1, seed) * (1.0 - tx) +
    filter_noise_hash(x0 + 1, y0 + 1, seed) * tx
  top * (1.0 - ty) + bottom * ty
}

///|
fn turbulence_filter_image(
  width : Int,
  height : Int,
  base_x : Double,
  base_y : Double,
  octaves : Int,
  seed : Double,
  fractal_noise : Bool,
) -> Image {
  let result = Image::new(width, height)
  let octave_count = if octaves < 1 {
    1
  } else if octaves > 8 {
    8
  } else {
    octaves
  }
  for y in 0..<height {
    for x in 0..<width {
      let mut sum = 0.0
      let mut weight_sum = 0.0
      let mut frequency = 1.0
      let mut weight = 1.0
      for octave in 0..<octave_count {
        let noise = filter_value_noise(
          x.to_double() * base_x * frequency,
          y.to_double() * base_y * frequency,
          seed + octave.to_double() * 19.0,
        )
        sum = sum +
          (if fractal_noise {
            noise * 2.0 - 1.0
          } else {
            (noise * 2.0 - 1.0).abs()
          }) *
          weight
        weight_sum = weight_sum + weight
        frequency = frequency * 2.0
        weight = weight * 0.5
      }
      let unit = if fractal_noise {
        clamp_filter_unit(0.5 + sum / weight_sum * 0.5)
      } else {
        clamp_filter_unit(sum / weight_sum)
      }
      let byte = (unit * 255.0).round().to_int()
      result.set_pixel(x, y, Color::rgba(byte, byte, byte, 255))
    }
  }
  result
}

///|
fn tile_filter_image(source : Image) -> Image {
  let mut min_x = source.width
  let mut min_y = source.height
  let mut max_x = -1
  let mut max_y = -1
  for y in 0..<source.height {
    for x in 0..<source.width {
      if source.get_pixel(x, y).a > 0 {
        min_x = if min_x < x { min_x } else { x }
        min_y = if min_y < y { min_y } else { y }
        max_x = if max_x > x { max_x } else { x }
        max_y = if max_y > y { max_y } else { y }
      }
    }
  }
  if max_x < min_x || max_y < min_y {
    return Image::new(source.width, source.height)
  }
  let tile_width = max_x - min_x + 1
  let tile_height = max_y - min_y + 1
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let sample_x = min_x +
        ((x - min_x) % tile_width + tile_width) % tile_width
      let sample_y = min_y +
        ((y - min_y) % tile_height + tile_height) % tile_height
      result.set_pixel(x, y, source.get_pixel(sample_x, sample_y))
    }
  }
  result
}

///|
fn filter_image_resource(
  width : Int,
  height : Int,
  href : String,
  x : Double,
  y : Double,
  target_width : Double,
  target_height : Double,
  resolver : ((String) -> Image?)?,
) -> Image {
  let result = Image::new(width, height)
  let resource = match resolver {
    Some(resolve) => resolve(href)
    None => None
  }
  match resource {
    Some(image) => {
      let output_width = if target_width > 0.0 {
        target_width
      } else {
        image.width.to_double()
      }
      let output_height = if target_height > 0.0 {
        target_height
      } else {
        image.height.to_double()
      }
      let min_x = floor_to_int(x)
      let min_y = floor_to_int(y)
      let max_x = ceil_to_int(x + output_width)
      let max_y = ceil_to_int(y + output_height)
      for py in min_y..<max_y {
        for px in min_x..<max_x {
          let source_x = floor_to_int(
            (px.to_double() + 0.5 - x) / output_width * image.width.to_double(),
          )
          let source_y = floor_to_int(
            (py.to_double() + 0.5 - y) /
            output_height *
            image.height.to_double(),
          )
          result.set_pixel(px, py, image.get_pixel(source_x, source_y))
        }
      }
    }
    None => ()
  }
  result
}

///|
fn normalize_filter_vector(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  let length = (x * x + y * y + z * z).sqrt()
  if length <= 0.000001 {
    (0.0, 0.0, 1.0)
  } else {
    (x / length, y / length, z / length)
  }
}

///|
fn filter_light_vector(
  light : FilterLight,
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double, Double) {
  match light {
    DistantLight(azimuth~, elevation~) => {
      let azimuth_radians = degrees_to_radians(azimuth)
      let elevation_radians = degrees_to_radians(elevation)
      (
        @math.cos(azimuth_radians) * @math.cos(elevation_radians),
        @math.sin(azimuth_radians) * @math.cos(elevation_radians),
        @math.sin(elevation_radians),
        1.0,
      )
    }
    PointLight(x=light_x, y=light_y, z=light_z) => {
      let vector = normalize_filter_vector(
        light_x - x,
        light_y - y,
        light_z - z,
      )
      (vector.0, vector.1, vector.2, 1.0)
    }
    SpotLight(
      x=light_x,
      y=light_y,
      z=light_z,
      points_at_x~,
      points_at_y~,
      points_at_z~,
      exponent~,
      limiting_cone_angle~
    ) => {
      let vector = normalize_filter_vector(
        light_x - x,
        light_y - y,
        light_z - z,
      )
      let spot_direction = normalize_filter_vector(
        points_at_x - light_x,
        points_at_y - light_y,
        points_at_z - light_z,
      )
      let from_light = (-vector.0, -vector.1, -vector.2)
      let cosine = max(
        0.0,
        from_light.0 * spot_direction.0 +
        from_light.1 * spot_direction.1 +
        from_light.2 * spot_direction.2,
      )
      let inside_cone = match limiting_cone_angle {
        Some(angle) => cosine >= @math.cos(degrees_to_radians(angle))
        None => true
      }
      let attenuation = if inside_cone {
        @math.pow(cosine, exponent)
      } else {
        0.0
      }
      (vector.0, vector.1, vector.2, attenuation)
    }
  }
}

///|
fn lighting_filter_image(
  source : Image,
  surface_scale : Double,
  constant : Double,
  exponent : Double,
  lighting_color : Color,
  light : FilterLight,
  specular : Bool,
) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let height = source.get_pixel(x, y).a.to_double() / 255.0 * surface_scale
      let dx = (
          source.get_pixel(x + 1, y).a.to_double() -
          source.get_pixel(x - 1, y).a.to_double()
        ) /
        510.0 *
        surface_scale
      let dy = (
          source.get_pixel(x, y + 1).a.to_double() -
          source.get_pixel(x, y - 1).a.to_double()
        ) /
        510.0 *
        surface_scale
      let normal = normalize_filter_vector(-dx, -dy, 1.0)
      let light_vector = filter_light_vector(
        light,
        x.to_double(),
        y.to_double(),
        height,
      )
      let dot = if specular {
        let half_vector = normalize_filter_vector(
          light_vector.0,
          light_vector.1,
          light_vector.2 + 1.0,
        )
        max(
          0.0,
          normal.0 * half_vector.0 +
          normal.1 * half_vector.1 +
          normal.2 * half_vector.2,
        )
      } else {
        max(
          0.0,
          normal.0 * light_vector.0 +
          normal.1 * light_vector.1 +
          normal.2 * light_vector.2,
        )
      }
      let intensity = clamp_filter_unit(
        constant *
        (if specular { @math.pow(dot, exponent) } else { dot }) *
        light_vector.3,
      )
      let red = (lighting_color.r.to_double() * intensity).round().to_int()
      let green = (lighting_color.g.to_double() * intensity).round().to_int()
      let blue = (lighting_color.b.to_double() * intensity).round().to_int()
      let alpha = if specular {
        let red_green = if red > green { red } else { green }
        if red_green > blue {
          red_green
        } else {
          blue
        }
      } else {
        255
      }
      result.set_pixel(x, y, Color::rgba(red, green, blue, alpha))
    }
  }
  result
}

///|
fn filter_primitive_x(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => value * target.width()
    MaskUnits::UserSpaceOnUse => value
  }
}

///|
fn filter_primitive_y(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => value * target.height()
    MaskUnits::UserSpaceOnUse => value
  }
}

///|
fn filter_primitive_position_x(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => target.min_x + value * target.width()
    MaskUnits::UserSpaceOnUse => value
  }
}

///|
fn filter_primitive_position_y(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => target.min_y + value * target.height()
    MaskUnits::UserSpaceOnUse => value
  }
}

///|
fn resolve_filter_light(
  graph : FilterGraph,
  light : FilterLight,
  target : BoundingBox,
) -> FilterLight {
  match light {
    DistantLight(..) => light
    PointLight(x~, y~, z~) =>
      PointLight(
        x=filter_primitive_position_x(graph, x, target),
        y=filter_primitive_position_y(graph, y, target),
        z=filter_primitive_x(graph, z, target),
      )
    SpotLight(
      x~,
      y~,
      z~,
      points_at_x~,
      points_at_y~,
      points_at_z~,
      exponent~,
      limiting_cone_angle~
    ) =>
      SpotLight(
        x=filter_primitive_position_x(graph, x, target),
        y=filter_primitive_position_y(graph, y, target),
        z=filter_primitive_x(graph, z, target),
        points_at_x=filter_primitive_position_x(graph, points_at_x, target),
        points_at_y=filter_primitive_position_y(graph, points_at_y, target),
        points_at_z=filter_primitive_x(graph, points_at_z, target),
        exponent~,
        limiting_cone_angle~,
      )
  }
}

///|
fn clamp_filter_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn composite_filter_pixel(
  source : Color,
  backdrop : Color,
  operator : FilterCompositeOperator,
  k1 : Double,
  k2 : Double,
  k3 : Double,
  k4 : Double,
) -> Color {
  let source_alpha = source.a.to_double() / 255.0
  let backdrop_alpha = backdrop.a.to_double() / 255.0
  let (source_factor, backdrop_factor) = match operator {
    CompositeOver => (1.0, 1.0 - source_alpha)
    CompositeIn => (backdrop_alpha, 0.0)
    CompositeOut => (1.0 - backdrop_alpha, 0.0)
    CompositeAtop => (backdrop_alpha, 1.0 - source_alpha)
    CompositeXor => (1.0 - backdrop_alpha, 1.0 - source_alpha)
    CompositeArithmetic => (0.0, 0.0)
  }
  let output_alpha = if operator == CompositeArithmetic {
    clamp_filter_unit(
      k1 * source_alpha * backdrop_alpha +
      k2 * source_alpha +
      k3 * backdrop_alpha +
      k4,
    )
  } else {
    clamp_filter_unit(
      source_alpha * source_factor + backdrop_alpha * backdrop_factor,
    )
  }
  if output_alpha <= 0.0 {
    return Color::transparent()
  }
  fn channel(source_channel : Int, backdrop_channel : Int) -> Int {
    let source_premultiplied = source_channel.to_double() / 255.0 * source_alpha
    let backdrop_premultiplied = backdrop_channel.to_double() /
      255.0 *
      backdrop_alpha
    let output_premultiplied = if operator == CompositeArithmetic {
      clamp_filter_unit(
        k1 * source_premultiplied * backdrop_premultiplied +
        k2 * source_premultiplied +
        k3 * backdrop_premultiplied +
        k4,
      )
    } else {
      source_premultiplied * source_factor +
      backdrop_premultiplied * backdrop_factor
    }
    (clamp_filter_unit(output_premultiplied / output_alpha) * 255.0)
    .round()
    .to_int()
  }
  Color::rgba(
    channel(source.r, backdrop.r),
    channel(source.g, backdrop.g),
    channel(source.b, backdrop.b),
    (output_alpha * 255.0).round().to_int(),
  )
}

///|
fn composite_filter_images(
  source : Image,
  backdrop : Image,
  operator : FilterCompositeOperator,
  k1 : Double,
  k2 : Double,
  k3 : Double,
  k4 : Double,
) -> Image {
  let width = if source.width < backdrop.width {
    source.width
  } else {
    backdrop.width
  }
  let height = if source.height < backdrop.height {
    source.height
  } else {
    backdrop.height
  }
  let result = Image::new(width, height)
  for y in 0..<height {
    for x in 0..<width {
      result.set_pixel(
        x,
        y,
        composite_filter_pixel(
          source.get_pixel(x, y),
          backdrop.get_pixel(x, y),
          operator,
          k1,
          k2,
          k3,
          k4,
        ),
      )
    }
  }
  result
}

///|
fn clip_filter_result(result : Image, bounds : BoundingBox) -> Image {
  let min_x = floor_to_int(bounds.min_x)
  let min_y = floor_to_int(bounds.min_y)
  let max_x = ceil_to_int(bounds.max_x)
  let max_y = ceil_to_int(bounds.max_y)
  for y in 0..<result.height {
    for x in 0..<result.width {
      if x < min_x || x >= max_x || y < min_y || y >= max_y {
        result.set_pixel(x, y, Color::transparent())
      }
    }
  }
  result
}

///|
fn evaluate_filter_graph(
  graph : FilterGraph,
  source : Image,
  target_bounds : BoundingBox,
  image_resolver : ((String) -> Image?)?,
) -> Image {
  let source_alpha = filter_source_alpha(source)
  let named : Map[String, Image] = Map([])
  let mut previous = source
  for primitive in graph.primitives {
    let (output, result_name) = match primitive {
      GraphColorMatrix(input~, result~, matrix~) =>
        (
          apply_filter(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            ColorMatrix(matrix),
          ),
          result,
        )
      GraphGaussianBlur(input~, result~, radius_x~, radius_y~) =>
        (
          blur_filter_image_xy(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, radius_x, target_bounds),
            filter_primitive_y(graph, radius_y, target_bounds),
          ),
          result,
        )
      GraphOffset(input~, result~, dx~, dy~) =>
        (
          offset_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, dx, target_bounds),
            filter_primitive_y(graph, dy, target_bounds),
          ),
          result,
        )
      GraphBlend(input~, input2~, result~, mode~) =>
        (
          blend_images(
            resolve_filter_graph_input(
              input2, source, source_alpha, previous, named,
            ),
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            mode,
          ),
          result,
        )
      GraphComposite(input~, input2~, result~, operator~, k1~, k2~, k3~, k4~) =>
        (
          composite_filter_images(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            resolve_filter_graph_input(
              input2, source, source_alpha, previous, named,
            ),
            operator,
            k1,
            k2,
            k3,
            k4,
          ),
          result,
        )
      GraphFlood(result~, color~) =>
        (Image::filled(source.width, source.height, color), result)
      GraphMerge(result~, inputs~) => {
        let mut merged = Image::new(source.width, source.height)
        for input in inputs {
          merged = blend_images(
            merged,
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            Normal,
          )
        }
        (merged, result)
      }
      GraphComponentTransfer(input~, result~, red~, green~, blue~, alpha~) =>
        (
          component_transfer_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            red,
            green,
            blue,
            alpha,
          ),
          result,
        )
      GraphMorphology(input~, result~, radius_x~, radius_y~, operator~) =>
        (
          morphology_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, radius_x, target_bounds),
            filter_primitive_y(graph, radius_y, target_bounds),
            operator,
          ),
          result,
        )
      GraphConvolveMatrix(
        input~,
        result~,
        order_x~,
        order_y~,
        kernel~,
        divisor~,
        bias~,
        target_x~,
        target_y~,
        edge_mode~,
        preserve_alpha~
      ) =>
        (
          convolve_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            order_x,
            order_y,
            kernel,
            divisor,
            bias,
            target_x,
            target_y,
            edge_mode,
            preserve_alpha,
          ),
          result,
        )
      GraphDisplacementMap(
        input~,
        input2~,
        result~,
        scale~,
        x_channel~,
        y_channel~
      ) =>
        (
          displacement_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            resolve_filter_graph_input(
              input2, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, scale, target_bounds),
            filter_primitive_y(graph, scale, target_bounds),
            x_channel,
            y_channel,
          ),
          result,
        )
      GraphTurbulence(
        result~,
        base_x~,
        base_y~,
        octaves~,
        seed~,
        stitch=_,
        fractal_noise~
      ) => {
        let frequency_x = match graph.primitive_units {
          MaskUnits::ObjectBoundingBox =>
            if target_bounds.width() <= 0.0 {
              0.0
            } else {
              base_x / target_bounds.width()
            }
          MaskUnits::UserSpaceOnUse => base_x
        }
        let frequency_y = match graph.primitive_units {
          MaskUnits::ObjectBoundingBox =>
            if target_bounds.height() <= 0.0 {
              0.0
            } else {
              base_y / target_bounds.height()
            }
          MaskUnits::UserSpaceOnUse => base_y
        }
        (
          turbulence_filter_image(
            source.width,
            source.height,
            frequency_x,
            frequency_y,
            octaves,
            seed,
            fractal_noise,
          ),
          result,
        )
      }
      GraphTile(input~, result~) =>
        (
          tile_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
          ),
          result,
        )
      GraphImage(result~, href~, x~, y~, width~, height~) =>
        (
          filter_image_resource(
            source.width,
            source.height,
            href,
            filter_primitive_position_x(graph, x, target_bounds),
            filter_primitive_position_y(graph, y, target_bounds),
            filter_primitive_x(graph, width, target_bounds),
            filter_primitive_y(graph, height, target_bounds),
            image_resolver,
          ),
          result,
        )
      GraphDiffuseLighting(
        input~,
        result~,
        surface_scale~,
        diffuse_constant~,
        color~,
        light~
      ) =>
        (
          lighting_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_y(graph, surface_scale, target_bounds),
            diffuse_constant,
            1.0,
            color,
            resolve_filter_light(graph, light, target_bounds),
            false,
          ),
          result,
        )
      GraphSpecularLighting(
        input~,
        result~,
        surface_scale~,
        specular_constant~,
        specular_exponent~,
        color~,
        light~
      ) =>
        (
          lighting_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_y(graph, surface_scale, target_bounds),
            specular_constant,
            specular_exponent,
            color,
            resolve_filter_light(graph, light, target_bounds),
            true,
          ),
          result,
        )
    }
    previous = output
    if result_name.length() > 0 {
      named.set(result_name, output)
    }
  }
  clip_filter_result(previous, graph.get_filter_bounds(target_bounds))
}

///|
fn apply_mask_to_isolated_layer(
  source : Image,
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  mask : Mask,
  parent_color : Color,
) -> Image {
  let bbox_local = compute_bounds_without_self_transform(
    node,
    Transform::identity(),
  )
  if bbox_local.is_empty() {
    return Image::new(source.width, source.height)
  }
  let element_transform = parent_transform.multiply(node.transform)
  let mask_image = Image::new(source.width, source.height)
  let base_mask_ctx = {
    ..ctx,
    setter: make_image_compositing_setter(mask_image),
    target_image: Some(mask_image),
  }
  let mask_bounds_local = mask.get_mask_bounds(bbox_local)
  let mask_ctx = match
    apply_transformed_rect_clip(
      base_mask_ctx, mask_bounds_local, element_transform,
    ) {
    Some(clipped) => clipped
    None => return Image::new(source.width, source.height)
  }
  let mask_parent = match mask.mask_content_units {
    MaskUnits::ObjectBoundingBox => {
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      element_transform.multiply(translate.multiply(scale))
    }
    MaskUnits::UserSpaceOnUse => element_transform
  }
  for content_node in mask.content {
    render_node(
      content_node, mask_parent, mask_ctx, resources, true, parent_color,
    )
  }
  apply_mask_to_image(source, mask_image, mask.mask_type)
}

///|
fn apply_clip_path(
  ctx : RenderContext,
  clip : ClipPath,
  element_transform : Transform,
  bbox_local : BoundingBox,
) -> RenderContext {
  let base_transform = match clip.units {
    ClipPathUnits::UserSpaceOnUse => element_transform
    ClipPathUnits::ObjectBoundingBox => {
      if bbox_local.is_empty() {
        return ctx
      }
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      element_transform.multiply(translate.multiply(scale))
    }
  }
  let combined = base_transform.multiply(clip.transform)
  let clip = ClipPath::{
    id: clip.id,
    shape: clip.shape,
    content: clip.content,
    transform: combined,
    clip_rule: clip.clip_rule,
    units: clip.units,
  }
  let inner = ctx.setter
  let setter : PixelSetter = {
    set: fn(x, y, color) {
      let px = x.to_double() + 0.5
      let py = y.to_double() + 0.5
      if clip.contains(px, py) {
        inner.pixel(x, y, color)
      }
    },
  }
  { ..ctx, setter, }
}

///|
fn render_masked_node(
  node : SVGNode,
  parent_transform : Transform,
  ctx : RenderContext,
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
    MaskUnits::ObjectBoundingBox => {
      let scale = Transform::scale(bbox_local.width(), bbox_local.height())
      let translate = Transform::translate(bbox_local.min_x, bbox_local.min_y)
      let object_transform = element_transform.multiply(
        translate.multiply(scale),
      )
      offset.multiply(object_transform)
    }
    MaskUnits::UserSpaceOnUse => offset.multiply(element_transform)
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
  parent : RenderContext,
) -> RenderContext {
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
  }
}

///|
fn make_image_compositing_setter(image : Image) -> PixelSetter {
  {
    set: fn(x, y, source) {
      let backdrop = image.get_pixel(x, y)
      image.set_pixel(x, y, blend_colors(backdrop, source))
    },
  }
}

///|
fn composite_image_to_context(
  image : Image,
  ctx : RenderContext,
  offset_x : Int,
  offset_y : Int,
  mode : BlendMode,
) -> Unit {
  if mode == Normal {
    blit_image_to_context(image, ctx, offset_x, offset_y)
    return
  }
  match ctx.target_image {
    Some(target) =>
      for y in 0..<image.height {
        for x in 0..<image.width {
          let source = image.get_pixel(x, y)
          if source.a > 0 {
            let tx = x + offset_x
            let ty = y + offset_y
            let visible = match ctx.clip {
              Some(clip) => clip.contains(tx, ty)
              None => true
            }
            if visible {
              target.set_pixel(
                tx,
                ty,
                blend_with_mode(target.get_pixel(tx, ty), source, mode),
              )
            }
          }
        }
      }
    None => blit_image_to_context(image, ctx, offset_x, offset_y)
  }
}

///|
fn blit_image_to_context(
  image : Image,
  ctx : RenderContext,
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
/// Sort nodes by z_index (ascending order: lower z_index drawn first)
fn sort_by_z_index(nodes : Array[SVGNode]) -> Array[SVGNode] {
  if nodes.length() <= 1 {
    return nodes
  }
  // Simple insertion sort (good for small arrays, stable)
  let result = nodes.copy()
  for i in 1..<result.length() {
    let current = result[i]
    let mut j = i - 1
    while j >= 0 && result[j].z_index > current.z_index {
      result[j + 1] = result[j]
      j = j - 1
    }
    result[j + 1] = current
  }
  result
}

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
fn node_uses_paint_server(
  node : SVGNode,
  node_color : Color,
  resources : RenderResources,
) -> Bool {
  fn is_server(paint : ResolvedPaint) -> Bool {
    match paint {
      ResolvedPaint::LinearGrad(_)
      | ResolvedPaint::RadialGrad(_)
      | ResolvedPaint::Pattern(_) => true
      _ => false
    }
  }

  is_server(resolve_paint_for_render(node.fill, node_color, resources)) ||
  is_server(resolve_paint_for_render(node.stroke.paint, node_color, resources))
}

///|
fn node_has_rendered_stroke(
  node : SVGNode,
  node_color : Color,
  resources : RenderResources,
) -> Bool {
  if node.stroke.width <= 0.0 || node.stroke_opacity <= 0.0 {
    return false
  }
  match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
    ResolvedPaint::None => false
    _ => true
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
  ctx : RenderContext,
  resources : RenderResources,
) -> PatternTile? {
  if string_array_contains(resources.active_patterns, pattern.id) {
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
  if ctx.width > 0 && pixel_width > ctx.width {
    pixel_width = ctx.width
  }
  if ctx.height > 0 && pixel_height > ctx.height {
    pixel_height = ctx.height
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
  for child in sort_by_z_index(pattern.content) {
    render_node(
      child,
      content_transform,
      tile_ctx,
      nested_resources,
      true,
      Color::black(),
    )
  }
  Some({ image, x: tile_x, y: tile_y, width: tile_width, height: tile_height })
}

///|
fn make_pattern_setter(
  pattern : Pattern,
  bbox : BoundingBox,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  opacity : Double,
) -> PixelSetter? {
  let tile = match
    build_pattern_tile(pattern, bbox, transform, ctx, resources) {
    Some(value) => value
    None => return None
  }
  let inverse = transform.inverse()
  let pattern_inverse = pattern.transform.inverse()
  Some({
    set: (x, y, _color) => {
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
      let sample_x = (u * tile.image.width.to_double()).floor().to_int()
      let sample_y = (v * tile.image.height.to_double()).floor().to_int()
      let color = tile.image.get_pixel(sample_x, sample_y)
      if color.a > 0 {
        ctx.setter.pixel(x, y, apply_opacity(color, opacity))
      }
    },
  })
}

///|
fn build_substring_local(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  let len = s.length()
  while i < end && i < len {
    buf.write_char(Int::unsafe_to_char(s[i].to_int()))
    i = i + 1
  }
  buf.to_string()
}

///|
fn string_ends_with_local(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    return false
  }
  let start = s.length() - suffix.length()
  for i in 0..<suffix.length() {
    if s[start + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
fn trim_string_local(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = Int::unsafe_to_char(s[start].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = Int::unsafe_to_char(s[end - 1].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  build_substring_local(s, start, end)
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn char_at(s : String, i : Int) -> Char {
  Int::unsafe_to_char(s[i].to_int())
}

///|
fn parse_simple_number(s : String) -> Double {
  let s = trim_string_local(s)
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  let first = char_at(s, i)
  if first == '-' {
    sign = -1.0
    i = i + 1
  } else if first == '+' {
    i = i + 1
  }
  while i < len {
    let c = char_at(s, i)
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  if i < len && char_at(s, i) == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let c = char_at(s, i)
      if c >= '0' && c <= '9' {
        result = result + (c.to_int() - 48).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  sign * result
}

///|
fn parse_length_simple(s : String) -> Double {
  let s = trim_string_local(s)
  let cleaned = if string_ends_with_local(s, "px") {
    build_substring_local(s, 0, s.length() - 2)
  } else if string_ends_with_local(s, "em") || string_ends_with_local(s, "pt") {
    build_substring_local(s, 0, s.length() - 2)
  } else if string_ends_with_local(s, "%") {
    build_substring_local(s, 0, s.length() - 1)
  } else {
    s
  }
  parse_simple_number(cleaned)
}

///|
fn replace_viewport_units(value : String, vw : Double, vh : Double) -> String {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c = char_at(value, i)
    let is_number_start = (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' ||
      c == '+'
    if is_number_start {
      let start = i
      i = i + 1
      while i < len {
        let nc = char_at(value, i)
        if (nc >= '0' && nc <= '9') || nc == '.' {
          i = i + 1
        } else {
          break
        }
      }
      let num_str = build_substring_local(value, start, i)
      if i + 1 < len && char_at(value, i) == 'v' {
        let unit = char_at(value, i + 1)
        if unit == 'w' || unit == 'h' {
          let num = parse_simple_number(num_str)
          let val = if unit == 'w' {
            num * vw / 100.0
          } else {
            num * vh / 100.0
          }
          buf.write_string(val.to_string())
          i = i + 2
          continue
        }
      }
      buf.write_string(num_str)
      continue
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
fn match_at(s : String, idx : Int, pat : String) -> Bool {
  if idx + pat.length() > s.length() {
    return false
  }
  for i in 0..<pat.length() {
    if s[idx + i] != pat[i] {
      return false
    }
  }
  true
}

///|
fn find_attr_value(svg : String, name : String) -> String? {
  let len = svg.length()
  let mut end = len
  for i in 0..<len {
    if char_at(svg, i) == '>' {
      end = i
      break
    }
  }
  let mut i = 0
  while i < end {
    if match_at(svg, i, name) {
      let mut j = i + name.length()
      while j < end && is_space_char(char_at(svg, j)) {
        j = j + 1
      }
      if j < end && char_at(svg, j) == '=' {
        j = j + 1
        while j < end && is_space_char(char_at(svg, j)) {
          j = j + 1
        }
        if j >= end {
          return None
        }
        let quote = char_at(svg, j)
        if quote == '"' || quote == '\'' {
          j = j + 1
          let start = j
          while j < end && char_at(svg, j) != quote {
            j = j + 1
          }
          if j > start {
            return Some(build_substring_local(svg, start, j))
          }
          return None
        } else {
          let start = j
          while j < end &&
                !is_space_char(char_at(svg, j)) &&
                char_at(svg, j) != '>' {
            j = j + 1
          }
          if j > start {
            return Some(build_substring_local(svg, start, j))
          }
          return None
        }
      }
    }
    i = i + 1
  }
  None
}

///|
fn extract_svg_size(svg : String) -> (Double, Double) {
  let width = match find_attr_value(svg, "width") {
    Some(v) => parse_length_simple(v)
    None => 0.0
  }
  let height = match find_attr_value(svg, "height") {
    Some(v) => parse_length_simple(v)
    None => 0.0
  }
  (width, height)
}

///|
fn render_image(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  href : String,
  transform : Transform,
  ctx : RenderContext,
  preserve_aspect_ratio : PreserveAspectRatio,
  preserve_aspect_ratio_is_set : Bool,
  opacity : Double,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  if href.length() == 0 {
    return
  }
  let embedded_svg = match decode_data_svg(href) {
    Some(svg) => Some(svg)
    None => {
      let trimmed = trim_string(href)
      if string_starts_with(trimmed, "<svg") {
        Some(trimmed)
      } else {
        None
      }
    }
  }
  match embedded_svg {
    Some(svg) =>
      render_embedded_svg_image(
        svg, x, y, width, height, transform, ctx, preserve_aspect_ratio, preserve_aspect_ratio_is_set,
        opacity,
      )
    None =>
      match ctx.image_resolver {
        Some(resolve) =>
          match resolve(href) {
            Some(image) =>
              render_raster_image(
                image, x, y, width, height, transform, ctx, preserve_aspect_ratio,
                opacity,
              )
            None => ()
          }
        None => ()
      }
  }
}

///|
fn render_embedded_svg_image(
  svg : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  transform : Transform,
  ctx : RenderContext,
  preserve_aspect_ratio : PreserveAspectRatio,
  preserve_aspect_ratio_is_set : Bool,
  opacity : Double,
) -> Unit {
  let image_width = ceil_to_int(width)
  let image_height = ceil_to_int(height)
  if image_width <= 0 || image_height <= 0 {
    return
  }
  let processed = replace_viewport_units(
    svg,
    image_width.to_double(),
    image_height.to_double(),
  )
  match parse_svg_document(processed) {
    Some(doc) => {
      if preserve_aspect_ratio_is_set {
        doc.root.preserve_aspect_ratio = preserve_aspect_ratio
      }
      if doc.root.view_box is None {
        let (svg_w, svg_h) = extract_svg_size(processed)
        if svg_w > 0.0 && svg_h > 0.0 {
          doc.root.view_box = Some(ViewBox::{
            min_x: 0.0,
            min_y: 0.0,
            width: svg_w,
            height: svg_h,
          })
        }
      }
      let image = Image::new(image_width, image_height)
      let setter = make_image_compositing_setter(image)
      let image_ctx = {
        ..RenderContext::new(setter, image_width, image_height),
        image_resolver: ctx.image_resolver,
        target_image: Some(image),
      }
      doc.render(image_ctx)
      render_raster_image(
        image,
        x,
        y,
        width,
        height,
        transform,
        ctx,
        PreserveAspectRatio::{ align: None, meet_or_slice: Meet },
        opacity,
      )
    }
    None => ()
  }
}

///|
fn render_raster_image(
  image : Image,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  transform : Transform,
  ctx : RenderContext,
  preserve_aspect_ratio : PreserveAspectRatio,
  opacity : Double,
) -> Unit {
  if image.width <= 0 || image.height <= 0 || !transform.is_invertible() {
    return
  }
  let source_to_viewport = ViewBox::{
    min_x: 0.0,
    min_y: 0.0,
    width: image.width.to_double(),
    height: image.height.to_double(),
  }.get_transform(width, height, preserve_aspect_ratio)
  let source_to_local = Transform::translate(x, y).multiply(source_to_viewport)
  let source_to_device = transform.multiply(source_to_local)
  if !source_to_device.is_invertible() {
    return
  }
  let device_bounds = transform.apply_bbox(
    BoundingBox::from_rect(x, y, width, height),
  )
  let mut min_x = floor_to_int(device_bounds.min_x)
  let mut min_y = floor_to_int(device_bounds.min_y)
  let mut max_x = ceil_to_int(device_bounds.max_x)
  let mut max_y = ceil_to_int(device_bounds.max_y)
  if min_x < 0 {
    min_x = 0
  }
  if min_y < 0 {
    min_y = 0
  }
  if max_x > ctx.width {
    max_x = ctx.width
  }
  if max_y > ctx.height {
    max_y = ctx.height
  }
  let device_to_local = transform.inverse()
  let device_to_source = source_to_device.inverse()
  let setter = match ctx.clip {
    Some(clip) => ctx.setter.with_clip(clip)
    None => ctx.setter
  }
  for py in min_y..<max_y {
    for px in min_x..<max_x {
      let device_x = px.to_double() + 0.5
      let device_y = py.to_double() + 0.5
      let (local_x, local_y) = device_to_local.apply(device_x, device_y)
      if local_x >= x &&
        local_x < x + width &&
        local_y >= y &&
        local_y < y + height {
        let (source_x, source_y) = device_to_source.apply(device_x, device_y)
        if source_x >= 0.0 &&
          source_x < image.width.to_double() &&
          source_y >= 0.0 &&
          source_y < image.height.to_double() {
          let color = image.get_pixel(
            floor_to_int(source_x),
            floor_to_int(source_y),
          )
          if color.a > 0 {
            setter.pixel(px, py, apply_opacity(color, opacity))
          }
        }
      }
    }
  }
}

///|
fn transform_preserves_axes(transform : Transform) -> Bool {
  let epsilon = 0.000000000001
  transform.b.abs() <= epsilon && transform.c.abs() <= epsilon
}

///|
fn transform_preserves_circles(transform : Transform) -> Bool {
  if !transform_preserves_axes(transform) {
    return false
  }
  let epsilon = 0.000000000001
  let (sx, sy) = transform.get_scale()
  (sx - sy).abs() <= epsilon
}

///|
fn rect_path_commands(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
) -> Array[PathCommand] {
  let clamped_rx = min(max(rx, 0.0), width / 2.0)
  let clamped_ry = min(max(ry, 0.0), height / 2.0)
  if clamped_rx <= 0.0 || clamped_ry <= 0.0 {
    return [
      MoveTo(x, y),
      LineTo(x + width, y),
      LineTo(x + width, y + height),
      LineTo(x, y + height),
      ClosePath,
    ]
  }
  [
    MoveTo(x + clamped_rx, y),
    LineTo(x + width - clamped_rx, y),
    ArcTo(clamped_rx, clamped_ry, 0.0, false, true, x + width, y + clamped_ry),
    LineTo(x + width, y + height - clamped_ry),
    ArcTo(
      clamped_rx,
      clamped_ry,
      0.0,
      false,
      true,
      x + width - clamped_rx,
      y + height,
    ),
    LineTo(x + clamped_rx, y + height),
    ArcTo(clamped_rx, clamped_ry, 0.0, false, true, x, y + height - clamped_ry),
    LineTo(x, y + clamped_ry),
    ArcTo(clamped_rx, clamped_ry, 0.0, false, true, x + clamped_rx, y),
    ClosePath,
  ]
}

///|
fn points_path_commands(
  points : Array[(Double, Double)],
  close : Bool,
) -> Array[PathCommand] {
  if points.is_empty() {
    return []
  }
  let commands : Array[PathCommand] = [MoveTo(points[0].0, points[0].1)]
  for i in 1..<points.length() {
    commands.push(LineTo(points[i].0, points[i].1))
  }
  if close {
    commands.push(ClosePath)
  }
  commands
}

///|
fn ellipse_path_commands(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Array[PathCommand] {
  [
    MoveTo(cx + rx, cy),
    ArcTo(rx, ry, 0.0, true, true, cx - rx, cy),
    ArcTo(rx, ry, 0.0, true, true, cx + rx, cy),
    ClosePath,
  ]
}

///|
fn render_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  if node_has_rendered_stroke(node, node_color, resources) ||
    !transform_preserves_axes(transform) ||
    node_uses_paint_server(node, node_color, resources) {
    render_path(
      rect_path_commands(x, y, width, height, rx, ry),
      node,
      transform,
      ctx,
      node_color,
      resources,
    )
    return
  }
  // Transform corners
  let (x0, y0) = transform.apply(x, y)
  let (x1, y1) = transform.apply(x + width, y + height)
  let min_x = min(x0, x1)
  let min_y = min(y0, y1)
  let max_x = max(x0, x1)
  let max_y = max(y0, y1)
  let ix = quantize_geometry(min_x)
  let iy = quantize_geometry(min_y)
  let iw = ceil_to_int(max_x - min_x)
  let ih = ceil_to_int(max_y - min_y)
  if iw <= 0 || ih <= 0 {
    return
  }
  let (sx, sy) = transform.get_scale()
  let irx = (rx * sx).to_int()
  let iry = (ry * sy).to_int()
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          if irx > 0 || iry > 0 {
            raster_rounded_rect_fill(
              ix,
              iy,
              iw,
              ih,
              irx,
              iry,
              fill_color,
              ctx.setter,
            )
          } else {
            raster_rect_fill(ix, iy, iw, ih, fill_color, ctx.setter)
          }
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          let stroke_width = node.stroke.width * (sx + sy) / 2.0
          let stroke_px = if stroke_width > 0.0 {
            ceil_to_int(stroke_width)
          } else {
            0
          }
          if stroke_px > 0 {
            if irx > 0 || iry > 0 {
              raster_rounded_rect_stroke_thick(
                ix,
                iy,
                iw,
                ih,
                irx,
                iry,
                stroke_px,
                stroke_color,
                ctx.setter,
              )
            } else {
              let rect_points = [
                transform.apply(x, y),
                transform.apply(x + width, y),
                transform.apply(x + width, y + height),
                transform.apply(x, y + height),
              ].map(fn(point) {
                (quantize_geometry(point.0), quantize_geometry(point.1))
              })
              raster_normalized_stroke(
                rect_points,
                node.stroke,
                stroke_px,
                stroke_color,
                ctx.setter,
                true,
              )
            }
          }
        }
      _ => ()
    }
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, () => ())
}

///|
fn render_circle(
  cx : Double,
  cy : Double,
  r : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if r <= 0.0 {
    return
  }
  if !transform_preserves_circles(transform) ||
    node_has_rendered_stroke(node, node_color, resources) ||
    node_uses_paint_server(node, node_color, resources) {
    render_path(
      ellipse_path_commands(cx, cy, r, r),
      node,
      transform,
      ctx,
      node_color,
      resources,
    )
    return
  }
  let (tx, ty) = transform.apply(cx, cy)
  let (sx, sy) = transform.get_scale()
  let tr = (r * (sx + sy) / 2.0).to_int()
  if tr <= 0 {
    return
  }
  let icx = quantize_geometry(tx)
  let icy = quantize_geometry(ty)
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_rounded_rect_fill(
            icx - tr,
            icy - tr,
            tr * 2,
            tr * 2,
            tr,
            tr,
            fill_color,
            ctx.setter,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          let stroke_px = ceil_to_int(node.stroke.width * (sx + sy) / 2.0)
          raster_rounded_rect_stroke_thick(
            icx - tr,
            icy - tr,
            tr * 2,
            tr * 2,
            tr,
            tr,
            stroke_px,
            stroke_color,
            ctx.setter,
          )
        }
      _ => ()
    }
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, () => ())
}

///|
fn render_ellipse(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if rx <= 0.0 || ry <= 0.0 {
    return
  }
  if node_has_rendered_stroke(node, node_color, resources) ||
    !transform_preserves_axes(transform) ||
    node_uses_paint_server(node, node_color, resources) {
    render_path(
      ellipse_path_commands(cx, cy, rx, ry),
      node,
      transform,
      ctx,
      node_color,
      resources,
    )
    return
  }
  let (tx, ty) = transform.apply(cx, cy)
  let (sx, sy) = transform.get_scale()
  let trx = (rx * sx).to_int()
  let try_ = (ry * sy).to_int()
  if trx <= 0 || try_ <= 0 {
    return
  }
  let icx = quantize_geometry(tx)
  let icy = quantize_geometry(ty)
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_rounded_rect_fill(
            icx - trx,
            icy - try_,
            trx * 2,
            try_ * 2,
            trx,
            try_,
            fill_color,
            ctx.setter,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          let stroke_px = ceil_to_int(node.stroke.width * (sx + sy) / 2.0)
          raster_rounded_rect_stroke_thick(
            icx - trx,
            icy - try_,
            trx * 2,
            try_ * 2,
            trx,
            try_,
            stroke_px,
            stroke_color,
            ctx.setter,
          )
        }
      _ => ()
    }
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, () => ())
}

///|
fn render_line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_affine_stroke(
            [(x1, y1), (x2, y2)],
            node.stroke,
            transform,
            stroke_color,
            ctx.setter,
            false,
          )
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_linear_shape(
      [(x1, y1), (x2, y2)],
      false,
      node,
      transform,
      ctx,
      resources,
      node_color,
    )
  }

  render_paint_order(node.paint_order, () => (), draw_stroke, draw_markers)
}

///|
fn marker_transform_with_ref_ratio(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  scale : Double,
  ref_ratio : Double,
) -> Transform {
  let orient_angle = match marker.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  let content_transform = match marker.view_box {
    Some(vb) => {
      let view_t = vb.get_transform(
        marker.marker_width,
        marker.marker_height,
        marker.preserve_aspect_ratio,
      )
      let (ref_px, ref_py) = view_t.apply(marker.ref_x, marker.ref_y)
      let ref_t = Transform::translate(-ref_px * ref_ratio, -ref_py * ref_ratio)
      ref_t.multiply(view_t)
    }
    None =>
      Transform::translate(-marker.ref_x * ref_ratio, -marker.ref_y * ref_ratio)
  }
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  t1.multiply(r).multiply(s).multiply(content_transform)
}

///|
fn render_marker_instance(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  let (marker_scale, ref_ratio) = match marker.marker_units {
    StrokeWidth => {
      let scale = node.stroke.width
      if scale > 0.0 {
        (scale, 1.0)
      } else {
        (0.0, 1.0)
      }
    }
    UserSpaceOnUse_ => (1.0, 1.0)
  }
  let marker_transform = marker_transform_with_ref_ratio(
    marker, x, y, angle, marker_scale, ref_ratio,
  )
  let viewport_transform = marker_viewport_transform(
    marker, x, y, angle, marker_scale, ref_ratio,
  )
  let parent_transform = transform.multiply(marker_transform)
  let mut ctx_for_marker = ctx
  if marker.clip_overflow &&
    marker.marker_width > 0.0 &&
    marker.marker_height > 0.0 {
    let viewport_bbox = BoundingBox::from_rect(
      0.0,
      0.0,
      marker.marker_width,
      marker.marker_height,
    )
    let clip_transform = transform.multiply(viewport_transform)
    let clip_shape = Rect(
      x=viewport_bbox.min_x,
      y=viewport_bbox.min_y,
      width=viewport_bbox.width(),
      height=viewport_bbox.height(),
      rx=0.0,
      ry=0.0,
    )
    let clip = ClipPath::with_transform(
      "marker-viewport", clip_shape, clip_transform,
    )
    ctx_for_marker = apply_clip_path(
      ctx_for_marker,
      clip,
      Transform::identity(),
      BoundingBox::empty(),
    )
  }
  render_node(
    marker.content,
    parent_transform,
    ctx_for_marker,
    resources,
    true,
    node_color,
  )
}

///|
fn marker_viewport_transform(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  scale : Double,
  ref_ratio : Double,
) -> Transform {
  let orient_angle = match marker.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  let (ref_px, ref_py) = match marker.view_box {
    Some(vb) => {
      let view_t = vb.get_transform(
        marker.marker_width,
        marker.marker_height,
        marker.preserve_aspect_ratio,
      )
      view_t.apply(marker.ref_x, marker.ref_y)
    }
    None => (marker.ref_x, marker.ref_y)
  }
  let ref_t = Transform::translate(-ref_px * ref_ratio, -ref_py * ref_ratio)
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  t1.multiply(r).multiply(s).multiply(ref_t)
}

///|
fn render_markers_for_linear_shape(
  points : Array[(Double, Double)],
  closed : Bool,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if points.length() == 0 {
    return
  }
  let commands : Array[PathCommand] = [MoveTo(points[0].0, points[0].1)]
  for index in 1..<points.length() {
    commands.push(LineTo(points[index].0, points[index].1))
  }
  if closed {
    commands.push(ClosePath)
  }
  render_markers_for_path_commands(
    commands, node, transform, ctx, resources, node_color,
  )
}

///|
fn normalize_dash_pattern(dasharray : Array[Double]) -> Array[Double] {
  let normalized : Array[Double] = []
  for value in dasharray {
    if value < 0.0 {
      return []
    }
    normalized.push(value)
  }
  if normalized.length() % 2 == 1 {
    for value in dasharray {
      normalized.push(value)
    }
  }
  normalized
}

///|
fn push_distinct_point(points : Array[(Int, Int)], point : (Int, Int)) -> Unit {
  if points.length() == 0 || points[points.length() - 1] != point {
    points.push(point)
  }
}

///|
fn dash_polyline_pieces(
  points : Array[(Int, Int)],
  dasharray : Array[Double],
  dashoffset : Double,
) -> Array[Array[(Int, Int)]] {
  let pieces : Array[Array[(Int, Int)]] = []
  if points.length() < 2 {
    return pieces
  }
  let pattern = normalize_dash_pattern(dasharray)
  if pattern.length() == 0 {
    pieces.push(points)
    return pieces
  }
  let total = pattern.fold(init=0.0, (sum, value) => sum + value)
  if total <= 0.0 {
    return pieces
  }
  let epsilon = 0.000001
  let mut position = -dashoffset
  while position < 0.0 {
    position += total
  }
  while position >= total {
    position -= total
  }
  let mut pattern_index = 0
  while position >= pattern[pattern_index] && pattern[pattern_index] > epsilon {
    position -= pattern[pattern_index]
    pattern_index = (pattern_index + 1) % pattern.length()
  }
  let mut remaining = pattern[pattern_index] - position
  let mut drawing = pattern_index % 2 == 0
  let mut zero_guard = 0
  while remaining <= epsilon && zero_guard < pattern.length() {
    pattern_index = (pattern_index + 1) % pattern.length()
    remaining = pattern[pattern_index]
    drawing = pattern_index % 2 == 0
    zero_guard += 1
  }
  let mut current : Array[(Int, Int)] = []
  for segment_index in 0..<(points.length() - 1) {
    let start = points[segment_index]
    let finish = points[segment_index + 1]
    let dx = (finish.0 - start.0).to_double()
    let dy = (finish.1 - start.1).to_double()
    let length = (dx * dx + dy * dy).sqrt()
    if length <= epsilon {
      continue
    }
    let mut traveled = 0.0
    while traveled < length - epsilon {
      let available = length - traveled
      let step = if remaining < available { remaining } else { available }
      let start_ratio = traveled / length
      let end_ratio = (traveled + step) / length
      let piece_start = (
        quantize_geometry(start.0.to_double() + dx * start_ratio),
        quantize_geometry(start.1.to_double() + dy * start_ratio),
      )
      let piece_end = (
        quantize_geometry(start.0.to_double() + dx * end_ratio),
        quantize_geometry(start.1.to_double() + dy * end_ratio),
      )
      if drawing {
        push_distinct_point(current, piece_start)
        push_distinct_point(current, piece_end)
      }
      traveled += step
      remaining -= step
      if remaining <= epsilon {
        if drawing && current.length() >= 2 {
          pieces.push(current)
          current = []
        }
        pattern_index = (pattern_index + 1) % pattern.length()
        remaining = pattern[pattern_index]
        drawing = pattern_index % 2 == 0
        zero_guard = 0
        while remaining <= epsilon && zero_guard < pattern.length() {
          pattern_index = (pattern_index + 1) % pattern.length()
          remaining = pattern[pattern_index]
          drawing = pattern_index % 2 == 0
          zero_guard += 1
        }
      }
    }
  }
  if drawing && current.length() >= 2 {
    pieces.push(current)
  }
  pieces
}

///|
fn raster_stroke_piece(
  points : Array[(Int, Int)],
  stroke_px : Int,
  linecap : LineCap,
  linejoin : LineJoin,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
  closed : Bool,
) -> Unit {
  if points.length() < 2 || stroke_px <= 0 {
    return
  }
  if stroke_px <= 1 {
    if closed {
      raster_polygon_stroke(points, color, setter)
    } else {
      raster_polyline(points, color, setter)
    }
    return
  }
  let segment_count = if closed { points.length() } else { points.length() - 1 }
  for index in 0..<segment_count {
    let next = if index + 1 == points.length() { 0 } else { index + 1 }
    let start = points[index]
    let finish = points[next]
    if start != finish {
      raster_thick_line(
        start.0,
        start.1,
        finish.0,
        finish.1,
        stroke_px,
        color,
        setter,
      )
    }
  }
  draw_polyline_joins_caps(
    points, stroke_px, linecap, linejoin, miterlimit, color, setter, closed,
  )
}

///|
fn raster_normalized_stroke(
  points : Array[(Int, Int)],
  stroke : StrokeStyle,
  stroke_px : Int,
  color : Color,
  setter : PixelSetter,
  closed : Bool,
) -> Unit {
  match stroke.dasharray {
    Some(dasharray) => {
      let pieces = dash_polyline_pieces(points, dasharray, stroke.dashoffset)
      for piece in pieces {
        raster_stroke_piece(
          piece,
          stroke_px,
          stroke.linecap,
          stroke.linejoin,
          stroke.miterlimit,
          color,
          setter,
          false,
        )
      }
    }
    None =>
      raster_stroke_piece(
        points,
        stroke_px,
        stroke.linecap,
        stroke.linejoin,
        stroke.miterlimit,
        color,
        setter,
        closed,
      )
  }
}

///|
fn push_distinct_local_point(
  points : Array[(Double, Double)],
  point : (Double, Double),
) -> Unit {
  if points.length() == 0 {
    points.push(point)
    return
  }
  let previous = points[points.length() - 1]
  if (previous.0 - point.0).abs() > 0.000001 ||
    (previous.1 - point.1).abs() > 0.000001 {
    points.push(point)
  }
}

///|
fn dash_local_polyline_pieces(
  points : Array[(Double, Double)],
  dasharray : Array[Double],
  dashoffset : Double,
) -> Array[Array[(Double, Double)]] {
  let pieces : Array[Array[(Double, Double)]] = []
  if points.length() < 2 {
    return pieces
  }
  let pattern = normalize_dash_pattern(dasharray)
  if pattern.length() == 0 {
    pieces.push(points)
    return pieces
  }
  let total = pattern.fold(init=0.0, (sum, value) => sum + value)
  if total <= 0.0 {
    return pieces
  }
  let epsilon = 0.000001
  let mut position = -dashoffset
  while position < 0.0 {
    position = position + total
  }
  while position >= total {
    position = position - total
  }
  let mut pattern_index = 0
  while position >= pattern[pattern_index] && pattern[pattern_index] > epsilon {
    position = position - pattern[pattern_index]
    pattern_index = (pattern_index + 1) % pattern.length()
  }
  let mut remaining = pattern[pattern_index] - position
  let mut drawing = pattern_index % 2 == 0
  let mut zero_guard = 0
  while remaining <= epsilon && zero_guard < pattern.length() {
    pattern_index = (pattern_index + 1) % pattern.length()
    remaining = pattern[pattern_index]
    drawing = pattern_index % 2 == 0
    zero_guard = zero_guard + 1
  }
  let mut current : Array[(Double, Double)] = []
  for segment_index in 0..<(points.length() - 1) {
    let start = points[segment_index]
    let finish = points[segment_index + 1]
    let dx = finish.0 - start.0
    let dy = finish.1 - start.1
    let length = (dx * dx + dy * dy).sqrt()
    if length <= epsilon {
      continue
    }
    let mut traveled = 0.0
    while traveled < length - epsilon {
      let available = length - traveled
      let step = if remaining < available { remaining } else { available }
      let start_ratio = traveled / length
      let end_ratio = (traveled + step) / length
      let piece_start = (start.0 + dx * start_ratio, start.1 + dy * start_ratio)
      let piece_end = (start.0 + dx * end_ratio, start.1 + dy * end_ratio)
      if drawing {
        push_distinct_local_point(current, piece_start)
        push_distinct_local_point(current, piece_end)
      }
      traveled = traveled + step
      remaining = remaining - step
      if remaining <= epsilon {
        if drawing && current.length() >= 2 {
          pieces.push(current)
          current = []
        }
        pattern_index = (pattern_index + 1) % pattern.length()
        remaining = pattern[pattern_index]
        drawing = pattern_index % 2 == 0
        zero_guard = 0
        while remaining <= epsilon && zero_guard < pattern.length() {
          pattern_index = (pattern_index + 1) % pattern.length()
          remaining = pattern[pattern_index]
          drawing = pattern_index % 2 == 0
          zero_guard = zero_guard + 1
        }
      }
    }
  }
  if drawing && current.length() >= 2 {
    pieces.push(current)
  }
  pieces
}

///|
fn push_transformed_stroke_polygon(
  outlines : Array[Array[(Int, Int)]],
  local_points : Array[(Double, Double)],
  transform : Transform,
) -> Unit {
  let transformed : Array[(Int, Int)] = []
  for point in local_points {
    let device = transform.apply(point.0, point.1)
    push_distinct_point(
      transformed,
      (quantize_geometry(device.0), quantize_geometry(device.1)),
    )
  }
  if transformed.length() >= 3 && polygon_area_int(transformed) != 0 {
    if polygon_area_int(transformed) > 0 {
      outlines.push(transformed)
    } else {
      let reversed : Array[(Int, Int)] = []
      for index in 0..<transformed.length() {
        reversed.push(transformed[transformed.length() - 1 - index])
      }
      outlines.push(reversed)
    }
  }
}

///|
fn push_affine_stroke_disk(
  outlines : Array[Array[(Int, Int)]],
  center : (Double, Double),
  radius : Double,
  transform : Transform,
) -> Unit {
  let polygon : Array[(Double, Double)] = []
  let segments = 32
  for index in 0..<segments {
    let angle = 6.283185307179586 * index.to_double() / segments.to_double()
    polygon.push(
      (
        center.0 + @math.cos(angle) * radius,
        center.1 + @math.sin(angle) * radius,
      ),
    )
  }
  push_transformed_stroke_polygon(outlines, polygon, transform)
}

///|
fn push_affine_stroke_join(
  outlines : Array[Array[(Int, Int)]],
  previous : (Double, Double),
  vertex : (Double, Double),
  next : (Double, Double),
  half : Double,
  linejoin : LineJoin,
  miterlimit : Double,
  transform : Transform,
) -> Unit {
  let previous_dx = vertex.0 - previous.0
  let previous_dy = vertex.1 - previous.1
  let next_dx = next.0 - vertex.0
  let next_dy = next.1 - vertex.1
  let previous_length = (previous_dx * previous_dx + previous_dy * previous_dy).sqrt()
  let next_length = (next_dx * next_dx + next_dy * next_dy).sqrt()
  if previous_length <= 0.000001 || next_length <= 0.000001 {
    return
  }
  let ux0 = previous_dx / previous_length
  let uy0 = previous_dy / previous_length
  let ux1 = next_dx / next_length
  let uy1 = next_dy / next_length
  let cross = ux0 * uy1 - uy0 * ux1
  if cross.abs() <= 0.000001 {
    return
  }
  match linejoin {
    Round => push_affine_stroke_disk(outlines, vertex, half, transform)
    Bevel | Miter => {
      let side = if cross > 0.0 { -1.0 } else { 1.0 }
      let outer0 = (vertex.0 + side * -uy0 * half, vertex.1 + side * ux0 * half)
      let outer1 = (vertex.0 + side * -uy1 * half, vertex.1 + side * ux1 * half)
      if linejoin == Bevel {
        push_transformed_stroke_polygon(
          outlines,
          [vertex, outer0, outer1],
          transform,
        )
        return
      }
      let denominator = ux0 * uy1 - uy0 * ux1
      let t = ((outer1.0 - outer0.0) * uy1 - (outer1.1 - outer0.1) * ux1) /
        denominator
      let miter = (outer0.0 + t * ux0, outer0.1 + t * uy0)
      let miter_dx = miter.0 - vertex.0
      let miter_dy = miter.1 - vertex.1
      let miter_ratio = (miter_dx * miter_dx + miter_dy * miter_dy).sqrt() /
        half
      let polygon = if miter_ratio <= miterlimit {
        [vertex, outer0, miter, outer1]
      } else {
        [vertex, outer0, outer1]
      }
      push_transformed_stroke_polygon(outlines, polygon, transform)
    }
  }
}

///|
fn append_affine_stroke_piece(
  outlines : Array[Array[(Int, Int)]],
  points : Array[(Double, Double)],
  stroke : StrokeStyle,
  transform : Transform,
  closed : Bool,
) -> Unit {
  if points.length() < 2 || stroke.width <= 0.0 {
    return
  }
  let half = stroke.width / 2.0
  let segment_count = if closed { points.length() } else { points.length() - 1 }
  for index in 0..<segment_count {
    let next_index = if index + 1 == points.length() { 0 } else { index + 1 }
    let start = points[index]
    let finish = points[next_index]
    let dx = finish.0 - start.0
    let dy = finish.1 - start.1
    let length = (dx * dx + dy * dy).sqrt()
    if length <= 0.000001 {
      continue
    }
    let ux = dx / length
    let uy = dy / length
    let start_extension = if !closed && index == 0 && stroke.linecap == Square {
      half
    } else {
      0.0
    }
    let end_extension = if !closed &&
      index == segment_count - 1 &&
      stroke.linecap == Square {
      half
    } else {
      0.0
    }
    let sx = start.0 - ux * start_extension
    let sy = start.1 - uy * start_extension
    let ex = finish.0 + ux * end_extension
    let ey = finish.1 + uy * end_extension
    let nx = -uy * half
    let ny = ux * half
    push_transformed_stroke_polygon(
      outlines,
      [
        (sx + nx, sy + ny),
        (sx - nx, sy - ny),
        (ex - nx, ey - ny),
        (ex + nx, ey + ny),
      ],
      transform,
    )
  }
  if closed {
    for index in 0..<points.length() {
      let previous = if index == 0 {
        points[points.length() - 1]
      } else {
        points[index - 1]
      }
      let next = if index + 1 == points.length() {
        points[0]
      } else {
        points[index + 1]
      }
      push_affine_stroke_join(
        outlines,
        previous,
        points[index],
        next,
        half,
        stroke.linejoin,
        stroke.miterlimit,
        transform,
      )
    }
  } else {
    for index in 1..<(points.length() - 1) {
      push_affine_stroke_join(
        outlines,
        points[index - 1],
        points[index],
        points[index + 1],
        half,
        stroke.linejoin,
        stroke.miterlimit,
        transform,
      )
    }
    if stroke.linecap == Round {
      push_affine_stroke_disk(outlines, points[0], half, transform)
      push_affine_stroke_disk(
        outlines,
        points[points.length() - 1],
        half,
        transform,
      )
    }
  }
}

///|
fn raster_affine_stroke(
  source_points : Array[(Double, Double)],
  stroke : StrokeStyle,
  transform : Transform,
  color : Color,
  setter : PixelSetter,
  closed : Bool,
) -> Unit {
  if source_points.length() < 2 || stroke.width <= 0.0 {
    return
  }
  if transform_preserves_circles(transform) {
    let (scale, _) = transform.get_scale()
    let stroke_px = ceil_to_int(stroke.width * scale)
    if stroke_px <= 1 {
      let device_points = source_points.map(fn(point) {
        let device = transform.apply(point.0, point.1)
        (quantize_geometry(device.0), quantize_geometry(device.1))
      })
      raster_normalized_stroke(
        device_points, stroke, stroke_px, color, setter, closed,
      )
      return
    }
  }
  let points = source_points.copy()
  if closed && points.length() > 1 {
    let first = points[0]
    let last = points[points.length() - 1]
    if (first.0 - last.0).abs() <= 0.000001 &&
      (first.1 - last.1).abs() <= 0.000001 {
      let _ = points.pop()
    }
  }
  let outlines : Array[Array[(Int, Int)]] = []
  match stroke.dasharray {
    Some(dasharray) => {
      let dash_points = if closed {
        let result = points.copy()
        result.push(points[0])
        result
      } else {
        points
      }
      for
        piece in dash_local_polyline_pieces(
          dash_points,
          dasharray,
          stroke.dashoffset,
        ) {
        append_affine_stroke_piece(outlines, piece, stroke, transform, false)
      }
    }
    None =>
      append_affine_stroke_piece(outlines, points, stroke, transform, closed)
  }
  if outlines.length() > 0 {
    raster_polygons_fill_rule(outlines, color, NonZero, setter)
  }
}

///|
priv struct MarkerPoint {
  x : Double
  y : Double
  mut has_in : Bool
  mut in_dx : Double
  mut in_dy : Double
  mut has_out : Bool
  mut out_dx : Double
  mut out_dy : Double
}

///|
fn MarkerPoint::new(x : Double, y : Double) -> MarkerPoint {
  {
    x,
    y,
    has_in: false,
    in_dx: 0.0,
    in_dy: 0.0,
    has_out: false,
    out_dx: 0.0,
    out_dy: 0.0,
  }
}

///|
priv struct MarkerSubpath {
  points : Array[MarkerPoint]
}

///|
fn arc_tangent_at(
  theta : Double,
  cos_phi : Double,
  sin_phi : Double,
  rx : Double,
  ry : Double,
) -> (Double, Double) {
  let sin_t = @math.sin(theta)
  let cos_t = @math.cos(theta)
  let dx = -cos_phi * rx * sin_t - sin_phi * ry * cos_t
  let dy = -sin_phi * rx * sin_t + cos_phi * ry * cos_t
  (dx, dy)
}

///|
fn angle_between_vec(
  ux : Double,
  uy : Double,
  vx : Double,
  vy : Double,
) -> Double {
  let dot = ux * vx + uy * vy
  let len_u = (ux * ux + uy * uy).sqrt()
  let len_v = (vx * vx + vy * vy).sqrt()
  let len_prod = len_u * len_v
  if len_prod == 0.0 {
    return 0.0
  }
  let mut cos_angle = dot / len_prod
  if cos_angle > 1.0 {
    cos_angle = 1.0
  }
  if cos_angle < -1.0 {
    cos_angle = -1.0
  }
  let angle = @math.acos(cos_angle)
  let cross = ux * vy - uy * vx
  if cross < 0.0 {
    -angle
  } else {
    angle
  }
}

///|
fn compute_arc_tangents(
  x1 : Double,
  y1 : Double,
  rx_in : Double,
  ry_in : Double,
  rotation_degrees : Double,
  large_arc : Bool,
  sweep : Bool,
  x2 : Double,
  y2 : Double,
) -> (Double, Double, Double, Double) {
  let dx_line = x2 - x1
  let dy_line = y2 - y1
  if (x1 == x2 && y1 == y2) || rx_in == 0.0 || ry_in == 0.0 {
    return (dx_line, dy_line, dx_line, dy_line)
  }
  let mut rx = if rx_in < 0.0 { -rx_in } else { rx_in }
  let mut ry = if ry_in < 0.0 { -ry_in } else { ry_in }
  let phi = degrees_to_radians(rotation_degrees)
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let dx = (x1 - x2) / 2.0
  let dy = (y1 - y2) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if lambda > 1.0 {
    let sqrt_lambda = lambda.sqrt()
    rx = rx * sqrt_lambda
    ry = ry * sqrt_lambda
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let sq = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / (rx2 * y1p2 + ry2 * x1p2)
  let sq_abs = if sq < 0.0 { 0.0 } else { sq }
  let coef = sq_abs.sqrt() * (if large_arc == sweep { -1.0 } else { 1.0 })
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  let theta1 = angle_between_vec(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  let mut dtheta = angle_between_vec(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  )
  let pi = 3.14159265358979323846
  if !sweep && dtheta > 0.0 {
    dtheta = dtheta - 2.0 * pi
  } else if sweep && dtheta < 0.0 {
    dtheta = dtheta + 2.0 * pi
  }
  let theta2 = theta1 + dtheta
  let sign = if dtheta < 0.0 { -1.0 } else { 1.0 }
  let (sx, sy) = arc_tangent_at(theta1, cos_phi, sin_phi, rx, ry)
  let (ex, ey) = arc_tangent_at(theta2, cos_phi, sin_phi, rx, ry)
  (sx * sign, sy * sign, ex * sign, ey * sign)
}

///|
fn build_marker_subpaths(commands : Array[PathCommand]) -> Array[MarkerSubpath] {
  let subpaths : Array[MarkerSubpath] = []
  let mut points : Array[MarkerPoint] = []
  let mut closed = false
  let mut cur_x = 0.0
  let mut cur_y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  let mut last_ctrl_x = 0.0
  let mut last_ctrl_y = 0.0
  let mut last_cmd_was_curve = false
  let mut last_cmd_was_quad = false
  let eps = 0.0001
  fn finish_subpath(
    subpaths : Array[MarkerSubpath],
    points : Array[MarkerPoint],
    closed : Bool,
  ) -> Unit {
    if points.length() == 0 {
      return
    }
    let out_points = points
    if closed {
      let first = out_points[0]
      let dup = MarkerPoint::new(first.x, first.y)
      if first.has_in {
        dup.has_in = true
        dup.in_dx = first.in_dx
        dup.in_dy = first.in_dy
      }
      out_points.push(dup)
    }
    subpaths.push(MarkerSubpath::{ points: out_points })
  }

  fn record_out(
    points : Array[MarkerPoint],
    idx : Int,
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> Unit {
    let len = (dx * dx + dy * dy).sqrt()
    if len >= eps {
      points[idx].has_out = true
      points[idx].out_dx = dx
      points[idx].out_dy = dy
    }
  }

  fn record_in(
    points : Array[MarkerPoint],
    idx : Int,
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> Unit {
    let len = (dx * dx + dy * dy).sqrt()
    if len >= eps {
      points[idx].has_in = true
      points[idx].in_dx = dx
      points[idx].in_dy = dy
    }
  }

  fn add_segment(
    points : Array[MarkerPoint],
    cur_x : Double,
    cur_y : Double,
    end_x : Double,
    end_y : Double,
    out_dx : Double,
    out_dy : Double,
    in_dx : Double,
    in_dy : Double,
    eps : Double,
  ) -> Unit {
    if points.length() == 0 {
      points.push(MarkerPoint::new(cur_x, cur_y))
    }
    let last_idx = points.length() - 1
    record_out(points, last_idx, out_dx, out_dy, eps)
    let end_point = MarkerPoint::new(end_x, end_y)
    let in_len = (in_dx * in_dx + in_dy * in_dy).sqrt()
    if in_len >= eps {
      end_point.has_in = true
      end_point.in_dx = in_dx
      end_point.in_dy = in_dy
    }
    points.push(end_point)
  }

  for cmd in commands {
    match cmd {
      MoveTo(x, y) => {
        finish_subpath(subpaths, points, closed)
        points = [MarkerPoint::new(x, y)]
        closed = false
        cur_x = x
        cur_y = y
        start_x = x
        start_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      MoveToRel(dx, dy) => {
        finish_subpath(subpaths, points, closed)
        let x = cur_x + dx
        let y = cur_y + dy
        points = [MarkerPoint::new(x, y)]
        closed = false
        cur_x = x
        cur_y = y
        start_x = x
        start_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      LineTo(x, y) => {
        let dx = x - cur_x
        let dy = y - cur_y
        add_segment(points, cur_x, cur_y, x, y, dx, dy, dx, dy, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      LineToRel(dx, dy) => {
        let x = cur_x + dx
        let y = cur_y + dy
        add_segment(points, cur_x, cur_y, x, y, dx, dy, dx, dy, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      HorizontalLineTo(x) => {
        let dx = x - cur_x
        add_segment(points, cur_x, cur_y, x, cur_y, dx, 0.0, dx, 0.0, eps)
        cur_x = x
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      HorizontalLineToRel(dx) => {
        let x = cur_x + dx
        add_segment(points, cur_x, cur_y, x, cur_y, dx, 0.0, dx, 0.0, eps)
        cur_x = x
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      VerticalLineTo(y) => {
        let dy = y - cur_y
        add_segment(points, cur_x, cur_y, cur_x, y, 0.0, dy, 0.0, dy, eps)
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      VerticalLineToRel(dy) => {
        let y = cur_y + dy
        add_segment(points, cur_x, cur_y, cur_x, y, 0.0, dy, 0.0, dy, eps)
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      CurveTo(x1, y1, x2, y2, x, y) => {
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy) => {
        let x1 = cur_x + dx1
        let y1 = cur_y + dy1
        let x2 = cur_x + dx2
        let y2 = cur_y + dy2
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      SmoothCurveTo(x2, y2, x, y) => {
        let x1 = if last_cmd_was_curve {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_curve {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      SmoothCurveToRel(dx2, dy2, dx, dy) => {
        let x1 = if last_cmd_was_curve {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_curve {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let x2 = cur_x + dx2
        let y2 = cur_y + dy2
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      QuadraticCurveTo(x1, y1, x, y) => {
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      QuadraticCurveToRel(dx1, dy1, dx, dy) => {
        let x1 = cur_x + dx1
        let y1 = cur_y + dy1
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      SmoothQuadraticCurveTo(x, y) => {
        let x1 = if last_cmd_was_quad {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_quad {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      SmoothQuadraticCurveToRel(dx, dy) => {
        let x1 = if last_cmd_was_quad {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_quad {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      ArcTo(rx, ry, rotation, large_arc, sweep, x, y) => {
        let (sx, sy, ex, ey) = compute_arc_tangents(
          cur_x, cur_y, rx, ry, rotation, large_arc, sweep, x, y,
        )
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) => {
        let x = cur_x + dx
        let y = cur_y + dy
        let (sx, sy, ex, ey) = compute_arc_tangents(
          cur_x, cur_y, rx, ry, rotation, large_arc, sweep, x, y,
        )
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      ClosePath => {
        if points.length() > 0 {
          let dx = start_x - cur_x
          let dy = start_y - cur_y
          let last_idx = points.length() - 1
          record_out(points, last_idx, dx, dy, eps)
          record_in(points, 0, dx, dy, eps)
          cur_x = start_x
          cur_y = start_y
          closed = true
        }
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
    }
  }
  finish_subpath(subpaths, points, closed)
  subpaths
}

///|
fn render_markers_for_path_commands(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if node.marker_start is None &&
    node.marker_mid is None &&
    node.marker_end is None {
    return
  }
  let subpaths = build_marker_subpaths(commands)
  if subpaths.length() == 0 {
    return
  }
  let eps = 0.0001
  let (sx, sy) = transform.get_scale()
  let skew = transform.a * transform.c + transform.b * transform.d
  let use_transformed = (sx - sy).abs() > eps || skew.abs() > eps
  let inv = transform.inverse()
  fn to_local_angle(angle : Double) -> Double {
    let dx = @math.cos(angle)
    let dy = @math.sin(angle)
    let lx = inv.a * dx + inv.c * dy
    let ly = inv.b * dx + inv.d * dy
    @math.atan2(ly, lx)
  }

  fn apply_vec(
    dx : Double,
    dy : Double,
    t : Transform,
    use_t : Bool,
  ) -> (Double, Double) {
    if use_t {
      (t.a * dx + t.c * dy, t.b * dx + t.d * dy)
    } else {
      (dx, dy)
    }
  }

  fn normalize(
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> (Double, Double, Double) {
    let len = (dx * dx + dy * dy).sqrt()
    if len < eps {
      (0.0, 0.0, len)
    } else {
      (dx / len, dy / len, len)
    }
  }

  fn angle_from_vec(
    dx : Double,
    dy : Double,
    use_t : Bool,
    t : Transform,
  ) -> Double {
    let (vx, vy) = apply_vec(dx, dy, t, use_t)
    let ang = @math.atan2(vy, vx)
    if use_t {
      to_local_angle(ang)
    } else {
      ang
    }
  }

  fn angle_mid_vec(
    in_dx : Double,
    in_dy : Double,
    out_dx : Double,
    out_dy : Double,
    eps : Double,
  ) -> Double {
    let (ux1, uy1, l1) = normalize(in_dx, in_dy, eps)
    let (ux2, uy2, l2) = normalize(out_dx, out_dy, eps)
    if l1 < eps && l2 < eps {
      0.0
    } else if l1 < eps {
      @math.atan2(out_dy, out_dx)
    } else if l2 < eps {
      @math.atan2(in_dy, in_dx)
    } else {
      let sx = ux1 + ux2
      let sy = uy1 + uy2
      if sx * sx + sy * sy < eps * eps {
        @math.atan2(out_dx, -out_dy)
      } else {
        @math.atan2(sy, sx)
      }
    }
  }

  let sub_last = subpaths.length() - 1
  for sub_idx in 0..<subpaths.length() {
    let sub = subpaths[sub_idx]
    if sub.points.length() < 2 {
      continue
    }
    let last = sub.points.length() - 1
    for i in 0..<sub.points.length() {
      let marker_id = if sub_idx == 0 && i == 0 {
        node.marker_start
      } else if sub_idx == sub_last && i == last {
        node.marker_end
      } else {
        node.marker_mid
      }
      match marker_id {
        Some(id) =>
          match resources.markers.get(id) {
            Some(marker) => {
              let p = sub.points[i]
              let angle = if i == 0 {
                if p.has_in && p.has_out {
                  let (in_dx, in_dy) = apply_vec(
                    p.in_dx,
                    p.in_dy,
                    transform,
                    use_transformed,
                  )
                  let (out_dx, out_dy) = apply_vec(
                    p.out_dx,
                    p.out_dy,
                    transform,
                    use_transformed,
                  )
                  let ang = angle_mid_vec(in_dx, in_dy, out_dx, out_dy, eps)
                  if use_transformed {
                    to_local_angle(ang)
                  } else {
                    ang
                  }
                } else if p.has_out {
                  angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
                } else if p.has_in {
                  angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
                } else {
                  0.0
                }
              } else if i == last {
                if p.has_in {
                  angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
                } else if p.has_out {
                  angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
                } else {
                  0.0
                }
              } else if p.has_in && p.has_out {
                let (in_dx, in_dy) = apply_vec(
                  p.in_dx,
                  p.in_dy,
                  transform,
                  use_transformed,
                )
                let (out_dx, out_dy) = apply_vec(
                  p.out_dx,
                  p.out_dy,
                  transform,
                  use_transformed,
                )
                let ang = angle_mid_vec(in_dx, in_dy, out_dx, out_dy, eps)
                if use_transformed {
                  to_local_angle(ang)
                } else {
                  ang
                }
              } else if p.has_in {
                angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
              } else if p.has_out {
                angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
              } else {
                0.0
              }
              render_marker_instance(
                marker,
                p.x,
                p.y,
                angle,
                node,
                transform,
                ctx,
                resources,
                node_color,
              )
            }
            None => ()
          }
        None => ()
      }
    }
  }
}

///|
fn is_closed_polyline(points : Array[(Int, Int)]) -> Bool {
  if points.length() < 2 {
    false
  } else {
    let last = points.length() - 1
    let (x0, y0) = points[0]
    let (x1, y1) = points[last]
    x0 == x1 && y0 == y1
  }
}

///|
fn polygon_area_int(points : Array[(Int, Int)]) -> Int {
  if points.length() < 3 {
    return 0
  }
  let mut area = 0
  let last = points.length() - 1
  for i in 0..<last {
    let (x0, y0) = points[i]
    let (x1, y1) = points[i + 1]
    area = area + (x0 * y1 - x1 * y0)
  }
  let (lx, ly) = points[last]
  let (fx, fy) = points[0]
  if lx != fx || ly != fy {
    area = area + (lx * fy - fx * ly)
  }
  area
}

///|
fn draw_polyline_joins_caps(
  points : Array[(Int, Int)],
  stroke_px : Int,
  linecap : LineCap,
  linejoin : LineJoin,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
  closed : Bool,
) -> Unit {
  if stroke_px <= 1 || points.length() < 2 {
    return
  }
  if closed {
    let mut count = points.length()
    if is_closed_polyline(points) {
      count = count - 1
    }
    if count < 2 {
      return
    }
    for i in 0..<count {
      let prev = if i == 0 { points[count - 1] } else { points[i - 1] }
      let cur = points[i]
      let next = if i + 1 == count { points[0] } else { points[i + 1] }
      draw_line_join(
        prev, cur, next, stroke_px, linejoin, miterlimit, color, setter,
      )
    }
  } else {
    for i = 1; i < points.length() - 1; i = i + 1 {
      draw_line_join(
        points[i - 1],
        points[i],
        points[i + 1],
        stroke_px,
        linejoin,
        miterlimit,
        color,
        setter,
      )
    }
    draw_line_cap_start(points[0], points[1], stroke_px, linecap, color, setter)
    let last = points.length() - 1
    draw_line_cap_end(
      points[last - 1],
      points[last],
      stroke_px,
      linecap,
      color,
      setter,
    )
  }
}

///|
fn draw_line_cap_start(
  p0 : (Int, Int),
  p1 : (Int, Int),
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  draw_line_cap(p0, p1, width, linecap, color, setter, true)
}

///|
fn draw_line_cap_end(
  p0 : (Int, Int),
  p1 : (Int, Int),
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  draw_line_cap(p0, p1, width, linecap, color, setter, false)
}

///|
fn draw_line_cap(
  p0 : (Int, Int),
  p1 : (Int, Int),
  width : Int,
  linecap : LineCap,
  color : Color,
  setter : PixelSetter,
  is_start : Bool,
) -> Unit {
  if width <= 1 {
    return
  }
  match linecap {
    Butt => ()
    Round => {
      let (x, y) = if is_start { p0 } else { p1 }
      raster_circle_fill(x, y, width / 2, color, setter)
    }
    Square => {
      let (x0, y0) = p0
      let (x1, y1) = p1
      let dx = (x1 - x0).to_double()
      let dy = (y1 - y0).to_double()
      let len = (dx * dx + dy * dy).sqrt()
      if len < 0.001 {
        raster_circle_fill(x0, y0, width / 2, color, setter)
        return
      }
      let ux = dx / len
      let uy = dy / len
      let half_w = width / 2
      let ex = (ux * half_w.to_double()).to_int()
      let ey = (uy * half_w.to_double()).to_int()
      if is_start {
        raster_thick_line(x0 - ex, y0 - ey, x0, y0, width, color, setter)
      } else {
        raster_thick_line(x1, y1, x1 + ex, y1 + ey, width, color, setter)
      }
    }
  }
}

///|
fn draw_line_join(
  p0 : (Int, Int),
  p1 : (Int, Int),
  p2 : (Int, Int),
  width : Int,
  linejoin : LineJoin,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if width <= 1 {
    return
  }
  let (x0, y0) = p0
  let (x1, y1) = p1
  let (x2, y2) = p2
  let dx0 = (x1 - x0).to_double()
  let dy0 = (y1 - y0).to_double()
  let dx1 = (x2 - x1).to_double()
  let dy1 = (y2 - y1).to_double()
  let len0 = (dx0 * dx0 + dy0 * dy0).sqrt()
  let len1 = (dx1 * dx1 + dy1 * dy1).sqrt()
  if len0 < 0.001 || len1 < 0.001 {
    return
  }
  let ux0 = dx0 / len0
  let uy0 = dy0 / len0
  let ux1 = dx1 / len1
  let uy1 = dy1 / len1
  let cross = ux0 * uy1 - uy0 * ux1
  if cross.abs() < 0.0001 {
    return
  }
  let side = if cross > 0.0 { -1.0 } else { 1.0 }
  match linejoin {
    Round => raster_circle_fill(x1, y1, width / 2, color, setter)
    Bevel =>
      draw_bevel_join(x1, y1, ux0, uy0, ux1, uy1, side, width, color, setter)
    Miter =>
      draw_miter_join(
        x1, y1, ux0, uy0, ux1, uy1, side, width, miterlimit, color, setter,
      )
  }
}

///|
fn draw_bevel_join(
  x1 : Int,
  y1 : Int,
  ux0 : Double,
  uy0 : Double,
  ux1 : Double,
  uy1 : Double,
  side : Double,
  width : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let half = width.to_double() / 2.0
  let ox0 = x1.to_double() + side * -uy0 * half
  let oy0 = y1.to_double() + side * ux0 * half
  let ox1 = x1.to_double() + side * -uy1 * half
  let oy1 = y1.to_double() + side * ux1 * half
  let points : Array[(Int, Int)] = [
    (ox0.to_int(), oy0.to_int()),
    (ox1.to_int(), oy1.to_int()),
    (x1, y1),
  ]
  raster_polygon_fill(points, color, setter)
}

///|
fn draw_miter_join(
  x1 : Int,
  y1 : Int,
  ux0 : Double,
  uy0 : Double,
  ux1 : Double,
  uy1 : Double,
  side : Double,
  width : Int,
  miterlimit : Double,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let half = width.to_double() / 2.0
  let ox0 = x1.to_double() + side * -uy0 * half
  let oy0 = y1.to_double() + side * ux0 * half
  let ox1 = x1.to_double() + side * -uy1 * half
  let oy1 = y1.to_double() + side * ux1 * half
  // Intersection of offset lines
  let denom = ux0 * uy1 - uy0 * ux1
  if denom.abs() < 0.0001 {
    draw_bevel_join(x1, y1, ux0, uy0, ux1, uy1, side, width, color, setter)
    return
  }
  let px = ox0
  let py = oy0
  let qx = ox1
  let qy = oy1
  let t = ((qx - px) * uy1 - (qy - py) * ux1) / denom
  let ix = px + t * ux0
  let iy = py + t * uy0
  let dx = ix - x1.to_double()
  let dy = iy - y1.to_double()
  let miter_len = (dx * dx + dy * dy).sqrt() / half
  if miter_len > miterlimit {
    draw_bevel_join(x1, y1, ux0, uy0, ux1, uy1, side, width, color, setter)
    return
  }
  let points : Array[(Int, Int)] = [
    (ox0.to_int(), oy0.to_int()),
    (ix.to_int(), iy.to_int()),
    (ox1.to_int(), oy1.to_int()),
  ]
  raster_polygon_fill(points, color, setter)
}

///|
fn render_polyline(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if points.length() < 2 {
    return
  }
  if node_uses_paint_server(node, node_color, resources) {
    render_path(
      points_path_commands(points, false),
      node,
      transform,
      ctx,
      node_color,
      resources,
    )
    return
  }
  let transformed = points.map(fn(p) {
    let (x, y) = transform.apply(p.0, p.1)
    (quantize_geometry(x), quantize_geometry(y))
  })
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 && transformed.length() >= 3 {
          raster_polygon_fill_rule(
            transformed,
            apply_opacity(color, node.fill_opacity * node.opacity),
            node.fill_rule,
            ctx.setter,
          )
        }
      _ => ()
    }
  }
  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_affine_stroke(
            points,
            node.stroke,
            transform,
            stroke_color,
            ctx.setter,
            false,
          )
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_linear_shape(
      points, false, node, transform, ctx, resources, node_color,
    )
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, draw_markers)
}

///|
fn render_polygon(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  if points.length() < 3 {
    return
  }
  if node_uses_paint_server(node, node_color, resources) {
    render_path(
      points_path_commands(points, true),
      node,
      transform,
      ctx,
      node_color,
      resources,
    )
    return
  }
  let transformed = points.map(fn(p) {
    let (x, y) = transform.apply(p.0, p.1)
    (quantize_geometry(x), quantize_geometry(y))
  })
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          raster_polygon_fill_rule(
            transformed,
            fill_color,
            node.fill_rule,
            ctx.setter,
          )
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_affine_stroke(
            points,
            node.stroke,
            transform,
            stroke_color,
            ctx.setter,
            true,
          )
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_linear_shape(
      points, true, node, transform, ctx, resources, node_color,
    )
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, draw_markers)
}

///|
fn gradient_sample_point(
  local_x : Double,
  local_y : Double,
  bbox : BoundingBox,
  units : GradientUnits,
  gradient_transform : Transform,
) -> (Double, Double) {
  let (x, y) = match units {
    ObjectBoundingBox => {
      let width = bbox.width()
      let height = bbox.height()
      (
        if width > 0.0 {
          (local_x - bbox.min_x) / width
        } else {
          0.0
        },
        if height > 0.0 {
          (local_y - bbox.min_y) / height
        } else {
          0.0
        },
      )
    }
    UserSpaceOnUse => (local_x, local_y)
  }
  gradient_transform.inverse().apply(x, y)
}

///|
fn sample_linear_gradient(
  gradient : LinearGradient,
  local_x : Double,
  local_y : Double,
  bbox : BoundingBox,
) -> Color {
  let (x, y) = gradient_sample_point(
    local_x,
    local_y,
    bbox,
    gradient.units,
    gradient.transform,
  )
  let dx = gradient.x2 - gradient.x1
  let dy = gradient.y2 - gradient.y1
  let length_squared = dx * dx + dy * dy
  let t = if length_squared > 0.000000000001 {
    ((x - gradient.x1) * dx + (y - gradient.y1) * dy) / length_squared
  } else {
    0.0
  }
  gradient.color_at(t)
}

///|
fn sample_radial_gradient(
  gradient : RadialGradient,
  lut : Array[Color],
  local_x : Double,
  local_y : Double,
  bbox : BoundingBox,
) -> Color {
  let (x, y) = gradient_sample_point(
    local_x,
    local_y,
    bbox,
    gradient.units,
    gradient.transform,
  )
  let mut fx = gradient.fx
  let mut fy = gradient.fy
  let focus_dx = fx - gradient.cx
  let focus_dy = fy - gradient.cy
  let focus_distance = (focus_dx * focus_dx + focus_dy * focus_dy).sqrt()
  if gradient.r > 0.0 && focus_distance >= gradient.r {
    let scale = gradient.r * 0.999999 / focus_distance
    fx = gradient.cx + focus_dx * scale
    fy = gradient.cy + focus_dy * scale
  }
  let qx = x - fx
  let qy = y - fy
  let dx = gradient.cx - fx
  let dy = gradient.cy - fy
  let a = dx * dx + dy * dy - gradient.r * gradient.r
  let b = -2.0 * (qx * dx + qy * dy)
  let c = qx * qx + qy * qy
  let t = if gradient.r <= 0.0 {
    0.0
  } else if a.abs() <= 0.000000000001 {
    if b.abs() <= 0.000000000001 {
      0.0
    } else {
      -c / b
    }
  } else {
    let discriminant = b * b - 4.0 * a * c
    if discriminant <= 0.0 {
      0.0
    } else {
      let root = discriminant.sqrt()
      max((-b + root) / (2.0 * a), (-b - root) / (2.0 * a))
    }
  }
  let t = apply_spread_inline(t, gradient.spread_method)
  lut_color_at(lut, t)
}

///|
fn make_paint_server_setter(
  paint : ResolvedPaint,
  shape : Shape,
  transform : Transform,
  ctx : RenderContext,
  resources : RenderResources,
  opacity : Double,
) -> PixelSetter? {
  let bbox = get_shape_bounds(shape)
  match paint {
    ResolvedPaint::LinearGrad(gradient) => {
      let inverse = transform.inverse()
      Some({
        set: (x, y, _color) => {
          if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
            return
          }
          let (local_x, local_y) = inverse.apply(
            x.to_double() + 0.5,
            y.to_double() + 0.5,
          )
          ctx.setter.pixel(
            x,
            y,
            apply_opacity(
              sample_linear_gradient(gradient, local_x, local_y, bbox),
              opacity,
            ),
          )
        },
      })
    }
    ResolvedPaint::RadialGrad(gradient) => {
      let inverse = transform.inverse()
      let lut = gradient.build_lut(256)
      Some({
        set: (x, y, _color) => {
          if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
            return
          }
          let (local_x, local_y) = inverse.apply(
            x.to_double() + 0.5,
            y.to_double() + 0.5,
          )
          ctx.setter.pixel(
            x,
            y,
            apply_opacity(
              sample_radial_gradient(gradient, lut, local_x, local_y, bbox),
              opacity,
            ),
          )
        },
      })
    }
    ResolvedPaint::Pattern(pattern) =>
      make_pattern_setter(pattern, bbox, transform, ctx, resources, opacity)
    _ => None
  }
}

///|
fn render_path(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  // Convert to polylines with transform
  let polylines = path_to_polylines(commands, ctx.flatness)
  let transformed_polylines : Array[Array[(Int, Int)]] = []
  for polyline in polylines {
    let transformed = polyline.map(fn(p) {
      let (x, y) = transform.apply(p.0, p.1)
      (quantize_geometry(x), quantize_geometry(y))
    })
    transformed_polylines.push(transformed)
  }
  let fill_polylines : Array[Array[(Int, Int)]] = []
  for polyline in transformed_polylines {
    if polyline.length() >= 3 && polygon_area_int(polyline) != 0 {
      fill_polylines.push(polyline)
    }
  }
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          if fill_polylines.length() > 0 {
            raster_polygons_fill_rule(
              fill_polylines,
              fill_color,
              node.fill_rule,
              ctx.setter,
            )
          }
        }
      ResolvedPaint::LinearGrad(gradient) =>
        if node.fill_opacity > 0.0 {
          let bbox = get_shape_bounds(node.shape)
          let inverse = transform.inverse()
          let gradient_setter : PixelSetter = {
            set: (x, y, _color) => {
              if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
                return
              }
              let (local_x, local_y) = inverse.apply(
                x.to_double() + 0.5,
                y.to_double() + 0.5,
              )
              ctx.setter.pixel(
                x,
                y,
                apply_opacity(
                  sample_linear_gradient(gradient, local_x, local_y, bbox),
                  node.fill_opacity * node.opacity,
                ),
              )
            },
          }
          raster_polygons_fill_rule(
            fill_polylines,
            Color::white(),
            node.fill_rule,
            gradient_setter,
          )
        }
      ResolvedPaint::RadialGrad(gradient) =>
        if node.fill_opacity > 0.0 {
          let bbox = get_shape_bounds(node.shape)
          let inverse = transform.inverse()
          let lut = gradient.build_lut(256)
          let gradient_setter : PixelSetter = {
            set: (x, y, _color) => {
              if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
                return
              }
              let (local_x, local_y) = inverse.apply(
                x.to_double() + 0.5,
                y.to_double() + 0.5,
              )
              ctx.setter.pixel(
                x,
                y,
                apply_opacity(
                  sample_radial_gradient(gradient, lut, local_x, local_y, bbox),
                  node.fill_opacity * node.opacity,
                ),
              )
            },
          }
          raster_polygons_fill_rule(
            fill_polylines,
            Color::white(),
            node.fill_rule,
            gradient_setter,
          )
        }
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          let bbox = get_shape_bounds(node.shape)
          match
            make_pattern_setter(
              pattern,
              bbox,
              transform,
              ctx,
              resources,
              node.fill_opacity * node.opacity,
            ) {
            Some(pattern_setter) =>
              raster_polygons_fill_rule(
                fill_polylines,
                Color::white(),
                node.fill_rule,
                pattern_setter,
              )
            None => ()
          }
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    let stroke_paint = resolve_paint_for_render(
      node.stroke.paint,
      node_color,
      resources,
    )
    match stroke_paint {
      ResolvedPaint::SolidColor(color) =>
        for polyline in polylines {
          if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
            let stroke_color = apply_opacity(
              color,
              node.stroke_opacity * node.opacity,
            )
            let closed = polyline.length() > 1 &&
              (polyline[0].0 - polyline[polyline.length() - 1].0).abs() <=
              0.000001 &&
              (polyline[0].1 - polyline[polyline.length() - 1].1).abs() <=
              0.000001
            raster_affine_stroke(
              polyline,
              node.stroke,
              transform,
              stroke_color,
              ctx.setter,
              closed,
            )
          }
        }
      ResolvedPaint::LinearGrad(_)
      | ResolvedPaint::RadialGrad(_)
      | ResolvedPaint::Pattern(_) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          match
            make_paint_server_setter(
              stroke_paint,
              node.shape,
              transform,
              ctx,
              resources,
              node.stroke_opacity * node.opacity,
            ) {
            Some(stroke_setter) =>
              for polyline in polylines {
                let closed = polyline.length() > 1 &&
                  (polyline[0].0 - polyline[polyline.length() - 1].0).abs() <=
                  0.000001 &&
                  (polyline[0].1 - polyline[polyline.length() - 1].1).abs() <=
                  0.000001
                raster_affine_stroke(
                  polyline,
                  node.stroke,
                  transform,
                  Color::white(),
                  stroke_setter,
                  closed,
                )
              }
            None => ()
          }
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_path_commands(
      commands, node, transform, ctx, resources, node_color,
    )
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, draw_markers)
}

///|
fn render_text(
  x : Double,
  y : Double,
  text : String,
  font_size : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderContext,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  let (tx, ty) = transform.apply(x, y)
  let (sx, _) = transform.get_scale()
  let scaled_size = (font_size * sx).to_int()
  // Fill color for text
  let fill_paint = resolve_paint_for_render(node.fill, node_color, resources)
  let paint_server_setter = match fill_paint {
    ResolvedPaint::LinearGrad(_)
    | ResolvedPaint::RadialGrad(_)
    | ResolvedPaint::Pattern(_) =>
      if node.fill_opacity > 0.0 {
        make_paint_server_setter(
          fill_paint,
          node.shape,
          transform,
          ctx,
          resources,
          node.fill_opacity * node.opacity,
        )
      } else {
        None
      }
    _ => None
  }
  match ctx.text_to_paths {
    Some(to_paths) => {
      // Use font callback: render each character as path commands
      let fill_color : Color? = match fill_paint {
        ResolvedPaint::SolidColor(color) =>
          if node.fill_opacity > 0.0 {
            Some(apply_opacity(color, node.fill_opacity * node.opacity))
          } else {
            None
          }
        ResolvedPaint::LinearGrad(_)
        | ResolvedPaint::RadialGrad(_)
        | ResolvedPaint::Pattern(_) =>
          match paint_server_setter {
            Some(_) => Some(Color::white())
            None => None
          }
        _ => None
      }
      let setter = paint_server_setter.unwrap_or(ctx.setter)
      let mut cursor_x = tx
      for i in 0..<text.length() {
        let codepoint = text[i].unsafe_to_char().to_int()
        let (cmds, advance) = to_paths(codepoint, font_size * sx)
        // Translate commands to cursor position
        let translated = translate_path_commands(cmds, cursor_x, ty)
        raster_path(translated, fill_color, None, ctx.flatness, setter)
        cursor_x = cursor_x + advance
      }
    }
    None =>
      // Fallback: bitmap font
      match fill_paint {
        ResolvedPaint::SolidColor(color) =>
          if node.fill_opacity > 0.0 {
            let fill_color = apply_opacity(
              color,
              node.fill_opacity * node.opacity,
            )
            raster_text(
              quantize_geometry(tx),
              quantize_geometry(ty),
              text,
              scaled_size,
              fill_color,
              ctx.setter,
            )
          }
        ResolvedPaint::LinearGrad(_)
        | ResolvedPaint::RadialGrad(_)
        | ResolvedPaint::Pattern(_) =>
          if node.fill_opacity > 0.0 {
            match paint_server_setter {
              Some(setter) =>
                raster_text(
                  quantize_geometry(tx),
                  quantize_geometry(ty),
                  text,
                  scaled_size,
                  Color::white(),
                  setter,
                )
              None => ()
            }
          }
        _ => ()
      }
  }
}

///|
/// Translate path commands by (dx, dy) offset
fn translate_path_commands(
  commands : Array[PathCommand],
  dx : Double,
  dy : Double,
) -> Array[PathCommand] {
  let result : Array[PathCommand] = []
  for cmd in commands {
    let translated : PathCommand = match cmd {
      MoveTo(x, y) => MoveTo(x + dx, y + dy)
      LineTo(x, y) => LineTo(x + dx, y + dy)
      QuadraticCurveTo(cx, cy, x, y) =>
        QuadraticCurveTo(cx + dx, cy + dy, x + dx, y + dy)
      CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        CurveTo(cx1 + dx, cy1 + dy, cx2 + dx, cy2 + dy, x + dx, y + dy)
      ClosePath => ClosePath
      other => other
    }
    result.push(translated)
  }
  result
}

///|
/// Apply opacity to a color
fn apply_opacity(color : Color, opacity : Double) -> Color {
  if opacity >= 1.0 {
    color
  } else if opacity <= 0.0 {
    Color::transparent()
  } else {
    {
      r: color.r,
      g: color.g,
      b: color.b,
      a: (color.a.to_double() * opacity).round().to_int(),
    }
  }
}

///|
/// Helper: Create a rectangle node
pub fn rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGNode {
  let node = SVGNode::new(Rect(x~, y~, width~, height~, rx=0.0, ry=0.0))
  node.id = id
  node
}

///|
/// Helper: Create a circle node
pub fn circle(id : String, cx : Double, cy : Double, r : Double) -> SVGNode {
  let node = SVGNode::new(Circle(cx~, cy~, r~))
  node.id = id
  node
}

///|
/// Helper: Create a line node
pub fn line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> SVGNode {
  let node = SVGNode::new(Line(x1~, y1~, x2~, y2~))
  node.id = id
  node.fill = None // Lines have no fill by default
  node
}

///|
/// Helper: Create a path node from path data string
pub fn path(id : String, d : String) -> SVGNode {
  let commands = parse_path(d)
  let node = SVGNode::new(Path(commands~))
  node.id = id
  node
}

///|
/// Helper: Create a text node
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
  font_size : Double,
) -> SVGNode {
  let node = SVGNode::new(Text(x~, y~, text=content, font_size~))
  node.id = id
  node
}

///|
/// Helper: Create a group node
pub fn group(id : String, children : Array[SVGNode]) -> SVGNode {
  let node = SVGNode::new(Group)
  node.id = id
  for child in children {
    node.children.push(child)
  }
  node
}

///|
/// Create a RenderContext with default settings
pub fn RenderContext::new(
  setter : PixelSetter,
  width : Int,
  height : Int,
) -> RenderContext {
  {
    setter,
    width,
    height,
    flatness: 0.5,
    clip: None,
    text_to_paths: None,
    image_resolver: None,
    target_image: None,
  }
}

///|
/// Return this render context with a host image resolver.
///
/// The resolver receives the authored `href` and returns decoded RGBA pixels.
/// Filesystem access, network access, codec selection, and caching remain the
/// responsibility of the host application.
pub fn RenderContext::with_image_resolver(
  self : RenderContext,
  image_resolver : (String) -> Image?,
) -> RenderContext {
  { ..self, image_resolver: Some(image_resolver) }
}

///|
/// Create a RenderContext with clipping
pub fn RenderContext::with_clip(
  setter : PixelSetter,
  width : Int,
  height : Int,
  clip : ClipRect,
) -> RenderContext {
  {
    setter,
    width,
    height,
    flatness: 0.5,
    clip: Some(clip),
    text_to_paths: None,
    image_resolver: None,
    target_image: None,
  }
}

///|
/// Create a RenderContext with font callback for text rendering
pub fn RenderContext::with_font(
  setter : PixelSetter,
  width : Int,
  height : Int,
  text_to_paths : (Int, Double) -> (Array[PathCommand], Double),
) -> RenderContext {
  {
    setter,
    width,
    height,
    flatness: 0.5,
    clip: None,
    text_to_paths: Some(text_to_paths),
    image_resolver: None,
    target_image: None,
  }
}

///|
/// Create a RenderContext for a camera
pub fn RenderContext::for_camera(
  setter : PixelSetter,
  camera : Camera,
) -> RenderContext {
  let clip = ClipRect::from_size(camera.viewport_width, camera.viewport_height)
  {
    setter,
    width: camera.viewport_width,
    height: camera.viewport_height,
    flatness: 0.5,
    clip: Some(clip),
    text_to_paths: None,
    image_resolver: None,
    target_image: None,
  }
}
