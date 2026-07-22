///|
fn css_is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn parse_embedded_stylesheets(
  events : Array[@xml.Event],
) -> Array[@css_cascade.Stylesheet] {
  let stylesheets : Array[@css_cascade.Stylesheet] = []
  let content = StringBuilder::new()
  let mut in_style = false
  for event in events {
    match event {
      Start(element) =>
        if element.name == "style" {
          content.reset()
          in_style = true
        }
      Empty(element) =>
        if element.name == "style" {
          stylesheets.push(@css.parse_stylesheet(""))
        }
      Text(text) | CData(text) =>
        if in_style {
          content.write_string(text)
        }
      End(name) =>
        if in_style && name == "style" {
          stylesheets.push(
            @css.parse_stylesheet(trim_string(content.to_string())),
          )
          in_style = false
        }
      _ => ()
    }
  }
  stylesheets
}

///|
fn split_class_names(value : String) -> Array[String] {
  let result : Array[String] = []
  let mut start = -1
  for i in 0..<=value.length() {
    let whitespace = i == value.length() ||
      css_is_whitespace(Int::unsafe_to_char(value[i].to_int()))
    if whitespace {
      if start >= 0 {
        result.push(build_substring(value, start, i))
        start = -1
      }
    } else if start < 0 {
      start = i
    }
  }
  result
}

///|
fn style_element(
  tag : String,
  attrs : Array[(String, String)],
  parent : @css_selector.Element?,
  previous_sibling : @css_selector.Element?,
  sibling_index : Int,
  sibling_count : Int,
) -> @css_selector.Element {
  let mut element = @css_selector.Element::new(tag.to_lower())
  for attr in attrs {
    element = element.set_attribute(attr.0, attr.1)
    if attr.0 == "id" {
      element = element.set_id(attr.1)
    } else if attr.0 == "class" {
      for class_name in split_class_names(attr.1) {
        element = element.add_class(class_name)
      }
    }
  }
  element = element.set_sibling_info(sibling_index, sibling_count)
  match previous_sibling {
    Some(previous) => element = { ..element, prev_sibling: Some(previous) }
    None => ()
  }
  match parent {
    Some(parent) => element.set_parent(parent)
    None => element
  }
}

///|
fn declarations_from_css_body(
  value : String,
) -> Array[@css_cascade.Declaration] {
  let stylesheet = @css.parse_stylesheet("* {" + value + "}")
  if stylesheet.rules.length() == 0 {
    []
  } else {
    stylesheet.rules[0].declarations
  }
}

///|
fn presentation_stylesheet(
  attrs : Array[(String, String)],
) -> @css_cascade.Stylesheet? {
  let declarations : Array[@css_cascade.Declaration] = []
  for attr in attrs {
    let name = attr.0
    if name == name.to_lower() && is_computed_style_property(name) {
      declarations.push(
        @css_cascade.Declaration::new(name, trim_string(attr.1)),
      )
    }
  }
  if declarations.length() == 0 {
    return None
  }
  let selector = match @css.parse_selector("*") {
    Some(selector) => selector
    None => return None
  }
  let stylesheet = @css_cascade.Stylesheet::new(Author)
  stylesheet.add_rule("*", selector, declarations)
  Some(stylesheet)
}

///|
fn inline_declarations(
  attrs : Array[(String, String)],
) -> Array[@css_cascade.Declaration] {
  match get_attr(attrs, "style") {
    Some(value) => declarations_from_css_body(value)
    None => []
  }
}

///|
fn parse_inline_style_declarations(value : String) -> Array[StyleDeclaration] {
  cascaded_style_declarations(
    @css.cascade_declarations(declarations_from_css_body(value)),
  )
}

///|
fn inline_style_value(value : String, name : String) -> String? {
  find_winning_declaration(parse_inline_style_declarations(value), name).map(fn(
    declaration,
  ) {
    declaration.value
  })
}

///|
fn cascade_element_styles(
  stylesheets : Array[@css_cascade.Stylesheet],
  element : @css_selector.Element,
  attrs : Array[(String, String)],
  media_environment : @css_media.MediaEnvironment,
) -> @css_cascade.CascadedValues {
  let author_stylesheets : Array[@css_cascade.Stylesheet] = []
  match presentation_stylesheet(attrs) {
    Some(stylesheet) => author_stylesheets.push(stylesheet)
    None => ()
  }
  for stylesheet in stylesheets {
    author_stylesheets.push(stylesheet)
  }
  @css.cascade_element_with_media_and_validator(
    element,
    author_stylesheets,
    inline_declarations(attrs),
    Some(media_environment),
    svg_declaration_is_valid,
  )
}

///|
fn property_value_text(value : @css_cascade.PropertyValue) -> String {
  match value {
    Value(value) => value
    Inherit => "inherit"
    Initial => "initial"
    Unset => "unset"
    Revert => "revert"
    RevertLayer => "revert-layer"
  }
}

///|
fn cascaded_style_declarations(
  values : @css_cascade.CascadedValues,
) -> Array[StyleDeclaration] {
  let declarations : Array[StyleDeclaration] = []
  values.each(fn(name, declaration) {
    declarations.push({ name, value: property_value_text(declaration.value) })
  })
  declarations
}
