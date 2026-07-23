///|
fn qualify_resource_id(base_uri : String, id : String) -> String {
  if id == "" || id.find("#") is Some(_) {
    id
  } else {
    resource_strip_fragment(base_uri) + "#" + id
  }
}

///|
fn qualify_paint_reference(paint : Paint, base_uri : String) -> Paint {
  match paint {
    PaintServerRef(id, fallback) =>
      PaintServerRef(qualify_resource_id(base_uri, id), fallback)
    _ => paint
  }
}

///|
fn qualify_node_resource_references(node : SVGNode, base_uri : String) -> Unit {
  node.fill = qualify_paint_reference(node.fill, base_uri)
  node.stroke = {
    ..node.stroke,
    paint: qualify_paint_reference(node.stroke.paint, base_uri),
  }
  node.marker_start = node.marker_start.map(fn(id) {
    qualify_resource_id(base_uri, id)
  })
  node.marker_mid = node.marker_mid.map(fn(id) {
    qualify_resource_id(base_uri, id)
  })
  node.marker_end = node.marker_end.map(fn(id) {
    qualify_resource_id(base_uri, id)
  })
  node.filter_graph_id = node.filter_graph_id.map(fn(id) {
    qualify_resource_id(base_uri, id)
  })
  node.mask_id = node.mask_id.map(fn(id) { qualify_resource_id(base_uri, id) })
  node.clip_path_id = node.clip_path_id.map(fn(id) {
    qualify_resource_id(base_uri, id)
  })
  for child in node.children {
    qualify_node_resource_references(child, base_uri)
  }
}

///|
fn qualify_document_resource_references(
  document : SVGDocument,
  base_uri : String,
) -> Unit {
  qualify_node_resource_references(document.root, base_uri)
  document.definitions.elements.each(fn(_id, node) {
    qualify_node_resource_references(node, base_uri)
  })
  document.symbols.symbols.each(fn(_id, symbol) {
    qualify_node_resource_references(symbol.content, base_uri)
  })
  document.clips.clips.each(fn(_id, clip) {
    for node in clip.content {
      qualify_node_resource_references(node, base_uri)
    }
  })
  document.masks.masks.each(fn(_id, mask) {
    for node in mask.content {
      qualify_node_resource_references(node, base_uri)
    }
  })
  document.patterns.patterns.each(fn(_id, pattern) {
    for node in pattern.content {
      qualify_node_resource_references(node, base_uri)
    }
  })
  document.markers.markers.each(fn(_id, marker) {
    qualify_node_resource_references(marker.content, base_uri)
  })
}

///|
fn merge_external_document(
  ctx : SVGParseContext,
  document : SVGDocument,
  base_uri : String,
) -> Unit {
  let prefix = resource_strip_fragment(base_uri) + "#"
  ctx.defs.elements[resource_strip_fragment(base_uri)] = document.root
  if document.root.id != "" {
    ctx.defs.elements[prefix + document.root.id] = document.root
  }
  document.definitions.elements.each(fn(id, node) {
    ctx.defs.elements[prefix + id] = node
  })
  document.symbols.symbols.each(fn(id, symbol) {
    ctx.symbols.symbols[prefix + id] = { ..symbol, id: prefix + id }
  })
  document.clips.clips.each(fn(id, clip) {
    ctx.clips.clips[prefix + id] = { ..clip, id: prefix + id }
  })
  document.masks.masks.each(fn(id, mask) {
    ctx.masks.masks[prefix + id] = { ..mask, id: prefix + id }
  })
  document.filter_graphs.graphs.each(fn(id, graph) {
    ctx.filter_graphs.graphs[prefix + id] = { ..graph, id: prefix + id }
  })
  document.patterns.patterns.each(fn(id, pattern) {
    ctx.patterns.patterns[prefix + id] = { ..pattern, id: prefix + id }
  })
  document.patterns.references.each(fn(id, parent) {
    ctx.patterns.references[prefix + id] = qualify_resource_id(base_uri, parent)
  })
  document.patterns.specified.each(fn(id, specified) {
    ctx.patterns.specified[prefix + id] = specified
  })
  document.gradients.gradients.each(fn(id, gradient) {
    ctx.gradients.gradients[prefix + id] = gradient
  })
  document.gradients.references.each(fn(id, parent) {
    ctx.gradients.references[prefix + id] = qualify_resource_id(
      base_uri, parent,
    )
  })
  document.gradients.specified.each(fn(id, specified) {
    ctx.gradients.specified[prefix + id] = specified
  })
  document.markers.markers.each(fn(id, marker) {
    ctx.markers.markers[prefix + id] = { ..marker, id: prefix + id }
  })
}

///|
fn canonicalize_svg_element_references(
  element : SVGXmlElement,
  base_uri : String,
) -> SVGXmlElement {
  let attrs = element.attributes.map(fn(attr) {
    let value = if attr.0 == "href" || attr.0 == xlink_href_attribute_name {
      if element.name == "use" && attr.1.find("#") is None {
        resolve_resource_uri(base_uri, attr.1)
      } else {
        canonicalize_fragment_reference(base_uri, attr.1)
      }
    } else {
      canonicalize_url_references(attr.1, base_uri)
    }
    (attr.0, value)
  })
  { name: element.name, attributes: attrs }
}

///|
fn canonicalize_svg_reference_events(
  events : Array[SVGXmlEvent],
  base_uri : String,
) -> Array[SVGXmlEvent] {
  events.map(fn(event) {
    match event {
      XmlStart(element) =>
        XmlStart(canonicalize_svg_element_references(element, base_uri))
      XmlEmpty(element) =>
        XmlEmpty(canonicalize_svg_element_references(element, base_uri))
      _ => event
    }
  })
}

///|
fn collect_url_references(value : String) -> Array[String] {
  let result : Array[String] = []
  let lower = value.to_lower()
  let mut pos = 0
  while pos < value.length() {
    let found = match lower[pos:].find("url(") {
      Some(index) => pos + index
      None => break
    }
    let content_start = found + 4
    let close = match value[content_start:].find(")") {
      Some(index) => content_start + index
      None => break
    }
    result.push(strip_resource_quotes(value[content_start:close].to_owned()))
    pos = close + 1
  }
  result
}

///|
fn push_external_document_uri(
  uris : Array[String],
  reference : String,
  allow_whole_document : Bool,
) -> Unit {
  if reference == "" || reference.has_prefix("#") {
    return
  }
  let uri = match reference.find("#") {
    Some(index) => reference[:index].to_owned()
    None if allow_whole_document => reference
    None => return
  }
  if uri == "" {
    return
  }
  for existing in uris {
    if existing == uri {
      return
    }
  }
  uris.push(uri)
}

///|
fn collect_external_document_uris(
  events : Array[SVGXmlEvent],
  stylesheets : Array[@css_cascade.Stylesheet],
) -> Array[String] {
  let uris : Array[String] = []
  for event in events {
    let element = match event {
      XmlStart(element) | XmlEmpty(element) => Some(element)
      _ => None
    }
    match element {
      None => ()
      Some(element) =>
        for attr in element.attributes {
          if attr.0 == "href" || attr.0 == xlink_href_attribute_name {
            let whole_document = element.name == "use"
            if whole_document ||
              element.name == "linearGradient" ||
              element.name == "radialGradient" ||
              element.name == "pattern" {
              push_external_document_uri(uris, attr.1, whole_document)
            }
          }
          for reference in collect_url_references(attr.1) {
            push_external_document_uri(uris, reference, false)
          }
        }
    }
  }
  for stylesheet in stylesheets {
    for rule in stylesheet.rules {
      for declaration in rule.declarations {
        match declaration.value {
          Value(value) =>
            for reference in collect_url_references(value) {
              push_external_document_uri(uris, reference, false)
            }
          _ => ()
        }
      }
    }
    for keyframes in stylesheet.keyframes {
      for block in keyframes.blocks {
        for declaration in block.declarations {
          match declaration.value {
            Value(value) =>
              for reference in collect_url_references(value) {
                push_external_document_uri(uris, reference, false)
              }
            _ => ()
          }
        }
      }
    }
  }
  uris
}

///|
fn TextResourceLoadState::load_svg_document(
  self : TextResourceLoadState,
  uri : String,
  viewport_width : Double,
  viewport_height : Double,
) -> SVGDocument? {
  match self.documents.get(uri) {
    Some(document) => return Some(document)
    None => ()
  }
  let active_key = "svg:" + uri
  if self.active.contains(active_key) {
    self.record(ResourceCycle, Document, uri)
    return None
  }
  if self.depth >= self.options.max_external_depth {
    self.record(ResourceLimitExceeded, Document, uri)
    return None
  }
  self.active[active_key] = true
  self.depth = self.depth + 1
  let result = match self.resolve_text(uri, SvgDocument, Document) {
    Some(text) => {
      let parsed = parse_svg_document_with_state(
        text,
        viewport_width,
        viewport_height,
        self.options,
        self,
        uri,
      )
      if parsed is None {
        self.record(ParseFailed, Document, uri)
      }
      parsed
    }
    None => None
  }
  self.active.remove(active_key)
  self.depth = self.depth - 1
  match result {
    Some(document) => {
      qualify_document_resource_references(document, uri)
      self.documents[uri] = document
      Some(document)
    }
    None => None
  }
}
