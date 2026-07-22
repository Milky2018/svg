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
  let result = CascadedValues::new()
  let mut source_order_offset = 0
  for stylesheet in stylesheets {
    let max_source_order = cascade_stylesheet_forced_into(
      result, stylesheet, element, media_env, forced, source_order_offset,
    )
    if max_source_order >= source_order_offset {
      source_order_offset = max_source_order + 1
    }
  }
  for decl in inline_style {
    accumulate_inline_declaration(result, decl, source_order_offset)
  }
  result
}

///|
fn cascade_stylesheet_forced_into(
  result : CascadedValues,
  stylesheet : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
  forced : @selector.ForcedPseudoStates,
  source_order_offset : Int,
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
  )
}
