///|
/// SVG Module Tests

///|
fn parse_svg(svg : String) -> SVGNode? {
  parse_svg_document(svg).map(fn(document) { document.root })
}

///|
fn rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGNode {
  let node = SVGNode::new(Rect(x~, y~, width~, height~, rx=0.0, ry=0.0))
  node.id = id
  node
}

///|
fn circle(id : String, cx : Double, cy : Double, r : Double) -> SVGNode {
  let node = SVGNode::new(Circle(cx~, cy~, r~))
  node.id = id
  node
}

///|
fn find_test_node(node : SVGNode, id : String) -> SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    match find_test_node(child, id) {
      Some(found) => return Some(found)
      None => continue
    }
  }
  None
}

///|
fn miter_triangle_probe(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  width : Int,
) -> (Int, Int) {
  let dx0 = (x1 - x0).to_double()
  let dy0 = (y1 - y0).to_double()
  let dx1 = (x2 - x1).to_double()
  let dy1 = (y2 - y1).to_double()
  let len0 = (dx0 * dx0 + dy0 * dy0).sqrt()
  let len1 = (dx1 * dx1 + dy1 * dy1).sqrt()
  if len0 < 0.001 || len1 < 0.001 {
    return (x1, y1)
  }
  let ux0 = dx0 / len0
  let uy0 = dy0 / len0
  let ux1 = dx1 / len1
  let uy1 = dy1 / len1
  let denom = ux0 * uy1 - uy0 * ux1
  if denom.abs() < 0.0001 {
    return (x1, y1)
  }
  let half = width.to_double() / 2.0
  let side = if denom > 0.0 { -1.0 } else { 1.0 }
  let ox0 = x1.to_double() + side * -uy0 * half
  let oy0 = y1.to_double() + side * ux0 * half
  let ox1 = x1.to_double() + side * -uy1 * half
  let oy1 = y1.to_double() + side * ux1 * half
  let t = ((ox1 - ox0) * uy1 - (oy1 - oy0) * ux1) / denom
  let ix = ox0 + t * ux0
  let iy = oy0 + t * uy0
  let cx = (ox0 + ox1 + ix) / 3.0
  let cy = (oy0 + oy1 + iy) / 3.0
  (cx.to_int(), cy.to_int())
}
