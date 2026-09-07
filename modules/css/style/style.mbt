///|
/// CSS border-style values, ordered by conflict resolution priority (higher wins).
pub(all) enum BorderStyle {
  None // 0 - lowest priority
  Inset // 1
  Groove // 2
  Outset // 3
  Ridge // 4
  Dotted // 5
  Dashed // 6
  Solid // 7
  Double // 8
  Hidden // 9 - highest priority (suppresses border)
} derive(Debug, Eq)

///|
pub fn BorderStyle::priority(self : BorderStyle) -> Int {
  match self {
    None => 0
    Inset => 1
    Groove => 2
    Outset => 3
    Ridge => 4
    Dotted => 5
    Dashed => 6
    Solid => 7
    Double => 8
    Hidden => 9
  }
}

///|
/// CSS border-collapse property (for tables)
pub(all) enum BorderCollapse {
  Separate // Default - borders have spacing
  Collapse // Adjacent borders merge
} derive(Debug, Eq)

///|
/// Table layout algorithm
pub(all) enum TableLayout {
  Auto // Default - column widths based on content
  Fixed // Column widths based on first row only
} derive(Debug, Eq)

///|
/// CSS caption-side property (for table captions)
pub(all) enum CaptionSide {
  Top // Caption above the table (default)
  Bottom // Caption below the table
} derive(Debug, Eq)

///|
/// CSS white-space property (for text wrapping)
pub(all) enum WhiteSpace {
  Normal // Default - collapse whitespace, wrap text
  Nowrap // Collapse whitespace, no wrapping
  Pre // Preserve whitespace, only wrap at newlines
  PreWrap // Preserve whitespace, wrap when needed
  PreLine // Collapse whitespace, wrap at newlines
} derive(Debug, Eq)

///|
/// CSS text-overflow property.
pub(all) enum TextOverflow {
  Clip
  Ellipsis
} derive(Debug, Eq)

///|
/// CSS writing-mode property (for text direction and flow)
pub(all) enum WritingMode {
  HorizontalTb // Default - left-to-right, top-to-bottom
  VerticalRl // Top-to-bottom, right-to-left (e.g., traditional Japanese)
  VerticalLr // Top-to-bottom, left-to-right (e.g., Mongolian)
} derive(Debug, Eq)

///|
/// Check if writing mode is vertical
pub fn WritingMode::is_vertical(self : WritingMode) -> Bool {
  match self {
    HorizontalTb => false
    VerticalRl | VerticalLr => true
  }
}

///|
/// Check if block direction is right-to-left (vertical-rl)
/// In vertical-rl, blocks flow from right to left
pub fn WritingMode::is_block_rtl(self : WritingMode) -> Bool {
  match self {
    VerticalRl => true
    HorizontalTb | VerticalLr => false
  }
}

///|
/// CSS direction property (for inline text direction)
pub(all) enum Direction {
  Ltr // Left-to-right (default)
  Rtl // Right-to-left (e.g., Arabic, Hebrew)
} derive(Debug, Eq)

///|
/// Check if direction is right-to-left
pub fn Direction::is_rtl(self : Direction) -> Bool {
  match self {
    Rtl => true
    Ltr => false
  }
}

///|
/// CSS text-align property
pub(all) enum TextAlign {
  Start
  End
  Left
  Right
  Center
  Justify
} derive(Debug, Eq)

///|
/// CSS scroll-snap-type axis
pub(all) enum ScrollSnapAxis {
  None
  X
  Y
  Both
} derive(Debug, Eq)

///|
/// CSS scroll-snap-type strictness
pub(all) enum ScrollSnapStrictness {
  None
  Mandatory
  Proximity
} derive(Debug, Eq)

///|
/// CSS scroll-snap-type value
pub(all) struct ScrollSnapType {
  axis : ScrollSnapAxis
  strictness : ScrollSnapStrictness
} derive(Debug, Eq)

///|
let scroll_snap_type_none : ScrollSnapType = { axis: None, strictness: None, }

///|
pub fn ScrollSnapType::none() -> ScrollSnapType {
  scroll_snap_type_none
}

///|
pub fn ScrollSnapType::is_mandatory(self : ScrollSnapType) -> Bool {
  self.strictness == Mandatory
}

///|
pub fn ScrollSnapType::snaps_x(self : ScrollSnapType) -> Bool {
  match self.axis {
    X | Both => true
    None | Y => false
  }
}

///|
pub fn ScrollSnapType::snaps_y(self : ScrollSnapType) -> Bool {
  match self.axis {
    Y | Both => true
    None | X => false
  }
}

///|
/// CSS scroll-snap-align keywords
pub(all) enum ScrollSnapAlign {
  None
  Start
  End
  Center
} derive(Debug, Eq)

///|
/// CSS visibility property
pub(all) enum Visibility {
  Visible // Element is visible (default)
  Hidden // Element is invisible but takes up space
  Collapse // Same as hidden for most elements
} derive(Debug, Eq)

///|
/// CSS pointer-events property (minimum subset for browser hit testing).
pub(all) enum PointerEvents {
  Auto
  None
} derive(Debug, Eq)

///|
/// CSS margin-trim property
pub(all) enum MarginTrim {
  None
  BlockStart
  BlockEnd
  Block
  InlineStart
  InlineEnd
  Inline
} derive(Debug, Eq)

///|
/// CSS multi-column column-fill property.
pub(all) enum ColumnFill {
  Balance
  Auto
} derive(Debug, Eq)

///|
/// CSS break-before property (minimum subset for multicol tests).
pub(all) enum BreakBefore {
  Auto
  Column
  Avoid
} derive(Debug, Eq)

///|
/// CSS break-inside property (minimum subset for multicol tests).
pub(all) enum BreakInside {
  Auto
  Avoid
} derive(Debug, Eq)

///|
/// CSS column-span property.
pub(all) enum ColumnSpan {
  None
  All
} derive(Debug, Eq)

///|
pub fn MarginTrim::trim_block_start(self : MarginTrim) -> Bool {
  match self {
    BlockStart | Block => true
    None | BlockEnd | InlineStart | InlineEnd | Inline => false
  }
}

///|
pub fn MarginTrim::trim_block_end(self : MarginTrim) -> Bool {
  match self {
    BlockEnd | Block => true
    None | BlockStart | InlineStart | InlineEnd | Inline => false
  }
}

///|
/// CSS z-index property
pub(all) enum ZIndex {
  Auto // Stacking order determined by DOM order
  Value(Int) // Explicit stacking level
} derive(Debug, Eq)

///|
/// CSS transform translate value (can be length or percent)
pub(all) enum TranslateValue {
  Length(Double) // Fixed length in pixels
  Percent(Double) // Percentage of element's own dimension (0.0 - 1.0)
} derive(Debug, Eq)

///|
/// CSS transform property - list of transform functions
/// Supports a 2D subset for visual hit testing.
pub(all) struct Transform {
  translate_x : TranslateValue // translateX or first arg of translate()
  translate_y : TranslateValue // translateY or second arg of translate()
  scale_x : Double // scaleX or first arg of scale() (default 1.0)
  scale_y : Double // scaleY or second arg of scale() (default 1.0)
  rotate_degrees : Double // rotate() angle in degrees
  skew_x_degrees : Double // skewX() angle in degrees
  skew_y_degrees : Double // skewY() angle in degrees
  has_matrix : Bool // matrix() is explicitly present
  matrix_a : Double // 2D affine matrix a
  matrix_b : Double // 2D affine matrix b
  matrix_c : Double // 2D affine matrix c
  matrix_d : Double // 2D affine matrix d
  matrix_e : Double // 2D affine matrix e
  matrix_f : Double // 2D affine matrix f
  // matrix3d(): a 16-element column-major 4x4 matrix, or [] when not a 3D
  // matrix. Layout consumers that are 2D-only can ignore this.
  matrix3d : Array[Double]
} derive(Debug, Eq)

///|
/// Whether this transform carries an explicit `matrix3d()`.
pub fn Transform::has_matrix3d(self : Transform) -> Bool {
  self.matrix3d.length() == 16
}

///|
/// Shared immutable identity transform. `Transform` has no mutable fields, so a
/// single shared instance is safe and avoids re-allocating the identity on every
/// `Transform::none()` call (one per default style).
let transform_identity : Transform = {
  translate_x: Length(0.0),
  translate_y: Length(0.0),
  scale_x: 1.0,
  scale_y: 1.0,
  rotate_degrees: 0.0,
  skew_x_degrees: 0.0,
  skew_y_degrees: 0.0,
  has_matrix: false,
  matrix_a: 1.0,
  matrix_b: 0.0,
  matrix_c: 0.0,
  matrix_d: 1.0,
  matrix_e: 0.0,
  matrix_f: 0.0,
  matrix3d: [],
}

///|
/// Create a none/identity transform
pub fn Transform::none() -> Transform {
  transform_identity
}

///|
/// Check if transform is identity (no visual change)
pub fn Transform::is_none(self : Transform) -> Bool {
  let translate_none = match (self.translate_x, self.translate_y) {
    (Length(0.0), Length(0.0)) => true
    (Percent(0.0), Percent(0.0)) => true
    _ => false
  }
  let scale_none = self.scale_x == 1.0 && self.scale_y == 1.0
  let rotate_none = self.rotate_degrees == 0.0
  let skew_none = self.skew_x_degrees == 0.0 && self.skew_y_degrees == 0.0
  let matrix_none = !self.has_matrix ||
    (
      self.matrix_a == 1.0 &&
      self.matrix_b == 0.0 &&
      self.matrix_c == 0.0 &&
      self.matrix_d == 1.0 &&
      self.matrix_e == 0.0 &&
      self.matrix_f == 0.0
    )
  translate_none && scale_none && rotate_none && skew_none && matrix_none
}

///|
/// Check if transform has scale applied
pub fn Transform::has_scale(self : Transform) -> Bool {
  self.scale_x != 1.0 || self.scale_y != 1.0
}

///|
/// Check if transform has skew applied
pub fn Transform::has_skew(self : Transform) -> Bool {
  self.skew_x_degrees != 0.0 || self.skew_y_degrees != 0.0
}

///|
/// Check if transform has an explicit non-identity matrix applied
pub fn Transform::has_affine_matrix(self : Transform) -> Bool {
  self.has_matrix &&
  !(self.matrix_a == 1.0 &&
  self.matrix_b == 0.0 &&
  self.matrix_c == 0.0 &&
  self.matrix_d == 1.0 &&
  self.matrix_e == 0.0 &&
  self.matrix_f == 0.0)
}

///|
/// Return a quarter-turn rotation count (0..3), or -1 for other angles.
pub fn Transform::quarter_turns(self : Transform) -> Int {
  let raw_turns = (self.rotate_degrees / 90.0).round().to_int()
  let snapped_degrees = raw_turns.to_double() * 90.0
  if (self.rotate_degrees - snapped_degrees).abs() > 0.0001 {
    return -1
  }
  let mut turns = raw_turns % 4
  if turns < 0 {
    turns = turns + 4
  }
  turns
}

///|
/// Compute translate X offset given element width
pub fn Transform::compute_translate_x(
  self : Transform,
  element_width : Double,
) -> Double {
  match self.translate_x {
    Length(v) => v
    Percent(p) => element_width * p
  }
}

///|
/// Compute translate Y offset given element height
pub fn Transform::compute_translate_y(
  self : Transform,
  element_height : Double,
) -> Double {
  match self.translate_y {
    Length(v) => v
    Percent(p) => element_height * p
  }
}

///|
/// CSS clip-path property subset used by paint and hit testing.
/// Shape values are pixels; negative values encode percentages as fractions.
pub(all) enum ClipPath {
  None
  Inset(Double, Double, Double, Double) // top, right, bottom, left
  Rect(Double, Double, Double, Double) // top, right, bottom, left coordinates
  Xywh(Double, Double, Double, Double) // x, y, width, height
  Circle(Double, Double, Double) // radius, center-x, center-y
  Ellipse(Double, Double, Double, Double) // radius-x, radius-y, center-x, center-y
  Polygon(Array[(Double, Double)])
} derive(Debug, Eq)

///|
pub fn ClipPath::none() -> ClipPath {
  None
}

///|
/// CSS contain property - uses flags since multiple values can be combined
/// e.g., "contain: layout paint" or "contain: strict"
pub(all) struct Contain {
  size : Bool // Size containment - element size computed independently
  inline_size : Bool // Inline-size containment only (mutually exclusive with size)
  layout : Bool // Layout containment - isolates internal layout
  paint : Bool // Paint containment - clips overflow, creates stacking context
  style : Bool // Style containment - scopes counters/quotes
} derive(Debug, Eq)

///|
/// Shared immutable `Contain` sentinels. `Contain` has no mutable fields, so a
/// single shared instance per keyword is safe and avoids re-allocating on every
/// access (`Contain::none()` runs once per default style).
let contain_none : Contain = {
  size: false,
  inline_size: false,
  layout: false,
  paint: false,
  style: false,
}

///|
let contain_strict : Contain = {
  size: true,
  inline_size: false,
  layout: true,
  paint: true,
  style: true,
}

///|
let contain_content : Contain = {
  size: false,
  inline_size: false,
  layout: true,
  paint: true,
  style: true,
}

///|
pub fn Contain::none() -> Contain {
  contain_none
}

///|
/// strict = size + layout + paint + style
pub fn Contain::strict() -> Contain {
  contain_strict
}

///|
/// content = layout + paint + style (no size)
pub fn Contain::content() -> Contain {
  contain_content
}

///|
pub fn Contain::has_containment(self : Contain) -> Bool {
  self.size || self.inline_size || self.layout || self.paint || self.style
}

///|
/// Whether containment suppresses intrinsic contribution on physical width.
pub fn Style::suppresses_intrinsic_width(self : Style) -> Bool {
  self.contain.size ||
  (self.contain.inline_size && !self.writing_mode.is_vertical())
}

///|
/// Whether containment suppresses intrinsic contribution on physical height.
pub fn Style::suppresses_intrinsic_height(self : Style) -> Bool {
  self.contain.size ||
  (self.contain.inline_size && self.writing_mode.is_vertical())
}

///|
/// Fallback intrinsic contribution on physical width from contain-intrinsic-size.
pub fn Style::contained_intrinsic_width_fallback(self : Style) -> Double {
  if self.writing_mode.is_vertical() {
    match self.contain_intrinsic_block_size {
      Some(v) => if v > 0.0 { v } else { 0.0 }
      None => 0.0
    }
  } else {
    match self.contain_intrinsic_inline_size {
      Some(v) => if v > 0.0 { v } else { 0.0 }
      None => 0.0
    }
  }
}

///|
/// Fallback intrinsic contribution on physical height from contain-intrinsic-size.
pub fn Style::contained_intrinsic_height_fallback(self : Style) -> Double {
  if self.writing_mode.is_vertical() {
    match self.contain_intrinsic_inline_size {
      Some(v) => if v > 0.0 { v } else { 0.0 }
      None => 0.0
    }
  } else {
    match self.contain_intrinsic_block_size {
      Some(v) => if v > 0.0 { v } else { 0.0 }
      None => 0.0
    }
  }
}

///|
/// Whether this style enables CSS multi-column layout.
pub fn Style::has_multicol(self : Style) -> Bool {
  match self.column_count {
    // `column-count: 1` still establishes a multicol container; overflowing
    // content may fragment into additional columns.
    Some(v) => v > 0
    None =>
      match self.column_width {
        Length(v) => v > 0.0
        Percent(v) => v > 0.0
        Calc(px, pct) => px > 0.0 || pct > 0.0
        MathFn(_, _) => true
        Auto | MinContent | MaxContent | FitContent(_) => false
      }
  }
}

///|
/// Vertical alignment for inline elements
pub(all) enum VerticalAlign {
  Baseline // Align baseline (default, simplified to bottom for now)
  Top // Align to top of line box
  Middle // Align middle
  Bottom // Align to bottom of line box
  TextTop // Align to top of parent's font (simplified to Top)
  TextBottom // Align to bottom of parent's font (simplified to Bottom)
  Sub // Subscript position
  Super // Superscript position
} derive(Debug, Eq)

///|
pub impl Show for BorderStyle with fn output(self, logger) {
  let name = match self {
    None => "None"
    Inset => "Inset"
    Groove => "Groove"
    Outset => "Outset"
    Ridge => "Ridge"
    Dotted => "Dotted"
    Dashed => "Dashed"
    Solid => "Solid"
    Double => "Double"
    Hidden => "Hidden"
  }
  logger.write_string(name)
}

///|
pub impl Show for BorderCollapse with fn output(self, logger) {
  let name = match self {
    Separate => "Separate"
    Collapse => "Collapse"
  }
  logger.write_string(name)
}

///|
pub impl Show for TableLayout with fn output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Fixed => "Fixed"
  }
  logger.write_string(name)
}

///|
pub impl Show for CaptionSide with fn output(self, logger) {
  let name = match self {
    Top => "Top"
    Bottom => "Bottom"
  }
  logger.write_string(name)
}

///|
pub impl Show for WhiteSpace with fn output(self, logger) {
  let name = match self {
    Normal => "Normal"
    Nowrap => "Nowrap"
    Pre => "Pre"
    PreWrap => "PreWrap"
    PreLine => "PreLine"
  }
  logger.write_string(name)
}

///|
pub impl Show for TextOverflow with fn output(self, logger) {
  let name = match self {
    Clip => "Clip"
    Ellipsis => "Ellipsis"
  }
  logger.write_string(name)
}

///|
pub impl Show for WritingMode with fn output(self, logger) {
  let name = match self {
    HorizontalTb => "HorizontalTb"
    VerticalRl => "VerticalRl"
    VerticalLr => "VerticalLr"
  }
  logger.write_string(name)
}

///|
pub impl Show for Direction with fn output(self, logger) {
  let name = match self {
    Ltr => "Ltr"
    Rtl => "Rtl"
  }
  logger.write_string(name)
}

///|
pub impl Show for TextAlign with fn output(self, logger) {
  let name = match self {
    Start => "Start"
    End => "End"
    Left => "Left"
    Right => "Right"
    Center => "Center"
    Justify => "Justify"
  }
  logger.write_string(name)
}

///|
pub impl Show for ScrollSnapAxis with fn output(self, logger) {
  let name = match self {
    None => "None"
    X => "X"
    Y => "Y"
    Both => "Both"
  }
  logger.write_string(name)
}

///|
pub impl Show for ScrollSnapStrictness with fn output(self, logger) {
  let name = match self {
    None => "None"
    Mandatory => "Mandatory"
    Proximity => "Proximity"
  }
  logger.write_string(name)
}

///|
pub impl Show for ScrollSnapType with fn output(self, logger) {
  logger.write_string("{axis: ")
  logger.write_string(self.axis.to_string())
  logger.write_string(", strictness: ")
  logger.write_string(self.strictness.to_string())
  logger.write_string("}")
}

///|
pub impl Show for ScrollSnapAlign with fn output(self, logger) {
  let name = match self {
    None => "None"
    Start => "Start"
    End => "End"
    Center => "Center"
  }
  logger.write_string(name)
}

///|
pub impl Show for Visibility with fn output(self, logger) {
  let name = match self {
    Visible => "Visible"
    Hidden => "Hidden"
    Collapse => "Collapse"
  }
  logger.write_string(name)
}

///|
pub impl Show for PointerEvents with fn output(self, logger) {
  let name = match self {
    Auto => "Auto"
    None => "None"
  }
  logger.write_string(name)
}

///|
pub impl Show for MarginTrim with fn output(self, logger) {
  let name = match self {
    None => "None"
    BlockStart => "BlockStart"
    BlockEnd => "BlockEnd"
    Block => "Block"
    InlineStart => "InlineStart"
    InlineEnd => "InlineEnd"
    Inline => "Inline"
  }
  logger.write_string(name)
}

///|
pub impl Show for ColumnFill with fn output(self, logger) {
  let name = match self {
    Balance => "Balance"
    Auto => "Auto"
  }
  logger.write_string(name)
}

///|
pub impl Show for BreakBefore with fn output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Column => "Column"
    Avoid => "Avoid"
  }
  logger.write_string(name)
}

///|
pub impl Show for BreakInside with fn output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Avoid => "Avoid"
  }
  logger.write_string(name)
}

///|
pub impl Show for ColumnSpan with fn output(self, logger) {
  let name = match self {
    None => "None"
    All => "All"
  }
  logger.write_string(name)
}

///|
pub impl Show for ZIndex with fn output(self, logger) {
  let text = match self {
    Auto => "Auto"
    Value(v) => "Value(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for TranslateValue with fn output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for Transform with fn output(self, logger) {
  logger.write_string("{translate_x: ")
  logger.write_string(self.translate_x.to_string())
  logger.write_string(", translate_y: ")
  logger.write_string(self.translate_y.to_string())
  logger.write_string(", scale_x: ")
  logger.write_string(self.scale_x.to_string())
  logger.write_string(", scale_y: ")
  logger.write_string(self.scale_y.to_string())
  logger.write_string(", rotate_degrees: ")
  logger.write_string(self.rotate_degrees.to_string())
  logger.write_string(", skew_x_degrees: ")
  logger.write_string(self.skew_x_degrees.to_string())
  logger.write_string(", skew_y_degrees: ")
  logger.write_string(self.skew_y_degrees.to_string())
  logger.write_string(", has_matrix: ")
  logger.write_string(self.has_matrix.to_string())
  logger.write_string(", matrix: [")
  logger.write_string(self.matrix_a.to_string())
  logger.write_string(", ")
  logger.write_string(self.matrix_b.to_string())
  logger.write_string(", ")
  logger.write_string(self.matrix_c.to_string())
  logger.write_string(", ")
  logger.write_string(self.matrix_d.to_string())
  logger.write_string(", ")
  logger.write_string(self.matrix_e.to_string())
  logger.write_string(", ")
  logger.write_string(self.matrix_f.to_string())
  logger.write_string("]")
  if self.matrix3d.length() == 16 {
    logger.write_string(", matrix3d: [")
    for i = 0; i < 16; i = i + 1 {
      if i > 0 {
        logger.write_string(", ")
      }
      logger.write_string(self.matrix3d[i].to_string())
    }
    logger.write_string("]")
  }
  logger.write_string("}")
}

///|
pub impl Show for Contain with fn output(self, logger) {
  logger.write_string("{size: ")
  logger.write_string(self.size.to_string())
  logger.write_string(", inline_size: ")
  logger.write_string(self.inline_size.to_string())
  logger.write_string(", layout: ")
  logger.write_string(self.layout.to_string())
  logger.write_string(", paint: ")
  logger.write_string(self.paint.to_string())
  logger.write_string(", style: ")
  logger.write_string(self.style.to_string())
  logger.write_string("}")
}

///|
pub impl Show for VerticalAlign with fn output(self, logger) {
  let name = match self {
    Baseline => "Baseline"
    Top => "Top"
    Middle => "Middle"
    Bottom => "Bottom"
    TextTop => "TextTop"
    TextBottom => "TextBottom"
    Sub => "Sub"
    Super => "Super"
  }
  logger.write_string(name)
}

///|
pub struct BoxShadow {
  inset : Bool
  offset_x : Double
  offset_y : Double
  blur_radius : Double
  spread_radius : Double
  color : @types.Color
} derive(Debug, Eq)

///|
pub fn BoxShadow::new(
  inset : Bool,
  offset_x : Double,
  offset_y : Double,
  blur_radius : Double,
  spread_radius : Double,
  color : @types.Color,
) -> BoxShadow {
  { inset, offset_x, offset_y, blur_radius, spread_radius, color, }
}

///|
/// CSS Style definition for layout computation
/// All fields are mutable to support Yoga-like setter API
pub(all) struct Style {
  mut display : @types.Display
  mut position : @types.Position
  mut float : @types.Float
  mut clear : @types.Clear
  // Box sizing
  mut box_sizing : @types.BoxSizing
  // Overflow
  mut overflow_x : @types.Overflow
  mut overflow_y : @types.Overflow
  // Scroll snap
  mut scroll_snap_type : ScrollSnapType
  mut scroll_snap_align_x : ScrollSnapAlign
  mut scroll_snap_align_y : ScrollSnapAlign
  // Sizing
  mut width : @types.Dimension
  mut height : @types.Dimension
  mut min_width : @types.Dimension
  mut min_height : @types.Dimension
  mut max_width : @types.Dimension
  mut max_height : @types.Dimension
  // Box model
  mut margin : @types.Rect[@types.Dimension]
  mut padding : @types.Rect[@types.Dimension]
  mut border : @types.Rect[@types.Dimension]
  mut border_style : @types.Rect[BorderStyle]
  mut border_color : @types.Rect[@types.Color]
  mut margin_trim : MarginTrim
  // Flexbox
  mut flex_direction : @types.FlexDirection
  mut flex_wrap : @types.FlexWrap
  mut justify_content : @types.Alignment
  mut align_items : @types.Alignment
  mut align_content : @types.Alignment
  // Whether overflow alignment requested `unsafe` position.
  // Unqualified values default to safe behavior for initial scroll positioning.
  mut justify_content_unsafe : Bool
  mut align_content_unsafe : Bool
  mut align_self : @types.AlignSelf
  mut flex_grow : Double
  mut flex_shrink : Double
  mut flex_basis : @types.Dimension
  mut order : Int // Flex item order (default 0)
  // Gap
  mut row_gap : @types.Dimension
  mut column_gap : @types.Dimension
  mut column_gap_is_normal : Bool
  // Multi-column layout
  mut column_count : Int? // None = auto
  mut column_width : @types.Dimension // auto or fixed width
  mut column_fill : ColumnFill
  // Aspect ratio (width / height)
  mut aspect_ratio : Double?
  // Inset for position: absolute (left, right, top, bottom)
  mut inset : @types.Rect[@types.Dimension]
  // Grid container properties
  mut grid_template_rows : Array[@types.TrackSizingFunction]
  mut grid_template_columns : Array[@types.TrackSizingFunction]
  mut grid_auto_rows : Array[@types.TrackSizingFunction]
  mut grid_auto_columns : Array[@types.TrackSizingFunction]
  mut grid_auto_flow : @types.GridAutoFlow
  // Named lines declared in grid-template-columns/rows. Index i holds the names
  // declared at grid line i (0-based), so the array length is tracks + 1.
  // e.g. `[a] 1fr [b c] 2fr` => [["a"], ["b", "c"], []]
  mut grid_template_column_line_names : Array[Array[String]]
  mut grid_template_row_line_names : Array[Array[String]]
  // Axis kind: Explicit track list (default), subgrid, or masonry.
  mut grid_template_columns_kind : @types.GridTemplateKind
  mut grid_template_rows_kind : @types.GridTemplateKind
  // Grid template areas (each string is a row, e.g. ["header header", "sidebar main"])
  mut grid_template_areas : Array[String]
  // Grid item properties
  mut grid_row : @types.GridLine
  mut grid_column : @types.GridLine
  mut grid_area : String? // Named area for item placement
  // justify-items for grid (different from justify-content)
  mut justify_items : @types.Alignment
  // justify-self for grid items (horizontal self-alignment)
  mut justify_self : @types.AlignSelf
  // Font properties (for baseline calculation)
  mut font_size : Double // Computed font size in pixels (default 16.0)
  mut font_weight : Double // Computed font weight (100-900, default 400)
  mut font_family : String // Computed font family (default "")
  mut line_height : Double // Computed line height in pixels (default = font_size)
  // Text wrapping and direction
  mut text_align : TextAlign
  mut white_space : WhiteSpace // white-space: normal | nowrap | pre | pre-wrap | pre-line
  mut text_overflow : TextOverflow // text-overflow: clip | ellipsis
  mut writing_mode : WritingMode // writing-mode: horizontal-tb | vertical-rl | vertical-lr
  mut direction : Direction // direction: ltr | rtl (inline text direction)
  // Vertical alignment for inline elements
  mut vertical_align : VerticalAlign
  // Clip (legacy, deprecated but widely used for a11y)
  mut clip : @types.ClipRect
  // Clip path (minimum paint/hit-test subset)
  mut clip_path : ClipPath
  // Paint properties (visual, not layout)
  mut visibility : Visibility
  mut pointer_events : PointerEvents
  mut z_index : ZIndex
  mut opacity : Double // 0.0 = transparent, 1.0 = opaque
  // Color properties (resolved RGBA values)
  mut color : @types.Color // Text color (inherited)
  mut background_color : @types.Color // Background color (not inherited)
  mut background_image : @types.BackgroundImage // Background image (gradient etc.)
  mut box_shadows : Array[BoxShadow]
  // Containment (for layout optimization)
  mut contain : Contain
  // Fragmentation
  mut break_before : BreakBefore
  mut break_after : BreakBefore
  mut break_inside : BreakInside
  mut column_span : ColumnSpan
  // contain-intrinsic-* fallback sizes (content-box lengths in px)
  mut contain_intrinsic_inline_size : Double?
  mut contain_intrinsic_block_size : Double?
  // CSS transform (visual offset, applied in paint phase)
  mut transform : Transform
  // Individual transform properties (`translate` / `scale` / `rotate`),
  // composed into one Transform. Distinct from the `transform` shorthand.
  individual_transform : Transform
  // Animation properties (parallel longhand lists; index = animation in the
  // comma-separated list). Set by the `animation` shorthand or the longhands.
  animation_name : Array[String]
  animation_duration : Array[Double] // seconds
  animation_timing_function : Array[@types.Easing]
  animation_delay : Array[Double] // seconds
  animation_iteration_count : Array[@types.AnimationIterationCount]
  animation_direction : Array[@types.AnimationDirection]
  animation_fill_mode : Array[@types.AnimationFillMode]
  animation_play_state : Array[@types.AnimationPlayState]
  // Transition properties (parallel longhand lists).
  transition_property : Array[String]
  transition_duration : Array[Double] // seconds
  transition_timing_function : Array[@types.Easing]
  transition_delay : Array[Double] // seconds
  // CSS filter / backdrop-filter presence flag. Layout only cares whether
  // such a property establishes a containing block for abspos descendants,
  // not the actual filter functions.
  mut has_filter : Bool
  // CSS zoom (affects layout scaling, inherited)
  mut zoom : Double // zoom factor (1.0 = 100%, 2.0 = 200%)
  // Table properties
  mut border_spacing : Double // border-spacing horizontal in pixels
  mut border_spacing_vertical : Double // border-spacing vertical in pixels
  mut border_collapse : BorderCollapse // border-collapse: separate | collapse
  mut table_layout : TableLayout // table-layout: auto | fixed
  mut caption_side : CaptionSide // caption-side: top | bottom
  // Table cell properties (from HTML attributes)
  mut rowspan : Int // rowspan attribute (default 1)
  mut colspan : Int // colspan attribute (default 1)
  // Border radius (computed px values for rounded corners)
  mut border_top_left_radius : Double
  mut border_top_right_radius : Double
  mut border_bottom_right_radius : Double
  mut border_bottom_left_radius : Double
  // Text decoration
  mut text_decoration_underline : Bool
  mut text_decoration_line_through : Bool
  mut text_decoration_overline : Bool
  // Letter/word spacing
  mut letter_spacing : Double // in pixels, 0 = normal
  mut word_spacing : Double // in pixels, 0 = normal
} derive(Debug, Eq)

///|
/// Compare only fields that can affect layout results.
///
/// Paint-only fields such as colors, backgrounds, shadows, opacity,
/// pointer-events, z-index, and clipping are intentionally ignored so callers
/// can distinguish layout invalidation from repaint-only changes.
pub fn Style::layout_eq(self : Style, other : Style) -> Bool {
  self.display == other.display &&
  self.position == other.position &&
  self.float == other.float &&
  self.clear == other.clear &&
  self.box_sizing == other.box_sizing &&
  self.overflow_x == other.overflow_x &&
  self.overflow_y == other.overflow_y &&
  self.width == other.width &&
  self.height == other.height &&
  self.min_width == other.min_width &&
  self.min_height == other.min_height &&
  self.max_width == other.max_width &&
  self.max_height == other.max_height &&
  self.margin == other.margin &&
  self.padding == other.padding &&
  self.border == other.border &&
  self.border_style == other.border_style &&
  self.margin_trim == other.margin_trim &&
  self.flex_direction == other.flex_direction &&
  self.flex_wrap == other.flex_wrap &&
  self.justify_content == other.justify_content &&
  self.align_items == other.align_items &&
  self.align_content == other.align_content &&
  self.justify_content_unsafe == other.justify_content_unsafe &&
  self.align_content_unsafe == other.align_content_unsafe &&
  self.align_self == other.align_self &&
  self.flex_grow == other.flex_grow &&
  self.flex_shrink == other.flex_shrink &&
  self.flex_basis == other.flex_basis &&
  self.order == other.order &&
  self.row_gap == other.row_gap &&
  self.column_gap == other.column_gap &&
  self.column_gap_is_normal == other.column_gap_is_normal &&
  self.column_count == other.column_count &&
  self.column_width == other.column_width &&
  self.column_fill == other.column_fill &&
  self.aspect_ratio == other.aspect_ratio &&
  self.inset == other.inset &&
  self.grid_template_rows == other.grid_template_rows &&
  self.grid_template_columns == other.grid_template_columns &&
  self.grid_auto_rows == other.grid_auto_rows &&
  self.grid_auto_columns == other.grid_auto_columns &&
  self.grid_auto_flow == other.grid_auto_flow &&
  self.grid_template_column_line_names == other.grid_template_column_line_names &&
  self.grid_template_row_line_names == other.grid_template_row_line_names &&
  self.grid_template_columns_kind == other.grid_template_columns_kind &&
  self.grid_template_rows_kind == other.grid_template_rows_kind &&
  self.grid_template_areas == other.grid_template_areas &&
  self.grid_row == other.grid_row &&
  self.grid_column == other.grid_column &&
  self.grid_area == other.grid_area &&
  self.justify_items == other.justify_items &&
  self.justify_self == other.justify_self &&
  self.font_size == other.font_size &&
  self.font_weight == other.font_weight &&
  self.font_family == other.font_family &&
  self.line_height == other.line_height &&
  self.text_align == other.text_align &&
  self.white_space == other.white_space &&
  self.text_overflow == other.text_overflow &&
  self.writing_mode == other.writing_mode &&
  self.direction == other.direction &&
  self.vertical_align == other.vertical_align &&
  self.visibility == other.visibility &&
  self.contain == other.contain &&
  self.break_before == other.break_before &&
  self.break_after == other.break_after &&
  self.break_inside == other.break_inside &&
  self.column_span == other.column_span &&
  self.contain_intrinsic_inline_size == other.contain_intrinsic_inline_size &&
  self.contain_intrinsic_block_size == other.contain_intrinsic_block_size &&
  self.transform == other.transform &&
  self.individual_transform == other.individual_transform &&
  self.has_filter == other.has_filter &&
  self.zoom == other.zoom &&
  self.border_spacing == other.border_spacing &&
  self.border_spacing_vertical == other.border_spacing_vertical &&
  self.border_collapse == other.border_collapse &&
  self.table_layout == other.table_layout &&
  self.caption_side == other.caption_side &&
  self.rowspan == other.rowspan &&
  self.colspan == other.colspan &&
  self.letter_spacing == other.letter_spacing &&
  self.word_spacing == other.word_spacing
}

///|
pub fn Style::default() -> Style {
  {
    display: Block,
    position: Static,
    float: None,
    clear: None,
    box_sizing: ContentBox,
    overflow_x: Visible,
    overflow_y: Visible,
    scroll_snap_type: ScrollSnapType::none(),
    scroll_snap_align_x: None,
    scroll_snap_align_y: None,
    width: Auto,
    height: Auto,
    min_width: Auto,
    min_height: Auto,
    max_width: Auto,
    max_height: Auto,
    margin: {
      left: Length(0.0),
      right: Length(0.0),
      top: Length(0.0),
      bottom: Length(0.0),
    },
    border_style: { left: None, right: None, top: None, bottom: None, },
    border_color: {
      left: @types.Color::transparent(),
      right: @types.Color::transparent(),
      top: @types.Color::transparent(),
      bottom: @types.Color::transparent(),
    },
    padding: {
      left: Length(0.0),
      right: Length(0.0),
      top: Length(0.0),
      bottom: Length(0.0),
    },
    border: {
      left: Length(0.0),
      right: Length(0.0),
      top: Length(0.0),
      bottom: Length(0.0),
    },
    margin_trim: None,
    flex_direction: Row,
    flex_wrap: NoWrap,
    justify_content: Start,
    align_items: Stretch,
    align_content: Stretch,
    justify_content_unsafe: false,
    align_content_unsafe: false,
    align_self: Auto,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    flex_basis: Auto,
    order: 0,
    row_gap: Length(0.0),
    column_gap: Length(0.0),
    column_gap_is_normal: true,
    column_count: None,
    column_width: Auto,
    column_fill: Balance,
    aspect_ratio: None,
    inset: { left: Auto, right: Auto, top: Auto, bottom: Auto, },
    grid_template_rows: [],
    grid_template_columns: [],
    grid_auto_rows: [],
    grid_auto_columns: [],
    grid_auto_flow: Row,
    grid_template_column_line_names: [],
    grid_template_row_line_names: [],
    grid_template_columns_kind: Explicit,
    grid_template_rows_kind: Explicit,
    grid_template_areas: [],
    grid_row: @types.GridLine::auto(),
    grid_column: @types.GridLine::auto(),
    grid_area: None,
    justify_items: Stretch,
    justify_self: Auto,
    font_size: 16.0,
    font_weight: 400.0,
    font_family: "",
    line_height: 19.2, // 16.0 * 1.2 (CSS initial: normal)
    text_align: Start,
    white_space: Normal,
    text_overflow: Clip,
    writing_mode: HorizontalTb,
    direction: Ltr,
    vertical_align: Baseline,
    clip: Auto,
    clip_path: ClipPath::none(),
    visibility: Visible,
    pointer_events: Auto,
    z_index: Auto,
    opacity: 1.0,
    color: @types.Color::black(),
    background_color: @types.Color::transparent(),
    background_image: None,
    box_shadows: [],
    contain: Contain::none(),
    break_before: Auto,
    break_after: Auto,
    break_inside: Auto,
    column_span: None,
    contain_intrinsic_inline_size: None,
    contain_intrinsic_block_size: None,
    transform: Transform::none(),
    individual_transform: Transform::none(),
    animation_name: [],
    animation_duration: [],
    animation_timing_function: [],
    animation_delay: [],
    animation_iteration_count: [],
    animation_direction: [],
    animation_fill_mode: [],
    animation_play_state: [],
    transition_property: [],
    transition_duration: [],
    transition_timing_function: [],
    transition_delay: [],
    has_filter: false,
    zoom: 1.0,
    border_spacing: 0.0,
    border_spacing_vertical: 0.0,
    border_collapse: Separate,
    table_layout: Auto,
    caption_side: Top,
    rowspan: 1,
    colspan: 1,
    border_top_left_radius: 0.0,
    border_top_right_radius: 0.0,
    border_bottom_right_radius: 0.0,
    border_bottom_left_radius: 0.0,
    text_decoration_underline: false,
    text_decoration_line_through: false,
    text_decoration_overline: false,
    letter_spacing: 0.0,
    word_spacing: 0.0,
  }
}

///|
pub extend BorderCollapse with Debug::{to_repr}

///|
pub extend BorderCollapse with Eq::{not_equal, equal}

///|
pub extend BorderCollapse with Show::{to_string, output}

///|
pub extend BorderStyle with Debug::{to_repr}

///|
pub extend BorderStyle with Eq::{not_equal, equal}

///|
pub extend BorderStyle with Show::{to_string, output}

///|
pub extend BoxShadow with Debug::{to_repr}

///|
pub extend BoxShadow with Eq::{not_equal, equal}

///|
pub extend BreakBefore with Debug::{to_repr}

///|
pub extend BreakBefore with Eq::{not_equal, equal}

///|
pub extend BreakBefore with Show::{to_string, output}

///|
pub extend BreakInside with Debug::{to_repr}

///|
pub extend BreakInside with Eq::{not_equal, equal}

///|
pub extend BreakInside with Show::{to_string, output}

///|
pub extend CaptionSide with Debug::{to_repr}

///|
pub extend CaptionSide with Eq::{not_equal, equal}

///|
pub extend CaptionSide with Show::{to_string, output}

///|
pub extend ClipPath with Debug::{to_repr}

///|
pub extend ClipPath with Eq::{not_equal, equal}

///|
pub extend ColumnFill with Debug::{to_repr}

///|
pub extend ColumnFill with Eq::{not_equal, equal}

///|
pub extend ColumnFill with Show::{to_string, output}

///|
pub extend ColumnSpan with Debug::{to_repr}

///|
pub extend ColumnSpan with Eq::{not_equal, equal}

///|
pub extend ColumnSpan with Show::{to_string, output}

///|
pub extend Contain with Debug::{to_repr}

///|
pub extend Contain with Eq::{not_equal, equal}

///|
pub extend Contain with Show::{to_string, output}

///|
pub extend Direction with Debug::{to_repr}

///|
pub extend Direction with Eq::{not_equal, equal}

///|
pub extend Direction with Show::{to_string, output}

///|
pub extend MarginTrim with Debug::{to_repr}

///|
pub extend MarginTrim with Eq::{not_equal, equal}

///|
pub extend MarginTrim with Show::{to_string, output}

///|
pub extend PointerEvents with Debug::{to_repr}

///|
pub extend PointerEvents with Eq::{not_equal, equal}

///|
pub extend PointerEvents with Show::{to_string, output}

///|
pub extend ScrollSnapAlign with Debug::{to_repr}

///|
pub extend ScrollSnapAlign with Eq::{not_equal, equal}

///|
pub extend ScrollSnapAlign with Show::{to_string, output}

///|
pub extend ScrollSnapAxis with Debug::{to_repr}

///|
pub extend ScrollSnapAxis with Eq::{not_equal, equal}

///|
pub extend ScrollSnapAxis with Show::{to_string, output}

///|
pub extend ScrollSnapStrictness with Debug::{to_repr}

///|
pub extend ScrollSnapStrictness with Eq::{not_equal, equal}

///|
pub extend ScrollSnapStrictness with Show::{to_string, output}

///|
pub extend ScrollSnapType with Debug::{to_repr}

///|
pub extend ScrollSnapType with Eq::{not_equal, equal}

///|
pub extend ScrollSnapType with Show::{to_string, output}

///|
pub extend Style with Debug::{to_repr}

///|
pub extend Style with Eq::{not_equal, equal}

///|
pub extend TableLayout with Debug::{to_repr}

///|
pub extend TableLayout with Eq::{not_equal, equal}

///|
pub extend TableLayout with Show::{to_string, output}

///|
pub extend TextAlign with Debug::{to_repr}

///|
pub extend TextAlign with Eq::{not_equal, equal}

///|
pub extend TextAlign with Show::{to_string, output}

///|
pub extend TextOverflow with Debug::{to_repr}

///|
pub extend TextOverflow with Eq::{not_equal, equal}

///|
pub extend TextOverflow with Show::{to_string, output}

///|
pub extend Transform with Debug::{to_repr}

///|
pub extend Transform with Eq::{not_equal, equal}

///|
pub extend Transform with Show::{to_string, output}

///|
pub extend TranslateValue with Debug::{to_repr}

///|
pub extend TranslateValue with Eq::{not_equal, equal}

///|
pub extend TranslateValue with Show::{to_string, output}

///|
pub extend VerticalAlign with Debug::{to_repr}

///|
pub extend VerticalAlign with Eq::{not_equal, equal}

///|
pub extend VerticalAlign with Show::{to_string, output}

///|
pub extend Visibility with Debug::{to_repr}

///|
pub extend Visibility with Eq::{not_equal, equal}

///|
pub extend Visibility with Show::{to_string, output}

///|
pub extend WhiteSpace with Debug::{to_repr}

///|
pub extend WhiteSpace with Eq::{not_equal, equal}

///|
pub extend WhiteSpace with Show::{to_string, output}

///|
pub extend WritingMode with Debug::{to_repr}

///|
pub extend WritingMode with Eq::{not_equal, equal}

///|
pub extend WritingMode with Show::{to_string, output}

///|
pub extend ZIndex with Debug::{to_repr}

///|
pub extend ZIndex with Eq::{not_equal, equal}

///|
pub extend ZIndex with Show::{to_string, output}
