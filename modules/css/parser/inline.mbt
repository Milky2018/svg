///|
/// Inline style parser - parses CSS property declarations
/// e.g., "width: 100px; height: 50px; display: flex"

// Default viewport size for inline parser vh/vw resolution
let default_viewport_width : Double = 1000.0

///|
let default_viewport_height : Double = 1000.0

///|
fn is_viewport_width_unit(unit : String) -> Bool {
  unit == "vw" || unit == "dvw" || unit == "svw" || unit == "lvw"
}

///|
fn is_viewport_height_unit(unit : String) -> Bool {
  unit == "vh" || unit == "dvh" || unit == "svh" || unit == "lvh"
}

///|
/// Parse a calc() expression and try to simplify it to a Dimension
/// Returns Some(dimension) if simplification is possible, None otherwise.
/// Mixed length+percentage calc() returns None (the inline parser falls back to
/// Auto); min()/max()/clamp() use parse_calc_linear directly to keep the mixed
/// form.
fn parse_calc_expression(
  tokens : ArrayView[@token.Token],
) -> (@types.Dimension, ArrayView[@token.Token])? {
  match parse_calc_linear(tokens) {
    Some(((px, pct), rest)) =>
      if pct.abs() < 0.0001 {
        Some((Length(px), rest))
      } else if px.abs() < 0.0001 {
        Some((Percent(pct), rest))
      } else {
        // Mixed - cannot simplify (fall back to Auto)
        None
      }
    None => None
  }
}

///|
/// Parse a calc() body into a linear (px, percent_ratio) form. Starts right
/// after the Function("calc") token and consumes through the matching
/// RightParen, returning the remaining tokens. Returns None if no RightParen.
fn parse_calc_linear(
  tokens : ArrayView[@token.Token],
) -> ((Double, Double), ArrayView[@token.Token])? {
  let mut remaining = tokens
  let mut result_px : Double = 0.0
  let mut result_pct : Double = 0.0
  let mut current_op : Char = '+'
  // A unitless number before the first dimensioned term (e.g. `calc(2 * 10px)`)
  // multiplies that term; stash it here until the first value lands.
  let mut have_value = false
  let mut leading_factor : Double = 1.0
  while remaining.length() > 0 {
    remaining = skip_whitespace(remaining)
    if remaining.length() == 0 {
      break
    }
    match remaining[0] {
      RightParen =>
        // End of calc expression: return the linear form (pct as a ratio).
        return Some(((result_px, result_pct / 100.0), remaining[1:]))
      Dimension(value, raw_unit) => {
        let unit = raw_unit.to_lower()
        if unit == "%" {
          if !have_value {
            result_pct = value * leading_factor
            have_value = true
            leading_factor = 1.0
          } else {
            match current_op {
              '+' => result_pct = result_pct + value
              '-' => result_pct = result_pct - value
              '*' => result_pct = result_pct * value
              '/' => result_pct = result_pct / value
              _ => ()
            }
          }
        } else {
          // px and other length units (rem/em/pt/cm/in/...) accumulate in px.
          // Unknown units fall back to the legacy px interpretation.
          let px = match dimension_unit_to_px(value, unit) {
            Some(p) => p
            None => value
          }
          if !have_value {
            result_px = px * leading_factor
            have_value = true
            leading_factor = 1.0
          } else {
            match current_op {
              '+' => result_px = result_px + px
              '-' => result_px = result_px - px
              '*' => result_px = result_px * px
              '/' => result_px = result_px / px
              _ => ()
            }
          }
        }
        remaining = remaining[1:]
      }
      Percentage(value) => {
        if !have_value {
          result_pct = value * leading_factor
          have_value = true
          leading_factor = 1.0
        } else {
          match current_op {
            '+' => result_pct = result_pct + value
            '-' => result_pct = result_pct - value
            '*' => result_pct = result_pct * value
            '/' => result_pct = result_pct / value
            _ => ()
          }
        }
        remaining = remaining[1:]
      }
      Number(value, _) => {
        // Unitless number. After a dimensioned term it scales the running
        // result (`10px * 2`); before the first term it is a leading factor for
        // the next term (`2 * 10px`). Zero has no effect.
        if value != 0.0 {
          match current_op {
            '*' =>
              if have_value {
                result_px = result_px * value
                result_pct = result_pct * value
              } else {
                leading_factor = leading_factor * value
              }
            '/' =>
              if have_value {
                result_px = result_px / value
                result_pct = result_pct / value
              } else {
                leading_factor = leading_factor / value
              }
            _ => if !have_value { leading_factor = leading_factor * value }
          }
        }
        remaining = remaining[1:]
      }
      Delim(c) =>
        if c == '+' || c == '-' || c == '*' || c == '/' {
          current_op = c
          remaining = remaining[1:]
        } else {
          remaining = remaining[1:]
        }
      _ => remaining = remaining[1:]
    }
  }
  None
}

///|
/// Collapse a linear (px, percent_ratio) form to the most specific Dimension.
/// Mirrors the computed engine's lp_to_dimension.
fn lp_to_dim(px : Double, pct : Double) -> @types.Dimension {
  if pct.abs() < 0.0001 {
    Length(px)
  } else if px.abs() < 0.0001 {
    Percent(pct)
  } else {
    Calc(px, pct)
  }
}

///|
/// Reduce a resolvable Dimension to a linear (px, percent_ratio) form. Returns
/// None for forms that cannot be expressed as a single linear term (MathFn,
/// intrinsic keywords, Auto) — matching the computed engine's math_arg_lp.
fn dimension_to_lp(dim : @types.Dimension) -> (Double, Double)? {
  match dim {
    Length(px) => Some((px, 0.0))
    Percent(p) => Some((0.0, p))
    Calc(px, pct) => Some((px, pct))
    _ => None
  }
}

///|
/// Parse a single min()/max()/clamp() argument (one primary: a value token, a
/// calc(), or a nested math function) into a linear (px, percent_ratio) form.
/// Bare arithmetic without a calc() wrapper is not supported (parity with the
/// computed engine). Returns the remaining tokens positioned at the following
/// Comma or RightParen.
fn parse_math_arg_lp(
  tokens : ArrayView[@token.Token],
) -> ((Double, Double), ArrayView[@token.Token])? {
  let toks = skip_whitespace(tokens)
  if toks.length() == 0 {
    return None
  }
  match toks[0] {
    Function(name) => {
      let lname = name.to_lower()
      if lname == "calc" {
        parse_calc_linear(toks[1:])
      } else if lname == "min" || lname == "max" || lname == "clamp" {
        match parse_math_function(lname, toks[1:]) {
          Some((dim, rest)) =>
            match dimension_to_lp(dim) {
              Some(lp) => Some((lp, rest))
              None => None
            }
          None => None
        }
      } else {
        None
      }
    }
    Dimension(value, raw_unit) => {
      let unit = raw_unit.to_lower()
      if unit == "%" {
        Some(((0.0, value / 100.0), toks[1:]))
      } else {
        match dimension_unit_to_px(value, unit) {
          Some(px) => Some(((px, 0.0), toks[1:]))
          // Unknown unit is an invalid length argument; reject it so the result
          // matches the computed engine (rather than the legacy px fallback).
          None => None
        }
      }
    }
    Percentage(value) => Some(((0.0, value / 100.0), toks[1:]))
    Number(value, _) =>
      if value == 0.0 {
        Some(((0.0, 0.0), toks[1:]))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse min()/max()/clamp() arguments starting right after the Function token,
/// through the matching RightParen. Builds a collapsed Dimension when the
/// arguments share a unit (or there is a single argument) and a MathFn when
/// length and percentage are mixed and need a layout-time basis.
fn parse_math_function(
  op_name : String,
  tokens : ArrayView[@token.Token],
) -> (@types.Dimension, ArrayView[@token.Token])? {
  let op = match op_name {
    "min" => @types.MathOp::Min
    "max" => Max
    _ => Clamp
  }
  let lps : Array[(Double, Double)] = []
  let mut remaining = tokens
  let mut closed = false
  while !closed {
    remaining = skip_whitespace(remaining)
    if remaining.length() == 0 {
      return None // unterminated function
    }
    // Allow an empty argument list to terminate cleanly (e.g. malformed input).
    match remaining[0] {
      RightParen => {
        remaining = remaining[1:]
        closed = true
        continue
      }
      _ => ()
    }
    match parse_math_arg_lp(remaining) {
      Some((lp, rest)) => {
        lps.push(lp)
        remaining = skip_whitespace(rest)
        if remaining.length() == 0 {
          return None
        }
        match remaining[0] {
          Comma => remaining = remaining[1:]
          RightParen => {
            remaining = remaining[1:]
            closed = true
          }
          _ => return None // unexpected token
        }
      }
      None => return None
    }
  }
  if lps.is_empty() {
    return None
  }
  if op == Clamp && lps.length() != 3 {
    return None
  }
  // Single min()/max() argument resolves to that argument verbatim.
  if lps.length() == 1 {
    let (px, pct) = lps[0]
    return Some((lp_to_dim(px, pct), remaining))
  }
  let mut all_px = true
  let mut all_pct = true
  for lp in lps {
    if lp.1 != 0.0 {
      all_px = false
    }
    if lp.0 != 0.0 {
      all_pct = false
    }
  }
  let dim = if all_px {
    @types.Dimension::Length(@types.apply_math_op(op, lps.map(fn(lp) { lp.0 })))
  } else if all_pct {
    Percent(@types.apply_math_op(op, lps.map(fn(lp) { lp.1 })))
  } else {
    MathFn(op, lps)
  }
  Some((dim, remaining))
}

///|
/// Parse a dimension value (length, percent, auto)
/// viewport units are converted to Length using default viewport (1000x1000)

///|
/// Convert a length unit to pixels using the inline parser's context-free
/// defaults (16px font, 1000×1000 viewport). Mirrors the unit coverage of the
/// computed engine's resolve_dimension. Returns None for non-length units.
fn dimension_unit_to_px(value : Double, unit : String) -> Double? {
  match unit {
    "px" => Some(value)
    "em" | "rem" => Some(value * 16.0)
    // ex/ch approximated as 0.5em, matching the computed engine's default.
    "ex" | "ch" => Some(value * 16.0 * 0.5)
    "vw" | "dvw" | "svw" | "lvw" | "vi" =>
      Some(value * default_viewport_width / 100.0)
    "vh" | "dvh" | "svh" | "lvh" | "vb" =>
      Some(value * default_viewport_height / 100.0)
    "vmin" => {
      let base = if default_viewport_width < default_viewport_height {
        default_viewport_width
      } else {
        default_viewport_height
      }
      Some(value * base / 100.0)
    }
    "vmax" => {
      let base = if default_viewport_width > default_viewport_height {
        default_viewport_width
      } else {
        default_viewport_height
      }
      Some(value * base / 100.0)
    }
    "pt" => Some(value * 96.0 / 72.0)
    "pc" => Some(value * 16.0)
    "in" => Some(value * 96.0)
    "cm" => Some(value * 96.0 / 2.54)
    "mm" => Some(value * 96.0 / 25.4)
    "q" => Some(value * 96.0 / 101.6)
    _ => None
  }
}

///|
fn parse_dimension(tokens : ArrayView[@token.Token]) -> @types.Dimension? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Function(name) => {
      let lname = name.to_lower()
      if lname == "calc" {
        // Try to parse and simplify calc expression
        match parse_calc_expression(tokens[1:]) {
          Some((dim, _)) => return Some(dim)
          None => return Some(Auto) // Fallback for complex calc
        }
      } else if lname == "min" || lname == "max" || lname == "clamp" {
        match parse_math_function(lname, tokens[1:]) {
          Some((dim, _)) => return Some(dim)
          None => return Some(Auto) // Fallback for complex/mixed-calc args
        }
      } else {
        None
      }
    }
    Dimension(value, raw_unit) => {
      // CSS units are case-insensitive.
      let unit = raw_unit.to_lower()
      if unit == "%" {
        Some(Percent(value / 100.0))
      } else {
        match dimension_unit_to_px(value, unit) {
          Some(px) => Some(Length(px))
          // Unknown unit: fall back to treating the number as pixels (legacy).
          None => Some(Length(value))
        }
      }
    }
    Percentage(value) => Some(Percent(value / 100.0))
    Number(value, _) =>
      // Unitless 0 is valid
      if value == 0.0 {
        Some(Length(0.0))
      } else {
        None
      }
    Ident(s) =>
      if s == "auto" {
        Some(Auto)
      } else if s == "min-content" {
        Some(MinContent)
      } else if s == "max-content" {
        Some(MaxContent)
      } else if s == "fit-content" {
        // fit-content without argument is equivalent to fit-content(max-content)
        // Using infinity to represent unbounded
        Some(FitContent(1.0e10))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse multiple dimension values (for shorthand properties like margin, padding)
fn parse_multi_dimensions(
  tokens : ArrayView[@token.Token],
  max_count : Int,
) -> Array[@types.Dimension] {
  let result : Array[@types.Dimension] = []
  let mut rest = tokens
  while result.length() < max_count && rest.length() > 0 {
    // Skip whitespace
    rest = skip_whitespace(rest)
    if rest.length() == 0 {
      break
    }
    // Try to parse a dimension
    match parse_dimension(rest) {
      Some(dim) => {
        result.push(dim)
        rest = rest[1:]
      }
      None => break
    }
  }
  result
}

///|
fn parse_display_keyword(keyword : String) -> @types.Display? {
  if keyword == "block" {
    Some(Block)
  } else if keyword == "inline" {
    Some(Inline)
  } else if keyword == "inline-block" {
    Some(InlineBlock)
  } else if keyword == "flex" {
    Some(Flex)
  } else if keyword == "inline-flex" {
    Some(InlineFlex)
  } else if keyword == "grid" {
    Some(Grid)
  } else if keyword == "inline-grid" {
    Some(InlineGrid)
  } else if keyword == "table" {
    Some(Table)
  } else if keyword == "inline-table" {
    Some(InlineTable)
  } else if keyword == "table-row" {
    Some(TableRow)
  } else if keyword == "table-cell" {
    Some(TableCell)
  } else if keyword == "table-caption" {
    Some(TableCaption)
  } else if keyword == "table-row-group" {
    Some(TableRowGroup)
  } else if keyword == "table-header-group" {
    Some(TableHeaderGroup)
  } else if keyword == "table-footer-group" {
    Some(TableFooterGroup)
  } else if keyword == "table-column" {
    Some(TableColumn)
  } else if keyword == "table-column-group" {
    Some(TableColumnGroup)
  } else if keyword == "none" {
    Some(None)
  } else if keyword == "contents" {
    Some(Contents)
  } else if keyword == "flow-root" {
    Some(FlowRoot)
  } else if keyword == "math" {
    Some(Inline)
  } else {
    None
  }
}

///|
/// Parse display property
fn parse_display(tokens : ArrayView[@token.Token]) -> @types.Display? {
  if tokens.length() == 0 {
    return None
  }
  let keywords : Array[String] = []
  for token in tokens {
    match token {
      Ident(s) => keywords.push(s)
      Whitespace => ()
      _ => return None
    }
  }
  if keywords.length() == 0 {
    return None
  }
  if keywords.length() == 2 {
    let first = keywords[0]
    let second = keywords[1]
    if (first == "math" && second == "inline") ||
      (first == "inline" && second == "math") {
      return Some(Inline)
    }
    if (first == "math" && second == "block") ||
      (first == "block" && second == "math") {
      return Some(Block)
    }
    if (first == "flow-root" && second == "list-item") ||
      (first == "list-item" && second == "flow-root") {
      return Some(FlowRoot)
    }
  }
  if keywords.length() != 1 {
    return None
  }
  parse_display_keyword(keywords[0])
}

///|
/// Parse position property
fn parse_position(tokens : ArrayView[@token.Token]) -> @types.Position? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "relative" {
        Some(Relative)
      } else if s == "absolute" {
        Some(Absolute)
      } else if s == "fixed" {
        Some(Fixed)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse float property
fn parse_float(
  tokens : ArrayView[@token.Token],
  direction : @style.Direction,
) -> @types.Float? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "left" {
        Some(Left)
      } else if s == "right" {
        Some(Right)
      } else if s == "inline-start" {
        Some(if direction.is_rtl() { Right } else { Left })
      } else if s == "inline-end" {
        Some(if direction.is_rtl() { Left } else { Right })
      } else if s == "none" {
        Some(None)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse clear property
fn parse_clear(
  tokens : ArrayView[@token.Token],
  direction : @style.Direction,
) -> @types.Clear? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "left" {
        Some(Left)
      } else if s == "right" {
        Some(Right)
      } else if s == "inline-start" {
        Some(if direction.is_rtl() { Right } else { Left })
      } else if s == "inline-end" {
        Some(if direction.is_rtl() { Left } else { Right })
      } else if s == "both" {
        Some(Both)
      } else if s == "none" {
        Some(None)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse flex-direction property
fn parse_flex_direction(
  tokens : ArrayView[@token.Token],
) -> @types.FlexDirection? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "row" {
        Some(Row)
      } else if s == "row-reverse" {
        Some(RowReverse)
      } else if s == "column" {
        Some(Column)
      } else if s == "column-reverse" {
        Some(ColumnReverse)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse flex-wrap property
fn parse_flex_wrap(tokens : ArrayView[@token.Token]) -> @types.FlexWrap? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "nowrap" {
        Some(NoWrap)
      } else if s == "wrap" {
        Some(Wrap)
      } else if s == "wrap-reverse" {
        Some(WrapReverse)
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_alignment_keyword(value : String) -> @types.Alignment? {
  if value == "flex-start" {
    Some(FlexStart)
  } else if value == "start" {
    Some(Start)
  } else if value == "flex-end" {
    Some(FlexEnd)
  } else if value == "end" {
    Some(End)
  } else if value == "left" {
    Some(Left)
  } else if value == "right" {
    Some(Right)
  } else if value == "center" {
    Some(Center)
  } else if value == "space-between" {
    Some(SpaceBetween)
  } else if value == "space-around" {
    Some(SpaceAround)
  } else if value == "space-evenly" {
    Some(SpaceEvenly)
  } else if value == "stretch" {
    Some(Stretch)
  } else if value == "baseline" || value == "first baseline" {
    Some(Baseline)
  } else if value == "last baseline" {
    Some(End)
  } else {
    None
  }
}

///|
fn collect_alignment_parts(tokens : ArrayView[@token.Token]) -> Array[String] {
  let parts : Array[String] = []
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Ident(s) => parts.push(s)
      _ => ()
    }
  }
  parts
}

///|
fn parse_alignment_segment_with_overflow(
  parts : Array[String],
  start : Int,
) -> ((@types.Alignment, Bool), Int)? {
  if start >= parts.length() {
    return None
  }

  let mut idx = start
  let mut is_safe = false
  let mut is_unsafe = false
  if parts[idx] == "safe" {
    is_safe = true
    idx = idx + 1
  } else if parts[idx] == "unsafe" {
    is_unsafe = true
    idx = idx + 1
  }
  if idx >= parts.length() {
    return None
  }

  let keyword = if idx + 1 < parts.length() &&
    parts[idx + 1] == "baseline" &&
    (parts[idx] == "first" || parts[idx] == "last") {
    parts[idx] + " baseline"
  } else {
    parts[idx]
  }
  let next_index = if keyword == parts[idx] { idx + 1 } else { idx + 2 }

  match parse_alignment_keyword(keyword) {
    Some(parsed) => {
      let alignment = if is_safe {
        match parsed {
          Center | End | FlexEnd => @types.Alignment::Start
          _ => parsed
        }
      } else {
        parsed
      }
      Some(((alignment, is_unsafe), next_index))
    }
    None => None
  }
}

///|
fn parse_alignment_segment(
  parts : Array[String],
  start : Int,
) -> (@types.Alignment, Int)? {
  match parse_alignment_segment_with_overflow(parts, start) {
    Some(((alignment, _), next_index)) => Some((alignment, next_index))
    None => None
  }
}

///|
fn parse_alignment_with_overflow(
  tokens : ArrayView[@token.Token],
) -> (@types.Alignment, Bool)? {
  let parts = collect_alignment_parts(tokens)
  match parse_alignment_segment_with_overflow(parts, 0) {
    Some(((alignment, is_unsafe), _)) => Some((alignment, is_unsafe))
    None => None
  }
}

///|
/// Parse alignment property (justify-content, align-items, etc.)
fn parse_alignment(tokens : ArrayView[@token.Token]) -> @types.Alignment? {
  let parts = collect_alignment_parts(tokens)
  match parse_alignment_segment(parts, 0) {
    Some((alignment, _)) => Some(alignment)
    None => None
  }
}

///|
fn parse_place_content_with_overflow(
  tokens : ArrayView[@token.Token],
) -> ((@types.Alignment, Bool), (@types.Alignment, Bool))? {
  let parts = collect_alignment_parts(tokens)
  match parse_alignment_segment_with_overflow(parts, 0) {
    Some((align_content, next_index)) =>
      if next_index >= parts.length() {
        Some((align_content, align_content))
      } else {
        match parse_alignment_segment_with_overflow(parts, next_index) {
          Some((justify_content, _)) => Some((align_content, justify_content))
          None => Some((align_content, align_content))
        }
      }
    None => None
  }
}

///|
/// Parse self-alignment property (align-self, justify-self)
fn parse_self_alignment(tokens : ArrayView[@token.Token]) -> @types.AlignSelf? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "auto" {
        Some(Auto)
      } else if s == "flex-start" || s == "start" {
        Some(Start)
      } else if s == "flex-end" || s == "end" {
        Some(End)
      } else if s == "center" {
        Some(Center)
      } else if s == "stretch" {
        Some(Stretch)
      } else if s == "baseline" {
        Some(Baseline)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a numeric value
fn parse_number(tokens : ArrayView[@token.Token]) -> Double? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Number(value, _) => Some(value)
    _ => None
  }
}

///|
/// Parse an integer value
fn parse_integer(tokens : ArrayView[@token.Token]) -> Int? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Number(value, _) => Some(value.to_int())
    _ => None
  }
}

///|
/// Parse flex shorthand property
/// flex: none | auto | <flex-grow> [<flex-shrink>] [<flex-basis>]
/// The values can appear in any order, with these rules:
/// - Numbers are flex-grow (first) and flex-shrink (second)
/// - Dimensions/percentages/keywords are flex-basis
fn parse_flex_shorthand(
  tokens : ArrayView[@token.Token],
) -> (Double, Double, @types.Dimension)? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }

  // Check for keyword values
  match tokens[0] {
    Ident(s) => {
      if s == "none" {
        // flex: none = 0 0 auto
        return Some((0.0, 0.0, Auto))
      }
      if s == "auto" {
        // flex: auto = 1 1 auto
        return Some((1.0, 1.0, Auto))
      }
      if s == "initial" {
        // flex: initial = 0 1 auto
        return Some((0.0, 1.0, Auto))
      }
    }
    _ => ()
  }

  // CSS flex shorthand order: <flex-grow> [<flex-shrink>] [<flex-basis>]
  // Numbers must come first, then optionally a basis value.
  // Invalid orderings like "1 0% 1" (basis in middle) must return None.
  let numbers : Array[Double] = []
  let mut basis : @types.Dimension? = None
  let mut tokens_view = tokens
  let mut seen_basis = false

  // First, parse all leading numbers (grow and optionally shrink)
  while tokens_view.length() > 0 {
    tokens_view = skip_whitespace(tokens_view)
    if tokens_view.length() == 0 {
      break
    }
    match tokens_view[0] {
      Number(v, _) => {
        if seen_basis {
          // Number after basis is invalid (e.g., "1 0% 1")
          return None
        }
        numbers.push(v)
        tokens_view = tokens_view[1:]
      }
      Dimension(_, _) | Percentage(_) => {
        // This is flex-basis
        if seen_basis {
          // Second basis value is invalid
          return None
        }
        match parse_dimension(tokens_view) {
          Some(dim) => {
            basis = Some(dim)
            seen_basis = true
            tokens_view = tokens_view[1:]
          }
          None => break
        }
      }
      Ident(s) =>
        // Could be flex-basis keyword (auto, content, etc.)
        if s == "auto" || s == "content" {
          if seen_basis {
            return None
          }
          basis = Some(Auto)
          seen_basis = true
          tokens_view = tokens_view[1:]
        } else {
          break
        }
      _ => break
    }
  }

  // Check for trailing tokens (anything after basis is invalid)
  tokens_view = skip_whitespace(tokens_view)
  if tokens_view.length() > 0 {
    // Still have tokens left - could be invalid like "1 0% 1"
    match tokens_view[0] {
      Number(_, _) =>
        // Number after basis is invalid
        if seen_basis {
          return None
        }
      _ => ()
    }
  }

  // Determine values based on what we found
  let grow = if numbers.length() >= 1 { numbers[0] } else { 1.0 }
  let shrink = if numbers.length() >= 2 { numbers[1] } else { 1.0 }
  let final_basis = match basis {
    Some(b) => b
    None =>
      // CSS spec: when only numbers are specified, basis defaults to 0%.
      if numbers.length() >= 1 {
        Percent(0.0)
      } else {
        Auto
      }
  }
  if numbers.length() == 0 && basis is None {
    return None
  }
  Some((grow, shrink, final_basis))
}

///|
/// Parse flex-flow shorthand property
/// flex-flow: <flex-direction> || <flex-wrap>
fn parse_flex_flow_shorthand(
  tokens : ArrayView[@token.Token],
) -> (@types.FlexDirection, @types.FlexWrap)? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  let mut direction : @types.FlexDirection? = None
  let mut wrap : @types.FlexWrap? = None

  // Parse up to 2 tokens
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      Ident(s) =>
        // Check if it's a flex-direction value
        if s == "row" {
          direction = Some(Row)
        } else if s == "row-reverse" {
          direction = Some(RowReverse)
        } else if s == "column" {
          direction = Some(Column)
        } else if s == "column-reverse" {
          direction = Some(ColumnReverse)
          // Check if it's a flex-wrap value
        } else if s == "nowrap" {
          wrap = Some(NoWrap)
        } else if s == "wrap" {
          wrap = Some(Wrap)
        } else if s == "wrap-reverse" {
          wrap = Some(WrapReverse)
        }
      Whitespace => ()
      _ => ()
    }
    i += 1
  }

  // If we found at least one value, return with defaults for the other
  if direction is Some(_) || wrap is Some(_) {
    Some((direction.unwrap_or(Row), wrap.unwrap_or(NoWrap)))
  } else {
    None
  }
}

///|
/// Parse aspect-ratio property (e.g., "16 / 9" or "1.5")
fn parse_aspect_ratio(tokens : ArrayView[@token.Token]) -> Double? {
  if tokens.length() == 0 {
    return None
  }
  let tokens = skip_whitespace(tokens)
  match tokens[0] {
    Number(value, _) => {
      // Check for "x / y" format
      let rest = skip_whitespace(tokens[1:])
      if rest.length() >= 2 {
        match (rest[0], skip_whitespace(rest[1:])) {
          (Delim('/'), rest2) =>
            if rest2.length() > 0 {
              match rest2[0] {
                Number(divisor, _) =>
                  if divisor != 0.0 {
                    return Some(value / divisor)
                  } else {
                    return Some(value)
                  }
                _ => return Some(value)
              }
            } else {
              return Some(value)
            }
          _ => return Some(value)
        }
      }
      Some(value)
    }
    _ => None
  }
}
