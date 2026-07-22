///|
fn build_substring_local(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  let len = s.length()
  while i < end && i < len {
    buf.write_char(Int::unsafe_to_char(s[i].to_int()))
    i = i + 1
  }
  buf.to_string()
}

///|
fn string_ends_with_local(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    return false
  }
  let start = s.length() - suffix.length()
  for i in 0..<suffix.length() {
    if s[start + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
fn trim_string_local(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = Int::unsafe_to_char(s[start].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = Int::unsafe_to_char(s[end - 1].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  build_substring_local(s, start, end)
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn char_at(s : String, i : Int) -> Char {
  Int::unsafe_to_char(s[i].to_int())
}

///|
fn parse_simple_number(s : String) -> Double {
  let s = trim_string_local(s)
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  let first = char_at(s, i)
  if first == '-' {
    sign = -1.0
    i = i + 1
  } else if first == '+' {
    i = i + 1
  }
  while i < len {
    let c = char_at(s, i)
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  if i < len && char_at(s, i) == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let c = char_at(s, i)
      if c >= '0' && c <= '9' {
        result = result + (c.to_int() - 48).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  sign * result
}

///|
fn parse_length_simple(s : String) -> Double {
  let s = trim_string_local(s)
  let cleaned = if string_ends_with_local(s, "px") {
    build_substring_local(s, 0, s.length() - 2)
  } else if string_ends_with_local(s, "em") || string_ends_with_local(s, "pt") {
    build_substring_local(s, 0, s.length() - 2)
  } else if string_ends_with_local(s, "%") {
    build_substring_local(s, 0, s.length() - 1)
  } else {
    s
  }
  parse_simple_number(cleaned)
}

///|
fn replace_viewport_units(value : String, vw : Double, vh : Double) -> String {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c = char_at(value, i)
    let is_number_start = (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' ||
      c == '+'
    if is_number_start {
      let start = i
      i = i + 1
      while i < len {
        let nc = char_at(value, i)
        if (nc >= '0' && nc <= '9') || nc == '.' {
          i = i + 1
        } else {
          break
        }
      }
      let num_str = build_substring_local(value, start, i)
      if i + 1 < len && char_at(value, i) == 'v' {
        let unit = char_at(value, i + 1)
        if unit == 'w' || unit == 'h' {
          let num = parse_simple_number(num_str)
          let val = if unit == 'w' {
            num * vw / 100.0
          } else {
            num * vh / 100.0
          }
          buf.write_string(val.to_string())
          i = i + 2
          continue
        }
      }
      buf.write_string(num_str)
      continue
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
fn match_at(s : String, idx : Int, pat : String) -> Bool {
  if idx + pat.length() > s.length() {
    return false
  }
  for i in 0..<pat.length() {
    if s[idx + i] != pat[i] {
      return false
    }
  }
  true
}

///|
fn find_attr_value(svg : String, name : String) -> String? {
  let len = svg.length()
  let mut end = len
  for i in 0..<len {
    if char_at(svg, i) == '>' {
      end = i
      break
    }
  }
  let mut i = 0
  while i < end {
    if match_at(svg, i, name) {
      let mut j = i + name.length()
      while j < end && is_space_char(char_at(svg, j)) {
        j = j + 1
      }
      if j < end && char_at(svg, j) == '=' {
        j = j + 1
        while j < end && is_space_char(char_at(svg, j)) {
          j = j + 1
        }
        if j >= end {
          return None
        }
        let quote = char_at(svg, j)
        if quote == '"' || quote == '\'' {
          j = j + 1
          let start = j
          while j < end && char_at(svg, j) != quote {
            j = j + 1
          }
          if j > start {
            return Some(build_substring_local(svg, start, j))
          }
          return None
        } else {
          let start = j
          while j < end &&
                !is_space_char(char_at(svg, j)) &&
                char_at(svg, j) != '>' {
            j = j + 1
          }
          if j > start {
            return Some(build_substring_local(svg, start, j))
          }
          return None
        }
      }
    }
    i = i + 1
  }
  None
}

///|
fn extract_svg_size(svg : String) -> (Double, Double) {
  let width = match find_attr_value(svg, "width") {
    Some(v) => parse_length_simple(v)
    None => 0.0
  }
  let height = match find_attr_value(svg, "height") {
    Some(v) => parse_length_simple(v)
    None => 0.0
  }
  (width, height)
}

///|
fn render_image(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  href : String,
  transform : Transform,
  ctx : RenderState,
  preserve_aspect_ratio : PreserveAspectRatio,
  preserve_aspect_ratio_is_set : Bool,
  sampling : ImageSampling,
  opacity : Double,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  if href.length() == 0 {
    return
  }
  let embedded_svg = match decode_data_svg(href) {
    Some(svg) => Some(svg)
    None => {
      let trimmed = trim_string(href)
      if string_starts_with(trimmed, "<svg") {
        Some(trimmed)
      } else {
        None
      }
    }
  }
  match embedded_svg {
    Some(svg) =>
      render_embedded_svg_image(
        svg, x, y, width, height, transform, ctx, preserve_aspect_ratio, preserve_aspect_ratio_is_set,
        sampling, opacity,
      )
    None =>
      match ctx.image_resolver {
        Some(resolve) =>
          match resolve(href) {
            Some(image) =>
              render_raster_image(
                image, x, y, width, height, transform, ctx, preserve_aspect_ratio,
                sampling, opacity,
              )
            None =>
              ctx.diagnostics.push({
                kind: ResourceUnresolved,
                stage: Image,
                resource: href,
                node_id: "",
              })
          }
        None =>
          ctx.diagnostics.push({
            kind: ResourceUnresolved,
            stage: Image,
            resource: href,
            node_id: "",
          })
      }
  }
}

///|
fn render_embedded_svg_image(
  svg : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  transform : Transform,
  ctx : RenderState,
  preserve_aspect_ratio : PreserveAspectRatio,
  preserve_aspect_ratio_is_set : Bool,
  sampling : ImageSampling,
  opacity : Double,
) -> Unit {
  let image_width = ceil_to_int(width)
  let image_height = ceil_to_int(height)
  if image_width <= 0 || image_height <= 0 {
    return
  }
  let processed = replace_viewport_units(
    svg,
    image_width.to_double(),
    image_height.to_double(),
  )
  match parse_svg_document(processed) {
    Some(doc) => {
      if preserve_aspect_ratio_is_set {
        doc.root.preserve_aspect_ratio = preserve_aspect_ratio
      }
      if doc.root.view_box is None {
        let (svg_w, svg_h) = extract_svg_size(processed)
        if svg_w > 0.0 && svg_h > 0.0 {
          doc.root.view_box = Some({
            min_x: 0.0,
            min_y: 0.0,
            width: svg_w,
            height: svg_h,
          })
        }
      }
      let image = Image::new(image_width, image_height)
      let setter = make_image_compositing_setter(image)
      let image_ctx = {
        ..RenderState::new(setter, image_width, image_height),
        image_resolver: ctx.image_resolver,
        target_image: Some(image),
        diagnostics: ctx.diagnostics,
      }
      doc.render(image_ctx)
      render_raster_image(
        image,
        x,
        y,
        width,
        height,
        transform,
        ctx,
        { align: None, meet_or_slice: Meet },
        sampling,
        opacity,
      )
    }
    None =>
      ctx.diagnostics.push({
        kind: ParseFailed,
        stage: Image,
        resource: "embedded-svg",
        node_id: "",
      })
  }
}

///|
fn render_raster_image(
  image : Image,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  transform : Transform,
  ctx : RenderState,
  preserve_aspect_ratio : PreserveAspectRatio,
  sampling : ImageSampling,
  opacity : Double,
) -> Unit {
  if image.width <= 0 || image.height <= 0 || !transform.is_invertible() {
    return
  }
  let source_to_viewport = ViewBox::{
    min_x: 0.0,
    min_y: 0.0,
    width: image.width.to_double(),
    height: image.height.to_double(),
  }.get_transform(width, height, preserve_aspect_ratio)
  let source_to_local = Transform::translate(x, y).multiply(source_to_viewport)
  let source_to_device = transform.multiply(source_to_local)
  if !source_to_device.is_invertible() {
    return
  }
  let device_bounds = transform.apply_bbox(
    BoundingBox::from_rect(x, y, width, height),
  )
  let mut min_x = floor_to_int(device_bounds.min_x)
  let mut min_y = floor_to_int(device_bounds.min_y)
  let mut max_x = ceil_to_int(device_bounds.max_x)
  let mut max_y = ceil_to_int(device_bounds.max_y)
  if min_x < 0 {
    min_x = 0
  }
  if min_y < 0 {
    min_y = 0
  }
  if max_x > ctx.width {
    max_x = ctx.width
  }
  if max_y > ctx.height {
    max_y = ctx.height
  }
  let device_to_local = transform.inverse()
  let device_to_source = source_to_device.inverse()
  let setter = match ctx.clip {
    Some(clip) => ctx.setter.with_clip(clip)
    None => ctx.setter
  }
  for py in min_y..<max_y {
    for px in min_x..<max_x {
      let device_x = px.to_double() + 0.5
      let device_y = py.to_double() + 0.5
      let (local_x, local_y) = device_to_local.apply(device_x, device_y)
      if local_x >= x &&
        local_x < x + width &&
        local_y >= y &&
        local_y < y + height {
        let (source_x, source_y) = device_to_source.apply(device_x, device_y)
        if source_x >= 0.0 &&
          source_x < image.width.to_double() &&
          source_y >= 0.0 &&
          source_y < image.height.to_double() {
          let color = sample_raster_color(
            image, source_x, source_y, sampling, false,
          )
          if color.a > 0 {
            setter.pixel(px, py, apply_opacity(color, opacity))
          }
        }
      }
    }
  }
}

///|
fn sample_index(index : Int, length : Int, wrap : Bool) -> Int {
  if wrap {
    let value = index % length
    if value < 0 {
      value + length
    } else {
      value
    }
  } else {
    max_int(0, min_int(length - 1, index))
  }
}

///|
fn sampled_premul_pixel(
  image : Image,
  x : Int,
  y : Int,
  wrap : Bool,
) -> PremulColor16 {
  PremulColor16::from_color(
    image.get_pixel(
      sample_index(x, image.width, wrap),
      sample_index(y, image.height, wrap),
    ),
  )
}

///|
fn sampled_premul_color(
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
) -> Color {
  let output_alpha = clamp_channel16(alpha.round().to_int())
  PremulColor16::{
    r: min_int(output_alpha, clamp_channel16(red.round().to_int())),
    g: min_int(output_alpha, clamp_channel16(green.round().to_int())),
    b: min_int(output_alpha, clamp_channel16(blue.round().to_int())),
    a: output_alpha,
  }.to_color()
}

///|
fn cubic_sample_weight(distance : Double) -> Double {
  let x = distance.abs()
  if x <= 1.0 {
    (1.5 * x - 2.5) * x * x + 1.0
  } else if x < 2.0 {
    ((-0.5 * x + 2.5) * x - 4.0) * x + 2.0
  } else {
    0.0
  }
}

///|
fn sample_raster_color(
  image : Image,
  source_x : Double,
  source_y : Double,
  sampling : ImageSampling,
  wrap : Bool,
) -> Color {
  match sampling {
    Nearest =>
      image.get_pixel(
        sample_index(source_x.floor().to_int(), image.width, wrap),
        sample_index(source_y.floor().to_int(), image.height, wrap),
      )
    Bilinear => {
      let x = source_x - 0.5
      let y = source_y - 0.5
      let x0 = x.floor().to_int()
      let y0 = y.floor().to_int()
      let tx = x - x0.to_double()
      let ty = y - y0.to_double()
      let p00 = sampled_premul_pixel(image, x0, y0, wrap)
      let p10 = sampled_premul_pixel(image, x0 + 1, y0, wrap)
      let p01 = sampled_premul_pixel(image, x0, y0 + 1, wrap)
      let p11 = sampled_premul_pixel(image, x0 + 1, y0 + 1, wrap)
      let w00 = (1.0 - tx) * (1.0 - ty)
      let w10 = tx * (1.0 - ty)
      let w01 = (1.0 - tx) * ty
      let w11 = tx * ty
      sampled_premul_color(
        p00.r.to_double() * w00 +
        p10.r.to_double() * w10 +
        p01.r.to_double() * w01 +
        p11.r.to_double() * w11,
        p00.g.to_double() * w00 +
        p10.g.to_double() * w10 +
        p01.g.to_double() * w01 +
        p11.g.to_double() * w11,
        p00.b.to_double() * w00 +
        p10.b.to_double() * w10 +
        p01.b.to_double() * w01 +
        p11.b.to_double() * w11,
        p00.a.to_double() * w00 +
        p10.a.to_double() * w10 +
        p01.a.to_double() * w01 +
        p11.a.to_double() * w11,
      )
    }
    Bicubic => {
      let x = source_x - 0.5
      let y = source_y - 0.5
      let base_x = x.floor().to_int()
      let base_y = y.floor().to_int()
      let mut red = 0.0
      let mut green = 0.0
      let mut blue = 0.0
      let mut alpha = 0.0
      for offset_y in -1..<=2 {
        let wy = cubic_sample_weight(y - (base_y + offset_y).to_double())
        for offset_x in -1..<=2 {
          let wx = cubic_sample_weight(x - (base_x + offset_x).to_double())
          let weight = wx * wy
          let pixel = sampled_premul_pixel(
            image,
            base_x + offset_x,
            base_y + offset_y,
            wrap,
          )
          red = red + pixel.r.to_double() * weight
          green = green + pixel.g.to_double() * weight
          blue = blue + pixel.b.to_double() * weight
          alpha = alpha + pixel.a.to_double() * weight
        }
      }
      sampled_premul_color(red, green, blue, alpha)
    }
  }
}

///|
