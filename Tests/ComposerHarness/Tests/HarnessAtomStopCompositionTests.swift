import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, an IME composition (Japanese, Chinese, Korean — anything
/// that delivers marked text) with the caret at a MEDIA atom's stop is not composed: the atom-stop rule
/// treats every `setMarkedText` delivery as a finished keystroke.
///
///     [p "Before"] [media "Cap"] [p "After"]    engine "Before\n\u{FFFC}\nCap\nAfter"
///     caret 7 (before the atom; ↓ from "Before" lands here), compose k → か → … → 漢字, commit
///       → [p "k"] [p "か"] [p "かn"] [p "かん"] [p "かんj"] [p "かんじ"] [media] …  one paragraph per
///         candidate, and one Undo does not take them back
///     caret 8 (after the atom), compose, cancel
///       → caption "漢字かんじかんjかんかnかkCap": every candidate stays, accumulated
///     an audio atom's trailing stop (caption-less): cancel leaves a paragraph "k"
///     control: the same composition inside the caption behaves (commit types "漢字", cancel changes
///     nothing); typing "Z" at caret 7 mints ONE paragraph
///
/// ↓ and → both put the caret on these stops (measured: → visits 7 and 8, ↓ from the first line lands
/// on 7), so a CJK user editing a message with a photo hits this with the next keystroke.
///
/// **How it was seen.** p13 probe, 2026-09-24 (the fuzz's `compose` oracle at an atom's stops).
///
/// **Suspected cause.** `decideTextInputAtAnAtomUnit` (`+MediaEditing.swift`), reached from
/// `decideTextInput` (`+SurfaceGate.swift`) for `.standalone(.media)`, mints a paragraph (stop 0) or
/// redirects to the caption (stop 1) and then types the delivered text there as a plain insertion. A
/// composition's deliveries arrive through the same gate (`tgid_isResolvingCompositionSelection` is the
/// only composition awareness in it), so each candidate is committed where it lands and the next
/// candidate starts over at the atom's stop.
///
/// **Tier 1**: the composition goes through `setMarkedText(_:selectedRange:)` / `unmarkText`, the
/// keyboard's own entry points; the oracle is the fuzz's (`composeViolation`: the committed result
/// equals typing, a cancel changes nothing, one undo reverts it).
@available(iOS 18.4, *)
final class HarnessAtomStopCompositionTests: XCTestCase {
    typealias E = HarnessEdited

    private static let media = ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(caption: "Cap"), E.paragraph([E.run("After")])])

    private func compose(_ start: ChatInputContent, caret: Int, _ commit: FuzzCommit) throws -> (violation: String?, model: ChatInputContent) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(caret, caret)])
        let violation = HarnessComposerFuzzTests.composeViolation(.japanese, commit, selecting: nil, on: driver)
        driver.settle(0.1)
        return (violation, driver.model())
    }

    func testACompositionBeforeAMediaAtomIsOneParagraph() throws {
        let result = try self.compose(Self.media, caret: 7, .unmark)
        XCTAssertNil(result.violation, E.describe(result.model))
    }

    func testACancelledCompositionAfterAMediaAtomChangesNothing() throws {
        let result = try self.compose(Self.media, caret: 8, .cancel)
        XCTAssertNil(result.violation, E.describe(result.model))
    }

    func testACancelledCompositionAfterAnAudioAtomChangesNothing() throws {
        let result = try self.compose(ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.audio(), E.paragraph([E.run("After")])]), caret: 8, .cancel)
        XCTAssertNil(result.violation, E.describe(result.model))
    }

    /// Control: the same composition inside the caption.
    func testControlACompositionInsideTheCaptionBehaves() throws {
        let committed = try self.compose(Self.media, caret: 10, .unmark)
        XCTAssertNil(committed.violation, E.describe(committed.model))
        let cancelled = try self.compose(Self.media, caret: 10, .cancel)
        XCTAssertNil(cancelled.violation, E.describe(cancelled.model))
    }
}
