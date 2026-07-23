///|
test "absolute SVG length units convert to CSS reference pixels" {
  let svg = "<svg width=\"400\" height=\"400\">" +
    "<rect id=\"target\" x=\"1in\" y=\"72pt\" width=\"2.54cm\" height=\"25.4mm\"/>" +
    "</svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(x~, y~, width~, height~, ..) => {
          assert_eq(x, 96.0)
          assert_eq(y, 96.0)
          assert_eq(width, 96.0)
          assert_eq(height, 96.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}

///|
test "inline geometry percentages use the current viewBox axes" {
  let svg = "<svg width=\"400\" height=\"200\" viewBox=\"0 0 200 100\">" +
    "<rect id=\"target\" style=\"x:50%; y:50%; width:25%; height:50%\"/>" +
    "</svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(x~, y~, width~, height~, ..) => {
          assert_eq(x, 100.0)
          assert_eq(y, 50.0)
          assert_eq(width, 50.0)
          assert_eq(height, 50.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}

///|
test "compact points accept an adjacent negative coordinate" {
  let svg = "<svg><polygon id=\"target\" points=\"0,0 10-10 20,0\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Polygon(points~) =>
          assert_eq(points, [(0.0, 0.0), (10.0, -10.0), (20.0, 0.0)])
        _ => fail("expected a polygon")
      }
    None => fail("expected target")
  }
}

///|
test "inline geometry accepts absolute and font-relative length units" {
  let svg = "<svg width=\"400\" height=\"200\">" +
    "<rect id=\"target\" style=\"font-size:20px; x:2em; y:1em; width:1in; height:25.4mm\"/>" +
    "</svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(x~, y~, width~, height~, ..) => {
          assert_eq(x, 40.0)
          assert_eq(y, 20.0)
          assert_eq(width, 96.0)
          assert_eq(height, 96.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}

///|
test "nested SVG percentages use parent placement and child viewBox axes" {
  let svg = "<svg width=\"200\" height=\"100\" viewBox=\"0 0 200 100\">" +
    "<svg id=\"nested\" x=\"50%\" width=\"50%\" height=\"100%\" viewBox=\"0 0 10 10\">" +
    "<rect id=\"target\" x=\"50%\" width=\"50%\" height=\"100%\"/>" +
    "</svg></svg>"
  match css_test_node(svg, "nested") {
    Some(node) => {
      assert_eq(node.transform.e, 100.0)
      assert_eq(node.viewport_width, Some(100.0))
      assert_eq(node.viewport_height, Some(100.0))
    }
    None => fail("expected nested viewport")
  }
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(x~, width~, height~, ..) => {
          assert_eq(x, 5.0)
          assert_eq(width, 5.0)
          assert_eq(height, 10.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}

///|
test "inline geometry positions and sizes a nested SVG viewport" {
  let svg = "<svg width=\"200\" height=\"100\" viewBox=\"0 0 200 100\">" +
    "<svg id=\"nested\" style=\"x:50%; width:50%; height:100%\" viewBox=\"0 0 10 10\"/>" +
    "</svg>"
  match css_test_node(svg, "nested") {
    Some(node) => {
      assert_eq(node.transform.e, 100.0)
      assert_eq(node.viewport_width, Some(100.0))
      assert_eq(node.viewport_height, Some(100.0))
    }
    None => fail("expected nested viewport")
  }
}

///|
test "SVG lengths and compact points accept exponent notation" {
  let svg = "<svg width=\"400\" height=\"200\">" +
    "<rect id=\"rect\" width=\"1e2px\" height=\"1E1px\"/>" +
    "<polyline id=\"line\" points=\"1e1-2e1 3e1,4e1\"/>" +
    "</svg>"
  match css_test_node(svg, "rect") {
    Some(node) =>
      match node.shape {
        Rect(width~, height~, ..) => {
          assert_eq(width, 100.0)
          assert_eq(height, 10.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected rect")
  }
  match css_test_node(svg, "line") {
    Some(node) =>
      match node.shape {
        Polyline(points~) => assert_eq(points, [(10.0, -20.0), (30.0, 40.0)])
        _ => fail("expected a polyline")
      }
    None => fail("expected line")
  }
}

///|
test "unknown SVG length units do not become numeric prefixes" {
  let svg = "<svg><rect id=\"target\" width=\"10furlong\" height=\"10\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(width~, ..) => assert_eq(width, 0.0)
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}

///|
test "use placement resolves attribute and inline percentages" {
  let svg = "<svg width=\"200\" height=\"100\" viewBox=\"0 0 200 100\">" +
    "<defs><rect id=\"shape\" width=\"10\" height=\"10\"/></defs>" +
    "<use id=\"attribute\" href=\"#shape\" x=\"50%\"/>" +
    "<use id=\"inline\" href=\"#shape\" style=\"x:25%; y:50%\"/>" +
    "</svg>"
  match css_test_node(svg, "attribute") {
    Some(node) => assert_eq(node.transform.e, 100.0)
    None => fail("expected attribute use")
  }
  match css_test_node(svg, "inline") {
    Some(node) => {
      assert_eq(node.transform.e, 50.0)
      assert_eq(node.transform.f, 50.0)
    }
    None => fail("expected inline use")
  }
}

///|
test "non-axis length percentages use the normalized viewBox diagonal" {
  let svg = "<svg width=\"300\" height=\"400\" viewBox=\"0 0 300 400\">" +
    "<circle id=\"target\" r=\"10%\" style=\"stroke:black; stroke-width:10%\"/>" +
    "</svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      let expected = 35.35533905932738
      match node.shape {
        Circle(r~, ..) => assert_true((r - expected).abs() < 0.0000001)
        _ => fail("expected a circle")
      }
      assert_true((node.stroke.width - expected).abs() < 0.0000001)
    }
    None => fail("expected target")
  }
}

///|
test "outer SVG percentages use the render viewport" {
  let svg = "<svg width=\"100%\" height=\"100%\">" +
    "<rect width=\"100%\" height=\"100%\" fill=\"red\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 200, 100) {
    Some(image) => image
    None => Image::new(200, 100)
  }
  inspect(image.get_pixel(199, 99).a, content="255")
}

///|
test "text coordinates resolve lengths in the current viewBox" {
  let svg = "<svg width=\"400\" height=\"200\" viewBox=\"0 0 200 100\">" +
    "<text id=\"target\" x=\"50%\" y=\"72pt\">A</text>" +
    "</svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Text(x~, y~, ..) => {
          assert_eq(x, 100.0)
          assert_eq(y, 96.0)
        }
        _ => fail("expected text")
      }
    None => fail("expected target")
  }
}

///|
test "stroke dash percentages use the normalized viewBox diagonal" {
  let svg = "<svg width=\"300\" height=\"400\" viewBox=\"0 0 300 400\">" +
    "<path id=\"target\" d=\"M0 0L100 0\" " +
    "style=\"stroke:black; stroke-dasharray:10%,20%; stroke-dashoffset:5%\"/>" +
    "</svg>"
  match css_test_node(svg, "target") {
    Some(node) => {
      let unit = 35.35533905932738
      match node.stroke.dasharray {
        Some(values) => {
          assert_true((values[0] - unit).abs() < 0.0000001)
          assert_true((values[1] - unit * 2.0).abs() < 0.0000001)
        }
        None => fail("expected dash array")
      }
      assert_true((node.stroke.dashoffset - unit * 0.5).abs() < 0.0000001)
    }
    None => fail("expected target")
  }
}

///|
test "CSS calc resolves percentages and relative units in SVG geometry" {
  let svg = "<svg style=\"font-size:20px; --offset:1rem\" viewBox=\"0 0 200 100\">" +
    "<svg viewBox=\"0 0 10 10\" width=\"100\" height=\"100\">" +
    "<rect id=\"target\" style=\"x:calc(50% + var(--offset)); y:10vh; width:10vw; height:2ex\"/>" +
    "</svg></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(x~, y~, width~, height~, ..) => {
          // Percentages follow the nested 10x10 viewBox.
          assert_eq(x, 25.0)
          // Viewport units remain tied to the outer render viewport.
          assert_eq(y, 15.0)
          assert_eq(width, 30.0)
          // ex uses the deterministic 0.5em fallback.
          assert_eq(height, 20.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}

///|
test "root font size establishes rem for descendant geometry" {
  let svg = "<svg style=\"font-size:24px\"><rect id=\"target\" style=\"x:2rem; width:1rem\"/></svg>"
  match css_test_node(svg, "target") {
    Some(node) =>
      match node.shape {
        Rect(x~, width~, ..) => {
          assert_eq(x, 48.0)
          assert_eq(width, 24.0)
        }
        _ => fail("expected a rect")
      }
    None => fail("expected target")
  }
}
