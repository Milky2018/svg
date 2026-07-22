///|
/// CSS Property Metadata
/// Defines initial values and inheritance behavior for layout properties

///|
/// Whether a property is inherited by default
pub fn is_inherited(property : String) -> Bool {
  match property {
    // Text-related properties (inherited)
    "direction"
    | "writing-mode"
    | "text-align"
    | "line-height"
    | "white-space"
    | "font-size"
    | "font-family"
    | "font-weight"
    | "font-style"
    | "color"
    | "visibility" => true
    // Table properties that are inherited
    "caption-side" | "border-collapse" | "border-spacing" => true
    // Containment is not inherited
    "contain" => false
    "pointer-events" => true
    // All layout properties are not inherited
    _ => false
  }
}

///|
/// Get the initial value for a property as a string
pub fn initial_value(property : String) -> String {
  match property {
    // Display
    "display" => "block"
    "position" => "relative"
    "float" => "none"
    "clear" => "none"
    // Overflow
    "overflow" | "overflow-x" | "overflow-y" => "visible"
    "pointer-events" => "auto"
    "scroll-snap-type" => "none"
    "scroll-snap-align" => "none"
    // Sizing
    "width" | "height" | "min-width" | "min-height" => "auto"
    "max-width" | "max-height" => "none"
    // Box model
    "margin"
    | "margin-top"
    | "margin-right"
    | "margin-bottom"
    | "margin-left" => "0"
    "margin-trim" => "none"
    "padding"
    | "padding-top"
    | "padding-right"
    | "padding-bottom"
    | "padding-left" => "0"
    "border-width"
    | "border-top-width"
    | "border-right-width"
    | "border-bottom-width"
    | "border-left-width" => "0"
    // Flexbox container
    "flex-direction" => "row"
    "flex-wrap" => "nowrap"
    "justify-content" => "flex-start"
    "align-items" => "stretch"
    "align-content" => "stretch"
    // Flexbox item
    "align-self" => "auto"
    "flex-grow" => "0"
    "flex-shrink" => "1"
    "flex-basis" => "auto"
    // Gap (grid-gap is legacy alias)
    "gap"
    | "row-gap"
    | "column-gap"
    | "grid-gap"
    | "grid-row-gap"
    | "grid-column-gap" => "0"
    "columns" | "column-count" | "column-width" => "auto"
    "column-fill" => "balance"
    "break-before" | "break-after" | "break-inside" | "page-break-inside" =>
      "auto"
    "column-span" => "none"
    // Aspect ratio
    "aspect-ratio" => "auto"
    // Inset
    "top" | "right" | "bottom" | "left" | "inset" => "auto"
    // Grid container
    "grid-template-rows" | "grid-template-columns" => "none"
    "grid-auto-rows" | "grid-auto-columns" => "auto"
    "grid-auto-flow" => "row"
    // Grid item
    "grid-row-start"
    | "grid-row-end"
    | "grid-column-start"
    | "grid-column-end" => "auto"
    // Text (inherited)
    "direction" => "ltr"
    "writing-mode" => "horizontal-tb"
    "text-align" => "start"
    "font-weight" => "400"
    "white-space" => "normal"
    "text-overflow" => "clip"
    "text-decoration" | "text-decoration-line" => "none"
    "box-shadow" => "none"
    "opacity" => "1"
    // Containment
    "contain" => "none"
    "contain-intrinsic-size"
    | "contain-intrinsic-inline-size"
    | "contain-intrinsic-block-size" => "none"
    // Table properties
    "caption-side" => "top"
    "border-collapse" => "separate"
    "border-spacing" => "0"
    "table-layout" => "auto"
    // Default
    _ => "auto"
  }
}

///|
