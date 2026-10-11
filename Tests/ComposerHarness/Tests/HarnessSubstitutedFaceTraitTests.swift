import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Hebrew (or Thai) typed into a HEADING and then merged into a
/// body paragraph by a cross-block edit came out BOLD in the model and on screen, although nobody
/// bolded it:
///
///     [p "Body"] [h1 "Title"] → type "עברית" at the heading's end → select "dy\nTi" (2..<7) → type "b"
///       engine: [p "Bobtle" [b]"עברית"]   drawn .SFHebrew-Semibold
///     control: Latin typed the same way stays plain
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 12 (reported as NSFont
/// drift); reduced by replay.
///
/// **Cause.** A heading's New York Medium has no Hebrew, and font fixing substitutes a BOLD Hebrew
/// face. In the heading the mapper recognises that bold as ambient; merged into a body paragraph the
/// stored face still said bold and the read-back took it for the user's (no bold marker was set), so
/// the model gained it and normalisation drew it bold from then on. Fixed in the read-back
/// (`EngineDocumentBridge.withCarriedTraitsOnFallbackFaces`): a substituted face is read as the traits
/// the run is meant to carry — its base face's ambient ones and the user's markers.
///
/// **Tier 1**: typing is `insertText` on the engine view.
@available(iOS 18.4, *)
final class HarnessSubstitutedFaceTraitTests: XCTestCase {
    private func mergeHeadingInto(typing text: String) throws -> (runs: [ChatInputRun], drift: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("Body"),
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "Title")])),
        ])
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(10, 10), .insert(text), .select(2, 7), .insert("b")])
        var runs: [ChatInputRun] = []
        if case let .paragraph(paragraph)? = driver.model().blocks.first {
            runs = paragraph.runs
        }
        return (runs, driver.engineVerifierViolations())
    }

    func testHebrewFromAHeadingIsNotBoldInABodyParagraph() throws {
        let result = try self.mergeHeadingInto(typing: "\u{5E2}\u{5D1}\u{5E8}\u{5D9}\u{5EA}")
        XCTAssertEqual(result.runs.map(\.text).joined(), "Bobtle\u{5E2}\u{5D1}\u{5E8}\u{5D9}\u{5EA}", "precondition: the merge did not happen")
        XCTAssertFalse(result.runs.contains { $0.attributes.bold }, "the substituted face's bold reached the model")
        XCTAssertEqual(result.drift, [])
    }

    func testThaiFromAHeadingIsNotBoldInABodyParagraph() throws {
        let result = try self.mergeHeadingInto(typing: "\u{E01}\u{E48}\u{E2D}\u{E19}")
        XCTAssertFalse(result.runs.contains { $0.attributes.bold }, "the substituted face's bold reached the model")
        XCTAssertEqual(result.drift, [])
    }

    /// Control: Latin.
    func testControlLatin() throws {
        let result = try self.mergeHeadingInto(typing: "xyz")
        XCTAssertEqual(result.runs.map(\.text).joined(), "Bobtlexyz")
        XCTAssertFalse(result.runs.contains { $0.attributes.bold })
        XCTAssertEqual(result.drift, [])
    }
}
