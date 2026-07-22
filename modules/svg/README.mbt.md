# Milky2018/svg

A standalone SVG parser and deterministic CPU renderer for MoonBit. It renders
SVG markup or an `SVGDocument` into an owned RGBA `Image`.

## Install

```sh
moon add Milky2018/svg
```

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
  assert_eq(result.diagnostics[0].kind, RenderDiagnosticKind::ParseFailed)
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

## Main API

- Parsing: `parse_svg_document`, `parse_path`, `parse_transform`
- Rendering: `render_svg`, `render_svg_document`, `render_svg_to_image`
- Results: `RenderResult`, `RenderDiagnostic`, `RenderOptions`
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
and basic text `font-size`.

This is a static-document model, not a browser DOM. External stylesheets,
scripting, dynamic restyling, interaction-dependent pseudo-classes, cascade
layers, and browser-driven animations are intentionally excluded.

## Rendering Contract

The implementation aims for internally consistent SVG semantics and stable
software output. It does not guarantee pixel-for-pixel parity with Chromium,
Skia, or platform text engines. Nested SVG text layout and external SVG resource
documents remain outside the supported core.

## License and Attribution

Milky2018/svg is distributed under Apache-2.0 and depends on the separately
published Milky2018/css module. See `NOTICE` for the CSS dependency's source
origin and attribution.
