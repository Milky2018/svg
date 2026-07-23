# Changelog

This workspace releases `Milky2018/css` and `Milky2018/svg` with matching
versions.

## Milky2018/svg 0.5.0 - 2026-07-23

### Added

- Resolve SVG and CSS lengths with explicit viewport, percentage, font, root
  font, and viewport-unit context, including mixed `calc()` expressions.
- Add a deterministic static render environment for media queries, forced
  interaction pseudo-classes, and explicit-time CSS keyframe sampling.
- Add a bounded host text resolver for external stylesheets, recursive
  `@import`, and document-scoped external SVG resources used by `<use>`, paint,
  clip, mask, filter, pattern, and marker references.

## Milky2018/css 0.5.0 - 2026-07-23

### Added

- Preserve parsed `@import` rules for embedding applications.
- Expose validated cascade matching with both media and forced pseudo-class
  state.
- Expose shared context-aware length-dimension resolution.

## Milky2018/svg 0.4.1 - 2026-07-22

### Fixed

- Resolve prefixed SVG elements and attributes by namespace URI, including
  XLink aliases and scoped prefix rebinding.
- Allow manually constructed documents to register ordinary ID definitions for
  `<use>` instantiation, matching parsed-document behavior.
- Align the public transform surface and migration guide with the 0.4 API.

## Milky2018/css 0.4.1 - 2026-07-22

### Changed

- Publish the locally maintained static CSS core for the first time, versioned
  in lockstep with `Milky2018/svg`.
- Retain tokenizer, stylesheet and inline parsing, selectors, media queries,
  cascade, computed values, property metadata, colors, and custom properties.
- Reorganize computed values, inline parsing, property families, value helpers,
  and tests into cohesive files.

### Removed

- Remove the animation execution runtime and generic browser layout/support
  diagnostics. Static animation and transition syntax remains representable,
  but no timeline or dynamic browser behavior is executed.

## Milky2018/svg 0.4.0 - 2026-07-22

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

### Migration from 0.3.x

| Removed or retained 0.3.x API | 0.4.0 migration |
| --- | --- |
| `parse_svg(source)` | Use `parse_svg_document(source)` and access `document.root()` when only the root node is needed. |
| `parse_svg_document`, `render_svg`, and `render_svg_to_image` | Retained; `render_svg` remains the structured `RenderResult` entry point. |
| `render_svg_document_to_image*` | Use `render_svg_document(document, width, height, options).image`. |
| `render_svg_node_to_image*` | Wrap the node with `SVGDocument::new(node)`, then call `render_svg_document`. |
| `render_svg_scene_to_image*` and `Scene` | No direct replacement; migrate authored content to `SVGDocument` and `SVGNode`. |
| All `*_with_resolver` rendering functions | Pass `RenderOptions::with_image_resolver(resolver)` to `render_svg` or `render_svg_document`. |
| `PixelSetter`, `RenderContext`, context-driven `.render`, and public `raster_*` functions | No direct replacement; use the owned-image rendering facade. |
| `render_path_commands_to_image` | Retained as the expert direct-path entry point. |

The published [SVG module guide](modules/svg/README.mbt.md#migrating-from-03x)
contains the complete function-by-function table and current usage examples.

## Milky2018/svg 0.3.1 - 2026-07-21

- Published the owned-image renderer facade and continuous-coverage software
  renderer baseline.
