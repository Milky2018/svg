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
    @xml.Start(element) => XmlStart(adapt_xml_element(element))
    @xml.End(name) => XmlEnd(name)
    @xml.Empty(element) => XmlEmpty(adapt_xml_element(element))
    @xml.Text(text) => XmlText(text)
    @xml.CData(text) => XmlCData(text)
    @xml.PI(target~, data~) => XmlPI(target~, data~)
    @xml.Eof => XmlEof
    @xml.Comment(_) | @xml.Decl(..) | @xml.DocType(_) => XmlOther
  }
}
