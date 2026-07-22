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
    Value("10px solid transparent"),
    Author,
    Normal,
    { a: 0, b: 1, c: 0 },
    0,
  )
  let left_decl = @cascade.Declaration::with_metadata(
    "border-left-width",
    Value("100px"),
    Author,
    Normal,
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
    Value("100px"),
    Author,
    Normal,
    { a: 0, b: 1, c: 0 },
    0,
  )
  let border_second_decl = @cascade.Declaration::with_metadata(
    "border",
    Value("10px solid transparent"),
    Author,
    Normal,
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
    @cascade.Declaration::from_inline("border-top-width", "100px", Normal),
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
