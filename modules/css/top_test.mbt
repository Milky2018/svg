///|
test "css package parses stylesheets with diagnostics" {
  let result = parse_stylesheet_with_diagnostics(
    ".card { display: flex; mystery-prop: 1; }",
  )
  let summary = result.diagnostics.get_summary()
  inspect(summary.supported, content="1")
  inspect(summary.unknown, content="1")
}

///|
test "css package computes cascaded display" {
  let element = Element::with_classes("div", ["card"])
  let stylesheet = parse_stylesheet(".card { display: flex; padding: 8px; }")
  let cascaded = cascade_element(element, [stylesheet], [])
  let computed = compute_style(cascaded, ComputeContext::new())
  inspect(computed.display.to_string(), content="Flex")
}

///|
test "parse_inline_style returns a populated Style" {
  let style = parse_inline_style("display: flex; padding: 8px;")
  inspect(style.display.to_string(), content="Flex")
}

///|
test "parse_media_query_list" {
  let mq = parse_media_query_list("(min-width: 768px)")
  let env = MediaEnvironment::new(800.0, 600.0)
  assert_true(mq.evaluate(env))
  let small = MediaEnvironment::new(400.0, 600.0)
  assert_false(mq.evaluate(small))
}

///|
test "parse_selector and matches_selector" {
  let element = Element::with_classes("div", ["card"]).set_id("hero")
  let sel = parse_selector("div.card#hero").unwrap()
  assert_true(matches_selector(element, sel))
}

///|
test "parse_selector_list and matches_selector_list" {
  let element = Element::new("h1")
  let list = parse_selector_list("h1, h2, h3").unwrap()
  assert_true(matches_selector_list(element, list))
  let other = Element::new("p")
  assert_false(matches_selector_list(other, list))
}

///|
test "cascade_declarations sugar" {
  let decls = [
    Declaration::new("color", "red"),
    Declaration::new("color", "blue"),
  ]
  // Same property, later wins at equal specificity/source order=0
  let cascaded = cascade_declarations(decls)
  assert_true(cascaded.has("color"))
}

///|
test "cascade_element_with_media respects media query" {
  let element = Element::with_classes("div", ["card"])
  let css = "@media (min-width: 1000px) { .card { color: red; } }"
  let sheet = parse_stylesheet(css)
  let big = MediaEnvironment::new(1200.0, 800.0)
  let small = MediaEnvironment::new(400.0, 800.0)
  let result_big = cascade_element_with_media(element, [sheet], [], Some(big))
  let result_small = cascade_element_with_media(
    element,
    [sheet],
    [],
    Some(small),
  )
  assert_true(result_big.has("color"))
  assert_false(result_small.has("color"))
}

///|
test "cascade_element_indexed delegates to indexed stylesheet" {
  let element = Element::with_classes("div", ["card"])
  let sheet = parse_stylesheet(".card { color: red; }")
  let indexed = IndexedStylesheet::new(sheet)
  let result = cascade_element_indexed(element, [indexed], [], None)
  assert_true(result.has("color"))
}

///|
test "compute_inline_style and compute_inline_raw" {
  let ctx = ComputeContext::new()
  let s1 = compute_inline_style("display: flex; flex-grow: 2;", ctx)
  inspect(s1.display.to_string(), content="Flex")
  inspect(s1.flex_grow, content="2")
  let s2 = compute_inline_raw("display: grid;", ctx)
  inspect(s2.display.to_string(), content="Grid")
}

///|
test "compute_style_with_vars exposes custom property map" {
  let element = Element::new("div")
  let sheet = parse_stylesheet("div { --brand: #ff0; color: var(--brand); }")
  let cascaded = cascade_element(element, [sheet], [])
  let (_style, vars) = compute_style_with_vars(cascaded, ComputeContext::new())
  inspect(vars.contains("--brand"), content="true")
}

///|
test "apply_property_direct mutates a Style copy" {
  let ctx = ComputeContext::new()
  let style = compute_inline_style("display: block;", ctx)
  let updated = apply_property_direct(style, "display", "flex", ctx)
  inspect(updated.display.to_string(), content="Flex")
}

///|
test "parse_color returns CssColorValue" {
  let value = parse_color("#ff0000")
  // CssColorValue is opaque; just ensure it parses without panic
  let _ = value
  inspect(true, content="true")
}

///|
test "affects_layout re-exports diagnostics helper" {
  assert_true(affects_layout(UnsupportedLayout))
  assert_false(affects_layout(Supported))
}

///|
test "css package re-exports animation timing helpers" {
  let effect = NumericKeyframeEffect::new(
    [NumericKeyframe::new(0.0, 0.0), NumericKeyframe::new(1.0, 100.0)],
    { ..EffectTiming::new(1000.0), fill: FillMode::Both },
  ).unwrap()
  inspect(effect.sample(-1.0).unwrap(), content="0")
  inspect(effect.sample(500.0).unwrap(), content="50")
  inspect(effect.sample(1001.0).unwrap(), content="100")
}
