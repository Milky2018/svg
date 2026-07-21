---
status: accepted
---

# Use coverage and bounded regions for effects

Clip paths produce 16-bit Coverage from their complete geometry subtree, same-document use references, transforms, units, nested clipping, and clip rules. Paint and image effects do not contribute to clip geometry. Nested clips multiply Coverage instead of applying binary point containment. Masks render their complete subtree into an isolated region and convert it to alpha or luminance Coverage according to mask type, with transparent content outside the mask region.

Isolated groups and filter intermediates use tight device-space surface regions carrying an explicit origin instead of full-canvas images. Filter primitives propagate their primitive subregions, expansion, transparent-black input, and edge behavior within the Filter Region. Every filter primitive already recognized by the parser and every existing blend mode must be semantically correct on the new premultiplied, color-space-aware surfaces; adding unparsed Filter Effects features is outside this refactor.

A per-render bounded surface pool reuses filter intermediates after their final graph consumer, with deterministic clearing before reuse. Isolation is created whenever required by filters, masks, group opacity, non-normal blending, or explicit isolation, while direct rendering remains available when it is semantically equivalent.
