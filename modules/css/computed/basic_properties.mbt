///|
/// Parse display value
pub fn parse_display(value : String) -> @types.Display {
  let normalized = value.trim().to_lower().to_owned()
  let parts = split_whitespace(normalized)
  if parts.length() == 0 {
    return @types.Display::Block
  }
  if parts.length() == 2 {
    let first = parts[0]
    let second = parts[1]
    if (first == "math" && second == "inline") ||
      (first == "inline" && second == "math") {
      return @types.Display::Inline
    }
    if (first == "math" && second == "block") ||
      (first == "block" && second == "math") {
      return @types.Display::Block
    }
    if (first == "flow-root" && second == "list-item") ||
      (first == "list-item" && second == "flow-root") {
      return @types.Display::FlowRoot
    }
  }
  if parts.length() > 1 {
    return @types.Display::Block
  }
  match parts[0] {
    "block" => @types.Display::Block
    "inline" => @types.Display::Inline
    "inline-block" => @types.Display::InlineBlock
    "flex" => @types.Display::Flex
    "inline-flex" => @types.Display::InlineFlex
    "grid" => @types.Display::Grid
    "inline-grid" => @types.Display::InlineGrid
    "none" => @types.Display::None
    "contents" => @types.Display::Contents
    "flow-root" => @types.Display::FlowRoot
    "math" => @types.Display::Inline
    // Table display types
    "table" => @types.Display::Table
    "inline-table" => @types.Display::InlineTable
    "table-row" => @types.Display::TableRow
    "table-cell" => @types.Display::TableCell
    "table-caption" => @types.Display::TableCaption
    "table-row-group" => @types.Display::TableRowGroup
    "table-header-group" => @types.Display::TableHeaderGroup
    "table-footer-group" => @types.Display::TableFooterGroup
    "table-column" => @types.Display::TableColumn
    "table-column-group" => @types.Display::TableColumnGroup
    // Ruby internal display types are inline-level for layout-tree comparison.
    // (Full ruby formatting context is not yet implemented.)
    "ruby" => @types.Display::Inline
    "ruby-base" => @types.Display::Inline
    "ruby-base-container" => @types.Display::Inline
    "ruby-text" => @types.Display::Inline
    "ruby-text-container" => @types.Display::Inline
    _ => @types.Display::Block
  }
}

///|
/// Parse position value
pub fn parse_position(value : String) -> @types.Position {
  match value.trim().to_lower() {
    "static" => @types.Position::Static
    "absolute" => @types.Position::Absolute
    "fixed" => @types.Position::Fixed
    "relative" | "sticky" => @types.Position::Relative
    _ => @types.Position::Static // Default is static
  }
}

///|
/// Parse float value
pub fn parse_float(value : String) -> @types.Float {
  match value.trim().to_lower() {
    "left" => @types.Float::Left
    "right" => @types.Float::Right
    "none" => @types.Float::None
    _ => @types.Float::None
  }
}

///|
pub fn parse_float_with_direction(
  value : String,
  direction : @style.Direction,
) -> @types.Float {
  match value.trim().to_lower() {
    "inline-start" =>
      if direction.is_rtl() {
        @types.Float::Right
      } else {
        @types.Float::Left
      }
    "inline-end" =>
      if direction.is_rtl() {
        @types.Float::Left
      } else {
        @types.Float::Right
      }
    _ => parse_float(value)
  }
}

///|
/// Parse clear value
pub fn parse_clear(value : String) -> @types.Clear {
  match value.trim().to_lower() {
    "left" => @types.Clear::Left
    "right" => @types.Clear::Right
    "both" => @types.Clear::Both
    "none" => @types.Clear::None
    _ => @types.Clear::None
  }
}

///|
pub fn parse_clear_with_direction(
  value : String,
  direction : @style.Direction,
) -> @types.Clear {
  match value.trim().to_lower() {
    "inline-start" =>
      if direction.is_rtl() {
        @types.Clear::Right
      } else {
        @types.Clear::Left
      }
    "inline-end" =>
      if direction.is_rtl() {
        @types.Clear::Left
      } else {
        @types.Clear::Right
      }
    _ => parse_clear(value)
  }
}

///|
/// Parse flex-direction value
pub fn parse_flex_direction(value : String) -> @types.FlexDirection {
  match value.trim().to_lower() {
    "row" => @types.FlexDirection::Row
    "row-reverse" => @types.FlexDirection::RowReverse
    "column" => @types.FlexDirection::Column
    "column-reverse" => @types.FlexDirection::ColumnReverse
    _ => @types.FlexDirection::Row
  }
}

///|
/// Parse flex-wrap value
pub fn parse_flex_wrap(value : String) -> @types.FlexWrap {
  match value.trim().to_lower() {
    "nowrap" => @types.FlexWrap::NoWrap
    "wrap" => @types.FlexWrap::Wrap
    "wrap-reverse" => @types.FlexWrap::WrapReverse
    _ => @types.FlexWrap::NoWrap
  }
}

///|
fn tokenize_alignment_value(value : String) -> Array[String] {
  value
  .trim()
  .to_lower()
  .split(" ")
  .map(fn(part) { part.to_owned().trim().to_owned() })
  .filter(fn(part) { !part.is_empty() })
  .collect()
}

///|
fn parse_alignment_keyword(value : String) -> @types.Alignment {
  match value {
    "flex-start" => @types.Alignment::FlexStart
    "flex-end" => @types.Alignment::FlexEnd
    "start" => @types.Alignment::Start
    "end" => @types.Alignment::End
    "left" => @types.Alignment::Left
    "right" => @types.Alignment::Right
    "center" => @types.Alignment::Center
    "space-between" => @types.Alignment::SpaceBetween
    "space-around" => @types.Alignment::SpaceAround
    "space-evenly" => @types.Alignment::SpaceEvenly
    "stretch" => @types.Alignment::Stretch
    "baseline" | "first baseline" => @types.Alignment::Baseline
    // Fallback alignment for last-baseline in axis alignment.
    "last baseline" => @types.Alignment::End
    _ => @types.Alignment::FlexStart
  }
}

///|
fn parse_alignment_segment(
  tokens : Array[String],
  start : Int,
) -> (String, Int)? {
  if start >= tokens.length() {
    return None
  }
  let head = tokens[start]
  if start + 1 < tokens.length() {
    let next = tokens[start + 1]
    if head == "safe" ||
      head == "unsafe" ||
      ((head == "first" || head == "last") && next == "baseline") {
      return Some((head + " " + next, start + 2))
    }
  }
  Some((head, start + 1))
}

///|
/// Parse alignment value (justify-content, align-items, align-content)
/// Note: flex-start/flex-end are flex-relative (affected by wrap-reverse)
///       start/end are physical/logical (not affected by wrap-reverse)
pub fn parse_alignment_with_overflow(
  value : String,
) -> (@types.Alignment, Bool) {
  let tokens = tokenize_alignment_value(value)
  if tokens.is_empty() {
    return (@types.Alignment::FlexStart, false)
  }
  let mut offset = 0
  let mut is_safe = false
  let mut is_unsafe = false
  if tokens[0] == "safe" {
    is_safe = true
    offset = 1
  } else if tokens[0] == "unsafe" {
    is_unsafe = true
    offset = 1
  }
  if offset >= tokens.length() {
    return (@types.Alignment::FlexStart, false)
  }
  let keyword = if offset + 1 < tokens.length() &&
    tokens[offset + 1] == "baseline" &&
    (tokens[offset] == "first" || tokens[offset] == "last") {
    tokens[offset] + " baseline"
  } else {
    tokens[offset]
  }
  let parsed = parse_alignment_keyword(keyword)
  let parsed = if is_safe {
    match parsed {
      @types.Alignment::Center
      | @types.Alignment::End
      | @types.Alignment::FlexEnd => @types.Alignment::Start
      _ => parsed
    }
  } else {
    parsed
  }
  (parsed, is_unsafe)
}

///|
pub fn parse_alignment(value : String) -> @types.Alignment {
  let (alignment, _) = parse_alignment_with_overflow(value)
  alignment
}

///|
/// Parse place-content shorthand.
/// Returns (align_content, justify_content).
pub fn parse_place_content_with_overflow(
  value : String,
) -> ((@types.Alignment, Bool), (@types.Alignment, Bool))? {
  let tokens = tokenize_alignment_value(value)
  if tokens.is_empty() {
    return None
  }
  match parse_alignment_segment(tokens, 0) {
    Some((first, next_index)) => {
      let first_alignment = parse_alignment_with_overflow(first)
      if next_index >= tokens.length() {
        return Some((first_alignment, first_alignment))
      }
      match parse_alignment_segment(tokens, next_index) {
        Some((second, _)) =>
          Some((first_alignment, parse_alignment_with_overflow(second)))
        None => Some((first_alignment, first_alignment))
      }
    }
    None => None
  }
}

///|
/// Parse place-content shorthand.
/// Returns (align_content, justify_content).
pub fn parse_place_content(
  value : String,
) -> (@types.Alignment, @types.Alignment)? {
  match parse_place_content_with_overflow(value) {
    Some(((align_content, _), (justify_content, _))) =>
      Some((align_content, justify_content))
    None => None
  }
}

///|
/// Parse place-items shorthand: `<'align-items'> <'justify-items'>?`.
/// A single component is duplicated to both axes. Returns
/// (align_items, justify_items).
pub fn parse_place_items(
  value : String,
) -> (@types.Alignment, @types.Alignment)? {
  let tokens = tokenize_alignment_value(value)
  if tokens.is_empty() {
    return None
  }
  match parse_alignment_segment(tokens, 0) {
    Some((first, next_index)) => {
      let align_items = parse_alignment_with_overflow(first).0
      if next_index >= tokens.length() {
        return Some((align_items, align_items))
      }
      match parse_alignment_segment(tokens, next_index) {
        Some((second, _)) =>
          Some((align_items, parse_alignment_with_overflow(second).0))
        None => Some((align_items, align_items))
      }
    }
    None => None
  }
}

///|
/// Parse place-self shorthand: `<'align-self'> <'justify-self'>?`.
/// A single component is duplicated to both axes. Returns
/// (align_self, justify_self).
pub fn parse_place_self(
  value : String,
) -> (@types.AlignSelf, @types.AlignSelf)? {
  let tokens = tokenize_alignment_value(value)
  if tokens.is_empty() {
    return None
  }
  match parse_alignment_segment(tokens, 0) {
    Some((first, next_index)) => {
      let align_self = parse_align_self(first)
      if next_index >= tokens.length() {
        return Some((align_self, align_self))
      }
      match parse_alignment_segment(tokens, next_index) {
        Some((second, _)) => Some((align_self, parse_align_self(second)))
        None => Some((align_self, align_self))
      }
    }
    None => None
  }
}

///|
/// Parse align-self value
pub fn parse_align_self(value : String) -> @types.AlignSelf {
  match value.trim().to_lower() {
    "auto" => @types.AlignSelf::Auto
    "flex-start" | "start" => @types.AlignSelf::Start
    "flex-end" | "end" => @types.AlignSelf::End
    "center" => @types.AlignSelf::Center
    "stretch" => @types.AlignSelf::Stretch
    "baseline" | "first baseline" => @types.AlignSelf::Baseline
    // Fallback alignment for last-baseline in self alignment.
    "last baseline" => @types.AlignSelf::End
    _ => @types.AlignSelf::Auto
  }
}

///|
/// Parse overflow value
pub fn parse_overflow(value : String) -> @types.Overflow {
  match value.trim().to_lower() {
    "visible" => @types.Overflow::Visible
    "hidden" => @types.Overflow::Hidden
    "clip" => @types.Overflow::Clip
    "scroll" => @types.Overflow::Scroll
    "auto" => @types.Overflow::Auto
    _ => @types.Overflow::Visible
  }
}

///|
/// Parse scroll-snap-type value
/// Supports a minimal subset: none | x mandatory | y mandatory | both mandatory.
pub fn parse_scroll_snap_type(value : String) -> @style.ScrollSnapType {
  let tokens = value
    .trim()
    .to_lower()
    .split(" ")
    .map(fn(part) { part.to_owned().trim().to_owned() })
    .filter(fn(part) { !part.is_empty() })
    .collect()
  if tokens.is_empty() {
    return @style.ScrollSnapType::none()
  }

  let mut axis = @style.ScrollSnapAxis::None
  let mut strictness = @style.ScrollSnapStrictness::None
  for token in tokens {
    match token {
      "none" => return @style.ScrollSnapType::none()
      "x" | "inline" => axis = @style.ScrollSnapAxis::X
      "y" | "block" => axis = @style.ScrollSnapAxis::Y
      "both" => axis = @style.ScrollSnapAxis::Both
      "mandatory" => strictness = @style.ScrollSnapStrictness::Mandatory
      "proximity" => strictness = @style.ScrollSnapStrictness::Proximity
      _ => ()
    }
  }
  if axis == @style.ScrollSnapAxis::None ||
    strictness == @style.ScrollSnapStrictness::None {
    @style.ScrollSnapType::none()
  } else {
    { axis, strictness }
  }
}

///|
/// Parse scroll-snap-align value as (inline, block).
/// Supports keywords: none | start | end | center.
pub fn parse_scroll_snap_align(
  value : String,
) -> (@style.ScrollSnapAlign, @style.ScrollSnapAlign) {
  let tokens = value
    .trim()
    .to_lower()
    .split(" ")
    .map(fn(part) { part.to_owned().trim().to_owned() })
    .filter(fn(part) { !part.is_empty() })
    .collect()
  if tokens.is_empty() {
    return (@style.ScrollSnapAlign::None, @style.ScrollSnapAlign::None)
  }
  if tokens.length() == 1 {
    let keyword = parse_scroll_snap_align_keyword(tokens[0])
    return (keyword, keyword)
  }
  let block = parse_scroll_snap_align_keyword(tokens[0])
  let inline = parse_scroll_snap_align_keyword(tokens[1])
  (inline, block)
}

///|
fn parse_scroll_snap_align_keyword(value : String) -> @style.ScrollSnapAlign {
  match value.trim().to_lower() {
    "none" => @style.ScrollSnapAlign::None
    "start" => @style.ScrollSnapAlign::Start
    "end" => @style.ScrollSnapAlign::End
    "center" => @style.ScrollSnapAlign::Center
    _ => @style.ScrollSnapAlign::None
  }
}

///|
/// Parse white-space value
pub fn parse_white_space(value : String) -> @style.WhiteSpace {
  match value.trim().to_lower() {
    "normal" => @style.WhiteSpace::Normal
    "nowrap" => @style.WhiteSpace::Nowrap
    "pre" => @style.WhiteSpace::Pre
    "pre-wrap" => @style.WhiteSpace::PreWrap
    "pre-line" => @style.WhiteSpace::PreLine
    _ => @style.WhiteSpace::Normal
  }
}

///|
/// Parse writing-mode value
pub fn parse_writing_mode(value : String) -> @style.WritingMode {
  match value.trim().to_lower() {
    "horizontal-tb" => @style.WritingMode::HorizontalTb
    "vertical-rl" => @style.WritingMode::VerticalRl
    "vertical-lr" => @style.WritingMode::VerticalLr
    // Legacy values
    "lr" | "lr-tb" | "rl" | "rl-tb" => @style.WritingMode::HorizontalTb
    "tb" | "tb-rl" => @style.WritingMode::VerticalRl
    "tb-lr" => @style.WritingMode::VerticalLr
    _ => @style.WritingMode::HorizontalTb
  }
}

///|
/// Parse direction value (ltr/rtl)
pub fn parse_direction(value : String) -> @style.Direction {
  match value.trim().to_lower() {
    "rtl" => @style.Direction::Rtl
    "ltr" | _ => @style.Direction::Ltr
  }
}

///|
/// Parse text-align value
pub fn parse_text_align(value : String) -> @style.TextAlign {
  match value.trim().to_lower() {
    "center" => @style.TextAlign::Center
    "justify" => @style.TextAlign::Justify
    "left" => @style.TextAlign::Left
    "right" => @style.TextAlign::Right
    "end" => @style.TextAlign::End
    "start" | _ => @style.TextAlign::Start
  }
}

///|
