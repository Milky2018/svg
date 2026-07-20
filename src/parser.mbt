///|
/// SVG XML Parser
/// Parses SVG markup into SVGNode tree

///|
/// SVG Parser state
priv struct SVGParser {
  data : String
  mut pos : Int
  len : Int
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
  fill_opacity : Double
  stroke : StrokeStyle
  stroke_opacity : Double
  color : Color
  paint_order : PaintOrder
  marker_start : String?
  marker_mid : String?
  marker_end : String?
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
    fill_opacity: 1.0,
    stroke: StrokeStyle::default(),
    stroke_opacity: 1.0,
    color: Color::black(),
    paint_order: PaintOrder::default(),
    marker_start: None,
    marker_mid: None,
    marker_end: None,
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
    fill_opacity: node.fill_opacity,
    stroke: node.stroke,
    stroke_opacity: node.stroke_opacity,
    color: node.color.unwrap_or(Color::black()),
    paint_order: node.paint_order,
    marker_start: node.marker_start,
    marker_mid: node.marker_mid,
    marker_end: node.marker_end,
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
fn SVGParser::new(data : String) -> SVGParser {
  { data, pos: 0, len: data.length() }
}

///|
fn SVGParser::is_end(self : SVGParser) -> Bool {
  self.pos >= self.len
}

///|
fn SVGParser::peek(self : SVGParser) -> Char {
  if self.pos < self.len {
    Int::unsafe_to_char(self.data[self.pos].to_int())
  } else {
    '\u0000'
  }
}

///|
fn SVGParser::advance(self : SVGParser) -> Char {
  if self.pos < self.len {
    let c = Int::unsafe_to_char(self.data[self.pos].to_int())
    self.pos = self.pos + 1
    c
  } else {
    '\u0000'
  }
}

///|
fn SVGParser::skip_whitespace(self : SVGParser) -> Unit {
  while !self.is_end() {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      let _ = self.advance()
    } else {
      break
    }
  }
}

///|
fn SVGParser::expect_char(self : SVGParser, expected : Char) -> Bool {
  if self.peek() == expected {
    let _ = self.advance()
    true
  } else {
    false
  }
}

///|
fn SVGParser::read_until(self : SVGParser, stop : Char) -> String {
  let buf = StringBuilder::new()
  while !self.is_end() && self.peek() != stop {
    buf.write_char(self.advance())
  }
  buf.to_string()
}

///|
fn SVGParser::read_name(self : SVGParser) -> String {
  let buf = StringBuilder::new()
  while !self.is_end() {
    let c = self.peek()
    if is_name_char(c) {
      buf.write_char(self.advance())
    } else {
      break
    }
  }
  buf.to_string()
}

///|
fn is_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':'
}

///|
fn SVGParser::read_attr_value(self : SVGParser) -> String {
  self.skip_whitespace()
  if !self.expect_char('=') {
    return ""
  }
  self.skip_whitespace()
  let quote = self.peek()
  if quote != '"' && quote != '\'' {
    return ""
  }
  let _ = self.advance()
  let value = self.read_until(quote)
  let _ = self.advance() // Skip closing quote
  value
}

///|
/// Parse SVG markup string into SVGNode
pub fn parse_svg(svg_str : String) -> SVGNode? {
  match parse_svg_document(svg_str) {
    Some(doc) => Some(doc.root)
    None => None
  }
}

///|
/// Parse SVG markup string into SVGDocument with resources
pub fn parse_svg_document(svg_str : String) -> SVGDocument? {
  let parser = SVGParser::new(svg_str)
  let ctx = SVGParseContext::new(parse_embedded_stylesheets(svg_str))
  match parse_element(parser, ctx, "") {
    Some(root) =>
      Some({
        root,
        symbols: ctx.symbols,
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
  parser.skip_whitespace()
  // Skip comments and declarations
  while !parser.is_end() {
    if parser.peek() == '<' {
      let _ = parser.advance()
      if parser.peek() == '!' || parser.peek() == '?' {
        // Skip comment or declaration
        skip_comment_or_decl(parser)
        parser.skip_whitespace()
        continue
      }
      break
    } else {
      let _ = parser.advance()
    }
  }
  if parser.is_end() {
    return None
  }
  // Read tag name
  let tag_name = parser.read_name()
  if tag_name.length() == 0 {
    return None
  }
  // Parse attributes (raw)
  let attrs = parse_attributes(parser)
  let _ = ctx.record_selector_element(tag_name, attrs)
  parser.skip_whitespace()
  // Check for self-closing tag
  let mut self_closing = false
  if parser.peek() == '/' {
    let _ = parser.advance()
    let _ = parser.expect_char('>')
    self_closing = true
  } else {
    // Expect closing '>'
    let _ = parser.expect_char('>')
  }
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
fn skip_comment_or_decl(parser : SVGParser) -> Unit {
  // Skip until we find '>'
  while !parser.is_end() {
    if parser.advance() == '>' {
      break
    }
  }
}

///|
fn skip_to_end_tag(parser : SVGParser, _tag_name : String) -> Unit {
  // Skip until we find the closing tag
  while !parser.is_end() {
    if parser.peek() == '<' {
      let _ = parser.advance()
      if parser.peek() == '/' {
        let _ = parser.advance()
        let _ = parser.read_name() // Read the tag name
        parser.skip_whitespace()
        let _ = parser.expect_char('>')
        break
      }
    } else {
      let _ = parser.advance()
    }
  }
}

///|
fn xml_digit_value(c : Char, radix : Int) -> Int {
  let value = if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
  if value < radix {
    value
  } else {
    -1
  }
}

///|
fn parse_xml_character_reference(value : String) -> Char? {
  if value.length() < 2 || value[0] != '#' {
    return None
  }
  let hexadecimal = value.length() > 2 && (value[1] == 'x' || value[1] == 'X')
  let start = if hexadecimal { 2 } else { 1 }
  let radix = if hexadecimal { 16 } else { 10 }
  if start >= value.length() {
    return None
  }
  let mut codepoint = 0
  for i in start..<value.length() {
    let digit = xml_digit_value(Int::unsafe_to_char(value[i].to_int()), radix)
    if digit < 0 {
      return None
    }
    codepoint = codepoint * radix + digit
  }
  Some(Int::unsafe_to_char(codepoint))
}

///|
fn decode_xml_text(value : String) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < value.length() {
    if value[i] != '&' {
      result.write_char(Int::unsafe_to_char(value[i].to_int()))
      i += 1
      continue
    }
    let semicolon = find_substring_from(value, ";", i + 1)
    if semicolon < 0 {
      result.write_char('&')
      i += 1
      continue
    }
    let entity = build_substring(value, i + 1, semicolon)
    let decoded : Char? = match entity {
      "amp" => Some('&')
      "lt" => Some('<')
      "gt" => Some('>')
      "quot" => Some('"')
      "apos" => Some('\'')
      _ => parse_xml_character_reference(entity)
    }
    match decoded {
      Some(character) => {
        result.write_char(character)
        i = semicolon + 1
      }
      None => {
        result.write_char('&')
        i += 1
      }
    }
  }
  result.to_string()
}

///|
fn parse_plain_text_content(parser : SVGParser, tag_name : String) -> String? {
  let close = find_substring_from(parser.data, "</" + tag_name, parser.pos)
  if close < 0 {
    parser.pos = parser.len
    return None
  }
  let raw = build_substring(parser.data, parser.pos, close)
  let close_end = find_substring_from(
    parser.data,
    ">",
    close + tag_name.length() + 2,
  )
  parser.pos = if close_end < 0 { parser.len } else { close_end + 1 }
  if raw.contains("<") {
    None
  } else {
    Some(decode_xml_text(raw))
  }
}

///|
fn count_direct_child_elements(parser : SVGParser, parent_tag : String) -> Int {
  let probe : SVGParser = {
    data: parser.data,
    pos: parser.pos,
    len: parser.len,
  }
  let mut depth = 0
  let mut count = 0
  while !probe.is_end() {
    while !probe.is_end() && probe.peek() != '<' {
      let _ = probe.advance()
    }
    if probe.is_end() {
      break
    }
    let open = probe.pos
    let _ = probe.advance()
    if substring_starts_at(probe.data, "!--", probe.pos) {
      let close = find_substring_from(probe.data, "-->", probe.pos + 3)
      if close < 0 {
        break
      }
      probe.pos = close + 3
      continue
    }
    if substring_starts_at(probe.data, "![CDATA[", probe.pos) {
      let close = find_substring_from(probe.data, "]]>", probe.pos + 8)
      if close < 0 {
        break
      }
      probe.pos = close + 3
      continue
    }
    if probe.peek() == '!' || probe.peek() == '?' {
      skip_comment_or_decl(probe)
      continue
    }
    if probe.peek() == '/' {
      let _ = probe.advance()
      let end_tag = probe.read_name()
      while !probe.is_end() && probe.advance() != '>' {

      }
      if depth == 0 && end_tag == parent_tag {
        break
      }
      if depth > 0 {
        depth -= 1
      }
      continue
    }
    let tag = probe.read_name()
    if tag.length() == 0 {
      probe.pos = open + 1
      continue
    }
    let _ = parse_attributes(probe)
    probe.skip_whitespace()
    let self_closing = probe.peek() == '/'
    if self_closing {
      let _ = probe.advance()
    }
    let _ = probe.expect_char('>')
    if depth == 0 {
      count += 1
    }
    if !self_closing {
      depth += 1
    }
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
    parser.skip_whitespace()
    if parser.peek() != '<' {
      // Skip text content
      while !parser.is_end() && parser.peek() != '<' {
        let _ = parser.advance()
      }
      continue
    }
    let _ = parser.advance()
    // Check for end tag
    if parser.peek() == '/' {
      let _ = parser.advance()
      let end_tag = parser.read_name()
      if end_tag == parent_tag {
        parser.skip_whitespace()
        let _ = parser.expect_char('>')
        break
      }
      // Skip malformed end tag
      while !parser.is_end() && parser.advance() != '>' {

      }
      continue
    }
    // Check for comment/declaration
    if parser.peek() == '!' || parser.peek() == '?' {
      skip_comment_or_decl(parser)
      continue
    }
    // Parse child element
    let current_index = ctx.sibling_index_stack.length() - 1
    ctx.sibling_index_stack[current_index] += 1
    // Backtrack the '<' we consumed
    parser.pos = parser.pos - 1
    match parse_element(parser, ctx, parent_tag) {
      Some(child) => {
        let child_depth = ctx.element_stack.length()
        if child_depth < ctx.selector_element_slots.length() {
          ctx.previous_sibling_stack[current_index] = ctx.selector_element_slots[child_depth]
        }
        let child_node = child
        apply_inherited_markers(child_node, parent)
        parent.children.push(child_node)
        if child_node.id.length() > 0 {
          ctx.defs.add(child_node.id, child_node)
        }
      }
      None => break
    }
  }
  let _ = ctx.previous_sibling_stack.pop()
  let _ = ctx.sibling_count_stack.pop()
  let _ = ctx.sibling_index_stack.pop()
  let _ = ctx.style_stack.pop()
  let _ = ctx.element_stack.pop()
}

///|
fn create_node_for_tag(tag_name : String) -> SVGNode {
  let node = match tag_name {
    "rect" =>
      SVGNode::new(Rect(x=0.0, y=0.0, width=0.0, height=0.0, rx=0.0, ry=0.0))
    "circle" => SVGNode::new(Circle(cx=0.0, cy=0.0, r=0.0))
    "ellipse" => SVGNode::new(Ellipse(cx=0.0, cy=0.0, rx=0.0, ry=0.0))
    "line" => SVGNode::new(Line(x1=0.0, y1=0.0, x2=0.0, y2=0.0))
    "polyline" => SVGNode::new(Polyline(points=[]))
    "polygon" => SVGNode::new(Polygon(points=[]))
    "path" => SVGNode::new(Path(commands=[]))
    _ => SVGNode::new(Group) // svg, g, defs, etc. are groups
  }
  node
}

///|
fn parse_attributes(parser : SVGParser) -> Array[(String, String)] {
  let attrs : Array[(String, String)] = []
  while !parser.is_end() {
    parser.skip_whitespace()
    let c = parser.peek()
    if c == '>' || c == '/' {
      break
    }
    let attr_name = parser.read_name()
    if attr_name.length() == 0 {
      break
    }
    let attr_value = parser.read_attr_value()
    attrs.push((attr_name, attr_value))
  }
  attrs
}

///|
fn apply_attributes(node : SVGNode, attrs : Array[(String, String)]) -> Unit {
  for attr in attrs {
    if attr.0 != "style" {
      apply_presentation_attribute(node, attr.0, attr.1)
    }
  }
  for attr in attrs {
    if attr.0 == "style" {
      apply_style_attributes(node, attr.1)
    }
  }
  match node.shape {
    Rect(..) as rect => {
      let has_rx = get_attr(attrs, "rx") is Some(_)
      let has_ry = get_attr(attrs, "ry") is Some(_)
      if has_rx && !has_ry {
        node.shape = Rect(
          x=rect.x,
          y=rect.y,
          width=rect.width,
          height=rect.height,
          rx=rect.rx,
          ry=rect.rx,
        )
      } else if has_ry && !has_rx {
        node.shape = Rect(
          x=rect.x,
          y=rect.y,
          width=rect.width,
          height=rect.height,
          rx=rect.ry,
          ry=rect.ry,
        )
      }
    }
    _ => ()
  }
}

///|
fn apply_attribute(node : SVGNode, name : String, value : String) -> Unit {
  match name {
    "id" => node.id = value
    "style" => apply_style_attributes(node, value)
    "viewBox" => node.view_box = parse_view_box(value)
    "preserveAspectRatio" => {
      node.preserve_aspect_ratio = parse_preserve_aspect_ratio(value)
      node.preserve_aspect_ratio_is_set = true
    }
    "clip-path" =>
      if parse_url_ref(value) is Some(id) {
        node.set_clip_path(id)
      }
    "mask" => if parse_url_ref(value) is Some(id) { node.set_mask(id) }
    "requiredExtensions" => node.opacity = 0.0
    "x" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=parse_length(value),
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=parse_length(value),
            y=i.y,
            width=i.width,
            height=i.height,
            href=i.href,
          )
        _ => ()
      }
    "y" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=parse_length(value),
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=parse_length(value),
            width=i.width,
            height=i.height,
            href=i.href,
          )
        _ => ()
      }
    "width" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=parse_length(value),
            height=r.height,
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=i.y,
            width=parse_length(value),
            height=i.height,
            href=i.href,
          )
        _ => ()
      }
    "height" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=parse_length(value),
            rx=r.rx,
            ry=r.ry,
          )
        Image(..) as i =>
          node.shape = Image(
            x=i.x,
            y=i.y,
            width=i.width,
            height=parse_length(value),
            href=i.href,
          )
        _ => ()
      }
    "rx" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=parse_length(value),
            ry=r.ry,
          )
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=e.cx,
            cy=e.cy,
            rx=parse_length(value),
            ry=e.ry,
          )
        _ => ()
      }
    "ry" =>
      match node.shape {
        Rect(..) as r =>
          node.shape = Rect(
            x=r.x,
            y=r.y,
            width=r.width,
            height=r.height,
            rx=r.rx,
            ry=parse_length(value),
          )
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=e.cx,
            cy=e.cy,
            rx=e.rx,
            ry=parse_length(value),
          )
        _ => ()
      }
    "cx" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=parse_length(value), cy=c.cy, r=c.r)
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=parse_length(value),
            cy=e.cy,
            rx=e.rx,
            ry=e.ry,
          )
        _ => ()
      }
    "cy" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=c.cx, cy=parse_length(value), r=c.r)
        Ellipse(..) as e =>
          node.shape = Ellipse(
            cx=e.cx,
            cy=parse_length(value),
            rx=e.rx,
            ry=e.ry,
          )
        _ => ()
      }
    "r" =>
      match node.shape {
        Circle(..) as c =>
          node.shape = Circle(cx=c.cx, cy=c.cy, r=parse_length(value))
        _ => ()
      }
    "x1" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=parse_length(value), y1=l.y1, x2=l.x2, y2=l.y2)
        _ => ()
      }
    "y1" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=parse_length(value), x2=l.x2, y2=l.y2)
        _ => ()
      }
    "x2" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=l.y1, x2=parse_length(value), y2=l.y2)
        _ => ()
      }
    "y2" =>
      match node.shape {
        Line(..) as l =>
          node.shape = Line(x1=l.x1, y1=l.y1, x2=l.x2, y2=parse_length(value))
        _ => ()
      }
    "d" =>
      match node.shape {
        Path(..) => node.shape = Path(commands=parse_path(value))
        _ => ()
      }
    "points" =>
      match node.shape {
        Polyline(..) => node.shape = Polyline(points=parse_points(value))
        Polygon(..) => node.shape = Polygon(points=parse_points(value))
        _ => ()
      }
    "fill" => {
      node.fill = parse_paint(value)
      node.fill_is_set = true
    }
    "color" => {
      node.color = Some(parse_color(value))
      node.color_is_set = true
    }
    "paint-order" => node.paint_order = parse_paint_order(value)
    "stroke" => {
      node.stroke = {
        paint: parse_paint(value),
        width: node.stroke.width,
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
      node.stroke_paint_is_set = true
    }
    "stroke-width" => {
      node.stroke_width_is_set = true
      node.stroke = {
        paint: node.stroke.paint,
        width: parse_length(value),
        linecap: node.stroke.linecap,
        linejoin: node.stroke.linejoin,
        miterlimit: node.stroke.miterlimit,
        dasharray: node.stroke.dasharray,
        dashoffset: node.stroke.dashoffset,
      }
    }
    "opacity" => node.opacity = parse_number(value)
    "fill-opacity" => node.fill_opacity = parse_number(value)
    "stroke-opacity" => node.stroke_opacity = parse_number(value)
    "filter" => node.filter_graph_id = parse_url_ref(value)
    "mix-blend-mode" => node.blend_mode = parse_blend_mode(value)
    "isolation" => node.isolation = parse_isolation(value)
    "transform" => node.transform = parse_transform(value)
    // Stroke detail attributes
    "stroke-linecap" =>
      node.stroke = { ..node.stroke, linecap: parse_linecap(value) }
    "stroke-linejoin" =>
      node.stroke = { ..node.stroke, linejoin: parse_linejoin(value) }
    "stroke-miterlimit" =>
      node.stroke = { ..node.stroke, miterlimit: parse_number(value) }
    "stroke-dasharray" =>
      node.stroke = { ..node.stroke, dasharray: parse_dasharray(value) }
    "stroke-dashoffset" =>
      node.stroke = { ..node.stroke, dashoffset: parse_number(value) }
    "marker-start" => {
      node.marker_start = parse_marker_ref(value)
      node.marker_start_is_set = true
    }
    "marker-mid" => {
      node.marker_mid = parse_marker_ref(value)
      node.marker_mid_is_set = true
    }
    "marker-end" => {
      node.marker_end = parse_marker_ref(value)
      node.marker_end_is_set = true
    }
    "marker" =>
      match parse_marker_ref(value) {
        Some(id) => {
          node.marker_start = Some(id)
          node.marker_mid = Some(id)
          node.marker_end = Some(id)
          node.marker_start_is_set = true
          node.marker_mid_is_set = true
          node.marker_end_is_set = true
        }
        None => {
          node.marker_start = None
          node.marker_mid = None
          node.marker_end = None
          node.marker_start_is_set = true
          node.marker_mid_is_set = true
          node.marker_end_is_set = true
        }
      }
    // Fill rule
    "fill-rule" => node.fill_rule = parse_fill_rule(value)
    "clip-rule" => node.fill_rule = parse_fill_rule(value)
    _ => () // Ignore unknown attributes
  }
}

///|
fn parse_blend_mode(value : String) -> BlendMode {
  match trim_string(value).to_lower() {
    "multiply" => Multiply
    "screen" => Screen
    "overlay" => Overlay
    "darken" => Darken
    "lighten" => Lighten
    "color-dodge" => ColorDodge
    "color-burn" => ColorBurn
    "hard-light" => HardLight
    "soft-light" => SoftLight
    "difference" => Difference
    "exclusion" => Exclusion
    "hue" => Hue
    "saturation" => Saturation
    "color" => ColorMode
    "luminosity" => Luminosity
    _ => Normal
  }
}

///|
fn parse_isolation(value : String) -> Isolation {
  if trim_string(value).to_lower() == "isolate" {
    Isolate
  } else {
    Auto
  }
}

///|
fn apply_presentation_attribute(
  node : SVGNode,
  name : String,
  value : String,
) -> Unit {
  if name == "marker" {
    return
  }
  apply_attribute(node, name, value)
}

///|
fn parse_marker_ref(value : String) -> String? {
  let v = trim_string(value)
  if v.length() == 0 || v == "none" {
    return None
  }
  parse_url_ref(v)
}

///|
fn apply_style_attributes(node : SVGNode, value : String) -> Unit {
  let declarations = parse_inline_style_declarations(value)
  for declaration in declarations {
    let name = declaration.name
    let winner = find_winning_declaration(declarations, name)
    if name == "style" || is_custom_property(name) {
      continue
    }
    match winner {
      Some(_) => apply_attribute(node, name, declaration.value)
      _ => ()
    }
  }
}

///|
fn apply_style_attributes_filtered(node : SVGNode, value : String) -> Unit {
  let declarations = parse_inline_style_declarations(value)
  for declaration in declarations {
    let name = declaration.name
    let winner = find_winning_declaration(declarations, name)
    if name == "style" ||
      is_custom_property(name) ||
      name == "transform" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" {
      continue
    }
    match winner {
      Some(_) => apply_attribute(node, name, declaration.value)
      _ => ()
    }
  }
}

///|
fn apply_presentation_attributes(
  node : SVGNode,
  attrs : Array[(String, String)],
) -> Unit {
  for attr in attrs {
    let name = attr.0
    if name == "id" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href" ||
      name == "xlink:href" ||
      name == "transform" ||
      name == "style" {
      continue
    }
    apply_presentation_attribute(node, name, attr.1)
  }
  for attr in attrs {
    if attr.0 == "style" {
      apply_style_attributes_filtered(node, attr.1)
    }
  }
}

///|
fn apply_paint_order_recursive(node : SVGNode, order : PaintOrder) -> Unit {
  node.paint_order = order
  for child in node.children {
    apply_paint_order_recursive(child, order)
  }
}

///|
fn get_attr(attrs : Array[(String, String)], name : String) -> String? {
  for attr in attrs {
    if attr.0 == name {
      return Some(attr.1)
    }
  }
  None
}

///|
fn parse_url_ref(value : String) -> String? {
  let v = trim_string(value)
  if v.length() == 0 {
    return None
  }
  if string_starts_with(v, "url(") && string_ends_with(v, ")") {
    let inner = build_substring(v, 4, v.length() - 1)
    let trimmed = trim_string(inner)
    if trimmed.length() > 0 && Int::unsafe_to_char(trimmed[0].to_int()) == '#' {
      return Some(build_substring(trimmed, 1, trimmed.length()))
    }
    return Some(trimmed)
  }
  if Int::unsafe_to_char(v[0].to_int()) == '#' {
    return Some(build_substring(v, 1, v.length()))
  }
  None
}

///|
fn parse_number_list(value : String) -> Array[Double] {
  let nums : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        nums.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    nums.push(parse_number(buf.to_string()))
  }
  nums
}

///|
fn split_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        tokens.push(buf.to_string())
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    tokens.push(buf.to_string())
  }
  tokens
}

///|
fn parse_view_box(value : String) -> ViewBox? {
  let nums = parse_number_list(value)
  if nums.length() < 4 {
    return None
  }
  Some(ViewBox::{
    min_x: nums[0],
    min_y: nums[1],
    width: nums[2],
    height: nums[3],
  })
}

///|
fn parse_preserve_aspect_ratio(value : String) -> PreserveAspectRatio {
  let v = trim_string(value)
  if v.length() == 0 {
    return PreserveAspectRatio::default()
  }
  let tokens = split_tokens(v)
  if tokens.length() == 0 {
    return PreserveAspectRatio::default()
  }
  if tokens[0] == "none" {
    return PreserveAspectRatio::{ align: None, meet_or_slice: Meet }
  }
  let align = match tokens[0] {
    "xMinYMin" => XMinYMin
    "xMidYMin" => XMidYMin
    "xMaxYMin" => XMaxYMin
    "xMinYMid" => XMinYMid
    "xMidYMid" => XMidYMid
    "xMaxYMid" => XMaxYMid
    "xMinYMax" => XMinYMax
    "xMidYMax" => XMidYMax
    "xMaxYMax" => XMaxYMax
    _ => XMidYMid
  }
  let meet_or_slice = if tokens.length() > 1 {
    match tokens[1] {
      "slice" => Slice
      _ => Meet
    }
  } else {
    Meet
  }
  PreserveAspectRatio::{ align, meet_or_slice }
}

///|
fn parse_mask_units(value : String) -> MaskUnits {
  match trim_string(value) {
    "userSpaceOnUse" => MaskUnits::UserSpaceOnUse
    "objectBoundingBox" => MaskUnits::ObjectBoundingBox
    _ => MaskUnits::ObjectBoundingBox
  }
}

///|
fn parse_clip_path_units(value : String) -> ClipPathUnits {
  match trim_string(value) {
    "objectBoundingBox" => ClipPathUnits::ObjectBoundingBox
    _ => ClipPathUnits::UserSpaceOnUse
  }
}

///|
fn parse_mask_type(value : String) -> MaskType {
  match trim_string(value) {
    "alpha" => Alpha
    _ => Luminance
  }
}

///|
fn parse_use(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> SVGNode? {
  let href = match get_attr(attrs, "href") {
    Some(v) => Some(v)
    None => get_attr(attrs, "xlink:href")
  }
  let href = match href {
    Some(v) => v
    None => return None
  }
  let mut x = match get_attr(attrs, "x") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let mut y = match get_attr(attrs, "y") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let mut width = match get_attr(attrs, "width") {
    Some(v) => v |> parse_length |> Some
    None => None
  }
  let mut height = match get_attr(attrs, "height") {
    Some(v) => v |> parse_length |> Some
    None => None
  }
  let mut transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  if get_attr(attrs, "style") is Some(style) {
    if inline_style_value(style, "x") is Some(value) {
      x = parse_length(value)
    }
    if inline_style_value(style, "y") is Some(value) {
      y = parse_length(value)
    }
    if inline_style_value(style, "width") is Some(value) {
      width = value |> parse_length |> Some
    }
    if inline_style_value(style, "height") is Some(value) {
      height = value |> parse_length |> Some
    }
    if inline_style_value(style, "transform") is Some(value) {
      transform = parse_transform(value)
    }
  }
  let use_elem = { ..UseElement::new(href, x, y), width, height, transform }
  let viewport_fallback = ctx.current_viewport()
  let (base_href, frag) = split_href_fragment(use_elem.href)
  let allow_data_url_use = false
  match decode_data_svg(base_href) {
    Some(svg_data) if allow_data_url_use =>
      match parse_svg_document(svg_data) {
        Some(doc) => {
          let node = match frag {
            Some(id) =>
              match find_node_by_id(doc.root, id) {
                Some(found) => found.clone()
                None => return None
              }
            None => doc.root.clone()
          }
          let (vb, force_non_uniform) = match node.view_box {
            Some(vb) => (Some(vb), false)
            None =>
              match (node.viewport_width, node.viewport_height) {
                (Some(w), Some(h)) =>
                  (
                    Some(ViewBox::{
                      min_x: 0.0,
                      min_y: 0.0,
                      width: w,
                      height: h,
                    }),
                    true,
                  )
                _ =>
                  match viewport_fallback {
                    Some((vw, vh)) =>
                      (
                        Some(ViewBox::{
                          min_x: 0.0,
                          min_y: 0.0,
                          width: vw,
                          height: vh,
                        }),
                        true,
                      )
                    None => (None, false)
                  }
              }
          }
          if force_non_uniform {
            node.preserve_aspect_ratio = PreserveAspectRatio::{
              align: None,
              meet_or_slice: Meet,
            }
          }
          let vw = match use_elem.width {
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
          let vh = match use_elem.height {
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
          let translate = Transform::translate(use_elem.x, use_elem.y)
          let base = use_elem.transform.multiply(translate)
          node.transform = base.multiply(node.transform)
          node.id = get_attr(attrs, "id").unwrap_or("")
          apply_presentation_attributes(node, attrs)
          let base_style = inherited_style_from_node(
            node,
            ctx.current_style().css_style,
            ctx.current_style().custom_properties,
            ctx.current_style().stop_color,
            ctx.current_style().stop_opacity,
          )
          let _ = resolve_element_computed_style(
            node, "use", attrs, ctx, base_style, false,
          )
          if element_style_property_is_declared(
              "use", attrs, ctx, "paint-order",
            ) {
            apply_paint_order_recursive(node, node.paint_order)
          }
          Some(node)
        }
        None => None
      }
    _ =>
      match use_elem.instantiate(ctx.symbols) {
        Some(node) => {
          if viewport_fallback is Some((vw, vh)) {
            if node.viewport_width is None {
              node.viewport_width = Some(vw)
            }
            if node.viewport_height is None {
              node.viewport_height = Some(vh)
            }
            if node.view_box is None &&
              node.viewport_width is Some(_) &&
              node.viewport_height is Some(_) {
              node.view_box = Some(ViewBox::{
                min_x: 0.0,
                min_y: 0.0,
                width: node.viewport_width.unwrap(),
                height: node.viewport_height.unwrap(),
              })
              node.preserve_aspect_ratio = PreserveAspectRatio::{
                align: None,
                meet_or_slice: Meet,
              }
            }
          }
          node.id = get_attr(attrs, "id").unwrap_or("")
          apply_presentation_attributes(node, attrs)
          let base_style = inherited_style_from_node(
            node,
            ctx.current_style().css_style,
            ctx.current_style().custom_properties,
            ctx.current_style().stop_color,
            ctx.current_style().stop_opacity,
          )
          let _ = resolve_element_computed_style(
            node, "use", attrs, ctx, base_style, false,
          )
          if element_style_property_is_declared(
              "use", attrs, ctx, "paint-order",
            ) {
            apply_paint_order_recursive(node, node.paint_order)
          }
          Some(node)
        }
        None => {
          let id = use_elem.get_id()
          match ctx.defs.get(id) {
            Some(target) => {
              let node = target.clone()
              let (vb, force_non_uniform) = match node.view_box {
                Some(vb) => (Some(vb), false)
                None =>
                  match (node.viewport_width, node.viewport_height) {
                    (Some(w), Some(h)) =>
                      (
                        Some(ViewBox::{
                          min_x: 0.0,
                          min_y: 0.0,
                          width: w,
                          height: h,
                        }),
                        true,
                      )
                    _ =>
                      match viewport_fallback {
                        Some((vw, vh)) =>
                          (
                            Some(ViewBox::{
                              min_x: 0.0,
                              min_y: 0.0,
                              width: vw,
                              height: vh,
                            }),
                            true,
                          )
                        None => (None, false)
                      }
                  }
              }
              if force_non_uniform {
                node.preserve_aspect_ratio = PreserveAspectRatio::{
                  align: None,
                  meet_or_slice: Meet,
                }
              }
              let vw = match use_elem.width {
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
              let vh = match use_elem.height {
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
              let translate = Transform::translate(use_elem.x, use_elem.y)
              let base = use_elem.transform.multiply(translate)
              node.transform = base.multiply(node.transform)
              node.id = get_attr(attrs, "id").unwrap_or("")
              apply_presentation_attributes(node, attrs)
              let base_style = inherited_style_from_node(
                node,
                ctx.current_style().css_style,
                ctx.current_style().custom_properties,
                ctx.current_style().stop_color,
                ctx.current_style().stop_opacity,
              )
              let _ = resolve_element_computed_style(
                node, "use", attrs, ctx, base_style, false,
              )
              if element_style_property_is_declared(
                  "use", attrs, ctx, "paint-order",
                ) {
                apply_paint_order_recursive(node, node.paint_order)
              }
              Some(node)
            }
            None => None
          }
        }
      }
  }
}

///|
fn decode_html_entities(value : String) -> String {
  let mut i = 0
  let len = value.length()
  let buf = StringBuilder::new()
  while i < len {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == '&' {
      if i + 3 < len &&
        value[i + 1] == 'l' &&
        value[i + 2] == 't' &&
        value[i + 3] == ';' {
        buf.write_char('<')
        i = i + 4
        continue
      }
      if i + 3 < len &&
        value[i + 1] == 'g' &&
        value[i + 2] == 't' &&
        value[i + 3] == ';' {
        buf.write_char('>')
        i = i + 4
        continue
      }
      if i + 4 < len &&
        value[i + 1] == 'a' &&
        value[i + 2] == 'm' &&
        value[i + 3] == 'p' &&
        value[i + 4] == ';' {
        buf.write_char('&')
        i = i + 5
        continue
      }
      if i + 5 < len &&
        value[i + 1] == 'q' &&
        value[i + 2] == 'u' &&
        value[i + 3] == 'o' &&
        value[i + 4] == 't' &&
        value[i + 5] == ';' {
        buf.write_char('"')
        i = i + 6
        continue
      }
      if i + 5 < len &&
        value[i + 1] == 'a' &&
        value[i + 2] == 'p' &&
        value[i + 3] == 'o' &&
        value[i + 4] == 's' &&
        value[i + 5] == ';' {
        buf.write_char('\'')
        i = i + 6
        continue
      }
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
fn hex_value_local(c : Char) -> Int? {
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
fn decode_percent_local(value : String) -> String {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == '%' && i + 2 < len {
      let c1 = Int::unsafe_to_char(value[i + 1].to_int())
      let c2 = Int::unsafe_to_char(value[i + 2].to_int())
      match (hex_value_local(c1), hex_value_local(c2)) {
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
fn base64_value_local(c : Char) -> Int? {
  if c >= 'A' && c <= 'Z' {
    Some(c.to_int() - 'A'.to_int())
  } else if c >= 'a' && c <= 'z' {
    Some(26 + (c.to_int() - 'a'.to_int()))
  } else if c >= '0' && c <= '9' {
    Some(52 + (c.to_int() - '0'.to_int()))
  } else if c == '+' || c == '-' {
    Some(62)
  } else if c == '/' || c == '_' {
    Some(63)
  } else {
    None
  }
}

///|
fn is_base64_ws_local(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn decode_base64_local(value : String) -> String? {
  let len = value.length()
  let buf = StringBuilder::new()
  let mut q0 = 0
  let mut q1 = 0
  let mut q2 = 0
  let mut q3 = 0
  let mut qlen = 0
  let mut pad = 0
  let mut finished = false
  let mut i = 0
  while i < len {
    let c = Int::unsafe_to_char(value[i].to_int())
    if is_base64_ws_local(c) {
      i = i + 1
      continue
    }
    if finished {
      return None
    }
    let v = if c == '=' {
      pad = pad + 1
      -1
    } else {
      match base64_value_local(c) {
        Some(v) => v
        None => return None
      }
    }
    if qlen == 0 {
      q0 = v
    } else if qlen == 1 {
      q1 = v
    } else if qlen == 2 {
      q2 = v
    } else {
      q3 = v
    }
    qlen = qlen + 1
    if qlen == 4 {
      if q0 < 0 || q1 < 0 {
        return None
      }
      if pad == 0 {
        if q2 < 0 || q3 < 0 {
          return None
        }
        let b0 = (q0 << 2) | (q1 >> 4)
        let b1 = ((q1 & 15) << 4) | (q2 >> 2)
        let b2 = ((q2 & 3) << 6) | q3
        buf.write_char(Int::unsafe_to_char(b0))
        buf.write_char(Int::unsafe_to_char(b1))
        buf.write_char(Int::unsafe_to_char(b2))
      } else if pad == 1 {
        if q2 < 0 || q3 >= 0 {
          return None
        }
        let b0 = (q0 << 2) | (q1 >> 4)
        let b1 = ((q1 & 15) << 4) | (q2 >> 2)
        buf.write_char(Int::unsafe_to_char(b0))
        buf.write_char(Int::unsafe_to_char(b1))
        finished = true
      } else if pad == 2 {
        if q2 >= 0 || q3 >= 0 {
          return None
        }
        let b0 = (q0 << 2) | (q1 >> 4)
        buf.write_char(Int::unsafe_to_char(b0))
        finished = true
      } else {
        return None
      }
      qlen = 0
      pad = 0
    }
    i = i + 1
  }
  if qlen != 0 {
    return None
  }
  Some(buf.to_string())
}

///|
fn decode_data_svg(href : String) -> String? {
  let v = trim_string(href)
  if !string_starts_with(v, "data:image/svg+xml") {
    return None
  }
  let comma = find_first(v, ',')
  if comma < 0 {
    return None
  }
  let meta = build_substring(v, 0, comma)
  let data = build_substring(v, comma + 1, v.length())
  let meta_lower = meta.to_lower()
  let mut has_base64 = false
  let mut start = 0
  for i = 0; i <= meta_lower.length(); i = i + 1 {
    let is_sep = i == meta_lower.length() ||
      Int::unsafe_to_char(meta_lower[i].to_int()) == ';'
    if is_sep {
      let token = trim_string(build_substring(meta_lower, start, i))
      if token == "base64" {
        has_base64 = true
      }
      start = i + 1
    }
  }
  if has_base64 {
    let cleaned = decode_percent_local(data)
    return decode_base64_local(cleaned)
  }
  let decoded = decode_html_entities(data)
  decoded |> decode_percent_local |> Some
}

///|
fn split_href_fragment(href : String) -> (String, String?) {
  let idx = find_first(href, '#')
  if idx < 0 {
    (href, None)
  } else {
    let base = build_substring(href, 0, idx)
    let frag = build_substring(href, idx + 1, href.length())
    (base, frag |> decode_percent_local |> Some)
  }
}

///|
fn find_node_by_id(node : SVGNode, id : String) -> SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    if find_node_by_id(child, id) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
fn parse_image(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> SVGNode? {
  let href = match get_attr(attrs, "href") {
    Some(v) => Some(v)
    None => get_attr(attrs, "xlink:href")
  }
  let href = match href {
    Some(v) => v
    None => return None
  }
  let x = match get_attr(attrs, "x") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let y = match get_attr(attrs, "y") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let mut width = match get_attr(attrs, "width") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  let mut height = match get_attr(attrs, "height") {
    Some(v) => parse_length(v)
    None => 0.0
  }
  if height <= 0.0 && width > 0.0 {
    height = width
  }
  if width <= 0.0 && height > 0.0 {
    width = height
  }
  let node = SVGNode::new(Image(x~, y~, width~, height~, href~))
  apply_attributes(node, attrs)
  let _ = resolve_element_computed_style(
    node,
    "image",
    attrs,
    ctx,
    ctx.current_style(),
    true,
  )
  match node.shape {
    Image(..) as img =>
      node.shape = Image(
        x=img.x,
        y=img.y,
        width=img.width,
        height=img.height,
        href~,
      )
    _ => ()
  }
  Some(node)
}

///|
fn parse_clip_path_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let clip_rule = match get_attr(attrs, "clip-rule") {
    Some(v) => parse_fill_rule(v)
    None => NonZero
  }
  let transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let units = match get_attr(attrs, "clipPathUnits") {
    Some(v) => parse_clip_path_units(v)
    None => ClipPathUnits::UserSpaceOnUse
  }
  let clip = ClipPath::{
    id,
    shape: Group,
    content: [],
    transform,
    clip_rule,
    units,
  }
  ctx.clips.add(clip)
}

///|
fn parse_clip_path(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
) -> Unit {
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
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let clip_rule = match get_attr(attrs, "clip-rule") {
    Some(v) => parse_fill_rule(v)
    None => NonZero
  }
  let transform = match get_attr(attrs, "transform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let units = match get_attr(attrs, "clipPathUnits") {
    Some(v) => parse_clip_path_units(v)
    None => ClipPathUnits::UserSpaceOnUse
  }
  let mut shape : Shape = Group
  for child in temp.children {
    match child.shape {
      Group => ()
      _ => {
        shape = child.shape
        break
      }
    }
  }
  let clip = ClipPath::{
    id,
    shape,
    content: temp.children,
    transform,
    clip_rule,
    units,
  }
  ctx.clips.add(clip)
}

///|
fn parse_filter_matrix(value : String) -> FixedArray[Double]? {
  let numbers = parse_number_list(value)
  if numbers.length() != 20 {
    return None
  }
  Some([
    numbers[0],
    numbers[1],
    numbers[2],
    numbers[3],
    numbers[4],
    numbers[5],
    numbers[6],
    numbers[7],
    numbers[8],
    numbers[9],
    numbers[10],
    numbers[11],
    numbers[12],
    numbers[13],
    numbers[14],
    numbers[15],
    numbers[16],
    numbers[17],
    numbers[18],
    numbers[19],
  ])
}

///|
fn parse_filter_primitive(
  tag : String,
  attrs : Array[(String, String)],
) -> FilterGraphPrimitive? {
  let input = get_attr(attrs, "in").unwrap_or("")
  let result = get_attr(attrs, "result").unwrap_or("")
  match tag {
    "feColorMatrix" =>
      if get_attr(attrs, "type").unwrap_or("matrix") != "matrix" {
        None
      } else {
        match get_attr(attrs, "values") {
          Some(value) =>
            parse_filter_matrix(value).map(fn(matrix) {
              GraphColorMatrix(input~, result~, matrix~)
            })
          None => None
        }
      }
    "feGaussianBlur" => {
      let values = get_attr(attrs, "stdDeviation")
        .map(parse_number_list)
        .unwrap_or([])
      let radius = if values.length() == 0 { 0.0 } else { values[0] }
      Some(GraphGaussianBlur(input~, result~, radius~))
    }
    "feOffset" =>
      Some(
        GraphOffset(
          input~,
          result~,
          dx=get_attr(attrs, "dx").map(parse_number).unwrap_or(0.0),
          dy=get_attr(attrs, "dy").map(parse_number).unwrap_or(0.0),
        ),
      )
    "feBlend" =>
      Some(
        GraphBlend(
          input~,
          input2=get_attr(attrs, "in2").unwrap_or(""),
          result~,
          mode=parse_blend_mode(get_attr(attrs, "mode").unwrap_or("normal")),
        ),
      )
    "feComposite" => {
      let operator = match get_attr(attrs, "operator").unwrap_or("over") {
        "in" => CompositeIn
        "out" => CompositeOut
        "atop" => CompositeAtop
        "xor" => CompositeXor
        "arithmetic" => CompositeArithmetic
        _ => CompositeOver
      }
      Some(
        GraphComposite(
          input~,
          input2=get_attr(attrs, "in2").unwrap_or(""),
          result~,
          operator~,
          k1=get_attr(attrs, "k1").map(parse_number).unwrap_or(0.0),
          k2=get_attr(attrs, "k2").map(parse_number).unwrap_or(0.0),
          k3=get_attr(attrs, "k3").map(parse_number).unwrap_or(0.0),
          k4=get_attr(attrs, "k4").map(parse_number).unwrap_or(0.0),
        ),
      )
    }
    _ => None
  }
}

///|
fn parse_filter_graph(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
) -> Unit {
  let primitives : Array[FilterGraphPrimitive] = []
  while !parser.is_end() {
    parser.skip_whitespace()
    if parser.peek() != '<' {
      let _ = parser.advance()
      continue
    }
    let _ = parser.advance()
    if parser.peek() == '/' {
      let _ = parser.advance()
      let end_tag = parser.read_name()
      while !parser.is_end() && parser.advance() != '>' {

      }
      if end_tag == tag_name {
        break
      }
      continue
    }
    if parser.peek() == '!' || parser.peek() == '?' {
      skip_comment_or_decl(parser)
      continue
    }
    let primitive_tag = parser.read_name()
    let primitive_attrs = parse_attributes(parser)
    parser.skip_whitespace()
    let self_closing = parser.peek() == '/'
    if self_closing {
      let _ = parser.advance()
    }
    let _ = parser.expect_char('>')
    match parse_filter_primitive(primitive_tag, primitive_attrs) {
      Some(primitive) => primitives.push(primitive)
      None => ()
    }
    if !self_closing {
      skip_to_end_tag(parser, primitive_tag)
    }
  }
  let id = get_attr(attrs, "id").unwrap_or("")
  if id.length() == 0 {
    return
  }
  let units = match get_attr(attrs, "filterUnits") {
    Some(value) => parse_mask_units(value)
    None => MaskUnits::ObjectBoundingBox
  }
  let (default_x, default_y, default_width, default_height) = match units {
    MaskUnits::ObjectBoundingBox => (-0.1, -0.1, 1.2, 1.2)
    MaskUnits::UserSpaceOnUse => (-0.1, -0.1, 1.2, 1.2)
  }
  let (x, x_is_percent) = match get_attr(attrs, "x") {
    Some(value) => parse_mask_length(value, units)
    None => (default_x, true)
  }
  let (y, y_is_percent) = match get_attr(attrs, "y") {
    Some(value) => parse_mask_length(value, units)
    None => (default_y, true)
  }
  let (width, width_is_percent) = match get_attr(attrs, "width") {
    Some(value) => parse_mask_length(value, units)
    None => (default_width, true)
  }
  let (height, height_is_percent) = match get_attr(attrs, "height") {
    Some(value) => parse_mask_length(value, units)
    None => (default_height, true)
  }
  ctx.filter_graphs.add({
    id,
    primitives,
    units,
    x,
    y,
    width,
    height,
    x_is_percent,
    y_is_percent,
    width_is_percent,
    height_is_percent,
  })
}

///|
fn parse_mask_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
) -> Unit {
  parse_mask_with_content(attrs, [], ctx)
}

///|
fn parse_mask(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
) -> Unit {
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
  parse_mask_with_content(attrs, temp.children, ctx)
}

///|
fn parse_mask_with_content(
  attrs : Array[(String, String)],
  content : Array[SVGNode],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let mask_units = match get_attr(attrs, "maskUnits") {
    Some(v) => parse_mask_units(v)
    None => MaskUnits::ObjectBoundingBox
  }
  let mask_content_units = match get_attr(attrs, "maskContentUnits") {
    Some(v) => parse_mask_units(v)
    None => MaskUnits::UserSpaceOnUse
  }
  let mask_type = match get_attr(attrs, "mask-type") {
    Some(v) => parse_mask_type(v)
    None => Luminance
  }
  let mut has_bounds = false
  let mut x = 0.0
  let mut y = 0.0
  let mut width = 0.0
  let mut height = 0.0
  let mut x_is_percent = false
  let mut y_is_percent = false
  let mut width_is_percent = false
  let mut height_is_percent = false
  if get_attr(attrs, "x") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    x = val
    x_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "y") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    y = val
    y_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "width") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    width = val
    width_is_percent = is_percent
    has_bounds = true
  }
  if get_attr(attrs, "height") is Some(v) {
    let (val, is_percent) = parse_mask_length(v, mask_units)
    height = val
    height_is_percent = is_percent
    has_bounds = true
  }
  let base = if has_bounds {
    Mask::with_bounds(id, content, x, y, width, height)
  } else {
    Mask::new(id, content)
  }
  let mask = if has_bounds {
    {
      ..base,
      x_is_percent,
      y_is_percent,
      width_is_percent,
      height_is_percent,
      mask_units,
      mask_content_units,
      mask_type,
    }
  } else {
    { ..base, mask_units, mask_content_units, mask_type }
  }
  ctx.masks.add(mask)
}

///|
fn is_paint_server_context(parent_tag : String) -> Bool {
  parent_tag == "svg" || parent_tag == "defs" || parent_tag == "symbol"
}

///|
fn parse_pattern_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    return
  }
  parse_pattern_with_content(attrs, [], ctx)
}

///|
fn parse_pattern(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    skip_to_end_tag(parser, tag_name)
    return
  }
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
  parse_pattern_with_content(attrs, temp.children, ctx)
}

///|
fn parse_marker_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  _parent_tag : String,
) -> Unit {
  let node = SVGNode::new(Group)
  apply_attributes(node, attrs)
  let _ = resolve_element_computed_style(
    node,
    "marker",
    attrs,
    ctx,
    ctx.current_style(),
    true,
  )
  parse_marker_with_content(attrs, node, ctx)
}

///|
fn parse_marker(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  _parent_tag : String,
) -> Unit {
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
  parse_marker_with_content(attrs, temp, ctx)
}

///|
fn parse_marker_with_content(
  attrs : Array[(String, String)],
  content : SVGNode,
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let mut ref_x = 0.0
  let mut ref_y = 0.0
  let mut marker_width = 3.0
  let mut marker_height = 3.0
  let mut marker_units = MarkerUnits::StrokeWidth
  let mut orient = MarkerOrient::Angle(0.0)
  let mut view_box : ViewBox? = None
  let mut preserve_aspect_ratio = PreserveAspectRatio::default()
  let mut overflow_visible = false
  if get_attr(attrs, "refX") is Some(v) {
    ref_x = parse_length(v)
  }
  if get_attr(attrs, "refY") is Some(v) {
    ref_y = parse_length(v)
  }
  if get_attr(attrs, "markerWidth") is Some(v) {
    marker_width = parse_length(v)
  }
  if get_attr(attrs, "markerHeight") is Some(v) {
    marker_height = parse_length(v)
  }
  if get_attr(attrs, "markerUnits") is Some(v) {
    marker_units = parse_marker_units(v)
  }
  if get_attr(attrs, "orient") is Some(v) {
    orient = parse_marker_orient(v)
  }
  if get_attr(attrs, "viewBox") is Some(v) {
    view_box = parse_view_box(v)
  }
  if get_attr(attrs, "preserveAspectRatio") is Some(v) {
    preserve_aspect_ratio = parse_preserve_aspect_ratio(v)
  }
  if get_attr(attrs, "overflow") is Some(v) {
    overflow_visible = trim_string(v) == "visible"
  }
  content.viewport_width = Some(marker_width)
  content.viewport_height = Some(marker_height)
  // Marker viewBox is handled by marker transform, not by content node.
  content.view_box = None
  content.preserve_aspect_ratio = PreserveAspectRatio::default()
  content.preserve_aspect_ratio_is_set = false
  // Marker viewport clipping is handled at render time.
  content.clip_overflow = false
  let clip_overflow = !overflow_visible
  let marker = {
    ..Marker::new(id, content),
    ref_x,
    ref_y,
    marker_width,
    marker_height,
    marker_units,
    orient,
    view_box,
    preserve_aspect_ratio,
    clip_overflow,
  }
  ctx.markers.add(marker)
}

///|
fn parse_marker_units(value : String) -> MarkerUnits {
  match trim_string(value) {
    "userSpaceOnUse" => MarkerUnits::UserSpaceOnUse_
    "strokeWidth" => MarkerUnits::StrokeWidth
    _ => MarkerUnits::StrokeWidth
  }
}

///|
fn parse_marker_orient(value : String) -> MarkerOrient {
  let v = trim_string(value)
  if v == "auto" {
    MarkerOrient::Auto
  } else if v == "auto-start-reverse" {
    MarkerOrient::AutoStartReverse
  } else {
    let angle = if string_ends_with(v, "deg") {
      parse_number(build_substring(v, 0, v.length() - 3))
    } else {
      parse_number(v)
    }
    MarkerOrient::Angle(angle)
  }
}

///|
fn parse_pattern_with_content(
  attrs : Array[(String, String)],
  content : Array[SVGNode],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let reference = match get_attr(attrs, "href") {
    Some(v) => parse_url_ref(v)
    None =>
      match get_attr(attrs, "xlink:href") {
        Some(v) => parse_url_ref(v)
        None => None
      }
  }
  let mut x = 0.0
  let mut y = 0.0
  let mut width = 0.0
  let mut height = 0.0
  if get_attr(attrs, "x") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    x = val
  }
  if get_attr(attrs, "y") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    y = val
  }
  if get_attr(attrs, "width") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    width = val
  }
  if get_attr(attrs, "height") is Some(v) {
    let (val, _) = parse_length_or_percent(v)
    height = val
  }
  let pattern_units = match get_attr(attrs, "patternUnits") {
    Some(v) => parse_pattern_units(v)
    None => ObjectBoundingBox
  }
  let pattern_content_units = match get_attr(attrs, "patternContentUnits") {
    Some(v) => parse_pattern_units(v)
    None => UserSpaceOnUse
  }
  let transform = match get_attr(attrs, "patternTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let view_box = match get_attr(attrs, "viewBox") {
    Some(v) => parse_view_box(v)
    None => None
  }
  let preserve_aspect_ratio = match get_attr(attrs, "preserveAspectRatio") {
    Some(v) => parse_preserve_aspect_ratio(v)
    None => PreserveAspectRatio::default()
  }
  let pattern = {
    ..Pattern::new(id, width, height, content),
    x,
    y,
    pattern_units,
    pattern_content_units,
    transform,
    view_box,
    preserve_aspect_ratio,
  }
  let mut specified = 0
  if get_attr(attrs, "x") is Some(_) {
    specified = specified | 1
  }
  if get_attr(attrs, "y") is Some(_) {
    specified = specified | 2
  }
  if get_attr(attrs, "width") is Some(_) {
    specified = specified | 4
  }
  if get_attr(attrs, "height") is Some(_) {
    specified = specified | 8
  }
  if get_attr(attrs, "patternUnits") is Some(_) {
    specified = specified | 16
  }
  if get_attr(attrs, "patternContentUnits") is Some(_) {
    specified = specified | 32
  }
  if get_attr(attrs, "patternTransform") is Some(_) {
    specified = specified | 64
  }
  if get_attr(attrs, "viewBox") is Some(_) {
    specified = specified | 128
  }
  if get_attr(attrs, "preserveAspectRatio") is Some(_) {
    specified = specified | 256
  }
  if !content.is_empty() {
    specified = specified | 512
  }
  ctx.patterns.add_definition(pattern, reference, specified)
}

///|
fn parse_pattern_units(value : String) -> PatternUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_gradient_units(value : String) -> GradientUnits {
  match trim_string(value) {
    "userSpaceOnUse" => UserSpaceOnUse
    "objectBoundingBox" => ObjectBoundingBox
    _ => ObjectBoundingBox
  }
}

///|
fn parse_linear_gradient_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    return
  }
  parse_linear_gradient_with_stops(attrs, [], ctx)
}

///|
fn parse_linear_gradient(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
  gradient_style : InheritedStyle,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let stops = parse_gradient_stops(parser, tag_name, attrs, ctx, gradient_style)
  parse_linear_gradient_with_stops(attrs, stops, ctx)
}

///|
fn parse_linear_gradient_with_stops(
  attrs : Array[(String, String)],
  stops : Array[GradientStop],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let reference = match get_attr(attrs, "href") {
    Some(v) => parse_url_ref(v)
    None =>
      match get_attr(attrs, "xlink:href") {
        Some(v) => parse_url_ref(v)
        None => None
      }
  }
  let x1 = parse_gradient_coord(get_attr(attrs, "x1"), 0.0)
  let y1 = parse_gradient_coord(get_attr(attrs, "y1"), 0.0)
  let x2 = parse_gradient_coord(get_attr(attrs, "x2"), 1.0)
  let y2 = parse_gradient_coord(get_attr(attrs, "y2"), 0.0)
  let spread_method = match get_attr(attrs, "spreadMethod") {
    Some(v) => parse_spread_method(v)
    None => Pad
  }
  let units = match get_attr(attrs, "gradientUnits") {
    Some(v) => parse_gradient_units(v)
    None => ObjectBoundingBox
  }
  let transform = match get_attr(attrs, "gradientTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let grad = {
    ..LinearGradient::new(x1, y1, x2, y2, stops),
    spread_method,
    units,
    transform,
  }
  let mut specified = 0
  if get_attr(attrs, "x1") is Some(_) {
    specified = specified | 1
  }
  if get_attr(attrs, "y1") is Some(_) {
    specified = specified | 2
  }
  if get_attr(attrs, "x2") is Some(_) {
    specified = specified | 4
  }
  if get_attr(attrs, "y2") is Some(_) {
    specified = specified | 8
  }
  if get_attr(attrs, "spreadMethod") is Some(_) {
    specified = specified | 16
  }
  if get_attr(attrs, "gradientUnits") is Some(_) {
    specified = specified | 32
  }
  if get_attr(attrs, "gradientTransform") is Some(_) {
    specified = specified | 64
  }
  if !stops.is_empty() {
    specified = specified | 128
  }
  ctx.gradients.add_definition(id, Gradient::Linear(grad), reference, specified)
}

///|
fn parse_radial_gradient_from_attrs(
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_tag : String,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    return
  }
  parse_radial_gradient_with_stops(attrs, [], ctx)
}

///|
fn parse_radial_gradient(
  parser : SVGParser,
  attrs : Array[(String, String)],
  ctx : SVGParseContext,
  tag_name : String,
  parent_tag : String,
  gradient_style : InheritedStyle,
) -> Unit {
  if !is_paint_server_context(parent_tag) {
    skip_to_end_tag(parser, tag_name)
    return
  }
  let stops = parse_gradient_stops(parser, tag_name, attrs, ctx, gradient_style)
  parse_radial_gradient_with_stops(attrs, stops, ctx)
}

///|
fn parse_radial_gradient_with_stops(
  attrs : Array[(String, String)],
  stops : Array[GradientStop],
  ctx : SVGParseContext,
) -> Unit {
  let id = match get_attr(attrs, "id") {
    Some(v) => v
    None => ""
  }
  if id.length() == 0 {
    return
  }
  let reference = match get_attr(attrs, "href") {
    Some(v) => parse_url_ref(v)
    None =>
      match get_attr(attrs, "xlink:href") {
        Some(v) => parse_url_ref(v)
        None => None
      }
  }
  let cx = parse_gradient_coord(get_attr(attrs, "cx"), 0.5)
  let cy = parse_gradient_coord(get_attr(attrs, "cy"), 0.5)
  let r = parse_gradient_coord(get_attr(attrs, "r"), 0.5)
  let fx = match get_attr(attrs, "fx") {
    Some(v) => parse_gradient_coord(Some(v), cx)
    None => cx
  }
  let fy = match get_attr(attrs, "fy") {
    Some(v) => parse_gradient_coord(Some(v), cy)
    None => cy
  }
  let spread_method = match get_attr(attrs, "spreadMethod") {
    Some(v) => parse_spread_method(v)
    None => Pad
  }
  let units = match get_attr(attrs, "gradientUnits") {
    Some(v) => parse_gradient_units(v)
    None => ObjectBoundingBox
  }
  let transform = match get_attr(attrs, "gradientTransform") {
    Some(v) => parse_transform(v)
    None => Transform::identity()
  }
  let grad = {
    ..RadialGradient::new(cx, cy, r, stops),
    fx,
    fy,
    spread_method,
    units,
    transform,
  }
  let mut specified = 0
  if get_attr(attrs, "cx") is Some(_) {
    specified = specified | 1
  }
  if get_attr(attrs, "cy") is Some(_) {
    specified = specified | 2
  }
  if get_attr(attrs, "r") is Some(_) {
    specified = specified | 4
  }
  if get_attr(attrs, "fx") is Some(_) {
    specified = specified | 8
  }
  if get_attr(attrs, "fy") is Some(_) {
    specified = specified | 16
  }
  if get_attr(attrs, "spreadMethod") is Some(_) {
    specified = specified | 32
  }
  if get_attr(attrs, "gradientUnits") is Some(_) {
    specified = specified | 64
  }
  if get_attr(attrs, "gradientTransform") is Some(_) {
    specified = specified | 128
  }
  if !stops.is_empty() {
    specified = specified | 256
  }
  ctx.gradients.add_definition(id, Gradient::Radial(grad), reference, specified)
}

///|
fn parse_gradient_coord(value : String?, default : Double) -> Double {
  match value {
    Some(v) => {
      let (val, _) = parse_length_or_percent(v)
      val
    }
    None => default
  }
}

///|
fn parse_spread_method(value : String) -> SpreadMethod {
  match trim_string(value) {
    "repeat" => Repeat
    "reflect" => Reflect
    _ => Pad
  }
}

///|
fn parse_gradient_stops(
  parser : SVGParser,
  parent_tag : String,
  parent_attrs : Array[(String, String)],
  ctx : SVGParseContext,
  parent_style : InheritedStyle,
) -> Array[GradientStop] {
  let stops : Array[GradientStop] = []
  let depth = ctx.element_stack.length()
  let parent_element = if depth < ctx.selector_element_slots.length() {
    match ctx.selector_element_slots[depth] {
      Some(element) => element
      None => ctx.record_selector_element(parent_tag, parent_attrs)
    }
  } else {
    ctx.record_selector_element(parent_tag, parent_attrs)
  }
  ctx.element_stack.push(parent_element)
  ctx.style_stack.push(parent_style)
  ctx.sibling_index_stack.push(0)
  ctx.sibling_count_stack.push(count_direct_child_elements(parser, parent_tag))
  ctx.previous_sibling_stack.push(None)
  while !parser.is_end() {
    parser.skip_whitespace()
    if parser.peek() != '<' {
      // Skip text content
      while !parser.is_end() && parser.peek() != '<' {
        let _ = parser.advance()
      }
      continue
    }
    let _ = parser.advance()
    // End tag
    if parser.peek() == '/' {
      let _ = parser.advance()
      let end_tag = parser.read_name()
      if end_tag == parent_tag {
        parser.skip_whitespace()
        let _ = parser.expect_char('>')
        break
      }
      while !parser.is_end() && parser.advance() != '>' {

      }
      continue
    }
    if parser.peek() == '!' || parser.peek() == '?' {
      skip_comment_or_decl(parser)
      continue
    }
    let tag_name = parser.read_name()
    if tag_name.length() == 0 {
      continue
    }
    let attrs = parse_attributes(parser)
    let current_index = ctx.sibling_index_stack.length() - 1
    ctx.sibling_index_stack[current_index] += 1
    let _ = ctx.record_selector_element(tag_name, attrs)
    parser.skip_whitespace()
    let mut self_closing = false
    if parser.peek() == '/' {
      let _ = parser.advance()
      let _ = parser.expect_char('>')
      self_closing = true
    } else {
      let _ = parser.expect_char('>')
    }
    if tag_name == "stop" {
      let temp = SVGNode::new(Group)
      let stop_cascaded = ctx.cascaded_style(tag_name, attrs)
      let stop_style = resolve_computed_style(
        temp,
        attrs,
        stop_cascaded,
        ctx.current_style(),
        false,
      )
      stops.push(parse_gradient_stop(attrs, stop_style))
    }
    let child_depth = ctx.element_stack.length()
    if child_depth < ctx.selector_element_slots.length() {
      ctx.previous_sibling_stack[current_index] = ctx.selector_element_slots[child_depth]
    }
    if !self_closing {
      skip_to_end_tag(parser, tag_name)
    }
  }
  let _ = ctx.previous_sibling_stack.pop()
  let _ = ctx.sibling_count_stack.pop()
  let _ = ctx.sibling_index_stack.pop()
  let _ = ctx.style_stack.pop()
  let _ = ctx.element_stack.pop()
  stops
}

///|
fn parse_gradient_stop(
  attrs : Array[(String, String)],
  style : InheritedStyle,
) -> GradientStop {
  let offset = match get_attr(attrs, "offset") {
    Some(v) => parse_gradient_offset(v)
    None => 0.0
  }
  let color = style.stop_color
  let mut opacity = style.stop_opacity
  if opacity < 0.0 {
    opacity = 0.0
  }
  if opacity > 1.0 {
    opacity = 1.0
  }
  let final_color = if opacity < 1.0 {
    Color::rgba(
      color.r,
      color.g,
      color.b,
      (color.a.to_double() * opacity).round().to_int(),
    )
  } else {
    color
  }
  { offset, color: final_color }
}

///|
fn parse_gradient_offset(value : String) -> Double {
  let v = trim_string(value)
  let t = if string_ends_with(v, "%") {
    let cleaned = build_substring(v, 0, v.length() - 1)
    parse_number(cleaned) / 100.0
  } else {
    parse_number(v)
  }
  if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
}

///|
fn parse_linecap(value : String) -> LineCap {
  let v = trim_string(value)
  match v {
    "round" => Round
    "square" => Square
    _ => Butt // Default
  }
}

///|
fn parse_linejoin(value : String) -> LineJoin {
  let v = trim_string(value)
  match v {
    "round" => Round
    "bevel" => Bevel
    _ => Miter // Default
  }
}

///|
fn parse_dasharray(value : String) -> Array[Double]? {
  let v = trim_string(value)
  if v == "none" || v.length() == 0 {
    return None
  }
  let result : Array[Double] = []
  let mut current = ""
  for c in v {
    if c == ',' || c == ' ' {
      if current.length() > 0 {
        result.push(parse_number(current))
        current = ""
      }
    } else {
      current = current + c.to_string()
    }
  }
  if current.length() > 0 {
    result.push(parse_number(current))
  }
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
fn parse_fill_rule(value : String) -> FillRule {
  let v = trim_string(value)
  match v {
    "evenodd" => EvenOdd
    _ => NonZero // Default
  }
}

///|
fn trim_string(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end {
    let c = Int::unsafe_to_char(s[start].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = Int::unsafe_to_char(s[end - 1].to_int())
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  build_substring(s, start, end)
}

///|
fn string_starts_with(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if s[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
fn string_ends_with(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    return false
  }
  let start = s.length() - suffix.length()
  for i in 0..<suffix.length() {
    if s[start + i] != suffix[i] {
      return false
    }
  }
  true
}

///|
fn find_first(s : String, target : Char) -> Int {
  for i in 0..<s.length() {
    if Int::unsafe_to_char(s[i].to_int()) == target {
      return i
    }
  }
  -1
}

///|
fn parse_length(s : String) -> Double {
  // Simple number parsing (strips common units)
  let s = trim_string(s)
  if string_starts_with(s, "var(") && string_ends_with(s, ")") {
    let inner = build_substring(s, 4, s.length() - 1)
    let comma = find_first(inner, ',')
    if comma >= 0 {
      let fallback = trim_string(
        build_substring(inner, comma + 1, inner.length()),
      )
      if fallback.length() > 0 {
        return parse_length(fallback)
      }
    }
    return 0.0
  }
  // Remove units
  let cleaned = if string_ends_with(s, "px") {
    build_substring(s, 0, s.length() - 2)
  } else if string_ends_with(s, "em") || string_ends_with(s, "pt") {
    build_substring(s, 0, s.length() - 2)
  } else if string_ends_with(s, "%") {
    build_substring(s, 0, s.length() - 1)
  } else {
    s
  }
  parse_number(cleaned)
}

///|
fn parse_length_or_percent(s : String) -> (Double, Bool) {
  let s = trim_string(s)
  if string_ends_with(s, "%") {
    let cleaned = build_substring(s, 0, s.length() - 1)
    (parse_number(cleaned) / 100.0, true)
  } else {
    (parse_length(s), false)
  }
}

///|
fn parse_mask_length(value : String, units : MaskUnits) -> (Double, Bool) {
  let (val, is_percent) = parse_length_or_percent(value)
  match units {
    MaskUnits::ObjectBoundingBox => (val, false)
    MaskUnits::UserSpaceOnUse => (val, is_percent)
  }
}

///|
fn parse_number(s : String) -> Double {
  let s = trim_string(s)
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  let mut sign = 1.0
  let mut i = 0
  let len = s.length()
  fn char_at(str : String, idx : Int) -> Char {
    Int::unsafe_to_char(str[idx].to_int())
  }
  // Sign
  if i < len && char_at(s, i) == '-' {
    sign = -1.0
    i = i + 1
  } else if i < len && char_at(s, i) == '+' {
    i = i + 1
  }
  // Integer part
  while i < len {
    let c = char_at(s, i)
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  // Fractional part
  if i < len && char_at(s, i) == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let c = char_at(s, i)
      if c >= '0' && c <= '9' {
        result = result + (c.to_int() - 48).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  sign * result
}

///|
fn parse_paint(value : String) -> Paint {
  let value = trim_string(value)
  let lower = value.to_lower()
  if value.length() == 0 {
    return None
  }
  if lower == "none" {
    return None
  }
  if lower == "currentcolor" {
    return CurrentColor
  }
  // Paint server with optional fallback: url(#id) <fallback>
  if string_starts_with(value, "url(") {
    let close_index = find_first(value, ')')
    if close_index >= 0 {
      let url_part = build_substring(value, 0, close_index + 1)
      let rest = trim_string(
        build_substring(value, close_index + 1, value.length()),
      )
      match parse_url_ref(url_part) {
        Some(id) => {
          let fallback = if rest.length() == 0 {
            PaintFallback::NoPaint
          } else {
            parse_paint_fallback(rest)
          }
          return PaintServerRef(id, fallback)
        }
        None => ()
      }
    }
  }
  // Parse color
  let color = parse_color(value)
  SolidColor(color)
}

///|
fn parse_paint_fallback(value : String) -> PaintFallback {
  let value = trim_string(value)
  let lower = value.to_lower()
  if value.length() == 0 || lower == "none" {
    return PaintFallback::NoPaint
  }
  if lower == "currentcolor" {
    return PaintFallback::CurrentColor
  }
  PaintFallback::SolidColor(parse_color(value))
}

///|
fn parse_paint_order(value : String) -> PaintOrder {
  let v = trim_string(value)
  if v.length() == 0 || v == "normal" {
    return PaintOrder::default()
  }
  let tokens = split_tokens(v)
  if tokens.length() == 0 {
    return PaintOrder::default()
  }
  let order : Array[PaintOrderItem] = []
  for t in tokens {
    match t {
      "fill" => if !order.contains(Fill) { order.push(Fill) }
      "stroke" => if !order.contains(Stroke) { order.push(Stroke) }
      "markers" => if !order.contains(Markers) { order.push(Markers) }
      _ => ()
    }
  }
  if order.length() == 0 {
    return PaintOrder::default()
  }
  if !order.contains(Fill) {
    order.push(Fill)
  }
  if !order.contains(Stroke) {
    order.push(Stroke)
  }
  if !order.contains(Markers) {
    order.push(Markers)
  }
  PaintOrder::{ order, }
}

///|
fn parse_color(value : String) -> Color {
  let value = trim_string(value).to_lower()
  if value.length() == 0 {
    return Color::black()
  }
  // Named colors
  match value {
    "black" => return Color::black()
    "white" => return Color::white()
    "red" => return Color::rgb(255, 0, 0)
    "green" => return Color::rgb(0, 128, 0)
    "blue" => return Color::rgb(0, 0, 255)
    "yellow" => return Color::rgb(255, 255, 0)
    "cyan" => return Color::rgb(0, 255, 255)
    "magenta" => return Color::rgb(255, 0, 255)
    "gray" | "grey" => return Color::rgb(128, 128, 128)
    "orange" => return Color::rgb(255, 165, 0)
    "purple" => return Color::rgb(128, 0, 128)
    "pink" => return Color::rgb(255, 192, 203)
    "brown" => return Color::rgb(165, 42, 42)
    "transparent" => return Color::transparent()
    _ => ()
  }
  // Hex color
  if value.length() > 0 && Int::unsafe_to_char(value[0].to_int()) == '#' {
    return parse_hex_color(value)
  }
  // rgb(r, g, b)
  if string_starts_with(value, "rgb") {
    return parse_rgb_color(value)
  }
  if string_starts_with(value, "hsl") {
    return parse_hsl_color(value)
  }
  Color::black()
}

///|
fn parse_hex_color(value : String) -> Color {
  // #RGB or #RRGGBB
  fn hex_digit(c : Char) -> Int {
    if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      0
    }
  }

  fn char_at(s : String, i : Int) -> Char {
    Int::unsafe_to_char(s[i].to_int())
  }

  if value.length() == 4 || value.length() == 5 {
    // #RGB
    let r = hex_digit(char_at(value, 1))
    let g = hex_digit(char_at(value, 2))
    let b = hex_digit(char_at(value, 3))
    let a = if value.length() == 5 {
      hex_digit(char_at(value, 4)) * 17
    } else {
      255
    }
    Color::rgba(r * 17, g * 17, b * 17, a)
  } else if value.length() == 7 || value.length() == 9 {
    // #RRGGBB
    let r = hex_digit(char_at(value, 1)) * 16 + hex_digit(char_at(value, 2))
    let g = hex_digit(char_at(value, 3)) * 16 + hex_digit(char_at(value, 4))
    let b = hex_digit(char_at(value, 5)) * 16 + hex_digit(char_at(value, 6))
    let a = if value.length() == 9 {
      hex_digit(char_at(value, 7)) * 16 + hex_digit(char_at(value, 8))
    } else {
      255
    }
    Color::rgba(r, g, b, a)
  } else {
    Color::black()
  }
}

///|
fn parse_rgb_color(value : String) -> Color {
  let args = parse_color_function_args(value)
  if args.length() < 3 {
    return Color::black()
  }
  fn channel(arg : String) -> Int {
    let v = trim_string(arg)
    if string_ends_with(v, "%") {
      let number = parse_number(build_substring(v, 0, v.length() - 1))
      clamp_int((number * 2.55).round().to_int(), 0, 255)
    } else {
      clamp_int(parse_number(v).round().to_int(), 0, 255)
    }
  }
  let alpha = if args.length() >= 4 { parse_color_alpha(args[3]) } else { 255 }
  Color::rgba(channel(args[0]), channel(args[1]), channel(args[2]), alpha)
}

///|
fn parse_color_function_args(value : String) -> Array[String] {
  let mut start = 0
  while start < value.length() &&
        Int::unsafe_to_char(value[start].to_int()) != '(' {
    start = start + 1
  }
  start = start + 1
  let mut end = start
  while end < value.length() && Int::unsafe_to_char(value[end].to_int()) != ')' {
    end = end + 1
  }
  if start >= end {
    return []
  }
  let args : Array[String] = []
  let mut num_start = start
  for i = start; i <= end; i = i + 1 {
    let c = if i < value.length() {
      Int::unsafe_to_char(value[i].to_int())
    } else {
      ')'
    }
    if c == ',' || c == ')' {
      if num_start < i {
        args.push(trim_string(build_substring(value, num_start, i)))
      }
      num_start = i + 1
    }
  }
  args
}

///|
fn parse_color_alpha(value : String) -> Int {
  let value = trim_string(value)
  let alpha = if string_ends_with(value, "%") {
    parse_number(build_substring(value, 0, value.length() - 1)) / 100.0
  } else {
    parse_number(value)
  }
  clamp_int((alpha * 255.0).round().to_int(), 0, 255)
}

///|
fn parse_hsl_color(value : String) -> Color {
  let args = parse_color_function_args(value)
  if args.length() < 3 {
    return Color::black()
  }
  let raw_hue = parse_number(args[0])
  let hue = raw_hue - (raw_hue / 360.0).floor() * 360.0
  fn percentage(arg : String) -> Double {
    let value = trim_string(arg)
    let number = if string_ends_with(value, "%") {
      parse_number(build_substring(value, 0, value.length() - 1)) / 100.0
    } else {
      parse_number(value)
    }
    if number < 0.0 {
      0.0
    } else if number > 1.0 {
      1.0
    } else {
      number
    }
  }
  let saturation = percentage(args[1])
  let lightness = percentage(args[2])
  let chroma = (1.0 - (2.0 * lightness - 1.0).abs()) * saturation
  let hue_segment = hue / 60.0
  let segment_mod = hue_segment - (hue_segment / 2.0).floor() * 2.0
  let x = chroma * (1.0 - (segment_mod - 1.0).abs())
  let (r1, g1, b1) = if hue_segment < 1.0 {
    (chroma, x, 0.0)
  } else if hue_segment < 2.0 {
    (x, chroma, 0.0)
  } else if hue_segment < 3.0 {
    (0.0, chroma, x)
  } else if hue_segment < 4.0 {
    (0.0, x, chroma)
  } else if hue_segment < 5.0 {
    (x, 0.0, chroma)
  } else {
    (chroma, 0.0, x)
  }
  let m = lightness - chroma / 2.0
  let r = clamp_int(((r1 + m) * 255.0).round().to_int(), 0, 255)
  let g = clamp_int(((g1 + m) * 255.0).round().to_int(), 0, 255)
  let b = clamp_int(((b1 + m) * 255.0).round().to_int(), 0, 255)
  let a = if args.length() >= 4 { parse_color_alpha(args[3]) } else { 255 }
  Color::rgba(r, g, b, a)
}

///|
fn build_substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(Int::unsafe_to_char(s[i].to_int()))
  }
  buf.to_string()
}

///|
fn parse_points(value : String) -> Array[(Double, Double)] {
  // Parse space/comma separated list of x,y pairs
  let result : Array[(Double, Double)] = []
  let nums : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i in 0..<value.length() {
    let c = Int::unsafe_to_char(value[i].to_int())
    if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
      if buf.to_string().length() > 0 {
        nums.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    nums.push(parse_number(buf.to_string()))
  }
  // Pair up the numbers
  let mut i = 0
  while i + 1 < nums.length() {
    result.push((nums[i], nums[i + 1]))
    i = i + 2
  }
  result
}

///|
pub fn parse_transform(value : String) -> Transform {
  // Parse transform attribute: translate(x, y) scale(sx, sy) rotate(angle) etc.
  let mut result = Transform::identity()
  let mut i = 0
  while i < value.length() {
    // Skip whitespace
    while i < value.length() {
      let c = Int::unsafe_to_char(value[i].to_int())
      if c == ' ' || c == ',' {
        i = i + 1
      } else {
        break
      }
    }
    if i >= value.length() {
      break
    }
    // Read function name
    let name_start = i
    while i < value.length() {
      let c = Int::unsafe_to_char(value[i].to_int())
      if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
        i = i + 1
      } else {
        break
      }
    }
    let name = build_substring(value, name_start, i)
    // Find '('
    while i < value.length() && Int::unsafe_to_char(value[i].to_int()) != '(' {
      i = i + 1
    }
    i = i + 1 // Skip '('
    // Find ')' and parse arguments
    let args_start = i
    while i < value.length() && Int::unsafe_to_char(value[i].to_int()) != ')' {
      i = i + 1
    }
    let args_str = build_substring(value, args_start, i)
    i = i + 1 // Skip ')'
    // Parse arguments
    let args = parse_transform_args(args_str)
    // Apply transform
    let t = match name {
      "translate" =>
        if args.length() >= 2 {
          Transform::translate(args[0], args[1])
        } else if args.length() >= 1 {
          Transform::translate(args[0], 0.0)
        } else {
          Transform::identity()
        }
      "scale" =>
        if args.length() >= 2 {
          Transform::scale(args[0], args[1])
        } else if args.length() >= 1 {
          Transform::scale(args[0], args[0])
        } else {
          Transform::identity()
        }
      "rotate" =>
        if args.length() >= 3 {
          Transform::rotate_around(
            degrees_to_radians(args[0]),
            args[1],
            args[2],
          )
        } else if args.length() >= 1 {
          Transform::rotate(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "skewX" =>
        if args.length() >= 1 {
          Transform::skew_x(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "skewY" =>
        if args.length() >= 1 {
          Transform::skew_y(args[0] |> degrees_to_radians)
        } else {
          Transform::identity()
        }
      "matrix" =>
        if args.length() >= 6 {
          Transform::matrix(
            args[0],
            args[1],
            args[2],
            args[3],
            args[4],
            args[5],
          )
        } else {
          Transform::identity()
        }
      _ => Transform::identity()
    }
    result = result.multiply(t)
  }
  result
}

///|
fn parse_transform_args(s : String) -> Array[Double] {
  let result : Array[Double] = []
  let mut buf = StringBuilder::new()
  for i in 0..<s.length() {
    let c = Int::unsafe_to_char(s[i].to_int())
    if c == ' ' || c == ',' {
      if buf.to_string().length() > 0 {
        result.push(parse_number(buf.to_string()))
        buf = StringBuilder::new()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    result.push(parse_number(buf.to_string()))
  }
  result
}
