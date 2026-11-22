import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p23 fix wave, 2026-10-02; reduced from default fuzz seed 48).** Two adjacent identical custom
/// emoji — the chat's emoji keyboard inserting the same custom emoji next to one already there — are two runs
/// with EQUAL attributes in the chat's model (`ChatInputRun` keeps the file id, not the editor's per-occurrence
/// instance). Anything that coalesces equal runs makes them ONE run whose text is both emoji, and the
/// composer's content bridge turned such a run into ONE atom holding both as its alt text
/// (`runs(fromChatInputRuns:)`): the composer drew one emoji where the model held two, and the model's axis and
/// the engine's disagreed from then on.
///
/// The seed reached it through the fuzz's OWN normaliser: the end-of-sequence edit-reload round trip sends the
/// NORMALISED tip, and `FuzzModel.merged` coalesced the two emoji runs, so the reload set a one-run pair. The
/// editor never makes that model itself; a sender that coalesces runs, or a message whose custom-emoji entity
/// covers two emoji, does.
///
/// **Fixed at both ends:** the bridge makes one atom per character of a custom-emoji run (each with its own
/// ref), the composer reports that normalisation back so the chat's copy is what it shows, and the fuzz's
/// normaliser keeps atoms (custom emoji, buttons, formulas) one run each.
///
/// **Tier 1**: an external set, the chat's emoji keyboard (`HarnessChatInserts`), the send path's edit load.
@available(iOS 18.4, *)
final class HarnessAdjacentCustomEmojiRunTests: XCTestCase {
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

    private func emojiRuns(_ content: ChatInputContent) -> [String] {
        var result: [String] = []
        for block in content.blocks {
            guard case let .paragraph(paragraph) = block else { continue }
            for run in paragraph.runs {
                if case .customEmoji? = run.attributes.entity { result.append(run.text) }
            }
        }
        return result
    }

    private func attachmentCount() -> Int {
        var count = 0
        for block in self.driver.editor.engine.attributedBlocks {
            block.enumerateAttribute(.attachment, in: NSRange(location: 0, length: block.length), options: []) { value, range, _ in
                if value != nil { count += range.length }
            }
        }
        return count
    }

    // MARK: - Red before the fix

    /// The seed-48 reduction: two adjacent custom emoji inserted by the chat survive the edit-reload round
    /// trip the fuzz makes (which sends the normalised model).
    func testTwoAdjacentInsertedEmojiSurviveTheEditReloadRoundTrip() {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("a")]), E.paragraph([])]))
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.length, length: 0))
        self.driver.settle(0.1)
        XCTAssertNil(HarnessComposerFuzzTests.chatInsertViolation("😀", custom: true, on: self.driver))
        XCTAssertNil(HarnessComposerFuzzTests.chatInsertViolation("😀", custom: true, on: self.driver))
        XCTAssertEqual(self.emojiRuns(self.driver.model()), ["😀", "😀"], "precondition: \(E.describe(self.driver.model(), merging: false))")
        let violation = HarnessComposerFuzzTests.editReloadViolation(self.driver, tip: FuzzModel.normalized(self.driver.model()))
        XCTAssertNil(violation, violation ?? "")
        XCTAssertEqual(self.attachmentCount(), 2)
    }

    /// A custom-emoji run holding TWO emoji, set from outside, is two atoms: drawn twice, two runs in the
    /// model, and the chat's copy (what Send reads) is what the composer shows.
    func testASetCustomEmojiRunOfTwoEmojiIsTwoAtoms() {
        let pair = ChatInputRun(text: "😀😀", attributes: E.emoji().attributes)
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("a")]), E.paragraph([pair])]))
        XCTAssertEqual(self.attachmentCount(), 2)
        XCTAssertEqual(self.emojiRuns(self.driver.model()), ["😀", "😀"], E.describe(self.driver.model(), merging: false))
        let violations = self.driver.unfilteredViolations()
        XCTAssertTrue(violations.isEmpty, "\(violations)")
    }

    /// The fuzz's normaliser keeps atoms apart.
    func testTheFuzzNormaliserKeepsAdjacentEmojiApart() {
        let content = ChatInputContent(blocks: [E.paragraph([E.emoji(), E.emoji(), E.run("x"), E.run("y")])])
        guard case let .paragraph(paragraph) = FuzzModel.normalized(content).blocks[0] else { return XCTFail() }
        XCTAssertEqual(paragraph.runs.map(\.text), ["😀", "😀", "xy"])
    }

    // MARK: - Control

    /// Two separate emoji runs set from outside were always two atoms.
    func testControlTwoSeparateRunsAreTwoAtoms() {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("a")]), E.paragraph([E.emoji(), E.emoji()])]))
        XCTAssertEqual(self.attachmentCount(), 2)
        XCTAssertEqual(self.emojiRuns(self.driver.model()), ["😀", "😀"])
    }
}
