///|
fn gradient_sample_point(
  local_x : Double,
  local_y : Double,
  bbox : BoundingBox,
  units : GradientUnits,
  gradient_transform : Transform,
) -> (Double, Double) {
  let (x, y) = match units {
    ObjectBoundingBox => {
      let width = bbox.width()
      let height = bbox.height()
      (
        if width > 0.0 {
          (local_x - bbox.min_x) / width
        } else {
          0.0
        },
        if height > 0.0 {
          (local_y - bbox.min_y) / height
        } else {
          0.0
        },
      )
    }
    UserSpaceOnUse => (local_x, local_y)
  }
  gradient_transform.inverse().apply(x, y)
}

///|
fn apply_spread_inline(t : Double, spread : SpreadMethod) -> Double {
  match spread {
    Pad => max(0.0, min(1.0, t))
    Repeat => t - t.floor()
    Reflect => {
      let period = t - (t / 2.0).floor() * 2.0
      if period <= 1.0 {
        period
      } else {
        2.0 - period
      }
    }
  }
}

///|
fn sample_linear_gradient(
  gradient : LinearGradient,
  local_x : Double,
  local_y : Double,
  bbox : BoundingBox,
) -> Color {
  let (x, y) = gradient_sample_point(
    local_x,
    local_y,
    bbox,
    gradient.units,
    gradient.transform,
  )
  let dx = gradient.x2 - gradient.x1
  let dy = gradient.y2 - gradient.y1
  let length_squared = dx * dx + dy * dy
  let t = if length_squared > 0.000000000001 {
    ((x - gradient.x1) * dx + (y - gradient.y1) * dy) / length_squared
  } else {
    0.0
  }
  gradient.color_at(t)
}

///|
fn sample_radial_gradient(
  gradient : RadialGradient,
  local_x : Double,
  local_y : Double,
  bbox : BoundingBox,
) -> Color {
  let (x, y) = gradient_sample_point(
    local_x,
    local_y,
    bbox,
    gradient.units,
    gradient.transform,
  )
  let mut fx = gradient.fx
  let mut fy = gradient.fy
  let focus_dx = fx - gradient.cx
  let focus_dy = fy - gradient.cy
  let focus_distance = (focus_dx * focus_dx + focus_dy * focus_dy).sqrt()
  if gradient.r > 0.0 && focus_distance >= gradient.r {
    let scale = gradient.r * 0.999999 / focus_distance
    fx = gradient.cx + focus_dx * scale
    fy = gradient.cy + focus_dy * scale
  }
  let qx = x - fx
  let qy = y - fy
  let dx = gradient.cx - fx
  let dy = gradient.cy - fy
  let a = dx * dx + dy * dy - gradient.r * gradient.r
  let b = -2.0 * (qx * dx + qy * dy)
  let c = qx * qx + qy * qy
  let t = if gradient.r <= 0.0 {
    0.0
  } else if a.abs() <= 0.000000000001 {
    if b.abs() <= 0.000000000001 {
      0.0
    } else {
      -c / b
    }
  } else {
    let discriminant = b * b - 4.0 * a * c
    if discriminant <= 0.0 {
      0.0
    } else {
      let root = discriminant.sqrt()
      max((-b + root) / (2.0 * a), (-b - root) / (2.0 * a))
    }
  }
  let t = apply_spread_inline(t, gradient.spread_method)
  interpolate_gradient_color(t, gradient.stops)
}

///|
fn make_paint_server_setter(
  paint : ResolvedPaint,
  shape : Shape,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  opacity : Double,
  sampling : ImageSampling,
) -> ColorSink? {
  let bbox = get_shape_bounds(shape)
  match paint {
    ResolvedPaint::LinearGrad(gradient) => {
      let inverse = transform.inverse()
      Some({
        set: (x, y, coverage_color) => {
          if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
            return
          }
          let (local_x, local_y) = inverse.apply(
            x.to_double() + 0.5,
            y.to_double() + 0.5,
          )
          ctx.setter.pixel(
            x,
            y,
            apply_coverage(
              apply_opacity(
                sample_linear_gradient(gradient, local_x, local_y, bbox),
                opacity,
              ),
              coverage_color.a * 257,
            ),
          )
        },
      })
    }
    ResolvedPaint::RadialGrad(gradient) => {
      let inverse = transform.inverse()
      Some({
        set: (x, y, coverage_color) => {
          if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height {
            return
          }
          let (local_x, local_y) = inverse.apply(
            x.to_double() + 0.5,
            y.to_double() + 0.5,
          )
          ctx.setter.pixel(
            x,
            y,
            apply_coverage(
              apply_opacity(
                sample_radial_gradient(gradient, local_x, local_y, bbox),
                opacity,
              ),
              coverage_color.a * 257,
            ),
          )
        },
      })
    }
    ResolvedPaint::Pattern(pattern) =>
      make_pattern_setter(
        pattern, bbox, transform, ctx, resources, opacity, sampling,
      )
    _ => None
  }
}

///|
