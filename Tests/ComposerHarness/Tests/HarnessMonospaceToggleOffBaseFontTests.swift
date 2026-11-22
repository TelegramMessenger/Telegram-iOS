import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Format ▸ Monospace applied and then toggled OFF leaves the
/// text without the base-font key (`IDInlineTextBaseFontAttributeName`) its role derives. Also within
/// one paragraph, across two, inside a quote. A second, visible sibling: a character TYPED inside an
/// inline-code run lacks the inline-code presentation (the base font and the grey background), so the
/// pill shows a gap under it, although the model marks it monospace.
///
///     "First paragraph." → select "rst pa" → Monospace → Monospace
///       engine: model plain (correct), drawn .SFUI-Regular (correct), but the base-font key is nil
///       where the role derives .SFUI-Regular
///     [m "abcdef"] → caret at 3 → type "x"   (also an emoji, CJK, Arabic)
///       engine: model [m "abcxdef"]; "x" has no inline-code background and base font .SFUI-Regular
///       where the role derives the monospaced face
///     control: Bold / Italic toggled on and off — no drift; Monospace applied once — no drift
///
/// No visible consequence of the toggle-off case was found (a later Bold / Italic on the same text
/// draws the right face, and the next edit re-derives it); it is filed because the engine's own
/// verifier traps on it in every test process. The typed case is visible.
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23 (seeds 15 and 49); reduced by
/// replay.
///
/// **Suspected cause.** Toggle-off: the inline-code removal restores the face but not the base-font
/// key. Typed: the typed-text policy carries `.rtInlineCode` forward (`markersThatAlwaysContinue`,
/// `+TypedText.swift`) AFTER settle has re-derived presentation (the sixth wave moved that
/// re-attribution after the baseline commit), so the typed run's presentation is never derived.
///
/// **Tier 1**: `performFormatAction` and `insertText` are what the menu and the keyboard call; the
/// verifier is asked directly with its trap off.
@available(iOS 18.4, *)
final class HarnessMonospaceToggleOffBaseFontTests: XCTestCase {
    private func drift(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return driver.engineVerifierViolations()
    }

    private static let two = HarnessContent.plainText("First paragraph.\nSecond paragraph.")

    func testMonospaceToggledOffLeavesTheDerivedBaseFont() throws {
        let drift = try self.drift(Self.two, [.format(.monospace, selecting: (2, 8)), .format(.monospace, selecting: nil)])
        XCTAssertEqual(drift, [], "Monospace toggled off left the base font underived")
    }

    func testMonospaceToggledOffAcrossTwoParagraphsLeavesTheDerivedBaseFont() throws {
        let drift = try self.drift(Self.two, [.format(.monospace, selecting: (10, 20)), .format(.monospace, selecting: nil)])
        XCTAssertEqual(drift, [], "Monospace toggled off across two paragraphs left the base font underived")
    }

    func testACharacterTypedInsideInlineCodeHasTheInlineCodePresentation() throws {
        var mono = ChatInputInlineAttributes()
        mono.monospace = true
        let start = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "abcdef", attributes: mono)]))])
        let drift = try self.drift(start, [.select(3, 3), .insert("x")])
        XCTAssertEqual(drift, [], "a character typed inside inline code lacks the inline-code presentation")
    }

    /// Controls: Bold toggled on and off, and Monospace applied once, derive cleanly.
    func testControlBoldToggledOff() throws {
        XCTAssertEqual(try self.drift(Self.two, [.format(.bold, selecting: (2, 8)), .format(.bold, selecting: nil)]), [])
    }

    func testControlMonospaceOnce() throws {
        XCTAssertEqual(try self.drift(Self.two, [.format(.monospace, selecting: (2, 8))]), [])
    }
}
