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
