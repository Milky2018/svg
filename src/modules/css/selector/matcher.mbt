///|
/// CSS Selector Matcher
/// Determines if an element matches a given selector

///|
/// Shadow DOM scoping information for selector matching.
///
/// `host` is the shadow host for the current styling scope.
/// `host_ancestors` is the light-tree ancestor chain used by
/// `:host-context()`. If it is empty, the matcher falls back to walking
/// `host.parent`.
/// `assigned_slot` is the slot assigned to the element currently being matched
/// by `::slotted()`.
pub(all) struct ShadowContext {
  host : Element
  host_ancestors : Array[Element]
  assigned_slot : Element?
}

///|
pub fn ShadowContext::new(host : Element) -> ShadowContext {
  { host, host_ancestors: [], assigned_slot: None }
}

///|
pub fn ShadowContext::set_host_ancestors(
  self : ShadowContext,
  host_ancestors : Array[Element],
) -> ShadowContext {
  { ..self, host_ancestors, }
}

///|
pub fn ShadowContext::set_assigned_slot(
  self : ShadowContext,
  assigned_slot : Element,
) -> ShadowContext {
  { ..self, assigned_slot: Some(assigned_slot) }
}

///|
/// Check if an element matches a simple selector. Hot path — class lookup
/// is inlined to skip the call into `Element::has_class`.
fn matches_simple(element : Element, selector : SimpleSelector) -> Bool {
  matches_simple_with_shadow_context(element, selector, None)
}

///|
fn matches_simple_with_shadow_context(
  element : Element,
  selector : SimpleSelector,
  context : ShadowContext?,
) -> Bool {
  match selector {
    Type(name) => element.tag_name == name
    Universal => true
    Id(id) =>
      match element.id {
        Some(elem_id) => elem_id == id
        None => false
      }
    Class(cls) => {
      for c in element.classes {
        if c == cls {
          return true
        }
      }
      false
    }
    Attribute(attr_sel) => matches_attribute(element, attr_sel)
    PseudoClass(pc) =>
      matches_pseudo_class_with_shadow_context(element, pc, context)
    PseudoElement(Slotted(selectors)) =>
      matches_slotted(element, selectors, context)
    // Pseudo-elements like ::before/::after attach virtual content that does
    // not exist in the DOM; selectors targeting them never match the
    // underlying element.
    PseudoElement(_) => false
  }
}

///|
/// Fast prefix check using char-code comparison. MoonBit's
/// `String::has_prefix` walks via UTF iterators and measures ~450 ns even for
/// short prefixes; this hot-path variant runs in ~30 ns by comparing
/// UTF-16 code units directly.
fn fast_has_prefix(s : String, prefix : String) -> Bool {
  let pl = prefix.length()
  if pl > s.length() {
    return false
  }
  for i in 0..<pl {
    if s[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
/// Fast suffix check mirroring `fast_has_prefix`.
fn fast_has_suffix(s : String, suffix : String) -> Bool {
  let sl = s.length()
  let nl = suffix.length()
  if nl > sl {
    return false
  }
  let offset = sl - nl
  for i in 0..<nl {
    if s[offset + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
/// Specialized `[attr|=value]` check: matches when `value` equals the
/// attribute, or is followed by `-`. Avoids constructing a new string for
/// the `value + "-"` prefix.
fn fast_dash_match(value : String, query : String) -> Bool {
  let ql = query.length()
  let vl = value.length()
  if vl <= ql {
    return false // already handled by `==` in caller
  }
  if value[ql] != '-' {
    return false
  }
  for i in 0..<ql {
    if value[i] != query[i] {
      return false
    }
  }
  true
}

///|
/// Fast substring check using char-code scan. Comparable to a naive O(n*m)
/// search but with no per-char allocation.
fn fast_contains(s : String, needle : String) -> Bool {
  let nl = needle.length()
  if nl == 0 {
    return true
  }
  let sl = s.length()
  if nl > sl {
    return false
  }
  let last = sl - nl
  let first = needle[0]
  for i in 0..<=last {
    if s[i] == first {
      let mut all = true
      let mut j = 1
      while j < nl {
        if s[i + j] != needle[j] {
          all = false
          break
        }
        j = j + 1
      }
      if all {
        return true
      }
    }
  }
  false
}

///|
/// Check if an element matches an attribute selector. Hot path — case
/// insensitivity is rare so we keep the case-sensitive branch closure-free.
fn matches_attribute(element : Element, selector : AttributeSelector) -> Bool {
  let attr_value = element.get_attribute(selector.name)
  match (selector.match_type, attr_value) {
    (Exists, Some(_)) => true
    (Exists, None) => false
    (_, None) => false
    (Exact(value), Some(v)) =>
      if selector.case_insensitive {
        v.to_lower() == value.to_lower()
      } else {
        v == value
      }
    (Includes(value), Some(v)) => {
      let parts = split_whitespace(v)
      for part in parts {
        let hit = if selector.case_insensitive {
          part.to_lower() == value.to_lower()
        } else {
          part == value
        }
        if hit {
          return true
        }
      }
      false
    }
    (DashMatch(value), Some(v)) => {
      let (a, b) = if selector.case_insensitive {
        (v.to_lower(), value.to_lower())
      } else {
        (v, value)
      }
      a == b || fast_dash_match(a, b)
    }
    (Prefix(value), Some(v)) =>
      if selector.case_insensitive {
        fast_has_prefix(v.to_lower(), value.to_lower())
      } else {
        fast_has_prefix(v, value)
      }
    (Suffix(value), Some(v)) =>
      if selector.case_insensitive {
        fast_has_suffix(v.to_lower(), value.to_lower())
      } else {
        fast_has_suffix(v, value)
      }
    (Substring(value), Some(v)) =>
      if selector.case_insensitive {
        fast_contains(v.to_lower(), value.to_lower())
      } else {
        fast_contains(v, value)
      }
  }
}

///|
/// Split string by whitespace
fn split_whitespace(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  // Track the pending segment length with a counter instead of materializing
  // `current.to_string()` on every whitespace char (and at the end) just to
  // test emptiness — that allocated a throwaway String per character.
  let mut current_len = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if current_len > 0 {
        result.push(current.to_string())
        current.reset()
        current_len = 0
      }
    } else {
      current.write_char(c)
      current_len = current_len + 1
    }
  }
  if current_len > 0 {
    result.push(current.to_string())
  }
  result
}

///|
/// Check if an element matches a pseudo-class
fn matches_pseudo_class(element : Element, pc : PseudoClass) -> Bool {
  matches_pseudo_class_with_shadow_context(element, pc, None)
}

///|
fn matches_pseudo_class_with_shadow_context(
  element : Element,
  pc : PseudoClass,
  context : ShadowContext?,
) -> Bool {
  match pc {
    FirstChild => element.is_first_child()
    LastChild => element.is_last_child()
    OnlyChild => element.sibling_count == 1
    NthChild(expr) => matches_nth(element.sibling_index, expr)
    NthLastChild(expr) => {
      let from_end = element.sibling_count - element.sibling_index + 1
      matches_nth(from_end, expr)
    }
    FirstOfType =>
      // Would need to check siblings of same type
      // For now, approximate with first-child
      element.is_first_child()
    LastOfType => element.is_last_child()
    OnlyOfType => element.sibling_count == 1
    NthOfType(expr) =>
      // Would need type-specific index
      matches_nth(element.sibling_index, expr)
    NthLastOfType(expr) => {
      let from_end = element.sibling_count - element.sibling_index + 1
      matches_nth(from_end, expr)
    }
    Root =>
      match element.parent {
        None => true
        Some(_) => false
      }
    Empty => element.children.is_empty()
    Not(selectors) => {
      for sel in selectors {
        if matches_complex_with_shadow_context(element, sel, context) {
          return false
        }
      }
      true
    }
    Is(selectors) => {
      for sel in selectors {
        if matches_complex_with_shadow_context(element, sel, context) {
          return true
        }
      }
      false
    }
    Where(selectors) => {
      for sel in selectors {
        if matches_complex_with_shadow_context(element, sel, context) {
          return true
        }
      }
      false
    }
    Has(selectors) =>
      matches_has_with_shadow_context(element, selectors, context)
    State(state) => {
      for token in element.custom_states {
        if token == state {
          return true
        }
      }
      false
    }
    // User-action pseudo-classes - these depend on runtime state
    // For static matching, we return false (or could check element state)
    Hover | Active | Focus | FocusVisible | FocusWithin => false
    // Link pseudo-classes. Static rendering has no visited-history state, so
    // :visited must not match by default; otherwise later visited rules override
    // normal link styling.
    Link | AnyLink =>
      element.tag_name == "a" && element.get_attribute("href") is Some(_)
    Visited => false
    Host => matches_shadow_host(element, context)
    HostFunc(compound) =>
      matches_shadow_host(element, context) &&
      matches_compound_with_shadow_context(element, compound, context)
    HostContextFunc(compound) =>
      matches_shadow_host(element, context) &&
      shadow_context_has_host_context(compound, context)
    // :dir(ltr|rtl) — depends on inherited direction. Static matching
    // without a direction property defaults to no match.
    Dir(_) => false
    // :lang(...) — matches by element language attribute. Without
    // explicit language metadata on our Element type we treat as miss.
    Lang(_) => false
    // :heading / :heading(N) — match HTML heading elements.
    Heading(levels) =>
      match element.tag_name {
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
          if levels.is_empty() {
            return true
          }
          let n = match element.tag_name {
            "h1" => 1
            "h2" => 2
            "h3" => 3
            "h4" => 4
            "h5" => 5
            "h6" => 6
            _ => 0
          }
          for level in levels {
            if level == n {
              return true
            }
          }
          false
        }
        _ => false
      }
    // Form pseudo-classes - would need form element state
    Enabled
    | Disabled
    | Checked
    | Indeterminate
    | Required
    | Optional
    | Valid
    | Invalid
    | ReadOnly
    | ReadWrite => false
  }
}

///|
fn matches_shadow_host(element : Element, context : ShadowContext?) -> Bool {
  match context {
    None => false
    Some(ctx) => physical_equal(element, ctx.host)
  }
}

///|
fn shadow_context_has_host_context(
  compound : CompoundSelector,
  context : ShadowContext?,
) -> Bool {
  match context {
    None => false
    Some(ctx) => {
      if !ctx.host_ancestors.is_empty() {
        for ancestor in ctx.host_ancestors {
          if matches_compound_with_shadow_context(ancestor, compound, context) {
            return true
          }
        }
        return false
      }
      let mut ancestor = ctx.host.parent
      while true {
        match ancestor {
          None => break
          Some(anc) => {
            if matches_compound_with_shadow_context(anc, compound, context) {
              return true
            }
            ancestor = anc.parent
          }
        }
      }
      false
    }
  }
}

///|
fn descendant_matches_complex_with_shadow_context(
  element : Element,
  selector : ComplexSelector,
  context : ShadowContext?,
) -> Bool {
  for child in element.children {
    if matches_complex_with_shadow_context(child, selector, context) {
      return true
    }
    if descendant_matches_complex_with_shadow_context(child, selector, context) {
      return true
    }
  }
  false
}

///|
fn direct_child_matches_complex_with_shadow_context(
  element : Element,
  selector : ComplexSelector,
  context : ShadowContext?,
) -> Bool {
  for child in element.children {
    if matches_complex_with_shadow_context(child, selector, context) {
      return true
    }
  }
  false
}

///|
fn next_sibling_matches_complex_with_shadow_context(
  element : Element,
  selector : ComplexSelector,
  context : ShadowContext?,
) -> Bool {
  match element.next_sibling {
    Some(next) => matches_complex_with_shadow_context(next, selector, context)
    None => false
  }
}

///|
fn subsequent_sibling_matches_complex_with_shadow_context(
  element : Element,
  selector : ComplexSelector,
  context : ShadowContext?,
) -> Bool {
  let mut sibling = element.next_sibling
  while true {
    match sibling {
      None => break
      Some(sib) => {
        if matches_complex_with_shadow_context(sib, selector, context) {
          return true
        }
        sibling = sib.next_sibling
      }
    }
  }
  false
}

///|
fn matches_relative_selector_with_shadow_context(
  element : Element,
  relative : RelativeSelector,
  context : ShadowContext?,
) -> Bool {
  match relative.combinator {
    None =>
      descendant_matches_complex_with_shadow_context(
        element,
        relative.selector,
        context,
      )
    Some(Descendant) =>
      descendant_matches_complex_with_shadow_context(
        element,
        relative.selector,
        context,
      )
    Some(Child) =>
      direct_child_matches_complex_with_shadow_context(
        element,
        relative.selector,
        context,
      )
    Some(NextSibling) =>
      next_sibling_matches_complex_with_shadow_context(
        element,
        relative.selector,
        context,
      )
    Some(SubsequentSibling) =>
      subsequent_sibling_matches_complex_with_shadow_context(
        element,
        relative.selector,
        context,
      )
  }
}

///|
fn matches_has_with_shadow_context(
  element : Element,
  selectors : Array[RelativeSelector],
  context : ShadowContext?,
) -> Bool {
  for relative in selectors {
    if matches_relative_selector_with_shadow_context(element, relative, context) {
      return true
    }
  }
  false
}

///|
/// Check if index matches An+B expression
fn matches_nth(index : Int, expr : NthExpr) -> Bool {
  if expr.a == 0 {
    // Just check if index == b
    return index == expr.b
  }

  // Check if (index - b) is divisible by a
  let diff = index - expr.b
  if expr.a > 0 {
    // Positive a: diff must be >= 0 and divisible by a
    diff >= 0 && diff % expr.a == 0
  } else {
    // Negative a: diff must be <= 0 and divisible by |a|
    diff <= 0 && diff % expr.a == 0
  }
}

///|
/// Check if an element matches a compound selector
fn matches_compound(element : Element, selector : CompoundSelector) -> Bool {
  matches_compound_with_shadow_context(element, selector, None)
}

///|
fn compound_has_slotted(selector : CompoundSelector) -> Bool {
  for sub in selector.subclasses {
    match sub {
      PseudoElement(Slotted(_)) => return true
      _ => ()
    }
  }
  false
}

///|
fn matches_slotted(
  element : Element,
  selectors : Array[CompoundSelector],
  context : ShadowContext?,
) -> Bool {
  match context {
    None => false
    Some(ctx) =>
      match ctx.assigned_slot {
        None => false
        Some(_) => {
          for selector in selectors {
            if matches_compound_with_shadow_context(element, selector, context) {
              return true
            }
          }
          false
        }
      }
  }
}

///|
fn matches_slotted_compound(
  element : Element,
  selector : CompoundSelector,
  context : ShadowContext?,
) -> Bool {
  match context {
    None => false
    Some(ctx) =>
      match ctx.assigned_slot {
        None => false
        Some(slot) => {
          match selector.type_selector {
            Some(type_sel) =>
              if !matches_simple_with_shadow_context(slot, type_sel, context) {
                return false
              }
            None => ()
          }

          let mut found_slotted = false
          for sub in selector.subclasses {
            match sub {
              PseudoElement(Slotted(selectors)) => {
                found_slotted = true
                if !matches_slotted(element, selectors, context) {
                  return false
                }
              }
              _ =>
                if !matches_simple_with_shadow_context(slot, sub, context) {
                  return false
                }
            }
          }
          found_slotted
        }
      }
  }
}

///|
fn matches_compound_with_shadow_context(
  element : Element,
  selector : CompoundSelector,
  context : ShadowContext?,
) -> Bool {
  if compound_has_slotted(selector) {
    return matches_slotted_compound(element, selector, context)
  }

  // Check type selector
  match selector.type_selector {
    Some(type_sel) =>
      if !matches_simple_with_shadow_context(element, type_sel, context) {
        return false
      }
    None => ()
  }

  // Check all subclass selectors
  for sub in selector.subclasses {
    if !matches_simple_with_shadow_context(element, sub, context) {
      return false
    }
  }
  true
}

///|
/// Check if an element matches a complex selector
pub fn matches_complex(element : Element, selector : ComplexSelector) -> Bool {
  matches_complex_with_shadow_context(element, selector, None)
}

///|
pub fn matches_complex_with_shadow_context(
  element : Element,
  selector : ComplexSelector,
  context : ShadowContext?,
) -> Bool {
  // First, check if the element matches the head (rightmost/subject)
  if !matches_compound_with_shadow_context(element, selector.head, context) {
    return false
  }

  // If there's no tail, we're done
  if selector.tail.is_empty() {
    return true
  }

  // Walk up the tree following the combinators
  let mut current_element = element
  for step in selector.tail {
    match step.combinator {
      Descendant => {
        // Find any ancestor that matches
        let mut found = false
        let mut ancestor = current_element.parent
        while true {
          match ancestor {
            None => break
            Some(anc) => {
              if matches_compound_with_shadow_context(
                  anc,
                  step.selector,
                  context,
                ) {
                current_element = anc
                found = true
                break
              }
              ancestor = anc.parent
            }
          }
        }
        if !found {
          return false
        }
      }
      Child =>
        // Parent must match
        match current_element.parent {
          None => return false
          Some(parent) => {
            if !matches_compound_with_shadow_context(
                parent,
                step.selector,
                context,
              ) {
              return false
            }
            current_element = parent
          }
        }
      NextSibling =>
        // Previous sibling must match
        match current_element.prev_sibling {
          None => return false
          Some(prev) => {
            if !matches_compound_with_shadow_context(
                prev,
                step.selector,
                context,
              ) {
              return false
            }
            current_element = prev
          }
        }
      SubsequentSibling => {
        // Any previous sibling must match
        let mut found = false
        let mut sibling = current_element.prev_sibling
        while true {
          match sibling {
            None => break
            Some(sib) => {
              if matches_compound_with_shadow_context(
                  sib,
                  step.selector,
                  context,
                ) {
                current_element = sib
                found = true
                break
              }
              sibling = sib.prev_sibling
            }
          }
        }
        if !found {
          return false
        }
      }
    }
  }
  true
}

///|
/// Check if an element matches any selector in a list
pub fn matches_selector_list(element : Element, list : SelectorList) -> Bool {
  matches_selector_list_with_shadow_context(element, list, None)
}

///|
pub fn matches_selector_list_with_shadow_context(
  element : Element,
  list : SelectorList,
  context : ShadowContext?,
) -> Bool {
  for sel in list.selectors {
    if matches_complex_with_shadow_context(element, sel, context) {
      return true
    }
  }
  false
}
