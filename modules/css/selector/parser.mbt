///|
/// CSS Selector Parser
/// Parses CSS tokens into Selector structures

///|
/// Parser state
priv struct SelectorParser {
  tokens : Array[@token.Token]
  /// Parallel array marking which `Number` tokens had an explicit
  /// leading `+`/`-` sign — needed to validate `<an+b>` micro-syntax
  /// (CSS Syntax 3's "type flag" that the public `Token` enum drops).
  /// `None` means the parser was constructed from a token-only stream
  /// (the legacy/stylesheet path) and the An+B parser falls back to
  /// the lenient pre-sign-info behavior.
  signs : Array[Bool]?
  /// Exclusive upper bound on `pos`. When parsing a selector slice
  /// from a larger token stream (e.g. a stylesheet's rule body),
  /// `tokens_end` caps where the parser is allowed to read so callers
  /// don't have to copy a sub-array.
  tokens_end : Int
  mut pos : Int
}

///|
fn SelectorParser::new_with_signs(
  tokens : Array[@token.Token],
  signs : Array[Bool],
) -> SelectorParser {
  { tokens, signs: Some(signs), tokens_end: tokens.length(), pos: 0 }
}

///|
/// Build a parser bound to the half-open `[start, end)` slice of
/// `tokens`. Used by `parse_stylesheet` to avoid re-tokenizing
/// selectors it has already lexed.
fn SelectorParser::from_slice(
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> SelectorParser {
  { tokens, signs: None, tokens_end: end, pos: start }
}

///|
/// True iff the token at `pos` is a `Number` that had an explicit
/// leading `+`/`-` sign in source. Returns `false` for non-Number
/// tokens, out-of-bounds positions, and parsers built without sign
/// info (legacy callers).
fn SelectorParser::is_signed_at(self : SelectorParser, pos : Int) -> Bool {
  match self.signs {
    None => false
    Some(s) => if pos < 0 || pos >= s.length() { false } else { s[pos] }
  }
}

///|
fn SelectorParser::peek(self : SelectorParser) -> @token.Token {
  if self.pos >= self.tokens_end {
    // Return a safe fallback — the tokenizer always appends an EOF
    // sentinel so the source array is never empty.
    self.tokens[self.tokens.length() - 1]
  } else {
    self.tokens[self.pos]
  }
}

///|
fn SelectorParser::is_at_end(self : SelectorParser) -> Bool {
  self.pos >= self.tokens_end ||
  (match self.tokens[self.pos] {
    EOF => true
    _ => false
  })
}

///|
fn SelectorParser::advance(self : SelectorParser) -> @token.Token {
  let tok = self.peek()
  self.pos = self.pos + 1
  tok
}

///|
fn SelectorParser::skip_whitespace(self : SelectorParser) -> Unit {
  while !self.is_at_end() {
    match self.peek() {
      Whitespace => {
        let _ = self.advance()
      }
      _ => break
    }
  }
}

///|
/// Parse a selector list (comma-separated) from a constructed parser.
fn SelectorParser::parse_selector_list(self : SelectorParser) -> SelectorList? {
  self.skip_whitespace()
  let selectors : Array[ComplexSelector] = []
  match self.parse_complex_selector() {
    Some(sel) => selectors.push(sel)
    None => return None
  }
  while !self.is_at_end() {
    self.skip_whitespace()
    match self.peek() {
      Comma => {
        let _ = self.advance()
        self.skip_whitespace()
        match self.parse_complex_selector() {
          Some(sel) => selectors.push(sel)
          None => return None
        }
      }
      _ => break
    }
  }
  self.skip_whitespace()
  if !self.is_at_end() {
    return None
  }
  Some(SelectorList::{ selectors, })
}

///|
/// Parse a single selector (without commas) from a constructed parser.
fn SelectorParser::parse_top_selector(
  self : SelectorParser,
) -> ComplexSelector? {
  self.skip_whitespace()
  match self.parse_complex_selector() {
    None => None
    Some(sel) => {
      self.skip_whitespace()
      if self.is_at_end() {
        Some(sel)
      } else {
        None
      }
    }
  }
}

///|
fn SelectorParser::parse_complex_selector(
  self : SelectorParser,
) -> ComplexSelector? {
  // Parse the first compound selector
  let first = match self.parse_compound_selector() {
    None => return None
    Some(f) => f
  }
  let tail : Array[ComplexSelectorStep] = []
  let mut current = first
  while !self.is_at_end() {
    // Check for combinator (maybe preceded by whitespace)
    let had_whitespace = match self.peek() {
      Whitespace => {
        let _ = self.advance()
        true
      }
      _ => false
    }

    // Check for explicit combinator
    let combinator : Combinator? = match self.peek() {
      Delim('>') => {
        let _ = self.advance()
        self.skip_whitespace()
        Some(Child)
      }
      Delim('+') => {
        let _ = self.advance()
        self.skip_whitespace()
        Some(NextSibling)
      }
      Delim('~') => {
        let _ = self.advance()
        self.skip_whitespace()
        Some(SubsequentSibling)
      }
      _ =>
        if had_whitespace && !self.is_at_end() {
          // Descendant combinator (whitespace) — only when something
          // non-empty follows. Pure trailing whitespace at the end of a
          // selector slice must not be treated as a descendant.
          Some(Descendant)
        } else {
          None
        }
    }
    match combinator {
      None => break
      Some(comb) =>
        // A pseudo-element-bearing compound must be the rightmost
        // (subject) compound of a complex selector — combinators may
        // not follow it.
        if compound_has_pseudo_element(current) {
          return None
        } else {
          match self.parse_compound_selector() {
            None => return None
            Some(next) => {
              tail.push({ combinator: comb, selector: current })
              current = next
            }
          }
        }
    }
  }

  // Reverse tail so it goes from right to left
  let reversed_tail : Array[ComplexSelectorStep] = []
  for i = tail.length() - 1; i >= 0; i = i - 1 {
    reversed_tail.push(tail[i])
  }
  Some({ head: current, tail: reversed_tail })
}

///|

///|
/// CSS Namespaces 3 prefix on a type/universal/attribute selector.
priv enum NamespacePrefix {
  NoPrefix // nothing — use default namespace
  AnyNs // `*|` — any namespace
  EmptyNs // `|`  — explicit no namespace (canonically dropped)
  NamedNs // `name|` — named namespace (the name itself isn't kept;
  // mizchi/css doesn't track @namespace declarations)
}

///|
/// Match-everything helper so the unused EmptyNs/NamedNs constructors
/// (parsed but not significant to canonical Show) don't trip the
/// dead-code linter. We otherwise treat them identically to NoPrefix.
fn ns_prefix_collapse(p : NamespacePrefix) -> NamespacePrefix {
  match p {
    AnyNs => AnyNs
    NoPrefix | EmptyNs | NamedNs => NoPrefix
  }
}

///|
/// Optimistically consume a namespace prefix (`*|`, `|`, or `name|`).
/// If the next non-prefix tokens don't form a valid head (type/universal),
/// the caller restores `self.pos`.
fn SelectorParser::parse_ns_prefix(self : SelectorParser) -> NamespacePrefix {
  let start = self.pos
  match self.peek() {
    Delim('|') =>
      match self.peek_at(1) {
        Ident(_) | Delim('*') => {
          let _ = self.advance()
          return EmptyNs
        }
        _ => return NoPrefix
      }
    Delim('*') =>
      match self.peek_at(1) {
        Delim('|') =>
          match self.peek_at(2) {
            Ident(_) | Delim('*') => {
              let _ = self.advance()
              let _ = self.advance()
              return AnyNs
            }
            _ => return NoPrefix
          }
        _ => return NoPrefix
      }
    Ident(_) =>
      match self.peek_at(1) {
        Delim('|') =>
          match self.peek_at(2) {
            // `name|=` is the dash-match operator inside an attribute
            // selector, which we never enter from here; still, guard
            // against `name|something` followed by `=`.
            Delim('=') => return NoPrefix
            Ident(_) | Delim('*') => {
              let _ = self.advance()
              let _ = self.advance()
              return NamedNs
            }
            _ => return NoPrefix
          }
        _ => return NoPrefix
      }
    _ => return NoPrefix
  }
  let _ = start // keep `start` referenced if compiler complains
  NoPrefix
}

///|
fn SelectorParser::peek_at(self : SelectorParser, offset : Int) -> @token.Token {
  let idx = self.pos + offset
  if idx >= self.tokens.length() {
    // Fall back to the tokenizer's trailing EOF (always present).
    return self.tokens[self.tokens.length() - 1]
  }
  self.tokens[idx]
}

///|
fn SelectorParser::parse_compound_selector(
  self : SelectorParser,
) -> CompoundSelector? {
  let mut type_selector : SimpleSelector? = None
  let subclasses : Array[SimpleSelector] = []
  let mut any_ns_universal = false
  // Tracks whether we've already consumed a pseudo-element and, if so,
  // whether it's ::part (which permits a small whitelist of subsequent
  // selectors per CSS Shadow Parts 1) or another element (which closes
  // the compound).
  let mut saw_pe : PseudoElement? = None

  // First, try to parse a (possibly namespaced) type selector or
  // universal. CSS Namespaces 3 allows the prefixes:
  //   `*|`    any namespace
  //   `|`     explicit no namespace (canonically dropped)
  //   `name|` named namespace (we discard the name; we don't track
  //           @namespace declarations)
  // followed by an identifier or `*`.
  let saved_pos = self.pos
  let ns_prefix : NamespacePrefix = ns_prefix_collapse(self.parse_ns_prefix())
  match self.peek() {
    Ident(name) => {
      let _ = self.advance()
      type_selector = Some(Type(name.to_lower()))
      // CSS Namespaces 3 §6: any/named prefixes don't affect serialization
      // beyond optionally keeping the `*|` prefix on attribute selectors.
      // For type selectors we discard the prefix at parse time — the
      // canonical form is just `name`.
      let _ = ns_prefix
    }
    Delim('*') => {
      let _ = self.advance()
      type_selector = Some(Universal)
      // Only the `*|` (any-namespace) prefix on `*` is observable in the
      // canonical serialization: `*|*` is dropped when subclasses follow,
      // whereas a bare `*` is kept.
      match ns_prefix {
        AnyNs => any_ns_universal = true
        _ => ()
      }
    }
    _ =>
      // No type / universal followed the namespace prefix — back off
      // entirely. Same effect as the original parser when there's
      // nothing to consume.
      match ns_prefix {
        NoPrefix => ()
        _ => self.pos = saved_pos
      }
  }

  // Parse subclass selectors
  while !self.is_at_end() {
    match self.peek() {
      // ID selector
      Hash(id, _) =>
        if not_allowed_after_pe(saw_pe, false) {
          return None
        } else {
          let _ = self.advance()
          subclasses.push(Id(id))
        }
      // Class selector
      Delim('.') =>
        if not_allowed_after_pe(saw_pe, false) {
          return None
        } else {
          let _ = self.advance()
          match self.peek() {
            Ident(class_name) => {
              let _ = self.advance()
              subclasses.push(Class(class_name))
            }
            _ => break
          }
        }
      // Attribute selector
      LeftBracket =>
        if not_allowed_after_pe(saw_pe, false) {
          return None
        } else {
          match self.parse_attribute_selector() {
            Some(attr) => subclasses.push(Attribute(attr))
            None => break
          }
        }
      // Pseudo-class or pseudo-element
      Colon => {
        let _ = self.advance()
        match self.peek() {
          // Double colon - pseudo-element
          Colon => {
            // After a non-::part pseudo-element, no further pseudo-
            // elements may appear. ::part allows exactly one chained
            // pseudo-element (e.g. ::part(x)::after).
            if pe_chain_closed(saw_pe) {
              return None
            }
            let _ = self.advance()
            match self.parse_pseudo_element() {
              Some(pe) => {
                subclasses.push(PseudoElement(pe))
                saw_pe = Some(pe)
              }
              None => return None
            }
          }
          // Single colon - pseudo-class (or legacy pseudo-element)
          _ =>
            // First try to parse as pseudo-class
            match self.parse_pseudo_class() {
              Some(pc) => {
                if !pseudo_class_allowed_after_pe(saw_pe, pc) {
                  return None
                }
                subclasses.push(PseudoClass(pc))
              }
              None =>
                // Try legacy pseudo-element syntax (:before, :after)
                if pe_chain_closed(saw_pe) {
                  return None
                } else {
                  match self.parse_pseudo_element() {
                    Some(pe) => {
                      subclasses.push(PseudoElement(pe))
                      saw_pe = Some(pe)
                    }
                    None => return None
                  }
                }
            }
        }
      }
      _ => break
    }
  }

  // Must have at least one selector component
  if type_selector is None && subclasses.is_empty() {
    return None
  }
  Some({ type_selector, subclasses, any_ns_universal })
}

///|
/// True if a non-pseudo subclass (id/class/attr) would be invalid after
/// the most recently seen pseudo-element. Per CSS Shadow Parts 1 only
/// `::part(...)` allows further subclasses; per CSS Scoping 1
/// `::slotted(...)` and other pseudo-elements do not.
fn not_allowed_after_pe(saw_pe : PseudoElement?, _allow_part : Bool) -> Bool {
  match saw_pe {
    None => false
    Some(Part(_)) => false // ::part allows id/class/attr — actually no per spec but be lenient
    Some(_) => true
  }
}

///|
/// Whether another pseudo-element may appear after `saw_pe`. Only
/// `::part(...)` keeps the chain open (one further pseudo-element).
fn pe_chain_closed(saw_pe : PseudoElement?) -> Bool {
  match saw_pe {
    None => false
    Some(Part(_)) => false
    Some(_) => true
  }
}

///|
/// CSS Selectors / Shadow DOM rules constraining which pseudo-classes
/// may follow a pseudo-element:
///
/// - After `::part(name)`: allow `:state`, `:hover`, `:active`,
///   `:focus`, `:focus-visible`, `:focus-within`, `:lang`, `:dir`.
/// - After `::slotted(...)`: no pseudo-classes are permitted.
/// - After other pseudo-elements: no pseudo-classes are permitted.
fn pseudo_class_allowed_after_pe(
  saw_pe : PseudoElement?,
  pc : PseudoClass,
) -> Bool {
  match saw_pe {
    None => true
    Some(Part(_)) =>
      // CSS Shadow Parts 1 §3.2: allow user-action, linguistic, form,
      // and a handful of structural pseudos after ::part. Reject the
      // tree-structural ones whose answer is undefined inside a part
      // (e.g. :first-child against a part of unknown depth) and reject
      // :has / :state-of-the-tree pseudos.
      match pc {
        State(_)
        | Hover
        | Active
        | Focus
        | FocusVisible
        | FocusWithin
        | Lang(_)
        | Dir(_)
        | Link
        | Visited
        | AnyLink
        | Enabled
        | Disabled
        | Checked
        | Indeterminate
        | Required
        | Optional
        | Valid
        | Invalid
        | ReadOnly
        | ReadWrite
        | Is(_)
        | Where(_)
        | Not(_) => true
        _ => false
      }
    Some(_) => false
  }
}

///|
fn SelectorParser::parse_attribute_selector(
  self : SelectorParser,
) -> AttributeSelector? {
  // Consume '['
  match self.peek() {
    LeftBracket => {
      let _ = self.advance()
    }
    _ => return None
  }
  self.skip_whitespace()

  // Optional namespace prefix on the attribute name (CSS Namespaces 3).
  let ns_prefix : NamespacePrefix = ns_prefix_collapse(self.parse_ns_prefix())
  let any_namespace = match ns_prefix {
    AnyNs => true
    _ => false
  }

  // Get attribute name
  let name = match self.peek() {
    Ident(n) => {
      let _ = self.advance()
      n
    }
    _ => return None
  }
  self.skip_whitespace()

  // Check for match operator or end
  let match_type : AttributeMatch = match self.peek() {
    RightBracket => {
      let _ = self.advance()
      return Some({
        name,
        match_type: Exists,
        case_insensitive: false,
        any_namespace,
      })
    }
    Delim('=') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Exact(v)
        None => return None
      }
    }
    Delim('~') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()
        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Includes(v)
        None => return None
      }
    }
    Delim('|') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()
        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => DashMatch(v)
        None => return None
      }
    }
    Delim('^') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()
        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Prefix(v)
        None => return None
      }
    }
    Delim('$') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()
        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Suffix(v)
        None => return None
      }
    }
    Delim('*') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()
        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Substring(v)
        None => return None
      }
    }
    _ => return None
  }
  self.skip_whitespace()

  // Check for case-insensitive flag
  let case_insensitive = match self.peek() {
    Ident(flag) =>
      if flag.to_lower() == "i" {
        let _ = self.advance()
        self.skip_whitespace()
        true
      } else if flag.to_lower() == "s" {
        let _ = self.advance()
        self.skip_whitespace()
        false
      } else {
        false
      }
    _ => false
  }

  // Consume ']'
  match self.peek() {
    RightBracket => {
      let _ = self.advance()
    }
    _ => return None
  }
  Some({ name, match_type, case_insensitive, any_namespace })
}

///|
fn SelectorParser::parse_attr_value(self : SelectorParser) -> String? {
  match self.peek() {
    Ident(v) => {
      let _ = self.advance()
      Some(v)
    }
    @token.Token::String(v) => {
      let _ = self.advance()
      Some(v)
    }
    _ => None
  }
}

///|
fn SelectorParser::parse_pseudo_element(
  self : SelectorParser,
) -> PseudoElement? {
  match self.peek() {
    Ident(name) => {
      // Resolve name BEFORE consuming so unknown pseudo-elements leave
      // the parser state unchanged. This matters when an outer parser
      // (e.g. inside :not()) wants to fall through on an unrecognized
      // ident.
      let result = match name.to_lower() {
        "before" => Some(Before)
        "after" => Some(After)
        "first-line" => Some(FirstLine)
        "first-letter" => Some(FirstLetter)
        "marker" => Some(Marker)
        "placeholder" => Some(Placeholder)
        "selection" => Some(Selection)
        "backdrop" => Some(Backdrop)
        "file-selector-button" => Some(FileSelectorButton)
        "placeholder-shown" => Some(PlaceholderShown)
        "target-text" => Some(TargetText)
        "spelling-error" => Some(SpellingError)
        "grammar-error" => Some(GrammarError)
        "cue" => Some(Cue)
        _ => None
      }
      match result {
        Some(_) => {
          let _ = self.advance()
          result
        }
        None => None
      }
    }
    Function(name) => {
      let _ = self.advance()
      let name_lower = name.to_lower()
      match name_lower {
        "part" => {
          // ::part(<ident>+) — one or more identifiers, whitespace-
          // separated. CSS Shadow Parts 1.
          self.skip_whitespace()
          let names : Array[String] = []
          while true {
            match self.peek() {
              Ident(part_name) => {
                let _ = self.advance()
                names.push(part_name)
                self.skip_whitespace()
              }
              _ => break
            }
          }
          match (self.peek(), names.length()) {
            (RightParen, n) if n > 0 => {
              let _ = self.advance()
              Some(Part(names))
            }
            _ => None
          }
        }
        "slotted" => {
          // ::slotted(<compound-selector-list>) — CSS Scoping 1.
          self.skip_whitespace()
          let selectors = self.parse_compound_selector_list_until_paren()
          match self.peek() {
            RightParen =>
              if selectors.is_empty() {
                None
              } else {
                let _ = self.advance()
                Some(Slotted(selectors))
              }
            _ => None
          }
        }
        _ => None
      }
    }
    _ => None
  }
}

///|

///|
/// CSS Selectors 4 — the argument of `:not()` may not contain pseudo-
/// elements. (Unknown pseudo-classes have already been rejected by
/// `parse_pseudo_class` returning None.)
fn compound_has_pseudo_element(c : CompoundSelector) -> Bool {
  for sub in c.subclasses {
    match sub {
      PseudoElement(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn complex_has_pseudo_element(c : ComplexSelector) -> Bool {
  if compound_has_pseudo_element(c.head) {
    return true
  }
  for step in c.tail {
    if compound_has_pseudo_element(step.selector) {
      return true
    }
  }
  false
}

///|
fn not_arg_has_invalid(selectors : Array[ComplexSelector]) -> Bool {
  for s in selectors {
    if complex_has_pseudo_element(s) {
      return true
    }
  }
  false
}

///|
/// CSS Scoping 1: `:host()` / `:host-context()` accept a single
/// `<compound-selector>`. The compound-selector restriction extends
/// recursively through `:not()`, `:is()`, `:where()`, and `:has()`: no
/// inner pseudo-class may contain a complex selector with combinators.
fn compound_is_strictly_compound(c : CompoundSelector) -> Bool {
  for sub in c.subclasses {
    match sub {
      PseudoClass(pc) =>
        if !pseudo_class_is_strictly_compound(pc) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn complex_is_strictly_compound(c : ComplexSelector) -> Bool {
  if c.tail.length() > 0 {
    return false
  }
  compound_is_strictly_compound(c.head)
}

///|
fn pseudo_class_is_strictly_compound(pc : PseudoClass) -> Bool {
  match pc {
    Not(sels) | Is(sels) | Where(sels) => {
      for s in sels {
        if !complex_is_strictly_compound(s) {
          return false
        }
      }
      true
    }
    Has(rels) => {
      for r in rels {
        if !complex_is_strictly_compound(r.selector) {
          return false
        }
      }
      true
    }
    HostFunc(c) | HostContextFunc(c) => compound_is_strictly_compound(c)
    _ => true
  }
}

///|
fn SelectorParser::parse_pseudo_class(self : SelectorParser) -> PseudoClass? {
  match self.peek() {
    Ident(name) => {
      // Check if it's a known pseudo-class BEFORE consuming the token
      let result = match name.to_lower() {
        "first-child" => Some(FirstChild)
        "last-child" => Some(LastChild)
        "only-child" => Some(OnlyChild)
        "first-of-type" => Some(FirstOfType)
        "last-of-type" => Some(LastOfType)
        "only-of-type" => Some(OnlyOfType)
        "root" => Some(Root)
        "empty" => Some(Empty)
        "hover" => Some(Hover)
        "active" => Some(Active)
        "focus" => Some(Focus)
        "focus-visible" => Some(FocusVisible)
        "focus-within" => Some(FocusWithin)
        "link" => Some(Link)
        "visited" => Some(Visited)
        "any-link" => Some(AnyLink)
        "enabled" => Some(Enabled)
        "disabled" => Some(Disabled)
        "checked" => Some(Checked)
        "indeterminate" => Some(Indeterminate)
        "required" => Some(Required)
        "optional" => Some(Optional)
        "valid" => Some(Valid)
        "invalid" => Some(Invalid)
        "read-only" => Some(ReadOnly)
        "read-write" => Some(ReadWrite)
        "host" => Some(Host)
        "heading" => Some(Heading([]))
        _ => None
      }
      // Only consume the token if it matched
      match result {
        Some(_) => {
          let _ = self.advance()
          result
        }
        None => None
      }
    }
    Function(name) => {
      let _ = self.advance() // Consume the Function token
      let name_lower = name.to_lower()
      match name_lower {
        "nth-child" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthChild(e))
                None => None
              }
            }
            _ => None
          }
        }
        "nth-last-child" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthLastChild(e))
                None => None
              }
            }
            _ => None
          }
        }
        "nth-of-type" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthOfType(e))
                None => None
              }
            }
            _ => None
          }
        }
        "nth-last-of-type" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthLastOfType(e))
                None => None
              }
            }
            _ => None
          }
        }
        "not" => {
          self.skip_whitespace()
          let selectors = self.parse_complex_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              // CSS Selectors 4: empty :not() argument is invalid.
              // Also reject if any inner selector contains a pseudo-element
              // or an unknown pseudo (per spec).
              if selectors.is_empty() {
                None
              } else if not_arg_has_invalid(selectors) {
                None
              } else {
                Some(Not(selectors))
              }
            }
            _ => None
          }
        }
        "is" => {
          self.skip_whitespace()
          let selectors = self.parse_complex_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              Some(Is(selectors))
            }
            _ => None
          }
        }
        "where" => {
          self.skip_whitespace()
          let selectors = self.parse_complex_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              Some(Where(selectors))
            }
            _ => None
          }
        }
        "has" => {
          self.skip_whitespace()
          let selectors = self.parse_relative_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              // CSS Selectors 4: empty :has() argument is invalid.
              if selectors.is_empty() {
                None
              } else {
                Some(Has(selectors))
              }
            }
            _ => None
          }
        }
        "host" => {
          self.skip_whitespace()
          // :host(<compound-selector>) — single compound, not list.
          let compound = self.parse_compound_selector()
          self.skip_whitespace()
          match (self.peek(), compound) {
            (RightParen, Some(c)) =>
              if compound_is_strictly_compound(c) {
                let _ = self.advance()
                Some(HostFunc(c))
              } else {
                None
              }
            _ => None
          }
        }
        "host-context" => {
          self.skip_whitespace()
          let compound = self.parse_compound_selector()
          self.skip_whitespace()
          match (self.peek(), compound) {
            (RightParen, Some(c)) =>
              if compound_is_strictly_compound(c) {
                let _ = self.advance()
                Some(HostContextFunc(c))
              } else {
                None
              }
            _ => None
          }
        }
        "heading" => {
          // :heading(N, ...) — comma-separated list of integer levels.
          self.skip_whitespace()
          let levels : Array[Int] = []
          let mut ok = true
          while true {
            match self.peek() {
              Number(n, @token.NumType::Integer) => {
                let _ = self.advance()
                levels.push(n.to_int())
                self.skip_whitespace()
                match self.peek() {
                  Comma => {
                    let _ = self.advance()
                    self.skip_whitespace()
                  }
                  RightParen => break
                  _ => {
                    ok = false
                    break
                  }
                }
              }
              _ => {
                ok = false
                break
              }
            }
          }
          if ok && levels.length() > 0 && self.peek() is RightParen {
            let _ = self.advance()
            Some(Heading(levels))
          } else {
            None
          }
        }
        "dir" => {
          self.skip_whitespace()
          match self.peek() {
            Ident(v) => {
              let _ = self.advance()
              self.skip_whitespace()
              match self.peek() {
                RightParen => {
                  let _ = self.advance()
                  Some(Dir(v))
                }
                _ => None
              }
            }
            _ => None
          }
        }
        "lang" => {
          self.skip_whitespace()
          let tags : Array[String] = []
          while true {
            match self.peek() {
              Ident(v) => {
                let _ = self.advance()
                tags.push(v)
              }
              @token.Token::String(v) => {
                let _ = self.advance()
                tags.push(v)
              }
              _ => break
            }
            self.skip_whitespace()
            match self.peek() {
              Comma => {
                let _ = self.advance()
                self.skip_whitespace()
              }
              _ => break
            }
          }
          match (self.peek(), tags.is_empty()) {
            (RightParen, false) => {
              let _ = self.advance()
              Some(Lang(tags))
            }
            _ => None
          }
        }
        "state" => {
          self.skip_whitespace()
          let state = self.parse_attr_value()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match state {
                Some(token) => Some(State(token))
                None => None
              }
            }
            _ => None
          }
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn SelectorParser::parse_nth_expr(self : SelectorParser) -> NthExpr? {
  self.skip_whitespace()

  // Handle keywords: odd, even
  match self.peek() {
    Ident(kw) => {
      // Match against the lowercase identifier. Supported forms:
      //   "odd", "even"
      //   "n"           a=1, b=parse_nth_b() (allows trailing ± N)
      //   "-n"          a=-1, b=parse_nth_b()
      //   "n-<digits>"  a=1,  b=-<digits>    (CSS Selectors 4 ndashdigit-ident)
      //   "-n-<digits>" a=-1, b=-<digits>
      // Bare `n-`/`-n-` followed by whitespace + integer is NOT
      // a valid An+B form per spec.
      let kw_lower = kw.to_lower()
      if kw_lower == "odd" {
        let _ = self.advance()
        return Some({ a: 2, b: 1 })
      }
      if kw_lower == "even" {
        let _ = self.advance()
        return Some({ a: 2, b: 0 })
      }
      if kw_lower == "n" {
        let _ = self.advance()
        return self.finish_nth_after_n(1)
      }
      if kw_lower == "-n" {
        let _ = self.advance()
        return self.finish_nth_after_n(-1)
      }
      match ndashdigit_to_b(kw_lower, "n-") {
        Some(b) => {
          let _ = self.advance()
          return Some({ a: 1, b })
        }
        None => ()
      }
      match ndashdigit_to_b(kw_lower, "-n-") {
        Some(b) => {
          let _ = self.advance()
          return Some({ a: -1, b })
        }
        None => ()
      }
      // Bare `n-` / `-n-` ident: must be followed (after optional
      // whitespace) by a **signless** integer. CSS Selectors 4 only
      // accepts the `<ndash-ident> <signless-integer>` shape; a signed
      // integer after `n-` is a parse error (the second sign comes
      // from the integer token, not from the syntactic `+`/`-`).
      if kw_lower == "n-" {
        return self.finish_ndash_int(1)
      }
      if kw_lower == "-n-" {
        return self.finish_ndash_int(-1)
      }
      return None
    }
    Dimension(num, unit) => {
      let unit_lower = unit.to_lower()
      if unit_lower == "n" {
        let _ = self.advance()
        return self.finish_nth_after_n(num.to_int())
      }
      // ndashdigit-dimension, e.g. `5n-3` lexes as Dimension(5, "n-3").
      match ndashdigit_to_b(unit_lower, "n-") {
        Some(b) => {
          let _ = self.advance()
          return Some({ a: num.to_int(), b })
        }
        None => ()
      }
      // `<int>n-` dimension followed by signless integer (e.g. `5n- 3`).
      if unit_lower == "n-" {
        return self.finish_ndash_int(num.to_int())
      }
      // Fallback for `5n+3` lex shapes (unit_lower starts with "n+").
      if unit_lower.length() > 1 && unit_lower[0] == 'n' {
        let suffix = unit_lower.unsafe_substring(
          start=1,
          end=unit_lower.length(),
        )
        if suffix.length() > 1 && suffix[0] == '+' {
          let b = @string.parse_int(
            suffix.unsafe_substring(start=1, end=suffix.length()),
          ) catch {
            _ => return None
          }
          let _ = self.advance()
          return Some({ a: num.to_int(), b })
        }
        return None
      }
      return None
    }
    Number(num, _) => {
      let _ = self.advance()
      // Just a number = 0n+B
      return Some({ a: 0, b: num.to_int() })
    }
    Delim('+') => {
      // `+` must be immediately followed by `n`-form ident; CSS
      // Selectors 4 forbids whitespace between `+` and what follows,
      // and forbids `+ <signed-integer>` (which is just `<signed-integer>`).
      let _ = self.advance()
      match self.peek() {
        Ident(kw) => {
          let kw_lower = kw.to_lower()
          if kw_lower == "n" {
            let _ = self.advance()
            return self.finish_nth_after_n(1)
          }
          if kw_lower == "n-" {
            return self.finish_ndash_int(1)
          }
          match ndashdigit_to_b(kw_lower, "n-") {
            Some(b) => {
              let _ = self.advance()
              return Some({ a: 1, b })
            }
            None => return None
          }
        }
        _ => return None
      }
    }
    _ => return None
  }
}

///|
/// After consuming a `<n-form>-` shape (`n-`, `-n-`, `<int>n-`),
/// require a signless integer next. WPT cases like `5n- 5` are valid
/// (canonicalize to `5n-5`); `5n- -5` / `5n- +5` are parse errors.
fn SelectorParser::finish_ndash_int(self : SelectorParser, a : Int) -> NthExpr? {
  let _ = self.advance()
  self.skip_whitespace()
  match self.peek() {
    Number(n, _) => {
      // When sign info is available, enforce signless; legacy callers
      // (parser built without signs) keep the lenient behavior.
      match self.signs {
        Some(_) => if self.is_signed_at(self.pos) { return None }
        None => ()
      }
      let _ = self.advance()
      Some({ a, b: -n.to_int() })
    }
    _ => None
  }
}

///|
/// After consuming an `<n-form>` (`n`, `-n`, `+n`, or `<int>n`) with
/// coefficient `a`, optionally parse the trailing `b` part:
///   <signed-integer>  → b = signed value (e.g. `5n -3`)
///   '+' <signless>    → b = +value
///   '-' <signless>    → b = -value
///   (nothing)         → b = 0
/// Returns None if any of the surrounding shapes are spec-invalid
/// (e.g. `5n +3` with double sign, `5n 3` with no operator).
fn SelectorParser::finish_nth_after_n(
  self : SelectorParser,
  a : Int,
) -> NthExpr? {
  // Snapshot position to peek the next non-whitespace token; we need
  // to distinguish "no whitespace" from "whitespace + signed-integer".
  self.skip_whitespace()
  match self.peek() {
    Delim('+') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.peek() {
        Number(n, _) => {
          if self.is_signed_at(self.pos) {
            return None
          }
          let _ = self.advance()
          return Some({ a, b: n.to_int() })
        }
        _ => return None
      }
    }
    Delim('-') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.peek() {
        Number(n, _) => {
          if self.is_signed_at(self.pos) {
            return None
          }
          let _ = self.advance()
          return Some({ a, b: -n.to_int() })
        }
        _ => return None
      }
    }
    Number(n, _) => {
      // <signed-integer> form. The number MUST have an explicit sign
      // (else it'd be `<n-form> <signless-int>` which is invalid).
      // Legacy callers without sign info accept this for back-compat.
      match self.signs {
        Some(_) => if !self.is_signed_at(self.pos) { return None }
        None => ()
      }
      let _ = self.advance()
      return Some({ a, b: n.to_int() })
    }
    _ => return Some({ a, b: 0 })
  }
}

///|
/// Parse `<prefix><digits>` patterns from a lowercased identifier. The
/// prefix is one of "n-" / "-n-"; the returned integer is the negative
/// of the digit run (the `-` is part of the ident token).
fn ndashdigit_to_b(name : String, prefix : String) -> Int? {
  if !name.has_prefix(prefix) {
    return None
  }
  let digits = name.unsafe_substring(start=prefix.length(), end=name.length())
  if digits.is_empty() {
    return None
  }
  // All remaining chars must be digits.
  for i in 0..<digits.length() {
    let c = digits[i].to_int().unsafe_to_char()
    if c < '0' || c > '9' {
      return None
    }
  }
  let n = @string.parse_int(digits) catch { _ => return None }
  Some(-n)
}

///|
fn SelectorParser::parse_compound_selector_list_until_paren(
  self : SelectorParser,
) -> Array[CompoundSelector] {
  let result : Array[CompoundSelector] = []
  while !self.is_at_end() {
    self.skip_whitespace()
    match self.peek() {
      RightParen | EOF => break
      Comma => {
        let _ = self.advance()
      }
      _ =>
        match self.parse_compound_selector() {
          Some(sel) => result.push(sel)
          None => break
        }
    }
  }
  result
}

///|
fn SelectorParser::parse_complex_selector_list_until_paren(
  self : SelectorParser,
) -> Array[ComplexSelector] {
  let result : Array[ComplexSelector] = []
  while !self.is_at_end() {
    self.skip_whitespace()
    match self.peek() {
      RightParen | EOF => break
      Comma => {
        let _ = self.advance()
      }
      _ =>
        match self.parse_complex_selector() {
          Some(sel) => result.push(sel)
          None => break
        }
    }
  }
  result
}

///|
fn SelectorParser::parse_relative_selector_list_until_paren(
  self : SelectorParser,
) -> Array[RelativeSelector] {
  let result : Array[RelativeSelector] = []
  while !self.is_at_end() {
    self.skip_whitespace()
    match self.peek() {
      RightParen | EOF => break
      Comma => {
        let _ = self.advance()
      }
      _ => {
        // Check for optional leading combinator
        let combinator : Combinator? = match self.peek() {
          Delim('>') => {
            let _ = self.advance()
            self.skip_whitespace()
            Some(Child)
          }
          Delim('+') => {
            let _ = self.advance()
            self.skip_whitespace()
            Some(NextSibling)
          }
          Delim('~') => {
            let _ = self.advance()
            self.skip_whitespace()
            Some(SubsequentSibling)
          }
          _ => None
        }
        match self.parse_complex_selector() {
          Some(sel) => result.push({ combinator, selector: sel })
          None => break
        }
      }
    }
  }
  result
}

///|
/// Convenience function to parse a selector from CSS text
pub fn parse_selector_text(css : String) -> ComplexSelector? {
  let (tokens, signs) = @token.tokenize_with_signs(css)
  SelectorParser::new_with_signs(tokens, signs).parse_top_selector()
}

///|
/// Convenience function to parse a selector list from CSS text
pub fn parse_selector_list_text(css : String) -> SelectorList? {
  let (tokens, signs) = @token.tokenize_with_signs(css)
  SelectorParser::new_with_signs(tokens, signs).parse_selector_list()
}

///|
/// Parse a selector-list from an existing token stream in-place
/// (`tokens[start..end]`). This is the fast path used by
/// `parser/stylesheet`: callers reuse tokens they have already lexed
/// instead of stringifying + re-tokenizing the slice.
///
/// Returns `(text, selector)` pairs because the stylesheet parser
/// stores both the original source text and the parsed selector for
/// every rule; we synthesize the text from the same slice.
pub fn parse_selector_list_from_tokens(
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> Array[ComplexSelector] {
  let result : Array[ComplexSelector] = []
  // Find top-level commas inside the slice to split into selectors.
  let mut depth = 0
  let mut segment_start = start
  let mut i = start
  while i < end {
    match tokens[i] {
      @token.Token::EOF => break
      @token.Token::Function(_)
      | @token.Token::LeftParen
      | @token.Token::LeftBracket => depth = depth + 1
      @token.Token::RightParen | @token.Token::RightBracket =>
        if depth > 0 {
          depth = depth - 1
        }
      @token.Token::Comma =>
        if depth == 0 {
          match parse_selector_slice(tokens, segment_start, i) {
            Some(sel) => result.push(sel)
            None => ()
          }
          segment_start = i + 1
        }
      _ => ()
    }
    i = i + 1
  }
  // Final segment.
  match parse_selector_slice(tokens, segment_start, end) {
    Some(sel) => result.push(sel)
    None => ()
  }
  result
}

///|
fn parse_selector_slice(
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> ComplexSelector? {
  let parser = SelectorParser::from_slice(tokens, start, end)
  parser.skip_whitespace()
  match parser.parse_complex_selector() {
    None => None
    Some(sel) => {
      parser.skip_whitespace()
      if parser.is_at_end() {
        Some(sel)
      } else {
        None
      }
    }
  }
}
