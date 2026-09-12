// ============================================================================
// Use/Symbol (Reusable Elements)
// ============================================================================

///|
/// Symbol definition (reusable graphic)
pub(all) struct Symbol {
  id : String
  content : SVGNode
  view_box : ViewBox?
  width : Double?
  height : Double?
  preserve_aspect_ratio : PreserveAspectRatio
  display_none : Bool
}

///|
pub fn Symbol::new(id : String, content : SVGNode) -> Symbol {
  {
    id,
    content,
    view_box: None,
    width: None,
    height: None,
    preserve_aspect_ratio: PreserveAspectRatio::default(),
    display_none: false,
  }
}

///|
pub fn Symbol::with_viewbox(
  id : String,
  content : SVGNode,
  view_box : ViewBox,
) -> Symbol {
  {
    id,
    content,
    view_box: Some(view_box),
    width: None,
    height: None,
    preserve_aspect_ratio: PreserveAspectRatio::default(),
    display_none: false,
  }
}

///|
/// Use element (instance of a symbol)
pub(all) struct UseElement {
  href : String // Reference to symbol ID (e.g., "#mySymbol")
  x : Double
  y : Double
  width : Double?
  height : Double?
  transform : Transform
}

///|
pub fn UseElement::new(href : String, x : Double, y : Double) -> UseElement {
  { href, x, y, width: None, height: None, transform: Transform::identity(), }
}

///|
pub fn UseElement::with_size(
  href : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> UseElement {
  {
    href,
    x,
    y,
    width: Some(width),
    height: Some(height),
    transform: Transform::identity(),
  }
}

///|
fn hex_value(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(10 + (c.to_int() - 'a'.to_int()))
  } else if c >= 'A' && c <= 'F' {
    Some(10 + (c.to_int() - 'A'.to_int()))
  } else {
    None
  }
}

///|
fn decode_percent(s : String) -> String {
  let mut i = 0
  let len = s.length()
  let buf = StringBuilder()
  while i < len {
    let c = Int::unsafe_to_char(s[i].to_int())
    if c == '%' && i + 2 < len {
      let c1 = Int::unsafe_to_char(s[i + 1].to_int())
      let c2 = Int::unsafe_to_char(s[i + 2].to_int())
      match (hex_value(c1), hex_value(c2)) {
        (Some(h1), Some(h2)) => {
          let v = h1 * 16 + h2
          buf.write_char(Int::unsafe_to_char(v))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
/// Get the href ID (strips leading #)
pub fn UseElement::get_id(self : UseElement) -> String {
  if self.href.length() > 0 && self.href[0].unsafe_to_char() == '#' {
    let buf = StringBuilder()
    for i in 1..<self.href.length() {
      buf.write_char(self.href[i].unsafe_to_char())
    }
    decode_percent(buf.to_string())
  } else {
    self.href
  }
}

///|
/// Symbol registry
priv struct SymbolRegistry {
  symbols : Map[String, Symbol]
}

///|
fn SymbolRegistry::new() -> SymbolRegistry {
  { symbols: Map([]), }
}

///|
fn SymbolRegistry::add(self : SymbolRegistry, symbol : Symbol) -> Unit {
  self.symbols.set(symbol.id, symbol)
}

///|
fn SymbolRegistry::get(self : SymbolRegistry, id : String) -> Symbol? {
  self.symbols.get(id)
}

///|
/// Registry for reusable elements defined in <defs>
priv struct DefsRegistry {
  elements : Map[String, SVGNode]
}

///|
fn DefsRegistry::new() -> DefsRegistry {
  { elements: Map([]), }
}

///|
fn DefsRegistry::add(self : DefsRegistry, id : String, node : SVGNode) -> Unit {
  if id.length() == 0 {
    return
  }
  self.elements.set(id, node)
}

///|
fn DefsRegistry::get(self : DefsRegistry, id : String) -> SVGNode? {
  self.elements.get(id)
}

///|
fn UseElement::instantiate_definition(
  self : UseElement,
  registry : DefsRegistry,
  viewport_fallback : (Double, Double)?,
) -> SVGNode? {
  let id = self.get_id()
  match registry.get(id) {
    Some(target) => {
      let node = target.clone()
      // Only a nested <svg> (or a target that already carries viewport
      // geometry) establishes a new viewport when instantiated through <use>.
      // Plain graphics elements such as <path>, <rect>, or <g> are rendered in
      // the referencing user space without an implicit viewport, so their
      // content must never be clipped to the fallback viewport size. Glyph
      // outlines with negative coordinates rely on this.
      let is_viewport_target = node.establishes_viewport ||
        node.view_box is Some(_) ||
        (node.viewport_width is Some(_) && node.viewport_height is Some(_))
      let viewport_fallback : (Double, Double)? = if is_viewport_target {
        viewport_fallback
      } else {
        None
      }
      if !is_viewport_target {
        node.clip_overflow = false
      }
      let (vb, force_non_uniform) = match node.view_box {
        Some(vb) => (Some(vb), false)
        None =>
          match (node.viewport_width, node.viewport_height) {
            (Some(w), Some(h)) =>
              (Some({ min_x: 0.0, min_y: 0.0, width: w, height: h, }), true)
            _ =>
              match viewport_fallback {
                Some((vw, vh)) =>
                  (
                    Some({ min_x: 0.0, min_y: 0.0, width: vw, height: vh, }),
                    true,
                  )
                None => (None, false)
              }
          }
      }
      if force_non_uniform {
        node.preserve_aspect_ratio = { align: None, meet_or_slice: Meet, }
      }
      let vw = match self.width {
        Some(w) => Some(w)
        None =>
          match node.viewport_width {
            Some(w) => Some(w)
            None =>
              match viewport_fallback {
                Some((vw, _)) => Some(vw)
                None => None
              }
          }
      }
      let vh = match self.height {
        Some(h) => Some(h)
        None =>
          match node.viewport_height {
            Some(h) => Some(h)
            None =>
              match viewport_fallback {
                Some((_, vh)) => Some(vh)
                None => None
              }
          }
      }
      node.view_box = vb
      node.viewport_width = vw
      node.viewport_height = vh
      let translate = Transform::translate(self.x, self.y)
      let base = self.transform.multiply(translate)
      node.transform = base.multiply(node.transform)
      Some(node)
    }
    None => None
  }
}

///|
/// Instantiate a use element with the symbol registry
fn UseElement::instantiate(
  self : UseElement,
  registry : SymbolRegistry,
) -> SVGNode? {
  let id = self.get_id()
  match registry.get(id) {
    Some(symbol) => {
      if symbol.display_none {
        return None
      }
      // Create a copy of the symbol content
      let node = symbol.content.clone()
      let (vb, force_non_uniform) = match symbol.view_box {
        Some(vb) => (Some(vb), false)
        None =>
          match (symbol.width, symbol.height) {
            (Some(w), Some(h)) =>
              (Some({ min_x: 0.0, min_y: 0.0, width: w, height: h, }), true)
            _ => (None, false)
          }
      }
      let vw = match self.width {
        Some(w) => Some(w)
        None => symbol.width
      }
      let vh = match self.height {
        Some(h) => Some(h)
        None => symbol.height
      }
      // Apply viewBox scaling (if viewport is known)
      node.view_box = vb
      if force_non_uniform {
        node.preserve_aspect_ratio = { align: None, meet_or_slice: Meet, }
      }
      node.viewport_width = vw
      node.viewport_height = vh
      // Apply use element transform
      let translate = Transform::translate(self.x, self.y)
      let base = self.transform.multiply(translate)
      node.transform = base.multiply(node.transform)
      Some(node)
    }
    None => None
  }
}

///|
/// Instantiate a reusable element registered on this document.
pub fn SVGDocument::instantiate_use(
  self : SVGDocument,
  element : UseElement,
) -> SVGNode? {
  match element.instantiate(self.symbols) {
    Some(node) => Some(node)
    None => element.instantiate_definition(self.definitions, None)
  }
}

///|
/// Clone an SVGNode (shallow clone of children)
fn SVGNode::clone(self : SVGNode) -> SVGNode {
  let children : Array[SVGNode] = []
  for child in self.children {
    children.push(child.clone())
  }
  let filters : Array[Filter] = []
  for f in self.filters {
    filters.push(f)
  }
  {
    id: self.id,
    shape: self.shape,
    transform: self.transform,
    view_box: self.view_box,
    viewport_width: self.viewport_width,
    viewport_height: self.viewport_height,
    preserve_aspect_ratio: self.preserve_aspect_ratio,
    preserve_aspect_ratio_is_set: self.preserve_aspect_ratio_is_set,
    image_sampling: self.image_sampling,
    fill: self.fill,
    fill_is_set: self.fill_is_set,
    color: self.color,
    color_is_set: self.color_is_set,
    paint_order: self.paint_order,
    fill_rule: self.fill_rule,
    clip_rule: self.clip_rule,
    fill_opacity: self.fill_opacity,
    stroke: self.stroke,
    stroke_paint_is_set: self.stroke_paint_is_set,
    stroke_width_is_set: self.stroke_width_is_set,
    stroke_opacity: self.stroke_opacity,
    opacity: self.opacity,
    blend_mode: self.blend_mode,
    isolation: self.isolation,
    marker_start: self.marker_start,
    marker_start_is_set: self.marker_start_is_set,
    marker_mid: self.marker_mid,
    marker_mid_is_set: self.marker_mid_is_set,
    marker_end: self.marker_end,
    marker_end_is_set: self.marker_end_is_set,
    filters,
    filter_graph_id: self.filter_graph_id,
    mask_id: self.mask_id,
    clip_path_id: self.clip_path_id,
    clip_overflow: self.clip_overflow,
    establishes_viewport: self.establishes_viewport,
    children,
  }
}
