///|
/// SVG XML Parser
/// Parses SVG markup into SVGNode tree

///|
/// SVG Parser state
priv struct SVGParser {
  events : Array[SVGXmlEvent]
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
  length_viewport_stack : Array[(Double, Double)]
  css_viewport : (Double, Double)
  media_environment : @css_media.MediaEnvironment
  element_state_resolver : ((String) -> ElementState)?
  sample_time_seconds : Double
}

///|
fn SVGParseContext::new(
  stylesheets : Array[@css_cascade.Stylesheet],
  initial_length_viewport? : (Double, Double) = (300.0, 150.0),
  environment? : RenderEnvironment = RenderEnvironment::default(),
) -> SVGParseContext {
  let color_scheme = match environment.color_scheme {
    Light => @css_media.Light
    Dark => Dark
  }
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
    length_viewport_stack: [initial_length_viewport],
    css_viewport: initial_length_viewport,
    media_environment: {
      viewport_width: initial_length_viewport.0,
      viewport_height: initial_length_viewport.1,
      device_pixel_ratio: environment.device_pixel_ratio,
      color_scheme,
    },
    element_state_resolver: environment.element_state_resolver,
    sample_time_seconds: environment.sample_time_seconds,
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
  root_font_size : Double
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
    root_font_size: 16.0,
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
  let state = match self.element_state_resolver {
    Some(resolve) =>
      resolve(get_attr(attrs, "id").unwrap_or("")).to_forced_pseudo_states()
    None => @css_selector.ForcedPseudoStates::none()
  }
  cascade_element_styles(
    self.stylesheets,
    element,
    attrs,
    self.media_environment,
    forced_states=state,
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
  let length_viewport = ctx.current_length_viewport().unwrap_or((300.0, 150.0))
  resolve_computed_style(
    node,
    attrs,
    ctx.cascaded_style(tag, attrs),
    parent,
    apply_noncomputed,
    length_viewport,
    ctx.css_viewport,
    is_root=ctx.element_stack.length() == 0,
    stylesheets=ctx.stylesheets,
    sample_time_seconds=ctx.sample_time_seconds,
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
  root_font_size : Double,
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
    root_font_size,
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
fn SVGParseContext::current_length_viewport(
  self : SVGParseContext,
) -> (Double, Double)? {
  if self.length_viewport_stack.length() == 0 {
    None
  } else {
    Some(self.length_viewport_stack[self.length_viewport_stack.length() - 1])
  }
}

///|
fn SVGParser::new(events : Array[SVGXmlEvent]) -> SVGParser {
  { events, pos: 0 }
}

///|
fn SVGParser::is_end(self : SVGParser) -> Bool {
  self.pos >= self.events.length() || self.events[self.pos] is XmlEof
}

///|
fn SVGParser::peek_event(self : SVGParser) -> SVGXmlEvent {
  if self.pos < self.events.length() {
    self.events[self.pos]
  } else {
    XmlEof
  }
}

///|
fn SVGParser::advance_event(self : SVGParser) -> SVGXmlEvent {
  if self.pos < self.events.length() {
    let event = self.events[self.pos]
    self.pos += 1
    event
  } else {
    XmlEof
  }
}

///|
let svg_namespace_uri = "http://www.w3.org/2000/svg"

///|
let xml_namespace_uri = "http://www.w3.org/XML/1998/namespace"

///|
let xlink_namespace_uri = "http://www.w3.org/1999/xlink"

///|
let xlink_href_attribute_name : String = "{" + xlink_namespace_uri + "}href"

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
fn XmlNamespaceScope::normalize_attribute_name(
  self : XmlNamespaceScope,
  qualified_name : String,
) -> String {
  if qualified_name == "xmlns" || qualified_name.has_prefix("xmlns:") {
    return qualified_name
  }
  match qualified_name.find(":") {
    None => qualified_name
    Some(index) => {
      let prefix = qualified_name[:index].to_owned()
      let local_name = qualified_name[index + 1:].to_owned()
      match self.prefixes.get(prefix) {
        Some(uri) => "{" + uri + "}" + local_name
        None => "{unbound-prefix}" + local_name
      }
    }
  }
}

///|
fn XmlNamespaceScope::normalize_attributes(
  self : XmlNamespaceScope,
  attrs : Array[(String, String)],
) -> Array[(String, String)] {
  attrs.map(fn(attr) { (self.normalize_attribute_name(attr.0), attr.1) })
}

///|
fn normalize_xml_namespaces(events : Array[SVGXmlEvent]) -> Array[SVGXmlEvent] {
  let normalized : Array[SVGXmlEvent] = []
  let scopes : Array[XmlNamespaceScope] = [XmlNamespaceScope::root()]
  for event in events {
    let current = scopes[scopes.length() - 1]
    match event {
      XmlStart(element) => {
        let scope = current.with_declarations(element.attributes)
        normalized.push(
          XmlStart({
            name: scope.normalize_element_name(element.name),
            attributes: scope.normalize_attributes(element.attributes),
          }),
        )
        scopes.push(scope)
      }
      XmlEmpty(element) => {
        let scope = current.with_declarations(element.attributes)
        normalized.push(
          XmlEmpty({
            name: scope.normalize_element_name(element.name),
            attributes: scope.normalize_attributes(element.attributes),
          }),
        )
      }
      XmlEnd(name) => {
        normalized.push(XmlEnd(current.normalize_element_name(name)))
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
fn read_xml_events(svg_str : String) -> Array[SVGXmlEvent]? {
  let reader = @xml.Reader::from_string(svg_str)
  try {
    let events : Array[SVGXmlEvent] = []
    while true {
      let event = adapt_xml_event(reader.read_event())
      events.push(event)
      if event is XmlEof {
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
  parse_svg_document_in_viewport(svg_str, 300.0, 150.0)
}

///|
fn parse_svg_document_in_viewport(
  svg_str : String,
  viewport_width : Double,
  viewport_height : Double,
) -> SVGDocument? {
  parse_svg_document_in_environment(
    svg_str,
    viewport_width,
    viewport_height,
    RenderEnvironment::default(),
  )
}

///|
fn parse_svg_document_in_environment(
  svg_str : String,
  viewport_width : Double,
  viewport_height : Double,
  environment : RenderEnvironment,
) -> SVGDocument? {
  parse_svg_document_with_options(
    svg_str,
    viewport_width,
    viewport_height,
    { ..RenderOptions::default(), environment, },
    [],
  )
}

///|
fn parse_svg_document_with_options(
  svg_str : String,
  viewport_width : Double,
  viewport_height : Double,
  options : RenderOptions,
  diagnostics : Array[RenderDiagnostic],
) -> SVGDocument? {
  let state = TextResourceLoadState::new(
    options, diagnostics, viewport_width, viewport_height,
  )
  parse_svg_document_with_state(
    svg_str,
    viewport_width,
    viewport_height,
    options,
    state,
    options.environment.base_uri,
  )
}

///|
fn parse_svg_document_with_state(
  svg_str : String,
  viewport_width : Double,
  viewport_height : Double,
  options : RenderOptions,
  resource_state : TextResourceLoadState,
  base_uri : String,
) -> SVGDocument? {
  let raw_events = match read_xml_events(svg_str) {
    Some(events) => events
    None => return None
  }
  let events = canonicalize_svg_reference_events(raw_events, base_uri)
  let parser = SVGParser::new(events)
  let stylesheets = load_document_stylesheets(events, resource_state, base_uri)
  let ctx = SVGParseContext::new(
    stylesheets,
    initial_length_viewport=(viewport_width, viewport_height),
    environment=options.environment,
  )
  for uri in collect_external_document_uris(events, stylesheets) {
    match
      resource_state.load_svg_document(uri, viewport_width, viewport_height) {
      Some(document) => merge_external_document(ctx, document, uri)
      None => ()
    }
  }
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
  let mut element : SVGXmlElement? = None
  let mut self_closing = false
  while !parser.is_end() && element is None {
    match parser.advance_event() {
      XmlStart(found) => element = Some(found)
      XmlEmpty(found) => {
        element = Some(found)
        self_closing = true
      }
      XmlEnd(_) | XmlEof => return None
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
      } else {
        register_filter_graph(attrs, ctx, [])
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
          let node = SVGNode::new(Text(x=0.0, y=0.0, text~, font_size=16.0))
          apply_attributes(node, attrs)
          let computed_style = resolve_element_computed_style(
            node,
            tag_name,
            attrs,
            ctx,
            ctx.current_style(),
            true,
          )
          let viewport = ctx.current_length_viewport().unwrap_or((300.0, 150.0))
          let length_context = LengthContext::new(
            viewport.0,
            viewport.1,
            font_size=computed_style.css_style.font_size,
            root_font_size=computed_style.root_font_size,
            css_viewport_width=ctx.css_viewport.0,
            css_viewport_height=ctx.css_viewport.1,
          )
          let x = get_attr(attrs, "x")
            .map(fn(value) {
              parse_length_with_context(value, Horizontal, length_context)
            })
            .unwrap_or(0.0)
          let y = get_attr(attrs, "y")
            .map(fn(value) {
              parse_length_with_context(value, Vertical, length_context)
            })
            .unwrap_or(0.0)
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
      let parent_length_viewport = ctx
        .current_length_viewport()
        .unwrap_or((300.0, 150.0))
      let element_length_context = LengthContext::new(
        parent_length_viewport.0,
        parent_length_viewport.1,
        font_size=computed_style.css_style.font_size,
        root_font_size=computed_style.root_font_size,
        css_viewport_width=ctx.css_viewport.0,
        css_viewport_height=ctx.css_viewport.1,
      )
      let element_declarations = cascaded_style_declarations(
        ctx.cascaded_style(tag_name, attrs),
      )
      fn geometry_value(name : String) -> String? {
        resolved_element_noncomputed_value(
          attrs,
          element_declarations,
          computed_style.custom_properties,
          name,
        )
      }
      if tag_name == "svg" {
        if parent_tag != "" {
          if geometry_value("width") is Some(v) {
            node.viewport_width = Some(
              parse_length_with_context(v, Horizontal, element_length_context),
            )
          }
          if geometry_value("height") is Some(v) {
            node.viewport_height = Some(
              parse_length_with_context(v, Vertical, element_length_context),
            )
          }
        }
        if get_attr(attrs, "overflow") is Some(v) {
          if trim_string(v) == "visible" {
            node.clip_overflow = false
          }
        }
        let x = match geometry_value("x") {
          Some(v) =>
            parse_length_with_context(v, Horizontal, element_length_context)
          None => 0.0
        }
        let y = match geometry_value("y") {
          Some(v) =>
            parse_length_with_context(v, Vertical, element_length_context)
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
            geometry_value("width")
            .map(fn(value) {
              parse_length_with_context(
                value,
                Horizontal,
                element_length_context,
              )
            })
            .unwrap_or(parent_length_viewport.0),
          ),
          node.viewport_height.unwrap_or(
            geometry_value("height")
            .map(fn(value) {
              parse_length_with_context(value, Vertical, element_length_context)
            })
            .unwrap_or(parent_length_viewport.1),
          ),
        )
        ctx.viewport_stack.push(viewport)
        let child_length_viewport = match node.view_box {
          Some(view_box) => (view_box.width, view_box.height)
          None =>
            (
              node.viewport_width.unwrap_or(viewport.0),
              node.viewport_height.unwrap_or(viewport.1),
            )
        }
        ctx.length_viewport_stack.push(child_length_viewport)
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
        let _ = ctx.length_viewport_stack.pop()
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
      XmlStart(_) => depth += 1
      XmlEmpty(_) => ()
      XmlEnd(name) => {
        if depth == 0 && name == tag_name {
          return
        }
        if depth > 0 {
          depth -= 1
        }
      }
      XmlEof => return
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
      XmlText(text) | XmlCData(text) => content.write_string(text)
      XmlStart(element) => {
        has_nested_element = true
        skip_to_end_tag(parser, element.name)
      }
      XmlEmpty(_) => has_nested_element = true
      XmlEnd(name) =>
        if name == tag_name {
          return if has_nested_element {
            None
          } else {
            Some(content.to_string())
          }
        }
      XmlEof => return None
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
      XmlStart(_) => {
        if depth == 0 {
          count += 1
        }
        depth += 1
      }
      XmlEmpty(_) => if depth == 0 { count += 1 }
      XmlEnd(name) => {
        if depth == 0 && name == parent_tag {
          break
        }
        if depth > 0 {
          depth -= 1
        }
      }
      XmlEof => break
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
      XmlEnd(name) => {
        let _ = parser.advance_event()
        if name == parent_tag {
          break
        }
      }
      XmlStart(_) | XmlEmpty(_) => {
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
      XmlEof => break
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
