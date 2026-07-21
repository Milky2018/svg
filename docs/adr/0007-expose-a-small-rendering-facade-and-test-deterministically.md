---
status: accepted
---

# Expose a small rendering facade and test deterministically

The new renderer is implemented as focused private files within the existing MoonBit package. Scene traversal depends on a small internal rendering interface; segment geometry, strokes, coverage, surfaces, paint, image sampling, compositing, and effects remain hidden implementations. The existing eight render_svg functions and render_path_commands_to_image remain source-compatible, while low-level PixelSetter, RenderContext, raster functions, and context-driven scene rendering may be removed or changed.

A new render_svg entry accepts Render Options and returns a Render Result. Diagnostics use stable kinds with rendering stage and relevant node or resource identity rather than requiring callers to parse messages. Existing image-returning functions delegate to this entry point.

Acceptance combines cross-target exact RGBA results, numeric geometry and alpha invariants, equivalent-SVG cases, and selected specification fixtures. Chromium comparisons produce non-blocking reports. Changed legacy expectations require a classified semantic explanation and a corresponding invariant. CI checks formatting, warnings, generated interfaces, and tests across every existing target. Representative pre-refactor benchmarks are retained, and the completed geometry renderer should remain within approximately twice the previous median runtime unless a measured exception is documented.
