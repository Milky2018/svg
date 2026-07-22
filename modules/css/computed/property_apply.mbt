///|
/// Apply a resolved property value to a style builder
fn apply_property(
  builder : StyleBuilder,
  property : String,
  value : String,
  ctx : ComputeContext,
) -> Unit {
  fn grid_template_value(value : String) -> String {
    normalize_grid_template_math_functions(resolve_all_vars(value, ctx), ctx)
  }
  match property {
    // Display and positioning
    "display" => builder.display = parse_display(value)
    "position" => builder.position = parse_position(value)
    "float" =>
      builder.float = parse_float_with_direction(value, builder.direction)
    "clear" =>
      builder.clear = parse_clear_with_direction(value, builder.direction)
    "box-sizing" =>
      builder.box_sizing = match value.trim().to_lower() {
        "border-box" => @types.BoxSizing::BorderBox
        "content-box" | "initial" | "inherit" => @types.BoxSizing::ContentBox
        _ => @types.BoxSizing::ContentBox
      }
    // Sizing
    "width" =>
      builder.width = resolve_dimension_with_calc_percent_fallback(value, ctx)
    "height" =>
      builder.height = resolve_dimension_with_calc_percent_fallback(value, ctx)
    "min-width" =>
      builder.min_width = resolve_dimension_with_mixed_calc_fallback(
        "min-width", value, ctx,
      )
    "min-height" =>
      builder.min_height = resolve_dimension_with_mixed_calc_fallback(
        "min-height", value, ctx,
      )
    "max-width" =>
      builder.max_width = resolve_dimension_with_calc_percent_fallback(
        value, ctx,
      )
    "max-height" =>
      builder.max_height = resolve_dimension_with_calc_percent_fallback(
        value, ctx,
      )
    // Logical sizing properties
    // In vertical writing-modes:
    // - inline axis is vertical -> inline-size maps to height
    // - block axis is horizontal -> block-size maps to width
    "inline-size" => {
      let dim = resolve_dimension_with_calc_percent_fallback(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.height = dim
      } else {
        builder.width = dim
      }
    }
    "block-size" => {
      let dim = resolve_dimension_with_calc_percent_fallback(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.width = dim
      } else {
        builder.height = dim
      }
    }
    "min-inline-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.min_height = dim
      } else {
        builder.min_width = dim
      }
    }
    "min-block-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.min_width = dim
      } else {
        builder.min_height = dim
      }
    }
    "max-inline-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.max_height = dim
      } else {
        builder.max_width = dim
      }
    }
    "max-block-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.max_width = dim
      } else {
        builder.max_height = dim
      }
    }
    // Box model
    "margin" => {
      // Parse margin shorthand: 1-4 values
      let parts : Array[StringView] = value
        .split(" ")
        .filter(fn(s) { !s.is_empty() })
        .collect()
      match parts.length() {
        1 => {
          let dim = resolve_dimension(parts[0].to_owned(), ctx)
          builder.margin_top = dim
          builder.margin_right = dim
          builder.margin_bottom = dim
          builder.margin_left = dim
        }
        2 => {
          let tb = resolve_dimension(parts[0].to_owned(), ctx)
          let lr = resolve_dimension(parts[1].to_owned(), ctx)
          builder.margin_top = tb
          builder.margin_bottom = tb
          builder.margin_left = lr
          builder.margin_right = lr
        }
        3 => {
          builder.margin_top = resolve_dimension(parts[0].to_owned(), ctx)
          let lr = resolve_dimension(parts[1].to_owned(), ctx)
          builder.margin_left = lr
          builder.margin_right = lr
          builder.margin_bottom = resolve_dimension(parts[2].to_owned(), ctx)
        }
        4 => {
          builder.margin_top = resolve_dimension(parts[0].to_owned(), ctx)
          builder.margin_right = resolve_dimension(parts[1].to_owned(), ctx)
          builder.margin_bottom = resolve_dimension(parts[2].to_owned(), ctx)
          builder.margin_left = resolve_dimension(parts[3].to_owned(), ctx)
        }
        _ => ()
      }
    }
    "margin-top" => builder.margin_top = resolve_dimension(value, ctx)
    "margin-right" => builder.margin_right = resolve_dimension(value, ctx)
    "margin-bottom" => builder.margin_bottom = resolve_dimension(value, ctx)
    "margin-left" => builder.margin_left = resolve_dimension(value, ctx)
    // Logical margin properties (LTR horizontal-tb writing mode)
    "margin-inline" => {
      let (start, end) = resolve_logical_pair(value, ctx)
      builder.margin_left = start
      builder.margin_right = end
    }
    "margin-inline-start" => builder.margin_left = resolve_dimension(value, ctx)
    "margin-inline-end" => builder.margin_right = resolve_dimension(value, ctx)
    "margin-block" => {
      let (start, end) = resolve_logical_pair(value, ctx)
      builder.margin_top = start
      builder.margin_bottom = end
    }
    "margin-block-start" => builder.margin_top = resolve_dimension(value, ctx)
    "margin-block-end" => builder.margin_bottom = resolve_dimension(value, ctx)
    "margin-trim" => builder.margin_trim = parse_margin_trim(value)
    "padding-top" => builder.padding_top = resolve_dimension(value, ctx)
    "padding-right" => builder.padding_right = resolve_dimension(value, ctx)
    "padding-bottom" => builder.padding_bottom = resolve_dimension(value, ctx)
    "padding-left" => builder.padding_left = resolve_dimension(value, ctx)
    "padding" => {
      // Shorthand: padding (1, 2, 3, or 4 values)
      let parts = value.trim().to_owned().split(" ")
      let values : Array[@types.Dimension] = []
      for part in parts {
        let p = part.to_owned().trim().to_owned()
        if !p.is_empty() {
          values.push(resolve_dimension(p, ctx))
        }
      }
      match values.length() {
        1 => {
          builder.padding_top = values[0]
          builder.padding_right = values[0]
          builder.padding_bottom = values[0]
          builder.padding_left = values[0]
        }
        2 => {
          builder.padding_top = values[0]
          builder.padding_right = values[1]
          builder.padding_bottom = values[0]
          builder.padding_left = values[1]
        }
        3 => {
          builder.padding_top = values[0]
          builder.padding_right = values[1]
          builder.padding_bottom = values[2]
          builder.padding_left = values[1]
        }
        _ =>
          // 4 or more values
          if values.length() >= 4 {
            builder.padding_top = values[0]
            builder.padding_right = values[1]
            builder.padding_bottom = values[2]
            builder.padding_left = values[3]
          }
      }
    }
    // Logical padding properties (block/inline)
    "padding-block" => {
      let (start, end) = resolve_logical_pair(value, ctx)
      builder.padding_top = start
      builder.padding_bottom = end
    }
    "padding-block-start" => builder.padding_top = resolve_dimension(value, ctx)
    "padding-block-end" =>
      builder.padding_bottom = resolve_dimension(value, ctx)
    "padding-inline" => {
      let (start, end) = resolve_logical_pair(value, ctx)
      builder.padding_left = start
      builder.padding_right = end
    }
    "padding-inline-start" =>
      builder.padding_left = resolve_dimension(value, ctx)
    "padding-inline-end" =>
      builder.padding_right = resolve_dimension(value, ctx)
    "border-width" => {
      // Shorthand: border-width (1, 2, 3, or 4 values)
      let parts = value.trim().to_owned().split(" ")
      let values : Array[@types.Dimension] = []
      for part in parts {
        let p = part.to_owned().trim().to_owned()
        if !p.is_empty() {
          values.push(resolve_dimension(p, ctx))
        }
      }
      if values.length() == 1 {
        // All sides
        builder.border_top = values[0]
        builder.border_right = values[0]
        builder.border_bottom = values[0]
        builder.border_left = values[0]
      } else if values.length() == 2 {
        // top/bottom, left/right
        builder.border_top = values[0]
        builder.border_bottom = values[0]
        builder.border_right = values[1]
        builder.border_left = values[1]
      } else if values.length() == 3 {
        // top, left/right, bottom
        builder.border_top = values[0]
        builder.border_right = values[1]
        builder.border_left = values[1]
        builder.border_bottom = values[2]
      } else if values.length() >= 4 {
        // top, right, bottom, left
        builder.border_top = values[0]
        builder.border_right = values[1]
        builder.border_bottom = values[2]
        builder.border_left = values[3]
      }
    }
    "border" => {
      // Shorthand: border: [width] [style] [color]
      let width = resolve_border_width(value, ctx)
      builder.border_top = width
      builder.border_right = width
      builder.border_bottom = width
      builder.border_left = width
      let bs = extract_border_style_from_shorthand(value)
      builder.border_style_top = bs
      builder.border_style_right = bs
      builder.border_style_bottom = bs
      builder.border_style_left = bs
      let bc = extract_border_color_from_shorthand(value, ctx)
      builder.border_color_top = bc
      builder.border_color_right = bc
      builder.border_color_bottom = bc
      builder.border_color_left = bc
    }
    "border-top" => {
      let bs = extract_border_style_from_shorthand(value)
      builder.border_style_top = bs
      builder.border_top = if is_none_border_style_enum(bs) {
        @types.Length(0.0)
      } else {
        resolve_border_width(value, ctx)
      }
      builder.border_color_top = extract_border_color_from_shorthand(value, ctx)
    }
    "border-right" => {
      let bs = extract_border_style_from_shorthand(value)
      builder.border_style_right = bs
      builder.border_right = if is_none_border_style_enum(bs) {
        @types.Length(0.0)
      } else {
        resolve_border_width(value, ctx)
      }
      builder.border_color_right = extract_border_color_from_shorthand(
        value, ctx,
      )
    }
    "border-bottom" => {
      let bs = extract_border_style_from_shorthand(value)
      builder.border_style_bottom = bs
      builder.border_bottom = if is_none_border_style_enum(bs) {
        @types.Length(0.0)
      } else {
        resolve_border_width(value, ctx)
      }
      builder.border_color_bottom = extract_border_color_from_shorthand(
        value, ctx,
      )
    }
    "border-left" => {
      let bs = extract_border_style_from_shorthand(value)
      builder.border_style_left = bs
      builder.border_left = if is_none_border_style_enum(bs) {
        @types.Length(0.0)
      } else {
        resolve_border_width(value, ctx)
      }
      builder.border_color_left = extract_border_color_from_shorthand(
        value, ctx,
      )
    }
    "border-top-width" => builder.border_top = resolve_dimension(value, ctx)
    "border-right-width" => builder.border_right = resolve_dimension(value, ctx)
    "border-bottom-width" =>
      builder.border_bottom = resolve_dimension(value, ctx)
    "border-left-width" => builder.border_left = resolve_dimension(value, ctx)
    "border-style" => {
      let raw_parts = value.trim().to_lower().split(" ")
      let parts : Array[String] = []
      for part in raw_parts {
        let p = part.to_owned().trim().to_owned()
        if !p.is_empty() {
          parts.push(p)
        }
      }
      if parts.length() == 1 {
        let s = parse_border_style_value(parts[0])
        builder.border_style_top = s
        builder.border_style_right = s
        builder.border_style_bottom = s
        builder.border_style_left = s
        if is_none_border_style(parts[0]) {
          builder.border_top = @types.Length(0.0)
          builder.border_right = @types.Length(0.0)
          builder.border_bottom = @types.Length(0.0)
          builder.border_left = @types.Length(0.0)
        }
      } else if parts.length() == 2 {
        let v = parse_border_style_value(parts[0])
        let h = parse_border_style_value(parts[1])
        builder.border_style_top = v
        builder.border_style_bottom = v
        builder.border_style_right = h
        builder.border_style_left = h
        if is_none_border_style(parts[0]) {
          builder.border_top = @types.Length(0.0)
          builder.border_bottom = @types.Length(0.0)
        }
        if is_none_border_style(parts[1]) {
          builder.border_right = @types.Length(0.0)
          builder.border_left = @types.Length(0.0)
        }
      } else if parts.length() >= 4 {
        builder.border_style_top = parse_border_style_value(parts[0])
        builder.border_style_right = parse_border_style_value(parts[1])
        builder.border_style_bottom = parse_border_style_value(parts[2])
        builder.border_style_left = parse_border_style_value(parts[3])
        if is_none_border_style(parts[0]) {
          builder.border_top = @types.Length(0.0)
        }
        if is_none_border_style(parts[1]) {
          builder.border_right = @types.Length(0.0)
        }
        if is_none_border_style(parts[2]) {
          builder.border_bottom = @types.Length(0.0)
        }
        if is_none_border_style(parts[3]) {
          builder.border_left = @types.Length(0.0)
        }
      }
    }
    "border-top-style" => {
      builder.border_style_top = parse_border_style_value(value)
      if is_none_border_style(value) {
        builder.border_top = @types.Length(0.0)
      }
    }
    "border-right-style" => {
      builder.border_style_right = parse_border_style_value(value)
      if is_none_border_style(value) {
        builder.border_right = @types.Length(0.0)
      }
    }
    "border-bottom-style" => {
      builder.border_style_bottom = parse_border_style_value(value)
      if is_none_border_style(value) {
        builder.border_bottom = @types.Length(0.0)
      }
    }
    "border-left-style" => {
      builder.border_style_left = parse_border_style_value(value)
      if is_none_border_style(value) {
        builder.border_left = @types.Length(0.0)
      }
    }
    "border-color" => {
      let c = parse_color_with_ctx(value, ctx).or_default(@types.Color::black())
      builder.border_color_top = c
      builder.border_color_right = c
      builder.border_color_bottom = c
      builder.border_color_left = c
    }
    "border-top-color" =>
      builder.border_color_top = parse_color_with_ctx(value, ctx).or_default(
        @types.Color::black(),
      )
    "border-right-color" =>
      builder.border_color_right = parse_color_with_ctx(value, ctx).or_default(
        @types.Color::black(),
      )
    "border-bottom-color" =>
      builder.border_color_bottom = parse_color_with_ctx(value, ctx).or_default(
        @types.Color::black(),
      )
    "border-left-color" =>
      builder.border_color_left = parse_color_with_ctx(value, ctx).or_default(
        @types.Color::black(),
      )
    // Logical border properties (block/inline)
    "border-block" | "border-block-width" => {
      let width = resolve_border_width(value, ctx)
      builder.border_top = width
      builder.border_bottom = width
    }
    "border-block-style" => {
      let raw_parts = value.trim().to_lower().split(" ")
      let parts : Array[String] = []
      for part in raw_parts {
        let p = part.to_owned().trim().to_owned()
        if !p.is_empty() {
          parts.push(p)
        }
      }
      if parts.length() > 0 && is_none_border_style(parts[0]) {
        builder.border_top = @types.Length(0.0)
      }
      if parts.length() > 1 && is_none_border_style(parts[1]) {
        builder.border_bottom = @types.Length(0.0)
      } else if parts.length() == 1 && is_none_border_style(parts[0]) {
        builder.border_bottom = @types.Length(0.0)
      }
    }
    "border-block-start" | "border-block-start-width" =>
      builder.border_top = resolve_border_width(value, ctx)
    "border-block-end" | "border-block-end-width" =>
      builder.border_bottom = resolve_border_width(value, ctx)
    "border-inline" | "border-inline-width" => {
      let width = resolve_border_width(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.border_top = width
        builder.border_bottom = width
      } else {
        builder.border_left = width
        builder.border_right = width
      }
    }
    "border-inline-style" => {
      let raw_parts = value.trim().to_lower().split(" ")
      let parts : Array[String] = []
      for part in raw_parts {
        let p = part.to_owned().trim().to_owned()
        if !p.is_empty() {
          parts.push(p)
        }
      }
      if builder.writing_mode.is_vertical() {
        if parts.length() > 0 && is_none_border_style(parts[0]) {
          builder.border_top = @types.Length(0.0)
        }
        if parts.length() > 1 && is_none_border_style(parts[1]) {
          builder.border_bottom = @types.Length(0.0)
        } else if parts.length() == 1 && is_none_border_style(parts[0]) {
          builder.border_bottom = @types.Length(0.0)
        }
      } else {
        if parts.length() > 0 && is_none_border_style(parts[0]) {
          builder.border_left = @types.Length(0.0)
        }
        if parts.length() > 1 && is_none_border_style(parts[1]) {
          builder.border_right = @types.Length(0.0)
        } else if parts.length() == 1 && is_none_border_style(parts[0]) {
          builder.border_right = @types.Length(0.0)
        }
      }
    }
    "border-inline-start" | "border-inline-start-width" =>
      if builder.writing_mode.is_vertical() {
        builder.border_top = resolve_border_width(value, ctx)
      } else {
        builder.border_left = resolve_border_width(value, ctx)
      }
    "border-inline-end" | "border-inline-end-width" =>
      if builder.writing_mode.is_vertical() {
        builder.border_bottom = resolve_border_width(value, ctx)
      } else {
        builder.border_right = resolve_border_width(value, ctx)
      }
    // Flexbox container
    "flex-direction" => builder.flex_direction = parse_flex_direction(value)
    "flex-wrap" => builder.flex_wrap = parse_flex_wrap(value)
    "justify-content" => {
      let (alignment, is_unsafe) = parse_alignment_with_overflow(value)
      builder.justify_content = alignment
      builder.justify_content_unsafe = is_unsafe
    }
    "align-items" => builder.align_items = parse_alignment(value)
    "align-content" => {
      let normalized = value.trim().to_lower().to_owned()
      let (alignment, is_unsafe) = if normalized == "normal" {
        (@types.Alignment::Stretch, false)
      } else if normalized == "last baseline" {
        (@types.Alignment::Baseline, false)
      } else {
        parse_alignment_with_overflow(value)
      }
      builder.align_content = alignment
      builder.align_content_unsafe = is_unsafe
    }
    "place-content" =>
      match parse_place_content_with_overflow(value) {
        Some(((align_content, align_unsafe), (justify_content, justify_unsafe))) => {
          builder.align_content = align_content
          builder.align_content_unsafe = align_unsafe
          builder.justify_content = justify_content
          builder.justify_content_unsafe = justify_unsafe
        }
        None => ()
      }
    // Flexbox/Grid item alignment
    "align-self" => builder.align_self = parse_align_self(value)
    "justify-self" => builder.justify_self = parse_align_self(value)
    "place-self" =>
      match parse_place_self(value) {
        Some((align_self, justify_self)) => {
          builder.align_self = align_self
          builder.justify_self = justify_self
        }
        None => ()
      }
    // Grid container alignment
    "justify-items" => builder.justify_items = parse_alignment(value)
    "place-items" =>
      match parse_place_items(value) {
        Some((align_items, justify_items)) => {
          builder.align_items = align_items
          builder.justify_items = justify_items
        }
        None => ()
      }
    "flex-grow" => {
      let v = parse_number(value)
      if v >= 0.0 {
        builder.flex_grow = v
      }
    }
    "flex-shrink" => {
      let v = parse_number(value)
      if v >= 0.0 {
        builder.flex_shrink = v
      }
    }
    "flex-basis" => {
      // CSS spec: negative values are invalid, keep as auto
      let dim = resolve_dimension(value, ctx)
      match dim {
        @types.Length(v) => if v >= 0.0 { builder.flex_basis = dim }
        @types.Percent(v) => if v >= 0.0 { builder.flex_basis = dim }
        @types.Calc(px, pct) =>
          if px > 0.0 || pct > 0.0 {
            builder.flex_basis = dim
          }
        @types.MathFn(_, _) => builder.flex_basis = dim
        @types.Auto => builder.flex_basis = dim
        @types.MinContent => builder.flex_basis = dim
        @types.MaxContent => builder.flex_basis = dim
        @types.FitContent(_) => builder.flex_basis = dim
      }
    }
    "order" => builder.order = parse_integer(value)
    "flex" => {
      // Parse flex shorthand: none | auto | <flex-grow> [<flex-shrink>] [<flex-basis>]
      // Order must be: numbers first (grow, shrink), then optionally basis
      // Invalid orders like "1 0% 1" (basis in middle) must be rejected
      let v = value.trim()
      if v == "none" {
        builder.flex_grow = 0.0
        builder.flex_shrink = 0.0
        builder.flex_basis = @types.Dimension::Auto
      } else if v == "auto" {
        builder.flex_grow = 1.0
        builder.flex_shrink = 1.0
        builder.flex_basis = @types.Dimension::Auto
      } else if v == "initial" {
        builder.flex_grow = 0.0
        builder.flex_shrink = 1.0
        builder.flex_basis = @types.Dimension::Auto
      } else {
        // Try to parse as number(s) and optionally a basis
        let parts : Array[StringView] = v
          .split(" ")
          .filter(fn(s) { !s.is_empty() })
          .collect()
        // Validate ordering: numbers first, then basis
        // A value is a "number" if it's purely numeric (no % or units)
        // A value is a "basis" if it has %, px, or is "auto"/"content"
        let mut num_count = 0
        let mut basis_found = false
        let mut valid = true
        for i = 0; i < parts.length(); i = i + 1 {
          let p = parts[i].to_owned()
          if is_flex_basis_value(p) {
            if basis_found {
              // Second basis value is invalid
              valid = false
            }
            basis_found = true
          } else if is_pure_number(p) {
            if basis_found {
              // Number after basis is invalid (e.g., "1 0% 1")
              valid = false
            }
            num_count = num_count + 1
          } else {
            // Unknown token
            valid = false
          }
        }
        if valid {
          match parts.length() {
            1 =>
              if num_count == 1 {
                // flex: <number> = <number> 1 0%
                builder.flex_grow = parse_number(parts[0].to_owned())
                builder.flex_shrink = 1.0
                builder.flex_basis = @types.Dimension::Percent(0.0)
              } else if basis_found {
                // flex: <basis> = 1 1 <basis>
                builder.flex_grow = 1.0
                builder.flex_shrink = 1.0
                builder.flex_basis = resolve_dimension(parts[0].to_owned(), ctx)
              }
            2 =>
              if num_count == 2 {
                // flex: <grow> <shrink> = <grow> <shrink> 0%
                builder.flex_grow = parse_number(parts[0].to_owned())
                builder.flex_shrink = parse_number(parts[1].to_owned())
                builder.flex_basis = @types.Dimension::Percent(0.0)
              } else if num_count == 1 && basis_found {
                // flex: <grow> <basis>
                builder.flex_grow = parse_number(parts[0].to_owned())
                builder.flex_shrink = 1.0
                builder.flex_basis = resolve_dimension(parts[1].to_owned(), ctx)
              }
            3 =>
              if num_count == 2 && basis_found {
                // flex: <grow> <shrink> <basis>
                builder.flex_grow = parse_number(parts[0].to_owned())
                builder.flex_shrink = parse_number(parts[1].to_owned())
                builder.flex_basis = resolve_dimension(parts[2].to_owned(), ctx)
              }
            // If num_count != 2 or basis not at end, it's invalid and we do nothing
            _ => ()
          }
        }
        // If not valid, we don't modify the builder (keep defaults)
      }
    }
    // flex-flow shorthand: <flex-direction> || <flex-wrap>
    "flex-flow" => {
      let parts : Array[StringView] = value
        .trim()
        .split(" ")
        .filter(fn(s) { !s.is_empty() })
        .collect()
      for part in parts {
        let p = part.to_owned()
        // Check flex-direction values
        if p == "row" {
          builder.flex_direction = @types.FlexDirection::Row
        } else if p == "row-reverse" {
          builder.flex_direction = @types.FlexDirection::RowReverse
        } else if p == "column" {
          builder.flex_direction = @types.FlexDirection::Column
        } else if p == "column-reverse" {
          builder.flex_direction = @types.FlexDirection::ColumnReverse
          // Check flex-wrap values
        } else if p == "nowrap" {
          builder.flex_wrap = @types.FlexWrap::NoWrap
        } else if p == "wrap" {
          builder.flex_wrap = @types.FlexWrap::Wrap
        } else if p == "wrap-reverse" {
          builder.flex_wrap = @types.FlexWrap::WrapReverse
        }
      }
    }
    // Gap (grid-gap is legacy alias)
    "gap" | "grid-gap" => {
      let parts : Array[StringView] = value
        .trim()
        .split(" ")
        .filter(fn(s) { !s.is_empty() })
        .collect()
      builder.column_gap_is_normal = false
      match parts.length() {
        1 => {
          let dim = resolve_dimension_with_calc_percent_fallback(
            parts[0].to_owned(),
            ctx,
          )
          builder.row_gap = dim
          builder.column_gap = dim
        }
        2 => {
          builder.row_gap = resolve_dimension_with_calc_percent_fallback(
            parts[0].to_owned(),
            ctx,
          )
          builder.column_gap = resolve_dimension_with_calc_percent_fallback(
            parts[1].to_owned(),
            ctx,
          )
        }
        _ => {
          let dim = resolve_dimension_with_calc_percent_fallback(value, ctx)
          builder.row_gap = dim
          builder.column_gap = dim
        }
      }
    }
    "row-gap" | "grid-row-gap" =>
      builder.row_gap = resolve_dimension_with_calc_percent_fallback(value, ctx)
    "column-gap" | "grid-column-gap" => {
      builder.column_gap = resolve_dimension_with_calc_percent_fallback(
        value, ctx,
      )
      builder.column_gap_is_normal = false
    }
    // Multi-column
    "column-count" => builder.column_count = parse_column_count(value)
    "column-width" => builder.column_width = parse_column_width(value, ctx)
    "column-fill" => builder.column_fill = parse_column_fill(value)
    "columns" =>
      match parse_columns_shorthand(value, ctx) {
        Some((count, width)) => {
          builder.column_count = count
          builder.column_width = width
        }
        None => ()
      }
    "break-before" => builder.break_before = parse_break_before(value)
    "break-after" => builder.break_after = parse_break_before(value)
    "break-inside" | "page-break-inside" =>
      builder.break_inside = parse_break_inside(value)
    "column-span" => builder.column_span = parse_column_span(value)
    // Inset
    "top" => builder.inset_top = resolve_dimension(value, ctx)
    "right" => builder.inset_right = resolve_dimension(value, ctx)
    "bottom" => builder.inset_bottom = resolve_dimension(value, ctx)
    "left" => builder.inset_left = resolve_dimension(value, ctx)
    "inset" => {
      let parts : Array[StringView] = value
        .split(" ")
        .filter(fn(s) { !s.is_empty() })
        .collect()
      match parts.length() {
        1 => {
          let dim = resolve_dimension(parts[0].to_owned(), ctx)
          builder.inset_top = dim
          builder.inset_right = dim
          builder.inset_bottom = dim
          builder.inset_left = dim
        }
        2 => {
          let tb = resolve_dimension(parts[0].to_owned(), ctx)
          let lr = resolve_dimension(parts[1].to_owned(), ctx)
          builder.inset_top = tb
          builder.inset_bottom = tb
          builder.inset_left = lr
          builder.inset_right = lr
        }
        3 => {
          builder.inset_top = resolve_dimension(parts[0].to_owned(), ctx)
          let lr = resolve_dimension(parts[1].to_owned(), ctx)
          builder.inset_left = lr
          builder.inset_right = lr
          builder.inset_bottom = resolve_dimension(parts[2].to_owned(), ctx)
        }
        4 => {
          builder.inset_top = resolve_dimension(parts[0].to_owned(), ctx)
          builder.inset_right = resolve_dimension(parts[1].to_owned(), ctx)
          builder.inset_bottom = resolve_dimension(parts[2].to_owned(), ctx)
          builder.inset_left = resolve_dimension(parts[3].to_owned(), ctx)
        }
        _ => ()
      }
    }
    // Logical inset properties (LTR horizontal-tb writing mode)
    "inset-inline" => {
      let (start, end) = resolve_logical_pair(value, ctx)
      builder.inset_left = start
      builder.inset_right = end
    }
    "inset-inline-start" => builder.inset_left = resolve_dimension(value, ctx)
    "inset-inline-end" => builder.inset_right = resolve_dimension(value, ctx)
    "inset-block" => {
      let (start, end) = resolve_logical_pair(value, ctx)
      builder.inset_top = start
      builder.inset_bottom = end
    }
    "inset-block-start" => builder.inset_top = resolve_dimension(value, ctx)
    "inset-block-end" => builder.inset_bottom = resolve_dimension(value, ctx)
    // Aspect ratio
    "aspect-ratio" => builder.aspect_ratio = parse_aspect_ratio(value)
    // Overflow
    "overflow" => {
      // `overflow: <x> [<y>]` — one value applies to both axes.
      let parts : Array[String] = []
      for part in value.trim().to_owned().split(" ") {
        let p = part.to_owned().trim().to_owned()
        if !p.is_empty() {
          parts.push(p)
        }
      }
      match parts.length() {
        0 | 1 => {
          let ov = parse_overflow(value)
          builder.overflow_x = ov
          builder.overflow_y = ov
        }
        _ => {
          builder.overflow_x = parse_overflow(parts[0])
          builder.overflow_y = parse_overflow(parts[1])
        }
      }
    }
    "overflow-x" => builder.overflow_x = parse_overflow(value)
    "overflow-y" => builder.overflow_y = parse_overflow(value)
    "scroll-snap-type" =>
      builder.scroll_snap_type = parse_scroll_snap_type(value)
    "scroll-snap-align" => {
      let (inline_align, block_align) = parse_scroll_snap_align(value)
      builder.scroll_snap_align_x = inline_align
      builder.scroll_snap_align_y = block_align
    }
    // Grid container
    "grid-auto-flow" => builder.grid_auto_flow = parse_grid_auto_flow(value)
    "grid-auto-rows" =>
      builder.grid_auto_rows = parse_grid_template_tracks(
        grid_template_value(value),
      )
    "grid-auto-columns" =>
      builder.grid_auto_columns = parse_grid_template_tracks(
        grid_template_value(value),
      )
    "grid-template-columns" => {
      let (kind, tracks, line_names) = parse_grid_template_axis(
        grid_template_value(value),
      )
      builder.grid_template_columns = tracks
      builder.grid_template_column_line_names = line_names
      builder.grid_template_columns_kind = kind
    }
    "grid-template-rows" => {
      let (kind, tracks, line_names) = parse_grid_template_axis(
        grid_template_value(value),
      )
      builder.grid_template_rows = tracks
      builder.grid_template_row_line_names = line_names
      builder.grid_template_rows_kind = kind
    }
    "grid-template-areas" =>
      builder.grid_template_areas = parse_grid_template_areas_value(value)
    "grid-template" | "grid" => {
      let tv = grid_template_value(value)
      // Try the "areas" form first (it carries <string> rows); the `grid`
      // shorthand additionally supports the auto-flow form; finally fall back to
      // the `<rows> / <columns>` form.
      match parse_grid_template_areas_form(tv) {
        Some((areas, rows, row_names, cols, col_names)) => {
          builder.grid_template_areas = areas
          builder.grid_template_rows = rows
          builder.grid_template_row_line_names = row_names
          builder.grid_template_columns = cols
          builder.grid_template_column_line_names = col_names
        }
        None => {
          let autoflow = if property == "grid" {
            parse_grid_autoflow_form(tv)
          } else {
            None
          }
          match autoflow {
            Some((flow, rows, row_names, cols, col_names, auto_rows, auto_cols)) => {
              builder.grid_auto_flow = flow
              builder.grid_template_rows = rows
              builder.grid_template_row_line_names = row_names
              builder.grid_template_columns = cols
              builder.grid_template_column_line_names = col_names
              builder.grid_auto_rows = auto_rows
              builder.grid_auto_columns = auto_cols
            }
            None =>
              match parse_grid_template_shorthand_with_names(tv) {
                Some((rows, row_names, cols, col_names)) => {
                  builder.grid_template_rows = rows
                  builder.grid_template_row_line_names = row_names
                  builder.grid_template_columns = cols
                  builder.grid_template_column_line_names = col_names
                }
                None => ()
              }
          }
        }
      }
    }
    // Grid item placement
    "grid-column-start" =>
      builder.grid_column_start = parse_grid_placement(value)
    "grid-column-end" => builder.grid_column_end = parse_grid_placement(value)
    "grid-row-start" => builder.grid_row_start = parse_grid_placement(value)
    "grid-row-end" => builder.grid_row_end = parse_grid_placement(value)
    "grid-column" => {
      let (start, end) = parse_grid_line_shorthand(value)
      builder.grid_column_start = start
      match end {
        @types.GridPlacement::Auto =>
          match builder.grid_column_end {
            @types.GridPlacement::Auto => builder.grid_column_end = end
            _ => ()
          }
        _ => builder.grid_column_end = end
      }
    }
    "grid-row" => {
      let (start, end) = parse_grid_line_shorthand(value)
      builder.grid_row_start = start
      match end {
        @types.GridPlacement::Auto =>
          match builder.grid_row_end {
            @types.GridPlacement::Auto => builder.grid_row_end = end
            _ => ()
          }
        _ => builder.grid_row_end = end
      }
    }
    "grid-area" => {
      let v = value.trim().to_owned()
      // Check if this is a single named area identifier (no slashes, not a number, not auto/span)
      if !v.contains("/") && is_grid_area_name(v) {
        builder.grid_area = Some(v)
      } else {
        let (row_start, column_start, row_end, column_end) = parse_grid_area_shorthand(
          value,
        )
        builder.grid_row_start = row_start
        builder.grid_column_start = column_start
        builder.grid_row_end = row_end
        builder.grid_column_end = column_end
      }
    }
    // Animation longhands
    "animation-name" =>
      builder.animation_name = @parser.parse_animation_name_from_string(value)
    "animation-duration" =>
      builder.animation_duration = @parser.parse_time_list_from_string(value)
    "animation-timing-function" =>
      builder.animation_timing_function = @parser.parse_easing_list_from_string(
        value,
      )
    "animation-delay" =>
      builder.animation_delay = @parser.parse_time_list_from_string(value)
    "animation-iteration-count" =>
      builder.animation_iteration_count = @parser.parse_iteration_count_list_from_string(
        value,
      )
    "animation-direction" =>
      builder.animation_direction = @parser.parse_direction_list_from_string(
        value,
      )
    "animation-fill-mode" =>
      builder.animation_fill_mode = @parser.parse_fill_mode_list_from_string(
        value,
      )
    "animation-play-state" =>
      builder.animation_play_state = @parser.parse_play_state_list_from_string(
        value,
      )
    "animation" => {
      let a = @parser.parse_animation_shorthand_from_string(value)
      builder.animation_name = a.names
      builder.animation_duration = a.durations
      builder.animation_timing_function = a.timing_functions
      builder.animation_delay = a.delays
      builder.animation_iteration_count = a.iteration_counts
      builder.animation_direction = a.directions
      builder.animation_fill_mode = a.fill_modes
      builder.animation_play_state = a.play_states
    }
    // Transition longhands
    "transition-property" =>
      builder.transition_property = @parser.parse_animation_name_from_string(
        value,
      )
    "transition-duration" =>
      builder.transition_duration = @parser.parse_time_list_from_string(value)
    "transition-timing-function" =>
      builder.transition_timing_function = @parser.parse_easing_list_from_string(
        value,
      )
    "transition-delay" =>
      builder.transition_delay = @parser.parse_time_list_from_string(value)
    "transition" => {
      let t = @parser.parse_transition_shorthand_from_string(value)
      builder.transition_property = t.properties
      builder.transition_duration = t.durations
      builder.transition_timing_function = t.timing_functions
      builder.transition_delay = t.delays
    }
    // Font properties
    "font-size" => builder.font_size = parse_font_size(value, ctx)
    "line-height" =>
      builder.line_height = parse_line_height(
        value,
        builder.font_size,
        root_font_size=ctx.root_font_size,
      )
    "text-align" => builder.text_align = parse_text_align(value)
    "white-space" => builder.white_space = parse_white_space(value)
    "writing-mode" => builder.writing_mode = parse_writing_mode(value)
    "direction" => builder.direction = parse_direction(value)
    "vertical-align" => builder.vertical_align = parse_vertical_align(value)
    "font" => {
      // Parse font shorthand: [style] [variant] [weight] size[/line-height] family
      let parsed = parse_font_shorthand(value, ctx)
      builder.font_size = parsed.font_size
      builder.line_height = parsed.line_height
      builder.font_weight = parsed.font_weight
      builder.font_family = parsed.font_family
    }
    // CSS Containment
    "contain" => builder.contain = parse_contain(value)
    "container-type" =>
      match parse_container_type(value) {
        Some(implied) =>
          if implied.has_containment() {
            builder.contain = merge_contain(builder.contain, implied)
          }
        None => ()
      }
    "contain-intrinsic-inline-size" =>
      builder.contain_intrinsic_inline_size = parse_contain_intrinsic_axis(
        value, ctx,
      )
    "contain-intrinsic-block-size" =>
      builder.contain_intrinsic_block_size = parse_contain_intrinsic_axis(
        value, ctx,
      )
    "contain-intrinsic-size" =>
      match parse_contain_intrinsic_size(value, ctx) {
        Some((inline_size, block_size)) => {
          builder.contain_intrinsic_inline_size = inline_size
          builder.contain_intrinsic_block_size = block_size
        }
        None => ()
      }
    // Clip (legacy, deprecated but widely used for a11y)
    "clip" => builder.clip = parse_clip(value)
    "clip-path" => builder.clip_path = parse_clip_path(value)
    // Paint properties (visual, not layout)
    "visibility" => builder.visibility = parse_visibility(value)
    "pointer-events" => builder.pointer_events = parse_pointer_events(value)
    "z-index" => builder.z_index = parse_z_index(value)
    "opacity" => builder.opacity = parse_opacity(value)
    // Color properties
    "color" => {
      let parsed = parse_color_with_ctx(value, ctx)
      match parsed {
        Resolved(c) => builder.color = c
        CurrentColor =>
          // currentColor for 'color' property inherits from parent
          match ctx.parent_style {
            Some(parent) => builder.color = parent.color
            None => () // Keep default (black)
          }
        Inherit =>
          match ctx.parent_style {
            Some(parent) => builder.color = parent.color
            None => ()
          }
        Invalid => ()
      }
    }
    "background-color" | "background" => {
      let resolved_value = resolve_all_vars(value, ctx)
      // Check for linear-gradient first
      let v_lower = resolved_value.trim().to_lower()
      if v_lower.contains("linear-gradient") {
        let grad = parse_linear_gradient(resolved_value)
        builder.background_image = grad
      } else {
        let parsed = parse_color_with_ctx(resolved_value, ctx)
        match parsed {
          Resolved(c) => builder.background_color = c
          CurrentColor =>
            // currentColor uses the element's computed color
            builder.background_color = builder.color
          Inherit =>
            match ctx.parent_style {
              Some(parent) => builder.background_color = parent.background_color
              None => ()
            }
          Invalid => ()
        }
      }
    }
    "background-image" => {
      let resolved_value = resolve_all_vars(value, ctx)
      let v_lower = resolved_value.trim().to_lower()
      if v_lower.contains("linear-gradient") {
        builder.background_image = parse_linear_gradient(resolved_value)
      }
    }
    "box-shadow" =>
      builder.box_shadows = parse_box_shadows(value, ctx, builder.color)
    // Font weight
    "font-weight" => builder.font_weight = parse_font_weight(value)
    // Font family (store first family name for font matching)
    "font-family" => builder.font_family = parse_font_family(value)
    // Transform (visual position offset)
    "transform" => builder.transform = parse_transform(value)
    // Individual transform properties compose into one Transform.
    "translate" => {
      let t = @parser.parse_translate_property_from_string(value)
      builder.individual_transform = {
        ..builder.individual_transform,
        translate_x: t.translate_x,
        translate_y: t.translate_y,
      }
    }
    "scale" => {
      let t = @parser.parse_scale_property_from_string(value)
      builder.individual_transform = {
        ..builder.individual_transform,
        scale_x: t.scale_x,
        scale_y: t.scale_y,
      }
    }
    "rotate" => {
      let t = @parser.parse_rotate_property_from_string(value)
      builder.individual_transform = {
        ..builder.individual_transform,
        rotate_degrees: t.rotate_degrees,
      }
    }
    // filter / backdrop-filter only need to be tracked as "present" for the
    // containing-block rule in absolute positioning. The actual filter
    // functions are paint-side and not modelled here.
    "filter" | "backdrop-filter" => {
      let v = value.trim().to_lower()
      if v != "" && v != "none" && v != "initial" && v != "unset" {
        builder.has_filter = true
      }
    }
    // Zoom (layout scaling, inherited)
    "zoom" => builder.zoom = parse_zoom(value)
    // Table properties
    "border-spacing" => {
      let (horizontal, vertical) = parse_border_spacing(value, ctx)
      builder.border_spacing = horizontal
      builder.border_spacing_vertical = vertical
    }
    "border-collapse" => builder.border_collapse = parse_border_collapse(value)
    "table-layout" => builder.table_layout = parse_table_layout(value)
    "caption-side" => builder.caption_side = parse_caption_side(value)
    // Border radius
    "border-radius" => {
      let r = resolve_border_radius(value, ctx)
      builder.border_top_left_radius = r.0
      builder.border_top_right_radius = r.1
      builder.border_bottom_right_radius = r.2
      builder.border_bottom_left_radius = r.3
    }
    "border-top-left-radius" =>
      builder.border_top_left_radius = resolve_dimension_to_px(
        resolve_dimension(value, ctx),
      )
    "border-top-right-radius" =>
      builder.border_top_right_radius = resolve_dimension_to_px(
        resolve_dimension(value, ctx),
      )
    "border-bottom-right-radius" =>
      builder.border_bottom_right_radius = resolve_dimension_to_px(
        resolve_dimension(value, ctx),
      )
    "border-bottom-left-radius" =>
      builder.border_bottom_left_radius = resolve_dimension_to_px(
        resolve_dimension(value, ctx),
      )
    "text-decoration" | "text-decoration-line" => {
      let v = value.trim().to_lower()
      builder.text_decoration_underline = v.contains("underline")
      builder.text_decoration_line_through = v.contains("line-through")
      builder.text_decoration_overline = v.contains("overline")
    }
    "text-overflow" =>
      builder.text_overflow = match value.trim().to_lower() {
        "ellipsis" => @style.TextOverflow::Ellipsis
        _ => @style.TextOverflow::Clip
      }
    "letter-spacing" => {
      let v = value.trim().to_lower()
      if v == "normal" {
        builder.letter_spacing = 0.0
      } else {
        builder.letter_spacing = resolve_dimension_to_px(
          resolve_dimension(value, ctx),
        )
      }
    }
    "word-spacing" => {
      let v = value.trim().to_lower()
      if v == "normal" {
        builder.word_spacing = 0.0
      } else {
        builder.word_spacing = resolve_dimension_to_px(
          resolve_dimension(value, ctx),
        )
      }
    }
    _ => ()
  }
}

///|
fn parse_font_weight(value : String) -> Double {
  match value.trim().to_lower() {
    "normal" => 400.0
    "bold" => 700.0
    "lighter" => 100.0
    "bolder" => 700.0
    _ => {
      let n = @string.parse_double(value.trim()) catch { _ => return 400.0 }
      if n >= 1.0 && n <= 1000.0 {
        n
      } else {
        400.0
      }
    }
  }
}

///|
/// Parse font-family, returning the first family name (lowercase, unquoted).
fn parse_font_family(value : String) -> String {
  let v = value.trim()
  // Split by comma, take first
  let first = match v.split(",").collect() {
    [] => v
    parts => parts[0]
  }
  // Remove quotes and normalize
  let trimmed = first.trim()
  let len = trimmed.length()
  if len >= 2 && trimmed[0] == '"' && trimmed[len - 1] == '"' {
    trimmed[1:len - 1].to_owned().to_lower()
  } else if len >= 2 && trimmed[0] == '\'' && trimmed[len - 1] == '\'' {
    trimmed[1:len - 1].to_owned().to_lower()
  } else {
    trimmed.to_owned().to_lower()
  }
}

///|
fn split_css_top_level(input : String, delimiter : Char) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder::new()
  let mut depth = 0
  for ch in input {
    if ch == '(' {
      depth += 1
      current.write_char(ch)
      continue
    }
    if ch == ')' {
      if depth > 0 {
        depth -= 1
      }
      current.write_char(ch)
      continue
    }
    if ch == delimiter && depth == 0 {
      let part = current.to_string().trim().to_owned()
      if !part.is_empty() {
        parts.push(part)
      }
      current.reset()
      continue
    }
    current.write_char(ch)
  }
  let last = current.to_string().trim().to_owned()
  if !last.is_empty() {
    parts.push(last)
  }
  parts
}

///|
fn split_css_whitespace_preserving_functions(input : String) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder::new()
  let mut depth = 0
  for ch in input {
    if ch == '(' {
      depth += 1
      current.write_char(ch)
      continue
    }
    if ch == ')' {
      if depth > 0 {
        depth -= 1
      }
      current.write_char(ch)
      continue
    }
    let is_space = ch == ' ' || ch == '\t' || ch == '\n'
    if is_space && depth == 0 {
      let part = current.to_string().trim().to_owned()
      if !part.is_empty() {
        parts.push(part)
      }
      current.reset()
      continue
    }
    current.write_char(ch)
  }
  let last = current.to_string().trim().to_owned()
  if !last.is_empty() {
    parts.push(last)
  }
  parts
}

///|
fn parse_box_shadows(
  value : String,
  ctx : ComputeContext,
  default_color : @types.Color,
) -> Array[@style.BoxShadow] {
  let trimmed = value.trim().to_lower()
  if trimmed == "none" {
    return []
  }
  let shadows : Array[@style.BoxShadow] = []
  for entry in split_css_top_level(value, ',') {
    match parse_box_shadow(entry, ctx, default_color) {
      Some(shadow) => shadows.push(shadow)
      None => ()
    }
  }
  shadows
}

///|
fn parse_box_shadow(
  value : String,
  ctx : ComputeContext,
  default_color : @types.Color,
) -> @style.BoxShadow? {
  let tokens = split_css_whitespace_preserving_functions(value)
  if tokens.length() == 0 {
    return None
  }

  let mut inset = false
  let mut color = default_color
  let length_tokens : Array[String] = []
  for token in tokens {
    let lower = token.to_lower()
    if lower == "inset" {
      inset = true
      continue
    }
    match parse_css_value_to_px(token, ctx) {
      Some(_) => {
        length_tokens.push(token)
        continue
      }
      None => ()
    }
    if is_box_shadow_color_token(lower) {
      let parsed_color = parse_color_with_ctx(token, ctx)
      match parsed_color {
        Resolved(resolved) => {
          color = resolved
          continue
        }
        CurrentColor => {
          color = default_color
          continue
        }
        Inherit => return None
        Invalid => return None
      }
    }
    return None
  }

  if length_tokens.length() < 2 || length_tokens.length() > 4 {
    return None
  }

  let lengths : Array[Double] = []
  for token in length_tokens {
    match parse_css_value_to_px(token, ctx) {
      Some(px) => lengths.push(px)
      None => return None
    }
  }

  Some(
    @style.BoxShadow::new(
      inset,
      lengths[0],
      lengths[1],
      if lengths.length() >= 3 {
        @cmp.maximum(lengths[2], 0.0)
      } else {
        0.0
      },
      if lengths.length() >= 4 {
        lengths[3]
      } else {
        0.0
      },
      color,
    ),
  )
}

///|
fn is_box_shadow_color_token(token : String) -> Bool {
  token.has_prefix("#") ||
  token.has_prefix("rgb(") ||
  token.has_prefix("rgba(") ||
  token == "transparent" ||
  token == "currentcolor" ||
  get_named_color(token) is Some(_)
}
