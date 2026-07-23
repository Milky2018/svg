///|
test "external stylesheet and imports resolve relative to their own resource" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: {
      ..RenderEnvironment::default(),
      base_uri: "mem:/documents/main.svg",
    },
    text_resource_resolver: Some(fn(uri, kind) {
      guard kind is Stylesheet else { return None }
      match uri {
        "mem:/styles/theme.css" =>
          Some("@import \"base.css\"; #target { fill: rgb(255 0 0); }")
        "mem:/styles/base.css" => Some("#target { fill: blue; }")
        _ => None
      }
    }),
  }
  let svg =
    #|<?xml-stylesheet type="text/css" href="../styles/theme.css"?>
    #|<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2">
    #|  <rect id="target" width="2" height="2"/>
    #|</svg>
  let result = render_svg(svg, 2, 2, options)
  inspect(result.diagnostics.length(), content="0")
  let pixel = result.image.get_pixel(1, 1)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
}

///|
test "static environment drives pseudo state and media queries" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: {
      ..RenderEnvironment::default(),
      color_scheme: Dark,
      device_pixel_ratio: 2.0,
      element_state_resolver: Some(fn(id) {
        if id == "target" {
          { ..ElementState::none(), hover: true }
        } else {
          ElementState::none()
        }
      }),
    },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2">
    #|  <style>
    #|    #target { fill: black; }
    #|    @media (prefers-color-scheme: dark) { #target { fill: blue; } }
    #|    #target:hover { fill: red; }
    #|  </style>
    #|  <rect id="target" width="2" height="2"/>
    #|</svg>
  let result = render_svg(svg, 2, 2, options)
  inspect(result.diagnostics.length(), content="0")
  let pixel = result.image.get_pixel(1, 1)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
}

///|
test "cyclic stylesheet import is diagnostic and bounded" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), base_uri: "mem:/main.svg" },
    text_resource_resolver: Some(fn(uri, kind) {
      guard kind is Stylesheet else { return None }
      match uri {
        "mem:/a.css" => Some("@import \"b.css\"; rect { fill: red; }")
        "mem:/b.css" => Some("@import \"a.css\";")
        _ => None
      }
    }),
  }
  let svg =
    #|<?xml-stylesheet href="a.css"?>
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">
    #|  <rect width="1" height="1"/>
    #|</svg>
  let result = render_svg(svg, 1, 1, options)
  inspect(
    result.diagnostics.any(fn(item) { item.kind is ResourceCycle }),
    content="true",
  )
  inspect(result.image.get_pixel(0, 0).r, content="255")
}
