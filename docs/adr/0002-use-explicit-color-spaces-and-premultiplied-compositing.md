---
status: accepted
---

# Use explicit color spaces and premultiplied compositing

Internal raster surfaces use 16-bit premultiplied channels and explicitly identify either the sRGB or linearRGB working color space. Ordinary SVG color interpolation follows its computed color-interpolation space, while filter operations follow color-interpolation-filters; conversions occur at those semantic boundaries instead of forcing the entire renderer into one space.

The high-level renderer continues to return straight RGBA8 sRGB images, and image resolvers continue to provide straight RGBA8 sRGB pixels. An isolated element or group is processed as Source Graphic, then filter, clip, mask, opacity, blend, and backdrop composite. Alpha, coverage, compositing, and final channel conversion use deterministic round-to-nearest with positive midpoint values rounded upward. Both alpha and luminance masks are part of the required implementation.
