///|
test "viewBox transform identity" {
  // viewBox matches viewport - should be identity
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 100.0, }
  let t = vb.get_transform(100.0, 100.0, PreserveAspectRatio::default())
  // Should be identity (scale=1, no translation)
  inspect(t.a, content="1")
  inspect(t.d, content="1")
  inspect(t.e, content="0")
  inspect(t.f, content="0")
}

///|
test "viewBox transform scale 2x" {
  // viewBox is half the viewport size - should scale 2x
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 50.0, height: 50.0, }
  let t = vb.get_transform(100.0, 100.0, PreserveAspectRatio::default())
  // Should scale by 2
  inspect(t.a, content="2")
  inspect(t.d, content="2")
}

///|
test "viewBox with offset" {
  // viewBox starts at (10, 20)
  let vb = ViewBox::{ min_x: 10.0, min_y: 20.0, width: 100.0, height: 100.0, }
  let t = vb.get_transform(100.0, 100.0, PreserveAspectRatio::default())
  // Should translate by (-10, -20) scaled
  inspect(t.e, content="-10")
  inspect(t.f, content="-20")
}

///|
test "viewBox preserveAspectRatio none" {
  // Non-uniform scaling
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 50.0, }
  let par = PreserveAspectRatio::{ align: None, meet_or_slice: Meet, }
  let t = vb.get_transform(200.0, 200.0, par)
  // Should stretch: x by 2, y by 4
  inspect(t.a, content="2")
  inspect(t.d, content="4")
}

///|
test "viewBox preserveAspectRatio meet" {
  // Uniform scaling, fit entirely (use smaller scale)
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 50.0, }
  let par = PreserveAspectRatio::{ align: XMidYMid, meet_or_slice: Meet, }
  let t = vb.get_transform(200.0, 200.0, par)
  // x scale would be 2, y scale would be 4, use min = 2
  inspect(t.a, content="2")
  inspect(t.d, content="2")
  // Centered: extra y space = 200 - 50*2 = 100, translate by 50
  inspect(t.f, content="50")
}

///|
test "viewBox preserveAspectRatio slice" {
  // Uniform scaling, cover entirely (use larger scale)
  let vb = ViewBox::{ min_x: 0.0, min_y: 0.0, width: 100.0, height: 50.0, }
  let par = PreserveAspectRatio::{ align: XMidYMid, meet_or_slice: Slice, }
  let t = vb.get_transform(200.0, 200.0, par)
  // x scale would be 2, y scale would be 4, use max = 4
  inspect(t.a, content="4")
  inspect(t.d, content="4")
}
