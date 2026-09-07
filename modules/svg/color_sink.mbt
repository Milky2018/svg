///|
/// Internal color sink used by coverage, paint, and compositing stages.
priv struct ColorSink {
  set : (Int, Int, Color) -> Unit
}

///|
fn ColorSink::pixel(self : ColorSink, x : Int, y : Int, color : Color) -> Unit {
  (self.set)(x, y, color)
}

///|
fn ColorSink::with_clip(self : ColorSink, clip : ClipRect) -> ColorSink {
  let inner_set = self.set
  { set: (x, y, color) => if clip.contains(x, y) { inner_set(x, y, color) }, }
}
