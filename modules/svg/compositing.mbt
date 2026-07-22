// ============================================================================
// Blend Modes (mix-blend-mode / isolation)
// ============================================================================

///|
/// CSS mix-blend-mode values
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  ColorMode // 'color' in CSS
  Luminosity
} derive(Debug, Eq)

///|
/// CSS isolation values
pub(all) enum Isolation {
  Auto
  Isolate
} derive(Debug, Eq)

///|
/// Blend two colors using the specified blend mode
fn blend_with_mode(backdrop : Color, source : Color, mode : BlendMode) -> Color {
  let bd_r = backdrop.r.to_double() / 255.0
  let bd_g = backdrop.g.to_double() / 255.0
  let bd_b = backdrop.b.to_double() / 255.0
  let bd_a = backdrop.a.to_double() / 255.0
  let src_r = source.r.to_double() / 255.0
  let src_g = source.g.to_double() / 255.0
  let src_b = source.b.to_double() / 255.0
  let src_a = source.a.to_double() / 255.0
  // Apply blend mode to RGB
  let (blended_r, blended_g, blended_b) = match mode {
    Normal => (src_r, src_g, src_b)
    Multiply => (bd_r * src_r, bd_g * src_g, bd_b * src_b)
    Screen =>
      (
        1.0 - (1.0 - bd_r) * (1.0 - src_r),
        1.0 - (1.0 - bd_g) * (1.0 - src_g),
        1.0 - (1.0 - bd_b) * (1.0 - src_b),
      )
    Overlay =>
      (
        blend_overlay_channel(bd_r, src_r),
        blend_overlay_channel(bd_g, src_g),
        blend_overlay_channel(bd_b, src_b),
      )
    Darken =>
      (
        if bd_r < src_r {
          bd_r
        } else {
          src_r
        },
        if bd_g < src_g {
          bd_g
        } else {
          src_g
        },
        if bd_b < src_b {
          bd_b
        } else {
          src_b
        },
      )
    Lighten =>
      (
        if bd_r > src_r {
          bd_r
        } else {
          src_r
        },
        if bd_g > src_g {
          bd_g
        } else {
          src_g
        },
        if bd_b > src_b {
          bd_b
        } else {
          src_b
        },
      )
    ColorDodge =>
      (
        blend_color_dodge_channel(bd_r, src_r),
        blend_color_dodge_channel(bd_g, src_g),
        blend_color_dodge_channel(bd_b, src_b),
      )
    ColorBurn =>
      (
        blend_color_burn_channel(bd_r, src_r),
        blend_color_burn_channel(bd_g, src_g),
        blend_color_burn_channel(bd_b, src_b),
      )
    HardLight =>
      (
        blend_overlay_channel(src_r, bd_r), // HardLight is Overlay with args swapped
        blend_overlay_channel(src_g, bd_g),
        blend_overlay_channel(src_b, bd_b),
      )
    SoftLight =>
      (
        blend_soft_light_channel(bd_r, src_r),
        blend_soft_light_channel(bd_g, src_g),
        blend_soft_light_channel(bd_b, src_b),
      )
    Difference =>
      ((bd_r - src_r).abs(), (bd_g - src_g).abs(), (bd_b - src_b).abs())
    Exclusion =>
      (
        bd_r + src_r - 2.0 * bd_r * src_r,
        bd_g + src_g - 2.0 * bd_g * src_g,
        bd_b + src_b - 2.0 * bd_b * src_b,
      )
    Hue => blend_hue(bd_r, bd_g, bd_b, src_r, src_g, src_b)
    Saturation => blend_saturation(bd_r, bd_g, bd_b, src_r, src_g, src_b)
    ColorMode => blend_color_mode(bd_r, bd_g, bd_b, src_r, src_g, src_b)
    Luminosity => blend_luminosity(bd_r, bd_g, bd_b, src_r, src_g, src_b)
  }
  // W3C compositing and blending formula in premultiplied form.
  let out_a = src_a + bd_a * (1.0 - src_a)
  if out_a < 0.001 {
    return Color::transparent()
  }
  let out_r = (
      src_a * (1.0 - bd_a) * src_r +
      src_a * bd_a * blended_r +
      (1.0 - src_a) * bd_a * bd_r
    ) /
    out_a
  let out_g = (
      src_a * (1.0 - bd_a) * src_g +
      src_a * bd_a * blended_g +
      (1.0 - src_a) * bd_a * bd_g
    ) /
    out_a
  let out_b = (
      src_a * (1.0 - bd_a) * src_b +
      src_a * bd_a * blended_b +
      (1.0 - src_a) * bd_a * bd_b
    ) /
    out_a
  Color::rgba(
    clamp_int((out_r * 255.0).round().to_int(), 0, 255),
    clamp_int((out_g * 255.0).round().to_int(), 0, 255),
    clamp_int((out_b * 255.0).round().to_int(), 0, 255),
    clamp_int((out_a * 255.0).round().to_int(), 0, 255),
  )
}

///|
/// Overlay blend for a single channel
fn blend_overlay_channel(backdrop : Double, source : Double) -> Double {
  if backdrop < 0.5 {
    2.0 * backdrop * source
  } else {
    1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
  }
}

///|
/// Color dodge blend for a single channel
fn blend_color_dodge_channel(backdrop : Double, source : Double) -> Double {
  if backdrop < 0.001 {
    0.0
  } else if source >= 0.999 {
    1.0
  } else {
    let result = backdrop / (1.0 - source)
    if result > 1.0 {
      1.0
    } else {
      result
    }
  }
}

///|
/// Color burn blend for a single channel
fn blend_color_burn_channel(backdrop : Double, source : Double) -> Double {
  if backdrop >= 0.999 {
    1.0
  } else if source < 0.001 {
    0.0
  } else {
    let result = 1.0 - (1.0 - backdrop) / source
    if result < 0.0 {
      0.0
    } else {
      result
    }
  }
}

///|
/// Soft light blend for a single channel
fn blend_soft_light_channel(backdrop : Double, source : Double) -> Double {
  if source <= 0.5 {
    backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop)
  } else {
    let d = if backdrop <= 0.25 {
      ((16.0 * backdrop - 12.0) * backdrop + 4.0) * backdrop
    } else {
      sqrt_approx(backdrop)
    }
    backdrop + (2.0 * source - 1.0) * (d - backdrop)
  }
}

///|
/// Approximate square root
fn sqrt_approx(x : Double) -> Double {
  if x < 0.0 {
    return 0.0
  }
  // Newton-Raphson iteration
  let mut guess = x / 2.0
  if guess < 0.001 {
    guess = 0.001
  }
  for _ in 0..<10 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

///|
/// Convert RGB to HSL
fn rgb_to_hsl(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let max_val = if r > g {
    if r > b {
      r
    } else {
      b
    }
  } else if g > b {
    g
  } else {
    b
  }
  let min_val = if r < g {
    if r < b {
      r
    } else {
      b
    }
  } else if g < b {
    g
  } else {
    b
  }
  let l = (max_val + min_val) / 2.0
  if max_val - min_val < 0.001 {
    return (0.0, 0.0, l) // Achromatic
  }
  let d = max_val - min_val
  let s = if l > 0.5 {
    d / (2.0 - max_val - min_val)
  } else {
    d / (max_val + min_val)
  }
  let h = if max_val - r < 0.001 {
    let h_raw = (g - b) / d
    if g < b {
      h_raw + 6.0
    } else {
      h_raw
    }
  } else if max_val - g < 0.001 {
    (b - r) / d + 2.0
  } else {
    (r - g) / d + 4.0
  }
  (h / 6.0, s, l)
}

///|
/// Convert HSL to RGB
fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Double, Double, Double) {
  if s < 0.001 {
    return (l, l, l)
  }
  let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s }
  let p = 2.0 * l - q
  (
    hue_to_rgb(p, q, h + 1.0 / 3.0),
    hue_to_rgb(p, q, h),
    hue_to_rgb(p, q, h - 1.0 / 3.0),
  )
}

///|
fn hue_to_rgb(p : Double, q : Double, t_raw : Double) -> Double {
  let mut t = t_raw
  if t < 0.0 {
    t = t + 1.0
  }
  if t > 1.0 {
    t = t - 1.0
  }
  if t < 1.0 / 6.0 {
    return p + (q - p) * 6.0 * t
  }
  if t < 0.5 {
    return q
  }
  if t < 2.0 / 3.0 {
    return p + (q - p) * (2.0 / 3.0 - t) * 6.0
  }
  p
}

///|
/// Get luminosity of RGB
fn get_luminosity(r : Double, g : Double, b : Double) -> Double {
  0.3 * r + 0.59 * g + 0.11 * b
}

///|
/// Set luminosity of RGB
fn set_luminosity(
  r : Double,
  g : Double,
  b : Double,
  target_lum : Double,
) -> (Double, Double, Double) {
  let current_lum = get_luminosity(r, g, b)
  let d = target_lum - current_lum
  clip_color(r + d, g + d, b + d)
}

///|
/// Clip color to valid range
fn clip_color(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let lum = get_luminosity(r, g, b)
  let min_val = if r < g {
    if r < b {
      r
    } else {
      b
    }
  } else if g < b {
    g
  } else {
    b
  }
  let max_val = if r > g {
    if r > b {
      r
    } else {
      b
    }
  } else if g > b {
    g
  } else {
    b
  }
  let mut out_r = r
  let mut out_g = g
  let mut out_b = b
  if min_val < 0.0 && lum - min_val > 0.001 {
    let factor = lum / (lum - min_val)
    out_r = lum + (out_r - lum) * factor
    out_g = lum + (out_g - lum) * factor
    out_b = lum + (out_b - lum) * factor
  }
  if max_val > 1.0 && max_val - lum > 0.001 {
    let factor = (1.0 - lum) / (max_val - lum)
    out_r = lum + (out_r - lum) * factor
    out_g = lum + (out_g - lum) * factor
    out_b = lum + (out_b - lum) * factor
  }
  (out_r, out_g, out_b)
}

///|
/// Hue blend mode
fn blend_hue(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  let (src_h, _, _) = rgb_to_hsl(src_r, src_g, src_b)
  let (_, bd_s, bd_l) = rgb_to_hsl(bd_r, bd_g, bd_b)
  let (r, g, b) = hsl_to_rgb(src_h, bd_s, bd_l)
  set_luminosity(r, g, b, get_luminosity(bd_r, bd_g, bd_b))
}

///|
/// Saturation blend mode
fn blend_saturation(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  let (bd_h, _, bd_l) = rgb_to_hsl(bd_r, bd_g, bd_b)
  let (_, src_s, _) = rgb_to_hsl(src_r, src_g, src_b)
  let (r, g, b) = hsl_to_rgb(bd_h, src_s, bd_l)
  set_luminosity(r, g, b, get_luminosity(bd_r, bd_g, bd_b))
}

///|
/// Color blend mode
fn blend_color_mode(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  let (src_h, src_s, _) = rgb_to_hsl(src_r, src_g, src_b)
  let (_, _, bd_l) = rgb_to_hsl(bd_r, bd_g, bd_b)
  let (r, g, b) = hsl_to_rgb(src_h, src_s, bd_l)
  set_luminosity(r, g, b, get_luminosity(bd_r, bd_g, bd_b))
}

///|
/// Luminosity blend mode
fn blend_luminosity(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  set_luminosity(bd_r, bd_g, bd_b, get_luminosity(src_r, src_g, src_b))
}

///|
/// Blend two images using the specified blend mode
fn blend_images(backdrop : Image, source : Image, mode : BlendMode) -> Image {
  let width = if backdrop.width < source.width {
    backdrop.width
  } else {
    source.width
  }
  let height = if backdrop.height < source.height {
    backdrop.height
  } else {
    source.height
  }
  let result = Image::new(width, height)
  for y in 0..<height {
    for x in 0..<width {
      let bd_color = backdrop.get_pixel(x, y)
      let src_color = source.get_pixel(x, y)
      let blended = blend_with_mode(bd_color, src_color, mode)
      result.set_pixel(x, y, blended)
    }
  }
  result
}
