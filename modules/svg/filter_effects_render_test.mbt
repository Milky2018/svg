///|
fn render_filter_fixture(svg : String, width : Int, height : Int) -> Image {
  render_svg_to_image(svg, width, height).unwrap_or(Image::new(width, height))
}

///|
test "empty filter suppresses its host while a missing filter is ignored" {
  let self_closing = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"4\"><defs><filter id=\"f\"/></defs><rect width=\"4\" height=\"4\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    4, 4,
  )
  let explicit_close = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"4\"><defs><filter id=\"f\"></filter></defs><rect width=\"4\" height=\"4\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    4, 4,
  )
  let missing = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"4\"><rect width=\"4\" height=\"4\" fill=\"red\" filter=\"url(#missing)\"/></svg>",
    4, 4,
  )
  inspect(self_closing.get_pixel(2, 2).a, content="0")
  inspect(explicit_close.get_pixel(2, 2).a, content="0")
  inspect(missing.get_pixel(2, 2).r, content="255")
  inspect(missing.get_pixel(2, 2).a, content="255")
}

///|
test "filter Gaussian blur supports separate horizontal and vertical deviations" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"><defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"8\" height=\"8\"><feGaussianBlur stdDeviation=\"0 1\"/></filter></defs><rect x=\"3\" y=\"3\" width=\"1\" height=\"1\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    8, 8,
  )
  inspect(image.get_pixel(3, 2).a > 0, content="true")
  inspect(image.get_pixel(2, 3).a, content="0")
}

///|
test "filter flood produces its color and opacity" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"><defs><filter id=\"f\"><feFlood flood-color=\"blue\" flood-opacity=\"0.5\"/></filter></defs><rect x=\"1\" y=\"1\" width=\"6\" height=\"6\" filter=\"url(#f)\"/></svg>",
    8, 8,
  )
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="255")
  inspect(pixel.a, content="128")
}

///|
test "filter merge consumes nested merge nodes in order" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"><defs><filter id=\"f\"><feFlood flood-color=\"red\" result=\"red\"/><feMerge><feMergeNode in=\"red\"/><feMergeNode in=\"SourceGraphic\"/></feMerge></filter></defs><rect width=\"8\" height=\"8\" fill=\"blue\" filter=\"url(#f)\"/></svg>",
    8, 8,
  )
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.b, content="255")
}

///|
test "filter component transfer parses per-channel functions" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"4\"><defs><filter id=\"f\"><feComponentTransfer><feFuncR type=\"linear\" slope=\"0\"/><feFuncG type=\"table\" tableValues=\"0 1\"/><feFuncB type=\"discrete\" tableValues=\"0 1\"/></feComponentTransfer></filter></defs><rect width=\"4\" height=\"4\" fill=\"rgb(255,128,255)\" filter=\"url(#f)\"/></svg>",
    4, 4,
  )
  let pixel = image.get_pixel(2, 2)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="128")
  inspect(pixel.b, content="255")
  inspect(pixel.a, content="255")
}

///|
test "filter morphology dilates through transparent pixels" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"><defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"8\" height=\"8\"><feMorphology operator=\"dilate\" radius=\"1\"/></filter></defs><rect x=\"3\" y=\"3\" width=\"1\" height=\"1\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    8, 8,
  )
  inspect(image.get_pixel(2, 3).a, content="255")
  inspect(image.get_pixel(1, 3).a, content="0")
}

///|
test "filter convolve matrix identity preserves pixels" {
  let filtered = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"6\" height=\"6\"><defs><filter id=\"f\"><feConvolveMatrix order=\"3\" kernelMatrix=\"0 0 0 0 1 0 0 0 0\"/></filter></defs><rect x=\"1\" y=\"1\" width=\"4\" height=\"4\" fill=\"#2468ac\" filter=\"url(#f)\"/></svg>",
    6, 6,
  )
  let plain = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"6\" height=\"6\"><rect x=\"1\" y=\"1\" width=\"4\" height=\"4\" fill=\"#2468ac\"/></svg>",
    6, 6,
  )
  inspect(image_difference_count(filtered, plain), content="0")
}

///|
test "filter displacement map samples the requested channel" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"4\"><defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"8\" height=\"4\"><feFlood flood-color=\"white\" result=\"map\"/><feDisplacementMap in=\"SourceGraphic\" in2=\"map\" scale=\"2\" xChannelSelector=\"R\" yChannelSelector=\"A\"/></filter></defs><rect x=\"1\" y=\"1\" width=\"2\" height=\"2\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    8, 4,
  )
  inspect(image.get_pixel(0, 1).a, content="255")
  inspect(image.get_pixel(1, 1).a, content="255")
  inspect(image.get_pixel(2, 1).a, content="0")
}

///|
test "filter turbulence creates deterministic opaque variation" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"><defs><filter id=\"f\"><feTurbulence baseFrequency=\"0.2 0.3\" numOctaves=\"2\" seed=\"7\"/></filter></defs><rect width=\"8\" height=\"8\" filter=\"url(#f)\"/></svg>",
    8, 8,
  )
  inspect(image.get_pixel(2, 2).a, content="255")
  inspect(image.get_pixel(2, 2).r != image.get_pixel(5, 5).r, content="true")
}

///|
test "filter tile repeats the non-transparent input bounds" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"4\"><defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"8\" height=\"4\"><feTile/></filter></defs><rect width=\"2\" height=\"2\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    8, 4,
  )
  inspect(image.get_pixel(6, 3).a, content="255")
}

///|
test "filter primitive object bounding box units scale offsets" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><defs><filter id=\"f\" primitiveUnits=\"objectBoundingBox\" x=\"-100%\" width=\"300%\"><feOffset dx=\"0.5\"/></filter></defs><rect x=\"2\" y=\"1\" width=\"4\" height=\"4\" fill=\"red\" filter=\"url(#f)\"/></svg>",
    10, 6,
  )
  inspect(image.get_pixel(2, 2).a, content="0")
  inspect(image.get_pixel(4, 2).a, content="255")
}

///|
test "filter image uses the host image resolver" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"6\" height=\"6\"><defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"6\" height=\"6\"><feImage href=\"asset.png\" x=\"2\" y=\"2\" width=\"2\" height=\"2\"/></filter></defs><rect width=\"6\" height=\"6\" filter=\"url(#f)\"/></svg>"
  let image = render_svg(
      svg,
      6,
      6,
      RenderOptions::with_image_resolver(fn(href) {
        if href == "asset.png" {
          Some(Image::filled(1, 1, Color::rgb(0, 255, 0)))
        } else {
          None
        }
      }),
    ).image
  inspect(image.get_pixel(2, 2).g, content="255")
  inspect(image.get_pixel(1, 2).a, content="0")
}

///|
test "filter lighting parses nested distant lights" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"6\" height=\"6\"><defs><filter id=\"f\"><feDiffuseLighting lighting-color=\"yellow\" diffuseConstant=\"1\"><feDistantLight azimuth=\"0\" elevation=\"90\"/></feDiffuseLighting></filter></defs><rect width=\"6\" height=\"6\" fill=\"white\" filter=\"url(#f)\"/></svg>",
    6, 6,
  )
  let pixel = image.get_pixel(3, 3)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="255")
  inspect(pixel.b, content="0")
  inspect(pixel.a, content="255")
}

///|
test "filter specular lighting emits color-derived alpha" {
  let image = render_filter_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"6\" height=\"6\"><defs><filter id=\"f\"><feSpecularLighting lighting-color=\"red\" specularConstant=\"1\" specularExponent=\"1\"><feDistantLight azimuth=\"0\" elevation=\"90\"/></feSpecularLighting></filter></defs><rect width=\"6\" height=\"6\" fill=\"white\" filter=\"url(#f)\"/></svg>",
    6, 6,
  )
  let pixel = image.get_pixel(3, 3)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
  inspect(pixel.a, content="255")
}
