///|
/// Working color spaces used by internal rendering surfaces.
#warnings("-unused_constructor-unused_value")
priv enum WorkingColorSpace {
  SRGB
  LinearRGB
} derive(Eq)

///|
/// A premultiplied RGBA color with channels in the range 0...65535.
#warnings("-unused_value")
priv struct PremulColor16 {
  r : Int
  g : Int
  b : Int
  a : Int
} derive(Eq)

///|
fn transparent_premul16() -> PremulColor16 {
  { r: 0, g: 0, b: 0, a: 0 }
}

///|
fn clamp_channel16(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 65535 {
    65535
  } else {
    value
  }
}

///|
fn round_div_nonnegative(value : Int64, divisor : Int64) -> Int {
  ((value + divisor / 2L) / divisor).to_int()
}

///|
fn multiply_channel16(left : Int, right : Int) -> Int {
  round_div_nonnegative(left.to_int64() * right.to_int64(), 65535L)
}

///|
fn unit_to_channel16(value : Double) -> Int {
  let clamped = if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
  (clamped * 65535.0 + 0.5).floor().to_int()
}

///|
fn channel16_to_byte(value : Int) -> Int {
  round_div_nonnegative(clamp_channel16(value).to_int64(), 257L)
}

///|
#warnings("-unused_value")
fn PremulColor16::from_color(color : Color) -> PremulColor16 {
  let alpha = clamp_channel16(color.a * 257)
  {
    r: multiply_channel16(clamp_channel16(color.r * 257), alpha),
    g: multiply_channel16(clamp_channel16(color.g * 257), alpha),
    b: multiply_channel16(clamp_channel16(color.b * 257), alpha),
    a: alpha,
  }
}

///|
#warnings("-unused_value")
fn PremulColor16::to_color(self : PremulColor16) -> Color {
  if self.a <= 0 {
    return Color::transparent()
  }
  let alpha = clamp_channel16(self.a)
  let unpremultiply = fn(channel : Int) {
    let straight = round_div_nonnegative(
      clamp_channel16(channel).to_int64() * 65535L,
      alpha.to_int64(),
    )
    channel16_to_byte(straight)
  }
  Color::rgba(
    unpremultiply(self.r),
    unpremultiply(self.g),
    unpremultiply(self.b),
    channel16_to_byte(alpha),
  )
}

///|
#warnings("-unused_value")
fn PremulColor16::scaled(self : PremulColor16, factor : Int) -> PremulColor16 {
  let factor = clamp_channel16(factor)
  {
    r: multiply_channel16(self.r, factor),
    g: multiply_channel16(self.g, factor),
    b: multiply_channel16(self.b, factor),
    a: multiply_channel16(self.a, factor),
  }
}

///|
fn PremulColor16::source_over(
  self : PremulColor16,
  backdrop : PremulColor16,
) -> PremulColor16 {
  let inverse_alpha = 65535 - clamp_channel16(self.a)
  {
    r: clamp_channel16(self.r + multiply_channel16(backdrop.r, inverse_alpha)),
    g: clamp_channel16(self.g + multiply_channel16(backdrop.g, inverse_alpha)),
    b: clamp_channel16(self.b + multiply_channel16(backdrop.b, inverse_alpha)),
    a: clamp_channel16(self.a + multiply_channel16(backdrop.a, inverse_alpha)),
  }
}

///|
fn srgb_to_linear_unit(value : Double) -> Double {
  if value <= 0.04045 {
    value / 12.92
  } else {
    @math.pow((value + 0.055) / 1.055, 2.4)
  }
}

///|
fn linear_to_srgb_unit(value : Double) -> Double {
  if value <= 0.0031308 {
    value * 12.92
  } else {
    1.055 * @math.pow(value, 1.0 / 2.4) - 0.055
  }
}

///|
fn PremulColor16::convert_space(
  self : PremulColor16,
  from : WorkingColorSpace,
  to : WorkingColorSpace,
) -> PremulColor16 {
  if from == to || self.a <= 0 {
    return self
  }
  let alpha = clamp_channel16(self.a)
  let convert = fn(channel : Int) {
    let straight = clamp_channel16(channel).to_double() / alpha.to_double()
    let converted = match (from, to) {
      (SRGB, LinearRGB) => srgb_to_linear_unit(straight)
      (LinearRGB, SRGB) => linear_to_srgb_unit(straight)
      _ => straight
    }
    multiply_channel16(unit_to_channel16(converted), alpha)
  }
  { r: convert(self.r), g: convert(self.g), b: convert(self.b), a: alpha }
}

///|
/// A tight rectangular rendering surface addressed in device coordinates.
priv struct RenderSurface {
  mut origin_x : Int
  mut origin_y : Int
  width : Int
  height : Int
  color_space : WorkingColorSpace
  pixels : Array[PremulColor16]
}

///|
fn RenderSurface::new(
  origin_x : Int,
  origin_y : Int,
  width : Int,
  height : Int,
  color_space : WorkingColorSpace,
) -> RenderSurface {
  let width = if width < 0 { 0 } else { width }
  let height = if height < 0 { 0 } else { height }
  {
    origin_x,
    origin_y,
    width,
    height,
    color_space,
    pixels: Array::make(width * height, transparent_premul16()),
  }
}

///|
fn RenderSurface::contains_device(
  self : RenderSurface,
  x : Int,
  y : Int,
) -> Bool {
  x >= self.origin_x &&
  x < self.origin_x + self.width &&
  y >= self.origin_y &&
  y < self.origin_y + self.height
}

///|
fn RenderSurface::index_device(self : RenderSurface, x : Int, y : Int) -> Int {
  (y - self.origin_y) * self.width + (x - self.origin_x)
}

///|
#warnings("-unused_value")
fn RenderSurface::get_device(
  self : RenderSurface,
  x : Int,
  y : Int,
) -> PremulColor16 {
  if self.contains_device(x, y) {
    self.pixels[self.index_device(x, y)]
  } else {
    transparent_premul16()
  }
}

///|
#warnings("-unused_value")
fn RenderSurface::set_device(
  self : RenderSurface,
  x : Int,
  y : Int,
  color : PremulColor16,
) -> Unit {
  if self.contains_device(x, y) {
    self.pixels[self.index_device(x, y)] = color
  }
}

///|
#warnings("-unused_value")
fn RenderSurface::composite_device(
  self : RenderSurface,
  x : Int,
  y : Int,
  source : PremulColor16,
) -> Unit {
  if self.contains_device(x, y) {
    let index = self.index_device(x, y)
    self.pixels[index] = source.source_over(self.pixels[index])
  }
}

///|
fn RenderSurface::clear(self : RenderSurface) -> Unit {
  let transparent = transparent_premul16()
  for index in 0..<self.pixels.length() {
    self.pixels[index] = transparent
  }
}

///|
fn RenderSurface::to_image(self : RenderSurface) -> Image {
  let image = Image::new(self.width, self.height)
  for local_y in 0..<self.height {
    for local_x in 0..<self.width {
      image.set_pixel(
        local_x,
        local_y,
        self.pixels[local_y * self.width + local_x].to_color(),
      )
    }
  }
  image
}

///|
fn RenderSurface::replace_from_image(
  self : RenderSurface,
  image : Image,
) -> Unit {
  self.clear()
  let width = min_int(self.width, image.width)
  let height = min_int(self.height, image.height)
  for local_y in 0..<height {
    for local_x in 0..<width {
      self.pixels[local_y * self.width + local_x] = PremulColor16::from_color(
        image.get_pixel(local_x, local_y),
      )
    }
  }
}

///|
fn RenderSurface::apply_opacity(self : RenderSurface, opacity : Double) -> Unit {
  let factor = unit_to_channel16(opacity)
  for index in 0..<self.pixels.length() {
    self.pixels[index] = self.pixels[index].scaled(factor)
  }
}

///|
#warnings("-unused_value")
fn RenderSurface::convert_space(
  self : RenderSurface,
  color_space : WorkingColorSpace,
) -> RenderSurface {
  let result = RenderSurface::new(
    self.origin_x,
    self.origin_y,
    self.width,
    self.height,
    color_space,
  )
  for index in 0..<self.pixels.length() {
    result.pixels[index] = self.pixels[index].convert_space(
      self.color_space,
      color_space,
    )
  }
  result
}

///|
/// A bounded per-render cache for reusable intermediate surfaces.
priv struct RenderSurfacePool {
  available : Array[RenderSurface]
  max_surfaces : Int
}

///|
#warnings("-unused_value")
fn RenderSurfacePool::new(max_surfaces? : Int = 8) -> RenderSurfacePool {
  {
    available: [],
    max_surfaces: if max_surfaces < 0 {
      0
    } else {
      max_surfaces
    },
  }
}

///|
#warnings("-unused_value")
fn RenderSurfacePool::acquire(
  self : RenderSurfacePool,
  origin_x : Int,
  origin_y : Int,
  width : Int,
  height : Int,
  color_space : WorkingColorSpace,
) -> RenderSurface {
  for index in 0..<self.available.length() {
    let candidate = self.available[index]
    if candidate.width == width &&
      candidate.height == height &&
      candidate.color_space == color_space {
      let surface = self.available.remove(index)
      surface.origin_x = origin_x
      surface.origin_y = origin_y
      surface.clear()
      return surface
    }
  }
  RenderSurface::new(origin_x, origin_y, width, height, color_space)
}

///|
#warnings("-unused_value")
fn RenderSurfacePool::release(
  self : RenderSurfacePool,
  surface : RenderSurface,
) -> Unit {
  if self.available.length() < self.max_surfaces {
    surface.clear()
    self.available.push(surface)
  }
}
