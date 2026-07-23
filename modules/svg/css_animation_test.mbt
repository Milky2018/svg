///|
test "explicit sample time interpolates SVG geometry, color, and opacity" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), sample_time_seconds: 1.0 },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="10" height="2">
    #|  <style>
    #|    @keyframes move {
    #|      from { x: 0; fill: red; opacity: 0.2; }
    #|      to { x: 8px; fill: blue; opacity: 1; }
    #|    }
    #|    #target { animation: move 2s linear forwards; }
    #|  </style>
    #|  <rect id="target" width="2" height="2"/>
    #|</svg>
  let result = render_svg(svg, 10, 2, options)
  inspect(result.diagnostics.length(), content="0")
  inspect(result.image.get_pixel(1, 1).a, content="0")
  let pixel = result.image.get_pixel(4, 1)
  inspect(pixel.r, content="128")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="128")
  inspect(pixel.a, content="153")
}

///|
test "animation direction and forwards fill are sampled deterministically" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), sample_time_seconds: 3.0 },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="10" height="1">
    #|  <style>
    #|    @keyframes move { from { x: 0; } to { x: 8px; } }
    #|    rect { animation: move 1s linear 2 alternate forwards; }
    #|  </style>
    #|  <rect width="2" height="1" fill="red"/>
    #|</svg>
  let result = render_svg(svg, 10, 1, options)
  // Two alternate iterations finish back at the authored start.
  inspect(result.image.get_pixel(0, 0).r, content="255")
  inspect(result.image.get_pixel(8, 0).a, content="0")
}

///|
test "backwards fill applies before a positive delay" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), sample_time_seconds: 0.0 },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="4" height="1">
    #|  <style>
    #|    @keyframes appear { from { fill: red; } to { fill: blue; } }
    #|    rect { animation: appear 1s 2s backwards; }
    #|  </style>
    #|  <rect width="4" height="1" fill="black"/>
    #|</svg>
  let result = render_svg(svg, 4, 1, options)
  let pixel = result.image.get_pixel(2, 0)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
}

///|
test "animation origin stays below important author declarations" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), sample_time_seconds: 0.5 },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="2" height="1">
    #|  <style>
    #|    @keyframes color { from { fill: red; } to { fill: blue; } }
    #|    rect { animation: color 1s linear forwards; fill: green !important; }
    #|  </style>
    #|  <rect width="2" height="1"/>
    #|</svg>
  let pixel = render_svg(svg, 2, 1, options).image.get_pixel(1, 0)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="128")
  inspect(pixel.b, content="0")
}

///|
test "paused animation has a deterministic zero hold time" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), sample_time_seconds: 10.0 },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="2" height="1">
    #|  <style>
    #|    @keyframes color { from { fill: red; } to { fill: blue; } }
    #|    rect { animation: color 1s linear paused both; }
    #|  </style>
    #|  <rect width="2" height="1"/>
    #|</svg>
  let pixel = render_svg(svg, 2, 1, options).image.get_pixel(1, 0)
  inspect(pixel.r, content="255")
  inspect(pixel.b, content="0")
}

///|
test "steps timing is applied within a keyframe interval" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: { ..RenderEnvironment::default(), sample_time_seconds: 0.5 },
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="10" height="1">
    #|  <style>
    #|    @keyframes move { from { x: 0; } to { x: 8px; } }
    #|    rect { animation: move 1s steps(1, end) forwards; }
    #|  </style>
    #|  <rect width="2" height="1" fill="red"/>
    #|</svg>
  let result = render_svg(svg, 10, 1, options)
  inspect(result.image.get_pixel(0, 0).r, content="255")
  inspect(result.image.get_pixel(8, 0).a, content="0")
}
