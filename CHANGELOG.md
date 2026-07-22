# Changelog

This workspace versions `Milky2018/css` and `Milky2018/svg` independently.

## Milky2018/svg 0.4.0 - Unreleased

### Changed

- Use the locally maintained `Milky2018/css` 0.8.0 static CSS core for
  presentation attributes, embedded stylesheets, inline declarations, cascade,
  inheritance, custom properties, `currentColor`, and CSS Color 3 values.
- Use `Milky2018/xml` for namespace-aware, entity-aware SVG XML tokenization and
  structural validation.
- Reduce the supported public surface to document parsing, scene data, owned
  image rendering, structured diagnostics, host image resolution, geometry,
  and direct path rendering.
- Reorganize parsing, resources, geometry, paint, compositing, filters, images,
  and tests by responsibility without changing their package ownership.

### Removed

- Remove public low-level render contexts, pixel callbacks, raster helpers, and
  unrelated game-oriented utilities. Use `render_svg`, `render_svg_document`,
  `render_svg_to_image`, or `render_path_commands_to_image` instead.

## Milky2018/css 0.8.0 - Unreleased

### Changed

- Establish `Milky2018/css` as an independently versioned, locally maintained
  static CSS core derived from `mizchi/css` 0.7.3.
- Retain tokenizer, stylesheet and inline parsing, selectors, media queries,
  cascade, computed values, property metadata, colors, and custom properties.
- Reorganize computed values, inline parsing, property families, value helpers,
  and tests into cohesive files.

### Removed

- Remove the animation execution runtime and generic browser layout/support
  diagnostics. Static animation and transition syntax remains representable,
  but no timeline or dynamic browser behavior is executed.

## Milky2018/svg 0.3.1 - 2026-07-21

- Published the owned-image renderer facade and continuous-coverage software
  renderer baseline.
