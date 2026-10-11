import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Format ▸ Italic over INLINE CODE inside a PULL QUOTE slants
/// the code on screen. A pull quote's role derives UPRIGHT monospace for code, the model does not
/// change, and the engine's verifier reports NSFont drift:
///
///     [pull "ab " [m]"code" " span"] → select "code" (3..<7), or everything → Format ▸ Italic
///       engine: model unchanged; "code" drawn .AppleSystemUIFontMonospaced-RegularItalic
///       (before: -Regular)
///     controls: Format ▸ Bold on the same range gives [b,m] in upright semibold monospace, no drift;
///       no Format command leaves the code upright, no drift
///
/// The tenth wave fixed the neighbouring case, Format ▸ MONOSPACE inside a pull quote
/// (`HarnessPullQuoteInlineFormatDriftTests`). This is the other order: Italic over code that is
/// already there.
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, wide sweep seed 82 (last op
/// `.format(.italic, selecting: (50, 68))` over a pull quote holding pasted `` `code` span `` runs);
/// reduced by probe to a single Format command.
///
/// **Suspected cause.** The italic toggle in a pull quote recomputes base face + markers (the tenth-wave
/// `stampingAmbientItalicBaseFont` path in `EngineDocumentBridge`). For an inline-code run it composes
/// the face from the pull quote's italic base rather than from the user's markers, which is the rule
/// `font(_:carryingUserTraitsOf:)` (`+InlineCode.swift`) applies when Monospace is the command.
///
/// **Tier 1**: `performFormatAction` is what the Format menu calls; the verifier is asked directly with
/// its trap switched off (`FuzzEngineVerifier`).
@available(iOS 18.4, *)
final class HarnessPullQuoteItalicOverCodeTests: XCTestCase {
    private static var start: ChatInputContent {
        var mono = ChatInputInlineAttributes()
        mono.monospace = true
        return ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [
            ChatInputRun(text: "ab "), ChatInputRun(text: "code", attributes: mono), ChatInputRun(text: " span"),
        ]))])
    }

    private func run(_ ops: [FuzzOp]) throws -> (codeFont: UIFont?, drift: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: ops)
        let block = driver.editor.engine.attributedBlocks.first
        let font = (block?.length ?? 0) > 4 ? block?.attribute(.font, at: 4, effectiveRange: nil) as? UIFont : nil
        return (font, driver.engineVerifierViolations())
    }

    private static func isItalic(_ font: UIFont?) -> Bool {
        return font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
    }

    func testItalicOverCodeInAPullQuoteKeepsTheCodeUpright() throws {
        let result = try self.run([.format(.italic, selecting: (3, 7))])
        XCTAssertFalse(Self.isItalic(result.codeFont), "the code is drawn slanted: \(result.codeFont?.fontName ?? "nil")")
        XCTAssertEqual(result.drift, [])
    }

    func testItalicOverAWholePullQuoteWithCodeKeepsTheCodeUpright() throws {
        let result = try self.run([.format(.italic, selecting: (0, 12))])
        XCTAssertFalse(Self.isItalic(result.codeFont), "the code is drawn slanted: \(result.codeFont?.fontName ?? "nil")")
        XCTAssertEqual(result.drift, [])
    }

    /// Control: Bold over the same range.
    func testControlBold() throws {
        let result = try self.run([.format(.bold, selecting: (0, 12))])
        XCTAssertFalse(Self.isItalic(result.codeFont))
        XCTAssertEqual(result.drift, [])
    }

    /// Control: no Format command.
    func testControlUntouched() throws {
        let result = try self.run([.select(1, 1)])
        XCTAssertFalse(Self.isItalic(result.codeFont))
        XCTAssertEqual(result.drift, [])
    }

    /// Italic cannot apply inside a pull quote (its slant is the role's, the model cannot carry it and
    /// the V2 renderer draws an italic run there exactly like the rest), so the Format menu offers the
    /// command DISABLED rather than as a silent no-op. Control: the same query over text outside the
    /// pull quote (the whole document) answers true.
    func testTheFormatMenuOffersItalicDisabledInsideAPullQuote() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let start = ChatInputContent(blocks: [HarnessEngine.paragraph("Intro")] + Self.start.blocks)
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(9, 13)])
        XCTAssertFalse(driver.node.canPerformFormatAction(.italic), "Italic is offered over a pull quote's code, where it cannot apply")
        XCTAssertTrue(driver.node.canPerformFormatAction(.bold), "control: Bold applies inside a pull quote")
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(0, 13)])
        XCTAssertTrue(driver.node.canPerformFormatAction(.italic), "control: a selection reaching a paragraph can take italic")
    }

    /// The same drift reached by CONVERSION rather than by the toggle (twelfth wave, fuzz seed 5,
    /// reduced): Format ▸ Pull Quote over a paragraph whose inline code already carries the user's
    /// italic. The model's pull-quote runs kept `italic`, the bridge rendered the code monospaced
    /// italic from it while the read-back strips italic in a pull quote, so the block drifted on
    /// NSFont from then on. A pull quote's runs now render without italic (`pullQuoteRuns`).
    func testMakingAPullQuoteOverItalicCodeKeepsTheCodeUpright() throws {
        var italicCode = ChatInputInlineAttributes()
        italicCode.monospace = true
        italicCode.italic = true
        let start = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [
            ChatInputRun(text: "ab "), ChatInputRun(text: "code", attributes: italicCode), ChatInputRun(text: " span"),
        ]))])
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.format(.pullQuote, selecting: (0, 12))])
        guard case .pullQuote? = driver.model().blocks.first else {
            return XCTFail("precondition: no pull quote was made: \(FuzzModel.describe(driver.model()))")
        }
        let block = driver.editor.engine.attributedBlocks.first
        let font = (block?.length ?? 0) > 4 ? block?.attribute(.font, at: 4, effectiveRange: nil) as? UIFont : nil
        XCTAssertFalse(Self.isItalic(font), "the code is drawn slanted: \(font?.fontName ?? "nil")")
        XCTAssertEqual(driver.engineVerifierViolations(), [])
    }
}
