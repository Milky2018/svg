///|
test "parse_stroke_width_basic" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\">" +
    "<path d=\"M 0 0 L 10 0\" stroke=\"black\" stroke-width=\"16\"/>" +
    "</svg>"
  let doc = match parse_svg_document(svg) {
    Some(v) => v
    None => SVGDocument::new(SVGNode::new(Group))
  }
  let node = if doc.root.children.length() > 0 {
    doc.root.children[0]
  } else {
    SVGNode::new(Group)
  }
  inspect(node.stroke.width, content="16")
}

///|
test "path_to_polylines_simple" {
  let commands = parse_path("M 0 0 L 100 0 L 100 100 Z")
  let polylines = path_to_polylines(commands, 1.0)
  inspect(polylines.length(), content="1")
  // 4 points: start, 2 line endpoints, close back to start
  inspect(polylines[0].length(), content="4")
}

///|
test "bounding_box" {
  let bbox = BoundingBox::from_rect(10.0, 20.0, 30.0, 40.0)
  inspect(bbox.width(), content="30")
  inspect(bbox.height(), content="40")
}

///|
test "bounding_box_union" {
  let b1 = BoundingBox::from_rect(0.0, 0.0, 10.0, 10.0)
  let b2 = BoundingBox::from_rect(5.0, 5.0, 10.0, 10.0)
  let union = b1.union(b2)
  inspect(union.min_x, content="0")
  inspect(union.min_y, content="0")
  inspect(union.max_x, content="15")
  inspect(union.max_y, content="15")
}
