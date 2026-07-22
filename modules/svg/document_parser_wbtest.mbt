///|
test "parse_svg_document viewBox and preserveAspectRatio" {
  let svg = "<svg viewBox=\"0 0 10 20\" preserveAspectRatio=\"xMinYMin slice\"><rect width=\"10\" height=\"20\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      if doc.root.view_box is Some(vb) {
        inspect(vb.width, content="10")
        inspect(vb.height, content="20")
      } else {
        inspect("none", content="should parse viewBox")
      }
      inspect(doc.root.preserve_aspect_ratio.align, content="XMinYMin")
      inspect(doc.root.preserve_aspect_ratio.meet_or_slice, content="Slice")
    }
    None => panic()
  }
}
