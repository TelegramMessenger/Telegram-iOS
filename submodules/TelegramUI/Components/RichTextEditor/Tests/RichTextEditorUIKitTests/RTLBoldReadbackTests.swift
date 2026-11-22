#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Regression: under the iOS "Bold Text" accessibility setting, TextKit's font SUBSTITUTION for scripts the
/// base font can't render (Arabic/Hebrew/CJK) stamps `.traitBold` onto the substituted font as a DISPLAY
/// artifact. The model readback (`characterAttributes`/`runs(from:)`, reached by `currentParagraph()` on a
/// backspace merge) must NOT capture that ambient bold — otherwise merging an Arabic line bakes spurious
/// `bold=true` into the model ("the whole previous line becomes bold"). Same class as the fontFamily leak.
@available(iOS 16.0, *)
final class RTLBoldReadbackTests: XCTestCase {
    /// Render a model block through a real (font-fixing) layout, then read it back.
    private func roundTrip(_ block: ParagraphBlock, mapper: AttributedStringMapper = AttributedStringMapper()) -> [TextRun] {
        let layout = BlockLayout(attributedString: mapper.attributedString(for: block), width: 300)
        _ = layout.boundingHeight   // force layout → TextKit font substitution into storage
        return mapper.runs(from: layout.attributedString, style: block.style)
    }

    func test_arabic_nonBold_doesNotRoundTripAmbientBold() throws {
        try XCTSkipUnless(UIAccessibility.isBoldTextEnabled,
                          "Reproduces only with system Bold Text ON (the substitution stamps ambient bold).")
        let block = ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "مرحبا بالعالم")])  // model bold=false
        let runs = roundTrip(block)
        XCTAssertFalse(runs.contains { $0.attributes.bold },
                       "ambient system/substitution bold must not leak into the model on read-back")
    }

    /// User-applied bold on ARABIC must round-trip even under system Bold Text — the marker carries the
    /// intent that the substituted font's ambient `.traitBold` can't distinguish.
    func test_arabic_userBold_roundTrips_viaMarker() throws {
        try XCTSkipUnless(UIAccessibility.isBoldTextEnabled, "requires system Bold Text ON")
        var bold = CharacterAttributes(); bold.bold = true
        let block = ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "مرحبا", attributes: bold)])
        let runs = roundTrip(block)
        XCTAssertTrue(runs.allSatisfy { $0.attributes.bold },
                      "user bold on Arabic must round-trip via the .rtBold marker, even under Bold Text")
    }

    /// User-applied bold on LATIN text must still round-trip (the base Latin font carries no ambient bold).
    func test_latin_userBold_roundTrips() {
        var bold = CharacterAttributes(); bold.bold = true
        let block = ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "hello", attributes: bold)])
        let runs = roundTrip(block)
        XCTAssertTrue(runs.allSatisfy { $0.attributes.bold }, "user bold on Latin must round-trip")
    }

    /// The headline scenario end-to-end: backspace at the start of an Arabic paragraph merges it into the
    /// previous one; the merged model must not have become bold.
    func test_backspaceMerge_arabic_doesNotBoldPreviousLine() throws {
        try XCTSkipUnless(UIAccessibility.isBoldTextEnabled, "requires system Bold Text ON")
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "مرحبا")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "بالعالم")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[1].textStart),
                                                DocumentTextPosition(v.boxes[1].textStart))   // start of "بالعالم"
        v.deleteBackward()                                  // merge into "مرحبا"
        let merged = v.currentParagraphs()
        XCTAssertEqual(merged.count, 1)
        XCTAssertFalse(merged[0].runs.contains { $0.attributes.bold },
                       "merging an Arabic line under Bold Text must not bold the merged text")
    }

    func test_toggleBold_onArabic_appliesThenClearsModelBold() throws {
        try XCTSkipUnless(UIAccessibility.isBoldTextEnabled, "requires system Bold Text ON")
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "مرحبا")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 100); v.layoutIfNeeded()
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                                DocumentTextPosition(v.boxes[0].textStart + v.boxes[0].textLength))
        v.toggleBold()
        XCTAssertTrue(v.currentParagraphs()[0].runs.allSatisfy { $0.attributes.bold },
                      "first toggle applies model bold to the Arabic selection")
        v.toggleBold()
        XCTAssertFalse(v.currentParagraphs()[0].runs.contains { $0.attributes.bold },
                       "second toggle clears model bold")
    }

    func test_rangeIsBold_arabic_nonUserBold_isFalse() throws {
        try XCTSkipUnless(UIAccessibility.isBoldTextEnabled, "requires system Bold Text ON")
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "مرحبا")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 100); v.layoutIfNeeded()
        let storage = try XCTUnwrap(v.boxes[0].textLayout.backingStorage)
        XCTAssertFalse(v.rangeIsBold(storage, NSRange(location: 0, length: storage.length)),
                       "ambient-bold (non-user) Arabic must report not-bold, so the first toggle adds bold")
    }
}
#endif
