# Releasing

`Milky2018/css` and `Milky2018/svg` follow Semantic Versioning independently.
While versions are below 1.0, incompatible public API or maintained-scope
changes increment the minor version; compatible fixes increment the patch
version. The SVG manifest pins the CSS release it was validated against.

Repository tags are module-qualified:

- `css-vX.Y.Z` for `Milky2018/css`
- `svg-vX.Y.Z` for `Milky2018/svg`

The historical unqualified `v0.2.1` tag predates the two-module workspace and
is not the convention for new releases.

## Validation

From the workspace root, start with a clean tree and run:

```sh
moon fmt --check
moon info
moon check --target all --deny-warn
moon test --target all
git diff --check
```

Then validate each package from its module directory:

```sh
cd modules/css
moon publish --dry-run
cd ../svg
moon publish --dry-run
```

## Publish Order

1. Confirm the CSS version, CSS changelog entry, and `css-vX.Y.Z` tag agree.
2. Publish `Milky2018/css` and verify the registry contains that version.
3. Confirm the SVG dependency names the published CSS version.
4. Publish `Milky2018/svg`, then create the matching `svg-vX.Y.Z` tag.

Never publish SVG before its referenced CSS version is available. Publication,
tag creation, and pushing tags are explicit release actions and are not part of
ordinary cleanup or version preparation.
