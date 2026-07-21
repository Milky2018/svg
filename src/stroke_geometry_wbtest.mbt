///|
test "closed dash pieces join across the path seam" {
  let points = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0), (0.0, 0.0)]
  let pieces = dash_local_polyline_pieces(points, [8.0, 4.0], 0.0)
  inspect(pieces.length(), content="4")
  merge_closed_dash_seam(pieces, points[0])
  inspect(pieces.length(), content="3")
  inspect(points_are_close(pieces[0][1], points[0]), content="true")
}

///|
test "zero-length strokes follow linecap shape semantics" {
  for linecap in [LineCap::Round, LineCap::Square, LineCap::Butt] {
    let outlines : Array[Array[(Double, Double)]] = []
    let stroke = { ..StrokeStyle::default(), width: 4.0, linecap }
    append_affine_stroke_piece(
      outlines,
      [(8.0, 8.0), (8.0, 8.0)],
      stroke,
      Transform::identity(),
      false,
    )
    inspect(
      outlines.length() > 0,
      content=if linecap == Butt { "false" } else { "true" },
    )
  }
}
