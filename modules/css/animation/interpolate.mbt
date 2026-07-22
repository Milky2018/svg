///|
/// Computed-value interpolation for CSS animations.
///
/// CSS animations interpolate *computed values*; the result is later resolved
/// to a used value by the layout engine (exactly like a static computed value).
/// This module therefore stays layout-independent: it interpolates already
/// computed values (px lengths, percentages, numbers, colors) and leaves
/// used-value resolution (% -> px, `auto`, intrinsic sizing) to the consumer.

///|
/// A computed value that can take part in animation interpolation. Anything not
/// representable here (or interpolated between mismatched kinds) animates
/// discretely (a 50% jump).
pub(all) enum AnimatableValue {
  Number(Double)
  Length(Double) // px
  Percent(Double) // ratio: 0.5 == 50%
  Color(@values.Color)
  Transform(@style.Transform)
  /// Non-interpolable / unsupported computed value; animates discretely.
  Discrete(String)
} derive(Eq)

///|
pub impl Show for AnimatableValue with fn output(self, logger) {
  match self {
    Number(v) => logger.write_string("Number(\{v})")
    Length(v) => logger.write_string("Length(\{v})")
    Percent(v) => logger.write_string("Percent(\{v})")
    Color(c) => {
      logger.write_string("Color(")
      c.output(logger)
      logger.write_string(")")
    }
    Transform(t) => {
      logger.write_string("Transform(")
      t.output(logger)
      logger.write_string(")")
    }
    Discrete(s) => logger.write_string("Discrete(\{s})")
  }
}

///|
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
  a : @values.Color,
  b : @values.Color,
  t : Double,
) -> @values.Color {
  @values.Color::rgba(
    lerp_channel(a.r, b.r, t),
    lerp_channel(a.g, b.g, t),
    lerp_channel(a.b, b.b, t),
    lerp(a.a, b.a, t),
  )
}

///|
/// Interpolate between two computed values at eased progress `t` in [0, 1].
/// Matching numeric kinds interpolate linearly; colors interpolate in sRGB;
/// any mismatched or non-interpolable pair animates discretely (jumps at 0.5).
pub fn interpolate(
  from : AnimatableValue,
  to : AnimatableValue,
  t : Double,
) -> AnimatableValue {
  match (from, to) {
    (Number(a), Number(b)) => Number(lerp(a, b, t))
    (Length(a), Length(b)) => Length(lerp(a, b, t))
    (Percent(a), Percent(b)) => Percent(lerp(a, b, t))
    (Color(a), Color(b)) => Color(interpolate_color(a, b, t))
    (Transform(a), Transform(b)) =>
      match interpolate_transform(a, b, t) {
        Some(tr) => Transform(tr)
        None => if t < 0.5 { from } else { to }
      }
    _ => if t < 0.5 { from } else { to }
  }
}

///|
/// Interpolate one `translate` component (px length or percentage). Mismatched
/// kinds (length vs percentage) cannot interpolate without a box basis, so they
/// animate discretely.
fn interpolate_translate(
  a : @style.TranslateValue,
  b : @style.TranslateValue,
  t : Double,
) -> @style.TranslateValue {
  match (a, b) {
    (@style.TranslateValue::Length(x), @style.TranslateValue::Length(y)) =>
      @style.TranslateValue::Length(lerp(x, y, t))
    (@style.TranslateValue::Percent(x), @style.TranslateValue::Percent(y)) =>
      @style.TranslateValue::Percent(lerp(x, y, t))
    _ => if t < 0.5 { a } else { b }
  }
}

///|
/// Interpolate two transforms component-wise at the computed-value level
/// (translate / scale / rotate / skew). Two explicit `matrix()` transforms are
/// interpolated component-wise. A mismatch between a matrix and a decomposed
/// transform returns None (the caller animates discretely) — full matrix
/// decomposition is a later phase.
fn interpolate_transform(
  a : @style.Transform,
  b : @style.Transform,
  t : Double,
) -> @style.Transform? {
  // 3D matrices interpolate via 3D decompose / quaternion slerp / recompose.
  // A matrix3d mixed with a non-matrix3d transform falls back to discrete.
  if a.has_matrix3d() || b.has_matrix3d() {
    if a.has_matrix3d() && b.has_matrix3d() {
      match interpolate_matrix3d(a.matrix3d, b.matrix3d, t) {
        Some(m) =>
          return Some({
            ..@style.Transform::none(),
            has_matrix: true,
            matrix_a: m[0],
            matrix_b: m[1],
            matrix_c: m[4],
            matrix_d: m[5],
            matrix_e: m[12],
            matrix_f: m[13],
            matrix3d: m,
          })
        None => return None
      }
    }
    return None
  }
  // Per spec, mismatched transforms are decomposed and interpolated. Here a
  // matrix() operand is decomposed to the (translate, scale, rotate, skew) form
  // so it can interpolate component-wise with the other operand (including the
  // both-matrices case, which a naive component lerp would get wrong for
  // rotation).
  let da = if a.has_matrix { decompose_2d(a) } else { a }
  let db = if b.has_matrix { decompose_2d(b) } else { b }
  Some({
    ..da,
    translate_x: interpolate_translate(da.translate_x, db.translate_x, t),
    translate_y: interpolate_translate(da.translate_y, db.translate_y, t),
    scale_x: lerp(da.scale_x, db.scale_x, t),
    scale_y: lerp(da.scale_y, db.scale_y, t),
    rotate_degrees: lerp(da.rotate_degrees, db.rotate_degrees, t),
    skew_x_degrees: lerp(da.skew_x_degrees, db.skew_x_degrees, t),
    skew_y_degrees: lerp(da.skew_y_degrees, db.skew_y_degrees, t),
  })
}

///|
/// Decompose a 2D affine `matrix(a,b,c,d,e,f)` transform into the
/// (translate, scale, rotate, skewX) form (the "unmatrix" 2D algorithm), so it
/// can interpolate component-wise. skewY is not separately recoverable from a 2D
/// matrix and is reported as 0.
fn decompose_2d(m : @style.Transform) -> @style.Transform {
  let mut row0x = m.matrix_a
  let mut row0y = m.matrix_b
  let mut row1x = m.matrix_c
  let mut row1y = m.matrix_d
  let det = row0x * row1y - row0y * row1x
  let mut scale_x = (row0x * row0x + row0y * row0y).sqrt()
  if scale_x == 0.0 {
    // Degenerate first row; nothing meaningful to decompose.
    return {
      ..@style.Transform::none(),
      translate_x: @style.TranslateValue::Length(m.matrix_e),
      translate_y: @style.TranslateValue::Length(m.matrix_f),
    }
  }
  row0x = row0x / scale_x
  row0y = row0y / scale_x
  let mut shear = row0x * row1x + row0y * row1y
  row1x = row1x - row0x * shear
  row1y = row1y - row0y * shear
  let scale_y = (row1x * row1x + row1y * row1y).sqrt()
  if scale_y != 0.0 {
    row1x = row1x / scale_y
    row1y = row1y / scale_y
    shear = shear / scale_y
  }
  // A negative determinant means a reflection; fold it into scale_x.
  if det < 0.0 {
    scale_x = -scale_x
    row0x = -row0x
    row0y = -row0y
  }
  let deg = 180.0 / @math.PI
  {
    ..@style.Transform::none(),
    translate_x: @style.TranslateValue::Length(m.matrix_e),
    translate_y: @style.TranslateValue::Length(m.matrix_f),
    scale_x,
    scale_y,
    rotate_degrees: @math.atan2(row0y, row0x) * deg,
    skew_x_degrees: @math.atan(shear) * deg,
    skew_y_degrees: 0.0,
  }
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
pub fn interpolate_color_oklab(
  a : @values.Color,
  b : @values.Color,
  t : Double,
) -> @values.Color {
  let (l1, a1, b1) = srgb_to_oklab(a)
  let (l2, a2, b2) = srgb_to_oklab(b)
  let (r, g, bl) = oklab_to_srgb(
    lerp(l1, l2, t),
    lerp(a1, a2, t),
    lerp(b1, b2, t),
  )
  @values.Color::rgba(r, g, bl, lerp(a.a, b.a, t))
}

///|
fn srgb_to_oklab(c : @values.Color) -> (Double, Double, Double) {
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
pub(all) enum ColorSpace {
  Srgb
  Oklab
  Oklch
  Lab
  Lch
} derive(Debug, Eq)

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
pub fn interpolate_color_in(
  space : ColorSpace,
  a : @values.Color,
  b : @values.Color,
  t : Double,
) -> @values.Color {
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
      @values.Color::rgba(r, g, bl, alpha)
    }
    Oklch => {
      let (l1, c1, h1) = srgb_to_oklch(a)
      let (l2, c2, h2) = srgb_to_oklch(b)
      let (oa, ob) = lch_to_ab(lerp(c1, c2, t), lerp_hue(h1, h2, t))
      let (r, g, bl) = oklab_to_srgb(lerp(l1, l2, t), oa, ob)
      @values.Color::rgba(r, g, bl, alpha)
    }
    Lch => {
      let (l1, c1, h1) = srgb_to_lch(a)
      let (l2, c2, h2) = srgb_to_lch(b)
      let (la, lb) = lch_to_ab(lerp(c1, c2, t), lerp_hue(h1, h2, t))
      let (r, g, bl) = lab_to_srgb(lerp(l1, l2, t), la, lb)
      @values.Color::rgba(r, g, bl, alpha)
    }
  }
}

///|
/// Convert a rectangular (a, b) pair from a chroma/hue (hue in radians).
fn lch_to_ab(c : Double, h : Double) -> (Double, Double) {
  (c * @math.cos(h), c * @math.sin(h))
}

///|
fn srgb_to_oklch(col : @values.Color) -> (Double, Double, Double) {
  let (l, a, b) = srgb_to_oklab(col)
  (l, (a * a + b * b).sqrt(), @math.atan2(b, a))
}

///|
/// sRGB color to CIE Lab (D65).
fn srgb_to_lab(col : @values.Color) -> (Double, Double, Double) {
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
fn srgb_to_lch(col : @values.Color) -> (Double, Double, Double) {
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

///|
/// One typed keyframe: an offset in [0, 1], the computed value at that offset,
/// and the easing governing interpolation *to* the next keyframe.
pub(all) struct AnimatableKeyframe {
  offset : Double
  value : AnimatableValue
  easing : @values.Easing
}

///|
pub fn AnimatableKeyframe::new(
  offset : Double,
  value : AnimatableValue,
) -> AnimatableKeyframe {
  { offset, value, easing: @values.Easing::Linear }
}

///|
pub fn AnimatableKeyframe::with_easing(
  offset : Double,
  value : AnimatableValue,
  easing : @values.Easing,
) -> AnimatableKeyframe {
  { offset, value, easing }
}

///|
/// A typed keyframe effect: keyframes (sorted by offset) plus timing. Mirrors
/// `NumericKeyframeEffect` but interpolates `AnimatableValue` computed values.
pub(all) struct AnimatableKeyframeEffect {
  keyframes : Array[AnimatableKeyframe]
  timing : EffectTiming
}

///|
/// Build a typed keyframe effect. Returns None if there are no keyframes.
/// Keyframes are assumed to be sorted by non-decreasing offset.
pub fn AnimatableKeyframeEffect::new(
  keyframes : Array[AnimatableKeyframe],
  timing : EffectTiming,
) -> AnimatableKeyframeEffect? {
  if keyframes.length() == 0 {
    None
  } else {
    Some({ keyframes, timing })
  }
}

///|
/// Sample the computed value at normalized progress `progress` in [0, 1] within
/// one iteration. Values before the first / after the last keyframe clamp to the
/// endpoint value.
pub fn AnimatableKeyframeEffect::sample_progress(
  self : AnimatableKeyframeEffect,
  progress : Double,
) -> AnimatableValue {
  let kfs = self.keyframes
  let p = if progress < 0.0 {
    0.0
  } else if progress > 1.0 {
    1.0
  } else {
    progress
  }
  let first = kfs[0]
  if p <= first.offset {
    return first.value
  }
  let last = kfs[kfs.length() - 1]
  if p >= last.offset {
    return last.value
  }
  for i = 0; i < kfs.length() - 1; i = i + 1 {
    let start = kfs[i]
    let end = kfs[i + 1]
    if p >= start.offset && p <= end.offset {
      let span = end.offset - start.offset
      if span <= 0.0 {
        // Coincident offsets: jump to the later keyframe's value.
        return end.value
      }
      let local_progress = (p - start.offset) / span
      let eased = start.easing.sample(local_progress)
      return interpolate(start.value, end.value, eased)
    }
  }
  last.value
}

///|
/// Sample the computed value at `local_time` (ms on the effect's local
/// timeline). Returns None when the timing model produces no active value
/// (e.g. a non-filled before/after phase).
pub fn AnimatableKeyframeEffect::sample(
  self : AnimatableKeyframeEffect,
  local_time : Double,
) -> AnimatableValue? {
  let computed = self.timing.at(local_time)
  match computed.transformed_progress {
    Some(p) => Some(self.sample_progress(p))
    None => None
  }
}
