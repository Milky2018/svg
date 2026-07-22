///|
/// Public API helpers
/// Convenience functions for rendering to Image and bridging external trees.

///|
/// Parse and render SVG markup with structured diagnostics.
pub fn render_svg(
  svg_str : String,
  width : Int,
  height : Int,
  options : RenderOptions,
) -> RenderResult {
  match parse_svg_document(svg_str) {
    Some(document) => render_svg_document(document, width, height, options)
    None => {
      let diagnostics = [
        { kind: ParseFailed, stage: Document, resource: "", node_id: "" },
      ]
      { image: Image::new(width, height), diagnostics }
    }
  }
}

///|
/// Render a parsed SVG document with structured diagnostics.
pub fn render_svg_document(
  document : SVGDocument,
  width : Int,
  height : Int,
  options : RenderOptions,
) -> RenderResult {
  let image = Image::new(width, height)
  let diagnostics : Array[RenderDiagnostic] = []
  let setter = make_image_compositing_setter(image)
  let ctx = {
    ..RenderState::new(setter, width, height),
    image_resolver: options.image_resolver,
    target_image: Some(image),
    diagnostics,
  }
  document.render(ctx)
  { image, diagnostics }
}

///|
/// Parse and render an SVG markup string into an Image.
pub fn render_svg_to_image(
  svg_str : String,
  width : Int,
  height : Int,
) -> Image? {
  parse_svg_document(svg_str).map(fn(doc) {
    render_svg_document(doc, width, height, RenderOptions::default()).image
  })
}

///|
/// Render PathCommand array directly to an Image (no SVG string parsing).
/// This is much faster than render_svg_to_image for programmatic paths
/// (e.g., font glyph outlines) because it skips SVG serialization and parsing.
///
/// `transform` is a 6-element affine transform [a, b, c, d, e, f] or empty for identity.
pub fn render_path_commands_to_image(
  commands : Array[PathCommand],
  width : Int,
  height : Int,
  fill_color : Color,
  transform? : Array[Double] = [],
) -> Image {
  let image = Image::new(width, height)
  if commands.is_empty() || width <= 0 || height <= 0 {
    return image
  }
  let tf = if transform.length() >= 6 {
    Transform::matrix(
      transform[0],
      transform[1],
      transform[2],
      transform[3],
      transform[4],
      transform[5],
    )
  } else {
    Transform::identity()
  }
  let contours = path_to_polylines(commands, device_path_flatness(tf)).map(fn(
    polyline,
  ) {
    polyline.map(fn(point) { tf.apply(point.0, point.1) })
  })
  raster_contours_coverage(
    contours,
    fill_color,
    NonZero,
    make_image_compositing_setter(image),
    width,
    height,
  )
  image
}
