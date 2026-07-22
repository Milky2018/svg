///|
test "MediaQueryList - new, is_empty, length" {
  let empty = MediaQueryList::new()
  assert_true(empty.is_empty())
  inspect(empty.length(), content="0")
  let list = parse_media_query_list("screen, (min-width: 600px)")
  assert_false(list.is_empty())
  inspect(list.length(), content="2")
}

///|
test "MediaQuery::default" {
  let mq = MediaQuery::default()
  inspect(mq.negated, content="false")
  inspect(mq.only, content="false")
  inspect(mq.conditions.length(), content="0")
}

///|
test "Show MediaType" {
  inspect(MediaType::All, content="All")
  inspect(MediaType::Screen, content="Screen")
  inspect(MediaType::Print, content="Print")
  inspect(MediaType::Speech, content="Speech")
}

///|
test "Show RangeOp" {
  inspect(RangeOp::Eq, content="Eq")
  inspect(RangeOp::Lt, content="Lt")
  inspect(RangeOp::Le, content="Le")
  inspect(RangeOp::Gt, content="Gt")
  inspect(RangeOp::Ge, content="Ge")
}

///|
test "Show MediaValue" {
  inspect(MediaValue::Number(2.5), content="Number(2.5)")
  inspect(MediaValue::Dimension(768.0, "px"), content="Dimension(768, \"px\")")
  inspect(MediaValue::Ratio(16, 9), content="Ratio(16, 9)")
  inspect(MediaValue::Ident("landscape"), content="Ident(\"landscape\")")
}

///|
test "Show MediaFeature - boolean features" {
  inspect(MediaFeature::Color, content="Color")
  inspect(MediaFeature::ColorGamut, content="ColorGamut")
  inspect(MediaFeature::ColorIndex, content="ColorIndex")
  inspect(MediaFeature::Grid, content="Grid")
  inspect(MediaFeature::Hover, content="Hover")
  inspect(MediaFeature::Monochrome, content="Monochrome")
  inspect(MediaFeature::Pointer, content="Pointer")
  inspect(MediaFeature::Scripting, content="Scripting")
  inspect(MediaFeature::Update, content="Update")
}

///|
test "Show MediaFeature - range features" {
  let v = MediaValue::Dimension(768.0, "px")
  inspect(MediaFeature::MinWidth(v), content="MinWidth(Dimension(768, \"px\"))")
  inspect(MediaFeature::MaxWidth(v), content="MaxWidth(Dimension(768, \"px\"))")
  inspect(
    MediaFeature::MinHeight(v),
    content="MinHeight(Dimension(768, \"px\"))",
  )
  inspect(
    MediaFeature::MaxHeight(v),
    content="MaxHeight(Dimension(768, \"px\"))",
  )
  let ratio = MediaValue::Ratio(16, 9)
  inspect(
    MediaFeature::MinAspectRatio(ratio),
    content="MinAspectRatio(Ratio(16, 9))",
  )
  inspect(
    MediaFeature::MaxAspectRatio(ratio),
    content="MaxAspectRatio(Ratio(16, 9))",
  )
  let dppx = MediaValue::Dimension(2.0, "dppx")
  inspect(
    MediaFeature::MinResolution(dppx),
    content="MinResolution(Dimension(2, \"dppx\"))",
  )
  inspect(
    MediaFeature::MaxResolution(dppx),
    content="MaxResolution(Dimension(2, \"dppx\"))",
  )
}

///|
test "Show MediaFeature - optional value features" {
  let s_width = MediaFeature::Width(Some(MediaValue::Number(800.0))).to_string()
  assert_true(s_width.contains("Width("))
  let s_height = MediaFeature::Height(None).to_string()
  assert_true(s_height.contains("Height("))
  let s_ar = MediaFeature::AspectRatio(Some(MediaValue::Ratio(4, 3))).to_string()
  assert_true(s_ar.contains("AspectRatio("))
  let s_res = MediaFeature::Resolution(None).to_string()
  assert_true(s_res.contains("Resolution("))
}

///|
test "Show MediaFeature - range syntax" {
  let v = MediaValue::Dimension(500.0, "px")
  let s = MediaFeature::WidthRange(RangeOp::Le, v).to_string()
  assert_true(s.contains("WidthRange("))
  let s2 = MediaFeature::HeightRange(RangeOp::Ge, v).to_string()
  assert_true(s2.contains("HeightRange("))
}

///|
test "Show MediaFeature - discrete features" {
  inspect(
    MediaFeature::Orientation("portrait"),
    content="Orientation(\"portrait\")",
  )
  inspect(
    MediaFeature::DisplayMode("standalone"),
    content="DisplayMode(\"standalone\")",
  )
  inspect(
    MediaFeature::PrefersColorScheme("dark"),
    content="PrefersColorScheme(\"dark\")",
  )
  inspect(
    MediaFeature::PrefersReducedMotion("reduce"),
    content="PrefersReducedMotion(\"reduce\")",
  )
}

///|
test "Show MediaFeature - custom" {
  let s = MediaFeature::Custom("foo", Some(MediaValue::Number(1.0))).to_string()
  assert_true(s.contains("Custom("))
  assert_true(s.contains("\"foo\""))
  let s2 = MediaFeature::Custom("bar", None).to_string()
  assert_true(s2.contains("Custom("))
}

///|
test "Show MediaQuery and MediaQueryList" {
  let mq : MediaQuery = {
    negated: true,
    only: false,
    media_type: Some(MediaType::Screen),
    conditions: [MediaFeature::Color],
  }
  let s = mq.to_string()
  assert_true(s.contains("negated: true"))
  assert_true(s.contains("media_type: Some"))
  assert_true(s.contains("conditions: ["))
  let list : MediaQueryList = { queries: [mq] }
  let s2 = list.to_string()
  assert_true(s2.contains("queries: ["))
}

///|
test "parse_media_query_list - boolean features" {
  let mq = parse_media_query_list("(color)")
  inspect(mq.queries[0].conditions[0], content="Color")
  let mq2 = parse_media_query_list("(hover)")
  inspect(mq2.queries[0].conditions[0], content="Hover")
  let mq3 = parse_media_query_list("(grid)")
  inspect(mq3.queries[0].conditions[0], content="Grid")
  let mq4 = parse_media_query_list("(monochrome)")
  inspect(mq4.queries[0].conditions[0], content="Monochrome")
  let mq5 = parse_media_query_list("(scripting)")
  inspect(mq5.queries[0].conditions[0], content="Scripting")
  let mq6 = parse_media_query_list("(pointer)")
  inspect(mq6.queries[0].conditions[0], content="Pointer")
  let mq7 = parse_media_query_list("(update)")
  inspect(mq7.queries[0].conditions[0], content="Update")
}

///|
test "parse_media_query_list - range syntax operators" {
  let lt = parse_media_query_list("(width < 600px)")
  assert_true(lt.queries[0].conditions[0].to_string().contains("Lt"))
  let le = parse_media_query_list("(width <= 600px)")
  assert_true(le.queries[0].conditions[0].to_string().contains("Le"))
  let gt = parse_media_query_list("(width > 600px)")
  assert_true(gt.queries[0].conditions[0].to_string().contains("Gt"))
  let ge = parse_media_query_list("(width >= 600px)")
  assert_true(ge.queries[0].conditions[0].to_string().contains("Ge"))
  let eq = parse_media_query_list("(width = 600px)")
  assert_true(eq.queries[0].conditions[0].to_string().contains("Eq"))
}

///|
test "parse_media_query_list - height range" {
  let mq = parse_media_query_list("(height > 480px)")
  let s = mq.queries[0].conditions[0].to_string()
  assert_true(s.contains("HeightRange"))
}

///|
test "parse_media_query_list - resolution" {
  let dpi = parse_media_query_list("(min-resolution: 96dpi)")
  let s = dpi.queries[0].conditions[0].to_string()
  assert_true(s.contains("MinResolution"))
  let dppx = parse_media_query_list("(resolution: 2dppx)")
  let s2 = dppx.queries[0].conditions[0].to_string()
  assert_true(s2.contains("Resolution"))
}

///|
test "parse_media_query_list - aspect-ratio" {
  let mq = parse_media_query_list("(aspect-ratio: 16/9)")
  let s = mq.queries[0].conditions[0].to_string()
  assert_true(s.contains("AspectRatio"))
}

///|
test "parse_media_query_list - orientation parses both" {
  let portrait = parse_media_query_list("(orientation: portrait)")
  inspect(
    portrait.queries[0].conditions[0],
    content="Orientation(\"portrait\")",
  )
  let landscape = parse_media_query_list("(orientation: landscape)")
  inspect(
    landscape.queries[0].conditions[0],
    content="Orientation(\"landscape\")",
  )
}

///|
test "parse_media_query_list - prefers-reduced-motion" {
  let mq = parse_media_query_list("(prefers-reduced-motion: reduce)")
  inspect(
    mq.queries[0].conditions[0],
    content="PrefersReducedMotion(\"reduce\")",
  )
}

///|
test "parse_media_query_list - display-mode" {
  let mq = parse_media_query_list("(display-mode: standalone)")
  inspect(mq.queries[0].conditions[0], content="DisplayMode(\"standalone\")")
}

///|
test "parse_media_query_list - 'all' media type" {
  let mq = parse_media_query_list("all")
  debug_inspect(mq.queries[0].media_type, content="Some(All)")
}

///|
test "parse_media_query_list - empty input is empty list" {
  let mq = parse_media_query_list("")
  inspect(mq.is_empty(), content="true")
}

///|
test "parse_media_query_list - 'and' joins conditions" {
  let mq = parse_media_query_list(
    "screen and (min-width: 600px) and (max-width: 1200px)",
  )
  inspect(mq.queries.length(), content="1")
  inspect(mq.queries[0].conditions.length(), content="2")
}

///|
test "parse_media_query_list - unknown custom feature" {
  let mq = parse_media_query_list("(future-feature: 42)")
  let s = mq.queries[0].conditions[0].to_string()
  assert_true(s.contains("Custom"))
}

///|
test "parse_media_query_list - empty input list" {
  let mq = parse_media_query_list("  ")
  inspect(mq.is_empty(), content="true")
}

///|
test "parse_media_query_list - calc() arithmetic" {
  // calc(40rem + 1px) is 641px
  let mq = parse_media_query_list("(width >= calc(40rem + 1px))")
  let env_match = MediaEnvironment::new(641.0, 100.0)
  let env_miss = MediaEnvironment::new(640.0, 100.0)
  inspect(mq.evaluate(env_match), content="true")
  inspect(mq.evaluate(env_miss), content="false")
}

///|
test "parse_media_query_list - calc with multiplication" {
  let mq = parse_media_query_list("(min-width: calc(20rem * 2))")
  let env = MediaEnvironment::new(641.0, 100.0)
  inspect(mq.evaluate(env), content="true")
}

///|
test "parse_media_query_list - calc with division" {
  let mq = parse_media_query_list("(min-width: calc(640px / 2))")
  // 320px
  let env = MediaEnvironment::new(320.0, 100.0)
  inspect(mq.evaluate(env), content="true")
}

///|
test "parse_media_query_list - calc with subtraction" {
  let mq = parse_media_query_list("(min-width: calc(100px - 20px))")
  // 80px
  let env = MediaEnvironment::new(80.0, 100.0)
  inspect(mq.evaluate(env), content="true")
}

///|
test "parse_media_query_list - 'or' between groups" {
  // Already covered, but additional fallthrough
  let mq = parse_media_query_list(
    "(min-width: 800px) or (orientation: portrait)",
  )
  let big = MediaEnvironment::new(900.0, 100.0)
  let small_portrait = MediaEnvironment::new(400.0, 800.0)
  let small_landscape = MediaEnvironment::new(400.0, 100.0)
  inspect(mq.evaluate(big), content="true")
  inspect(mq.evaluate(small_portrait), content="true")
  inspect(mq.evaluate(small_landscape), content="false")
}

///|
test "parse_media_query_list - feature with non-Ident value goes to Custom" {
  // E.g. orientation expecting Ident but given Number falls into Custom branch
  let mq = parse_media_query_list("(orientation: 90)")
  let s = mq.queries[0].conditions[0].to_string()
  assert_true(s.contains("Custom") || s.contains("Orientation"))
}

///|
test "parse_media_query_list - 'not' prefix at start" {
  let mq = parse_media_query_list("not (max-width: 600px)")
  inspect(mq.queries[0].negated, content="true")
}

///|
test "parse_media_query_list - boolean monochrome and color-index" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq1 = parse_media_query_list("(monochrome)")
  inspect(mq1.evaluate(env), content="false")
  let mq2 = parse_media_query_list("(color-index)")
  inspect(mq2.evaluate(env), content="false")
  let mq3 = parse_media_query_list("(scripting)")
  inspect(mq3.evaluate(env), content="true")
  let mq4 = parse_media_query_list("(update)")
  inspect(mq4.evaluate(env), content="true")
}

///|
test "MediaValue - non-pixel values yield zero pixels" {
  // Ratio inside a min-width context: to_pixels returns 0
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MinWidth(MediaValue::Ratio(16, 9))],
  }
  // 800 >= 0 (ratio coerced to 0px) → true
  inspect(mq.evaluate(env), content="true")
  // Ident value: same
  let mq2 : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MinWidth(MediaValue::Ident("foo"))],
  }
  inspect(mq2.evaluate(env), content="true")
}
