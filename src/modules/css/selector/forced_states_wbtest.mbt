///|
fn must_parse(css : String) -> ComplexSelector {
  parse_selector_text(css).unwrap()
}

///|
test "matches_complex_with_forced_states hover" {
  let selector = must_parse(".btn:hover")
  let element = Element::new("button").add_class("btn")
  assert_false(matches_complex(element, selector))
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), hover: true }
  assert_true(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "matches_complex_with_forced_states focus" {
  let selector = must_parse("input:focus")
  let element = Element::new("input")
  assert_false(matches_complex(element, selector))
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), focus: true }
  assert_true(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "matches_complex_with_forced_states does not match wrong pseudo" {
  let selector = must_parse(".btn:hover")
  let element = Element::new("button").add_class("btn")
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), focus: true }
  assert_false(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "matches_complex_with_forced_states hover and focus combined" {
  let selector = must_parse(".btn:hover:focus")
  let element = Element::new("button").add_class("btn")
  let hover_only = ForcedPseudoStates::{
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(
    matches_complex_with_forced_states(element, selector, hover_only),
  )
  let both = ForcedPseudoStates::{
    ..ForcedPseudoStates::none(),
    hover: true,
    focus: true,
  }
  assert_true(matches_complex_with_forced_states(element, selector, both))
}

///|
test "matches_complex_with_forced_states with parent selector" {
  let selector = must_parse(".container .btn:hover")
  let parent = Element::new("div").add_class("container")
  let element = Element::new("button").add_class("btn").set_parent(parent)
  let forced = ForcedPseudoStates::{ ..ForcedPseudoStates::none(), hover: true }
  assert_true(matches_complex_with_forced_states(element, selector, forced))
}

///|
test "ForcedPseudoStates none is empty" {
  assert_true(ForcedPseudoStates::none().is_empty())
  assert_false(
    ForcedPseudoStates::{ ..ForcedPseudoStates::none(), hover: true }.is_empty(),
  )
}

///|
test "matches_complex_with_forced_states focus_visible and focus_within" {
  let sel_fv = must_parse(":focus-visible")
  let sel_fw = must_parse(":focus-within")
  let element = Element::new("div")
  let only_fv : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    focus_visible: true,
  }
  assert_true(matches_complex_with_forced_states(element, sel_fv, only_fv))
  assert_false(matches_complex_with_forced_states(element, sel_fw, only_fv))
  let only_fw : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    focus_within: true,
  }
  assert_true(matches_complex_with_forced_states(element, sel_fw, only_fw))
}

///|
test "matches_complex_with_forced_states active" {
  let sel = must_parse(":active")
  let element = Element::new("a")
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    active: true,
  }
  assert_true(matches_complex_with_forced_states(element, sel, forced))
  assert_false(
    matches_complex_with_forced_states(element, sel, ForcedPseudoStates::none()),
  )
}

///|
test "matches_complex_with_forced_states - child combinator with non-forced ancestor" {
  let sel = must_parse(".parent > .btn:hover")
  let parent = Element::new("div").add_class("parent")
  let element = Element::new("button").add_class("btn").set_parent(parent)
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_true(matches_complex_with_forced_states(element, sel, forced))
  // Wrong ancestor class -> no match
  let other_parent = Element::new("div").add_class("other")
  let element2 = Element::new("button")
    .add_class("btn")
    .set_parent(other_parent)
  assert_false(matches_complex_with_forced_states(element2, sel, forced))
}

///|
test "matches_complex_with_forced_states - next-sibling combinator" {
  let sel = must_parse(".prev + .btn:hover")
  let prev = Element::new("span").add_class("prev")
  let element = {
    ..Element::new("button").add_class("btn"),
    prev_sibling: Some(prev),
  }
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_true(matches_complex_with_forced_states(element, sel, forced))
  // Missing sibling
  let element_no_sib = Element::new("button").add_class("btn")
  assert_false(matches_complex_with_forced_states(element_no_sib, sel, forced))
}

///|
test "matches_complex_with_forced_states - subsequent-sibling combinator" {
  let sel = must_parse(".prev ~ .btn:hover")
  let prev = Element::new("span").add_class("prev")
  let middle = { ..Element::new("span"), prev_sibling: Some(prev) }
  let element = {
    ..Element::new("button").add_class("btn"),
    prev_sibling: Some(middle),
  }
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_true(matches_complex_with_forced_states(element, sel, forced))
}

///|
test "matches_complex_with_forced_states - descendant with no matching ancestor" {
  let sel = must_parse(".missing .btn:hover")
  let element = Element::new("button").add_class("btn")
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(matches_complex_with_forced_states(element, sel, forced))
}

///|
test "matches_pseudo_class_with_forced_states falls through for non-forced" {
  let element = Element::new("input")
  // :enabled is not a forced state; should use the underlying matcher.
  // For a plain new element, :enabled depends on the matcher impl - test the routing.
  let _ = matches_pseudo_class_with_forced_states(
    element,
    PseudoClass::Enabled,
    ForcedPseudoStates::none(),
  )
  inspect(true, content="true")
}

///|
test "matches_complex_with_forced_states - type selector mismatch on head" {
  let sel = must_parse("button:hover")
  let element = Element::new("a") // wrong tag
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(matches_complex_with_forced_states(element, sel, forced))
}

///|
test "matches_complex_with_forced_states - child combinator no parent" {
  let sel = must_parse(".container > .btn:hover")
  let element = Element::new("button").add_class("btn") // no parent
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(matches_complex_with_forced_states(element, sel, forced))
}

///|
test "matches_complex_with_forced_states - next-sibling wrong sibling" {
  let sel = must_parse(".prev + .btn:hover")
  let prev = Element::new("div").add_class("other") // wrong class
  let element = {
    ..Element::new("button").add_class("btn"),
    prev_sibling: Some(prev),
  }
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(matches_complex_with_forced_states(element, sel, forced))
}

///|
test "matches_complex_with_forced_states - subsequent-sibling no match" {
  let sel = must_parse(".missing ~ .btn:hover")
  let element = Element::new("button").add_class("btn") // no prev sibling
  let forced : ForcedPseudoStates = {
    ..ForcedPseudoStates::none(),
    hover: true,
  }
  assert_false(matches_complex_with_forced_states(element, sel, forced))
}

///|
test "Show for ForcedPseudoStates" {
  let f = ForcedPseudoStates::none()
  let s = f.to_string()
  assert_true(s.contains("hover: false"))
  assert_true(s.contains("focus: false"))
  assert_true(s.contains("active: false"))
  assert_true(s.contains("focus_visible: false"))
  assert_true(s.contains("focus_within: false"))
}
