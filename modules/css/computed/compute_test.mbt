///|
/// Tests for CSS computed values

///|
test "compute_inline background-color hex" {
  let css = "background-color: #ff0000"
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(css, ctx)
  // Should be red
  inspect(style.background_color.r, content="255")
  inspect(style.background_color.g, content="0")
  inspect(style.background_color.b, content="0")
}

///|
test "compute_inline background-color named" {
  let css = "background-color: red"
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(css, ctx)
  // Should be red
  inspect(style.background_color.r, content="255")
  inspect(style.background_color.g, content="0")
  inspect(style.background_color.b, content="0")
}

///|
test "parse_dimension basic" {
  let auto = @computed.parse_dimension("auto")
  inspect(auto, content="Auto")
  let px = @computed.parse_dimension("100px")
  inspect(px, content="Length(100)")
  let percent = @computed.parse_dimension("50%")
  inspect(percent, content="Percent(0.5)")
  let plain = @computed.parse_dimension("200")
  inspect(plain, content="Length(200)")
}

///|
test "parse_display" {
  inspect(@computed.parse_display("block"), content="Block")
  inspect(@computed.parse_display("flex"), content="Flex")
  inspect(@computed.parse_display("grid"), content="Grid")
  inspect(@computed.parse_display("none"), content="None")
  inspect(@computed.parse_display("math"), content="Inline")
  inspect(@computed.parse_display("block math"), content="Block")
  inspect(@computed.parse_display("flow-root list-item"), content="FlowRoot")
  inspect(@computed.parse_display("FLEX"), content="Flex") // case insensitive
}

///|
test "parse_position" {
  inspect(@computed.parse_position("relative"), content="Relative")
  inspect(@computed.parse_position("absolute"), content="Absolute")
  inspect(@computed.parse_position("static"), content="Static") // treated as relative
}

///|
test "parse_flex_direction" {
  inspect(@computed.parse_flex_direction("row"), content="Row")
  inspect(@computed.parse_flex_direction("row-reverse"), content="RowReverse")
  inspect(@computed.parse_flex_direction("column"), content="Column")
  inspect(
    @computed.parse_flex_direction("column-reverse"),
    content="ColumnReverse",
  )
}

///|
test "parse_alignment" {
  inspect(@computed.parse_alignment("flex-start"), content="FlexStart")
  inspect(@computed.parse_alignment("start"), content="Start")
  inspect(@computed.parse_alignment("flex-end"), content="FlexEnd")
  inspect(@computed.parse_alignment("end"), content="End")
  inspect(@computed.parse_alignment("left"), content="Left")
  inspect(@computed.parse_alignment("right"), content="Right")
  inspect(@computed.parse_alignment("center"), content="Center")
  inspect(@computed.parse_alignment("space-between"), content="SpaceBetween")
  inspect(@computed.parse_alignment("stretch"), content="Stretch")
  inspect(@computed.parse_alignment("safe center"), content="Start")
  inspect(@computed.parse_alignment("safe end"), content="Start")
  inspect(@computed.parse_alignment("unsafe center"), content="Center")
  inspect(@computed.parse_alignment("unsafe end"), content="End")
}

///|
test "compute_inline place-content shorthand" {
  let ctx = @computed.ComputeContext::new()

  let safe_center = @computed.compute_inline("place-content: safe center", ctx)
  inspect(safe_center.align_content, content="Start")
  inspect(safe_center.justify_content, content="Start")
  inspect(safe_center.align_content_unsafe, content="false")
  inspect(safe_center.justify_content_unsafe, content="false")

  let unsafe_end = @computed.compute_inline("place-content: unsafe end", ctx)
  inspect(unsafe_end.align_content, content="End")
  inspect(unsafe_end.justify_content, content="End")
  inspect(unsafe_end.align_content_unsafe, content="true")
  inspect(unsafe_end.justify_content_unsafe, content="true")

  let mixed = @computed.compute_inline("place-content: end center", ctx)
  inspect(mixed.align_content, content="End")
  inspect(mixed.justify_content, content="Center")
  inspect(mixed.align_content_unsafe, content="false")
  inspect(mixed.justify_content_unsafe, content="false")

  let left_right = @computed.compute_inline("place-content: start left", ctx)
  inspect(left_right.align_content, content="Start")
  inspect(left_right.justify_content, content="Left")
  inspect(left_right.align_content_unsafe, content="false")
  inspect(left_right.justify_content_unsafe, content="false")
}

///|
test "compute_inline align-content normal maps to stretch" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("align-content: normal", ctx)
  inspect(style.align_content, content="Stretch")
  inspect(style.align_content_unsafe, content="false")
}

///|
test "compute_inline align-content last baseline falls back to baseline packing" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("align-content: last baseline", ctx)
  inspect(style.align_content, content="Baseline")
  inspect(style.align_content_unsafe, content="false")
}

///|
test "parse_align_self baseline variants" {
  inspect(@computed.parse_align_self("baseline"), content="Baseline")
  inspect(@computed.parse_align_self("first baseline"), content="Baseline")
  inspect(@computed.parse_align_self("last baseline"), content="End")
}

///|
test "parse_scroll_snap_type_and_align" {
  let snap_type = @computed.parse_scroll_snap_type("x mandatory")
  inspect(snap_type.axis, content="X")
  inspect(snap_type.strictness, content="Mandatory")
  let (inline_align, block_align) = @computed.parse_scroll_snap_align("center")
  inspect(inline_align, content="Center")
  inspect(block_align, content="Center")
}

///|
test "compute_inline scroll_snap properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "scroll-snap-type: y mandatory; scroll-snap-align: center", ctx,
  )
  inspect(style.scroll_snap_type.axis, content="Y")
  inspect(style.scroll_snap_type.strictness, content="Mandatory")
  inspect(style.scroll_snap_align_x, content="Center")
  inspect(style.scroll_snap_align_y, content="Center")
}

///|
test "compute_inline container-type size implies contain size and style" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("container-type: size", ctx)
  inspect(style.contain.size, content="true")
  inspect(style.contain.inline_size, content="false")
  inspect(style.contain.style, content="true")
}

///|
test "compute_inline container-type merges with contain" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "contain: paint; container-type: inline-size", ctx,
  )
  inspect(style.contain.paint, content="true")
  inspect(style.contain.inline_size, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "compute_inline contain-intrinsic-inline-size parses length" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "contain-intrinsic-inline-size: 120px", ctx,
  )
  debug_inspect(style.contain_intrinsic_inline_size, content="Some(120)")
}

///|
test "compute_inline contain-intrinsic-size shorthand sets both axes" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("contain-intrinsic-size: 90px 45px", ctx)
  debug_inspect(style.contain_intrinsic_inline_size, content="Some(90)")
  debug_inspect(style.contain_intrinsic_block_size, content="Some(45)")
}

///|
test "compute_inline columns shorthand parses count and width" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("columns: 2 40px; column-gap: 20px", ctx)
  debug_inspect(style.column_count, content="Some(2)")
  inspect(style.column_width, content="Length(40)")
  inspect(style.column_gap, content="Length(20)")
}

///|
test "compute_inline column-width preserves mixed calc" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("column-width: calc(50% - 10px)", ctx)
  inspect(style.column_width, content="Calc(-10, 0.5)")
}

///|
test "compute_inline break-before and column-span parse values" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "break-before: column; column-span: all", ctx,
  )
  inspect(style.break_before, content="Column")
  inspect(style.column_span, content="All")
}

///|
test "compute_inline break-after parses column value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("break-after: column", ctx)
  inspect(style.break_after, content="Column")
}

///|
test "compute_inline break-before and break-after parse avoid value" {
  let ctx = @computed.ComputeContext::new()
  let before = @computed.compute_inline("break-before: avoid", ctx)
  inspect(before.break_before, content="Avoid")
  let after = @computed.compute_inline("break-after: avoid", ctx)
  inspect(after.break_after, content="Avoid")
}

///|
test "compute_inline break-inside parses avoid value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("break-inside: avoid", ctx)
  inspect(style.break_inside, content="Avoid")
}

///|
test "compute_inline page-break-inside aliases break-inside" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("page-break-inside: avoid", ctx)
  inspect(style.break_inside, content="Avoid")
}

///|
test "compute_inline font-size rem resolves against root font size" {
  let ctx = {
    ..@computed.ComputeContext::new(),
    root_font_size: 16.0,
    font_size: 8.0,
  }
  let style = @computed.compute_inline("font-size: 1rem", ctx)
  inspect(style.font_size, content="16")
}

///|
test "parse_grid_placement custom ident is preserved as a named line" {
  inspect(@computed.parse_grid_placement("foo"), content="Named(foo)")
  inspect(@computed.parse_grid_placement("bar-baz"), content="Named(bar-baz)")
}

///|
test "compute_inline grid-area shorthand sets row and column lines" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: 1 / 2 / 3 / 4", ctx)
  inspect(style.grid_row.start, content="Line(1)")
  inspect(style.grid_column.start, content="Line(2)")
  inspect(style.grid_row.end, content="Line(3)")
  inspect(style.grid_column.end, content="Line(4)")
}

///|
test "compute_inline grid-area custom idents are preserved as named lines" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: a / a / b / b", ctx)
  inspect(style.grid_row.start, content="Named(a)")
  inspect(style.grid_column.start, content="Named(a)")
  inspect(style.grid_row.end, content="Named(b)")
  inspect(style.grid_column.end, content="Named(b)")
}

///|
test "compute_inline grid-area named area sets grid_area field" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: header", ctx)
  debug_inspect(style.grid_area, content="Some(\"header\")")
  // Named area should not set grid line placements
  inspect(style.grid_row.start, content="Auto")
  inspect(style.grid_column.start, content="Auto")
}

///|
test "compute_inline MDN page shell: named lines resolve grid-column" {
  let ctx = @computed.ComputeContext::new()
  // Container: .layout__2-sidebars-inline style page shell.
  let container = @computed.compute_inline(
    "display: grid; grid-template-columns: [left-sidebar-start] 240px [left-sidebar-end content-start] 689px [content-end]",
    ctx,
  )
  let col_names = container.grid_template_column_line_names
  inspect(col_names.length(), content="3")
  // Item placed with `grid-column: left-sidebar` (named line / implicit area).
  let sidebar = @computed.compute_inline("grid-column: left-sidebar", ctx)
  inspect(sidebar.grid_column.start, content="Named(left-sidebar)")
  inspect(sidebar.grid_column.end, content="Named(left-sidebar)")
  let (s, e) = @computed.resolve_grid_line_placement(
    sidebar.grid_column.start,
    sidebar.grid_column.end,
    col_names,
  )
  debug_inspect(s, content="Some(1)")
  debug_inspect(e, content="Some(2)")
  // Another item placed in the content column.
  let content = @computed.compute_inline("grid-column: content", ctx)
  let (cs, ce) = @computed.resolve_grid_line_placement(
    content.grid_column.start,
    content.grid_column.end,
    col_names,
  )
  debug_inspect(cs, content="Some(2)")
  debug_inspect(ce, content="Some(3)")
}

///|
test "compute_inline animation and transition shorthands" {
  let ctx = @computed.ComputeContext::new()
  let s = @computed.compute_inline(
    "animation: fade 1s ease-in 0.2s 3 reverse; transition: width 0.5s linear", ctx,
  )
  debug_inspect(s.animation_name, content="[\"fade\"]")
  debug_inspect(s.animation_duration, content="[1]")
  inspect(s.animation_timing_function[0], content="EaseIn")
  debug_inspect(s.animation_delay, content="[0.2]")
  inspect(s.animation_iteration_count[0], content="Count(3)")
  inspect(s.animation_direction[0], content="Reverse")
  debug_inspect(s.transition_property, content="[\"width\"]")
  debug_inspect(s.transition_duration, content="[0.5]")
  inspect(s.transition_timing_function[0], content="Linear")
}

///|
test "compute_inline grid-template-areas parsed correctly" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: grid; grid-template-areas: \"header header\" \"sidebar main\" \"footer footer\"",
    ctx,
  )
  inspect(style.grid_template_areas.length(), content="3")
  inspect(style.grid_template_areas[0], content="header header")
  inspect(style.grid_template_areas[1], content="sidebar main")
  inspect(style.grid_template_areas[2], content="footer footer")
}

///|
test "compute_inline grid-area with slashes still parses as line numbers" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: 2 / 1 / 3 / 4", ctx)
  debug_inspect(style.grid_area, content="None")
  inspect(style.grid_row.start, content="Line(2)")
  inspect(style.grid_column.start, content="Line(1)")
}

///|
test "parse_aspect_ratio" {
  debug_inspect(@computed.parse_aspect_ratio("auto"), content="None")
  debug_inspect(
    @computed.parse_aspect_ratio("16 / 9"),
    content="Some(1.7777777777777777)",
  )
  debug_inspect(
    @computed.parse_aspect_ratio("16/9"),
    content="Some(1.7777777777777777)",
  )
  debug_inspect(@computed.parse_aspect_ratio("1.5"), content="Some(1.5)")
}

///|
test "extract_border_width" {
  inspect(@computed.extract_border_width("3px"), content="Length(3)")
  inspect(@computed.extract_border_width("solid 3px"), content="Length(3)")
  inspect(@computed.extract_border_width("1px solid red"), content="Length(1)")
  inspect(@computed.extract_border_width("none"), content="Length(0)")
  inspect(@computed.extract_border_width("solid"), content="Length(1.5)")
  inspect(@computed.extract_border_width("medium"), content="Length(3)")
}

///|
test "compute_inline border shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border: 3px solid red", ctx)
  inspect(style.border.top, content="Length(3)")
  inspect(style.border.right, content="Length(3)")
  inspect(style.border.bottom, content="Length(3)")
  inspect(style.border.left, content="Length(3)")
}

///|
test "compute_inline border shorthand em uses context font-size" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("border: 1em solid red", ctx)
  inspect(style.border.top, content="Length(20)")
  inspect(style.border.right, content="Length(20)")
  inspect(style.border.bottom, content="Length(20)")
  inspect(style.border.left, content="Length(20)")
}

///|
test "compute_inline basic" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("width: 100px; height: 200px", ctx)
  inspect(style.width, content="Length(100)")
  inspect(style.height, content="Length(200)")
}

///|
test "compute_inline strips important from inline declaration values" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "width: 100px ! important; width: 200px; height: 48.5px!important; display: inline-block !important; visibility: hidden!important",
    ctx,
  )
  inspect(style.width, content="Length(100)")
  inspect(style.height, content="Length(48.5)")
  inspect(style.display, content="InlineBlock")
  inspect(style.visibility, content="Hidden")
}

///|
test "compute_inline flex properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: flex; flex-direction: column; justify-content: center", ctx,
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Column")
  inspect(style.justify_content, content="Center")
}

///|
test "compute_inline resolves logical float and clear with final direction" {
  let ctx = @computed.ComputeContext::new()
  let rtl_first = @computed.compute_inline(
    "direction: rtl; float: inline-start; clear: inline-end", ctx,
  )
  inspect(rtl_first.float, content="Right")
  inspect(rtl_first.clear, content="Left")

  let rtl_last = @computed.compute_inline(
    "float: inline-start; clear: inline-end; direction: rtl", ctx,
  )
  inspect(rtl_last.float, content="Right")
  inspect(rtl_last.clear, content="Left")
}

///|
test "compute_inline relative units em" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0, // 20px font
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("width: 2em", ctx)
  // 2em * 20px = 40px
  inspect(style.width, content="Length(40)")
}

///|
test "compute_inline relative units rem" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("width: 2rem", ctx)
  // 2rem * 16px = 32px
  inspect(style.width, content="Length(32)")
}

///|
test "compute_inline viewport units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1000.0,
    viewport_height: 800.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("width: 50vw; height: 25vh", ctx)
  // 50vw = 50% of 1000px = 500px
  inspect(style.width, content="Length(500)")
  // 25vh = 25% of 800px = 200px
  inspect(style.height, content="Length(200)")
}

///|
test "compute_inline dynamic viewport units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1000.0,
    viewport_height: 800.0,
    custom_properties: Map([]),
  }
  let height_style = @computed.compute_inline(
    "height: 100dvh; min-height: 50svh; max-height: 25lvh", ctx,
  )
  inspect(height_style.height, content="Length(800)")
  inspect(height_style.min_height, content="Length(400)")
  inspect(height_style.max_height, content="Length(200)")

  let width_style = @computed.compute_inline(
    "width: 100dvw; min-width: 50svw; max-width: 25lvw", ctx,
  )
  inspect(width_style.width, content="Length(1000)")
  inspect(width_style.min_width, content="Length(500)")
  inspect(width_style.max_width, content="Length(250)")
}

///|
test "compute_inline calc viewport units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("width: calc(100vw + 100px)", ctx)
  inspect(style.width, content="Length(900)")
}

///|
test "compute_inline calc dynamic viewport units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline(
    "width: calc(100dvw + 100px); height: calc(100dvh - 50px)", ctx,
  )
  inspect(style.width, content="Length(900)")
  inspect(style.height, content="Length(550)")
}

///|
test "compute_inline calc mixed width preserves layout-time basis" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("width: calc(50% - 10px)", ctx)
  inspect(style.width, content="Calc(-10, 0.5)")
}

///|
test "compute_inline calc multiplication with signed unitless operand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "--offset: 20em; position: absolute; top: calc(var(--offset)*-1)", ctx,
  )
  inspect(style.inset.top, content="Length(-320)")
}

///|
test "compute_inline gap shorthand two values" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("gap: 40px 20px", ctx)
  inspect(style.row_gap, content="Length(40)")
  inspect(style.column_gap, content="Length(20)")
}

///|
test "compute_inline mixed calc gap preserves layout-time basis" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: Map([]),
  }
  // 10% - 1rem/2 = 10% - 8px. The `/2` binds only to `1rem` (precedence), so
  // the percentage stays 10% (0.1). The previous 0.05 was a precedence bug that
  // divided the accumulated percentage too.
  let style = @computed.compute_inline("gap: calc(10% - 1rem / 2)", ctx)
  inspect(style.row_gap, content="Calc(-8, 0.1)")
  inspect(style.column_gap, content="Calc(-8, 0.1)")
}

///|
test "compute_inline box model" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "margin-top: 10px; margin-bottom: 20px; padding-left: 5px", ctx,
  )
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.bottom, content="Length(20)")
  inspect(style.padding.left, content="Length(5)")
}

///|
test "compute_inline margin auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin: auto", ctx)
  inspect(style.margin.top, content="Auto")
  inspect(style.margin.right, content="Auto")
  inspect(style.margin.bottom, content="Auto")
  inspect(style.margin.left, content="Auto")
}

///|
test "compute_inline inset shorthand with 4 values including auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("inset: 50px auto 50px 50px", ctx)
  inspect(style.inset.top, content="Length(50)")
  inspect(style.inset.right, content="Auto")
  inspect(style.inset.bottom, content="Length(50)")
  inspect(style.inset.left, content="Length(50)")
}

///|
test "is_inherited" {
  // Inherited properties
  inspect(@computed.is_inherited("color"), content="true")
  inspect(@computed.is_inherited("font-size"), content="true")
  inspect(@computed.is_inherited("line-height"), content="true")
  inspect(@computed.is_inherited("white-space"), content="true")
  inspect(@computed.is_inherited("pointer-events"), content="true")
  // Non-inherited properties
  inspect(@computed.is_inherited("width"), content="false")
  inspect(@computed.is_inherited("display"), content="false")
  inspect(@computed.is_inherited("margin"), content="false")
}

///|
test "initial_value" {
  inspect(@computed.initial_value("display"), content="block")
  inspect(@computed.initial_value("position"), content="relative")
  inspect(@computed.initial_value("flex-direction"), content="row")
  inspect(@computed.initial_value("flex-grow"), content="0")
  inspect(@computed.initial_value("flex-shrink"), content="1")
  inspect(@computed.initial_value("width"), content="auto")
}

///|
test "parse_grid_template_tracks" {
  let tracks = @computed.parse_grid_template_tracks("100px 200px 1fr")
  inspect(tracks.length(), content="3")
  inspect(tracks[0], content="Length(100)")
  inspect(tracks[1], content="Length(200)")
  inspect(tracks[2], content="Fr(1)")
}

///|
test "parse_grid_template_tracks with auto" {
  let tracks = @computed.parse_grid_template_tracks("auto 50px 2fr")
  inspect(tracks.length(), content="3")
  inspect(tracks[0], content="Auto")
  inspect(tracks[1], content="Length(50)")
  inspect(tracks[2], content="Fr(2)")
}

///|
test "parse_grid_template_tracks none" {
  let tracks = @computed.parse_grid_template_tracks("none")
  inspect(tracks.length(), content="0")
}

///|
test "parse_grid_template_tracks named lines with rem max" {
  let tracks = @computed.parse_grid_template_tracks(
    "[extended-full-start] 16px [full-start] 1fr [content-start] minmax(0, 48rem) [content-end] 1fr [full-end] 16px [extended-full-end]",
  )
  inspect(tracks.length(), content="5")
}

///|
test "compute_inline grid-template" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: grid; grid-template-columns: 100px 1fr 100px", ctx,
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[1], content="Fr(1)")
  inspect(style.grid_template_columns[2], content="Length(100)")
}

///|
test "compute_inline grid-template resolves custom property css math tracks" {
  let ctx = @computed.ComputeContext::with_viewport(800.0, 600.0)
  let style = @computed.compute_inline(
    "--pad: max(1rem, calc(50vw - 720px + 1rem)); --content: 48rem; display: grid; grid-template-columns: [extended-full-start] var(--pad) [full-start] 1fr [content-start] minmax(0, var(--content)) [content-end] 1fr [full-end] var(--pad) [extended-full-end]",
    ctx,
  )
  inspect(style.grid_template_columns.length(), content="5")
  inspect(style.grid_template_columns[0], content="Length(16)")
  inspect(
    style.grid_template_columns[2],
    content="MinMax(Length(0), Length(768))",
  )
}

///|
test "compute_inline grid-template resolves custom property inside minmax" {
  let ctx = @computed.ComputeContext::with_viewport(800.0, 600.0)
  let style = @computed.compute_inline(
    "--content: 48rem; display: grid; grid-template-columns: 16px 1fr minmax(0, var(--content)) 1fr 16px",
    ctx,
  )
  inspect(style.grid_template_columns.length(), content="5")
  inspect(
    style.grid_template_columns[2],
    content="MinMax(Length(0), Length(768))",
  )
}

///|
test "compute_inline grid-template resolves inherited custom property inside minmax" {
  let ctx : @computed.ComputeContext = {
    ..@computed.ComputeContext::with_viewport(800.0, 600.0),
    custom_properties: { "--content": "48rem" },
  }
  let style = @computed.compute_inline(
    "display: grid; grid-template-columns: 16px 1fr minmax(0, var(--content)) 1fr 16px",
    ctx,
  )
  inspect(style.grid_template_columns.length(), content="5")
  inspect(
    style.grid_template_columns[2],
    content="MinMax(Length(0), Length(768))",
  )
}

///|
test "compute_inline grid named placement is preserved as named lines" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "grid-column: content; grid-column-end: extended-full-end", ctx,
  )
  inspect(style.grid_column.start, content="Named(content)")
  inspect(style.grid_column.end, content="Named(extended-full-end)")
}

///|
test "compute_inline grid-template shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: grid; grid-template: 100px / 200px", ctx,
  )
  inspect(style.grid_template_rows.length(), content="1")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Length(200)")
}
