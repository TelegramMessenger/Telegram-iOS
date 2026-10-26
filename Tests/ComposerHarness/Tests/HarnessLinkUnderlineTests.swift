import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, UNDERLINE on a LINKED run is drawn but not in the model, in
/// either order, so the message sends the link without the underline the user sees:
///
///     "abc def ghi" → Format ▸ Underline on "def" → Format ▸ Link on "def"
///       engine: model [p "abc " [e]"def" " ghi"] (no underline); "def" drawn underlined
///     Link first, then Underline: the same
///     remove the link again: the model shows [u]"def" — the underline was in the storage all along
///     control: Link then Bold keeps both ([b,e]"def"); a link alone is not drawn underlined
///
/// The engine's verifier reports NSUnderline drift (the role derives no underline for the run) and
/// traps in any test process. A related face, invisible: after a link removal and re-link, runs can
/// carry a stale `NSUnderline = 0` the verifier also reports (fuzz seeds 13, 21).
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine, with links added to the op mix),
/// 2026-09-23: seeds 2, 5, 17, 24 reduced to Link + Underline by the probe's greedy reducer.
///
/// **Suspected cause.** The read-back (`EngineDocumentBridge` model runs) drops `underline` on a run
/// that carries a link, while the storage keeps it.
///
/// **Tier 1**: `performFormatAction(.underline)` and Format ▸ Link through the panel (answered by
/// `linkPromptOverride`) are what the menu calls.
@available(iOS 18.4, *)
final class HarnessLinkUnderlineTests: XCTestCase {
    private static let start = HarnessContent.plainText("abc def ghi")

    private func run(_ ops: [FuzzOp]) throws -> (run: ChatInputInlineAttributes?, drift: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: ops)
        var def: ChatInputInlineAttributes?
        if case let .paragraph(paragraph)? = driver.model().blocks.first {
            for run in paragraph.runs where run.text == "def" {
                def = run.attributes
            }
        }
        return (def, driver.engineVerifierViolations())
    }

    func testUnderlineThenLinkKeepsTheUnderlineInTheModel() throws {
        let result = try self.run([.format(.underline, selecting: (4, 7)), .link("https://telegram.org", selecting: (4, 7))])
        XCTAssertNotNil(result.run?.entity, "precondition: the link was not applied")
        XCTAssertEqual(result.run?.underline, true, "the underline the screen shows is not in the model")
        XCTAssertEqual(result.drift, [], "the underline on the link is not derived from the role")
    }

    func testLinkThenUnderlineKeepsTheUnderlineInTheModel() throws {
        let result = try self.run([.link("https://telegram.org", selecting: (4, 7)), .format(.underline, selecting: (4, 7))])
        XCTAssertNotNil(result.run?.entity, "precondition: the link was not applied")
        XCTAssertEqual(result.run?.underline, true, "the underline the screen shows is not in the model")
        XCTAssertEqual(result.drift, [], "the underline on the link is not derived from the role")
    }

    /// Control: Link then Bold keeps both.
    func testControlLinkThenBold() throws {
        let result = try self.run([.link("https://telegram.org", selecting: (4, 7)), .format(.bold, selecting: (4, 7))])
        XCTAssertNotNil(result.run?.entity)
        XCTAssertEqual(result.run?.bold, true)
        XCTAssertEqual(result.drift, [])
    }
}
