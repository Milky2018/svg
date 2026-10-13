///|
test "Show for Display" {
  inspect(@values.Display::Block, content="Block")
  inspect(@values.Display::Inline, content="Inline")
  inspect(@values.Display::InlineBlock, content="InlineBlock")
  inspect(@values.Display::Flex, content="Flex")
  inspect(@values.Display::InlineFlex, content="InlineFlex")
  inspect(@values.Display::Grid, content="Grid")
  inspect(@values.Display::InlineGrid, content="InlineGrid")
  inspect(@values.Display::Table, content="Table")
  inspect(@values.Display::InlineTable, content="InlineTable")
  inspect(@values.Display::TableRow, content="TableRow")
  inspect(@values.Display::TableCell, content="TableCell")
  inspect(@values.Display::TableCaption, content="TableCaption")
  inspect(@values.Display::TableRowGroup, content="TableRowGroup")
  inspect(@values.Display::TableHeaderGroup, content="TableHeaderGroup")
  inspect(@values.Display::TableFooterGroup, content="TableFooterGroup")
  inspect(@values.Display::TableColumn, content="TableColumn")
  inspect(@values.Display::TableColumnGroup, content="TableColumnGroup")
  inspect(@values.Display::None, content="None")
  inspect(@values.Display::Contents, content="Contents")
  inspect(@values.Display::FlowRoot, content="FlowRoot")
}

///|
test "Show for Position" {
  inspect(@values.Position::Static, content="Static")
  inspect(@values.Position::Relative, content="Relative")
  inspect(@values.Position::Absolute, content="Absolute")
  inspect(@values.Position::Fixed, content="Fixed")
}

///|
test "Show for FlexDirection" {
  inspect(@values.FlexDirection::Row, content="Row")
  inspect(@values.FlexDirection::RowReverse, content="RowReverse")
  inspect(@values.FlexDirection::Column, content="Column")
  inspect(@values.FlexDirection::ColumnReverse, content="ColumnReverse")
}

///|
test "Show for Alignment" {
  inspect(@values.Alignment::Start, content="Start")
  inspect(@values.Alignment::End, content="End")
  inspect(@values.Alignment::Left, content="Left")
  inspect(@values.Alignment::Right, content="Right")
  inspect(@values.Alignment::FlexStart, content="FlexStart")
  inspect(@values.Alignment::FlexEnd, content="FlexEnd")
  inspect(@values.Alignment::Center, content="Center")
  inspect(@values.Alignment::SpaceBetween, content="SpaceBetween")
  inspect(@values.Alignment::SpaceAround, content="SpaceAround")
  inspect(@values.Alignment::SpaceEvenly, content="SpaceEvenly")
  inspect(@values.Alignment::Stretch, content="Stretch")
  inspect(@values.Alignment::Baseline, content="Baseline")
}

///|
test "Show for FlexWrap" {
  inspect(@values.FlexWrap::NoWrap, content="NoWrap")
  inspect(@values.FlexWrap::Wrap, content="Wrap")
  inspect(@values.FlexWrap::WrapReverse, content="WrapReverse")
}

///|
test "Show for AlignSelf" {
  inspect(@values.AlignSelf::Auto, content="Auto")
  inspect(@values.AlignSelf::Start, content="Start")
  inspect(@values.AlignSelf::End, content="End")
  inspect(@values.AlignSelf::Center, content="Center")
  inspect(@values.AlignSelf::Stretch, content="Stretch")
  inspect(@values.AlignSelf::Baseline, content="Baseline")
}

///|
test "Show for CssFloat, Clear, Overflow, BoxSizing" {
  inspect(@values.CssFloat::None, content="None")
  inspect(@values.CssFloat::Left, content="Left")
  inspect(@values.CssFloat::Right, content="Right")
  inspect(@values.Clear::None, content="None")
  inspect(@values.Clear::Both, content="Both")
  inspect(@values.Overflow::Visible, content="Visible")
  inspect(@values.Overflow::Hidden, content="Hidden")
  inspect(@values.Overflow::Clip, content="Clip")
  inspect(@values.Overflow::Scroll, content="Scroll")
  inspect(@values.Overflow::Auto, content="Auto")
  inspect(@values.BoxSizing::ContentBox, content="ContentBox")
  inspect(@values.BoxSizing::BorderBox, content="BorderBox")
}

///|
test "Show for grid types" {
  inspect(@values.GridAutoFlow::Row, content="Row")
  inspect(@values.GridAutoFlow::Column, content="Column")
  inspect(@values.GridAutoFlow::RowDense, content="RowDense")
  inspect(@values.GridAutoFlow::ColumnDense, content="ColumnDense")
  inspect(@values.GridPlacement::Auto, content="Auto")
  inspect(@values.GridPlacement::Line(3), content="Line(3)")
  inspect(@values.GridPlacement::Span(2), content="Span(2)")
  inspect(
    @values.GridPlacement::Named("left-sidebar"),
    content="Named(left-sidebar)",
  )
  let gl = @values.GridLine::auto()
  inspect(gl, content="{start: Auto, end: Auto}")
}

///|
test "Show for SingleTrackSizing" {
  inspect(@values.SingleTrackSizing::Length(50.0), content="Length(50)")
  inspect(@values.SingleTrackSizing::Percent(0.5), content="Percent(0.5)")
  inspect(@values.SingleTrackSizing::Fr(1.0), content="Fr(1)")
  inspect(@values.SingleTrackSizing::Auto, content="Auto")
  inspect(@values.SingleTrackSizing::MinContent, content="MinContent")
  inspect(@values.SingleTrackSizing::MaxContent, content="MaxContent")
  inspect(
    @values.SingleTrackSizing::FitContentLength(100.0),
    content="FitContentLength(100)",
  )
  inspect(
    @values.SingleTrackSizing::FitContentPercent(0.5),
    content="FitContentPercent(0.5)",
  )
  inspect(
    @values.SingleTrackSizing::MinMax(Length(10.0), Fr(1.0)),
    content="MinMax(Length(10), Fr(1))",
  )
}

///|
test "Show for TrackSizingFunction" {
  inspect(@values.TrackSizingFunction::Length(50.0), content="Length(50)")
  inspect(@values.TrackSizingFunction::Percent(0.25), content="Percent(0.25)")
  inspect(@values.TrackSizingFunction::Fr(2.0), content="Fr(2)")
  inspect(@values.TrackSizingFunction::Auto, content="Auto")
  inspect(@values.TrackSizingFunction::MinContent, content="MinContent")
  inspect(@values.TrackSizingFunction::MaxContent, content="MaxContent")
  inspect(
    @values.TrackSizingFunction::FitContentLength(80.0),
    content="FitContentLength(80)",
  )
  inspect(
    @values.TrackSizingFunction::FitContentPercent(0.25),
    content="FitContentPercent(0.25)",
  )
  let mm = @values.TrackSizingFunction::MinMax(Auto, Fr(1.0))
  inspect(mm, content="MinMax(Auto, Fr(1))")
  inspect(@values.RepeatCount::Count(3), content="Count(3)")
  inspect(@values.RepeatCount::AutoFill, content="AutoFill")
  inspect(@values.RepeatCount::AutoFit, content="AutoFit")
  let rep = @values.TrackSizingFunction::Repeat(Count(2), [Fr(1.0), Auto], [])
  inspect(rep, content="Repeat(Count(2), [Fr(1), Auto])")
  // With inner line names, the third component is rendered.
  let rep2 = @values.TrackSizingFunction::Repeat(Count(3), [Fr(1.0)], [
    ["a"],
    ["b"],
  ])
  inspect(rep2, content="Repeat(Count(3), [Fr(1)], [[\"a\"], [\"b\"]])")
}

///|
test "Show for MinTrackSizing and MaxTrackSizing" {
  inspect(@values.MinTrackSizing::Length(10.0), content="Length(10)")
  inspect(@values.MinTrackSizing::Percent(0.5), content="Percent(0.5)")
  inspect(@values.MinTrackSizing::Auto, content="Auto")
  inspect(@values.MinTrackSizing::MinContent, content="MinContent")
  inspect(@values.MinTrackSizing::MaxContent, content="MaxContent")
  inspect(@values.MaxTrackSizing::Length(20.0), content="Length(20)")
  inspect(@values.MaxTrackSizing::Percent(0.25), content="Percent(0.25)")
  inspect(@values.MaxTrackSizing::Fr(3.0), content="Fr(3)")
  inspect(@values.MaxTrackSizing::Auto, content="Auto")
  inspect(@values.MaxTrackSizing::MinContent, content="MinContent")
  inspect(@values.MaxTrackSizing::MaxContent, content="MaxContent")
}
