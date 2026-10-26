#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// UIKit hands the storage façade a raw range replace. Without the latch, "pressed Return"
/// and "typed a newline" and "deleted backward" are the same call, and Telegram's document
/// client would execute them correctly but DIFFERENTLY from the legacy backend.
@available(iOS 17.0, *)
@MainActor
final class IDBackendIntentLatchTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    func test_insertTextIntentWithNewline_becomesInsertParagraphBreak() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.storageFacade.currentIntent = .insertText
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "\n")
        guard case .insertParagraphBreak = h.document.receivedMutations.first else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
        }
    }

    /// `.insertText` is a THREE-value case — `(text: NSAttributedString, replacing:, origin:)`.
    /// A two-value `case .insertText(let text, _)` pattern does not compile, and `text` is an
    /// NSAttributedString, never a String.
    func test_insertTextIntentWithPlainText_becomesInsertText() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.storageFacade.currentIntent = .insertText
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a")
        guard case .insertText(let text, _, let origin) = h.document.receivedMutations.first,
              text.string == "a", origin == .softwareKeyboard else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
        }
    }

    func test_deleteBackwardIntent_forwardsTheProposedRangeVerbatim() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.storageFacade.currentIntent = .deleteBackward
        h.storageFacade.replaceCharacters(in: NSRange(location: 2, length: 3), with: "")
        // `proposedRange` is `NSRange?`, so the comparison promotes the literal.
        guard case .deleteBackward(_, let proposed) = h.document.receivedMutations.first,
              proposed == NSRange(location: 2, length: 3) else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
        }
    }

    /// Paste is an ORIGIN, not a mutation case — there is no `RichTextInputMutation.paste`.
    /// The assertion is therefore on the origin of an `.insertText`, which is also what the
    /// client's `allowsPaste` policy check reads.
    func test_pasteIntent_becomesInsertTextWithThePasteOrigin() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.storageFacade.currentIntent = .paste
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "xy")
        guard case .insertText(let text, _, let origin) = h.document.receivedMutations.first,
              text.string == "xy", origin == .paste else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
        }
    }

    /// The latch is single-transaction-scoped. A second replace with no intervening callback
    /// must NOT reuse the previous intent, or a programmatic edit inherits a keyboard intent.
    func test_theLatchIsClearedAfterEveryTransaction() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.storageFacade.currentIntent = .deleteBackward
        h.storageFacade.replaceCharacters(in: NSRange(location: 2, length: 1), with: "")
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "z")
        XCTAssertEqual(h.storageFacade.currentIntent, .programmatic)
        guard case .replaceText = h.document.receivedMutations.last else {
            return XCTFail("second replace inherited an intent")
        }
    }
}
#endif
