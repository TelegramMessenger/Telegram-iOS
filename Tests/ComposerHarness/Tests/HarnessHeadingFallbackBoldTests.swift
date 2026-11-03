import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Format ▸ Bold over a HEADING that contains Thai or Hebrew
/// bolds only the Latin part in the model. The fallback text stays unbolded in what is sent, and the
/// engine's own verifier reports NSFont drift for the block:
///
///     [h1 "Titleก่อน"] → select all (0..<9) → Format ▸ Bold
///       engine: model [h1 [b]"Title" + "ก่อน"]   drawn .NewYork-Semibold | .ThonburiUI-Bold
///     [h1 "Titleก่อน"] → select "ก่อน" only (5..<9) → Format ▸ Bold
///       engine: model unchanged, NSFont drift
///     Hebrew ("Titleעבר") the same. A later keystroke redraws the Latin part in .NewYork-Bold, so
///     the face also changes under the user.
///     controls: Latin-only heading → [h1 [b]"Title"], no drift; the same text in a BODY paragraph →
///     [p [b]"Titleก่อน"], no drift
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, wide sweep seed 35 (last op
/// `.format(.bold, selecting: (1, 53))` over a `# Title` heading with Thai typed into it); reduced by
/// probe to a single Format command.
///
/// **Suspected cause.** A heading's New York Medium has no Thai or Hebrew, and font fixing substitutes
/// a BOLD face (`.ThonburiUI-Bold`, `.SFHebrew-Semibold`) whether or not the user bolded it. So after
/// Bold the substituted face is exactly the face it had before, and
/// `EngineDocumentBridge.withCarriedTraitsOnFallbackFaces` leaves it alone (`intended == rendered`).
/// The mapper then reads a bold fallback face in a heading as the heading's AMBIENT bold (the rule
/// behind `HarnessSubstitutedFaceTraitTests`) and drops the user's `IDInlineTextBold` marker. The
/// read-back needs to trust the marker for a substituted face, and so does the derivation that the
/// verifier compares against.
///
/// **Tier 1**: `performFormatAction` is what the Format menu calls; the verifier is asked directly with
/// its trap switched off (`FuzzEngineVerifier`).
@available(iOS 18.4, *)
final class HarnessHeadingFallbackBoldTests: XCTestCase {
    private static func heading(_ text: String) -> ChatInputContent {
        return ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: text)]))])
    }

    private func bold(_ start: ChatInputContent, selecting: (Int, Int)) throws -> (runs: [ChatInputRun], drift: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.format(.bold, selecting: selecting)])
        var runs: [ChatInputRun] = []
        if case let .paragraph(paragraph)? = driver.model().blocks.first {
            runs = FuzzModel.merged(paragraph.runs)
        }
        return (runs, driver.engineVerifierViolations())
    }

    func testBoldOverAHeadingWithThaiBoldsTheThai() throws {
        let result = try self.bold(Self.heading("Title\u{E01}\u{E48}\u{E2D}\u{E19}"), selecting: (0, 9))
        XCTAssertEqual(result.runs.map(\.text).joined(), "Title\u{E01}\u{E48}\u{E2D}\u{E19}", "precondition: the text changed")
        XCTAssertTrue(result.runs.allSatisfy { $0.attributes.bold }, "Bold did not reach the Thai part of the heading: \(result.runs)")
        XCTAssertEqual(result.drift, [])
    }

    func testBoldOverOnlyTheThaiOfAHeadingBoldsIt() throws {
        let result = try self.bold(Self.heading("Title\u{E01}\u{E48}\u{E2D}\u{E19}"), selecting: (5, 9))
        XCTAssertTrue(result.runs.contains { $0.text == "\u{E01}\u{E48}\u{E2D}\u{E19}" && $0.attributes.bold }, "Bold did not reach the Thai (model unchanged): \(result.runs.map { fuzzEscaped($0.text) + ($0.attributes.bold ? "[b]" : "") })")
        XCTAssertEqual(result.drift, [])
    }

    func testBoldOverAHeadingWithHebrewBoldsTheHebrew() throws {
        let result = try self.bold(Self.heading("Title\u{5E2}\u{5D1}\u{5E8}"), selecting: (0, 8))
        XCTAssertTrue(result.runs.allSatisfy { $0.attributes.bold }, "Bold did not reach the Hebrew part of the heading: \(result.runs)")
        XCTAssertEqual(result.drift, [])
    }

    /// Control: a Latin-only heading.
    func testControlLatinHeading() throws {
        let result = try self.bold(Self.heading("Title"), selecting: (0, 5))
        XCTAssertTrue(result.runs.allSatisfy { $0.attributes.bold })
        XCTAssertEqual(result.drift, [])
    }

    /// Control: the same text in a body paragraph.
    func testControlBodyParagraph() throws {
        let result = try self.bold(ChatInputContent(blocks: [HarnessEngine.paragraph("Title\u{E01}\u{E48}\u{E2D}\u{E19}")]), selecting: (0, 9))
        XCTAssertTrue(result.runs.allSatisfy { $0.attributes.bold })
        XCTAssertEqual(result.drift, [])
    }
}
