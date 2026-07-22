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
test "only SVG namespace elements use SVG element semantics" {
  let document = parse_svg_document(
    "<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\" xmlns:html=\"http://www.w3.org/1999/xhtml\"><html:rect id=\"foreign\" width=\"2\" height=\"3\"/><svg:rect id=\"native\" width=\"2\" height=\"3\"/></svg:svg>",
  ).unwrap()
  let foreign = xml_test_find_node(document.root(), "foreign").unwrap()
  let native = xml_test_find_node(document.root(), "native").unwrap()
  assert_true(foreign.shape is Group)
  assert_true(native.shape is Rect(width=2.0, height=3.0, ..))
}

///|
test "non-SVG style elements do not enter the SVG stylesheet cascade" {
  let document = parse_svg_document(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:foo=\"https://example.test/foreign\"><foo:style>rect { fill: red; }</foo:style><rect id=\"target\" width=\"2\" height=\"2\" fill=\"blue\"/></svg>",
  ).unwrap()
  let target = xml_test_find_node(document.root(), "target").unwrap()
  match target.fill {
    SolidColor(color) => {
      assert_eq(color.r, 0)
      assert_eq(color.g, 0)
      assert_eq(color.b, 255)
    }
    _ => fail("expected a solid fill")
  }
}

///|
test "namespace prefix rebinding is scoped to its declaring element" {
  let document = parse_svg_document(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:p=\"http://www.w3.org/2000/svg\"><p:rect id=\"before\" width=\"1\" height=\"1\"/><g xmlns:p=\"https://example.test/foreign\"><p:rect id=\"foreign\" width=\"1\" height=\"1\"/></g><p:rect id=\"after\" width=\"1\" height=\"1\"/></svg>",
  ).unwrap()
  let before = xml_test_find_node(document.root(), "before").unwrap()
  let foreign = xml_test_find_node(document.root(), "foreign").unwrap()
  let after = xml_test_find_node(document.root(), "after").unwrap()
  assert_true(before.shape is Rect(..))
  assert_true(foreign.shape is Group)
  assert_true(after.shape is Rect(..))
}

///|
test "explicitly clearing the default namespace removes SVG semantics" {
  let document = parse_svg_document(
    "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect xmlns=\"\" id=\"foreign\" width=\"1\" height=\"1\"/><rect id=\"native\" width=\"1\" height=\"1\"/></svg>",
  ).unwrap()
  let foreign = xml_test_find_node(document.root(), "foreign").unwrap()
  let native = xml_test_find_node(document.root(), "native").unwrap()
  assert_true(foreign.shape is Group)
  assert_true(native.shape is Rect(..))
}

///|
test "foreignObject descendants retain their foreign namespace" {
  let document = parse_svg_document(
    "<svg xmlns=\"http://www.w3.org/2000/svg\"><foreignObject><html xmlns=\"http://www.w3.org/1999/xhtml\"><rect id=\"foreign\" width=\"1\" height=\"1\"/></html></foreignObject><rect id=\"native\" width=\"1\" height=\"1\"/></svg>",
  ).unwrap()
  let foreign = xml_test_find_node(document.root(), "foreign").unwrap()
  let native = xml_test_find_node(document.root(), "native").unwrap()
  assert_true(foreign.shape is Group)
  assert_true(native.shape is Rect(..))
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
