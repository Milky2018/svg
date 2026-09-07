///|
priv struct TextResourceLoadState {
  options : RenderOptions
  diagnostics : Array[RenderDiagnostic]
  media_environment : @css_media.MediaEnvironment
  cache : Map[String, String]
  documents : Map[String, SVGDocument]
  active : Map[String, Bool]
  mut depth : Int
  mut resource_count : Int
  mut byte_count : Int
}

///|
fn TextResourceLoadState::new(
  options : RenderOptions,
  diagnostics : Array[RenderDiagnostic],
  viewport_width : Double,
  viewport_height : Double,
) -> TextResourceLoadState {
  let color_scheme = match options.environment.color_scheme {
    Light => @css_media.Light
    Dark => Dark
  }
  {
    options,
    diagnostics,
    media_environment: {
      viewport_width,
      viewport_height,
      device_pixel_ratio: options.environment.device_pixel_ratio,
      color_scheme,
    },
    cache: Map([]),
    documents: Map([]),
    active: Map([]),
    depth: 0,
    resource_count: 0,
    byte_count: 0,
  }
}

///|
fn resource_last_slash(value : String) -> Int {
  let mut found = -1
  for i = 0; i < value.length(); i = i + 1 {
    if value[i] == '/' {
      found = i
    }
  }
  found
}

///|
fn resource_strip_fragment(value : String) -> String {
  match value.find("#") {
    Some(index) => value[:index].to_owned()
    None => value
  }
}

///|
fn resource_has_scheme(value : String) -> Bool {
  for i = 0; i < value.length(); i = i + 1 {
    match value[i] {
      ':' => return i > 0
      '/' | '?' | '#' => return false
      _ => ()
    }
  }
  false
}

///|
fn resource_origin(base : String) -> String {
  match base.find("://") {
    None => ""
    Some(scheme_end) => {
      let authority_start = scheme_end + 3
      let suffix = base[authority_start:]
      match suffix.find("/") {
        Some(index) => base[:authority_start + index].to_owned()
        None => base
      }
    }
  }
}

///|
fn normalize_resource_path(value : String) -> String {
  let prefix_end = match value.find("://") {
    Some(index) => {
      let authority_start = index + 3
      match value[authority_start:].find("/") {
        Some(slash) => authority_start + slash
        None => return value
      }
    }
    None => 0
  }
  let prefix = value[:prefix_end].to_owned()
  let path = value[prefix_end:].to_owned()
  let absolute = path.has_prefix("/")
  let segments : Array[String] = []
  for part in path.split("/") {
    let item = part.to_owned()
    if item == "" || item == "." {
      continue
    }
    if item == ".." {
      if !segments.is_empty() {
        let _ = segments.pop()
      }
    } else {
      segments.push(item)
    }
  }
  prefix + (if absolute { "/" } else { "" }) + segments.join("/")
}

///|
fn resolve_resource_uri(base : String, href : String) -> String {
  let href = trim_string(href)
  if href == "" || resource_has_scheme(href) {
    return href
  }
  let document_uri = resource_strip_fragment(base)
  if href.has_prefix("#") {
    return document_uri + href
  }
  if href.has_prefix("//") {
    match document_uri.find(":") {
      Some(index) => return document_uri[:index + 1].to_owned() + href
      None => return href
    }
  }
  if href.has_prefix("/") {
    return normalize_resource_path(resource_origin(document_uri) + href)
  }
  let slash = resource_last_slash(document_uri)
  let directory = if slash >= 0 {
    document_uri[:slash + 1].to_owned()
  } else {
    ""
  }
  normalize_resource_path(directory + href)
}

///|
fn strip_resource_quotes(value : String) -> String {
  let value = trim_string(value)
  if value.length() >= 2 {
    let first = value[0]
    let last = value[value.length() - 1]
    if (first == '"' && last == '"') || (first == '\'' && last == '\'') {
      return value[1:value.length() - 1].to_owned()
    }
  }
  value
}

///|
fn canonicalize_fragment_reference(base : String, reference : String) -> String {
  let reference = strip_resource_quotes(reference)
  if reference.has_prefix("#") || reference.find("#") is None {
    reference
  } else {
    resolve_resource_uri(base, reference)
  }
}

///|
fn canonicalize_url_references(value : String, base : String) -> String {
  let lower = value.to_lower()
  let output = StringBuilder()
  let mut pos = 0
  while pos < value.length() {
    let found = match lower[pos:].find("url(") {
      Some(index) => pos + index
      None => {
        output.write_string(value[pos:].to_owned())
        break
      }
    }
    output.write_string(value[pos:found].to_owned())
    let content_start = found + 4
    let close = match value[content_start:].find(")") {
      Some(index) => content_start + index
      None => {
        output.write_string(value[found:].to_owned())
        break
      }
    }
    output.write_string("url(")
    output.write_string(
      canonicalize_fragment_reference(
        base,
        value[content_start:close].to_owned(),
      ),
    )
    output.write_char(')')
    pos = close + 1
  }
  output.to_string()
}

///|
fn parse_pi_attributes(data : String) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  let mut pos = 0
  while pos < data.length() {
    while pos < data.length() &&
          css_is_whitespace(Int::unsafe_to_char(data[pos].to_int())) {
      pos = pos + 1
    }
    let name_start = pos
    while pos < data.length() &&
          !css_is_whitespace(Int::unsafe_to_char(data[pos].to_int())) &&
          data[pos] != '=' {
      pos = pos + 1
    }
    if pos == name_start {
      break
    }
    let name = data[name_start:pos].to_owned().to_lower()
    while pos < data.length() &&
          css_is_whitespace(Int::unsafe_to_char(data[pos].to_int())) {
      pos = pos + 1
    }
    if pos >= data.length() || data[pos] != '=' {
      continue
    }
    pos = pos + 1
    while pos < data.length() &&
          css_is_whitespace(Int::unsafe_to_char(data[pos].to_int())) {
      pos = pos + 1
    }
    if pos >= data.length() {
      break
    }
    let quote = data[pos]
    let quoted = quote == '"' || quote == '\''
    if quoted {
      pos = pos + 1
    }
    let value_start = pos
    while pos < data.length() &&
          (if quoted {
            data[pos] != quote
          } else {
            !css_is_whitespace(Int::unsafe_to_char(data[pos].to_int()))
          }) {
      pos = pos + 1
    }
    result[name] = data[value_start:pos].to_owned()
    if quoted && pos < data.length() {
      pos = pos + 1
    }
  }
  result
}

///|
fn TextResourceLoadState::record(
  self : TextResourceLoadState,
  kind : RenderDiagnosticKind,
  stage : RenderStage,
  resource : String,
) -> Unit {
  self.diagnostics.push({ kind, stage, resource, node_id: "", })
}

///|
fn TextResourceLoadState::resolve_text(
  self : TextResourceLoadState,
  uri : String,
  kind : TextResourceKind,
  stage : RenderStage,
) -> String? {
  let cache_key = match kind {
    Stylesheet => "css:" + uri
    SvgDocument => "svg:" + uri
  }
  match self.cache.get(cache_key) {
    Some(text) => return Some(text)
    None => ()
  }
  if self.resource_count >= self.options.max_external_resources {
    self.record(ResourceLimitExceeded, stage, uri)
    return None
  }
  let resolver = match self.options.text_resource_resolver {
    Some(resolver) => resolver
    None => {
      self.record(ResourceUnresolved, stage, uri)
      return None
    }
  }
  let resolved = resolver(uri, kind)
  match resolved {
    None => {
      self.record(ResourceUnresolved, stage, uri)
      None
    }
    Some(text) => {
      if self.byte_count + text.length() > self.options.max_external_bytes {
        self.record(ResourceLimitExceeded, stage, uri)
        return None
      }
      self.resource_count = self.resource_count + 1
      self.byte_count = self.byte_count + text.length()
      self.cache[cache_key] = text
      Some(text)
    }
  }
}

///|
fn TextResourceLoadState::load_stylesheet_uri(
  self : TextResourceLoadState,
  uri : String,
) -> Array[@css_cascade.Stylesheet] {
  let active_key = "css:" + uri
  if self.active.contains(active_key) {
    self.record(ResourceCycle, Stylesheet, uri)
    return []
  }
  if self.depth >= self.options.max_external_depth {
    self.record(ResourceLimitExceeded, Stylesheet, uri)
    return []
  }
  self.active[active_key] = true
  self.depth = self.depth + 1
  let result = match self.resolve_text(uri, Stylesheet, Stylesheet) {
    Some(text) => self.load_stylesheet_text(text, uri)
    None => []
  }
  self.active.remove(active_key)
  self.depth = self.depth - 1
  result
}

///|
fn TextResourceLoadState::load_stylesheet_text(
  self : TextResourceLoadState,
  text : String,
  base_uri : String,
) -> Array[@css_cascade.Stylesheet] {
  let parsed = @css.parse_stylesheet(
    canonicalize_url_references(text, base_uri),
  )
  let result : Array[@css_cascade.Stylesheet] = []
  for import_rule in parsed.imports {
    if import_rule.media != "" {
      let query = @css_media.parse_media_query_list(import_rule.media)
      if !query.evaluate(self.media_environment) {
        continue
      }
    }
    let uri = resolve_resource_uri(base_uri, import_rule.href)
    for sheet in self.load_stylesheet_uri(uri) {
      result.push(sheet)
    }
  }
  result.push(parsed)
  result
}

///|
fn load_document_stylesheets(
  events : Array[SVGXmlEvent],
  state : TextResourceLoadState,
  base_uri : String,
) -> Array[@css_cascade.Stylesheet] {
  let stylesheets : Array[@css_cascade.Stylesheet] = []
  let content = StringBuilder()
  let mut in_style = false
  for event in events {
    match event {
      XmlPI(target~, data~) if target.to_lower() == "xml-stylesheet" => {
        let attrs = parse_pi_attributes(data)
        let css_type = attrs.get("type").unwrap_or("text/css").to_lower()
        match attrs.get("href") {
          Some(href) if css_type == "text/css" => {
            let uri = resolve_resource_uri(base_uri, href)
            for sheet in state.load_stylesheet_uri(uri) {
              stylesheets.push(sheet)
            }
          }
          _ => ()
        }
      }
      XmlStart(element) =>
        if element.name == "style" {
          content.reset()
          in_style = true
        }
      XmlEmpty(element) =>
        if element.name == "style" {
          for sheet in state.load_stylesheet_text("", base_uri) {
            stylesheets.push(sheet)
          }
        }
      XmlText(text) | XmlCData(text) =>
        if in_style {
          content.write_string(text)
        }
      XmlEnd(name) =>
        if in_style && name == "style" {
          for
            sheet in state.load_stylesheet_text(
              trim_string(content.to_string()),
              base_uri,
            ) {
            stylesheets.push(sheet)
          }
          in_style = false
        }
      _ => ()
    }
  }
  stylesheets
}
