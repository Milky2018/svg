///|
priv enum ComputedStyleProperty {
  StyleFill
  StyleFillRule
  StyleFillOpacity
  StyleStroke
  StyleStrokeWidth
  StyleStrokeLinecap
  StyleStrokeLinejoin
  StyleStrokeMiterlimit
  StyleStrokeDasharray
  StyleStrokeDashoffset
  StyleStrokeOpacity
  StyleVectorEffect
  StyleImageRendering
  StyleColor
  StylePaintOrder
  StyleOpacity
  StyleMarkerStart
  StyleMarkerMid
  StyleMarkerEnd
  StyleStopColor
  StyleStopOpacity
  StyleFontSize
}

///|
fn computed_style_property(name : String) -> ComputedStyleProperty? {
  match name {
    "fill" => Some(StyleFill)
    "fill-rule" => Some(StyleFillRule)
    "fill-opacity" => Some(StyleFillOpacity)
    "stroke" => Some(StyleStroke)
    "stroke-width" => Some(StyleStrokeWidth)
    "stroke-linecap" => Some(StyleStrokeLinecap)
    "stroke-linejoin" => Some(StyleStrokeLinejoin)
    "stroke-miterlimit" => Some(StyleStrokeMiterlimit)
    "stroke-dasharray" => Some(StyleStrokeDasharray)
    "stroke-dashoffset" => Some(StyleStrokeDashoffset)
    "stroke-opacity" => Some(StyleStrokeOpacity)
    "vector-effect" => Some(StyleVectorEffect)
    "image-rendering" => Some(StyleImageRendering)
    "color" => Some(StyleColor)
    "paint-order" => Some(StylePaintOrder)
    "opacity" => Some(StyleOpacity)
    "marker-start" => Some(StyleMarkerStart)
    "marker-mid" => Some(StyleMarkerMid)
    "marker-end" => Some(StyleMarkerEnd)
    "stop-color" => Some(StyleStopColor)
    "stop-opacity" => Some(StyleStopOpacity)
    "font-size" => Some(StyleFontSize)
    _ => None
  }
}

///|
fn ComputedStyleProperty::name(self : ComputedStyleProperty) -> String {
  match self {
    StyleFill => "fill"
    StyleFillRule => "fill-rule"
    StyleFillOpacity => "fill-opacity"
    StyleStroke => "stroke"
    StyleStrokeWidth => "stroke-width"
    StyleStrokeLinecap => "stroke-linecap"
    StyleStrokeLinejoin => "stroke-linejoin"
    StyleStrokeMiterlimit => "stroke-miterlimit"
    StyleStrokeDasharray => "stroke-dasharray"
    StyleStrokeDashoffset => "stroke-dashoffset"
    StyleStrokeOpacity => "stroke-opacity"
    StyleVectorEffect => "vector-effect"
    StyleImageRendering => "image-rendering"
    StyleColor => "color"
    StylePaintOrder => "paint-order"
    StyleOpacity => "opacity"
    StyleMarkerStart => "marker-start"
    StyleMarkerMid => "marker-mid"
    StyleMarkerEnd => "marker-end"
    StyleStopColor => "stop-color"
    StyleStopOpacity => "stop-opacity"
    StyleFontSize => "font-size"
  }
}

///|
fn ComputedStyleProperty::is_inherited(self : ComputedStyleProperty) -> Bool {
  match self {
    StyleOpacity | StyleVectorEffect => false
    _ => true
  }
}

///|
fn is_computed_style_property(name : String) -> Bool {
  computed_style_property(name) is Some(_)
}
