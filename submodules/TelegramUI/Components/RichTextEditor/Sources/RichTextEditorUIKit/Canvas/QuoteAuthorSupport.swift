#if canImport(UIKit)
import RichTextEditorCore

/// Force render-only bold (and, when `italic` is set — pull quotes only — render-only italic too) + inject
/// the author text color as the DEFAULT foreground (only where the run has no explicit color). All of these
/// are ambient — stripped on read-back (see `quoteAuthorStripAmbientStyle`). A run that already carries an
/// explicit user color is left alone (round-trips as explicit, unchanged).
@available(iOS 13.0, *)
func quoteAuthorRenderRuns(_ runs: [TextRun], textColor: RGBAColor?, italic: Bool = false) -> [TextRun] {
    runs.map { var r = $0; r.attributes.bold = true; if italic { r.attributes.italic = true }
               if r.attributes.foreground == nil { r.attributes.foreground = textColor }; return r }
}
/// Strip the ambient bold (and, when `italic` is set, the ambient italic) AND the ambient author text color
/// so none of it persists into the model. Only a foreground EXACTLY equal to the injected default is
/// stripped — a genuinely different explicit color (set by the user) round-trips unchanged.
@available(iOS 13.0, *)
func quoteAuthorStripAmbientStyle(_ runs: [TextRun], textColor: RGBAColor?, italic: Bool = false) -> [TextRun] {
    runs.map { var r = $0; r.attributes.bold = false; if italic { r.attributes.italic = false }
               if r.attributes.foreground == textColor { r.attributes.foreground = nil }; return r }
}
#endif
