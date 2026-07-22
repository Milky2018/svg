///|
fn make_button_stylesheet(origin : Origin) -> Stylesheet {
  let stylesheet = Stylesheet::new(origin)
  let base = @selector.parse_selector_text(".btn").unwrap()
  stylesheet.add_rule(".btn", base, [
    Declaration::new("background-color", "white"),
    Declaration::new("color", "black"),
  ])
  let hover = @selector.parse_selector_text(".btn:hover").unwrap()
  stylesheet.add_rule(".btn:hover", hover, [
    Declaration::new("background-color", "blue"),
  ])
  let focus = @selector.parse_selector_text(".btn:focus").unwrap()
  stylesheet.add_rule(".btn:focus", focus, [
    Declaration::new("outline", "2px solid red"),
  ])
  let active = @selector.parse_selector_text(".btn:active").unwrap()
  stylesheet.add_rule(".btn:active", active, [
    Declaration::new("background-color", "darkblue"),
  ])
  stylesheet
}

///|
test "cascade_element_with_forced_states - none means base only" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let stylesheet = make_button_stylesheet(Author)
  let result = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    None,
    @selector.ForcedPseudoStates::none(),
  )
  debug_inspect(result.get_value("background-color"), content="Some(\"white\")")
  inspect(result.has("outline"), content="false")
}

///|
test "cascade_element_with_forced_states - hover activates :hover rules" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let stylesheet = make_button_stylesheet(Author)
  let forced : @selector.ForcedPseudoStates = {
    hover: true,
    focus: false,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
  let result = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    None,
    forced,
  )
  debug_inspect(result.get_value("background-color"), content="Some(\"blue\")")
}

///|
test "cascade_element_with_forced_states - active overrides hover (later wins)" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let stylesheet = make_button_stylesheet(Author)
  let forced : @selector.ForcedPseudoStates = {
    hover: true,
    focus: false,
    active: true,
    focus_visible: false,
    focus_within: false,
  }
  let result = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    None,
    forced,
  )
  // :active rule comes after :hover in source order
  debug_inspect(
    result.get_value("background-color"),
    content="Some(\"darkblue\")",
  )
}

///|
test "cascade_element_with_forced_states - focus enables :focus rules" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let stylesheet = make_button_stylesheet(Author)
  let forced : @selector.ForcedPseudoStates = {
    hover: false,
    focus: true,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
  let result = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    None,
    forced,
  )
  debug_inspect(result.get_value("outline"), content="Some(\"2px solid red\")")
}

///|
test "cascade_element_with_forced_states - inline style still applies on top" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let stylesheet = make_button_stylesheet(Author)
  let forced : @selector.ForcedPseudoStates = {
    hover: true,
    focus: false,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
  let inline = [Declaration::from_inline("background-color", "yellow", Normal)]
  let result = cascade_element_with_forced_states(
    element,
    [stylesheet],
    inline,
    None,
    forced,
  )
  debug_inspect(
    result.get_value("background-color"),
    content="Some(\"yellow\")",
  )
}

///|
test "cascade_element_with_forced_states - multiple stylesheets, later wins" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let sheet_a = Stylesheet::new(Author)
  let sel_a = @selector.parse_selector_text(".btn:hover").unwrap()
  sheet_a.add_rule(".btn:hover", sel_a, [Declaration::new("color", "blue")])
  let sheet_b = Stylesheet::new(Author)
  let sel_b = @selector.parse_selector_text(".btn:hover").unwrap()
  sheet_b.add_rule(".btn:hover", sel_b, [Declaration::new("color", "red")])
  let forced : @selector.ForcedPseudoStates = {
    hover: true,
    focus: false,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
  let result = cascade_element_with_forced_states(
    element,
    [sheet_a, sheet_b],
    [],
    None,
    forced,
  )
  debug_inspect(result.get_value("color"), content="Some(\"red\")")
}

///|
test "cascade_element_with_forced_states - media query gates rule" {
  let element = @selector.Element::with_classes("button", ["btn"])
  let stylesheet = Stylesheet::new(Author)
  let sel = @selector.parse_selector_text(".btn:hover").unwrap()
  let mq = @media.parse_media_query_list("(min-width: 800px)")
  stylesheet.add_rule_with_media(
    ".btn:hover",
    sel,
    [Declaration::new("color", "purple")],
    mq,
  )
  let forced : @selector.ForcedPseudoStates = {
    hover: true,
    focus: false,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
  // Without media env, no gating -> rule applies
  let result_no_env = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    None,
    forced,
  )
  debug_inspect(result_no_env.get_value("color"), content="Some(\"purple\")")
  // With matching environment -> rule applies
  let env_match = @media.MediaEnvironment::new(1024.0, 768.0)
  let result_match = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    Some(env_match),
    forced,
  )
  debug_inspect(result_match.get_value("color"), content="Some(\"purple\")")
  // With non-matching environment -> rule does not apply
  let env_small = @media.MediaEnvironment::new(400.0, 768.0)
  let result_small = cascade_element_with_forced_states(
    element,
    [stylesheet],
    [],
    Some(env_small),
    forced,
  )
  inspect(result_small.has("color"), content="false")
}

///|
test "ForcedPseudoStates - none and is_empty" {
  let none_state = @selector.ForcedPseudoStates::none()
  assert_true(none_state.is_empty())
  let with_hover : @selector.ForcedPseudoStates = { ..none_state, hover: true }
  assert_false(with_hover.is_empty())
}
