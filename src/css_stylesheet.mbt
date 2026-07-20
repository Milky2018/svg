///|
fn css_is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn find_substring_from(haystack : String, needle : String, start : Int) -> Int {
  if needle.length() == 0 || start < 0 || haystack.length() < needle.length() {
    return -1
  }
  for i in start..<=(haystack.length() - needle.length()) {
    let mut matches = true
    for j in 0..<needle.length() {
      if haystack[i + j] != needle[j] {
        matches = false
        break
      }
    }
    if matches {
      return i
    }
  }
  -1
}

///|
fn substring_starts_at(value : String, expected : String, start : Int) -> Bool {
  if start < 0 || start + expected.length() > value.length() {
    return false
  }
  for i in 0..<expected.length() {
    if value[start + i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn parse_embedded_stylesheets(svg : String) -> Array[@css_cascade.Stylesheet] {
  let stylesheets : Array[@css_cascade.Stylesheet] = []
  let mut pos = 0
  while pos < svg.length() {
    let open = find_substring_from(svg, "<", pos)
    if open < 0 {
      break
    }
    if substring_starts_at(svg, "<!--", open) {
      let comment_close = find_substring_from(svg, "-->", open + 4)
      if comment_close < 0 {
        break
      }
      pos = comment_close + 3
      continue
    }
    if !substring_starts_at(svg, "<style", open) {
      pos = open + 1
      continue
    }
    let name_end = open + 6
    if name_end >= svg.length() ||
      (
        !css_is_whitespace(Int::unsafe_to_char(svg[name_end].to_int())) &&
        svg[name_end] != '>'
      ) {
      pos = name_end
      continue
    }
    let content_start_tag = find_substring_from(svg, ">", name_end)
    if content_start_tag < 0 {
      break
    }
    let close = find_substring_from(svg, "</style", content_start_tag + 1)
    if close < 0 {
      break
    }
    let raw_css = trim_string(
      build_substring(svg, content_start_tag + 1, close),
    )
    let css = if substring_starts_at(raw_css, "<![CDATA[", 0) &&
      string_ends_with(raw_css, "]]>") {
      build_substring(raw_css, 9, raw_css.length() - 3)
    } else {
      raw_css
    }
    stylesheets.push(@css.parse_stylesheet(css))
    let close_end = find_substring_from(svg, ">", close + 7)
    if close_end < 0 {
      break
    }
    pos = close_end + 1
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
  let stylesheet = @css_cascade.Stylesheet::new(@css_cascade.Author)
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
  @css.cascade_element_with_media(
    element,
    author_stylesheets,
    inline_declarations(attrs),
    Some(media_environment),
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
