///|
/// CSS display property
pub(all) enum Display {
  Block
  Inline
  InlineBlock
  Flex
  InlineFlex
  Grid
  InlineGrid
  Table
  InlineTable
  TableRow
  TableCell
  TableCaption
  TableRowGroup
  TableHeaderGroup
  TableFooterGroup
  TableColumn
  TableColumnGroup
  None
  Contents
  FlowRoot
} derive(Debug, Eq)

///|
/// CSS position property
pub(all) enum Position {
  Static
  Relative
  Absolute
  Fixed
} derive(Debug, Eq)

///|
/// Flex direction
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
} derive(Debug, Eq)

///|
/// Alignment for justify-content, align-items, etc.
pub(all) enum Alignment {
  Start
  End
  Left
  Right
  FlexStart
  FlexEnd
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
  Stretch
  Baseline
} derive(Debug, Eq)

///|
/// Flex wrap mode
pub(all) enum FlexWrap {
  NoWrap
  Wrap
  WrapReverse
} derive(Debug, Eq)

///|
/// Align-self value (can override align-items for individual items)
pub(all) enum AlignSelf {
  Auto
  Start
  End
  Center
  Stretch
  Baseline
} derive(Debug, Eq)

///|
/// CSS float property
pub(all) enum Float {
  None
  Left
  Right
} derive(Debug, Eq)

///|
/// CSS clear property
pub(all) enum Clear {
  None
  Left
  Right
  Both
} derive(Debug, Eq)

///|
/// CSS overflow property
pub(all) enum Overflow {
  Visible
  Hidden
  Clip
  Scroll
  Auto
} derive(Debug, Eq)

///|
/// CSS box-sizing property
pub(all) enum BoxSizing {
  ContentBox
  BorderBox
} derive(Debug, Eq)

///|
/// Grid auto-flow direction
pub(all) enum GridAutoFlow {
  Row
  Column
  RowDense
  ColumnDense
} derive(Debug, Eq)

///|
/// Kind of a grid template axis (grid-template-columns / -rows).
/// `Explicit` is the normal `<track-list>` (or `none` when the track array is
/// empty); `Subgrid` / `Masonry` are the alternative axis values.
pub(all) enum GridTemplateKind {
  Explicit
  Subgrid
  Masonry
} derive(Debug, Eq)

///|
/// `animation-direction` value.
pub(all) enum AnimationDirection {
  Normal
  Reverse
  Alternate
  AlternateReverse
} derive(Debug, Eq)

///|
/// `animation-fill-mode` value.
pub(all) enum AnimationFillMode {
  None
  Forwards
  Backwards
  Both
} derive(Debug, Eq)

///|
/// `animation-play-state` value.
pub(all) enum AnimationPlayState {
  Running
  Paused
} derive(Debug, Eq)

///|
/// `animation-iteration-count` value (`<number>` or `infinite`).
pub(all) enum AnimationIterationCount {
  Count(Double)
  Infinite
} derive(Debug, Eq)

///|
pub impl Show for AnimationDirection with fn output(self, logger) {
  let name = match self {
    Normal => "Normal"
    Reverse => "Reverse"
    Alternate => "Alternate"
    AlternateReverse => "AlternateReverse"
  }
  logger.write_string(name)
}

///|
pub impl Show for AnimationFillMode with fn output(self, logger) {
  let name = match self {
    None => "None"
    Forwards => "Forwards"
    Backwards => "Backwards"
    Both => "Both"
  }
  logger.write_string(name)
}

///|
pub impl Show for AnimationPlayState with fn output(self, logger) {
  let name = match self {
    Running => "Running"
    Paused => "Paused"
  }
  logger.write_string(name)
}

///|
pub impl Show for AnimationIterationCount with fn output(self, logger) {
  match self {
    Count(v) => logger.write_string("Count(\{v})")
    Infinite => logger.write_string("Infinite")
  }
}

///|
/// Grid line placement for grid items
pub(all) enum GridPlacement {
  Auto
  Line(Int)
  Span(Int)
  // Named line reference, e.g. `grid-column: left-sidebar`.
  // Resolved against the named lines declared in grid-template-columns/rows.
  Named(String)
  // `<integer> && <custom-ident>`, e.g. `grid-column: 2 foo`: the Nth line
  // named `foo` (N may be negative to count from the end).
  NamedLine(Int, String)
  // `span && <integer>? && <custom-ident>`, e.g. `grid-column: span 2 foo`:
  // span until the Nth line named `foo` (N defaults to 1).
  SpanNamed(Int, String)
} derive(Debug, Eq)

///|
/// Single track sizing function (non-repeating)
pub(all) enum SingleTrackSizing {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
  MinMax(MinTrackSizing, MaxTrackSizing)
  FitContentLength(Double)
  FitContentPercent(Double)
} derive(Debug, Eq)

///|
/// Repeat count for repeat() function
pub(all) enum RepeatCount {
  Count(Int)
  AutoFill
  AutoFit
} derive(Debug, Eq)

///|
/// Track sizing function for grid-template-rows/columns
pub(all) enum TrackSizingFunction {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
  MinMax(MinTrackSizing, MaxTrackSizing)
  // Repeat(count, tracks, line_names). `line_names` holds the named lines
  // declared inside one repetition (index = line within the repetition, length
  // = tracks + 1), e.g. `repeat(3, [a] 1fr [b])` => [["a"], ["b"]].
  Repeat(RepeatCount, Array[SingleTrackSizing], Array[Array[String]])
  FitContentLength(Double)
  FitContentPercent(Double)
} derive(Debug, Eq)

///|
/// Minimum track sizing function for minmax()
pub(all) enum MinTrackSizing {
  Length(Double)
  Percent(Double)
  Auto
  MinContent
  MaxContent
} derive(Debug, Eq)

///|
/// Maximum track sizing function for minmax()
pub(all) enum MaxTrackSizing {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
} derive(Debug, Eq)

///|
/// Grid line range (start and end)
pub(all) struct GridLine {
  start : GridPlacement
  end : GridPlacement
} derive(Debug, Eq)

///|
let grid_line_auto : GridLine = { start: Auto, end: Auto, }

///|
pub fn GridLine::auto() -> GridLine {
  grid_line_auto
}

///|
pub impl Show for Display with fn output(self, logger) {
  let name = match self {
    Block => "Block"
    Inline => "Inline"
    InlineBlock => "InlineBlock"
    Flex => "Flex"
    InlineFlex => "InlineFlex"
    Grid => "Grid"
    InlineGrid => "InlineGrid"
    Table => "Table"
    InlineTable => "InlineTable"
    TableRow => "TableRow"
    TableCell => "TableCell"
    TableCaption => "TableCaption"
    TableRowGroup => "TableRowGroup"
    TableHeaderGroup => "TableHeaderGroup"
    TableFooterGroup => "TableFooterGroup"
    TableColumn => "TableColumn"
    TableColumnGroup => "TableColumnGroup"
    None => "None"
    Contents => "Contents"
    FlowRoot => "FlowRoot"
  }
  logger.write_string(name)
}

///|
pub impl Show for Position with fn output(self, logger) {
  let name = match self {
    Static => "Static"
    Relative => "Relative"
    Absolute => "Absolute"
    Fixed => "Fixed"
  }
  logger.write_string(name)
}

///|
pub impl Show for FlexDirection with fn output(self, logger) {
  let name = match self {
    Row => "Row"
    RowReverse => "RowReverse"
    Column => "Column"
    ColumnReverse => "ColumnReverse"
  }
  logger.write_string(name)
}

///|
pub impl Show for Alignment with fn output(self, logger) {
  let name = match self {
    Start => "Start"
    End => "End"
    Left => "Left"
    Right => "Right"
    FlexStart => "FlexStart"
    FlexEnd => "FlexEnd"
    Center => "Center"
    SpaceBetween => "SpaceBetween"
    SpaceAround => "SpaceAround"
    SpaceEvenly => "SpaceEvenly"
    Stretch => "Stretch"
    Baseline => "Baseline"
  }
  logger.write_string(name)
}

///|
pub impl Show for FlexWrap with fn output(self, logger) {
  let name = match self {
    NoWrap => "NoWrap"
    Wrap => "Wrap"
    WrapReverse => "WrapReverse"
  }
  logger.write_string(name)
}

///|
pub impl Show for AlignSelf with fn output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Start => "Start"
    End => "End"
    Center => "Center"
    Stretch => "Stretch"
    Baseline => "Baseline"
  }
  logger.write_string(name)
}

///|
pub impl Show for Float with fn output(self, logger) {
  let name = match self {
    None => "None"
    Left => "Left"
    Right => "Right"
  }
  logger.write_string(name)
}

///|
pub impl Show for Clear with fn output(self, logger) {
  let name = match self {
    None => "None"
    Left => "Left"
    Right => "Right"
    Both => "Both"
  }
  logger.write_string(name)
}

///|
pub impl Show for Overflow with fn output(self, logger) {
  let name = match self {
    Visible => "Visible"
    Hidden => "Hidden"
    Clip => "Clip"
    Scroll => "Scroll"
    Auto => "Auto"
  }
  logger.write_string(name)
}

///|
pub impl Show for BoxSizing with fn output(self, logger) {
  let name = match self {
    ContentBox => "ContentBox"
    BorderBox => "BorderBox"
  }
  logger.write_string(name)
}

///|
pub impl Show for GridAutoFlow with fn output(self, logger) {
  let name = match self {
    Row => "Row"
    Column => "Column"
    RowDense => "RowDense"
    ColumnDense => "ColumnDense"
  }
  logger.write_string(name)
}

///|
pub impl Show for GridTemplateKind with fn output(self, logger) {
  let name = match self {
    Explicit => "Explicit"
    Subgrid => "Subgrid"
    Masonry => "Masonry"
  }
  logger.write_string(name)
}

///|
pub impl Show for GridPlacement with fn output(self, logger) {
  let text = match self {
    Auto => "Auto"
    Line(v) => "Line(\{v})"
    Span(v) => "Span(\{v})"
    Named(name) => "Named(\{name})"
    NamedLine(n, name) => "NamedLine(\{n}, \{name})"
    SpanNamed(n, name) => "SpanNamed(\{n}, \{name})"
  }
  logger.write_string(text)
}

///|
pub impl Show for SingleTrackSizing with fn output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Fr(v) => "Fr(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
    MinMax(min, max) => "MinMax(\{min}, \{max})"
    FitContentLength(v) => "FitContentLength(\{v})"
    FitContentPercent(v) => "FitContentPercent(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for RepeatCount with fn output(self, logger) {
  let text = match self {
    Count(v) => "Count(\{v})"
    AutoFill => "AutoFill"
    AutoFit => "AutoFit"
  }
  logger.write_string(text)
}

///|
pub impl Show for TrackSizingFunction with fn output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Fr(v) => "Fr(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
    MinMax(min, max) => "MinMax(\{min}, \{max})"
    Repeat(count, tracks, line_names) => {
      // Only render the line-name component when at least one line is named, so
      // plain repeats keep the compact two-argument form.
      let mut has_names = false
      for g in line_names {
        if g.length() > 0 {
          has_names = true
          break
        }
      }
      if has_names {
        "Repeat(\{count}, \{Repr(tracks)}, \{Repr(line_names)})"
      } else {
        "Repeat(\{count}, \{Repr(tracks)})"
      }
    }
    FitContentLength(v) => "FitContentLength(\{v})"
    FitContentPercent(v) => "FitContentPercent(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for MinTrackSizing with fn output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
  }
  logger.write_string(text)
}

///|
pub impl Show for MaxTrackSizing with fn output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Fr(v) => "Fr(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
  }
  logger.write_string(text)
}

///|
pub impl Show for GridLine with fn output(self, logger) {
  logger.write_string("{start: ")
  logger.write_string(self.start.to_string())
  logger.write_string(", end: ")
  logger.write_string(self.end.to_string())
  logger.write_string("}")
}

///|
pub extend AlignSelf with Debug::{to_repr}

///|
pub extend AlignSelf with Eq::{not_equal, equal}

///|
pub extend AlignSelf with Show::{to_string, output}

///|
pub extend Alignment with Debug::{to_repr}

///|
pub extend Alignment with Eq::{not_equal, equal}

///|
pub extend Alignment with Show::{to_string, output}

///|
pub extend AnimationDirection with Debug::{to_repr}

///|
pub extend AnimationDirection with Eq::{not_equal, equal}

///|
pub extend AnimationDirection with Show::{to_string, output}

///|
pub extend AnimationFillMode with Debug::{to_repr}

///|
pub extend AnimationFillMode with Eq::{not_equal, equal}

///|
pub extend AnimationFillMode with Show::{to_string, output}

///|
pub extend AnimationIterationCount with Debug::{to_repr}

///|
pub extend AnimationIterationCount with Eq::{not_equal, equal}

///|
pub extend AnimationIterationCount with Show::{to_string, output}

///|
pub extend AnimationPlayState with Debug::{to_repr}

///|
pub extend AnimationPlayState with Eq::{not_equal, equal}

///|
pub extend AnimationPlayState with Show::{to_string, output}

///|
pub extend BoxSizing with Debug::{to_repr}

///|
pub extend BoxSizing with Eq::{not_equal, equal}

///|
pub extend BoxSizing with Show::{to_string, output}

///|
pub extend Clear with Debug::{to_repr}

///|
pub extend Clear with Eq::{not_equal, equal}

///|
pub extend Clear with Show::{to_string, output}

///|
pub extend Display with Debug::{to_repr}

///|
pub extend Display with Eq::{not_equal, equal}

///|
pub extend Display with Show::{to_string, output}

///|
pub extend FlexDirection with Debug::{to_repr}

///|
pub extend FlexDirection with Eq::{not_equal, equal}

///|
pub extend FlexDirection with Show::{to_string, output}

///|
pub extend FlexWrap with Debug::{to_repr}

///|
pub extend FlexWrap with Eq::{not_equal, equal}

///|
pub extend FlexWrap with Show::{to_string, output}

///|
pub extend Float with Debug::{to_repr}

///|
pub extend Float with Eq::{not_equal, equal}

///|
pub extend Float with Show::{to_string, output}

///|
pub extend GridAutoFlow with Debug::{to_repr}

///|
pub extend GridAutoFlow with Eq::{not_equal, equal}

///|
pub extend GridAutoFlow with Show::{to_string, output}

///|
pub extend GridLine with Debug::{to_repr}

///|
pub extend GridLine with Eq::{not_equal, equal}

///|
pub extend GridLine with Show::{to_string, output}

///|
pub extend GridPlacement with Debug::{to_repr}

///|
pub extend GridPlacement with Eq::{not_equal, equal}

///|
pub extend GridPlacement with Show::{to_string, output}

///|
pub extend GridTemplateKind with Debug::{to_repr}

///|
pub extend GridTemplateKind with Eq::{not_equal, equal}

///|
pub extend GridTemplateKind with Show::{to_string, output}

///|
pub extend MaxTrackSizing with Debug::{to_repr}

///|
pub extend MaxTrackSizing with Eq::{not_equal, equal}

///|
pub extend MaxTrackSizing with Show::{to_string, output}

///|
pub extend MinTrackSizing with Debug::{to_repr}

///|
pub extend MinTrackSizing with Eq::{not_equal, equal}

///|
pub extend MinTrackSizing with Show::{to_string, output}

///|
pub extend Overflow with Debug::{to_repr}

///|
pub extend Overflow with Eq::{not_equal, equal}

///|
pub extend Overflow with Show::{to_string, output}

///|
pub extend Position with Debug::{to_repr}

///|
pub extend Position with Eq::{not_equal, equal}

///|
pub extend Position with Show::{to_string, output}

///|
pub extend RepeatCount with Debug::{to_repr}

///|
pub extend RepeatCount with Eq::{not_equal, equal}

///|
pub extend RepeatCount with Show::{to_string, output}

///|
pub extend SingleTrackSizing with Debug::{to_repr}

///|
pub extend SingleTrackSizing with Eq::{not_equal, equal}

///|
pub extend SingleTrackSizing with Show::{to_string, output}

///|
pub extend TrackSizingFunction with Debug::{to_repr}

///|
pub extend TrackSizingFunction with Eq::{not_equal, equal}

///|
pub extend TrackSizingFunction with Show::{to_string, output}
