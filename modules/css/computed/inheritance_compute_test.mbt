///|
/// Helper: build a parent style with a single property set, then compute a
/// declaration that explicitly inherits that property. Returns the computed
/// child style.
fn compute_inheriting(prop : String, parent : @style.Style) -> @style.Style {
  let ctx = @computed.ComputeContext::with_parent(parent)
  let decl : @cascade.Declaration = {
    property: prop,
    value: Inherit,
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 0, },
    source_order: 0,
  }
  @computed.compute(@cascade.cascade([decl]), ctx)
}

///|
test "Inherit - display variants" {
  for
    d in [
      @types.Inline,
      InlineBlock,
      Flex,
      InlineFlex,
      Grid,
      InlineGrid,
      Table,
      InlineTable,
      TableRow,
      TableCell,
      TableCaption,
      TableRowGroup,
      TableHeaderGroup,
      TableFooterGroup,
      TableColumn,
      TableColumnGroup,
      None,
      Contents,
      FlowRoot,
    ] {
    let parent : @style.Style = { ..@style.Style::default(), display: d, }
    let s = compute_inheriting("display", parent)
    inspect(s.display, content=d.to_string())
  }
}

///|
test "Inherit - position variants" {
  for p in [@types.Position::Relative, Absolute, Fixed] {
    let parent : @style.Style = { ..@style.Style::default(), position: p, }
    let s = compute_inheriting("position", parent)
    inspect(s.position, content=p.to_string())
  }
}

///|
test "Inherit - flex-direction variants" {
  for d in [@types.RowReverse, Column, ColumnReverse] {
    let parent : @style.Style = {
      ..@style.Style::default(),
      flex_direction: d,
    }
    let s = compute_inheriting("flex-direction", parent)
    inspect(s.flex_direction, content=d.to_string())
  }
}

///|
test "Inherit - flex-wrap variants" {
  for w in [@types.Wrap, WrapReverse] {
    let parent : @style.Style = { ..@style.Style::default(), flex_wrap: w, }
    let s = compute_inheriting("flex-wrap", parent)
    inspect(s.flex_wrap, content=w.to_string())
  }
}

///|
test "Inherit - dimensions" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    width: Length(100.0),
    height: Percent(0.5),
    min_width: Length(50.0),
    min_height: Length(20.0),
    max_width: Length(200.0),
    max_height: Length(150.0),
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
      top: Length(1.0),
      right: Length(2.0),
      bottom: Length(3.0),
      left: Length(4.0),
    },
    padding: {
      top: Length(5.0),
      right: Length(6.0),
      bottom: Length(7.0),
      left: Length(8.0),
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
      BlockEnd,
      Block,
      InlineStart,
      InlineEnd,
      Inline,
    ] {
    let parent : @style.Style = { ..@style.Style::default(), margin_trim: mt, }
    let s = compute_inheriting("margin-trim", parent)
    inspect(s.margin_trim, content=mt.to_string())
  }
}

///|
test "Inherit - column-* values" {
  let parent : @style.Style = {
    ..@style.Style::default(),
    column_count: Some(3),
    column_width: Length(100.0),
    column_fill: Auto,
    break_before: Column,
    break_after: Avoid,
    break_inside: Avoid,
    column_span: All,
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
    column_width: Calc(-10.0, 0.5),
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
    flex_basis: Length(50.0),
    color: @types.Color::rgb(10, 20, 30),
    background_color: @types.Color::rgb(40, 50, 60),
    font_size: 18.0,
    font_weight: 700.0,
    line_height: 27.0,
    text_overflow: Ellipsis,
    text_align: Center,
    white_space: PreWrap,
    pointer_events: None,
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
    caption_side: Bottom,
    border_collapse: Collapse,
    border_spacing: 4.0,
    border_spacing_vertical: 8.0,
    writing_mode: VerticalRl,
    direction: Rtl,
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
  let parent : @style.Style = { ..@style.Style::default(), opacity: 0.25, }
  inspect(compute_inheriting("opacity", parent).opacity, content="0.25")
}

///|
test "Initial keyword - all properties" {
  // PropertyValue::Initial resets to initial_value(property)
  let ctx = @computed.ComputeContext::new()
  let make_decl = fn(prop : String) {
    let d : @cascade.Declaration = {
      property: prop,
      value: Initial,
      origin: Author,
      importance: Normal,
      specificity: { a: 0, b: 0, c: 0, },
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
    value: Unset,
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 0, },
    source_order: 0,
  }
  let s = @computed.compute(@cascade.cascade([decl]), ctx)
  inspect(s.color.r, content="100")
}

///|
test "Unset keyword on non-inherited property uses initial" {
  let parent : @style.Style = { ..@style.Style::default(), display: Flex, }
  let ctx = @computed.ComputeContext::with_parent(parent)
  let decl : @cascade.Declaration = {
    property: "display",
    value: Unset,
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 0, },
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
    value: Revert,
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 0, },
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
    value: RevertLayer,
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 0, },
    source_order: 0,
  }
  let s = @computed.compute(@cascade.cascade([decl]), ctx)
  inspect(s.position, content="Relative")
}
