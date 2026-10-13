///|
test "css package computes cascaded display" {
  let element = @css.Element::with_classes("div", ["card"])
  let stylesheet = @css.parse_stylesheet(
    ".card { display: flex; padding: 8px; }",
  )
  let cascaded = @css.cascade_element(element, [stylesheet], [])
  let computed = @css.compute_style(cascaded, @css.ComputeContext::new())
  inspect(computed.display.to_string(), content="Flex")
}

///|
test "parse_inline_style returns a populated Style" {
  let style = @css.parse_inline_style("display: flex; padding: 8px;")
  inspect(style.display.to_string(), content="Flex")
}

///|
test "parse_media_query_list" {
  let mq = @css.parse_media_query_list("(min-width: 768px)")
  let env = @css.MediaEnvironment::new(800.0, 600.0)
  assert_true(mq.evaluate(env))
  let small = @css.MediaEnvironment::new(400.0, 600.0)
  assert_false(mq.evaluate(small))
}

///|
test "parse_selector and matches_selector" {
  let element = @css.Element::with_classes("div", ["card"]).set_id("hero")
  let sel = @css.parse_selector("div.card#hero").unwrap()
  assert_true(@css.matches_selector(element, sel))
}

///|
test "parse_selector_list and matches_selector_list" {
  let element = @css.Element::new("h1")
  let list = @css.parse_selector_list("h1, h2, h3").unwrap()
  assert_true(@css.matches_selector_list(element, list))
  let other = @css.Element::new("p")
  assert_false(@css.matches_selector_list(other, list))
}

///|
test "cascade_declarations sugar" {
  let decls = [
    @css.Declaration::new("color", "red"),
    @css.Declaration::new("color", "blue"),
  ]
  // Same property, later wins at equal specificity/source order=0
  let cascaded = @css.cascade_declarations(decls)
  assert_true(cascaded.has("color"))
}

///|
test "cascade_element_with_media respects media query" {
  let element = @css.Element::with_classes("div", ["card"])
  let css = "@media (min-width: 1000px) { .card { color: red; } }"
  let sheet = @css.parse_stylesheet(css)
  let big = @css.MediaEnvironment::new(1200.0, 800.0)
  let small = @css.MediaEnvironment::new(400.0, 800.0)
  let result_big = @css.cascade_element_with_media(
    element,
    [sheet],
    [],
    Some(big),
  )
  let result_small = @css.cascade_element_with_media(
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
  let element = @css.Element::with_classes("div", ["card"])
  let sheet = @css.parse_stylesheet(".card { color: red; }")
  let indexed = @css.IndexedStylesheet::new(sheet)
  let result = @css.cascade_element_indexed(element, [indexed], [], None)
  assert_true(result.has("color"))
}

///|
test "validated cascade skips invalid winning extension declarations" {
  let element = @css.Element::new("rect")
  let sheet = @css.parse_stylesheet("rect { fill: red; fill: not-a-color; }")
  let result = @css.cascade_element_with_media_and_validator(
    element,
    [sheet],
    [],
    None,
    fn(property, value) {
      match (property, value) {
        ("fill", Value("not-a-color")) => false
        _ => true
      }
    },
  )
  debug_inspect(result.get_value("fill"), content="Some(\"red\")")
}

///|
test "compute_inline_style and compute_inline_raw" {
  let ctx = @css.ComputeContext::new()
  let s1 = @css.compute_inline_style("display: flex; flex-grow: 2;", ctx)
  inspect(s1.display.to_string(), content="Flex")
  inspect(s1.flex_grow, content="2")
  let s2 = @css.compute_inline_raw("display: grid;", ctx)
  inspect(s2.display.to_string(), content="Grid")
}

///|
test "compute_style_with_vars exposes custom property map" {
  let element = @css.Element::new("div")
  let sheet = @css.parse_stylesheet(
    "div { --brand: #ff0; color: var(--brand); }",
  )
  let cascaded = @css.cascade_element(element, [sheet], [])
  let (_style, vars) = @css.compute_style_with_vars(
    cascaded,
    @css.ComputeContext::new(),
  )
  inspect(vars.contains("--brand"), content="true")
}

///|
test "empty custom properties remain present for var substitution" {
  let element = @css.Element::new("div")
  let sheet = @css.parse_stylesheet(
    "div { --empty: ; --value: var(--empty) red; }",
  )
  let cascaded = @css.cascade_element(element, [sheet], [])
  let (_style, vars) = @css.compute_style_with_vars(
    cascaded,
    @css.ComputeContext::new(),
  )
  debug_inspect(vars.get("--empty"), content="Some(\"\")")
  debug_inspect(
    @css.resolve_custom_property_value("var(--value, blue)", vars),
    content="Some(\" red\")",
  )
}

///|
test "apply_property_direct mutates a Style copy" {
  let ctx = @css.ComputeContext::new()
  let style = @css.compute_inline_style("display: block;", ctx)
  let updated = @css.apply_property_direct(style, "display", "flex", ctx)
  inspect(updated.display.to_string(), content="Flex")
}

///|
test "parse_color returns CssColorValue" {
  let value = @css.parse_color("#ff0000")
  // CssColorValue is opaque; just ensure it parses without panic
  let _ = value
  inspect(true, content="true")
}
