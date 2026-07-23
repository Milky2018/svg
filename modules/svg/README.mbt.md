# Milky2018/svg

A standalone SVG parser and deterministic CPU renderer for MoonBit. It renders
SVG markup or an `SVGDocument` into an owned RGBA `Image`.

## Install

```sh
moon add Milky2018/svg
```

## Migrating from 0.3.x

Version 0.4.0 removes the combinatorial document, node, scene, and resolver
rendering functions. Rendering now goes through an owned `Image` facade, and
image resolution is configured with `RenderOptions`.

| 0.3.x API | 0.4.0 replacement | Notes |
| --- | --- | --- |
| `parse_svg(source)` | `parse_svg_document(source).map(fn(document) { document.root() })` | Use the document result when resources are needed. |
| `parse_svg_document(source)` | Unchanged | Returns `SVGDocument?`. |
| `render_svg(source, width, height, options)` | Unchanged | Returns `RenderResult` with an owned image and diagnostics. |
| `render_svg_to_image(source, width, height)` | Unchanged | Remains the simple `Image?` convenience. |
| `render_svg_to_image_with_resolver(...)` | `render_svg(source, width, height, RenderOptions::with_image_resolver(resolver))` | Read `.image` and inspect `.diagnostics`; parse failure is reported diagnostically. |
| `render_svg_document_to_image(...)` | `render_svg_document(document, width, height, RenderOptions::default()).image` | Use the structured result when diagnostics matter. |
| `render_svg_document_to_image_with_resolver(...)` | `render_svg_document(document, width, height, RenderOptions::with_image_resolver(resolver)).image` | Resolver configuration is no longer a separate function family. |
| `render_svg_node_to_image*` | `render_svg_document(SVGDocument::new(node), width, height, options).image` | Register referenced resources on the document before rendering. |
| `render_svg_scene_to_image*` and `Scene` | No direct replacement | Migrate authored content to `SVGDocument` and `SVGNode`. |
| `PixelSetter`, `RenderContext`, context-driven `.render`, and public `raster_*` functions | No direct replacement | The renderer owns its target image; use the rendering facade. |
| `render_path_commands_to_image(...)` | Unchanged | Remains the expert direct-path entry point. |

## Parse and Render

```mbt check
///|
test "README: render SVG markup" {
  let source = "<svg width=\"10\" height=\"10\"><rect x=\"1\" y=\"1\" width=\"8\" height=\"8\" fill=\"red\"/></svg>"
  let image = render_svg_to_image(source, 16, 16)
  assert_true(image is Some(_))
}
```

Use the document API when the parsed resource tables or root node are needed:

```mbt check
///|
test "README: parse and render a document" {
  let source = "<svg width=\"4\" height=\"4\"><circle cx=\"2\" cy=\"2\" r=\"2\"/></svg>"
  match parse_svg_document(source) {
    Some(document) => {
      let result = render_svg_document(document, 4, 4, RenderOptions::default())
      assert_eq(result.image.width(), 4)
    }
    None => fail("expected a valid SVG document")
  }
}
```

## Structured Results

`render_svg` always returns an image and typed diagnostics. A malformed
document produces a transparent image plus a `ParseFailed` diagnostic instead
of requiring a separate error channel.

```mbt check
///|
test "README: inspect structured diagnostics" {
  let result = render_svg("<svg><broken></svg>", 8, 8, RenderOptions::default())
  assert_eq(result.image.width(), 8)
  assert_true(result.diagnostics.length() > 0)
  assert_eq(result.diagnostics[0].kind, ParseFailed)
}
```

## Host-Provided Raster Images

The renderer passes each `<image href>` string to the resolver. The host owns
file or network access, decoding, caching, and policy; return `None` when a
resource cannot be resolved.

```mbt check
///|
test "README: resolve a raster image" {
  let options = RenderOptions::with_image_resolver(fn(href) {
    if href == "asset.png" {
      Some(Image::filled(2, 2, Color::rgba(255, 0, 0, 128)))
    } else {
      None
    }
  })
  let result = render_svg(
    "<svg width=\"2\" height=\"2\"><image href=\"asset.png\" width=\"2\" height=\"2\"/></svg>",
    2, 2, options,
  )
  assert_eq(result.image.width(), 2)
  assert_eq(result.diagnostics.length(), 0)
}
```

Resolved images participate in `preserveAspectRatio`, affine transforms,
clipping, opacity, and compositing. External SVG resource documents are not
resolved by this callback.

## Static Render Environment and Text Resources

`RenderEnvironment` makes every non-document input to a snapshot explicit:
the document base URI, device pixel ratio, preferred color scheme, animation
sample time, and per-element interaction state. `text_resource_resolver`
supplies CSS or SVG text after URI resolution. The library never reads files
or performs network requests.

```mbt check
///|
test "README: render with host text resources and static state" {
  let options = RenderOptions::{
    ..RenderOptions::default(),
    environment: {
      ..RenderEnvironment::default(),
      base_uri: "mem:/document.svg",
      color_scheme: Dark,
      sample_time_seconds: 0.5,
      element_state_resolver: Some(fn(id) {
        if id == "target" {
          { ..ElementState::none(), hover: true }
        } else {
          ElementState::none()
        }
      }),
    },
    text_resource_resolver: Some(fn(uri, kind) {
      match (uri, kind) {
        ("mem:/theme.css", Stylesheet) => Some("#target:hover { fill: red; }")
        _ => None
      }
    }),
  }
  let source = "<?xml-stylesheet href=\"theme.css\"?><svg width=\"2\" height=\"2\"><rect id=\"target\" width=\"2\" height=\"2\"/></svg>"
  let result = render_svg(source, 2, 2, options)
  assert_eq(result.diagnostics.length(), 0)
}
```

External CSS supports `xml-stylesheet` processing instructions and recursive
`@import`. External SVG fragments used by `<use>`, paint servers, clip paths,
masks, filters, patterns, and markers share the same bounded, cached resolver.
Relative references use the containing document or stylesheet URI. Missing,
cyclic, oversized, over-deep, or over-count resources fail closed and produce
typed diagnostics. Defaults allow 16 nested resources, 64 distinct resources,
and 16 MiB of resolved text; callers may lower these limits in `RenderOptions`.

The explicit sample time evaluates CSS keyframes without a clock. The initial
interpolation set covers geometry lengths, affine transforms, colors, opacity,
and paint opacity; other properties are discrete. Paused animations have a
deterministic hold time of zero because a static document has no prior running
timeline. SMIL, scripting, DOM mutation, event dispatch, and live restyling are
outside this API.

## Main API

- Parsing: `parse_svg_document`, `parse_path`, `parse_transform`
- Rendering: `render_svg`, `render_svg_document`, `render_svg_to_image`
- Results: `RenderResult`, `RenderDiagnostic`, `RenderOptions`,
  `RenderEnvironment`
- Data: `SVGDocument`, `SVGNode`, `Shape`, `Image`, `Color`
- Direct paths: `render_path_commands_to_image`

The renderer owns its pixel target. Former low-level context and raster
functions are implementation details and are not public APIs.

## Static CSS Support

Presentation attributes, embedded `<style>` rules, and inline declarations use
the shared `Milky2018/css` cascade. Supported behavior includes selector
specificity and source order, `!important`, inheritance, CSS-wide keywords,
inherited custom properties and nested `var()` fallbacks, `currentColor`,
and CSS Color 3 named, RGB/RGBA, HSL/HSLA, and hex colors.

The same computed path covers SVG paint and stroke properties, markers, paint
order, fill and clip rules, geometry properties, transforms, gradient stops,
and basic text `font-size`. Length expressions retain their unit and percentage
semantics until an SVG axis, nested viewport, font context, and outer CSS
viewport are available.

This is a static-document model, not a browser DOM. Host-provided external
stylesheets, forced interaction pseudo-classes, media inputs, and sampled CSS
keyframes are supported as immutable snapshot inputs. Scripting, dynamic
restyling, cascade layers, SMIL, event dispatch, and a browser animation clock
are intentionally excluded.

## Rendering Contract

The implementation aims for internally consistent SVG semantics and stable
software output. It does not guarantee pixel-for-pixel parity with Chromium,
Skia, or platform text engines. Nested SVG text layout remains outside the
supported core.

## License and Attribution

Milky2018/svg is distributed under Apache-2.0 and depends on the separately
published Milky2018/css module. See `NOTICE` for the CSS dependency's source
origin and attribution.
