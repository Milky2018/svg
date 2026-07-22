# Renderer Baseline for 0.3.0

This baseline records the renderer before the staged replacement described by ADR-0001 through ADR-0008.

## Environment

- Commit: `afcb2d2b03426b4e4f7e5eaced2dbdf7011de865`
- Moon: `0.1.20260717`
- Moon compiler: `v0.10.4+483324529-nightly`
- Host: macOS 26.5.1, Darwin 25.5.0, arm64

## Correctness Gates

`moon check --target all --deny-warn` passed.

`moon test --target all` passed 367 tests on each of wasm, wasm-gc, JavaScript, and native.

`moon fmt --check` required the current toolchain's mechanical migration from the deprecated `moon.mod.json` manifest to `moon.mod`. The baseline stage applies that metadata-preserving migration before later formatter gates.

`moon check --target all --deny-warn --warn-list +73` exposed 155 pre-existing unnecessary-annotation diagnostics in parser, scene, types, CSS adaptation, and tests. Warning 73 was not enabled by the repository CI at this baseline and these diagnostics are not regressions from the renderer replacement.

Existing focused tests establish the pre-cutover numeric behavior:

- `tiny rect translations are quantized symmetrically`
- `tiny path translations are quantized symmetrically`
- `tiny scene path translations are quantized symmetrically`
- `container pipeline applies filter then mask then opacity`
- the ISS-014 opacity tests, which require half alpha to round to 128

## Native Release Benchmarks

Command:

```sh
moon bench --target native --release modules/svg/svg_bench.mbt --no-parallelize
```

The table records mean time from ten benchmark samples. It is a comparison baseline rather than a portable performance claim.

| Benchmark | Mean |
| --- | ---: |
| simple rect 100x100 | 198.31 us |
| 10 rects 200x200 | 238.53 us |
| circle 100x100 | 285.83 us |
| Bezier path 100x100 | 88.49 us |
| star path 200x200 | 374.32 us |
| linear gradient 100x100 | 654.14 us |
| radial gradient 100x100 | 364.87 us |
| clipPath 100x100 | 520.83 us |
| mask 100x100 | 1.02 ms |
| rotated transform 100x100 | 84.96 us |
| nested groups 100x100 | 89.38 us |
| use elements 200x200 | 207.59 us |
| simple rect 500x500 | 4.47 ms |
| thick stroke 100x100 | 125.91 us |
| polygon 100x100 | 122.03 us |
| parse-only complex SVG | 59.75 us |
| full pipeline 200x200 | 3.90 ms |

## Accepted Performance Envelope

The completed common geometry suite should remain within approximately twice these median timings on a back-to-back run on the same host and toolchain. Parser-only time is recorded to separate renderer cost from parsing cost. Any larger regression requires a measured explanation in ISS-035 rather than an unreviewed expectation update.
