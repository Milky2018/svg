///|
/// 3D matrix (`matrix3d()`) interpolation: decompose each 4x4 into translation,
/// scale, skew and a rotation quaternion, interpolate (linearly, with quaternion
/// slerp for rotation), then recompose. Follows the css-transforms-2 "decompose
/// / recompose a 3D matrix" algorithm. Perspective is assumed absent (the common
/// case for animated matrix3d); a matrix carrying perspective is normalized and
/// its perspective component dropped.
///
/// Matrices are 16-element column-major arrays: element (column c, row r) is at
/// index c * 4 + r.

///|
priv struct Decomposed3D {
  translation : Array[Double] // [x, y, z]
  scale : Array[Double] // [x, y, z]
  skew : Array[Double] // [xy, xz, yz]
  quaternion : Array[Double] // [x, y, z, w]
}

///|
fn v3_length(v : Array[Double]) -> Double {
  (v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).sqrt()
}

///|
fn v3_scale(v : Array[Double], s : Double) -> Array[Double] {
  [v[0] * s, v[1] * s, v[2] * s]
}

///|
fn v3_dot(a : Array[Double], b : Array[Double]) -> Double {
  a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

///|
fn v3_cross(a : Array[Double], b : Array[Double]) -> Array[Double] {
  [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ]
}

///|
/// `dest + src * scale`, component-wise (the "combine" helper from the spec).
fn v3_combine(
  dest : Array[Double],
  src : Array[Double],
  scale : Double,
) -> Array[Double] {
  [dest[0] + src[0] * scale, dest[1] + src[1] * scale, dest[2] + src[2] * scale]
}

///|
fn m_get(m : Array[Double], c : Int, r : Int) -> Double {
  m[c * 4 + r]
}

///|
/// Decompose an affine (perspective-free) 4x4 column-major matrix.
fn decompose_matrix3d(m : Array[Double]) -> Decomposed3D? {
  let w = m_get(m, 3, 3)
  if w == 0.0 {
    return None
  }
  // Normalize so element (3,3) is 1.
  let n = m.map(fn(x) { x / w })
  let translation = [m_get(n, 3, 0), m_get(n, 3, 1), m_get(n, 3, 2)]
  let mut col0 = [m_get(n, 0, 0), m_get(n, 0, 1), m_get(n, 0, 2)]
  let mut col1 = [m_get(n, 1, 0), m_get(n, 1, 1), m_get(n, 1, 2)]
  let mut col2 = [m_get(n, 2, 0), m_get(n, 2, 1), m_get(n, 2, 2)]
  let mut sx = v3_length(col0)
  col0 = v3_scale(col0, 1.0 / sx)
  let mut skew_xy = v3_dot(col0, col1)
  col1 = v3_combine(col1, col0, -skew_xy)
  let mut sy = v3_length(col1)
  col1 = v3_scale(col1, 1.0 / sy)
  skew_xy = skew_xy / sy
  let mut skew_xz = v3_dot(col0, col2)
  col2 = v3_combine(col2, col0, -skew_xz)
  let mut skew_yz = v3_dot(col1, col2)
  col2 = v3_combine(col2, col1, -skew_yz)
  let mut sz = v3_length(col2)
  col2 = v3_scale(col2, 1.0 / sz)
  skew_xz = skew_xz / sz
  skew_yz = skew_yz / sz
  // If the determinant is negative, negate the matrix and the scales.
  if v3_dot(col0, v3_cross(col1, col2)) < 0.0 {
    sx = -sx
    sy = -sy
    sz = -sz
    col0 = v3_scale(col0, -1.0)
    col1 = v3_scale(col1, -1.0)
    col2 = v3_scale(col2, -1.0)
  }
  // Build the rotation quaternion from the orthonormal columns.
  let m00 = col0[0]
  let m01 = col0[1]
  let m02 = col0[2]
  let m10 = col1[0]
  let m11 = col1[1]
  let m12 = col1[2]
  let m20 = col2[0]
  let m21 = col2[1]
  let m22 = col2[2]
  let trace = m00 + m11 + m22
  let quaternion = if trace > 0.0 {
    let s = (trace + 1.0).sqrt() * 2.0
    [(m12 - m21) / s, (m20 - m02) / s, (m01 - m10) / s, 0.25 * s]
  } else if m00 > m11 && m00 > m22 {
    let s = (1.0 + m00 - m11 - m22).sqrt() * 2.0
    [0.25 * s, (m01 + m10) / s, (m20 + m02) / s, (m12 - m21) / s]
  } else if m11 > m22 {
    let s = (1.0 + m11 - m00 - m22).sqrt() * 2.0
    [(m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m20 - m02) / s]
  } else {
    let s = (1.0 + m22 - m00 - m11).sqrt() * 2.0
    [(m20 + m02) / s, (m12 + m21) / s, 0.25 * s, (m01 - m10) / s]
  }
  Some({
    translation,
    scale: [sx, sy, sz],
    skew: [skew_xy, skew_xz, skew_yz],
    quaternion,
  })
}

///|
/// Spherical linear interpolation of two unit quaternions.
fn quat_slerp(
  qa : Array[Double],
  qb : Array[Double],
  t : Double,
) -> Array[Double] {
  let mut cos = qa[0] * qb[0] + qa[1] * qb[1] + qa[2] * qb[2] + qa[3] * qb[3]
  let q2 = if cos < 0.0 {
    cos = -cos
    [-qb[0], -qb[1], -qb[2], -qb[3]]
  } else {
    qb
  }
  if cos > 0.9995 {
    // Nearly identical: fall back to normalized linear interpolation.
    let r = [
      qa[0] + (q2[0] - qa[0]) * t,
      qa[1] + (q2[1] - qa[1]) * t,
      qa[2] + (q2[2] - qa[2]) * t,
      qa[3] + (q2[3] - qa[3]) * t,
    ]
    let len = (r[0] * r[0] + r[1] * r[1] + r[2] * r[2] + r[3] * r[3]).sqrt()
    return [r[0] / len, r[1] / len, r[2] / len, r[3] / len]
  }
  let theta = @math.acos(cos)
  let sin_theta = @math.sin(theta)
  let wa = @math.sin((1.0 - t) * theta) / sin_theta
  let wb = @math.sin(t * theta) / sin_theta
  [
    qa[0] * wa + q2[0] * wb,
    qa[1] * wa + q2[1] * wb,
    qa[2] * wa + q2[2] * wb,
    qa[3] * wa + q2[3] * wb,
  ]
}

///|
/// 4x4 column-major matrix multiply: returns a * b.
fn mat4_mul(a : Array[Double], b : Array[Double]) -> Array[Double] {
  let r = Array::make(16, 0.0)
  for c = 0; c < 4; c = c + 1 {
    for row = 0; row < 4; row = row + 1 {
      let mut sum = 0.0
      for k = 0; k < 4; k = k + 1 {
        sum = sum + m_get(a, k, row) * m_get(b, c, k)
      }
      r[c * 4 + row] = sum
    }
  }
  r
}

///|
fn mat4_identity() -> Array[Double] {
  [
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  ]
}

///|
/// Recompose a decomposed 3D transform into a 16-element column-major matrix.
fn recompose_matrix3d(d : Decomposed3D) -> Array[Double] {
  let mut m = mat4_identity()
  // Translation.
  m[12] = d.translation[0]
  m[13] = d.translation[1]
  m[14] = d.translation[2]
  // Rotation from quaternion.
  let x = d.quaternion[0]
  let y = d.quaternion[1]
  let z = d.quaternion[2]
  let w = d.quaternion[3]
  let rot = mat4_identity()
  rot[0] = 1.0 - 2.0 * (y * y + z * z)
  rot[1] = 2.0 * (x * y + z * w)
  rot[2] = 2.0 * (x * z - y * w)
  rot[4] = 2.0 * (x * y - z * w)
  rot[5] = 1.0 - 2.0 * (x * x + z * z)
  rot[6] = 2.0 * (y * z + x * w)
  rot[8] = 2.0 * (x * z + y * w)
  rot[9] = 2.0 * (y * z - x * w)
  rot[10] = 1.0 - 2.0 * (x * x + y * y)
  m = mat4_mul(m, rot)
  // Apply skews using explicit shear matrices, in spec order (YZ, XZ, XY).
  // skewYZ -> (col2,row1)=index 9, skewXZ -> (col2,row0)=index 8,
  // skewXY -> (col1,row0)=index 4.
  let apply_skew = fn(idx : Int, value : Double) -> Unit {
    if value != 0.0 {
      let t = mat4_identity()
      t[idx] = value
      m = mat4_mul(m, t)
    }
  }
  apply_skew(9, d.skew[2])
  apply_skew(8, d.skew[1])
  apply_skew(4, d.skew[0])
  // Scale.
  for row = 0; row < 4; row = row + 1 {
    m[0 + row] = m[0 + row] * d.scale[0]
    m[4 + row] = m[4 + row] * d.scale[1]
    m[8 + row] = m[8 + row] * d.scale[2]
  }
  m
}

///|
/// Interpolate two `matrix3d()` transforms via decompose / slerp / recompose.
/// Returns the recomposed 16-element column-major matrix, or None if either is
/// not decomposable.
fn interpolate_matrix3d(
  a : Array[Double],
  b : Array[Double],
  t : Double,
) -> Array[Double]? {
  match (decompose_matrix3d(a), decompose_matrix3d(b)) {
    (Some(da), Some(db)) => {
      let lerp3 = fn(x : Array[Double], y : Array[Double]) -> Array[Double] {
        [
          x[0] + (y[0] - x[0]) * t,
          x[1] + (y[1] - x[1]) * t,
          x[2] + (y[2] - x[2]) * t,
        ]
      }
      let decomposed : Decomposed3D = {
        translation: lerp3(da.translation, db.translation),
        scale: lerp3(da.scale, db.scale),
        skew: lerp3(da.skew, db.skew),
        quaternion: quat_slerp(da.quaternion, db.quaternion, t),
      }
      Some(recompose_matrix3d(decomposed))
    }
    _ => None
  }
}
