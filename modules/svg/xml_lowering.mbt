///|
/// Namespace-resolved XML representation consumed by the SVG parser.
/// `Milky2018/xml` owns syntax validation and source ranges; this representation
/// owns the SVG-specific namespace and attribute semantics used downstream.
priv struct SVGXmlElement {
  name : String
  attributes : Array[(String, String)]
}

///|
priv enum SVGXmlEvent {
  XmlStart(SVGXmlElement)
  XmlEnd(String)
  XmlEmpty(SVGXmlElement)
  XmlText(String)
  XmlCData(String)
  XmlPI(target~ : String, data~ : String)
  XmlEof
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
  attributes : Array[@xml.XmlAttribute],
) -> XmlNamespaceScope {
  let mut default_uri = self.default_uri
  let mut default_declared = self.default_declared
  let prefixes = self.prefixes.copy()
  for attribute in attributes {
    let name = attribute.name
    let value = attribute.value
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
  { default_uri, default_declared, prefixes, }
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
  attributes : Array[@xml.XmlAttribute],
) -> Array[(String, String)] {
  attributes.map(fn(attribute) {
    (self.normalize_attribute_name(attribute.name), attribute.value)
  })
}

///|
fn read_xml_events(svg_str : String) -> Array[SVGXmlEvent]? {
  let reader = @xml.Reader::from_string(svg_str)
  try {
    let events : Array[SVGXmlEvent] = []
    let scopes : Array[XmlNamespaceScope] = [XmlNamespaceScope::root()]
    while true {
      let current = scopes[scopes.length() - 1]
      let event : SVGXmlEvent = match reader.read_event().kind {
        Start(element) => {
          let scope = current.with_declarations(element.attributes)
          scopes.push(scope)
          XmlStart({
            name: scope.normalize_element_name(element.name),
            attributes: scope.normalize_attributes(element.attributes),
          })
        }
        Empty(element) => {
          let scope = current.with_declarations(element.attributes)
          XmlEmpty({
            name: scope.normalize_element_name(element.name),
            attributes: scope.normalize_attributes(element.attributes),
          })
        }
        End(name) => {
          let normalized = XmlEnd(current.normalize_element_name(name))
          if scopes.length() > 1 {
            let _ = scopes.pop()
          }
          normalized
        }
        Text(text) => XmlText(text)
        CData(text) => XmlCData(text)
        PI(target~, data~) => XmlPI(target~, data~)
        Eof => XmlEof
        Comment(_) | Decl(..) | DocType(_) => continue
      }
      events.push(event)
      if event is XmlEof {
        break
      }
    }
    Some(events)
  } catch {
    _ => None
  }
}
