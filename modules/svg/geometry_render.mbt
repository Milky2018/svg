///|
fn rect_path_commands(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
) -> Array[PathCommand] {
  let clamped_rx = min(max(rx, 0.0), width / 2.0)
  let clamped_ry = min(max(ry, 0.0), height / 2.0)
  if (clamped_rx - width / 2.0).abs() <= 0.000000000001 &&
    (clamped_ry - height / 2.0).abs() <= 0.000000000001 {
    return ellipse_path_commands(
      x + width / 2.0,
      y + height / 2.0,
      clamped_rx,
      clamped_ry,
    )
  }
  if clamped_rx <= 0.0 || clamped_ry <= 0.0 {
    return [
      MoveTo(x, y),
      LineTo(x + width, y),
      LineTo(x + width, y + height),
      LineTo(x, y + height),
      ClosePath,
    ]
  }
  [
    MoveTo(x + clamped_rx, y),
    LineTo(x + width - clamped_rx, y),
    ArcTo(clamped_rx, clamped_ry, 0.0, false, true, x + width, y + clamped_ry),
    LineTo(x + width, y + height - clamped_ry),
    ArcTo(
      clamped_rx,
      clamped_ry,
      0.0,
      false,
      true,
      x + width - clamped_rx,
      y + height,
    ),
    LineTo(x + clamped_rx, y + height),
    ArcTo(clamped_rx, clamped_ry, 0.0, false, true, x, y + height - clamped_ry),
    LineTo(x, y + clamped_ry),
    ArcTo(clamped_rx, clamped_ry, 0.0, false, true, x + clamped_rx, y),
    ClosePath,
  ]
}

///|
fn points_path_commands(
  points : Array[(Double, Double)],
  close : Bool,
) -> Array[PathCommand] {
  if points.is_empty() {
    return []
  }
  let commands : Array[PathCommand] = [MoveTo(points[0].0, points[0].1)]
  for i in 1..<points.length() {
    commands.push(LineTo(points[i].0, points[i].1))
  }
  if close {
    commands.push(ClosePath)
  }
  commands
}

///|
fn ellipse_path_commands(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Array[PathCommand] {
  [
    MoveTo(cx + rx, cy),
    ArcTo(rx, ry, 0.0, true, true, cx - rx, cy),
    ArcTo(rx, ry, 0.0, true, true, cx + rx, cy),
    ClosePath,
  ]
}

///|
fn render_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  render_path(
    rect_path_commands(x, y, width, height, rx, ry),
    node,
    transform,
    ctx,
    node_color,
    resources,
  )
}

///|
fn render_circle(
  cx : Double,
  cy : Double,
  r : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if r <= 0.0 {
    return
  }
  render_path(
    ellipse_path_commands(cx, cy, r, r),
    node,
    transform,
    ctx,
    node_color,
    resources,
  )
}

///|
fn render_ellipse(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if rx <= 0.0 || ry <= 0.0 {
    return
  }
  render_path(
    ellipse_path_commands(cx, cy, rx, ry),
    node,
    transform,
    ctx,
    node_color,
    resources,
  )
}

///|
fn render_line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  fn draw_stroke() -> Unit {
    match resolve_paint_for_render(node.stroke.paint, node_color, resources) {
      SolidColor(color) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          let stroke_color = apply_opacity(
            color,
            node.stroke_opacity * node.opacity,
          )
          raster_affine_stroke(
            [(x1, y1), (x2, y2)],
            node.stroke,
            transform,
            stroke_color,
            ctx.setter,
            ctx.width,
            ctx.height,
            false,
          )
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_linear_shape(
      [(x1, y1), (x2, y2)],
      false,
      node,
      transform,
      ctx,
      resources,
      node_color,
    )
  }

  render_paint_order(node.paint_order, () => (), draw_stroke, draw_markers)
}

///|
fn marker_transform_with_ref_ratio(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  scale : Double,
  ref_ratio : Double,
) -> Transform {
  let orient_angle = match marker.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  let content_transform = match marker.view_box {
    Some(vb) => {
      let view_t = vb.get_transform(
        marker.marker_width,
        marker.marker_height,
        marker.preserve_aspect_ratio,
      )
      let (ref_px, ref_py) = view_t.apply(marker.ref_x, marker.ref_y)
      let ref_t = Transform::translate(-ref_px * ref_ratio, -ref_py * ref_ratio)
      ref_t.multiply(view_t)
    }
    None =>
      Transform::translate(-marker.ref_x * ref_ratio, -marker.ref_y * ref_ratio)
  }
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  t1.multiply(r).multiply(s).multiply(content_transform)
}

///|
fn render_marker_instance(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  let (marker_scale, ref_ratio) = match marker.marker_units {
    StrokeWidth => {
      let scale = node.stroke.width
      if scale > 0.0 {
        (scale, 1.0)
      } else {
        (0.0, 1.0)
      }
    }
    UserSpaceOnUse_ => (1.0, 1.0)
  }
  let marker_transform = marker_transform_with_ref_ratio(
    marker, x, y, angle, marker_scale, ref_ratio,
  )
  let viewport_transform = marker_viewport_transform(
    marker, x, y, angle, marker_scale, ref_ratio,
  )
  let parent_transform = transform.multiply(marker_transform)
  let mut ctx_for_marker = ctx
  if marker.clip_overflow &&
    marker.marker_width > 0.0 &&
    marker.marker_height > 0.0 {
    let viewport_bbox = BoundingBox::from_rect(
      0.0,
      0.0,
      marker.marker_width,
      marker.marker_height,
    )
    let clip_transform = transform.multiply(viewport_transform)
    let clip_shape = Rect(
      x=viewport_bbox.min_x,
      y=viewport_bbox.min_y,
      width=viewport_bbox.width(),
      height=viewport_bbox.height(),
      rx=0.0,
      ry=0.0,
    )
    let clip = ClipPath::with_transform(
      "marker-viewport", clip_shape, clip_transform,
    )
    ctx_for_marker = apply_clip_path(
      ctx_for_marker,
      clip,
      Transform::identity(),
      BoundingBox::empty(),
      resources,
    )
  }
  render_node(
    marker.content,
    parent_transform,
    ctx_for_marker,
    resources,
    true,
    node_color,
  )
}

///|
fn marker_viewport_transform(
  marker : Marker,
  x : Double,
  y : Double,
  angle : Double,
  scale : Double,
  ref_ratio : Double,
) -> Transform {
  let orient_angle = match marker.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  let (ref_px, ref_py) = match marker.view_box {
    Some(vb) => {
      let view_t = vb.get_transform(
        marker.marker_width,
        marker.marker_height,
        marker.preserve_aspect_ratio,
      )
      view_t.apply(marker.ref_x, marker.ref_y)
    }
    None => (marker.ref_x, marker.ref_y)
  }
  let ref_t = Transform::translate(-ref_px * ref_ratio, -ref_py * ref_ratio)
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  t1.multiply(r).multiply(s).multiply(ref_t)
}

///|
fn render_markers_for_linear_shape(
  points : Array[(Double, Double)],
  closed : Bool,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if points.length() == 0 {
    return
  }
  let commands : Array[PathCommand] = [MoveTo(points[0].0, points[0].1)]
  for index in 1..<points.length() {
    commands.push(LineTo(points[index].0, points[index].1))
  }
  if closed {
    commands.push(ClosePath)
  }
  render_markers_for_path_commands(
    commands, node, transform, ctx, resources, node_color,
  )
}

///|
fn normalize_dash_pattern(dasharray : Array[Double]) -> Array[Double] {
  let normalized : Array[Double] = []
  for value in dasharray {
    if value < 0.0 {
      return []
    }
    normalized.push(value)
  }
  if normalized.length() % 2 == 1 {
    for value in dasharray {
      normalized.push(value)
    }
  }
  normalized
}

///|
fn push_distinct_local_point(
  points : Array[(Double, Double)],
  point : (Double, Double),
) -> Unit {
  if points.length() == 0 {
    points.push(point)
    return
  }
  let previous = points[points.length() - 1]
  if (previous.0 - point.0).abs() > 0.000001 ||
    (previous.1 - point.1).abs() > 0.000001 {
    points.push(point)
  }
}

///|
fn points_are_close(left : (Double, Double), right : (Double, Double)) -> Bool {
  (left.0 - right.0).abs() <= 0.000001 && (left.1 - right.1).abs() <= 0.000001
}

///|
fn dash_local_polyline_pieces(
  points : Array[(Double, Double)],
  dasharray : Array[Double],
  dashoffset : Double,
) -> Array[Array[(Double, Double)]] {
  let pieces : Array[Array[(Double, Double)]] = []
  if points.length() < 2 {
    return pieces
  }
  let pattern = normalize_dash_pattern(dasharray)
  if pattern.length() == 0 {
    pieces.push(points)
    return pieces
  }
  let total = pattern.fold(init=0.0, (sum, value) => sum + value)
  if total <= 0.0 {
    return pieces
  }
  let epsilon = 0.000001
  let mut position = -dashoffset
  while position < 0.0 {
    position = position + total
  }
  while position >= total {
    position = position - total
  }
  let mut pattern_index = 0
  while position >= pattern[pattern_index] && pattern[pattern_index] > epsilon {
    position = position - pattern[pattern_index]
    pattern_index = (pattern_index + 1) % pattern.length()
  }
  let mut remaining = pattern[pattern_index] - position
  let mut drawing = pattern_index % 2 == 0
  let mut zero_guard = 0
  while remaining <= epsilon && zero_guard < pattern.length() {
    pattern_index = (pattern_index + 1) % pattern.length()
    remaining = pattern[pattern_index]
    drawing = pattern_index % 2 == 0
    zero_guard = zero_guard + 1
  }
  let mut current : Array[(Double, Double)] = []
  for segment_index in 0..<(points.length() - 1) {
    let start = points[segment_index]
    let finish = points[segment_index + 1]
    let dx = finish.0 - start.0
    let dy = finish.1 - start.1
    let length = (dx * dx + dy * dy).sqrt()
    if length <= epsilon {
      continue
    }
    let mut traveled = 0.0
    while traveled < length - epsilon {
      let available = length - traveled
      let step = if remaining < available { remaining } else { available }
      let start_ratio = traveled / length
      let end_ratio = (traveled + step) / length
      let piece_start = (start.0 + dx * start_ratio, start.1 + dy * start_ratio)
      let piece_end = (start.0 + dx * end_ratio, start.1 + dy * end_ratio)
      if drawing {
        push_distinct_local_point(current, piece_start)
        push_distinct_local_point(current, piece_end)
      }
      traveled = traveled + step
      remaining = remaining - step
      if remaining <= epsilon {
        if drawing && current.length() >= 2 {
          pieces.push(current)
          current = []
        }
        pattern_index = (pattern_index + 1) % pattern.length()
        remaining = pattern[pattern_index]
        drawing = pattern_index % 2 == 0
        zero_guard = 0
        while remaining <= epsilon && zero_guard < pattern.length() {
          pattern_index = (pattern_index + 1) % pattern.length()
          remaining = pattern[pattern_index]
          drawing = pattern_index % 2 == 0
          zero_guard = zero_guard + 1
        }
      }
    }
  }
  if drawing && current.length() >= 2 {
    pieces.push(current)
  }
  pieces
}

///|
fn merge_closed_dash_seam(
  pieces : Array[Array[(Double, Double)]],
  seam : (Double, Double),
) -> Unit {
  if pieces.length() <= 1 {
    return
  }
  let first_piece = pieces[0]
  let last_piece = pieces[pieces.length() - 1]
  if points_are_close(first_piece[0], seam) &&
    points_are_close(last_piece[last_piece.length() - 1], seam) {
    let merged = last_piece.copy()
    for index in 1..<first_piece.length() {
      push_distinct_local_point(merged, first_piece[index])
    }
    pieces[0] = merged
    let _ = pieces.pop()
  }
}

///|
fn push_transformed_stroke_polygon(
  outlines : Array[Array[(Double, Double)]],
  local_points : Array[(Double, Double)],
  transform : Transform,
) -> Unit {
  let transformed : Array[(Double, Double)] = []
  for point in local_points {
    let device = transform.apply(point.0, point.1)
    push_distinct_local_point(transformed, device)
  }
  let area = polygon_signed_area(transformed)
  if transformed.length() >= 3 && area.abs() > 0.000000000001 {
    if area > 0.0 {
      outlines.push(transformed)
    } else {
      let reversed : Array[(Double, Double)] = []
      for index in 0..<transformed.length() {
        reversed.push(transformed[transformed.length() - 1 - index])
      }
      outlines.push(reversed)
    }
  }
}

///|
fn push_affine_stroke_disk(
  outlines : Array[Array[(Double, Double)]],
  center : (Double, Double),
  radius : Double,
  transform : Transform,
) -> Unit {
  let polygon : Array[(Double, Double)] = []
  let error = min(radius, device_path_flatness(transform))
  let max_angle = 2.0 * @math.acos(1.0 - error / radius)
  let segments = min_int(
    65536,
    max_int((6.283185307179586 / max_angle).ceil().to_int(), 8),
  )
  for index in 0..<segments {
    let angle = 6.283185307179586 * index.to_double() / segments.to_double()
    polygon.push(
      (
        center.0 + @math.cos(angle) * radius,
        center.1 + @math.sin(angle) * radius,
      ),
    )
  }
  push_transformed_stroke_polygon(outlines, polygon, transform)
}

///|
fn push_affine_stroke_join(
  outlines : Array[Array[(Double, Double)]],
  previous : (Double, Double),
  vertex : (Double, Double),
  next : (Double, Double),
  half : Double,
  linejoin : LineJoin,
  miterlimit : Double,
  transform : Transform,
) -> Unit {
  let previous_dx = vertex.0 - previous.0
  let previous_dy = vertex.1 - previous.1
  let next_dx = next.0 - vertex.0
  let next_dy = next.1 - vertex.1
  let previous_length = (previous_dx * previous_dx + previous_dy * previous_dy).sqrt()
  let next_length = (next_dx * next_dx + next_dy * next_dy).sqrt()
  if previous_length <= 0.000001 || next_length <= 0.000001 {
    return
  }
  let ux0 = previous_dx / previous_length
  let uy0 = previous_dy / previous_length
  let ux1 = next_dx / next_length
  let uy1 = next_dy / next_length
  let cross = ux0 * uy1 - uy0 * ux1
  if cross.abs() <= 0.000001 {
    return
  }
  match linejoin {
    Round => push_affine_stroke_disk(outlines, vertex, half, transform)
    Bevel | Miter => {
      let side = if cross > 0.0 { -1.0 } else { 1.0 }
      let outer0 = (vertex.0 + side * -uy0 * half, vertex.1 + side * ux0 * half)
      let outer1 = (vertex.0 + side * -uy1 * half, vertex.1 + side * ux1 * half)
      if linejoin == Bevel {
        push_transformed_stroke_polygon(
          outlines,
          [vertex, outer0, outer1],
          transform,
        )
        return
      }
      let denominator = ux0 * uy1 - uy0 * ux1
      let t = ((outer1.0 - outer0.0) * uy1 - (outer1.1 - outer0.1) * ux1) /
        denominator
      let miter = (outer0.0 + t * ux0, outer0.1 + t * uy0)
      let miter_dx = miter.0 - vertex.0
      let miter_dy = miter.1 - vertex.1
      let miter_ratio = (miter_dx * miter_dx + miter_dy * miter_dy).sqrt() /
        half
      let polygon = if miter_ratio <= miterlimit {
        [vertex, outer0, miter, outer1]
      } else {
        [vertex, outer0, outer1]
      }
      push_transformed_stroke_polygon(outlines, polygon, transform)
    }
  }
}

///|
fn append_affine_stroke_piece(
  outlines : Array[Array[(Double, Double)]],
  points : Array[(Double, Double)],
  stroke : StrokeStyle,
  transform : Transform,
  closed : Bool,
) -> Unit {
  if points.length() == 0 || stroke.width <= 0.0 {
    return
  }
  let half = stroke.width / 2.0
  let segment_count = if closed { points.length() } else { points.length() - 1 }
  let mut has_segment = false
  for index in 0..<segment_count {
    let next_index = if index + 1 == points.length() { 0 } else { index + 1 }
    let start = points[index]
    let finish = points[next_index]
    let dx = finish.0 - start.0
    let dy = finish.1 - start.1
    let length = (dx * dx + dy * dy).sqrt()
    if length <= 0.000001 {
      continue
    }
    has_segment = true
    let ux = dx / length
    let uy = dy / length
    let start_extension = if !closed && index == 0 && stroke.linecap == Square {
      half
    } else {
      0.0
    }
    let end_extension = if !closed &&
      index == segment_count - 1 &&
      stroke.linecap == Square {
      half
    } else {
      0.0
    }
    let sx = start.0 - ux * start_extension
    let sy = start.1 - uy * start_extension
    let ex = finish.0 + ux * end_extension
    let ey = finish.1 + uy * end_extension
    let nx = -uy * half
    let ny = ux * half
    push_transformed_stroke_polygon(
      outlines,
      [
        (sx + nx, sy + ny),
        (sx - nx, sy - ny),
        (ex - nx, ey - ny),
        (ex + nx, ey + ny),
      ],
      transform,
    )
  }
  if !has_segment {
    if !closed {
      match stroke.linecap {
        Butt => ()
        Round => push_affine_stroke_disk(outlines, points[0], half, transform)
        Square =>
          push_transformed_stroke_polygon(
            outlines,
            [
              (points[0].0 - half, points[0].1 - half),
              (points[0].0 + half, points[0].1 - half),
              (points[0].0 + half, points[0].1 + half),
              (points[0].0 - half, points[0].1 + half),
            ],
            transform,
          )
      }
    }
    return
  }
  if closed {
    for index in 0..<points.length() {
      let previous = if index == 0 {
        points[points.length() - 1]
      } else {
        points[index - 1]
      }
      let next = if index + 1 == points.length() {
        points[0]
      } else {
        points[index + 1]
      }
      push_affine_stroke_join(
        outlines,
        previous,
        points[index],
        next,
        half,
        stroke.linejoin,
        stroke.miterlimit,
        transform,
      )
    }
  } else {
    for index in 1..<(points.length() - 1) {
      push_affine_stroke_join(
        outlines,
        points[index - 1],
        points[index],
        points[index + 1],
        half,
        stroke.linejoin,
        stroke.miterlimit,
        transform,
      )
    }
    if stroke.linecap == Round {
      push_affine_stroke_disk(outlines, points[0], half, transform)
      push_affine_stroke_disk(
        outlines,
        points[points.length() - 1],
        half,
        transform,
      )
    }
  }
}

///|
fn raster_affine_stroke(
  source_points : Array[(Double, Double)],
  stroke : StrokeStyle,
  transform : Transform,
  color : Color,
  setter : ColorSink,
  canvas_width : Int,
  canvas_height : Int,
  closed : Bool,
) -> Unit {
  if source_points.length() == 0 || stroke.width <= 0.0 {
    return
  }
  if stroke.non_scaling {
    let device_points = source_points.map(fn(point) {
      transform.apply(point.0, point.1)
    })
    raster_affine_stroke(
      device_points,
      { ..stroke, non_scaling: false },
      Transform::identity(),
      color,
      setter,
      canvas_width,
      canvas_height,
      closed,
    )
    return
  }
  let points = source_points.copy()
  if closed && points.length() > 1 {
    let first = points[0]
    let last = points[points.length() - 1]
    if (first.0 - last.0).abs() <= 0.000001 &&
      (first.1 - last.1).abs() <= 0.000001 {
      let _ = points.pop()
    }
  }
  let outlines : Array[Array[(Double, Double)]] = []
  match stroke.dasharray {
    Some(dasharray) => {
      let dash_points = if closed {
        let result = points.copy()
        result.push(points[0])
        result
      } else {
        points
      }
      let pieces = dash_local_polyline_pieces(
        dash_points,
        dasharray,
        stroke.dashoffset,
      )
      if closed {
        merge_closed_dash_seam(pieces, points[0])
      }
      for piece in pieces {
        let piece_closed = piece.length() > 2 &&
          points_are_close(piece[0], piece[piece.length() - 1])
        let piece_points = piece.copy()
        if piece_closed {
          let _ = piece_points.pop()
        }
        append_affine_stroke_piece(
          outlines, piece_points, stroke, transform, piece_closed,
        )
      }
    }
    None =>
      append_affine_stroke_piece(outlines, points, stroke, transform, closed)
  }
  if outlines.length() > 0 {
    raster_contours_coverage(
      outlines,
      color,
      NonZero,
      setter,
      canvas_width,
      canvas_height,
    )
  }
}

///|
priv struct MarkerPoint {
  x : Double
  y : Double
  mut has_in : Bool
  mut in_dx : Double
  mut in_dy : Double
  mut has_out : Bool
  mut out_dx : Double
  mut out_dy : Double
}

///|
fn MarkerPoint::new(x : Double, y : Double) -> MarkerPoint {
  {
    x,
    y,
    has_in: false,
    in_dx: 0.0,
    in_dy: 0.0,
    has_out: false,
    out_dx: 0.0,
    out_dy: 0.0,
  }
}

///|
priv struct MarkerSubpath {
  points : Array[MarkerPoint]
}

///|
fn arc_tangent_at(
  theta : Double,
  cos_phi : Double,
  sin_phi : Double,
  rx : Double,
  ry : Double,
) -> (Double, Double) {
  let sin_t = @math.sin(theta)
  let cos_t = @math.cos(theta)
  let dx = -cos_phi * rx * sin_t - sin_phi * ry * cos_t
  let dy = -sin_phi * rx * sin_t + cos_phi * ry * cos_t
  (dx, dy)
}

///|
fn angle_between_vec(
  ux : Double,
  uy : Double,
  vx : Double,
  vy : Double,
) -> Double {
  let dot = ux * vx + uy * vy
  let len_u = (ux * ux + uy * uy).sqrt()
  let len_v = (vx * vx + vy * vy).sqrt()
  let len_prod = len_u * len_v
  if len_prod == 0.0 {
    return 0.0
  }
  let mut cos_angle = dot / len_prod
  if cos_angle > 1.0 {
    cos_angle = 1.0
  }
  if cos_angle < -1.0 {
    cos_angle = -1.0
  }
  let angle = @math.acos(cos_angle)
  let cross = ux * vy - uy * vx
  if cross < 0.0 {
    -angle
  } else {
    angle
  }
}

///|
fn compute_arc_tangents(
  x1 : Double,
  y1 : Double,
  rx_in : Double,
  ry_in : Double,
  rotation_degrees : Double,
  large_arc : Bool,
  sweep : Bool,
  x2 : Double,
  y2 : Double,
) -> (Double, Double, Double, Double) {
  let dx_line = x2 - x1
  let dy_line = y2 - y1
  if (x1 == x2 && y1 == y2) || rx_in == 0.0 || ry_in == 0.0 {
    return (dx_line, dy_line, dx_line, dy_line)
  }
  let mut rx = if rx_in < 0.0 { -rx_in } else { rx_in }
  let mut ry = if ry_in < 0.0 { -ry_in } else { ry_in }
  let phi = degrees_to_radians(rotation_degrees)
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let dx = (x1 - x2) / 2.0
  let dy = (y1 - y2) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if lambda > 1.0 {
    let sqrt_lambda = lambda.sqrt()
    rx = rx * sqrt_lambda
    ry = ry * sqrt_lambda
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let sq = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / (rx2 * y1p2 + ry2 * x1p2)
  let sq_abs = if sq < 0.0 { 0.0 } else { sq }
  let coef = sq_abs.sqrt() * (if large_arc == sweep { -1.0 } else { 1.0 })
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  let theta1 = angle_between_vec(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  let mut dtheta = angle_between_vec(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  )
  let pi = 3.14159265358979323846
  if !sweep && dtheta > 0.0 {
    dtheta = dtheta - 2.0 * pi
  } else if sweep && dtheta < 0.0 {
    dtheta = dtheta + 2.0 * pi
  }
  let theta2 = theta1 + dtheta
  let sign = if dtheta < 0.0 { -1.0 } else { 1.0 }
  let (sx, sy) = arc_tangent_at(theta1, cos_phi, sin_phi, rx, ry)
  let (ex, ey) = arc_tangent_at(theta2, cos_phi, sin_phi, rx, ry)
  (sx * sign, sy * sign, ex * sign, ey * sign)
}

///|
fn build_marker_subpaths(commands : Array[PathCommand]) -> Array[MarkerSubpath] {
  let subpaths : Array[MarkerSubpath] = []
  let mut points : Array[MarkerPoint] = []
  let mut closed = false
  let mut cur_x = 0.0
  let mut cur_y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  let mut last_ctrl_x = 0.0
  let mut last_ctrl_y = 0.0
  let mut last_cmd_was_curve = false
  let mut last_cmd_was_quad = false
  let eps = 0.0001
  fn finish_subpath(
    subpaths : Array[MarkerSubpath],
    points : Array[MarkerPoint],
    closed : Bool,
  ) -> Unit {
    if points.length() == 0 {
      return
    }
    let out_points = points
    if closed {
      let first = out_points[0]
      let dup = MarkerPoint::new(first.x, first.y)
      if first.has_in {
        dup.has_in = true
        dup.in_dx = first.in_dx
        dup.in_dy = first.in_dy
      }
      out_points.push(dup)
    }
    subpaths.push({ points: out_points })
  }

  fn record_out(
    points : Array[MarkerPoint],
    idx : Int,
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> Unit {
    let len = (dx * dx + dy * dy).sqrt()
    if len >= eps {
      points[idx].has_out = true
      points[idx].out_dx = dx
      points[idx].out_dy = dy
    }
  }

  fn record_in(
    points : Array[MarkerPoint],
    idx : Int,
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> Unit {
    let len = (dx * dx + dy * dy).sqrt()
    if len >= eps {
      points[idx].has_in = true
      points[idx].in_dx = dx
      points[idx].in_dy = dy
    }
  }

  fn add_segment(
    points : Array[MarkerPoint],
    cur_x : Double,
    cur_y : Double,
    end_x : Double,
    end_y : Double,
    out_dx : Double,
    out_dy : Double,
    in_dx : Double,
    in_dy : Double,
    eps : Double,
  ) -> Unit {
    if points.length() == 0 {
      points.push(MarkerPoint::new(cur_x, cur_y))
    }
    let last_idx = points.length() - 1
    record_out(points, last_idx, out_dx, out_dy, eps)
    let end_point = MarkerPoint::new(end_x, end_y)
    let in_len = (in_dx * in_dx + in_dy * in_dy).sqrt()
    if in_len >= eps {
      end_point.has_in = true
      end_point.in_dx = in_dx
      end_point.in_dy = in_dy
    }
    points.push(end_point)
  }

  for cmd in commands {
    match cmd {
      MoveTo(x, y) => {
        finish_subpath(subpaths, points, closed)
        points = [MarkerPoint::new(x, y)]
        closed = false
        cur_x = x
        cur_y = y
        start_x = x
        start_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      MoveToRel(dx, dy) => {
        finish_subpath(subpaths, points, closed)
        let x = cur_x + dx
        let y = cur_y + dy
        points = [MarkerPoint::new(x, y)]
        closed = false
        cur_x = x
        cur_y = y
        start_x = x
        start_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      LineTo(x, y) => {
        let dx = x - cur_x
        let dy = y - cur_y
        add_segment(points, cur_x, cur_y, x, y, dx, dy, dx, dy, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      LineToRel(dx, dy) => {
        let x = cur_x + dx
        let y = cur_y + dy
        add_segment(points, cur_x, cur_y, x, y, dx, dy, dx, dy, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      HorizontalLineTo(x) => {
        let dx = x - cur_x
        add_segment(points, cur_x, cur_y, x, cur_y, dx, 0.0, dx, 0.0, eps)
        cur_x = x
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      HorizontalLineToRel(dx) => {
        let x = cur_x + dx
        add_segment(points, cur_x, cur_y, x, cur_y, dx, 0.0, dx, 0.0, eps)
        cur_x = x
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      VerticalLineTo(y) => {
        let dy = y - cur_y
        add_segment(points, cur_x, cur_y, cur_x, y, 0.0, dy, 0.0, dy, eps)
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      VerticalLineToRel(dy) => {
        let y = cur_y + dy
        add_segment(points, cur_x, cur_y, cur_x, y, 0.0, dy, 0.0, dy, eps)
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      CurveTo(x1, y1, x2, y2, x, y) => {
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy) => {
        let x1 = cur_x + dx1
        let y1 = cur_y + dy1
        let x2 = cur_x + dx2
        let y2 = cur_y + dy2
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      SmoothCurveTo(x2, y2, x, y) => {
        let x1 = if last_cmd_was_curve {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_curve {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      SmoothCurveToRel(dx2, dy2, dx, dy) => {
        let x1 = if last_cmd_was_curve {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_curve {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let x2 = cur_x + dx2
        let y2 = cur_y + dy2
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x2 - cur_x
          sy = y2 - cur_y
        }
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x2
        let mut ey = y - y2
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - x1
          ey = y - y1
        }
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x2
        last_ctrl_y = y2
        cur_x = x
        cur_y = y
        last_cmd_was_curve = true
        last_cmd_was_quad = false
      }
      QuadraticCurveTo(x1, y1, x, y) => {
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      QuadraticCurveToRel(dx1, dy1, dx, dy) => {
        let x1 = cur_x + dx1
        let y1 = cur_y + dy1
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      SmoothQuadraticCurveTo(x, y) => {
        let x1 = if last_cmd_was_quad {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_quad {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      SmoothQuadraticCurveToRel(dx, dy) => {
        let x1 = if last_cmd_was_quad {
          2.0 * cur_x - last_ctrl_x
        } else {
          cur_x
        }
        let y1 = if last_cmd_was_quad {
          2.0 * cur_y - last_ctrl_y
        } else {
          cur_y
        }
        let x = cur_x + dx
        let y = cur_y + dy
        let mut sx = x1 - cur_x
        let mut sy = y1 - cur_y
        if (sx * sx + sy * sy).sqrt() < eps {
          sx = x - cur_x
          sy = y - cur_y
        }
        let mut ex = x - x1
        let mut ey = y - y1
        if (ex * ex + ey * ey).sqrt() < eps {
          ex = x - cur_x
          ey = y - cur_y
        }
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        last_ctrl_x = x1
        last_ctrl_y = y1
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = true
      }
      ArcTo(rx, ry, rotation, large_arc, sweep, x, y) => {
        let (sx, sy, ex, ey) = compute_arc_tangents(
          cur_x, cur_y, rx, ry, rotation, large_arc, sweep, x, y,
        )
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) => {
        let x = cur_x + dx
        let y = cur_y + dy
        let (sx, sy, ex, ey) = compute_arc_tangents(
          cur_x, cur_y, rx, ry, rotation, large_arc, sweep, x, y,
        )
        add_segment(points, cur_x, cur_y, x, y, sx, sy, ex, ey, eps)
        cur_x = x
        cur_y = y
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
      ClosePath => {
        if points.length() > 0 {
          let dx = start_x - cur_x
          let dy = start_y - cur_y
          let last_idx = points.length() - 1
          record_out(points, last_idx, dx, dy, eps)
          record_in(points, 0, dx, dy, eps)
          cur_x = start_x
          cur_y = start_y
          closed = true
        }
        last_cmd_was_curve = false
        last_cmd_was_quad = false
      }
    }
  }
  finish_subpath(subpaths, points, closed)
  subpaths
}

///|
fn render_markers_for_path_commands(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if node.marker_start is None &&
    node.marker_mid is None &&
    node.marker_end is None {
    return
  }
  let subpaths = build_marker_subpaths(commands)
  if subpaths.length() == 0 {
    return
  }
  let eps = 0.0001
  let (sx, sy) = transform.get_scale()
  let skew = transform.a * transform.c + transform.b * transform.d
  let use_transformed = (sx - sy).abs() > eps || skew.abs() > eps
  let inv = transform.inverse()
  fn to_local_angle(angle : Double) -> Double {
    let dx = @math.cos(angle)
    let dy = @math.sin(angle)
    let lx = inv.a * dx + inv.c * dy
    let ly = inv.b * dx + inv.d * dy
    @math.atan2(ly, lx)
  }

  fn apply_vec(
    dx : Double,
    dy : Double,
    t : Transform,
    use_t : Bool,
  ) -> (Double, Double) {
    if use_t {
      (t.a * dx + t.c * dy, t.b * dx + t.d * dy)
    } else {
      (dx, dy)
    }
  }

  fn normalize(
    dx : Double,
    dy : Double,
    eps : Double,
  ) -> (Double, Double, Double) {
    let len = (dx * dx + dy * dy).sqrt()
    if len < eps {
      (0.0, 0.0, len)
    } else {
      (dx / len, dy / len, len)
    }
  }

  fn angle_from_vec(
    dx : Double,
    dy : Double,
    use_t : Bool,
    t : Transform,
  ) -> Double {
    let (vx, vy) = apply_vec(dx, dy, t, use_t)
    let ang = @math.atan2(vy, vx)
    if use_t {
      to_local_angle(ang)
    } else {
      ang
    }
  }

  fn angle_mid_vec(
    in_dx : Double,
    in_dy : Double,
    out_dx : Double,
    out_dy : Double,
    eps : Double,
  ) -> Double {
    let (ux1, uy1, l1) = normalize(in_dx, in_dy, eps)
    let (ux2, uy2, l2) = normalize(out_dx, out_dy, eps)
    if l1 < eps && l2 < eps {
      0.0
    } else if l1 < eps {
      @math.atan2(out_dy, out_dx)
    } else if l2 < eps {
      @math.atan2(in_dy, in_dx)
    } else {
      let sx = ux1 + ux2
      let sy = uy1 + uy2
      if sx * sx + sy * sy < eps * eps {
        @math.atan2(out_dx, -out_dy)
      } else {
        @math.atan2(sy, sx)
      }
    }
  }

  let sub_last = subpaths.length() - 1
  for sub_idx in 0..<subpaths.length() {
    let sub = subpaths[sub_idx]
    if sub.points.length() < 2 {
      continue
    }
    let last = sub.points.length() - 1
    for i in 0..<sub.points.length() {
      let marker_id = if sub_idx == 0 && i == 0 {
        node.marker_start
      } else if sub_idx == sub_last && i == last {
        node.marker_end
      } else {
        node.marker_mid
      }
      match marker_id {
        Some(id) =>
          match resources.markers.get(id) {
            Some(marker) => {
              let p = sub.points[i]
              let angle = if i == 0 {
                if p.has_in && p.has_out {
                  let (in_dx, in_dy) = apply_vec(
                    p.in_dx,
                    p.in_dy,
                    transform,
                    use_transformed,
                  )
                  let (out_dx, out_dy) = apply_vec(
                    p.out_dx,
                    p.out_dy,
                    transform,
                    use_transformed,
                  )
                  let ang = angle_mid_vec(in_dx, in_dy, out_dx, out_dy, eps)
                  if use_transformed {
                    to_local_angle(ang)
                  } else {
                    ang
                  }
                } else if p.has_out {
                  angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
                } else if p.has_in {
                  angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
                } else {
                  0.0
                }
              } else if i == last {
                if p.has_in {
                  angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
                } else if p.has_out {
                  angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
                } else {
                  0.0
                }
              } else if p.has_in && p.has_out {
                let (in_dx, in_dy) = apply_vec(
                  p.in_dx,
                  p.in_dy,
                  transform,
                  use_transformed,
                )
                let (out_dx, out_dy) = apply_vec(
                  p.out_dx,
                  p.out_dy,
                  transform,
                  use_transformed,
                )
                let ang = angle_mid_vec(in_dx, in_dy, out_dx, out_dy, eps)
                if use_transformed {
                  to_local_angle(ang)
                } else {
                  ang
                }
              } else if p.has_in {
                angle_from_vec(p.in_dx, p.in_dy, use_transformed, transform)
              } else if p.has_out {
                angle_from_vec(p.out_dx, p.out_dy, use_transformed, transform)
              } else {
                0.0
              }
              render_marker_instance(
                marker,
                p.x,
                p.y,
                angle,
                node,
                transform,
                ctx,
                resources,
                node_color,
              )
            }
            None => ()
          }
        None => ()
      }
    }
  }
}

///|

///|
fn render_polyline(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  resources : RenderResources,
  node_color : Color,
) -> Unit {
  if points.length() < 2 {
    return
  }
  render_path(
    points_path_commands(points, false),
    node,
    transform,
    ctx,
    node_color,
    resources,
  )
}

///|
fn render_polygon(
  points : Array[(Double, Double)],
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  if points.length() < 3 {
    return
  }
  render_path(
    points_path_commands(points, true),
    node,
    transform,
    ctx,
    node_color,
    resources,
  )
}

///|
