// ============================================================================
// Marker
// ============================================================================

///|
/// Marker definition (for line endpoints)
pub(all) struct Marker {
  id : String
  content : SVGNode
  ref_x : Double // Reference point x
  ref_y : Double // Reference point y
  marker_width : Double
  marker_height : Double
  orient : MarkerOrient
  marker_units : MarkerUnits
  view_box : ViewBox?
  preserve_aspect_ratio : PreserveAspectRatio
  clip_overflow : Bool
}

///|
pub(all) enum MarkerOrient {
  Auto // Orient along path direction
  AutoStartReverse // Reverse at start
  Angle(Double) // Fixed angle in degrees
}

///|
pub(all) enum MarkerUnits {
  StrokeWidth // Marker size relative to stroke width
  UserSpaceOnUse_ // Marker size in user space (renamed to avoid conflict)
}

///|
pub fn Marker::new(id : String, content : SVGNode) -> Marker {
  {
    id,
    content,
    ref_x: 0.0,
    ref_y: 0.0,
    marker_width: 3.0,
    marker_height: 3.0,
    orient: Angle(0.0),
    marker_units: StrokeWidth,
    view_box: None,
    preserve_aspect_ratio: PreserveAspectRatio::default(),
    clip_overflow: true,
  }
}

///|
/// Marker registry
priv struct MarkerRegistry {
  markers : Map[String, Marker]
}

///|
fn MarkerRegistry::new() -> MarkerRegistry {
  { markers: Map([]) }
}

///|
fn MarkerRegistry::add(self : MarkerRegistry, marker : Marker) -> Unit {
  self.markers.set(marker.id, marker)
}

///|
fn MarkerRegistry::get(self : MarkerRegistry, id : String) -> Marker? {
  self.markers.get(id)
}

///|
pub impl Show for Align with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for MeetOrSlice with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for LineCap with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for LineJoin with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for FillRule with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for MaskType with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for PaintOrderItem with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}
