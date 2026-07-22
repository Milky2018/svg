///|
/// CSS Stylesheet Parser
/// Parses full stylesheets with selectors and declaration blocks

///|
/// Maximum allowed CSS input size (10 MB)
let css_max_input_size : Int = 10 * 1024 * 1024

///|
/// Parse a full stylesheet from CSS text
pub fn parse_stylesheet(css : String) -> @cascade.Stylesheet {
  // Security: reject excessively large CSS inputs
  if css.length() > css_max_input_size {
    return @cascade.Stylesheet::new(Author)
  }
  let stylesheet = @cascade.Stylesheet::new(Author)
  let tokens = @token.tokenize(css)
  let mut pos = 0
  while pos < tokens.length() {
    // Skip whitespace
    pos = skip_ws(tokens, pos)
    if pos >= tokens.length() {
      break
    }
    match tokens[pos] {
      EOF => break
      AtKeyword(name) =>
        if name.to_lower() == "media" {
          // Parse @media rule
          pos = parse_media_rule(stylesheet, tokens, pos)
        } else if name.to_lower() == "supports" {
          // Parse @supports rule (treat condition as always true)
          pos = parse_supports_rule(stylesheet, tokens, pos)
        } else if is_keyframes_keyword(name) {
          // Parse @keyframes rule
          pos = parse_keyframes_rule(stylesheet, tokens, pos)
        } else {
          // Skip other @-rules (e.g., @import, @font-face)
          pos = skip_at_rule(tokens, pos)
        }
      _ =>
        // Try to parse a style rule
        match parse_style_rule(tokens, pos) {
          Some((selectors, declarations, new_pos)) => {
            // Add rules for each selector
            for item in selectors {
              let selector_text = item.0
              let selector = item.1
              stylesheet.add_rule(selector_text, selector, declarations.copy())
            }
            let nested_rules = extract_ampersand_nested_rules(
              tokens, pos, new_pos, selectors,
            )
            for nested_rule in nested_rules {
              stylesheet.add_rule(
                nested_rule.0,
                nested_rule.1,
                nested_rule.2.copy(),
              )
            }
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  stylesheet
}

///|
/// Parse an @media rule and add its rules to the stylesheet
fn parse_media_rule(
  stylesheet : @cascade.Stylesheet,
  tokens : Array[@token.Token],
  start : Int,
) -> Int {
  let mut pos = start + 1 // Skip @media token

  // Collect media query tokens until '{'
  let query_start = pos
  while pos < tokens.length() {
    match tokens[pos] {
      LeftBrace => break
      EOF => return pos
      _ => pos = pos + 1
    }
  }
  if pos >= tokens.length() {
    return pos
  }

  // Extract and parse media query
  let query_text = tokens_to_string(tokens, query_start, pos).trim().to_owned()
  let media_query = @media.parse_media_query_list(query_text)

  // Skip '{'
  pos = pos + 1

  // Parse rules inside @media block until '}'
  let mut brace_depth = 1
  while pos < tokens.length() && brace_depth > 0 {
    pos = skip_ws(tokens, pos)
    if pos >= tokens.length() {
      break
    }
    match tokens[pos] {
      RightBrace => {
        brace_depth = brace_depth - 1
        pos = pos + 1
        if brace_depth <= 0 {
          break
        }
      }
      LeftBrace => {
        // This shouldn't happen at top level, skip past it
        brace_depth = brace_depth + 1
        pos = pos + 1
      }
      EOF => break
      AtKeyword(at_name) =>
        if at_name.to_lower() == "supports" {
          // Parse @supports inside @media — rules get the media query
          pos = parse_supports_rule_with_media(
            stylesheet, tokens, pos, media_query,
          )
        } else {
          // Skip other nested @-rules inside @media
          pos = skip_at_rule(tokens, pos)
        }
      _ =>
        // Try to parse a style rule
        match parse_style_rule(tokens, pos) {
          Some((selectors, declarations, new_pos)) => {
            // Add rules with media query for each selector
            for item in selectors {
              let selector_text = item.0
              let selector = item.1
              stylesheet.add_rule_with_media(
                selector_text,
                selector,
                declarations.copy(),
                media_query,
              )
            }
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  pos
}

///|
/// Parse an @supports rule inside @media, attaching the media query to rules.
fn parse_supports_rule_with_media(
  stylesheet : @cascade.Stylesheet,
  tokens : Array[@token.Token],
  start : Int,
  media_query : @media.MediaQueryList,
) -> Int {
  let mut pos = start + 1 // Skip @supports token

  // Skip condition tokens until '{' (handling nested parens)
  let condition_start = pos
  pos = skip_supports_condition_to_block(tokens, pos)
  if pos >= tokens.length() {
    return pos
  }
  let condition_text = tokens_to_string(tokens, condition_start, pos)
  if !supports_condition_matches(condition_text) {
    return skip_at_rule(tokens, start)
  }

  // Skip '{'
  pos = pos + 1

  // Parse rules inside @supports block until '}'
  let mut brace_depth = 1
  while pos < tokens.length() && brace_depth > 0 {
    pos = skip_ws(tokens, pos)
    if pos >= tokens.length() {
      break
    }
    match tokens[pos] {
      RightBrace => {
        brace_depth -= 1
        pos = pos + 1
        if brace_depth <= 0 {
          break
        }
      }
      EOF => break
      AtKeyword(_) => pos = skip_at_rule(tokens, pos)
      _ =>
        match parse_style_rule(tokens, pos) {
          Some((selectors, declarations, new_pos)) => {
            for item in selectors {
              let selector_text = item.0
              let selector = item.1
              stylesheet.add_rule_with_media(
                selector_text,
                selector,
                declarations.copy(),
                media_query,
              )
            }
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  pos
}

///|
/// Parse an @supports rule and add its rules to the stylesheet.
/// The condition is treated as always true (minimal implementation).
fn parse_supports_rule(
  stylesheet : @cascade.Stylesheet,
  tokens : Array[@token.Token],
  start : Int,
) -> Int {
  let mut pos = start + 1 // Skip @supports token

  // Skip condition tokens until '{' (handling nested parens)
  let condition_start = pos
  pos = skip_supports_condition_to_block(tokens, pos)
  if pos >= tokens.length() {
    return pos
  }
  let condition_text = tokens_to_string(tokens, condition_start, pos)
  if !supports_condition_matches(condition_text) {
    return skip_at_rule(tokens, start)
  }

  // Skip '{'
  pos = pos + 1

  // Parse rules inside @supports block until '}'
  let mut brace_depth = 1
  while pos < tokens.length() && brace_depth > 0 {
    pos = skip_ws(tokens, pos)
    if pos >= tokens.length() {
      break
    }
    match tokens[pos] {
      RightBrace => {
        brace_depth -= 1
        pos = pos + 1
        if brace_depth <= 0 {
          break
        }
      }
      EOF => break
      AtKeyword(name) =>
        if name.to_lower() == "media" {
          pos = parse_media_rule(stylesheet, tokens, pos)
        } else if name.to_lower() == "supports" {
          pos = parse_supports_rule(stylesheet, tokens, pos)
        } else {
          pos = skip_at_rule(tokens, pos)
        }
      _ =>
        match parse_style_rule(tokens, pos) {
          Some((selectors, declarations, new_pos)) => {
            for item in selectors {
              let selector_text = item.0
              let selector = item.1
              stylesheet.add_rule(selector_text, selector, declarations.copy())
            }
            let nested_rules = extract_ampersand_nested_rules(
              tokens, pos, new_pos, selectors,
            )
            for nested_rule in nested_rules {
              stylesheet.add_rule(
                nested_rule.0,
                nested_rule.1,
                nested_rule.2.copy(),
              )
            }
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  pos
}

///|
/// Skip whitespace tokens
fn skip_ws(tokens : Array[@token.Token], pos : Int) -> Int {
  let mut p = pos
  while p < tokens.length() {
    match tokens[p] {
      Whitespace => p = p + 1
      _ => break
    }
  }
  p
}

///|
fn skip_supports_condition_to_block(
  tokens : Array[@token.Token],
  start : Int,
) -> Int {
  let mut pos = start
  let mut paren_depth = 0
  while pos < tokens.length() {
    match tokens[pos] {
      Function(_) | LeftParen => {
        paren_depth += 1
        pos = pos + 1
      }
      RightParen => {
        if paren_depth > 0 {
          paren_depth -= 1
        }
        pos = pos + 1
      }
      LeftBrace if paren_depth == 0 => break
      EOF => return pos
      _ => pos = pos + 1
    }
  }
  pos
}

///|
fn compact_supports_condition(condition : String) -> String {
  let lower = condition.to_lower()
  let out = StringBuilder::new()
  for i = 0; i < lower.length(); i = i + 1 {
    let c = lower[i].to_int().unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\n' {
      continue
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
fn supports_known_positive_condition(compact : String) -> Bool? {
  if compact.contains("color:light-dark(") {
    return Some(true)
  }
  None
}

///|
fn supports_condition_matches(condition : String) -> Bool {
  let compact = compact_supports_condition(condition)
  if compact.has_prefix("not(") && compact.has_suffix(")") {
    let inner = compact.unsafe_substring(start=4, end=compact.length() - 1)
    match supports_known_positive_condition(inner) {
      Some(value) => return !value
      None => return true
    }
  }
  if compact.has_prefix("not") {
    let inner = compact.unsafe_substring(start=3, end=compact.length())
    match supports_known_positive_condition(inner) {
      Some(value) => return !value
      None => return true
    }
  }
  match supports_known_positive_condition(compact) {
    Some(value) => value
    None => true
  }
}

///|
/// Parse an `@keyframes name { <keyframe-block>* }` rule and add it to the
/// stylesheet. `start` points at the `@keyframes` (or `@-webkit-keyframes`)
/// AtKeyword token. Returns the position just past the closing brace.
fn parse_keyframes_rule(
  stylesheet : @cascade.Stylesheet,
  tokens : Array[@token.Token],
  start : Int,
) -> Int {
  let mut pos = skip_ws(tokens, start + 1)
  // Animation name: a custom-ident or a string.
  let name = match tokens[pos] {
    Ident(n) => {
      pos = pos + 1
      n
    }
    String(n) => {
      pos = pos + 1
      n
    }
    _ => return skip_at_rule(tokens, start)
  }
  pos = skip_ws(tokens, pos)
  match tokens[pos] {
    LeftBrace => pos = pos + 1
    _ => return skip_at_rule(tokens, start)
  }
  let blocks : Array[@cascade.KeyframeBlock] = []
  while pos < tokens.length() {
    pos = skip_ws(tokens, pos)
    match tokens[pos] {
      RightBrace => {
        pos = pos + 1
        break
      }
      EOF => break
      _ => {
        // Keyframe selector list: from | to | <percentage> (comma-separated),
        // up to the block's '{'.
        let offsets : Array[Double] = []
        while pos < tokens.length() {
          pos = skip_ws(tokens, pos)
          match tokens[pos] {
            LeftBrace => break
            EOF => break
            RightBrace => break
            Percentage(v) => {
              offsets.push(v / 100.0)
              pos = pos + 1
            }
            Number(v, _) => {
              // Only `0` is a valid unitless keyframe selector (= 0%).
              if v == 0.0 {
                offsets.push(0.0)
              }
              pos = pos + 1
            }
            Ident(s) => {
              let ls = s.to_lower()
              if ls == "from" {
                offsets.push(0.0)
              } else if ls == "to" {
                offsets.push(1.0)
              }
              pos = pos + 1
            }
            Comma => pos = pos + 1
            _ => pos = pos + 1
          }
        }
        if pos >= tokens.length() {
          break
        }
        match tokens[pos] {
          LeftBrace => pos = pos + 1
          _ => break
        }
        // Declarations for this block, until '}'.
        let declarations : Array[@cascade.Declaration] = []
        let mut decl_order = 0
        while pos < tokens.length() {
          pos = skip_ws(tokens, pos)
          match tokens[pos] {
            RightBrace => {
              pos = pos + 1
              break
            }
            EOF => break
            _ =>
              match parse_rule_declaration(tokens, pos) {
                Some((property, value, importance, new_pos)) => {
                  declarations.push({
                    property,
                    value: @cascade.PropertyValue::from_css_text(value),
                    origin: Author,
                    importance,
                    specificity: { a: 0, b: 0, c: 0 },
                    source_order: decl_order,
                  })
                  decl_order = decl_order + 1
                  pos = new_pos
                }
                None => pos = pos + 1
              }
          }
        }
        if offsets.length() > 0 {
          blocks.push({ offsets, declarations })
        }
      }
    }
  }
  stylesheet.add_keyframes({ name, blocks })
  pos
}

///|
/// Whether an `@`-rule keyword names a `@keyframes` (incl. vendor-prefixed).
fn is_keyframes_keyword(name : String) -> Bool {
  let n = name.to_lower()
  n == "keyframes" || n == "-webkit-keyframes" || n == "-moz-keyframes"
}

///|
/// Skip an @-rule (until semicolon or matching braces)
fn skip_at_rule(tokens : Array[@token.Token], start : Int) -> Int {
  let mut pos = start + 1
  let mut brace_depth = 0
  while pos < tokens.length() {
    match tokens[pos] {
      LeftBrace => {
        brace_depth = brace_depth + 1
        pos = pos + 1
      }
      RightBrace => {
        brace_depth = brace_depth - 1
        pos = pos + 1
        if brace_depth <= 0 {
          break
        }
      }
      Semicolon => {
        if brace_depth == 0 {
          pos = pos + 1
          break
        }
        pos = pos + 1
      }
      EOF => break
      _ => pos = pos + 1
    }
  }
  pos
}

///|
/// Parse a style rule: selector { declarations }
fn parse_style_rule(
  tokens : Array[@token.Token],
  start : Int,
) -> (
  Array[(String, @selector.ComplexSelector)],
  Array[@cascade.Declaration],
  Int,
)? {
  let mut pos = start

  // Collect selector tokens until '{'
  let selector_start = pos
  while pos < tokens.length() {
    match tokens[pos] {
      LeftBrace => break
      EOF => return None
      _ => pos = pos + 1
    }
  }
  if pos >= tokens.length() {
    return None
  }

  // Parse selectors directly from the already-lexed token stream —
  // avoids stringifying then re-tokenizing each selector.
  let selectors = parse_selector_list_from_tokens(tokens, selector_start, pos)
  if selectors.is_empty() {
    return None
  }

  // Skip '{'
  pos = pos + 1

  // Parse declarations until '}'
  let declarations : Array[@cascade.Declaration] = []
  let mut decl_order = 0
  while pos < tokens.length() {
    pos = skip_ws(tokens, pos)
    match tokens[pos] {
      RightBrace => {
        pos = pos + 1
        break
      }
      EOF => break
      Delim('&') =>
        match skip_nested_rule_block(tokens, pos) {
          Some(next_pos) => pos = next_pos
          None => pos = pos + 1
        }
      _ =>
        // Parse declaration
        match parse_rule_declaration(tokens, pos) {
          Some((property, value, importance, new_pos)) => {
            let decl : @cascade.Declaration = {
              property,
              value: @cascade.PropertyValue::from_css_text(value),
              origin: Author,
              importance,
              specificity: { a: 0, b: 0, c: 0 }, // Will be set during cascade
              source_order: decl_order,
            }
            declarations.push(decl)
            decl_order = decl_order + 1
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  Some((selectors, declarations, pos))
}

///|
/// Parse a declaration within a rule block
fn parse_rule_declaration(
  tokens : Array[@token.Token],
  start : Int,
) -> (String, String, @cascade.Importance, Int)? {
  let mut pos = skip_ws(tokens, start)

  // Get property name
  let property = match tokens[pos] {
    Ident(name) => name
    _ => return None
  }
  pos = pos + 1
  pos = skip_ws(tokens, pos)

  // Expect colon
  match tokens[pos] {
    Colon => pos = pos + 1
    _ => return None
  }
  pos = skip_ws(tokens, pos)

  // Collect value tokens until ';' or '}'
  let value_start = pos
  let mut has_important = false
  while pos < tokens.length() {
    match tokens[pos] {
      Semicolon | RightBrace => break
      EOF => break
      Delim('!') => {
        // Check for !important
        let next_pos = skip_ws(tokens, pos + 1)
        match tokens[next_pos] {
          Ident(s) if s.to_lower() == "important" => {
            has_important = true
            pos = next_pos + 1
            continue
          }
          _ => pos = pos + 1
        }
      }
      _ => pos = pos + 1
    }
  }

  // Extract value (excluding !important)
  let value_end = if has_important {
    // Find where !important starts
    let mut end = value_start
    while end < pos {
      match tokens[end] {
        Delim('!') => break
        _ => end = end + 1
      }
    }
    end
  } else {
    pos
  }
  let value = tokens_to_string(tokens, value_start, value_end).trim().to_owned()

  // Skip semicolon if present
  if pos < tokens.length() {
    match tokens[pos] {
      Semicolon => pos = pos + 1
      _ => ()
    }
  }
  let importance = if has_important {
    @cascade.Important
  } else {
    Normal
  }
  Some((property, value, importance, pos))
}

///|
/// Find matching right brace index for a left brace token.
fn find_matching_right_brace(
  tokens : Array[@token.Token],
  left_brace_pos : Int,
  limit : Int,
) -> Int? {
  if left_brace_pos < 0 || left_brace_pos >= tokens.length() {
    return None
  }
  match tokens[left_brace_pos] {
    LeftBrace => ()
    _ => return None
  }
  let mut depth = 1
  let mut pos = left_brace_pos + 1
  while pos < tokens.length() && pos < limit {
    match tokens[pos] {
      LeftBrace => depth = depth + 1
      RightBrace => {
        depth = depth - 1
        if depth == 0 {
          return Some(pos)
        }
      }
      EOF => return None
      _ => ()
    }
    pos = pos + 1
  }
  None
}

///|
/// Skip a nested ampersand rule block like `&::foo { ... }`.
fn skip_nested_rule_block(tokens : Array[@token.Token], start : Int) -> Int? {
  let mut pos = start
  while pos < tokens.length() {
    match tokens[pos] {
      LeftBrace =>
        match find_matching_right_brace(tokens, pos, tokens.length()) {
          Some(close) => return Some(close + 1)
          None => return None
        }
      RightBrace | EOF => return None
      _ => pos = pos + 1
    }
  }
  None
}

///|
fn replace_ampersand(
  nested_selector : String,
  parent_selector : String,
) -> String {
  let out = StringBuilder::new()
  for i = 0; i < nested_selector.length(); i = i + 1 {
    let c = nested_selector[i].to_int().unsafe_to_char()
    if c == '&' {
      out.write_string(parent_selector)
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// Extract one-level nested `&... { ... }` rules as parsed selector/declaration entries.
fn extract_ampersand_nested_rules(
  tokens : Array[@token.Token],
  rule_start : Int,
  rule_end : Int,
  selectors : Array[(String, @selector.ComplexSelector)],
) -> Array[(String, @selector.ComplexSelector, Array[@cascade.Declaration])] {
  let rules : Array[
    (String, @selector.ComplexSelector, Array[@cascade.Declaration]),
  ] = []
  let mut body_start = -1
  let mut i = rule_start
  while i < rule_end {
    match tokens[i] {
      LeftBrace => {
        body_start = i
        break
      }
      _ => i = i + 1
    }
  }
  if body_start < 0 {
    return rules
  }

  let mut pos = body_start + 1
  while pos < rule_end - 1 {
    pos = skip_ws(tokens, pos)
    if pos >= rule_end - 1 {
      break
    }
    match tokens[pos] {
      Delim('&') => {
        let nested_selector_start = pos
        while pos < rule_end - 1 {
          match tokens[pos] {
            LeftBrace
            | RightBrace
            | EOF => break
            _ => pos = pos + 1
          }
        }
        if pos >= rule_end - 1 {
          break
        }
        match tokens[pos] {
          LeftBrace => {
            let nested_selector_text = tokens_to_string(
                tokens, nested_selector_start, pos,
              )
              .trim()
              .to_owned()
            match find_matching_right_brace(tokens, pos, rule_end) {
              Some(nested_close) => {
                let nested_decls : Array[@cascade.Declaration] = []
                let mut decl_order = 0
                let mut decl_pos = pos + 1
                while decl_pos < nested_close {
                  decl_pos = skip_ws(tokens, decl_pos)
                  if decl_pos >= nested_close {
                    break
                  }
                  match parse_rule_declaration(tokens, decl_pos) {
                    Some((property, value, importance, new_decl_pos)) => {
                      let decl : @cascade.Declaration = {
                        property,
                        value: @cascade.PropertyValue::from_css_text(value),
                        origin: Author,
                        importance,
                        specificity: { a: 0, b: 0, c: 0 },
                        source_order: decl_order,
                      }
                      nested_decls.push(decl)
                      decl_order = decl_order + 1
                      if new_decl_pos > decl_pos {
                        decl_pos = new_decl_pos
                      } else {
                        decl_pos = decl_pos + 1
                      }
                    }
                    None => decl_pos = decl_pos + 1
                  }
                }
                if !nested_selector_text.is_empty() && !nested_decls.is_empty() {
                  let nested_parts = split_by_comma(nested_selector_text)
                  for parent_item in selectors {
                    let parent_selector = parent_item.0.trim().to_owned()
                    if parent_selector.is_empty() {
                      continue
                    }
                    for nested_part in nested_parts {
                      let nested_trim = nested_part.trim().to_owned()
                      if nested_trim.is_empty() {
                        continue
                      }
                      let expanded = replace_ampersand(
                        nested_trim, parent_selector,
                      )
                      match @selector.parse_selector_text(expanded) {
                        Some(sel) =>
                          rules.push((expanded, sel, nested_decls.copy()))
                        None => ()
                      }
                    }
                  }
                }
                pos = nested_close + 1
                continue
              }
              None => break
            }
          }
          _ => pos = pos + 1
        }
      }
      LeftBrace =>
        match find_matching_right_brace(tokens, pos, rule_end) {
          Some(close) => pos = close + 1
          None => break
        }
      RightBrace | EOF => break
      _ => pos = pos + 1
    }
  }
  rules
}

///|
/// Convert token range to string
fn tokens_to_string(
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    match tokens[i] {
      Ident(s) => buf.write_string(s)
      Hash(s, _) => {
        buf.write_char('#')
        buf.write_string(s)
      }
      Delim(c) => buf.write_char(c)
      Colon => buf.write_char(':')
      Comma => buf.write_char(',')
      Whitespace => buf.write_char(' ')
      Dimension(n, u) => {
        buf.write_string(n.to_string())
        buf.write_string(u)
      }
      Number(n, _) => buf.write_string(n.to_string())
      Percentage(n) => {
        buf.write_string(n.to_string())
        buf.write_char('%')
      }
      String(s) => {
        buf.write_char('"')
        buf.write_string(s)
        buf.write_char('"')
      }
      LeftParen => buf.write_char('(')
      RightParen => buf.write_char(')')
      LeftBracket => buf.write_char('[')
      RightBracket => buf.write_char(']')
      Function(name) => {
        buf.write_string(name)
        buf.write_char('(')
      }
      _ => ()
    }
  }
  buf.to_string()
}

///|
/// Parse comma-separated selector list directly from a token slice.
/// Saves the round-trip through `tokens_to_string` +
/// `@token.tokenize` that the previous string-based path required.
fn parse_selector_list_from_tokens(
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> Array[(String, @selector.ComplexSelector)] {
  let result : Array[(String, @selector.ComplexSelector)] = []
  // Find top-level commas; each segment becomes one (text, selector).
  let mut depth = 0
  let mut seg_start = start
  let mut i = start
  while i < end {
    match tokens[i] {
      EOF => break
      Function(_)
      | LeftParen
      | LeftBracket => depth = depth + 1
      RightParen | RightBracket =>
        if depth > 0 {
          depth = depth - 1
        }
      Comma =>
        if depth == 0 {
          push_selector(result, tokens, seg_start, i)
          seg_start = i + 1
        }
      _ => ()
    }
    i = i + 1
  }
  push_selector(result, tokens, seg_start, end)
  result
}

///|
fn push_selector(
  result : Array[(String, @selector.ComplexSelector)],
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> Unit {
  // Use the token-direct selector parser (no re-tokenization).
  // Note `from_tokens` returns Array[ComplexSelector] over each
  // top-level comma; here we feed it a slice that we already know
  // contains a single selector (no top-level comma), so we expect 0 or 1.
  let parsed = @selector.parse_selector_list_from_tokens(tokens, start, end)
  if parsed.is_empty() {
    return
  }
  // Reconstruct the text for the rule's `selector_text` debug field.
  // It's not on the cascade hot path, but downstream code expects a
  // non-empty string here.
  let text = tokens_to_string(tokens, start, end).trim().to_owned()
  for sel in parsed {
    result.push((text, sel))
  }
}

///|
/// Split string by comma
fn split_by_comma(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut in_single_quote = false
  let mut in_double_quote = false
  let mut escaped = false
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    if escaped {
      current.write_char(c)
      escaped = false
      continue
    }
    if c == '\\' && (in_single_quote || in_double_quote) {
      current.write_char(c)
      escaped = true
      continue
    }
    if in_single_quote {
      current.write_char(c)
      if c == '\'' {
        in_single_quote = false
      }
      continue
    }
    if in_double_quote {
      current.write_char(c)
      if c == '"' {
        in_double_quote = false
      }
      continue
    }

    if c == '\'' {
      in_single_quote = true
      current.write_char(c)
      continue
    }
    if c == '"' {
      in_double_quote = true
      current.write_char(c)
      continue
    }
    if c == '(' {
      paren_depth += 1
      current.write_char(c)
      continue
    }
    if c == ')' {
      if paren_depth > 0 {
        paren_depth -= 1
      }
      current.write_char(c)
      continue
    }
    if c == '[' {
      bracket_depth += 1
      current.write_char(c)
      continue
    }
    if c == ']' {
      if bracket_depth > 0 {
        bracket_depth -= 1
      }
      current.write_char(c)
      continue
    }
    if c == ',' && paren_depth == 0 && bracket_depth == 0 {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }
  result
}
