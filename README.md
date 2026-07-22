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

## Scope

The renderer targets coherent SVG and CSS semantics with deterministic software
output. It does not promise pixel-for-pixel Chromium parity. Network and file
access, external SVG documents, and PNG/JPEG decoding are host responsibilities;
raster images can be supplied through `RenderOptions::with_image_resolver`.

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
