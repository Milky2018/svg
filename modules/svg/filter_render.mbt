///|
fn filter_source_alpha(source : Image) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let alpha = source.get_pixel(x, y).a
      if alpha > 0 {
        result.set_pixel(x, y, Color::rgba(0, 0, 0, alpha))
      }
    }
  }
  result
}

///|
fn resolve_filter_graph_input(
  name : String,
  source : Image,
  source_alpha : Image,
  previous : Image,
  named : Map[String, Image],
) -> Image {
  match name {
    "SourceGraphic" => source
    "SourceAlpha" => source_alpha
    "" => previous
    _ => named.get(name).unwrap_or(Image::new(source.width, source.height))
  }
}

///|
fn offset_filter_image(source : Image, dx : Double, dy : Double) -> Image {
  let result = Image::new(source.width, source.height)
  let offset_x = dx.round().to_int()
  let offset_y = dy.round().to_int()
  for y in 0..<source.height {
    for x in 0..<source.width {
      let color = source.get_pixel(x, y)
      if color.a > 0 {
        result.set_pixel(x + offset_x, y + offset_y, color)
      }
    }
  }
  result
}

///|
fn blur_filter_image_xy(
  source : Image,
  radius_x : Double,
  radius_y : Double,
) -> Image {
  let rx = ceil_to_int(if radius_x < 0.0 { 0.0 } else { radius_x })
  let ry = ceil_to_int(if radius_y < 0.0 { 0.0 } else { radius_y })
  if rx == 0 && ry == 0 {
    return source
  }
  let result = Image::new(source.width, source.height)
  let sample_count = (rx * 2 + 1) * (ry * 2 + 1)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let mut alpha_sum = 0
      let mut red_premultiplied = 0
      let mut green_premultiplied = 0
      let mut blue_premultiplied = 0
      for offset_y in -ry..<=ry {
        for offset_x in -rx..<=rx {
          let color = source.get_pixel(x + offset_x, y + offset_y)
          alpha_sum = alpha_sum + color.a
          red_premultiplied = red_premultiplied + color.r * color.a
          green_premultiplied = green_premultiplied + color.g * color.a
          blue_premultiplied = blue_premultiplied + color.b * color.a
        }
      }
      if alpha_sum > 0 {
        result.set_pixel(
          x,
          y,
          Color::rgba(
            red_premultiplied / alpha_sum,
            green_premultiplied / alpha_sum,
            blue_premultiplied / alpha_sum,
            alpha_sum / sample_count,
          ),
        )
      }
    }
  }
  result
}

///|
fn transfer_filter_value(
  function : ComponentTransferFunction,
  value : Double,
) -> Double {
  match function {
    TransferIdentity => value
    TransferTable(values) => {
      if values.length() == 0 {
        return value
      }
      if values.length() == 1 {
        return clamp_filter_unit(values[0])
      }
      let position = clamp_filter_unit(value) *
        (values.length() - 1).to_double()
      let lower = position.floor().to_int()
      let upper = if lower + 1 < values.length() { lower + 1 } else { lower }
      let fraction = position - lower.to_double()
      clamp_filter_unit(
        values[lower] * (1.0 - fraction) + values[upper] * fraction,
      )
    }
    TransferDiscrete(values) => {
      if values.length() == 0 {
        return value
      }
      let mut index = (clamp_filter_unit(value) * values.length().to_double())
        .floor()
        .to_int()
      if index >= values.length() {
        index = values.length() - 1
      }
      clamp_filter_unit(values[index])
    }
    TransferLinear(slope~, intercept~) =>
      clamp_filter_unit(slope * value + intercept)
    TransferGamma(amplitude~, exponent~, offset~) =>
      clamp_filter_unit(amplitude * @math.pow(value, exponent) + offset)
  }
}

///|
fn component_transfer_filter_image(
  source : Image,
  red : ComponentTransferFunction,
  green : ComponentTransferFunction,
  blue : ComponentTransferFunction,
  alpha : ComponentTransferFunction,
) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let color = source.get_pixel(x, y)
      result.set_pixel(
        x,
        y,
        Color::rgba(
          (transfer_filter_value(red, color.r.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
          (transfer_filter_value(green, color.g.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
          (transfer_filter_value(blue, color.b.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
          (transfer_filter_value(alpha, color.a.to_double() / 255.0) * 255.0)
          .round()
          .to_int(),
        ),
      )
    }
  }
  result
}

///|
fn morphology_filter_image(
  source : Image,
  radius_x : Double,
  radius_y : Double,
  operator : MorphologyOperator,
) -> Image {
  let rx = ceil_to_int(if radius_x < 0.0 { 0.0 } else { radius_x })
  let ry = ceil_to_int(if radius_y < 0.0 { 0.0 } else { radius_y })
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let initial = if operator == MorphologyDilate { 0 } else { 255 }
      let mut r = initial
      let mut g = initial
      let mut b = initial
      let mut a = initial
      for offset_y in -ry..<=ry {
        for offset_x in -rx..<=rx {
          let color = source.get_pixel(x + offset_x, y + offset_y)
          if operator == MorphologyDilate {
            r = if r > color.r { r } else { color.r }
            g = if g > color.g { g } else { color.g }
            b = if b > color.b { b } else { color.b }
            a = if a > color.a { a } else { color.a }
          } else {
            r = if r < color.r { r } else { color.r }
            g = if g < color.g { g } else { color.g }
            b = if b < color.b { b } else { color.b }
            a = if a < color.a { a } else { color.a }
          }
        }
      }
      result.set_pixel(x, y, Color::rgba(r, g, b, a))
    }
  }
  result
}

///|
fn convolve_sample(
  source : Image,
  x : Int,
  y : Int,
  edge_mode : FilterEdgeMode,
) -> Color {
  if x >= 0 && x < source.width && y >= 0 && y < source.height {
    return source.get_pixel(x, y)
  }
  match edge_mode {
    EdgeNone => Color::transparent()
    EdgeDuplicate => {
      let sample_x = if x < 0 {
        0
      } else if x >= source.width {
        source.width - 1
      } else {
        x
      }
      let sample_y = if y < 0 {
        0
      } else if y >= source.height {
        source.height - 1
      } else {
        y
      }
      source.get_pixel(sample_x, sample_y)
    }
    EdgeWrap => {
      let mut sample_x = x % source.width
      let mut sample_y = y % source.height
      if sample_x < 0 {
        sample_x = sample_x + source.width
      }
      if sample_y < 0 {
        sample_y = sample_y + source.height
      }
      source.get_pixel(sample_x, sample_y)
    }
  }
}

///|
fn convolve_filter_image(
  source : Image,
  order_x : Int,
  order_y : Int,
  kernel : Array[Double],
  divisor : Double,
  bias : Double,
  target_x : Int,
  target_y : Int,
  edge_mode : FilterEdgeMode,
  preserve_alpha : Bool,
) -> Image {
  if order_x <= 0 || order_y <= 0 || kernel.length() != order_x * order_y {
    return source
  }
  let safe_divisor = if divisor.abs() <= 0.000001 { 1.0 } else { divisor }
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let mut red = 0.0
      let mut green = 0.0
      let mut blue = 0.0
      let mut alpha = 0.0
      for kernel_y in 0..<order_y {
        for kernel_x in 0..<order_x {
          let sample = convolve_sample(
            source,
            x + kernel_x - target_x,
            y + kernel_y - target_y,
            edge_mode,
          )
          let weight = kernel[(order_y - 1 - kernel_y) * order_x +
            order_x -
            1 -
            kernel_x]
          red = red + sample.r.to_double() * weight
          green = green + sample.g.to_double() * weight
          blue = blue + sample.b.to_double() * weight
          alpha = alpha + sample.a.to_double() * weight
        }
      }
      fn output_channel(value : Double) -> Int {
        (clamp_filter_unit(value / safe_divisor / 255.0 + bias) * 255.0)
        .round()
        .to_int()
      }
      result.set_pixel(
        x,
        y,
        Color::rgba(
          output_channel(red),
          output_channel(green),
          output_channel(blue),
          if preserve_alpha {
            source.get_pixel(x, y).a
          } else {
            output_channel(alpha)
          },
        ),
      )
    }
  }
  result
}

///|
fn filter_channel_value(color : Color, channel : FilterChannel) -> Double {
  match channel {
    ChannelR => color.r.to_double() / 255.0
    ChannelG => color.g.to_double() / 255.0
    ChannelB => color.b.to_double() / 255.0
    ChannelA => color.a.to_double() / 255.0
  }
}

///|
fn displacement_filter_image(
  source : Image,
  displacement : Image,
  scale_x : Double,
  scale_y : Double,
  x_channel : FilterChannel,
  y_channel : FilterChannel,
) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let map_color = displacement.get_pixel(x, y)
      let source_x = x.to_double() +
        scale_x * (filter_channel_value(map_color, x_channel) - 0.5)
      let source_y = y.to_double() +
        scale_y * (filter_channel_value(map_color, y_channel) - 0.5)
      result.set_pixel(
        x,
        y,
        source.get_pixel(source_x.round().to_int(), source_y.round().to_int()),
      )
    }
  }
  result
}

///|
fn smooth_noise_fraction(value : Double) -> Double {
  value * value * (3.0 - 2.0 * value)
}

///|
fn filter_noise_hash(x : Int, y : Int, seed : Double) -> Double {
  let value = @math.sin(
      x.to_double() * 12.9898 + y.to_double() * 78.233 + seed * 37.719,
    ) *
    43758.5453
  let fraction = value - value.floor()
  if fraction < 0.0 {
    fraction + 1.0
  } else {
    fraction
  }
}

///|
fn filter_value_noise(x : Double, y : Double, seed : Double) -> Double {
  let x0 = x.floor().to_int()
  let y0 = y.floor().to_int()
  let tx = smooth_noise_fraction(x - x0.to_double())
  let ty = smooth_noise_fraction(y - y0.to_double())
  let top = filter_noise_hash(x0, y0, seed) * (1.0 - tx) +
    filter_noise_hash(x0 + 1, y0, seed) * tx
  let bottom = filter_noise_hash(x0, y0 + 1, seed) * (1.0 - tx) +
    filter_noise_hash(x0 + 1, y0 + 1, seed) * tx
  top * (1.0 - ty) + bottom * ty
}

///|
fn turbulence_filter_image(
  width : Int,
  height : Int,
  base_x : Double,
  base_y : Double,
  octaves : Int,
  seed : Double,
  fractal_noise : Bool,
) -> Image {
  let result = Image::new(width, height)
  let octave_count = if octaves < 1 {
    1
  } else if octaves > 8 {
    8
  } else {
    octaves
  }
  for y in 0..<height {
    for x in 0..<width {
      let mut sum = 0.0
      let mut weight_sum = 0.0
      let mut frequency = 1.0
      let mut weight = 1.0
      for octave in 0..<octave_count {
        let noise = filter_value_noise(
          x.to_double() * base_x * frequency,
          y.to_double() * base_y * frequency,
          seed + octave.to_double() * 19.0,
        )
        sum = sum +
          (if fractal_noise {
            noise * 2.0 - 1.0
          } else {
            (noise * 2.0 - 1.0).abs()
          }) *
          weight
        weight_sum = weight_sum + weight
        frequency = frequency * 2.0
        weight = weight * 0.5
      }
      let unit = if fractal_noise {
        clamp_filter_unit(0.5 + sum / weight_sum * 0.5)
      } else {
        clamp_filter_unit(sum / weight_sum)
      }
      let byte = (unit * 255.0).round().to_int()
      result.set_pixel(x, y, Color::rgba(byte, byte, byte, 255))
    }
  }
  result
}

///|
fn tile_filter_image(source : Image) -> Image {
  let mut min_x = source.width
  let mut min_y = source.height
  let mut max_x = -1
  let mut max_y = -1
  for y in 0..<source.height {
    for x in 0..<source.width {
      if source.get_pixel(x, y).a > 0 {
        min_x = if min_x < x { min_x } else { x }
        min_y = if min_y < y { min_y } else { y }
        max_x = if max_x > x { max_x } else { x }
        max_y = if max_y > y { max_y } else { y }
      }
    }
  }
  if max_x < min_x || max_y < min_y {
    return Image::new(source.width, source.height)
  }
  let tile_width = max_x - min_x + 1
  let tile_height = max_y - min_y + 1
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let sample_x = min_x +
        ((x - min_x) % tile_width + tile_width) % tile_width
      let sample_y = min_y +
        ((y - min_y) % tile_height + tile_height) % tile_height
      result.set_pixel(x, y, source.get_pixel(sample_x, sample_y))
    }
  }
  result
}

///|
fn filter_image_resource(
  width : Int,
  height : Int,
  href : String,
  x : Double,
  y : Double,
  target_width : Double,
  target_height : Double,
  resolver : ((String) -> Image?)?,
) -> Image {
  let result = Image::new(width, height)
  let resource = match resolver {
    Some(resolve) => resolve(href)
    None => None
  }
  match resource {
    Some(image) => {
      let output_width = if target_width > 0.0 {
        target_width
      } else {
        image.width.to_double()
      }
      let output_height = if target_height > 0.0 {
        target_height
      } else {
        image.height.to_double()
      }
      let min_x = floor_to_int(x)
      let min_y = floor_to_int(y)
      let max_x = ceil_to_int(x + output_width)
      let max_y = ceil_to_int(y + output_height)
      for py in min_y..<max_y {
        for px in min_x..<max_x {
          let source_x = floor_to_int(
            (px.to_double() + 0.5 - x) / output_width * image.width.to_double(),
          )
          let source_y = floor_to_int(
            (py.to_double() + 0.5 - y) /
            output_height *
            image.height.to_double(),
          )
          result.set_pixel(px, py, image.get_pixel(source_x, source_y))
        }
      }
    }
    None => ()
  }
  result
}

///|
fn normalize_filter_vector(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  let length = (x * x + y * y + z * z).sqrt()
  if length <= 0.000001 {
    (0.0, 0.0, 1.0)
  } else {
    (x / length, y / length, z / length)
  }
}

///|
fn filter_light_vector(
  light : FilterLight,
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double, Double) {
  match light {
    DistantLight(azimuth~, elevation~) => {
      let azimuth_radians = degrees_to_radians(azimuth)
      let elevation_radians = degrees_to_radians(elevation)
      (
        @math.cos(azimuth_radians) * @math.cos(elevation_radians),
        @math.sin(azimuth_radians) * @math.cos(elevation_radians),
        @math.sin(elevation_radians),
        1.0,
      )
    }
    PointLight(x=light_x, y=light_y, z=light_z) => {
      let vector = normalize_filter_vector(
        light_x - x,
        light_y - y,
        light_z - z,
      )
      (vector.0, vector.1, vector.2, 1.0)
    }
    SpotLight(
      x=light_x,
      y=light_y,
      z=light_z,
      points_at_x~,
      points_at_y~,
      points_at_z~,
      exponent~,
      limiting_cone_angle~
    ) => {
      let vector = normalize_filter_vector(
        light_x - x,
        light_y - y,
        light_z - z,
      )
      let spot_direction = normalize_filter_vector(
        points_at_x - light_x,
        points_at_y - light_y,
        points_at_z - light_z,
      )
      let from_light = (-vector.0, -vector.1, -vector.2)
      let cosine = max(
        0.0,
        from_light.0 * spot_direction.0 +
        from_light.1 * spot_direction.1 +
        from_light.2 * spot_direction.2,
      )
      let inside_cone = match limiting_cone_angle {
        Some(angle) => cosine >= @math.cos(degrees_to_radians(angle))
        None => true
      }
      let attenuation = if inside_cone {
        @math.pow(cosine, exponent)
      } else {
        0.0
      }
      (vector.0, vector.1, vector.2, attenuation)
    }
  }
}

///|
fn lighting_filter_image(
  source : Image,
  surface_scale : Double,
  constant : Double,
  exponent : Double,
  lighting_color : Color,
  light : FilterLight,
  specular : Bool,
) -> Image {
  let result = Image::new(source.width, source.height)
  for y in 0..<source.height {
    for x in 0..<source.width {
      let height = source.get_pixel(x, y).a.to_double() / 255.0 * surface_scale
      let dx = (
          source.get_pixel(x + 1, y).a.to_double() -
          source.get_pixel(x - 1, y).a.to_double()
        ) /
        510.0 *
        surface_scale
      let dy = (
          source.get_pixel(x, y + 1).a.to_double() -
          source.get_pixel(x, y - 1).a.to_double()
        ) /
        510.0 *
        surface_scale
      let normal = normalize_filter_vector(-dx, -dy, 1.0)
      let light_vector = filter_light_vector(
        light,
        x.to_double(),
        y.to_double(),
        height,
      )
      let dot = if specular {
        let half_vector = normalize_filter_vector(
          light_vector.0,
          light_vector.1,
          light_vector.2 + 1.0,
        )
        max(
          0.0,
          normal.0 * half_vector.0 +
          normal.1 * half_vector.1 +
          normal.2 * half_vector.2,
        )
      } else {
        max(
          0.0,
          normal.0 * light_vector.0 +
          normal.1 * light_vector.1 +
          normal.2 * light_vector.2,
        )
      }
      let intensity = clamp_filter_unit(
        constant *
        (if specular { @math.pow(dot, exponent) } else { dot }) *
        light_vector.3,
      )
      let red = (lighting_color.r.to_double() * intensity).round().to_int()
      let green = (lighting_color.g.to_double() * intensity).round().to_int()
      let blue = (lighting_color.b.to_double() * intensity).round().to_int()
      let alpha = if specular {
        let red_green = if red > green { red } else { green }
        if red_green > blue {
          red_green
        } else {
          blue
        }
      } else {
        255
      }
      result.set_pixel(x, y, Color::rgba(red, green, blue, alpha))
    }
  }
  result
}

///|
fn filter_primitive_x(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => value * target.width()
    MaskUnits::UserSpaceOnUse => value
  }
}

///|
fn filter_primitive_y(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => value * target.height()
    MaskUnits::UserSpaceOnUse => value
  }
}

///|
fn filter_primitive_position_x(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
  origin_x : Int,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => target.min_x + value * target.width()
    MaskUnits::UserSpaceOnUse => value - origin_x.to_double()
  }
}

///|
fn filter_primitive_position_y(
  graph : FilterGraph,
  value : Double,
  target : BoundingBox,
  origin_y : Int,
) -> Double {
  match graph.primitive_units {
    MaskUnits::ObjectBoundingBox => target.min_y + value * target.height()
    MaskUnits::UserSpaceOnUse => value - origin_y.to_double()
  }
}

///|
fn resolve_filter_light(
  graph : FilterGraph,
  light : FilterLight,
  target : BoundingBox,
  origin_x : Int,
  origin_y : Int,
) -> FilterLight {
  match light {
    DistantLight(..) => light
    PointLight(x~, y~, z~) =>
      PointLight(
        x=filter_primitive_position_x(graph, x, target, origin_x),
        y=filter_primitive_position_y(graph, y, target, origin_y),
        z=filter_primitive_x(graph, z, target),
      )
    SpotLight(
      x~,
      y~,
      z~,
      points_at_x~,
      points_at_y~,
      points_at_z~,
      exponent~,
      limiting_cone_angle~
    ) =>
      SpotLight(
        x=filter_primitive_position_x(graph, x, target, origin_x),
        y=filter_primitive_position_y(graph, y, target, origin_y),
        z=filter_primitive_x(graph, z, target),
        points_at_x=filter_primitive_position_x(
          graph, points_at_x, target, origin_x,
        ),
        points_at_y=filter_primitive_position_y(
          graph, points_at_y, target, origin_y,
        ),
        points_at_z=filter_primitive_x(graph, points_at_z, target),
        exponent~,
        limiting_cone_angle~,
      )
  }
}

///|
fn clamp_filter_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn composite_filter_pixel(
  source : Color,
  backdrop : Color,
  operator : FilterCompositeOperator,
  k1 : Double,
  k2 : Double,
  k3 : Double,
  k4 : Double,
) -> Color {
  let source_alpha = source.a.to_double() / 255.0
  let backdrop_alpha = backdrop.a.to_double() / 255.0
  let (source_factor, backdrop_factor) = match operator {
    CompositeOver => (1.0, 1.0 - source_alpha)
    CompositeIn => (backdrop_alpha, 0.0)
    CompositeOut => (1.0 - backdrop_alpha, 0.0)
    CompositeAtop => (backdrop_alpha, 1.0 - source_alpha)
    CompositeXor => (1.0 - backdrop_alpha, 1.0 - source_alpha)
    CompositeArithmetic => (0.0, 0.0)
  }
  let output_alpha = if operator == CompositeArithmetic {
    clamp_filter_unit(
      k1 * source_alpha * backdrop_alpha +
      k2 * source_alpha +
      k3 * backdrop_alpha +
      k4,
    )
  } else {
    clamp_filter_unit(
      source_alpha * source_factor + backdrop_alpha * backdrop_factor,
    )
  }
  if output_alpha <= 0.0 {
    return Color::transparent()
  }
  fn channel(source_channel : Int, backdrop_channel : Int) -> Int {
    let source_premultiplied = source_channel.to_double() / 255.0 * source_alpha
    let backdrop_premultiplied = backdrop_channel.to_double() /
      255.0 *
      backdrop_alpha
    let output_premultiplied = if operator == CompositeArithmetic {
      clamp_filter_unit(
        k1 * source_premultiplied * backdrop_premultiplied +
        k2 * source_premultiplied +
        k3 * backdrop_premultiplied +
        k4,
      )
    } else {
      source_premultiplied * source_factor +
      backdrop_premultiplied * backdrop_factor
    }
    (clamp_filter_unit(output_premultiplied / output_alpha) * 255.0)
    .round()
    .to_int()
  }
  Color::rgba(
    channel(source.r, backdrop.r),
    channel(source.g, backdrop.g),
    channel(source.b, backdrop.b),
    (output_alpha * 255.0).round().to_int(),
  )
}

///|
fn composite_filter_images(
  source : Image,
  backdrop : Image,
  operator : FilterCompositeOperator,
  k1 : Double,
  k2 : Double,
  k3 : Double,
  k4 : Double,
) -> Image {
  let width = if source.width < backdrop.width {
    source.width
  } else {
    backdrop.width
  }
  let height = if source.height < backdrop.height {
    source.height
  } else {
    backdrop.height
  }
  let result = Image::new(width, height)
  for y in 0..<height {
    for x in 0..<width {
      result.set_pixel(
        x,
        y,
        composite_filter_pixel(
          source.get_pixel(x, y),
          backdrop.get_pixel(x, y),
          operator,
          k1,
          k2,
          k3,
          k4,
        ),
      )
    }
  }
  result
}

///|
fn clip_filter_result(result : Image, bounds : BoundingBox) -> Image {
  let min_x = floor_to_int(bounds.min_x)
  let min_y = floor_to_int(bounds.min_y)
  let max_x = ceil_to_int(bounds.max_x)
  let max_y = ceil_to_int(bounds.max_y)
  for y in 0..<result.height {
    for x in 0..<result.width {
      if x < min_x || x >= max_x || y < min_y || y >= max_y {
        result.set_pixel(x, y, Color::transparent())
      }
    }
  }
  result
}

///|
fn evaluate_filter_graph(
  graph : FilterGraph,
  source : Image,
  target_bounds : BoundingBox,
  image_resolver : ((String) -> Image?)?,
  origin_x : Int,
  origin_y : Int,
) -> Image {
  let target_bounds = {
    min_x: target_bounds.min_x - origin_x.to_double(),
    min_y: target_bounds.min_y - origin_y.to_double(),
    max_x: target_bounds.max_x - origin_x.to_double(),
    max_y: target_bounds.max_y - origin_y.to_double(),
  }
  let source_alpha = filter_source_alpha(source)
  let named : Map[String, Image] = Map([])
  let mut previous = source
  for primitive in graph.primitives {
    let (output, result_name) = match primitive {
      GraphColorMatrix(input~, result~, matrix~) =>
        (
          apply_filter(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            ColorMatrix(matrix),
          ),
          result,
        )
      GraphGaussianBlur(input~, result~, radius_x~, radius_y~) =>
        (
          blur_filter_image_xy(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, radius_x, target_bounds),
            filter_primitive_y(graph, radius_y, target_bounds),
          ),
          result,
        )
      GraphOffset(input~, result~, dx~, dy~) =>
        (
          offset_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, dx, target_bounds),
            filter_primitive_y(graph, dy, target_bounds),
          ),
          result,
        )
      GraphBlend(input~, input2~, result~, mode~) =>
        (
          blend_images(
            resolve_filter_graph_input(
              input2, source, source_alpha, previous, named,
            ),
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            mode,
          ),
          result,
        )
      GraphComposite(input~, input2~, result~, operator~, k1~, k2~, k3~, k4~) =>
        (
          composite_filter_images(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            resolve_filter_graph_input(
              input2, source, source_alpha, previous, named,
            ),
            operator,
            k1,
            k2,
            k3,
            k4,
          ),
          result,
        )
      GraphFlood(result~, color~) =>
        (Image::filled(source.width, source.height, color), result)
      GraphMerge(result~, inputs~) => {
        let mut merged = Image::new(source.width, source.height)
        for input in inputs {
          merged = blend_images(
            merged,
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            Normal,
          )
        }
        (merged, result)
      }
      GraphComponentTransfer(input~, result~, red~, green~, blue~, alpha~) =>
        (
          component_transfer_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            red,
            green,
            blue,
            alpha,
          ),
          result,
        )
      GraphMorphology(input~, result~, radius_x~, radius_y~, operator~) =>
        (
          morphology_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, radius_x, target_bounds),
            filter_primitive_y(graph, radius_y, target_bounds),
            operator,
          ),
          result,
        )
      GraphConvolveMatrix(
        input~,
        result~,
        order_x~,
        order_y~,
        kernel~,
        divisor~,
        bias~,
        target_x~,
        target_y~,
        edge_mode~,
        preserve_alpha~
      ) =>
        (
          convolve_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            order_x,
            order_y,
            kernel,
            divisor,
            bias,
            target_x,
            target_y,
            edge_mode,
            preserve_alpha,
          ),
          result,
        )
      GraphDisplacementMap(
        input~,
        input2~,
        result~,
        scale~,
        x_channel~,
        y_channel~
      ) =>
        (
          displacement_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            resolve_filter_graph_input(
              input2, source, source_alpha, previous, named,
            ),
            filter_primitive_x(graph, scale, target_bounds),
            filter_primitive_y(graph, scale, target_bounds),
            x_channel,
            y_channel,
          ),
          result,
        )
      GraphTurbulence(
        result~,
        base_x~,
        base_y~,
        octaves~,
        seed~,
        stitch=_,
        fractal_noise~
      ) => {
        let frequency_x = match graph.primitive_units {
          MaskUnits::ObjectBoundingBox =>
            if target_bounds.width() <= 0.0 {
              0.0
            } else {
              base_x / target_bounds.width()
            }
          MaskUnits::UserSpaceOnUse => base_x
        }
        let frequency_y = match graph.primitive_units {
          MaskUnits::ObjectBoundingBox =>
            if target_bounds.height() <= 0.0 {
              0.0
            } else {
              base_y / target_bounds.height()
            }
          MaskUnits::UserSpaceOnUse => base_y
        }
        (
          turbulence_filter_image(
            source.width,
            source.height,
            frequency_x,
            frequency_y,
            octaves,
            seed,
            fractal_noise,
          ),
          result,
        )
      }
      GraphTile(input~, result~) =>
        (
          tile_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
          ),
          result,
        )
      GraphImage(result~, href~, x~, y~, width~, height~) =>
        (
          filter_image_resource(
            source.width,
            source.height,
            href,
            filter_primitive_position_x(graph, x, target_bounds, origin_x),
            filter_primitive_position_y(graph, y, target_bounds, origin_y),
            filter_primitive_x(graph, width, target_bounds),
            filter_primitive_y(graph, height, target_bounds),
            image_resolver,
          ),
          result,
        )
      GraphDiffuseLighting(
        input~,
        result~,
        surface_scale~,
        diffuse_constant~,
        color~,
        light~
      ) =>
        (
          lighting_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_y(graph, surface_scale, target_bounds),
            diffuse_constant,
            1.0,
            color,
            resolve_filter_light(
              graph, light, target_bounds, origin_x, origin_y,
            ),
            false,
          ),
          result,
        )
      GraphSpecularLighting(
        input~,
        result~,
        surface_scale~,
        specular_constant~,
        specular_exponent~,
        color~,
        light~
      ) =>
        (
          lighting_filter_image(
            resolve_filter_graph_input(
              input, source, source_alpha, previous, named,
            ),
            filter_primitive_y(graph, surface_scale, target_bounds),
            specular_constant,
            specular_exponent,
            color,
            resolve_filter_light(
              graph, light, target_bounds, origin_x, origin_y,
            ),
            true,
          ),
          result,
        )
    }
    previous = output
    if result_name.length() > 0 {
      named.set(result_name, output)
    }
  }
  let filter_bounds = match graph.units {
    MaskUnits::ObjectBoundingBox => graph.get_filter_bounds(target_bounds)
    MaskUnits::UserSpaceOnUse => {
      let device_target = {
        min_x: target_bounds.min_x + origin_x.to_double(),
        min_y: target_bounds.min_y + origin_y.to_double(),
        max_x: target_bounds.max_x + origin_x.to_double(),
        max_y: target_bounds.max_y + origin_y.to_double(),
      }
      let device_bounds = graph.get_filter_bounds(device_target)
      {
        min_x: device_bounds.min_x - origin_x.to_double(),
        min_y: device_bounds.min_y - origin_y.to_double(),
        max_x: device_bounds.max_x - origin_x.to_double(),
        max_y: device_bounds.max_y - origin_y.to_double(),
      }
    }
  }
  clip_filter_result(previous, filter_bounds)
}

///|
