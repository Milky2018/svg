///|
test "public length resolver preserves property-specific percentages" {
  let ctx : ComputeContext = {
    ..ComputeContext::with_viewport(800.0, 600.0),
    root_font_size: 20.0,
    font_size: 10.0,
  }
  match resolve_length_dimension("calc(50% - 2em + 1rem)", ctx) {
    Some(dimension) => assert_eq(dimension.resolve(200.0), Some(100.0))
    None => fail("expected a resolved length expression")
  }
}

///|
test "public length resolver covers viewport and fallback font units" {
  let ctx : ComputeContext = {
    ..ComputeContext::with_viewport(800.0, 600.0),
    root_font_size: 20.0,
    font_size: 10.0,
  }
  assert_eq(
    resolve_length_dimension("10vw", ctx).unwrap().resolve(0.0),
    Some(80.0),
  )
  assert_eq(
    resolve_length_dimension("10vh", ctx).unwrap().resolve(0.0),
    Some(60.0),
  )
  assert_eq(
    resolve_length_dimension("2rem", ctx).unwrap().resolve(0.0),
    Some(40.0),
  )
  assert_eq(
    resolve_length_dimension("2ex", ctx).unwrap().resolve(0.0),
    Some(10.0),
  )
  assert_eq(
    resolve_length_dimension("2ch", ctx).unwrap().resolve(0.0),
    Some(10.0),
  )
}

///|
test "public length resolver rejects unknown units and intrinsic keywords" {
  let ctx = ComputeContext::new()
  assert_true(resolve_length_dimension("10furlong", ctx) is None)
  assert_true(resolve_length_dimension("calc(10px * 2px)", ctx) is None)
  assert_true(resolve_length_dimension("calc(10px / 0)", ctx) is None)
  assert_true(resolve_length_dimension("auto", ctx) is None)
  assert_true(resolve_length_dimension("min-content", ctx) is None)
}
