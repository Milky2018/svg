///|
priv struct StyleElement {
  tag : String
  id : String
  classes : Array[String]
}

///|
priv struct SimpleSelector {
  tag : String?
  id : String?
  classes : Array[String]
}

///|
priv struct StaticSelector {
  parts : Array[SimpleSelector]
  child_relations : Array[Bool]
  specificity : Int
}

///|
priv struct StyleRule {
  selector : StaticSelector
  declarations : Array[StyleDeclaration]
}

///|
fn css_is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn css_is_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_'
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
fn remove_css_comments(css : String) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < css.length() {
    if i + 1 < css.length() && css[i] == '/' && css[i + 1] == '*' {
      let close = find_substring_from(css, "*/", i + 2)
      if close < 0 {
        break
      }
      i = close + 2
    } else {
      result.write_char(Int::unsafe_to_char(css[i].to_int()))
      i += 1
    }
  }
  result.to_string()
}

///|
fn split_selector_list(value : String) -> Array[String] {
  let result : Array[String] = []
  let mut start = 0
  for i in 0..<value.length() {
    if value[i] == ',' {
      let selector = trim_string(build_substring(value, start, i))
      if selector.length() > 0 {
        result.push(selector)
      }
      start = i + 1
    }
  }
  let selector = trim_string(build_substring(value, start, value.length()))
  if selector.length() > 0 {
    result.push(selector)
  }
  result
}

///|
fn tokenize_static_selector(value : String) -> Array[String]? {
  let tokens : Array[String] = []
  let mut buffer = StringBuilder::new()
  fn flush(tokens : Array[String], buffer : StringBuilder) -> StringBuilder {
    let token = buffer.to_string()
    if token.length() > 0 {
      tokens.push(token)
    }
    StringBuilder::new()
  }
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if css_is_whitespace(c) {
      buffer = flush(tokens, buffer)
    } else if c == '>' {
      buffer = flush(tokens, buffer)
      if tokens.length() == 0 || tokens[tokens.length() - 1] == ">" {
        return None
      }
      tokens.push(">")
    } else {
      buffer.write_char(c)
    }
  }
  buffer = flush(tokens, buffer)
  ignore(buffer)
  if tokens.length() == 0 || tokens[tokens.length() - 1] == ">" {
    None
  } else {
    Some(tokens)
  }
}

///|
fn parse_simple_selector(value : String) -> (SimpleSelector, Int)? {
  let mut i = 0
  let mut tag : String? = None
  let mut id : String? = None
  let classes : Array[String] = []
  let mut specificity = 0
  if value[0] == '*' {
    i = 1
  } else if value[0] != '.' && value[0] != '#' {
    let start = i
    while i < value.length() &&
          css_is_name_char(Int::unsafe_to_char(value[i].to_int())) {
      i += 1
    }
    if i == start {
      return None
    }
    tag = Some(build_substring(value, start, i))
    specificity += 1
  }
  while i < value.length() {
    let prefix = value[i]
    if prefix != '.' && prefix != '#' {
      return None
    }
    i += 1
    let start = i
    while i < value.length() &&
          css_is_name_char(Int::unsafe_to_char(value[i].to_int())) {
      i += 1
    }
    if i == start {
      return None
    }
    let name = build_substring(value, start, i)
    if prefix == '#' {
      if id is Some(_) {
        return None
      }
      id = Some(name)
      specificity += 10000
    } else {
      classes.push(name)
      specificity += 100
    }
  }
  Some(({ tag, id, classes }, specificity))
}

///|
fn parse_static_selector(value : String) -> StaticSelector? {
  let tokens = match tokenize_static_selector(value) {
    Some(tokens) => tokens
    None => return None
  }
  let parts : Array[SimpleSelector] = []
  let child_relations : Array[Bool] = []
  let mut specificity = 0
  let first = match parse_simple_selector(tokens[0]) {
    Some(parsed) => parsed
    None => return None
  }
  parts.push(first.0)
  specificity += first.1
  let mut i = 1
  while i < tokens.length() {
    let child = tokens[i] == ">"
    if child {
      i += 1
      if i >= tokens.length() {
        return None
      }
    }
    let parsed = match parse_simple_selector(tokens[i]) {
      Some(parsed) => parsed
      None => return None
    }
    child_relations.push(child)
    parts.push(parsed.0)
    specificity += parsed.1
    i += 1
  }
  Some({ parts, child_relations, specificity })
}

///|
fn parse_stylesheet(css : String, next_order : Array[Int]) -> Array[StyleRule] {
  let rules : Array[StyleRule] = []
  let css = remove_css_comments(css)
  let mut start = 0
  while start < css.length() {
    let open = find_substring_from(css, "{", start)
    if open < 0 {
      break
    }
    let close = find_substring_from(css, "}", open + 1)
    if close < 0 {
      break
    }
    let selector_text = trim_string(build_substring(css, start, open))
    if selector_text.length() > 0 && selector_text[0] != '@' {
      let parsed_declarations = parse_inline_style_declarations(
        build_substring(css, open + 1, close),
      )
      let declarations : Array[StyleDeclaration] = []
      for declaration in parsed_declarations {
        declarations.push({
          ..declaration,
          inline_style: false,
          order: next_order[0],
        })
        next_order[0] += 1
      }
      for selector_text in split_selector_list(selector_text) {
        match parse_static_selector(selector_text) {
          Some(selector) => {
            let selector_declarations : Array[StyleDeclaration] = []
            for declaration in declarations {
              selector_declarations.push({
                ..declaration,
                specificity: selector.specificity,
              })
            }
            rules.push({ selector, declarations: selector_declarations })
          }
          None => ()
        }
      }
    }
    start = close + 1
  }
  rules
}

///|
fn parse_embedded_stylesheets(svg : String) -> Array[StyleRule] {
  let rules : Array[StyleRule] = []
  let next_order = [0]
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
    for rule in parse_stylesheet(css, next_order) {
      rules.push(rule)
    }
    let close_end = find_substring_from(svg, ">", close + 7)
    if close_end < 0 {
      break
    }
    pos = close_end + 1
  }
  rules
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
fn style_element(tag : String, attrs : Array[(String, String)]) -> StyleElement {
  {
    tag,
    id: get_attr(attrs, "id").unwrap_or(""),
    classes: split_class_names(get_attr(attrs, "class").unwrap_or("")),
  }
}

///|
fn simple_selector_matches(
  selector : SimpleSelector,
  element : StyleElement,
) -> Bool {
  match selector.tag {
    Some(tag) => if tag != element.tag { return false }
    None => ()
  }
  match selector.id {
    Some(id) => if id != element.id { return false }
    None => ()
  }
  for class_name in selector.classes {
    if !element.classes.contains(class_name) {
      return false
    }
  }
  true
}

///|
fn static_selector_matches(
  selector : StaticSelector,
  element : StyleElement,
  ancestors : Array[StyleElement],
) -> Bool {
  let last = selector.parts.length() - 1
  if !simple_selector_matches(selector.parts[last], element) {
    return false
  }
  let mut ancestor_index = ancestors.length() - 1
  let mut part_index = last - 1
  while part_index >= 0 {
    if selector.child_relations[part_index] {
      if ancestor_index < 0 ||
        !simple_selector_matches(
          selector.parts[part_index],
          ancestors[ancestor_index],
        ) {
        return false
      }
      ancestor_index -= 1
    } else {
      let mut found = false
      while ancestor_index >= 0 {
        if simple_selector_matches(
            selector.parts[part_index],
            ancestors[ancestor_index],
          ) {
          found = true
          ancestor_index -= 1
          break
        }
        ancestor_index -= 1
      }
      if !found {
        return false
      }
    }
    part_index -= 1
  }
  true
}

///|
fn matching_stylesheet_declarations(
  rules : Array[StyleRule],
  tag : String,
  attrs : Array[(String, String)],
  ancestors : Array[StyleElement],
) -> Array[StyleDeclaration] {
  let element = style_element(tag, attrs)
  let result : Array[StyleDeclaration] = []
  for rule in rules {
    if static_selector_matches(rule.selector, element, ancestors) {
      for declaration in rule.declarations {
        result.push(declaration)
      }
    }
  }
  result
}
