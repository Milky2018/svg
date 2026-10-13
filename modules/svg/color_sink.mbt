///|
/// Internal color sink used by coverage, paint, and compositing stages.
priv struct ColorSink {
  set : (Int32, Int32, Color) -> Unit
}

///|
fn ColorSink::pixel(
  self : ColorSink,
  x : Int32,
  y : Int32,
  color : Color,
) -> Unit {
  (self.set)(x, y, color)
}

///|
fn ColorSink::with_clip(self : ColorSink, clip : ClipRect) -> ColorSink {
  let inner_set = self.set
  { set: (x, y, color) => if clip.contains(x, y) { inner_set(x, y, color) }, }
}
