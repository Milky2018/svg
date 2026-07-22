///|
/// SVG XML Parser
/// Parses SVG markup into SVGNode tree

///|
/// SVG Parser state
priv struct SVGParser {
  events : Array[@xml.Event]
  mut pos : Int
}

///|
/// SVG parse context for reusable resources
priv struct SVGParseContext {
  symbols : SymbolRegistry
  defs : DefsRegistry
  clips : ClipPathRegistry
  masks : MaskRegistry
  filter_graphs : FilterGraphRegistry
  patterns : PatternRegistry
  gradients : GradientRegistry
  markers : MarkerRegistry
  stylesheets : Array[@css_cascade.Stylesheet]
  element_stack : Array[@css_selector.Element]
  sibling_index_stack : Array[Int]
  sibling_count_stack : Array[Int]
  previous_sibling_stack : Array[@css_selector.Element?]
  selector_element_slots : Array[@css_selector.Element?]
  style_stack : Array[InheritedStyle]
  viewport_stack : Array[(Double, Double)]
}

///|
fn SVGParseContext::new(
  stylesheets : Array[@css_cascade.Stylesheet],
) -> SVGParseContext {
  {
    symbols: SymbolRegistry::new(),
    defs: DefsRegistry::new(),
    clips: ClipPathRegistry::new(),
    masks: MaskRegistry::new(),
    filter_graphs: FilterGraphRegistry::new(),
    patterns: PatternRegistry::new(),
    gradients: GradientRegistry::new(),
    markers: MarkerRegistry::new(),
    stylesheets,
    element_stack: [],
    sibling_index_stack: [],
    sibling_count_stack: [],
    previous_sibling_stack: [],
    selector_element_slots: [],
    style_stack: [],
    viewport_stack: [],
  }
}

///|
priv struct InheritedStyle {
  fill : Paint
  fill_rule : FillRule
  clip_rule : FillRule
  fill_opacity : Double
  stroke : StrokeStyle
  stroke_opacity : Double
  color : Color
  paint_order : PaintOrder
  marker_start : String?
  marker_mid : String?
  marker_end : String?
  image_sampling : ImageSampling
  stop_color : Color
  stop_opacity : Double
  css_style : @css_style.Style
  custom_properties : Map[String, String]
}

///|
fn InheritedStyle::default() -> InheritedStyle {
  {
    fill: SolidColor(Color::black()),
    fill_rule: NonZero,
    clip_rule: NonZero,
    fill_opacity: 1.0,
    stroke: StrokeStyle::default(),
    stroke_opacity: 1.0,
    color: Color::black(),
    paint_order: PaintOrder::default(),
    marker_start: None,
    marker_mid: None,
    marker_end: None,
    image_sampling: Bilinear,
    stop_color: Color::black(),
    stop_opacity: 1.0,
    css_style: @css_style.Style::default(),
    custom_properties: Map([]),
  }
}

///|
fn SVGParseContext::current_style(self : SVGParseContext) -> InheritedStyle {
  if self.style_stack.length() == 0 {
    InheritedStyle::default()
  } else {
    self.style_stack[self.style_stack.length() - 1]
  }
}

///|
fn SVGParseContext::current_sibling_index(self : SVGParseContext) -> Int {
  if self.sibling_index_stack.length() == 0 {
    1
  } else {
    self.sibling_index_stack[self.sibling_index_stack.length() - 1]
  }
}

///|
fn SVGParseContext::current_sibling_count(self : SVGParseContext) -> Int {
  if self.sibling_count_stack.length() == 0 {
    1
  } else {
    self.sibling_count_stack[self.sibling_count_stack.length() - 1]
  }
}

///|
fn SVGParseContext::current_previous_sibling(
  self : SVGParseContext,
) -> @css_selector.Element? {
  if self.previous_sibling_stack.length() == 0 {
    None
  } else {
    self.previous_sibling_stack[self.previous_sibling_stack.length() - 1]
  }
}

///|
fn SVGParseContext::record_selector_element(
  self : SVGParseContext,
  tag : String,
  attrs : Array[(String, String)],
) -> @css_selector.Element {
  let parent : @css_selector.Element? = if self.element_stack.length() == 0 {
    None
  } else {
    Some(self.element_stack[self.element_stack.length() - 1])
  }
  let element = style_element(
    tag,
    attrs,
    parent,
    self.current_previous_sibling(),
    self.current_sibling_index(),
    self.current_sibling_count(),
  )
  let depth = self.element_stack.length()
  while self.selector_element_slots.length() <= depth {
    self.selector_element_slots.push(None)
  }
  self.selector_element_slots[depth] = Some(element)
  element
}

///|
fn SVGParseContext::cascaded_style(
  self : SVGParseContext,
  tag : String,
  attrs : Array[(String, String)],
) -> @css_cascade.CascadedValues {
  let element = self.record_selector_element(tag, attrs)
  let viewport = match self.current_viewport() {
    Some(viewport) => viewport
    None =>
      (
        get_attr(attrs, "width").map(parse_length).unwrap_or(300.0),
        get_attr(attrs, "height").map(parse_length).unwrap_or(150.0),
      )
  }
  cascade_element_styles(
    self.stylesheets,
    element,
    attrs,
    @css_media.MediaEnvironment::new(viewport.0, viewport.1),
  )
}

///|
fn resolve_element_computed_style(
  node : SVGNode,
  tag : String,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent : InheritedStyle,
  apply_noncomputed : Bool,
) -> InheritedStyle {
  resolve_computed_style(
    node,
    attrs,
    ctx.cascaded_style(tag, attrs),
    parent,
    apply_noncomputed,
  )
}

///|
fn element_style_property_is_declared(
  tag : String,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  name : String,
) -> Bool {
  ctx.cascaded_style(tag, attrs).has(name)
}

///|
fn inherited_style_from_node(
  node : SVGNode,
  css_style : @css_style.Style,
  custom_properties : Map[String, String],
  stop_color : Color,
  stop_opacity : Double,
) -> InheritedStyle {
  {
    fill: node.fill,
    fill_rule: node.fill_rule,
    clip_rule: node.clip_rule,
    fill_opacity: node.fill_opacity,
    stroke: node.stroke,
    stroke_opacity: node.stroke_opacity,
    color: node.color.unwrap_or(Color::black()),
    paint_order: node.paint_order,
    marker_start: node.marker_start,
    marker_mid: node.marker_mid,
    marker_end: node.marker_end,
    image_sampling: node.image_sampling,
    stop_color,
    stop_opacity,
    css_style,
    custom_properties,
  }
}

///|
fn apply_inherited_markers(child : SVGNode, parent : SVGNode) -> Unit {
  if !child.marker_start_is_set {
    child.marker_start = parent.marker_start
  }
  if !child.marker_mid_is_set {
    child.marker_mid = parent.marker_mid
  }
  if !child.marker_end_is_set {
    child.marker_end = parent.marker_end
  }
}

///|
fn SVGParseContext::current_viewport(
  self : SVGParseContext,
) -> (Double, Double)? {
  if self.viewport_stack.length() == 0 {
    None
  } else {
    Some(self.viewport_stack[self.viewport_stack.length() - 1])
  }
}

///|
fn SVGParser::new(events : Array[@xml.Event]) -> SVGParser {
  { events, pos: 0 }
}

///|
fn SVGParser::is_end(self : SVGParser) -> Bool {
  self.pos >= self.events.length() || self.events[self.pos] is Eof
}

///|
fn SVGParser::peek_event(self : SVGParser) -> @xml.Event {
  if self.pos < self.events.length() {
    self.events[self.pos]
  } else {
    Eof
  }
}

///|
fn SVGParser::advance_event(self : SVGParser) -> @xml.Event {
  if self.pos < self.events.length() {
    let event = self.events[self.pos]
    self.pos += 1
    event
  } else {
    Eof
  }
}

///|
let svg_namespace_uri = "http://www.w3.org/2000/svg"

///|
let xml_namespace_uri = "http://www.w3.org/XML/1998/namespace"

///|
priv struct XmlNamespaceScope {
  default_uri : String?
  default_declared : Bool
  prefixes : Map[String, String]
}

///|
fn XmlNamespaceScope::root() -> XmlNamespaceScope {
  {
    default_uri: None,
    default_declared: false,
    prefixes: { "xml": xml_namespace_uri },
  }
}

///|
fn XmlNamespaceScope::with_declarations(
  self : XmlNamespaceScope,
  attrs : Array[(String, String)],
) -> XmlNamespaceScope {
  let mut default_uri = self.default_uri
  let mut default_declared = self.default_declared
  let prefixes = self.prefixes.copy()
  for attr in attrs {
    let (name, value) = attr
    if name == "xmlns" {
      default_declared = true
      default_uri = if value == "" { None } else { Some(value) }
    } else if name.has_prefix("xmlns:") {
      let prefix = name[6:].to_owned()
      if value == "" {
        prefixes.remove(prefix)
      } else {
        prefixes[prefix] = value
      }
    }
  }
  { default_uri, default_declared, prefixes }
}

///|
fn XmlNamespaceScope::normalize_element_name(
  self : XmlNamespaceScope,
  qualified_name : String,
) -> String {
  let (local_name, namespace_uri, prefix_bound, legacy_unqualified) = match
    qualified_name.find(":") {
    Some(index) => {
      let prefix = qualified_name[:index].to_owned()
      let local_name = qualified_name[index + 1:].to_owned()
      match self.prefixes.get(prefix) {
        Some(uri) => (local_name, Some(uri), true, false)
        None => (local_name, None, false, false)
      }
    }
    None => (qualified_name, self.default_uri, true, !self.default_declared)
  }
  if !prefix_bound {
    // An unbound prefix must never gain SVG semantics merely from its local
    // name. Curly braces cannot occur in an XML name, so this marker cannot
    // collide with an authored SVG element name.
    "{unbound-prefix}" + local_name
  } else {
    match namespace_uri {
      // Preserve the library's historical support for unqualified SVG
      // fragments such as `<rect/>` while respecting any declared namespace.
      None if legacy_unqualified => local_name
      None => "{no-namespace}" + local_name
      Some(uri) if uri == svg_namespace_uri => local_name
      Some(uri) => "{" + uri + "}" + local_name
    }
  }
}

///|
fn normalize_xml_namespaces(events : Array[@xml.Event]) -> Array[@xml.Event] {
  let normalized : Array[@xml.Event] = []
  let scopes : Array[XmlNamespaceScope] = [XmlNamespaceScope::root()]
  for event in events {
    let current = scopes[scopes.length() - 1]
    match event {
      Start(element) => {
        let scope = current.with_declarations(element.attributes)
        normalized.push(
          Start(
            @xml.XmlElement::with_attrs(
              scope.normalize_element_name(element.name),
              element.attributes,
            ),
          ),
        )
        scopes.push(scope)
      }
      Empty(element) => {
        let scope = current.with_declarations(element.attributes)
        normalized.push(
          Empty(
            @xml.XmlElement::with_attrs(
              scope.normalize_element_name(element.name),
              element.attributes,
            ),
          ),
        )
      }
      End(name) => {
        normalized.push(End(current.normalize_element_name(name)))
        if scopes.length() > 1 {
          let _ = scopes.pop()
        }
      }
      _ => normalized.push(event)
    }
  }
  normalized
}

///|
fn read_xml_events(svg_str : String) -> Array[@xml.Event]? {
  let reader = @xml.Reader::from_string(svg_str)
  try {
    let events : Array[@xml.Event] = []
    while true {
      let event = reader.read_event()
      events.push(event)
      if event is Eof {
        break
      }
    }
    Some(normalize_xml_namespaces(events))
  } catch {
    _ => None
  }
}

///|
/// Parse SVG markup string into SVGDocument with resources
pub fn parse_svg_document(svg_str : String) -> SVGDocument? {
  let events = match read_xml_events(svg_str) {
    Some(events) => events
    None => return None
  }
  let parser = SVGParser::new(events)
  let ctx = SVGParseContext::new(parse_embedded_stylesheets(events))
  match parse_element(parser, ctx, "") {
    Some(root) =>
      Some({
        root,
        symbols: ctx.symbols,
        definitions: ctx.defs,
        clips: ctx.clips,
        masks: ctx.masks,
        filter_graphs: ctx.filter_graphs,
        patterns: ctx.patterns,
        gradients: ctx.gradients,
        markers: ctx.markers,
      })
    None => None
  }
}

///|
fn parse_element(
  parser : SVGParser,
  ctx : SVGParseContext,
  parent_tag : String,
) -> SVGNode? {
  let mut element : @xml.XmlElement? = None
  let mut self_closing = false
  while !parser.is_end() && element is None {
    match parser.advance_event() {
      Start(found) => element = Some(found)
      Empty(found) => {
        element = Some(found)
        self_closing = true
      }
      End(_) | Eof => return None
      _ => ()
    }
  }
  let element = match element {
    Some(element) => element
    None => return None
  }
  let tag_name = element.name
  let attrs = element.attributes
  let _ = ctx.record_selector_element(tag_name, attrs)
  match tag_name {
    "defs" => {
      if !self_closing {
        let temp = SVGNode::new(Group)
        apply_attributes(temp, attrs)
        let style = resolve_element_computed_style(
          temp,
          tag_name,
          attrs,
          ctx,
          ctx.current_style(),
          true,
        )
        parse_children(parser, temp, tag_name, attrs, ctx, style)
      }
      Group |> SVGNode::new |> Some
    }
    "symbol" => {
      let symbol_node = SVGNode::new(Group)
      let id = match get_attr(attrs, "id") {
        Some(v) => v
        None => ""
      }
      symbol_node.id = id
      apply_attributes(symbol_node, attrs)
      let symbol_style = resolve_element_computed_style(
        symbol_node,
        tag_name,
        attrs,
        ctx,
        ctx.current_style(),
        true,
      )
      let view_box = match get_attr(attrs, "viewBox") {
        Some(v) => parse_view_box(v)
        None => None
      }
      let width = match get_attr(attrs, "width") {
        Some(v) => v |> parse_length |> Some
        None => None
      }
      let height = match get_attr(attrs, "height") {
        Some(v) => v |> parse_length |> Some
        None => None
      }
      let display_none = match get_attr(attrs, "display") {
        Some(v) => trim_string(v) == "none"
        None => false
      }
      let preserve = match get_attr(attrs, "preserveAspectRatio") {
        Some(v) => parse_preserve_aspect_ratio(v)
        None => PreserveAspectRatio::default()
      }
      if !self_closing {
        parse_children(parser, symbol_node, tag_name, attrs, ctx, symbol_style)
      }
      let symbol = match view_box {
        Some(vb) =>
          {
            ..Symbol::with_viewbox(id, symbol_node, vb),
            preserve_aspect_ratio: preserve,
          }
        None =>
          { ..Symbol::new(id, symbol_node), preserve_aspect_ratio: preserve }
      }
      let symbol = { ..symbol, width, height, display_none }
      ctx.symbols.add(symbol)
      Group |> SVGNode::new |> Some
    }
    "clipPath" => {
      if !self_closing {
        parse_clip_path(parser, attrs, ctx, tag_name)
      } else {
        parse_clip_path_from_attrs(attrs, ctx)
      }
      Group |> SVGNode::new |> Some
    }
    "mask" => {
      if !self_closing {
        parse_mask(parser, attrs, ctx, tag_name)
      } else {
        parse_mask_from_attrs(attrs, ctx)
      }
      Group |> SVGNode::new |> Some
    }
    "filter" => {
      if !self_closing {
        parse_filter_graph(parser, attrs, ctx, tag_name)
      }
      Group |> SVGNode::new |> Some
    }
    "marker" => {
      if !self_closing {
        parse_marker(parser, attrs, ctx, tag_name, parent_tag)
      } else {
        parse_marker_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "image" => {
      let node = parse_image(attrs, ctx)
      if !self_closing {
        skip_to_end_tag(parser, tag_name)
      }
      node
    }
    "pattern" => {
      if !self_closing {
        parse_pattern(parser, attrs, ctx, tag_name, parent_tag)
      } else {
        parse_pattern_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "linearGradient" => {
      if !self_closing {
        let temp = SVGNode::new(Group)
        let gradient_style = resolve_element_computed_style(
          temp,
          tag_name,
          attrs,
          ctx,
          ctx.current_style(),
          false,
        )
        parse_linear_gradient(
          parser, attrs, ctx, tag_name, parent_tag, gradient_style,
        )
      } else {
        parse_linear_gradient_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "radialGradient" => {
      if !self_closing {
        let temp = SVGNode::new(Group)
        let gradient_style = resolve_element_computed_style(
          temp,
          tag_name,
          attrs,
          ctx,
          ctx.current_style(),
          false,
        )
        parse_radial_gradient(
          parser, attrs, ctx, tag_name, parent_tag, gradient_style,
        )
      } else {
        parse_radial_gradient_from_attrs(attrs, ctx, parent_tag)
      }
      Group |> SVGNode::new |> Some
    }
    "use" => {
      let node = parse_use(attrs, ctx)
      if !self_closing {
        skip_to_end_tag(parser, tag_name)
      }
      match node {
        Some(_) => node
        None => Group |> SVGNode::new |> Some
      }
    }
    "style" => {
      if !self_closing {
        skip_to_end_tag(parser, tag_name)
      }
      Group |> SVGNode::new |> Some
    }
    "text" => {
      let content = if self_closing {
        Some("")
      } else {
        parse_plain_text_content(parser, tag_name)
      }
      match content {
        Some(text) => {
          let x = get_attr(attrs, "x").map(parse_length).unwrap_or(0.0)
          let y = get_attr(attrs, "y").map(parse_length).unwrap_or(0.0)
          let node = SVGNode::new(Text(x~, y~, text~, font_size=16.0))
          apply_attributes(node, attrs)
          let computed_style = resolve_element_computed_style(
            node,
            tag_name,
            attrs,
            ctx,
            ctx.current_style(),
            true,
          )
          node.shape = Text(
            x~,
            y~,
            text~,
            font_size=computed_style.css_style.font_size,
          )
          Some(node)
        }
        None => {
          let node = SVGNode::new(Group)
          apply_attributes(node, attrs)
          Some(node)
        }
      }
    }
    _ => {
      // Create node based on tag
      let node = create_node_for_tag(tag_name)
      // Apply attributes
      apply_attributes(node, attrs)
      let computed_style = resolve_element_computed_style(
        node,
        tag_name,
        attrs,
        ctx,
        ctx.current_style(),
        true,
      )
      if tag_name == "svg" {
        if parent_tag != "" {
          if get_attr(attrs, "width") is Some(v) {
            node.viewport_width = v |> parse_length |> Some
          }
          if get_attr(attrs, "height") is Some(v) {
            node.viewport_height = v |> parse_length |> Some
          }
        }
        if get_attr(attrs, "overflow") is Some(v) {
          if trim_string(v) == "visible" {
            node.clip_overflow = false
          }
        }
        let x = match get_attr(attrs, "x") {
          Some(v) => parse_length(v)
          None => 0.0
        }
        let y = match get_attr(attrs, "y") {
          Some(v) => parse_length(v)
          None => 0.0
        }
        if x != 0.0 || y != 0.0 {
          node.transform = Transform::translate(x, y).multiply(node.transform)
        }
      }
      let mut pushed = false
      if tag_name == "svg" && !self_closing {
        let viewport = (
          node.viewport_width.unwrap_or(
            get_attr(attrs, "width").map(parse_length).unwrap_or(300.0),
          ),
          node.viewport_height.unwrap_or(
            get_attr(attrs, "height").map(parse_length).unwrap_or(150.0),
          ),
        )
        ctx.viewport_stack.push(viewport)
        pushed = true
      }
      // Parse children (for container elements)
      if !self_closing {
        match node.shape {
          Group =>
            parse_children(parser, node, tag_name, attrs, ctx, computed_style)
          _ =>
            // Skip to end tag for non-container elements
            skip_to_end_tag(parser, tag_name)
        }
      }
      if pushed {
        let _ = ctx.viewport_stack.pop()
      }
      Some(node)
    }
  }
}

///|
fn skip_to_end_tag(parser : SVGParser, tag_name : String) -> Unit {
  let mut depth = 0
  while !parser.is_end() {
    match parser.advance_event() {
      Start(_) => depth += 1
      Empty(_) => ()
      End(name) => {
        if depth == 0 && name == tag_name {
          return
        }
        if depth > 0 {
          depth -= 1
        }
      }
      Eof => return
      _ => ()
    }
  }
}

///|
fn parse_plain_text_content(parser : SVGParser, tag_name : String) -> String? {
  let content = StringBuilder::new()
  let mut has_nested_element = false
  while !parser.is_end() {
    match parser.advance_event() {
      Text(text) | CData(text) => content.write_string(text)
      Start(element) => {
        has_nested_element = true
        skip_to_end_tag(parser, element.name)
      }
      Empty(_) => has_nested_element = true
      End(name) =>
        if name == tag_name {
          return if has_nested_element {
            None
          } else {
            Some(content.to_string())
          }
        }
      Eof => return None
      _ => ()
    }
  }
  None
}

///|
fn count_direct_child_elements(parser : SVGParser, parent_tag : String) -> Int {
  let mut pos = parser.pos
  let mut depth = 0
  let mut count = 0
  while pos < parser.events.length() {
    match parser.events[pos] {
      Start(_) => {
        if depth == 0 {
          count += 1
        }
        depth += 1
      }
      Empty(_) => if depth == 0 { count += 1 }
      End(name) => {
        if depth == 0 && name == parent_tag {
          break
        }
        if depth > 0 {
          depth -= 1
        }
      }
      Eof => break
      _ => ()
    }
    pos += 1
  }
  count
}

///|
fn parse_children(
  parser : SVGParser,
  parent : SVGNode,
  parent_tag : String,
  parent_attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_style : InheritedStyle,
) -> Unit {
  let parent_element : @css_selector.Element? = if ctx.element_stack.length() ==
    0 {
    None
  } else {
    Some(ctx.element_stack[ctx.element_stack.length() - 1])
  }
  let depth = ctx.element_stack.length()
  let parent_element = if depth < ctx.selector_element_slots.length() {
    match ctx.selector_element_slots[depth] {
      Some(element) => element
      None =>
        style_element(
          parent_tag,
          parent_attrs,
          parent_element,
          ctx.current_previous_sibling(),
          ctx.current_sibling_index(),
          ctx.current_sibling_count(),
        )
    }
  } else {
    style_element(
      parent_tag,
      parent_attrs,
      parent_element,
      ctx.current_previous_sibling(),
      ctx.current_sibling_index(),
      ctx.current_sibling_count(),
    )
  }
  ctx.element_stack.push(parent_element)
  ctx.style_stack.push(parent_style)
  ctx.sibling_index_stack.push(0)
  ctx.sibling_count_stack.push(count_direct_child_elements(parser, parent_tag))
  ctx.previous_sibling_stack.push(None)
  while !parser.is_end() {
    match parser.peek_event() {
      End(name) => {
        let _ = parser.advance_event()
        if name == parent_tag {
          break
        }
      }
      Start(_) | Empty(_) => {
        let current_index = ctx.sibling_index_stack.length() - 1
        ctx.sibling_index_stack[current_index] += 1
        match parse_element(parser, ctx, parent_tag) {
          Some(child) => {
            let child_depth = ctx.element_stack.length()
            if child_depth < ctx.selector_element_slots.length() {
              ctx.previous_sibling_stack[current_index] = ctx.selector_element_slots[child_depth]
            }
            apply_inherited_markers(child, parent)
            parent.children.push(child)
            if child.id.length() > 0 {
              ctx.defs.add(child.id, child)
            }
          }
          None => break
        }
      }
      Eof => break
      _ => {
        let _ = parser.advance_event()
      }
    }
  }
  let _ = ctx.previous_sibling_stack.pop()
  let _ = ctx.sibling_count_stack.pop()
  let _ = ctx.sibling_index_stack.pop()
  let _ = ctx.style_stack.pop()
  let _ = ctx.element_stack.pop()
}
