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
pub(all) struct RenderOptions {
  image_resolver : ((String) -> Image?)?
}

///|
pub fn RenderOptions::default() -> RenderOptions {
  { image_resolver: None }
}

///|
/// Return these options with a host callback for decoded raster images.
pub fn RenderOptions::with_image_resolver(
  image_resolver : (String) -> Image?,
) -> RenderOptions {
  { image_resolver: Some(image_resolver) }
}

///|
pub(all) struct RenderResult {
  image : Image
  diagnostics : Array[RenderDiagnostic]
}
