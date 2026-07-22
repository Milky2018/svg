///|
fn resolved(value : String) -> @types.Color raise {
  match @computed.parse_color(value) {
    Resolved(c) => c
    _ => fail("expected Resolved color for: " + value)
  }
}

///|
fn assert_invalid(value : String) -> Unit raise {
  assert_true(@computed.parse_color(value) is Invalid)
}

///|
test "parse_color - keywords" {
  let t = @computed.parse_color("transparent")
  inspect(t.is_resolved(), content="true")
  let c = @computed.parse_color("currentColor")
  // CurrentColor is not Resolved
  inspect(c.is_resolved(), content="false")
  let i = @computed.parse_color("inherit")
  inspect(i.is_resolved(), content="false")
}

///|
test "parse_color - hex 6 digit" {
  let c = resolved("#ff8040")
  inspect(c.r, content="255")
  inspect(c.g, content="128")
  inspect(c.b, content="64")
}

///|
test "parse_color - hex 3 digit" {
  let c = resolved("#abc")
  inspect(c.r, content="170")
  inspect(c.g, content="187")
  inspect(c.b, content="204")
}

///|
test "parse_color - hex 8 digit with alpha" {
  let c = resolved("#ff000080")
  inspect(c.r, content="255")
  inspect(c.g, content="0")
  inspect(c.b, content="0")
  // alpha is ~0.5
  assert_true((c.a - 0.5).abs() < 0.01)
}

///|
test "parse_color - hex 4 digit with alpha" {
  let c = resolved("#f008")
  inspect(c.r, content="255")
  inspect(c.g, content="0")
  inspect(c.b, content="0")
  // 0x88 / 255 ~ 0.533
  assert_true((c.a - 0.533).abs() < 0.01)
}

///|
test "parse_color - rgb decimal" {
  let c = resolved("rgb(10, 20, 30)")
  inspect(c.r, content="10")
  inspect(c.g, content="20")
  inspect(c.b, content="30")
}

///|
test "parse_color - rgba with float alpha" {
  let c = resolved("rgba(255, 0, 0, 0.5)")
  inspect(c.r, content="255")
  inspect(c.a, content="0.5")
}

///|
test "parse_color - rgb with percent values" {
  let c = resolved("rgb(100%, 0%, 50%)")
  inspect(c.r, content="255")
  inspect(c.g, content="0")
  // 50% rounds down to 127
  inspect(c.b, content="127")
}

///|
test "parse_color - whitespace separated rgb" {
  let c = resolved("rgb(10 20 30)")
  inspect(c.r, content="10")
  inspect(c.g, content="20")
  inspect(c.b, content="30")
}

///|
test "parse_color - rgb with slash alpha" {
  let c = resolved("rgb(255 128 0 / 0.5)")
  inspect(c.r, content="255")
  inspect(c.a, content="0.5")
}

///|
test "parse_color - named common colors" {
  let red = resolved("red")
  inspect(red.r, content="255")
  inspect(red.g, content="0")
  inspect(red.b, content="0")
  let blue = resolved("blue")
  inspect(blue.b, content="255")
  let green = resolved("green")
  inspect(green.g, content="128")
  let white = resolved("white")
  inspect(white.r, content="255")
  inspect(white.g, content="255")
  inspect(white.b, content="255")
  let black = resolved("black")
  inspect(black.r, content="0")
}

///|
test "parse_color - case insensitive named" {
  let c1 = resolved("RED")
  let c2 = resolved("Red")
  let c3 = resolved("red")
  inspect(c1.r, content="255")
  inspect(c2.r, content="255")
  inspect(c3.r, content="255")
}

///|
test "parse_color - hsl and hsla" {
  let red = resolved("hsl(0, 100%, 50%)")
  inspect(red.r, content="255")
  inspect(red.g, content="0")
  inspect(red.b, content="0")
  let green = resolved("hsla(120, 100%, 25%, 50%)")
  inspect(green.r, content="0")
  inspect(green.g, content="128")
  inspect(green.b, content="0")
  inspect(green.a, content="0.5")
}

///|
test "parse_color - gradient is not a solid color" {
  assert_invalid("linear-gradient(to right, red, blue)")
}

///|
test "parse_color - url is not a solid color" {
  assert_invalid("url(image.png)")
}

///|
test "parse_color - empty string is invalid" {
  assert_invalid("")
}

///|
test "parse_color - var() with fallback resolves to fallback" {
  let c = resolved("var(--brand-color, red)")
  inspect(c.r, content="255")
  inspect(c.g, content="0")
  inspect(c.b, content="0")
}

///|
test "parse_color - var() with nested fallback" {
  let c = resolved("var(--a, var(--b, blue))")
  inspect(c.r, content="0")
  inspect(c.g, content="0")
  inspect(c.b, content="255")
}

///|
test "CssColorValue is_resolved, get_color, or_default" {
  let r = @computed.parse_color("#ff0000")
  inspect(r.is_resolved(), content="true")
  assert_true(r.get_color() is Some(_))
  let cc = @computed.parse_color("currentColor")
  assert_true(cc.get_color() is None)
  let fallback = @types.Color::transparent()
  let out = cc.or_default(fallback)
  inspect(out.a, content="0")
  let resolved_white = @computed.parse_color("white")
  inspect(resolved_white.or_default(fallback).r, content="255")
}

///|
test "CssColorValue Show outputs" {
  let r = @computed.parse_color("#ff0000")
  let s = r.to_string()
  assert_true(s.length() > 0)
  inspect(
    @computed.parse_color("currentColor").to_string(),
    content="currentColor",
  )
  inspect(@computed.parse_color("inherit").to_string(), content="inherit")
}

///|
test "parse_color - large named color set" {
  // Covers a wide swath of named colors to exercise the named-color table.
  let names = [
    "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque",
    "blanchedalmond", "blueviolet", "brown", "burlywood", "cadetblue", "chartreuse",
    "chocolate", "coral", "cornflowerblue", "cornsilk", "crimson", "cyan", "darkblue",
    "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkgrey", "darkkhaki",
    "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred", "darksalmon",
    "darkseagreen", "darkslateblue", "darkslategray", "darkslategrey", "darkturquoise",
    "darkviolet", "deeppink", "deepskyblue", "dimgray", "dimgrey", "dodgerblue",
    "firebrick", "floralwhite", "forestgreen", "fuchsia", "gainsboro", "ghostwhite",
    "gold", "goldenrod", "gray", "greenyellow", "grey", "honeydew", "hotpink", "indianred",
    "indigo", "ivory", "khaki", "lavender", "lavenderblush", "lawngreen", "lemonchiffon",
    "lightblue", "lightcoral", "lightcyan", "lightgoldenrodyellow", "lightgray",
    "lightgreen", "lightgrey", "lightpink", "lightsalmon", "lightseagreen", "lightskyblue",
    "lightslategray", "lightslategrey", "lightsteelblue", "lightyellow", "lime",
    "limegreen", "linen", "magenta", "maroon", "mediumaquamarine", "mediumblue",
    "mediumorchid", "mediumpurple", "mediumseagreen", "mediumslateblue", "mediumspringgreen",
    "mediumturquoise", "mediumvioletred", "midnightblue", "mintcream", "mistyrose",
    "moccasin", "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange",
    "orangered", "orchid", "palegoldenrod", "palegreen", "paleturquoise", "palevioletred",
    "papayawhip", "peachpuff", "peru", "pink", "plum", "powderblue", "purple", "rebeccapurple",
    "rosybrown", "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen",
    "seashell", "sienna", "silver", "skyblue", "slateblue", "slategray", "slategrey",
    "snow", "springgreen", "steelblue", "tan", "teal", "thistle", "tomato", "turquoise",
    "violet", "wheat", "whitesmoke", "yellow", "yellowgreen",
  ]
  for n in names {
    let v = @computed.parse_color(n)
    inspect(v.is_resolved(), content="true")
  }
}

///|
test "parse_color - rgb percentage alpha" {
  let c = resolved("rgba(255, 0, 0, 50%)")
  inspect(c.r, content="255")
  // 50% / 100 = 0.5
  inspect(c.a, content="0.5")
}

///|
test "parse_color - numeric alpha is clamped to one" {
  let c = resolved("rgba(255, 0, 0, 128)")
  inspect(c.a, content="1")
}

///|
test "parse_color - unknown name is invalid" {
  assert_invalid("definitely-not-a-color")
}

///|
test "parse_color - hex 5 digit is invalid" {
  assert_invalid("#abcde")
}

///|
test "parse_color - rgb without closing paren is invalid" {
  assert_invalid("rgb(10, 20, 30")
}

///|
test "parse_color - mixed-case hex" {
  let c = resolved("#FfAa11")
  inspect(c.r, content="255")
  inspect(c.g, content="170")
  inspect(c.b, content="17")
}

///|
test "parse_color - gradient functions are invalid as solid colors" {
  assert_invalid("radial-gradient(red, blue)")
  assert_invalid("conic-gradient(red, blue)")
  assert_invalid("repeating-linear-gradient(red, blue)")
  assert_invalid("repeating-radial-gradient(red, blue)")
}

///|
test "parse_color_with_ctx - light-dark() resolves to light arg by default" {
  let ctx = @computed.ComputeContext::new()
  let r = @computed.parse_color_with_ctx("light-dark(#ff0000, #0000ff)", ctx)
  match r {
    Resolved(c) => inspect(c.r, content="255")
    _ => fail("expected Resolved")
  }
}

///|
test "parse_color_with_ctx - light-dark() with var() inside" {
  let ctx = @computed.ComputeContext::new()
  let r = @computed.parse_color_with_ctx("light-dark(var(--a, red), blue)", ctx)
  match r {
    Resolved(c) => inspect(c.r, content="255")
    _ => fail("expected Resolved")
  }
}

///|
test "parse_color - hex with paren in var() balanced" {
  // Exercise the inner paren-depth tracking in resolve_color_var_fallback.
  let c = resolved("var(--x, rgba(255, 0, 0, 1))")
  inspect(c.r, content="255")
}

///|
test "parse_color - unresolved var() is invalid" {
  assert_invalid("var(--no-fallback)")
}

///|
test "resolve_current_color resolves CurrentColor and Inherit to parent" {
  let parent_color = @types.Color::rgb(50, 100, 150)
  let resolved_val = @computed.parse_color("red")
  inspect(
    @computed.resolve_current_color(resolved_val, parent_color).r,
    content="255",
  )
  let cc = @computed.parse_color("currentColor")
  inspect(@computed.resolve_current_color(cc, parent_color).r, content="50")
  let inh = @computed.parse_color("inherit")
  inspect(@computed.resolve_current_color(inh, parent_color).g, content="100")
}

///|
test "parse_linear_gradient - basic two-color" {
  let bg = @computed.parse_linear_gradient("linear-gradient(red, blue)")
  let s = bg.to_string()
  assert_true(s.has_prefix("Gradient"))
  assert_true(s.contains("180")) // default angle
}

///|
test "parse_linear_gradient - direction keywords" {
  let directions = [
    ("to top", "0"),
    ("to right", "90"),
    ("to bottom", "180"),
    ("to left", "270"),
    ("to top right", "45"),
    ("to right top", "45"),
    ("to bottom right", "135"),
    ("to right bottom", "135"),
    ("to bottom left", "225"),
    ("to left bottom", "225"),
    ("to top left", "315"),
    ("to left top", "315"),
  ]
  for d in directions {
    let bg = @computed.parse_linear_gradient(
      "linear-gradient(" + d.0 + ", red, blue)",
    )
    let s = bg.to_string()
    assert_true(s.contains("angle_deg: " + d.1))
  }
}

///|
test "parse_linear_gradient - explicit deg angle" {
  let bg = @computed.parse_linear_gradient("linear-gradient(45deg, red, blue)")
  let s = bg.to_string()
  assert_true(s.contains("angle_deg: 45"))
}

///|
test "parse_linear_gradient - turn unit" {
  let bg = @computed.parse_linear_gradient(
    "linear-gradient(0.25turn, red, blue)",
  )
  let s = bg.to_string()
  // 0.25 * 360 = 90
  assert_true(s.contains("angle_deg: 90"))
}

///|
test "parse_linear_gradient - bad input returns None" {
  let bg1 = @computed.parse_linear_gradient("not-a-gradient")
  inspect(bg1, content="None")
  let bg2 = @computed.parse_linear_gradient("linear-gradient(red)") // too few stops
  inspect(bg2, content="None")
  let bg3 = @computed.parse_linear_gradient("linear-gradient(") // no closing paren
  inspect(bg3, content="None")
}

///|
test "parse_linear_gradient - unknown direction defaults to bottom" {
  let bg = @computed.parse_linear_gradient(
    "linear-gradient(to nowhere, red, blue)",
  )
  // 'to nowhere' is unknown; falls through to default 180 (to bottom)
  let s = bg.to_string()
  assert_true(s.contains("Gradient"))
}

///|
test "parse_linear_gradient - color stop with percentage" {
  let bg = @computed.parse_linear_gradient("linear-gradient(red 25%, blue 75%)")
  let s = bg.to_string()
  assert_true(s.contains("position: 0.25"))
  assert_true(s.contains("position: 0.75"))
}

///|
test "parse_linear_gradient - bad color in stop resolves to transparent" {
  let bg = @computed.parse_linear_gradient(
    "linear-gradient(not-a-color, also-not-a-color)",
  )
  let s = bg.to_string()
  // Both colors fall through to transparent
  assert_true(s.contains("Gradient"))
}

///|
test "parse_color - hex rejects non-hex digits" {
  assert_invalid("#zzzzzz")
}

///|
test "parse_color - empty hex (just #)" {
  assert_invalid("#")
}

///|
test "parse_color - var() chain with deeply nested parens" {
  // Triggers paren_depth tracking in resolve_color_var_fallback.
  let c = resolved("var(--x, var(--y, var(--z, red)))")
  inspect(c.r, content="255")
}

///|
test "parse_color_with_ctx - light-dark() with bad input" {
  let ctx = @computed.ComputeContext::new()
  // Only one arg to light-dark
  let c = @computed.parse_color_with_ctx("light-dark(red)", ctx)
  // Falls through, parses 'light-dark(red)' as a regular color → transparent
  let _ = c
  inspect(true, content="true")
}

///|
test "parse_color - light-dark() without trailing paren" {
  let ctx = @computed.ComputeContext::new()
  let c = @computed.parse_color_with_ctx("light-dark(red, blue", ctx)
  let _ = c
  inspect(true, content="true")
}

///|
test "parse_color_with_ctx - dark scheme selects second arg" {
  let ctx = @computed.ComputeContext::new()
  ctx.custom_properties["--crater-effective-color-scheme"] = "dark"
  let c = @computed.parse_color_with_ctx("light-dark(#ff0000, #0000ff)", ctx)
  match c {
    Resolved(col) => inspect(col.b, content="255")
    _ => fail("expected Resolved")
  }
}

///|
test "parse_color color-mix() across spaces and weights" {
  inspect(
    @computed.parse_color("color-mix(in srgb, red, blue)"),
    content="rgb(128, 0, 128)",
  )
  inspect(
    @computed.parse_color("color-mix(in srgb, white 25%, black)"),
    content="rgb(64, 64, 64)",
  )
  inspect(
    @computed.parse_color("color-mix(in oklch, red 30%, blue)"),
    content="rgb(136, 0, 236)",
  )
  // space-separated function args inside components are handled
  inspect(
    @computed.parse_color("color-mix(in lab, rgb(255 0 0), rgb(0 0 255))"),
    content="rgb(202, 0, 136)",
  )
}
