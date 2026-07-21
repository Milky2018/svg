---
status: accepted
---

# Prepare and sample paint servers in their coordinate spaces

Linear and radial gradients are prepared with their complete coordinate mapping, spread method, stop inheritance, and radial two-circle geometry. Stops are evaluated directly in the computed interpolation color space with premultiplied alpha; lossy lookup tables are not part of the correctness implementation. Paint is evaluated at pixel centers and multiplied by geometric Coverage.

Patterns resolve their units, content units, view box, aspect ratio, transform, and same-document reference chain before rendering one Pattern Tile through the full scene renderer. Tile resolution conservatively follows the complete affine mapping, including rotation and skew, with fixed cross-target limits of 4096 texels per axis and 16 million texels total; oversized tiles are proportionally reduced. Sampling is wrap-aware bilinear unless image-rendering requires nearest-neighbor behavior, and bounded caching lasts only for one render. Recursive references are rejected. External gradient and pattern resources are not fetched and instead use the SVG paint fallback behavior.
