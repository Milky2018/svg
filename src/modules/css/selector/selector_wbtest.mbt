///|
test "Specificity::zero and add" {
  let zero = Specificity::zero()
  inspect(zero, content="(0,0,0)")
  let a : Specificity = { a: 1, b: 2, c: 3 }
  let b : Specificity = { a: 0, b: 1, c: 2 }
  let sum = a.add(b)
  inspect(sum, content="(1,3,5)")
}

///|
test "Specificity::compare_to" {
  let s1 : Specificity = { a: 0, b: 1, c: 0 }
  let s2 : Specificity = { a: 1, b: 0, c: 0 }
  let s3 : Specificity = { a: 0, b: 1, c: 5 }
  let s4 : Specificity = { a: 0, b: 1, c: 0 }
  assert_true(s1.compare_to(s2) < 0)
  assert_true(s2.compare_to(s1) > 0)
  assert_true(s3.compare_to(s1) > 0)
  inspect(s1.compare_to(s4), content="0")
}

///|
test "CompoundSelector constructors" {
  let type_sel = CompoundSelector::from_type("div")
  inspect(type_sel, content="div")
  let class_sel = CompoundSelector::from_class("primary")
  inspect(class_sel, content=".primary")
  let id_sel = CompoundSelector::from_id("main")
  inspect(id_sel, content="#main")
  let uni = CompoundSelector::universal()
  inspect(uni, content="*")
}

///|
test "ComplexSelector::simple" {
  let cs = ComplexSelector::simple(CompoundSelector::from_type("p"))
  inspect(cs, content="p")
}

///|
test "Show for SimpleSelector variants" {
  inspect(SimpleSelector::Type("div"), content="div")
  inspect(SimpleSelector::Universal, content="*")
  inspect(SimpleSelector::Id("main"), content="#main")
  inspect(SimpleSelector::Class("a"), content=".a")
}

///|
test "Show for AttributeSelector" {
  let s : AttributeSelector = {
    name: "href",
    match_type: AttributeMatch::Exists,
    case_insensitive: false,
    any_namespace: false,
  }
  inspect(s, content="[href]")
  let s2 : AttributeSelector = {
    name: "type",
    match_type: AttributeMatch::Exact("text"),
    case_insensitive: false,
    any_namespace: false,
  }
  inspect(s2, content="[type Exact(text)]")
  let s3 : AttributeSelector = {
    name: "lang",
    match_type: AttributeMatch::DashMatch("en"),
    case_insensitive: true,
    any_namespace: false,
  }
  inspect(s3, content="[lang DashMatch(en) i]")
}

///|
test "Show for AttributeMatch" {
  inspect(AttributeMatch::Exists, content="Exists")
  inspect(AttributeMatch::Exact("v"), content="Exact(v)")
  inspect(AttributeMatch::Includes("v"), content="Includes(v)")
  inspect(AttributeMatch::DashMatch("v"), content="DashMatch(v)")
  inspect(AttributeMatch::Prefix("v"), content="Prefix(v)")
  inspect(AttributeMatch::Suffix("v"), content="Suffix(v)")
  inspect(AttributeMatch::Substring("v"), content="Substring(v)")
}

///|
test "Show for PseudoClass" {
  inspect(PseudoClass::FirstChild, content=":first-child")
  inspect(PseudoClass::LastChild, content=":last-child")
  inspect(PseudoClass::OnlyChild, content=":only-child")
  inspect(PseudoClass::Root, content=":root")
  inspect(PseudoClass::Empty, content=":empty")
  inspect(PseudoClass::Hover, content=":hover")
  inspect(PseudoClass::Active, content=":active")
  inspect(PseudoClass::Focus, content=":focus")
  inspect(PseudoClass::FocusVisible, content=":focus-visible")
  inspect(PseudoClass::FocusWithin, content=":focus-within")
  inspect(PseudoClass::Link, content=":link")
  inspect(PseudoClass::Visited, content=":visited")
  inspect(PseudoClass::AnyLink, content=":any-link")
  inspect(PseudoClass::Enabled, content=":enabled")
  inspect(PseudoClass::Disabled, content=":disabled")
  inspect(PseudoClass::Checked, content=":checked")
  inspect(PseudoClass::Indeterminate, content=":indeterminate")
  inspect(PseudoClass::Required, content=":required")
  inspect(PseudoClass::Optional, content=":optional")
  inspect(PseudoClass::Valid, content=":valid")
  inspect(PseudoClass::Invalid, content=":invalid")
  inspect(PseudoClass::ReadOnly, content=":read-only")
  inspect(PseudoClass::ReadWrite, content=":read-write")
  inspect(PseudoClass::FirstOfType, content=":first-of-type")
  inspect(PseudoClass::LastOfType, content=":last-of-type")
  inspect(PseudoClass::OnlyOfType, content=":only-of-type")
  inspect(PseudoClass::State("loading"), content=":state(loading)")
  inspect(PseudoClass::NthChild({ a: 2, b: 1 }), content=":nth-child(2n+1)")
  inspect(
    PseudoClass::NthLastChild({ a: 0, b: 3 }),
    content=":nth-last-child(3)",
  )
  inspect(PseudoClass::NthOfType({ a: 1, b: 0 }), content=":nth-of-type(n)")
  inspect(
    PseudoClass::NthLastOfType({ a: -1, b: 2 }),
    content=":nth-last-of-type(-n+2)",
  )
  inspect(PseudoClass::Not([]), content=":not(...)")
  inspect(PseudoClass::Is([]), content=":is(...)")
  inspect(PseudoClass::Where([]), content=":where(...)")
  inspect(PseudoClass::Has([]), content=":has(...)")
}

///|
test "NthExpr Show edge cases" {
  inspect(NthExpr::{ a: 0, b: 5 }, content="5")
  inspect(NthExpr::{ a: 1, b: 0 }, content="n")
  inspect(NthExpr::{ a: 1, b: 3 }, content="n+3")
  inspect(NthExpr::{ a: 1, b: -2 }, content="n-2")
  inspect(NthExpr::{ a: -1, b: 4 }, content="-n+4")
  inspect(NthExpr::{ a: -1, b: -1 }, content="-n-1")
  inspect(NthExpr::{ a: 3, b: 0 }, content="3n")
  inspect(NthExpr::{ a: 3, b: 2 }, content="3n+2")
  inspect(NthExpr::{ a: 2, b: -1 }, content="2n-1")
}

///|
test "Show for PseudoElement" {
  inspect(PseudoElement::Before, content="::before")
  inspect(PseudoElement::After, content="::after")
  inspect(PseudoElement::FirstLine, content="::first-line")
  inspect(PseudoElement::FirstLetter, content="::first-letter")
  inspect(PseudoElement::Marker, content="::marker")
  inspect(PseudoElement::Placeholder, content="::placeholder")
  inspect(PseudoElement::Selection, content="::selection")
}

///|
test "Show for Combinator" {
  inspect(Combinator::Descendant, content=" ")
  inspect(Combinator::Child, content=" > ")
  inspect(Combinator::NextSibling, content=" + ")
  inspect(Combinator::SubsequentSibling, content=" ~ ")
}

///|
test "Show for ComplexSelector with combinators" {
  let cs = parse_selector_text("div > p.intro + span").unwrap()
  inspect(cs, content="div > p.intro + span")
}

///|
test "Show for ComplexSelector with descendant" {
  let cs = parse_selector_text("ul li a").unwrap()
  inspect(cs, content="ul li a")
}

///|
test "Show for ComplexSelector with subsequent sibling" {
  let cs = parse_selector_text("h2 ~ p").unwrap()
  inspect(cs, content="h2 ~ p")
}

///|
test "Show for CompoundSelector with multiple subclasses" {
  let cs = parse_selector_text("div.foo#bar:hover").unwrap()
  inspect(cs, content="div.foo#bar:hover")
}

///|
test "Show for SelectorList" {
  let list = parse_selector_list_text("h1, .title, #main").unwrap()
  inspect(list, content="h1, .title, #main")
}

///|
test "Element constructors and accessors" {
  let plain = Element::new("div")
  inspect(plain.tag_name, content="div")
  debug_inspect(plain.id, content="None")
  inspect(plain.classes.length(), content="0")
  let with_id = Element::with_id("section", "main")
  debug_inspect(with_id.id, content="Some(\"main\")")
  let with_classes = Element::with_classes("a", ["btn", "primary"])
  inspect(with_classes.classes.length(), content="2")
}

///|
test "Element::add_class, set_id, set_attribute, add_custom_state" {
  let e = Element::new("div")
    .set_id("hero")
    .add_class("card")
    .add_class("primary")
    .set_attribute("data-x", "1")
    .add_custom_state("open")
  debug_inspect(e.id, content="Some(\"hero\")")
  assert_true(e.has_class("card"))
  assert_true(e.has_class("primary"))
  assert_false(e.has_class("missing"))
  debug_inspect(e.get_attribute("data-x"), content="Some(\"1\")")
  debug_inspect(e.get_attribute("missing"), content="None")
  inspect(e.custom_states.length(), content="1")
}

///|
test "Element::is_first_child / is_last_child" {
  let first = Element::new("li").set_sibling_info(1, 5)
  assert_true(first.is_first_child())
  assert_false(first.is_last_child())
  let last = Element::new("li").set_sibling_info(5, 5)
  assert_false(last.is_first_child())
  assert_true(last.is_last_child())
}

///|
test "Element::set_parent" {
  let parent = Element::new("section").add_class("main")
  let child = Element::new("p").set_parent(parent)
  debug_inspect(child.parent is Some(_), content="true")
}

///|
test "SimpleSelector Show for Attribute variant" {
  let attr : AttributeSelector = {
    name: "type",
    match_type: AttributeMatch::Exact("button"),
    case_insensitive: false,
    any_namespace: false,
  }
  inspect(SimpleSelector::Attribute(attr), content="[type Exact(button)]")
}
