///|
fn xml_test_find_node(node : SVGNode, id : String) -> SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    match xml_test_find_node(child, id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
test "XML reader handles namespaces and entities in attributes and text" {
  let document = parse_svg_document(
    "<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"><svg:text id=\"a&#x2D;b\">A&amp;&#x42;</svg:text></svg:svg>",
  ).unwrap()
  let node = xml_test_find_node(document.root(), "a-b").unwrap()
  match node.shape {
    Text(text~, ..) => assert_eq(text, "A&B")
    _ => fail("expected text shape")
  }
}

///|
test "XML reader preserves CDATA text and ignores comments" {
  let document = parse_svg_document(
    "<svg><!-- ignored --><text id=\"target\"><![CDATA[x<y]]></text></svg>",
  ).unwrap()
  let node = xml_test_find_node(document.root(), "target").unwrap()
  match node.shape {
    Text(text~, ..) => assert_eq(text, "x<y")
    _ => fail("expected text shape")
  }
}

///|
test "XML reader accepts self-closing elements" {
  let document = parse_svg_document(
    "<svg><g><rect id=\"box\" width=\"2\" height=\"3\"/></g></svg>",
  ).unwrap()
  let node = xml_test_find_node(document.root(), "box").unwrap()
  assert_true(node.shape is Rect(width=2.0, height=3.0, ..))
}

///|
test "XML reader rejects malformed nesting and attributes" {
  assert_true(parse_svg_document("<svg><g></svg>") is None)
  assert_true(parse_svg_document("<svg><rect width=1/></svg>") is None)
  assert_true(parse_svg_document("<svg id=\"a\" id=\"b\"/>") is None)
}

///|
test "string parsing does not resolve external DTD resources" {
  let svg = "<!DOCTYPE svg SYSTEM \"definitely-missing.dtd\"><svg/>"
  assert_true(parse_svg_document(svg) is Some(_))
}
