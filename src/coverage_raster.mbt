///|
priv struct CoverageEdge {
  x0 : Int64
  y0 : Int64
  x1 : Int64
  y1 : Int64
  winding : Int
}

///|
priv struct CoverageCrossing {
  edge : CoverageEdge
  x : Double
}

///|
priv struct CoverageMask {
  origin_x : Int
  origin_y : Int
  width : Int
  height : Int
  values : Array[Int]
}

///|
fn quantize_coverage_coordinate(value : Double) -> Int64 {
  if value.is_nan() {
    return 0L
  }
  if value.is_pos_inf() {
    return 2305843009213693952L
  }
  if value.is_neg_inf() {
    return -2305843009213693952L
  }
  let scaled = value * 65536.0
  let bounded = max(-2305843009213693952.0, min(2305843009213693952.0, scaled))
  bounded.round().to_int64()
}

///|
fn fixed_coverage_coordinate(value : Int64) -> Double {
  value.to_double() / 65536.0
}

///|
fn device_path_flatness(transform : Transform) -> Double {
  let xx = transform.a * transform.a + transform.b * transform.b
  let yy = transform.c * transform.c + transform.d * transform.d
  let xy = transform.a * transform.c + transform.b * transform.d
  let discriminant = ((xx - yy) * (xx - yy) + 4.0 * xy * xy).sqrt()
  let largest_eigenvalue = (xx + yy + discriminant) * 0.5
  let scale = if largest_eigenvalue > 0.0 {
    largest_eigenvalue.sqrt()
  } else {
    1.0
  }
  0.125 / max(1.0, scale)
}

///|
fn CoverageEdge::x_at(self : CoverageEdge, y : Double) -> Double {
  let dy = self.y1 - self.y0
  if dy == 0L {
    fixed_coverage_coordinate(self.x0)
  } else {
    fixed_coverage_coordinate(self.x0) +
    (y - fixed_coverage_coordinate(self.y0)) *
    (self.x1 - self.x0).to_double() /
    dy.to_double()
  }
}

///|
fn CoverageEdge::min_y(self : CoverageEdge) -> Double {
  fixed_coverage_coordinate(if self.y0 < self.y1 { self.y0 } else { self.y1 })
}

///|
fn CoverageEdge::max_y(self : CoverageEdge) -> Double {
  fixed_coverage_coordinate(if self.y0 > self.y1 { self.y0 } else { self.y1 })
}

///|
fn make_coverage_edges(
  contours : Array[Array[(Double, Double)]],
) -> Array[CoverageEdge] {
  let edges : Array[CoverageEdge] = []
  for contour in contours {
    if contour.length() < 2 {
      continue
    }
    let mut count = contour.length()
    let first = contour[0]
    let last = contour[count - 1]
    let explicitly_closed = (first.0 - last.0).abs() <= 0.000000000001 &&
      (first.1 - last.1).abs() <= 0.000000000001
    if explicitly_closed {
      count = count - 1
    }
    if count < 2 {
      continue
    }
    for index in 0..<count {
      let next = if index + 1 == count { 0 } else { index + 1 }
      let p0 = contour[index]
      let p1 = contour[next]
      let x0 = quantize_coverage_coordinate(p0.0)
      let y0 = quantize_coverage_coordinate(p0.1)
      let x1 = quantize_coverage_coordinate(p1.0)
      let y1 = quantize_coverage_coordinate(p1.1)
      if y1 == y0 {
        continue
      }
      edges.push({ x0, y0, x1, y1, winding: if y1 > y0 { 1 } else { -1 } })
    }
  }
  edges
}

///|
fn sort_doubles(values : Array[Double]) -> Unit {
  for index in 1..<values.length() {
    let current = values[index]
    let mut cursor = index - 1
    while cursor >= 0 && values[cursor] > current {
      values[cursor + 1] = values[cursor]
      cursor = cursor - 1
    }
    values[cursor + 1] = current
  }
}

///|
fn unique_sorted_doubles(values : Array[Double]) -> Array[Double] {
  sort_doubles(values)
  let result : Array[Double] = []
  for value in values {
    if result.is_empty() ||
      (value - result[result.length() - 1]).abs() > 0.000000000001 {
      result.push(value)
    }
  }
  result
}

///|
fn sort_crossings(values : Array[CoverageCrossing]) -> Unit {
  for index in 1..<values.length() {
    let current = values[index]
    let mut cursor = index - 1
    while cursor >= 0 && values[cursor].x > current.x {
      values[cursor + 1] = values[cursor]
      cursor = cursor - 1
    }
    values[cursor + 1] = current
  }
}

///|
fn edge_intersection_y(left : CoverageEdge, right : CoverageEdge) -> Double? {
  let left_dy = left.y1 - left.y0
  let right_dy = right.y1 - right.y0
  if left_dy == 0L || right_dy == 0L {
    return None
  }
  let left_slope = (left.x1 - left.x0).to_double() / left_dy.to_double()
  let right_slope = (right.x1 - right.x0).to_double() / right_dy.to_double()
  let slope_delta = left_slope - right_slope
  if slope_delta.abs() <= 0.000000000001 {
    return None
  }
  let left_intercept = fixed_coverage_coordinate(left.x0) -
    left_slope * fixed_coverage_coordinate(left.y0)
  let right_intercept = fixed_coverage_coordinate(right.x0) -
    right_slope * fixed_coverage_coordinate(right.y0)
  Some((right_intercept - left_intercept) / slope_delta)
}

///|
fn polygon_area_abs(polygon : Array[(Double, Double)]) -> Double {
  if polygon.length() < 3 {
    return 0.0
  }
  let mut twice_area = 0.0
  for index in 0..<polygon.length() {
    let next = if index + 1 == polygon.length() { 0 } else { index + 1 }
    twice_area = twice_area +
      polygon[index].0 * polygon[next].1 -
      polygon[next].0 * polygon[index].1
  }
  twice_area.abs() * 0.5
}

///|
fn polygon_signed_area(polygon : Array[(Double, Double)]) -> Double {
  if polygon.length() < 3 {
    return 0.0
  }
  let mut twice_area = 0.0
  for index in 0..<polygon.length() {
    let next = if index + 1 == polygon.length() { 0 } else { index + 1 }
    twice_area = twice_area +
      polygon[index].0 * polygon[next].1 -
      polygon[next].0 * polygon[index].1
  }
  twice_area * 0.5
}

///|
fn clamp_coverage_unit(value : Double) -> Double {
  max(0.0, min(1.0, value))
}

///|
fn integrate_clamped_edge(
  edge : CoverageEdge,
  y0 : Double,
  y1 : Double,
  pixel_x : Double,
) -> Double {
  let value0 = edge.x_at(y0) - pixel_x
  let value1 = edge.x_at(y1) - pixel_x
  let delta = value1 - value0
  if delta.abs() <= 0.000000000001 {
    return clamp_coverage_unit(value0) * (y1 - y0)
  }
  let cuts : Array[Double] = [0.0, 1.0]
  let zero_crossing = -value0 / delta
  if zero_crossing > 0.0 && zero_crossing < 1.0 {
    cuts.push(zero_crossing)
  }
  let one_crossing = (1.0 - value0) / delta
  if one_crossing > 0.0 && one_crossing < 1.0 {
    cuts.push(one_crossing)
  }
  sort_doubles(cuts)
  let mut integral = 0.0
  for index in 0..<(cuts.length() - 1) {
    let t0 = cuts[index]
    let t1 = cuts[index + 1]
    let clamped0 = clamp_coverage_unit(value0 + delta * t0)
    let clamped1 = clamp_coverage_unit(value0 + delta * t1)
    integral = integral + (clamped0 + clamped1) * 0.5 * (t1 - t0)
  }
  integral * (y1 - y0)
}

///|
fn add_coverage_interval(
  row_coverage : Array[Double],
  origin_x : Int,
  left : CoverageEdge,
  right : CoverageEdge,
  y0 : Double,
  y1 : Double,
) -> Unit {
  let left0 = left.x_at(y0)
  let left1 = left.x_at(y1)
  let right0 = right.x_at(y0)
  let right1 = right.x_at(y1)
  let min_x = min(min(left0, left1), min(right0, right1)).floor().to_int()
  let max_x = max(max(left0, left1), max(right0, right1)).ceil().to_int()
  for device_x in min_x..<max_x {
    let local_x = device_x - origin_x
    if local_x < 0 || local_x >= row_coverage.length() {
      continue
    }
    let pixel_x = device_x.to_double()
    let right_area = integrate_clamped_edge(right, y0, y1, pixel_x)
    let left_area = integrate_clamped_edge(left, y0, y1, pixel_x)
    row_coverage[local_x] = row_coverage[local_x] +
      max(0.0, right_area - left_area)
  }
}

///|
fn build_coverage_mask(
  contours : Array[Array[(Double, Double)]],
  rule : FillRule,
  canvas_width : Int,
  canvas_height : Int,
) -> CoverageMask {
  let edges = make_coverage_edges(contours)
  if edges.is_empty() || canvas_width <= 0 || canvas_height <= 0 {
    return { origin_x: 0, origin_y: 0, width: 0, height: 0, values: [] }
  }
  let mut min_x = fixed_coverage_coordinate(edges[0].x0)
  let mut max_x = min_x
  let mut min_y = edges[0].min_y()
  let mut max_y = edges[0].max_y()
  for edge in edges {
    min_x = min(
      min_x,
      min(
        fixed_coverage_coordinate(edge.x0),
        fixed_coverage_coordinate(edge.x1),
      ),
    )
    max_x = max(
      max_x,
      max(
        fixed_coverage_coordinate(edge.x0),
        fixed_coverage_coordinate(edge.x1),
      ),
    )
    min_y = min(min_y, edge.min_y())
    max_y = max(max_y, edge.max_y())
  }
  let origin_x = max_int(0, min_x.floor().to_int())
  let origin_y = max_int(0, min_y.floor().to_int())
  let end_x = min_int(canvas_width, max_x.ceil().to_int())
  let end_y = min_int(canvas_height, max_y.ceil().to_int())
  let width = max_int(0, end_x - origin_x)
  let height = max_int(0, end_y - origin_y)
  let values = Array::make(width * height, 0)
  if width == 0 || height == 0 {
    return { origin_x, origin_y, width, height, values }
  }
  for device_y in origin_y..<end_y {
    let row_start = device_y.to_double()
    let row_end = row_start + 1.0
    let boundaries : Array[Double] = [row_start, row_end]
    let row_edges : Array[CoverageEdge] = []
    for edge in edges {
      if edge.max_y() > row_start && edge.min_y() < row_end {
        row_edges.push(edge)
        let edge_y0 = fixed_coverage_coordinate(edge.y0)
        let edge_y1 = fixed_coverage_coordinate(edge.y1)
        if edge_y0 > row_start && edge_y0 < row_end {
          boundaries.push(edge_y0)
        }
        if edge_y1 > row_start && edge_y1 < row_end {
          boundaries.push(edge_y1)
        }
      }
    }
    for left_index in 0..<row_edges.length() {
      for right_index in (left_index + 1)..<row_edges.length() {
        match
          edge_intersection_y(row_edges[left_index], row_edges[right_index]) {
          Some(y) =>
            if y > row_start &&
              y < row_end &&
              y >
              max(row_edges[left_index].min_y(), row_edges[right_index].min_y()) &&
              y <
              min(row_edges[left_index].max_y(), row_edges[right_index].max_y()) {
              boundaries.push(y)
            }
          None => ()
        }
      }
    }
    let bands = unique_sorted_doubles(boundaries)
    let row_coverage = Array::make(width, 0.0)
    for band_index in 0..<(bands.length() - 1) {
      let y0 = bands[band_index]
      let y1 = bands[band_index + 1]
      if y1 - y0 <= 0.000000000001 {
        continue
      }
      let sample_y = (y0 + y1) * 0.5
      let crossings : Array[CoverageCrossing] = []
      for edge in row_edges {
        if sample_y >= edge.min_y() && sample_y < edge.max_y() {
          crossings.push({ edge, x: edge.x_at(sample_y) })
        }
      }
      sort_crossings(crossings)
      match rule {
        EvenOdd => {
          let mut index = 0
          while index + 1 < crossings.length() {
            add_coverage_interval(
              row_coverage,
              origin_x,
              crossings[index].edge,
              crossings[index + 1].edge,
              y0,
              y1,
            )
            index = index + 2
          }
        }
        NonZero => {
          let mut winding = 0
          let mut start : CoverageEdge? = None
          for crossing in crossings {
            let previous = winding
            winding = winding + crossing.edge.winding
            if previous == 0 && winding != 0 {
              start = Some(crossing.edge)
            } else if previous != 0 && winding == 0 {
              match start {
                Some(left) =>
                  add_coverage_interval(
                    row_coverage,
                    origin_x,
                    left,
                    crossing.edge,
                    y0,
                    y1,
                  )
                None => ()
              }
              start = None
            }
          }
        }
      }
    }
    let local_y = device_y - origin_y
    for local_x in 0..<width {
      values[local_y * width + local_x] = unit_to_channel16(
        min(1.0, row_coverage[local_x]),
      )
    }
  }
  { origin_x, origin_y, width, height, values }
}

///|
#warnings("-unused_value")
fn CoverageMask::get_device(self : CoverageMask, x : Int, y : Int) -> Int {
  let local_x = x - self.origin_x
  let local_y = y - self.origin_y
  if local_x < 0 ||
    local_x >= self.width ||
    local_y < 0 ||
    local_y >= self.height {
    0
  } else {
    self.values[local_y * self.width + local_x]
  }
}

///|
fn union_coverage_masks(
  left : CoverageMask,
  right : CoverageMask,
) -> CoverageMask {
  if left.width == 0 || left.height == 0 {
    return right
  }
  if right.width == 0 || right.height == 0 {
    return left
  }
  let origin_x = min_int(left.origin_x, right.origin_x)
  let origin_y = min_int(left.origin_y, right.origin_y)
  let end_x = max_int(left.origin_x + left.width, right.origin_x + right.width)
  let end_y = max_int(
    left.origin_y + left.height,
    right.origin_y + right.height,
  )
  let width = end_x - origin_x
  let height = end_y - origin_y
  let values = Array::make(width * height, 0)
  for y in origin_y..<end_y {
    for x in origin_x..<end_x {
      values[(y - origin_y) * width + x - origin_x] = max_int(
        left.get_device(x, y),
        right.get_device(x, y),
      )
    }
  }
  { origin_x, origin_y, width, height, values }
}

///|
fn intersect_coverage_masks(
  left : CoverageMask,
  right : CoverageMask,
) -> CoverageMask {
  let origin_x = max_int(left.origin_x, right.origin_x)
  let origin_y = max_int(left.origin_y, right.origin_y)
  let end_x = min_int(left.origin_x + left.width, right.origin_x + right.width)
  let end_y = min_int(
    left.origin_y + left.height,
    right.origin_y + right.height,
  )
  let width = max_int(0, end_x - origin_x)
  let height = max_int(0, end_y - origin_y)
  let values = Array::make(width * height, 0)
  for local_y in 0..<height {
    for local_x in 0..<width {
      let x = origin_x + local_x
      let y = origin_y + local_y
      values[local_y * width + local_x] = multiply_channel16(
        left.get_device(x, y),
        right.get_device(x, y),
      )
    }
  }
  { origin_x, origin_y, width, height, values }
}

///|
fn paint_coverage_mask(
  mask : CoverageMask,
  color : Color,
  setter : ColorSink,
) -> Unit {
  let source = PremulColor16::from_color(color)
  for local_y in 0..<mask.height {
    for local_x in 0..<mask.width {
      let coverage = mask.values[local_y * mask.width + local_x]
      if coverage > 0 {
        setter.pixel(
          mask.origin_x + local_x,
          mask.origin_y + local_y,
          if coverage == 65535 {
            color
          } else {
            source.scaled(coverage).to_color()
          },
        )
      }
    }
  }
}

///|
#warnings("-unused_value")
fn raster_contours_coverage(
  contours : Array[Array[(Double, Double)]],
  color : Color,
  rule : FillRule,
  setter : ColorSink,
  canvas_width : Int,
  canvas_height : Int,
) -> Unit {
  paint_coverage_mask(
    build_coverage_mask(contours, rule, canvas_width, canvas_height),
    color,
    setter,
  )
}
