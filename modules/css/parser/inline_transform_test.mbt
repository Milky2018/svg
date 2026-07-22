///|
test "parse transform translate" {
  let style = parse_inline_style("transform: translate(10px, 20px)")
  inspect(style.transform.translate_x, content="Length(10)")
  inspect(style.transform.translate_y, content="Length(20)")
}

///|
test "parse transform translateX" {
  let style = parse_inline_style("transform: translateX(50%)")
  inspect(style.transform.translate_x, content="Percent(0.5)")
  inspect(style.transform.translate_y, content="Length(0)")
}

///|
test "parse transform translateY" {
  let style = parse_inline_style("transform: translateY(-100px)")
  inspect(style.transform.translate_x, content="Length(0)")
  inspect(style.transform.translate_y, content="Length(-100)")
}

///|
test "parse transform translate with percentage" {
  let style = parse_inline_style("transform: translate(-50%, -50%)")
  inspect(style.transform.translate_x, content="Percent(-0.5)")
  inspect(style.transform.translate_y, content="Percent(-0.5)")
}

///|
test "parse transform translate converts rem/physical units" {
  let style = parse_inline_style("transform: translate(2rem, 1in)")
  inspect(style.transform.translate_x, content="Length(32)")
  inspect(style.transform.translate_y, content="Length(96)")
}

///|
test "parse transform scale" {
  let style = parse_inline_style("transform: scale(2, 0.5)")
  inspect(style.transform.scale_x, content="2")
  inspect(style.transform.scale_y, content="0.5")
}

///|
test "parse transform rotate" {
  let style = parse_inline_style("transform: rotate(90deg)")
  inspect(style.transform.rotate_degrees, content="90")
  inspect(style.transform.quarter_turns(), content="1")
}

///|
test "parse transform skew" {
  let style = parse_inline_style("transform: skew(45deg, -15deg)")
  inspect(style.transform.skew_x_degrees, content="45")
  inspect(style.transform.skew_y_degrees, content="-15")
}

///|
test "parse transform matrix" {
  let style = parse_inline_style("transform: matrix(1, 0, -1, 1, 64, 0)")
  inspect(style.transform.has_matrix, content="true")
  debug_inspect(
    [
      style.transform.matrix_a,
      style.transform.matrix_b,
      style.transform.matrix_c,
      style.transform.matrix_d,
      style.transform.matrix_e,
      style.transform.matrix_f,
    ],
    content="[1, 0, -1, 1, 64, 0]",
  )
}

///|
test "parse transform matrix3d as 2D affine matrix" {
  let style = parse_inline_style(
    "transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1)",
  )
  inspect(style.transform.has_matrix, content="true")
  debug_inspect(
    [
      style.transform.matrix_a,
      style.transform.matrix_b,
      style.transform.matrix_c,
      style.transform.matrix_d,
      style.transform.matrix_e,
      style.transform.matrix_f,
    ],
    content="[1, 0, -1, 1, 64, 0]",
  )
}

///|
test "parse pointer-events none" {
  let style = parse_inline_style("pointer-events: none")
  inspect(style.pointer_events, content="None")
}

///|
test "parse clip-path inset" {
  let style = parse_inline_style("clip-path: inset(16px 0 25% 4px)")
  match style.clip_path {
    Inset(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 0, -0.25, 4]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "parse clip-path rect" {
  let style = parse_inline_style("clip-path: rect(16px 128px 64px 16px)")
  match style.clip_path {
    Rect(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 128, 64, 16]")
    _ => fail("expected rect clip-path")
  }
}

///|
test "parse clip-path xywh" {
  let style = parse_inline_style("clip-path: xywh(16px 16px 112px 48px)")
  match style.clip_path {
    Xywh(x, y, width, height) =>
      debug_inspect([x, y, width, height], content="[16, 16, 112, 48]")
    _ => fail("expected xywh clip-path")
  }
}

///|
test "parse clip-path circle" {
  let style = parse_inline_style("clip-path: circle(24px at 24px 24px)")
  match style.clip_path {
    Circle(radius, center_x, center_y) =>
      debug_inspect([radius, center_x, center_y], content="[24, 24, 24]")
    _ => fail("expected circle clip-path")
  }
}

///|
test "parse clip-path ellipse" {
  let style = parse_inline_style("clip-path: ellipse(24px 16px at 32px 32px)")
  match style.clip_path {
    Ellipse(radius_x, radius_y, center_x, center_y) =>
      debug_inspect(
        [radius_x, radius_y, center_x, center_y],
        content="[24, 16, 32, 32]",
      )
    _ => fail("expected ellipse clip-path")
  }
}

///|
test "parse clip-path polygon" {
  let style = parse_inline_style(
    "clip-path: polygon(32px 0, 64px 64px, 0 64px)",
  )
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="3")
      let (x0, y0) = points[0]
      let (x1, y1) = points[1]
      let (x2, y2) = points[2]
      debug_inspect([x0, y0, x1, y1, x2, y2], content="[32, 0, 64, 64, 0, 64]")
    }
    _ => fail("expected polygon clip-path")
  }
}

///|
test "parse clip-path path as polygon" {
  let style = parse_inline_style("clip-path: path(\"M 32 0 L 64 64 L 0 64 Z\")")
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="3")
      let (x0, y0) = points[0]
      let (x1, y1) = points[1]
      let (x2, y2) = points[2]
      debug_inspect([x0, y0, x1, y1, x2, y2], content="[32, 0, 64, 64, 0, 64]")
    }
    _ => fail("expected path clip-path polygon")
  }
}

///|
test "parse clip-path quadratic path as polygon" {
  let style = parse_inline_style("clip-path: path(\"M 0 64 Q 32 0 64 64 Z\")")
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      debug_inspect([x0, y0, x4, y4, x8, y8], content="[0, 64, 32, 32, 64, 64]")
    }
    _ => fail("expected quadratic path clip-path polygon")
  }
}

///|
test "parse clip-path cubic path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 C 0 0 64 0 64 64 Z\")",
  )
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      debug_inspect([x0, y0, x4, y4, x8, y8], content="[0, 64, 32, 16, 64, 64]")
    }
    _ => fail("expected cubic path clip-path polygon")
  }
}

///|
test "parse clip-path smooth quadratic path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 Q 16 0 32 64 T 64 64 Z\")",
  )
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="17")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      let (x12, y12) = points[12]
      let (x16, y16) = points[16]
      debug_inspect(
        [x0, y0, x4, y4, x8, y8, x12, y12, x16, y16],
        content="[0, 64, 16, 32, 32, 64, 48, 96, 64, 64]",
      )
    }
    _ => fail("expected smooth quadratic path clip-path polygon")
  }
}

///|
test "parse clip-path smooth cubic path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 C 0 0 32 0 32 64 S 64 128 64 64 Z\")",
  )
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="17")
      let (x0, y0) = points[0]
      let (x8, y8) = points[8]
      let (x12, y12) = points[12]
      let (x16, y16) = points[16]
      debug_inspect(
        [x0, y0, x8, y8, x12, y12, x16, y16],
        content="[0, 64, 32, 64, 48, 112, 64, 64]",
      )
    }
    _ => fail("expected smooth cubic path clip-path polygon")
  }
}

///|
test "parse clip-path arc path as polygon" {
  let style = parse_inline_style(
    "clip-path: path(\"M 0 64 A 32 32 0 0 1 64 64 Z\")",
  )
  match style.clip_path {
    Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      assert_true((x0 - 0.0).abs() < 0.001)
      assert_true((y0 - 64.0).abs() < 0.001)
      assert_true((x4 - 32.0).abs() < 0.001)
      assert_true((y4 - 32.0).abs() < 0.001)
      assert_true((x8 - 64.0).abs() < 0.001)
      assert_true((y8 - 64.0).abs() < 0.001)
    }
    _ => fail("expected arc path clip-path polygon")
  }
}

///|
test "parse justify-self center" {
  let style = parse_inline_style("justify-self: center")
  inspect(style.justify_self, content="Center")
}

///|
test "parse align-self center" {
  let style = parse_inline_style("align-self: center")
  inspect(style.align_self, content="Center")
}

///|
test "parse justify-items center" {
  let style = parse_inline_style("justify-items: center")
  inspect(style.justify_items, content="Center")
}
