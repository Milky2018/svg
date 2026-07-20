///|
fn css_test_node(svg : String, id : String) -> SVGNode? {
  match parse_svg_document(svg) {
    Some(document) => Scene::new(document.root).find_node(id)
    None => None
  }
}

///|
fn assert_solid_color(
  paint : Paint,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit raise {
  match paint {
    SolidColor(color) => {
      assert_eq(color.r, r)
      assert_eq(color.g, g)
      assert_eq(color.b, b)
      assert_eq(color.a, a)
    }
    _ => fail("expected a solid color")
  }
}

///|
test "inline important participates in declaration priority" {
  let svg = "<rect id=\"target\" width=\"8\" height=\"8\" fill=\"green\" style=\"fill: red !important; fill: blue\"/>"
  match css_test_node(svg, "target") {
    Some(node) => assert_solid_color(node.fill, 255, 0, 0, 255)
    None => fail("expected target")
  }
}

///|
test "painting properties inherit their computed values" {
  let svg = "<svg><g style=\"fill: red; fill-rule: evenodd; fill-opacity: 0.4; stroke: blue; stroke-width: 3; stroke-linecap: round; stroke-linejoin: bevel; stroke-miterlimit: 7; stroke-dasharray: 2,3; stroke-dashoffset: 4; stroke-opacity: 0.5; paint-order: stroke\"><path id=\"target\" d=\"M0 0 L8 0 L8 8 Z\"/></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      assert_solid_color(node.fill, 255, 0, 0, 255)
      assert_true(node.fill_rule is EvenOdd)
      assert_eq(node.fill_opacity, 0.4)
      assert_solid_color(node.stroke.paint, 0, 0, 255, 255)
      assert_eq(node.stroke.width, 3.0)
      assert_true(node.stroke.linecap is Round)
      assert_true(node.stroke.linejoin is Bevel)
      assert_eq(node.stroke.miterlimit, 7.0)
      assert_eq(node.stroke.dasharray, Some([2.0, 3.0]))
      assert_eq(node.stroke.dashoffset, 4.0)
      assert_eq(node.stroke_opacity, 0.5)
      assert_true(node.paint_order.order[0] is Stroke)
    }
    None => fail("expected target")
  }
}

///|
test "css wide keywords use inherited and initial values" {
  let svg = "<svg><g fill=\"red\" stroke=\"blue\" opacity=\"0.2\"><rect id=\"inherited\" width=\"8\" height=\"8\" fill=\"inherit\" stroke=\"unset\" opacity=\"unset\"/><rect id=\"initial\" width=\"8\" height=\"8\" fill=\"initial\" stroke=\"initial\"/></g></svg>"
  match css_test_node(svg, "inherited") {
    Some(node) => {
      assert_solid_color(node.fill, 255, 0, 0, 255)
      assert_solid_color(node.stroke.paint, 0, 0, 255, 255)
      assert_eq(node.opacity, 1.0)
    }
    None => fail("expected inherited target")
  }
  match css_test_node(svg, "initial") {
    Some(node) => {
      assert_solid_color(node.fill, 0, 0, 0, 255)
      assert_true(node.stroke.paint is None)
    }
    None => fail("expected initial target")
  }
}

///|
test "custom properties inherit and var fallback is resolved" {
  let svg = "<svg><g style=\"--paint: hsl(120, 100%, 25%); --width: 4; --x: 3\"><rect id=\"target\" width=\"8\" height=\"8\" color=\"blue\" style=\"x: var(--x); fill: var(--paint); stroke: var(--missing, currentColor); stroke-width: var(--width)\"/></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      assert_solid_color(node.fill, 0, 128, 0, 255)
      assert_true(node.stroke.paint is CurrentColor)
      assert_eq(node.stroke.width, 4.0)
      match node.shape {
        Rect(x~, ..) => assert_eq(x, 3.0)
        _ => fail("expected a rect")
      }
    }
    None => fail("expected target")
  }
}

///|
test "currentColor follows the computed color property" {
  let svg = "<svg color=\"hsl(240, 100%, 50%)\"><g color=\"currentColor\"><rect id=\"target\" width=\"8\" height=\"8\" fill=\"currentcolor\"/></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      assert_true(node.fill is CurrentColor)
      match node.color {
        Some(color) => {
          assert_eq(color.r, 0)
          assert_eq(color.g, 0)
          assert_eq(color.b, 255)
        }
        None => fail("expected computed color")
      }
    }
    None => fail("expected target")
  }
}

///|
test "hsl and hsla colors are parsed" {
  let svg = "<svg><rect id=\"hsl\" width=\"8\" height=\"8\" fill=\"hsl(0, 100%, 50%)\"/><rect id=\"hsla\" width=\"8\" height=\"8\" fill=\"hsla(120, 100%, 50%, 0.5)\"/></svg>"
  match css_test_node(svg, "hsl") {
    Some(node) => assert_solid_color(node.fill, 255, 0, 0, 255)
    None => fail("expected hsl target")
  }
  match css_test_node(svg, "hsla") {
    Some(node) => assert_solid_color(node.fill, 0, 255, 0, 128)
    None => fail("expected hsla target")
  }
}

///|
test "embedded styles apply regardless of document order" {
  let svg = "<svg><rect id=\"target\" width=\"8\" height=\"8\"/><style><![CDATA[rect { fill: hsl(30, 100%, 50%); }]]></style></svg>"
  match css_test_node(svg, "target") {
    Some(node) => assert_solid_color(node.fill, 255, 128, 0, 255)
    None => fail("expected target")
  }
}

///|
test "stylesheet cascade respects specificity importance and inline style" {
  let svg = "<svg><style>* { fill: black; } rect { fill: red; } .hot { fill: green; } #target { fill: blue; } rect.hot { stroke: red !important; }</style><rect id=\"target\" class=\"hot\" width=\"8\" height=\"8\" fill=\"white\" style=\"fill: yellow; stroke: blue\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      assert_solid_color(node.fill, 255, 255, 0, 255)
      assert_solid_color(node.stroke.paint, 255, 0, 0, 255)
    }
    None => fail("expected target")
  }
}

///|
test "static selector lists child and descendant combinators match" {
  let svg = "<svg><style>circle, g.outer > g rect.selected { fill: purple; stroke-width: var(--width); } g.outer { --width: 5; }</style><g class=\"outer\"><g><rect id=\"target\" class=\"selected\" width=\"8\" height=\"8\"/></g></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      assert_solid_color(node.fill, 128, 0, 128, 255)
      assert_eq(node.stroke.width, 5.0)
    }
    None => fail("expected target")
  }
}

///|
test "stylesheet source order wins and commented styles are ignored" {
  let svg = "<svg><!-- <style>#target { fill: blue !important; }</style> --><style>.same { fill: red; } .same { fill: green; }</style><rect id=\"target\" class=\"same\" width=\"8\" height=\"8\" fill=\"white\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) => assert_solid_color(node.fill, 0, 128, 0, 255)
    None => fail("expected target")
  }
}

///|
test "upstream attribute selectors and screen media rules are applied" {
  let svg = "<svg><style>@media print { #target { fill: red; } } @media screen and (min-width: 100px) { g[data-theme~='hot'] > rect:first-child { fill: blue; } }</style><g data-theme=\"cold hot\"><rect id=\"target\" width=\"8\" height=\"8\"/></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) => assert_solid_color(node.fill, 0, 0, 255, 255)
    None => fail("expected target")
  }
}

///|
test "media queries use the active SVG viewport" {
  let svg = "<svg width=\"200\" height=\"100\"><style>@media (min-width: 500px) { rect { fill: red; } } @media (max-width: 499px) { rect { fill: blue; } }</style><rect id=\"target\" width=\"8\" height=\"8\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) => assert_solid_color(node.fill, 0, 0, 255, 255)
    None => fail("expected target")
  }
}

///|
test "upstream child indexes distinguish first and second children" {
  let svg = "<svg><style>rect:first-child { fill: red; } rect:nth-child(2) { fill: blue; }</style><g><rect id=\"first\" width=\"8\" height=\"8\"/><rect id=\"second\" width=\"8\" height=\"8\"/></g></svg>"
  match css_test_node(svg, "first") {
    Some(node) => assert_solid_color(node.fill, 255, 0, 0, 255)
    None => fail("expected first child")
  }
  match css_test_node(svg, "second") {
    Some(node) => assert_solid_color(node.fill, 0, 0, 255, 255)
    None => fail("expected second child")
  }
}

///|
test "upstream last-child selectors use the direct SVG child count" {
  let svg = "<svg><style>rect:last-child { fill: blue; } rect:nth-last-child(2) { stroke: red; }</style><g><rect id=\"first\" width=\"8\" height=\"8\"/><rect id=\"last\" width=\"8\" height=\"8\"/></g></svg>"
  match css_test_node(svg, "first") {
    Some(node) => assert_solid_color(node.stroke.paint, 255, 0, 0, 255)
    None => fail("expected first child")
  }
  match css_test_node(svg, "last") {
    Some(node) => assert_solid_color(node.fill, 0, 0, 255, 255)
    None => fail("expected last child")
  }
}

///|
test "upstream adjacent and subsequent sibling selectors use SVG order" {
  let svg = "<svg><style>rect.lead + rect { fill: blue; } rect.lead ~ circle { stroke: red; }</style><g><rect class=\"lead\" width=\"8\" height=\"8\"/><rect id=\"adjacent\" width=\"8\" height=\"8\"/><circle id=\"later\" r=\"4\"/></g></svg>"
  match css_test_node(svg, "adjacent") {
    Some(node) => assert_solid_color(node.fill, 0, 0, 255, 255)
    None => fail("expected adjacent sibling")
  }
  match css_test_node(svg, "later") {
    Some(node) => assert_solid_color(node.stroke.paint, 255, 0, 0, 255)
    None => fail("expected subsequent sibling")
  }
}

///|
test "upstream stylesheet recovery preserves later valid rules" {
  let svg = "<svg><style>??? { fill: red; } rect.valid { fill: blue; }</style><rect id=\"target\" class=\"valid\" width=\"8\" height=\"8\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) => assert_solid_color(node.fill, 0, 0, 255, 255)
    None => fail("expected recovered target")
  }
}

///|
test "linear gradient stops use the shared CSS cascade" {
  let svg = "<svg><style>linearGradient { --accent: hsl(120, 100%, 25%); color: blue; stop-color: red; } #current { stop-color: currentColor !important; } stop.clamped { stop-opacity: 2; }</style><defs><linearGradient id=\"paint\"><stop offset=\"0\" style=\"stop-color: var(--accent); stop-opacity: -1\"/><stop id=\"current\" offset=\"0.5\" style=\"stop-color: yellow\"/><stop class=\"clamped\" offset=\"1\" stop-color=\"inherit\"/></linearGradient></defs></svg>"
  match parse_svg_document(svg) {
    Some(document) =>
      match document.gradients.get("paint") {
        Some(Linear(gradient)) => {
          assert_eq(gradient.stops.length(), 3)
          assert_eq(gradient.stops[0].color.r, 0)
          assert_eq(gradient.stops[0].color.g, 128)
          assert_eq(gradient.stops[0].color.b, 0)
          assert_eq(gradient.stops[0].color.a, 0)
          assert_eq(gradient.stops[1].color.r, 0)
          assert_eq(gradient.stops[1].color.g, 0)
          assert_eq(gradient.stops[1].color.b, 255)
          assert_eq(gradient.stops[2].color.r, 255)
          assert_eq(gradient.stops[2].color.g, 0)
          assert_eq(gradient.stops[2].color.b, 0)
        }
        _ => fail("expected linear gradient")
      }
    None => fail("expected SVG document")
  }
}

///|
test "radial gradient stop selectors receive structural context" {
  let svg = "<svg><style>radialGradient > stop:last-child { stop-color: hsl(300, 100%, 25%); stop-opacity: 0.5; }</style><defs><radialGradient id=\"paint\"><stop offset=\"0\" stop-color=\"white\"/><stop offset=\"1\" stop-color=\"black\"/></radialGradient></defs></svg>"
  match parse_svg_document(svg) {
    Some(document) =>
      match document.gradients.get("paint") {
        Some(Radial(gradient)) => {
          assert_eq(gradient.stops.length(), 2)
          assert_eq(gradient.stops[1].color.r, 128)
          assert_eq(gradient.stops[1].color.g, 0)
          assert_eq(gradient.stops[1].color.b, 128)
          assert_eq(gradient.stops[1].color.a, 128)
        }
        _ => fail("expected radial gradient")
      }
    None => fail("expected SVG document")
  }
}

///|
test "text elements use computed font size and decode XML entities" {
  let svg = "<svg><style>text { font-size: 12px; } #target { font-size: 18px !important; }</style><g class=\"copy\"><text id=\"target\" x=\"3\" y=\"7\" font-size=\"10\" style=\"font-size: 14px\">A &amp; &#x42;</text></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Text(x~, y~, text~, font_size~) => {
          assert_eq(x, 3.0)
          assert_eq(y, 7.0)
          assert_eq(text, "A & B")
          assert_eq(font_size, 18.0)
        }
        _ => fail("expected text shape")
      }
    None => fail("expected text target")
  }
}

///|
test "text inherits computed font size" {
  let svg = "<svg><g style=\"font-size: 20px\"><text id=\"target\">Inherited</text></g></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Text(font_size~, ..) => assert_eq(font_size, 20.0)
        _ => fail("expected text shape")
      }
    None => fail("expected text target")
  }
}

///|
test "font-size CSS-wide initial overrides inherited text size" {
  let svg = "<svg font-size=\"24\"><text id=\"target\" style=\"font-size: initial\">Initial</text></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Text(font_size~, ..) => assert_eq(font_size, 16.0)
        _ => fail("expected text shape")
      }
    None => fail("expected text target")
  }
}

///|
test "nested SVG text is not misrepresented as flat text" {
  let svg = "<svg><text id=\"target\">A<tspan>B</tspan></text></svg>"
  match css_test_node(svg, "target") {
    Some(node) => assert_true(node.shape is Group)
    None => fail("expected unsupported text placeholder")
  }
}
