///|
/// Parse grid-auto-flow value
pub fn parse_grid_auto_flow(value : String) -> @types.GridAutoFlow {
  match value.trim().to_lower() {
    "row" => @types.GridAutoFlow::Row
    "column" => @types.GridAutoFlow::Column
    "row dense" | "dense row" => @types.GridAutoFlow::RowDense
    "column dense" | "dense column" => @types.GridAutoFlow::ColumnDense
    _ => @types.GridAutoFlow::Row
  }
}

///|
/// Parse a grid placement value (for grid-column-start, grid-row-end, etc.).
/// Supports the full `<grid-line>` grammar:
///   auto
///   <custom-ident>                       -> Named
///   <integer> && <custom-ident>?         -> Line / NamedLine (order-independent)
///   span && <integer>? && <custom-ident>? -> Span / SpanNamed
pub fn parse_grid_placement(value : String) -> @types.GridPlacement {
  @parser.parse_grid_placement_from_string(value)
}

///|
/// Parse grid-column or grid-row shorthand
/// Formats: <start>, <start> / <end>, <start> / span <n>
pub fn parse_grid_line_shorthand(
  value : String,
) -> (@types.GridPlacement, @types.GridPlacement) {
  @parser.parse_grid_line_shorthand_from_string(value)
}

///|
/// Find the 1-based grid line number where `name` is first declared in the
/// given line-name table (table index 0 = grid line 1). Returns None if the
/// name is not present.
pub fn find_grid_named_line(
  name : String,
  line_names : Array[Array[String]],
) -> Int? {
  for i = 0; i < line_names.length(); i = i + 1 {
    let group = line_names[i]
    for j = 0; j < group.length(); j = j + 1 {
      if group[j] == name {
        return Some(i + 1)
      }
    }
  }
  None
}

///|
/// Find the 1-based grid line number of the `n`-th line named `name`. Positive
/// `n` counts occurrences from the start (n=1 is the first); negative `n` counts
/// from the end (n=-1 is the last). Returns None if there is no such line.
pub fn find_grid_named_line_nth(
  name : String,
  n : Int,
  line_names : Array[Array[String]],
) -> Int? {
  // Collect the 1-based line numbers carrying `name`, in document order.
  let hits : Array[Int] = []
  for i = 0; i < line_names.length(); i = i + 1 {
    let group = line_names[i]
    for j = 0; j < group.length(); j = j + 1 {
      if group[j] == name {
        hits.push(i + 1)
        break
      }
    }
  }
  if n == 0 || hits.length() == 0 {
    return None
  }
  let idx = if n > 0 { n - 1 } else { hits.length() + n }
  if idx < 0 || idx >= hits.length() {
    None
  } else {
    Some(hits[idx])
  }
}

///|
/// Resolve one side of a named grid placement to a concrete 1-based line number.
/// Falls back to the implicit named area edge (`<name>-start` / `<name>-end`)
/// when no explicit line carries the bare name. `is_start` selects the edge.
fn resolve_named_grid_side(
  name : String,
  is_start : Bool,
  line_names : Array[Array[String]],
) -> Int? {
  // 1. An explicit line declared with this exact name wins.
  match find_grid_named_line(name, line_names) {
    Some(n) => return Some(n)
    None => ()
  }
  // 2. Implicit named area: `<name>-start` / `<name>-end`.
  let edge = if is_start { name + "-start" } else { name + "-end" }
  find_grid_named_line(edge, line_names)
}

///|
/// Resolve a grid item's start/end placement against a grid template's named
/// lines (as captured in `grid_template_column_line_names` /
/// `grid_template_row_line_names`). Returns concrete 1-based line numbers where
/// resolvable. `Line(n)` passes through; `Named` resolves against the table
/// (with implicit-area expansion); `Auto` / `Span` and unresolved names yield
/// None, leaving auto/span placement to the layout engine.
pub fn resolve_grid_line_placement(
  start : @types.GridPlacement,
  end : @types.GridPlacement,
  line_names : Array[Array[String]],
) -> (Int?, Int?) {
  let start_line = match start {
    @types.GridPlacement::Line(n) => Some(n)
    @types.GridPlacement::Named(name) =>
      resolve_named_grid_side(name, true, line_names)
    @types.GridPlacement::NamedLine(n, name) =>
      find_grid_named_line_nth(name, n, line_names)
    // Auto / Span / SpanNamed are relative and resolved by the layout engine.
    _ => None
  }
  let end_line = match end {
    @types.GridPlacement::Line(n) => Some(n)
    @types.GridPlacement::Named(name) =>
      resolve_named_grid_side(name, false, line_names)
    @types.GridPlacement::NamedLine(n, name) =>
      find_grid_named_line_nth(name, n, line_names)
    _ => None
  }
  (start_line, end_line)
}

///|
/// Parse grid-area shorthand:
/// <row-start> / <column-start> / <row-end> / <column-end>
pub fn parse_grid_area_shorthand(
  value : String,
) -> (
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
) {
  @parser.parse_grid_area_shorthand_from_string(value)
}

///|
fn is_basic_custom_ident(value : StringView) -> Bool {
  if value.length() == 0 {
    return false
  }
  let first = value[0]
  let first_ok = (first >= 'a' && first <= 'z') ||
    (first >= 'A' && first <= 'Z') ||
    first == '_' ||
    first == '-'
  if !first_ok {
    return false
  }
  for i = 1; i < value.length(); i = i + 1 {
    let c = value[i]
    let ok = (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c == '-'
    if !ok {
      return false
    }
  }
  true
}

///|
/// Parse a number value
pub fn parse_number(value : String) -> Double {
  @string.parse_double(value.trim().to_owned()) catch {
    _ => 0.0
  }
}

///|
/// Parse an integer value
pub fn parse_integer(value : String) -> Int {
  @string.parse_int(value.trim().to_owned()) catch {
    _ => 0
  }
}

///|
/// Parse grid-template-columns or grid-template-rows value
/// Delegate to the full parser to support minmax() and repeat().
pub fn parse_grid_template_tracks(
  value : String,
) -> Array[@types.TrackSizingFunction] {
  @parser.parse_grid_template_tracks_from_string(value)
}

///|
/// Parse grid-template-columns or grid-template-rows value, returning both the
/// track sizing functions and the named lines (index = grid line, length =
/// tracks + 1).
pub fn parse_grid_template_track_list(
  value : String,
) -> (Array[@types.TrackSizingFunction], Array[Array[String]]) {
  @parser.parse_grid_template_track_list_from_string(value)
}

///|
/// Parse the `grid-template` / `grid` areas form. Returns
/// (areas, rows, row_line_names, cols, col_line_names) or None.
pub fn parse_grid_template_areas_form(
  value : String,
) -> (
  Array[String],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
)? {
  @parser.parse_grid_template_areas_form_from_string(value)
}

///|
/// Parse the `grid` shorthand auto-flow form. Returns (auto-flow,
/// template-rows, row-names, template-cols, col-names, auto-rows, auto-cols) or
/// None when neither side has `auto-flow`.
pub fn parse_grid_autoflow_form(
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
  @parser.parse_grid_autoflow_form_from_string(value)
}

///|
/// Parse one grid template axis, detecting subgrid/masonry. Returns the axis
/// kind, the explicit track sizing functions, and the line names.
pub fn parse_grid_template_axis(
  value : String,
) -> (
  @types.GridTemplateKind,
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
) {
  @parser.parse_grid_template_axis_from_string(value)
}

///|
/// Parse grid-template shorthand: `<rows> / <columns>`
pub fn parse_grid_template_shorthand(
  value : String,
) -> (Array[@types.TrackSizingFunction], Array[@types.TrackSizingFunction])? {
  let v = value.trim()
  if !v.contains("/") {
    return None
  }
  let parts = v.split("/").map(fn(s) { s.trim().to_owned() }).collect()
  if parts.length() != 2 {
    return None
  }
  let rows = parse_grid_template_tracks(parts[0])
  let cols = parse_grid_template_tracks(parts[1])
  Some((rows, cols))
}

///|
/// Parse grid-template shorthand `<rows> / <columns>`, preserving named lines.
/// Returns (rows, row_line_names, cols, col_line_names).
pub fn parse_grid_template_shorthand_with_names(
  value : String,
) -> (
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
  Array[@types.TrackSizingFunction],
  Array[Array[String]],
)? {
  let v = value.trim()
  if !v.contains("/") {
    return None
  }
  let parts = v.split("/").map(fn(s) { s.trim().to_owned() }).collect()
  if parts.length() != 2 {
    return None
  }
  let (rows, row_names) = parse_grid_template_track_list(parts[0])
  let (cols, col_names) = parse_grid_template_track_list(parts[1])
  Some((rows, row_names, cols, col_names))
}

///|
/// Parse grid-template-areas CSS property value.
/// The value is a series of quoted strings like: "header header" "sidebar main" "footer footer"
pub fn parse_grid_template_areas_value(value : String) -> Array[String] {
  let result : Array[String] = []
  let v = value.trim()
  // Parse quoted strings - each quoted string is one row
  let mut i = 0
  while i < v.length() {
    let c = v[i].unsafe_to_char()
    if c == '"' || c == '\'' {
      let quote = c
      let mut end = i + 1
      while end < v.length() && v[end].unsafe_to_char() != quote {
        end = end + 1
      }
      if end > i + 1 {
        let row_str = view_to_string(v.view(start_offset=i + 1, end_offset=end))
        result.push(row_str.to_string())
      }
      i = end + 1
    } else {
      i = i + 1
    }
  }
  result
}

///|
/// Check if a value is a named grid area identifier (not a number, auto, or span keyword)
pub fn is_grid_area_name(value : String) -> Bool {
  let v = value.trim().to_lower()
  if v == "auto" ||
    v == "none" ||
    v == "inherit" ||
    v == "initial" ||
    v == "unset" {
    return false
  }
  if v.has_prefix("span") {
    return false
  }
  // Check if it's a number
  let parsed = @string.parse_int(v.to_owned()) catch { _ => 0 }
  if parsed != 0 {
    return false
  }
  // Must be a valid custom ident
  is_basic_custom_ident(v)
}

///|
/// Parse aspect-ratio value
pub fn parse_aspect_ratio(value : String) -> Double? {
  let v = value.trim()
  if v == "auto" {
    return None
  }
  // Check for ratio format: "16 / 9" or "16/9"
  if v.contains("/") {
    // Find the slash position
    let mut slash_pos = -1
    for i = 0; i < v.length(); i = i + 1 {
      if v[i].to_int().unsafe_to_char() == '/' {
        slash_pos = i
        break
      }
    }
    if slash_pos > 0 {
      // Use view slicing
      let width_str = view_to_string(v.view(end_offset=slash_pos)).trim()
      let height_str = view_to_string(v.view(start_offset=slash_pos + 1)).trim()
      let w = @string.parse_double(width_str.to_owned()) catch {
        _ => return None
      }
      let h = @string.parse_double(height_str.to_owned()) catch {
        _ => return None
      }
      if h != 0.0 {
        return Some(w / h)
      }
      return None
    }
  }
  // Try parsing as a single number
  let n = @string.parse_double(v.to_owned()) catch { _ => return None }
  Some(n)
}

///|
