///|
/// Parse grid-auto-flow property
fn parse_grid_auto_flow(
  tokens : ArrayView[@token.Token],
) -> @types.GridAutoFlow? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Ident(s) =>
      if s == "row" {
        Some(Row)
      } else if s == "column" {
        Some(Column)
      } else if s == "row dense" {
        Some(RowDense)
      } else if s == "column dense" {
        Some(ColumnDense)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a single track value for MinTrackSizing
fn parse_min_track_sizing(
  tokens : ArrayView[@token.Token],
) -> (@types.MinTrackSizing, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Dimension(value, unit) =>
      if unit == "px" {
        Some((Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((Percent(value / 100.0), tokens[1:]))
      } else if is_viewport_width_unit(unit) {
        Some(
          (
            Length(
              value * default_viewport_width / 100.0,
            ),
            tokens[1:],
          ),
        )
      } else if is_viewport_height_unit(unit) {
        Some(
          (
            Length(
              value * default_viewport_height / 100.0,
            ),
            tokens[1:],
          ),
        )
      } else {
        // rem/em and physical units (pt/cm/in/...) are converted to px.
        let px = match dimension_unit_to_px(value, unit.to_lower()) {
          Some(p) => p
          None => value
        }
        Some((Length(px), tokens[1:]))
      }
    Percentage(value) =>
      Some((Percent(value / 100.0), tokens[1:]))
    Number(value, _) =>
      if value == 0.0 {
        Some((Length(0.0), tokens[1:]))
      } else {
        None
      }
    Ident(s) =>
      if s == "auto" {
        Some((Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((MaxContent, tokens[1:]))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a single track value for MaxTrackSizing
fn parse_max_track_sizing(
  tokens : ArrayView[@token.Token],
) -> (@types.MaxTrackSizing, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Dimension(value, unit) =>
      if unit == "px" {
        Some((Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((Percent(value / 100.0), tokens[1:]))
      } else if unit == "fr" {
        Some((Fr(value), tokens[1:]))
      } else if is_viewport_width_unit(unit) {
        Some(
          (
            Length(
              value * default_viewport_width / 100.0,
            ),
            tokens[1:],
          ),
        )
      } else if is_viewport_height_unit(unit) {
        Some(
          (
            Length(
              value * default_viewport_height / 100.0,
            ),
            tokens[1:],
          ),
        )
      } else {
        // rem/em and physical units (pt/cm/in/...) are converted to px.
        let px = match dimension_unit_to_px(value, unit.to_lower()) {
          Some(p) => p
          None => value
        }
        Some((Length(px), tokens[1:]))
      }
    Percentage(value) =>
      Some((Percent(value / 100.0), tokens[1:]))
    Number(value, _) =>
      if value == 0.0 {
        Some((Length(0.0), tokens[1:]))
      } else {
        None
      }
    Ident(s) =>
      if s == "auto" {
        Some((Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((MaxContent, tokens[1:]))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse the single `<length-percentage>` argument of `fit-content( ... )`,
/// starting right after the `Function("fit-content")` token. Returns the value,
/// whether it is a percentage (ratio) rather than a px length, and the tokens
/// after the matching RightParen. Length units are converted to px.
fn parse_fit_content_arg(
  tokens : ArrayView[@token.Token],
) -> (Double, Bool, ArrayView[@token.Token])? {
  let rest = skip_whitespace(tokens)
  if rest.length() == 0 {
    return None
  }
  let (val, is_pct, rest2) : (Double, Bool, ArrayView[@token.Token]) = match
    rest[0] {
    Dimension(v, raw_unit) => {
      let unit = raw_unit.to_lower()
      if unit == "%" {
        (v / 100.0, true, rest[1:])
      } else {
        let px = match dimension_unit_to_px(v, unit) {
          Some(p) => p
          None => v
        }
        (px, false, rest[1:])
      }
    }
    Percentage(v) => (v / 100.0, true, rest[1:])
    Number(v, _) =>
      if v == 0.0 {
        (0.0, false, rest[1:])
      } else {
        return None
      }
    _ => return None
  }
  let rest3 = skip_whitespace(rest2)
  if rest3.length() == 0 {
    return None
  }
  match rest3[0] {
    RightParen => Some((val, is_pct, rest3[1:]))
    _ => None
  }
}

///|
/// Parse a single track sizing value (without repeat)
fn parse_single_track_sizing(
  tokens : ArrayView[@token.Token],
) -> (@types.SingleTrackSizing, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Dimension(value, unit) =>
      if unit == "px" {
        Some((Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((Percent(value / 100.0), tokens[1:]))
      } else if unit == "fr" {
        Some((Fr(value), tokens[1:]))
      } else {
        // rem/em and physical units (pt/cm/in/...) are converted to px.
        let px = match dimension_unit_to_px(value, unit.to_lower()) {
          Some(p) => p
          None => value
        }
        Some((Length(px), tokens[1:]))
      }
    Percentage(value) =>
      Some((Percent(value / 100.0), tokens[1:]))
    Number(value, _) =>
      if value == 0.0 {
        Some((Length(0.0), tokens[1:]))
      } else {
        None
      }
    Ident(s) =>
      if s == "auto" {
        Some((Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((MaxContent, tokens[1:]))
      } else {
        None
      }
    Function(name) =>
      if name == "minmax" {
        // Parse minmax(min, max)
        let rest = tokens[1:] // skip Function token (already consumed '(')
        match parse_min_track_sizing(rest) {
          Some((min_val, rest2)) => {
            // Skip whitespace and comma
            let rest3 = skip_whitespace(rest2)
            if rest3.length() == 0 {
              return None
            }
            let rest4 = match rest3[0] {
              Comma => rest3[1:]
              _ => rest3
            }
            match parse_max_track_sizing(rest4) {
              Some((max_val, rest5)) => {
                // Skip to closing paren
                let rest6 = skip_whitespace(rest5)
                if rest6.length() > 0 {
                  match rest6[0] {
                    RightParen => {
                      let next_tokens = rest6[1:]
                      Some(
                        (
                          MinMax(min_val, max_val),
                          next_tokens,
                        ),
                      )
                    }
                    _ => None
                  }
                } else {
                  None
                }
              }
              None => None
            }
          }
          None => None
        }
      } else if name == "fit-content" {
        match parse_fit_content_arg(tokens[1:]) {
          Some((v, true, rest)) =>
            Some((FitContentPercent(v), rest))
          Some((v, false, rest)) =>
            Some((FitContentLength(v), rest))
          None => None
        }
      } else if name == "calc" {
        match parse_calc_linear(tokens[1:]) {
          Some(((px, pct), rest)) =>
            if pct.abs() < 0.0001 {
              Some((Length(px), rest))
            } else if px.abs() < 0.0001 {
              Some((Percent(pct), rest))
            } else {
              // Mixed length+percentage calc cannot be represented as a single
              // track breadth; fall back to auto but keep parsing the rest.
              Some((Auto, rest))
            }
          None => None
        }
      } else if name == "min" || name == "max" || name == "clamp" {
        match parse_math_function(name, tokens[1:]) {
          Some((dim, rest)) => {
            let tf = match dim {
              Length(v) => @types.SingleTrackSizing::Length(v)
              Percent(v) => Percent(v)
              _ => Auto
            }
            Some((tf, rest))
          }
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a track sizing function (including repeat)
fn parse_track_sizing_function(
  tokens : ArrayView[@token.Token],
) -> (@types.TrackSizingFunction, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    Function(name) =>
      if name == "repeat" {
        // Parse repeat(count, tracks...)
        let rest = tokens[1:]
        let rest = skip_whitespace(rest)
        if rest.length() == 0 {
          return None
        }
        // Parse repeat count
        let (count, rest2) : (@types.RepeatCount, ArrayView[@token.Token]) = match
          rest[0] {
          Number(value, _) =>
            (Count(value.to_int()), rest[1:])
          Ident(s) =>
            if s == "auto-fill" {
              (AutoFill, rest[1:])
            } else if s == "auto-fit" {
              (AutoFit, rest[1:])
            } else {
              return None
            }
          _ => return None
        }
        // Skip comma
        let rest3 = skip_whitespace(rest2)
        if rest3.length() == 0 {
          return None
        }
        let rest4 = match rest3[0] {
          Comma => rest3[1:]
          _ => rest3
        }
        // Parse track list until closing paren, preserving the line names
        // declared within one repetition (index = line, length = tracks + 1).
        let tracks : Array[@types.SingleTrackSizing] = []
        let line_names : Array[Array[String]] = []
        let mut remaining = rest4
        let mut done = false
        while !done {
          let (names, after_names) = capture_grid_line_names(remaining)
          remaining = after_names
          if remaining.length() == 0 {
            line_names.push(names)
            done = true
          } else {
            match remaining[0] {
              RightParen => {
                line_names.push(names)
                remaining = remaining[1:]
                done = true
              }
              _ =>
                match parse_single_track_sizing(remaining) {
                  Some((track, rest)) => {
                    line_names.push(names)
                    tracks.push(track)
                    remaining = rest
                  }
                  None => {
                    line_names.push(names)
                    done = true
                  }
                }
            }
          }
        }
        if tracks.length() > 0 {
          Some(
            (
              Repeat(count, tracks, line_names),
              remaining,
            ),
          )
        } else {
          None
        }
      } else if name == "minmax" {
        // minmax is also valid as TrackSizingFunction
        match parse_single_track_sizing(tokens) {
          Some((MinMax(min_val, max_val), rest)) =>
            Some((MinMax(min_val, max_val), rest))
          _ => None
        }
      } else if name == "fit-content" {
        match parse_fit_content_arg(tokens[1:]) {
          Some((v, true, rest)) =>
            Some((FitContentPercent(v), rest))
          Some((v, false, rest)) =>
            Some((FitContentLength(v), rest))
          None => None
        }
      } else if name == "calc" {
        match parse_calc_linear(tokens[1:]) {
          Some(((px, pct), rest)) =>
            if pct.abs() < 0.0001 {
              Some((Length(px), rest))
            } else if px.abs() < 0.0001 {
              Some((Percent(pct), rest))
            } else {
              // Mixed length+percentage calc cannot be represented as a single
              // track breadth; fall back to auto but keep parsing the rest.
              Some((Auto, rest))
            }
          None => None
        }
      } else if name == "min" || name == "max" || name == "clamp" {
        match parse_math_function(name, tokens[1:]) {
          Some((dim, rest)) => {
            let tf = match dim {
              Length(v) => @types.TrackSizingFunction::Length(v)
              Percent(v) => Percent(v)
              _ => Auto
            }
            Some((tf, rest))
          }
          None => None
        }
      } else {
        None
      }
    Dimension(value, unit) =>
      if unit == "px" {
        Some((Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((Percent(value / 100.0), tokens[1:]))
      } else if unit == "fr" {
        Some((Fr(value), tokens[1:]))
      } else {
        // rem/em and physical units (pt/cm/in/...) are converted to px.
        let px = match dimension_unit_to_px(value, unit.to_lower()) {
          Some(p) => p
          None => value
        }
        Some((Length(px), tokens[1:]))
      }
    Percentage(value) =>
      Some((Percent(value / 100.0), tokens[1:]))
    Number(value, _) =>
      if value == 0.0 {
        Some((Length(0.0), tokens[1:]))
      } else {
        None
      }
    Ident(s) =>
      if s == "auto" {
        Some((Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((MaxContent, tokens[1:]))
      } else if s == "none" {
        // none means empty template
        None
      } else {
        None
      }
    _ => None
  }
}

///|
/// Capture the grid line names declared in `[name1 name2 ...]` bracket groups at
/// the current position. Returns the collected names (lowercased, possibly
/// empty) and the remaining tokens after the brackets. Consecutive bracket
/// groups at the same line are merged.
fn capture_grid_line_names(
  tokens : ArrayView[@token.Token],
) -> (Array[String], ArrayView[@token.Token]) {
  let names : Array[String] = []
  let mut remaining = skip_whitespace(tokens)
  while remaining.length() > 0 {
    match remaining[0] {
      LeftBracket => {
        let mut i = 1
        while i < remaining.length() {
          match remaining[i] {
            RightBracket => {
              i = i + 1
              break
            }
            Ident(s) => {
              names.push(s.to_lower())
              i = i + 1
            }
            _ => i = i + 1
          }
        }
        remaining = skip_whitespace(remaining[i:])
      }
      _ => return (names, remaining)
    }
  }
  (names, remaining)
}

///|
/// Parse grid-template-columns or grid-template-rows value, preserving named
/// lines. Returns the track sizing functions and the line names (index = grid
/// line, length = tracks + 1).
fn parse_grid_template_track_list(
  tokens : ArrayView[@token.Token],
) -> (Array[@types.TrackSizingFunction], Array[Array[String]]) {
  let result : Array[@types.TrackSizingFunction] = []
  let line_names : Array[Array[String]] = []
  let mut remaining = tokens
  let mut done = false
  while !done {
    let (names, rest) = capture_grid_line_names(remaining)
    remaining = rest
    let stop = if remaining.length() == 0 {
      true
    } else {
      match remaining[0] {
        Semicolon | EOF => true
        Ident("none") =>
          // `none` means empty template: no tracks, no line names.
          return ([], [])
        _ =>
          match parse_track_sizing_function(remaining) {
            Some((track, rest2)) => {
              result.push(track)
              remaining = rest2
              false
            }
            None => true
          }
      }
    }
    if stop {
      // `names` belongs to the final grid line.
      line_names.push(names)
      done = true
    } else {
      // `names` belongs to the line before the track we just pushed.
      line_names.push(names)
    }
  }
  (result, line_names)
}

///|
/// Parse grid-template-columns or grid-template-rows value (tracks only).
fn parse_grid_template_tracks(
  tokens : ArrayView[@token.Token],
) -> Array[@types.TrackSizingFunction] {
  parse_grid_template_track_list(tokens).0
}

///|
/// Parse the `<line-name-list>` that follows `subgrid`. Unlike a track list,
/// each `[...]` bracket group is a SEPARATE grid line, so names are not merged.
/// `repeat(...)` inside the list is not yet expanded and is skipped.
fn parse_subgrid_line_names(
  tokens : ArrayView[@token.Token],
) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  let mut remaining = skip_whitespace(tokens)
  while remaining.length() > 0 {
    match remaining[0] {
      LeftBracket => {
        let names : Array[String] = []
        let mut i = 1
        while i < remaining.length() {
          match remaining[i] {
            RightBracket => {
              i = i + 1
              break
            }
            Ident(s) => {
              names.push(s.to_lower())
              i = i + 1
            }
            _ => i = i + 1
          }
        }
        result.push(names)
        remaining = skip_whitespace(remaining[i:])
      }
      Semicolon | EOF => break
      // Skip anything else (e.g. an unsupported repeat()) without aborting.
      _ => remaining = skip_whitespace(remaining[1:])
    }
  }
  result
}

///|
/// Parse one grid template axis (grid-template-columns / -rows), detecting the
/// `subgrid` and `masonry` keywords. Returns the axis kind, the explicit track
/// sizing functions, and the line names.
fn parse_grid_template_axis(
  tokens : ArrayView[@token.Token],
) -> (
  @types.GridTemplateKind,
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
) {
  let toks = skip_whitespace(tokens)
  if toks.length() > 0 {
    match toks[0] {
      Ident("subgrid") =>
        return (Subgrid, [], parse_subgrid_line_names(toks[1:]))
      Ident("masonry") => return (Masonry, [], [])
      _ => ()
    }
  }
  let (tracks, names) = parse_grid_template_track_list(toks)
  (Explicit, tracks, names)
}

///|
/// Parse grid-template shorthand: `<rows> / <columns>`, preserving named lines.
fn parse_grid_template_shorthand(
  tokens : ArrayView[@token.Token],
) -> (
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
)? {
  let mut slash_index = -1
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Delim('/') => {
        slash_index = i
        break
      }
      _ => ()
    }
  }
  if slash_index < 0 {
    return None
  }
  let (rows, row_names) = parse_grid_template_track_list(tokens[:slash_index])
  let (cols, col_names) = parse_grid_template_track_list(
    tokens[slash_index + 1:],
  )
  Some((rows, row_names, cols, col_names))
}

///|
/// Parse the `grid-template` / `grid` "areas" form:
///   [ <line-names>? <string> <track-size>? <line-names>? ]+ [ / <track-list> ]?
/// Returns the areas (one string per row), the row track sizes and row line
/// names, and the column track sizes and column line names. Returns None when
/// the value is not the areas form (no <string> tokens present).
fn parse_grid_template_areas_form(
  tokens : ArrayView[@token.Token],
) -> (
  Array[String],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
)? {
  // Split off the optional `/ <columns>` part at the top-level slash.
  let mut slash_index = -1
  let mut has_string = false
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Delim('/') => if slash_index < 0 { slash_index = i }
      String(_) => has_string = true
      _ => ()
    }
  }
  if !has_string {
    return None
  }
  let left = if slash_index < 0 { tokens } else { tokens[:slash_index] }
  let areas : Array[String] = []
  let rows : Array[@types.TrackSizingFunction] = []
  let row_names : Array[Array[String]] = []
  let mut remaining = left
  let mut done = false
  while !done {
    let (names, rest) = capture_grid_line_names(remaining)
    remaining = rest
    if remaining.length() == 0 {
      row_names.push(names)
      done = true
    } else {
      match remaining[0] {
        String(s) => {
          row_names.push(names)
          areas.push(s)
          remaining = remaining[1:]
          // Optional row track size after the string.
          let after = skip_whitespace(remaining)
          match parse_track_sizing_function(after) {
            Some((track, rest2)) => {
              rows.push(track)
              remaining = rest2
            }
            None => rows.push(Auto)
          }
        }
        _ => {
          row_names.push(names)
          done = true
        }
      }
    }
  }
  let (cols, col_names) = if slash_index < 0 {
    ([], [])
  } else {
    parse_grid_template_track_list(tokens[slash_index + 1:])
  }
  Some((areas, rows, row_names, cols, col_names))
}

///|
/// Whether a side of the `grid` shorthand contains the `auto-flow` keyword.
fn grid_side_has_autoflow(tokens : ArrayView[@token.Token]) -> Bool {
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Ident("auto-flow") => return true
      _ => ()
    }
  }
  false
}

///|
/// Parse the `[ auto-flow && dense? ] <track-list>?` side of a `grid` shorthand.
/// Returns the resolved auto-flow direction and the implicit (auto) track list.
fn parse_grid_autoflow_side(
  tokens : ArrayView[@token.Token],
  is_column : Bool,
) -> (@types.GridAutoFlow, Array[@types.TrackSizingFunction]) {
  let mut dense = false
  let mut remaining = skip_whitespace(tokens)
  let mut consuming = true
  while consuming && remaining.length() > 0 {
    match remaining[0] {
      Ident("auto-flow") =>
        remaining = skip_whitespace(remaining[1:])
      Ident("dense") => {
        dense = true
        remaining = skip_whitespace(remaining[1:])
      }
      _ => consuming = false
    }
  }
  let flow = if is_column {
    if dense {
      @types.GridAutoFlow::ColumnDense
    } else {
      Column
    }
  } else if dense {
    RowDense
  } else {
    Row
  }
  let (tracks, _) = parse_grid_template_track_list(remaining)
  (flow, tracks)
}

///|
/// Parse the `grid` shorthand auto-flow form:
///   <grid-template-rows> / [ auto-flow && dense? ] <grid-auto-columns>?
///   [ auto-flow && dense? ] <grid-auto-rows>? / <grid-template-columns>
/// Returns (auto-flow, template-rows, row-names, template-cols, col-names,
/// auto-rows, auto-cols). Returns None when neither side has `auto-flow`.
fn parse_grid_autoflow_form(
  tokens : ArrayView[@token.Token],
) -> (
  @types.GridAutoFlow,
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[@types.TrackSizingFunction],
)? {
  let mut slash = -1
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Delim('/') => {
        slash = i
        break
      }
      _ => ()
    }
  }
  if slash < 0 {
    return None
  }
  let left = tokens[:slash]
  let right = tokens[slash + 1:]
  if grid_side_has_autoflow(right) {
    // rows are explicit (left); columns flow automatically (right).
    let (rows, row_names) = parse_grid_template_track_list(left)
    let (flow, auto_cols) = parse_grid_autoflow_side(right, true)
    Some((flow, rows, row_names, [], [], [], auto_cols))
  } else if grid_side_has_autoflow(left) {
    // rows flow automatically (left); columns are explicit (right).
    let (cols, col_names) = parse_grid_template_track_list(right)
    let (flow, auto_rows) = parse_grid_autoflow_side(left, false)
    Some((flow, [], [], cols, col_names, auto_rows, []))
  } else {
    None
  }
}

///|
/// Parse the `grid` shorthand auto-flow form from a raw string.
pub fn parse_grid_autoflow_form_from_string(
  value : String,
) -> (
  @types.GridAutoFlow,
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[@types.TrackSizingFunction],
)? {
  let tokens = @token.tokenize(value)
  parse_grid_autoflow_form(tokens[:])
}

///|
/// Classify one `<grid-line>` token slice into a GridPlacement. Handles
///   auto | <custom-ident> | <integer> && <custom-ident>? |
///   span && <integer>? && <custom-ident>?
/// (order-independent; CSS keywords are case-insensitive).
fn classify_grid_line(tokens : ArrayView[@token.Token]) -> @types.GridPlacement {
  let mut is_span = false
  let mut has_auto = false
  let mut line = 0
  let mut name : String? = None
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Ident(s) => {
        let ls = s.to_lower()
        if ls == "auto" {
          has_auto = true
        } else if ls == "span" {
          is_span = true
        } else {
          name = Some(ls)
        }
      }
      Number(v, _) => {
        let n = v.to_int()
        if n != 0 {
          line = n
        }
      }
      _ => ()
    }
  }
  if is_span {
    let count = if line != 0 { line } else { 1 }
    match name {
      Some(nm) => SpanNamed(count, nm)
      None => Span(count)
    }
  } else if has_auto {
    Auto
  } else {
    match name {
      Some(nm) =>
        if line != 0 {
          NamedLine(line, nm)
        } else {
          Named(nm)
        }
      None =>
        if line != 0 {
          Line(line)
        } else {
          Auto
        }
    }
  }
}

///|
/// Split a token view into segments separated by top-level `/` delimiters.
fn split_grid_segments(
  tokens : ArrayView[@token.Token],
) -> Array[ArrayView[@token.Token]] {
  let segments : Array[ArrayView[@token.Token]] = []
  let mut start = 0
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Delim('/') => {
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
/// Whether a token segment carries any meaningful (non-whitespace/EOF) token.
fn grid_segment_is_empty(tokens : ArrayView[@token.Token]) -> Bool {
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Whitespace | EOF => ()
      _ => return false
    }
  }
  true
}

///|
/// Parse a grid-column / grid-row value (`<start> [ / <end> ]?`) from tokens.
/// A single bare `<custom-ident>` is copied to both start and end (implicit
/// named area); any other single value leaves the end as auto.
fn parse_grid_line_shorthand_tokens(
  tokens : ArrayView[@token.Token],
) -> (@types.GridPlacement, @types.GridPlacement) {
  let segments = split_grid_segments(tokens)
  if segments.length() >= 2 {
    (classify_grid_line(segments[0]), classify_grid_line(segments[1]))
  } else {
    let start = classify_grid_line(tokens)
    match start {
      Named(_) => (start, start)
      _ => (start, Auto)
    }
  }
}

///|
/// Parse a grid-area value (`<row-start> [ / <col-start> [ / <row-end>
/// [ / <col-end> ]?]?]?`) from tokens, filling omitted longhands with auto
/// (a single value applies to both start longhands).
fn parse_grid_area_shorthand_tokens(
  tokens : ArrayView[@token.Token],
) -> (
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
) {
  let parts = split_grid_segments(tokens).filter(fn(s) {
    !grid_segment_is_empty(s)
  })
  let auto = @types.GridPlacement::Auto
  if parts.length() >= 4 {
    (
      classify_grid_line(parts[0]),
      classify_grid_line(parts[1]),
      classify_grid_line(parts[2]),
      classify_grid_line(parts[3]),
    )
  } else if parts.length() == 3 {
    (
      classify_grid_line(parts[0]),
      classify_grid_line(parts[1]),
      classify_grid_line(parts[2]),
      auto,
    )
  } else if parts.length() == 2 {
    (classify_grid_line(parts[0]), classify_grid_line(parts[1]), auto, auto)
  } else if parts.length() == 1 {
    let start = classify_grid_line(parts[0])
    (start, start, auto, auto)
  } else {
    (auto, auto, auto, auto)
  }
}

///|
/// If the value is a single `<custom-ident>` (no slash, not a number / `auto` /
/// `span` / global keyword), return that lowercased ident as a grid-area name.
/// Otherwise return None (the value is a line-based placement).
fn grid_area_single_name(tokens : ArrayView[@token.Token]) -> String? {
  let mut found : String? = None
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Whitespace | EOF => ()
      Ident(s) => {
        let ls = s.to_lower()
        if ls == "auto" ||
          ls == "span" ||
          ls == "none" ||
          ls == "inherit" ||
          ls == "initial" ||
          ls == "unset" {
          return None
        }
        // More than one meaningful token => not a bare ident.
        match found {
          Some(_) => return None
          None => found = Some(ls)
        }
      }
      // Any number, slash, or other token means this is not a bare ident.
      _ => return None
    }
  }
  found
}

///|
/// Parse a single `<grid-line>` from a raw string.
pub fn parse_grid_placement_from_string(value : String) -> @types.GridPlacement {
  classify_grid_line(@token.tokenize(value)[:])
}

///|
/// Parse a grid-column / grid-row shorthand from a raw string.
pub fn parse_grid_line_shorthand_from_string(
  value : String,
) -> (@types.GridPlacement, @types.GridPlacement) {
  parse_grid_line_shorthand_tokens(@token.tokenize(value)[:])
}

///|
/// Parse a grid-area shorthand from a raw string.
pub fn parse_grid_area_shorthand_from_string(
  value : String,
) -> (
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
) {
  parse_grid_area_shorthand_tokens(@token.tokenize(value)[:])
}

///|
/// Parse grid-template-columns or grid-template-rows from a raw string
pub fn parse_grid_template_tracks_from_string(
  value : String,
) -> Array[@types.TrackSizingFunction] {
  let tokens = @token.tokenize(value)
  parse_grid_template_tracks(tokens[:])
}

///|
/// Parse grid-template-columns or grid-template-rows from a raw string,
/// returning both the track sizing functions and the named lines (index = grid
/// line, length = tracks + 1).
pub fn parse_grid_template_track_list_from_string(
  value : String,
) -> (Array[@types.TrackSizingFunction], Array[Array[String]]) {
  let tokens = @token.tokenize(value)
  parse_grid_template_track_list(tokens[:])
}

///|
/// Parse the `grid-template` / `grid` areas form from a raw string.
/// Returns (areas, rows, row_line_names, cols, col_line_names) or None when the
/// value is not the areas form.
pub fn parse_grid_template_areas_form_from_string(
  value : String,
) -> (
  Array[String],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
)? {
  let tokens = @token.tokenize(value)
  parse_grid_template_areas_form(tokens[:])
}

///|
/// Parse one grid template axis from a raw string, detecting subgrid/masonry.
/// Returns the axis kind, the explicit tracks, and the line names.
pub fn parse_grid_template_axis_from_string(
  value : String,
) -> (
  @types.GridTemplateKind,
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
) {
  let tokens = @token.tokenize(value)
  parse_grid_template_axis(tokens[:])
}

///|
