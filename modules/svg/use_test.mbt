///|
test "document registers and instantiates ordinary definitions" {
  let definition = SVGNode::new(
    Rect(x=0.0, y=0.0, width=4.0, height=3.0, rx=0.0, ry=0.0),
  )
  definition.id = "shape"
  let document = SVGDocument::new(SVGNode::new(Group))
  document.add_definition("shape", definition)
  let use_element = UseElement::new("#shape", 7.0, 9.0)
  match document.instantiate_use(use_element) {
    Some(node) => {
      let (x, y) = node.transform.apply(0.0, 0.0)
      debug_inspect((x, y), content="(7, 9)")
      assert_true(node.shape is Rect(..))
    }
    None => fail("expected ordinary definition instance")
  }
}
