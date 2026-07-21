///|
fn coverage_sum(mask : CoverageMask) -> Int64 {
  let mut result = 0L
  for value in mask.values {
    result = result + value.to_int64()
  }
  result
}

///|
test "coverage coordinates use symmetric 16.16 storage" {
  inspect(quantize_coverage_coordinate(1.25) == 81920L, content="true")
  inspect(
    quantize_coverage_coordinate(0.99999) +
    quantize_coverage_coordinate(1.00001) ==
    131072L,
    content="true",
  )
  inspect(
    quantize_coverage_coordinate(1.0 / 0.0) == 2305843009213693952L,
    content="true",
  )
  inspect(quantize_coverage_coordinate(0.0 / 0.0) == 0L, content="true")
}

///|
test "fractional rectangle produces analytic horizontal coverage" {
  let mask = build_coverage_mask(
    [[(1.25, 1.0), (2.25, 1.0), (2.25, 2.0), (1.25, 2.0)]],
    NonZero,
    4,
    4,
  )
  inspect(mask.get_device(1, 1), content="49151")
  inspect(mask.get_device(2, 1), content="16384")
  inspect(mask.get_device(0, 1), content="0")
}

///|
test "opposite tiny translations preserve equal area" {
  let rectangle = fn(x : Double) {
    build_coverage_mask(
      [[(x, 1.0), (x + 8.0, 1.0), (x + 8.0, 9.0), (x, 9.0)]],
      NonZero,
      12,
      12,
    )
  }
  let lower = rectangle(0.99999)
  let upper = rectangle(1.00001)
  inspect(coverage_sum(lower) == coverage_sum(upper), content="true")
  inspect(lower.get_device(0, 4) == upper.get_device(9, 4), content="true")
  inspect(lower.get_device(8, 4) == upper.get_device(1, 4), content="true")
}

///|
test "nonzero and evenodd distinguish nested contour direction" {
  let contours = [
    [(0.0, 0.0), (4.0, 0.0), (4.0, 4.0), (0.0, 4.0)],
    [(1.0, 1.0), (3.0, 1.0), (3.0, 3.0), (1.0, 3.0)],
  ]
  let nonzero = build_coverage_mask(contours, NonZero, 4, 4)
  let evenodd = build_coverage_mask(contours, EvenOdd, 4, 4)
  inspect(nonzero.get_device(2, 2), content="65535")
  inspect(evenodd.get_device(2, 2), content="0")
}

///|
test "reversed nested contour creates nonzero hole" {
  let contours = [
    [(0.0, 0.0), (4.0, 0.0), (4.0, 4.0), (0.0, 4.0)],
    [(1.0, 1.0), (1.0, 3.0), (3.0, 3.0), (3.0, 1.0)],
  ]
  let nonzero = build_coverage_mask(contours, NonZero, 4, 4)
  inspect(nonzero.get_device(2, 2), content="0")
}

///|
test "skewed polygon preserves its analytic area" {
  let mask = build_coverage_mask(
    [[(1.0, 1.0), (5.0, 1.0), (7.0, 5.0), (3.0, 5.0)]],
    NonZero,
    10,
    8,
  )
  let expected = 16L * 65535L
  let error = (coverage_sum(mask) - expected).abs()
  inspect(error <= 4L, content="true")
}

///|
test "axis-aligned stroke outline covers its boundary pixel" {
  let mask = build_coverage_mask(
    [[(7.0, 23.0), (7.0, 17.0), (33.0, 17.0), (33.0, 23.0)]],
    NonZero,
    40,
    40,
  )
  inspect(mask.get_device(7, 20), content="65535")
  inspect(mask.get_device(32, 20), content="65535")
  inspect(mask.get_device(33, 20), content="0")
}
