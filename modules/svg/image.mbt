// ============================================================================
// Image Support
// ============================================================================

///|
/// Image data (RGBA pixels)
pub struct Image {
  priv width : Int
  priv height : Int
  priv pixels : Array[Color] // Row-major order
}

///|
/// Create a new image with specified dimensions
pub fn Image::new(width : Int, height : Int) -> Image {
  let width = if width < 0 { 0 } else { width }
  let height = if height < 0 { 0 } else { height }
  let total = width * height
  let pixels = Array::make(total, Color::transparent())
  { width, height, pixels }
}

///|
/// Create an image filled with a color
pub fn Image::filled(width : Int, height : Int, color : Color) -> Image {
  let width = if width < 0 { 0 } else { width }
  let height = if height < 0 { 0 } else { height }
  let total = width * height
  let pixels = Array::make(total, color)
  { width, height, pixels }
}

///|
/// Create an image from row-major RGBA pixels when dimensions match exactly.
pub fn Image::from_pixels(
  width : Int,
  height : Int,
  source : Array[Color],
) -> Image? {
  if width < 0 || height < 0 || source.length() != width * height {
    return None
  }
  let pixels : Array[Color] = []
  for color in source {
    pixels.push(color)
  }
  Some({ width, height, pixels })
}

///|
pub fn Image::width(self : Image) -> Int {
  self.width
}

///|
pub fn Image::height(self : Image) -> Int {
  self.height
}

///|
/// Get pixel at coordinates
pub fn Image::get_pixel(self : Image, x : Int, y : Int) -> Color {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    return Color::transparent()
  }
  self.pixels[y * self.width + x]
}

///|
/// Set pixel at coordinates
pub fn Image::set_pixel(self : Image, x : Int, y : Int, color : Color) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.pixels[y * self.width + x] = color
  }
}

///|
/// Clone the image
fn Image::clone(self : Image) -> Image {
  let pixels : Array[Color] = []
  for i in 0..<self.pixels.length() {
    pixels.push(self.pixels[i])
  }
  { width: self.width, height: self.height, pixels }
}

///|
/// Apply blur filter in place
fn Image::apply_blur_in_place(self : Image, radius : Int) -> Unit {
  if radius <= 0 {
    return
  }
  // Convert to 2D array for processing
  let rows : Array[Array[Color]] = []
  for y in 0..<self.height {
    let row : Array[Color] = []
    for x in 0..<self.width {
      row.push(self.get_pixel(x, y))
    }
    rows.push(row)
  }
  let blurred = apply_blur(rows, radius)
  // Copy back
  for y in 0..<self.height {
    for x in 0..<self.width {
      self.set_pixel(x, y, blurred[y][x])
    }
  }
}

///|
/// Apply brightness filter in place
fn Image::apply_brightness_in_place(self : Image, factor : Double) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_brightness(self.pixels[i], factor)
  }
}

///|
/// Apply contrast filter in place
fn Image::apply_contrast_in_place(self : Image, factor : Double) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_contrast(self.pixels[i], factor)
  }
}

///|
/// Apply grayscale filter in place
fn Image::apply_grayscale_in_place(self : Image, amount : Double) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_grayscale(self.pixels[i], amount)
  }
}

///|
/// Apply sepia filter in place
fn Image::apply_sepia_in_place(self : Image, amount : Double) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_sepia(self.pixels[i], amount)
  }
}

///|
/// Apply hue rotate filter in place
fn Image::apply_hue_rotate_in_place(
  self : Image,
  angle_degrees : Double,
) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_hue_rotate(self.pixels[i], angle_degrees)
  }
}

///|
/// Apply invert filter in place
fn Image::apply_invert_in_place(self : Image, amount : Double) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_invert(self.pixels[i], amount)
  }
}

///|
/// Apply saturate filter in place
fn Image::apply_saturate_in_place(self : Image, factor : Double) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_saturate(self.pixels[i], factor)
  }
}

///|
/// Apply color matrix filter in place
fn Image::apply_color_matrix_in_place(
  self : Image,
  matrix : FixedArray[Double],
) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = apply_color_matrix(self.pixels[i], matrix)
  }
}
