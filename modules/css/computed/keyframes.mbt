///|
/// Bridge from parsed `@keyframes` (cascade) to the animation package's typed
/// computed-value interpolation. This is the layout-independent part of "frame
/// value resolution": it turns a `KeyframesRule` plus the element's base
/// computed value into a per-property track of `AnimatableValue`s. The consumer
/// (layout engine) drives time and resolves the interpolated computed value to
/// a used value, exactly as for a static computed value.

///|
/// Classify a single keyframe declaration value into an AnimatableValue at the
/// computed-value level. Length units are resolved to px via `ctx`; percentages
/// stay as ratios; colors resolve to sRGB; bare numbers stay numbers; anything
/// else (`auto`, intrinsic sizing, keywords) is discrete.
pub fn keyframe_value_to_animatable(
  value : String,
  ctx : ComputeContext,
) -> @animation.AnimatableValue {
  let v = value.trim().to_owned()
  // Pure number (e.g. opacity). `0` stays a Number here and is reconciled to a
  // Length/Percent zero per-track in `build_keyframe_track`.
  if is_pure_number(v) {
    return @animation.AnimatableValue::Number(parse_number(v))
  }
  // Length / percentage. Tried before color because `parse_color` is lenient
  // (it resolves unknown input to transparent), so it must not see dimensions.
  match resolve_dimension(v, ctx) {
    @types.Length(px) => return @animation.AnimatableValue::Length(px)
    @types.Percent(r) => return @animation.AnimatableValue::Percent(r)
    _ => ()
  }
  // Color (#hex / rgb()/hsl()/... functions, or a named color).
  match animatable_color(v) {
    Some(col) => return @animation.AnimatableValue::Color(col)
    None => ()
  }
  @animation.AnimatableValue::Discrete(v)
}

///|
/// Resolve a keyframe value for a specific property. The `transform` property is
/// parsed into a `Transform` (component-wise interpolable); everything else uses
/// the generic computed-value classifier.
fn keyframe_value_for_property(
  property : String,
  value : String,
  ctx : ComputeContext,
) -> @animation.AnimatableValue {
  if property == "transform" {
    @animation.AnimatableValue::Transform(parse_transform(value))
  } else if property == "translate" {
    @animation.AnimatableValue::Transform(
      @parser.parse_translate_property_from_string(value),
    )
  } else if property == "scale" {
    @animation.AnimatableValue::Transform(
      @parser.parse_scale_property_from_string(value),
    )
  } else if property == "rotate" {
    @animation.AnimatableValue::Transform(
      @parser.parse_rotate_property_from_string(value),
    )
  } else {
    keyframe_value_to_animatable(value, ctx)
  }
}

///|
/// Resolve a color, shape-gated so `parse_color`'s lenient transparent fallback
/// does not turn non-color keywords (`auto`, `flex-start`) into colors. Function
/// / hex forms are accepted outright; a bare ident is accepted as a named color
/// only when it does not resolve to the fully-transparent "unknown" sentinel.
fn animatable_color(v : String) -> @types.Color? {
  if v == "transparent" {
    return Some(@types.Color::transparent())
  }
  let is_func_or_hex = v.has_prefix("#") ||
    v.has_prefix("rgb") ||
    v.has_prefix("hsl") ||
    v.has_prefix("hwb") ||
    v.has_prefix("lab") ||
    v.has_prefix("lch") ||
    v.has_prefix("oklab") ||
    v.has_prefix("oklch") ||
    v.has_prefix("color(")
  match parse_color(v).get_color() {
    Some(c) =>
      if is_func_or_hex {
        Some(c)
      } else if c.a == 0.0 && c.r == 0 && c.g == 0 && c.b == 0 {
        None
      } else {
        Some(c)
      }
    None => None
  }
}

///|
/// The dominant interpolable kind in a value list, used to reconcile a unitless
/// `0` (parsed as Number) with Length/Percent siblings (so `left: 0 -> 100px`
/// interpolates as lengths instead of falling back to discrete).
priv enum TrackKind {
  KindNumber
  KindLength
  KindPercent
  KindColor
  KindNone
}

///|
fn animatable_kind(v : @animation.AnimatableValue) -> TrackKind {
  match v {
    @animation.AnimatableValue::Number(_) => KindNumber
    @animation.AnimatableValue::Length(_) => KindLength
    @animation.AnimatableValue::Percent(_) => KindPercent
    @animation.AnimatableValue::Color(_) => KindColor
    @animation.AnimatableValue::Transform(_) => KindNone
    @animation.AnimatableValue::Discrete(_) => KindNone
  }
}

///|
/// Coerce a unitless `Number(0)` to the track's dominant Length/Percent zero.
fn reconcile_zero(
  v : @animation.AnimatableValue,
  dominant : TrackKind,
) -> @animation.AnimatableValue {
  match v {
    @animation.AnimatableValue::Number(n) =>
      if n == 0.0 {
        match dominant {
          KindLength => @animation.AnimatableValue::Length(0.0)
          KindPercent => @animation.AnimatableValue::Percent(0.0)
          _ => v
        }
      } else {
        v
      }
    _ => v
  }
}

///|
/// Extract the string value of a declaration (or "" if not a plain value).
fn declaration_value_string(decl : @cascade.Declaration) -> String {
  match decl.value {
    @cascade.Value(s) => s
    _ => ""
  }
}

///|
/// One raw keyframe collected from the rule before kind reconciliation.
priv struct RawKeyframe {
  offset : Double
  value : @animation.AnimatableValue
  easing : @types.Easing
}

///|
/// Build a per-property animation track from a `@keyframes` rule and the
/// element's base computed value (`base_value`, the value the property has on
/// the element, used to fill missing 0%/100% endpoints). Returns keyframes
/// sorted by offset, with a 0.0 and 1.0 endpoint guaranteed, and unitless-zero
/// values reconciled to the track's dominant Length/Percent kind.
pub fn build_keyframe_track(
  rule : @cascade.KeyframesRule,
  property : String,
  base_value : String,
  ctx : ComputeContext,
) -> Array[@animation.AnimatableKeyframe] {
  let raw : Array[RawKeyframe] = []
  for block in rule.blocks {
    // Find this block's value for the property and its per-keyframe easing.
    let mut value_str : String? = None
    let mut easing = @types.Easing::Linear
    for decl in block.declarations {
      if decl.property == property {
        value_str = Some(declaration_value_string(decl))
      } else if decl.property == "animation-timing-function" {
        match @types.parse_easing(declaration_value_string(decl)) {
          Some(e) => easing = e
          None => ()
        }
      }
    }
    match value_str {
      Some(s) => {
        let v = keyframe_value_for_property(property, s, ctx)
        for off in block.offsets {
          raw.push({ offset: off, value: v, easing })
        }
      }
      None => ()
    }
  }
  let base = keyframe_value_for_property(property, base_value, ctx)
  // Ensure 0.0 and 1.0 endpoints exist (CSS fills them with the base value).
  let mut has_start = false
  let mut has_end = false
  for r in raw {
    if r.offset <= 0.0 {
      has_start = true
    }
    if r.offset >= 1.0 {
      has_end = true
    }
  }
  if !has_start {
    raw.push({ offset: 0.0, value: base, easing: @types.Easing::Linear })
  }
  if !has_end {
    raw.push({ offset: 1.0, value: base, easing: @types.Easing::Linear })
  }
  // Stable insertion sort by offset (keeps source order for equal offsets).
  for i = 1; i < raw.length(); i = i + 1 {
    let cur = raw[i]
    let mut j = i - 1
    while j >= 0 && raw[j].offset > cur.offset {
      raw[j + 1] = raw[j]
      j = j - 1
    }
    raw[j + 1] = cur
  }
  // Determine the dominant interpolable kind to reconcile unitless zeros.
  let mut dominant = KindNone
  for r in raw {
    match animatable_kind(r.value) {
      KindLength => dominant = KindLength
      KindPercent => if dominant is KindNone { dominant = KindPercent }
      KindColor => if dominant is KindNone { dominant = KindColor }
      _ => ()
    }
  }
  let result : Array[@animation.AnimatableKeyframe] = []
  for r in raw {
    result.push(
      @animation.AnimatableKeyframe::with_easing(
        r.offset,
        reconcile_zero(r.value, dominant),
        r.easing,
      ),
    )
  }
  result
}

///|
/// Return `arr[index]` cycling by length (CSS animation longhand lists repeat
/// to match the animation count), or `default` when the list is empty.
fn[T] list_cycle(arr : Array[T], index : Int, default : T) -> T {
  if arr.length() == 0 {
    default
  } else {
    arr[index % arr.length()]
  }
}

///|
fn fill_mode_to_anim(f : @types.AnimationFillMode) -> @animation.FillMode {
  match f {
    @types.AnimationFillMode::None => @animation.FillMode::None
    @types.AnimationFillMode::Forwards => @animation.FillMode::Forwards
    @types.AnimationFillMode::Backwards => @animation.FillMode::Backwards
    @types.AnimationFillMode::Both => @animation.FillMode::Both
  }
}

///|
fn direction_to_anim(
  d : @types.AnimationDirection,
) -> @animation.PlaybackDirection {
  match d {
    @types.AnimationDirection::Normal => @animation.PlaybackDirection::Normal
    @types.AnimationDirection::Reverse => @animation.PlaybackDirection::Reverse
    @types.AnimationDirection::Alternate =>
      @animation.PlaybackDirection::Alternate
    @types.AnimationDirection::AlternateReverse =>
      @animation.PlaybackDirection::AlternateReverse
  }
}

///|
/// Build an `EffectTiming` for the `index`-th animation declared on `style`
/// (its `animation-*` longhands). Durations/delays are converted from seconds to
/// milliseconds (the timing model's unit); `infinite` maps to an infinite
/// iteration count. Longhand lists shorter than the animation list are cycled.
pub fn effect_timing_from_style(
  style : @style.Style,
  index : Int,
) -> @animation.EffectTiming {
  let duration = list_cycle(style.animation_duration, index, 0.0) * 1000.0
  let delay = list_cycle(style.animation_delay, index, 0.0) * 1000.0
  let iterations = match
    list_cycle(
      style.animation_iteration_count,
      index,
      @types.AnimationIterationCount::Count(1.0),
    ) {
    @types.AnimationIterationCount::Count(n) => n
    @types.AnimationIterationCount::Infinite => @double.infinity
  }
  let fill = fill_mode_to_anim(
    list_cycle(style.animation_fill_mode, index, @types.AnimationFillMode::None),
  )
  let direction = direction_to_anim(
    list_cycle(
      style.animation_direction,
      index,
      @types.AnimationDirection::Normal,
    ),
  )
  let easing = list_cycle(
    style.animation_timing_function,
    index,
    @types.Easing::Ease,
  )
  {
    ..@animation.EffectTiming::new(duration),
    delay,
    iterations,
    fill,
    direction,
    easing,
  }
}
