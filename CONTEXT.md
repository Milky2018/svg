# SVG Rendering

This context describes the visual interpretation of a parsed SVG scene into a raster image. It distinguishes geometric occupancy, color sources, and isolated effects so that rendering stages use the same language.

## Language

**Coverage**:
The fraction of an output pixel occupied by painted geometry after geometric clipping.
_Avoid_: Hit, inside flag, binary mask

**Paint**:
The color-producing value applied to the fill or stroke shape of a graphical element.
_Avoid_: Color, brush

**Paint Server**:
A reusable SVG resource, such as a gradient or pattern, that produces paint from a position in its coordinate system.
_Avoid_: Texture, shader

**Pattern Tile**:
The rectangular region established by a pattern's position and size that repeats to produce Paint.
_Avoid_: Texture, sprite, pattern image

**Segment Path**:
A geometric contour that preserves its authored line, quadratic, cubic, and elliptical-arc segments until an operation explicitly requires an approximation.
_Avoid_: Polyline, flattened path

**Stroke Shape**:
The fillable geometry produced by applying stroke width, dashing, caps, joins, and vector effects to a Segment Path.
_Avoid_: Thick line, stroked pixels

**Marker Instance**:
A rendering of a marker's SVG subtree positioned and oriented at one applicable vertex of a Segment Path.
_Avoid_: Arrowhead, marker pixels

**Source Graphic**:
The rendered content of an element or group before its filter, clip, mask, group opacity, and backdrop compositing are applied.
_Avoid_: Raw image, original pixels

**Isolated Group**:
A group rendered against a transparent initial backdrop and composited with the surrounding backdrop only after the group's effects are complete.
_Avoid_: Temporary image, layer

**Filter Region**:
The SVG-defined region in which a filter graph may produce visible output, including areas outside the Source Graphic bounds.
_Avoid_: Source bounds, element box

**Render Diagnostic**:
A structured explanation of content that could not be rendered as authored without invalidating the rest of the rendered image.
_Avoid_: Render error, warning string

**Render Result**:
The optional output image and ordered Render Diagnostics produced by one requested SVG rendering.
_Avoid_: Image, response
