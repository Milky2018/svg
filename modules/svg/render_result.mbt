///|
pub(all) enum RenderDiagnosticKind {
  ParseFailed
  ResourceUnresolved
  ResourceCycle
  ResourceLimitExceeded
} derive(Debug, Eq)

///|
pub(all) enum RenderStage {
  Document
  Stylesheet
  Paint
  Image
  Effects
} derive(Debug, Eq)

///|
pub(all) struct RenderDiagnostic {
  kind : RenderDiagnosticKind
  stage : RenderStage
  resource : String
  node_id : String
}

///|
pub(all) enum TextResourceKind {
  Stylesheet
  SvgDocument
} derive(Debug, Eq)

///|
pub(all) enum PreferredColorScheme {
  Light
  Dark
} derive(Debug, Eq)

///|
pub(all) struct ElementState {
  hover : Bool
  focus : Bool
  active : Bool
  focus_visible : Bool
  focus_within : Bool
} derive(Debug, Eq)

///|
pub fn ElementState::none() -> ElementState {
  {
    hover: false,
    focus: false,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
}

///|
/// Static inputs used while parsing and computing an SVG snapshot.
pub(all) struct RenderEnvironment {
  base_uri : String
  device_pixel_ratio : Double
  color_scheme : PreferredColorScheme
  sample_time_seconds : Double
  element_state_resolver : ((String) -> ElementState)?
}

///|
pub fn RenderEnvironment::default() -> RenderEnvironment {
  {
    base_uri: "",
    device_pixel_ratio: 1.0,
    color_scheme: Light,
    sample_time_seconds: 0.0,
    element_state_resolver: None,
  }
}

///|
pub(all) struct RenderOptions {
  image_resolver : ((String) -> Image?)?
  text_resource_resolver : ((String, TextResourceKind) -> String?)?
  environment : RenderEnvironment
  max_external_depth : Int
  max_external_resources : Int
  max_external_bytes : Int
}

///|
pub fn RenderOptions::default() -> RenderOptions {
  {
    image_resolver: None,
    text_resource_resolver: None,
    environment: RenderEnvironment::default(),
    max_external_depth: 16,
    max_external_resources: 64,
    max_external_bytes: 16 * 1024 * 1024,
  }
}

///|
/// Return these options with a host callback for decoded raster images.
pub fn RenderOptions::with_image_resolver(
  image_resolver : (String) -> Image?,
) -> RenderOptions {
  { ..RenderOptions::default(), image_resolver: Some(image_resolver), }
}

///|
/// Return these options with a host callback for CSS and SVG text resources.
pub fn RenderOptions::with_text_resource_resolver(
  text_resource_resolver : (String, TextResourceKind) -> String?,
) -> RenderOptions {
  {
    ..RenderOptions::default(),
    text_resource_resolver: Some(text_resource_resolver),
  }
}

///|
pub(all) struct RenderResult {
  image : Image
  diagnostics : Array[RenderDiagnostic]
}

///|
pub extend ElementState with Debug::{to_repr}

///|
pub extend ElementState with Eq::{not_equal, equal}

///|
pub extend PreferredColorScheme with Debug::{to_repr}

///|
pub extend PreferredColorScheme with Eq::{not_equal, equal}

///|
pub extend RenderDiagnosticKind with Debug::{to_repr}

///|
pub extend RenderDiagnosticKind with Eq::{not_equal, equal}

///|
pub extend RenderStage with Debug::{to_repr}

///|
pub extend RenderStage with Eq::{not_equal, equal}

///|
pub extend TextResourceKind with Debug::{to_repr}

///|
pub extend TextResourceKind with Eq::{not_equal, equal}
