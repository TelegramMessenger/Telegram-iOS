import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, removing a link across a PULL QUOTE's author line (Format ▸
/// Link ▸ Remove) left the line drawn in the BODY colour where its role derives the caption colour,
/// which the verifier reports as `NSColor` drift and traps on:
///
///     [p "Intro"] [pull "Body" author "Someone"] → link 0..<18 → remove the link over 0..<18
///       engine: author drawn primary-coloured; drift NSColor on the author line
///     control: the same on two plain paragraphs
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 18 (`.link("",
/// selecting:)` over a range reaching a pull quote's author line); reduced by hand.
///
/// **Cause.** `removeLink` (`+Links.swift`) wrote the body colour on every run it touched. Fixed: the
/// link commands end by re-deriving the touched blocks' presentation from their roles
/// (`normalisePresentation(ofBlocksTouching:)`).
///
/// **Tier 1**: Format ▸ Link through the panel (answered by `linkPromptOverride`) is what the menu calls.
@available(iOS 18.4, *)
final class HarnessLinkRemovalColourTests: XCTestCase {
    private func drift(_ start: ChatInputContent, _ range: (Int, Int)) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.link("https://telegram.org", selecting: range), .link("", selecting: range)])
        return driver.engineVerifierViolations()
    }

    func testRemovingALinkAcrossAPullQuoteAuthorKeepsItsColour() throws {
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Body")], author: [ChatInputRun(text: "Someone")])),
        ])
        XCTAssertEqual(try self.drift(start, (0, 18)), [])
    }

    /// Control: two plain paragraphs.
    func testControlPlainParagraphs() throws {
        XCTAssertEqual(try self.drift(HarnessContent.plainText("First paragraph.\nSecond paragraph."), (2, 20)), [])
    }
}
