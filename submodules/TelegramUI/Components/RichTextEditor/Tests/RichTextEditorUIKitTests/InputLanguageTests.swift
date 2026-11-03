#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class InputLanguageTests: XCTestCase {
    /// A primary-language code that the simulator actually has active, so the pre-selection
    /// branch finds a matching `UITextInputMode`. Skips if the host exposes none (defensive).
    private func anActiveLanguage() throws -> String {
        guard let lang = UITextInputMode.activeInputModes.compactMap({ $0.primaryLanguage }).first else {
            throw XCTSkip("No active input mode with a primary language on this host")
        }
        return lang
    }

    func test_canvas_preselectsInitialLanguageOnce() throws {
        let lang = try anActiveLanguage()
        let canvas = DocumentCanvasView()
        canvas.initialPrimaryLanguage = lang

        // First query returns the matching input mode (drives the keyboard's initial language).
        XCTAssertEqual(canvas.textInputMode?.primaryLanguage, lang)
        // The one-time flag is now consumed: a detached (non-first-responder) view falls through
        // to super, which reports no input mode.
        XCTAssertNil(canvas.textInputMode)
    }

    func test_canvas_resetReArmsPreselection() throws {
        let lang = try anActiveLanguage()
        let canvas = DocumentCanvasView()
        canvas.initialPrimaryLanguage = lang
        XCTAssertEqual(canvas.textInputMode?.primaryLanguage, lang) // consume

        canvas.resetInitialPrimaryLanguage()
        XCTAssertEqual(canvas.textInputMode?.primaryLanguage, lang) // re-armed
    }

    func test_canvas_unknownLanguageFallsThrough() throws {
        let canvas = DocumentCanvasView()
        canvas.initialPrimaryLanguage = "zz-not-a-real-language"
        // No active mode matches → falls through to super (nil for a detached view).
        // This first query also CONSUMES the one-shot.
        XCTAssertNil(canvas.textInputMode)

        // The one-shot is now consumed: setting a real, active language afterward is NOT
        // picked up — if the flag had not flipped, this query would return the matching mode
        // (non-nil, == lang) instead of nil. This proves consumption directly, not just via
        // the detached-view nil.
        let lang = try anActiveLanguage()
        canvas.initialPrimaryLanguage = lang
        XCTAssertNil(canvas.textInputMode)
    }

    func test_facade_forwardsPreselectionAndReadBack() throws {
        let lang = try anActiveLanguage()
        let view = RichTextEditorView()
        view.initialInputPrimaryLanguage = lang

        // Reading the live language through the façade consumes the one-time pre-selection on the canvas.
        XCTAssertEqual(view.inputPrimaryLanguage, lang)

        // Reset re-arms it through the façade.
        view.resetInputPrimaryLanguage()
        XCTAssertEqual(view.inputPrimaryLanguage, lang)
    }
}
#endif
