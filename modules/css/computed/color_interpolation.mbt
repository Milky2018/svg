///|
/// Color interpolation used by static CSS Color functions.
///
/// These helpers belong to computed-value evaluation rather than to an
/// animation runtime. Rectangular spaces interpolate channels linearly; polar
/// spaces interpolate hue along the shortest arc.
fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
/// Round to the nearest integer and clamp to the 0-255 color-channel range.
fn lerp_channel(a : Int, b : Int, t : Double) -> Int {
  let v = lerp(a.to_double(), b.to_double(), t)
  let r = (v + 0.5).to_int()
  if r < 0 {
    0
  } else if r > 255 {
    255
  } else {
    r
  }
}

///|
/// Interpolate two colors in sRGB. Alpha is interpolated linearly.
fn interpolate_color(
  a : @types.Color,
  b : @types.Color,
  t : Double,
) -> @types.Color {
  @types.Color::rgba(
    lerp_channel(a.r, b.r, t),
    lerp_channel(a.g, b.g, t),
    lerp_channel(a.b, b.b, t),
    lerp(a.a, b.a, t),
  )
}
// ---- Oklab color interpolation (CSS Color 4) ----

///|
/// sRGB 0-255 channel to linear-light [0, 1].
fn srgb_to_linear(c : Int) -> Double {
  let x = c.to_double() / 255.0
  if x <= 0.04045 {
    x / 12.92
  } else {
    @math.pow((x + 0.055) / 1.055, 2.4)
  }
}

///|
/// Linear-light [0, 1] to sRGB 0-255 channel (rounded, clamped).
fn linear_to_srgb(x : Double) -> Int {
  let c = if x <= 0.0031308 {
    12.92 * x
  } else {
    1.055 * @math.pow(x, 1.0 / 2.4) - 0.055
  }
  let v = (c * 255.0 + 0.5).to_int()
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
/// Interpolate two colors in the Oklab color space (CSS Color 4 default for
/// `<color>` interpolation). Alpha is interpolated linearly in [0, 1].
fn interpolate_color_oklab(
  a : @types.Color,
  b : @types.Color,
  t : Double,
) -> @types.Color {
  let (l1, a1, b1) = srgb_to_oklab(a)
  let (l2, a2, b2) = srgb_to_oklab(b)
  let (r, g, bl) = oklab_to_srgb(
    lerp(l1, l2, t),
    lerp(a1, a2, t),
    lerp(b1, b2, t),
  )
  @types.Color::rgba(r, g, bl, lerp(a.a, b.a, t))
}

///|
fn srgb_to_oklab(c : @types.Color) -> (Double, Double, Double) {
  let r = srgb_to_linear(c.r)
  let g = srgb_to_linear(c.g)
  let b = srgb_to_linear(c.b)
  let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
  let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
  let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
  let l_ = @math.cbrt(l)
  let m_ = @math.cbrt(m)
  let s_ = @math.cbrt(s)
  (
    0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
  )
}

///|
fn oklab_to_srgb(l : Double, a : Double, b : Double) -> (Int, Int, Int) {
  let l_ = l + 0.3963377774 * a + 0.2158037573 * b
  let m_ = l - 0.1055613458 * a - 0.0638541728 * b
  let s_ = l - 0.0894841775 * a - 1.2914855480 * b
  let l3 = l_ * l_ * l_
  let m3 = m_ * m_ * m_
  let s3 = s_ * s_ * s_
  let r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
  let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
  let bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
  (linear_to_srgb(r), linear_to_srgb(g), linear_to_srgb(bl))
}

// ---- Additional color spaces (CSS Color 4): oklch, lab, lch ----

///|
/// Color space used for `<color>` interpolation.
priv enum ColorInterpolationSpace {
  Srgb
  Oklab
  Oklch
  Lab
  Lch
}

///|
/// Interpolate a hue (radians) along the shortest arc.
fn lerp_hue(h1 : Double, h2 : Double, t : Double) -> Double {
  let two_pi = 2.0 * @math.PI
  let mut dh = h2 - h1
  while dh > @math.PI {
    dh = dh - two_pi
  }
  while dh < -@math.PI {
    dh = dh + two_pi
  }
  h1 + dh * t
}

///|
/// Interpolate two colors in the given color space. Rectangular spaces (srgb,
/// oklab, lab) interpolate channels linearly; polar spaces (oklch, lch)
/// interpolate lightness/chroma linearly and hue along the shortest arc. Alpha
/// is always interpolated linearly.
fn interpolate_color_in(
  space : ColorInterpolationSpace,
  a : @types.Color,
  b : @types.Color,
  t : Double,
) -> @types.Color {
  let alpha = lerp(a.a, b.a, t)
  match space {
    Srgb => interpolate_color(a, b, t)
    Oklab => interpolate_color_oklab(a, b, t)
    Lab => {
      let (l1, a1, b1) = srgb_to_lab(a)
      let (l2, a2, b2) = srgb_to_lab(b)
      let (r, g, bl) = lab_to_srgb(
        lerp(l1, l2, t),
        lerp(a1, a2, t),
        lerp(b1, b2, t),
      )
      @types.Color::rgba(r, g, bl, alpha)
    }
    Oklch => {
      let (l1, c1, h1) = srgb_to_oklch(a)
      let (l2, c2, h2) = srgb_to_oklch(b)
      let (oa, ob) = lch_to_ab(lerp(c1, c2, t), lerp_hue(h1, h2, t))
      let (r, g, bl) = oklab_to_srgb(lerp(l1, l2, t), oa, ob)
      @types.Color::rgba(r, g, bl, alpha)
    }
    Lch => {
      let (l1, c1, h1) = srgb_to_lch(a)
      let (l2, c2, h2) = srgb_to_lch(b)
      let (la, lb) = lch_to_ab(lerp(c1, c2, t), lerp_hue(h1, h2, t))
      let (r, g, bl) = lab_to_srgb(lerp(l1, l2, t), la, lb)
      @types.Color::rgba(r, g, bl, alpha)
    }
  }
}

///|
/// Convert a rectangular (a, b) pair from a chroma/hue (hue in radians).
fn lch_to_ab(c : Double, h : Double) -> (Double, Double) {
  (c * @math.cos(h), c * @math.sin(h))
}

///|
fn srgb_to_oklch(col : @types.Color) -> (Double, Double, Double) {
  let (l, a, b) = srgb_to_oklab(col)
  (l, (a * a + b * b).sqrt(), @math.atan2(b, a))
}

///|
/// sRGB color to CIE Lab (D65).
fn srgb_to_lab(col : @types.Color) -> (Double, Double, Double) {
  let r = srgb_to_linear(col.r)
  let g = srgb_to_linear(col.g)
  let b = srgb_to_linear(col.b)
  let x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
  let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
  let z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
  let xn = 0.95047
  let yn = 1.0
  let zn = 1.08883
  let fx = lab_f(x / xn)
  let fy = lab_f(y / yn)
  let fz = lab_f(z / zn)
  (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))
}

///|
fn srgb_to_lch(col : @types.Color) -> (Double, Double, Double) {
  let (l, a, b) = srgb_to_lab(col)
  (l, (a * a + b * b).sqrt(), @math.atan2(b, a))
}

///|
fn lab_f(t : Double) -> Double {
  let eps = 216.0 / 24389.0
  if t > eps {
    @math.cbrt(t)
  } else {
    (24389.0 / 27.0 * t + 16.0) / 116.0
  }
}

///|
/// CIE Lab (D65) to sRGB 0-255.
fn lab_to_srgb(l : Double, a : Double, b : Double) -> (Int, Int, Int) {
  let fy = (l + 16.0) / 116.0
  let fx = fy + a / 500.0
  let fz = fy - b / 200.0
  let eps = 216.0 / 24389.0
  let kappa = 24389.0 / 27.0
  let fx3 = fx * fx * fx
  let fz3 = fz * fz * fz
  let xr = if fx3 > eps { fx3 } else { (116.0 * fx - 16.0) / kappa }
  let yr = if l > kappa * eps { fy * fy * fy } else { l / kappa }
  let zr = if fz3 > eps { fz3 } else { (116.0 * fz - 16.0) / kappa }
  let x = xr * 0.95047
  let y = yr * 1.0
  let z = zr * 1.08883
  let r = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
  let g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
  let bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z
  (linear_to_srgb(r), linear_to_srgb(g), linear_to_srgb(bl))
}
