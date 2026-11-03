#if canImport(UIKit)
import UIKit

/// Which input backend a canvas should be built for. This is a *preference*, not a backend type:
/// no backend type is ever named in `RichTextEditorView`'s API (spec: "No backend type becomes
/// part of `RichTextEditorView`'s public API").
enum RichTextInputBackendPreference {
    case legacy
    /// Use the InputDec backend when the runtime supports it; fall back to legacy otherwise.
    case inputDecIfSupported
    /// Debug/comparison only: fail loudly instead of falling back.
    case inputDecRequired
}

/// `@MainActor`: `RichTextInputBackend` (and therefore `IDTextEditorBackend`, which declares no
/// isolation of its own) is `@MainActor`-isolated, so `IDTextEditorBackend.isSupported()` and
/// `IDTextEditorBackend()` are main-actor-isolated calls — a NONISOLATED `make(_:)` fails to
/// compile under this package's concurrency checking (`#ActorIsolatedCall`, caught building the
/// UIKit test target; `swift build`/`RichTextEditorCoreTests` never compile this target and so
/// never see it). Every real caller already runs on the main actor (`RichTextEditorView.init`,
/// itself UIView-isolated), so this only states an isolation that was already true in practice.
/// Not part of the task brief's Step-4 snippet, which predates discovering this — recorded here
/// as a deliberate deviation, not a silent fix.
@MainActor
enum RichTextInputCanvasFactory {
    /// The one place backend selection policy lives. `RichTextInputBackend` itself never
    /// chooses or falls back (spec: "Unsupported runtime policy is owned by the canvas factory
    /// or its caller").
    /// The canvas class AND the backend are chosen together, and the backend is INJECTED
    /// through the seam plan's `init(mapper:inputBackend:)`. Constructing
    /// `IDDocumentCanvasView()` bare would silently attach `LegacyRichTextInputBackend()` — the
    /// initializer's `inputBackend ?? LegacyRichTextInputBackend()` default (deviation D30) —
    /// producing an ID-shaped canvas driven by the legacy backend, which type-checks, runs, and
    /// makes every `.inputDec` test pass while testing the wrong thing.
    static func make(_ preference: RichTextInputBackendPreference) -> DocumentCanvasView {
        switch preference {
        case .legacy:
            return DocumentCanvasView()
        case .inputDecIfSupported:
            if #available(iOS 17.0, *), IDTextEditorBackend.isSupported() {
                return IDDocumentCanvasView(inputBackend: IDTextEditorBackend())
            }
            return DocumentCanvasView()
        case .inputDecRequired:
            if #available(iOS 17.0, *), IDTextEditorBackend.isSupported() {
                return IDDocumentCanvasView(inputBackend: IDTextEditorBackend())
            }
            preconditionFailure(
                "inputDecRequired: IDTextEditorBackend.isSupported() == false on this runtime")
        }
    }
}
#endif
