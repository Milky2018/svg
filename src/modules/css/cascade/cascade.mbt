///|
/// CSS Cascade Algorithm
/// Resolves multiple declarations into final cascaded values

///|
/// Cascaded values for an element
/// Maps property names to their winning declaration
pub struct CascadedValues {
  /// Map from property name to winning declaration
  values : Map[String, Declaration]
}

///|
pub fn CascadedValues::new() -> CascadedValues {
  { values: Map([]) }
}

///|
/// Get the cascaded value for a property
pub fn CascadedValues::get(
  self : CascadedValues,
  property : String,
) -> Declaration? {
  self.values.get(property)
}

///|
/// Get the raw value string for a property
pub fn CascadedValues::get_value(
  self : CascadedValues,
  property : String,
) -> String? {
  match self.values.get(property) {
    Some(decl) =>
      match decl.value {
        Value(v) => Some(v)
        _ => None
      }
    None => None
  }
}

///|
/// Check if a property has a cascaded value
pub fn CascadedValues::has(self : CascadedValues, property : String) -> Bool {
  self.values.contains(property)
}

///|
/// Get all property names that have cascaded values
pub fn CascadedValues::properties(self : CascadedValues) -> Array[String] {
  let result : Array[String] = []
  self.values.each(fn(k, _v) { result.push(k) })
  result
}

///|
/// Iterate cascaded declarations without allocating an intermediate key array.
pub fn CascadedValues::each(
  self : CascadedValues,
  f : (String, Declaration) -> Unit,
) -> Unit {
  self.values.each(f)
}

///|
/// Cascade a list of declarations into final values
/// Declarations should be for a single element
pub fn cascade(declarations : Array[Declaration]) -> CascadedValues {
  let result = CascadedValues::new()
  for decl in declarations {
    accumulate_cascaded_declaration(result, decl)
  }
  result
}

///|
fn accumulate_cascaded_declaration(
  result : CascadedValues,
  decl : Declaration,
) -> Unit {
  match result.values.get(decl.property) {
    Some(current) =>
      if compare_declarations(decl, current) > 0 {
        result.values.set(decl.property, decl)
      }
    None => result.values.set(decl.property, decl)
  }
}

///|
fn accumulate_inline_declaration(
  result : CascadedValues,
  decl : Declaration,
  source_order_offset : Int,
) -> Unit {
  accumulate_cascaded_declaration(result, {
    property: decl.property,
    value: decl.value,
    origin: Author,
    importance: decl.importance,
    specificity: { a: 1000, b: 0, c: 0 },
    // Inline styles are authored after every stylesheet, so their source order
    // must sort above all stylesheet declarations. Otherwise an inline longhand
    // (e.g. border-top-width) would be applied before a stylesheet shorthand
    // (e.g. border), and the shorthand's four-side expansion would clobber it
    // at compute time even though the inline declaration wins the cascade.
    source_order: source_order_offset + decl.source_order,
  })
}

///|
/// Collect declarations from matching rules for an element
/// This is a helper to build the input for cascade()
pub(all) struct RuleMatch {
  /// The matched selector's specificity
  specificity : @selector.Specificity
  /// Declarations from the rule
  declarations : Array[Declaration]
  /// Source order of the rule
  source_order : Int
}

///|
/// A CSS rule: selector + declarations
pub struct CSSRule {
  /// Selector text (for debugging)
  selector_text : String
  /// Parsed selector
  selector : @selector.ComplexSelector
  /// Declarations in this rule
  declarations : Array[Declaration]
  /// Source order
  source_order : Int
  /// Media query (if this rule is inside @media)
  media_query : @media.MediaQueryList?
}

///|
/// One keyframe block inside an `@keyframes` rule: a set of offsets (the
/// `from` / `to` / `<percentage>` selectors, normalized to [0, 1]) sharing the
/// same declarations.
pub(all) struct KeyframeBlock {
  /// Offsets in [0, 1] this block applies to (e.g. `0%, 50%` => [0.0, 0.5]).
  offsets : Array[Double]
  /// Declarations declared for these offsets.
  declarations : Array[Declaration]
}

///|
/// A parsed `@keyframes` at-rule.
pub(all) struct KeyframesRule {
  /// The animation name (the identifier after `@keyframes`).
  name : String
  /// Keyframe blocks in source order.
  blocks : Array[KeyframeBlock]
}

///|
/// A stylesheet: collection of rules
pub struct Stylesheet {
  /// Rules in source order
  rules : Array[CSSRule]
  /// `@keyframes` rules in source order.
  keyframes : Array[KeyframesRule]
  /// Origin of this stylesheet
  origin : Origin
  /// Lazily-built selector index for fast match candidate lookup. Invalidated
  /// to `None` on every rule mutation; rebuilt on first lookup.
  mut cached_index : SelectorIndex?
}

///|
pub fn Stylesheet::new(origin : Origin) -> Stylesheet {
  { rules: [], keyframes: [], origin, cached_index: None }
}

///|
/// Add a parsed `@keyframes` rule to the stylesheet.
pub fn Stylesheet::add_keyframes(
  self : Stylesheet,
  rule : KeyframesRule,
) -> Unit {
  self.keyframes.push(rule)
}

///|
/// Find the last `@keyframes` rule with the given name (later rules win, per
/// the CSS cascade). Returns None if no such rule exists.
pub fn Stylesheet::find_keyframes(
  self : Stylesheet,
  name : String,
) -> KeyframesRule? {
  let mut found : KeyframesRule? = None
  for kf in self.keyframes {
    if kf.name == name {
      found = Some(kf)
    }
  }
  found
}

///|
/// Add a rule to the stylesheet
pub fn Stylesheet::add_rule(
  self : Stylesheet,
  selector_text : String,
  selector : @selector.ComplexSelector,
  declarations : Array[Declaration],
) -> Unit {
  let source_order = self.rules.length()
  let rule : CSSRule = {
    selector_text,
    selector,
    declarations,
    source_order,
    media_query: None,
  }
  self.rules.push(rule)
  self.cached_index = None
}

///|
/// Add a rule with a media query to the stylesheet
pub fn Stylesheet::add_rule_with_media(
  self : Stylesheet,
  selector_text : String,
  selector : @selector.ComplexSelector,
  declarations : Array[Declaration],
  media_query : @media.MediaQueryList,
) -> Unit {
  let source_order = self.rules.length()
  let rule : CSSRule = {
    selector_text,
    selector,
    declarations,
    source_order,
    media_query: Some(media_query),
  }
  self.rules.push(rule)
  self.cached_index = None
}

///|
/// Return (and lazily build) the selector index for this stylesheet.
/// Subsequent calls on an unmutated stylesheet reuse the cached value.
fn Stylesheet::get_or_build_index(self : Stylesheet) -> SelectorIndex {
  match self.cached_index {
    Some(idx) => idx
    None => {
      let idx = SelectorIndex::from_stylesheet(self)
      self.cached_index = Some(idx)
      idx
    }
  }
}

///|
/// Match all rules against an element and return matched rules
pub fn Stylesheet::match_element(
  self : Stylesheet,
  element : @selector.Element,
) -> Array[RuleMatch] {
  self.match_element_with_media(element, None)
}

///|
/// Match all rules against an element with media query evaluation. Uses the
/// stylesheet's cached selector index to prune rule candidates — large
/// stylesheets see ~30× speedup vs scanning every rule.
pub fn Stylesheet::match_element_with_media(
  self : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
) -> Array[RuleMatch] {
  let matches : Array[RuleMatch] = []
  let idx = self.get_or_build_index()
  for rule_idx in idx.get_candidates(element) {
    push_rule_match(
      matches,
      self.rules[rule_idx],
      element,
      self.origin,
      media_env,
    )
  }
  matches
}

///|
/// If `rule` matches `element` under `media_env`, append its `RuleMatch`
/// (with origin annotation) to `matches`. Shared by Stylesheet and
/// IndexedStylesheet.
fn push_rule_match(
  matches : Array[RuleMatch],
  rule : CSSRule,
  element : @selector.Element,
  origin : Origin,
  media_env : @media.MediaEnvironment?,
) -> Unit {
  let media_matches = match (rule.media_query, media_env) {
    (Some(mq), Some(env)) => mq.evaluate(env)
    (Some(_), None) => true
    (None, _) => true
  }
  if !media_matches {
    return
  }
  if !@selector.matches_complex(element, rule.selector) {
    return
  }
  let specificity = @selector.complex_specificity(rule.selector)
  // Combine rule source_order with declaration source_order to preserve
  // declaration order within rules (important for vendor prefix fallbacks like
  // "display: -webkit-flex; display: flex;")
  let decls : Array[Declaration] = []
  for decl in rule.declarations {
    decls.push({
      property: decl.property,
      value: decl.value,
      origin,
      importance: decl.importance,
      specificity,
      source_order: rule.source_order * 10000 + decl.source_order,
    })
  }
  matches.push({
    specificity,
    declarations: decls,
    source_order: rule.source_order,
  })
}

///|
/// Apply one CSS rule against an element: if media gate passes and selector
/// matches, accumulate every declaration into `result`. Returns the largest
/// source order assigned by this rule, or `prev_max` if no declarations were
/// applied.
fn cascade_rule_into(
  result : CascadedValues,
  rule : CSSRule,
  element : @selector.Element,
  origin : Origin,
  media_env : @media.MediaEnvironment?,
  source_order_offset : Int,
  prev_max : Int,
  matches : (@selector.Element, @selector.ComplexSelector) -> Bool,
) -> Int {
  let media_matches = match (rule.media_query, media_env) {
    (Some(mq), Some(env)) => mq.evaluate(env)
    (Some(_), None) => true
    (None, _) => true
  }
  if !media_matches {
    return prev_max
  }
  if !matches(element, rule.selector) {
    return prev_max
  }
  let specificity = @selector.complex_specificity(rule.selector)
  let mut max_so = prev_max
  for decl in rule.declarations {
    let adjusted_source_order = source_order_offset +
      rule.source_order * 10000 +
      decl.source_order
    if adjusted_source_order > max_so {
      max_so = adjusted_source_order
    }
    accumulate_cascaded_declaration(result, {
      property: decl.property,
      value: decl.value,
      origin,
      importance: decl.importance,
      specificity,
      source_order: adjusted_source_order,
    })
  }
  max_so
}

///|
/// Iterate stylesheet rules, accumulating declarations from rules whose
/// selector passes `matches`. Returns the maximum source order assigned so
/// the caller can advance the cross-stylesheet offset.
fn cascade_stylesheet_into(
  result : CascadedValues,
  stylesheet : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
  source_order_offset : Int,
  matches : (@selector.Element, @selector.ComplexSelector) -> Bool,
) -> Int {
  let mut max_so = source_order_offset - 1
  let idx = stylesheet.get_or_build_index()
  for rule_idx in idx.get_candidates(element) {
    max_so = cascade_rule_into(
      result,
      stylesheet.rules[rule_idx],
      element,
      stylesheet.origin,
      media_env,
      source_order_offset,
      max_so,
      matches,
    )
  }
  max_so
}

///|
fn cascade_stylesheet_matches_into(
  result : CascadedValues,
  stylesheet : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
  source_order_offset : Int,
) -> Int {
  cascade_stylesheet_into(
    result, stylesheet, element, media_env, source_order_offset, @selector.matches_complex,
  )
}

///|
/// Cascade styles for an element from multiple stylesheets
pub fn cascade_element(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
) -> CascadedValues {
  cascade_element_with_media(element, stylesheets, inline_style, None)
}

///|
/// Cascade styles for an element with media query evaluation
pub fn cascade_element_with_media(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
  media_env : @media.MediaEnvironment?,
) -> CascadedValues {
  let result = CascadedValues::new()
  let mut source_order_offset = 0

  // Collect matches from all stylesheets
  for stylesheet in stylesheets {
    let max_source_order_in_sheet = cascade_stylesheet_matches_into(
      result, stylesheet, element, media_env, source_order_offset,
    )
    if max_source_order_in_sheet >= source_order_offset {
      source_order_offset = max_source_order_in_sheet + 1
    }
  }

  for decl in inline_style {
    accumulate_inline_declaration(result, decl, source_order_offset)
  }
  result
}
