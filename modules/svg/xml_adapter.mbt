///|
/// XML representation consumed by the SVG parser. The adapter deliberately
/// drops source spans after `Milky2018/xml` has validated the document.
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
  XmlOther
}

///|
fn adapt_xml_element(element : @xml.XmlElement) -> SVGXmlElement {
  {
    name: element.name,
    attributes: element.attributes.map(fn(attribute) {
      (attribute.name, attribute.value)
    }),
  }
}

///|
fn adapt_xml_event(event : @xml.Event) -> SVGXmlEvent {
  match event.kind {
    Start(element) => XmlStart(adapt_xml_element(element))
    End(name) => XmlEnd(name)
    Empty(element) => XmlEmpty(adapt_xml_element(element))
    Text(text) => XmlText(text)
    CData(text) => XmlCData(text)
    PI(target~, data~) => XmlPI(target~, data~)
    Eof => XmlEof
    Comment(_) | Decl(..) | DocType(_) => XmlOther
  }
}
