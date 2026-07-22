// ============================================================================
// Filter Effects
// ============================================================================

///|
/// Filter types
pub(all) enum Filter {
  Blur(Double) // Blur radius
  DropShadow(Double, Double, Double, Color) // offsetX, offsetY, blur, color
  Brightness(Double) // Factor (1.0 = normal)
  Contrast(Double) // Factor (1.0 = normal)
  Grayscale(Double) // Amount (0.0-1.0)
  Sepia(Double) // Amount (0.0-1.0)
  HueRotate(Double) // Angle in degrees
  Invert(Double) // Amount (0.0-1.0)
  Saturate(Double) // Factor (1.0 = normal, 0.0 = grayscale, 2.0 = double)
  ColorMatrix(FixedArray[Double]) // 5x4 matrix (20 values) for feColorMatrix
}

///|
/// Apply blur filter to a region of pixels
fn apply_blur(
  pixels : Array[Array[Color]],
  radius : Int,
) -> Array[Array[Color]] {
  if radius <= 0 || pixels.is_empty() {
    return pixels
  }
  let height = pixels.length()
  let width = if height > 0 { pixels[0].length() } else { 0 }
  // Create output buffer
  let output : Array[Array[Color]] = []
  for _ in 0..<height {
    let row : Array[Color] = []
    for _ in 0..<width {
      row.push(Color::black())
    }
    output.push(row)
  }
  // Box blur (simplified)
  let kernel_size = radius * 2 + 1
  let div = kernel_size * kernel_size
  for y in 0..<height {
    for x in 0..<width {
      let mut r = 0
      let mut g = 0
      let mut b = 0
      let mut a = 0
      for ky in -radius..<=radius {
        for kx in -radius..<=radius {
          let sy = clamp_int(y + ky, 0, height - 1)
          let sx = clamp_int(x + kx, 0, width - 1)
          let c = pixels[sy][sx]
          r = r + c.r
          g = g + c.g
          b = b + c.b
          a = a + c.a
        }
      }
      output[y][x] = { r: r / div, g: g / div, b: b / div, a: a / div }
    }
  }
  output
}

///|
fn clamp_int(v : Int, min : Int, max : Int) -> Int {
  if v < min {
    min
  } else if v > max {
    max
  } else {
    v
  }
}

///|
/// Apply brightness filter to a color
fn apply_brightness(color : Color, factor : Double) -> Color {
  {
    r: clamp_int((color.r.to_double() * factor).to_int(), 0, 255),
    g: clamp_int((color.g.to_double() * factor).to_int(), 0, 255),
    b: clamp_int((color.b.to_double() * factor).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Apply grayscale filter to a color
fn apply_grayscale(color : Color, amount : Double) -> Color {
  let gray = (color.r.to_double() * 0.299 +
  color.g.to_double() * 0.587 +
  color.b.to_double() * 0.114).to_int()
  {
    r: lerp(color.r.to_double(), gray.to_double(), amount).to_int(),
    g: lerp(color.g.to_double(), gray.to_double(), amount).to_int(),
    b: lerp(color.b.to_double(), gray.to_double(), amount).to_int(),
    a: color.a,
  }
}

///|
/// Apply contrast filter to a color
fn apply_contrast(color : Color, factor : Double) -> Color {
  // Contrast formula: ((value - 128) * factor) + 128
  let r = ((color.r.to_double() - 128.0) * factor + 128.0).to_int()
  let g = ((color.g.to_double() - 128.0) * factor + 128.0).to_int()
  let b = ((color.b.to_double() - 128.0) * factor + 128.0).to_int()
  {
    r: clamp_int(r, 0, 255),
    g: clamp_int(g, 0, 255),
    b: clamp_int(b, 0, 255),
    a: color.a,
  }
}

///|
/// Apply sepia filter to a color
fn apply_sepia(color : Color, amount : Double) -> Color {
  // Sepia matrix coefficients
  let r = color.r.to_double()
  let g = color.g.to_double()
  let b = color.b.to_double()
  // Sepia tone calculation
  let sepia_r = r * 0.393 + g * 0.769 + b * 0.189
  let sepia_g = r * 0.349 + g * 0.686 + b * 0.168
  let sepia_b = r * 0.272 + g * 0.534 + b * 0.131
  // Interpolate between original and sepia
  {
    r: clamp_int(lerp(r, sepia_r, amount).to_int(), 0, 255),
    g: clamp_int(lerp(g, sepia_g, amount).to_int(), 0, 255),
    b: clamp_int(lerp(b, sepia_b, amount).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Apply hue rotation to a color
fn apply_hue_rotate(color : Color, angle_degrees : Double) -> Color {
  // Convert to radians
  let angle = angle_degrees * 3.14159265358979 / 180.0
  let cos_a = cos_approx(angle)
  let sin_a = sin_approx(angle)
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  // Hue rotation matrix (based on SVG spec)
  let matrix_00 = 0.213 + cos_a * 0.787 - sin_a * 0.213
  let matrix_01 = 0.715 - cos_a * 0.715 - sin_a * 0.715
  let matrix_02 = 0.072 - cos_a * 0.072 + sin_a * 0.928
  let matrix_10 = 0.213 - cos_a * 0.213 + sin_a * 0.143
  let matrix_11 = 0.715 + cos_a * 0.285 + sin_a * 0.140
  let matrix_12 = 0.072 - cos_a * 0.072 - sin_a * 0.283
  let matrix_20 = 0.213 - cos_a * 0.213 - sin_a * 0.787
  let matrix_21 = 0.715 - cos_a * 0.715 + sin_a * 0.715
  let matrix_22 = 0.072 + cos_a * 0.928 + sin_a * 0.072
  let new_r = r * matrix_00 + g * matrix_01 + b * matrix_02
  let new_g = r * matrix_10 + g * matrix_11 + b * matrix_12
  let new_b = r * matrix_20 + g * matrix_21 + b * matrix_22
  {
    r: clamp_int((new_r * 255.0).to_int(), 0, 255),
    g: clamp_int((new_g * 255.0).to_int(), 0, 255),
    b: clamp_int((new_b * 255.0).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Approximate cosine function
fn cos_approx(x : Double) -> Double {
  let pi = 3.14159265358979
  let pi2 = 6.28318530717959
  // Normalize to [0, 2π]
  let mut normalized = x
  while normalized < 0.0 {
    normalized = normalized + pi2
  }
  while normalized >= pi2 {
    normalized = normalized - pi2
  }
  // Reduce to [-π, π] for better Taylor accuracy
  if normalized > pi {
    normalized = normalized - pi2
  }
  // Taylor series approximation for cos (accurate near 0)
  let x2 = normalized * normalized
  let x4 = x2 * x2
  let x6 = x4 * x2
  let x8 = x4 * x4
  let x10 = x4 * x6
  1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0
}

///|
/// Approximate sine function
fn sin_approx(x : Double) -> Double {
  let pi = 3.14159265358979
  let pi2 = 6.28318530717959
  // Normalize to [0, 2π]
  let mut normalized = x
  while normalized < 0.0 {
    normalized = normalized + pi2
  }
  while normalized >= pi2 {
    normalized = normalized - pi2
  }
  // Reduce to [-π, π]
  if normalized > pi {
    normalized = normalized - pi2
  }
  // Taylor series for sin: x - x³/6 + x⁵/120 - x⁷/5040 + x⁹/362880
  let x2 = normalized * normalized
  let x3 = normalized * x2
  let x5 = x3 * x2
  let x7 = x5 * x2
  let x9 = x7 * x2
  normalized - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0 + x9 / 362880.0
}

///|
/// Apply invert filter to a color
fn apply_invert(color : Color, amount : Double) -> Color {
  let inv_r = 255 - color.r
  let inv_g = 255 - color.g
  let inv_b = 255 - color.b
  {
    r: lerp(color.r.to_double(), inv_r.to_double(), amount).to_int(),
    g: lerp(color.g.to_double(), inv_g.to_double(), amount).to_int(),
    b: lerp(color.b.to_double(), inv_b.to_double(), amount).to_int(),
    a: color.a,
  }
}

///|
/// Apply saturate filter to a color
fn apply_saturate(color : Color, factor : Double) -> Color {
  // Saturation matrix based on luminance
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  // Luminance coefficients
  let lum_r = 0.2126
  let lum_g = 0.7152
  let lum_b = 0.0722
  // Saturation matrix
  let sr = (1.0 - factor) * lum_r + factor
  let sg = (1.0 - factor) * lum_g
  let sb = (1.0 - factor) * lum_b
  let new_r = r * sr + g * sg + b * sb
  let new_g = r * ((1.0 - factor) * lum_r) +
    g * ((1.0 - factor) * lum_g + factor) +
    b * ((1.0 - factor) * lum_b)
  let new_b = r * ((1.0 - factor) * lum_r) +
    g * ((1.0 - factor) * lum_g) +
    b * ((1.0 - factor) * lum_b + factor)
  {
    r: clamp_int((new_r * 255.0).to_int(), 0, 255),
    g: clamp_int((new_g * 255.0).to_int(), 0, 255),
    b: clamp_int((new_b * 255.0).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Apply color matrix filter (feColorMatrix)
/// Matrix is 5x4 (20 values) in row-major order:
/// [R'] = [a00 a01 a02 a03 a04] [R]
/// [G'] = [a10 a11 a12 a13 a14] [G]
/// [B'] = [a20 a21 a22 a23 a24] [B]
/// [A'] = [a30 a31 a32 a33 a34] [A]
///                              [1]
fn apply_color_matrix(color : Color, matrix : FixedArray[Double]) -> Color {
  if matrix.length() != 20 {
    return color // Invalid matrix
  }
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  let a = color.a.to_double() / 255.0
  let new_r = r * matrix[0] +
    g * matrix[1] +
    b * matrix[2] +
    a * matrix[3] +
    matrix[4]
  let new_g = r * matrix[5] +
    g * matrix[6] +
    b * matrix[7] +
    a * matrix[8] +
    matrix[9]
  let new_b = r * matrix[10] +
    g * matrix[11] +
    b * matrix[12] +
    a * matrix[13] +
    matrix[14]
  let new_a = r * matrix[15] +
    g * matrix[16] +
    b * matrix[17] +
    a * matrix[18] +
    matrix[19]
  {
    r: clamp_int((new_r * 255.0).round().to_int(), 0, 255),
    g: clamp_int((new_g * 255.0).round().to_int(), 0, 255),
    b: clamp_int((new_b * 255.0).round().to_int(), 0, 255),
    a: clamp_int((new_a * 255.0).round().to_int(), 0, 255),
  }
}

///|
/// Apply drop shadow to an image and return new image with shadow
fn apply_drop_shadow(
  image : Image,
  offset_x : Int,
  offset_y : Int,
  blur_radius : Int,
  shadow_color : Color,
) -> Image {
  // Create output with extra space for shadow
  let max_offset = if offset_x.abs() > offset_y.abs() {
    offset_x.abs()
  } else {
    offset_y.abs()
  }
  let margin = blur_radius + max_offset
  let new_width = image.width + margin * 2
  let new_height = image.height + margin * 2
  let output = Image::new(new_width, new_height)
  // First, render the shadow (offset copy with color)
  for y in 0..<image.height {
    for x in 0..<image.width {
      let src_color = image.get_pixel(x, y)
      if src_color.a > 0 {
        let shadow_x = margin + x + offset_x
        let shadow_y = margin + y + offset_y
        if shadow_x >= 0 &&
          shadow_x < new_width &&
          shadow_y >= 0 &&
          shadow_y < new_height {
          // Use original alpha to modulate shadow
          let alpha = (shadow_color.a.to_double() *
          src_color.a.to_double() /
          255.0).to_int()
          output.set_pixel(shadow_x, shadow_y, { ..shadow_color, a: alpha })
        }
      }
    }
  }
  // Apply blur to shadow
  if blur_radius > 0 {
    output.apply_blur_in_place(blur_radius)
  }
  // Then overlay the original image on top
  for y in 0..<image.height {
    for x in 0..<image.width {
      let src_color = image.get_pixel(x, y)
      if src_color.a > 0 {
        let dst_x = margin + x
        let dst_y = margin + y
        // Alpha blend
        let bg = output.get_pixel(dst_x, dst_y)
        let blended = alpha_blend(src_color, bg)
        output.set_pixel(dst_x, dst_y, blended)
      }
    }
  }
  output
}

///|
/// Alpha blend foreground over background
fn alpha_blend(fg : Color, bg : Color) -> Color {
  let fg_a = fg.a.to_double() / 255.0
  let bg_a = bg.a.to_double() / 255.0
  let out_a = fg_a + bg_a * (1.0 - fg_a)
  if out_a < 0.001 {
    return Color::transparent()
  }
  let r = (fg.r.to_double() * fg_a + bg.r.to_double() * bg_a * (1.0 - fg_a)) /
    out_a
  let g = (fg.g.to_double() * fg_a + bg.g.to_double() * bg_a * (1.0 - fg_a)) /
    out_a
  let b = (fg.b.to_double() * fg_a + bg.b.to_double() * bg_a * (1.0 - fg_a)) /
    out_a
  Color::rgba(
    r.round().to_int(),
    g.round().to_int(),
    b.round().to_int(),
    (out_a * 255.0).round().to_int(),
  )
}

///|
/// Apply a filter to an image (returns new image)
fn apply_filter(image : Image, filter : Filter) -> Image {
  match filter {
    Blur(radius) => {
      let result = image.clone()
      result.apply_blur_in_place(radius.to_int())
      result
    }
    DropShadow(offset_x, offset_y, blur, color) =>
      apply_drop_shadow(
        image,
        offset_x.to_int(),
        offset_y.to_int(),
        blur.to_int(),
        color,
      )
    Brightness(factor) => {
      let result = image.clone()
      result.apply_brightness_in_place(factor)
      result
    }
    Contrast(factor) => {
      let result = image.clone()
      result.apply_contrast_in_place(factor)
      result
    }
    Grayscale(amount) => {
      let result = image.clone()
      result.apply_grayscale_in_place(amount)
      result
    }
    Sepia(amount) => {
      let result = image.clone()
      result.apply_sepia_in_place(amount)
      result
    }
    HueRotate(angle) => {
      let result = image.clone()
      result.apply_hue_rotate_in_place(angle)
      result
    }
    Invert(amount) => {
      let result = image.clone()
      result.apply_invert_in_place(amount)
      result
    }
    Saturate(factor) => {
      let result = image.clone()
      result.apply_saturate_in_place(factor)
      result
    }
    ColorMatrix(matrix) => {
      let result = image.clone()
      result.apply_color_matrix_in_place(matrix)
      result
    }
  }
}
