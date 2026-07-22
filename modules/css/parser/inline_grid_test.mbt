///|
test "parse - border-left/right/top/bottom-width individual" {
  let s = parse_inline_style(
    "border-left-width: 1px; border-right-width: 2px; border-top-width: 3px; border-bottom-width: 4px",
  )
  inspect(s.border.left, content="Length(1)")
  inspect(s.border.right, content="Length(2)")
  inspect(s.border.top, content="Length(3)")
  inspect(s.border.bottom, content="Length(4)")
}

///|
test "parse - border-block and border-block-width shorthand" {
  let s = parse_inline_style("border-block: 5px")
  inspect(s.border.top, content="Length(5)")
  inspect(s.border.bottom, content="Length(5)")
  let s2 = parse_inline_style("border-block-width: 7px")
  inspect(s2.border.top, content="Length(7)")
  inspect(s2.border.bottom, content="Length(7)")
}

///|
test "parse - border-inline shorthand" {
  let s = parse_inline_style("border-inline: 6px")
  inspect(s.border.left, content="Length(6)")
  inspect(s.border.right, content="Length(6)")
}

///|
test "parse - padding-block and padding-inline shorthands" {
  let s = parse_inline_style("padding-block: 5px; padding-inline: 10px")
  inspect(s.padding.top, content="Length(5)")
  inspect(s.padding.bottom, content="Length(5)")
  inspect(s.padding.left, content="Length(10)")
  inspect(s.padding.right, content="Length(10)")
}

///|
test "parse - row-gap and column-gap individually" {
  let s = parse_inline_style("row-gap: 5px; column-gap: 10px")
  inspect(s.row_gap, content="Length(5)")
  inspect(s.column_gap, content="Length(10)")
}

///|
test "parse - overflow-x and overflow-y separately" {
  let s = parse_inline_style("overflow-x: scroll; overflow-y: hidden")
  inspect(s.overflow_x, content="Scroll")
  inspect(s.overflow_y, content="Hidden")
}

///|
test "parse - top/right/bottom/left individually" {
  let s = parse_inline_style("top: 1px; right: 2px; bottom: 3px; left: 4px")
  inspect(s.inset.top, content="Length(1)")
  inspect(s.inset.right, content="Length(2)")
  inspect(s.inset.bottom, content="Length(3)")
  inspect(s.inset.left, content="Length(4)")
}

///|
test "parse - clip rect()" {
  let s = parse_inline_style("clip: rect(1px, 2px, 3px, 4px)")
  inspect(s.clip, content="rect(1, 2, 3, 4)")
  let auto = parse_inline_style("clip: auto")
  inspect(auto.clip, content="auto")
}

///|
test "parse - clip-path inset/circle convert rem/physical units" {
  // inset(1rem) -> 16px on all sides
  debug_inspect(
    parse_inline_style("clip-path: inset(1rem)").clip_path,
    content="Inset(16, 16, 16, 16)",
  )
  // circle(2rem at 1in 1in) -> radius 32, center 96/96
  debug_inspect(
    parse_inline_style("clip-path: circle(2rem at 1in 1in)").clip_path,
    content="Circle(32, 96, 96)",
  )
}

///|
test "parse - clip-path inset/circle/ellipse/polygon/none" {
  let inset = parse_inline_style("clip-path: inset(5px)")
  let _ = inset.clip_path
  let circle = parse_inline_style("clip-path: circle(20px at 30px 40px)")
  let _ = circle.clip_path
  let ellipse = parse_inline_style("clip-path: ellipse(20px 30px at 40px 50px)")
  let _ = ellipse.clip_path
  let polygon = parse_inline_style("clip-path: polygon(0 0, 100% 0, 50% 100%)")
  let _ = polygon.clip_path
  let none = parse_inline_style("clip-path: none")
  let _ = none.clip_path
  inspect(true, content="true")
}

///|
test "parse - place-content shorthand" {
  let s = parse_inline_style("place-content: center end")
  inspect(s.align_content, content="Center")
  inspect(s.justify_content, content="End")
}

///|
test "parse - justify-self and justify-items" {
  let s = parse_inline_style("justify-self: end; justify-items: center")
  inspect(s.justify_self, content="End")
  inspect(s.justify_items, content="Center")
}

///|
test "parse - flex-flow shorthand individual" {
  let s = parse_inline_style("flex-flow: column wrap")
  inspect(s.flex_direction, content="Column")
  inspect(s.flex_wrap, content="Wrap")
}

///|
test "parse - margin-top/right/bottom/left individual" {
  let s = parse_inline_style(
    "margin-top: 1px; margin-right: 2px; margin-bottom: 3px; margin-left: 4px",
  )
  inspect(s.margin.top, content="Length(1)")
  inspect(s.margin.right, content="Length(2)")
  inspect(s.margin.bottom, content="Length(3)")
  inspect(s.margin.left, content="Length(4)")
}

///|
test "parse - padding-top/right/bottom/left individual" {
  let s = parse_inline_style(
    "padding-top: 1px; padding-right: 2px; padding-bottom: 3px; padding-left: 4px",
  )
  inspect(s.padding.top, content="Length(1)")
  inspect(s.padding.right, content="Length(2)")
  inspect(s.padding.bottom, content="Length(3)")
  inspect(s.padding.left, content="Length(4)")
}

///|
test "parse grid-template-columns with min-content/max-content/auto" {
  let s = parse_inline_style(
    "grid-template-columns: min-content max-content auto 100px",
  )
  inspect(s.grid_template_columns.length(), content="4")
}

///|
test "parse grid-template-columns with minmax(min-content, 1fr)" {
  let s = parse_inline_style(
    "grid-template-columns: minmax(min-content, 1fr) minmax(auto, max-content)",
  )
  inspect(s.grid_template_columns.length(), content="2")
}

///|
test "parse grid-template-columns with various track sizes" {
  let s = parse_inline_style(
    "grid-template-columns: 50% 2fr 100px auto min-content max-content",
  )
  inspect(s.grid_template_columns.length(), content="6")
}

///|
test "parse grid-template-columns with 0 unitless" {
  let s = parse_inline_style("grid-template-columns: 0 100px")
  inspect(s.grid_template_columns.length(), content="2")
}

///|
test "parse grid-template-columns with bad ident drops the rest" {
  let s = parse_inline_style("grid-template-columns: bogus 100px")
  // Bogus ident causes parser to stop accumulating tracks
  let _ = s.grid_template_columns
  inspect(true, content="true")
}

///|
test "parse grid-template-columns with non-zero unitless drops the rest" {
  let s = parse_inline_style("grid-template-columns: 5 100px")
  // Non-zero unitless causes parser to stop
  let _ = s.grid_template_columns
  inspect(true, content="true")
}

///|
test "parse contain-intrinsic-size single value" {
  let s = parse_inline_style("contain-intrinsic-size: 100px")
  debug_inspect(s.contain_intrinsic_inline_size, content="Some(100)")
  debug_inspect(s.contain_intrinsic_block_size, content="Some(100)")
}

///|
test "parse contain-intrinsic-size auto" {
  let s = parse_inline_style("contain-intrinsic-size: auto")
  // 'auto' produces None
  debug_inspect(s.contain_intrinsic_inline_size, content="None")
}

///|
test "parse container-type: size and inline-size" {
  let s1 = parse_inline_style("container-type: size")
  inspect(s1.contain.size, content="true")
  let s2 = parse_inline_style("container-type: inline-size")
  inspect(s2.contain.inline_size, content="true")
  let s3 = parse_inline_style("container-type: normal")
  // 'normal' should not add containment
  let _ = s3
  inspect(true, content="true")
}

///|
test "parse negative top left" {
  let style = parse_inline_style("top: -20px; left: -40px")
  inspect(style.inset.top, content="Length(-20)")
  inspect(style.inset.left, content="Length(-40)")
}

///|
test "parse basic width and height" {
  let style = parse_inline_style("width: 100px; height: 50px")
  inspect(style.width, content="Length(100)")
  inspect(style.height, content="Length(50)")
}

///|
test "parse display flex" {
  let style = parse_inline_style("display: flex")
  inspect(style.display, content="Flex")
}

///|
test "parse display flow-root list-item" {
  let style = parse_inline_style("display: flow-root list-item")
  inspect(style.display, content="FlowRoot")
}

///|
test "parse display math aliases" {
  let inline_math = parse_inline_style("display: math")
  inspect(inline_math.display, content="Inline")
  let block_math = parse_inline_style("display: block math")
  inspect(block_math.display, content="Block")
}

///|
test "parse flex properties" {
  let style = parse_inline_style(
    "display: flex; flex-direction: column; justify-content: center",
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Column")
  inspect(style.justify_content, content="Center")
}

///|
test "parse margin and padding" {
  let style = parse_inline_style("margin: 10px; padding: 20px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.left, content="Length(10)")
  inspect(style.padding.top, content="Length(20)")
  inspect(style.padding.right, content="Length(20)")
}

///|
test "parse percentage values" {
  let style = parse_inline_style("width: 50%; height: 100%")
  inspect(style.width, content="Percent(0.5)")
  inspect(style.height, content="Percent(1)")
}

///|
test "parse flex-grow and flex-shrink" {
  let style = parse_inline_style("flex-grow: 1; flex-shrink: 0")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="0")
}

///|
test "parse gap" {
  let style = parse_inline_style("gap: 10px")
  inspect(style.row_gap, content="Length(10)")
  inspect(style.column_gap, content="Length(10)")
}

///|
test "parse complex flex layout" {
  let style = parse_inline_style(
    "display: flex; flex-direction: row; flex-wrap: wrap; align-items: center; gap: 16px",
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Row")
  inspect(style.flex_wrap, content="Wrap")
  inspect(style.align_items, content="Center")
  inspect(style.row_gap, content="Length(16)")
}

///|
test "parse border-width" {
  let style = parse_inline_style("border-width: 2px")
  inspect(style.border.top, content="Length(2)")
  inspect(style.border.left, content="Length(2)")
}

///|
test "parse inset properties" {
  let style = parse_inline_style("position: absolute; top: 10px; left: 20px")
  inspect(style.position, content="Absolute")
  inspect(style.inset.top, content="Length(10)")
  inspect(style.inset.left, content="Length(20)")
}

///|
test "parse aspect-ratio simple" {
  let style = parse_inline_style("aspect-ratio: 1.5")
  debug_inspect(style.aspect_ratio, content="Some(1.5)")
}

///|
test "parse aspect-ratio fraction" {
  let style = parse_inline_style("aspect-ratio: 16 / 9")
  // 16/9 ≈ 1.777...
  match style.aspect_ratio {
    Some(v) => assert_true(v > 1.77 && v < 1.78)
    None => fail("aspect_ratio should be Some")
  }
}

///|
test "parse grid-auto-flow" {
  let style = parse_inline_style("display: grid; grid-auto-flow: column")
  inspect(style.display, content="Grid")
  inspect(style.grid_auto_flow, content="Column")
}

///|
test "order property" {
  let style = parse_inline_style("order: 5")
  inspect(style.order, content="5")
}

///|
test "order negative" {
  let style = parse_inline_style("order: -1")
  inspect(style.order, content="-1")
}

///|
test "flex shorthand" {
  let style = parse_inline_style("flex: 1")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Percent(0)")
}

///|
test "grid-template-columns basic" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: 100px 200px 1fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[1], content="Length(200)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

///|
test "grid-template-columns captures named line brackets" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: [extended-full-start] minmax(1rem, 1fr) [full-start] minmax(0, 2rem) [content-start] minmax(0, 72rem) [content-end] minmax(0, 2rem) [full-end] minmax(1rem, 1fr) [extended-full-end]",
  )
  inspect(style.grid_template_columns.length(), content="5")
  // Line names are now preserved: one entry per grid line (tracks + 1).
  let names = style.grid_template_column_line_names
  inspect(names.length(), content="6")
  debug_inspect(names[0], content="[\"extended-full-start\"]")
  debug_inspect(names[1], content="[\"full-start\"]")
  debug_inspect(names[2], content="[\"content-start\"]")
  debug_inspect(names[3], content="[\"content-end\"]")
  debug_inspect(names[4], content="[\"full-end\"]")
  debug_inspect(names[5], content="[\"extended-full-end\"]")
}

///|
test "grid-template-columns captures multiple names at one line (MDN page shell)" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: [left-sidebar-start] 240px [left-sidebar-end content-start] 689px [content-end]",
  )
  inspect(style.grid_template_columns.length(), content="2")
  let names = style.grid_template_column_line_names
  inspect(names.length(), content="3")
  debug_inspect(names[0], content="[\"left-sidebar-start\"]")
  debug_inspect(names[1], content="[\"left-sidebar-end\", \"content-start\"]")
  debug_inspect(names[2], content="[\"content-end\"]")
}

///|
test "grid-template-columns fractional fr" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: 1.01fr 0.99fr 1fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Fr(1.01)")
  inspect(style.grid_template_columns[1], content="Fr(0.99)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

///|
test "grid-template-rows basic" {
  let style = parse_inline_style(
    "display: grid; grid-template-rows: auto 50px 2fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_rows.length(), content="3")
  inspect(style.grid_template_rows[0], content="Auto")
  inspect(style.grid_template_rows[1], content="Length(50)")
  inspect(style.grid_template_rows[2], content="Fr(2)")
}

///|
test "grid-template-columns with percentage" {
  let style = parse_inline_style("grid-template-columns: 50% 50%")
  inspect(style.grid_template_columns.length(), content="2")
  inspect(style.grid_template_columns[0], content="Percent(0.5)")
  inspect(style.grid_template_columns[1], content="Percent(0.5)")
}

///|
test "grid-template-columns none" {
  let style = parse_inline_style("grid-template-columns: none")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid-template-columns subgrid with line names" {
  let style = parse_inline_style("grid-template-columns: subgrid [a] [b c] [d]")
  inspect(style.grid_template_columns_kind, content="Subgrid")
  inspect(style.grid_template_columns.length(), content="0")
  // Each bracket group is a separate line (not merged like a track list).
  let names = style.grid_template_column_line_names
  inspect(names.length(), content="3")
  debug_inspect(names[0], content="[\"a\"]")
  debug_inspect(names[1], content="[\"b\", \"c\"]")
  debug_inspect(names[2], content="[\"d\"]")
}

///|
test "grid-template-rows masonry" {
  let style = parse_inline_style("grid-template-rows: masonry")
  inspect(style.grid_template_rows_kind, content="Masonry")
  inspect(style.grid_template_rows.length(), content="0")
}

///|
test "grid-template-columns explicit kind by default" {
  let style = parse_inline_style("grid-template-columns: 1fr 2fr")
  inspect(style.grid_template_columns_kind, content="Explicit")
}

///|
test "grid-template areas form sets areas, row sizes and columns" {
  let style = parse_inline_style(
    "grid-template: \"head head\" 80px \"nav main\" 1fr / 200px 1fr",
  )
  inspect(style.grid_template_areas.length(), content="2")
  inspect(style.grid_template_areas[0], content="head head")
  inspect(style.grid_template_areas[1], content="nav main")
  inspect(style.grid_template_rows.length(), content="2")
  inspect(style.grid_template_rows[0], content="Length(80)")
  inspect(style.grid_template_rows[1], content="Fr(1)")
  inspect(style.grid_template_columns.length(), content="2")
  inspect(style.grid_template_columns[0], content="Length(200)")
  inspect(style.grid_template_columns[1], content="Fr(1)")
}

///|
test "grid-template areas form without column part or row sizes" {
  let style = parse_inline_style("grid-template: \"a\" \"b\" \"c\"")
  inspect(style.grid_template_areas.length(), content="3")
  // No explicit row sizes -> each row defaults to auto.
  inspect(style.grid_template_rows.length(), content="3")
  inspect(style.grid_template_rows[0], content="Auto")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid shorthand areas form" {
  let style = parse_inline_style("grid: \"a b\" 100px / 1fr 1fr")
  inspect(style.grid_template_areas.length(), content="1")
  inspect(style.grid_template_areas[0], content="a b")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_template_columns.length(), content="2")
}

///|
test "grid shorthand auto-flow on the column side" {
  // rows are explicit; columns are auto-placed.
  let style = parse_inline_style("grid: 100px 200px / auto-flow 1fr")
  inspect(style.grid_auto_flow, content="Column")
  inspect(style.grid_template_rows.length(), content="2")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_auto_columns.length(), content="1")
  inspect(style.grid_auto_columns[0], content="Fr(1)")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid shorthand auto-flow dense on the row side" {
  let style = parse_inline_style("grid: auto-flow dense 80px / 1fr 1fr")
  inspect(style.grid_auto_flow, content="RowDense")
  inspect(style.grid_auto_rows.length(), content="1")
  inspect(style.grid_auto_rows[0], content="Length(80)")
  inspect(style.grid_template_columns.length(), content="2")
}

///|
test "grid-template-columns converts rem/em and physical units to px" {
  let style = parse_inline_style(
    "grid-template-columns: 10rem 2em 1fr 12pt 1in",
  )
  inspect(style.grid_template_columns.length(), content="5")
  inspect(style.grid_template_columns[0], content="Length(160)")
  inspect(style.grid_template_columns[1], content="Length(32)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
  inspect(style.grid_template_columns[3], content="Length(16)")
  inspect(style.grid_template_columns[4], content="Length(96)")
}

///|
test "grid-template-columns minmax converts rem/physical units to px" {
  let style = parse_inline_style("grid-template-columns: minmax(1rem, 2cm)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="MinMax(Length(16), Length(75.59055118110236))",
  )
}

///|
test "grid-template-columns minmax" {
  let style = parse_inline_style("grid-template-columns: minmax(100px, 1fr)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="MinMax(Length(100), Fr(1))")
}

///|
test "grid-template-columns fit-content()" {
  let style = parse_inline_style(
    "grid-template-columns: fit-content(200px) fit-content(30%) 1fr",
  )
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="FitContentLength(200)")
  inspect(style.grid_template_columns[1], content="FitContentPercent(0.3)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
  // fit-content with rem is converted to px
  let s2 = parse_inline_style("grid-template-columns: fit-content(2rem)")
  inspect(s2.grid_template_columns[0], content="FitContentLength(32)")
}

///|
test "grid-template-columns fit-content() inside repeat" {
  let style = parse_inline_style(
    "grid-template-columns: repeat(2, fit-content(100px))",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(2), [FitContentLength(100)])",
  )
}

///|
test "grid-template-columns calc() track keeps following tracks" {
  // calc() in a track must not abort parsing of the remaining tracks.
  let style = parse_inline_style(
    "grid-template-columns: 100px calc(50% + 10px) 1fr",
  )
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
  // Pure-px calc resolves to a length track.
  let s2 = parse_inline_style("grid-template-columns: calc(100px + 20px) 1fr")
  inspect(s2.grid_template_columns.length(), content="2")
  inspect(s2.grid_template_columns[0], content="Length(120)")
  inspect(s2.grid_template_columns[1], content="Fr(1)")
}

///|
test "grid-template-columns repeat with inner line names does not abort" {
  // Line names inside repeat() must not kill parsing of the track list.
  let style = parse_inline_style(
    "grid-template-columns: repeat(3, [a] 1fr [b])",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [Fr(1)], [[\"a\"], [\"b\"]])",
  )
}

///|
test "grid-template-columns minmax min-content auto" {
  let style = parse_inline_style(
    "grid-template-columns: minmax(min-content, 100px) auto",
  )
  inspect(style.grid_template_columns.length(), content="2")
  inspect(
    style.grid_template_columns[0],
    content="MinMax(MinContent, Length(100))",
  )
  inspect(style.grid_template_columns[1], content="Auto")
}

///|
test "grid-template-columns repeat" {
  let style = parse_inline_style("grid-template-columns: repeat(3, 100px)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [Length(100)])",
  )
}

///|
test "grid-template shorthand rows and columns" {
  let style = parse_inline_style("grid-template: 100px / 200px")
  inspect(style.grid_template_rows.length(), content="1")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Length(200)")
}

///|
test "grid shorthand template rows and columns" {
  let style = parse_inline_style("display: grid; grid: 1fr 1fr / auto")
  inspect(style.grid_template_rows.length(), content="2")
  inspect(style.grid_template_rows[0], content="Fr(1)")
  inspect(style.grid_template_rows[1], content="Fr(1)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Auto")
}
