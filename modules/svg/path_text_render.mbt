///|
fn render_path(
  commands : Array[PathCommand],
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  let polylines = path_to_polylines(commands, device_path_flatness(transform))
  let closed_subpaths = path_subpath_closed_flags(commands)
  let transformed_polylines : Array[Array[(Double, Double)]] = []
  for polyline in polylines {
    let transformed = polyline.map(fn(p) { transform.apply(p.0, p.1) })
    transformed_polylines.push(transformed)
  }
  let fill_polylines : Array[Array[(Double, Double)]] = []
  for polyline in transformed_polylines {
    if polyline.length() >= 3 && polygon_area_abs(polyline) > 0.000000000001 {
      fill_polylines.push(polyline)
    }
  }
  fn draw_fill() -> Unit {
    match resolve_paint_for_render(node.fill, node_color, resources) {
      ResolvedPaint::SolidColor(color) =>
        if node.fill_opacity > 0.0 {
          let fill_color = apply_opacity(
            color,
            node.fill_opacity * node.opacity,
          )
          if fill_polylines.length() > 0 {
            raster_contours_coverage(
              fill_polylines,
              fill_color,
              node.fill_rule,
              ctx.setter,
              ctx.width,
              ctx.height,
            )
          }
        }
      ResolvedPaint::LinearGrad(gradient) =>
        if node.fill_opacity > 0.0 {
          let bbox = get_shape_bounds(node.shape)
          let inverse = transform.inverse()
          let gradient_setter : ColorSink = {
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
                    node.fill_opacity * node.opacity,
                  ),
                  coverage_color.a * 257,
                ),
              )
            },
          }
          raster_contours_coverage(
            fill_polylines,
            Color::white(),
            node.fill_rule,
            gradient_setter,
            ctx.width,
            ctx.height,
          )
        }
      ResolvedPaint::RadialGrad(gradient) =>
        if node.fill_opacity > 0.0 {
          let bbox = get_shape_bounds(node.shape)
          let inverse = transform.inverse()
          let gradient_setter : ColorSink = {
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
                    node.fill_opacity * node.opacity,
                  ),
                  coverage_color.a * 257,
                ),
              )
            },
          }
          raster_contours_coverage(
            fill_polylines,
            Color::white(),
            node.fill_rule,
            gradient_setter,
            ctx.width,
            ctx.height,
          )
        }
      ResolvedPaint::Pattern(pattern) =>
        if node.fill_opacity > 0.0 {
          let bbox = get_shape_bounds(node.shape)
          match
            make_pattern_setter(
              pattern,
              bbox,
              transform,
              ctx,
              resources,
              node.fill_opacity * node.opacity,
              node.image_sampling,
            ) {
            Some(pattern_setter) =>
              raster_contours_coverage(
                fill_polylines,
                Color::white(),
                node.fill_rule,
                pattern_setter,
                ctx.width,
                ctx.height,
              )
            None => ()
          }
        }
      _ => ()
    }
  }

  fn draw_stroke() -> Unit {
    let stroke_paint = resolve_paint_for_render(
      node.stroke.paint,
      node_color,
      resources,
    )
    match stroke_paint {
      ResolvedPaint::SolidColor(color) =>
        for index, polyline in polylines {
          if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
            let stroke_color = apply_opacity(
              color,
              node.stroke_opacity * node.opacity,
            )
            let closed = index < closed_subpaths.length() &&
              closed_subpaths[index]
            raster_affine_stroke(
              polyline,
              node.stroke,
              transform,
              stroke_color,
              ctx.setter,
              ctx.width,
              ctx.height,
              closed,
            )
          }
        }
      ResolvedPaint::LinearGrad(_)
      | ResolvedPaint::RadialGrad(_)
      | ResolvedPaint::Pattern(_) =>
        if node.stroke_opacity > 0.0 && node.stroke.width > 0.0 {
          match
            make_paint_server_setter(
              stroke_paint,
              node.shape,
              transform,
              ctx,
              resources,
              node.stroke_opacity * node.opacity,
              node.image_sampling,
            ) {
            Some(stroke_setter) =>
              for index, polyline in polylines {
                let closed = index < closed_subpaths.length() &&
                  closed_subpaths[index]
                raster_affine_stroke(
                  polyline,
                  node.stroke,
                  transform,
                  Color::white(),
                  stroke_setter,
                  ctx.width,
                  ctx.height,
                  closed,
                )
              }
            None => ()
          }
        }
      _ => ()
    }
  }

  fn draw_markers() -> Unit {
    render_markers_for_path_commands(
      commands, node, transform, ctx, resources, node_color,
    )
  }

  render_paint_order(node.paint_order, draw_fill, draw_stroke, draw_markers)
}

///|
fn render_text(
  x : Double,
  y : Double,
  text : String,
  font_size : Double,
  node : SVGNode,
  transform : Transform,
  ctx : RenderState,
  node_color : Color,
  resources : RenderResources,
) -> Unit {
  let (tx, ty) = transform.apply(x, y)
  let (sx, _) = transform.get_scale()
  let scaled_size = (font_size * sx).to_int()
  // Fill color for text
  let fill_paint = resolve_paint_for_render(node.fill, node_color, resources)
  let paint_server_setter = match fill_paint {
    ResolvedPaint::LinearGrad(_)
    | ResolvedPaint::RadialGrad(_)
    | ResolvedPaint::Pattern(_) =>
      if node.fill_opacity > 0.0 {
        make_paint_server_setter(
          fill_paint,
          node.shape,
          transform,
          ctx,
          resources,
          node.fill_opacity * node.opacity,
          node.image_sampling,
        )
      } else {
        None
      }
    _ => None
  }
  match ctx.text_to_paths {
    Some(to_paths) => {
      // Use font callback: render each character as path commands
      let fill_color : Color? = match fill_paint {
        ResolvedPaint::SolidColor(color) =>
          if node.fill_opacity > 0.0 {
            Some(apply_opacity(color, node.fill_opacity * node.opacity))
          } else {
            None
          }
        ResolvedPaint::LinearGrad(_)
        | ResolvedPaint::RadialGrad(_)
        | ResolvedPaint::Pattern(_) =>
          match paint_server_setter {
            Some(_) => Some(Color::white())
            None => None
          }
        _ => None
      }
      let setter = paint_server_setter.unwrap_or(ctx.setter)
      let mut cursor_x = tx
      for i in 0..<text.length() {
        let codepoint = text[i].unsafe_to_char().to_int()
        let (cmds, advance) = to_paths(codepoint, font_size * sx)
        // Translate commands to cursor position
        let translated = translate_path_commands(cmds, cursor_x, ty)
        match fill_color {
          Some(color) =>
            raster_contours_coverage(
              path_to_polylines(
                translated,
                device_path_flatness(Transform::identity()),
              ),
              color,
              NonZero,
              setter,
              ctx.width,
              ctx.height,
            )
          None => ()
        }
        cursor_x = cursor_x + advance
      }
    }
    None =>
      // Fallback: bitmap font
      match fill_paint {
        ResolvedPaint::SolidColor(color) =>
          if node.fill_opacity > 0.0 {
            let fill_color = apply_opacity(
              color,
              node.fill_opacity * node.opacity,
            )
            raster_text(
              tx.round().to_int(),
              ty.round().to_int(),
              text,
              scaled_size,
              fill_color,
              ctx.setter,
            )
          }
        ResolvedPaint::LinearGrad(_)
        | ResolvedPaint::RadialGrad(_)
        | ResolvedPaint::Pattern(_) =>
          if node.fill_opacity > 0.0 {
            match paint_server_setter {
              Some(setter) =>
                raster_text(
                  tx.round().to_int(),
                  ty.round().to_int(),
                  text,
                  scaled_size,
                  Color::white(),
                  setter,
                )
              None => ()
            }
          }
        _ => ()
      }
  }
}

///|
/// Translate path commands by (dx, dy) offset
fn translate_path_commands(
  commands : Array[PathCommand],
  dx : Double,
  dy : Double,
) -> Array[PathCommand] {
  let result : Array[PathCommand] = []
  for cmd in commands {
    let translated : PathCommand = match cmd {
      MoveTo(x, y) => MoveTo(x + dx, y + dy)
      LineTo(x, y) => LineTo(x + dx, y + dy)
      QuadraticCurveTo(cx, cy, x, y) =>
        QuadraticCurveTo(cx + dx, cy + dy, x + dx, y + dy)
      CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        CurveTo(cx1 + dx, cy1 + dy, cx2 + dx, cy2 + dy, x + dx, y + dy)
      ClosePath => ClosePath
      other => other
    }
    result.push(translated)
  }
  result
}

///|
/// Apply opacity to a color
fn apply_opacity(color : Color, opacity : Double) -> Color {
  if opacity >= 1.0 {
    color
  } else if opacity <= 0.0 {
    Color::transparent()
  } else {
    PremulColor16::from_color(color)
    .scaled(unit_to_channel16(opacity))
    .to_color()
  }
}

///|
fn apply_coverage(color : Color, coverage : Int) -> Color {
  PremulColor16::from_color(color).scaled(clamp_channel16(coverage)).to_color()
}

///|
/// Create a RenderState with default settings
fn RenderState::new(
  setter : ColorSink,
  width : Int,
  height : Int,
) -> RenderState {
  {
    setter,
    width,
    height,
    flatness: 0.5,
    clip: None,
    text_to_paths: None,
    image_resolver: None,
    target_image: None,
    blend_pixel: None,
    diagnostics: [],
  }
}
