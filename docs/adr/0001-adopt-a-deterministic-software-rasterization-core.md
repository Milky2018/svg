---
status: accepted
---

# Adopt a deterministic software rasterization core

The renderer will be rebuilt around continuous `Double` geometry, deterministic 16.16 fixed-point edge processing with `Int64` intermediates, 16-bit coverage, and 16-bit premultiplied compositing surfaces. SVG and CSS specifications are the correctness authority; Chromium output remains differential evidence rather than a pixel-exact acceptance requirement. The implementation must remain portable across all existing MoonBit targets without native dependencies and will replace the current renderer through independently testable stages instead of keeping two long-lived rendering paths.

Only the high-level `render_svg_*` facade is compatibility-sensitive. Low-level rendering types such as `PixelSetter` and `RenderContext` may be changed or removed so the new rasterization seam is not constrained by the published 0.3 implementation.
