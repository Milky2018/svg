///|
test "external use keeps its document-scoped paint resources" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: {
      ..RenderEnvironment::default(),
      base_uri: "mem:/documents/main.svg",
    },
    text_resource_resolver: Some(fn(uri, kind) {
      guard kind is SvgDocument else { return None }
      if uri == "mem:/assets/icons.svg" {
        Some(
          (
            #|<svg xmlns="http://www.w3.org/2000/svg">
            #|  <defs>
            #|    <linearGradient id="paint">
            #|      <stop offset="0" stop-color="red"/>
            #|      <stop offset="1" stop-color="red"/>
            #|    </linearGradient>
            #|    <g id="tile"><rect width="4" height="4" fill="url(#paint)"/></g>
            #|  </defs>
            #|</svg>
          ),
        )
      } else {
        None
      }
    }),
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4">
    #|  <use href="../assets/icons.svg#tile"/>
    #|</svg>
  let result = render_svg(svg, 4, 4, options)
  inspect(result.diagnostics.length(), content="0")
  let pixel = result.image.get_pixel(2, 2)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
}

///|
test "external paint and clip resources use qualified ids" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), base_uri: "mem:/main.svg", },
    text_resource_resolver: Some(fn(uri, kind) {
      guard kind is SvgDocument else { return None }
      if uri == "mem:/resources.svg" {
        Some(
          (
            #|<svg xmlns="http://www.w3.org/2000/svg">
            #|  <defs>
            #|    <linearGradient id="paint">
            #|      <stop offset="0" stop-color="blue"/>
            #|      <stop offset="1" stop-color="blue"/>
            #|    </linearGradient>
            #|    <clipPath id="left"><rect width="2" height="4"/></clipPath>
            #|  </defs>
            #|</svg>
          ),
        )
      } else {
        None
      }
    }),
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4">
    #|  <rect width="4" height="4"
    #|        fill="url(resources.svg#paint)"
    #|        clip-path="url(resources.svg#left)"/>
    #|</svg>
  let result = render_svg(svg, 4, 4, options)
  inspect(result.diagnostics.length(), content="0")
  inspect(result.image.get_pixel(1, 2).b, content="255")
  inspect(result.image.get_pixel(3, 2).a, content="0")
}
