///|
/// Parsing for the `animation` / `transition` properties (shorthands and
/// longhands). Values are comma-separated lists; commas inside function
/// arguments (e.g. `cubic-bezier(...)`, `steps(...)`, `linear(...)`) are not
/// separators, so splitting is done at paren depth 0 on the token stream.

///|
/// Split a token view into comma-separated segments at paren depth 0.
fn split_top_level_commas(
  tokens : ArrayView[@token.Token],
) -> Array[ArrayView[@token.Token]] {
  let segments : Array[ArrayView[@token.Token]] = []
  let mut depth = 0
  let mut start = 0
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Function(_) | LeftParen => depth = depth + 1
      RightParen => if depth > 0 { depth = depth - 1 }
      Comma =>
        if depth == 0 {
          segments.push(tokens[start:i])
          start = i + 1
        }
      _ => ()
    }
  }
  segments.push(tokens[start:])
  segments
}

///|
/// Reconstruct CSS source text for a token slice (used to feed sub-parsers such
/// as `parse_easing`). Only the token kinds that appear in animation/transition
/// values are handled.
fn reconstruct_css(tokens : ArrayView[@token.Token]) -> String {
  let sb = StringBuilder::new()
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Ident(s) => sb.write_string(s)
      Function(name) => {
        sb.write_string(name)
        sb.write_char('(')
      }
      Number(v, _) => sb.write_string(format_number(v))
      Dimension(v, unit) => {
        sb.write_string(format_number(v))
        sb.write_string(unit)
      }
      Percentage(v) => {
        sb.write_string(format_number(v))
        sb.write_char('%')
      }
      LeftParen => sb.write_char('(')
      RightParen => sb.write_char(')')
      Comma => sb.write_char(',')
      Whitespace => sb.write_char(' ')
      Delim(c) => sb.write_char(c)
      Colon => sb.write_char(':')
      _ => ()
    }
  }
  sb.to_string()
}

///|
/// Format a Double for CSS reconstruction, dropping a trailing `.0` for
/// integers (so `4.0` becomes `4`, matching the original source closely enough
/// for the sub-parsers).
fn format_number(v : Double) -> String {
  let i = v.to_int()
  if i.to_double() == v {
    i.to_string()
  } else {
    v.to_string()
  }
}

///|
/// Parse a single `<time>` token (`<n>s` / `<n>ms` / unitless `0`) into seconds.
fn time_token_to_seconds(t : @token.Token) -> Double? {
  match t {
    Dimension(v, unit) => {
      let u = unit.to_lower()
      if u == "s" {
        Some(v)
      } else if u == "ms" {
        Some(v / 1000.0)
      } else {
        None
      }
    }
    Number(v, _) => if v == 0.0 { Some(0.0) } else { None }
    _ => None
  }
}

///|
/// Parse a comma-separated list of `<time>` values into seconds.
fn parse_time_list(tokens : ArrayView[@token.Token]) -> Array[Double] {
  let result : Array[Double] = []
  for seg in split_top_level_commas(tokens) {
    let s = skip_whitespace(seg)
    if s.length() > 0 {
      match time_token_to_seconds(s[0]) {
        Some(secs) => result.push(secs)
        None => ()
      }
    }
  }
  result
}

///|
/// Parse a comma-separated list of `<easing>` values.
fn parse_easing_list(tokens : ArrayView[@token.Token]) -> Array[@types.Easing] {
  let result : Array[@types.Easing] = []
  for seg in split_top_level_commas(tokens) {
    let text = reconstruct_css(seg).trim().to_owned()
    match @types.parse_easing(text) {
      Some(e) => result.push(e)
      None => ()
    }
  }
  result
}

///|
/// Parse a comma-separated list of `<custom-ident>` names (animation-name /
/// transition-property). `none` is kept verbatim.
fn parse_ident_list(tokens : ArrayView[@token.Token]) -> Array[String] {
  let result : Array[String] = []
  for seg in split_top_level_commas(tokens) {
    let s = skip_whitespace(seg)
    if s.length() > 0 {
      match s[0] {
        Ident(name) => result.push(name)
        _ => ()
      }
    }
  }
  result
}

///|
/// Parse animation-iteration-count: list of `<number>` or `infinite`.
fn parse_iteration_count_list(
  tokens : ArrayView[@token.Token],
) -> Array[@types.AnimationIterationCount] {
  let result : Array[@types.AnimationIterationCount] = []
  for seg in split_top_level_commas(tokens) {
    let s = skip_whitespace(seg)
    if s.length() > 0 {
      match s[0] {
        Number(v, _) => result.push(Count(v))
        Ident(name) =>
          if name.to_lower() == "infinite" {
            result.push(Infinite)
          }
        _ => ()
      }
    }
  }
  result
}

///|
/// Map an ident to an animation-direction, if it is one.
fn ident_to_direction(s : String) -> @types.AnimationDirection? {
  match s.to_lower() {
    "normal" => Some(Normal)
    "reverse" => Some(Reverse)
    "alternate" => Some(Alternate)
    "alternate-reverse" => Some(AlternateReverse)
    _ => None
  }
}

///|
/// Map an ident to an animation-fill-mode, if it is one.
fn ident_to_fill_mode(s : String) -> @types.AnimationFillMode? {
  match s.to_lower() {
    "none" => Some(None)
    "forwards" => Some(Forwards)
    "backwards" => Some(Backwards)
    "both" => Some(Both)
    _ => None
  }
}

///|
/// Map an ident to an animation-play-state, if it is one.
fn ident_to_play_state(s : String) -> @types.AnimationPlayState? {
  match s.to_lower() {
    "running" => Some(Running)
    "paused" => Some(Paused)
    _ => None
  }
}

///|
/// Parse animation-direction list.
fn parse_direction_list(
  tokens : ArrayView[@token.Token],
) -> Array[@types.AnimationDirection] {
  let result : Array[@types.AnimationDirection] = []
  for seg in split_top_level_commas(tokens) {
    let s = skip_whitespace(seg)
    if s.length() > 0 {
      match s[0] {
        Ident(name) =>
          match ident_to_direction(name) {
            Some(d) => result.push(d)
            None => ()
          }
        _ => ()
      }
    }
  }
  result
}

///|
/// Parse animation-fill-mode list.
fn parse_fill_mode_list(
  tokens : ArrayView[@token.Token],
) -> Array[@types.AnimationFillMode] {
  let result : Array[@types.AnimationFillMode] = []
  for seg in split_top_level_commas(tokens) {
    let s = skip_whitespace(seg)
    if s.length() > 0 {
      match s[0] {
        Ident(name) =>
          match ident_to_fill_mode(name) {
            Some(f) => result.push(f)
            None => ()
          }
        _ => ()
      }
    }
  }
  result
}

///|
/// Parse animation-play-state list.
fn parse_play_state_list(
  tokens : ArrayView[@token.Token],
) -> Array[@types.AnimationPlayState] {
  let result : Array[@types.AnimationPlayState] = []
  for seg in split_top_level_commas(tokens) {
    let s = skip_whitespace(seg)
    if s.length() > 0 {
      match s[0] {
        Ident(name) =>
          match ident_to_play_state(name) {
            Some(p) => result.push(p)
            None => ()
          }
        _ => ()
      }
    }
  }
  result
}

///|
/// One parsed animation in the `animation` shorthand.
priv struct AnimationItem {
  mut name : String
  mut duration : Double
  mut timing : @types.Easing
  mut delay : Double
  mut iteration : @types.AnimationIterationCount
  mut direction : @types.AnimationDirection
  mut fill : @types.AnimationFillMode
  mut play_state : @types.AnimationPlayState
  mut time_count : Int
}

///|
/// The result of parsing the `animation` shorthand: parallel longhand lists.
pub struct AnimationShorthand {
  names : Array[String]
  durations : Array[Double]
  timing_functions : Array[@types.Easing]
  delays : Array[Double]
  iteration_counts : Array[@types.AnimationIterationCount]
  directions : Array[@types.AnimationDirection]
  fill_modes : Array[@types.AnimationFillMode]
  play_states : Array[@types.AnimationPlayState]
}

///|
/// Try to consume an easing starting at index `i` in `seg`. Returns the parsed
/// easing and the index just past it, or None.
fn try_parse_easing_at(
  seg : ArrayView[@token.Token],
  i : Int,
) -> (@types.Easing, Int)? {
  match seg[i] {
    Function(_) => {
      // Consume through the matching RightParen.
      let mut j = i + 1
      let mut depth = 1
      while j < seg.length() && depth > 0 {
        match seg[j] {
          Function(_) | LeftParen => depth = depth + 1
          RightParen => depth = depth - 1
          _ => ()
        }
        j = j + 1
      }
      let text = reconstruct_css(seg[i:j]).trim().to_owned()
      match @types.parse_easing(text) {
        Some(e) => Some((e, j))
        None => None
      }
    }
    Ident(s) =>
      // Only treat as easing when it is not a direction/fill/play-state keyword
      // (those are handled separately) and parse_easing accepts it.
      if ident_to_direction(s) is None &&
        ident_to_fill_mode(s) is None &&
        ident_to_play_state(s) is None {
        match @types.parse_easing(s) {
          Some(e) => Some((e, i + 1))
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse one segment of the `animation` shorthand into an AnimationItem.
fn parse_animation_item(seg : ArrayView[@token.Token]) -> AnimationItem {
  let item : AnimationItem = {
    name: "none",
    duration: 0.0,
    timing: Ease,
    delay: 0.0,
    iteration: Count(1.0),
    direction: Normal,
    fill: None,
    play_state: Running,
    time_count: 0,
  }
  let mut i = 0
  while i < seg.length() {
    match seg[i] {
      Whitespace => i = i + 1
      Dimension(_, _) | Number(_, _) =>
        // A <time> is duration (first) then delay (second). A bare <number>
        // (or `0`) that is not a time is iteration-count.
        match time_token_to_seconds(seg[i]) {
          Some(secs) => {
            if item.time_count == 0 {
              item.duration = secs
            } else {
              item.delay = secs
            }
            item.time_count = item.time_count + 1
            i = i + 1
          }
          None =>
            // Non-time number => iteration-count.
            match seg[i] {
              Number(v, _) => {
                item.iteration = Count(v)
                i = i + 1
              }
              _ => i = i + 1
            }
        }
      Function(_) =>
        match try_parse_easing_at(seg, i) {
          Some((e, next)) => {
            item.timing = e
            i = next
          }
          None => i = i + 1
        }
      Ident(s) => {
        let ls = s.to_lower()
        if ls == "infinite" {
          item.iteration = Infinite
          i = i + 1
        } else if ident_to_direction(s) is Some(d) {
          item.direction = d
          i = i + 1
        } else if ident_to_fill_mode(s) is Some(f) {
          // `none` is both a fill-mode and a valid name; prefer fill-mode only
          // when it is not the sole token. Simplicity: treat as fill-mode.
          item.fill = f
          i = i + 1
        } else if ident_to_play_state(s) is Some(p) {
          item.play_state = p
          i = i + 1
        } else {
          match try_parse_easing_at(seg, i) {
            Some((e, next)) => {
              item.timing = e
              i = next
            }
            None => {
              // Otherwise it is the animation-name.
              item.name = s
              i = i + 1
            }
          }
        }
      }
      _ => i = i + 1
    }
  }
  item
}

///|
/// Parse the `animation` shorthand into parallel longhand lists.
pub fn parse_animation_shorthand_from_string(
  value : String,
) -> AnimationShorthand {
  parse_animation_shorthand(@token.tokenize(value)[:])
}

///|
/// Parse the `animation` shorthand tokens into parallel longhand lists.
pub fn parse_animation_shorthand(
  tokens : ArrayView[@token.Token],
) -> AnimationShorthand {
  let names : Array[String] = []
  let durations : Array[Double] = []
  let timing_functions : Array[@types.Easing] = []
  let delays : Array[Double] = []
  let iteration_counts : Array[@types.AnimationIterationCount] = []
  let directions : Array[@types.AnimationDirection] = []
  let fill_modes : Array[@types.AnimationFillMode] = []
  let play_states : Array[@types.AnimationPlayState] = []
  for seg in split_top_level_commas(tokens[:]) {
    let item = parse_animation_item(seg)
    names.push(item.name)
    durations.push(item.duration)
    timing_functions.push(item.timing)
    delays.push(item.delay)
    iteration_counts.push(item.iteration)
    directions.push(item.direction)
    fill_modes.push(item.fill)
    play_states.push(item.play_state)
  }
  {
    names,
    durations,
    timing_functions,
    delays,
    iteration_counts,
    directions,
    fill_modes,
    play_states,
  }
}

///|
/// The result of parsing the `transition` shorthand: parallel longhand lists.
pub struct TransitionShorthand {
  properties : Array[String]
  durations : Array[Double]
  timing_functions : Array[@types.Easing]
  delays : Array[Double]
}

///|
/// One parsed transition in the `transition` shorthand.
priv struct TransitionItem {
  mut property : String
  mut duration : Double
  mut timing : @types.Easing
  mut delay : Double
  mut time_count : Int
}

///|
/// Parse one segment of the `transition` shorthand.
fn parse_transition_item(seg : ArrayView[@token.Token]) -> TransitionItem {
  let item : TransitionItem = {
    property: "all",
    duration: 0.0,
    timing: Ease,
    delay: 0.0,
    time_count: 0,
  }
  let mut i = 0
  while i < seg.length() {
    match seg[i] {
      Whitespace => i = i + 1
      Dimension(_, _) | Number(_, _) =>
        match time_token_to_seconds(seg[i]) {
          Some(secs) => {
            if item.time_count == 0 {
              item.duration = secs
            } else {
              item.delay = secs
            }
            item.time_count = item.time_count + 1
            i = i + 1
          }
          None => i = i + 1
        }
      Function(_) =>
        match try_parse_easing_at(seg, i) {
          Some((e, next)) => {
            item.timing = e
            i = next
          }
          None => i = i + 1
        }
      Ident(s) =>
        match try_parse_easing_at(seg, i) {
          Some((e, next)) => {
            item.timing = e
            i = next
          }
          None => {
            // The transitioned property name (or `all` / `none`).
            item.property = s
            i = i + 1
          }
        }
      _ => i = i + 1
    }
  }
  item
}

///|
/// Parse the `transition` shorthand into parallel longhand lists.
pub fn parse_transition_shorthand_from_string(
  value : String,
) -> TransitionShorthand {
  parse_transition_shorthand(@token.tokenize(value)[:])
}

///|
/// Parse the `transition` shorthand tokens into parallel longhand lists.
pub fn parse_transition_shorthand(
  tokens : ArrayView[@token.Token],
) -> TransitionShorthand {
  let properties : Array[String] = []
  let durations : Array[Double] = []
  let timing_functions : Array[@types.Easing] = []
  let delays : Array[Double] = []
  for seg in split_top_level_commas(tokens) {
    let item = parse_transition_item(seg)
    properties.push(item.property)
    durations.push(item.duration)
    timing_functions.push(item.timing)
    delays.push(item.delay)
  }
  { properties, durations, timing_functions, delays }
}

// ---- Longhand string entry points (used by the cascade/computed path) ----

///|
pub fn parse_animation_name_from_string(value : String) -> Array[String] {
  parse_ident_list(@token.tokenize(value)[:])
}

///|
pub fn parse_time_list_from_string(value : String) -> Array[Double] {
  parse_time_list(@token.tokenize(value)[:])
}

///|
pub fn parse_easing_list_from_string(value : String) -> Array[@types.Easing] {
  parse_easing_list(@token.tokenize(value)[:])
}

///|
pub fn parse_iteration_count_list_from_string(
  value : String,
) -> Array[@types.AnimationIterationCount] {
  parse_iteration_count_list(@token.tokenize(value)[:])
}

///|
pub fn parse_direction_list_from_string(
  value : String,
) -> Array[@types.AnimationDirection] {
  parse_direction_list(@token.tokenize(value)[:])
}

///|
pub fn parse_fill_mode_list_from_string(
  value : String,
) -> Array[@types.AnimationFillMode] {
  parse_fill_mode_list(@token.tokenize(value)[:])
}

///|
pub fn parse_play_state_list_from_string(
  value : String,
) -> Array[@types.AnimationPlayState] {
  parse_play_state_list(@token.tokenize(value)[:])
}
