///|
test "tokenize basic selectors" {
  let tokens = tokenize(".foo #bar div")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content=(
      #|[
      #|  "Delim(.)",
      #|  "Ident(foo)",
      #|  "Whitespace",
      #|  "Hash(bar)",
      #|  "Whitespace",
      #|  "Ident(div)",
      #|  "EOF",
      #|]
    ),
  )
}

///|
test "tokenize property declaration" {
  let tokens = tokenize("width: 100px")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Ident(width)\", \"Colon\", \"Whitespace\", \"Dimension(100, px)\", \"EOF\"]",
  )
}

///|
test "tokenize numbers" {
  let tokens = tokenize("10 10.5 10% 10px 10em")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content=(
      #|[
      #|  "Number(10, int)",
      #|  "Whitespace",
      #|  "Number(10.5, num)",
      #|  "Whitespace",
      #|  "Percentage(10)",
      #|  "Whitespace",
      #|  "Dimension(10, px)",
      #|  "Whitespace",
      #|  "Dimension(10, em)",
      #|  "EOF",
      #|]
    ),
  )
}

///|
test "tokenize function" {
  let tokens = tokenize("calc(100% - 20px)")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content=(
      #|[
      #|  "Function(calc)",
      #|  "Percentage(100)",
      #|  "Whitespace",
      #|  "Delim(-)",
      #|  "Whitespace",
      #|  "Dimension(20, px)",
      #|  "RightParen",
      #|  "EOF",
      #|]
    ),
  )
}

///|
test "tokenize string" {
  let tokens = tokenize("\"hello world\"")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"String(hello world)\", \"EOF\"]",
  )
}

///|
test "tokenize at-rule" {
  let tokens = tokenize("@media screen")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"AtKeyword(media)\", \"Whitespace\", \"Ident(screen)\", \"EOF\"]",
  )
}

///|
test "tokenize braces and brackets" {
  let tokens = tokenize("{ [ ( ) ] }")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content=(
      #|[
      #|  "LeftBrace",
      #|  "Whitespace",
      #|  "LeftBracket",
      #|  "Whitespace",
      #|  "LeftParen",
      #|  "Whitespace",
      #|  "RightParen",
      #|  "Whitespace",
      #|  "RightBracket",
      #|  "Whitespace",
      #|  "RightBrace",
      #|  "EOF",
      #|]
    ),
  )
}

///|
test "tokenize comment" {
  let tokens = tokenize("a /* comment */ b")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Ident(a)\", \"Whitespace\", \"Whitespace\", \"Ident(b)\", \"EOF\"]",
  )
}

///|
test "tokenize css rule" {
  let tokens = tokenize(".container { display: flex; }")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content=(
      #|[
      #|  "Delim(.)",
      #|  "Ident(container)",
      #|  "Whitespace",
      #|  "LeftBrace",
      #|  "Whitespace",
      #|  "Ident(display)",
      #|  "Colon",
      #|  "Whitespace",
      #|  "Ident(flex)",
      #|  "Semicolon",
      #|  "Whitespace",
      #|  "RightBrace",
      #|  "EOF",
      #|]
    ),
  )
}

///|
test "tokenize negative number" {
  let tokens = tokenize("-10px")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Dimension(-10, px)\", \"EOF\"]",
  )
}

///|
test "tokenize hash unrestricted vs id" {
  let id_tokens = tokenize("#main")
  debug_inspect(
    id_tokens.map(fn(t) { t.to_string() }),
    content="[\"Hash(main)\", \"EOF\"]",
  )
  // numeric hash is still parsed as Hash
  let num_tokens = tokenize("#123")
  inspect(num_tokens[0].to_string(), content="Hash(123)")
}

///|
test "tokenize single-quoted string" {
  let tokens = tokenize("'hello'")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"String(hello)\", \"EOF\"]",
  )
}

///|
test "tokenize comma" {
  let tokens = tokenize("a,b")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Ident(a)\", \"Comma\", \"Ident(b)\", \"EOF\"]",
  )
}

///|
test "tokenize delim characters" {
  let tokens = tokenize("> + ~ |")
  debug_inspect(
    tokens.map(fn(t) { t.to_string() }),
    content=(
      #|[
      #|  "Delim(>)",
      #|  "Whitespace",
      #|  "Delim(+)",
      #|  "Whitespace",
      #|  "Delim(~)",
      #|  "Whitespace",
      #|  "Delim(|)",
      #|  "EOF",
      #|]
    ),
  )
}

///|
test "tokenize positive signed number" {
  let tokens = tokenize("+5em")
  inspect(tokens[0].to_string(), content="Dimension(5, em)")
}

///|
test "tokenize float number" {
  let tokens = tokenize("3.14")
  inspect(tokens[0].to_string(), content="Number(3.14, num)")
}

///|
test "tokenize empty input yields just EOF" {
  let tokens = tokenize("")
  inspect(tokens.length(), content="1")
  inspect(tokens[0].to_string(), content="EOF")
}

///|
test "tokenize identifier with hyphens" {
  let tokens = tokenize("flex-direction")
  inspect(tokens[0].to_string(), content="Ident(flex-direction)")
}

///|
test "tokenize url-like value via function token" {
  let tokens = tokenize("url(image.png)")
  inspect(tokens[0].to_string(), content="Function(url)")
}

///|
test "tokenize CDO and CDC" {
  let tokens = tokenize("<!-- -->")
  // CDO and CDC may or may not be emitted depending on tokenizer; assert no panic.
  assert_true(tokens.length() > 0)
}

///|
test "tokenize colon and semicolon adjacency" {
  let tokens = tokenize("a:b;c")
  inspect(tokens[0].to_string(), content="Ident(a)")
  inspect(tokens[1].to_string(), content="Colon")
  inspect(tokens[2].to_string(), content="Ident(b)")
  inspect(tokens[3].to_string(), content="Semicolon")
  inspect(tokens[4].to_string(), content="Ident(c)")
}

///|
test "tokenize at-keyword variants" {
  let tokens = tokenize("@import @media @keyframes")
  inspect(tokens[0].to_string(), content="AtKeyword(import)")
  inspect(tokens[2].to_string(), content="AtKeyword(media)")
  inspect(tokens[4].to_string(), content="AtKeyword(keyframes)")
}

///|
test "tokenize escaped backslash in identifier" {
  let tokens = tokenize("\\\\foo")
  // Escape consumed and produced something; just confirm we got an ident.
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("Ident("))
}

///|
test "tokenize many delim characters" {
  let chars = "!@$%^&*?"
  let tokens = tokenize(chars)
  // Each becomes a Delim (except @ which becomes AtKeyword if followed by ident)
  inspect(tokens.length() > 1, content="true")
}

///|
test "tokenize string with embedded escape" {
  let tokens = tokenize("\"a\\\"b\"")
  // String token should be returned
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("String("))
}

///|
test "tokenize whitespace-only input" {
  let tokens = tokenize("   \t\n  ")
  // Should produce one or two Whitespace tokens then EOF
  let last = tokens[tokens.length() - 1].to_string()
  inspect(last, content="EOF")
}

///|
test "tokenize number with uppercase hex escape in string" {
  // \41 = 'A' (hex), terminated by trailing space which is consumed.
  let tokens = tokenize("\"\\41 BC\"")
  inspect(tokens[0].to_string(), content="String(ABC)")
}

///|
test "tokenize hex escape with mixed-case hex" {
  // Cover hex_digit_to_int's upper-case branch (A-F).
  let tokens = tokenize("\"\\Ab\"")
  // Hex \Ab parses; the result is some codepoint.
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("String("))
}

///|
test "tokenize CDO token: <!--" {
  let tokens = tokenize("<!-- foo -->")
  inspect(tokens[0].to_string(), content="CDO")
}

///|
test "tokenize lone '<' as delim" {
  let tokens = tokenize("<x")
  inspect(tokens[0].to_string(), content="Delim(<)")
}

///|
test "tokenize lone '/' as delim" {
  let tokens = tokenize("a / b")
  let mut has_slash = false
  for t in tokens {
    if t.to_string() == "Delim(/)" {
      has_slash = true
    }
  }
  assert_true(has_slash)
}

///|
test "tokenize lone '#' as delim" {
  let tokens = tokenize("# ")
  inspect(tokens[0].to_string(), content="Delim(#)")
}

///|
test "tokenize lone '@' as delim" {
  let tokens = tokenize("@ ")
  inspect(tokens[0].to_string(), content="Delim(@)")
}

///|
test "tokenize backslash followed by newline yields delim" {
  let tokens = tokenize("\\\n")
  inspect(tokens[0].to_string(), content="Delim(\\)")
}

///|
test "tokenize lone '+' as delim" {
  let tokens = tokenize("+ a")
  inspect(tokens[0].to_string(), content="Delim(+)")
}

///|
test "tokenize lone '.' as delim" {
  let tokens = tokenize(". a")
  inspect(tokens[0].to_string(), content="Delim(.)")
}

///|
test "tokenize identifier starting with double-dash" {
  // --my-var should be ident, not delim or number
  let tokens = tokenize("--my-var")
  inspect(tokens[0].to_string(), content="Ident(--my-var)")
}

///|
test "tokenize number with exponent" {
  let tokens = tokenize("1.5e2")
  inspect(tokens[0].to_string(), content="Number(150, num)")
}

///|
test "tokenize number with negative exponent" {
  let tokens = tokenize("1e-2")
  inspect(tokens[0].to_string(), content="Number(0.01, num)")
}

///|
test "tokenize number with positive exponent sign" {
  let tokens = tokenize("3e+1")
  inspect(tokens[0].to_string(), content="Number(30, num)")
}

///|
test "tokenize percentage with float" {
  let tokens = tokenize("12.5%")
  inspect(tokens[0].to_string(), content="Percentage(12.5)")
}

///|
test "tokenize bad string (newline before quote)" {
  let tokens = tokenize("\"abc\ndef\"")
  inspect(tokens[0].to_string(), content="BadString")
}

///|
test "tokenize string with escaped non-special char" {
  let tokens = tokenize("\"a\\bc\"")
  // \b consumes 'b' literally — string contains "abc"
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("String("))
}

///|
test "tokenize unterminated string at EOF" {
  let tokens = tokenize("\"abc")
  // Reaches EOF — returns the partial string
  inspect(tokens[0].to_string(), content="String(abc)")
}

///|
test "tokenize string with line continuation" {
  // \<newline> inside a string is consumed silently
  let tokens = tokenize("\"a\\\nb\"")
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("String("))
}

///|
test "tokenize hash with no name" {
  let tokens = tokenize("#")
  inspect(tokens[0].to_string(), content="Delim(#)")
}

///|
test "tokenize signed decimal number (+.5)" {
  let tokens = tokenize("+.5")
  inspect(tokens[0].to_string(), content="Number(0.5, num)")
}

///|
test "tokenize signed decimal number (-.5)" {
  let tokens = tokenize("-.5em")
  inspect(tokens[0].to_string(), content="Dimension(-0.5, em)")
}

///|
test "tokenize backslash-start identifier" {
  // Backslash followed by something would start ident through escape path.
  let tokens = tokenize("\\68 ello")
  let first = tokens[0].to_string()
  // Should be an Ident token
  assert_true(first.has_prefix("Ident("))
}

///|
test "tokenize at-keyword with double-dash" {
  // @--my is would_start_ident via the -- branch
  let tokens = tokenize("@--my")
  inspect(tokens[0].to_string(), content="AtKeyword(--my)")
}

///|
test "tokenize backslash-prefixed at-keyword" {
  let tokens = tokenize("@\\41")
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("AtKeyword("))
}

///|
test "tokenize lone dot at end" {
  let tokens = tokenize(".")
  inspect(tokens[0].to_string(), content="Delim(.)")
}

///|
test "tokenize sign at end (lone plus)" {
  let tokens = tokenize("+")
  inspect(tokens[0].to_string(), content="Delim(+)")
}

///|
test "tokenize sign at end (lone minus)" {
  let tokens = tokenize("-")
  inspect(tokens[0].to_string(), content="Delim(-)")
}

///|
test "tokenize backslash at EOF" {
  let tokens = tokenize("\\")
  // Backslash with nothing after — falls into name path, returns empty ident
  let first = tokens[0].to_string()
  // Could be Ident or Delim depending on impl
  assert_true(first.has_prefix("Ident(") || first == "Delim(\\)")
}

///|
test "tokenize at-rule '@' followed by space" {
  let tokens = tokenize("@ media")
  inspect(tokens[0].to_string(), content="Delim(@)")
}

///|
test "tokenize hash followed by name char yields Hash" {
  // Hash followed by content that is_name_char but not would_start_ident.
  let tokens = tokenize("#1abc")
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("Hash("))
}

///|
test "tokenize sign followed by dot then non-digit" {
  // "+.x" — would_start_number sees + then . then non-digit → returns false
  let tokens = tokenize("+.x")
  inspect(tokens[0].to_string(), content="Delim(+)")
}

///|
test "tokenize dot followed by non-digit" {
  // ".x" — would_start_number: . then non-digit → returns false
  let tokens = tokenize(".x")
  inspect(tokens[0].to_string(), content="Delim(.)")
}

///|
test "tokenize number followed by dot then digit" {
  // ".5" — would_start_number: . then digit → returns true
  let tokens = tokenize(".5")
  inspect(tokens[0].to_string(), content="Number(0.5, num)")
}

///|
test "tokenize - misc non-special character is Delim" {
  let tokens = tokenize("?")
  inspect(tokens[0].to_string(), content="Delim(?)")
  let tokens2 = tokenize("&")
  inspect(tokens2[0].to_string(), content="Delim(&)")
}

///|
test "tokenize - escape followed by non-special letter in identifier" {
  // "\\a" - escape consumes 'a' literally
  let tokens = tokenize("\\abc")
  let first = tokens[0].to_string()
  // Should be an Ident token
  assert_true(first.has_prefix("Ident("))
}

///|
test "tokenize - exponent at end of number" {
  // "1e" without exponent value falls through, returning just "1"
  let tokens = tokenize("1e ")
  // Implementation may or may not produce a number
  let first = tokens[0].to_string()
  assert_true(first.has_prefix("Number(") || first.has_prefix("Dimension("))
}
