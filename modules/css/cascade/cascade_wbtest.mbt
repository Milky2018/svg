///|
test "cascade precedence - author normal" {
  let prec = cascade_precedence(Author, Normal)
  inspect(prec, content="3")
}

///|
test "cascade precedence - author important" {
  let prec = cascade_precedence(Author, Important)
  inspect(prec, content="4")
}

///|
test "cascade precedence - important beats normal" {
  let prec_normal = cascade_precedence(Author, Normal)
  let prec_important = cascade_precedence(Author, Important)
  assert_true(prec_important > prec_normal)
}

///|
test "cascade precedence - user-agent important highest" {
  let prec_ua_important = cascade_precedence(UserAgent, Important)
  let prec_user_important = cascade_precedence(User, Important)
  let prec_author_important = cascade_precedence(Author, Important)
  assert_true(prec_ua_important > prec_user_important)
  assert_true(prec_user_important > prec_author_important)
}

///|
test "compare declarations - same origin, different specificity" {
  let decl_low : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 1, }, // type selector
    source_order: 0,
  }
  let decl_high : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, }, // class selector
    source_order: 0,
  }
  // Higher specificity wins
  assert_true(compare_declarations(decl_high, decl_low) > 0)
}

///|
test "compare declarations - same specificity, different source order" {
  let decl_first : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, },
    source_order: 1,
  }
  let decl_second : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, },
    source_order: 2,
  }
  // Later source order wins
  assert_true(compare_declarations(decl_second, decl_first) > 0)
}

///|
test "compare declarations - important beats normal" {
  let decl_normal : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 1, b: 0, c: 0, }, // ID selector
    source_order: 10,
  }
  let decl_important : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Important,
    specificity: { a: 0, b: 0, c: 1, }, // type selector
    source_order: 1,
  }
  // Important beats even higher specificity and later source order
  assert_true(compare_declarations(decl_important, decl_normal) > 0)
}

///|
test "cascade - single declaration" {
  let decl = Declaration::new("width", "100px")
  let result = cascade([decl])
  debug_inspect(result.get_value("width"), content="Some(\"100px\")")
}

///|
test "cascade - later declaration wins" {
  let decl1 : Declaration = {
    property: "width",
    value: Value("100px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, },
    source_order: 1,
  }
  let decl2 : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, },
    source_order: 2,
  }
  let result = cascade([decl1, decl2])
  debug_inspect(result.get_value("width"), content="Some(\"200px\")")
}

///|
test "cascade - higher specificity wins" {
  let decl_type : Declaration = {
    property: "color",
    value: Value("red"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 1, },
    source_order: 2,
  }
  let decl_class : Declaration = {
    property: "color",
    value: Value("blue"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, },
    source_order: 1,
  }
  let result = cascade([decl_type, decl_class])
  // Class wins over type even though type is later
  debug_inspect(result.get_value("color"), content="Some(\"blue\")")
}

///|
test "cascade - important wins" {
  let decl_normal : Declaration = {
    property: "display",
    value: Value("block"),
    origin: Author,
    importance: Normal,
    specificity: { a: 1, b: 0, c: 0, },
    source_order: 10,
  }
  let decl_important : Declaration = {
    property: "display",
    value: Value("flex"),
    origin: Author,
    importance: Important,
    specificity: { a: 0, b: 0, c: 1, },
    source_order: 1,
  }
  let result = cascade([decl_normal, decl_important])
  debug_inspect(result.get_value("display"), content="Some(\"flex\")")
}

///|
test "cascade - multiple properties" {
  let decl1 = Declaration::new("width", "100px")
  let decl2 = Declaration::new("height", "50px")
  let decl3 : Declaration = {
    property: "width",
    value: Value("200px"),
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 1, c: 0, },
    source_order: 1,
  }
  let result = cascade([decl1, decl2, decl3])
  debug_inspect(result.get_value("width"), content="Some(\"200px\")")
  debug_inspect(result.get_value("height"), content="Some(\"50px\")")
}

///|
test "cascaded values - has property" {
  let decl = Declaration::new("margin", "10px")
  let result = cascade([decl])
  inspect(result.has("margin"), content="true")
  inspect(result.has("padding"), content="false")
}

///|
test "cascaded values - properties list" {
  let decl1 = Declaration::new("width", "100px")
  let decl2 = Declaration::new("height", "50px")
  let result = cascade([decl1, decl2])
  let props = result.properties()
  inspect(props.length(), content="2")
}

///|
test "declaration from inline" {
  let decl = Declaration::from_inline("width", "100px", Normal)
  inspect(decl.origin, content="Author")
  // Inline has high specificity
  assert_true(decl.specificity.a >= 1)
}

///|
fn collect_declarations_for_test(
  matches : Array[RuleMatch],
  inline_style : Array[Declaration],
) -> Array[Declaration] {
  let result : Array[Declaration] = []
  for rule_match in matches {
    for decl in rule_match.declarations {
      result.push(decl)
    }
  }
  for decl in inline_style {
    result.push({
      property: decl.property,
      value: decl.value,
      origin: Author,
      importance: decl.importance,
      specificity: { a: 1000, b: 0, c: 0, },
      source_order: decl.source_order,
    })
  }
  result
}

///|
test "collect declarations - inline beats rules" {
  let rule_match : RuleMatch = {
    specificity: { a: 1, b: 0, c: 0, }, // ID selector
    declarations: [Declaration::new("width", "100px")],
    source_order: 1,
  }
  let inline = [Declaration::from_inline("width", "200px", Normal)]
  let collected = collect_declarations_for_test([rule_match], inline)
  let result = cascade(collected)

  // Inline should win
  debug_inspect(result.get_value("width"), content="Some(\"200px\")")
}

///|
test "stylesheet match and cascade" {
  // Create a simple stylesheet
  let stylesheet = Stylesheet::new(Author)

  // Parse a selector
  let sel = @selector.parse_selector_text("div.foo")
  match sel {
    Some(selector) =>
      stylesheet.add_rule("div.foo", selector, [
        Declaration::new("width", "100px"),
      ])
    None => fail("failed to parse selector")
  }

  // Create an element that matches
  let element = @selector.Element::new("div").add_class("foo")

  // Match and cascade
  let result = cascade_element(element, [stylesheet], [])
  debug_inspect(result.get_value("width"), content="Some(\"100px\")")
}

///|
test "stylesheet - non-matching element" {
  let stylesheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div.bar")
  match sel {
    Some(selector) =>
      stylesheet.add_rule("div.bar", selector, [
        Declaration::new("width", "100px"),
      ])
    None => fail("failed to parse selector")
  }

  // Create an element that doesn't match
  let element = @selector.Element::new("div").add_class("foo")
  let result = cascade_element(element, [stylesheet], [])
  inspect(result.has("width"), content="false")
}

///|
test "multiple stylesheets" {
  let ua_stylesheet = Stylesheet::new(UserAgent)
  let author_stylesheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div")
  match sel {
    Some(selector) => {
      // UA sets width: 0
      ua_stylesheet.add_rule("div", selector, [Declaration::new("width", "0")])
      // Author sets width: 100px
      author_stylesheet.add_rule("div", selector, [
        Declaration::new("width", "100px"),
      ])
    }
    None => fail("failed to parse selector")
  }
  let element = @selector.Element::new("div")
  let result = cascade_element(element, [ua_stylesheet, author_stylesheet], [])

  // Author beats UA
  debug_inspect(result.get_value("width"), content="Some(\"100px\")")
}

///|
test "later author stylesheet wins at same specificity" {
  let stylesheet1 = Stylesheet::new(Author)
  let stylesheet2 = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div")
  match sel {
    Some(selector) => {
      stylesheet1.add_rule("div", selector, [Declaration::new("width", "10px")])
      stylesheet2.add_rule("div", selector, [Declaration::new("width", "20px")])
    }
    None => fail("failed to parse selector")
  }
  let element = @selector.Element::new("div")
  let result = cascade_element(element, [stylesheet1, stylesheet2], [])
  debug_inspect(result.get_value("width"), content="Some(\"20px\")")
}

///|
test "later indexed stylesheet wins at same specificity" {
  let stylesheet1 = Stylesheet::new(Author)
  let stylesheet2 = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div")
  match sel {
    Some(selector) => {
      stylesheet1.add_rule("div", selector, [Declaration::new("width", "10px")])
      stylesheet2.add_rule("div", selector, [Declaration::new("width", "20px")])
    }
    None => fail("failed to parse selector")
  }
  let element = @selector.Element::new("div")
  let result = cascade_element_indexed(
    element,
    [IndexedStylesheet::new(stylesheet1), IndexedStylesheet::new(stylesheet2)],
    [],
    None,
  )
  debug_inspect(result.get_value("width"), content="Some(\"20px\")")
}

///|
test "specificity - ID beats class" {
  let stylesheet = Stylesheet::new(Author)

  // Class selector (0,1,0)
  let class_sel = @selector.parse_selector_text(".container")
  match class_sel {
    Some(selector) =>
      stylesheet.add_rule(".container", selector, [
        Declaration::new("width", "100px"),
      ])
    None => fail("failed to parse class selector")
  }

  // ID selector (1,0,0)
  let id_sel = @selector.parse_selector_text("#main")
  match id_sel {
    Some(selector) =>
      stylesheet.add_rule("#main", selector, [
        Declaration::new("width", "200px"),
      ])
    None => fail("failed to parse id selector")
  }

  // Element with both class and id
  let element = @selector.Element::new("div")
    .set_id("main")
    .add_class("container")
  let result = cascade_element(element, [stylesheet], [])

  // ID selector should win (higher specificity)
  debug_inspect(result.get_value("width"), content="Some(\"200px\")")
}

///|
test "specificity - combined selectors" {
  let stylesheet = Stylesheet::new(Author)

  // Type selector (0,0,1)
  let type_sel = @selector.parse_selector_text("div")
  match type_sel {
    Some(selector) =>
      stylesheet.add_rule("div", selector, [Declaration::new("color", "red")])
    None => fail("failed to parse type selector")
  }

  // Class + type selector (0,1,1)
  let class_type_sel = @selector.parse_selector_text("div.highlight")
  match class_type_sel {
    Some(selector) =>
      stylesheet.add_rule("div.highlight", selector, [
        Declaration::new("color", "blue"),
      ])
    None => fail("failed to parse class+type selector")
  }

  // Element with class
  let element = @selector.Element::new("div").add_class("highlight")
  let result = cascade_element(element, [stylesheet], [])

  // div.highlight (0,1,1) should beat div (0,0,1)
  debug_inspect(result.get_value("color"), content="Some(\"blue\")")
}

///|
test "cascade order - later declaration wins at same specificity" {
  let stylesheet = Stylesheet::new(Author)

  // First rule
  let sel1 = @selector.parse_selector_text(".box")
  match sel1 {
    Some(selector) =>
      stylesheet.add_rule(".box", selector, [Declaration::new("width", "100px")])
    None => fail("failed to parse selector")
  }

  // Second rule with same specificity but later
  let sel2 = @selector.parse_selector_text(".container")
  match sel2 {
    Some(selector) =>
      stylesheet.add_rule(".container", selector, [
        Declaration::new("width", "200px"),
      ])
    None => fail("failed to parse selector")
  }

  // Element with both classes
  let element = @selector.Element::new("div")
    .add_class("box")
    .add_class("container")
  let result = cascade_element(element, [stylesheet], [])

  // Later declaration should win
  debug_inspect(result.get_value("width"), content="Some(\"200px\")")
}

///|
test "pseudo-class :not() specificity" {
  let stylesheet = Stylesheet::new(Author)

  // Simple class (0,1,0)
  let class_sel = @selector.parse_selector_text(".item")
  match class_sel {
    Some(selector) =>
      stylesheet.add_rule(".item", selector, [Declaration::new("color", "red")])
    None => fail("failed to parse class selector")
  }

  // :not(.hidden) with .item (0,2,0 - :not contributes its argument's specificity)
  let not_sel = @selector.parse_selector_text(".item:not(.hidden)")
  match not_sel {
    Some(selector) =>
      stylesheet.add_rule(".item:not(.hidden)", selector, [
        Declaration::new("color", "green"),
      ])
    None => fail("failed to parse :not selector")
  }

  // Element with class="item" (not hidden)
  let element = @selector.Element::new("div").add_class("item")
  let result = cascade_element(element, [stylesheet], [])

  // :not(.hidden) specificity = 0,2,0 (class + :not argument's class)
  debug_inspect(result.get_value("color"), content="Some(\"green\")")
}

///|
test "pseudo-class :where() has zero specificity" {
  let stylesheet = Stylesheet::new(Author)

  // :where(.container) has zero specificity
  let where_sel = @selector.parse_selector_text(":where(.container)")
  match where_sel {
    Some(selector) =>
      stylesheet.add_rule(":where(.container)", selector, [
        Declaration::new("color", "red"),
      ])
    None => fail("failed to parse :where selector")
  }

  // Simple type selector (0,0,1) - should beat :where()
  let type_sel = @selector.parse_selector_text("div")
  match type_sel {
    Some(selector) =>
      stylesheet.add_rule("div", selector, [Declaration::new("color", "blue")])
    None => fail("failed to parse type selector")
  }
  let element = @selector.Element::new("div").add_class("container")
  let result = cascade_element(element, [stylesheet], [])

  // div (0,0,1) should beat :where(.container) (0,0,0)
  debug_inspect(result.get_value("color"), content="Some(\"blue\")")
}

///|
test "Show impls for Origin, Importance, PropertyValue, Declaration" {
  inspect(Origin::UserAgent, content="UserAgent")
  inspect(Origin::User, content="User")
  inspect(Origin::Author, content="Author")
  inspect(Importance::Normal, content="Normal")
  inspect(Importance::Important, content="Important")
  inspect(PropertyValue::Value("flex"), content="Value(flex)")
  inspect(PropertyValue::Inherit, content="inherit")
  inspect(PropertyValue::Initial, content="initial")
  inspect(PropertyValue::Unset, content="unset")
  inspect(PropertyValue::Revert, content="revert")
  inspect(PropertyValue::RevertLayer, content="revert-layer")
  let decl_normal = Declaration::new("color", "red")
  inspect(decl_normal, content="color: Value(red)")
  let decl_imp = Declaration::from_inline("color", "red", Important)
  inspect(decl_imp, content="color: Value(red) !important")
}

///|
test "CSS-wide keywords retain their cascade meaning" {
  inspect(PropertyValue::from_css_text("inherit"), content="inherit")
  inspect(PropertyValue::from_css_text(" INITIAL "), content="initial")
  inspect(PropertyValue::from_css_text("unset"), content="unset")
  inspect(PropertyValue::from_css_text("revert"), content="revert")
  inspect(PropertyValue::from_css_text("revert-layer"), content="revert-layer")
  inspect(
    PropertyValue::from_css_text("calc(1 + 2)"),
    content="Value(calc(1 + 2))",
  )
}

///|
test "Declaration::with_metadata" {
  let spec : @selector.Specificity = { a: 1, b: 2, c: 3, }
  let d = Declaration::with_metadata(
    "padding",
    Inherit,
    User,
    Important,
    spec,
    42,
  )
  inspect(d.property, content="padding")
  inspect(d.source_order, content="42")
  inspect(d.origin, content="User")
  inspect(d.importance, content="Important")
}

///|
test "cascade precedence covers every origin/importance combo" {
  inspect(cascade_precedence(UserAgent, Normal), content="1")
  inspect(cascade_precedence(User, Normal), content="2")
  inspect(cascade_precedence(Author, Normal), content="3")
  inspect(cascade_precedence(Author, Important), content="4")
  inspect(cascade_precedence(User, Important), content="5")
  inspect(cascade_precedence(UserAgent, Important), content="6")
}

///|
test "CascadedValues::each and properties" {
  let result = cascade([
    Declaration::new("width", "100px"),
    Declaration::new("height", "50px"),
  ])
  let collected : Array[String] = []
  result.each(fn(k, _v) { collected.push(k) })
  inspect(collected.length(), content="2")
  let props = result.properties()
  inspect(props.length(), content="2")
}

///|
test "CascadedValues::get_value returns None for non-Value (keyword)" {
  let decl : Declaration = {
    property: "color",
    value: Inherit,
    origin: Author,
    importance: Normal,
    specificity: { a: 0, b: 0, c: 0, },
    source_order: 0,
  }
  let result = cascade([decl])
  assert_true(result.has("color"))
  debug_inspect(result.get_value("color"), content="None")
}

///|
test "SelectorIndex - empty" {
  let idx = SelectorIndex::new()
  let element = @selector.Element::new("div").add_class("foo").set_id("bar")
  inspect(idx.get_candidates(element).length(), content="0")
}

///|
test "SelectorIndex::from_stylesheet partitions by primary key" {
  let sheet = Stylesheet::new(Author)
  // ID selector
  let id_sel = @selector.parse_selector_text("#main").unwrap()
  sheet.add_rule("#main", id_sel, [Declaration::new("width", "100px")])
  // Class selector
  let cls_sel = @selector.parse_selector_text(".card").unwrap()
  sheet.add_rule(".card", cls_sel, [Declaration::new("padding", "8px")])
  // Tag selector
  let tag_sel = @selector.parse_selector_text("div").unwrap()
  sheet.add_rule("div", tag_sel, [Declaration::new("display", "block")])
  // Universal selector
  let uni_sel = @selector.parse_selector_text("*").unwrap()
  sheet.add_rule("*", uni_sel, [Declaration::new("box-sizing", "border-box")])
  let idx = SelectorIndex::from_stylesheet(sheet)
  inspect(idx.by_id.length(), content="1")
  inspect(idx.by_class.length(), content="1")
  inspect(idx.by_tag.length(), content="1")
  inspect(idx.universal.length(), content="1")
}

///|
test "SelectorIndex::get_candidates returns ID + tag + universal" {
  let sheet = Stylesheet::new(Author)
  let id_sel = @selector.parse_selector_text("#main").unwrap()
  sheet.add_rule("#main", id_sel, [Declaration::new("width", "100px")])
  let tag_sel = @selector.parse_selector_text("div").unwrap()
  sheet.add_rule("div", tag_sel, [Declaration::new("display", "block")])
  let uni_sel = @selector.parse_selector_text("*").unwrap()
  sheet.add_rule("*", uni_sel, [Declaration::new("box-sizing", "border-box")])
  let idx = SelectorIndex::from_stylesheet(sheet)
  let element = @selector.Element::new("div").set_id("main")
  // ID + tag + universal = 3 candidates
  inspect(idx.get_candidates(element).length(), content="3")
}

///|
test "SelectorIndex - non-matching element gets only universal" {
  let sheet = Stylesheet::new(Author)
  let cls_sel = @selector.parse_selector_text(".card").unwrap()
  sheet.add_rule(".card", cls_sel, [Declaration::new("padding", "8px")])
  let uni_sel = @selector.parse_selector_text("*").unwrap()
  sheet.add_rule("*", uni_sel, [Declaration::new("box-sizing", "border-box")])
  let idx = SelectorIndex::from_stylesheet(sheet)
  let element = @selector.Element::new("p") // no class, no id
  let candidates = idx.get_candidates(element)
  inspect(candidates.length(), content="1")
}

///|
test "IndexedStylesheet::match_element with no media env" {
  let sheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text(".card").unwrap()
  sheet.add_rule(".card", sel, [Declaration::new("padding", "8px")])
  let indexed = IndexedStylesheet::new(sheet)
  let element = @selector.Element::with_classes("div", ["card"])
  let matches = indexed.match_element(element)
  inspect(matches.length(), content="1")
}

///|
test "IndexedStylesheet::match_element_with_media gates by media query" {
  let sheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text(".card").unwrap()
  let mq = @media.parse_media_query_list("(min-width: 800px)")
  sheet.add_rule_with_media(
    ".card",
    sel,
    [Declaration::new("padding", "16px")],
    mq,
  )
  let indexed = IndexedStylesheet::new(sheet)
  let element = @selector.Element::with_classes("div", ["card"])
  let big = @media.MediaEnvironment::new(1024.0, 768.0)
  let small = @media.MediaEnvironment::new(400.0, 768.0)
  inspect(
    indexed.match_element_with_media(element, Some(big)).length(),
    content="1",
  )
  inspect(
    indexed.match_element_with_media(element, Some(small)).length(),
    content="0",
  )
}

///|
test "Stylesheet::match_element_with_media gates by media query" {
  let sheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text(".card").unwrap()
  let mq = @media.parse_media_query_list("(min-width: 800px)")
  sheet.add_rule_with_media(
    ".card",
    sel,
    [Declaration::new("padding", "16px")],
    mq,
  )
  let element = @selector.Element::with_classes("div", ["card"])
  let big = @media.MediaEnvironment::new(1024.0, 768.0)
  let small = @media.MediaEnvironment::new(400.0, 768.0)
  inspect(
    sheet.match_element_with_media(element, Some(big)).length(),
    content="1",
  )
  inspect(
    sheet.match_element_with_media(element, Some(small)).length(),
    content="0",
  )
  // No env -> always matches
  inspect(sheet.match_element_with_media(element, None).length(), content="1")
}

///|
test "Stylesheet::match_element exposes the array" {
  let sheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text(".card").unwrap()
  sheet.add_rule(".card", sel, [Declaration::new("padding", "8px")])
  let element = @selector.Element::with_classes("div", ["card"])
  let matches = sheet.match_element(element)
  inspect(matches.length(), content="1")
}

///|
test "cascade_element_with_media applies inline declarations" {
  let element = @selector.Element::new("div")
  let inline = [
    Declaration::from_inline("color", "red", Normal),
    Declaration::from_inline("display", "flex", Normal),
  ]
  let result = cascade_element_with_media(element, [], inline, None)
  debug_inspect(result.get_value("color"), content="Some(\"red\")")
  debug_inspect(result.get_value("display"), content="Some(\"flex\")")
}

///|
test "cascade_element_indexed applies inline declarations" {
  let element = @selector.Element::new("div")
  let inline = [Declaration::from_inline("color", "blue", Normal)]
  let result = cascade_element_indexed(element, [], inline, None)
  debug_inspect(result.get_value("color"), content="Some(\"blue\")")
}

///|
test "indexed cascade rejects non-matching candidate (full selector check)" {
  // Rule's head class is in the index, but the descendant constraint
  // fails — must hit the rejection branch inside push_rule_match.
  let sheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text(".parent > .child").unwrap()
  sheet.add_rule(".parent > .child", sel, [Declaration::new("color", "red")])
  // Element has class "child" (matches head) but no parent.
  let element = @selector.Element::new("div").add_class("child")
  let result = cascade_element(element, [sheet], [])
  inspect(result.has("color"), content="false")
}

///|
test "SelectorIndex - by_id deduplicates rules with same id" {
  let sheet = Stylesheet::new(Author)
  let s1 = @selector.parse_selector_text("#main").unwrap()
  sheet.add_rule("#main", s1, [Declaration::new("color", "red")])
  let s2 = @selector.parse_selector_text("#main").unwrap()
  sheet.add_rule("#main", s2, [Declaration::new("color", "blue")])
  let idx = SelectorIndex::from_stylesheet(sheet)
  match idx.by_id.get("main") {
    Some(arr) => inspect(arr.length(), content="2")
    None => fail("expected #main bucket")
  }
}

///|
test "SelectorIndex - by_class deduplicates rules with same class" {
  let sheet = Stylesheet::new(Author)
  let s1 = @selector.parse_selector_text(".card").unwrap()
  sheet.add_rule(".card", s1, [Declaration::new("color", "red")])
  let s2 = @selector.parse_selector_text(".card").unwrap()
  sheet.add_rule(".card", s2, [Declaration::new("color", "blue")])
  let idx = SelectorIndex::from_stylesheet(sheet)
  match idx.by_class.get("card") {
    Some(arr) => inspect(arr.length(), content="2")
    None => fail("expected .card bucket")
  }
}

///|
test "SelectorIndex - by_tag deduplicates rules with same tag" {
  let sheet = Stylesheet::new(Author)
  let s1 = @selector.parse_selector_text("div").unwrap()
  sheet.add_rule("div", s1, [Declaration::new("color", "red")])
  let s2 = @selector.parse_selector_text("div").unwrap()
  sheet.add_rule("div", s2, [Declaration::new("color", "blue")])
  let idx = SelectorIndex::from_stylesheet(sheet)
  match idx.by_tag.get("div") {
    Some(arr) => inspect(arr.length(), content="2")
    None => fail("expected div bucket")
  }
}

///|
test "indexed stylesheet matches compound class selector" {
  let stylesheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text("div.foo.bar")
  match sel {
    Some(selector) =>
      stylesheet.add_rule("div.foo.bar", selector, [
        Declaration::new("width", "100px"),
      ])
    None => fail("failed to parse selector")
  }
  let element = @selector.Element::new("div").add_class("foo").add_class("bar")
  let result = cascade_element_indexed(
    element,
    [IndexedStylesheet::new(stylesheet)],
    [],
    None,
  )
  debug_inspect(result.get_value("width"), content="Some(\"100px\")")
}
