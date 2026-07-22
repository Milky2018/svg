///|
test "raster filters interpolate premultiplied source pixels" {
  let image = Image::new(2, 1)
  image.set_pixel(0, 0, Color::rgba(255, 0, 0, 0))
  image.set_pixel(1, 0, Color::rgb(0, 0, 255))
  let nearest = sample_raster_color(image, 1.0, 0.5, Nearest, false)
  inspect(nearest.b, content="255")
  inspect(nearest.a, content="255")
  let bilinear = sample_raster_color(image, 1.0, 0.5, Bilinear, false)
  inspect(bilinear.r, content="0")
  inspect(bilinear.b, content="255")
  inspect(bilinear.a, content="128")
  let bicubic = sample_raster_color(image, 1.0, 0.5, Bicubic, false)
  inspect(bicubic.r, content="0")
  inspect(bicubic.b, content="255")
  inspect(bicubic.a > 0 && bicubic.a < 255, content="true")
}

///|
test "wrapped bilinear sampling is continuous at the pattern seam" {
  let image = Image::new(2, 1)
  image.set_pixel(0, 0, Color::rgb(255, 0, 0))
  image.set_pixel(1, 0, Color::rgb(0, 0, 255))
  let start = sample_raster_color(image, 0.0, 0.5, Bilinear, true)
  let end = sample_raster_color(image, 2.0, 0.5, Bilinear, true)
  inspect(start.r, content="128")
  inspect(start.g, content="0")
  inspect(start.b, content="128")
  inspect(start.a, content="255")
  inspect(start.r == end.r && start.b == end.b, content="true")
}
