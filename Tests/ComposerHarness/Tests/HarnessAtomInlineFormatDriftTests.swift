import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Bold, Italic, Strikethrough or Underline over a selection
/// that holds an ATTACHMENT ATOM — an inline formula, an inline button, a custom emoji, a media atom
/// or a button row — leaves the atom's presentation off its role's derivation: the engine's own
/// verifier reports drift on `NSFont` (and `IDInlineTextBaseFont` for a media / row atom),
/// `NSStrikethrough` or `NSUnderline`. In a DEBUG build that verifier TRAPS at the end of the settle,
/// so the app dies; in release the atom keeps an attribute the next re-derivation will not give it.
/// The model is unaffected (the atom takes no bold), so this is a presentation defect only.
///
///     [p "ab " [formula a^2] " cd"], select the formula, Bold → drift NSFont at engine block 0
///     the same with an inline button, a custom emoji; Italic → NSFont; Strikethrough → NSStrikethrough
///     [p "Before"] [media "Cap"] [p "After"], Select All ▸ Bold → drift at the media atom's block
///     [p "Row:"] [row] [p "After"], Select All ▸ Bold → drift at the row atom's block
///     Spoiler over a MEDIA atom (plain or quoted) → drift RTSpoiler (edited-content fuzz, seed 17)
///     controls: Bold over a mention, Spoiler / Monospace over the formula — no drift
///
/// Select All ▸ Bold on an edited message that holds a photo is an ordinary gesture, which makes the
/// DEBUG trap easy to hit.
///
/// **How it was seen.** p13 probe, 2026-09-24 (the fuzz's per-step verifier question), then the
/// edited-content fuzz sweep.
///
/// **Suspected cause.** The trait pass behind `performFormatAction` (`+Formatting.swift`) writes the
/// toggled face / decoration over the whole range, atoms included, while the role's derivation
/// (`verifyPresentationIsDerived`, `+Settle.swift`) pins an atom's `.font` (and base font) to the
/// attachment's own typography — the same pinning the R9 notes describe for inserted atoms ("An atom's
/// `.font` and `.paragraphStyle` must be pinned alongside its `.attachment`").
///
/// **Tier 1**: `performFormatAction` is the Format menu's entry point; the drift is the engine's own
/// answer (`presentationDrift(atBlock:)`), asked with the trap switched off.
@available(iOS 18.4, *)
final class HarnessAtomInlineFormatDriftTests: XCTestCase {
    typealias E = HarnessEdited

    private func drift(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        E.installFormulaRenderer(on: driver.host)
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [])
        XCTAssertEqual(driver.engineVerifierViolations(), [], "precondition: drift before the format")
        for op in ops {
            HarnessComposerFuzzTests.execute(op, on: driver)
            driver.settle(0.1)
        }
        driver.settle(0.2)
        return driver.engineVerifierViolations()
    }

    private func around(_ atom: ChatInputRun) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("ab "), atom, E.run(" cd")])])
    }

    func testBoldOverAnInlineFormulaLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(self.around(E.formula("a^2")), [.select(3, 4), .format(.bold, selecting: nil)]), [])
    }

    func testItalicOverAnInlineButtonLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(self.around(E.pill("Go")), [.select(3, 4), .format(.italic, selecting: nil)]), [])
    }

    func testStrikethroughOverACustomEmojiLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(self.around(E.emoji()), [.select(3, 4), .format(.strikethrough, selecting: nil)]), [])
    }

    func testSelectAllBoldWithAMediaBlockLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(caption: "Cap"), E.paragraph([E.run("After")])]), [.selectAllFormat(.bold)]), [])
    }

    func testSelectAllBoldWithAButtonRowLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("Row:")]), E.buttonRow(["One", "Two"]), E.paragraph([E.run("After")])]), [.selectAllFormat(.bold)]), [])
    }

    /// Spoiler over a MEDIA atom (the edited-content fuzz, seed 17: `RTSpoiler` drift on the atom).
    func testSpoilerOverAMediaAtomLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(caption: "Cap"), E.paragraph([E.run("After")])]), [.select(3, 15), .format(.spoiler, selecting: nil)]), [])
    }

    func testSpoilerOverAQuotedMediaAtomLeavesNoDrift() throws {
        let quoted = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("Al said")]), E.media(caption: "In a quote")]), collapsed: false)), E.paragraph([E.run("out")])])
        XCTAssertEqual(try self.drift(quoted, [.select(5, 12), .format(.spoiler, selecting: nil)]), [])
    }

    /// The drift is not only cosmetic: the atom's drifted face becomes the typing face, so a
    /// composition over the Bolded (but still not bold in the model) formula commits BOLD text, where
    /// typing the same over it does not (edited-content fuzz, seed 63).
    func testACompositionOverABoldedFormulaMatchesTyping() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        E.installFormulaRenderer(on: driver.host)
        HarnessComposerFuzzTests.perform(driver, start: self.around(E.formula("a^2")), ops: [.select(3, 4), .format(.bold, selecting: nil), .select(3, 4)])
        XCTAssertNil(HarnessComposerFuzzTests.composeViolation(.korean, .unmark, selecting: nil, on: driver))
    }

    /// Control: the same composition over the formula with no Bold first.
    func testControlACompositionOverAFormulaMatchesTyping() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        E.installFormulaRenderer(on: driver.host)
        HarnessComposerFuzzTests.perform(driver, start: self.around(E.formula("a^2")), ops: [.select(3, 4)])
        XCTAssertNil(HarnessComposerFuzzTests.composeViolation(.korean, .unmark, selecting: nil, on: driver))
    }

    /// Control: a mention is text; Bold over it derives cleanly.
    func testControlBoldOverAMentionLeavesNoDrift() throws {
        XCTAssertEqual(try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("ab "), E.mention("Al"), E.run(" cd")])]), [.select(3, 5), .format(.bold, selecting: nil)]), [])
    }

    /// Control: Spoiler and Monospace over the same formula derive cleanly.
    func testControlSpoilerAndMonospaceOverAnInlineFormulaLeaveNoDrift() throws {
        XCTAssertEqual(try self.drift(self.around(E.formula("a^2")), [.select(3, 4), .format(.spoiler, selecting: nil), .select(3, 4), .format(.monospace, selecting: nil)]), [])
    }
}
