///|
/// Cascade styles for an element with forced pseudo-class states.
/// This evaluates CSS rules as if the specified pseudo-class states
/// (:hover, :focus, :active) were active on the element.
pub fn cascade_element_with_forced_states(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
  media_env : @media.MediaEnvironment?,
  forced : @selector.ForcedPseudoStates,
) -> CascadedValues {
  cascade_element_with_media_forced_and_validator(
    element,
    stylesheets,
    inline_style,
    media_env,
    forced,
    fn(_property, _value) { true },
  )
}

///|
/// Cascade styles with media queries, a static pseudo-class state, and an
/// embedding-language declaration validator.
pub fn cascade_element_with_media_forced_and_validator(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
  media_env : @media.MediaEnvironment?,
  forced : @selector.ForcedPseudoStates,
  declaration_is_valid : (String, PropertyValue) -> Bool,
) -> CascadedValues {
  let result = CascadedValues::new()
  let mut source_order_offset = 0
  for stylesheet in stylesheets {
    let max_source_order = cascade_stylesheet_forced_validated_into(
      result, stylesheet, element, media_env, forced, source_order_offset, declaration_is_valid,
    )
    if max_source_order >= source_order_offset {
      source_order_offset = max_source_order + 1
    }
  }
  for decl in inline_style {
    if declaration_is_valid(decl.property, decl.value) {
      accumulate_inline_declaration(result, decl, source_order_offset)
    }
  }
  result
}

///|
fn cascade_stylesheet_forced_validated_into(
  result : CascadedValues,
  stylesheet : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
  forced : @selector.ForcedPseudoStates,
  source_order_offset : Int,
  declaration_is_valid : (String, PropertyValue) -> Bool,
) -> Int {
  cascade_stylesheet_into(
    result,
    stylesheet,
    element,
    media_env,
    source_order_offset,
    fn(el, sel) {
      @selector.matches_complex_with_forced_states(el, sel, forced)
    },
    declaration_is_valid,
  )
}
