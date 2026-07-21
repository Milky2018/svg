---
status: accepted
---

# Replace the renderer through green staged commits

The software renderer is replaced through independently verifiable commits in this order: baselines and architecture records; surfaces, color, and compositing; segment geometry, coverage, and primitive canonicalization; strokes, dashes, and markers; gradients, patterns, and images; clips, masks, filters, and blending; then facade migration, diagnostics, cleanup, CI, and benchmarks. New and old private source may coexist temporarily to keep every commit buildable, but there is no public or runtime renderer switch, and the old rasterizer is deleted at cutover.

Parser and CSS changes are limited to values required by the renderer. Existing text support is retained through path conversion or a minimal fallback adapter; font shaping and rasterization are not redesigned. Scene and animation data remain, while context-driven dirty-region rendering may change and incremental rendering is outside this work. Completion includes verified commits only: it does not include a version bump, publication, or push.
