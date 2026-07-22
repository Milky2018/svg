// ============================================================================
// Pattern Fill
// ============================================================================

///|
/// Pattern definition for fills
pub(all) struct Pattern {
  id : String
  x : Double
  y : Double
  width : Double // Pattern tile width
  height : Double // Pattern tile height
  content : Array[SVGNode] // Pattern content
  pattern_units : PatternUnits
  pattern_content_units : PatternUnits
  transform : Transform
  view_box : ViewBox?
  preserve_aspect_ratio : PreserveAspectRatio
}

///|
pub(all) enum PatternUnits {
  UserSpaceOnUse // Coordinates relative to current user space
  ObjectBoundingBox // Coordinates relative to bounding box (0-1)
}

///|
pub fn Pattern::new(
  id : String,
  width : Double,
  height : Double,
  content : Array[SVGNode],
) -> Pattern {
  {
    id,
    x: 0.0,
    y: 0.0,
    width,
    height,
    content,
    pattern_units: ObjectBoundingBox,
    pattern_content_units: UserSpaceOnUse,
    transform: Transform::identity(),
    view_box: None,
    preserve_aspect_ratio: PreserveAspectRatio::default(),
  }
}

///|
/// Pattern registry
priv struct PatternRegistry {
  patterns : Map[String, Pattern]
  references : Map[String, String]
  specified : Map[String, Int]
}

///|
fn PatternRegistry::new() -> PatternRegistry {
  { patterns: Map([]), references: Map([]), specified: Map([]) }
}

///|
fn PatternRegistry::add(self : PatternRegistry, pattern : Pattern) -> Unit {
  self.patterns.set(pattern.id, pattern)
  self.specified.set(pattern.id, 0x7FFFFFFF)
  let _ = self.references.remove(pattern.id)
}

///|
fn PatternRegistry::add_definition(
  self : PatternRegistry,
  pattern : Pattern,
  reference : String?,
  specified : Int,
) -> Unit {
  self.patterns.set(pattern.id, pattern)
  self.specified.set(pattern.id, specified)
  match reference {
    Some(id) => self.references.set(pattern.id, id)
    None => {
      let _ = self.references.remove(pattern.id)
    }
  }
}

///|
fn string_array_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn PatternRegistry::resolve_inner(
  self : PatternRegistry,
  id : String,
  visiting : Array[String],
) -> Pattern? {
  if string_array_contains(visiting, id) {
    return None
  }
  let current = match self.patterns.get(id) {
    Some(pattern) => pattern
    None => return None
  }
  let parent_id = match self.references.get(id) {
    Some(value) => value
    None => return Some(current)
  }
  let next_visiting = visiting.copy()
  next_visiting.push(id)
  let parent = match self.resolve_inner(parent_id, next_visiting) {
    Some(pattern) => pattern
    None => return None
  }
  let specified = self.specified.get(id).unwrap_or(0)
  Some({
    id: current.id,
    x: if (specified & 1) != 0 {
      current.x
    } else {
      parent.x
    },
    y: if (specified & 2) != 0 {
      current.y
    } else {
      parent.y
    },
    width: if (specified & 4) != 0 {
      current.width
    } else {
      parent.width
    },
    height: if (specified & 8) != 0 {
      current.height
    } else {
      parent.height
    },
    content: if (specified & 512) != 0 {
      current.content
    } else {
      parent.content
    },
    pattern_units: if (specified & 16) != 0 {
      current.pattern_units
    } else {
      parent.pattern_units
    },
    pattern_content_units: if (specified & 32) != 0 {
      current.pattern_content_units
    } else {
      parent.pattern_content_units
    },
    transform: if (specified & 64) != 0 {
      current.transform
    } else {
      parent.transform
    },
    view_box: if (specified & 128) != 0 {
      current.view_box
    } else {
      parent.view_box
    },
    preserve_aspect_ratio: if (specified & 256) != 0 {
      current.preserve_aspect_ratio
    } else {
      parent.preserve_aspect_ratio
    },
  })
}

///|
fn PatternRegistry::resolve(self : PatternRegistry, id : String) -> Pattern? {
  self.resolve_inner(id, [])
}

///|
/// Gradient definitions
pub(all) enum Gradient {
  Linear(LinearGradient)
  Radial(RadialGradient)
}

///|
/// Gradient registry
priv struct GradientRegistry {
  gradients : Map[String, Gradient]
  references : Map[String, String]
  specified : Map[String, Int]
}

///|
fn GradientRegistry::new() -> GradientRegistry {
  { gradients: Map([]), references: Map([]), specified: Map([]) }
}

///|
fn GradientRegistry::add(
  self : GradientRegistry,
  id : String,
  gradient : Gradient,
) -> Unit {
  self.gradients.set(id, gradient)
  self.specified.set(id, 0x7FFFFFFF)
  let _ = self.references.remove(id)
}

///|
fn GradientRegistry::add_definition(
  self : GradientRegistry,
  id : String,
  gradient : Gradient,
  reference : String?,
  specified : Int,
) -> Unit {
  self.gradients.set(id, gradient)
  self.specified.set(id, specified)
  match reference {
    Some(parent) => self.references.set(id, parent)
    None => {
      let _ = self.references.remove(id)
    }
  }
}

///|
fn GradientRegistry::resolve_inner(
  self : GradientRegistry,
  id : String,
  visiting : Array[String],
) -> Gradient? {
  if string_array_contains(visiting, id) {
    return None
  }
  let current = match self.gradients.get(id) {
    Some(gradient) => gradient
    None => return None
  }
  let parent_id = match self.references.get(id) {
    Some(value) => value
    None => return Some(current)
  }
  let next_visiting = visiting.copy()
  next_visiting.push(id)
  let parent = match self.resolve_inner(parent_id, next_visiting) {
    Some(gradient) => gradient
    None => return None
  }
  let specified = self.specified.get(id).unwrap_or(0)
  match (current, parent) {
    (Linear(child), Linear(base)) =>
      Some(
        Linear({
          x1: if (specified & 1) != 0 {
            child.x1
          } else {
            base.x1
          },
          y1: if (specified & 2) != 0 {
            child.y1
          } else {
            base.y1
          },
          x2: if (specified & 4) != 0 {
            child.x2
          } else {
            base.x2
          },
          y2: if (specified & 8) != 0 {
            child.y2
          } else {
            base.y2
          },
          stops: if (specified & 128) != 0 {
            child.stops
          } else {
            base.stops
          },
          spread_method: if (specified & 16) != 0 {
            child.spread_method
          } else {
            base.spread_method
          },
          units: if (specified & 32) != 0 {
            child.units
          } else {
            base.units
          },
          transform: if (specified & 64) != 0 {
            child.transform
          } else {
            base.transform
          },
        }),
      )
    (Radial(child), Radial(base)) =>
      Some(
        Radial({
          cx: if (specified & 1) != 0 {
            child.cx
          } else {
            base.cx
          },
          cy: if (specified & 2) != 0 {
            child.cy
          } else {
            base.cy
          },
          fx: if (specified & 8) != 0 {
            child.fx
          } else {
            base.fx
          },
          fy: if (specified & 16) != 0 {
            child.fy
          } else {
            base.fy
          },
          r: if (specified & 4) != 0 {
            child.r
          } else {
            base.r
          },
          stops: if (specified & 256) != 0 {
            child.stops
          } else {
            base.stops
          },
          spread_method: if (specified & 32) != 0 {
            child.spread_method
          } else {
            base.spread_method
          },
          units: if (specified & 64) != 0 {
            child.units
          } else {
            base.units
          },
          transform: if (specified & 128) != 0 {
            child.transform
          } else {
            base.transform
          },
        }),
      )
    _ => Some(current)
  }
}

///|
fn GradientRegistry::resolve(self : GradientRegistry, id : String) -> Gradient? {
  self.resolve_inner(id, [])
}
