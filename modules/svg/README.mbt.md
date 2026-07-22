# Milky2018/svg

Standalone SVG scene graph, parser, and deterministic CPU renderer for MoonBit.
It renders SVG markup or an external SVGNode tree into an Image.

## Install

```sh
moon add Milky2018/svg
```

## Quick Start (SVG string -> Image)

```mbt nocheck
let svg = "<svg width=\"10\" height=\"10\"><rect x=\"1\" y=\"1\" width=\"8\" height=\"8\" fill=\"red\"/></svg>"
match render_svg_to_image(svg, 16, 16) {
  Some(image) => image
  None => panic("parse failed")
}
```

## DOM Integration (external tree -> Image)

Build an SVGNode tree from your DOM, then render:

```mbt nocheck
let node = rect("r", 2.0, 2.0, 6.0, 6.0)
node.fill = SolidColor(Color::black())
let doc = SVGDocument::new(node)
let image = render_svg_document_to_image(doc, 16, 16)
```

If you already have a scene graph:

```mbt nocheck
///|
let scene = Scene::new(node)

///|
let image = render_svg_scene_to_image(scene, 16, 16)
```

## Structured Rendering

Use `render_svg` when the host needs typed diagnostics and an image resolver:

```mbt nocheck
///|
let result = render_svg(
  svg,
  64,
  64,
  RenderOptions::with_image_resolver(fn(href) { host_decode_image(href) }),
)

///|
let image = result.image

///|
let diagnostics = result.diagnostics
```

The renderer owns its pixel target and returns an `Image`. The former
`PixelSetter`, `RenderContext`, context-driven scene methods, and public
`raster_*` functions were low-level implementation APIs and are no longer
public. Use `render_path_commands_to_image` for direct path rendering.

## Main API

- Parsing: `parse_svg`, `parse_svg_document`
- Scene graph: `SVGNode`, `Scene`, `SVGDocument`
- Rendering: `render_svg`, `RenderResult`, `RenderOptions`, `render_svg_*_to_image`
- Geometry: `PathCommand`, `Transform`, `ViewBox`, `BoundingBox`
- Direct paths: `render_path_commands_to_image`
