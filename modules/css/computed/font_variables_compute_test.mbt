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
    parent_style: Some({ ..@style.Style::default(), font_family: "Ahem", }),
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
  // WPT css/css-values/calc-in-max.html: `max(calc(100%))` must
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
