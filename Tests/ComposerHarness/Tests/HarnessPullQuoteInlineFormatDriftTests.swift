import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Format ▸ Italic or Format ▸ Monospace on a word inside a
/// PULL QUOTE leaves the word drawn in a face its role does not derive, and the model disagrees
/// with the screen:
///
///     [p "Pull quote next."] [pull "A pulled line."] → select "pulled" → Format ▸ Italic
///       engine: "pulled" is drawn UPRIGHT (.SFUI-Regular) inside the italic pull quote, while the
///       model still reads [pull "A pulled line."] (nothing changed) — the message sends it italic
///     same → Format ▸ Monospace
///       engine: model [pull "A " [m]"pulled" " line."], drawn in the monospaced ITALIC face; the
///       role derives the upright monospaced face
///     control: Bold / Underline / Spoiler on the same word — no drift
///
/// The engine's own end-of-settle verifier (`verifyPresentationIsDerived`) reports this as
/// "presentation does not match its role (NSFont)"; in any test process it TRAPS, which is how the
/// fuzz first saw it (a crash at seed 1).
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23: 27 of 800 steps across
/// seeds 1-20 before this was filtered; reduced by replay to one Format command.
///
/// **Suspected cause.** The pull quote's italic is PRESENTATION (a role property), so the inline
/// italic toggle and the italic-monospace face (`AttributedStringMapper`, the seventh-wave fix)
/// compute a face from the stored run that the bridge's `render(role:)` for a pull quote does not.
///
/// **Tier 1**: `performFormatAction` is what the Format menu calls; the verifier is asked directly
/// with its trap switched off (`FuzzEngineVerifier`).
@available(iOS 18.4, *)
final class HarnessPullQuoteInlineFormatDriftTests: XCTestCase {
    private static let start = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Pull quote next."),
        .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "A pulled line.")])),
    ])

    /// "pulled" is 19..<25 on the engine axis (the paragraph, a newline, then "A ").
    private func drift(after format: FuzzFormat) throws -> (drift: [String], model: ChatInputContent) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: [.format(format, selecting: (19, 25))])
        return (driver.engineVerifierViolations(), driver.model())
    }

    func testItalicInsideAPullQuoteIsDrawnAsTheModelSaysAndChangesTheModel() throws {
        let result = try self.drift(after: .italic)
        XCTAssertEqual(result.drift, [], "Format ▸ Italic in a pull quote left presentation not derived from the role")
    }

    func testMonospaceInsideAPullQuoteIsDrawnInTheDerivedFace() throws {
        let result = try self.drift(after: .monospace)
        XCTAssertEqual(result.drift, [], "Format ▸ Monospace in a pull quote left presentation not derived from the role")
    }

    /// Control: Bold on the same word derives cleanly.
    func testControlBoldInsideAPullQuote() throws {
        let result = try self.drift(after: .bold)
        XCTAssertEqual(result.drift, [], "control: Bold in a pull quote drifted")
    }
}
