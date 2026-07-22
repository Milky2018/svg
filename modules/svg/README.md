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

## License

Apache-2.0
