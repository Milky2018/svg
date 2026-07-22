///|
test "text rendering basic" {
  // Create a text node
  let text_node = SVGNode::new(Text(x=10.0, y=20.0, text="Hi", font_size=7.0))
  text_node.fill = SolidColor(Color::rgb(0, 0, 0))
  let drawn_pixels : Array[(Int, Int, Color)] = []
  let setter : ColorSink = {
    set: (x, y, color) => drawn_pixels.push((x, y, color)),
  }
  let ctx = RenderState::new(setter, 100, 50)
  SVGDocument::new(text_node).render(ctx)
  // Should have drawn some pixels for the text
  inspect(drawn_pixels.length() > 0, content="true")
}
