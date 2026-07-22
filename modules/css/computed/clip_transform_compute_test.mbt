///|
test "parse_clip - auto" {
  let clip = @computed.parse_clip("auto")
  inspect(clip, content="auto")
}

///|
test "parse_clip - rect with px values" {
  let clip = @computed.parse_clip("rect(1px, 1px, 1px, 1px)")
  inspect(clip, content="rect(1, 1, 1, 1)")
}

///|
test "parse_clip - rect with comma separated values" {
  let clip = @computed.parse_clip("rect(10px, 100px, 50px, 5px)")
  inspect(clip, content="rect(10, 100, 50, 5)")
}

///|
test "parse_clip - rect with space separated values" {
  let clip = @computed.parse_clip("rect(10px 100px 50px 5px)")
  inspect(clip, content="rect(10, 100, 50, 5)")
}

///|
test "compute_inline clip property" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip: rect(1px, 1px, 1px, 1px)", ctx)
  inspect(style.clip, content="rect(1, 1, 1, 1)")
}

///|
test "compute_inline clip auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip: auto", ctx)
  inspect(style.clip, content="auto")
}

///|
test "compute_inline transform scale" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("transform: scaleX(2)", ctx)
  inspect(style.transform.scale_x, content="2")
  inspect(style.transform.scale_y, content="1")
}

///|
test "compute_inline transform rotate quarter turn" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("transform: rotate(90deg)", ctx)
  inspect(style.transform.rotate_degrees, content="90")
  inspect(style.transform.quarter_turns(), content="1")
}

///|
test "compute_inline transform skew" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: skewX(45deg) skewY(-15deg)", ctx,
  )
  inspect(style.transform.skew_x_degrees, content="45")
  inspect(style.transform.skew_y_degrees, content="-15")
}

///|
test "compute_inline transform matrix" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: matrix(1, 0, -1, 1, 64, 0)", ctx,
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
test "compute_inline transform matrix3d as 2D affine matrix" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1)", ctx,
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
test "parse_clip_path - inset" {
  let clip_path = @computed.parse_clip_path("inset(16px 0 25% 4px)")
  match clip_path {
    Inset(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 0, -0.25, 4]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "parse_clip_path - rect" {
  let clip_path = @computed.parse_clip_path("rect(16px 128px 64px 16px)")
  match clip_path {
    Rect(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 128, 64, 16]")
    _ => fail("expected rect clip-path")
  }
}

///|
test "parse_clip_path - xywh" {
  let clip_path = @computed.parse_clip_path("xywh(16px 16px 112px 48px)")
  match clip_path {
    Xywh(x, y, width, height) =>
      debug_inspect([x, y, width, height], content="[16, 16, 112, 48]")
    _ => fail("expected xywh clip-path")
  }
}

///|
test "parse_clip_path - circle" {
  let clip_path = @computed.parse_clip_path("circle(24px at 24px 24px)")
  match clip_path {
    Circle(radius, center_x, center_y) =>
      debug_inspect([radius, center_x, center_y], content="[24, 24, 24]")
    _ => fail("expected circle clip-path")
  }
}

///|
test "parse_clip_path - ellipse" {
  let clip_path = @computed.parse_clip_path("ellipse(24px 16px at 32px 32px)")
  match clip_path {
    Ellipse(radius_x, radius_y, center_x, center_y) =>
      debug_inspect(
        [radius_x, radius_y, center_x, center_y],
        content="[24, 16, 32, 32]",
      )
    _ => fail("expected ellipse clip-path")
  }
}

///|
test "parse_clip_path - polygon" {
  let clip_path = @computed.parse_clip_path(
    "polygon(32px 0, 64px 64px, 0 64px)",
  )
  match clip_path {
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
test "parse_clip_path - path as polygon" {
  let clip_path = @computed.parse_clip_path("path(\"M 32 0 L 64 64 L 0 64 Z\")")
  match clip_path {
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
test "parse_clip_path - quadratic path as polygon" {
  let clip_path = @computed.parse_clip_path("path(\"M 0 64 Q 32 0 64 64 Z\")")
  match clip_path {
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
test "parse_clip_path - cubic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 C 0 0 64 0 64 64 Z\")",
  )
  match clip_path {
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
test "parse_clip_path - smooth quadratic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 Q 16 0 32 64 T 64 64 Z\")",
  )
  match clip_path {
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
test "parse_clip_path - smooth cubic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 C 0 0 32 0 32 64 S 64 128 64 64 Z\")",
  )
  match clip_path {
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
test "parse_clip_path - arc path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 A 32 32 0 0 1 64 64 Z\")",
  )
  match clip_path {
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
test "compute_inline clip-path property" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip-path: inset(16px 0 0 16px)", ctx)
  match style.clip_path {
    Inset(top, right, bottom, left) =>
      debug_inspect([top, right, bottom, left], content="[16, 0, 0, 16]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "compute_inline border-collapse" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-collapse: collapse", ctx)
  inspect(style.border_collapse, content="Collapse")
}

///|
test "compute_inline border-collapse separate" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-collapse: separate", ctx)
  inspect(style.border_collapse, content="Separate")
}

///|
test "compute_inline border-spacing single value sets both axes" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-spacing: 8px", ctx)
  inspect(style.border_spacing, content="8")
  inspect(style.border_spacing_vertical, content="8")
}

///|
test "compute_inline border-spacing two values sets vertical axis" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-spacing: 50px 100px", ctx)
  inspect(style.border_spacing, content="50")
  inspect(style.border_spacing_vertical, content="100")
}

///|
test "compute_inline margin-trim block" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin-trim: block", ctx)
  inspect(style.margin_trim, content="Block")
}

///|
test "compute_inline margin-trim block-start" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin-trim: block-start", ctx)
  inspect(style.margin_trim, content="BlockStart")
}

///|
test "compute_inline caption-side top" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("caption-side: top", ctx)
  inspect(style.caption_side, content="Top")
}

///|
test "compute_inline caption-side bottom" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("caption-side: bottom", ctx)
  inspect(style.caption_side, content="Bottom")
}

///|
test "compute_inline background linear-gradient" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "background: linear-gradient(to right, #ff0000, #0000ff)", ctx,
  )
  inspect(
    style.background_image,
    content=(
      #|Gradient({angle_deg: 90, stops: [{color: rgb(255, 0, 0), position: 0}, {color: rgb(0, 0, 255), position: 1}]})
    ),
  )
}

///|
test "compute_inline background linear-gradient resolves custom properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "--g-angle: 135deg; --g-color-0: #c4b5fd; --g-position-0: 0%; --g-color-1: #2dd4bf; --g-position-1: 100%; background: linear-gradient(var(--g-angle), var(--g-color-0) var(--g-position-0), var(--g-color-1) var(--g-position-1))",
    ctx,
  )
  inspect(
    style.background_image,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(196, 181, 253), position: 0}, {color: rgb(45, 212, 191), position: 1}]})
    ),
  )
}

///|
test "compute_inline border-radius percentage" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-radius: 50%", ctx)
  // Negative encodes percentage for render-time resolution
  inspect(
    style.border_top_left_radius,
    content=(
      #|-0.5
    ),
  )
  inspect(
    style.border_top_right_radius,
    content=(
      #|-0.5
    ),
  )
}

///|
test "parse_linear_gradient basic" {
  let result = @computed.parse_linear_gradient(
    "linear-gradient(135deg, #667eea, #764ba2)",
  )
  inspect(
    result,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(102, 126, 234), position: 0}, {color: rgb(118, 75, 162), position: 1}]})
    ),
  )
}

///|
test "compute_inline box-shadow parses multiple and inset shadows" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "box-shadow: 2px 4px 8px rgba(0,0,0,0.25), inset 0 2px 6px #112233", ctx,
  )

  inspect(style.box_shadows.length(), content="2")

  let first = style.box_shadows[0]
  inspect(first.inset, content="false")
  inspect(first.offset_x, content="2")
  inspect(first.offset_y, content="4")
  inspect(first.blur_radius, content="8")
  inspect(first.spread_radius, content="0")
  inspect(first.color.r, content="0")
  inspect(first.color.g, content="0")
  inspect(first.color.b, content="0")
  inspect(first.color.a, content="0.25")

  let second = style.box_shadows[1]
  inspect(second.inset, content="true")
  inspect(second.offset_x, content="0")
  inspect(second.offset_y, content="2")
  inspect(second.blur_radius, content="6")
  inspect(second.spread_radius, content="0")
  inspect(second.color.r, content="17")
  inspect(second.color.g, content="34")
  inspect(second.color.b, content="51")
}

///|
test "compute_inline box-shadow parses rgba color with spaced commas" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "box-shadow: 0 20px 60px rgba(15, 23, 42, 0.18)", ctx,
  )

  inspect(style.box_shadows.length(), content="1")
  let shadow = style.box_shadows[0]
  inspect(shadow.offset_x, content="0")
  inspect(shadow.offset_y, content="20")
  inspect(shadow.blur_radius, content="60")
  inspect(shadow.color.r, content="15")
  inspect(shadow.color.g, content="23")
  inspect(shadow.color.b, content="42")
  inspect(shadow.color.a, content="0.18")
}
