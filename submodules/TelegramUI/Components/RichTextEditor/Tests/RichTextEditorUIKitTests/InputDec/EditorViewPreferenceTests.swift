#if canImport(UIKit)
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task E2: `RichTextEditorView` gained a public `init(frame:inputBackend:)` so a host (the chat
/// composer, driven by the `inputDecTextBackend` experimental setting) can name WHICH input backend
/// the editor is built for, without any backend type entering the view's public API.
///
/// `@MainActor`: `RichTextEditorView` is a `UIView` subclass and `IDTextEditorBackend.isSupported()`
/// is main-actor isolated (see `RichTextInputCanvasFactory.swift`'s doc comment on the same point).
/// An XCTestCase's test methods are nonisolated by default, so this class-level annotation is
/// required — matching the convention in `CanvasFactoryTests` / `IsSupportedTests`. Not in the task
/// brief's snippet, which predates that constraint; recorded here as a deliberate deviation.
@MainActor
final class EditorViewPreferenceTests: XCTestCase {
    /// Production must be unaffected: the no-argument / `init(frame:)` path still selects `.legacy`.
    /// (`CanvasFactoryTests.test_defaultEditorViewStillUsesTheLegacyCanvas` asserts the same thing
    /// from the factory's side; this one guards the *initializer split* specifically — the
    /// convenience initializer must keep forwarding `.legacy`.)
    func test_defaultInitStillProducesTheLegacyCanvas() {
        XCTAssertTrue(type(of: RichTextEditorView().canvas) == DocumentCanvasView.self)
    }

    func test_explicitLegacyPreferenceProducesTheLegacyCanvas() {
        let editor = RichTextEditorView(frame: .zero, inputBackend: .legacy)
        XCTAssertTrue(type(of: editor.canvas) == DocumentCanvasView.self)
    }

    /// The positive arm: on a runtime the InputDec backend can drive, naming it must actually
    /// produce the ID canvas — otherwise the whole preference is inert and the two tests above
    /// would pass against a view that ignores its argument.
    @available(iOS 17.0, *)
    func test_inputDecIfSupportedProducesTheIDCanvasWhenSupported() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let editor = RichTextEditorView(frame: .zero, inputBackend: .inputDecIfSupported)
        XCTAssertTrue(editor.canvas is IDDocumentCanvasView)
    }
}
#endif
