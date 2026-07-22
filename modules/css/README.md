# Milky2018/css

A reusable static CSS core for MoonBit and the computed-style engine used by
`Milky2018/svg`.

## Install

```sh
moon add Milky2018/css
```

## Supported Boundary

The module owns:

- CSS tokenization and stylesheet or inline-declaration parsing
- selector parsing and matching
- author-origin cascade, specificity, source order, and `!important`
- media-query parsing and evaluation against a supplied environment
- computed values, inheritance, CSS-wide keywords, and custom properties
- CSS Color 3 values and the color functions used by the SVG renderer

The root package exposes the common parser, selector, cascade, media, and
computed-style APIs through one import. Embedders can use
`resolve_custom_property_value` for extension properties and
`cascade_element_with_media_and_validator` to reject invalid extension
declarations before they win the cascade.

The module does not provide a DOM, layout engine, browser environment, dynamic
restyling, animation timeline, transition runtime, or generic browser support
diagnostics. Static animation and transition syntax may be parsed and stored,
but it is not executed.

## SVG Integration

`Milky2018/svg` is the first acceptance consumer, not the only permitted
consumer. Generic CSS behavior belongs here; SVG-specific presentation
attributes, paint semantics, and rendering remain in the SVG module.

## Source Origin

The initial source was copied from `mizchi/css` version `0.7.3`:

- Repository: <https://github.com/mizchi/css>
- Original module: `mizchi/css`
- License: Apache-2.0
- Maintained module: `Milky2018/css`

Generated WPT fixtures and benchmarks were not imported. Retained unit and
white-box tests cover the static core, while the SVG test suite provides
integration coverage for renderer-facing behavior.

The module is distributed under Apache-2.0. See `NOTICE` for the attribution
that accompanies this distribution.
