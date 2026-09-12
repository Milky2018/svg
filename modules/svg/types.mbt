///|
/// SVG Layout Engine - Standalone Types
/// Independent of HTML/CSS layout system

///|
/// RGB Color (0-255 range)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Int // Alpha (0-255, 255 = opaque)
} derive(Debug)

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  { r, g, b, a: 255, }
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Int) -> Color {
  { r, g, b, a, }
}

///|
pub fn Color::transparent() -> Color {
  { r: 0, g: 0, b: 0, a: 0, }
}

///|
pub fn Color::black() -> Color {
  { r: 0, g: 0, b: 0, a: 255, }
}

///|
pub fn Color::white() -> Color {
  { r: 255, g: 255, b: 255, a: 255, }
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  self.a == 0
}

///|
fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
fn blend_colors(dst : Color, src : Color) -> Color {
  PremulColor16::from_color(src)
  .source_over(PremulColor16::from_color(dst))
  .to_color()
}

///|
/// 2D affine transformation matrix
/// | a c e |
/// | b d f |
/// | 0 0 1 |
pub(all) struct Transform {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
/// ViewBox specification for SVG coordinate system mapping
pub(all) struct ViewBox {
  min_x : Double
  min_y : Double
  width : Double
  height : Double
}

///|
/// preserveAspectRatio alignment values
pub(all) enum Align {
  None // No forced uniform scaling
  XMinYMin
  XMidYMin
  XMaxYMin
  XMinYMid
  XMidYMid // Default
  XMaxYMid
  XMinYMax
  XMidYMax
  XMaxYMax
} derive(Debug, Eq)

///|
/// preserveAspectRatio meet/slice
pub(all) enum MeetOrSlice {
  Meet // Scale to fit entirely (default)
  Slice // Scale to cover entirely
} derive(Debug, Eq)

///|
/// Complete preserveAspectRatio setting
pub(all) struct PreserveAspectRatio {
  align : Align
  meet_or_slice : MeetOrSlice
}

///|
pub fn PreserveAspectRatio::default() -> PreserveAspectRatio {
  { align: XMidYMid, meet_or_slice: Meet, }
}

///|
/// Calculate the transform matrix to map viewBox coordinates to viewport
/// viewport_width/height: the actual pixel dimensions of the SVG element
pub fn ViewBox::get_transform(
  self : ViewBox,
  viewport_width : Double,
  viewport_height : Double,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Transform {
  // Handle zero-size viewBox
  if self.width <= 0.0 || self.height <= 0.0 {
    return Transform::identity()
  }
  // Calculate scale factors
  let scale_x = viewport_width / self.width
  let scale_y = viewport_height / self.height
  // Determine actual scale based on preserveAspectRatio
  let (sx, sy, tx, ty) = match preserve_aspect_ratio.align {
    None =>
      // No uniform scaling - stretch to fit
      (scale_x, scale_y, -self.min_x * scale_x, -self.min_y * scale_y)
    _ => {
      // Uniform scaling
      let scale = match preserve_aspect_ratio.meet_or_slice {
        Meet => if scale_x < scale_y { scale_x } else { scale_y } // Fit entirely
        Slice => if scale_x > scale_y { scale_x } else { scale_y } // Cover entirely
      }
      // Calculate translation based on alignment
      let (align_x, align_y) = get_alignment_factors(
        preserve_aspect_ratio.align,
      )
      // Extra space after scaling
      let extra_x = viewport_width - self.width * scale
      let extra_y = viewport_height - self.height * scale
      let translate_x = -self.min_x * scale + extra_x * align_x
      let translate_y = -self.min_y * scale + extra_y * align_y
      (scale, scale, translate_x, translate_y)
    }
  }
  // Combine: first translate by viewBox min, then scale
  { a: sx, b: 0.0, c: 0.0, d: sy, e: tx, f: ty, }
}

///|
/// Get alignment factors (0.0 = min, 0.5 = mid, 1.0 = max)
fn get_alignment_factors(align : Align) -> (Double, Double) {
  match align {
    None => (0.0, 0.0)
    XMinYMin => (0.0, 0.0)
    XMidYMin => (0.5, 0.0)
    XMaxYMin => (1.0, 0.0)
    XMinYMid => (0.0, 0.5)
    XMidYMid => (0.5, 0.5)
    XMaxYMid => (1.0, 0.5)
    XMinYMax => (0.0, 1.0)
    XMidYMax => (0.5, 1.0)
    XMaxYMax => (1.0, 1.0)
  }
}

///|
/// SVG path commands (full SVG 1.1 spec)
pub(all) enum PathCommand {
  // Absolute commands
  MoveTo(Double, Double) // M x y
  LineTo(Double, Double) // L x y
  HorizontalLineTo(Double) // H x
  VerticalLineTo(Double) // V y
  CurveTo(Double, Double, Double, Double, Double, Double) // C x1 y1 x2 y2 x y
  SmoothCurveTo(Double, Double, Double, Double) // S x2 y2 x y
  QuadraticCurveTo(Double, Double, Double, Double) // Q x1 y1 x y
  SmoothQuadraticCurveTo(Double, Double) // T x y
  ArcTo(Double, Double, Double, Bool, Bool, Double, Double) // A rx ry rotation large-arc sweep x y
  ClosePath // Z
  // Relative commands
  MoveToRel(Double, Double) // m dx dy
  LineToRel(Double, Double) // l dx dy
  HorizontalLineToRel(Double) // h dx
  VerticalLineToRel(Double) // v dy
  CurveToRel(Double, Double, Double, Double, Double, Double) // c dx1 dy1 dx2 dy2 dx dy
  SmoothCurveToRel(Double, Double, Double, Double) // s dx2 dy2 dx dy
  QuadraticCurveToRel(Double, Double, Double, Double) // q dx1 dy1 dx dy
  SmoothQuadraticCurveToRel(Double, Double) // t dx dy
  ArcToRel(Double, Double, Double, Bool, Bool, Double, Double) // a rx ry rotation large-arc sweep dx dy
} derive(Debug)

///|
/// SVG shape primitives
pub(all) enum Shape {
  Rect(
    x~ : Double,
    y~ : Double,
    width~ : Double,
    height~ : Double,
    rx~ : Double,
    ry~ : Double
  )
  Circle(cx~ : Double, cy~ : Double, r~ : Double)
  Ellipse(cx~ : Double, cy~ : Double, rx~ : Double, ry~ : Double)
  Line(x1~ : Double, y1~ : Double, x2~ : Double, y2~ : Double)
  Polyline(points~ : Array[(Double, Double)])
  Polygon(points~ : Array[(Double, Double)])
  Path(commands~ : Array[PathCommand])
  Text(x~ : Double, y~ : Double, text~ : String, font_size~ : Double)
  Image(
    x~ : Double,
    y~ : Double,
    width~ : Double,
    height~ : Double,
    href~ : String
  )
  Group // Container for children
} derive(Debug)

///|
pub(all) enum ImageSampling {
  Nearest
  Bilinear
  Bicubic
} derive(Debug, Eq)

///|
/// Gradient stop (position 0.0-1.0 and color)
pub(all) struct GradientStop {
  offset : Double // 0.0 to 1.0
  color : Color
}

///|
/// Linear gradient definition
pub(all) struct LinearGradient {
  x1 : Double // Start point x (0.0-1.0 or absolute)
  y1 : Double // Start point y
  x2 : Double // End point x
  y2 : Double // End point y
  stops : Array[GradientStop]
  spread_method : SpreadMethod
  units : GradientUnits
  transform : Transform
}

///|
pub fn LinearGradient::new(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  stops : Array[GradientStop],
) -> LinearGradient {
  {
    x1,
    y1,
    x2,
    y2,
    stops,
    spread_method: Pad,
    units: ObjectBoundingBox,
    transform: Transform::identity(),
  }
}

///|
/// Interpolate color at position t (0.0-1.0)
fn LinearGradient::color_at(self : LinearGradient, t : Double) -> Color {
  if self.stops.length() == 0 {
    return Color::black()
  }
  if self.stops.length() == 1 {
    return self.stops[0].color
  }
  // Apply spread method
  let t = match self.spread_method {
    Pad => if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
    Repeat => {
      let t2 = t - t.floor()
      if t2 < 0.0 {
        t2 + 1.0
      } else {
        t2
      }
    }
    Reflect => {
      let t2 = t - t.floor()
      let t2 = if t2 < 0.0 { t2 + 1.0 } else { t2 }
      let cycle = t.floor().to_int() % 2
      if cycle == 1 {
        1.0 - t2
      } else {
        t2
      }
    }
  }
  interpolate_gradient_color(t, self.stops)
}

///|
/// How gradient extends beyond its bounds
pub(all) enum SpreadMethod {
  Pad // Extend with end colors (default)
  Repeat // Repeat pattern
  Reflect // Mirror pattern
} derive(Debug, Eq)

///|
/// Gradient units coordinate space
pub(all) enum GradientUnits {
  UserSpaceOnUse
  ObjectBoundingBox
} derive(Debug, Eq)

///|
/// Paint style (fill or stroke)
pub(all) enum PaintFallback {
  NoPaint
  SolidColor(Color)
  CurrentColor
}

///|
/// Paint style (fill or stroke)
pub(all) enum Paint {
  None
  SolidColor(Color)
  LinearGrad(LinearGradient)
  RadialGrad(RadialGradient)
  CurrentColor
  PaintServerRef(String, PaintFallback)
}

///|
/// Stroke properties
pub(all) struct StrokeStyle {
  paint : Paint
  width : Double
  linecap : LineCap
  linejoin : LineJoin
  miterlimit : Double
  dasharray : Array[Double]?
  dashoffset : Double
  non_scaling : Bool
}

///|
pub fn StrokeStyle::default() -> StrokeStyle {
  {
    paint: None,
    width: 1.0,
    linecap: Butt,
    linejoin: Miter,
    miterlimit: 4.0,
    dasharray: None,
    dashoffset: 0.0,
    non_scaling: false,
  }
}

///|
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Debug, Eq)

///|
pub(all) enum LineJoin {
  Miter
  Round
  Bevel
} derive(Debug, Eq)

///|
/// Fill rule for paths and polygons
pub(all) enum FillRule {
  NonZero // Default
  EvenOdd
} derive(Debug, Eq)

///|
/// SVG paint-order components.
pub(all) enum PaintOrderItem {
  Fill
  Stroke
  Markers
} derive(Debug, Eq)

///|
/// SVG paint-order specification.
pub(all) struct PaintOrder {
  order : Array[PaintOrderItem]
} derive(Debug, Eq)

///|
pub fn PaintOrder::default() -> PaintOrder {
  { order: [Fill, Stroke, Markers], }
}

///|
/// SVG node (element in the scene graph)
pub(all) struct SVGNode {
  mut id : String
  mut shape : Shape
  mut transform : Transform
  mut view_box : ViewBox?
  mut viewport_width : Double?
  mut viewport_height : Double?
  mut preserve_aspect_ratio : PreserveAspectRatio
  priv mut preserve_aspect_ratio_is_set : Bool
  mut image_sampling : ImageSampling
  mut fill : Paint
  priv mut fill_is_set : Bool
  mut color : Color?
  priv mut color_is_set : Bool
  mut paint_order : PaintOrder
  mut fill_rule : FillRule
  mut clip_rule : FillRule
  mut fill_opacity : Double
  mut stroke : StrokeStyle
  priv mut stroke_paint_is_set : Bool
  priv mut stroke_width_is_set : Bool
  mut stroke_opacity : Double
  mut opacity : Double
  mut blend_mode : BlendMode
  mut isolation : Isolation
  mut marker_start : String?
  priv mut marker_start_is_set : Bool
  mut marker_mid : String?
  priv mut marker_mid_is_set : Bool
  mut marker_end : String?
  priv mut marker_end_is_set : Bool
  priv filters : Array[Filter] // Filter effects to apply
  priv mut filter_graph_id : String? // Reference to an SVG filter graph by ID
  priv mut mask_id : String? // Reference to mask by ID
  priv mut clip_path_id : String? // Reference to clip path by ID
  mut clip_overflow : Bool
  /// True for nested `<svg>` elements, which establish a viewport even when
  /// they carry no explicit width, height, or viewBox.
  priv mut establishes_viewport : Bool
  children : Array[SVGNode]
}

///|
pub fn SVGNode::new(shape : Shape) -> SVGNode {
  {
    id: "",
    shape,
    transform: Transform::identity(),
    view_box: None,
    viewport_width: None,
    viewport_height: None,
    preserve_aspect_ratio: PreserveAspectRatio::default(),
    preserve_aspect_ratio_is_set: false,
    image_sampling: Bilinear,
    fill: SolidColor(Color::black()),
    fill_is_set: false,
    color: None,
    color_is_set: false,
    paint_order: PaintOrder::default(),
    fill_rule: NonZero,
    clip_rule: NonZero,
    fill_opacity: 1.0,
    stroke: StrokeStyle::default(),
    stroke_paint_is_set: false,
    stroke_width_is_set: false,
    stroke_opacity: 1.0,
    opacity: 1.0,
    blend_mode: Normal,
    isolation: Auto,
    marker_start: None,
    marker_start_is_set: false,
    marker_mid: None,
    marker_mid_is_set: false,
    marker_end: None,
    marker_end_is_set: false,
    filters: [],
    filter_graph_id: None,
    mask_id: None,
    clip_path_id: None,
    clip_overflow: true,
    establishes_viewport: false,
    children: [],
  }
}

///|
/// Add a filter to the node
pub fn SVGNode::add_filter(self : SVGNode, filter : Filter) -> Unit {
  self.filters.push(filter)
}

///|
/// Clear all filters from the node
pub fn SVGNode::clear_filters(self : SVGNode) -> Unit {
  self.filters.clear()
}

///|
/// Set an SVG filter graph reference by ID.
pub fn SVGNode::set_filter_graph(self : SVGNode, filter_id : String) -> Unit {
  self.filter_graph_id = Some(filter_id)
}

///|
pub fn SVGNode::clear_filter_graph(self : SVGNode) -> Unit {
  self.filter_graph_id = None
}

///|
/// Set mask reference by ID
pub fn SVGNode::set_mask(self : SVGNode, mask_id : String) -> Unit {
  self.mask_id = Some(mask_id)
}

///|
/// Clear mask reference
pub fn SVGNode::clear_mask(self : SVGNode) -> Unit {
  self.mask_id = None
}

///|
/// Set clip path reference by ID
pub fn SVGNode::set_clip_path(self : SVGNode, clip_path_id : String) -> Unit {
  self.clip_path_id = Some(clip_path_id)
}

///|
/// Clear clip path reference
pub fn SVGNode::clear_clip_path(self : SVGNode) -> Unit {
  self.clip_path_id = None
}

///|

///|
/// Helper function for min of two doubles
fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Helper function for max of two doubles
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Bounding box for a shape
pub(all) struct BoundingBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
pub fn BoundingBox::empty() -> BoundingBox {
  {
    min_x: @double.infinity,
    min_y: @double.infinity,
    max_x: @double.neg_infinity,
    max_y: @double.neg_infinity,
  }
}

///|
pub fn BoundingBox::from_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> BoundingBox {
  { min_x: x, min_y: y, max_x: x + w, max_y: y + h, }
}

///|
pub fn BoundingBox::width(self : BoundingBox) -> Double {
  self.max_x - self.min_x
}

///|
pub fn BoundingBox::height(self : BoundingBox) -> Double {
  self.max_y - self.min_y
}

///|
pub fn BoundingBox::is_empty(self : BoundingBox) -> Bool {
  self.min_x > self.max_x || self.min_y > self.max_y
}

///|
pub fn BoundingBox::union(
  self : BoundingBox,
  other : BoundingBox,
) -> BoundingBox {
  if self.is_empty() {
    other
  } else if other.is_empty() {
    self
  } else {
    {
      min_x: min(self.min_x, other.min_x),
      min_y: min(self.min_y, other.min_y),
      max_x: max(self.max_x, other.max_x),
      max_y: max(self.max_y, other.max_y),
    }
  }
}

///|
pub fn BoundingBox::expand_by_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> BoundingBox {
  {
    min_x: min(self.min_x, x),
    min_y: min(self.min_y, y),
    max_x: max(self.max_x, x),
    max_y: max(self.max_y, y),
  }
}

///|
/// Check if two bounding boxes intersect
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  if self.is_empty() || other.is_empty() {
    false
  } else {
    self.min_x <= other.max_x &&
    self.max_x >= other.min_x &&
    self.min_y <= other.max_y &&
    self.max_y >= other.min_y
  }
}

///|
/// Check if this bounding box contains a point
pub fn BoundingBox::contains_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> Bool {
  x >= self.min_x && x <= self.max_x && y >= self.min_y && y <= self.max_y
}

///|
/// Clipping rectangle for camera/viewport
priv struct ClipRect {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
fn ClipRect::new(x : Int, y : Int, width : Int, height : Int) -> ClipRect {
  { x, y, width, height, }
}

///|
/// Check if a point is inside the clip rect
fn ClipRect::contains(self : ClipRect, x : Int, y : Int) -> Bool {
  x >= self.x &&
  x < self.x + self.width &&
  y >= self.y &&
  y < self.y + self.height
}

///|
/// Convert to BoundingBox
fn ClipRect::to_bbox(self : ClipRect) -> BoundingBox {
  {
    min_x: self.x.to_double(),
    min_y: self.y.to_double(),
    max_x: (self.x + self.width).to_double(),
    max_y: (self.y + self.height).to_double(),
  }
}

///|
pub extend Align with Debug::{to_repr}

///|
pub extend Align with Eq::{not_equal, equal}

///|
pub extend Color with Debug::{to_repr}

///|
pub extend FillRule with Debug::{to_repr}

///|
pub extend FillRule with Eq::{not_equal, equal}

///|
pub extend GradientUnits with Debug::{to_repr}

///|
pub extend GradientUnits with Eq::{not_equal, equal}

///|
pub extend ImageSampling with Debug::{to_repr}

///|
pub extend ImageSampling with Eq::{not_equal, equal}

///|
pub extend LineCap with Debug::{to_repr}

///|
pub extend LineCap with Eq::{not_equal, equal}

///|
pub extend LineJoin with Debug::{to_repr}

///|
pub extend LineJoin with Eq::{not_equal, equal}

///|
pub extend MeetOrSlice with Debug::{to_repr}

///|
pub extend MeetOrSlice with Eq::{not_equal, equal}

///|
pub extend PaintOrder with Debug::{to_repr}

///|
pub extend PaintOrder with Eq::{not_equal, equal}

///|
pub extend PaintOrderItem with Debug::{to_repr}

///|
pub extend PaintOrderItem with Eq::{not_equal, equal}

///|
pub extend PathCommand with Debug::{to_repr}

///|
pub extend Shape with Debug::{to_repr}

///|
pub extend SpreadMethod with Debug::{to_repr}

///|
pub extend SpreadMethod with Eq::{not_equal, equal}
