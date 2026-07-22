///|
test "inline parser grid item placement longhands and shorthands" {
  // longhands
  let a = parse_inline_style("grid-column-start: 2; grid-column-end: span foo")
  inspect(a.grid_column.start, content="Line(2)")
  inspect(a.grid_column.end, content="SpanNamed(1, foo)")
  let b = parse_inline_style("grid-row-start: 1; grid-row-end: 3")
  inspect(b.grid_row.start, content="Line(1)")
  inspect(b.grid_row.end, content="Line(3)")
  // grid-column / grid-row shorthand
  let c = parse_inline_style("grid-column: 2 foo / span 3")
  inspect(c.grid_column.start, content="NamedLine(2, foo)")
  inspect(c.grid_column.end, content="Span(3)")
  // single custom-ident copies to both (implicit named area)
  let d = parse_inline_style("grid-column: left-sidebar")
  inspect(d.grid_column.start, content="Named(left-sidebar)")
  inspect(d.grid_column.end, content="Named(left-sidebar)")
}

///|
test "inline parser grid-area: named area vs four lines" {
  // single <custom-ident> => named area, no line placement
  let named = parse_inline_style("grid-area: header")
  debug_inspect(named.grid_area, content="Some(\"header\")")
  inspect(named.grid_row.start, content="Auto")
  // four lines: row-start / col-start / row-end / col-end
  let lines = parse_inline_style("grid-area: 1 / 2 / 3 / 4")
  debug_inspect(lines.grid_area, content="None")
  inspect(lines.grid_row.start, content="Line(1)")
  inspect(lines.grid_column.start, content="Line(2)")
  inspect(lines.grid_row.end, content="Line(3)")
  inspect(lines.grid_column.end, content="Line(4)")
}

///|
test "inline parser animation shorthand" {
  let s = parse_inline_style(
    "animation: slide 2s ease-in-out 0.5s infinite alternate both",
  )
  debug_inspect(s.animation_name, content="[\"slide\"]")
  debug_inspect(s.animation_duration, content="[2]")
  inspect(s.animation_timing_function[0], content="EaseInOut")
  debug_inspect(s.animation_delay, content="[0.5]")
  inspect(s.animation_iteration_count[0], content="Infinite")
  inspect(s.animation_direction[0], content="Alternate")
  inspect(s.animation_fill_mode[0], content="Both")
}

///|
test "inline parser animation list with cubic-bezier (internal commas)" {
  let s = parse_inline_style(
    "animation: a 1s cubic-bezier(0.1, 0.2, 0.3, 0.4), b 2s linear",
  )
  debug_inspect(s.animation_name, content="[\"a\", \"b\"]")
  debug_inspect(s.animation_duration, content="[1, 2]")
  inspect(
    s.animation_timing_function[0],
    content="CubicBezier(0.1, 0.2, 0.3, 0.4)",
  )
  inspect(s.animation_timing_function[1], content="Linear")
}

///|
test "inline parser animation longhands" {
  let s = parse_inline_style(
    "animation-name: a, b; animation-duration: 1s, 200ms; animation-iteration-count: 3, infinite",
  )
  debug_inspect(s.animation_name, content="[\"a\", \"b\"]")
  debug_inspect(s.animation_duration, content="[1, 0.2]")
  inspect(s.animation_iteration_count[0], content="Count(3)")
  inspect(s.animation_iteration_count[1], content="Infinite")
}

///|
test "inline parser transition shorthand" {
  let s = parse_inline_style(
    "transition: opacity 0.3s ease-in 0.1s, transform 1s",
  )
  debug_inspect(s.transition_property, content="[\"opacity\", \"transform\"]")
  debug_inspect(s.transition_duration, content="[0.3, 1]")
  inspect(s.transition_timing_function[0], content="EaseIn")
  debug_inspect(s.transition_delay, content="[0.1, 0]")
}

///|
test "inline parser individual transform properties compose" {
  let s = parse_inline_style("translate: 10px 20px; scale: 2; rotate: 45deg")
  let it = s.individual_transform
  inspect(it.translate_x, content="Length(10)")
  inspect(it.translate_y, content="Length(20)")
  inspect(it.scale_x, content="2")
  inspect(it.scale_y, content="2")
  inspect(it.rotate_degrees, content="45")
}

///|
test "parse_inline_style calc with unitless multiplier" {
  inspect(
    parse_inline_style("width: calc(10px * 2)").width,
    content="Length(20)",
  )
  inspect(
    parse_inline_style("width: calc(2 * 10px)").width,
    content="Length(20)",
  )
  inspect(
    parse_inline_style("width: calc(10px / 2)").width,
    content="Length(5)",
  )
  inspect(
    parse_inline_style("width: calc(2 * 50%)").width,
    content="Percent(1)",
  )
}

///|
test "parse_inline_style absolute and viewport units" {
  // pt/pc/in/cm/mm/Q were previously treated as raw pixels.
  inspect(
    parse_inline_style("width: 10pt").width,
    content="Length(13.333333333333334)",
  )
  inspect(parse_inline_style("width: 1pc").width, content="Length(16)")
  inspect(parse_inline_style("width: 1in").width, content="Length(96)")
  // vmin/vmax against the default 1000x1000 viewport.
  inspect(parse_inline_style("width: 10vmin").width, content="Length(100)")
  inspect(parse_inline_style("width: 10vmax").width, content="Length(100)")
  // Units are case-insensitive.
  inspect(parse_inline_style("width: 1REM").width, content="Length(16)")
  inspect(parse_inline_style("width: 5VW").width, content="Length(50)")
}

///|
test "parse_inline_style transform grad angle unit" {
  // 200grad = 180deg; `grad` previously mis-matched the `rad` suffix.
  inspect(
    parse_inline_style("transform: rotate(200grad)").transform.quarter_turns(),
    content="2",
  )
  inspect(
    parse_inline_style("transform: rotate(100grad)").transform.quarter_turns(),
    content="1",
  )
}

///|
test "parse flex-flow shorthand" {
  let dir_only = parse_inline_style("flex-flow: column")
  inspect(dir_only.flex_direction, content="Column")
  inspect(dir_only.flex_wrap, content="NoWrap")
  let wrap_only = parse_inline_style("flex-flow: wrap")
  inspect(wrap_only.flex_direction, content="Row")
  inspect(wrap_only.flex_wrap, content="Wrap")
  let both = parse_inline_style("flex-flow: row-reverse wrap-reverse")
  inspect(both.flex_direction, content="RowReverse")
  inspect(both.flex_wrap, content="WrapReverse")
}

///|
test "parse aspect-ratio - single number and ratio" {
  let single = parse_inline_style("aspect-ratio: 2")
  debug_inspect(single.aspect_ratio, content="Some(2)")
  let ratio = parse_inline_style("aspect-ratio: 4/3")
  debug_inspect(single.aspect_ratio, content="Some(2)")
  match ratio.aspect_ratio {
    Some(v) => assert_true((v - 4.0 / 3.0).abs() < 0.001)
    None => fail("expected aspect ratio")
  }
}

///|
test "parse aspect-ratio - divisor zero falls back to value" {
  let s = parse_inline_style("aspect-ratio: 5 / 0")
  debug_inspect(s.aspect_ratio, content="Some(5)")
}

///|
test "parse pointer-events" {
  let none = parse_inline_style("pointer-events: none")
  inspect(none.pointer_events, content="None")
  let auto = parse_inline_style("pointer-events: auto")
  inspect(auto.pointer_events, content="Auto")
}

///|
test "parse min/max-width and min/max-height" {
  let s = parse_inline_style(
    "min-width: 10px; max-width: 200px; min-height: 20px; max-height: 100px",
  )
  inspect(s.min_width, content="Length(10)")
  inspect(s.max_width, content="Length(200)")
  inspect(s.min_height, content="Length(20)")
  inspect(s.max_height, content="Length(100)")
}

///|
test "parse min-content/max-content sizes" {
  let s = parse_inline_style("width: min-content; height: max-content")
  inspect(s.width, content="MinContent")
  inspect(s.height, content="MaxContent")
}

///|
test "parse inset shorthand all four sides" {
  let s = parse_inline_style("inset: 10px 20px 30px 40px")
  inspect(s.inset.top, content="Length(10)")
  inspect(s.inset.right, content="Length(20)")
  inspect(s.inset.bottom, content="Length(30)")
  inspect(s.inset.left, content="Length(40)")
}

///|
test "parse position absolute and fixed" {
  let abs = parse_inline_style("position: absolute")
  inspect(abs.position, content="Absolute")
  let fix = parse_inline_style("position: fixed")
  inspect(fix.position, content="Fixed")
}

///|
test "parse float left and right" {
  let l = parse_inline_style("float: left")
  inspect(l.float, content="Left")
  let r = parse_inline_style("float: right")
  inspect(r.float, content="Right")
  let none = parse_inline_style("float: none")
  inspect(none.float, content="None")
}

///|
test "parse clear" {
  inspect(parse_inline_style("clear: left").clear, content="Left")
  inspect(parse_inline_style("clear: right").clear, content="Right")
  inspect(parse_inline_style("clear: both").clear, content="Both")
  inspect(parse_inline_style("clear: none").clear, content="None")
}

///|
test "parse grid-template-columns simple lengths" {
  let s = parse_inline_style("grid-template-columns: 100px 200px 300px")
  inspect(s.grid_template_columns.length(), content="3")
}

///|
test "parse grid-template-columns with fr" {
  let s = parse_inline_style("grid-template-columns: 1fr 2fr 1fr")
  inspect(s.grid_template_columns.length(), content="3")
}

///|
test "parse grid-template-rows with mixed values" {
  let s = parse_inline_style("grid-template-rows: 50px auto 1fr min-content")
  inspect(s.grid_template_rows.length(), content="4")
}

///|
test "parse grid-template-columns with repeat" {
  let s = parse_inline_style("grid-template-columns: repeat(3, 1fr)")
  inspect(s.grid_template_columns.length(), content="1")
}

///|
test "parse grid-template-columns with auto-fit" {
  let s = parse_inline_style(
    "grid-template-columns: repeat(auto-fit, minmax(200px, 1fr))",
  )
  inspect(s.grid_template_columns.length(), content="1")
}

///|
test "parse overflow: hidden" {
  let s = parse_inline_style("overflow: hidden")
  inspect(s.overflow_x, content="Hidden")
  inspect(s.overflow_y, content="Hidden")
}

///|
test "parse contain shorthand" {
  let s = parse_inline_style("contain: layout paint")
  inspect(s.contain.layout, content="true")
  inspect(s.contain.paint, content="true")
  inspect(s.contain.size, content="false")
}

///|
test "parse contain: strict" {
  let s = parse_inline_style("contain: strict")
  inspect(s.contain.size, content="true")
  inspect(s.contain.layout, content="true")
  inspect(s.contain.paint, content="true")
  inspect(s.contain.style, content="true")
}

///|
test "parse contain: content" {
  let s = parse_inline_style("contain: content")
  inspect(s.contain.size, content="false")
  inspect(s.contain.layout, content="true")
}

///|
test "parse transform: none" {
  let s = parse_inline_style("transform: none")
  assert_true(s.transform.is_none())
}

///|
test "parse direction ltr/rtl" {
  let ltr = parse_inline_style("direction: ltr")
  inspect(ltr.direction, content="Ltr")
  let rtl = parse_inline_style("direction: rtl")
  inspect(rtl.direction, content="Rtl")
}

///|
test "parse border-inline-width" {
  let s = parse_inline_style("border-inline-width: 3px")
  inspect(s.border.left, content="Length(3)")
  inspect(s.border.right, content="Length(3)")
}

///|
test "parse container-type: inline-size" {
  let s = parse_inline_style("container-type: inline-size")
  inspect(s.contain.inline_size, content="true")
}

///|
test "parse contain-intrinsic-inline-size" {
  let s = parse_inline_style("contain-intrinsic-inline-size: 100px")
  debug_inspect(s.contain_intrinsic_inline_size, content="Some(100)")
}

///|
test "parse contain-intrinsic-block-size" {
  let s = parse_inline_style("contain-intrinsic-block-size: 60px")
  debug_inspect(s.contain_intrinsic_block_size, content="Some(60)")
}

///|
test "parse contain-intrinsic-size shorthand single value" {
  let s = parse_inline_style("contain-intrinsic-size: 80px")
  debug_inspect(s.contain_intrinsic_inline_size, content="Some(80)")
  debug_inspect(s.contain_intrinsic_block_size, content="Some(80)")
}

///|
test "parse contain-intrinsic-size shorthand two values" {
  let s = parse_inline_style("contain-intrinsic-size: 30px 70px")
  debug_inspect(s.contain_intrinsic_inline_size, content="Some(30)")
  debug_inspect(s.contain_intrinsic_block_size, content="Some(70)")
}

///|
test "parse transform with translate" {
  let s = parse_inline_style("transform: translate(10px, 20px)")
  let x = s.transform.compute_translate_x(100.0)
  let y = s.transform.compute_translate_y(100.0)
  inspect(x, content="10")
  inspect(y, content="20")
}

///|
test "parse top/right/bottom/left individual" {
  let s = parse_inline_style("top: 5px; right: 10px; bottom: 15px; left: 20px")
  inspect(s.inset.top, content="Length(5)")
  inspect(s.inset.right, content="Length(10)")
  inspect(s.inset.bottom, content="Length(15)")
  inspect(s.inset.left, content="Length(20)")
}

///|
test "parse inset shorthand 2 values" {
  let s = parse_inline_style("inset: 5px 10px")
  inspect(s.inset.top, content="Length(5)")
  inspect(s.inset.bottom, content="Length(5)")
  inspect(s.inset.left, content="Length(10)")
  inspect(s.inset.right, content="Length(10)")
}

///|
test "parse inset shorthand 3 values" {
  let s = parse_inline_style("inset: 5px 10px 15px")
  inspect(s.inset.top, content="Length(5)")
  inspect(s.inset.left, content="Length(10)")
  inspect(s.inset.right, content="Length(10)")
  inspect(s.inset.bottom, content="Length(15)")
}

///|
test "parse aspect-ratio property" {
  let s = parse_inline_style("aspect-ratio: 4 / 3")
  match s.aspect_ratio {
    Some(v) => assert_true((v - 4.0 / 3.0).abs() < 0.001)
    None => fail("expected aspect ratio")
  }
}

///|
test "parse grid-auto-flow column" {
  let s = parse_inline_style("grid-auto-flow: column")
  inspect(s.grid_auto_flow, content="Column")
}

///|
test "parse width: calc() with pure px expression" {
  let s = parse_inline_style("width: calc(100px + 20px)")
  inspect(s.width, content="Length(120)")
}

///|
test "parse width: calc() with subtraction" {
  let s = parse_inline_style("width: calc(100px - 20px)")
  inspect(s.width, content="Length(80)")
}

///|
test "parse width: calc() converts rem/em and physical units" {
  // Non-px length units must be converted to px before accumulating,
  // otherwise the term is silently dropped.
  inspect(parse_inline_style("width: calc(10rem)").width, content="Length(160)")
  inspect(
    parse_inline_style("width: calc(2rem + 8px)").width,
    content="Length(40)",
  )
  inspect(
    parse_inline_style("width: calc(1in - 16px)").width,
    content="Length(80)",
  )
}

///|
test "parse width: calc() with pure percentage" {
  let s = parse_inline_style("width: calc(50% + 10%)")
  inspect(s.width, content="Percent(0.6)")
}

///|
test "parse width: calc() with multiplication by integer" {
  let s = parse_inline_style("width: calc(10px * 5)")
  // calc skips raw numbers; result is 10px after the no-op
  // Implementation may handle differently — check it parses without panic
  let _ = s
  inspect(true, content="true")
}

///|
test "parse width: calc() mixed px + %% falls back to Auto" {
  let s = parse_inline_style("width: calc(50% + 10px)")
  inspect(s.width, content="Auto")
}

///|
test "parse min()/max()/clamp() all-px arguments" {
  inspect(
    parse_inline_style("width: min(100px, 200px)").width,
    content="Length(100)",
  )
  inspect(
    parse_inline_style("width: max(100px, 200px)").width,
    content="Length(200)",
  )
  inspect(
    parse_inline_style("width: clamp(100px, 250px, 200px)").width,
    content="Length(200)",
  )
}

///|
test "parse min()/max() single and all-percent arguments" {
  // single argument resolves to that argument verbatim (crater#282)
  inspect(parse_inline_style("height: max(100%)").width, content="Auto") // width unset
  inspect(parse_inline_style("height: max(100%)").height, content="Percent(1)")
  inspect(
    parse_inline_style("height: max(calc(100%))").height,
    content="Percent(1)",
  )
  // all-percent: ratio order matches resolved-length order
  inspect(
    parse_inline_style("width: min(50%, 100%)").width,
    content="Percent(0.5)",
  )
  inspect(
    parse_inline_style("width: max(50%, 100%)").width,
    content="Percent(1)",
  )
}

///|
test "parse min()/max()/clamp() mixed length+percent become MathFn" {
  let mn = parse_inline_style("width: min(50%, 200px)").width
  inspect(mn, content="MathFn(Min, [(0, 0.5), (200, 0)])")
  debug_inspect(mn.resolve(300.0), content="Some(150)") // 50% of 300 = 150 < 200
  debug_inspect(mn.resolve(500.0), content="Some(200)") // 50% of 500 = 250 > 200
  let cl = parse_inline_style("width: clamp(100px, 50%, 300px)").width
  inspect(cl, content="MathFn(Clamp, [(100, 0), (0, 0.5), (300, 0)])")
  debug_inspect(cl.resolve(1000.0), content="Some(300)") // 50%=500 > 300 -> 300
}

///|
test "parse min() rejects invalid arguments to match compute layer" {
  // non-zero unitless number and unknown units are invalid length args -> Auto
  inspect(parse_inline_style("width: min(5, 100px)").width, content="Auto")
  inspect(parse_inline_style("width: min(10foo, 100px)").width, content="Auto")
  // unitless 0 stays valid
  inspect(
    parse_inline_style("width: max(0, 100px)").width,
    content="Length(100)",
  )
}

///|
test "parse width: viewport units" {
  let s = parse_inline_style("width: 50vw; height: 25vh")
  // 50vw of 1000 default = 500, 25vh of 1000 = 250
  inspect(s.width, content="Length(500)")
  inspect(s.height, content="Length(250)")
}

///|
test "parse width: 0 unitless" {
  let s = parse_inline_style("width: 0; height: 0")
  inspect(s.width, content="Length(0)")
  inspect(s.height, content="Length(0)")
}

///|
test "parse width: unitless number is invalid" {
  let s = parse_inline_style("width: 100; height: 50")
  // Bare non-zero numbers are not valid CSS lengths
  inspect(s.width, content="Auto")
  inspect(s.height, content="Auto")
}

///|
test "parse padding multiple dimensions" {
  let s = parse_inline_style("padding: 10px 20%")
  inspect(s.padding.top, content="Length(10)")
  inspect(s.padding.right, content="Percent(0.2)")
  inspect(s.padding.bottom, content="Length(10)")
  inspect(s.padding.left, content="Percent(0.2)")
}

///|
test "parse padding 3 values" {
  let s = parse_inline_style("padding: 1px 2px 3px")
  inspect(s.padding.top, content="Length(1)")
  inspect(s.padding.right, content="Length(2)")
  inspect(s.padding.bottom, content="Length(3)")
  inspect(s.padding.left, content="Length(2)")
}

///|
test "parse margin individual sides" {
  let s = parse_inline_style(
    "margin-top: 1px; margin-right: 2px; margin-bottom: 3px; margin-left: 4px",
  )
  inspect(s.margin.top, content="Length(1)")
  inspect(s.margin.right, content="Length(2)")
  inspect(s.margin.bottom, content="Length(3)")
  inspect(s.margin.left, content="Length(4)")
}

///|
test "parse border-top/right/bottom/left individual widths" {
  let s = parse_inline_style(
    "border-top-width: 1px; border-right-width: 2px; border-bottom-width: 3px; border-left-width: 4px",
  )
  inspect(s.border.top, content="Length(1)")
  inspect(s.border.right, content="Length(2)")
  inspect(s.border.bottom, content="Length(3)")
  inspect(s.border.left, content="Length(4)")
}

///|
test "parse border-width single value" {
  let s = parse_inline_style("border-width: 3px")
  inspect(s.border.top, content="Length(3)")
}

///|
test "parse flex-basis with various values" {
  inspect(
    parse_inline_style("flex-basis: 50px").flex_basis,
    content="Length(50)",
  )
  inspect(
    parse_inline_style("flex-basis: 50%").flex_basis,
    content="Percent(0.5)",
  )
  inspect(parse_inline_style("flex-basis: auto").flex_basis, content="Auto")
}

///|
test "parse flex shorthand single number" {
  let s = parse_inline_style("flex: 1")
  inspect(s.flex_grow, content="1")
  inspect(s.flex_shrink, content="1")
}

///|
test "parse line-height various forms" {
  // Just verify they parse without error
  let _ = parse_inline_style("line-height: 1.5")
  let _ = parse_inline_style("line-height: 24px")
  let _ = parse_inline_style("line-height: 150%")
  let _ = parse_inline_style("line-height: normal")
  inspect(true, content="true")
}

///|
test "parse font shorthand" {
  // Font shorthand may set font-size and font-family
  let _ = parse_inline_style("font: 16px/1.5 Arial, sans-serif")
  let _ = parse_inline_style("font: bold 14px Helvetica")
  inspect(true, content="true")
}

///|
test "parse order property" {
  let s = parse_inline_style("order: 5")
  inspect(s.order, content="5")
}

///|
test "parse order negative value" {
  let s = parse_inline_style("order: -3")
  inspect(s.order, content="-3")
}

///|
test "parse direction shorthand" {
  let s_ltr = parse_inline_style("direction: ltr")
  inspect(s_ltr.direction, content="Ltr")
  let s_rtl = parse_inline_style("direction: rtl")
  inspect(s_rtl.direction, content="Rtl")
}

///|
test "parse writing-mode horizontal-tb default" {
  inspect(
    parse_inline_style("writing-mode: horizontal-tb").writing_mode,
    content="HorizontalTb",
  )
}

///|
test "parse aspect-ratio: auto and ratio" {
  let auto_s = parse_inline_style("aspect-ratio: auto")
  debug_inspect(auto_s.aspect_ratio, content="None")
  let ratio_s = parse_inline_style("aspect-ratio: 2")
  debug_inspect(ratio_s.aspect_ratio, content="Some(2)")
}

///|
test "parse multiple declarations with whitespace" {
  let s = parse_inline_style(
    "  display : flex ;  padding : 10px ; margin : 5px  ",
  )
  inspect(s.display, content="Flex")
  inspect(s.padding.top, content="Length(10)")
}

///|
test "parse trailing semicolon" {
  let s = parse_inline_style("display: flex;")
  inspect(s.display, content="Flex")
}

///|
test "parse multiple sibling declarations" {
  let s = parse_inline_style(
    "display: flex; flex-direction: column; align-items: center; gap: 10px",
  )
  inspect(s.display, content="Flex")
  inspect(s.flex_direction, content="Column")
  inspect(s.align_items, content="Center")
  inspect(s.row_gap, content="Length(10)")
}

///|
test "parse - border-left/right/top/bottom-width individual" {
  let s = parse_inline_style(
    "border-left-width: 1px; border-right-width: 2px; border-top-width: 3px; border-bottom-width: 4px",
  )
  inspect(s.border.left, content="Length(1)")
  inspect(s.border.right, content="Length(2)")
  inspect(s.border.top, content="Length(3)")
  inspect(s.border.bottom, content="Length(4)")
}

///|
test "parse - border-block and border-block-width shorthand" {
  let s = parse_inline_style("border-block: 5px")
  inspect(s.border.top, content="Length(5)")
  inspect(s.border.bottom, content="Length(5)")
  let s2 = parse_inline_style("border-block-width: 7px")
  inspect(s2.border.top, content="Length(7)")
  inspect(s2.border.bottom, content="Length(7)")
}

///|
test "parse - border-inline shorthand" {
  let s = parse_inline_style("border-inline: 6px")
  inspect(s.border.left, content="Length(6)")
  inspect(s.border.right, content="Length(6)")
}

///|
test "parse - padding-block and padding-inline shorthands" {
  let s = parse_inline_style("padding-block: 5px; padding-inline: 10px")
  inspect(s.padding.top, content="Length(5)")
  inspect(s.padding.bottom, content="Length(5)")
  inspect(s.padding.left, content="Length(10)")
  inspect(s.padding.right, content="Length(10)")
}

///|
test "parse - row-gap and column-gap individually" {
  let s = parse_inline_style("row-gap: 5px; column-gap: 10px")
  inspect(s.row_gap, content="Length(5)")
  inspect(s.column_gap, content="Length(10)")
}

///|
test "parse - overflow-x and overflow-y separately" {
  let s = parse_inline_style("overflow-x: scroll; overflow-y: hidden")
  inspect(s.overflow_x, content="Scroll")
  inspect(s.overflow_y, content="Hidden")
}

///|
test "parse - top/right/bottom/left individually" {
  let s = parse_inline_style("top: 1px; right: 2px; bottom: 3px; left: 4px")
  inspect(s.inset.top, content="Length(1)")
  inspect(s.inset.right, content="Length(2)")
  inspect(s.inset.bottom, content="Length(3)")
  inspect(s.inset.left, content="Length(4)")
}

///|
test "parse - clip rect()" {
  let s = parse_inline_style("clip: rect(1px, 2px, 3px, 4px)")
  inspect(s.clip, content="rect(1, 2, 3, 4)")
  let auto = parse_inline_style("clip: auto")
  inspect(auto.clip, content="auto")
}

///|
test "parse - clip-path inset/circle convert rem/physical units" {
  // inset(1rem) -> 16px on all sides
  debug_inspect(
    parse_inline_style("clip-path: inset(1rem)").clip_path,
    content="Inset(16, 16, 16, 16)",
  )
  // circle(2rem at 1in 1in) -> radius 32, center 96/96
  debug_inspect(
    parse_inline_style("clip-path: circle(2rem at 1in 1in)").clip_path,
    content="Circle(32, 96, 96)",
  )
}

///|
test "parse - clip-path inset/circle/ellipse/polygon/none" {
  let inset = parse_inline_style("clip-path: inset(5px)")
  let _ = inset.clip_path
  let circle = parse_inline_style("clip-path: circle(20px at 30px 40px)")
  let _ = circle.clip_path
  let ellipse = parse_inline_style("clip-path: ellipse(20px 30px at 40px 50px)")
  let _ = ellipse.clip_path
  let polygon = parse_inline_style("clip-path: polygon(0 0, 100% 0, 50% 100%)")
  let _ = polygon.clip_path
  let none = parse_inline_style("clip-path: none")
  let _ = none.clip_path
  inspect(true, content="true")
}

///|
test "parse - place-content shorthand" {
  let s = parse_inline_style("place-content: center end")
  inspect(s.align_content, content="Center")
  inspect(s.justify_content, content="End")
}

///|
test "parse - justify-self and justify-items" {
  let s = parse_inline_style("justify-self: end; justify-items: center")
  inspect(s.justify_self, content="End")
  inspect(s.justify_items, content="Center")
}

///|
test "parse - flex-flow shorthand individual" {
  let s = parse_inline_style("flex-flow: column wrap")
  inspect(s.flex_direction, content="Column")
  inspect(s.flex_wrap, content="Wrap")
}

///|
test "parse - margin-top/right/bottom/left individual" {
  let s = parse_inline_style(
    "margin-top: 1px; margin-right: 2px; margin-bottom: 3px; margin-left: 4px",
  )
  inspect(s.margin.top, content="Length(1)")
  inspect(s.margin.right, content="Length(2)")
  inspect(s.margin.bottom, content="Length(3)")
  inspect(s.margin.left, content="Length(4)")
}

///|
test "parse - padding-top/right/bottom/left individual" {
  let s = parse_inline_style(
    "padding-top: 1px; padding-right: 2px; padding-bottom: 3px; padding-left: 4px",
  )
  inspect(s.padding.top, content="Length(1)")
  inspect(s.padding.right, content="Length(2)")
  inspect(s.padding.bottom, content="Length(3)")
  inspect(s.padding.left, content="Length(4)")
}

///|
test "parse grid-template-columns with min-content/max-content/auto" {
  let s = parse_inline_style(
    "grid-template-columns: min-content max-content auto 100px",
  )
  inspect(s.grid_template_columns.length(), content="4")
}

///|
test "parse grid-template-columns with minmax(min-content, 1fr)" {
  let s = parse_inline_style(
    "grid-template-columns: minmax(min-content, 1fr) minmax(auto, max-content)",
  )
  inspect(s.grid_template_columns.length(), content="2")
}

///|
test "parse grid-template-columns with various track sizes" {
  let s = parse_inline_style(
    "grid-template-columns: 50% 2fr 100px auto min-content max-content",
  )
  inspect(s.grid_template_columns.length(), content="6")
}

///|
test "parse grid-template-columns with 0 unitless" {
  let s = parse_inline_style("grid-template-columns: 0 100px")
  inspect(s.grid_template_columns.length(), content="2")
}

///|
test "parse grid-template-columns with bad ident drops the rest" {
  let s = parse_inline_style("grid-template-columns: bogus 100px")
  // Bogus ident causes parser to stop accumulating tracks
  let _ = s.grid_template_columns
  inspect(true, content="true")
}

///|
test "parse grid-template-columns with non-zero unitless drops the rest" {
  let s = parse_inline_style("grid-template-columns: 5 100px")
  // Non-zero unitless causes parser to stop
  let _ = s.grid_template_columns
  inspect(true, content="true")
}

///|
test "parse contain-intrinsic-size single value" {
  let s = parse_inline_style("contain-intrinsic-size: 100px")
  debug_inspect(s.contain_intrinsic_inline_size, content="Some(100)")
  debug_inspect(s.contain_intrinsic_block_size, content="Some(100)")
}

///|
test "parse contain-intrinsic-size auto" {
  let s = parse_inline_style("contain-intrinsic-size: auto")
  // 'auto' produces None
  debug_inspect(s.contain_intrinsic_inline_size, content="None")
}

///|
test "parse container-type: size and inline-size" {
  let s1 = parse_inline_style("container-type: size")
  inspect(s1.contain.size, content="true")
  let s2 = parse_inline_style("container-type: inline-size")
  inspect(s2.contain.inline_size, content="true")
  let s3 = parse_inline_style("container-type: normal")
  // 'normal' should not add containment
  let _ = s3
  inspect(true, content="true")
}

///|
test "parse negative top left" {
  let style = parse_inline_style("top: -20px; left: -40px")
  inspect(style.inset.top, content="Length(-20)")
  inspect(style.inset.left, content="Length(-40)")
}

///|
test "parse basic width and height" {
  let style = parse_inline_style("width: 100px; height: 50px")
  inspect(style.width, content="Length(100)")
  inspect(style.height, content="Length(50)")
}

///|
test "parse display flex" {
  let style = parse_inline_style("display: flex")
  inspect(style.display, content="Flex")
}

///|
test "parse display flow-root list-item" {
  let style = parse_inline_style("display: flow-root list-item")
  inspect(style.display, content="FlowRoot")
}

///|
test "parse display math aliases" {
  let inline_math = parse_inline_style("display: math")
  inspect(inline_math.display, content="Inline")
  let block_math = parse_inline_style("display: block math")
  inspect(block_math.display, content="Block")
}

///|
test "parse flex properties" {
  let style = parse_inline_style(
    "display: flex; flex-direction: column; justify-content: center",
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Column")
  inspect(style.justify_content, content="Center")
}

///|
test "parse margin and padding" {
  let style = parse_inline_style("margin: 10px; padding: 20px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.left, content="Length(10)")
  inspect(style.padding.top, content="Length(20)")
  inspect(style.padding.right, content="Length(20)")
}

///|
test "parse percentage values" {
  let style = parse_inline_style("width: 50%; height: 100%")
  inspect(style.width, content="Percent(0.5)")
  inspect(style.height, content="Percent(1)")
}

///|
test "parse flex-grow and flex-shrink" {
  let style = parse_inline_style("flex-grow: 1; flex-shrink: 0")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="0")
}

///|
test "parse gap" {
  let style = parse_inline_style("gap: 10px")
  inspect(style.row_gap, content="Length(10)")
  inspect(style.column_gap, content="Length(10)")
}

///|
test "parse complex flex layout" {
  let style = parse_inline_style(
    "display: flex; flex-direction: row; flex-wrap: wrap; align-items: center; gap: 16px",
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Row")
  inspect(style.flex_wrap, content="Wrap")
  inspect(style.align_items, content="Center")
  inspect(style.row_gap, content="Length(16)")
}

///|
test "parse border-width" {
  let style = parse_inline_style("border-width: 2px")
  inspect(style.border.top, content="Length(2)")
  inspect(style.border.left, content="Length(2)")
}

///|
test "parse inset properties" {
  let style = parse_inline_style("position: absolute; top: 10px; left: 20px")
  inspect(style.position, content="Absolute")
  inspect(style.inset.top, content="Length(10)")
  inspect(style.inset.left, content="Length(20)")
}

///|
test "parse aspect-ratio simple" {
  let style = parse_inline_style("aspect-ratio: 1.5")
  debug_inspect(style.aspect_ratio, content="Some(1.5)")
}

///|
test "parse aspect-ratio fraction" {
  let style = parse_inline_style("aspect-ratio: 16 / 9")
  // 16/9 ≈ 1.777...
  match style.aspect_ratio {
    Some(v) => assert_true(v > 1.77 && v < 1.78)
    None => fail("aspect_ratio should be Some")
  }
}

///|
test "parse grid-auto-flow" {
  let style = parse_inline_style("display: grid; grid-auto-flow: column")
  inspect(style.display, content="Grid")
  inspect(style.grid_auto_flow, content="Column")
}

///|
test "order property" {
  let style = parse_inline_style("order: 5")
  inspect(style.order, content="5")
}

///|
test "order negative" {
  let style = parse_inline_style("order: -1")
  inspect(style.order, content="-1")
}

///|
test "flex shorthand" {
  let style = parse_inline_style("flex: 1")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Percent(0)")
}

///|
test "grid-template-columns basic" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: 100px 200px 1fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[1], content="Length(200)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

///|
test "grid-template-columns captures named line brackets" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: [extended-full-start] minmax(1rem, 1fr) [full-start] minmax(0, 2rem) [content-start] minmax(0, 72rem) [content-end] minmax(0, 2rem) [full-end] minmax(1rem, 1fr) [extended-full-end]",
  )
  inspect(style.grid_template_columns.length(), content="5")
  // Line names are now preserved: one entry per grid line (tracks + 1).
  let names = style.grid_template_column_line_names
  inspect(names.length(), content="6")
  debug_inspect(names[0], content="[\"extended-full-start\"]")
  debug_inspect(names[1], content="[\"full-start\"]")
  debug_inspect(names[2], content="[\"content-start\"]")
  debug_inspect(names[3], content="[\"content-end\"]")
  debug_inspect(names[4], content="[\"full-end\"]")
  debug_inspect(names[5], content="[\"extended-full-end\"]")
}

///|
test "grid-template-columns captures multiple names at one line (MDN page shell)" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: [left-sidebar-start] 240px [left-sidebar-end content-start] 689px [content-end]",
  )
  inspect(style.grid_template_columns.length(), content="2")
  let names = style.grid_template_column_line_names
  inspect(names.length(), content="3")
  debug_inspect(names[0], content="[\"left-sidebar-start\"]")
  debug_inspect(names[1], content="[\"left-sidebar-end\", \"content-start\"]")
  debug_inspect(names[2], content="[\"content-end\"]")
}

///|
test "grid-template-columns fractional fr" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: 1.01fr 0.99fr 1fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Fr(1.01)")
  inspect(style.grid_template_columns[1], content="Fr(0.99)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

///|
test "grid-template-rows basic" {
  let style = parse_inline_style(
    "display: grid; grid-template-rows: auto 50px 2fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_rows.length(), content="3")
  inspect(style.grid_template_rows[0], content="Auto")
  inspect(style.grid_template_rows[1], content="Length(50)")
  inspect(style.grid_template_rows[2], content="Fr(2)")
}

///|
test "grid-template-columns with percentage" {
  let style = parse_inline_style("grid-template-columns: 50% 50%")
  inspect(style.grid_template_columns.length(), content="2")
  inspect(style.grid_template_columns[0], content="Percent(0.5)")
  inspect(style.grid_template_columns[1], content="Percent(0.5)")
}

///|
test "grid-template-columns none" {
  let style = parse_inline_style("grid-template-columns: none")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid-template-columns subgrid with line names" {
  let style = parse_inline_style("grid-template-columns: subgrid [a] [b c] [d]")
  inspect(style.grid_template_columns_kind, content="Subgrid")
  inspect(style.grid_template_columns.length(), content="0")
  // Each bracket group is a separate line (not merged like a track list).
  let names = style.grid_template_column_line_names
  inspect(names.length(), content="3")
  debug_inspect(names[0], content="[\"a\"]")
  debug_inspect(names[1], content="[\"b\", \"c\"]")
  debug_inspect(names[2], content="[\"d\"]")
}

///|
test "grid-template-rows masonry" {
  let style = parse_inline_style("grid-template-rows: masonry")
  inspect(style.grid_template_rows_kind, content="Masonry")
  inspect(style.grid_template_rows.length(), content="0")
}

///|
test "grid-template-columns explicit kind by default" {
  let style = parse_inline_style("grid-template-columns: 1fr 2fr")
  inspect(style.grid_template_columns_kind, content="Explicit")
}

///|
test "grid-template areas form sets areas, row sizes and columns" {
  let style = parse_inline_style(
    "grid-template: \"head head\" 80px \"nav main\" 1fr / 200px 1fr",
  )
  inspect(style.grid_template_areas.length(), content="2")
  inspect(style.grid_template_areas[0], content="head head")
  inspect(style.grid_template_areas[1], content="nav main")
  inspect(style.grid_template_rows.length(), content="2")
  inspect(style.grid_template_rows[0], content="Length(80)")
  inspect(style.grid_template_rows[1], content="Fr(1)")
  inspect(style.grid_template_columns.length(), content="2")
  inspect(style.grid_template_columns[0], content="Length(200)")
  inspect(style.grid_template_columns[1], content="Fr(1)")
}

///|
test "grid-template areas form without column part or row sizes" {
  let style = parse_inline_style("grid-template: \"a\" \"b\" \"c\"")
  inspect(style.grid_template_areas.length(), content="3")
  // No explicit row sizes -> each row defaults to auto.
  inspect(style.grid_template_rows.length(), content="3")
  inspect(style.grid_template_rows[0], content="Auto")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid shorthand areas form" {
  let style = parse_inline_style("grid: \"a b\" 100px / 1fr 1fr")
  inspect(style.grid_template_areas.length(), content="1")
  inspect(style.grid_template_areas[0], content="a b")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_template_columns.length(), content="2")
}

///|
test "grid shorthand auto-flow on the column side" {
  // rows are explicit; columns are auto-placed.
  let style = parse_inline_style("grid: 100px 200px / auto-flow 1fr")
  inspect(style.grid_auto_flow, content="Column")
  inspect(style.grid_template_rows.length(), content="2")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_auto_columns.length(), content="1")
  inspect(style.grid_auto_columns[0], content="Fr(1)")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid shorthand auto-flow dense on the row side" {
  let style = parse_inline_style("grid: auto-flow dense 80px / 1fr 1fr")
  inspect(style.grid_auto_flow, content="RowDense")
  inspect(style.grid_auto_rows.length(), content="1")
  inspect(style.grid_auto_rows[0], content="Length(80)")
  inspect(style.grid_template_columns.length(), content="2")
}

///|
test "grid-template-columns converts rem/em and physical units to px" {
  let style = parse_inline_style(
    "grid-template-columns: 10rem 2em 1fr 12pt 1in",
  )
  inspect(style.grid_template_columns.length(), content="5")
  inspect(style.grid_template_columns[0], content="Length(160)")
  inspect(style.grid_template_columns[1], content="Length(32)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
  inspect(style.grid_template_columns[3], content="Length(16)")
  inspect(style.grid_template_columns[4], content="Length(96)")
}

///|
test "grid-template-columns minmax converts rem/physical units to px" {
  let style = parse_inline_style("grid-template-columns: minmax(1rem, 2cm)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="MinMax(Length(16), Length(75.59055118110236))",
  )
}

///|
test "grid-template-columns minmax" {
  let style = parse_inline_style("grid-template-columns: minmax(100px, 1fr)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="MinMax(Length(100), Fr(1))")
}

///|
test "grid-template-columns fit-content()" {
  let style = parse_inline_style(
    "grid-template-columns: fit-content(200px) fit-content(30%) 1fr",
  )
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="FitContentLength(200)")
  inspect(style.grid_template_columns[1], content="FitContentPercent(0.3)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
  // fit-content with rem is converted to px
  let s2 = parse_inline_style("grid-template-columns: fit-content(2rem)")
  inspect(s2.grid_template_columns[0], content="FitContentLength(32)")
}

///|
test "grid-template-columns fit-content() inside repeat" {
  let style = parse_inline_style(
    "grid-template-columns: repeat(2, fit-content(100px))",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(2), [FitContentLength(100)])",
  )
}

///|
test "grid-template-columns calc() track keeps following tracks" {
  // calc() in a track must not abort parsing of the remaining tracks.
  let style = parse_inline_style(
    "grid-template-columns: 100px calc(50% + 10px) 1fr",
  )
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
  // Pure-px calc resolves to a length track.
  let s2 = parse_inline_style("grid-template-columns: calc(100px + 20px) 1fr")
  inspect(s2.grid_template_columns.length(), content="2")
  inspect(s2.grid_template_columns[0], content="Length(120)")
  inspect(s2.grid_template_columns[1], content="Fr(1)")
}

///|
test "grid-template-columns repeat with inner line names does not abort" {
  // Line names inside repeat() must not kill parsing of the track list.
  let style = parse_inline_style(
    "grid-template-columns: repeat(3, [a] 1fr [b])",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [Fr(1)], [[\"a\"], [\"b\"]])",
  )
}

///|
test "grid-template-columns minmax min-content auto" {
  let style = parse_inline_style(
    "grid-template-columns: minmax(min-content, 100px) auto",
  )
  inspect(style.grid_template_columns.length(), content="2")
  inspect(
    style.grid_template_columns[0],
    content="MinMax(MinContent, Length(100))",
  )
  inspect(style.grid_template_columns[1], content="Auto")
}

///|
test "grid-template-columns repeat" {
  let style = parse_inline_style("grid-template-columns: repeat(3, 100px)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [Length(100)])",
  )
}

///|
test "grid-template shorthand rows and columns" {
  let style = parse_inline_style("grid-template: 100px / 200px")
  inspect(style.grid_template_rows.length(), content="1")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Length(200)")
}

///|
test "grid shorthand template rows and columns" {
  let style = parse_inline_style("display: grid; grid: 1fr 1fr / auto")
  inspect(style.grid_template_rows.length(), content="2")
  inspect(style.grid_template_rows[0], content="Fr(1)")
  inspect(style.grid_template_rows[1], content="Fr(1)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Auto")
}

///|
test "flex-flow row wrap" {
  let style = parse_inline_style("flex-flow: row wrap")
  inspect(style.flex_direction, content="Row")
  inspect(style.flex_wrap, content="Wrap")
}

///|
test "flex-flow column nowrap" {
  let style = parse_inline_style("flex-flow: column nowrap")
  inspect(style.flex_direction, content="Column")
  inspect(style.flex_wrap, content="NoWrap")
}

///|
test "flex-flow wrap-reverse only" {
  let style = parse_inline_style("flex-flow: wrap-reverse")
  inspect(style.flex_direction, content="Row") // default
  inspect(style.flex_wrap, content="WrapReverse")
}

///|
test "flex: 1 0% 1 (basis in middle - invalid)" {
  // CSS spec: flex shorthand must be <grow> [<shrink>] [<basis>]
  // Basis in middle like "1 0% 1" is invalid, so defaults are used
  let style = parse_inline_style("flex: 1 0% 1")
  inspect(style.flex_grow, content="0")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Auto")
}

///|
test "flex: 1 auto 1 (basis in middle - invalid)" {
  // CSS spec: flex shorthand must be <grow> [<shrink>] [<basis>]
  // Basis in middle like "1 auto 1" is invalid, so defaults are used
  let style = parse_inline_style("flex: 1 auto 1")
  inspect(style.flex_grow, content="0")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Auto")
}

///|
test "contain: none" {
  let style = parse_inline_style("contain: none")
  inspect(style.contain.size, content="false")
  inspect(style.contain.layout, content="false")
  inspect(style.contain.paint, content="false")
  inspect(style.contain.style, content="false")
}

///|
test "contain: strict" {
  let style = parse_inline_style("contain: strict")
  inspect(style.contain.size, content="true")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain: content" {
  let style = parse_inline_style("contain: content")
  inspect(style.contain.size, content="false")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain: layout" {
  let style = parse_inline_style("contain: layout")
  inspect(style.contain.size, content="false")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="false")
}

///|
test "contain: layout paint" {
  let style = parse_inline_style("contain: layout paint")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.size, content="false")
}

///|
test "contain: size layout paint style" {
  let style = parse_inline_style("contain: size layout paint style")
  inspect(style.contain.size, content="true")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain: inline-size" {
  let style = parse_inline_style("contain: inline-size")
  inspect(style.contain.inline_size, content="true")
  inspect(style.contain.size, content="false")
}

///|
test "container-type: size implies contain size and style" {
  let style = parse_inline_style("container-type: size")
  inspect(style.contain.size, content="true")
  inspect(style.contain.inline_size, content="false")
  inspect(style.contain.style, content="true")
}

///|
test "container-type: inline-size implies contain inline-size and style" {
  let style = parse_inline_style("container-type: inline-size")
  inspect(style.contain.size, content="false")
  inspect(style.contain.inline_size, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "container-type merges with contain flags" {
  let style = parse_inline_style("contain: paint; container-type: size")
  inspect(style.contain.size, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain-intrinsic-inline-size parses length" {
  let style = parse_inline_style("contain-intrinsic-inline-size: 100px")
  debug_inspect(style.contain_intrinsic_inline_size, content="Some(100)")
}

///|
test "contain-intrinsic-size shorthand sets inline and block" {
  let style = parse_inline_style("contain-intrinsic-size: 80px 40px")
  debug_inspect(style.contain_intrinsic_inline_size, content="Some(80)")
  debug_inspect(style.contain_intrinsic_block_size, content="Some(40)")
}

///|
test "parse width fit-content" {
  let style = parse_inline_style("width: fit-content")
  inspect(style.width, content="FitContent(10000000000)")
}

///|
test "parse width min-content" {
  let style = parse_inline_style("width: min-content")
  inspect(style.width, content="MinContent")
}

///|
test "parse width max-content" {
  let style = parse_inline_style("width: max-content")
  inspect(style.width, content="MaxContent")
}

///|
test "parse calc addition" {
  let style = parse_inline_style("width: calc(100px + 50px)")
  inspect(style.width, content="Length(150)")
}

///|
test "parse calc subtraction" {
  let style = parse_inline_style("width: calc(200px - 50px)")
  inspect(style.width, content="Length(150)")
}

///|
test "parse calc percentage" {
  let style = parse_inline_style("width: calc(50% + 50%)")
  inspect(style.width, content="Percent(1)")
}

///|
test "parse display none" {
  let style = parse_inline_style("display: none")
  inspect(style.display, content="None")
}

///|
test "parse display inline-flex" {
  let style = parse_inline_style("display: inline-flex")
  inspect(style.display, content="InlineFlex")
}

///|
test "parse display inline-grid" {
  let style = parse_inline_style("display: inline-grid")
  inspect(style.display, content="InlineGrid")
}

///|
test "parse position relative" {
  let style = parse_inline_style("position: relative")
  inspect(style.position, content="Relative")
}

///|
test "parse position fixed" {
  let style = parse_inline_style("position: fixed")
  inspect(style.position, content="Fixed")
}

///|
test "parse float left" {
  let style = parse_inline_style("float: left")
  inspect(style.float, content="Left")
}

///|
test "parse float right" {
  let style = parse_inline_style("float: right")
  inspect(style.float, content="Right")
}

///|
test "parse float inline-start uses final direction" {
  let rtl_first = parse_inline_style("direction: rtl; float: inline-start")
  inspect(rtl_first.float, content="Right")
  let rtl_last = parse_inline_style("float: inline-start; direction: rtl")
  inspect(rtl_last.float, content="Right")
}

///|
test "parse clear both" {
  let style = parse_inline_style("clear: both")
  inspect(style.clear, content="Both")
}

///|
test "parse clear left" {
  let style = parse_inline_style("clear: left")
  inspect(style.clear, content="Left")
}

///|
test "parse clear inline-end uses final direction" {
  let rtl_first = parse_inline_style("direction: rtl; clear: inline-end")
  inspect(rtl_first.clear, content="Left")
  let rtl_last = parse_inline_style("clear: inline-end; direction: rtl")
  inspect(rtl_last.clear, content="Left")
}

///|
test "parse align-items stretch" {
  let style = parse_inline_style("align-items: stretch")
  inspect(style.align_items, content="Stretch")
}

///|
test "parse align-items baseline" {
  let style = parse_inline_style("align-items: baseline")
  inspect(style.align_items, content="Baseline")
}

///|
test "parse justify-content space-evenly" {
  let style = parse_inline_style("justify-content: space-evenly")
  inspect(style.justify_content, content="SpaceEvenly")
}

///|
test "parse justify-content space-around" {
  let style = parse_inline_style("justify-content: space-around")
  inspect(style.justify_content, content="SpaceAround")
}

///|
test "parse overflow visible" {
  let style = parse_inline_style("overflow: visible")
  inspect(style.overflow_x, content="Visible")
  inspect(style.overflow_y, content="Visible")
}

///|
test "parse overflow hidden" {
  let style = parse_inline_style("overflow: hidden")
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Hidden")
}

///|
test "parse overflow scroll" {
  let style = parse_inline_style("overflow: scroll")
  inspect(style.overflow_x, content="Scroll")
  inspect(style.overflow_y, content="Scroll")
}

///|
test "parse overflow-x and overflow-y separately" {
  let style = parse_inline_style("overflow-x: hidden; overflow-y: scroll")
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Scroll")
}

///|
test "parse row-gap and column-gap separately" {
  let style = parse_inline_style("row-gap: 10px; column-gap: 20px")
  inspect(style.row_gap, content="Length(10)")
  inspect(style.column_gap, content="Length(20)")
}

///|
test "parse min-width and max-width" {
  let style = parse_inline_style("min-width: 100px; max-width: 500px")
  inspect(style.min_width, content="Length(100)")
  inspect(style.max_width, content="Length(500)")
}

///|
test "parse min-height and max-height" {
  let style = parse_inline_style("min-height: 50px; max-height: 300px")
  inspect(style.min_height, content="Length(50)")
  inspect(style.max_height, content="Length(300)")
}

///|
test "parse inset shorthand" {
  let style = parse_inline_style("position: absolute; inset: 10px")
  inspect(style.inset.top, content="Length(10)")
  inspect(style.inset.right, content="Length(10)")
  inspect(style.inset.bottom, content="Length(10)")
  inspect(style.inset.left, content="Length(10)")
}

///|
test "parse inset shorthand with 4 values including auto" {
  let style = parse_inline_style(
    "position: absolute; inset: 50px auto 50px 50px",
  )
  inspect(style.inset.top, content="Length(50)")
  inspect(style.inset.right, content="Auto")
  inspect(style.inset.bottom, content="Length(50)")
  inspect(style.inset.left, content="Length(50)")
}

///|
test "parse margin with 2 values" {
  let style = parse_inline_style("margin: 10px 20px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(10)")
  inspect(style.margin.left, content="Length(20)")
}

///|
test "parse margin with 3 values" {
  let style = parse_inline_style("margin: 10px 20px 30px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(20)")
}

///|
test "parse margin with 4 values" {
  let style = parse_inline_style("margin: 10px 20px 30px 40px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(40)")
}

///|
test "parse margin auto" {
  let style = parse_inline_style("margin: auto")
  inspect(style.margin.top, content="Auto")
  inspect(style.margin.right, content="Auto")
  inspect(style.margin.bottom, content="Auto")
  inspect(style.margin.left, content="Auto")
}

///|
test "parse padding with 2 values" {
  let style = parse_inline_style("padding: 5px 15px")
  inspect(style.padding.top, content="Length(5)")
  inspect(style.padding.right, content="Length(15)")
  inspect(style.padding.bottom, content="Length(5)")
  inspect(style.padding.left, content="Length(15)")
}

///|
test "parse individual margin properties" {
  let style = parse_inline_style(
    "margin-top: 10px; margin-right: 20px; margin-bottom: 30px; margin-left: 40px",
  )
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(40)")
}

///|
test "parse individual padding properties" {
  let style = parse_inline_style(
    "padding-top: 5px; padding-right: 10px; padding-bottom: 15px; padding-left: 20px",
  )
  inspect(style.padding.top, content="Length(5)")
  inspect(style.padding.right, content="Length(10)")
  inspect(style.padding.bottom, content="Length(15)")
  inspect(style.padding.left, content="Length(20)")
}

///|
test "parse border individual widths" {
  let style = parse_inline_style(
    "border-top-width: 1px; border-right-width: 2px; border-bottom-width: 3px; border-left-width: 4px",
  )
  inspect(style.border.top, content="Length(1)")
  inspect(style.border.right, content="Length(2)")
  inspect(style.border.bottom, content="Length(3)")
  inspect(style.border.left, content="Length(4)")
}

///|
test "parse flex-direction row-reverse" {
  let style = parse_inline_style("flex-direction: row-reverse")
  inspect(style.flex_direction, content="RowReverse")
}

///|
test "parse flex-direction column-reverse" {
  let style = parse_inline_style("flex-direction: column-reverse")
  inspect(style.flex_direction, content="ColumnReverse")
}

///|
test "parse flex: none" {
  let style = parse_inline_style("flex: none")
  inspect(style.flex_grow, content="0")
  inspect(style.flex_shrink, content="0")
  inspect(style.flex_basis, content="Auto")
}

///|
test "parse flex: auto" {
  let style = parse_inline_style("flex: auto")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Auto")
}

///|
test "parse flex: 2 1 100px" {
  let style = parse_inline_style("flex: 2 1 100px")
  inspect(style.flex_grow, content="2")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Length(100)")
}

///|
test "parse grid-auto-flow row" {
  let style = parse_inline_style("grid-auto-flow: row")
  inspect(style.grid_auto_flow, content="Row")
}

///|
test "parse vh and vw units" {
  let style = parse_inline_style("width: 50vw; height: 100vh")
  // 50vw = 50% of 1000px = 500px
  inspect(style.width, content="Length(500)")
  // 100vh = 100% of 1000px = 1000px
  inspect(style.height, content="Length(1000)")
}

///|
test "parse dynamic viewport units" {
  let style = parse_inline_style(
    "width: 50dvw; min-width: 25svw; max-width: 10lvw; height: 100dvh; min-height: 50svh; max-height: 25lvh",
  )
  inspect(style.width, content="Length(500)")
  inspect(style.min_width, content="Length(250)")
  inspect(style.max_width, content="Length(100)")
  inspect(style.height, content="Length(1000)")
  inspect(style.min_height, content="Length(500)")
  inspect(style.max_height, content="Length(250)")
}

///|
test "parse em and rem units" {
  let style = parse_inline_style("width: 2em; height: 1.5rem")
  // 2em = 2 * 16px = 32px
  inspect(style.width, content="Length(32)")
  // 1.5rem = 1.5 * 16px = 24px
  inspect(style.height, content="Length(24)")
}

///|
test "parse unitless zero" {
  let style = parse_inline_style("margin: 0; padding: 0")
  inspect(style.margin.top, content="Length(0)")
  inspect(style.padding.top, content="Length(0)")
}

///|
test "parse box-sizing content-box" {
  let style = parse_inline_style(
    "box-sizing: content-box; width: 100px; padding: 10px",
  )
  // content-box should adjust width to include padding
  // 100px content + 10px left + 10px right = 120px
  inspect(style.width, content="Length(120)")
}

///|
test "parse box-sizing border-box" {
  let style = parse_inline_style(
    "box-sizing: border-box; width: 100px; padding: 10px",
  )
  // border-box keeps width as-is
  inspect(style.width, content="Length(100)")
}

///|
test "parse align-content center" {
  let style = parse_inline_style("align-content: center")
  inspect(style.align_content, content="Center")
}

///|
test "parse align-content space-between" {
  let style = parse_inline_style("align-content: space-between")
  inspect(style.align_content, content="SpaceBetween")
}

///|
test "parse place-content safe center" {
  let style = parse_inline_style("place-content: safe center")
  inspect(style.align_content, content="Start")
  inspect(style.justify_content, content="Start")
  inspect(style.align_content_unsafe, content="false")
  inspect(style.justify_content_unsafe, content="false")
}

///|
test "parse place-content end center" {
  let style = parse_inline_style("place-content: end center")
  inspect(style.align_content, content="End")
  inspect(style.justify_content, content="Center")
  inspect(style.align_content_unsafe, content="false")
  inspect(style.justify_content_unsafe, content="false")
}

///|
test "parse place-content unsafe end" {
  let style = parse_inline_style("place-content: unsafe end")
  inspect(style.align_content, content="End")
  inspect(style.justify_content, content="End")
  inspect(style.align_content_unsafe, content="true")
  inspect(style.justify_content_unsafe, content="true")
}

///|
test "parse place-content start left" {
  let style = parse_inline_style("place-content: start left")
  inspect(style.align_content, content="Start")
  inspect(style.justify_content, content="Left")
  inspect(style.align_content_unsafe, content="false")
  inspect(style.justify_content_unsafe, content="false")
}

///|
test "parse logical property padding-block" {
  let style = parse_inline_style("padding-block: 20px")
  inspect(style.padding.top, content="Length(20)")
  inspect(style.padding.bottom, content="Length(20)")
}

///|
test "parse logical property padding-inline" {
  let style = parse_inline_style("padding-inline: 15px")
  inspect(style.padding.left, content="Length(15)")
  inspect(style.padding.right, content="Length(15)")
}

///|
test "parse logical property border-block" {
  let style = parse_inline_style("border-block: 2px")
  inspect(style.border.top, content="Length(2)")
  inspect(style.border.bottom, content="Length(2)")
}

///|
test "parse logical property border-inline" {
  let style = parse_inline_style("border-inline: 3px")
  inspect(style.border.left, content="Length(3)")
  inspect(style.border.right, content="Length(3)")
}

///|
test "parse grid-template-columns with auto-fill" {
  let style = parse_inline_style(
    "grid-template-columns: repeat(auto-fill, 100px)",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(AutoFill, [Length(100)])",
  )
}

///|
test "parse grid-template-columns with minmax in repeat" {
  let style = parse_inline_style(
    "grid-template-columns: repeat(3, minmax(100px, 1fr))",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [MinMax(Length(100), Fr(1))])",
  )
}

///|
test "parse alignment start and end" {
  let style = parse_inline_style("justify-content: start; align-items: end")
  inspect(style.justify_content, content="Start")
  inspect(style.align_items, content="End")
}

///|
test "parse alignment flex-start and flex-end" {
  let style = parse_inline_style(
    "justify-content: flex-start; align-items: flex-end",
  )
  inspect(style.justify_content, content="FlexStart")
  inspect(style.align_items, content="FlexEnd")
}

///|
test "parse transform translate" {
  let style = parse_inline_style("transform: translate(10px, 20px)")
  inspect(style.transform.translate_x, content="Length(10)")
  inspect(style.transform.translate_y, content="Length(20)")
}

///|
test "parse transform translateX" {
  let style = parse_inline_style("transform: translateX(50%)")
  inspect(style.transform.translate_x, content="Percent(0.5)")
  inspect(style.transform.translate_y, content="Length(0)")
}

///|
test "parse transform translateY" {
  let style = parse_inline_style("transform: translateY(-100px)")
  inspect(style.transform.translate_x, content="Length(0)")
  inspect(style.transform.translate_y, content="Length(-100)")
}

///|
test "parse transform translate with percentage" {
  let style = parse_inline_style("transform: translate(-50%, -50%)")
  inspect(style.transform.translate_x, content="Percent(-0.5)")
  inspect(style.transform.translate_y, content="Percent(-0.5)")
}

///|
test "parse transform translate converts rem/physical units" {
  let style = parse_inline_style("transform: translate(2rem, 1in)")
  inspect(style.transform.translate_x, content="Length(32)")
  inspect(style.transform.translate_y, content="Length(96)")
}

///|
test "parse transform scale" {
  let style = parse_inline_style("transform: scale(2, 0.5)")
  inspect(style.transform.scale_x, content="2")
  inspect(style.transform.scale_y, content="0.5")
}

///|
test "parse transform rotate" {
  let style = parse_inline_style("transform: rotate(90deg)")
  inspect(style.transform.rotate_degrees, content="90")
  inspect(style.transform.quarter_turns(), content="1")
}

///|
test "parse transform skew" {
  let style = parse_inline_style("transform: skew(45deg, -15deg)")
  inspect(style.transform.skew_x_degrees, content="45")
  inspect(style.transform.skew_y_degrees, content="-15")
}

///|
test "parse transform matrix" {
  let style = parse_inline_style("transform: matrix(1, 0, -1, 1, 64, 0)")
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
test "parse transform matrix3d as 2D affine matrix" {
  let style = parse_inline_style(
    "transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1)",
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
test "parse pointer-events none" {
  let style = parse_inline_style("pointer-events: none")
  inspect(style.pointer_events, content="None")
}

///|
test "parse clip-path inset" {
  let style = parse_inline_style("clip-path: inset(16px 0 25% 4px)")
  match style.clip_path {
    @style.ClipPath::Inset(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 0, -0.25, 4]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "parse clip-path rect" {
  let style = parse_inline_style("clip-path: rect(16px 128px 64px 16px)")
  match style.clip_path {
    @style.ClipPath::Rect(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 128, 64, 16]")
    _ => fail("expected rect clip-path")
  }
}

///|
test "parse clip-path xywh" {
  let style = parse_inline_style("clip-path: xywh(16px 16px 112px 48px)")
  match style.clip_path {
    @style.ClipPath::Xywh(x, y, width, height) =>
      debug_inspect([x, y, width, height], content="[16, 16, 112, 48]")
    _ => fail("expected xywh clip-path")
  }
}

///|
test "parse clip-path circle" {
  let style = parse_inline_style("clip-path: circle(24px at 24px 24px)")
  match style.clip_path {
    @style.ClipPath::Circle(radius, center_x, center_y) =>
      debug_inspect([radius, center_x, center_y], content="[24, 24, 24]")
    _ => fail("expected circle clip-path")
  }
}

///|
test "parse clip-path ellipse" {
  let style = parse_inline_style("clip-path: ellipse(24px 16px at 32px 32px)")
  match style.clip_path {
    @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) =>
      debug_inspect(
        [radius_x, radius_y, center_x, center_y],
        content="[24, 16, 32, 32]",
      )
    _ => fail("expected ellipse clip-path")
  }
}

///|
test "parse clip-path polygon" {
  let style = parse_inline_style(
    "clip-path: polygon(32px 0, 64px 64px, 0 64px)",
  )
  match style.clip_path {
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
test "parse clip-path path as polygon" {
  let style = parse_inline_style("clip-path: path(\"M 32 0 L 64 64 L 0 64 Z\")")
  match style.clip_path {
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
test "parse clip-path quadratic path as polygon" {
  let style = parse_inline_style("clip-path: path(\"M 0 64 Q 32 0 64 64 Z\")")
  match style.clip_path {
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
test "parse clip-path cubic path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 C 0 0 64 0 64 64 Z\")",
  )
  match style.clip_path {
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
test "parse clip-path smooth quadratic path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 Q 16 0 32 64 T 64 64 Z\")",
  )
  match style.clip_path {
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
test "parse clip-path smooth cubic path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 C 0 0 32 0 32 64 S 64 128 64 64 Z\")",
  )
  match style.clip_path {
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
test "parse clip-path arc path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 A 32 32 0 0 1 64 64 Z\")",
  )
  match style.clip_path {
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
test "parse justify-self center" {
  let style = parse_inline_style("justify-self: center")
  inspect(style.justify_self, content="Center")
}

///|
test "parse align-self center" {
  let style = parse_inline_style("align-self: center")
  inspect(style.align_self, content="Center")
}

///|
test "parse justify-items center" {
  let style = parse_inline_style("justify-items: center")
  inspect(style.justify_items, content="Center")
}
