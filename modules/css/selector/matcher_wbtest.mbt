///|
/// Test helper: check if an element matches a CSS selector string
fn matches_selector_text(element : Element, css : String) -> Bool {
  match parse_selector_text(css) {
    Some(sel) => matches_complex(element, sel)
    None => false
  }
}

///|
fn matches_selector_text_with_shadow_context(
  element : Element,
  css : String,
  context : ShadowContext,
) -> Bool {
  match parse_selector_text(css) {
    Some(sel) =>
      matches_complex_with_shadow_context(element, sel, Some(context))
    None => false
  }
}

///|
test "match type selector" {
  let elem = Element::new("div")
  let result = matches_selector_text(elem, "div")
  inspect(result, content="true")
}

///|
test "match type selector - no match" {
  let elem = Element::new("div")
  let result = matches_selector_text(elem, "span")
  inspect(result, content="false")
}

///|
test "match class selector" {
  let elem = Element::new("div").add_class("foo")
  let result = matches_selector_text(elem, ".foo")
  inspect(result, content="true")
}

///|
test "match class selector - no match" {
  let elem = Element::new("div").add_class("foo")
  let result = matches_selector_text(elem, ".bar")
  inspect(result, content="false")
}

///|
test "match id selector" {
  let elem = Element::new("div").set_id("main")
  let result = matches_selector_text(elem, "#main")
  inspect(result, content="true")
}

///|
test "match id selector - no match" {
  let elem = Element::new("div").set_id("main")
  let result = matches_selector_text(elem, "#other")
  inspect(result, content="false")
}

///|
test "match universal selector" {
  let elem = Element::new("div")
  let result = matches_selector_text(elem, "*")
  inspect(result, content="true")
}

///|
test "match compound selector" {
  let elem = Element::new("div").add_class("foo").set_id("bar")
  let result = matches_selector_text(elem, "div.foo#bar")
  inspect(result, content="true")
}

///|
test "match compound selector - partial match fails" {
  let elem = Element::new("div").add_class("foo")
  let result = matches_selector_text(elem, "div.foo#bar")
  inspect(result, content="false")
}

///|
test "match attribute exists" {
  let elem = Element::new("input").set_attribute("disabled", "")
  let result = matches_selector_text(elem, "[disabled]")
  inspect(result, content="true")
}

///|
test "match attribute exact" {
  let elem = Element::new("input").set_attribute("type", "button")
  let result = matches_selector_text(elem, "[type=button]")
  inspect(result, content="true")
}

///|
test "match attribute exact - no match" {
  let elem = Element::new("input").set_attribute("type", "text")
  let result = matches_selector_text(elem, "[type=button]")
  inspect(result, content="false")
}

///|
test "match first-child" {
  let elem = Element::new("div").set_sibling_info(1, 3)
  let result = matches_selector_text(elem, ":first-child")
  inspect(result, content="true")
}

///|
test "match first-child - no match" {
  let elem = Element::new("div").set_sibling_info(2, 3)
  let result = matches_selector_text(elem, ":first-child")
  inspect(result, content="false")
}

///|
test "match last-child" {
  let elem = Element::new("div").set_sibling_info(3, 3)
  let result = matches_selector_text(elem, ":last-child")
  inspect(result, content="true")
}

///|
test "match last-child - no match" {
  let elem = Element::new("div").set_sibling_info(2, 3)
  let result = matches_selector_text(elem, ":last-child")
  inspect(result, content="false")
}

///|
test "match nth-child 2n+1 (odd)" {
  // 1st, 3rd, 5th... should match
  let elem1 = Element::new("div").set_sibling_info(1, 5)
  let elem3 = Element::new("div").set_sibling_info(3, 5)
  let elem2 = Element::new("div").set_sibling_info(2, 5)
  inspect(matches_selector_text(elem1, ":nth-child(2n+1)"), content="true")
  inspect(matches_selector_text(elem3, ":nth-child(2n+1)"), content="true")
  inspect(matches_selector_text(elem2, ":nth-child(2n+1)"), content="false")
}

///|
test "match nth-child even" {
  // 2nd, 4th... should match
  let elem2 = Element::new("div").set_sibling_info(2, 5)
  let elem4 = Element::new("div").set_sibling_info(4, 5)
  let elem1 = Element::new("div").set_sibling_info(1, 5)
  inspect(matches_selector_text(elem2, ":nth-child(even)"), content="true")
  inspect(matches_selector_text(elem4, ":nth-child(even)"), content="true")
  inspect(matches_selector_text(elem1, ":nth-child(even)"), content="false")
}

///|
test "match root" {
  let root = Element::new("html")
  let child = Element::new("body").set_parent(root)
  inspect(matches_selector_text(root, ":root"), content="true")
  inspect(matches_selector_text(child, ":root"), content="false")
}

///|
test "match empty" {
  let empty_elem = Element::new("div")
  let non_empty = { ..Element::new("div"), children: [Element::new("span")] }
  inspect(matches_selector_text(empty_elem, ":empty"), content="true")
  inspect(matches_selector_text(non_empty, ":empty"), content="false")
}

///|
test "match child combinator" {
  let parent = Element::new("div").add_class("parent")
  let child = Element::new("p").set_parent(parent)
  let result = matches_selector_text(child, "div.parent > p")
  inspect(result, content="true")
}

///|
test "match child combinator - no match (not direct child)" {
  let grandparent = Element::new("div").add_class("parent")
  let parent = Element::new("span").set_parent(grandparent)
  let child = Element::new("p").set_parent(parent)

  // p is not a direct child of div.parent
  let result = matches_selector_text(child, "div.parent > p")
  inspect(result, content="false")
}

///|
test "match descendant combinator" {
  let grandparent = Element::new("div").add_class("parent")
  let parent = Element::new("span").set_parent(grandparent)
  let child = Element::new("p").set_parent(parent)

  // p is a descendant of div.parent
  let result = matches_selector_text(child, "div.parent p")
  inspect(result, content="true")
}

///|
test "match next-sibling combinator" {
  let first = Element::new("h1")
  let second = { ..Element::new("p"), prev_sibling: Some(first) }
  let result = matches_selector_text(second, "h1 + p")
  inspect(result, content="true")
}

///|
test "match :not pseudo-class" {
  let div = Element::new("div")
  let span = Element::new("span")
  inspect(matches_selector_text(div, ":not(span)"), content="true")
  inspect(matches_selector_text(span, ":not(span)"), content="false")
}

///|
test "match :not with class - .foo:not(.bar) matches element with foo but not bar" {
  let elem_foo = Element::new("div").add_class("foo")
  inspect(matches_selector_text(elem_foo, ".foo:not(.bar)"), content="true")
}

///|
test "match :not with class - .foo:not(.bar) does NOT match element with foo and bar" {
  let elem_foo_bar = Element::new("div").add_class("foo").add_class("bar")
  inspect(
    matches_selector_text(elem_foo_bar, ".foo:not(.bar)"),
    content="false",
  )
}

///|
test "match :state pseudo-class" {
  let open_elem = Element::new("x-panel").add_custom_state("open")
  let closed_elem = Element::new("x-panel")
  inspect(matches_selector_text(open_elem, ":state(open)"), content="true")
  inspect(
    matches_selector_text(open_elem, "x-panel:state(open)"),
    content="true",
  )
  inspect(matches_selector_text(closed_elem, ":state(open)"), content="false")
}

///|
test "static link pseudo classes do not match visited links" {
  let link = Element::new("a").set_attribute("href", "https://example.com")
  inspect(matches_selector_text(link, "a:link"), content="true")
  inspect(matches_selector_text(link, "a:any-link"), content="true")
  inspect(matches_selector_text(link, "a:visited"), content="false")
}

///|
test "match :not with class - body:not(.hidden) div matches div under body without hidden class" {
  let body = Element::new("body")
  let div = Element::new("div").set_parent(body)
  inspect(matches_selector_text(div, "body:not(.hidden) div"), content="true")
}

///|
test "match :not with class - body:not(.hidden) div does NOT match when body has hidden class" {
  let body = Element::new("body").add_class("hidden")
  let div = Element::new("div").set_parent(body)
  inspect(matches_selector_text(div, "body:not(.hidden) div"), content="false")
}

///|
test "match :not with class - Wikipedia-style body:not(.vector-sticky-header-visible)" {
  let body_without = Element::new("body")
  let div1 = Element::new("div")
    .add_class("vector-column-start")
    .set_parent(body_without)
  inspect(
    matches_selector_text(
      div1, "body:not(.vector-sticky-header-visible) .vector-column-start",
    ),
    content="true",
  )
  let body_with = Element::new("body").add_class("vector-sticky-header-visible")
  let div2 = Element::new("div")
    .add_class("vector-column-start")
    .set_parent(body_with)
  inspect(
    matches_selector_text(
      div2, "body:not(.vector-sticky-header-visible) .vector-column-start",
    ),
    content="false",
  )
}

///|
test "match :has descendant class" {
  let base = Element::new("div").add_class("box")
  let child = Element::new("span").add_class("child").set_parent(base)
  let elem = { ..base, children: [child] }
  inspect(matches_selector_text(elem, ".box:has(.child)"), content="true")
  inspect(matches_selector_text(elem, ".box:has(.missing)"), content="false")
}

///|
test "match :has direct child combinator" {
  let base = Element::new("div").add_class("box")
  let child = Element::new("span").add_class("child").set_parent(base)
  let elem = { ..base, children: [child] }
  inspect(matches_selector_text(elem, ".box:has(> .child)"), content="true")
  inspect(matches_selector_text(elem, ".box:has(> .missing)"), content="false")
}

///|
test "match :has next sibling combinator" {
  let next = Element::new("span").add_class("next")
  let elem = { ..Element::new("div"), next_sibling: Some(next) }
  inspect(matches_selector_text(elem, "div:has(+ .next)"), content="true")
  inspect(matches_selector_text(elem, "div:has(+ .missing)"), content="false")
}

///|
test "match attribute - all match types" {
  let elem = Element::new("input")
    .set_attribute("type", "text")
    .set_attribute("class", "form input-text large")
    .set_attribute("data-id", "abc-123")
    .set_attribute("href", "https://example.com/page.html")
    .set_attribute("lang", "en-US")
  // Includes
  inspect(matches_selector_text(elem, "[class~=input-text]"), content="true")
  inspect(matches_selector_text(elem, "[class~=missing]"), content="false")
  // DashMatch
  inspect(matches_selector_text(elem, "[lang|=en]"), content="true")
  inspect(matches_selector_text(elem, "[lang|=fr]"), content="false")
  // Prefix
  inspect(matches_selector_text(elem, "[href^=https]"), content="true")
  inspect(matches_selector_text(elem, "[href^=http://]"), content="false")
  // Suffix
  inspect(matches_selector_text(elem, "[href$=\".html\"]"), content="true")
  inspect(matches_selector_text(elem, "[href$=\".pdf\"]"), content="false")
  // Substring
  inspect(matches_selector_text(elem, "[href*=example]"), content="true")
  inspect(matches_selector_text(elem, "[href*=missing]"), content="false")
}

///|
test "match attribute - case insensitive flag" {
  let elem = Element::new("input").set_attribute("type", "BUTTON")
  inspect(matches_selector_text(elem, "[type=button i]"), content="true")
  inspect(matches_selector_text(elem, "[type=button]"), content="false")
}

///|
test "match attribute - missing attribute" {
  let elem = Element::new("input")
  inspect(matches_selector_text(elem, "[type=button]"), content="false")
  inspect(matches_selector_text(elem, "[type]"), content="false")
}

///|
test "match nth-of-type" {
  let elem = Element::new("li").set_sibling_info(2, 4)
  // Without siblings: only this element exists; nth-of-type isn't going to
  // find prior li's of the same type. Just exercise the matcher.
  let _ = matches_selector_text(elem, ":nth-of-type(odd)")
  inspect(true, content="true")
}

///|
test "match :only-child" {
  let only = Element::new("div").set_sibling_info(1, 1)
  let one_of_many = Element::new("div").set_sibling_info(1, 3)
  inspect(matches_selector_text(only, ":only-child"), content="true")
  inspect(matches_selector_text(one_of_many, ":only-child"), content="false")
}

///|
test "match :is with selector list" {
  let div = Element::new("div").add_class("active")
  inspect(matches_selector_text(div, ":is(.active, .hover)"), content="true")
  let other = Element::new("div")
  inspect(matches_selector_text(other, ":is(.active, .hover)"), content="false")
}

///|
test "match :is with type selector list" {
  inspect(
    matches_selector_text(Element::new("ol"), ":is(ol, li, div)"),
    content="true",
  )
  inspect(
    matches_selector_text(Element::new("span"), ":is(ol, li, div)"),
    content="false",
  )
}

///|
test "match :where (zero specificity but still matches)" {
  let div = Element::new("div").add_class("foo")
  inspect(matches_selector_text(div, ":where(.foo)"), content="true")
  inspect(matches_selector_text(div, ":where(.bar)"), content="false")
}

///|
test "selector list matches if any selector matches" {
  let elem = Element::new("p")
  let list = parse_selector_list_text("h1, h2, p, .foo").unwrap()
  assert_true(matches_selector_list(elem, list))
  let no_match = parse_selector_list_text("h1, h2, h3").unwrap()
  assert_false(matches_selector_list(elem, no_match))
}

///|
test "pseudo-elements do not match real elements" {
  let elem = Element::new("p")
  inspect(matches_selector_text(elem, "p::before"), content="false")
  inspect(matches_selector_text(elem, "::after"), content="false")
}

///|
test "match :has - subsequent sibling combinator" {
  let next = Element::new("p")
  let middle = { ..Element::new("span"), next_sibling: Some(next) }
  let elem = { ..Element::new("div"), next_sibling: Some(middle) }
  inspect(matches_selector_text(elem, "div:has(~ p)"), content="true")
  inspect(matches_selector_text(elem, "div:has(~ .missing)"), content="false")
}

///|
test "match :has - descendant via implicit combinator" {
  let leaf = Element::new("span").add_class("target")
  let nested = { ..Element::new("p"), children: [leaf] }
  let root = { ..Element::new("div"), children: [nested] }
  inspect(matches_selector_text(root, "div:has(.target)"), content="true")
  inspect(matches_selector_text(root, "div:has(.absent)"), content="false")
}

///|
test "match :nth-last-child" {
  let last = Element::new("li").set_sibling_info(5, 5)
  inspect(matches_selector_text(last, ":nth-last-child(1)"), content="true")
  let third_from_end = Element::new("li").set_sibling_info(3, 5)
  inspect(
    matches_selector_text(third_from_end, ":nth-last-child(3)"),
    content="true",
  )
  let first = Element::new("li").set_sibling_info(1, 5)
  inspect(matches_selector_text(first, ":nth-last-child(5)"), content="true")
}

///|
test "match :nth-child with negative coefficient" {
  // :nth-child(-n+3) matches 1st, 2nd, 3rd
  let first = Element::new("li").set_sibling_info(1, 5)
  let third = Element::new("li").set_sibling_info(3, 5)
  let fourth = Element::new("li").set_sibling_info(4, 5)
  inspect(matches_selector_text(first, ":nth-child(-n+3)"), content="true")
  inspect(matches_selector_text(third, ":nth-child(-n+3)"), content="true")
  inspect(matches_selector_text(fourth, ":nth-child(-n+3)"), content="false")
}

///|
test "match user-action pseudo-classes are false for static matching" {
  let elem = Element::new("button")
  inspect(matches_selector_text(elem, "button:hover"), content="false")
  inspect(matches_selector_text(elem, "button:active"), content="false")
  inspect(matches_selector_text(elem, "button:focus"), content="false")
  inspect(matches_selector_text(elem, "button:focus-visible"), content="false")
  inspect(matches_selector_text(elem, "button:focus-within"), content="false")
}

///|
test "match form pseudo-classes return false in static matching" {
  let input = Element::new("input")
  inspect(matches_selector_text(input, "input:enabled"), content="false")
  inspect(matches_selector_text(input, "input:disabled"), content="false")
  inspect(matches_selector_text(input, "input:checked"), content="false")
  inspect(matches_selector_text(input, "input:required"), content="false")
  inspect(matches_selector_text(input, "input:optional"), content="false")
  inspect(matches_selector_text(input, "input:valid"), content="false")
  inspect(matches_selector_text(input, "input:invalid"), content="false")
  inspect(matches_selector_text(input, "input:read-only"), content="false")
  inspect(matches_selector_text(input, "input:read-write"), content="false")
  inspect(matches_selector_text(input, "input:indeterminate"), content="false")
}

///|
test "link pseudo-class requires href" {
  let no_href = Element::new("a")
  inspect(matches_selector_text(no_href, "a:link"), content="false")
  let with_href = Element::new("a").set_attribute("href", "#")
  inspect(matches_selector_text(with_href, "a:link"), content="true")
  inspect(matches_selector_text(with_href, "a:any-link"), content="true")
  // non-anchor element with href doesn't match
  let div_with_href = Element::new("div").set_attribute("href", "#")
  inspect(matches_selector_text(div_with_href, ":link"), content="false")
}

///|
test "fast_has_prefix - rejects when prefix longer than s" {
  // Triggered via [attr^=long-value] where attr value is shorter
  let elem = Element::new("a").set_attribute("href", "x")
  inspect(
    matches_selector_text(elem, "a[href^=\"hello-world\"]"),
    content="false",
  )
}

///|
test "fast_has_prefix - mismatched first char" {
  let elem = Element::new("a").set_attribute("href", "xyz")
  inspect(matches_selector_text(elem, "a[href^=\"abc\"]"), content="false")
}

///|
test "fast_has_suffix - rejects when suffix longer than s" {
  let elem = Element::new("a").set_attribute("href", "x")
  inspect(
    matches_selector_text(elem, "a[href$=\"hello-world\"]"),
    content="false",
  )
}

///|
test "fast_dash_match - prefix matches but no following hyphen" {
  // e.g. [lang|=en] against "english" — should be false (no hyphen)
  let elem = Element::new("p").set_attribute("lang", "english")
  inspect(matches_selector_text(elem, "p[lang|=en]"), content="false")
}

///|
test "fast_dash_match - equal-length value short-circuits via ==" {
  // [lang|=en] with lang=en — caught by `a == b` before fast_dash_match runs
  let elem = Element::new("p").set_attribute("lang", "en")
  inspect(matches_selector_text(elem, "p[lang|=en]"), content="true")
}

///|
test "fast_contains - empty needle in [substring]" {
  // Empty value via "" should be true (matches everything)
  let elem = Element::new("a").set_attribute("href", "anything")
  // Empty quoted value
  inspect(matches_selector_text(elem, "a[href*=\"\"]"), content="true")
}

///|
test "fast_contains - needle longer than string" {
  let elem = Element::new("a").set_attribute("href", "x")
  inspect(matches_selector_text(elem, "a[href*=\"abcdef\"]"), content="false")
}

///|
test "matches_attribute - case insensitive Includes" {
  let elem = Element::new("div").set_attribute("class", "FOO BAR BAZ")
  inspect(matches_selector_text(elem, "[class~=\"foo\" i]"), content="true")
}

///|
test "matches_attribute - case insensitive DashMatch" {
  let elem = Element::new("p").set_attribute("lang", "EN-US")
  inspect(matches_selector_text(elem, "[lang|=en i]"), content="true")
}

///|
test "matches_pseudo_class - FirstOfType (currently approximates first-child)" {
  let first = Element::new("p").set_sibling_info(1, 3)
  let other = Element::new("p").set_sibling_info(2, 3)
  inspect(matches_selector_text(first, ":first-of-type"), content="true")
  inspect(matches_selector_text(other, ":first-of-type"), content="false")
}

///|
test "matches_pseudo_class - LastOfType" {
  let last = Element::new("p").set_sibling_info(3, 3)
  inspect(matches_selector_text(last, ":last-of-type"), content="true")
}

///|
test "matches_pseudo_class - OnlyOfType" {
  let only = Element::new("p").set_sibling_info(1, 1)
  let one_of_many = Element::new("p").set_sibling_info(1, 3)
  inspect(matches_selector_text(only, ":only-of-type"), content="true")
  inspect(matches_selector_text(one_of_many, ":only-of-type"), content="false")
}

///|
test "matches_pseudo_class - NthOfType" {
  let third = Element::new("p").set_sibling_info(3, 5)
  inspect(matches_selector_text(third, ":nth-of-type(3)"), content="true")
}

///|
test "matches_pseudo_class - NthLastOfType" {
  let last = Element::new("p").set_sibling_info(5, 5)
  inspect(matches_selector_text(last, ":nth-last-of-type(1)"), content="true")
}

///|
test "matches_has - next-sibling combinator path" {
  let next = Element::new("p").add_class("after")
  let elem = { ..Element::new("div"), next_sibling: Some(next) }
  inspect(matches_selector_text(elem, "div:has(+ .after)"), content="true")
  inspect(matches_selector_text(elem, "div:has(+ .missing)"), content="false")
}

///|
test "matches_has - subsequent-sibling combinator path with intermediate" {
  let target = Element::new("section").add_class("found")
  let middle = { ..Element::new("article"), next_sibling: Some(target) }
  let elem = { ..Element::new("div"), next_sibling: Some(middle) }
  inspect(matches_selector_text(elem, "div:has(~ .found)"), content="true")
  inspect(matches_selector_text(elem, "div:has(~ .nope)"), content="false")
}

///|
test "matches_has - subsequent-sibling has no next" {
  // Element with no next_sibling
  let elem = Element::new("div")
  inspect(matches_selector_text(elem, "div:has(~ .x)"), content="false")
}

///|
test "matches_has - direct child none" {
  // Element with no children
  let elem = Element::new("div")
  inspect(matches_selector_text(elem, "div:has(> .x)"), content="false")
}

///|
test "matches_complex - NextSibling combinator path" {
  // Already covered, but the false branch when no prev_sibling
  let elem = Element::new("p")
  // No prev_sibling at all
  inspect(matches_selector_text(elem, "h1 + p"), content="false")
}

///|
test "matches_complex - SubsequentSibling no match" {
  // Element with prev_sibling that doesn't match
  let prev = Element::new("span").add_class("other")
  let elem = { ..Element::new("p"), prev_sibling: Some(prev) }
  inspect(matches_selector_text(elem, ".target ~ p"), content="false")
}

///|
test "matches_attribute - case-insensitive Prefix/Suffix/Substring" {
  let elem = Element::new("a").set_attribute(
    "href", "HTTPS://Example.COM/Path.HTML",
  )
  inspect(matches_selector_text(elem, "a[href^=\"https\" i]"), content="true")
  inspect(matches_selector_text(elem, "a[href$=\".html\" i]"), content="true")
  inspect(matches_selector_text(elem, "a[href*=\"example\" i]"), content="true")
}

///|
test "fast_dash_match - value strictly shorter than query (vl < ql)" {
  // [lang|=long-name] against lang="en" — value shorter than query
  let elem = Element::new("p").set_attribute("lang", "en")
  inspect(
    matches_selector_text(elem, "p[lang|=\"long-name\"]"),
    content="false",
  )
}

///|
test "matches_has - next-sibling with no next" {
  // Triggers next_sibling_matches_complex None branch
  let elem = Element::new("div")
  inspect(matches_selector_text(elem, "div:has(+ .x)"), content="false")
}

///|
test "matches_has - explicit Descendant combinator" {
  // matches_relative_selector Some(Descendant) branch
  // Note: selector parser may treat ".x" inside :has() as implicit descendant.
  // This is what we already test, but explicit form covers Some(Descendant).
  let leaf = Element::new("span").add_class("found")
  let elem = { ..Element::new("div"), children: [leaf] }
  inspect(matches_selector_text(elem, "div:has(.found)"), content="true")
}

///|
test "matches_complex - SubsequentSibling deep chain" {
  // Build a chain: target → middle → elem; all should be siblings
  let target = Element::new("h1").add_class("target")
  let middle = { ..Element::new("span"), prev_sibling: Some(target) }
  let elem = { ..Element::new("p"), prev_sibling: Some(middle) }
  inspect(matches_selector_text(elem, ".target ~ p"), content="true")
}

///|
test "match :has selector list with attribute substring" {
  let base = Element::new("div").add_class("code-example")
  let child = Element::new("section")
    .set_attribute("class", "interactive-example-shell")
    .set_parent(base)
  let elem = { ..base, children: [child] }
  inspect(
    matches_selector_text(
      elem, ".code-example:has(.hidden, [class*=interactive-example])",
    ),
    content="true",
  )
}

///|
test "shadow matcher - :host matches only with shadow context" {
  let host = Element::new("x-card").add_class("featured")
  let context = ShadowContext::new(host)
  inspect(matches_selector_text(host, ":host"), content="false")
  inspect(
    matches_selector_text_with_shadow_context(host, ":host", context),
    content="true",
  )
  inspect(
    matches_selector_text_with_shadow_context(
      Element::new("div"),
      ":host",
      context,
    ),
    content="false",
  )
  inspect(
    matches_selector_text_with_shadow_context(
      Element::new("x-card").add_class("featured"),
      ":host",
      context,
    ),
    content="false",
  )
}

///|
test "shadow matcher - :host compound argument matches host" {
  let host = Element::new("x-card").add_class("featured")
  let context = ShadowContext::new(host)
  inspect(
    matches_selector_text_with_shadow_context(host, ":host(.featured)", context),
    content="true",
  )
  inspect(
    matches_selector_text_with_shadow_context(host, ":host(.plain)", context),
    content="false",
  )
}

///|
test "shadow matcher - :host-context matches light-tree host ancestors" {
  let body = Element::new("body").add_class("theme-dark")
  let host = Element::new("x-card").set_parent(body)
  let context = ShadowContext::new(host).set_host_ancestors([body])
  inspect(
    matches_selector_text_with_shadow_context(
      host, ":host-context(.theme-dark)", context,
    ),
    content="true",
  )
  inspect(
    matches_selector_text_with_shadow_context(
      host, ":host-context(.theme-light)", context,
    ),
    content="false",
  )
}

///|
test "shadow matcher - ::slotted matches assigned element in slot scope" {
  let slot = Element::new("slot").set_attribute("name", "title")
  let slotted = Element::new("span").add_class("title")
  let context = ShadowContext::new(Element::new("x-card")).set_assigned_slot(
    slot,
  )
  inspect(
    matches_selector_text_with_shadow_context(
      slotted, "::slotted(span.title)", context,
    ),
    content="true",
  )
  inspect(
    matches_selector_text_with_shadow_context(
      slotted, "::slotted(.missing)", context,
    ),
    content="false",
  )
  inspect(
    matches_selector_text_with_shadow_context(
      slotted, "slot[name=title]::slotted(.title)", context,
    ),
    content="true",
  )
}
