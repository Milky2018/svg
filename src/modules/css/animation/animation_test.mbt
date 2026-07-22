///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.000000001)
}

///|
fn assert_option_close(actual : Double?, expected : Double) -> Unit raise {
  match actual {
    Some(value) => assert_close(value, expected)
    None => fail("expected value")
  }
}

///|
fn sample_value(
  effect : NumericKeyframeEffect,
  local_time : Double,
) -> Double raise {
  match effect.sample(local_time) {
    Some(value) => value
    None => fail("expected sampled value")
  }
}

///|
fn numeric_effect(
  keyframes : Array[NumericKeyframe],
  timing : EffectTiming,
) -> NumericKeyframeEffect raise {
  match NumericKeyframeEffect::new(keyframes, timing) {
    Some(effect) => effect
    None => fail("expected keyframe effect")
  }
}

///|
test "EffectTiming::at phases and fill modes" {
  let timing = { ..EffectTiming::new(1000.0), delay: 100.0 }
  let before = timing.at(50.0)
  inspect(before.phase, content="Before")
  debug_inspect(before.progress, content="None")
  let active = timing.at(600.0)
  inspect(active.phase, content="Active")
  assert_option_close(active.progress, 0.5)
  assert_option_close(active.directed_progress, 0.5)
  assert_option_close(active.transformed_progress, 0.5)
  let after = timing.at(1200.0)
  inspect(after.phase, content="After")
  debug_inspect(after.progress, content="None")

  let forwards = { ..timing, fill: FillMode::Forwards }.at(1200.0)
  assert_option_close(forwards.progress, 1.0)
  assert_option_close(forwards.transformed_progress, 1.0)
  let backwards = { ..timing, fill: FillMode::Backwards }.at(50.0)
  assert_option_close(backwards.progress, 0.0)
  assert_option_close(backwards.transformed_progress, 0.0)
}

///|
test "EffectTiming::at direction iterations and easing" {
  let alternate = {
    ..EffectTiming::new(1000.0),
    iterations: 2.0,
    direction: PlaybackDirection::Alternate,
  }
  let first = alternate.at(250.0)
  debug_inspect(first.current_iteration, content="Some(0)")
  assert_option_close(first.directed_progress, 0.25)
  let second = alternate.at(1250.0)
  debug_inspect(second.current_iteration, content="Some(1)")
  assert_option_close(second.progress, 0.25)
  assert_option_close(second.directed_progress, 0.75)

  let reverse = {
    ..EffectTiming::new(1000.0),
    direction: PlaybackDirection::Reverse,
  }
  assert_option_close(reverse.at(250.0).directed_progress, 0.75)

  let eased = {
    ..EffectTiming::new(1000.0),
    easing: @values.Easing::EaseInQuad,
  }
  assert_option_close(eased.at(500.0).directed_progress, 0.5)
  assert_option_close(eased.at(500.0).transformed_progress, 0.25)
}

///|
test "NumericKeyframeEffect::sample interpolates keyframes" {
  let effect = numeric_effect(
    [
      NumericKeyframe::with_easing(0.0, 0.0, @values.Easing::EaseInQuad),
      NumericKeyframe::new(0.5, 100.0),
      NumericKeyframe::new(1.0, 200.0),
    ],
    EffectTiming::new(1000.0),
  )
  assert_close(sample_value(effect, 250.0), 25.0)
  assert_close(sample_value(effect, 750.0), 150.0)
}

///|
test "NumericKeyframeEffect::sample respects timing fill and global easing" {
  let timing = {
    ..EffectTiming::new(1000.0),
    fill: FillMode::Both,
    easing: @values.Easing::EaseOutQuad,
  }
  let effect = numeric_effect(
    [NumericKeyframe::new(0.0, 0.0), NumericKeyframe::new(1.0, 100.0)],
    timing,
  )
  assert_close(sample_value(effect, -10.0), 0.0)
  assert_close(sample_value(effect, 500.0), 75.0)
  assert_close(sample_value(effect, 1100.0), 100.0)

  let no_fill = numeric_effect(
    [NumericKeyframe::new(0.0, 0.0), NumericKeyframe::new(1.0, 100.0)],
    EffectTiming::new(1000.0),
  )
  debug_inspect(no_fill.sample(-10.0), content="None")
  debug_inspect(no_fill.sample(1100.0), content="None")
}

///|
test "NumericKeyframeEffect::sample_with_underlying applies composite modes" {
  let replace = numeric_effect(
    [NumericKeyframe::new(0.0, 10.0), NumericKeyframe::new(1.0, 20.0)],
    EffectTiming::new(1000.0),
  )
  assert_option_close(replace.sample_with_underlying(500.0, 100.0), 15.0)

  let add = NumericKeyframeEffect::with_composite(
    [NumericKeyframe::new(0.0, 10.0), NumericKeyframe::new(1.0, 20.0)],
    EffectTiming::new(1000.0),
    CompositeOperation::Add,
    IterationCompositeOperation::Replace,
  ).unwrap()
  assert_option_close(add.sample_with_underlying(500.0, 100.0), 115.0)

  let keyframe_override = NumericKeyframeEffect::with_composite(
    [
      NumericKeyframe::with_composite(
        0.0,
        10.0,
        @values.Easing::Linear,
        CompositeOperation::Add,
      ),
      NumericKeyframe::new(1.0, 20.0),
    ],
    { ..EffectTiming::new(1000.0), fill: FillMode::Both },
    CompositeOperation::Replace,
    IterationCompositeOperation::Replace,
  ).unwrap()
  assert_option_close(
    keyframe_override.sample_with_underlying(0.0, 100.0),
    110.0,
  )
  assert_option_close(
    keyframe_override.sample_with_underlying(1000.0, 100.0),
    20.0,
  )
}

///|
test "NumericKeyframeEffect::sample applies iteration accumulation" {
  let timing = { ..EffectTiming::new(1000.0), iterations: 3.0 }
  let effect = NumericKeyframeEffect::with_composite(
    [NumericKeyframe::new(0.0, 0.0), NumericKeyframe::new(1.0, 10.0)],
    timing,
    CompositeOperation::Add,
    IterationCompositeOperation::Accumulate,
  ).unwrap()
  assert_option_close(effect.sample(500.0), 5.0)
  assert_option_close(effect.sample(1500.0), 15.0)
  assert_option_close(effect.sample_with_underlying(2500.0, 100.0), 125.0)
}

///|
test "NumericKeyframeEffect::new validates offsets" {
  debug_inspect(
    NumericKeyframeEffect::new(
      [NumericKeyframe::new(0.0, 0.0)],
      EffectTiming::new(1.0),
    ),
    content="None",
  )
  debug_inspect(
    NumericKeyframeEffect::new(
      [NumericKeyframe::new(0.5, 0.0), NumericKeyframe::new(1.0, 100.0)],
      EffectTiming::new(1.0),
    ),
    content="None",
  )
  debug_inspect(
    NumericKeyframeEffect::new(
      [NumericKeyframe::new(0.0, 0.0), NumericKeyframe::new(1.1, 100.0)],
      EffectTiming::new(1.0),
    ),
    content="None",
  )
  // Duplicate (non-increasing) offsets are rejected: offsets must be strictly
  // increasing, so two keyframes sharing the same offset fail validation.
  debug_inspect(
    NumericKeyframeEffect::new(
      [
        NumericKeyframe::new(0.0, 0.0),
        NumericKeyframe::new(0.5, 10.0),
        NumericKeyframe::new(0.5, 20.0),
        NumericKeyframe::new(1.0, 100.0),
      ],
      EffectTiming::new(1.0),
    ),
    content="None",
  )
}

///|
test "interpolate computed values by kind" {
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Length(0.0),
      @animation.AnimatableValue::Length(100.0),
      0.25,
    ),
    content="Length(25)",
  )
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Number(1.0),
      @animation.AnimatableValue::Number(3.0),
      0.5,
    ),
    content="Number(2)",
  )
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Percent(0.0),
      @animation.AnimatableValue::Percent(1.0),
      0.5,
    ),
    content="Percent(0.5)",
  )
  // sRGB color interpolation
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Color(@values.Color::rgb(0, 0, 0)),
      @animation.AnimatableValue::Color(@values.Color::rgb(255, 0, 0)),
      0.5,
    ),
    content="Color(rgb(128, 0, 0))",
  )
}

///|
test "interpolate mismatched / non-interpolable kinds are discrete" {
  // length <-> percent cannot interpolate => discrete jump at 0.5
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Length(0.0),
      @animation.AnimatableValue::Percent(1.0),
      0.25,
    ),
    content="Length(0)",
  )
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Length(0.0),
      @animation.AnimatableValue::Percent(1.0),
      0.75,
    ),
    content="Percent(1)",
  )
  // `auto` <-> length (Discrete) also jumps
  inspect(
    @animation.interpolate(
      @animation.AnimatableValue::Discrete("auto"),
      @animation.AnimatableValue::Length(100.0),
      0.6,
    ),
    content="Length(100)",
  )
}

///|
test "AnimatableKeyframeEffect samples typed keyframes with easing and timing" {
  let effect = @animation.AnimatableKeyframeEffect::new(
    [
      @animation.AnimatableKeyframe::new(
        0.0,
        @animation.AnimatableValue::Length(0.0),
      ),
      @animation.AnimatableKeyframe::new(
        1.0,
        @animation.AnimatableValue::Length(100.0),
      ),
    ],
    { ..@animation.EffectTiming::new(1000.0), fill: @animation.FillMode::Both },
  ).unwrap()
  // midpoint
  inspect(effect.sample(500.0).unwrap(), content="Length(50)")
  // before phase with Both fill clamps to first
  inspect(effect.sample(-10.0).unwrap(), content="Length(0)")
  // after phase clamps to last
  inspect(effect.sample(2000.0).unwrap(), content="Length(100)")
}

///|
test "oklab color interpolation midpoint" {
  let mid = @animation.interpolate_color_oklab(
    @values.Color::rgb(0, 0, 0),
    @values.Color::rgb(255, 255, 255),
    0.5,
  )
  inspect(mid, content="rgb(99, 99, 99)")
  let redblue = @animation.interpolate_color_oklab(
    @values.Color::rgb(255, 0, 0),
    @values.Color::rgb(0, 0, 255),
    0.5,
  )
  inspect(redblue, content="rgb(140, 83, 162)")
}

///|
test "interpolate_color_in across color spaces" {
  let black = @values.Color::rgb(0, 0, 0)
  let white = @values.Color::rgb(255, 255, 255)
  // black -> white midpoint differs per space (perceptual vs sRGB-linear gamma)
  inspect(
    @animation.interpolate_color_in(
      @animation.ColorSpace::Srgb,
      black,
      white,
      0.5,
    ),
    content="rgb(128, 128, 128)",
  )
  inspect(
    @animation.interpolate_color_in(
      @animation.ColorSpace::Oklab,
      black,
      white,
      0.5,
    ),
    content="rgb(99, 99, 99)",
  )
  inspect(
    @animation.interpolate_color_in(
      @animation.ColorSpace::Lab,
      black,
      white,
      0.5,
    ),
    content="rgb(119, 119, 119)",
  )
  let red = @values.Color::rgb(255, 0, 0)
  let blue = @values.Color::rgb(0, 0, 255)
  // polar spaces interpolate hue along the shortest arc
  inspect(
    @animation.interpolate_color_in(
      @animation.ColorSpace::Oklch,
      red,
      blue,
      0.5,
    ),
    content="rgb(186, 0, 194)",
  )
  inspect(
    @animation.interpolate_color_in(@animation.ColorSpace::Lch, red, blue, 0.5),
    content="rgb(250, 0, 128)",
  )
}
