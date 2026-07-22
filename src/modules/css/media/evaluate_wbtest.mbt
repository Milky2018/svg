///|
test "media_query_max_width_evaluation" {
  // Test max-width: 50rem (800px)
  // At 375px viewport, should match
  let env_mobile = MediaEnvironment::new(375.0, 600.0)
  // At 1024px viewport, should not match
  let env_desktop = MediaEnvironment::new(1024.0, 768.0)

  // Create max-width: 800px query
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: Some(MediaType::Screen),
    conditions: [MediaFeature::MaxWidth(MediaValue::Dimension(800.0, "px"))],
  }

  // Mobile should match max-width: 800px
  inspect(mq.evaluate(env_mobile), content="true")
  // Desktop should not match max-width: 800px
  inspect(mq.evaluate(env_desktop), content="false")
}

///|
test "media_query_min_width_evaluation" {
  let env_mobile = MediaEnvironment::new(375.0, 600.0)
  let env_desktop = MediaEnvironment::new(1024.0, 768.0)

  // Create min-width: 768px query
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MinWidth(MediaValue::Dimension(768.0, "px"))],
  }

  // Mobile should NOT match min-width: 768px
  inspect(mq.evaluate(env_mobile), content="false")
  // Desktop should match min-width: 768px
  inspect(mq.evaluate(env_desktop), content="true")
}

///|
test "media_query_prefers_color_scheme_light" {
  // Test prefers-color-scheme: light
  let env_light = MediaEnvironment::with_color_scheme(375.0, 600.0, Light)
  let env_dark = MediaEnvironment::with_color_scheme(375.0, 600.0, Dark)
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::PrefersColorScheme("light")],
  }

  // Light mode should match prefers-color-scheme: light
  inspect(mq.evaluate(env_light), content="true")
  // Dark mode should NOT match prefers-color-scheme: light
  inspect(mq.evaluate(env_dark), content="false")
}

///|
test "media_query_prefers_color_scheme_dark" {
  // Test prefers-color-scheme: dark
  let env_light = MediaEnvironment::with_color_scheme(375.0, 600.0, Light)
  let env_dark = MediaEnvironment::with_color_scheme(375.0, 600.0, Dark)
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::PrefersColorScheme("dark")],
  }

  // Light mode should NOT match prefers-color-scheme: dark
  inspect(mq.evaluate(env_light), content="false")
  // Dark mode should match prefers-color-scheme: dark
  inspect(mq.evaluate(env_dark), content="true")
}

///|
test "media_query_parse_and_evaluate_prefers_color_scheme" {
  // End-to-end test: parse media query string and evaluate
  let env_light = MediaEnvironment::with_color_scheme(375.0, 600.0, Light)
  let env_dark = MediaEnvironment::with_color_scheme(375.0, 600.0, Dark)
  let mq_dark = parse_media_query_list("(prefers-color-scheme: dark)")
  let mq_light = parse_media_query_list("(prefers-color-scheme: light)")

  // Dark mode query
  inspect(mq_dark.evaluate(env_light), content="false")
  inspect(mq_dark.evaluate(env_dark), content="true")

  // Light mode query
  inspect(mq_light.evaluate(env_light), content="true")
  inspect(mq_light.evaluate(env_dark), content="false")
}

///|
test "media_query_list_or_semantics" {
  let env = MediaEnvironment::new(375.0, 600.0)

  // Query list with OR semantics: screen, (min-width: 1000px)
  let mq_list : MediaQueryList = {
    queries: [
      {
        negated: false,
        only: false,
        media_type: Some(MediaType::Screen),
        conditions: [],
      },
      {
        negated: false,
        only: false,
        media_type: None,
        conditions: [
          MediaFeature::MinWidth(MediaValue::Dimension(1000.0, "px")),
        ],
      },
    ],
  }

  // First query (screen) matches, so whole list matches
  inspect(mq_list.evaluate(env), content="true")
}

///|
test "media_query_level_4_or_range_evaluation" {
  let mq = parse_media_query_list("(width <= 769px) or (width > 1006px)")
  inspect(mq.evaluate(MediaEnvironment::new(500.0, 600.0)), content="true")
  inspect(mq.evaluate(MediaEnvironment::new(800.0, 600.0)), content="false")
  inspect(mq.evaluate(MediaEnvironment::new(1440.0, 600.0)), content="true")
}

///|
test "media_query_calc_range_evaluation" {
  let mq = parse_media_query_list("(width >= calc(40rem + 1px))")
  inspect(mq.evaluate(MediaEnvironment::new(640.0, 600.0)), content="false")
  inspect(mq.evaluate(MediaEnvironment::new(641.0, 600.0)), content="true")
}

///|
test "MediaQuery negated and only" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq : MediaQuery = {
    negated: true,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MinWidth(MediaValue::Dimension(1000.0, "px"))],
  }
  // negated: min-width 1000 fails on 800 -> negation is true
  inspect(mq.evaluate(env), content="true")
}

///|
test "MediaQuery print and speech are rejected" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq_print : MediaQuery = {
    negated: false,
    only: false,
    media_type: Some(MediaType::Print),
    conditions: [],
  }
  inspect(mq_print.evaluate(env), content="false")
  let mq_speech : MediaQuery = {
    negated: false,
    only: false,
    media_type: Some(MediaType::Speech),
    conditions: [],
  }
  inspect(mq_speech.evaluate(env), content="false")
}

///|
test "MediaQuery All matches" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq : MediaQuery = {
    negated: false,
    only: false,
    media_type: Some(MediaType::All),
    conditions: [],
  }
  inspect(mq.evaluate(env), content="true")
}

///|
test "Empty MediaQueryList matches everything" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let empty = MediaQueryList::new()
  inspect(empty.evaluate(env), content="true")
}

///|
test "MediaQuery::default constructs all/no-conditions" {
  let mq = MediaQuery::default()
  inspect(mq.negated, content="false")
}

///|
test "orientation portrait vs landscape" {
  let portrait = MediaEnvironment::new(400.0, 800.0)
  let landscape = MediaEnvironment::new(800.0, 400.0)
  let mq_p = parse_media_query_list("(orientation: portrait)")
  let mq_l = parse_media_query_list("(orientation: landscape)")
  inspect(mq_p.evaluate(portrait), content="true")
  inspect(mq_p.evaluate(landscape), content="false")
  inspect(mq_l.evaluate(portrait), content="false")
  inspect(mq_l.evaluate(landscape), content="true")
}

///|
test "aspect ratio - exact, min, max" {
  let env_wide = MediaEnvironment::new(1600.0, 900.0)
  let env_square = MediaEnvironment::new(500.0, 500.0)
  let mq_min : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MinAspectRatio(MediaValue::Ratio(16, 9))],
  }
  inspect(mq_min.evaluate(env_wide), content="true")
  inspect(mq_min.evaluate(env_square), content="false")
  let mq_max : MediaQuery = {
    negated: false,
    only: false,
    media_type: None,
    conditions: [MediaFeature::MaxAspectRatio(MediaValue::Ratio(1, 1))],
  }
  inspect(mq_max.evaluate(env_wide), content="false")
  inspect(mq_max.evaluate(env_square), content="true")
}

///|
test "boolean media features" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let make_query = fn(f) {
    let q : MediaQuery = {
      negated: false,
      only: false,
      media_type: None,
      conditions: [f],
    }
    q.evaluate(env)
  }
  inspect(make_query(MediaFeature::Color), content="true")
  inspect(make_query(MediaFeature::ColorGamut), content="true")
  inspect(make_query(MediaFeature::ColorIndex), content="false")
  inspect(make_query(MediaFeature::Grid), content="false")
  inspect(make_query(MediaFeature::Hover), content="true")
  inspect(make_query(MediaFeature::Monochrome), content="false")
  inspect(make_query(MediaFeature::Pointer), content="true")
  inspect(make_query(MediaFeature::Scripting), content="true")
  inspect(make_query(MediaFeature::Update), content="true")
  inspect(make_query(MediaFeature::Custom("unknown", None)), content="true")
}

///|
test "resolution media feature with various units" {
  let env_hd : MediaEnvironment = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    device_pixel_ratio: 2.0,
    color_scheme: Light,
  }
  let mq_min = parse_media_query_list("(min-resolution: 1.5dppx)")
  inspect(mq_min.evaluate(env_hd), content="true")
  let mq_max = parse_media_query_list("(max-resolution: 1.5dppx)")
  inspect(mq_max.evaluate(env_hd), content="false")
  let mq_dpi = parse_media_query_list("(min-resolution: 192dpi)")
  inspect(mq_dpi.evaluate(env_hd), content="true")
}

///|
test "Show for ColorScheme" {
  inspect(ColorScheme::Light, content="Light")
  inspect(ColorScheme::Dark, content="Dark")
}

///|
test "media query - boolean width and height match anything" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq_w = parse_media_query_list("(width)")
  inspect(mq_w.evaluate(env), content="true")
  let mq_h = parse_media_query_list("(height)")
  inspect(mq_h.evaluate(env), content="true")
}

///|
test "media query - width equals exact" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq = parse_media_query_list("(width: 800px)")
  inspect(mq.evaluate(env), content="true")
  let mq_diff = parse_media_query_list("(width: 900px)")
  inspect(mq_diff.evaluate(env), content="false")
}

///|
test "media query - aspect ratio with 0 height returns false" {
  let env_zero : MediaEnvironment = {
    viewport_width: 800.0,
    viewport_height: 0.0,
    device_pixel_ratio: 1.0,
    color_scheme: Light,
  }
  let mq = parse_media_query_list("(min-aspect-ratio: 1/1)")
  inspect(mq.evaluate(env_zero), content="false")
}

///|
test "media query - in/cm/mm units" {
  let env = MediaEnvironment::new(192.0, 600.0)
  // 192px = 2in
  let two_in = parse_media_query_list("(min-width: 2in)")
  inspect(two_in.evaluate(env), content="true")
  let three_in = parse_media_query_list("(min-width: 3in)")
  inspect(three_in.evaluate(env), content="false")
  let cm = parse_media_query_list("(min-width: 5cm)")
  // 5cm ≈ 189px <= 192
  inspect(cm.evaluate(env), content="true")
  let mm = parse_media_query_list("(min-width: 100mm)")
  // 100mm ≈ 378px > 192
  inspect(mm.evaluate(env), content="false")
}

///|
test "media query - resolution dpcm unit" {
  let env : MediaEnvironment = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    device_pixel_ratio: 1.0,
    color_scheme: Light,
  }
  let mq = parse_media_query_list("(min-resolution: 37.8dpcm)")
  // 37.8 dpcm / 37.8 = 1.0 dppx, so >= 1.0 matches
  inspect(mq.evaluate(env), content="true")
}

///|
test "media query - x unit for resolution" {
  let env : MediaEnvironment = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    device_pixel_ratio: 2.0,
    color_scheme: Light,
  }
  let mq = parse_media_query_list("(min-resolution: 1.5x)")
  inspect(mq.evaluate(env), content="true")
}

///|
test "media query - exact height match" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq = parse_media_query_list("(height: 600px)")
  inspect(mq.evaluate(env), content="true")
  let mq2 = parse_media_query_list("(height: 700px)")
  inspect(mq2.evaluate(env), content="false")
}

///|
test "media query - boolean aspect-ratio and resolution match anything" {
  let env = MediaEnvironment::new(800.0, 600.0)
  // bare (aspect-ratio) — no value — should always match (boolean form)
  let mq_ar = parse_media_query_list("(aspect-ratio)")
  inspect(mq_ar.evaluate(env), content="true")
  let mq_res = parse_media_query_list("(resolution)")
  inspect(mq_res.evaluate(env), content="true")
}

///|
test "media query - orientation falls back for unknown value" {
  let env = MediaEnvironment::new(800.0, 600.0)
  let mq = parse_media_query_list("(orientation: sideways)")
  // Unknown orientation matches anything per the impl
  inspect(mq.evaluate(env), content="true")
}

///|
test "media query - resolution exact match" {
  let env : MediaEnvironment = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    device_pixel_ratio: 2.0,
    color_scheme: Light,
  }
  let mq = parse_media_query_list("(resolution: 2dppx)")
  inspect(mq.evaluate(env), content="true")
}

///|
test "media query - prefers-color-scheme unknown value" {
  let env = MediaEnvironment::with_color_scheme(800.0, 600.0, Dark)
  let mq = parse_media_query_list("(prefers-color-scheme: auto)")
  // Unknown scheme matches anything
  inspect(mq.evaluate(env), content="true")
}

///|
test "media query - to_pixels for vw/vh, pt, pc" {
  let env = MediaEnvironment::new(100.0, 100.0)
  // pt: 1pt = 1.333px, so 75pt = 100px
  let mq = parse_media_query_list("(min-width: 75pt)")
  inspect(mq.evaluate(env), content="true")
  // pc: 1pc = 16px, 6.25pc = 100px
  let mq2 = parse_media_query_list("(min-width: 6pc)")
  inspect(mq2.evaluate(env), content="true")
  // vw/vh are resolved against the viewport: 50vw = 50px on a 100px viewport.
  let mq3 = parse_media_query_list("(min-width: 50vw)")
  inspect(mq3.evaluate(env), content="true")
  let mq4 = parse_media_query_list("(min-width: 50vh)")
  inspect(mq4.evaluate(env), content="true")
}

///|
test "media query - vw/vh resolve against the viewport" {
  // Asymmetric viewport so width- and height-relative units differ, and so a
  // raw (unconverted) comparison would give a different boolean than the
  // correct conversion.
  let env = MediaEnvironment::new(1000.0, 200.0)
  // min-width: k vw is satisfiable iff k <= 100 (k vw = k% of the width).
  inspect(
    parse_media_query_list("(min-width: 50vw)").evaluate(env),
    content="true",
  )
  inspect(
    parse_media_query_list("(min-width: 150vw)").evaluate(env),
    content="false",
  )
  // vh resolves against the height even inside a width feature: 150vh = 300px.
  inspect(
    parse_media_query_list("(min-height: 150vh)").evaluate(env),
    content="false",
  )
  inspect(
    parse_media_query_list("(min-width: 10vh)").evaluate(env),
    content="true",
  )
}

///|
test "media query - to_pixels for unknown unit" {
  let env = MediaEnvironment::new(50.0, 100.0)
  // Unknown unit "xyz" falls through to default — treated as raw number
  let mq = parse_media_query_list("(min-width: 30xyz)")
  inspect(mq.evaluate(env), content="true")
}

///|
test "media query - aspect-ratio with Number value" {
  let env = MediaEnvironment::new(1600.0, 900.0)
  // 1600/900 ≈ 1.78
  let mq = parse_media_query_list("(min-aspect-ratio: 1.5)")
  inspect(mq.evaluate(env), content="true")
}

///|
test "various length units in width queries" {
  let env = MediaEnvironment::new(320.0, 600.0)
  // 20em == 320px (at 16px base)
  let mq_em = parse_media_query_list("(min-width: 20em)")
  inspect(mq_em.evaluate(env), content="true")
  let mq_pt = parse_media_query_list("(max-width: 300pt)")
  // 300pt ~ 400px > 320 viewport
  inspect(mq_pt.evaluate(env), content="true")
  let mq_pc = parse_media_query_list("(min-width: 30pc)")
  // 30pc = 480px
  inspect(mq_pc.evaluate(env), content="false")
}
