# Milky2018/svg

A MoonBit workspace for parsing and rendering static SVG documents with a
deterministic CPU renderer.

## Workspace

| Directory | Published module | Responsibility |
| --- | --- | --- |
| `modules/svg` | `Milky2018/svg` | SVG parsing, scene data, rendering, effects, and host image resolution |
| `modules/css` | `Milky2018/css` | Static CSS parsing, selectors, cascade, computed values, colors, and custom properties |

Start with the [SVG module guide](modules/svg/README.mbt.md). The
[CSS module guide](modules/css/README.md) documents the reusable static CSS
boundary and intentional exclusions.

Users upgrading from SVG 0.3.x should follow the
[0.4.0 API migration table](modules/svg/README.mbt.md#migrating-from-03x) and
the corresponding [changelog entry](CHANGELOG.md#milky2018svg-040---unreleased).

## Scope

The renderer targets coherent SVG and CSS semantics with deterministic software
output. It does not promise pixel-for-pixel Chromium parity. Network and file
access and PNG/JPEG decoding are host responsibilities. Raster images can be
supplied through `RenderOptions::with_image_resolver`; external CSS and SVG
text can be supplied through `text_resource_resolver` with an explicit
`RenderEnvironment`.

## Development

Run the repository gate from the workspace root:

```sh
moon fmt --check
moon info
moon check --target all --deny-warn
moon test --target all
```

## License and Attribution

The workspace is distributed under Apache-2.0. The locally maintained CSS module
began from `mizchi/css` 0.7.3; see [NOTICE](NOTICE) and
[modules/css/NOTICE](modules/css/NOTICE) for attribution.
