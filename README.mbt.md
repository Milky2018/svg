# Milky2018/svg

Standalone SVG scene graph, parser, and CPU rasterizer for MoonBit.
It can render SVG markup or an external SVGNode tree into an Image or any custom
pixel target.

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
let scene = Scene::new(node)
let image = render_svg_scene_to_image(scene, 16, 16)
```

## Custom Rendering Target

You can render into any target by providing a PixelSetter and RenderContext.

```mbt nocheck
let image = Image::new(64, 64)
let setter : PixelSetter = { set: fn(x, y, c) { image.set_pixel(x, y, c) } }
let ctx = RenderContext::new(setter, 64, 64)
let doc = SVGDocument::new(rect("r", 0.0, 0.0, 10.0, 10.0))
doc.render(ctx)
```

## Main API

- Parsing: `parse_svg`, `parse_svg_document`
- Scene graph: `SVGNode`, `Scene`, `SVGDocument`
- Rendering: `RenderContext`, `PixelSetter`, `render_svg_*_to_image`
- Geometry: `PathCommand`, `Transform`, `ViewBox`, `BoundingBox`
- Raster: `raster_*` (low-level drawing primitives)
