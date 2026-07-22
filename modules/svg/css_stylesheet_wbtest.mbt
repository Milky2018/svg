///|
test "CSS adapter cascades SVG extension properties" {
  let stylesheets = [
    @css.parse_stylesheet("#current { stop-color: currentColor !important; }"),
  ]
  let element = style_element("stop", [("id", "current")], None, None, 1, 1)
  let values = cascade_element_styles(
    stylesheets,
    element,
    [("id", "current")],
    @css_media.MediaEnvironment::new(300.0, 150.0),
  )
  assert_eq(values.get_value("stop-color"), Some("currentColor"))
}

///|
test "computed SVG style applies cascaded stop properties" {
  let stylesheets = [
    @css.parse_stylesheet("#target { stop-color: red; stop-opacity: 0.5; }"),
  ]
  let attrs = [("id", "target")]
  let values = cascade_element_styles(
    stylesheets,
    style_element("stop", attrs, None, None, 1, 1),
    attrs,
    @css_media.MediaEnvironment::new(300.0, 150.0),
  )
  let style = resolve_computed_style(
    SVGNode::new(Group),
    attrs,
    values,
    InheritedStyle::default(),
    false,
  )
  assert_eq(style.stop_color.r, 255)
  assert_eq(style.stop_color.g, 0)
  assert_eq(style.stop_color.b, 0)
  assert_eq(style.stop_opacity, 0.5)
}

///|
test "gradient stop parser keeps the shared cascade" {
  let stylesheets = [
    @css.parse_stylesheet("#target { stop-color: red !important; }"),
  ]
  let ctx = SVGParseContext::new(stylesheets)
  let parent_attrs = [("id", "paint")]
  let _ = ctx.record_selector_element("linearGradient", parent_attrs)
  let events = read_xml_events(
    "<linearGradient><stop id=\"target\" offset=\"0\" style=\"stop-color: blue\"/></linearGradient>",
  ).unwrap()
  let parser = SVGParser::new(events)
  let _ = parser.advance_event()
  let stops = parse_gradient_stops(
    parser,
    "linearGradient",
    parent_attrs,
    ctx,
    InheritedStyle::default(),
  )
  assert_eq(stops.length(), 1)
  assert_eq(stops[0].color.r, 255)
  assert_eq(stops[0].color.g, 0)
  assert_eq(stops[0].color.b, 0)
}

///|
test "embedded styles cascade into parsed gradient stops" {
  let svg = "<svg width=\"2\" height=\"2\"><style>#target { stop-color: red !important; }</style><defs><linearGradient id=\"paint\"><stop id=\"target\" offset=\"0\" style=\"stop-color: blue\"/></linearGradient></defs><rect width=\"2\" height=\"2\" fill=\"url(#paint)\"/></svg>"
  let image = render_svg(svg, 2, 2, RenderOptions::default()).image
  let color = image.get_pixel(0, 0)
  assert_eq(color.r, 255)
  assert_eq(color.g, 0)
  assert_eq(color.b, 0)
}
