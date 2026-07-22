///|
test "Size::new and zero" {
  let size = Size::new(100.0, 200.0)
  inspect(size.width, content="100")
  inspect(size.height, content="200")
  let zero = Size::zero()
  inspect(zero.width, content="0")
  inspect(zero.height, content="0")
}

///|
test "Point::new and zero" {
  let point = Point::new(10.0, 20.0)
  inspect(point.x, content="10")
  inspect(point.y, content="20")
  let zero = Point::zero()
  inspect(zero.x, content="0")
  inspect(zero.y, content="0")
}

///|
test "Rect::new and sums" {
  let rect : Rect[Double] = Rect::new(10.0, 20.0, 5.0, 15.0)
  inspect(rect.horizontal_sum(), content="30")
  inspect(rect.vertical_sum(), content="20")
}

///|
test "Dimension::resolve" {
  let length : Dimension = Length(50.0)
  let percent : Dimension = Percent(0.5)
  let auto : Dimension = Auto
  debug_inspect(length.resolve(100.0), content="Some(50)")
  debug_inspect(percent.resolve(100.0), content="Some(50)")
  debug_inspect(auto.resolve(100.0), content="None")
  inspect(auto.resolve_or(100.0, 25.0), content="25")
}

///|
test "BoundingRect operations" {
  let rect = BoundingRect::new(10.0, 20.0, 100.0, 50.0)
  inspect(rect.right(), content="110")
  inspect(rect.bottom(), content="70")
  inspect(rect.area(), content="5000")
}

///|
test "min and max helpers" {
  inspect(min(3.0, 5.0), content="3")
  inspect(min(5.0, 3.0), content="3")
  inspect(max(3.0, 5.0), content="5")
  inspect(max(5.0, 3.0), content="5")
}

///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.000000001)
}

///|
fn assert_easing_sample(
  easing : Easing?,
  progress : Double,
  expected : Double,
) -> Unit raise {
  match easing {
    Some(easing) => assert_close(easing.sample(progress), expected)
    None => fail("expected easing")
  }
}

///|
test "Easing::sample linear and cubic presets" {
  inspect(Easing::Linear.sample(0.5), content="0.5")
  assert_close(Easing::EaseIn.sample(0.5), 0.31535681250589304)
  assert_close(Easing::EaseOut.sample(0.5), 0.6846431874941068)
  assert_close(Easing::EaseInOut.sample(0.5), 0.5)
}

///|
test "Easing::sample clamps progress" {
  inspect(Easing::Linear.sample(-0.25), content="0")
  inspect(Easing::Linear.sample(1.25), content="1")
}

///|
test "Easing::sample cubic-bezier" {
  let easing = Easing::cubic_bezier(0.25, 0.1, 0.25, 1.0)
  inspect(easing, content="CubicBezier(0.25, 0.1, 0.25, 1)")
  assert_close(easing.sample(0.5), 0.8024033876954126)
}

///|
test "Easing::sample steps" {
  let start = Easing::steps(4, StepPosition::Start)
  let end = Easing::steps(4, StepPosition::End)
  inspect(start.sample(0.0), content="0.25")
  inspect(start.sample(0.24), content="0.25")
  inspect(end.sample(0.24), content="0")
  inspect(end.sample(0.25), content="0.25")
  inspect(end.sample(1.0), content="1")
}

///|
test "Easing::sample CSS step positions" {
  let jump_none = Easing::steps(4, StepPosition::JumpNone)
  let jump_both = Easing::steps(4, StepPosition::JumpBoth)
  inspect(jump_none.sample(0.0), content="0")
  assert_close(jump_none.sample(0.25), 1.0 / 3.0)
  inspect(jump_none.sample(1.0), content="1")
  inspect(jump_both.sample(0.0), content="0.2")
  inspect(jump_both.sample(0.25), content="0.4")
  inspect(jump_both.sample(1.0), content="1")
}

///|
test "parse_easing CSS step aliases" {
  debug_inspect(parse_easing("step-start"), content="Some(Steps(1, Start))")
  debug_inspect(parse_easing("step-end"), content="Some(Steps(1, End))")
  debug_inspect(
    parse_easing("steps(4, jump-start)"),
    content="Some(Steps(4, Start))",
  )
  debug_inspect(
    parse_easing("steps(4, jump-end)"),
    content="Some(Steps(4, End))",
  )
}

///|
test "Easing::sample CSS linear function" {
  match
    Easing::linear([
      LinearEasingPoint::new(0.0, 0.0),
      LinearEasingPoint::new(0.5, 0.25),
      LinearEasingPoint::new(1.0, 1.0),
    ]) {
    Some(easing) => assert_close(easing.sample(0.75), 0.625)
    None => fail("expected linear easing")
  }
  debug_inspect(
    Easing::linear([LinearEasingPoint::new(0.0, 0.0)]),
    content="None",
  )
  debug_inspect(
    Easing::linear([
      LinearEasingPoint::new(1.0, 1.0),
      LinearEasingPoint::new(0.0, 0.0),
    ]),
    content="None",
  )
  assert_easing_sample(parse_easing("linear(0, 0.25, 1)"), 0.25, 0.125)
  assert_easing_sample(parse_easing("linear(0, 0.25, 1)"), 0.5, 0.25)
  assert_easing_sample(parse_easing("linear(0, 0.25, 1)"), 0.75, 0.625)
  assert_easing_sample(parse_easing("linear(0, 0.25 25% 75%, 1)"), 0.5, 0.25)
  assert_easing_sample(parse_easing("linear(0, 0.25 25% 75%, 1)"), 0.875, 0.625)
  assert_easing_sample(parse_easing("linear(0 20%, 0.5 10%, 1)"), 0.2, 0.5)
  assert_easing_sample(parse_easing("linear(0 0%, 1 100%)"), 0.5, 0.5)
  assert_easing_sample(parse_easing("linear(0, 0 50%, 1)"), 0.25, 0.0)
  assert_easing_sample(parse_easing("linear(0, 0 50%, 1)"), 0.75, 0.5)
  assert_easing_sample(parse_easing("linear(-0.25, 1.25)"), 0.5, 0.5)
  debug_inspect(parse_easing("linear(0)"), content="None")
  debug_inspect(parse_easing("linear()"), content="None")
  debug_inspect(parse_easing("linear(0%, 1)"), content="None")
  debug_inspect(parse_easing("linear(0, 1 garbage)"), content="None")
  debug_inspect(parse_easing("linear(0 0% 50% 75%, 1)"), content="None")
}

///|
test "Easing::apply interpolates values" {
  assert_close(Easing::EaseInQuad.apply(10.0, 20.0, 0.5), 12.5)
  assert_close(Easing::EaseOutQuad.apply(20.0, 10.0, 0.5), 12.5)
  inspect(Easing::Linear.apply(10.0, 20.0, -1.0), content="10")
  inspect(Easing::Linear.apply(10.0, 20.0, 2.0), content="20")
  assert_close(Easing::EaseOutBack.apply(0.0, 100.0, 0.5), 108.76975)
}

///|
test "Easing::frames exposes intermediate values" {
  let frames = Easing::EaseInQuad.frames(0.0, 100.0, 5)
  inspect(frames.length(), content="5")
  assert_close(frames[0].progress, 0.0)
  assert_close(frames[0].eased_progress, 0.0)
  assert_close(frames[0].value, 0.0)
  assert_close(frames[1].progress, 0.25)
  assert_close(frames[1].eased_progress, 0.0625)
  assert_close(frames[1].value, 6.25)
  assert_close(frames[2].progress, 0.5)
  assert_close(frames[2].eased_progress, 0.25)
  assert_close(frames[2].value, 25.0)
  assert_close(frames[4].progress, 1.0)
  assert_close(frames[4].eased_progress, 1.0)
  assert_close(frames[4].value, 100.0)

  inspect(Easing::Linear.frames(0.0, 10.0, 0).length(), content="0")
  let single = Easing::EaseOutQuad.frames(0.0, 10.0, 1)
  inspect(single.length(), content="1")
  assert_close(single[0].progress, 0.0)
  assert_close(single[0].value, 0.0)

  let clamped = Easing::EaseInQuad.frame(0.0, 10.0, 2.0)
  assert_close(clamped.progress, 1.0)
  assert_close(clamped.eased_progress, 1.0)
  assert_close(clamped.value, 10.0)

  let overshoot = Easing::EaseOutBack.frame(0.0, 100.0, 0.5)
  assert_true(overshoot.eased_progress > 1.0)
  assert_true(overshoot.value > 100.0)
}

///|
test "Easing::sample named polynomial and sine easings" {
  assert_close(Easing::EaseInSine.sample(0.5), 0.2928932188134524)
  assert_close(Easing::EaseOutSine.sample(0.5), 0.7071067811865475)
  assert_close(Easing::EaseInOutSine.sample(0.25), 0.1464466094067262)
  assert_close(Easing::EaseInQuad.sample(0.5), 0.25)
  assert_close(Easing::EaseOutQuad.sample(0.5), 0.75)
  assert_close(Easing::EaseInOutQuad.sample(0.25), 0.125)
  assert_close(Easing::EaseInCubic.sample(0.5), 0.125)
  assert_close(Easing::EaseOutCubic.sample(0.5), 0.875)
  assert_close(Easing::EaseInOutCubic.sample(0.25), 0.0625)
  assert_close(Easing::EaseInQuart.sample(0.5), 0.0625)
  assert_close(Easing::EaseOutQuart.sample(0.5), 0.9375)
  assert_close(Easing::EaseInOutQuart.sample(0.25), 0.03125)
  assert_close(Easing::EaseInQuint.sample(0.5), 0.03125)
  assert_close(Easing::EaseOutQuint.sample(0.5), 0.96875)
  assert_close(Easing::EaseInOutQuint.sample(0.25), 0.015625)
}

///|
test "Easing::sample named special easings" {
  assert_close(Easing::EaseInExpo.sample(0.5), 0.03125)
  assert_close(Easing::EaseOutExpo.sample(0.5), 0.96875)
  assert_close(Easing::EaseInOutExpo.sample(0.25), 0.015625)
  assert_close(Easing::EaseInCirc.sample(0.5), 0.1339745962155614)
  assert_close(Easing::EaseOutCirc.sample(0.5), 0.8660254037844386)
  assert_close(Easing::EaseInOutCirc.sample(0.25), 0.0669872981077807)
  assert_close(Easing::EaseInBack.sample(0.5), -0.08769750000000004)
  assert_close(Easing::EaseOutBack.sample(0.5), 1.0876975)
  assert_close(Easing::EaseInOutBack.sample(0.25), -0.09968184375)
  assert_close(Easing::EaseInElastic.sample(0.5), -0.015625000000000045)
  assert_close(Easing::EaseOutElastic.sample(0.5), 1.015625)
  assert_close(Easing::EaseInOutElastic.sample(0.25), 0.011969444423734044)
  assert_close(Easing::EaseInBounce.sample(0.5), 0.234375)
  assert_close(Easing::EaseOutBounce.sample(0.5), 0.765625)
  assert_close(Easing::EaseInOutBounce.sample(0.25), 0.1171875)
}

///|
test "parse_easing keywords and functions" {
  debug_inspect(parse_easing("linear"), content="Some(Linear)")
  debug_inspect(parse_easing("ease"), content="Some(Ease)")
  debug_inspect(parse_easing("ease-in"), content="Some(EaseIn)")
  debug_inspect(parse_easing("ease-out"), content="Some(EaseOut)")
  debug_inspect(parse_easing("ease-in-out"), content="Some(EaseInOut)")
  debug_inspect(
    parse_easing("cubic-bezier(0.25, 0.1, 0.25, 1)"),
    content="Some(CubicBezier(0.25, 0.1, 0.25, 1))",
  )
  debug_inspect(
    parse_easing("steps(4, start)"),
    content="Some(Steps(4, Start))",
  )
  debug_inspect(parse_easing("steps(4)"), content="Some(Steps(4, End))")
  debug_inspect(
    parse_easing("steps(4, jump-none)"),
    content="Some(Steps(4, JumpNone))",
  )
  debug_inspect(
    parse_easing("steps(4, jump-both)"),
    content="Some(Steps(4, JumpBoth))",
  )
  debug_inspect(parse_easing("cubic-bezier(-1, 0, 1, 1)"), content="None")
  debug_inspect(parse_easing("steps(0)"), content="None")
  debug_inspect(parse_easing("steps(1, jump-none)"), content="None")
}

///|
test "parse_easing named easings" {
  for
    name in [
      "ease-in-sine", "ease-out-sine", "ease-in-out-sine", "ease-in-quad", "ease-out-quad",
      "ease-in-out-quad", "ease-in-cubic", "ease-out-cubic", "ease-in-out-cubic",
      "ease-in-quart", "ease-out-quart", "ease-in-out-quart", "ease-in-quint", "ease-out-quint",
      "ease-in-out-quint", "ease-in-expo", "ease-out-expo", "ease-in-out-expo", "ease-in-circ",
      "ease-out-circ", "ease-in-out-circ", "ease-in-back", "ease-out-back", "ease-in-out-back",
      "ease-in-elastic", "ease-out-elastic", "ease-in-out-elastic", "ease-in-bounce",
      "ease-out-bounce", "ease-in-out-bounce",
    ] {
    assert_true(parse_easing(name) is Some(_))
  }
  debug_inspect(parse_easing("easeInSine"), content="Some(EaseInSine)")
  debug_inspect(
    parse_easing("ease_in_out_bounce"),
    content="Some(EaseInOutBounce)",
  )
}

///|
test "Dimension::resolve - MinContent/MaxContent/FitContent return None" {
  debug_inspect(Dimension::MinContent.resolve(100.0), content="None")
  debug_inspect(Dimension::MaxContent.resolve(100.0), content="None")
  debug_inspect(Dimension::FitContent(50.0).resolve(100.0), content="None")
}

///|
test "Dimension::resolve_or_intrinsic - MinContent/MaxContent/FitContent use fallback" {
  inspect(Dimension::resolve_or_intrinsic(MaxContent, 100.0, 7.0), content="7")
}

///|
test "resolve_rect_intrinsic - MinContent/MaxContent/FitContent edge" {
  let rect : Rect[Dimension] = {
    left: MinContent,
    right: MaxContent,
    top: FitContent(20.0),
    bottom: Length(5.0),
  }
  let resolved = resolve_rect_intrinsic(rect)
  inspect(resolved.left, content="0")
  inspect(resolved.right, content="0")
  inspect(resolved.top, content="0")
  inspect(resolved.bottom, content="5")
}

///|
test "resolve_dimensions_with_aspect_ratio - negative aspect ratio" {
  let (w, h) = resolve_dimensions_with_aspect_ratio(
    Some(200.0),
    Some(100.0),
    Some(-1.0),
    0.0,
    1000.0,
    0.0,
    1000.0,
  )
  // ar <= 0.0 path: just returns the input
  debug_inspect(w, content="Some(200)")
  debug_inspect(h, content="Some(100)")
}

///|
test "Size::map and Show" {
  let s = Size::new(10.0, 20.0)
  let doubled = s.map(fn(v) { v * 2.0 })
  inspect(doubled.width, content="20")
  inspect(doubled.height, content="40")
  inspect(s, content="Size { width: 10, height: 20 }")
}

///|
test "Point::map and Show" {
  let p = Point::new(2.0, 3.0)
  let neg = p.map(fn(v) { -v })
  inspect(neg.x, content="-2")
  inspect(neg.y, content="-3")
  inspect(p, content="Point { x: 2, y: 3 }")
}

///|
test "Rect helpers" {
  let r : Rect[Double] = Rect::all(7.0)
  inspect(r.left, content="7")
  inspect(r.right, content="7")
  inspect(r.top, content="7")
  inspect(r.bottom, content="7")
  let r2 = r.map(fn(v) { v + 1.0 })
  inspect(r2.left, content="8")
  let zero = Rect::zero()
  inspect(zero.horizontal_sum(), content="0")
  inspect(zero.vertical_sum(), content="0")
  inspect(r, content="Rect { left: 7, right: 7, top: 7, bottom: 7 }")
}

///|
test "Line construction and Show" {
  let l = Line::new(1.0, 5.0)
  inspect(l.start, content="1")
  inspect(l.end, content="5")
  inspect(l, content="Line { start: 1, end: 5 }")
}

///|
test "Dimension::eq_length and eq_percent" {
  let len : Dimension = Length(50.0)
  let pct : Dimension = Percent(0.5)
  assert_true(len.eq_length(50.0))
  assert_false(len.eq_length(51.0))
  assert_false(pct.eq_length(0.5))
  assert_true(pct.eq_percent(0.5))
  assert_false(pct.eq_percent(0.4))
  assert_false(len.eq_percent(50.0))
}

///|
test "Dimension::is_definite and is_intrinsic" {
  assert_true(Dimension::is_definite(Length(10.0)))
  assert_true(Dimension::is_definite(Percent(0.5)))
  assert_false(Dimension::is_definite(Auto))
  assert_false(Dimension::is_definite(MinContent))
  assert_true(Dimension::is_intrinsic(MinContent))
  assert_true(Dimension::is_intrinsic(MaxContent))
  assert_true(Dimension::is_intrinsic(FitContent(100.0)))
  assert_false(Dimension::is_intrinsic(Auto))
  assert_false(Dimension::is_intrinsic(Length(0.0)))
}

///|
test "Dimension::resolve_or_intrinsic" {
  inspect(
    Dimension::resolve_or_intrinsic(Length(10.0), 100.0, 5.0),
    content="10",
  )
  inspect(
    Dimension::resolve_or_intrinsic(Percent(0.4), 100.0, 5.0),
    content="40",
  )
  inspect(Dimension::resolve_or_intrinsic(Auto, 100.0, 5.0), content="5")
  inspect(Dimension::resolve_or_intrinsic(MinContent, 100.0, 5.0), content="5")
  inspect(
    Dimension::resolve_or_intrinsic(FitContent(50.0), 100.0, 5.0),
    content="5",
  )
}

///|
test "Dimension - Show variants" {
  inspect(Dimension::Length(8.0), content="Length(8)")
  inspect(Dimension::Percent(0.5), content="Percent(0.5)")
  inspect(Dimension::Auto, content="Auto")
  inspect(Dimension::MinContent, content="MinContent")
  inspect(Dimension::MaxContent, content="MaxContent")
  inspect(Dimension::FitContent(10.0), content="FitContent(10)")
}

///|
test "resolve_rect resolves all sides with parent width" {
  let rect : Rect[Dimension] = {
    left: Length(10.0),
    right: Percent(0.25),
    top: Auto,
    bottom: MinContent,
  }
  let resolved = resolve_rect(rect, 200.0)
  inspect(resolved.left, content="10")
  inspect(resolved.right, content="50")
  inspect(resolved.top, content="0")
  inspect(resolved.bottom, content="0")
}

///|
test "resolve_rect_intrinsic uses 0 fallback" {
  let rect : Rect[Dimension] = {
    left: Length(10.0),
    right: Percent(0.5),
    top: Auto,
    bottom: FitContent(40.0),
  }
  let resolved = resolve_rect_intrinsic(rect)
  inspect(resolved.left, content="10")
  inspect(resolved.right, content="0")
  inspect(resolved.top, content="0")
  inspect(resolved.bottom, content="0")
}

///|
test "BoundingRect::zero and Show" {
  let z = BoundingRect::zero()
  inspect(z.x, content="0")
  inspect(z.area(), content="0")
  let r = BoundingRect::new(1.0, 2.0, 3.0, 4.0)
  inspect(r, content="BoundingRect { x: 1, y: 2, width: 3, height: 4 }")
}

///|
test "clamp behavior" {
  inspect(clamp(5.0, 0.0, 10.0), content="5")
  inspect(clamp(-1.0, 0.0, 10.0), content="0")
  inspect(clamp(15.0, 0.0, 10.0), content="10")
  // min takes precedence when min > max
  inspect(clamp(5.0, 20.0, 10.0), content="20")
}

///|
test "apply_aspect_ratio" {
  debug_inspect(apply_aspect_ratio_width(100.0, Some(2.0)), content="Some(200)")
  debug_inspect(
    apply_aspect_ratio_height(200.0, Some(2.0)),
    content="Some(100)",
  )
  debug_inspect(apply_aspect_ratio_width(100.0, None), content="None")
  debug_inspect(apply_aspect_ratio_width(100.0, Some(0.0)), content="None")
  debug_inspect(apply_aspect_ratio_height(100.0, Some(-1.0)), content="None")
}

///|
test "resolve_dimensions_with_aspect_ratio - both known, aspect overrides height" {
  let (w, h) = resolve_dimensions_with_aspect_ratio(
    Some(200.0),
    Some(999.0),
    Some(2.0),
    0.0,
    1000.0,
    0.0,
    1000.0,
  )
  debug_inspect(w, content="Some(200)")
  debug_inspect(h, content="Some(100)")
}

///|
test "resolve_dimensions_with_aspect_ratio - width only" {
  let (w, h) = resolve_dimensions_with_aspect_ratio(
    Some(200.0),
    None,
    Some(2.0),
    0.0,
    1000.0,
    0.0,
    1000.0,
  )
  debug_inspect(w, content="Some(200)")
  debug_inspect(h, content="Some(100)")
}

///|
test "resolve_dimensions_with_aspect_ratio - height only with clamp" {
  let (w, h) = resolve_dimensions_with_aspect_ratio(
    None,
    Some(100.0),
    Some(4.0),
    0.0,
    300.0,
    0.0,
    1000.0,
  )
  debug_inspect(w, content="Some(300)") // 100 * 4 = 400, clamped to 300
  debug_inspect(h, content="Some(100)")
}

///|
test "resolve_dimensions_with_aspect_ratio - no aspect_ratio" {
  let (w, h) = resolve_dimensions_with_aspect_ratio(
    Some(100.0),
    Some(50.0),
    None,
    0.0,
    1000.0,
    0.0,
    1000.0,
  )
  debug_inspect(w, content="Some(100)")
  debug_inspect(h, content="Some(50)")
}

///|
test "resolve_dimensions_with_aspect_ratio - both unknown" {
  let (w, h) = resolve_dimensions_with_aspect_ratio(
    None,
    None,
    Some(2.0),
    0.0,
    1000.0,
    0.0,
    1000.0,
  )
  debug_inspect(w, content="None")
  debug_inspect(h, content="None")
}

///|
test "ClipRect default and Show" {
  let default = ClipRect::default()
  inspect(default, content="auto")
  let rect : ClipRect = Rect(top=1.0, right=2.0, bottom=3.0, left=4.0)
  inspect(rect, content="rect(1, 2, 3, 4)")
}

///|
test "BoundingRect::union" {
  let a = BoundingRect::new(0.0, 0.0, 50.0, 50.0)
  let b = BoundingRect::new(25.0, 25.0, 50.0, 50.0)
  let u = a.union(b)
  inspect(u.x, content="0")
  inspect(u.y, content="0")
  inspect(u.width, content="75")
  inspect(u.height, content="75")
}
