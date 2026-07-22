///|
test "Show for Display" {
  inspect(Display::Block, content="Block")
  inspect(Display::Inline, content="Inline")
  inspect(Display::InlineBlock, content="InlineBlock")
  inspect(Display::Flex, content="Flex")
  inspect(Display::InlineFlex, content="InlineFlex")
  inspect(Display::Grid, content="Grid")
  inspect(Display::InlineGrid, content="InlineGrid")
  inspect(Display::Table, content="Table")
  inspect(Display::InlineTable, content="InlineTable")
  inspect(Display::TableRow, content="TableRow")
  inspect(Display::TableCell, content="TableCell")
  inspect(Display::TableCaption, content="TableCaption")
  inspect(Display::TableRowGroup, content="TableRowGroup")
  inspect(Display::TableHeaderGroup, content="TableHeaderGroup")
  inspect(Display::TableFooterGroup, content="TableFooterGroup")
  inspect(Display::TableColumn, content="TableColumn")
  inspect(Display::TableColumnGroup, content="TableColumnGroup")
  inspect(Display::None, content="None")
  inspect(Display::Contents, content="Contents")
  inspect(Display::FlowRoot, content="FlowRoot")
}

///|
test "Show for Position" {
  inspect(Position::Static, content="Static")
  inspect(Position::Relative, content="Relative")
  inspect(Position::Absolute, content="Absolute")
  inspect(Position::Fixed, content="Fixed")
}

///|
test "Show for FlexDirection" {
  inspect(FlexDirection::Row, content="Row")
  inspect(FlexDirection::RowReverse, content="RowReverse")
  inspect(FlexDirection::Column, content="Column")
  inspect(FlexDirection::ColumnReverse, content="ColumnReverse")
}

///|
test "Show for Alignment" {
  inspect(Alignment::Start, content="Start")
  inspect(Alignment::End, content="End")
  inspect(Alignment::Left, content="Left")
  inspect(Alignment::Right, content="Right")
  inspect(Alignment::FlexStart, content="FlexStart")
  inspect(Alignment::FlexEnd, content="FlexEnd")
  inspect(Alignment::Center, content="Center")
  inspect(Alignment::SpaceBetween, content="SpaceBetween")
  inspect(Alignment::SpaceAround, content="SpaceAround")
  inspect(Alignment::SpaceEvenly, content="SpaceEvenly")
  inspect(Alignment::Stretch, content="Stretch")
  inspect(Alignment::Baseline, content="Baseline")
}

///|
test "Show for FlexWrap" {
  inspect(FlexWrap::NoWrap, content="NoWrap")
  inspect(FlexWrap::Wrap, content="Wrap")
  inspect(FlexWrap::WrapReverse, content="WrapReverse")
}

///|
test "Show for AlignSelf" {
  inspect(AlignSelf::Auto, content="Auto")
  inspect(AlignSelf::Start, content="Start")
  inspect(AlignSelf::End, content="End")
  inspect(AlignSelf::Center, content="Center")
  inspect(AlignSelf::Stretch, content="Stretch")
  inspect(AlignSelf::Baseline, content="Baseline")
}

///|
test "Show for Float, Clear, Overflow, BoxSizing" {
  inspect(Float::None, content="None")
  inspect(Float::Left, content="Left")
  inspect(Float::Right, content="Right")
  inspect(Clear::None, content="None")
  inspect(Clear::Both, content="Both")
  inspect(Overflow::Visible, content="Visible")
  inspect(Overflow::Hidden, content="Hidden")
  inspect(Overflow::Clip, content="Clip")
  inspect(Overflow::Scroll, content="Scroll")
  inspect(Overflow::Auto, content="Auto")
  inspect(BoxSizing::ContentBox, content="ContentBox")
  inspect(BoxSizing::BorderBox, content="BorderBox")
}

///|
test "Show for grid types" {
  inspect(GridAutoFlow::Row, content="Row")
  inspect(GridAutoFlow::Column, content="Column")
  inspect(GridAutoFlow::RowDense, content="RowDense")
  inspect(GridAutoFlow::ColumnDense, content="ColumnDense")
  inspect(GridPlacement::Auto, content="Auto")
  inspect(GridPlacement::Line(3), content="Line(3)")
  inspect(GridPlacement::Span(2), content="Span(2)")
  inspect(GridPlacement::Named("left-sidebar"), content="Named(left-sidebar)")
  let gl = GridLine::auto()
  inspect(gl, content="{start: Auto, end: Auto}")
}

///|
test "Show for SingleTrackSizing" {
  inspect(SingleTrackSizing::Length(50.0), content="Length(50)")
  inspect(SingleTrackSizing::Percent(0.5), content="Percent(0.5)")
  inspect(SingleTrackSizing::Fr(1.0), content="Fr(1)")
  inspect(SingleTrackSizing::Auto, content="Auto")
  inspect(SingleTrackSizing::MinContent, content="MinContent")
  inspect(SingleTrackSizing::MaxContent, content="MaxContent")
  inspect(
    SingleTrackSizing::FitContentLength(100.0),
    content="FitContentLength(100)",
  )
  inspect(
    SingleTrackSizing::FitContentPercent(0.5),
    content="FitContentPercent(0.5)",
  )
  inspect(
    SingleTrackSizing::MinMax(
      MinTrackSizing::Length(10.0),
      MaxTrackSizing::Fr(1.0),
    ),
    content="MinMax(Length(10), Fr(1))",
  )
}

///|
test "Show for TrackSizingFunction" {
  inspect(TrackSizingFunction::Length(50.0), content="Length(50)")
  inspect(TrackSizingFunction::Percent(0.25), content="Percent(0.25)")
  inspect(TrackSizingFunction::Fr(2.0), content="Fr(2)")
  inspect(TrackSizingFunction::Auto, content="Auto")
  inspect(TrackSizingFunction::MinContent, content="MinContent")
  inspect(TrackSizingFunction::MaxContent, content="MaxContent")
  inspect(
    TrackSizingFunction::FitContentLength(80.0),
    content="FitContentLength(80)",
  )
  inspect(
    TrackSizingFunction::FitContentPercent(0.25),
    content="FitContentPercent(0.25)",
  )
  let mm = TrackSizingFunction::MinMax(
    MinTrackSizing::Auto,
    MaxTrackSizing::Fr(1.0),
  )
  inspect(mm, content="MinMax(Auto, Fr(1))")
  inspect(RepeatCount::Count(3), content="Count(3)")
  inspect(RepeatCount::AutoFill, content="AutoFill")
  inspect(RepeatCount::AutoFit, content="AutoFit")
  let rep = TrackSizingFunction::Repeat(
    RepeatCount::Count(2),
    [SingleTrackSizing::Fr(1.0), SingleTrackSizing::Auto],
    [],
  )
  inspect(rep, content="Repeat(Count(2), [Fr(1), Auto])")
  // With inner line names, the third component is rendered.
  let rep2 = TrackSizingFunction::Repeat(
    RepeatCount::Count(3),
    [SingleTrackSizing::Fr(1.0)],
    [["a"], ["b"]],
  )
  inspect(rep2, content="Repeat(Count(3), [Fr(1)], [[\"a\"], [\"b\"]])")
}

///|
test "Show for MinTrackSizing and MaxTrackSizing" {
  inspect(MinTrackSizing::Length(10.0), content="Length(10)")
  inspect(MinTrackSizing::Percent(0.5), content="Percent(0.5)")
  inspect(MinTrackSizing::Auto, content="Auto")
  inspect(MinTrackSizing::MinContent, content="MinContent")
  inspect(MinTrackSizing::MaxContent, content="MaxContent")
  inspect(MaxTrackSizing::Length(20.0), content="Length(20)")
  inspect(MaxTrackSizing::Percent(0.25), content="Percent(0.25)")
  inspect(MaxTrackSizing::Fr(3.0), content="Fr(3)")
  inspect(MaxTrackSizing::Auto, content="Auto")
  inspect(MaxTrackSizing::MinContent, content="MinContent")
  inspect(MaxTrackSizing::MaxContent, content="MaxContent")
}
