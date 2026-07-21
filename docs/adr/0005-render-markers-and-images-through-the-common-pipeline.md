---
status: accepted
---

# Render markers and images through the common pipeline

Every Marker Instance is a positioned ordinary SVG subtree. Placement implements SVG start, mid, and end vertices, including zero-length segments, curve tangents, orient modes, marker units, reference points, view boxes, aspect-ratio handling, overflow, and computed paint order. Marker content therefore reuses the common paint, resource, effect, and compositing pipeline rather than a marker-specific raster implementation.

Raster images use the transformed image viewport's geometric Coverage and are sampled in premultiplied working-space colors. Pixelated and crisp-edges rendering uses nearest-neighbor sampling, auto and smooth use bilinear sampling, and high-quality uses Mitchell-Netravali bicubic sampling. Viewport placement, aspect-ratio modes, transforms, opacity, clipping, masking, filtering, and blending all use the common scene pipeline.

Image resolvers remain responsible for decoding external references into straight RGBA8 sRGB pixels; this library neither decodes nor encodes PNG or JPEG. Missing resources render no image content and produce a Render Diagnostic through a new detailed rendering result, while existing high-level image-returning functions remain available. Resource recursion is limited to 32 nested references per render, with cycles diagnosed and skipped.
