///|
test "resolve custom properties handles nesting fallbacks and cycles" {
  let vars : Map[String, String] = {
    "--gap": "8px",
    "--pair": "var(--gap) 12px",
    "--empty": "",
    "--toggle": "var(--empty) var(--gap)",
    "--a": "var(--b)",
    "--b": "var(--a)",
  }
  debug_inspect(
    @computed.resolve_custom_property_value("calc(100% - var(--pair))", vars),
    content="Some(\"calc(100% - 8px 12px)\")",
  )
  debug_inspect(
    @computed.resolve_custom_property_value("var(--missing, var(--gap))", vars),
    content="Some(\"8px\")",
  )
  debug_inspect(
    @computed.resolve_custom_property_value("var(--a, blue)", vars),
    content="Some(\"blue\")",
  )
  debug_inspect(
    @computed.resolve_custom_property_value(
      "var(--toggle, var(--missing, 4px))", vars,
    ),
    content="Some(\" 8px\")",
  )
  debug_inspect(
    @computed.resolve_custom_property_value("var(--missing)", vars),
    content="None",
  )
}

///|
test "font size resolves same-element and inherited custom properties" {
  let same_element = @computed.compute_inline_raw(
    "--size: 18px; font-size: var(--size)",
    @computed.ComputeContext::new(),
  )
  inspect(same_element.font_size, content="18")

  let parent : @style.Style = { ..@style.Style::default(), font_size: 20.0 }
  let inherited_vars : Map[String, String] = { "--size": "1.25em" }
  let inherited = @computed.compute_inline_raw(
    "font-size: var(--size)",
    @computed.ComputeContext::with_parent_and_vars(parent, inherited_vars),
  )
  inspect(inherited.font_size, content="25")
}
