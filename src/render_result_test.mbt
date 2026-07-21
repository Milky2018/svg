///|
test "detailed rendering reports parse failures" {
  let result = render_svg("", 4, 4, RenderOptions::default())
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].kind is ParseFailed, content="true")
  inspect(result.diagnostics[0].stage is Document, content="true")
}

///|
test "detailed rendering reports unresolved raster images" {
  let result = render_svg(
    "<svg width=\"4\" height=\"4\"><image href=\"missing.png\" width=\"4\" height=\"4\"/></svg>",
    4,
    4,
    RenderOptions::default(),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].kind is ResourceUnresolved, content="true")
  inspect(result.diagnostics[0].stage is Image, content="true")
  inspect(result.diagnostics[0].resource, content="missing.png")
}

///|
test "detailed rendering accepts a resolved raster image" {
  let options = RenderOptions::{
    image_resolver: Some(fn(href) {
      if href == "asset.png" {
        let image = Image::new(1, 1)
        image.set_pixel(0, 0, Color::rgb(255, 0, 0))
        Some(image)
      } else {
        None
      }
    }),
  }
  let result = render_svg(
    "<svg width=\"4\" height=\"4\"><image href=\"asset.png\" width=\"4\" height=\"4\"/></svg>",
    4, 4, options,
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.image.get_pixel(2, 2).r, content="255")
}
