///|
test "Style::default" {
  let style = Style::default()
  inspect(style.display, content="Block")
  inspect(style.position, content="Static")
  inspect(style.flex_grow, content="0")
}

///|
test "Style::Eq compares all fields" {
  let base = Style::default()
  let same = Style::default()
  let changed = { ..Style::default(), width: @types.Length(120.0) }
  assert_true(base == same)
  assert_false(base == changed)
}

///|
test "Style::layout_eq compares layout fields only" {
  let base = Style::default()
  let same = Style::default()
  let layout_changed = { ..Style::default(), width: @types.Length(120.0) }
  let paint_changed = {
    ..Style::default(),
    color: @types.Color::white(),
    background_color: @types.Color::rgba(10, 20, 30, 0.5),
    box_shadows: [
      BoxShadow::new(false, 1.0, 2.0, 3.0, 4.0, @types.Color::black()),
    ],
  }
  let containing_block_changed = {
    ..Style::default(),
    transform: { ..Transform::none(), translate_x: TranslateValue::Length(1.0) },
  }
  assert_true(base.layout_eq(same))
  assert_false(base.layout_eq(layout_changed))
  assert_true(base.layout_eq(paint_changed))
  assert_false(base.layout_eq(containing_block_changed))
}

///|
test "Style::has_multicol_true_for_column_count_one" {
  let style = { ..Style::default(), column_count: Some(1) }
  assert_true(style.has_multicol())
}

///|
test "Style::has_multicol_false_for_auto_columns" {
  let style = Style::default()
  assert_false(style.has_multicol())
}

///|
test "BorderStyle::priority ordering" {
  inspect(BorderStyle::priority(None), content="0")
  inspect(BorderStyle::priority(Hidden), content="9")
  assert_true(BorderStyle::priority(Double) > BorderStyle::priority(Solid))
  assert_true(BorderStyle::priority(Solid) > BorderStyle::priority(Dashed))
  assert_true(BorderStyle::priority(Dashed) > BorderStyle::priority(Dotted))
}

///|
test "WritingMode::is_vertical and is_block_rtl" {
  assert_false(WritingMode::is_vertical(HorizontalTb))
  assert_true(WritingMode::is_vertical(VerticalRl))
  assert_true(WritingMode::is_vertical(VerticalLr))
  assert_true(WritingMode::is_block_rtl(VerticalRl))
  assert_false(WritingMode::is_block_rtl(VerticalLr))
  assert_false(WritingMode::is_block_rtl(HorizontalTb))
}

///|
test "Direction::is_rtl" {
  assert_true(Direction::is_rtl(Rtl))
  assert_false(Direction::is_rtl(Ltr))
}

///|
test "ScrollSnapType none/mandatory/axis helpers" {
  let none = ScrollSnapType::none()
  assert_false(none.is_mandatory())
  assert_false(none.snaps_x())
  assert_false(none.snaps_y())
  let mandatory_x : ScrollSnapType = {
    axis: ScrollSnapAxis::X,
    strictness: ScrollSnapStrictness::Mandatory,
  }
  assert_true(mandatory_x.is_mandatory())
  assert_true(mandatory_x.snaps_x())
  assert_false(mandatory_x.snaps_y())
  let both : ScrollSnapType = {
    axis: ScrollSnapAxis::Both,
    strictness: ScrollSnapStrictness::Proximity,
  }
  assert_false(both.is_mandatory())
  assert_true(both.snaps_x())
  assert_true(both.snaps_y())
}

///|
test "MarginTrim block/inline helpers" {
  assert_true(MarginTrim::trim_block_start(BlockStart))
  assert_true(MarginTrim::trim_block_start(Block))
  assert_false(MarginTrim::trim_block_start(BlockEnd))
  assert_false(MarginTrim::trim_block_start(None))
  assert_true(MarginTrim::trim_block_end(BlockEnd))
  assert_true(MarginTrim::trim_block_end(Block))
  assert_false(MarginTrim::trim_block_end(BlockStart))
}

///|
test "Transform::none is identity" {
  let t = Transform::none()
  assert_true(t.is_none())
  assert_false(t.has_scale())
  assert_false(t.has_skew())
  assert_false(t.has_affine_matrix())
  inspect(t.quarter_turns(), content="0")
}

///|
test "Transform::has_scale and has_skew detect modifications" {
  let scaled : Transform = { ..Transform::none(), scale_x: 2.0 }
  assert_true(scaled.has_scale())
  assert_false(scaled.is_none())
  let skewed : Transform = { ..Transform::none(), skew_x_degrees: 10.0 }
  assert_true(skewed.has_skew())
  assert_false(skewed.is_none())
}

///|
test "Transform::compute_translate_x with length and percent" {
  let with_length : Transform = {
    ..Transform::none(),
    translate_x: TranslateValue::Length(15.0),
  }
  inspect(with_length.compute_translate_x(100.0), content="15")
  let with_percent : Transform = {
    ..Transform::none(),
    translate_y: TranslateValue::Percent(0.25),
  }
  inspect(with_percent.compute_translate_y(80.0), content="20")
}

///|
test "Transform::quarter_turns snaps to 90 degree increments" {
  let r0 : Transform = { ..Transform::none(), rotate_degrees: 0.0 }
  inspect(r0.quarter_turns(), content="0")
  let r90 : Transform = { ..Transform::none(), rotate_degrees: 90.0 }
  inspect(r90.quarter_turns(), content="1")
  let r180 : Transform = { ..Transform::none(), rotate_degrees: 180.0 }
  inspect(r180.quarter_turns(), content="2")
  let r270 : Transform = { ..Transform::none(), rotate_degrees: 270.0 }
  inspect(r270.quarter_turns(), content="3")
  let r360 : Transform = { ..Transform::none(), rotate_degrees: 360.0 }
  inspect(r360.quarter_turns(), content="0")
  let r45 : Transform = { ..Transform::none(), rotate_degrees: 45.0 }
  inspect(r45.quarter_turns(), content="-1")
}

///|
test "Transform::has_affine_matrix only when explicitly set" {
  let identity_matrix : Transform = { ..Transform::none(), has_matrix: true }
  assert_false(identity_matrix.has_affine_matrix())
  let real_matrix : Transform = {
    ..Transform::none(),
    has_matrix: true,
    matrix_a: 2.0,
  }
  assert_true(real_matrix.has_affine_matrix())
}

///|
test "Contain helpers - none/strict/content" {
  let none = Contain::none()
  assert_false(none.has_containment())
  let strict = Contain::strict()
  assert_true(strict.has_containment())
  assert_true(strict.size)
  assert_true(strict.layout)
  assert_true(strict.paint)
  assert_true(strict.style)
  let content = Contain::content()
  assert_true(content.has_containment())
  assert_false(content.size)
  assert_true(content.layout)
}

///|
test "Style::suppresses_intrinsic_width and height by containment" {
  let style = Style::default()
  assert_false(style.suppresses_intrinsic_width())
  assert_false(style.suppresses_intrinsic_height())
  let size_contained = { ..Style::default(), contain: Contain::strict() }
  assert_true(size_contained.suppresses_intrinsic_width())
  assert_true(size_contained.suppresses_intrinsic_height())
  let inline_only : Style = {
    ..Style::default(),
    contain: { ..Contain::none(), inline_size: true },
  }
  assert_true(inline_only.suppresses_intrinsic_width())
  assert_false(inline_only.suppresses_intrinsic_height())
  let inline_only_vertical : Style = {
    ..Style::default(),
    contain: { ..Contain::none(), inline_size: true },
    writing_mode: VerticalRl,
  }
  assert_false(inline_only_vertical.suppresses_intrinsic_width())
  assert_true(inline_only_vertical.suppresses_intrinsic_height())
}

///|
test "Style::contained_intrinsic_*_fallback follows writing mode" {
  let horiz : Style = {
    ..Style::default(),
    contain_intrinsic_inline_size: Some(50.0),
    contain_intrinsic_block_size: Some(75.0),
  }
  inspect(horiz.contained_intrinsic_width_fallback(), content="50")
  inspect(horiz.contained_intrinsic_height_fallback(), content="75")
  let vert : Style = {
    ..Style::default(),
    writing_mode: VerticalRl,
    contain_intrinsic_inline_size: Some(50.0),
    contain_intrinsic_block_size: Some(75.0),
  }
  inspect(vert.contained_intrinsic_width_fallback(), content="75")
  inspect(vert.contained_intrinsic_height_fallback(), content="50")
  let none_size : Style = {
    ..Style::default(),
    contain_intrinsic_inline_size: None,
  }
  inspect(none_size.contained_intrinsic_width_fallback(), content="0")
}

///|
test "Style::has_multicol with column-width set" {
  let s : Style = { ..Style::default(), column_width: @types.Length(200.0) }
  assert_true(s.has_multicol())
  let s_zero : Style = { ..Style::default(), column_width: @types.Length(0.0) }
  assert_false(s_zero.has_multicol())
  let s_calc : Style = {
    ..Style::default(),
    column_width: @types.Calc(-10.0, 0.5),
  }
  assert_true(s_calc.has_multicol())
  let s_negative_calc : Style = {
    ..Style::default(),
    column_width: @types.Calc(-10.0, -0.5),
  }
  assert_false(s_negative_calc.has_multicol())
}

///|
test "ClipPath::none returns None variant" {
  let cp = ClipPath::none()
  let is_none = match cp {
    None => true
    _ => false
  }
  assert_true(is_none)
}

///|
test "Show impls for style enums" {
  inspect(BorderStyle::Solid, content="Solid")
  inspect(BorderCollapse::Collapse, content="Collapse")
  inspect(TableLayout::Fixed, content="Fixed")
  inspect(CaptionSide::Bottom, content="Bottom")
  inspect(WhiteSpace::Nowrap, content="Nowrap")
  inspect(TextOverflow::Ellipsis, content="Ellipsis")
  inspect(WritingMode::VerticalLr, content="VerticalLr")
  inspect(Direction::Rtl, content="Rtl")
  inspect(TextAlign::Center, content="Center")
  inspect(ScrollSnapAxis::Both, content="Both")
  inspect(ScrollSnapStrictness::Mandatory, content="Mandatory")
  inspect(ScrollSnapAlign::Center, content="Center")
  inspect(Visibility::Collapse, content="Collapse")
  inspect(PointerEvents::None, content="None")
  inspect(MarginTrim::Inline, content="Inline")
  inspect(ColumnFill::Balance, content="Balance")
  inspect(BreakBefore::Column, content="Column")
  inspect(BreakInside::Avoid, content="Avoid")
  inspect(ColumnSpan::All, content="All")
  inspect(ZIndex::Auto, content="Auto")
  inspect(ZIndex::Value(3), content="Value(3)")
  inspect(VerticalAlign::Sub, content="Sub")
  inspect(TranslateValue::Length(1.5), content="Length(1.5)")
  inspect(TranslateValue::Percent(0.5), content="Percent(0.5)")
}

///|
test "ScrollSnapType Show" {
  let snap : ScrollSnapType = {
    axis: ScrollSnapAxis::Y,
    strictness: ScrollSnapStrictness::Proximity,
  }
  inspect(snap, content="{axis: Y, strictness: Proximity}")
}

///|
test "Show for Transform exposes full matrix dump" {
  let t : Transform = {
    translate_x: TranslateValue::Length(2.0),
    translate_y: TranslateValue::Percent(0.5),
    scale_x: 1.5,
    scale_y: 2.0,
    rotate_degrees: 45.0,
    skew_x_degrees: 10.0,
    skew_y_degrees: 5.0,
    has_matrix: true,
    matrix_a: 1.0,
    matrix_b: 0.0,
    matrix_c: 0.0,
    matrix_d: 1.0,
    matrix_e: 0.0,
    matrix_f: 0.0,
    matrix3d: [],
  }
  let out = t.to_string()
  assert_true(out.contains("translate_x: Length(2)"))
  assert_true(out.contains("translate_y: Percent(0.5)"))
  assert_true(out.contains("scale_x: 1.5"))
  assert_true(out.contains("rotate_degrees: 45"))
  assert_true(out.contains("matrix: ["))
}

///|
test "Show for Contain dumps all flags" {
  let c = Contain::strict()
  let out = c.to_string()
  assert_true(out.contains("size: true"))
  assert_true(out.contains("layout: true"))
  assert_true(out.contains("paint: true"))
  assert_true(out.contains("style: true"))
  assert_true(out.contains("inline_size: false"))
}

///|
test "BorderStyle::priority - every variant" {
  inspect(BorderStyle::priority(None), content="0")
  inspect(BorderStyle::priority(Inset), content="1")
  inspect(BorderStyle::priority(Groove), content="2")
  inspect(BorderStyle::priority(Outset), content="3")
  inspect(BorderStyle::priority(Ridge), content="4")
  inspect(BorderStyle::priority(Dotted), content="5")
  inspect(BorderStyle::priority(Dashed), content="6")
  inspect(BorderStyle::priority(Solid), content="7")
  inspect(BorderStyle::priority(Double), content="8")
  inspect(BorderStyle::priority(Hidden), content="9")
}

///|
test "BorderStyle Show - every variant" {
  inspect(BorderStyle::None, content="None")
  inspect(BorderStyle::Inset, content="Inset")
  inspect(BorderStyle::Groove, content="Groove")
  inspect(BorderStyle::Outset, content="Outset")
  inspect(BorderStyle::Ridge, content="Ridge")
  inspect(BorderStyle::Dotted, content="Dotted")
  inspect(BorderStyle::Dashed, content="Dashed")
  inspect(BorderStyle::Solid, content="Solid")
  inspect(BorderStyle::Double, content="Double")
  inspect(BorderStyle::Hidden, content="Hidden")
}

///|
test "Transform::is_none - percent zero counts" {
  let t : Transform = {
    ..Transform::none(),
    translate_x: TranslateValue::Percent(0.0),
    translate_y: TranslateValue::Percent(0.0),
  }
  assert_true(t.is_none())
}

///|
test "Transform::quarter_turns - negative angle" {
  let t : Transform = { ..Transform::none(), rotate_degrees: -90.0 }
  // -90 / 90 = -1 -> -1 % 4 + 4 = 3
  inspect(t.quarter_turns(), content="3")
}

///|
test "Transform::compute_translate_x with Percent" {
  let t : Transform = {
    ..Transform::none(),
    translate_x: TranslateValue::Percent(0.5),
  }
  inspect(t.compute_translate_x(100.0), content="50")
}

///|
test "Style::contained_intrinsic_*_fallback with negative value falls to 0" {
  let s : Style = {
    ..Style::default(),
    contain_intrinsic_inline_size: Some(-10.0),
    contain_intrinsic_block_size: Some(-20.0),
  }
  inspect(s.contained_intrinsic_width_fallback(), content="0")
  inspect(s.contained_intrinsic_height_fallback(), content="0")
}

///|
test "Style::contained_intrinsic_*_fallback in vertical mode with Some(0)" {
  let s : Style = {
    ..Style::default(),
    writing_mode: VerticalRl,
    contain_intrinsic_block_size: Some(0.0),
    contain_intrinsic_inline_size: Some(0.0),
  }
  // 0.0 is not > 0, so falls back to 0
  inspect(s.contained_intrinsic_width_fallback(), content="0")
  inspect(s.contained_intrinsic_height_fallback(), content="0")
}

///|
test "Style::has_multicol with Percent column-width" {
  let s : Style = { ..Style::default(), column_width: @types.Percent(0.5) }
  assert_true(s.has_multicol())
}

///|
test "Style::contained_intrinsic_*_fallback Some(0) in horizontal mode" {
  // Hit lines 467 and 483 — Some(v) where v <= 0
  let s_h : Style = {
    ..Style::default(),
    contain_intrinsic_inline_size: Some(0.0),
    contain_intrinsic_block_size: Some(0.0),
  }
  inspect(s_h.contained_intrinsic_width_fallback(), content="0")
  inspect(s_h.contained_intrinsic_height_fallback(), content="0")
}

///|
test "Transform::is_none not-zero translate falls through" {
  let t : Transform = {
    ..Transform::none(),
    translate_x: TranslateValue::Length(5.0),
  }
  assert_false(t.is_none())
}

///|
test "All style Show impls" {
  inspect(TableLayout::Auto, content="Auto")
  inspect(ScrollSnapAxis::None, content="None")
  inspect(ScrollSnapStrictness::None, content="None")
  inspect(BreakBefore::Auto, content="Auto")
  inspect(BreakBefore::Avoid, content="Avoid")
  inspect(BreakInside::Auto, content="Auto")
  inspect(ColumnSpan::None, content="None")
  inspect(VerticalAlign::Baseline, content="Baseline")
  inspect(VerticalAlign::Top, content="Top")
  inspect(VerticalAlign::Middle, content="Middle")
  inspect(VerticalAlign::Bottom, content="Bottom")
  inspect(VerticalAlign::TextBottom, content="TextBottom")
  inspect(VerticalAlign::Super, content="Super")
}

///|
test "Style::has_multicol with MinContent/MaxContent/FitContent column-width" {
  let s_min : Style = { ..Style::default(), column_width: @types.MinContent }
  assert_false(s_min.has_multicol())
  let s_max : Style = { ..Style::default(), column_width: @types.MaxContent }
  assert_false(s_max.has_multicol())
  let s_fit : Style = {
    ..Style::default(),
    column_width: @types.FitContent(100.0),
  }
  assert_false(s_fit.has_multicol())
}

///|
test "BoxShadow::new constructs public box shadow values" {
  let shadow = BoxShadow::new(
    false,
    3.0,
    2.0,
    4.0,
    1.0,
    @types.Color::rgba(10, 20, 30, 0.5),
  )
  inspect(shadow.inset, content="false")
  inspect(shadow.offset_x, content="3")
  inspect(shadow.offset_y, content="2")
  inspect(shadow.blur_radius, content="4")
  inspect(shadow.spread_radius, content="1")
  inspect(shadow.color.r, content="10")
  inspect(shadow.color.g, content="20")
  inspect(shadow.color.b, content="30")
  inspect(shadow.color.a, content="0.5")
}
