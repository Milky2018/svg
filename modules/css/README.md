# Local CSS core

This directory contains the CSS parser, selector, cascade, media-query, and
computed-style core used by the SVG renderer.

The initial source was copied from `mizchi/css` version `0.7.3`:

- Upstream: <https://github.com/mizchi/css>
- Upstream module: `mizchi/css`
- License: Apache-2.0
- Local module and package prefix: `Milky2018/css`

The code is maintained in the `modules/css` workspace member of
`Milky2018/svg`. Changes required by SVG
computed-value and rendering semantics should be made and tested here rather
than patched in the renderer or deferred to an external package release.

Generated WPT fixtures and benchmarks were not imported. Core unit tests and
white-box tests were retained. The surrounding SVG tests remain the acceptance
suite for the local CSS behavior used by the renderer.
