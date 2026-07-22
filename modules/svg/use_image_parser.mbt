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
                    Some({
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
                        Some({
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
            node.preserve_aspect_ratio = {
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
              node.view_box = Some({
                min_x: 0.0,
                min_y: 0.0,
                width: node.viewport_width.unwrap(),
                height: node.viewport_height.unwrap(),
              })
              node.preserve_aspect_ratio = {
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
        None =>
          match use_elem.instantiate_definition(ctx.defs, viewport_fallback) {
            Some(node) => {
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
