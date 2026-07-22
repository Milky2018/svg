# Software Renderer Cutover

The renderer replacement described by ADR-0001 through ADR-0008 is complete.
All compatibility-sensitive `render_svg_*` functions and
`render_path_commands_to_image` now use the continuous geometry, analytic
coverage, and premultiplied compositing pipeline.

## Public contract

- `render_svg` returns an `Image` together with typed diagnostics.
- The existing image-returning document, scene, node, string, and resolver
  functions retain their signatures.
- `render_path_commands_to_image` retains its signature and now preserves
  fractional coverage instead of quantizing geometry before rasterization.
- PNG and JPEG decoding remains a host responsibility supplied through an
  image resolver.
- `PixelSetter`, `RenderContext`, context-driven scene rendering, and public
  `raster_*` functions were implementation-level APIs and have been removed.
- Font shaping and incremental rendering remain outside this cutover. Text
  uses the existing deterministic bitmap fallback.

## Correctness gates

The final tree passes formatting, generated-interface validation,
`moon check --target all --deny-warn`, and 399 tests on each of wasm, wasm-gc,
JavaScript, and native.

## Native release benchmark

Command:

```sh
moon bench --target native --release modules/svg/svg_bench.mbt --no-parallelize
```

The table compares ten-sample means with the pre-refactor baseline recorded in
`renderer-baseline-0.3.0.md` on the same host and toolchain.

| Benchmark | Baseline | Cutover | Ratio |
| --- | ---: | ---: | ---: |
| simple rect 100x100 | 198.31 us | 465.93 us | 2.35x |
| 10 rects 200x200 | 238.53 us | 378.68 us | 1.59x |
| circle 100x100 | 285.83 us | 460.44 us | 1.61x |
| Bezier path 100x100 | 88.49 us | 398.93 us | 4.51x |
| star path 200x200 | 374.32 us | 1.42 ms | 3.80x |
| linear gradient 100x100 | 654.14 us | 1.31 ms | 2.00x |
| radial gradient 100x100 | 364.87 us | 959.17 us | 2.63x |
| clipPath 100x100 | 520.83 us | 615.49 us | 1.18x |
| mask 100x100 | 1.02 ms | 1.53 ms | 1.50x |
| rotated transform 100x100 | 84.96 us | 254.19 us | 2.99x |
| nested groups 100x100 | 89.38 us | 194.96 us | 2.18x |
| use elements 200x200 | 207.59 us | 326.21 us | 1.57x |
| simple rect 500x500 | 4.47 ms | 12.05 ms | 2.70x |
| thick stroke 100x100 | 125.91 us | 414.39 us | 3.29x |
| polygon 100x100 | 122.03 us | 392.88 us | 3.22x |
| parse-only complex SVG | 59.75 us | 56.26 us | 0.94x |
| full pipeline 200x200 | 3.90 ms | 6.13 ms | 1.57x |

The representative full pipeline remains inside the accepted two-times
envelope, as do resource-heavy clip, mask, use, and multi-shape cases. Small
geometry microbenchmarks exceed it because they now pay for 16.16 edge setup,
analytic per-pixel area integration, adaptive curve flattening, and 16-bit
premultiplied conversion instead of integer scanline fills. This is an
intentional correctness cost: no integer fallback remains in those paths.
