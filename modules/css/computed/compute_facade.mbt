///|
/// Apply inheritance for inherited properties not in cascaded values
fn apply_inheritance(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  // List of inherited properties we support
  let inherited_props = [
    "direction", "writing-mode", "text-align", "line-height", "font-size", "font-family",
    "font-weight", "font-style", "color", "visibility", "white-space", "pointer-events",
  ]
  for prop in inherited_props {
    let covered_by_font_shorthand = cascaded.has("font") &&
      (
        prop == "font-size" ||
        prop == "line-height" ||
        prop == "font-family" ||
        prop == "font-weight"
      )
    // If property not in cascaded values, inherit from parent
    if !cascaded.has(prop) && !covered_by_font_shorthand {
      match ctx.parent_style {
        Some(parent) => {
          let value = get_style_value_as_string(prop, parent)
          apply_property(builder, prop, value, ctx)
        }
        None => ()
      }
    }
  }
}

///|
/// Compute style from inline style string (raw, without box-sizing adjustment)
/// Use this when merging individual properties into an existing style.
/// The caller is responsible for calling adjust_for_box_sizing on the final result.
pub fn compute_inline_raw(
  inline_css : String,
  ctx : ComputeContext,
) -> @style.Style {
  // Parse inline style to declarations
  let decls : Array[@cascade.Declaration] = []
  // Simple parsing: split by semicolon
  let pairs = inline_css.split(";")
  let mut order = 0
  for pair in pairs {
    let pair_str = pair.to_owned().trim()
    if pair_str.is_empty() {
      continue
    }
    // Find colon
    let mut colon_pos = -1
    for i = 0; i < pair_str.length(); i = i + 1 {
      if pair_str[i].to_int().unsafe_to_char() == ':' {
        colon_pos = i
        break
      }
    }
    if colon_pos > 0 {
      let prop = view_to_string(pair_str.view(end_offset=colon_pos)).trim()
      let val = view_to_string(pair_str.view(start_offset=colon_pos + 1)).trim()
      if !prop.is_empty() &&
        (!val.is_empty() || starts_with(prop.to_owned(), "--")) {
        let (value, importance) = strip_inline_important_marker(val.to_owned())
        decls.push(
          @cascade.Declaration::with_metadata(
            prop.to_owned(),
            Value(value),
            Author,
            importance,
            { a: 1000, b: 0, c: 0 },
            order,
          ),
        )
        order += 1
      }
    }
  }

  // Cascade
  let cascaded = @cascade.cascade(decls)

  // Compute (without box-sizing adjustment)
  compute(cascaded, ctx)
}

///|
/// Compute style from inline style string
/// This is the standard function that applies box-sizing adjustment.
pub fn compute_inline(
  inline_css : String,
  ctx : ComputeContext,
) -> @style.Style {
  let style = compute_inline_raw(inline_css, ctx)
  // Convert content-box dimensions to border-box dimensions
  // The layout engine always works with outer (border-box) dimensions
  adjust_for_box_sizing(style)
}

///|
/// Apply a single CSS property to an existing style directly
/// This skips the CSS string parsing step for better performance
pub fn apply_property_direct(
  style : @style.Style,
  property : String,
  value : String,
  ctx : ComputeContext,
) -> @style.Style {
  // Special handling for font-size: when font-size changes,
  // update line-height proportionally to maintain the ratio
  if property == "font-size" {
    let builder = StyleBuilder::from_style(style)
    let old_fs = style.font_size
    apply_property(builder, property, value, ctx)
    let new_fs = builder.font_size
    // Maintain line-height / font-size ratio
    let lh_ratio = if old_fs > 0.0 { style.line_height / old_fs } else { 1.0 }
    builder.line_height = new_fs * lh_ratio
    return builder.build()
  }
  let builder = StyleBuilder::from_style(style)
  apply_property(builder, property, value, ctx)
  builder.build()
}

///|
/// Adjust dimensions for box-sizing: content-box
/// When box-sizing is content-box (default), specified width/height are content dimensions.
/// The layout engine expects outer dimensions (border-box), so we adjust here.
fn adjust_for_box_sizing(style : @style.Style) -> @style.Style {
  match style.box_sizing {
    BorderBox => style // No adjustment needed
    ContentBox => {
      // Calculate padding and border sums
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)

      // Adjust width and height to include padding+border
      let adjusted_width = match style.width {
        Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_height = match style.height {
        Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      // Adjust min/max constraints too
      let adjusted_min_width = match style.min_width {
        Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_min_height = match style.min_height {
        Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      let adjusted_max_width = match style.max_width {
        Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_max_height = match style.max_height {
        Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      {
        ..style,
        width: adjusted_width,
        height: adjusted_height,
        min_width: adjusted_min_width,
        min_height: adjusted_min_height,
        max_width: adjusted_max_width,
        max_height: adjusted_max_height,
        // Mark as adjusted (now using border-box semantics internally)
        box_sizing: BorderBox,
      }
    }
  }
}

///|
/// Helper to resolve a dimension to pixels (for padding/border calculation)
fn resolve_dimension_to_px(dim : @types.Dimension) -> Double {
  match dim {
    Length(v) => v
    Percent(_) => 0.0 // Percentages are resolved later
    Calc(px, _) => px // Percent component is resolved later
    MathFn(op, args) =>
      // Percent components resolve later; reduce using px parts only.
      if args.is_empty() {
        0.0
      } else {
        @types.apply_math_op(op, args.map(fn(a) { a.0 }))
      }
    Auto => 0.0
    MinContent => 0.0 // Intrinsic sizing resolved during layout
    MaxContent => 0.0
    FitContent(_) => 0.0
  }
}
