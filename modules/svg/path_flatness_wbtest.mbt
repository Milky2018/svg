///|
test "arc approximation respects the requested sagitta" {
  let polylines = path_to_polylines(
    [MoveTo(100.0, 0.0), ArcTo(100.0, 100.0, 0.0, false, true, -100.0, 0.0)],
    0.125,
  )
  let segments = polylines[0].length() - 1
  let segment_angle = 3.141592653589793 / segments.to_double()
  let sagitta = 100.0 * (1.0 - @math.cos(segment_angle / 2.0))
  inspect(sagitta <= 0.125, content="true")
}

///|
test "collinear cubic overshoot is not collapsed to its chord" {
  let polylines = path_to_polylines(
    [MoveTo(0.0, 0.0), CurveTo(1000.0, 0.0, -1000.0, 0.0, 1.0, 0.0)],
    0.125,
  )
  inspect(polylines[0].length() > 2, content="true")
}
