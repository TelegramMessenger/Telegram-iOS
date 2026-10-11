import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, pasting the editor's OWN clipboard (anything copied or cut
/// in the composer — it carries a `Document` fragment) with the caret in a MEDIA CAPTION deletes the
/// whole media unit, photo and caption, and puts the pasted text in its place. When the copy came from
/// the caption itself the paste does nothing at all. A plain-text paste into the same caption works.
///
///     [p "Before"] [media "Cap"] [p "After"]    engine "Before\n\u{FFFC}\nCap\nAfter"
///     copy "Bef" (0..<3), caret in the caption (9, 10 or 12), Paste
///                                              → [p "Before"] [p "Bef"] [p "After"]: the photo is gone
///     copy "a" from the caption (10..<11), caret at the caption's end, Paste → nothing changes
///     controls: `pasteText("abc")` (a plain string) into the caption → "Cabc…"-style insert, media kept;
///     the same fragment pasted into a DETAILS title or a pull quote's author inserts in place
///
/// Copy a word, paste it into a photo's caption is the ordinary way to edit a caption, and the photo
/// vanishes (Undo restores it).
///
/// **How it was seen.** p13 probe, 2026-09-24.
///
/// **Suspected cause.** `pasteFragment(from:)` (`+Clipboard.swift`) splices the fragment with
/// `replaceRange(from:to:with:)` at `globalPosition(atFlatOffset:)` of the caret. A caption position is
/// inside the media NODE's span, and Core's `replacingRange` treats a fragment landing there as
/// replacing the media block rather than inserting into its caption. The plain-text path goes through
/// the engine's own insertion, which the caption line takes.
///
/// **Tier 1**: `copy:` / `paste:` on the engine view.
@available(iOS 18.4, *)
final class HarnessCaptionFragmentPasteTests: XCTestCase {
    typealias E = HarnessEdited

    private static let media = ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(caption: "Cap"), E.paragraph([E.run("After")])])

    private func run(_ ops: [FuzzOp], start: ChatInputContent = HarnessCaptionFragmentPasteTests.media) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return driver.model()
    }

    private func caption(_ content: ChatInputContent) -> String? {
        for block in content.blocks {
            if case let .media(media) = block {
                return media.caption.map(\.text).joined()
            }
        }
        return nil
    }

    func testPastingACopiedWordInsideACaptionKeepsTheMedia() throws {
        let got = try self.run([.select(0, 3), .copy, .select(10, 10), .paste])
        XCTAssertEqual(self.caption(got), "CBefap", "the paste replaced the media unit: \(E.describe(got))")
    }

    func testPastingACopiedWordAtTheEndOfACaptionKeepsTheMedia() throws {
        let got = try self.run([.select(0, 3), .copy, .select(12, 12), .paste])
        XCTAssertEqual(self.caption(got), "CapBef", "the paste replaced the media unit: \(E.describe(got))")
    }

    func testPastingTextCopiedFromTheCaptionIntoItInserts() throws {
        let got = try self.run([.select(10, 11), .copy, .select(12, 12), .paste])
        XCTAssertEqual(self.caption(got), "Capa", "the paste did nothing: \(E.describe(got))")
    }

    /// Control: a plain-string paste into the caption inserts (smart-insert spacing included).
    func testControlPastingPlainTextInsideACaptionInserts() throws {
        let got = try self.run([.select(12, 12), .pasteText("abc")])
        XCTAssertEqual(self.caption(got), "Cap abc", E.describe(got))
    }

    /// Control: the same fragment pasted into a details title inserts in place.
    func testControlPastingACopiedWordIntoADetailsTitleInserts() throws {
        let start = ChatInputContent(blocks: [E.paragraph([E.run("Before")]), .details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("body")])]), title: [E.run("Title")], expanded: true))])
        let got = try self.run([.select(0, 3), .copy, .select(9, 9), .paste], start: start)
        XCTAssertEqual(E.describe(got), "[p body \"Before\"] [details title=\"TiBeftle\" [p body \"body\"]]")
    }
}
