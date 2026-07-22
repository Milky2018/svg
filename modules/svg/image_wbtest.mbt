///|
test "image creation" {
  let img = Image::new(10, 10)
  inspect(img.width, content="10")
  inspect(img.height, content="10")
  inspect(img.pixels.length(), content="100")
  // Default pixel is transparent
  let p = img.get_pixel(0, 0)
  inspect(p.a, content="0")
}

///|
test "image filled" {
  let red = Color::rgb(255, 0, 0)
  let img = Image::filled(5, 5, red)
  let p = img.get_pixel(2, 2)
  inspect(p.r, content="255")
  inspect(p.g, content="0")
  inspect(p.b, content="0")
}

///|
test "image set and get pixel" {
  let img = Image::new(10, 10)
  let blue = Color::rgb(0, 0, 255)
  img.set_pixel(5, 5, blue)
  let p = img.get_pixel(5, 5)
  inspect(p.b, content="255")
  // Out of bounds returns transparent
  let out = img.get_pixel(-1, 0)
  inspect(out.a, content="0")
}
