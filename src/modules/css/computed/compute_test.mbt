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
test "build_keyframe_track resolves @keyframes into a typed track" {
  let ctx = @computed.ComputeContext::new()
  let css =
    #|@keyframes slide { from { left: 0; } to { left: 100px; } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("slide").unwrap()
  // Unitless `0` is reconciled to Length(0) so it interpolates with `100px`.
  let track = @computed.build_keyframe_track(rule, "left", "0px", ctx)
  inspect(track.length(), content="2")
  let effect = @animation.AnimatableKeyframeEffect::new(track, {
    ..@animation.EffectTiming::new(1000.0),
    fill: @animation.FillMode::Both,
  }).unwrap()
  inspect(effect.sample(500.0).unwrap(), content="Length(50)")
  inspect(effect.sample(0.0).unwrap(), content="Length(0)")
  inspect(effect.sample(1000.0).unwrap(), content="Length(100)")
}

///|
test "build_keyframe_track fills implicit endpoint from base and interpolates color" {
  let ctx = @computed.ComputeContext::new()
  // Only a `to` keyframe; the 0% endpoint is filled from the base value.
  let css =
    #|@keyframes redden { to { color: rgb(255, 0, 0); } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("redden").unwrap()
  let track = @computed.build_keyframe_track(rule, "color", "rgb(0, 0, 0)", ctx)
  inspect(track.length(), content="2")
  let effect = @animation.AnimatableKeyframeEffect::new(
    track,
    @animation.EffectTiming::new(1000.0),
  ).unwrap()
  // Midpoint interpolates black -> red in sRGB.
  inspect(effect.sample(500.0).unwrap(), content="Color(rgb(128, 0, 0))")
  // No fill -> before phase (t < 0) yields no value.
  assert_true(effect.sample(-10.0) is None)
}

///|
test "transform keyframe track interpolates component-wise" {
  let ctx = @computed.ComputeContext::new()
  let css =
    #|@keyframes move { from { transform: translateX(0px); } to { transform: translateX(100px) scale(2); } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("move").unwrap()
  let track = @computed.build_keyframe_track(rule, "transform", "none", ctx)
  let effect = @animation.AnimatableKeyframeEffect::new(
    track,
    @animation.EffectTiming::new(1000.0),
  ).unwrap()
  inspect(
    effect.sample(500.0).unwrap(),
    content="Transform({translate_x: Length(50), translate_y: Length(0), scale_x: 1.5, scale_y: 1.5, rotate_degrees: 0, skew_x_degrees: 0, skew_y_degrees: 0, has_matrix: false, matrix: [1, 0, 0, 1, 0, 0]})",
  )
}

///|
test "individual transform properties animate via @keyframes" {
  let ctx = @computed.ComputeContext::new()
  let css =
    #|@keyframes sp { from { translate: 0px; } to { translate: 100px 40px; } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("sp").unwrap()
  let track = @computed.build_keyframe_track(rule, "translate", "none", ctx)
  let effect = @animation.AnimatableKeyframeEffect::new(
    track,
    @animation.EffectTiming::new(1000.0),
  ).unwrap()
  inspect(
    effect.sample(500.0).unwrap(),
    content="Transform({translate_x: Length(50), translate_y: Length(20), scale_x: 1, scale_y: 1, rotate_degrees: 0, skew_x_degrees: 0, skew_y_degrees: 0, has_matrix: false, matrix: [1, 0, 0, 1, 0, 0]})",
  )
}

///|
test "matrix3d interpolates via 3D decompose / slerp / recompose" {
  let ctx = @computed.ComputeContext::new()
  // translate3d(0,0,0) -> translate3d(100,0,0) expressed as matrix3d().
  let css =
    #|@keyframes m { from { transform: matrix3d(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1); } to { transform: matrix3d(1,0,0,0, 0,1,0,0, 0,0,1,0, 100,0,0,1); } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("m").unwrap()
  let track = @computed.build_keyframe_track(rule, "transform", "none", ctx)
  let effect = @animation.AnimatableKeyframeEffect::new(
    track,
    @animation.EffectTiming::new(1000.0),
  ).unwrap()
  let mid = effect.sample(500.0).unwrap()
  // Midpoint translation is 50 (the 2D approximation exposes it at matrix e).
  inspect(
    mid,
    content="Transform({translate_x: Length(0), translate_y: Length(0), scale_x: 1, scale_y: 1, rotate_degrees: 0, skew_x_degrees: 0, skew_y_degrees: 0, has_matrix: true, matrix: [1, 0, 0, 1, 50, 0], matrix3d: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 50, 0, 0, 1]})",
  )
}

///|
test "transform matrix is decomposed for interpolation" {
  let ctx = @computed.ComputeContext::new()
  // matrix(1,0,0,1,100,0) is a pure translateX(100); interpolating with the
  // decomposed `none` must decompose the matrix and interpolate component-wise.
  let css =
    #|@keyframes m { from { transform: none; } to { transform: matrix(1, 0, 0, 1, 100, 0); } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("m").unwrap()
  let track = @computed.build_keyframe_track(rule, "transform", "none", ctx)
  let effect = @animation.AnimatableKeyframeEffect::new(
    track,
    @animation.EffectTiming::new(1000.0),
  ).unwrap()
  inspect(
    effect.sample(500.0).unwrap(),
    content="Transform({translate_x: Length(50), translate_y: Length(0), scale_x: 1, scale_y: 1, rotate_degrees: 0, skew_x_degrees: 0, skew_y_degrees: 0, has_matrix: false, matrix: [1, 0, 0, 1, 0, 0]})",
  )
}

///|
test "effect_timing_from_style bridges animation longhands" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "animation: slide 2s ease-in 0.5s infinite alternate both", ctx,
  )
  let timing = @computed.effect_timing_from_style(style, 0)
  // seconds -> ms
  inspect(timing.duration, content="2000")
  inspect(timing.delay, content="500")
  inspect(timing.fill, content="Both")
  inspect(timing.direction, content="Alternate")
  inspect(timing.easing, content="EaseIn")
  // infinite iteration count maps to an infinite Double
  assert_true(timing.iterations > 1.0e308)
}

///|
test "end-to-end: @keyframes + animation drive a sampled value" {
  let ctx = @computed.ComputeContext::new()
  let css =
    #|@keyframes grow { from { width: 0; } to { width: 200px; } }
  let sheet = @parser.parse_stylesheet(css)
  let rule = sheet.find_keyframes("grow").unwrap()
  // The element using the animation.
  let style = @computed.compute_inline("animation: grow 1s linear", ctx)
  let timing = @computed.effect_timing_from_style(style, 0)
  let track = @computed.build_keyframe_track(rule, "width", "0px", ctx)
  let effect = @animation.AnimatableKeyframeEffect::new(track, timing).unwrap()
  // 1s duration, linear, no fill: quarter time -> 50px.
  inspect(effect.sample(250.0).unwrap(), content="Length(50)")
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

///|
test "font-size parsing" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("font-size: 20px", ctx)
  inspect(style.font_size, content="20")
  let zero_style = @computed.compute_inline("font-size: 0", ctx)
  inspect(zero_style.font_size, content="0")
}

///|
test "line-height rem uses root font size" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 14.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline(
    "font-size: 0.875rem; line-height: 1.25rem", ctx,
  )
  inspect(style.font_size, content="14")
  inspect(style.line_height, content="20")
}

///|
test "font shorthand parsing" {
  let ctx = @computed.ComputeContext::new()

  // font: size/line-height family
  let style1 = @computed.compute_inline("font: 100px/1 Ahem", ctx)
  inspect(style1.font_size, content="100")
  inspect(style1.line_height, content="100") // 100 * 1 = 100

  // font: size/line-height family (with ratio)
  let style2 = @computed.compute_inline("font: 20px/1.5 sans-serif", ctx)
  inspect(style2.font_size, content="20")
  inspect(style2.line_height, content="30") // 20 * 1.5 = 30

  // font: size family (no line-height)
  let style3 = @computed.compute_inline("font: 16px Arial", ctx)
  inspect(style3.font_size, content="16")
  inspect(style3.line_height, content="16") // default 1:1 ratio
}

///|
test "em_dimensions_use_seeded_element_font_metrics" {
  let ctx = @computed.ComputeContext::new()
  let style1 = @computed.compute_inline("font: 25px/1 Ahem; width: 15em", ctx)
  inspect(style1.width, content="Length(375)")
  let style2 = @computed.compute_inline("width: 15em; font: 25px/1 Ahem", ctx)
  inspect(style2.width, content="Length(375)")
}

///|
test "logical properties inline-size and block-size" {
  let ctx = @computed.ComputeContext::new()

  // inline-size -> width (in horizontal-tb writing mode)
  let style1 = @computed.compute_inline("inline-size: 200px", ctx)
  inspect(style1.width, content="Length(200)")

  // block-size -> height (in horizontal-tb writing mode)
  let style2 = @computed.compute_inline("block-size: 100px", ctx)
  inspect(style2.height, content="Length(100)")

  // Both together
  let style3 = @computed.compute_inline(
    "inline-size: 300px; block-size: 150px", ctx,
  )
  inspect(style3.width, content="Length(300)")
  inspect(style3.height, content="Length(150)")
}

///|
test "intrinsic sizing keywords are preserved on physical and logical sizes" {
  let ctx = @computed.ComputeContext::new()

  // Physical properties keep intrinsic keywords as-is.
  let horizontal = @computed.compute_inline(
    "height: min-content; min-height: min-content; max-height: max-content", ctx,
  )
  inspect(horizontal.height, content="MinContent")
  inspect(horizontal.min_height, content="MinContent")
  inspect(horizontal.max_height, content="MaxContent")

  // Writing mode does not normalize intrinsic keywords on physical width/height.
  let vertical_width = @computed.compute_inline(
    "writing-mode: vertical-lr; width: min-content; min-width: min-content; max-width: max-content",
    ctx,
  )
  inspect(vertical_width.width, content="MinContent")
  inspect(vertical_width.min_width, content="MinContent")
  inspect(vertical_width.max_width, content="MaxContent")

  // Logical properties map to the target axis while preserving intrinsic keywords.
  let vertical_height = @computed.compute_inline(
    "writing-mode: vertical-lr; height: min-content; min-height: min-content; max-height: max-content",
    ctx,
  )
  inspect(vertical_height.height, content="MinContent")
  inspect(vertical_height.min_height, content="MinContent")
  inspect(vertical_height.max_height, content="MaxContent")

  // In vertical writing mode, block-size maps to width.
  let vertical_block = @computed.compute_inline(
    "writing-mode: vertical-lr; min-block-size: max-content; max-block-size: min-content",
    ctx,
  )
  inspect(vertical_block.min_width, content="MaxContent")
  inspect(vertical_block.max_width, content="MinContent")
}

///|
test "intrinsic keywords remain preserved with inherited writing-mode" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("writing-mode: vertical-lr", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline(
    "width: 150px; max-width: min-content", child_ctx,
  )
  inspect(child.max_width, content="MinContent")
}

///|
test "white-space inherits from parent style" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("white-space: nowrap", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("", child_ctx)
  inspect(child.white_space, content="Nowrap")
}

///|
test "text-overflow computes to ellipsis and is not inherited" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("text-overflow: ellipsis", root_ctx)
  inspect(parent.text_overflow, content="Ellipsis")
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("", child_ctx)
  inspect(child.text_overflow, content="Clip")
}

///|
test "pointer-events inherits from parent style" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("pointer-events: none", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("", child_ctx)
  inspect(child.pointer_events, content="None")
}

///|
test "pointer-events auto overrides inherited none" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("pointer-events: none", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("pointer-events: auto", child_ctx)
  inspect(child.pointer_events, content="Auto")
}

///|
test "compute_inline vmin and vmax units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1000.0,
    viewport_height: 800.0,
    custom_properties: Map([]),
  }

  // vmin = min(1000, 800) = 800, so 50vmin = 400px
  let style1 = @computed.compute_inline("width: 50vmin", ctx)
  inspect(style1.width, content="Length(400)")

  // vmax = max(1000, 800) = 1000, so 50vmax = 500px
  let style2 = @computed.compute_inline("width: 50vmax", ctx)
  inspect(style2.width, content="Length(500)")
}

///|
test "compute_inline ch and ex units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0, // 20px font
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }

  // ch ≈ 0.5em, so 4ch with 20px font = 4 * 20 * 0.5 = 40px
  let style1 = @computed.compute_inline("width: 4ch", ctx)
  inspect(style1.width, content="Length(40)")

  // ex ≈ 0.5em, so 2ex with 20px font = 2 * 20 * 0.5 = 20px
  let style2 = @computed.compute_inline("height: 2ex", ctx)
  inspect(style2.height, content="Length(20)")
}

///|
test "compute_inline ch units use square advance for inherited Ahem" {
  let ctx : @computed.ComputeContext = {
    parent_style: Some({ ..@style.Style::default(), font_family: "Ahem" }),
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
  let style = @computed.compute_inline("width: 4ch", ctx)
  inspect(style.width, content="Length(64)")
}

///|
test "compute_inline absolute units pt, pc, in, cm, mm" {
  let ctx = @computed.ComputeContext::new()

  // pt: 1pt = 96/72 px = 1.333...px, so 72pt = 96px
  let style_pt = @computed.compute_inline("width: 72pt", ctx)
  assert_true(style_pt.width.eq_length(96.0))

  // pc: 1pc = 16px, so 6pc = 96px
  let style_pc = @computed.compute_inline("width: 6pc", ctx)
  assert_true(style_pc.width.eq_length(96.0))

  // in: 1in = 96px
  let style_in = @computed.compute_inline("width: 1in", ctx)
  assert_true(style_in.width.eq_length(96.0))

  // cm: 1cm = 96/2.54 px ≈ 37.795px, so 2.54cm = 96px
  let style_cm = @computed.compute_inline("width: 2.54cm", ctx)
  assert_true(style_cm.width.eq_length(96.0))

  // mm: 1mm = 96/25.4 px, so 25.4mm = 96px
  let style_mm = @computed.compute_inline("width: 25.4mm", ctx)
  assert_true(style_mm.width.eq_length(96.0))
}

///|
test "compute_inline min() function" {
  let ctx = @computed.ComputeContext::new()

  // min(100px, 200px) = 100px
  let style1 = @computed.compute_inline("width: min(100px, 200px)", ctx)
  assert_true(style1.width.eq_length(100.0))

  // min(300px, 50px, 150px) = 50px
  let style2 = @computed.compute_inline("width: min(300px, 50px, 150px)", ctx)
  assert_true(style2.width.eq_length(50.0))
}

///|
test "compute_inline max() function" {
  let ctx = @computed.ComputeContext::new()

  // max(100px, 200px) = 200px
  let style1 = @computed.compute_inline("width: max(100px, 200px)", ctx)
  assert_true(style1.width.eq_length(200.0))

  // max(50px, 300px, 150px) = 300px
  let style2 = @computed.compute_inline("width: max(50px, 300px, 150px)", ctx)
  assert_true(style2.width.eq_length(300.0))
}

///|
test "compute_inline clamp() function" {
  let ctx = @computed.ComputeContext::new()

  // clamp(100px, 150px, 200px) = 150px (value is within bounds)
  let style1 = @computed.compute_inline(
    "width: clamp(100px, 150px, 200px)", ctx,
  )
  assert_true(style1.width.eq_length(150.0))

  // clamp(100px, 50px, 200px) = 100px (value below min)
  let style2 = @computed.compute_inline("width: clamp(100px, 50px, 200px)", ctx)
  assert_true(style2.width.eq_length(100.0))

  // clamp(100px, 250px, 200px) = 200px (value above max)
  let style3 = @computed.compute_inline(
    "width: clamp(100px, 250px, 200px)", ctx,
  )
  assert_true(style3.width.eq_length(200.0))
}

///|
test "compute_inline max() with single percentage argument preserves percent" {
  // crater#282 / WPT css/css-values/calc-in-max.html: `max(calc(100%))` must
  // resolve to a 100% percentage (deferred to layout), not collapse to Auto.
  let ctx = @computed.ComputeContext::new()
  let style1 = @computed.compute_inline("height: max(calc(100%))", ctx)
  assert_true(style1.height.eq_percent(1.0))
  let style2 = @computed.compute_inline("height: max(100%)", ctx)
  assert_true(style2.height.eq_percent(1.0))
  let style3 = @computed.compute_inline("width: min(50%)", ctx)
  assert_true(style3.width.eq_percent(0.5))
}

///|
test "compute_inline min()/max() with all-percentage arguments" {
  // For pure percentages the containing-block basis is positive, so ordering by
  // ratio matches ordering by resolved length: min(50%,100%)=50%, max=100%.
  let ctx = @computed.ComputeContext::new()
  let style1 = @computed.compute_inline("width: min(50%, 100%)", ctx)
  assert_true(style1.width.eq_percent(0.5))
  let style2 = @computed.compute_inline("width: max(50%, 100%)", ctx)
  assert_true(style2.width.eq_percent(1.0))
  let style3 = @computed.compute_inline("width: clamp(20%, 60%, 80%)", ctx)
  assert_true(style3.width.eq_percent(0.6))
}

///|
test "compute_inline min()/max() with mixed length+percentage resolves against basis" {
  // min(50%, 200px) / max(...) / clamp(...) mixing length and percentage cannot
  // be ordered until the containing-block basis is known, so they are carried as
  // a MathFn dimension and resolved at layout time (Dimension::resolve).
  let ctx = @computed.ComputeContext::new()
  let mn = @computed.compute_inline("width: min(50%, 200px)", ctx).width
  debug_inspect(mn.resolve(300.0), content="Some(150)") // 50% of 300 = 150 < 200
  debug_inspect(mn.resolve(500.0), content="Some(200)") // 50% of 500 = 250 > 200
  let mx = @computed.compute_inline("width: max(50%, 200px)", ctx).width
  debug_inspect(mx.resolve(300.0), content="Some(200)") // 150 < 200
  debug_inspect(mx.resolve(500.0), content="Some(250)") // 250 > 200
  let cl = @computed.compute_inline("width: clamp(100px, 50%, 300px)", ctx).width
  debug_inspect(cl.resolve(100.0), content="Some(100)") // 50%=50 < 100 -> 100
  debug_inspect(cl.resolve(400.0), content="Some(200)") // 50%=200 within -> 200
  debug_inspect(cl.resolve(1000.0), content="Some(300)") // 50%=500 > 300 -> 300
}

///|
test "compute_inline math functions reject invalid arguments to match parser" {
  // Invalid CSS args inside min()/max()/clamp() must resolve to Auto in the
  // compute layer just like the parser layer (parser/compute parity).
  let ctx = @computed.ComputeContext::new()
  // non-zero unitless number is not a valid length argument
  inspect(
    @computed.compute_inline("width: min(5, 100px)", ctx).width,
    content="Auto",
  )
  // unknown unit is not a valid length argument
  inspect(
    @computed.compute_inline("width: min(10foo, 100px)", ctx).width,
    content="Auto",
  )
  // unitless 0 stays valid
  inspect(
    @computed.compute_inline("width: max(0, 100px)", ctx).width,
    content="Length(100)",
  )
}

///|
test "compute_inline clamp() with min greater than max follows spec" {
  // CSS: clamp(MIN, VAL, MAX) == max(MIN, min(VAL, MAX)). When MIN > MAX the
  // result is MIN regardless of VAL.
  let ctx = @computed.ComputeContext::new()
  // all-px: clamp(300, 500, 200) = max(300, min(500,200)) = 300
  let px = @computed.compute_inline("width: clamp(300px, 500px, 200px)", ctx).width
  assert_true(px.eq_length(300.0))
  // all-percent: clamp(50%, 60%, 20%) = max(0.5, min(0.6,0.2)) = 0.5
  let pct = @computed.compute_inline("width: clamp(50%, 60%, 20%)", ctx).width
  assert_true(pct.eq_percent(0.5))
}

///|
test "compute_inline nested math functions" {
  let ctx = @computed.ComputeContext::new()

  // max(min(100px, 200px), 50px) = max(100px, 50px) = 100px
  let style1 = @computed.compute_inline(
    "width: max(min(100px, 200px), 50px)", ctx,
  )
  assert_true(style1.width.eq_length(100.0))

  // min(max(50px, 100px), 80px) = min(100px, 80px) = 80px
  let style2 = @computed.compute_inline(
    "width: min(max(50px, 100px), 80px)", ctx,
  )
  assert_true(style2.width.eq_length(80.0))
}

// =============================================================================
// CSS Custom Properties (Variables) Tests
// =============================================================================

///|
test "css variables - basic resolution" {
  // Create context with pre-defined custom properties
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--my-width": "100px", "--my-margin": "20px" },
  }
  // Use var() to reference custom property
  let style = @computed.compute_inline("width: var(--my-width)", ctx)
  inspect(style.width, content="Length(100)")
  let style2 = @computed.compute_inline("margin-left: var(--my-margin)", ctx)
  inspect(style2.margin.left, content="Length(20)")
}

///|
test "css variables - fallback value" {
  // Create context without the referenced variable
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: Map([]),
  }
  // Use var() with fallback
  let style = @computed.compute_inline("width: var(--undefined, 50px)", ctx)
  inspect(style.width, content="Length(50)")
}

///|
test "css variables - defined variable takes precedence over fallback" {
  // Variable is defined, fallback should be ignored
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--my-size": "200px" },
  }
  let style = @computed.compute_inline("width: var(--my-size, 50px)", ctx)
  inspect(style.width, content="Length(200)")
}

///|
test "css variables - nested var() in fallback" {
  // Fallback can contain another var()
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--fallback-size": "75px" },
  }
  // --undefined is not set, so fallback to var(--fallback-size)
  let style = @computed.compute_inline(
    "width: var(--undefined, var(--fallback-size))", ctx,
  )
  inspect(style.width, content="Length(75)")
}

///|
test "css variables - chained variable references" {
  // One variable references another
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {
      "--base-size": "50px",
      "--derived-size": "var(--base-size)",
    },
  }
  // Resolving --derived-size should resolve to --base-size value
  let style = @computed.compute_inline("width: var(--derived-size)", ctx)
  inspect(style.width, content="Length(50)")
}

///|
test "css variables - color values" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--primary-color": "#ff0000", "--bg-color": "blue" },
  }
  let style = @computed.compute_inline("color: var(--primary-color)", ctx)
  inspect(style.color.to_hex(), content="#ff0000")
  let style2 = @computed.compute_inline(
    "background-color: var(--bg-color)", ctx,
  )
  inspect(style2.background_color.to_hex(), content="#0000ff")
}

///|
test "compute_inline light-dark color function uses color-scheme dark" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "color-scheme: dark; background-color: light-dark(#f7f7f8, #212426)", ctx,
  )
  inspect(style.background_color.to_hex(), content="#212426")
}

///|
test "compute_inline light-dark resolves custom property arms" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "--light-bg: #f7f7f8; --dark-bg: #212426; color-scheme: dark; background-color: light-dark(var(--light-bg), var(--dark-bg))",
    ctx,
  )
  inspect(style.background_color.to_hex(), content="#212426")
}

///|
test "css variables - embedded var value resolves recursively" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "--color-gray-10: #212426; --color-gray-90: #f7f7f8; --csstools-color-scheme--light: ; --toggle: var(--csstools-color-scheme--light) var(--color-gray-10); --color-background-primary: var(--toggle, var(--color-gray-90)); background-color: var(--color-background-primary)",
    ctx,
  )
  inspect(style.background_color.to_hex(), content="#212426")
}

///|
test "parse_clip - auto" {
  let clip = @computed.parse_clip("auto")
  inspect(clip, content="auto")
}

///|
test "parse_clip - rect with px values" {
  let clip = @computed.parse_clip("rect(1px, 1px, 1px, 1px)")
  inspect(clip, content="rect(1, 1, 1, 1)")
}

///|
test "parse_clip - rect with comma separated values" {
  let clip = @computed.parse_clip("rect(10px, 100px, 50px, 5px)")
  inspect(clip, content="rect(10, 100, 50, 5)")
}

///|
test "parse_clip - rect with space separated values" {
  let clip = @computed.parse_clip("rect(10px 100px 50px 5px)")
  inspect(clip, content="rect(10, 100, 50, 5)")
}

///|
test "compute_inline clip property" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip: rect(1px, 1px, 1px, 1px)", ctx)
  inspect(style.clip, content="rect(1, 1, 1, 1)")
}

///|
test "compute_inline clip auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip: auto", ctx)
  inspect(style.clip, content="auto")
}

///|
test "compute_inline transform scale" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("transform: scaleX(2)", ctx)
  inspect(style.transform.scale_x, content="2")
  inspect(style.transform.scale_y, content="1")
}

///|
test "compute_inline transform rotate quarter turn" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("transform: rotate(90deg)", ctx)
  inspect(style.transform.rotate_degrees, content="90")
  inspect(style.transform.quarter_turns(), content="1")
}

///|
test "compute_inline transform skew" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: skewX(45deg) skewY(-15deg)", ctx,
  )
  inspect(style.transform.skew_x_degrees, content="45")
  inspect(style.transform.skew_y_degrees, content="-15")
}

///|
test "compute_inline transform matrix" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: matrix(1, 0, -1, 1, 64, 0)", ctx,
  )
  inspect(style.transform.has_matrix, content="true")
  debug_inspect(
    [
      style.transform.matrix_a,
      style.transform.matrix_b,
      style.transform.matrix_c,
      style.transform.matrix_d,
      style.transform.matrix_e,
      style.transform.matrix_f,
    ],
    content="[1, 0, -1, 1, 64, 0]",
  )
}

///|
test "compute_inline transform matrix3d as 2D affine matrix" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1)", ctx,
  )
  inspect(style.transform.has_matrix, content="true")
  debug_inspect(
    [
      style.transform.matrix_a,
      style.transform.matrix_b,
      style.transform.matrix_c,
      style.transform.matrix_d,
      style.transform.matrix_e,
      style.transform.matrix_f,
    ],
    content="[1, 0, -1, 1, 64, 0]",
  )
}

///|
test "parse_clip_path - inset" {
  let clip_path = @computed.parse_clip_path("inset(16px 0 25% 4px)")
  match clip_path {
    @style.ClipPath::Inset(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 0, -0.25, 4]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "parse_clip_path - rect" {
  let clip_path = @computed.parse_clip_path("rect(16px 128px 64px 16px)")
  match clip_path {
    @style.ClipPath::Rect(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 128, 64, 16]")
    _ => fail("expected rect clip-path")
  }
}

///|
test "parse_clip_path - xywh" {
  let clip_path = @computed.parse_clip_path("xywh(16px 16px 112px 48px)")
  match clip_path {
    @style.ClipPath::Xywh(x, y, width, height) =>
      debug_inspect([x, y, width, height], content="[16, 16, 112, 48]")
    _ => fail("expected xywh clip-path")
  }
}

///|
test "parse_clip_path - circle" {
  let clip_path = @computed.parse_clip_path("circle(24px at 24px 24px)")
  match clip_path {
    @style.ClipPath::Circle(radius, center_x, center_y) =>
      debug_inspect([radius, center_x, center_y], content="[24, 24, 24]")
    _ => fail("expected circle clip-path")
  }
}

///|
test "parse_clip_path - ellipse" {
  let clip_path = @computed.parse_clip_path("ellipse(24px 16px at 32px 32px)")
  match clip_path {
    @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) =>
      debug_inspect(
        [radius_x, radius_y, center_x, center_y],
        content="[24, 16, 32, 32]",
      )
    _ => fail("expected ellipse clip-path")
  }
}

///|
test "parse_clip_path - polygon" {
  let clip_path = @computed.parse_clip_path(
    "polygon(32px 0, 64px 64px, 0 64px)",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="3")
      let (x0, y0) = points[0]
      let (x1, y1) = points[1]
      let (x2, y2) = points[2]
      debug_inspect([x0, y0, x1, y1, x2, y2], content="[32, 0, 64, 64, 0, 64]")
    }
    _ => fail("expected polygon clip-path")
  }
}

///|
test "parse_clip_path - path as polygon" {
  let clip_path = @computed.parse_clip_path("path(\"M 32 0 L 64 64 L 0 64 Z\")")
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="3")
      let (x0, y0) = points[0]
      let (x1, y1) = points[1]
      let (x2, y2) = points[2]
      debug_inspect([x0, y0, x1, y1, x2, y2], content="[32, 0, 64, 64, 0, 64]")
    }
    _ => fail("expected path clip-path polygon")
  }
}

///|
test "parse_clip_path - quadratic path as polygon" {
  let clip_path = @computed.parse_clip_path("path(\"M 0 64 Q 32 0 64 64 Z\")")
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      debug_inspect([x0, y0, x4, y4, x8, y8], content="[0, 64, 32, 32, 64, 64]")
    }
    _ => fail("expected quadratic path clip-path polygon")
  }
}

///|
test "parse_clip_path - cubic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 C 0 0 64 0 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      debug_inspect([x0, y0, x4, y4, x8, y8], content="[0, 64, 32, 16, 64, 64]")
    }
    _ => fail("expected cubic path clip-path polygon")
  }
}

///|
test "parse_clip_path - smooth quadratic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 Q 16 0 32 64 T 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="17")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      let (x12, y12) = points[12]
      let (x16, y16) = points[16]
      debug_inspect(
        [x0, y0, x4, y4, x8, y8, x12, y12, x16, y16],
        content="[0, 64, 16, 32, 32, 64, 48, 96, 64, 64]",
      )
    }
    _ => fail("expected smooth quadratic path clip-path polygon")
  }
}

///|
test "parse_clip_path - smooth cubic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 C 0 0 32 0 32 64 S 64 128 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="17")
      let (x0, y0) = points[0]
      let (x8, y8) = points[8]
      let (x12, y12) = points[12]
      let (x16, y16) = points[16]
      debug_inspect(
        [x0, y0, x8, y8, x12, y12, x16, y16],
        content="[0, 64, 32, 64, 48, 112, 64, 64]",
      )
    }
    _ => fail("expected smooth cubic path clip-path polygon")
  }
}

///|
test "parse_clip_path - arc path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 A 32 32 0 0 1 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      assert_true((x0 - 0.0).abs() < 0.001)
      assert_true((y0 - 64.0).abs() < 0.001)
      assert_true((x4 - 32.0).abs() < 0.001)
      assert_true((y4 - 32.0).abs() < 0.001)
      assert_true((x8 - 64.0).abs() < 0.001)
      assert_true((y8 - 64.0).abs() < 0.001)
    }
    _ => fail("expected arc path clip-path polygon")
  }
}

///|
test "compute_inline clip-path property" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip-path: inset(16px 0 0 16px)", ctx)
  match style.clip_path {
    @style.ClipPath::Inset(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 0, 0, 16]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "compute_inline border-collapse" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-collapse: collapse", ctx)
  inspect(style.border_collapse, content="Collapse")
}

///|
test "compute_inline border-collapse separate" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-collapse: separate", ctx)
  inspect(style.border_collapse, content="Separate")
}

///|
test "compute_inline border-spacing single value sets both axes" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-spacing: 8px", ctx)
  inspect(style.border_spacing, content="8")
  inspect(style.border_spacing_vertical, content="8")
}

///|
test "compute_inline border-spacing two values sets vertical axis" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-spacing: 50px 100px", ctx)
  inspect(style.border_spacing, content="50")
  inspect(style.border_spacing_vertical, content="100")
}

///|
test "compute_inline margin-trim block" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin-trim: block", ctx)
  inspect(style.margin_trim, content="Block")
}

///|
test "compute_inline margin-trim block-start" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin-trim: block-start", ctx)
  inspect(style.margin_trim, content="BlockStart")
}

///|
test "compute_inline caption-side top" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("caption-side: top", ctx)
  inspect(style.caption_side, content="Top")
}

///|
test "compute_inline caption-side bottom" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("caption-side: bottom", ctx)
  inspect(style.caption_side, content="Bottom")
}

///|
test "compute_inline background linear-gradient" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "background: linear-gradient(to right, #ff0000, #0000ff)", ctx,
  )
  inspect(
    style.background_image,
    content=(
      #|Gradient({angle_deg: 90, stops: [{color: rgb(255, 0, 0), position: 0}, {color: rgb(0, 0, 255), position: 1}]})
    ),
  )
}

///|
test "compute_inline background linear-gradient resolves custom properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "--g-angle: 135deg; --g-color-0: #c4b5fd; --g-position-0: 0%; --g-color-1: #2dd4bf; --g-position-1: 100%; background: linear-gradient(var(--g-angle), var(--g-color-0) var(--g-position-0), var(--g-color-1) var(--g-position-1))",
    ctx,
  )
  inspect(
    style.background_image,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(196, 181, 253), position: 0}, {color: rgb(45, 212, 191), position: 1}]})
    ),
  )
}

///|
test "compute_inline border-radius percentage" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-radius: 50%", ctx)
  // Negative encodes percentage for render-time resolution
  inspect(
    style.border_top_left_radius,
    content=(
      #|-0.5
    ),
  )
  inspect(
    style.border_top_right_radius,
    content=(
      #|-0.5
    ),
  )
}

///|
test "parse_linear_gradient basic" {
  let result = @computed.parse_linear_gradient(
    "linear-gradient(135deg, #667eea, #764ba2)",
  )
  inspect(
    result,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(102, 126, 234), position: 0}, {color: rgb(118, 75, 162), position: 1}]})
    ),
  )
}

///|
test "compute_inline box-shadow parses multiple and inset shadows" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "box-shadow: 2px 4px 8px rgba(0,0,0,0.25), inset 0 2px 6px #112233", ctx,
  )

  inspect(style.box_shadows.length(), content="2")

  let first = style.box_shadows[0]
  inspect(first.inset, content="false")
  inspect(first.offset_x, content="2")
  inspect(first.offset_y, content="4")
  inspect(first.blur_radius, content="8")
  inspect(first.spread_radius, content="0")
  inspect(first.color.r, content="0")
  inspect(first.color.g, content="0")
  inspect(first.color.b, content="0")
  inspect(first.color.a, content="0.25")

  let second = style.box_shadows[1]
  inspect(second.inset, content="true")
  inspect(second.offset_x, content="0")
  inspect(second.offset_y, content="2")
  inspect(second.blur_radius, content="6")
  inspect(second.spread_radius, content="0")
  inspect(second.color.r, content="17")
  inspect(second.color.g, content="34")
  inspect(second.color.b, content="51")
}

///|
test "compute_inline box-shadow parses rgba color with spaced commas" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "box-shadow: 0 20px 60px rgba(15, 23, 42, 0.18)", ctx,
  )

  inspect(style.box_shadows.length(), content="1")
  let shadow = style.box_shadows[0]
  inspect(shadow.offset_x, content="0")
  inspect(shadow.offset_y, content="20")
  inspect(shadow.blur_radius, content="60")
  inspect(shadow.color.r, content="15")
  inspect(shadow.color.g, content="23")
  inspect(shadow.color.b, content="42")
  inspect(shadow.color.a, content="0.18")
}

///|
test "ComputeContext::new defaults" {
  let ctx = @computed.ComputeContext::new()
  inspect(ctx.font_size, content="16")
  inspect(ctx.root_font_size, content="16")
  inspect(ctx.viewport_width, content="1920")
  inspect(ctx.viewport_height, content="1080")
}

///|
test "ComputeContext::with_viewport overrides dimensions" {
  let ctx = @computed.ComputeContext::with_viewport(800.0, 600.0)
  inspect(ctx.viewport_width, content="800")
  inspect(ctx.viewport_height, content="600")
}

///|
test "ComputeContext::with_parent inherits font size from parent" {
  let parent : @style.Style = { ..@style.Style::default(), font_size: 24.0 }
  let ctx = @computed.ComputeContext::with_parent(parent)
  assert_true(ctx.parent_style is Some(_))
}

///|
test "ComputeContext::with_parent_and_vars copies custom properties" {
  let parent = @style.Style::default()
  let vars : Map[String, String] = Map([])
  vars["--brand"] = "red"
  vars["--spacing"] = "8px"
  let ctx = @computed.ComputeContext::with_parent_and_vars(parent, vars)
  debug_inspect(ctx.custom_properties.get("--brand"), content="Some(\"red\")")
  debug_inspect(ctx.custom_properties.get("--spacing"), content="Some(\"8px\")")
}

///|
test "compute_inline color inheritance" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("color: red", ctx)
  inspect(style.color.r, content="255")
  inspect(style.color.g, content="0")
  inspect(style.color.b, content="0")
}

///|
test "compute_inline border shorthand sets width and color" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border: 2px solid red", ctx)
  inspect(style.border.top, content="Length(2)")
  inspect(style.border.left, content="Length(2)")
  inspect(style.border_color.top.r, content="255")
}

///|
test "compute_inline margin shorthand 4-value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin: 10px 20px 30px 40px", ctx)
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(40)")
}

///|
test "compute_inline margin shorthand 3-value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin: 10px 20px 30px", ctx)
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(20)")
}

///|
test "compute_inline margin shorthand 2-value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin: 10px 20px", ctx)
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(10)")
  inspect(style.margin.left, content="Length(20)")
}

///|
test "compute_inline margin shorthand 1-value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin: 5px", ctx)
  inspect(style.margin.top, content="Length(5)")
  inspect(style.margin.right, content="Length(5)")
  inspect(style.margin.bottom, content="Length(5)")
  inspect(style.margin.left, content="Length(5)")
}

///|
test "compute_inline padding individual sides" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "padding-top: 1px; padding-right: 2px; padding-bottom: 3px; padding-left: 4px",
    ctx,
  )
  inspect(style.padding.top, content="Length(1)")
  inspect(style.padding.right, content="Length(2)")
  inspect(style.padding.bottom, content="Length(3)")
  inspect(style.padding.left, content="Length(4)")
}

///|
test "compute_inline visibility variants" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("visibility: hidden", ctx).visibility,
    content="Hidden",
  )
  inspect(
    @computed.compute_inline("visibility: visible", ctx).visibility,
    content="Visible",
  )
  inspect(
    @computed.compute_inline("visibility: collapse", ctx).visibility,
    content="Collapse",
  )
}

///|
test "compute_inline opacity clamps" {
  let ctx = @computed.ComputeContext::new()
  inspect(@computed.compute_inline("opacity: 0.5", ctx).opacity, content="0.5")
  inspect(@computed.compute_inline("opacity: 1", ctx).opacity, content="1")
  inspect(@computed.compute_inline("opacity: 0", ctx).opacity, content="0")
}

///|
test "compute_inline z-index value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("z-index: 10", ctx)
  inspect(style.z_index, content="Value(10)")
  let auto = @computed.compute_inline("z-index: auto", ctx)
  inspect(auto.z_index, content="Auto")
}

///|
test "compute_inline aspect-ratio" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("aspect-ratio: 16 / 9", ctx)
  debug_inspect(style.aspect_ratio, content="Some(1.7777777777777777)")
}

///|
test "compute_inline grid template columns" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "grid-template-columns: 1fr 2fr 100px", ctx,
  )
  inspect(style.grid_template_columns.length(), content="3")
}

///|
test "compute_inline gap shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("gap: 8px 12px", ctx)
  inspect(style.row_gap, content="Length(8)")
  inspect(style.column_gap, content="Length(12)")
}

///|
test "compute_inline gap single value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("gap: 10px", ctx)
  inspect(style.row_gap, content="Length(10)")
  inspect(style.column_gap, content="Length(10)")
}

///|
test "compute_inline font-weight numeric and keywords" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("font-weight: 700", ctx).font_weight,
    content="700",
  )
  inspect(
    @computed.compute_inline("font-weight: bold", ctx).font_weight,
    content="700",
  )
  inspect(
    @computed.compute_inline("font-weight: normal", ctx).font_weight,
    content="400",
  )
}

///|
test "compute_inline line-height as multiplier and length" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("line-height: 1.5", ctx).line_height,
    content="24",
  )
  inspect(
    @computed.compute_inline("line-height: 30px", ctx).line_height,
    content="30",
  )
}

///|
test "compute_inline border-radius shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-radius: 4px", ctx)
  inspect(style.border_top_left_radius, content="4")
  inspect(style.border_top_right_radius, content="4")
  inspect(style.border_bottom_right_radius, content="4")
  inspect(style.border_bottom_left_radius, content="4")
}

///|
test "compute_inline border-radius 4 corners" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-radius: 1px 2px 3px 4px", ctx)
  inspect(style.border_top_left_radius, content="1")
  inspect(style.border_top_right_radius, content="2")
  inspect(style.border_bottom_right_radius, content="3")
  inspect(style.border_bottom_left_radius, content="4")
}

///|
test "compute_inline text-decoration" {
  let ctx = @computed.ComputeContext::new()
  let underline = @computed.compute_inline("text-decoration: underline", ctx)
  inspect(underline.text_decoration_underline, content="true")
  let line_through = @computed.compute_inline(
    "text-decoration: line-through", ctx,
  )
  inspect(line_through.text_decoration_line_through, content="true")
  let overline = @computed.compute_inline("text-decoration: overline", ctx)
  inspect(overline.text_decoration_overline, content="true")
  let none = @computed.compute_inline("text-decoration: none", ctx)
  inspect(none.text_decoration_underline, content="false")
}

///|
test "compute_inline letter-spacing and word-spacing" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "letter-spacing: 0.5px; word-spacing: 2px", ctx,
  )
  inspect(style.letter_spacing, content="0.5")
  inspect(style.word_spacing, content="2")
}

///|
test "compute_inline writing-mode and direction" {
  let ctx = @computed.ComputeContext::new()
  let vert = @computed.compute_inline("writing-mode: vertical-rl", ctx)
  inspect(vert.writing_mode, content="VerticalRl")
  let rtl = @computed.compute_inline("direction: rtl", ctx)
  inspect(rtl.direction, content="Rtl")
}

///|
test "compute_inline text-overflow" {
  let ctx = @computed.ComputeContext::new()
  let ellipsis = @computed.compute_inline("text-overflow: ellipsis", ctx)
  inspect(ellipsis.text_overflow, content="Ellipsis")
  let clip = @computed.compute_inline("text-overflow: clip", ctx)
  inspect(clip.text_overflow, content="Clip")
}

///|
test "compute_inline transform parses translateX and rotate" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: translateX(20px) rotate(45deg)", ctx,
  )
  let tx = style.transform.compute_translate_x(100.0)
  inspect(tx, content="20")
  inspect(style.transform.rotate_degrees, content="45")
}

///|
test "compute_inline zoom propagates" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("zoom: 1.5", ctx)
  inspect(style.zoom, content="1.5")
}

///|
test "compute_inline overflow-x and overflow-y independent" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "overflow-x: hidden; overflow-y: scroll", ctx,
  )
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Scroll")
}

///|
test "compute_inline order and flex shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("flex: 2 1 100px; order: 3", ctx)
  inspect(style.flex_grow, content="2")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Length(100)")
  inspect(style.order, content="3")
}

///|
test "compute_inline color custom property fallback" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("color: var(--brand, #00ff00)", ctx)
  inspect(style.color.g, content="255")
}

///|
test "compute_inline logical margin properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "margin-inline-start: 4px; margin-inline-end: 8px; margin-block-start: 12px; margin-block-end: 16px",
    ctx,
  )
  inspect(style.margin.left, content="Length(4)")
  inspect(style.margin.right, content="Length(8)")
  inspect(style.margin.top, content="Length(12)")
  inspect(style.margin.bottom, content="Length(16)")
}

///|
test "compute_inline logical padding properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "padding-inline: 10px; padding-block: 20px", ctx,
  )
  inspect(style.padding.left, content="Length(10)")
  inspect(style.padding.right, content="Length(10)")
  inspect(style.padding.top, content="Length(20)")
  inspect(style.padding.bottom, content="Length(20)")
}

///|
test "compute_inline inset shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("inset: 5px", ctx)
  inspect(style.inset.top, content="Length(5)")
  inspect(style.inset.right, content="Length(5)")
  inspect(style.inset.bottom, content="Length(5)")
  inspect(style.inset.left, content="Length(5)")
}

///|
test "compute_inline inline-size and block-size in horizontal writing mode" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "inline-size: 200px; block-size: 100px", ctx,
  )
  // In horizontal-tb (default): inline -> width, block -> height
  inspect(style.width, content="Length(200)")
  inspect(style.height, content="Length(100)")
}

///|
test "compute_inline inline-size in vertical writing mode" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "writing-mode: vertical-rl; inline-size: 200px; block-size: 100px", ctx,
  )
  // vertical-rl: inline -> height, block -> width
  inspect(style.height, content="Length(200)")
  inspect(style.width, content="Length(100)")
}

///|
test "compute_inline padding block-start/end" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "padding-block-start: 1px; padding-block-end: 2px", ctx,
  )
  inspect(style.padding.top, content="Length(1)")
  inspect(style.padding.bottom, content="Length(2)")
}

///|
test "compute_inline border-top/right/bottom/left shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "border-top: 1px solid red; border-right: 2px solid green; border-bottom: 3px solid blue; border-left: 4px solid yellow",
    ctx,
  )
  inspect(style.border.top, content="Length(1)")
  inspect(style.border.right, content="Length(2)")
  inspect(style.border.bottom, content="Length(3)")
  inspect(style.border.left, content="Length(4)")
  inspect(style.border_color.top.r, content="255")
  inspect(style.border_color.right.g, content="128")
}

///|
test "compute_inline border-style shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-style: dashed", ctx)
  inspect(style.border_style.top, content="Dashed")
}

///|
test "compute_inline border-width shorthand 4-value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-width: 1px 2px 3px 4px", ctx)
  inspect(style.border.top, content="Length(1)")
  inspect(style.border.right, content="Length(2)")
  inspect(style.border.bottom, content="Length(3)")
  inspect(style.border.left, content="Length(4)")
}

///|
test "compute preserves border shorthand and longhand source order" {
  let ctx = @computed.ComputeContext::new()
  let border_decl = @cascade.Declaration::with_metadata(
    "border",
    @cascade.Value("10px solid transparent"),
    @cascade.Author,
    @cascade.Normal,
    { a: 0, b: 1, c: 0 },
    0,
  )
  let left_decl = @cascade.Declaration::with_metadata(
    "border-left-width",
    @cascade.Value("100px"),
    @cascade.Author,
    @cascade.Normal,
    { a: 0, b: 1, c: 0 },
    1,
  )
  let style = @computed.compute(@cascade.cascade([border_decl, left_decl]), ctx)
  inspect(style.border.top, content="Length(10)")
  inspect(style.border.right, content="Length(10)")
  inspect(style.border.bottom, content="Length(10)")
  inspect(style.border.left, content="Length(100)")

  let left_first_decl = @cascade.Declaration::with_metadata(
    "border-left-width",
    @cascade.Value("100px"),
    @cascade.Author,
    @cascade.Normal,
    { a: 0, b: 1, c: 0 },
    0,
  )
  let border_second_decl = @cascade.Declaration::with_metadata(
    "border",
    @cascade.Value("10px solid transparent"),
    @cascade.Author,
    @cascade.Normal,
    { a: 0, b: 1, c: 0 },
    1,
  )
  let style2 = @computed.compute(
    @cascade.cascade([border_second_decl, left_first_decl]),
    ctx,
  )
  inspect(style2.border.left, content="Length(10)")
}

///|
test "compute stylesheet preserves border shorthand and longhand source order" {
  let element = @selector.Element::with_classes("div", ["box"])
  let sheet = @parser.parse_stylesheet(
    ".box { border: 10px solid transparent; border-left-width: 100px; }",
  )
  let style = @computed.compute(
    @cascade.cascade_element(element, [sheet], []),
    @computed.ComputeContext::new(),
  )
  inspect(style.border.top, content="Length(10)")
  inspect(style.border.right, content="Length(10)")
  inspect(style.border.bottom, content="Length(10)")
  inspect(style.border.left, content="Length(100)")

  let reverse_sheet = @parser.parse_stylesheet(
    ".box { border-left-width: 100px; border: 10px solid transparent; }",
  )
  let reverse_style = @computed.compute(
    @cascade.cascade_element(element, [reverse_sheet], []),
    @computed.ComputeContext::new(),
  )
  inspect(reverse_style.border.left, content="Length(10)")
}

///|
/// Inline longhand must win over a stylesheet border shorthand even though the
/// stylesheet declaration carries a much larger source order. Inline (1,0,0,0)
/// specificity wins the cascade per property, but the shorthand expands to all
/// four sides at apply time, so the inline longhand must also be applied last.
test "compute inline border longhand overrides stylesheet shorthand" {
  let element = @selector.Element::with_classes("div", ["box"])
  // A leading rule pushes the `.box` rule's source order above 0 so the
  // stylesheet `border` declaration sorts after a naive inline source order.
  let sheet = @parser.parse_stylesheet(
    "div { color: red; } .box { border: 10px solid transparent; }",
  )
  let inline : Array[@cascade.Declaration] = [
    @cascade.Declaration::from_inline(
      "border-top-width",
      "100px",
      @cascade.Normal,
    ),
  ]
  let style = @computed.compute(
    @cascade.cascade_element(element, [sheet], inline),
    @computed.ComputeContext::new(),
  )
  inspect(style.border.top, content="Length(100)")
  inspect(style.border.right, content="Length(10)")
  inspect(style.border.bottom, content="Length(10)")
  inspect(style.border.left, content="Length(10)")
}

///|
test "compute_inline overflow shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("overflow: hidden", ctx)
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Hidden")
}

///|
test "compute_inline overflow-x and overflow-y separately" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "overflow-x: hidden; overflow-y: scroll", ctx,
  )
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Scroll")
}

///|
test "compute_inline transition shorthand consumes the declaration" {
  let ctx = @computed.ComputeContext::new()
  // transition is unsupported-visual but should still parse without error
  let style = @computed.compute_inline("transition: all 0.3s ease", ctx)
  // No layout effect; just verify computation succeeded
  inspect(style.display, content="Block")
}

///|
test "compute_inline background-color transparent keyword" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("background-color: transparent", ctx)
  inspect(style.background_color.a, content="0")
}

///|
test "compute_inline initial keyword resets to default" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("display: flex; display: initial", ctx)
  // initial resets back to block (the initial value for display)
  inspect(style.display, content="Block")
}

///|
test "compute_inline grid-row and grid-column shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "grid-row: 1 / 3; grid-column: 2 / 4", ctx,
  )
  // GridLine starts/ends both set
  inspect(style.grid_row.start, content="Line(1)")
  inspect(style.grid_row.end, content="Line(3)")
  inspect(style.grid_column.start, content="Line(2)")
  inspect(style.grid_column.end, content="Line(4)")
}

///|
test "compute_inline cursor parses without error" {
  let ctx = @computed.ComputeContext::new()
  // cursor is UnsupportedVisual but should still be processed
  let style = @computed.compute_inline("cursor: pointer", ctx)
  inspect(style.display, content="Block")
}

///|
test "compute_inline align-items and justify-items separately" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "align-items: center; justify-items: end", ctx,
  )
  inspect(style.align_items, content="Center")
  inspect(style.justify_items, content="End")
}

///|
test "compute_inline align-self and justify-self separately" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "align-self: end; justify-self: center", ctx,
  )
  inspect(style.align_self, content="End")
  inspect(style.justify_self, content="Center")
}

///|
test "compute_inline place-items shorthand" {
  let ctx = @computed.ComputeContext::new()
  // Single value applies to both align-items and justify-items.
  let single = @computed.compute_inline("place-items: center", ctx)
  inspect(single.align_items, content="Center")
  inspect(single.justify_items, content="Center")
  // Two values: <align-items> <justify-items>.
  let pair = @computed.compute_inline("place-items: center end", ctx)
  inspect(pair.align_items, content="Center")
  inspect(pair.justify_items, content="End")
  // Multi-token segment (first baseline) for the align-items component.
  let baseline = @computed.compute_inline(
    "place-items: first baseline start", ctx,
  )
  inspect(baseline.align_items, content="Baseline")
  inspect(baseline.justify_items, content="Start")
}

///|
test "compute_inline place-self shorthand" {
  let ctx = @computed.ComputeContext::new()
  let single = @computed.compute_inline("place-self: center", ctx)
  inspect(single.align_self, content="Center")
  inspect(single.justify_self, content="Center")
  let pair = @computed.compute_inline("place-self: end center", ctx)
  inspect(pair.align_self, content="End")
  inspect(pair.justify_self, content="Center")
}

///|
test "compute_inline calc with unitless multiplier" {
  let ctx = @computed.ComputeContext::new()
  // Multiplier after the length.
  inspect(
    @computed.compute_inline("width: calc(10px * 2)", ctx).width,
    content="Length(20)",
  )
  // Multiplier before the length (leading factor).
  inspect(
    @computed.compute_inline("width: calc(2 * 10px)", ctx).width,
    content="Length(20)",
  )
  // Division by a unitless number.
  inspect(
    @computed.compute_inline("width: calc(10px / 2)", ctx).width,
    content="Length(5)",
  )
  // Percentage scaled by a leading factor.
  inspect(
    @computed.compute_inline("width: calc(2 * 50%)", ctx).width,
    content="Percent(1)",
  )
  // Mixed calc must still be preserved, not collapsed by the factor changes.
  inspect(
    @computed.compute_inline("width: calc(100% - 50px)", ctx).width,
    content="Calc(-50, 1)",
  )
}

///|
test "compute_inline calc operator precedence, parens, nested math" {
  let ctx = @computed.ComputeContext::new()
  // Multiplication binds tighter than addition: 2 + (3*2) = 8, not (2+3)*2.
  inspect(
    @computed.compute_inline("width: calc(2px + 3px * 2)", ctx).width,
    content="Length(8)",
  )
  // A unitless factor mid-expression.
  inspect(
    @computed.compute_inline("width: calc(10px + 2 * 3px)", ctx).width,
    content="Length(16)",
  )
  // Parentheses override precedence.
  inspect(
    @computed.compute_inline("width: calc((10px + 2px) * 2)", ctx).width,
    content="Length(24)",
  )
  // Nested math function inside calc().
  inspect(
    @computed.compute_inline("width: calc(min(10px, 20px) + 5px)", ctx).width,
    content="Length(15)",
  )
  // Existing simple cases still hold.
  inspect(
    @computed.compute_inline("width: calc(10px + 5px + 2px)", ctx).width,
    content="Length(17)",
  )
  inspect(
    @computed.compute_inline("width: calc(100% / 3)", ctx).width,
    content="Percent(0.33333333333333337)",
  )
  // Mixed px + percent preserved.
  inspect(
    @computed.compute_inline("width: calc(100% - 50px)", ctx).width,
    content="Calc(-50, 1)",
  )
}

///|
test "compute_inline calc with em/ex operands and scientific notation" {
  let ctx = @computed.ComputeContext::new()
  // `em`/`ex` start with `e`; the tokenizer must not mistake it for an exponent.
  inspect(
    @computed.compute_inline("width: calc(20em * -1)", ctx).width,
    content="Length(-320)",
  )
  inspect(
    @computed.compute_inline("width: calc(2ex + 1ex)", ctx).width,
    content="Length(24)",
  )
  // Genuine scientific notation still parses.
  inspect(
    @computed.compute_inline("width: calc(1e2px + 0px)", ctx).width,
    content="Length(100)",
  )
}

///|
test "compute_inline invalid calc falls back to initial value" {
  let ctx = @computed.ComputeContext::new()
  // Bare number, length × length, and division by zero are all invalid and must
  // not silently produce a wrong length.
  inspect(
    @computed.compute_inline("width: calc(2 + 3 * 4)", ctx).width,
    content="Auto",
  )
  inspect(
    @computed.compute_inline("width: calc(10px * 2px)", ctx).width,
    content="Auto",
  )
  inspect(
    @computed.compute_inline("width: calc(10px / 0)", ctx).width,
    content="Auto",
  )
  inspect(
    @computed.compute_inline("width: calc(10px +)", ctx).width,
    content="Auto",
  )
}

///|
test "compute_inline units are case-insensitive" {
  let ctx = @computed.ComputeContext::new()
  // CSS units are ASCII case-insensitive.
  inspect(
    @computed.compute_inline("width: 10PX", ctx).width,
    content="Length(10)",
  )
  inspect(
    @computed.compute_inline("width: 1REM", ctx).width,
    content="Length(16)",
  )
  inspect(
    @computed.compute_inline("width: 2EM", ctx).width,
    content="Length(32)",
  )
  // 5q and 5Q must agree (and not fall back to Auto).
  assert_eq(
    @computed.compute_inline("width: 5q", ctx).width,
    @computed.compute_inline("width: 5Q", ctx).width,
  )
  assert_eq(
    @computed.compute_inline("width: 10VW", ctx).width,
    @types.Length(192.0),
  )
}

///|
test "compute_inline vi and vb viewport units" {
  // vi/vb map to vw/vh in the assumed horizontal-tb writing mode.
  let ctx = @computed.ComputeContext::new()
  assert_eq(
    @computed.compute_inline("width: 10vi", ctx).width,
    @computed.compute_inline("width: 10vw", ctx).width,
  )
  assert_eq(
    @computed.compute_inline("width: 10vb", ctx).width,
    @computed.compute_inline("width: 10vh", ctx).width,
  )
}

///|
test "compute_inline two-value logical shorthands" {
  let ctx = @computed.ComputeContext::new()
  // These resolved the whole "A B" string as one dimension and silently
  // collapsed to Auto; only the single-value form worked.
  let mi = @computed.compute_inline("margin-inline: 10px 20px", ctx)
  inspect(mi.margin.left, content="Length(10)")
  inspect(mi.margin.right, content="Length(20)")
  let mb = @computed.compute_inline("margin-block: 5px 15px", ctx)
  inspect(mb.margin.top, content="Length(5)")
  inspect(mb.margin.bottom, content="Length(15)")
  let pi = @computed.compute_inline("padding-inline: 1px 2px", ctx)
  inspect(pi.padding.left, content="Length(1)")
  inspect(pi.padding.right, content="Length(2)")
  let ib = @computed.compute_inline("inset-block: 3px 4px", ctx)
  inspect(ib.inset.top, content="Length(3)")
  inspect(ib.inset.bottom, content="Length(4)")
  // Single value still applies to both ends.
  let one = @computed.compute_inline("margin-inline: 10px", ctx)
  inspect(one.margin.left, content="Length(10)")
  inspect(one.margin.right, content="Length(10)")
}

///|
test "compute_inline two-value overflow shorthand" {
  let ctx = @computed.ComputeContext::new()
  let s = @computed.compute_inline("overflow: hidden scroll", ctx)
  inspect(s.overflow_x, content="Hidden")
  inspect(s.overflow_y, content="Scroll")
  // Single value applies to both axes.
  let one = @computed.compute_inline("overflow: auto", ctx)
  inspect(one.overflow_x, content="Auto")
  inspect(one.overflow_y, content="Auto")
}

///|
test "compute_inline flex shorthand keyword forms" {
  let ctx = @computed.ComputeContext::new()
  // flex: none = 0 0 auto
  let none = @computed.compute_inline("flex: none", ctx)
  inspect(none.flex_grow, content="0")
  inspect(none.flex_shrink, content="0")
  inspect(none.flex_basis, content="Auto")
  // flex: auto = 1 1 auto
  let auto = @computed.compute_inline("flex: auto", ctx)
  inspect(auto.flex_grow, content="1")
  inspect(auto.flex_shrink, content="1")
  inspect(auto.flex_basis, content="Auto")
  // flex: 1 = 1 1 0%
  let one = @computed.compute_inline("flex: 1", ctx)
  inspect(one.flex_grow, content="1")
  inspect(one.flex_shrink, content="1")
  inspect(one.flex_basis, content="Percent(0)")
  // flex: 2 0 100px = explicit triple
  let triple = @computed.compute_inline("flex: 2 0 100px", ctx)
  inspect(triple.flex_grow, content="2")
  inspect(triple.flex_shrink, content="0")
  inspect(triple.flex_basis, content="Length(100)")
}

///|
test "compute_inline var() nested fallback chain" {
  let ctx = @computed.ComputeContext::new()
  // Neither --a nor --b defined: falls through to the innermost literal.
  inspect(
    @computed.compute_inline("width: var(--a, var(--b, 10px))", ctx).width,
    content="Length(10)",
  )
  // --b defined: the inner var() resolves before reaching the literal.
  inspect(
    @computed.compute_inline("--b: 20px; width: var(--a, var(--b, 10px))", ctx).width,
    content="Length(20)",
  )
}

///|
test "compute_inline grid-auto-rows and grid-auto-columns" {
  let ctx = @computed.ComputeContext::new()
  // These were declared on Style but never applied: the StyleBuilder lacked the
  // fields and build() hardcoded empty arrays.
  let rows = @computed.compute_inline("grid-auto-rows: 100px 200px", ctx)
  inspect(rows.grid_auto_rows.length(), content="2")
  let cols = @computed.compute_inline("grid-auto-columns: 50px", ctx)
  inspect(cols.grid_auto_columns.length(), content="1")
  // grid-auto-flow keeps the dense keyword through the full compute path.
  inspect(
    @computed.compute_inline("grid-auto-flow: row dense", ctx).grid_auto_flow,
    content="RowDense",
  )
  inspect(
    @computed.compute_inline("grid-auto-flow: column dense", ctx).grid_auto_flow,
    content="ColumnDense",
  )
}

///|
test "compute_inline transform grad angle unit" {
  let ctx = @computed.ComputeContext::new()
  // 200grad = 180deg. `grad` ends with `rad`, so it previously matched the
  // `rad` suffix, failed to parse "200g", and collapsed to 0.
  inspect(
    @computed.compute_inline("transform: rotate(200grad)", ctx).transform.quarter_turns(),
    content="2",
  )
  inspect(
    @computed.compute_inline("transform: rotate(100grad)", ctx).transform.quarter_turns(),
    content="1",
  )
}

///|
test "apply_property_direct mutates existing style" {
  let ctx = @computed.ComputeContext::new()
  let base = @computed.compute_inline("display: block", ctx)
  let updated = @computed.apply_property_direct(base, "padding", "16px", ctx)
  inspect(updated.padding.top, content="Length(16)")
  inspect(updated.padding.left, content="Length(16)")
}

///|
test "compute_inline table-layout, border-collapse, caption-side" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "table-layout: fixed; border-collapse: collapse; caption-side: bottom", ctx,
  )
  inspect(style.table_layout, content="Fixed")
  inspect(style.border_collapse, content="Collapse")
  inspect(style.caption_side, content="Bottom")
}

///|
test "compute_inline border-spacing single value" {
  let ctx = @computed.ComputeContext::new()
  let s = @computed.compute_inline("border-spacing: 4px", ctx)
  inspect(s.border_spacing, content="4")
  inspect(s.border_spacing_vertical, content="4")
}

///|
test "compute_inline border-spacing two values" {
  let ctx = @computed.ComputeContext::new()
  let s = @computed.compute_inline("border-spacing: 4px 8px", ctx)
  inspect(s.border_spacing, content="4")
  inspect(s.border_spacing_vertical, content="8")
}

///|
test "compute_inline column-fill" {
  let ctx = @computed.ComputeContext::new()
  let balance = @computed.compute_inline("column-fill: balance", ctx)
  inspect(balance.column_fill, content="Balance")
  let auto = @computed.compute_inline("column-fill: auto", ctx)
  inspect(auto.column_fill, content="Auto")
}

///|
test "compute_inline margin-trim variants" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("margin-trim: block", ctx).margin_trim,
    content="Block",
  )
  inspect(
    @computed.compute_inline("margin-trim: inline", ctx).margin_trim,
    content="Inline",
  )
  inspect(
    @computed.compute_inline("margin-trim: block-start", ctx).margin_trim,
    content="BlockStart",
  )
  inspect(
    @computed.compute_inline("margin-trim: none", ctx).margin_trim,
    content="None",
  )
}

///|
test "compute_inline clip-path inset" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip-path: inset(5px 10px)", ctx)
  let is_inset = match style.clip_path {
    Inset(_, _, _, _) => true
    _ => false
  }
  assert_true(is_inset)
}

///|
test "compute_inline clip-path circle" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "clip-path: circle(50px at 25px 50px)", ctx,
  )
  let is_circle = match style.clip_path {
    Circle(_, _, _) => true
    _ => false
  }
  assert_true(is_circle)
}

///|
test "compute_inline filter sets has_filter flag" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("filter: blur(5px)", ctx)
  inspect(style.has_filter, content="true")
}

///|
test "compute_inline vertical-align variants" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("vertical-align: top", ctx).vertical_align,
    content="Top",
  )
  inspect(
    @computed.compute_inline("vertical-align: middle", ctx).vertical_align,
    content="Middle",
  )
  inspect(
    @computed.compute_inline("vertical-align: bottom", ctx).vertical_align,
    content="Bottom",
  )
  inspect(
    @computed.compute_inline("vertical-align: text-top", ctx).vertical_align,
    content="TextTop",
  )
  inspect(
    @computed.compute_inline("vertical-align: sub", ctx).vertical_align,
    content="Sub",
  )
}

///|
test "compute_inline rowspan and colspan from HTML attributes" {
  let ctx = @computed.ComputeContext::new()
  // These are normally HTML attribute -> style; expose via parse
  let style = @computed.compute_inline("rowspan: 3; colspan: 2", ctx)
  // The compute layer may or may not handle these; ensure no panic.
  let _ = style
  inspect(true, content="true")
}

///|
test "compute_inline -webkit-line-clamp does not break compute" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("-webkit-line-clamp: 3", ctx)
  inspect(style.display, content="Block")
}

///|
test "compute_inline align-content stretch and start" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("align-content: stretch", ctx).align_content,
    content="Stretch",
  )
  inspect(
    @computed.compute_inline("align-content: start", ctx).align_content,
    content="Start",
  )
}

///|
test "compute_inline justify-content space variants" {
  let ctx = @computed.ComputeContext::new()
  inspect(
    @computed.compute_inline("justify-content: space-between", ctx).justify_content,
    content="SpaceBetween",
  )
  inspect(
    @computed.compute_inline("justify-content: space-around", ctx).justify_content,
    content="SpaceAround",
  )
  inspect(
    @computed.compute_inline("justify-content: space-evenly", ctx).justify_content,
    content="SpaceEvenly",
  )
}

///|
test "compute_inline custom property declaration" {
  let ctx = @computed.ComputeContext::new()
  let (_, vars) = @computed.compute_with_vars(
    @cascade.cascade([@cascade.Declaration::new("--my-color", "#123456")]),
    ctx,
  )
  debug_inspect(vars.get("--my-color"), content="Some(\"#123456\")")
}

///|
test "compute - inherited color from parent context" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    color: @types.Color::rgb(100, 100, 100),
  }
  let ctx = @computed.ComputeContext::with_parent(parent)
  // color is inherited; without an explicit declaration, child should pick up parent color
  let style = @computed.compute(@cascade.cascade([]), ctx)
  inspect(style.color.r, content="100")
}

///|
test "compute - explicit inherit keyword forces inheritance" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    color: @types.Color::rgb(50, 60, 70),
  }
  let ctx = @computed.ComputeContext::with_parent(parent)
  let decl : @cascade.Declaration = {
    property: "color",
    value: @cascade.Inherit,
    origin: @cascade.Author,
    importance: @cascade.Normal,
    specificity: { a: 0, b: 0, c: 0 },
    source_order: 0,
  }
  let style = @computed.compute(@cascade.cascade([decl]), ctx)
  inspect(style.color.r, content="50")
}

///|
test "compute_inline parses font shorthand minimal" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("font: 14px Arial", ctx)
  inspect(style.font_size, content="14")
}

///|
/// Helper: build a parent style with a single property set, then compute a
/// declaration that explicitly inherits that property. Returns the computed
/// child style.
fn compute_inheriting(prop : String, parent : @style.Style) -> @style.Style {
  let ctx = @computed.ComputeContext::with_parent(parent)
  let decl : @cascade.Declaration = {
    property: prop,
    value: @cascade.Inherit,
    origin: @cascade.Author,
    importance: @cascade.Normal,
    specificity: { a: 0, b: 0, c: 0 },
    source_order: 0,
  }
  @computed.compute(@cascade.cascade([decl]), ctx)
}

///|
test "Inherit - display variants" {
  for
    d in [
      @types.Inline,
      @types.InlineBlock,
      @types.Flex,
      @types.InlineFlex,
      @types.Grid,
      @types.InlineGrid,
      @types.Table,
      @types.InlineTable,
      @types.TableRow,
      @types.TableCell,
      @types.TableCaption,
      @types.TableRowGroup,
      @types.TableHeaderGroup,
      @types.TableFooterGroup,
      @types.TableColumn,
      @types.TableColumnGroup,
      @types.Display::None,
      @types.Contents,
      @types.FlowRoot,
    ] {
    let parent : @style.Style = { ..@style.Style::default(), display: d }
    let s = compute_inheriting("display", parent)
    inspect(s.display, content=d.to_string())
  }
}

///|
test "Inherit - position variants" {
  for
    p in [
      @types.Position::Relative,
      @types.Position::Absolute,
      @types.Position::Fixed,
    ] {
    let parent : @style.Style = { ..@style.Style::default(), position: p }
    let s = compute_inheriting("position", parent)
    inspect(s.position, content=p.to_string())
  }
}

///|
test "Inherit - flex-direction variants" {
  for
    d in [@types.RowReverse, @types.FlexDirection::Column, @types.ColumnReverse] {
    let parent : @style.Style = { ..@style.Style::default(), flex_direction: d }
    let s = compute_inheriting("flex-direction", parent)
    inspect(s.flex_direction, content=d.to_string())
  }
}

///|
test "Inherit - flex-wrap variants" {
  for w in [@types.Wrap, @types.WrapReverse] {
    let parent : @style.Style = { ..@style.Style::default(), flex_wrap: w }
    let s = compute_inheriting("flex-wrap", parent)
    inspect(s.flex_wrap, content=w.to_string())
  }
}

///|
test "Inherit - dimensions" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Percent(0.5),
    min_width: @types.Length(50.0),
    min_height: @types.Length(20.0),
    max_width: @types.Length(200.0),
    max_height: @types.Length(150.0),
  }
  inspect(compute_inheriting("width", parent).width, content="Length(100)")
  inspect(compute_inheriting("height", parent).height, content="Percent(0.5)")
  inspect(
    compute_inheriting("min-width", parent).min_width,
    content="Length(50)",
  )
  inspect(
    compute_inheriting("min-height", parent).min_height,
    content="Length(20)",
  )
  inspect(
    compute_inheriting("max-width", parent).max_width,
    content="Length(200)",
  )
  inspect(
    compute_inheriting("max-height", parent).max_height,
    content="Length(150)",
  )
}

///|
test "Inherit - margin/padding individual sides" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    margin: {
      top: @types.Length(1.0),
      right: @types.Length(2.0),
      bottom: @types.Length(3.0),
      left: @types.Length(4.0),
    },
    padding: {
      top: @types.Length(5.0),
      right: @types.Length(6.0),
      bottom: @types.Length(7.0),
      left: @types.Length(8.0),
    },
  }
  inspect(
    compute_inheriting("margin-top", parent).margin.top,
    content="Length(1)",
  )
  inspect(
    compute_inheriting("margin-right", parent).margin.right,
    content="Length(2)",
  )
  inspect(
    compute_inheriting("margin-bottom", parent).margin.bottom,
    content="Length(3)",
  )
  inspect(
    compute_inheriting("margin-left", parent).margin.left,
    content="Length(4)",
  )
  inspect(
    compute_inheriting("padding-top", parent).padding.top,
    content="Length(5)",
  )
  inspect(
    compute_inheriting("padding-right", parent).padding.right,
    content="Length(6)",
  )
  inspect(
    compute_inheriting("padding-bottom", parent).padding.bottom,
    content="Length(7)",
  )
  inspect(
    compute_inheriting("padding-left", parent).padding.left,
    content="Length(8)",
  )
}

///|
test "Inherit - margin-trim variants" {
  for
    mt in [
      @style.MarginTrim::BlockStart,
      @style.MarginTrim::BlockEnd,
      @style.MarginTrim::Block,
      @style.MarginTrim::InlineStart,
      @style.MarginTrim::InlineEnd,
      @style.MarginTrim::Inline,
    ] {
    let parent : @style.Style = { ..@style.Style::default(), margin_trim: mt }
    let s = compute_inheriting("margin-trim", parent)
    inspect(s.margin_trim, content=mt.to_string())
  }
}

///|
test "Inherit - column-* values" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    column_count: Some(3),
    column_width: @types.Length(100.0),
    column_fill: @style.ColumnFill::Auto,
    break_before: @style.BreakBefore::Column,
    break_after: @style.BreakBefore::Avoid,
    break_inside: @style.BreakInside::Avoid,
    column_span: @style.ColumnSpan::All,
  }
  debug_inspect(
    compute_inheriting("column-count", parent).column_count,
    content="Some(3)",
  )
  inspect(
    compute_inheriting("column-width", parent).column_width,
    content="Length(100)",
  )
  let parent_calc : @style.Style = {
    ..@style.Style::default(),
    column_width: @types.Calc(-10.0, 0.5),
  }
  inspect(
    compute_inheriting("column-width", parent_calc).column_width,
    content="Calc(-10, 0.5)",
  )
  inspect(compute_inheriting("column-fill", parent).column_fill, content="Auto")
  inspect(
    compute_inheriting("break-before", parent).break_before,
    content="Column",
  )
  inspect(
    compute_inheriting("break-after", parent).break_after,
    content="Avoid",
  )
  inspect(
    compute_inheriting("break-inside", parent).break_inside,
    content="Avoid",
  )
  inspect(compute_inheriting("column-span", parent).column_span, content="All")
}

///|
test "Inherit - text and color properties" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    flex_grow: 2.5,
    flex_shrink: 0.5,
    flex_basis: @types.Length(50.0),
    color: @types.Color::rgb(10, 20, 30),
    background_color: @types.Color::rgb(40, 50, 60),
    font_size: 18.0,
    font_weight: 700.0,
    line_height: 27.0,
    text_overflow: @style.TextOverflow::Ellipsis,
    text_align: @style.TextAlign::Center,
    white_space: @style.WhiteSpace::PreWrap,
    pointer_events: @style.PointerEvents::None,
  }
  inspect(compute_inheriting("flex-grow", parent).flex_grow, content="2.5")
  inspect(compute_inheriting("flex-shrink", parent).flex_shrink, content="0.5")
  inspect(
    compute_inheriting("flex-basis", parent).flex_basis,
    content="Length(50)",
  )
  inspect(compute_inheriting("color", parent).color.r, content="10")
  inspect(
    compute_inheriting("background-color", parent).background_color.r,
    content="40",
  )
  inspect(compute_inheriting("font-size", parent).font_size, content="18")
  inspect(compute_inheriting("font-weight", parent).font_weight, content="700")
  inspect(
    compute_inheriting("text-overflow", parent).text_overflow,
    content="Ellipsis",
  )
  inspect(compute_inheriting("text-align", parent).text_align, content="Center")
  inspect(
    compute_inheriting("white-space", parent).white_space,
    content="PreWrap",
  )
}

///|
test "Inherit - table properties" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    caption_side: @style.CaptionSide::Bottom,
    border_collapse: @style.BorderCollapse::Collapse,
    border_spacing: 4.0,
    border_spacing_vertical: 8.0,
    writing_mode: @style.WritingMode::VerticalRl,
    direction: @style.Direction::Rtl,
  }
  inspect(
    compute_inheriting("caption-side", parent).caption_side,
    content="Bottom",
  )
  inspect(
    compute_inheriting("border-collapse", parent).border_collapse,
    content="Collapse",
  )
  // border-spacing inheritance goes through string serialization
  let s = compute_inheriting("border-spacing", parent)
  let _ = s.border_spacing
  inspect(
    compute_inheriting("writing-mode", parent).writing_mode,
    content="VerticalRl",
  )
  inspect(compute_inheriting("direction", parent).direction, content="Rtl")
}

///|
test "Inherit - contain-intrinsic-size" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    contain_intrinsic_inline_size: Some(80.0),
    contain_intrinsic_block_size: Some(40.0),
  }
  debug_inspect(
    compute_inheriting("contain-intrinsic-inline-size", parent).contain_intrinsic_inline_size,
    content="Some(80)",
  )
  debug_inspect(
    compute_inheriting("contain-intrinsic-block-size", parent).contain_intrinsic_block_size,
    content="Some(40)",
  )
}

///|
test "Inherit - opacity serializes the parent computed value" {
  let parent : @style.Style = { ..@style.Style::default(), opacity: 0.25 }
  inspect(compute_inheriting("opacity", parent).opacity, content="0.25")
}

///|
test "Initial keyword - all properties" {
  // PropertyValue::Initial resets to initial_value(property)
  let ctx = @computed.ComputeContext::new()
  let make_decl = fn(prop : String) {
    let d : @cascade.Declaration = {
      property: prop,
      value: @cascade.Initial,
      origin: @cascade.Author,
      importance: @cascade.Normal,
      specificity: { a: 0, b: 0, c: 0 },
      source_order: 0,
    }
    d
  }
  let s = @computed.compute(
    @cascade.cascade([
      make_decl("display"),
      make_decl("position"),
      make_decl("color"),
    ]),
    ctx,
  )
  inspect(s.display, content="Block") // initial display
  inspect(s.position, content="Relative")
}

///|
test "Unset keyword on inherited property uses parent" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    color: @types.Color::rgb(100, 150, 200),
  }
  let ctx = @computed.ComputeContext::with_parent(parent)
  let decl : @cascade.Declaration = {
    property: "color",
    value: @cascade.Unset,
    origin: @cascade.Author,
    importance: @cascade.Normal,
    specificity: { a: 0, b: 0, c: 0 },
    source_order: 0,
  }
  let s = @computed.compute(@cascade.cascade([decl]), ctx)
  inspect(s.color.r, content="100")
}

///|
test "Unset keyword on non-inherited property uses initial" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    display: @types.Flex,
  }
  let ctx = @computed.ComputeContext::with_parent(parent)
  let decl : @cascade.Declaration = {
    property: "display",
    value: @cascade.Unset,
    origin: @cascade.Author,
    importance: @cascade.Normal,
    specificity: { a: 0, b: 0, c: 0 },
    source_order: 0,
  }
  let s = @computed.compute(@cascade.cascade([decl]), ctx)
  // display is non-inherited, so unset → initial → block
  inspect(s.display, content="Block")
}

///|
test "Revert keyword falls back to initial" {
  let ctx = @computed.ComputeContext::new()
  let decl : @cascade.Declaration = {
    property: "display",
    value: @cascade.Revert,
    origin: @cascade.Author,
    importance: @cascade.Normal,
    specificity: { a: 0, b: 0, c: 0 },
    source_order: 0,
  }
  let s = @computed.compute(@cascade.cascade([decl]), ctx)
  inspect(s.display, content="Block")
}

///|
test "compute_inline - viewport units vw/vh" {
  let ctx = @computed.ComputeContext::with_viewport(1000.0, 800.0)
  let s = @computed.compute_inline("width: 50vw; height: 25vh", ctx)
  inspect(s.width, content="Length(500)")
  inspect(s.height, content="Length(200)")
}

///|
test "compute_inline - viewport units dvw/dvh/svw/svh/lvw/lvh" {
  let ctx = @computed.ComputeContext::with_viewport(1000.0, 800.0)
  let dvw = @computed.compute_inline("width: 100dvw", ctx)
  inspect(dvw.width, content="Length(1000)")
  let dvh = @computed.compute_inline("height: 50dvh", ctx)
  inspect(dvh.height, content="Length(400)")
  let svw = @computed.compute_inline("width: 100svw", ctx)
  inspect(svw.width, content="Length(1000)")
  let svh = @computed.compute_inline("height: 50svh", ctx)
  inspect(svh.height, content="Length(400)")
  let lvw = @computed.compute_inline("width: 100lvw", ctx)
  inspect(lvw.width, content="Length(1000)")
  let lvh = @computed.compute_inline("height: 50lvh", ctx)
  inspect(lvh.height, content="Length(400)")
}

///|
test "compute_inline - viewport units vmin/vmax" {
  let ctx = @computed.ComputeContext::with_viewport(800.0, 1200.0)
  // vmin = min(800,1200)/100 * n = 8 * n; 50vmin = 400
  let vmin = @computed.compute_inline("width: 50vmin", ctx)
  inspect(vmin.width, content="Length(400)")
  // vmax = max(800,1200)/100 * n = 12 * n; 50vmax = 600
  let vmax = @computed.compute_inline("width: 50vmax", ctx)
  inspect(vmax.width, content="Length(600)")
}

///|
test "compute_inline - viewport units vmin/vmax with equal dims" {
  let ctx = @computed.ComputeContext::with_viewport(1000.0, 1000.0)
  let vmin = @computed.compute_inline("width: 50vmin", ctx)
  inspect(vmin.width, content="Length(500)")
  let vmax = @computed.compute_inline("width: 50vmax", ctx)
  inspect(vmax.width, content="Length(500)")
}

///|
test "compute_inline - color-scheme: light/dark/light dark" {
  let ctx = @computed.ComputeContext::new()
  let s_light = @computed.compute_inline("color-scheme: light", ctx)
  let _ = s_light
  let s_dark = @computed.compute_inline("color-scheme: dark", ctx)
  let _ = s_dark
  let s_both = @computed.compute_inline("color-scheme: light dark", ctx)
  let _ = s_both
  inspect(true, content="true")
}

///|
test "compute_inline - color-scheme with var() fallback" {
  let ctx = @computed.ComputeContext::new()
  let s = @computed.compute_inline("color-scheme: var(--scheme, dark)", ctx)
  let _ = s
  inspect(true, content="true")
}

///|
test "ch_unit_ratio - Ahem font uses 1.0" {
  // ch unit resolves against font's avg width; Ahem font is exactly 1em width.
  let parent : @style.Style = {
    ..@style.Style::default(),
    font_family: "Ahem",
    font_size: 16.0,
  }
  let ctx = @computed.ComputeContext::with_parent(parent)
  // 5ch should be 5 * 16 * 1.0 = 80
  let s = @computed.compute_inline("width: 5ch", ctx)
  inspect(s.width, content="Length(80)")
}

///|
test "ch_unit_ratio - non-Ahem font uses 0.5" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    font_family: "Arial",
    font_size: 16.0,
  }
  let ctx = @computed.ComputeContext::with_parent(parent)
  // 5ch should be 5 * 16 * 0.5 = 40
  let s = @computed.compute_inline("width: 5ch", ctx)
  inspect(s.width, content="Length(40)")
}

///|
test "RevertLayer keyword falls back to initial" {
  let ctx = @computed.ComputeContext::new()
  let decl : @cascade.Declaration = {
    property: "position",
    value: @cascade.RevertLayer,
    origin: @cascade.Author,
    importance: @cascade.Normal,
    specificity: { a: 0, b: 0, c: 0 },
    source_order: 0,
  }
  let s = @computed.compute(@cascade.cascade([decl]), ctx)
  inspect(s.position, content="Relative")
}
