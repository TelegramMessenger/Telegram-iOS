import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** Cut over a range that ENTERS a media unit's caption from
/// outside it — from the paragraph above into the caption, or across a unit into the next one's caption —
/// writes the WHOLE unit to the clipboard (the copy snaps an endpoint inside a unit to the unit's span,
/// `Document.expandingRangeOverNonTextBlocks`) but deletes only the text (a range that enters a unit keeps
/// its atom, `truncateAroundMediaUnits`). The photo stays in the composer AND goes to the clipboard, so
/// the paste that follows adds a second copy of it: Cut then Paste in place is not a round trip, and the
/// message goes out with the photo twice.
///
///     [p "Before the photo."] [media cap="A caption here"] [p "After it."]
///     select 13..<21 ("oto.⏎￼⏎A"), Cut   → [p "Before the ph"] [media cap=" caption here"] [p "After it."]
///                                         (the photo stays; the clipboard holds the whole unit)
///     Paste                               → [p "Before the photo."] [media "A caption here"]
///                                           [media " caption here"] [p "After it."]   — two photos
///     [p "Listen"] [audio] [album cap="Two …"] [p "tail"], select 8..<12, Cut, Paste inside "Listen"
///                                         → a second audio and a second album (probe, trial 158)
///
/// Controls: a Cut wholly inside one caption (the caption is a text region: its text is copied and cut),
/// and a Cut covering the whole unit (the unit is copied and deleted), each round-trip exactly.
///
/// **How it was seen.** p19 roam, 2026-09-25: a probe comparing a local drag-and-drop move with Cut +
/// Paste over random ranges of the fuzz's starting documents; the move is right (one photo), and four
/// Cut + Paste oracles came back with the medium duplicated.
///
/// **Suspected cause.** `writeSelectionToPasteboard()` / `cut:` (`RichTextEngineEditorView+Clipboard.swift`)
/// copies the EXPANDED range, then the deletion goes through the gate's `replaceAcrossBlocks`, whose media
/// rule keeps a partly covered unit's atom and caption tail. The two answer "what does this range hold"
/// differently; either the cut must delete what it copied or copy what it deletes.
///
/// **Tier 1**: `cut:` / `paste:` on the engine view.
@available(iOS 18.4, *)
final class HarnessCutIntoCaptionMediaDuplicationTests: XCTestCase {
    typealias E = HarnessEdited

    private static let photo = ChatInputContent(blocks: [E.paragraph([E.run("Before the photo.")]), E.media(caption: "A caption here"), E.paragraph([E.run("After it.")])])

    func testCutFromAParagraphIntoACaptionThenPasteKeepsOnePhoto() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        // "Before the photo.\n\u{FFFC}\nA caption here\nAfter it.": 13..<21 is "oto.⏎￼⏎A".
        HarnessComposerFuzzTests.perform(driver, start: Self.photo, ops: [.select(13, 21), .cut])
        let afterCut = driver.model()
        HarnessComposerFuzzTests.execute(.paste, on: driver)
        driver.settle(0.3)
        let pasted = driver.model()
        XCTAssertEqual(E.mediaCount(pasted), 1, "Cut then Paste duplicated the photo:\n  after cut   \(E.describe(afterCut))\n  after paste \(E.describe(pasted))")
    }

    func testCutAcrossAnAlbumIntoItsCaptionThenPasteElsewhereKeepsOneOfEach() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        // "Listen\n\u{FFFC}\n\u{FFFC}\nTwo Bo \u{FFFC}\ntail": 8..<12 is "⏎￼⏎T" (after the audio, over the
        // album's atom, into its caption); the paste goes inside "Listen" (2), where a drag would drop it.
        let start = HarnessComposerFuzzTests.editedStartingContents()[5]
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(8, 12), .cut, .select(2, 2)])
        let afterCut = driver.model()
        HarnessComposerFuzzTests.execute(.paste, on: driver)
        driver.settle(0.3)
        let pasted = driver.model()
        XCTAssertEqual(E.mediaCount(pasted), 2, "Cut then Paste duplicated the media:\n  after cut   \(E.describe(afterCut))\n  after paste \(E.describe(pasted))")
    }

    // Controls.

    func testControlCutInsideOneCaptionThenPasteIsARoundTrip() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        // "A caption here" is 20..<34; cut "caption" (22..<29).
        HarnessComposerFuzzTests.perform(driver, start: Self.photo, ops: [.select(22, 29), .cut, .paste])
        XCTAssertEqual(FuzzModel.normalized(driver.model()), FuzzModel.normalized(Self.photo), E.describe(driver.model()))
    }

    func testControlCutOfTheWholeUnitThenPasteKeepsOnePhoto() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        // 13..<35 reaches from "oto." through the caption's paragraph break.
        HarnessComposerFuzzTests.perform(driver, start: Self.photo, ops: [.select(13, 35), .cut, .paste])
        XCTAssertEqual(E.mediaCount(driver.model()), 1, E.describe(driver.model()))
    }
}
