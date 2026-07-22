# Milky2018/svg

SVG パーサー/レンダラーの [MoonBit](https://www.moonbitlang.com/) 実装。サードパーティ依存なし。

## Features

- SVG マークアップのパース (`parse_svg()`)
- CPU ソフトウェアラスタライズ
- シーングラフ操作 (ノードの追加/削除/更新、z-ordering)
- 基本図形: Rect, Circle, Ellipse, Line, Polyline, Polygon, Path, Text
- スタイリング: グラデーション、フィルタ、マスク、クリッピング、ブレンドモード
- 2D アフィン変換 (translate, scale, rotate, skew)
- SVG パスコマンド (`PathCommand` enum, SVG 1.1 仕様準拠)
- テキストレンダリング (最小ビットマップフォントフォールバック)
- 画像処理フィルタ (blur, brightness, contrast, grayscale, etc.)
- ヒットテスト・衝突判定
- スプライトアニメーション、パーティクルシステム

## Usage

```moonbit
// SVG 文字列からピクセル画像を生成
let image = @svg.render_svg_to_image(svg_string, 800, 600)

// PNG/JPEG などはホスト側でデコードし、RGBA Image として渡す
let image = @svg.render_svg_to_image_with_resolver(
  svg_string,
  800,
  600,
  fn(href) { host_decode_image(href) },
)

// パスコマンドの直接操作
let cmds = @svg.parse_path("M10 10 L90 90 Z")
```

image resolver は SVG に記述された `href` をそのまま受け取ります。ファイル・
ネットワークアクセス、PNG/JPEG のデコード、キャッシュはホスト側の責務です。
ライブラリ側は返された RGBA 画像の `preserveAspectRatio`、アフィン変換、クリップ、
アルファ合成を処理します。解決できない参照には `None` を返してください。

## Static CSS

presentation attribute、埋め込み `<style>`、inline style は共通の
`Milky2018/css` cascade で計算されます。specificity、`!important`、継承、
CSS-wide keyword、継承 custom property と `var()` fallback、`currentColor`、
CSS Color 3 の named/RGB/HSL/hex color を扱います。SVG の paint、stroke、
marker、paint order、fill/clip rule、geometry、transform、gradient stop、
基本 text の `font-size` も同じ computed-value 経路を使います。

これは静的 SVG 文書のモデルです。外部 stylesheet、script、動的 restyle、
interaction pseudo-class、cascade layer、browser state による animation は対象外です。
author-only かつ layer-free のため、`revert` と `revert-layer` は inherited property
では継承値、それ以外では initial value に解決します。nested text layout は未対応で、
誤って一つの文字列へ平坦化せず group として保持します。

## License

Apache-2.0
