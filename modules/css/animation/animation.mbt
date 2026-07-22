///|
pub(all) enum FillMode {
  None
  Forwards
  Backwards
  Both
  Auto
} derive(Debug, Eq)

///|
pub impl Show for FillMode with fn output(self, logger) {
  match self {
    FillMode::None => logger.write_string("None")
    FillMode::Forwards => logger.write_string("Forwards")
    FillMode::Backwards => logger.write_string("Backwards")
    FillMode::Both => logger.write_string("Both")
    FillMode::Auto => logger.write_string("Auto")
  }
}

///|
pub(all) enum PlaybackDirection {
  Normal
  Reverse
  Alternate
  AlternateReverse
} derive(Debug, Eq)

///|
pub impl Show for PlaybackDirection with fn output(self, logger) {
  match self {
    PlaybackDirection::Normal => logger.write_string("Normal")
    PlaybackDirection::Reverse => logger.write_string("Reverse")
    PlaybackDirection::Alternate => logger.write_string("Alternate")
    PlaybackDirection::AlternateReverse =>
      logger.write_string("AlternateReverse")
  }
}

///|
pub(all) enum AnimationPhase {
  Before
  Active
  After
} derive(Debug, Eq)

///|
pub impl Show for AnimationPhase with fn output(self, logger) {
  match self {
    AnimationPhase::Before => logger.write_string("Before")
    AnimationPhase::Active => logger.write_string("Active")
    AnimationPhase::After => logger.write_string("After")
  }
}

///|
pub(all) enum CompositeOperation {
  Replace
  Add
  Accumulate
} derive(Debug, Eq)

///|
pub impl Show for CompositeOperation with fn output(self, logger) {
  match self {
    CompositeOperation::Replace => logger.write_string("Replace")
    CompositeOperation::Add => logger.write_string("Add")
    CompositeOperation::Accumulate => logger.write_string("Accumulate")
  }
}

///|
pub(all) enum IterationCompositeOperation {
  Replace
  Accumulate
} derive(Debug, Eq)

///|
pub impl Show for IterationCompositeOperation with fn output(self, logger) {
  match self {
    IterationCompositeOperation::Replace => logger.write_string("Replace")
    IterationCompositeOperation::Accumulate => logger.write_string("Accumulate")
  }
}

///|
pub(all) struct EffectTiming {
  delay : Double
  end_delay : Double
  fill : FillMode
  iteration_start : Double
  iterations : Double
  duration : Double
  direction : PlaybackDirection
  easing : @values.Easing
} derive(Debug, Eq)

///|
pub(all) struct ComputedEffectTiming {
  phase : AnimationPhase
  active_duration : Double
  end_time : Double
  local_time : Double
  active_time : Double?
  progress : Double?
  current_iteration : Int?
  directed_progress : Double?
  transformed_progress : Double?
} derive(Debug, Eq)

///|
pub(all) struct NumericKeyframe {
  offset : Double
  value : Double
  easing : @values.Easing
  composite : CompositeOperation?
} derive(Debug, Eq)

///|
pub(all) struct NumericKeyframeEffect {
  keyframes : Array[NumericKeyframe]
  timing : EffectTiming
  composite : CompositeOperation
  iteration_composite : IterationCompositeOperation
} derive(Debug, Eq)

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn fill_allows_before(fill : FillMode) -> Bool {
  match fill {
    FillMode::Backwards | FillMode::Both => true
    FillMode::None | FillMode::Forwards | FillMode::Auto => false
  }
}

///|
fn fill_allows_after(fill : FillMode) -> Bool {
  match fill {
    FillMode::Forwards | FillMode::Both => true
    FillMode::None | FillMode::Backwards | FillMode::Auto => false
  }
}

///|
fn is_reverse_iteration(
  direction : PlaybackDirection,
  current_iteration : Int,
) -> Bool {
  match direction {
    PlaybackDirection::Normal => false
    PlaybackDirection::Reverse => true
    PlaybackDirection::Alternate => current_iteration % 2 == 1
    PlaybackDirection::AlternateReverse => current_iteration % 2 == 0
  }
}

///|
fn clamp_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn compute_progress(
  timing : EffectTiming,
  phase : AnimationPhase,
  active_time : Double,
  active_duration : Double,
) -> (Double, Int, Double) {
  if active_duration <= 0.0 || timing.duration <= 0.0 {
    let progress = if phase == AnimationPhase::Before { 0.0 } else { 1.0 }
    let current_iteration = 0
    let directed = if is_reverse_iteration(timing.direction, current_iteration) {
      1.0 - progress
    } else {
      progress
    }
    return (progress, current_iteration, directed)
  }
  let overall_progress = active_time / timing.duration + timing.iteration_start
  let at_end = active_time == active_duration && timing.iterations > 0.0
  let current_iteration = if at_end {
    max_double(0.0, overall_progress.ceil() - 1.0).to_int()
  } else {
    max_double(0.0, overall_progress.floor()).to_int()
  }
  let progress = if at_end {
    1.0
  } else {
    overall_progress - overall_progress.floor()
  }
  let progress = clamp_unit(progress)
  let directed = if is_reverse_iteration(timing.direction, current_iteration) {
    1.0 - progress
  } else {
    progress
  }
  (progress, current_iteration, directed)
}

///|
pub fn EffectTiming::new(duration : Double) -> EffectTiming {
  {
    delay: 0.0,
    end_delay: 0.0,
    fill: FillMode::Auto,
    iteration_start: 0.0,
    iterations: 1.0,
    duration,
    direction: PlaybackDirection::Normal,
    easing: @values.Easing::Linear,
  }
}

///|
pub fn EffectTiming::active_duration(self : EffectTiming) -> Double {
  max_double(0.0, self.duration) * max_double(0.0, self.iterations)
}

///|
pub fn EffectTiming::end_time(self : EffectTiming) -> Double {
  self.delay + self.active_duration() + self.end_delay
}

///|
pub fn EffectTiming::at(
  self : EffectTiming,
  local_time : Double,
) -> ComputedEffectTiming {
  let active_duration = self.active_duration()
  let active_start = self.delay
  let active_end = active_start + active_duration
  let phase = if local_time < active_start {
    AnimationPhase::Before
  } else if local_time < active_end {
    AnimationPhase::Active
  } else {
    AnimationPhase::After
  }
  let active_time = match phase {
    AnimationPhase::Before =>
      if fill_allows_before(self.fill) {
        Some(0.0)
      } else {
        None
      }
    AnimationPhase::Active => Some(local_time - active_start)
    AnimationPhase::After =>
      if fill_allows_after(self.fill) {
        Some(active_duration)
      } else {
        None
      }
  }
  match active_time {
    Some(active_time) => {
      let (progress, current_iteration, directed_progress) = compute_progress(
        self, phase, active_time, active_duration,
      )
      {
        phase,
        active_duration,
        end_time: self.end_time(),
        local_time,
        active_time: Some(active_time),
        progress: Some(progress),
        current_iteration: Some(current_iteration),
        directed_progress: Some(directed_progress),
        transformed_progress: Some(self.easing.sample(directed_progress)),
      }
    }
    None =>
      {
        phase,
        active_duration,
        end_time: self.end_time(),
        local_time,
        active_time: None,
        progress: None,
        current_iteration: None,
        directed_progress: None,
        transformed_progress: None,
      }
  }
}

///|
pub fn NumericKeyframe::new(offset : Double, value : Double) -> NumericKeyframe {
  { offset, value, easing: @values.Easing::Linear, composite: None }
}

///|
pub fn NumericKeyframe::with_easing(
  offset : Double,
  value : Double,
  easing : @values.Easing,
) -> NumericKeyframe {
  { offset, value, easing, composite: None }
}

///|
pub fn NumericKeyframe::with_composite(
  offset : Double,
  value : Double,
  easing : @values.Easing,
  composite : CompositeOperation,
) -> NumericKeyframe {
  { offset, value, easing, composite: Some(composite) }
}

///|
fn validate_numeric_keyframes(keyframes : Array[NumericKeyframe]) -> Bool {
  if keyframes.length() < 2 {
    return false
  }
  if keyframes[0].offset != 0.0 {
    return false
  }
  if keyframes[keyframes.length() - 1].offset != 1.0 {
    return false
  }
  for i = 0; i < keyframes.length(); i = i + 1 {
    if keyframes[i].offset < 0.0 || keyframes[i].offset > 1.0 {
      return false
    }
    if i > 0 && keyframes[i].offset <= keyframes[i - 1].offset {
      return false
    }
  }
  true
}

///|
fn keyframe_composite(
  effect : NumericKeyframeEffect,
  keyframe : NumericKeyframe,
) -> CompositeOperation {
  match keyframe.composite {
    Some(composite) => composite
    None => effect.composite
  }
}

///|
fn apply_composite(
  composite : CompositeOperation,
  underlying_value : Double,
  effect_value : Double,
) -> Double {
  match composite {
    CompositeOperation::Replace => effect_value
    CompositeOperation::Add | CompositeOperation::Accumulate =>
      underlying_value + effect_value
  }
}

///|
fn iteration_accumulation_delta(effect : NumericKeyframeEffect) -> Double {
  let keyframes = effect.keyframes
  keyframes[keyframes.length() - 1].value - keyframes[0].value
}

///|
pub fn NumericKeyframeEffect::new(
  keyframes : Array[NumericKeyframe],
  timing : EffectTiming,
) -> NumericKeyframeEffect? {
  if !validate_numeric_keyframes(keyframes) {
    return None
  }
  Some({
    keyframes: keyframes.copy(),
    timing,
    composite: CompositeOperation::Replace,
    iteration_composite: IterationCompositeOperation::Replace,
  })
}

///|
pub fn NumericKeyframeEffect::with_composite(
  keyframes : Array[NumericKeyframe],
  timing : EffectTiming,
  composite : CompositeOperation,
  iteration_composite : IterationCompositeOperation,
) -> NumericKeyframeEffect? {
  if !validate_numeric_keyframes(keyframes) {
    return None
  }
  Some({ keyframes: keyframes.copy(), timing, composite, iteration_composite })
}

///|
pub fn NumericKeyframeEffect::sample_progress(
  self : NumericKeyframeEffect,
  progress : Double,
) -> Double {
  self.sample_progress_with_underlying(progress, 0.0, 0)
}

///|
pub fn NumericKeyframeEffect::sample_progress_with_underlying(
  self : NumericKeyframeEffect,
  progress : Double,
  underlying_value : Double,
  current_iteration : Int,
) -> Double {
  let progress = clamp_unit(progress)
  let keyframes = self.keyframes
  let iteration_accumulation = match self.iteration_composite {
    IterationCompositeOperation::Replace => 0.0
    IterationCompositeOperation::Accumulate =>
      current_iteration.to_double() * iteration_accumulation_delta(self)
  }
  if progress <= keyframes[0].offset {
    return apply_composite(
      keyframe_composite(self, keyframes[0]),
      underlying_value,
      keyframes[0].value + iteration_accumulation,
    )
  }
  let last_index = keyframes.length() - 1
  if progress >= keyframes[last_index].offset {
    return apply_composite(
      keyframe_composite(self, keyframes[last_index]),
      underlying_value,
      keyframes[last_index].value + iteration_accumulation,
    )
  }
  for i = 0; i < last_index; i = i + 1 {
    let start = keyframes[i]
    let end = keyframes[i + 1]
    if progress <= end.offset {
      let local_progress = (progress - start.offset) /
        (end.offset - start.offset)
      let eased_progress = start.easing.sample(local_progress)
      let start_value = apply_composite(
        keyframe_composite(self, start),
        underlying_value,
        start.value + iteration_accumulation,
      )
      let end_value = apply_composite(
        keyframe_composite(self, end),
        underlying_value,
        end.value + iteration_accumulation,
      )
      return start_value + (end_value - start_value) * eased_progress
    }
  }
  apply_composite(
    keyframe_composite(self, keyframes[last_index]),
    underlying_value,
    keyframes[last_index].value + iteration_accumulation,
  )
}

///|
pub fn NumericKeyframeEffect::sample(
  self : NumericKeyframeEffect,
  local_time : Double,
) -> Double? {
  self.sample_with_underlying(local_time, 0.0)
}

///|
pub fn NumericKeyframeEffect::sample_with_underlying(
  self : NumericKeyframeEffect,
  local_time : Double,
  underlying_value : Double,
) -> Double? {
  let timing = self.timing.at(local_time)
  match (timing.transformed_progress, timing.current_iteration) {
    (Some(progress), Some(current_iteration)) =>
      Some(
        self.sample_progress_with_underlying(
          progress, underlying_value, current_iteration,
        ),
      )
    _ => None
  }
}
