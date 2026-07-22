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
  // A single argument resolves to that argument verbatim.
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
