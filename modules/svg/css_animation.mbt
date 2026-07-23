///|
fn animation_list_index(length : Int, index : Int) -> Int {
  if length == 0 {
    0
  } else {
    index % length
  }
}

///|
fn animation_duration(style : @css_style.Style, index : Int) -> Double {
  if style.animation_duration.is_empty() {
    0.0
  } else {
    style.animation_duration[animation_list_index(
      style.animation_duration.length(),
      index,
    )]
  }
}

///|
fn animation_delay(style : @css_style.Style, index : Int) -> Double {
  if style.animation_delay.is_empty() {
    0.0
  } else {
    style.animation_delay[animation_list_index(
      style.animation_delay.length(),
      index,
    )]
  }
}

///|
fn animation_easing(
  style : @css_style.Style,
  index : Int,
) -> @css_values.Easing {
  if style.animation_timing_function.is_empty() {
    Ease
  } else {
    style.animation_timing_function[animation_list_index(
      style.animation_timing_function.length(),
      index,
    )]
  }
}

///|
fn animation_iteration_count(
  style : @css_style.Style,
  index : Int,
) -> @css_values.AnimationIterationCount {
  if style.animation_iteration_count.is_empty() {
    Count(1.0)
  } else {
    style.animation_iteration_count[animation_list_index(
      style.animation_iteration_count.length(),
      index,
    )]
  }
}

///|
fn animation_direction(
  style : @css_style.Style,
  index : Int,
) -> @css_values.AnimationDirection {
  if style.animation_direction.is_empty() {
    Normal
  } else {
    style.animation_direction[animation_list_index(
      style.animation_direction.length(),
      index,
    )]
  }
}

///|
fn animation_fill_mode(
  style : @css_style.Style,
  index : Int,
) -> @css_values.AnimationFillMode {
  if style.animation_fill_mode.is_empty() {
    None
  } else {
    style.animation_fill_mode[animation_list_index(
      style.animation_fill_mode.length(),
      index,
    )]
  }
}

///|
fn animation_play_state(
  style : @css_style.Style,
  index : Int,
) -> @css_values.AnimationPlayState {
  if style.animation_play_state.is_empty() {
    Running
  } else {
    style.animation_play_state[animation_list_index(
      style.animation_play_state.length(),
      index,
    )]
  }
}

///|
fn animation_has_backwards_fill(mode : @css_values.AnimationFillMode) -> Bool {
  mode is Backwards || mode is Both
}

///|
fn animation_has_forwards_fill(mode : @css_values.AnimationFillMode) -> Bool {
  mode is Forwards || mode is Both
}

///|
fn directed_animation_progress(
  progress : Double,
  iteration : Int,
  direction : @css_values.AnimationDirection,
) -> Double {
  let reverse = match direction {
    Normal => false
    Reverse => true
    Alternate => iteration % 2 == 1
    AlternateReverse => iteration % 2 == 0
  }
  if reverse {
    1.0 - progress
  } else {
    progress
  }
}

///|
fn sampled_animation_progress(
  style : @css_style.Style,
  index : Int,
  sample_time_seconds : Double,
) -> Double? {
  let duration = animation_duration(style, index)
  let delay = animation_delay(style, index)
  let fill = animation_fill_mode(style, index)
  let direction = animation_direction(style, index)
  let timeline_time = if animation_play_state(style, index) is Paused {
    0.0
  } else {
    sample_time_seconds
  }
  let local_time = timeline_time - delay
  if local_time < 0.0 {
    if animation_has_backwards_fill(fill) {
      return Some(directed_animation_progress(0.0, 0, direction))
    }
    return None
  }
  if duration <= 0.0 {
    if animation_has_forwards_fill(fill) || local_time == 0.0 {
      return Some(directed_animation_progress(1.0, 0, direction))
    }
    return None
  }
  let iteration_count = animation_iteration_count(style, index)
  match iteration_count {
    Count(count) => {
      if count <= 0.0 {
        return None
      }
      let active_duration = duration * count
      if local_time >= active_duration {
        if !animation_has_forwards_fill(fill) {
          return None
        }
        let final_iteration = (count.ceil().to_int() - 1).max(0)
        let fractional = count - count.floor()
        let final_progress = if fractional == 0.0 { 1.0 } else { fractional }
        return Some(
          directed_animation_progress(
            final_progress, final_iteration, direction,
          ),
        )
      }
    }
    Infinite => ()
  }
  let iteration = (local_time / duration).floor().to_int()
  let progress = (local_time - iteration.to_double() * duration) / duration
  Some(directed_animation_progress(progress, iteration, direction))
}

///|
fn find_animation_keyframes(
  stylesheets : Array[@css_cascade.Stylesheet],
  name : String,
) -> @css_cascade.KeyframesRule? {
  let mut found : @css_cascade.KeyframesRule? = None
  for stylesheet in stylesheets {
    match stylesheet.find_keyframes(name) {
      Some(rule) => found = Some(rule)
      None => ()
    }
  }
  found
}

///|
fn animation_length_basis(property : String) -> LengthAxis {
  match property {
    "x" | "width" | "cx" | "x1" | "x2" | "rx" => Horizontal
    "y" | "height" | "cy" | "y1" | "y2" | "ry" => Vertical
    _ => Diagonal
  }
}

///|
fn animation_property_is_length(property : String) -> Bool {
  match property {
    "x"
    | "y"
    | "width"
    | "height"
    | "cx"
    | "cy"
    | "r"
    | "rx"
    | "ry"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "stroke-width"
    | "stroke-dashoffset" => true
    _ => false
  }
}

///|
fn animation_property_is_number(property : String) -> Bool {
  match property {
    "opacity"
    | "fill-opacity"
    | "stroke-opacity"
    | "stop-opacity"
    | "stroke-miterlimit" => true
    _ => false
  }
}

///|
fn animation_property_is_color(property : String) -> Bool {
  match property {
    "fill" | "stroke" | "color" | "stop-color" => true
    _ => false
  }
}

///|
fn interpolate_animation_color(
  from : String,
  to : String,
  progress : Double,
) -> String? {
  match (@css_computed.parse_color(from), @css_computed.parse_color(to)) {
    (Resolved(left), Resolved(right)) => {
      let r = (left.r.to_double() + (right.r - left.r).to_double() * progress)
        .round()
        .to_int()
      let g = (left.g.to_double() + (right.g - left.g).to_double() * progress)
        .round()
        .to_int()
      let b = (left.b.to_double() + (right.b - left.b).to_double() * progress)
        .round()
        .to_int()
      let a = left.a + (right.a - left.a) * progress
      Some("rgba(\{r}, \{g}, \{b}, \{a})")
    }
    _ => None
  }
}

///|
fn animation_color_text(color : Color) -> String {
  "rgba(\{color.r}, \{color.g}, \{color.b}, \{color.a.to_double() / 255.0})"
}

///|
fn animation_paint_text(paint : Paint) -> String {
  match paint {
    None => "none"
    SolidColor(color) => animation_color_text(color)
    CurrentColor => "currentColor"
    PaintServerRef(id, _) => "url(#\{id})"
    LinearGrad(_) | RadialGrad(_) => "none"
  }
}

///|
fn underlying_animation_value(
  property : String,
  base_declarations : Array[StyleDeclaration],
  attrs : Array[(String, String)],
  custom_properties : Map[String, String],
  parent : InheritedStyle,
  css_style : @css_style.Style,
) -> String? {
  match find_winning_declaration(base_declarations, property) {
    Some(declaration) =>
      match
        @css.resolve_custom_property_value(declaration.value, custom_properties) {
        Some(value) =>
          match trim_string(value).to_lower() {
            "initial" | "inherit" | "unset" | "revert" | "revert-layer" => ()
            _ => return Some(value)
          }
        None => ()
      }
    None => ()
  }
  match get_attr(attrs, property) {
    Some(value) => return Some(value)
    None => ()
  }
  match property {
    "fill" => Some(animation_paint_text(parent.fill))
    "fill-opacity" => Some(parent.fill_opacity.to_string())
    "stroke" => Some(animation_paint_text(parent.stroke.paint))
    "stroke-width" => Some(parent.stroke.width.to_string())
    "stroke-opacity" => Some(parent.stroke_opacity.to_string())
    "color" => Some(animation_color_text(parent.color))
    "stop-color" => Some(animation_color_text(parent.stop_color))
    "stop-opacity" => Some(parent.stop_opacity.to_string())
    "opacity" => Some(css_style.opacity.to_string())
    "transform" => Some("matrix(1, 0, 0, 1, 0, 0)")
    "x"
    | "y"
    | "width"
    | "height"
    | "cx"
    | "cy"
    | "r"
    | "rx"
    | "ry"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "stroke-dashoffset" => Some("0")
    _ => None
  }
}

///|
fn interpolate_animation_value(
  property : String,
  from : String,
  to : String,
  progress : Double,
  length_context : LengthContext,
) -> String {
  if animation_property_is_number(property) {
    match (parse_number_strict(from), parse_number_strict(to)) {
      (Some(left), Some(right)) =>
        return (left + (right - left) * progress).to_string()
      _ => ()
    }
  } else if animation_property_is_length(property) {
    let basis = animation_length_basis(property)
    match
      (
        parse_length_with_context_optional(from, basis, length_context),
        parse_length_with_context_optional(to, basis, length_context),
      ) {
      (Some(left), Some(right)) =>
        return (left + (right - left) * progress).to_string()
      _ => ()
    }
  } else if animation_property_is_color(property) {
    match interpolate_animation_color(from, to, progress) {
      Some(value) => return value
      None => ()
    }
  } else if property == "transform" {
    let left = parse_transform(from)
    let right = parse_transform(to)
    return "matrix(\{left.a + (right.a - left.a) * progress}, \{left.b + (right.b - left.b) * progress}, \{left.c + (right.c - left.c) * progress}, \{left.d + (right.d - left.d) * progress}, \{left.e + (right.e - left.e) * progress}, \{left.f + (right.f - left.f) * progress})"
  }
  if progress < 0.5 {
    from
  } else {
    to
  }
}

///|
fn sample_keyframe_property(
  frames : Array[(Double, String)],
  progress : Double,
  easing : @css_values.Easing,
  property : String,
  length_context : LengthContext,
) -> String {
  frames.sort_by(fn(left, right) {
    if left.0 < right.0 {
      -1
    } else if left.0 > right.0 {
      1
    } else {
      0
    }
  })
  if frames.length() == 1 || progress <= frames[0].0 {
    return frames[0].1
  }
  let last = frames[frames.length() - 1]
  if progress >= last.0 {
    return last.1
  }
  for i = 0; i + 1 < frames.length(); i = i + 1 {
    let left = frames[i]
    let right = frames[i + 1]
    if progress >= left.0 && progress <= right.0 {
      let span = right.0 - left.0
      let segment_progress = if span <= 0.0 {
        1.0
      } else {
        (progress - left.0) / span
      }
      return interpolate_animation_value(
        property,
        left.1,
        right.1,
        easing.sample(segment_progress),
        length_context,
      )
    }
  }
  last.1
}

///|
fn sampled_animation_declarations(
  style : @css_style.Style,
  stylesheets : Array[@css_cascade.Stylesheet],
  sample_time_seconds : Double,
  custom_properties : Map[String, String],
  length_context : LengthContext,
  base_declarations : Array[StyleDeclaration],
  attrs : Array[(String, String)],
  parent : InheritedStyle,
) -> Array[StyleDeclaration] {
  let sampled : Map[String, String] = Map([])
  for animation_index, name in style.animation_name {
    if name.to_lower() == "none" {
      continue
    }
    let progress = match
      sampled_animation_progress(style, animation_index, sample_time_seconds) {
      Some(progress) => progress
      None => continue
    }
    let keyframes = match find_animation_keyframes(stylesheets, name) {
      Some(keyframes) => keyframes
      None => continue
    }
    let property_frames : Map[String, Array[(Double, String)]] = Map([])
    for block in keyframes.blocks {
      for declaration in block.declarations {
        if declaration.property == "animation-timing-function" ||
          declaration.importance is Important {
          continue
        }
        let value = match declaration.value {
          Value(value) =>
            @css.resolve_custom_property_value(value, custom_properties).unwrap_or(
              value,
            )
          _ => continue
        }
        let frames = property_frames.get(declaration.property).unwrap_or([])
        for offset in block.offsets {
          frames.push((offset, value))
        }
        property_frames[declaration.property] = frames
      }
    }
    let easing = animation_easing(style, animation_index)
    property_frames.each(fn(property, frames) {
      if !frames.is_empty() {
        let mut has_start = false
        let mut has_end = false
        for frame in frames {
          if frame.0 == 0.0 {
            has_start = true
          }
          if frame.0 == 1.0 {
            has_end = true
          }
        }
        if !has_start || !has_end {
          match
            underlying_animation_value(
              property, base_declarations, attrs, custom_properties, parent, style,
            ) {
            Some(value) => {
              if !has_start {
                frames.push((0.0, value))
              }
              if !has_end {
                frames.push((1.0, value))
              }
            }
            None => ()
          }
        }
        sampled[property] = sample_keyframe_property(
          frames, progress, easing, property, length_context,
        )
      }
    })
  }
  let declarations : Array[StyleDeclaration] = []
  sampled.each(fn(name, value) { declarations.push({ name, value }) })
  declarations
}
