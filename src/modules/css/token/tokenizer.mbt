///|
/// CSS Tokenizer based on CSS Syntax Level 3
/// https://www.w3.org/TR/css-syntax-3/#tokenization

///|
/// Tokenizer state
priv struct Tokenizer {
  input : String
  mut pos : Int
  len : Int
  /// Set by `consume_number` to record whether the just-consumed number
  /// token had an explicit leading `+`/`-` sign. Read by
  /// `tokenize_with_signs` after each `next_token` call. CSS Syntax 3
  /// keeps this as a "type flag" on `<number-token>`; the public
  /// `Token::Number` doesn't carry it (would break the API), so the
  /// parallel `signs` array preserves it for the selector parser's An+B
  /// path.
  mut last_num_signed : Bool
}

///|
fn Tokenizer::new(input : String) -> Tokenizer {
  { input, pos: 0, len: input.length(), last_num_signed: false }
}

///|
/// Sentinel char returned by `peek_char` / `consume_char` past the end
/// of input. NUL is not produced by any reachable CSS token, so callers
/// can compare against it as a non-allocating EOF check. The
/// `Char?`-returning variants stay for paths that still pattern-match
/// on the option.
let nul_char : Char = '\u{0}'

///|
fn Tokenizer::peek_char(self : Tokenizer) -> Char {
  if self.pos >= self.len {
    nul_char
  } else {
    self.input[self.pos].to_int().unsafe_to_char()
  }
}

///|
fn Tokenizer::peek_char_at(self : Tokenizer, offset : Int) -> Char {
  let idx = self.pos + offset
  if idx >= self.len || idx < 0 {
    nul_char
  } else {
    self.input[idx].to_int().unsafe_to_char()
  }
}

///|
/// Peek current character without consuming
fn Tokenizer::peek(self : Tokenizer) -> Char? {
  if self.pos >= self.len {
    None
  } else {
    Some(self.input[self.pos].to_int().unsafe_to_char())
  }
}

///|
/// Consume and return current character
fn Tokenizer::consume(self : Tokenizer) -> Char? {
  if self.pos >= self.len {
    None
  } else {
    let c = self.input[self.pos].to_int().unsafe_to_char()
    self.pos += 1
    Some(c)
  }
}

///|
/// Check if at end of input
fn Tokenizer::is_eof(self : Tokenizer) -> Bool {
  self.pos >= self.len
}

///|
/// Check if character is whitespace (space, tab, newline)
fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Check if character is a digit
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Check if character is a letter
fn is_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// Check if character is a name-start character
fn is_name_start(c : Char) -> Bool {
  is_letter(c) || c == '_' || c.to_uint() > 0x7F
}

///|
/// Check if character is a name character
fn is_name_char(c : Char) -> Bool {
  is_name_start(c) || is_digit(c) || c == '-'
}

///|
fn is_hex_digit(c : Char) -> Bool {
  let code = c.to_int()
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'f'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'F'.to_int())
}

///|
fn hex_digit_to_int(c : Char) -> Int {
  let code = c.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    code - 'a'.to_int() + 10
  } else {
    code - 'A'.to_int() + 10
  }
}

///|
/// Consume whitespace
fn Tokenizer::consume_whitespace(self : Tokenizer) -> Unit {
  while self.pos < self.len {
    let c = self.input[self.pos].to_int().unsafe_to_char()
    if is_whitespace(c) {
      self.pos += 1
    } else {
      break
    }
  }
}

///|
/// Consume an identifier/name
fn Tokenizer::consume_name(self : Tokenizer) -> String {
  let start = self.pos
  // Fast path: scan a run of name chars and return it as one substring.
  while self.pos < self.len &&
        is_name_char(self.input[self.pos].to_int().unsafe_to_char()) {
    self.pos += 1
  }
  // Escapes are rare; only fall back to the char-by-char builder if we stopped
  // on a backslash, seeding it with the run already scanned.
  if self.pos < self.len &&
    self.input[self.pos].to_int().unsafe_to_char() == '\\' {
    let buf = StringBuilder::new()
    buf.write_string(self.input.unsafe_substring(start~, end=self.pos))
    while self.pos < self.len {
      let c = self.input[self.pos].to_int().unsafe_to_char()
      if is_name_char(c) {
        buf.write_char(c)
        self.pos += 1
      } else if c == '\\' {
        // Skip the backslash and write the following raw char (CSS hex escapes
        // aren't decoded here; callers that need them use consume_string).
        self.pos += 1
        if self.pos < self.len {
          buf.write_char(self.input[self.pos].to_int().unsafe_to_char())
          self.pos += 1
        }
      } else {
        break
      }
    }
    return buf.to_string()
  }
  self.input.unsafe_substring(start~, end=self.pos)
}

///|
/// Consume a number
fn Tokenizer::consume_number(self : Tokenizer) -> (Double, NumType) {
  // Advance `pos` over the numeric run, then take a single substring instead of
  // appending char-by-char to a StringBuilder.
  let start = self.pos
  let mut is_integer = true

  // Optional sign
  let first = self.peek_char()
  self.last_num_signed = first == '+' || first == '-'
  let negative = first == '-'
  if self.last_num_signed {
    self.pos += 1
  }

  // Integer part. Accumulate the value directly so the common integer case
  // (e.g. `8`, `16`, line numbers) avoids both a substring and parse_double.
  let mut int_value = 0.0
  while self.pos < self.len &&
        is_digit(self.input[self.pos].to_int().unsafe_to_char()) {
    int_value = int_value * 10.0 +
      (self.input[self.pos].to_int() - '0'.to_int()).to_double()
    self.pos += 1
  }

  // Decimal part
  if self.peek_char() == '.' && is_digit(self.peek_char_at(1)) {
    is_integer = false
    self.pos += 1
    while self.pos < self.len &&
          is_digit(self.input[self.pos].to_int().unsafe_to_char()) {
      self.pos += 1
    }
  }

  // Exponent part
  let e = self.peek_char()
  if e == 'e' || e == 'E' {
    let next = self.peek_char_at(1)
    if is_digit(next) || next == '+' || next == '-' {
      is_integer = false
      self.pos += 1
      let sign = self.peek_char()
      if sign == '+' || sign == '-' {
        self.pos += 1
      }
      while self.pos < self.len &&
            is_digit(self.input[self.pos].to_int().unsafe_to_char()) {
        self.pos += 1
      }
    }
  }
  // Integers are accumulated exactly above; only decimals / exponents need the
  // full (substring + parse_double) path to preserve correct rounding.
  let value = if is_integer {
    if negative {
      -int_value
    } else {
      int_value
    }
  } else {
    let num_str = self.input.unsafe_substring(start~, end=self.pos)
    @string.parse_double(num_str) catch {
      _ => 0.0
    }
  }
  let num_type : NumType = if is_integer { Integer } else { NumType::Number }
  (value, num_type)
}

///|
/// Consume a string token
fn Tokenizer::consume_string(self : Tokenizer, quote : Char) -> Token {
  // Fast path: scan to the closing quote and return one substring. Escapes and
  // raw newlines (which need special handling) are rare, so only fall back to
  // the char-by-char builder when one is encountered.
  let start = self.pos
  while self.pos < self.len {
    let c = self.input[self.pos].to_int().unsafe_to_char()
    if c == quote {
      let s = self.input.unsafe_substring(start~, end=self.pos)
      self.pos += 1
      return Token::String(s)
    } else if c == '\\' || c == '\n' || c == '\r' {
      break
    }
    self.pos += 1
  }
  if self.is_eof() {
    return Token::String(self.input.unsafe_substring(start~, end=self.pos))
  }
  // Slow path: seed the builder with the run scanned so far, then handle
  // escapes / bad-string termination char-by-char.
  let buf = StringBuilder::new()
  buf.write_string(self.input.unsafe_substring(start~, end=self.pos))
  while !self.is_eof() {
    match self.consume() {
      Some(c) if c == quote => return Token::String(buf.to_string())
      Some('\n') | Some('\r') => return BadString
      Some('\\') =>
        match self.peek() {
          Some('\n') => {
            let _ = self.consume()
            // Line continuation
          }
          Some(c) if is_hex_digit(c) => {
            let mut codepoint = 0
            let mut count = 0
            while !self.is_eof() && count < 6 {
              match self.peek() {
                Some(h) if is_hex_digit(h) => {
                  codepoint = codepoint * 16 + hex_digit_to_int(h)
                  let _ = self.consume()
                  count += 1
                }
                _ => break
              }
            }
            if !self.is_eof() {
              match self.peek() {
                Some(ws) if is_whitespace(ws) => {
                  let _ = self.consume()
                }
                _ => ()
              }
            }
            if codepoint > 0 {
              buf.write_char(codepoint.unsafe_to_char())
            }
          }
          Some(c) => {
            let _ = self.consume()
            buf.write_char(c)
          }
          None => ()
        }
      Some(c) => buf.write_char(c)
      None => return Token::String(buf.to_string())
    }
  }
  Token::String(buf.to_string())
}

///|
/// Check if the next characters would start a number
fn Tokenizer::would_start_number(self : Tokenizer) -> Bool {
  let c0 = self.peek_char()
  if c0 == '+' || c0 == '-' {
    let c1 = self.peek_char_at(1)
    if is_digit(c1) {
      return true
    }
    if c1 == '.' {
      return is_digit(self.peek_char_at(2))
    }
    false
  } else if c0 == '.' {
    is_digit(self.peek_char_at(1))
  } else {
    is_digit(c0)
  }
}

///|
/// Check if the next characters would start an identifier
fn Tokenizer::would_start_ident(self : Tokenizer) -> Bool {
  let c0 = self.peek_char()
  if c0 == '-' {
    let c1 = self.peek_char_at(1)
    c1 == '-' || is_name_start(c1) || c1 == '\\'
  } else if c0 == '\\' {
    true
  } else {
    is_name_start(c0)
  }
}

///|
/// Consume the next token
fn Tokenizer::next_token(self : Tokenizer) -> Token {
  if self.is_eof() {
    return EOF
  }
  // Hot dispatch on the first byte. `peek_char` returns NUL past the
  // end without allocating an Option, so the common case stays in
  // straight-line code.
  let c = self.peek_char()
  if is_whitespace(c) {
    self.consume_whitespace()
    return Whitespace
  }
  match c {
    '"' => {
      self.pos += 1
      self.consume_string('"')
    }
    '\'' => {
      self.pos += 1
      self.consume_string('\'')
    }
    '#' => {
      self.pos += 1
      if self.would_start_ident() || is_name_char(self.peek_char()) {
        let name = self.consume_name()
        let hash_type : HashType = if self.would_start_ident() {
          Id
        } else {
          Unrestricted
        }
        Hash(name, hash_type)
      } else {
        Delim('#')
      }
    }
    '(' => {
      self.pos += 1
      LeftParen
    }
    ')' => {
      self.pos += 1
      RightParen
    }
    '[' => {
      self.pos += 1
      LeftBracket
    }
    ']' => {
      self.pos += 1
      RightBracket
    }
    '{' => {
      self.pos += 1
      LeftBrace
    }
    '}' => {
      self.pos += 1
      RightBrace
    }
    ':' => {
      self.pos += 1
      Colon
    }
    ';' => {
      self.pos += 1
      Semicolon
    }
    ',' => {
      self.pos += 1
      Comma
    }
    '+' =>
      if self.would_start_number() {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else {
        self.pos += 1
        Delim('+')
      }
    '-' =>
      if self.would_start_number() {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else if self.would_start_ident() {
        let name = self.consume_name()
        self.finish_ident_token(name)
      } else if self.peek_char_at(1) == '-' && self.peek_char_at(2) == '>' {
        self.pos += 3
        CDC
      } else {
        self.pos += 1
        Delim('-')
      }
    '.' =>
      if self.would_start_number() {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else {
        self.pos += 1
        Delim('.')
      }
    '@' => {
      self.pos += 1
      if self.would_start_ident() {
        let name = self.consume_name()
        AtKeyword(name)
      } else {
        Delim('@')
      }
    }
    '/' =>
      if self.peek_char_at(1) == '*' {
        self.pos += 2
        // Skip until */
        while !self.is_eof() {
          if self.peek_char() == '*' && self.peek_char_at(1) == '/' {
            self.pos += 2
            break
          }
          self.pos += 1
        }
        self.next_token()
      } else {
        self.pos += 1
        Delim('/')
      }
    '<' =>
      if self.peek_char_at(1) == '!' &&
        self.peek_char_at(2) == '-' &&
        self.peek_char_at(3) == '-' {
        self.pos += 4
        CDO
      } else {
        self.pos += 1
        Delim('<')
      }
    '\\' =>
      if self.peek_char_at(1) == '\n' {
        self.pos += 1
        Delim('\\')
      } else {
        let name = self.consume_name()
        self.finish_ident_token(name)
      }
    _ =>
      if is_digit(c) {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else if is_name_start(c) {
        let name = self.consume_name()
        self.finish_ident_token(name)
      } else {
        self.pos += 1
        Delim(c)
      }
  }
}

///|
/// Finish a numeric token (check for % or dimension)
fn Tokenizer::finish_numeric_token(
  self : Tokenizer,
  value : Double,
  num_type : NumType,
) -> Token {
  let c = self.peek_char()
  if c == '%' {
    self.pos += 1
    Percentage(value)
  } else if is_name_start(c) || c == '-' {
    let unit = self.consume_name()
    Dimension(value, unit)
  } else {
    Number(value, num_type)
  }
}

///|
/// Finish an identifier token (check if it's a function)
fn Tokenizer::finish_ident_token(self : Tokenizer, name : String) -> Token {
  if self.peek_char() == '(' {
    self.pos += 1
    Function(name)
  } else {
    Ident(name)
  }
}

///|
/// Tokenize a CSS string into a list of tokens
pub fn tokenize(input : String) -> Array[Token] {
  let tokenizer = Tokenizer::new(input)
  let tokens : Array[Token] = []
  while true {
    let token = tokenizer.next_token()
    tokens.push(token)
    match token {
      EOF => break
      _ => continue
    }
  }
  tokens
}

///|
/// Tokenize and also return a parallel array marking which `Number`
/// tokens had an explicit leading `+`/`-` sign in the source. Used by
/// the selector parser to validate `<an+b>` shapes that depend on the
/// "type flag" CSS Syntax 3 records on `<number-token>`. The signs
/// array has the same length as the tokens array; entries are `false`
/// for non-`Number` tokens.
pub fn tokenize_with_signs(input : String) -> (Array[Token], Array[Bool]) {
  let tokenizer = Tokenizer::new(input)
  let tokens : Array[Token] = []
  let signs : Array[Bool] = []
  while true {
    tokenizer.last_num_signed = false
    let token = tokenizer.next_token()
    let signed = match token {
      Number(_, _) => tokenizer.last_num_signed
      _ => false
    }
    tokens.push(token)
    signs.push(signed)
    match token {
      EOF => break
      _ => continue
    }
  }
  (tokens, signs)
}
