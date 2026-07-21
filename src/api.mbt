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
  let image = Image::new(width, height)
  let diagnostics : Array[RenderDiagnostic] = []
  match parse_svg_document(svg_str) {
    Some(doc) => {
      let setter = make_image_compositing_setter(image)
      let ctx = {
        ..RenderState::new(setter, width, height),
        image_resolver: options.image_resolver,
        target_image: Some(image),
        diagnostics,
      }
      doc.render(ctx)
    }
    None =>
      diagnostics.push({
        kind: ParseFailed,
        stage: Document,
        resource: "",
        node_id: "",
      })
  }
  { image, diagnostics }
}

///|
/// Render an SVGDocument into an Image.
pub fn render_svg_document_to_image(
  doc : SVGDocument,
  width : Int,
  height : Int,
) -> Image {
  let image = Image::new(width, height)
  let setter = make_image_compositing_setter(image)
  let ctx = {
    ..RenderState::new(setter, width, height),
    target_image: Some(image),
  }
  doc.render(ctx)
  image
}

///|
/// Render an SVGDocument using a host callback for external image references.
pub fn render_svg_document_to_image_with_resolver(
  doc : SVGDocument,
  width : Int,
  height : Int,
  image_resolver : (String) -> Image?,
) -> Image {
  let image = Image::new(width, height)
  let setter = make_image_compositing_setter(image)
  let ctx = {
    ..RenderState::new(setter, width, height).with_image_resolver(
      image_resolver,
    ),
    target_image: Some(image),
  }
  doc.render(ctx)
  image
}

///|
/// Render a Scene into an Image.
pub fn render_svg_scene_to_image(
  scene : Scene,
  width : Int,
  height : Int,
) -> Image {
  let image = Image::new(width, height)
  let setter = make_image_compositing_setter(image)
  let ctx = {
    ..RenderState::new(setter, width, height),
    target_image: Some(image),
  }
  scene.render(ctx)
  image
}

///|
/// Render a Scene using a host callback for external image references.
pub fn render_svg_scene_to_image_with_resolver(
  scene : Scene,
  width : Int,
  height : Int,
  image_resolver : (String) -> Image?,
) -> Image {
  let image = Image::new(width, height)
  let setter = make_image_compositing_setter(image)
  let ctx = {
    ..RenderState::new(setter, width, height).with_image_resolver(
      image_resolver,
    ),
    target_image: Some(image),
  }
  scene.render(ctx)
  image
}

///|
/// Render a raw SVGNode tree into an Image.
pub fn render_svg_node_to_image(
  node : SVGNode,
  width : Int,
  height : Int,
) -> Image {
  let scene = Scene::new(node)
  render_svg_scene_to_image(scene, width, height)
}

///|
/// Render a raw SVGNode using a host callback for external image references.
pub fn render_svg_node_to_image_with_resolver(
  node : SVGNode,
  width : Int,
  height : Int,
  image_resolver : (String) -> Image?,
) -> Image {
  let scene = Scene::new(node)
  render_svg_scene_to_image_with_resolver(scene, width, height, image_resolver)
}

///|
/// Parse and render an SVG markup string into an Image.
pub fn render_svg_to_image(
  svg_str : String,
  width : Int,
  height : Int,
) -> Image? {
  parse_svg_document(svg_str).map(fn(doc) {
    render_svg_document_to_image(doc, width, height)
  })
}

///|
/// Parse and render SVG markup using a host callback for image references.
pub fn render_svg_to_image_with_resolver(
  svg_str : String,
  width : Int,
  height : Int,
  image_resolver : (String) -> Image?,
) -> Image? {
  parse_svg_document(svg_str).map(fn(doc) {
    render_svg_document_to_image_with_resolver(
      doc, width, height, image_resolver,
    )
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
