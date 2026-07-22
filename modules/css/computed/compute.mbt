///|
/// CSS Computed Values
/// Resolves cascaded values to computed values with inheritance

///|
/// Computed values context for resolving relative units
pub(all) struct ComputeContext {
  /// Parent's computed style (for inheritance)
  parent_style : @style.Style?
  /// Root font size (for rem units)
  root_font_size : Double
  /// Current font size (for em units)
  font_size : Double
  /// Viewport width (for vw units)
  viewport_width : Double
  /// Viewport height (for vh units)
  viewport_height : Double
  /// CSS Custom Properties (variables) - inherited from parent and local
  custom_properties : Map[String, String]
}

///|
/// Reserved implementation sentinel, not a supported author custom property.
let internal_effective_color_scheme_key = "--milky-css-effective-color-scheme"

///|
fn view_to_string(v : StringView) -> String {
  let sb = StringBuilder::new()
  sb.write_stringview(v)
  sb.to_string()
}

///|
/// Allocation-free prefix test for the hot cascade/compute path.
/// MoonBit's `String::has_prefix` runs a Boyer-Moore-Horspool search that
/// allocates a skip table (~850 bytes) per call; comparing UTF-16 code units
/// directly avoids that. This runs per declaration (the custom-property `--`
/// test) for every element, so the per-call allocation showed up in profiling.
fn starts_with(s : String, prefix : String) -> Bool {
  let pl = prefix.length()
  if pl > s.length() {
    return false
  }
  for i in 0..<pl {
    if s[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
/// StringView variant of `starts_with` for the `resolve_dimension` hot path,
/// where the value is already a trimmed view. Avoids the per-call
/// Boyer-Moore-Horspool skip-table allocation of `StringView::has_prefix`,
/// which ran up to four times (calc/min/max/clamp) for every plain px/%
/// dimension before reaching the unit dispatch.
fn view_starts_with(s : StringView, prefix : String) -> Bool {
  let pl = prefix.length()
  if pl > s.length() {
    return false
  }
  for i in 0..<pl {
    if s[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
pub fn ComputeContext::new() -> ComputeContext {
  {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
}

///|
fn ch_unit_ratio(ctx : ComputeContext) -> Double {
  match ctx.parent_style {
    Some(style) =>
      if style.font_family.to_lower().contains("ahem") {
        1.0
      } else {
        0.5
      }
    None => 0.5
  }
}

///|
pub fn ComputeContext::with_parent(parent : @style.Style) -> ComputeContext {
  {
    parent_style: Some(parent),
    root_font_size: 16.0,
    font_size: parent.font_size,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
}

///|
/// Create context with parent style and inherited custom properties
pub fn ComputeContext::with_parent_and_vars(
  parent : @style.Style,
  parent_vars : Map[String, String],
) -> ComputeContext {
  // Copy parent vars for inheritance (custom properties inherit by default)
  let vars : Map[String, String] = Map([])
  for k, v in parent_vars {
    vars[k] = v
  }
  {
    parent_style: Some(parent),
    root_font_size: 16.0,
    font_size: parent.font_size,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: vars,
  }
}

///|
/// Create context with custom viewport dimensions
pub fn ComputeContext::with_viewport(
  viewport_width : Double,
  viewport_height : Double,
) -> ComputeContext {
  {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width,
    viewport_height,
    custom_properties: Map([]),
  }
}

///|
/// Mutable style builder for collecting computed values
priv struct StyleBuilder {
  mut display : @types.Display
  mut position : @types.Position
  mut float : @types.Float
  mut clear : @types.Clear
  mut box_sizing : @types.BoxSizing
  mut overflow_x : @types.Overflow
  mut overflow_y : @types.Overflow
  mut scroll_snap_type : @style.ScrollSnapType
  mut scroll_snap_align_x : @style.ScrollSnapAlign
  mut scroll_snap_align_y : @style.ScrollSnapAlign
  mut width : @types.Dimension
  mut height : @types.Dimension
  mut min_width : @types.Dimension
  mut min_height : @types.Dimension
  mut max_width : @types.Dimension
  mut max_height : @types.Dimension
  mut margin_top : @types.Dimension
  mut margin_right : @types.Dimension
  mut margin_bottom : @types.Dimension
  mut margin_left : @types.Dimension
  mut margin_trim : @style.MarginTrim
  mut padding_top : @types.Dimension
  mut padding_right : @types.Dimension
  mut padding_bottom : @types.Dimension
  mut padding_left : @types.Dimension
  mut border_top : @types.Dimension
  mut border_right : @types.Dimension
  mut border_bottom : @types.Dimension
  mut border_left : @types.Dimension
  mut border_style_top : @style.BorderStyle
  mut border_style_right : @style.BorderStyle
  mut border_style_bottom : @style.BorderStyle
  mut border_style_left : @style.BorderStyle
  mut border_color_top : @types.Color
  mut border_color_right : @types.Color
  mut border_color_bottom : @types.Color
  mut border_color_left : @types.Color
  mut flex_direction : @types.FlexDirection
  mut flex_wrap : @types.FlexWrap
  mut justify_content : @types.Alignment
  mut align_items : @types.Alignment
  mut align_content : @types.Alignment
  mut justify_content_unsafe : Bool
  mut align_content_unsafe : Bool
  mut align_self : @types.AlignSelf
  mut justify_self : @types.AlignSelf
  mut justify_items : @types.Alignment
  mut flex_grow : Double
  mut flex_shrink : Double
  mut flex_basis : @types.Dimension
  mut order : Int
  mut row_gap : @types.Dimension
  mut column_gap : @types.Dimension
  mut column_gap_is_normal : Bool
  mut column_count : Int?
  mut column_width : @types.Dimension
  mut column_fill : @style.ColumnFill
  mut aspect_ratio : Double?
  mut inset_top : @types.Dimension
  mut inset_right : @types.Dimension
  mut inset_bottom : @types.Dimension
  mut inset_left : @types.Dimension
  mut grid_auto_flow : @types.GridAutoFlow
  mut grid_template_columns : Array[@types.TrackSizingFunction]
  mut grid_template_rows : Array[@types.TrackSizingFunction]
  mut grid_auto_rows : Array[@types.TrackSizingFunction]
  mut grid_auto_columns : Array[@types.TrackSizingFunction]
  // Named lines declared in grid-template-columns/rows (index = grid line)
  mut grid_template_column_line_names : Array[Array[String]]
  mut grid_template_row_line_names : Array[Array[String]]
  // Axis kind: Explicit track list (default), subgrid, or masonry.
  mut grid_template_columns_kind : @types.GridTemplateKind
  mut grid_template_rows_kind : @types.GridTemplateKind
  // Grid template areas (container)
  mut grid_template_areas : Array[String]
  // Grid item placement
  mut grid_column_start : @types.GridPlacement
  mut grid_column_end : @types.GridPlacement
  mut grid_row_start : @types.GridPlacement
  mut grid_row_end : @types.GridPlacement
  // Grid area name (item)
  mut grid_area : String?
  // Font properties
  mut font_size : Double
  mut font_weight : Double
  mut font_family : String
  mut line_height : Double
  // Text wrapping and direction
  mut text_align : @style.TextAlign
  mut white_space : @style.WhiteSpace
  mut text_overflow : @style.TextOverflow
  mut writing_mode : @style.WritingMode
  mut direction : @style.Direction
  // Vertical alignment for inline elements
  mut vertical_align : @style.VerticalAlign
  // Clip (legacy)
  mut clip : @types.ClipRect
  mut clip_path : @style.ClipPath
  // Paint properties
  mut visibility : @style.Visibility
  mut pointer_events : @style.PointerEvents
  mut z_index : @style.ZIndex
  mut opacity : Double
  // Color properties
  mut color : @types.Color
  mut background_color : @types.Color
  mut background_image : @types.BackgroundImage
  mut box_shadows : Array[@style.BoxShadow]
  // Containment
  mut contain : @style.Contain
  // Fragmentation
  mut break_before : @style.BreakBefore
  mut break_after : @style.BreakBefore
  mut break_inside : @style.BreakInside
  mut column_span : @style.ColumnSpan
  mut contain_intrinsic_inline_size : Double?
  mut contain_intrinsic_block_size : Double?
  // Transform
  mut transform : @style.Transform
  mut individual_transform : @style.Transform
  // Animation / transition properties (parallel longhand lists).
  mut animation_name : Array[String]
  mut animation_duration : Array[Double]
  mut animation_timing_function : Array[@types.Easing]
  mut animation_delay : Array[Double]
  mut animation_iteration_count : Array[@types.AnimationIterationCount]
  mut animation_direction : Array[@types.AnimationDirection]
  mut animation_fill_mode : Array[@types.AnimationFillMode]
  mut animation_play_state : Array[@types.AnimationPlayState]
  mut transition_property : Array[String]
  mut transition_duration : Array[Double]
  mut transition_timing_function : Array[@types.Easing]
  mut transition_delay : Array[Double]
  // CSS filter / backdrop-filter presence (not none). Layout uses this only
  // to know that the element establishes a containing block for abspos.
  mut has_filter : Bool
  // Zoom (affects layout scaling)
  mut zoom : Double
  // Table properties
  mut border_spacing : Double
  mut border_spacing_vertical : Double
  mut border_collapse : @style.BorderCollapse
  mut table_layout : @style.TableLayout
  mut caption_side : @style.CaptionSide
  // Table cell properties (not mutable via CSS, set from HTML attributes)
  rowspan : Int
  colspan : Int
  // Border radius
  mut border_top_left_radius : Double
  mut border_top_right_radius : Double
  mut border_bottom_right_radius : Double
  mut border_bottom_left_radius : Double
  mut text_decoration_underline : Bool
  mut text_decoration_line_through : Bool
  mut text_decoration_overline : Bool
  mut letter_spacing : Double
  mut word_spacing : Double
}

///|
fn StyleBuilder::new() -> StyleBuilder {
  {
    display: Block,
    position: Static,
    float: None,
    clear: None,
    box_sizing: ContentBox,
    overflow_x: Visible,
    overflow_y: Visible,
    scroll_snap_type: @style.ScrollSnapType::none(),
    scroll_snap_align_x: None,
    scroll_snap_align_y: None,
    width: Auto,
    height: Auto,
    min_width: Auto,
    min_height: Auto,
    max_width: Auto,
    max_height: Auto,
    margin_top: Length(0.0),
    margin_right: Length(0.0),
    margin_bottom: Length(0.0),
    margin_left: Length(0.0),
    margin_trim: None,
    padding_top: Length(0.0),
    padding_right: Length(0.0),
    padding_bottom: Length(0.0),
    padding_left: Length(0.0),
    border_top: Length(0.0),
    border_right: Length(0.0),
    border_bottom: Length(0.0),
    border_left: Length(0.0),
    border_style_top: None,
    border_style_right: None,
    border_style_bottom: None,
    border_style_left: None,
    border_color_top: @types.Color::transparent(),
    border_color_right: @types.Color::transparent(),
    border_color_bottom: @types.Color::transparent(),
    border_color_left: @types.Color::transparent(),
    flex_direction: Row,
    flex_wrap: NoWrap,
    justify_content: FlexStart,
    align_items: Stretch,
    align_content: Stretch,
    justify_content_unsafe: false,
    align_content_unsafe: false,
    align_self: Auto,
    justify_self: Auto,
    justify_items: Stretch,
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
    inset_top: Auto,
    inset_right: Auto,
    inset_bottom: Auto,
    inset_left: Auto,
    grid_auto_flow: Row,
    grid_template_columns: [],
    grid_template_rows: [],
    grid_auto_rows: [],
    grid_auto_columns: [],
    grid_template_column_line_names: [],
    grid_template_row_line_names: [],
    grid_template_columns_kind: Explicit,
    grid_template_rows_kind: Explicit,
    grid_template_areas: [],
    grid_column_start: Auto,
    grid_column_end: Auto,
    grid_row_start: Auto,
    grid_row_end: Auto,
    grid_area: None,
    font_size: 16.0,
    font_weight: 400.0,
    font_family: "",
    line_height: 16.0,
    text_align: Start,
    white_space: Normal,
    text_overflow: Clip,
    writing_mode: HorizontalTb,
    direction: Ltr,
    vertical_align: Baseline,
    clip: Auto,
    clip_path: @style.ClipPath::none(),
    visibility: Visible,
    pointer_events: Auto,
    z_index: Auto,
    opacity: 1.0,
    color: @types.Color::black(),
    background_color: @types.Color::transparent(),
    background_image: None,
    box_shadows: [],
    contain: @style.Contain::none(),
    break_before: Auto,
    break_after: Auto,
    break_inside: Auto,
    column_span: None,
    contain_intrinsic_inline_size: None,
    contain_intrinsic_block_size: None,
    transform: @style.Transform::none(),
    individual_transform: @style.Transform::none(),
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
/// Create a StyleBuilder from an existing Style
fn StyleBuilder::from_style(style : @style.Style) -> StyleBuilder {
  {
    display: style.display,
    position: style.position,
    float: style.float,
    clear: style.clear,
    box_sizing: style.box_sizing,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    scroll_snap_type: style.scroll_snap_type,
    scroll_snap_align_x: style.scroll_snap_align_x,
    scroll_snap_align_y: style.scroll_snap_align_y,
    width: style.width,
    height: style.height,
    min_width: style.min_width,
    min_height: style.min_height,
    max_width: style.max_width,
    max_height: style.max_height,
    margin_top: style.margin.top,
    margin_right: style.margin.right,
    margin_bottom: style.margin.bottom,
    margin_left: style.margin.left,
    margin_trim: style.margin_trim,
    padding_top: style.padding.top,
    padding_right: style.padding.right,
    padding_bottom: style.padding.bottom,
    padding_left: style.padding.left,
    border_top: style.border.top,
    border_right: style.border.right,
    border_bottom: style.border.bottom,
    border_left: style.border.left,
    border_style_top: style.border_style.top,
    border_style_right: style.border_style.right,
    border_style_bottom: style.border_style.bottom,
    border_style_left: style.border_style.left,
    border_color_top: style.border_color.top,
    border_color_right: style.border_color.right,
    border_color_bottom: style.border_color.bottom,
    border_color_left: style.border_color.left,
    flex_direction: style.flex_direction,
    flex_wrap: style.flex_wrap,
    justify_content: style.justify_content,
    align_items: style.align_items,
    align_content: style.align_content,
    justify_content_unsafe: style.justify_content_unsafe,
    align_content_unsafe: style.align_content_unsafe,
    align_self: style.align_self,
    justify_self: style.justify_self,
    justify_items: style.justify_items,
    flex_grow: style.flex_grow,
    flex_shrink: style.flex_shrink,
    flex_basis: style.flex_basis,
    order: style.order,
    row_gap: style.row_gap,
    column_gap: style.column_gap,
    column_gap_is_normal: style.column_gap_is_normal,
    column_count: style.column_count,
    column_width: style.column_width,
    column_fill: style.column_fill,
    aspect_ratio: style.aspect_ratio,
    inset_top: style.inset.top,
    inset_right: style.inset.right,
    inset_bottom: style.inset.bottom,
    inset_left: style.inset.left,
    grid_auto_flow: style.grid_auto_flow,
    grid_template_columns: style.grid_template_columns,
    grid_template_rows: style.grid_template_rows,
    grid_auto_rows: style.grid_auto_rows,
    grid_auto_columns: style.grid_auto_columns,
    grid_template_column_line_names: style.grid_template_column_line_names,
    grid_template_row_line_names: style.grid_template_row_line_names,
    grid_template_columns_kind: style.grid_template_columns_kind,
    grid_template_rows_kind: style.grid_template_rows_kind,
    grid_template_areas: style.grid_template_areas,
    grid_column_start: style.grid_column.start,
    grid_column_end: style.grid_column.end,
    grid_row_start: style.grid_row.start,
    grid_row_end: style.grid_row.end,
    grid_area: style.grid_area,
    font_size: style.font_size,
    font_weight: style.font_weight,
    font_family: style.font_family,
    line_height: style.line_height,
    text_align: style.text_align,
    white_space: style.white_space,
    text_overflow: style.text_overflow,
    writing_mode: style.writing_mode,
    direction: style.direction,
    vertical_align: style.vertical_align,
    clip: style.clip,
    clip_path: style.clip_path,
    visibility: style.visibility,
    pointer_events: style.pointer_events,
    z_index: style.z_index,
    opacity: style.opacity,
    color: style.color,
    background_color: style.background_color,
    background_image: style.background_image,
    box_shadows: style.box_shadows,
    contain: style.contain,
    break_before: style.break_before,
    break_after: style.break_after,
    break_inside: style.break_inside,
    column_span: style.column_span,
    contain_intrinsic_inline_size: style.contain_intrinsic_inline_size,
    contain_intrinsic_block_size: style.contain_intrinsic_block_size,
    transform: style.transform,
    individual_transform: style.individual_transform,
    animation_name: style.animation_name,
    animation_duration: style.animation_duration,
    animation_timing_function: style.animation_timing_function,
    animation_delay: style.animation_delay,
    animation_iteration_count: style.animation_iteration_count,
    animation_direction: style.animation_direction,
    animation_fill_mode: style.animation_fill_mode,
    animation_play_state: style.animation_play_state,
    transition_property: style.transition_property,
    transition_duration: style.transition_duration,
    transition_timing_function: style.transition_timing_function,
    transition_delay: style.transition_delay,
    has_filter: style.has_filter,
    zoom: style.zoom,
    border_spacing: style.border_spacing,
    border_spacing_vertical: style.border_spacing_vertical,
    border_collapse: style.border_collapse,
    table_layout: style.table_layout,
    caption_side: style.caption_side,
    rowspan: style.rowspan,
    colspan: style.colspan,
    border_top_left_radius: style.border_top_left_radius,
    border_top_right_radius: style.border_top_right_radius,
    border_bottom_right_radius: style.border_bottom_right_radius,
    border_bottom_left_radius: style.border_bottom_left_radius,
    text_decoration_underline: style.text_decoration_underline,
    text_decoration_line_through: style.text_decoration_line_through,
    text_decoration_overline: style.text_decoration_overline,
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
  }
}

///|
fn StyleBuilder::build(self : StyleBuilder) -> @style.Style {
  {
    display: self.display,
    position: self.position,
    float: self.float,
    clear: self.clear,
    box_sizing: self.box_sizing,
    overflow_x: self.overflow_x,
    overflow_y: self.overflow_y,
    scroll_snap_type: self.scroll_snap_type,
    scroll_snap_align_x: self.scroll_snap_align_x,
    scroll_snap_align_y: self.scroll_snap_align_y,
    width: self.width,
    height: self.height,
    min_width: self.min_width,
    min_height: self.min_height,
    max_width: self.max_width,
    max_height: self.max_height,
    margin: {
      top: self.margin_top,
      right: self.margin_right,
      bottom: self.margin_bottom,
      left: self.margin_left,
    },
    margin_trim: self.margin_trim,
    padding: {
      top: self.padding_top,
      right: self.padding_right,
      bottom: self.padding_bottom,
      left: self.padding_left,
    },
    border: {
      top: self.border_top,
      right: self.border_right,
      bottom: self.border_bottom,
      left: self.border_left,
    },
    border_style: {
      top: self.border_style_top,
      right: self.border_style_right,
      bottom: self.border_style_bottom,
      left: self.border_style_left,
    },
    border_color: {
      top: self.border_color_top,
      right: self.border_color_right,
      bottom: self.border_color_bottom,
      left: self.border_color_left,
    },
    flex_direction: self.flex_direction,
    flex_wrap: self.flex_wrap,
    justify_content: self.justify_content,
    align_items: self.align_items,
    align_content: self.align_content,
    justify_content_unsafe: self.justify_content_unsafe,
    align_content_unsafe: self.align_content_unsafe,
    align_self: self.align_self,
    flex_grow: self.flex_grow,
    flex_shrink: self.flex_shrink,
    flex_basis: self.flex_basis,
    order: self.order,
    row_gap: self.row_gap,
    column_gap: self.column_gap,
    column_gap_is_normal: self.column_gap_is_normal,
    column_count: self.column_count,
    column_width: self.column_width,
    column_fill: self.column_fill,
    aspect_ratio: self.aspect_ratio,
    inset: {
      top: self.inset_top,
      right: self.inset_right,
      bottom: self.inset_bottom,
      left: self.inset_left,
    },
    grid_template_rows: self.grid_template_rows,
    grid_template_columns: self.grid_template_columns,
    grid_auto_rows: self.grid_auto_rows,
    grid_auto_columns: self.grid_auto_columns,
    grid_auto_flow: self.grid_auto_flow,
    grid_template_column_line_names: self.grid_template_column_line_names,
    grid_template_row_line_names: self.grid_template_row_line_names,
    grid_template_columns_kind: self.grid_template_columns_kind,
    grid_template_rows_kind: self.grid_template_rows_kind,
    grid_template_areas: self.grid_template_areas,
    grid_row: { start: self.grid_row_start, end: self.grid_row_end },
    grid_column: { start: self.grid_column_start, end: self.grid_column_end },
    grid_area: self.grid_area,
    justify_items: self.justify_items,
    justify_self: self.justify_self,
    font_size: self.font_size,
    font_weight: self.font_weight,
    font_family: self.font_family,
    line_height: self.line_height,
    text_align: self.text_align,
    white_space: self.white_space,
    text_overflow: self.text_overflow,
    writing_mode: self.writing_mode,
    direction: self.direction,
    vertical_align: self.vertical_align,
    clip: self.clip,
    clip_path: self.clip_path,
    visibility: self.visibility,
    pointer_events: self.pointer_events,
    z_index: self.z_index,
    opacity: self.opacity,
    color: self.color,
    background_color: self.background_color,
    background_image: self.background_image,
    box_shadows: self.box_shadows,
    contain: self.contain,
    break_before: self.break_before,
    break_after: self.break_after,
    break_inside: self.break_inside,
    column_span: self.column_span,
    contain_intrinsic_inline_size: self.contain_intrinsic_inline_size,
    contain_intrinsic_block_size: self.contain_intrinsic_block_size,
    transform: self.transform,
    individual_transform: self.individual_transform,
    animation_name: self.animation_name,
    animation_duration: self.animation_duration,
    animation_timing_function: self.animation_timing_function,
    animation_delay: self.animation_delay,
    animation_iteration_count: self.animation_iteration_count,
    animation_direction: self.animation_direction,
    animation_fill_mode: self.animation_fill_mode,
    animation_play_state: self.animation_play_state,
    transition_property: self.transition_property,
    transition_duration: self.transition_duration,
    transition_timing_function: self.transition_timing_function,
    transition_delay: self.transition_delay,
    has_filter: self.has_filter,
    zoom: self.zoom,
    border_spacing: self.border_spacing,
    border_spacing_vertical: self.border_spacing_vertical,
    border_collapse: self.border_collapse,
    table_layout: self.table_layout,
    caption_side: self.caption_side,
    rowspan: self.rowspan,
    colspan: self.colspan,
    border_top_left_radius: self.border_top_left_radius,
    border_top_right_radius: self.border_top_right_radius,
    border_bottom_right_radius: self.border_bottom_right_radius,
    border_bottom_left_radius: self.border_bottom_left_radius,
    text_decoration_underline: self.text_decoration_underline,
    text_decoration_line_through: self.text_decoration_line_through,
    text_decoration_overline: self.text_decoration_overline,
    letter_spacing: self.letter_spacing,
    word_spacing: self.word_spacing,
  }
}

///|
/// Resolve a CSS keyword value to actual value
fn resolve_keyword(
  property : String,
  value : @cascade.PropertyValue,
  ctx : ComputeContext,
) -> String {
  match value {
    Value(v) => v
    Inherit =>
      // Get value from parent, or use initial if no parent
      get_inherited_value(property, ctx)
    Initial => initial_value(property)
    Unset =>
      // For inherited properties, acts like inherit
      // For non-inherited properties, acts like initial
      if is_inherited(property) {
        get_inherited_value(property, ctx)
      } else {
        initial_value(property)
      }
    Revert =>
      // This engine has author styles only. With no lower origin available,
      // use the same inherited/initial boundary as `unset`.
      if is_inherited(property) {
        get_inherited_value(property, ctx)
      } else {
        initial_value(property)
      }
    RevertLayer =>
      // Cascade layers are not represented, so fall back to the author-origin
      // boundary documented for `revert` above.
      if is_inherited(property) {
        get_inherited_value(property, ctx)
      } else {
        initial_value(property)
      }
  }
}

///|
/// Get inherited value from parent or initial value
fn get_inherited_value(property : String, ctx : ComputeContext) -> String {
  match ctx.parent_style {
    Some(parent) => get_style_value_as_string(property, parent)
    None => initial_value(property)
  }
}

///|
/// Get a style property value as string representation
fn get_style_value_as_string(property : String, style : @style.Style) -> String {
  match property {
    "display" =>
      match style.display {
        Block => "block"
        Inline => "inline"
        InlineBlock => "inline-block"
        Flex => "flex"
        InlineFlex => "inline-flex"
        Grid => "grid"
        InlineGrid => "inline-grid"
        Table => "table"
        InlineTable => "inline-table"
        TableRow => "table-row"
        TableCell => "table-cell"
        TableCaption => "table-caption"
        TableRowGroup => "table-row-group"
        TableHeaderGroup => "table-header-group"
        TableFooterGroup => "table-footer-group"
        TableColumn => "table-column"
        TableColumnGroup => "table-column-group"
        None => "none"
        Contents => "contents"
        FlowRoot => "flow-root"
      }
    "position" =>
      match style.position {
        Static => "static"
        Relative => "relative"
        Absolute => "absolute"
        Fixed => "fixed"
      }
    "flex-direction" =>
      match style.flex_direction {
        Row => "row"
        RowReverse => "row-reverse"
        Column => "column"
        ColumnReverse => "column-reverse"
      }
    "flex-wrap" =>
      match style.flex_wrap {
        NoWrap => "nowrap"
        Wrap => "wrap"
        WrapReverse => "wrap-reverse"
      }
    "width" => dimension_to_string(style.width)
    "height" => dimension_to_string(style.height)
    "min-width" => dimension_to_string(style.min_width)
    "min-height" => dimension_to_string(style.min_height)
    "max-width" => dimension_to_string(style.max_width)
    "max-height" => dimension_to_string(style.max_height)
    "margin-top" => dimension_to_string(style.margin.top)
    "margin-right" => dimension_to_string(style.margin.right)
    "margin-bottom" => dimension_to_string(style.margin.bottom)
    "margin-left" => dimension_to_string(style.margin.left)
    "margin-trim" =>
      match style.margin_trim {
        None => "none"
        BlockStart => "block-start"
        BlockEnd => "block-end"
        Block => "block"
        InlineStart => "inline-start"
        InlineEnd => "inline-end"
        Inline => "inline"
      }
    "padding-top" => dimension_to_string(style.padding.top)
    "padding-right" => dimension_to_string(style.padding.right)
    "padding-bottom" => dimension_to_string(style.padding.bottom)
    "padding-left" => dimension_to_string(style.padding.left)
    "column-count" =>
      match style.column_count {
        Some(v) => v.to_string()
        None => "auto"
      }
    "column-width" => dimension_to_string(style.column_width)
    "column-fill" =>
      match style.column_fill {
        Balance => "balance"
        Auto => "auto"
      }
    "break-before" =>
      match style.break_before {
        Auto => "auto"
        Column => "column"
        Avoid => "avoid"
      }
    "break-after" =>
      match style.break_after {
        Auto => "auto"
        Column => "column"
        Avoid => "avoid"
      }
    "break-inside" | "page-break-inside" =>
      match style.break_inside {
        Auto => "auto"
        Avoid => "avoid"
      }
    "column-span" =>
      match style.column_span {
        None => "none"
        All => "all"
      }
    "flex-grow" => style.flex_grow.to_string()
    "flex-shrink" => style.flex_shrink.to_string()
    "flex-basis" => dimension_to_string(style.flex_basis)
    "color" => style.color.to_hex()
    "background-color" => style.background_color.to_hex()
    "caption-side" =>
      match style.caption_side {
        Top => "top"
        Bottom => "bottom"
      }
    "border-collapse" =>
      match style.border_collapse {
        Separate => "separate"
        Collapse => "collapse"
      }
    "border-spacing" =>
      if style.border_spacing == style.border_spacing_vertical {
        style.border_spacing.to_string() + "px"
      } else {
        style.border_spacing.to_string() +
        "px " +
        style.border_spacing_vertical.to_string() +
        "px"
      }
    "writing-mode" =>
      match style.writing_mode {
        HorizontalTb => "horizontal-tb"
        VerticalRl => "vertical-rl"
        VerticalLr => "vertical-lr"
      }
    "direction" =>
      match style.direction {
        Ltr => "ltr"
        Rtl => "rtl"
      }
    "font-size" => style.font_size.to_string() + "px"
    "font-weight" => style.font_weight.to_string()
    "line-height" => style.line_height.to_string() + "px"
    "text-decoration" | "text-decoration-line" =>
      text_decoration_to_string(
        style.text_decoration_underline,
        style.text_decoration_line_through,
        style.text_decoration_overline,
      )
    "text-overflow" =>
      match style.text_overflow {
        Clip => "clip"
        Ellipsis => "ellipsis"
      }
    "text-align" =>
      match style.text_align {
        Start => "start"
        End => "end"
        Left => "left"
        Right => "right"
        Center => "center"
        Justify => "justify"
      }
    "white-space" =>
      match style.white_space {
        Normal => "normal"
        Nowrap => "nowrap"
        Pre => "pre"
        PreWrap => "pre-wrap"
        PreLine => "pre-line"
      }
    "pointer-events" =>
      match style.pointer_events {
        Auto => "auto"
        None => "none"
      }
    "opacity" => style.opacity.to_string()
    "contain-intrinsic-inline-size" =>
      match style.contain_intrinsic_inline_size {
        Some(v) => v.to_string() + "px"
        None => "none"
      }
    "contain-intrinsic-block-size" =>
      match style.contain_intrinsic_block_size {
        Some(v) => v.to_string() + "px"
        None => "none"
      }
    _ => initial_value(property)
  }
}

///|
/// Convert dimension to string
fn dimension_to_string(dim : @types.Dimension) -> String {
  match dim {
    Auto => "auto"
    Length(n) => if n == 0.0 { "0" } else { n.to_string() + "px" }
    Percent(n) => (n * 100.0).to_string() + "%"
    MinContent => "min-content"
    MaxContent => "max-content"
    FitContent(n) => "fit-content(" + n.to_string() + "px)"
    Calc(px, pct) => {
      let pct_part = (pct * 100.0).to_string() + "%"
      if px < 0.0 {
        "calc(" + pct_part + " - " + (-px).to_string() + "px)"
      } else {
        "calc(" + pct_part + " + " + px.to_string() + "px)"
      }
    }
    MathFn(op, args) => {
      let name = match op {
        Min => "min("
        Max => "max("
        Clamp => "clamp("
      }
      let parts = args.map(fn(a) { math_arg_to_string(a.0, a.1) })
      name + parts.join(", ") + ")"
    }
  }
}

///|
/// Serialize a single min()/max()/clamp() argument from its linear (px, pct)
/// form back to CSS, mirroring dimension_to_string's length/percent/calc tiers.
fn math_arg_to_string(px : Double, pct : Double) -> String {
  if pct.abs() < 0.0001 {
    if px == 0.0 {
      "0"
    } else {
      px.to_string() + "px"
    }
  } else if px.abs() < 0.0001 {
    (pct * 100.0).to_string() + "%"
  } else {
    let pct_part = (pct * 100.0).to_string() + "%"
    if px < 0.0 {
      "calc(" + pct_part + " - " + (-px).to_string() + "px)"
    } else {
      "calc(" + pct_part + " + " + px.to_string() + "px)"
    }
  }
}

///|
fn text_decoration_to_string(
  underline : Bool,
  line_through : Bool,
  overline : Bool,
) -> String {
  let values : Array[String] = []
  if underline {
    values.push("underline")
  }
  if line_through {
    values.push("line-through")
  }
  if overline {
    values.push("overline")
  }
  if values.is_empty() {
    "none"
  } else {
    let buf = StringBuilder::new()
    for i, value in values {
      if i > 0 {
        buf.write_string(" ")
      }
      buf.write_string(value)
    }
    buf.to_string()
  }
}

///|
/// Compute a Style from cascaded values
pub fn compute(
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> @style.Style {
  let builder = StyleBuilder::new()

  // First pass: collect custom properties (--*)
  // Custom properties are stored in the context for var() resolution
  cascaded.each(fn(prop, decl) {
    if starts_with(prop, "--") {
      let value = resolve_keyword(prop, decl.value, ctx)
      // Store custom property in context
      ctx.custom_properties[prop] = value
    }
  })
  seed_effective_color_scheme(cascaded, ctx)

  seed_direction(builder, cascaded, ctx)
  // Seed writing-mode before applying logical properties.
  // Logical sizing must follow the element's effective writing mode.
  seed_writing_mode(builder, cascaded, ctx)
  // Seed font metrics before resolving em/ch/ex units in other properties.
  let font_ctx = seed_font_metrics(builder, cascaded, ctx)

  // Second pass: apply regular properties with var() resolution
  for item in regular_declarations_in_source_order(cascaded) {
    let (prop, decl) = item
    let value = resolve_keyword(prop, decl.value, font_ctx)
    apply_property(builder, prop, value, font_ctx)
  }

  // Handle inheritance for inherited properties
  apply_inheritance(builder, cascaded, ctx)
  builder.build()
}

///|
/// Compute a Style and return updated custom properties
/// Used when building a style tree to pass custom properties to children
pub fn compute_with_vars(
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> (@style.Style, Map[String, String]) {
  let builder = StyleBuilder::new()

  // First pass: collect custom properties (--*)
  cascaded.each(fn(prop, decl) {
    if starts_with(prop, "--") {
      let value = resolve_keyword(prop, decl.value, ctx)
      ctx.custom_properties[prop] = value
    }
  })
  seed_effective_color_scheme(cascaded, ctx)

  // Seed writing-mode before applying logical properties.
  seed_direction(builder, cascaded, ctx)
  seed_writing_mode(builder, cascaded, ctx)
  let font_ctx = seed_font_metrics(builder, cascaded, ctx)

  // Second pass: apply regular properties
  for item in regular_declarations_in_source_order(cascaded) {
    let (prop, decl) = item
    let value = resolve_keyword(prop, decl.value, font_ctx)
    apply_property(builder, prop, value, font_ctx)
  }

  // Handle inheritance
  apply_inheritance(builder, cascaded, ctx)

  // Return both the style and the custom properties for children
  (builder.build(), ctx.custom_properties)
}

///|
fn seed_effective_color_scheme(
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  let inherited = match
    ctx.custom_properties.get(internal_effective_color_scheme_key) {
    Some(value) => value
    None => "light"
  }
  let mut scheme = inherited
  match cascaded.get_value("color-scheme") {
    Some(raw_value) => {
      let resolved = if raw_value.contains("var(") {
        resolve_all_vars(raw_value, ctx)
      } else {
        raw_value
      }
      match first_color_scheme_keyword(resolved) {
        Some(value) => scheme = value
        None => ()
      }
    }
    None => ()
  }
  ctx.custom_properties[internal_effective_color_scheme_key] = scheme
}

///|
fn first_color_scheme_keyword(value : String) -> String? {
  let normalized = value.to_lower()
  let tokens = normalized.split(" ")
  for token in tokens {
    let t = token.to_owned().trim()
    if t == "light" || t == "dark" {
      return Some(t.to_owned())
    }
  }
  None
}

///|
fn seed_direction(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  match ctx.parent_style {
    Some(parent_style) => builder.direction = parent_style.direction
    None => ()
  }
  match cascaded.get("direction") {
    Some(decl) => {
      let value = resolve_keyword("direction", decl.value, ctx)
      builder.direction = parse_direction(value)
    }
    None => ()
  }
}

///|
/// Seed writing-mode on the builder before logical properties are applied.
/// Uses inherited writing-mode as default, then overrides with explicit declaration.
fn seed_writing_mode(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  match ctx.parent_style {
    Some(parent_style) => builder.writing_mode = parent_style.writing_mode
    None => ()
  }
  match cascaded.get("writing-mode") {
    Some(decl) => {
      let value = resolve_keyword("writing-mode", decl.value, ctx)
      builder.writing_mode = parse_writing_mode(value)
    }
    None => ()
  }
}

///|
fn is_preseeded_font_property(property : String) -> Bool {
  property == "font" ||
  property == "font-size" ||
  property == "line-height" ||
  property == "font-weight" ||
  property == "font-family"
}

///|
/// Return regular declarations in CSS source order. CascadedValues is a map,
/// so applying it directly loses relative shorthand/longhand order.
fn regular_declarations_in_source_order(
  cascaded : @cascade.CascadedValues,
) -> Array[(String, @cascade.Declaration)] {
  let declarations : Array[(String, @cascade.Declaration)] = []
  cascaded.each(fn(prop, decl) {
    if !starts_with(prop, "--") && !is_preseeded_font_property(prop) {
      declarations.push((prop, decl))
    }
  })
  declarations.sort_by(fn(a, b) { a.1.source_order - b.1.source_order })
  declarations
}

///|
/// Seed font-size/line-height ahead of general property application so
/// em/ch/ex units in width/height and gaps resolve against the element's font.
fn seed_font_metrics(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> ComputeContext {
  let mut seeded_font_size = ctx.font_size
  let mut seeded_line_height = ctx.font_size * 1.2 // CSS initial: normal ≈ 1.2
  let mut seeded_font_weight = match ctx.parent_style {
    Some(parent_style) => parent_style.font_weight
    None => 400.0
  }
  let mut seeded_font_family = match ctx.parent_style {
    Some(parent_style) => parent_style.font_family
    None => ""
  }
  let mut font_decl : @cascade.Declaration? = None
  let mut font_size_decl : @cascade.Declaration? = None
  let mut line_height_decl : @cascade.Declaration? = None
  let mut font_weight_decl : @cascade.Declaration? = None
  let mut font_family_decl : @cascade.Declaration? = None
  match cascaded.get("font") {
    Some(decl) => font_decl = Some(decl)
    None => ()
  }
  match cascaded.get("font-size") {
    Some(decl) => font_size_decl = Some(decl)
    None => ()
  }
  match cascaded.get("line-height") {
    Some(decl) => line_height_decl = Some(decl)
    None => ()
  }
  match cascaded.get("font-weight") {
    Some(decl) => font_weight_decl = Some(decl)
    None => ()
  }
  match cascaded.get("font-family") {
    Some(decl) => font_family_decl = Some(decl)
    None => ()
  }
  for idx = 0; idx < 5; idx = idx + 1 {
    let mut next_prop = ""
    let mut next_decl : @cascade.Declaration? = None
    let mut next_order = 2147483647
    match font_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "font"
          next_decl = Some(decl)
          next_order = decl.source_order
        }
      None => ()
    }
    match font_size_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "font-size"
          next_decl = Some(decl)
          next_order = decl.source_order
        }
      None => ()
    }
    match line_height_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "line-height"
          next_decl = Some(decl)
          next_order = decl.source_order
        }
      None => ()
    }
    match font_weight_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "font-weight"
          next_decl = Some(decl)
          next_order = decl.source_order
        }
      None => ()
    }
    match font_family_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "font-family"
          next_decl = Some(decl)
        }
      None => ()
    }
    if next_prop == "" {
      break
    }
    let decl = match next_decl {
      Some(decl) => decl
      None => break
    }
    let unresolved = resolve_keyword(next_prop, decl.value, ctx)
    match resolve_custom_property_value(unresolved, ctx.custom_properties) {
      Some(value) =>
        match next_prop {
          "font" => {
            let parsed = parse_font_shorthand(value, ctx)
            seeded_font_size = parsed.font_size
            seeded_line_height = parsed.line_height
            seeded_font_weight = parsed.font_weight
            seeded_font_family = parsed.font_family
            font_decl = None
          }
          "font-size" => {
            seeded_font_size = parse_font_size(value, ctx)
            font_size_decl = None
          }
          "line-height" => {
            seeded_line_height = parse_line_height(
              value,
              seeded_font_size,
              root_font_size=ctx.root_font_size,
            )
            line_height_decl = None
          }
          "font-weight" => {
            seeded_font_weight = parse_font_weight(value)
            font_weight_decl = None
          }
          "font-family" => {
            seeded_font_family = parse_font_family(value)
            font_family_decl = None
          }
          _ => ()
        }
      None => ()
    }
  }

  builder.font_size = seeded_font_size
  builder.line_height = seeded_line_height
  builder.font_weight = seeded_font_weight
  builder.font_family = seeded_font_family
  { ..ctx, font_size: seeded_font_size }
}

///|
/// Resolve a 1-or-2 value logical shorthand (margin-inline, padding-block, …)
/// into a (start, end) dimension pair. A single value applies to both ends.
fn resolve_logical_pair(
  value : String,
  ctx : ComputeContext,
) -> (@types.Dimension, @types.Dimension) {
  let dims : Array[@types.Dimension] = []
  for part in value.trim().to_owned().split(" ") {
    let p = part.to_owned().trim().to_owned()
    if !p.is_empty() {
      dims.push(resolve_dimension(p, ctx))
    }
  }
  match dims.length() {
    0 => {
      let d = resolve_dimension(value, ctx)
      (d, d)
    }
    1 => (dims[0], dims[0])
    _ => (dims[0], dims[1])
  }
}
