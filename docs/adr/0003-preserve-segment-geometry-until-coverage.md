---
status: accepted
---

# Preserve segment geometry until coverage

All basic shapes and path data are represented as a common Segment Path, preserving curve and arc segments through path-length measurement, dash cutting, marker placement, and Stroke Shape construction. Ordinary strokes are constructed in user space and then transformed by the complete affine transform; non-scaling strokes use their specified device-space stroke semantics. Zero-length and degenerate segments retain their SVG-defined cap, marker, and tangent behavior.

Only completed fill and Stroke Shapes are adaptively approximated for rasterization, using a maximum device-space error of one eighth of a pixel with bounded numerical safeguards. A deterministic 16.16 fixed-point cell-accumulation rasterizer computes nonzero or even-odd pixel Coverage. Public flatness control and shape-specific rasterizers are removed so every shape uses the same quality rule and coverage implementation.
