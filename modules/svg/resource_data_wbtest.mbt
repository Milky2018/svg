///|
test "decode_data_svg_base64" {
  let encoded = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IGlkPSJyIiB3aWR0aD0iMTAiIGhlaWdodD0iMTAiLz48L3N2Zz4="
  let decoded = match decode_data_svg(encoded) {
    Some(v) => v
    None => "<none>"
  }
  inspect(
    decoded,
    content="<svg xmlns=\"http://www.w3.org/2000/svg\"><rect id=\"r\" width=\"10\" height=\"10\"/></svg>",
  )
}

///|
test "parse_marker_viewbox_offset" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\">" +
    "<defs>" +
    "<marker id=\"m\" viewBox=\"20 20 10 10\" markerWidth=\"2\" markerHeight=\"2\" refX=\"25\" refY=\"25\" markerUnits=\"strokeWidth\">" +
    "<rect x=\"20\" y=\"20\" width=\"10\" height=\"10\"/>" +
    "</marker>" +
    "</defs>" +
    "<path d=\"M 0 0 L 10 0\" marker-start=\"url(#m)\" stroke=\"black\" stroke-width=\"16\"/>" +
    "</svg>"
  let doc = match parse_svg_document(svg) {
    Some(v) => v
    None => SVGDocument::new(SVGNode::new(Group))
  }
  let marker = match doc.markers.get("m") {
    Some(v) => v
    None => Marker::new("m", SVGNode::new(Group))
  }
  inspect(marker.marker_width, content="2")
  inspect(marker.marker_height, content="2")
  inspect(marker.view_box is Some(_), content="true")
}
