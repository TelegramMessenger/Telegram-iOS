import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, a DETAILS block that ends the document and whose body ends
/// in an EMPTY paragraph does not survive the editor's own Copy → Paste: the empty paragraph leaves
/// the details and becomes a top-level line after it.
///
///     [p "a"] [details "Title" [p "body"] [p ""]], Select All → Copy → Paste over it
///       engine: [p "a"] [details "Title" [p "body"]] [p ""]
///       expected: the document, plus at most the documented trailing line a paste ending in a
///                 non-body block at the document end adds (`HarnessContainerCutPasteRoundTripTests`):
///                 [p "a"] [details "Title" [p "body"] [p ""]] [p ""]
///     Controls: the same details followed by a paragraph round-trips; a block quote whose last child
///     is empty round-trips; an empty paragraph in the MIDDLE of the details body round-trips; get →
///     set → get of the details keeps the empty child.
///
/// **How it was seen.** p17 roam fuzz sweep, default seeds 1-90, seed 69: the copy → paste-back round
/// trip at the end of the sequence (the tip ended in exactly this details).
///
/// **Suspected cause.** Copy, not paste: Select All ends AT the empty last line (an empty range of it),
/// and `Document.extractFragment`'s empty-paragraph coverage rule does not count an empty block that
/// the selection only touches at its start as covered — so the fragment's details has one body
/// paragraph, and the paste's trailing-line rule then adds the line after it. A quote does not show it
/// because its author line follows its children, so Select All covers the empty child. The copy-only
/// case below (paste into an empty composer) tells copy from paste.
///
/// **Tier 1**: Select All / Copy / Paste are the edit-menu actions on the engine view.
final class HarnessDetailsTrailingEmptyLineCopyTests: XCTestCase {
    private func details(_ body: [ChatInputBlock]) -> ChatInputBlock {
        return .details(ChatInputDetails(content: ChatInputContent(blocks: body), title: [ChatInputRun(text: "Title")], expanded: true))
    }

    private var trailingEmptyDetails: ChatInputContent {
        return ChatInputContent(blocks: [HarnessP16.paragraph("a"), self.details([HarnessP16.paragraph("body"), HarnessP16.paragraph("")])])
    }

    /// Select All → Copy → Paste over it; returns the model before and after.
    private func roundTrip(_ content: ChatInputContent) throws -> (before: ChatInputContent, after: ChatInputContent) {
        let arranged = try HarnessP16.arrange(content.blocks)
        defer { HarnessP16.finish(arranged) }
        let before = HarnessP16.content(arranged)
        HarnessP16.perform(arranged, #selector(UIResponderStandardEditActions.selectAll(_:)))
        HarnessP16.perform(arranged, #selector(UIResponderStandardEditActions.copy(_:)))
        HarnessP16.perform(arranged, #selector(UIResponderStandardEditActions.paste(_:)))
        return (before, HarnessP16.content(arranged))
    }

    func testCopyPasteKeepsTheEmptyLastLineInTheDetails() throws {
        let result = try self.roundTrip(self.trailingEmptyDetails)
        XCTAssertTrue(HarnessComposerFuzzTests.equalModuloTrailingLine(result.after, result.before),
                      "Select All → Copy → Paste moved the details' empty last line out:\n  before \(FuzzModel.describe(result.before))\n  after  \(FuzzModel.describe(result.after))")
    }

    /// The copy alone: pasted into an EMPTY composer, the fragment must still hold the empty line inside
    /// the details.
    func testTheCopiedFragmentKeepsTheEmptyLastLine() throws {
        let source = try HarnessP16.arrange(self.trailingEmptyDetails.blocks)
        HarnessP16.perform(source, #selector(UIResponderStandardEditActions.selectAll(_:)))
        HarnessP16.perform(source, #selector(UIResponderStandardEditActions.copy(_:)))
        let expected = HarnessP16.content(source)
        HarnessP16.finish(source)
        let target = try HarnessP16.arrange([HarnessP16.paragraph("")])
        defer { HarnessP16.finish(target) }
        HarnessP16.perform(target, #selector(UIResponderStandardEditActions.paste(_:)))
        let pasted = HarnessP16.content(target)
        XCTAssertTrue(HarnessComposerFuzzTests.equalModuloTrailingLine(pasted, expected),
                      "the copied fragment lost the details' empty last line:\n  copied \(FuzzModel.describe(expected))\n  pasted \(FuzzModel.describe(pasted))")
    }

    func testControlADetailsFollowedByAParagraphRoundTrips() throws {
        let content = ChatInputContent(blocks: self.trailingEmptyDetails.blocks + [HarnessP16.paragraph("z")])
        let result = try self.roundTrip(content)
        XCTAssertEqual(result.after, result.before, "control")
    }

    func testControlAQuoteWithAnEmptyLastChildRoundTrips() throws {
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("a"), HarnessP16.quote([HarnessP16.paragraph("body"), HarnessP16.paragraph("")])])
        let result = try self.roundTrip(content)
        XCTAssertTrue(HarnessComposerFuzzTests.equalModuloTrailingLine(result.after, result.before), "control: \(FuzzModel.describe(result.after))")
    }

    func testControlAnEmptyMiddleLineRoundTrips() throws {
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("a"), self.details([HarnessP16.paragraph("body"), HarnessP16.paragraph(""), HarnessP16.paragraph("x")])])
        let result = try self.roundTrip(content)
        XCTAssertTrue(HarnessComposerFuzzTests.equalModuloTrailingLine(result.after, result.before), "control: \(FuzzModel.describe(result.after))")
    }

    func testControlGetSetGetKeepsTheEmptyLastLine() throws {
        let arranged = try HarnessP16.arrange(self.trailingEmptyDetails.blocks)
        defer { HarnessP16.finish(arranged) }
        XCTAssertEqual(HarnessP16.content(arranged), FuzzModel.normalized(self.trailingEmptyDetails), "control: the set")
    }
}
