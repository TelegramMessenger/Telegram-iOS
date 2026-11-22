import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; CORRUPTS WHAT IS SENT):** plain text of two or more lines ENDING in a line
/// break (`"l1\nl2\n"`, what most copies of whole lines are, and what an HTML import always ends in) pasted
/// at a MEDIUM's stops breaks the unit:
/// - at the atom's LEADING stop (the caret just before the photo): the medium leaves the model — `[p "Before"]
///   [media cap="Cap"] [p "After"]` → `[p "Before"] [p "l1l2"] [p "\u{FFFC}"] [p "Cap"] [p "After"]`: the
///   photo is gone, its atom is a bare `U+FFFC` paragraph (sent literally), the caption a loose paragraph,
///   and the pasted line break is lost; inside a block quote the same;
/// - at the TRAILING stop (just after the photo): the model and the engine's text disagree (the fuzz's
///   engine-axis invariant), the caption holding `" l1l2Cap"` with an extra empty paragraph after it.
/// Controls: `"l1\nl2"` (no trailing break) and `"l1\n"` at the leading stop keep the medium.
///
/// **How it was seen:** the p20 `externalPaste` fuzz op (edited-content seed 17: an HTML paste at the leading
/// stop of a quoted medium), reduced by a greedy op reducer to one paste, then to plain text.
///
/// **Suspected:** the engine's own paste at a media unit's stop (not a caption, not body text, so markdown
/// and the fragment paths decline) splits the atom's line with the trailing break, and settle's unit
/// repair (`settleMediaAtomIntegrity`, `+Settle.swift`) cannot re-attach an atom that is no longer followed
/// by its caption.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessPasteAtMediaStopTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    /// `[p "Before"] [media cap="Cap"] [p "After"]`: the atom is at 7, its trailing stop at 8.
    private static let top = ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(1, caption: "Cap"), E.paragraph([E.run("After")])])
    /// `[quote [p "Al said"] [media cap="In a quote"]] [p "out"]`: the atom is at 8.
    private static let quoted = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("Al said")]), E.media(2, caption: "In a quote")]), collapsed: false)), E.paragraph([E.run("out")])])

    private func paste(_ text: String, into content: ChatInputContent, at caret: Int) -> ChatInputContent {
        self.driver.arrange(content)
        XCTAssertEqual((self.driver.viewText() as NSString).character(at: caret), 0xFFFC, "precondition: the caret is at the atom")
        self.driver.setViewSelection(NSRange(location: caret, length: 0))
        self.driver.settle(0.1)
        UIPasteboard.general.items = [["public.utf8-plain-text": text]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.5)
        return self.driver.model()
    }

    private func assertMediumKept(_ model: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(E.mediaCount(model), 1, "the paste destroyed the medium: \(E.describe(model))", file: file, line: line)
        XCTAssertTrue(FuzzModel.bareAttachments(model).isEmpty, "a bare U+FFFC is left in the model: \(E.describe(model))", file: file, line: line)
    }

    func testTwoLinesPastedBeforeAMediumKeepTheMedium() {
        self.assertMediumKept(self.paste("l1\nl2\n", into: Self.top, at: 7))
    }

    func testTwoLinesPastedBeforeAQuotedMediumKeepTheMedium() {
        self.assertMediumKept(self.paste("l1\nl2\n", into: Self.quoted, at: 8))
    }

    func testTwoLinesPastedAfterAMediumKeepTheModelOnTheEngineAxis() {
        // The trailing stop: the caret after the atom.
        self.driver.arrange(Self.top)
        self.driver.setViewSelection(NSRange(location: 8, length: 0))
        self.driver.settle(0.1)
        UIPasteboard.general.items = [["public.utf8-plain-text": "l1\nl2\n"]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.5)
        let after = self.driver.model()
        XCTAssertNil(FuzzModel.engineAxisMismatch(after, engineText: self.driver.viewText()), "model \(E.describe(after))")
        XCTAssertEqual(E.mediaCount(after), 1)
    }

    /// Control: two lines WITHOUT a trailing break keep the medium.
    func testControlTwoLinesWithoutATrailingBreakKeepTheMedium() {
        let model = self.paste("l1\nl2", into: Self.top, at: 7)
        self.assertMediumKept(model)
        XCTAssertTrue(model.plainText.contains("l1"))
    }

    /// Control: one line with a trailing break keeps the medium.
    func testControlOneLineWithATrailingBreakKeepsTheMedium() {
        self.assertMediumKept(self.paste("l1\n", into: Self.top, at: 7))
    }
}
