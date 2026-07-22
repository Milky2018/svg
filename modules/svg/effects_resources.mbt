// ============================================================================
// ClipPath
// ============================================================================

///|
/// Clip path definition
pub(all) struct ClipPath {
  id : String
  shape : Shape // The clipping shape
  content : Array[SVGNode] // Complete clipping subtree, when parsed from SVG
  transform : Transform
  clip_rule : FillRule // nonzero or evenodd
  units : ClipPathUnits
}

///|
/// Clip path units for coordinate system
pub(all) enum ClipPathUnits {
  UserSpaceOnUse
  ObjectBoundingBox
} derive(Debug, Eq)

///|
pub fn ClipPath::new(id : String, shape : Shape) -> ClipPath {
  {
    id,
    shape,
    content: [],
    transform: Transform::identity(),
    clip_rule: NonZero,
    units: UserSpaceOnUse,
  }
}

///|
pub fn ClipPath::with_transform(
  id : String,
  shape : Shape,
  transform : Transform,
) -> ClipPath {
  {
    id,
    shape,
    content: [],
    transform,
    clip_rule: NonZero,
    units: UserSpaceOnUse,
  }
}

///|
/// Clip path registry for referencing by ID
priv struct ClipPathRegistry {
  clips : Map[String, ClipPath]
}

///|
fn ClipPathRegistry::new() -> ClipPathRegistry {
  { clips: Map([]) }
}

///|
fn ClipPathRegistry::add(self : ClipPathRegistry, clip : ClipPath) -> Unit {
  self.clips.set(clip.id, clip)
}

///|
fn ClipPathRegistry::get(self : ClipPathRegistry, id : String) -> ClipPath? {
  self.clips.get(id)
}

// ============================================================================
// Mask
// ============================================================================

///|
/// Mask content units
pub(all) enum MaskUnits {
  UserSpaceOnUse // Coordinates relative to current user space
  ObjectBoundingBox // Coordinates relative to bounding box (0-1)
} derive(Debug, Eq)

///|
/// Mask type - how mask values are interpreted
pub(all) enum MaskType {
  Luminance // Use luminance (brightness) as mask value
  Alpha // Use alpha channel as mask value
} derive(Debug, Eq)

///|
/// Mask definition for transparency masking
pub(all) struct Mask {
  id : String
  content : Array[SVGNode] // Mask content (rendered to get mask values)
  x : Double // Mask region x
  y : Double // Mask region y
  width : Double // Mask region width
  height : Double // Mask region height
  x_is_percent : Bool
  y_is_percent : Bool
  width_is_percent : Bool
  height_is_percent : Bool
  mask_units : MaskUnits
  mask_content_units : MaskUnits
  mask_type : MaskType
}

///|
pub(all) enum FilterGraphPrimitive {
  GraphColorMatrix(
    input~ : String,
    result~ : String,
    matrix~ : FixedArray[Double]
  )
  GraphGaussianBlur(
    input~ : String,
    result~ : String,
    radius_x~ : Double,
    radius_y~ : Double
  )
  GraphOffset(input~ : String, result~ : String, dx~ : Double, dy~ : Double)
  GraphBlend(
    input~ : String,
    input2~ : String,
    result~ : String,
    mode~ : BlendMode
  )
  GraphComposite(
    input~ : String,
    input2~ : String,
    result~ : String,
    operator~ : FilterCompositeOperator,
    k1~ : Double,
    k2~ : Double,
    k3~ : Double,
    k4~ : Double
  )
  GraphFlood(result~ : String, color~ : Color)
  GraphMerge(result~ : String, inputs~ : Array[String])
  GraphComponentTransfer(
    input~ : String,
    result~ : String,
    red~ : ComponentTransferFunction,
    green~ : ComponentTransferFunction,
    blue~ : ComponentTransferFunction,
    alpha~ : ComponentTransferFunction
  )
  GraphMorphology(
    input~ : String,
    result~ : String,
    radius_x~ : Double,
    radius_y~ : Double,
    operator~ : MorphologyOperator
  )
  GraphConvolveMatrix(
    input~ : String,
    result~ : String,
    order_x~ : Int,
    order_y~ : Int,
    kernel~ : Array[Double],
    divisor~ : Double,
    bias~ : Double,
    target_x~ : Int,
    target_y~ : Int,
    edge_mode~ : FilterEdgeMode,
    preserve_alpha~ : Bool
  )
  GraphDisplacementMap(
    input~ : String,
    input2~ : String,
    result~ : String,
    scale~ : Double,
    x_channel~ : FilterChannel,
    y_channel~ : FilterChannel
  )
  GraphTurbulence(
    result~ : String,
    base_x~ : Double,
    base_y~ : Double,
    octaves~ : Int,
    seed~ : Double,
    stitch~ : Bool,
    fractal_noise~ : Bool
  )
  GraphTile(input~ : String, result~ : String)
  GraphImage(
    result~ : String,
    href~ : String,
    x~ : Double,
    y~ : Double,
    width~ : Double,
    height~ : Double
  )
  GraphDiffuseLighting(
    input~ : String,
    result~ : String,
    surface_scale~ : Double,
    diffuse_constant~ : Double,
    color~ : Color,
    light~ : FilterLight
  )
  GraphSpecularLighting(
    input~ : String,
    result~ : String,
    surface_scale~ : Double,
    specular_constant~ : Double,
    specular_exponent~ : Double,
    color~ : Color,
    light~ : FilterLight
  )
} derive(Debug)

///|
pub(all) enum ComponentTransferFunction {
  TransferIdentity
  TransferTable(Array[Double])
  TransferDiscrete(Array[Double])
  TransferLinear(slope~ : Double, intercept~ : Double)
  TransferGamma(amplitude~ : Double, exponent~ : Double, offset~ : Double)
} derive(Debug)

///|
pub(all) enum MorphologyOperator {
  MorphologyErode
  MorphologyDilate
} derive(Debug, Eq)

///|
pub(all) enum FilterEdgeMode {
  EdgeDuplicate
  EdgeWrap
  EdgeNone
} derive(Debug, Eq)

///|
pub(all) enum FilterChannel {
  ChannelR
  ChannelG
  ChannelB
  ChannelA
} derive(Debug, Eq)

///|
pub(all) enum FilterLight {
  DistantLight(azimuth~ : Double, elevation~ : Double)
  PointLight(x~ : Double, y~ : Double, z~ : Double)
  SpotLight(
    x~ : Double,
    y~ : Double,
    z~ : Double,
    points_at_x~ : Double,
    points_at_y~ : Double,
    points_at_z~ : Double,
    exponent~ : Double,
    limiting_cone_angle~ : Double?
  )
} derive(Debug)

///|
pub(all) enum FilterCompositeOperator {
  CompositeOver
  CompositeIn
  CompositeOut
  CompositeAtop
  CompositeXor
  CompositeArithmetic
} derive(Debug, Eq)

///|
pub(all) struct FilterGraph {
  id : String
  primitives : Array[FilterGraphPrimitive]
  units : MaskUnits
  primitive_units : MaskUnits
  x : Double
  y : Double
  width : Double
  height : Double
  x_is_percent : Bool
  y_is_percent : Bool
  width_is_percent : Bool
  height_is_percent : Bool
}

///|
fn FilterGraph::get_filter_bounds(
  self : FilterGraph,
  target : BoundingBox,
) -> BoundingBox {
  match self.units {
    MaskUnits::ObjectBoundingBox => {
      let width = target.width()
      let height = target.height()
      {
        min_x: target.min_x + self.x * width,
        min_y: target.min_y + self.y * height,
        max_x: target.min_x + (self.x + self.width) * width,
        max_y: target.min_y + (self.y + self.height) * height,
      }
    }
    MaskUnits::UserSpaceOnUse => {
      let width = target.width()
      let height = target.height()
      let min_x = resolve_mask_coord(
        self.x,
        self.x_is_percent,
        target.min_x,
        width,
      )
      let min_y = resolve_mask_coord(
        self.y,
        self.y_is_percent,
        target.min_y,
        height,
      )
      let filter_width = resolve_mask_size(
        self.width,
        self.width_is_percent,
        width,
      )
      let filter_height = resolve_mask_size(
        self.height,
        self.height_is_percent,
        height,
      )
      {
        min_x,
        min_y,
        max_x: min_x + filter_width,
        max_y: min_y + filter_height,
      }
    }
  }
}

///|
priv struct FilterGraphRegistry {
  graphs : Map[String, FilterGraph]
}

///|
fn FilterGraphRegistry::new() -> FilterGraphRegistry {
  { graphs: Map([]) }
}

///|
fn FilterGraphRegistry::add(
  self : FilterGraphRegistry,
  graph : FilterGraph,
) -> Unit {
  self.graphs.set(graph.id, graph)
}

///|
fn FilterGraphRegistry::get(
  self : FilterGraphRegistry,
  id : String,
) -> FilterGraph? {
  self.graphs.get(id)
}

///|
pub fn Mask::new(id : String, content : Array[SVGNode]) -> Mask {
  {
    id,
    content,
    x: -0.1,
    y: -0.1,
    width: 1.2,
    height: 1.2,
    x_is_percent: true,
    y_is_percent: true,
    width_is_percent: true,
    height_is_percent: true,
    mask_units: MaskUnits::ObjectBoundingBox,
    mask_content_units: MaskUnits::UserSpaceOnUse,
    mask_type: Luminance,
  }
}

///|
pub fn Mask::with_bounds(
  id : String,
  content : Array[SVGNode],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Mask {
  {
    id,
    content,
    x,
    y,
    width,
    height,
    x_is_percent: false,
    y_is_percent: false,
    width_is_percent: false,
    height_is_percent: false,
    mask_units: MaskUnits::ObjectBoundingBox,
    mask_content_units: MaskUnits::UserSpaceOnUse,
    mask_type: Luminance,
  }
}

///|
/// Compute mask value (0.0-1.0) at a point using luminance
fn compute_luminance(color : Color) -> Double {
  // Standard luminance formula (ITU-R BT.709)
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  let a = color.a.to_double() / 255.0
  // Luminance weighted by alpha
  (0.2126 * r + 0.7152 * g + 0.0722 * b) * a
}

///|
/// Compute mask value using alpha channel
fn compute_alpha_mask(color : Color) -> Double {
  color.a.to_double() / 255.0
}

///|
/// Mask registry for referencing by ID
priv struct MaskRegistry {
  masks : Map[String, Mask]
}

///|
fn MaskRegistry::new() -> MaskRegistry {
  { masks: Map([]) }
}

///|
fn MaskRegistry::add(self : MaskRegistry, mask : Mask) -> Unit {
  self.masks.set(mask.id, mask)
}

///|
fn MaskRegistry::get(self : MaskRegistry, id : String) -> Mask? {
  self.masks.get(id)
}

///|
fn resolve_mask_coord(
  value : Double,
  is_percent : Bool,
  min : Double,
  size : Double,
) -> Double {
  if is_percent {
    min + value * size
  } else {
    value
  }
}

///|
fn resolve_mask_size(
  value : Double,
  is_percent : Bool,
  size : Double,
) -> Double {
  if is_percent {
    value * size
  } else {
    value
  }
}

///|
/// Parsed SVG document with reusable resources
pub struct SVGDocument {
  priv root : SVGNode
  priv symbols : SymbolRegistry
  priv definitions : DefsRegistry
  priv clips : ClipPathRegistry
  priv masks : MaskRegistry
  priv filter_graphs : FilterGraphRegistry
  priv patterns : PatternRegistry
  priv gradients : GradientRegistry
  priv markers : MarkerRegistry
}

///|
pub fn SVGDocument::new(root : SVGNode) -> SVGDocument {
  {
    root,
    symbols: SymbolRegistry::new(),
    definitions: DefsRegistry::new(),
    clips: ClipPathRegistry::new(),
    masks: MaskRegistry::new(),
    filter_graphs: FilterGraphRegistry::new(),
    patterns: PatternRegistry::new(),
    gradients: GradientRegistry::new(),
    markers: MarkerRegistry::new(),
  }
}

///|
/// Return the authored root node.
pub fn SVGDocument::root(self : SVGDocument) -> SVGNode {
  self.root
}

///|
pub fn SVGDocument::add_symbol(self : SVGDocument, symbol : Symbol) -> Unit {
  self.symbols.add(symbol)
}

///|
/// Register an ordinary SVG node for fragment references such as `<use>`.
pub fn SVGDocument::add_definition(
  self : SVGDocument,
  id : String,
  node : SVGNode,
) -> Unit {
  self.definitions.add(id, node)
}

///|
pub fn SVGDocument::add_clip_path(self : SVGDocument, clip : ClipPath) -> Unit {
  self.clips.add(clip)
}

///|
pub fn SVGDocument::add_mask(self : SVGDocument, mask : Mask) -> Unit {
  self.masks.add(mask)
}

///|
pub fn SVGDocument::add_filter_graph(
  self : SVGDocument,
  filter : FilterGraph,
) -> Unit {
  self.filter_graphs.add(filter)
}

///|
pub fn SVGDocument::add_pattern(self : SVGDocument, pattern : Pattern) -> Unit {
  self.patterns.add(pattern)
}

///|
pub fn SVGDocument::add_gradient(
  self : SVGDocument,
  id : String,
  gradient : Gradient,
) -> Unit {
  self.gradients.add(id, gradient)
}

///|
pub fn SVGDocument::add_marker(self : SVGDocument, marker : Marker) -> Unit {
  self.markers.add(marker)
}

///|
/// Get the mask region bounds for a given target bounds
fn Mask::get_mask_bounds(self : Mask, target : BoundingBox) -> BoundingBox {
  match self.mask_units {
    MaskUnits::ObjectBoundingBox => {
      let tw = target.max_x - target.min_x
      let th = target.max_y - target.min_y
      {
        min_x: target.min_x + self.x * tw,
        min_y: target.min_y + self.y * th,
        max_x: target.min_x + (self.x + self.width) * tw,
        max_y: target.min_y + (self.y + self.height) * th,
      }
    }
    MaskUnits::UserSpaceOnUse => {
      let tw = target.max_x - target.min_x
      let th = target.max_y - target.min_y
      let min_x = resolve_mask_coord(
        self.x,
        self.x_is_percent,
        target.min_x,
        tw,
      )
      let min_y = resolve_mask_coord(
        self.y,
        self.y_is_percent,
        target.min_y,
        th,
      )
      let w = resolve_mask_size(self.width, self.width_is_percent, tw)
      let h = resolve_mask_size(self.height, self.height_is_percent, th)
      { min_x, min_y, max_x: min_x + w, max_y: min_y + h }
    }
  }
}

///|
/// Apply mask to an image using luminance or alpha
fn apply_mask_to_image(
  image : Image,
  mask_buffer : Image,
  mask_type : MaskType,
) -> Image {
  let result = Image::new(image.width, image.height)
  for y in 0..<image.height {
    for x in 0..<image.width {
      let src_color = image.get_pixel(x, y)
      // Get corresponding mask pixel (with bounds check)
      let mask_x = x * mask_buffer.width / image.width
      let mask_y = y * mask_buffer.height / image.height
      let mask_color = if mask_x >= 0 &&
        mask_x < mask_buffer.width &&
        mask_y >= 0 &&
        mask_y < mask_buffer.height {
        mask_buffer.get_pixel(mask_x, mask_y)
      } else {
        Color::transparent()
      }
      // Compute mask value
      let mask_value = match mask_type {
        Luminance => compute_luminance(mask_color)
        Alpha => compute_alpha_mask(mask_color)
      }
      // Apply mask to alpha
      let new_alpha = (src_color.a.to_double() * mask_value).round().to_int()
      result.set_pixel(
        x,
        y,
        Color::rgba(src_color.r, src_color.g, src_color.b, new_alpha),
      )
    }
  }
  result
}
