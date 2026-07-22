///|
/// Extract property name and value tokens from a declaration
fn parse_declaration(
  tokens : ArrayView[@token.Token],
) -> (String, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }

  // Get property name
  let property_name = match tokens[0] {
    @token.Token::Ident(name) => name
    _ => return None
  }

  // Skip to colon
  let mut pos = 1
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Whitespace => pos += 1
      @token.Token::Colon => {
        pos += 1
        break
      }
      _ => return None
    }
  }

  // Get value tokens (until semicolon or end)
  let value_start = pos
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Semicolon | @token.Token::EOF => break
      _ => pos += 1
    }
  }
  let value_tokens = skip_whitespace(tokens[value_start:pos])
  Some((property_name, value_tokens))
}

///|
/// Apply a single property to a style
fn apply_property(
  style : @style.Style,
  property : String,
  value_tokens : ArrayView[@token.Token],
) -> @style.Style {
  // display
  if property == "display" {
    match parse_display(value_tokens) {
      Some(v) => return { ..style, display: v }
      None => ()
    }
  }
  // position
  if property == "position" {
    match parse_position(value_tokens) {
      Some(v) => return { ..style, position: v }
      None => ()
    }
  }
  // float
  if property == "float" {
    match parse_float(value_tokens, style.direction) {
      Some(v) => return { ..style, float: v }
      None => ()
    }
  }
  // clear
  if property == "clear" {
    match parse_clear(value_tokens, style.direction) {
      Some(v) => return { ..style, clear: v }
      None => ()
    }
  }
  // box-sizing
  if property == "box-sizing" {
    match parse_box_sizing(value_tokens) {
      Some(v) => return { ..style, box_sizing: v }
      None => ()
    }
  }
  // width
  if property == "width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, width: v }
      None => ()
    }
  }
  // height
  if property == "height" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, height: v }
      None => ()
    }
  }
  // min-width
  if property == "min-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, min_width: v }
      None => ()
    }
  }
  // min-height
  if property == "min-height" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, min_height: v }
      None => ()
    }
  }
  // max-width
  if property == "max-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, max_width: v }
      None => ()
    }
  }
  // max-height
  if property == "max-height" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, max_height: v }
      None => ()
    }
  }
  // flex-direction
  if property == "flex-direction" {
    match parse_flex_direction(value_tokens) {
      Some(v) => return { ..style, flex_direction: v }
      None => ()
    }
  }
  // flex-wrap
  if property == "flex-wrap" {
    match parse_flex_wrap(value_tokens) {
      Some(v) => return { ..style, flex_wrap: v }
      None => ()
    }
  }
  // justify-content
  if property == "justify-content" {
    match parse_alignment_with_overflow(value_tokens) {
      Some((v, is_unsafe)) =>
        return {
          ..style,
          justify_content: v,
          justify_content_unsafe: is_unsafe,
        }
      None => ()
    }
  }
  // align-items
  if property == "align-items" {
    match parse_alignment(value_tokens) {
      Some(v) => return { ..style, align_items: v }
      None => ()
    }
  }
  // align-content
  if property == "align-content" {
    match parse_alignment_with_overflow(value_tokens) {
      Some((v, is_unsafe)) =>
        return { ..style, align_content: v, align_content_unsafe: is_unsafe }
      None => ()
    }
  }
  // place-content
  if property == "place-content" {
    match parse_place_content_with_overflow(value_tokens) {
      Some(
        (
          (align_content, align_content_unsafe),
          (justify_content, justify_content_unsafe),
        )
      ) =>
        return {
          ..style,
          align_content,
          align_content_unsafe,
          justify_content,
          justify_content_unsafe,
        }
      None => ()
    }
  }
  // align-self
  if property == "align-self" {
    match parse_self_alignment(value_tokens) {
      Some(v) => return { ..style, align_self: v }
      None => ()
    }
  }
  // justify-self
  if property == "justify-self" {
    match parse_self_alignment(value_tokens) {
      Some(v) => return { ..style, justify_self: v }
      None => ()
    }
  }
  // justify-items
  if property == "justify-items" {
    match parse_alignment(value_tokens) {
      Some(v) => return { ..style, justify_items: v }
      None => ()
    }
  }
  // flex-grow (must be non-negative)
  if property == "flex-grow" {
    match parse_number(value_tokens) {
      Some(v) if v >= 0.0 => return { ..style, flex_grow: v }
      _ => ()
    }
  }
  // flex-shrink (must be non-negative)
  if property == "flex-shrink" {
    match parse_number(value_tokens) {
      Some(v) if v >= 0.0 => return { ..style, flex_shrink: v }
      _ => ()
    }
  }
  // flex-basis
  if property == "flex-basis" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, flex_basis: v }
      None => ()
    }
  }
  // flex shorthand
  if property == "flex" {
    match parse_flex_shorthand(value_tokens) {
      Some((grow, shrink, basis)) =>
        return {
          ..style,
          flex_grow: grow,
          flex_shrink: shrink,
          flex_basis: basis,
        }
      None => ()
    }
  }
  // flex-flow shorthand
  if property == "flex-flow" {
    match parse_flex_flow_shorthand(value_tokens) {
      Some((direction, wrap)) =>
        return { ..style, flex_direction: direction, flex_wrap: wrap }
      None => ()
    }
  }
  // order
  if property == "order" {
    match parse_integer(value_tokens) {
      Some(v) => return { ..style, order: v }
      None => ()
    }
  }
  // margin (supports 1, 2, 3, or 4 values)
  if property == "margin" {
    let dims = parse_multi_dimensions(value_tokens, 4)
    match dims.length() {
      1 => {
        // All sides
        let v = dims[0]
        return { ..style, margin: { top: v, right: v, bottom: v, left: v } }
      }
      2 => {
        // top/bottom, left/right
        let tb = dims[0]
        let lr = dims[1]
        return { ..style, margin: { top: tb, right: lr, bottom: tb, left: lr } }
      }
      3 => {
        // top, left/right, bottom
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, margin: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 =>
        // top, right, bottom, left
        return {
          ..style,
          margin: {
            top: dims[0],
            right: dims[1],
            bottom: dims[2],
            left: dims[3],
          },
        }
      _ => ()
    }
  }
  // margin-left
  if property == "margin-left" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, left: v } }
      None => ()
    }
  }
  // margin-right
  if property == "margin-right" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, right: v } }
      None => ()
    }
  }
  // margin-top
  if property == "margin-top" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, top: v } }
      None => ()
    }
  }
  // margin-bottom
  if property == "margin-bottom" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, bottom: v } }
      None => ()
    }
  }
  // padding (supports 1, 2, 3, or 4 values)
  if property == "padding" {
    let dims = parse_multi_dimensions(value_tokens, 4)
    match dims.length() {
      1 => {
        let v = dims[0]
        return { ..style, padding: { top: v, right: v, bottom: v, left: v } }
      }
      2 => {
        let tb = dims[0]
        let lr = dims[1]
        return {
          ..style,
          padding: { top: tb, right: lr, bottom: tb, left: lr },
        }
      }
      3 => {
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, padding: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 =>
        return {
          ..style,
          padding: {
            top: dims[0],
            right: dims[1],
            bottom: dims[2],
            left: dims[3],
          },
        }
      _ => ()
    }
  }
  // padding-left
  if property == "padding-left" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, left: v } }
      None => ()
    }
  }
  // padding-right
  if property == "padding-right" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, right: v } }
      None => ()
    }
  }
  // padding-top
  if property == "padding-top" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, top: v } }
      None => ()
    }
  }
  // padding-bottom
  if property == "padding-bottom" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, bottom: v } }
      None => ()
    }
  }
  // padding-block (logical property: sets top and bottom for horizontal writing mode)
  if property == "padding-block" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, padding: { ..style.padding, top: v, bottom: v } }
      None => ()
    }
  }
  // padding-inline (logical property: sets left and right for horizontal writing mode)
  if property == "padding-inline" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, padding: { ..style.padding, left: v, right: v } }
      None => ()
    }
  }
  // gap
  if property == "gap" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, row_gap: v, column_gap: v }
      None => ()
    }
  }
  // row-gap
  if property == "row-gap" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, row_gap: v }
      None => ()
    }
  }
  // column-gap
  if property == "column-gap" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, column_gap: v }
      None => ()
    }
  }
  // overflow
  if property == "overflow" {
    match parse_overflow(value_tokens) {
      Some(v) => return { ..style, overflow_x: v, overflow_y: v }
      None => ()
    }
  }
  // overflow-x
  if property == "overflow-x" {
    match parse_overflow(value_tokens) {
      Some(v) => return { ..style, overflow_x: v }
      None => ()
    }
  }
  // overflow-y
  if property == "overflow-y" {
    match parse_overflow(value_tokens) {
      Some(v) => return { ..style, overflow_y: v }
      None => ()
    }
  }
  // clip (legacy, for accessibility)
  if property == "clip" {
    return { ..style, clip: parse_clip(value_tokens) }
  }
  // clip-path (paint/hit-test subset)
  if property == "clip-path" {
    return { ..style, clip_path: parse_clip_path(value_tokens) }
  }
  // border (single value)
  if property == "border-width" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { left: v, right: v, top: v, bottom: v } }
      None => ()
    }
  }
  // border-left-width
  if property == "border-left-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, left: v } }
      None => ()
    }
  }
  // border-right-width
  if property == "border-right-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, right: v } }
      None => ()
    }
  }
  // border-top-width
  if property == "border-top-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, top: v } }
      None => ()
    }
  }
  // border-bottom-width
  if property == "border-bottom-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, bottom: v } }
      None => ()
    }
  }
  // border-block (logical property: sets top and bottom border width)
  // Shorthand can be: border-block: 10px | border-block: 10px solid | border-block: 10px solid green
  if property == "border-block" {
    // Parse first token as dimension (width)
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, top: v, bottom: v } }
      None => ()
    }
  }
  // border-block-width
  if property == "border-block-width" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, top: v, bottom: v } }
      None => ()
    }
  }
  // border-inline (logical property: sets left and right border width)
  if property == "border-inline" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, left: v, right: v } }
      None => ()
    }
  }
  // border-inline-width
  if property == "border-inline-width" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, left: v, right: v } }
      None => ()
    }
  }
  // inset (supports 1, 2, 3, or 4 values like margin/padding)
  if property == "inset" {
    let dims = parse_multi_dimensions(value_tokens, 4)
    match dims.length() {
      1 => {
        let v = dims[0]
        return { ..style, inset: { top: v, right: v, bottom: v, left: v } }
      }
      2 => {
        let tb = dims[0]
        let lr = dims[1]
        return { ..style, inset: { top: tb, right: lr, bottom: tb, left: lr } }
      }
      3 => {
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, inset: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 =>
        return {
          ..style,
          inset: {
            top: dims[0],
            right: dims[1],
            bottom: dims[2],
            left: dims[3],
          },
        }
      _ => ()
    }
  }
  // top
  if property == "top" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, top: v } }
      None => ()
    }
  }
  // right
  if property == "right" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, right: v } }
      None => ()
    }
  }
  // bottom
  if property == "bottom" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, bottom: v } }
      None => ()
    }
  }
  // left
  if property == "left" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, left: v } }
      None => ()
    }
  }
  // aspect-ratio
  if property == "aspect-ratio" {
    match parse_aspect_ratio(value_tokens) {
      Some(v) => return { ..style, aspect_ratio: Some(v) }
      None => ()
    }
  }
  // grid-auto-flow
  if property == "grid-auto-flow" {
    match parse_grid_auto_flow(value_tokens) {
      Some(v) => return { ..style, grid_auto_flow: v }
      None => ()
    }
  }
  // grid-template-columns
  if property == "grid-template-columns" {
    let (kind, tracks, line_names) = parse_grid_template_axis(value_tokens)
    return {
      ..style,
      grid_template_columns: tracks,
      grid_template_column_line_names: line_names,
      grid_template_columns_kind: kind,
    }
  }
  // grid-template-rows
  if property == "grid-template-rows" {
    let (kind, tracks, line_names) = parse_grid_template_axis(value_tokens)
    return {
      ..style,
      grid_template_rows: tracks,
      grid_template_row_line_names: line_names,
      grid_template_rows_kind: kind,
    }
  }
  // grid-template / grid shorthand. Try the "areas" form first (it carries
  // <string> rows). The `grid` shorthand additionally supports the auto-flow
  // form. Finally fall back to the `<rows> / <columns>` form.
  if property == "grid-template" || property == "grid" {
    match parse_grid_template_areas_form(value_tokens) {
      Some((areas, rows, row_names, cols, col_names)) =>
        return {
          ..style,
          grid_template_areas: areas,
          grid_template_rows: rows,
          grid_template_row_line_names: row_names,
          grid_template_columns: cols,
          grid_template_column_line_names: col_names,
        }
      None => ()
    }
    if property == "grid" {
      match parse_grid_autoflow_form(value_tokens) {
        Some((flow, rows, row_names, cols, col_names, auto_rows, auto_cols)) =>
          return {
            ..style,
            grid_auto_flow: flow,
            grid_template_rows: rows,
            grid_template_row_line_names: row_names,
            grid_template_columns: cols,
            grid_template_column_line_names: col_names,
            grid_auto_rows: auto_rows,
            grid_auto_columns: auto_cols,
          }
        None => ()
      }
    }
    match parse_grid_template_shorthand(value_tokens) {
      Some((rows, row_names, cols, col_names)) =>
        return {
          ..style,
          grid_template_rows: rows,
          grid_template_row_line_names: row_names,
          grid_template_columns: cols,
          grid_template_column_line_names: col_names,
        }
      None => ()
    }
  }
  // Grid item placement longhands
  if property == "grid-column-start" {
    return {
      ..style,
      grid_column: {
        ..style.grid_column,
        start: classify_grid_line(value_tokens),
      },
    }
  }
  if property == "grid-column-end" {
    return {
      ..style,
      grid_column: {
        ..style.grid_column,
        end: classify_grid_line(value_tokens),
      },
    }
  }
  if property == "grid-row-start" {
    return {
      ..style,
      grid_row: { ..style.grid_row, start: classify_grid_line(value_tokens) },
    }
  }
  if property == "grid-row-end" {
    return {
      ..style,
      grid_row: { ..style.grid_row, end: classify_grid_line(value_tokens) },
    }
  }
  // grid-column / grid-row shorthand
  if property == "grid-column" {
    let (start, end) = parse_grid_line_shorthand_tokens(value_tokens)
    return { ..style, grid_column: { start, end } }
  }
  if property == "grid-row" {
    let (start, end) = parse_grid_line_shorthand_tokens(value_tokens)
    return { ..style, grid_row: { start, end } }
  }
  // grid-area: either a single named area, or up to four grid lines.
  if property == "grid-area" {
    match grid_area_single_name(value_tokens) {
      // A single <custom-ident> names a grid area rather than placing lines.
      Some(name) => return { ..style, grid_area: Some(name) }
      None => {
        let (rs, cs, re, ce) = parse_grid_area_shorthand_tokens(value_tokens)
        return {
          ..style,
          grid_row: { start: rs, end: re },
          grid_column: { start: cs, end: ce },
        }
      }
    }
  }
  // Individual transform properties (compose into individual_transform).
  if property == "translate" {
    let t = parse_translate_property_from_string(reconstruct_css(value_tokens))
    return {
      ..style,
      individual_transform: {
        ..style.individual_transform,
        translate_x: t.translate_x,
        translate_y: t.translate_y,
      },
    }
  }
  if property == "scale" {
    let t = parse_scale_property_from_string(reconstruct_css(value_tokens))
    return {
      ..style,
      individual_transform: {
        ..style.individual_transform,
        scale_x: t.scale_x,
        scale_y: t.scale_y,
      },
    }
  }
  if property == "rotate" {
    let t = parse_rotate_property_from_string(reconstruct_css(value_tokens))
    return {
      ..style,
      individual_transform: {
        ..style.individual_transform,
        rotate_degrees: t.rotate_degrees,
      },
    }
  }
  // Animation longhands
  if property == "animation-name" {
    return { ..style, animation_name: parse_ident_list(value_tokens) }
  }
  if property == "animation-duration" {
    return { ..style, animation_duration: parse_time_list(value_tokens) }
  }
  if property == "animation-timing-function" {
    return {
      ..style,
      animation_timing_function: parse_easing_list(value_tokens),
    }
  }
  if property == "animation-delay" {
    return { ..style, animation_delay: parse_time_list(value_tokens) }
  }
  if property == "animation-iteration-count" {
    return {
      ..style,
      animation_iteration_count: parse_iteration_count_list(value_tokens),
    }
  }
  if property == "animation-direction" {
    return { ..style, animation_direction: parse_direction_list(value_tokens) }
  }
  if property == "animation-fill-mode" {
    return { ..style, animation_fill_mode: parse_fill_mode_list(value_tokens) }
  }
  if property == "animation-play-state" {
    return {
      ..style,
      animation_play_state: parse_play_state_list(value_tokens),
    }
  }
  // animation shorthand
  if property == "animation" {
    let a = parse_animation_shorthand(value_tokens)
    return {
      ..style,
      animation_name: a.names,
      animation_duration: a.durations,
      animation_timing_function: a.timing_functions,
      animation_delay: a.delays,
      animation_iteration_count: a.iteration_counts,
      animation_direction: a.directions,
      animation_fill_mode: a.fill_modes,
      animation_play_state: a.play_states,
    }
  }
  // Transition longhands
  if property == "transition-property" {
    return { ..style, transition_property: parse_ident_list(value_tokens) }
  }
  if property == "transition-duration" {
    return { ..style, transition_duration: parse_time_list(value_tokens) }
  }
  if property == "transition-timing-function" {
    return {
      ..style,
      transition_timing_function: parse_easing_list(value_tokens),
    }
  }
  if property == "transition-delay" {
    return { ..style, transition_delay: parse_time_list(value_tokens) }
  }
  // transition shorthand
  if property == "transition" {
    let t = parse_transition_shorthand(value_tokens)
    return {
      ..style,
      transition_property: t.properties,
      transition_duration: t.durations,
      transition_timing_function: t.timing_functions,
      transition_delay: t.delays,
    }
  }
  // contain
  if property == "contain" {
    let contain = parse_contain(value_tokens)
    return { ..style, contain, }
  }
  // container-type
  if property == "container-type" {
    match parse_container_type(value_tokens) {
      Some(implied) =>
        if implied.has_containment() {
          return { ..style, contain: merge_contain(style.contain, implied) }
        } else {
          return style
        }
      None => ()
    }
  }
  // contain-intrinsic-inline-size
  if property == "contain-intrinsic-inline-size" {
    let contain_intrinsic_inline_size = parse_contain_intrinsic_axis(
      value_tokens,
    )
    return { ..style, contain_intrinsic_inline_size, }
  }
  // contain-intrinsic-block-size
  if property == "contain-intrinsic-block-size" {
    let contain_intrinsic_block_size = parse_contain_intrinsic_axis(
      value_tokens,
    )
    return { ..style, contain_intrinsic_block_size, }
  }
  // contain-intrinsic-size
  if property == "contain-intrinsic-size" {
    match parse_contain_intrinsic_size(value_tokens) {
      Some((contain_intrinsic_inline_size, contain_intrinsic_block_size)) =>
        return {
          ..style,
          contain_intrinsic_inline_size,
          contain_intrinsic_block_size,
        }
      None => ()
    }
  }
  // transform
  if property == "transform" {
    let transform = parse_transform(value_tokens)
    return { ..style, transform, }
  }
  // pointer-events
  if property == "pointer-events" {
    let pointer_events = parse_pointer_events(value_tokens)
    return { ..style, pointer_events, }
  }
  // Unknown property - ignore
  style
}
