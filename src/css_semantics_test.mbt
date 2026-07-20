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
