///|
fn seed_direction(tokens : Array[@token.Token]) -> @style.Direction {
  let mut direction = @style.Direction::Ltr
  let mut pos = 0
  while pos < tokens.length() {
    match tokens[pos] {
      Whitespace | Semicolon => {
        pos += 1
        continue
      }
      EOF => break
      _ => ()
    }

    match parse_declaration(tokens[pos:]) {
      Some((property, value_tokens)) => {
        if property == "direction" {
          match value_tokens.length() {
            0 => ()
            _ =>
              match value_tokens[0] {
                Ident(s) =>
                  if s == "rtl" {
                    direction = Rtl
                  } else if s == "ltr" {
                    direction = Ltr
                  }
                _ => ()
              }
          }
        }
        while pos < tokens.length() {
          match tokens[pos] {
            Semicolon => {
              pos += 1
              break
            }
            EOF => break
            _ => pos += 1
          }
        }
      }
      None => pos += 1
    }
  }
  direction
}

///|
/// Parse inline CSS style string and return a Style object
/// e.g., "width: 100px; height: 50px; display: flex"
pub fn parse_inline_style(css : String) -> @style.Style {
  let tokens = @token.tokenize(css)
  let mut style = {
    ..@style.Style::default(),
    direction: seed_direction(tokens),
  }
  let mut pos = 0
  while pos < tokens.length() {
    // Skip leading whitespace and semicolons
    match tokens[pos] {
      Whitespace | Semicolon => {
        pos += 1
        continue
      }
      EOF => break
      _ => ()
    }

    // Try to parse a declaration
    match parse_declaration(tokens[pos:]) {
      Some((property, value_tokens)) => {
        style = apply_property(style, property, value_tokens)
        // Skip to next semicolon or end
        while pos < tokens.length() {
          match tokens[pos] {
            Semicolon => {
              pos += 1
              break
            }
            EOF => break
            _ => pos += 1
          }
        }
      }
      None => pos += 1
    }
  }
  // Convert content-box dimensions to border-box dimensions
  // The layout engine always works with outer (border-box) dimensions
  // For content-box (CSS default), width/height specify content area only,
  // so we need to add padding and border to get the outer dimensions
  adjust_for_box_sizing(style)
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
