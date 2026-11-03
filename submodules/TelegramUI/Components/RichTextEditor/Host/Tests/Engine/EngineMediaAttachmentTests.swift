import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The attachment that reserves a media block's slot on the engine's axis.
@available(iOS 18.4, *)
final class EngineMediaAttachmentTests: XCTestCase {
    private func shape(_ items: [MediaItem], displayWidth: Double? = nil, mode: MediaDisplayMode = .mosaic) -> MediaShape {
        MediaShape(MediaBlock(id: BlockID("a"), items: items, displayWidth: displayWidth, displayMode: mode))
    }
    private func item(_ id: String, kind: MediaKind = .image, w: Double = 1000, h: Double = 500) -> MediaItem {
        MediaItem(mediaID: id, kind: kind, naturalSize: Size2D(width: w, height: h))
    }
    /// TextKit 1's variant needs no `NSTextLocation`, so it is the one a unit test can call.
    private func bounds(_ attachment: MediaTextAttachment, lineWidth: CGFloat) -> CGRect {
        attachment.attachmentBounds(for: nil, proposedLineFragment: CGRect(x: 0, y: 0, width: lineWidth, height: 20),
                                    glyphPosition: .zero, characterIndex: 0)
    }

    func test_boundsFollowTheProposedLineWidth() {
        let attachment = MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 0)
        // The SIZE is the slot; the origin carries the atom's declared descent and is asserted on
        // its own in `test_theAtomDeclaresItsOwnDescentSoItsLineBoxIsItsSlot`.
        XCTAssertEqual(bounds(attachment, lineWidth: 300).size, CGSize(width: 300, height: 150))
        XCTAssertEqual(bounds(attachment, lineWidth: 200).size, CGSize(width: 200, height: 100))
    }

    func test_theHeightIsComputedAtTheBledWidthAndTheWidthIsClampedToTheLine() {
        let attachment = MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 16)
        // legacy's canvas width is the line plus both bleeds: 300 + 32 = 332 → height 166
        XCTAssertEqual(bounds(attachment, lineWidth: 300).size, CGSize(width: 300, height: 166))
        XCTAssertTrue(attachment.fillsLine(ofWidth: 300))
    }

    func test_aNarrowDisplayWidthDoesNotFillTheLine() {
        let attachment = MediaTextAttachment(shape: shape([item("x")], displayWidth: 120), horizontalBleed: 16)
        XCTAssertEqual(bounds(attachment, lineWidth: 300).width, 120)
        XCTAssertFalse(attachment.fillsLine(ofWidth: 300))
    }

    func test_captionlessRowsAreFixedHeight() {
        XCTAssertEqual(bounds(MediaTextAttachment(shape: shape([item("a", kind: .audio)]), horizontalBleed: 0), lineWidth: 300).height, 44)
        XCTAssertEqual(bounds(MediaTextAttachment(shape: shape([item("d", kind: .document)]), horizontalBleed: 0), lineWidth: 300).height, 52)
    }

    /// **The atom declares its own descent, so its LINE BOX is exactly its slot.**
    ///
    /// TextKit sizes a line as `max(ascent) + max(descent)` over its runs, so an atom whose bounds
    /// sit at origin `.zero` is all ascent and its line comes out as the slot PLUS the atom font's
    /// descent. Measured: a 171.0 slot on the 1pt `mediaAtomFont` gave a 171.2412 line, which put
    /// every block below the medium on a fractional origin and their selection rects across a pixel.
    ///
    /// The SLOT is unchanged by this — the three size assertions above are the numbers they always
    /// were — and the atom does not move on screen, because its top is
    /// `lineTop + (lineAscent - atomAscent)` and both shrink by the descent together.
    func test_theAtomDeclaresItsOwnDescentSoItsLineBoxIsItsSlot() {
        let attachment = MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 0)
        let box = bounds(attachment, lineWidth: 300)
        let descent = -EngineDocumentBridge.mediaAtomFont.descender
        XCTAssertEqual(box.origin.y, -descent, accuracy: 0.0001)
        XCTAssertEqual(box.maxY - box.minY, box.height, accuracy: 0.0001)
        // The line TextKit will build: the atom's ascent plus whichever descent is larger.
        let lineHeight = max(box.maxY, EngineDocumentBridge.mediaAtomFont.ascender)
            + max(-box.minY, descent)
        XCTAssertEqual(lineHeight, box.height, accuracy: 0.0001, "the line is the slot, with nothing added")
    }

    func test_equalityIsByShape() {
        let a = MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 0)
        let b = MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 0)
        let c = MediaTextAttachment(shape: shape([item("y")]), horizontalBleed: 0)
        XCTAssertTrue(a.isEqual(b)); XCTAssertEqual(a.hash, b.hash)
        XCTAssertFalse(a.isEqual(c))
        XCTAssertTrue(NSAttributedString(attachment: a).isEqual(to: NSAttributedString(attachment: b)),
                      "the document setter's diff compares attributed strings; identity here would make every set a change")
    }

    /// Probe P1 (nesting design §4.4), measured: TextKit 2 proposes the WHOLE container width to
    /// `attachmentBounds` even under a head indent, so the atom subtracts its own. Neuter the
    /// subtraction and the first number goes back to 300×150 — the top-level slot, overhanging the
    /// quoted column by the indent.
    func test_theQuoteIndentNarrowsTheSlotAndTellsTwoAtomsApart() {
        let nested = MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 0, horizontalIndent: 16)
        XCTAssertEqual(bounds(nested, lineWidth: 300).size, CGSize(width: 284, height: 142))
        XCTAssertTrue(nested.fillsLine(ofWidth: 300), "it fills the line it is actually on, indent and all")
        XCTAssertFalse(nested.isEqual(MediaTextAttachment(shape: shape([item("x")]), horizontalBleed: 0)),
                       "the indent is part of equality: the document setter's diff must see a re-indented atom as changed")
    }

    /// The bleed is the HOSTED VIEW's overhang, and inside a quote there is none (nesting design
    /// §5.4) — so the box the medium is handed there must be its own aspect. Legacy decides this at
    /// CONSTRUCTION: `BlockQuoteBox` builds every nested child box with `horizontalBleed: 0`.
    ///
    /// The bleed is invisible in the width (`MediaSlotGeometry` derives the height from
    /// `line + bleed × 2` and `slot` then clamps the width back to `line`), so a bleed left on at
    /// depth ≥ 1 shows up only as reserved HEIGHT the medium never fills — and grows the quote's
    /// band with it. Neuter the depth test at the construction site and the first height reads 163
    /// instead of 147, for a photo drawn 294pt wide.
    func test_aQuotedAtomIsBuiltWithNoBleedSoItsHeightIsItsOwnAspect() {
        let bridge = EngineDocumentBridge(mapper: AttributedStringMapper(),
                                          mediaBlockStyle: MediaBlockStyle(horizontalBleed: 16))
        let nested = bridge.mediaAtom(for: shape([item("x")]),
                                      within: [.blockQuote(QuoteShape(id: BlockID("q")))])
        guard let inQuote = nested.attribute(.attachment, at: 0, effectiveRange: nil) as? MediaTextAttachment else {
            return XCTFail("no attachment on the quoted atom")
        }
        XCTAssertEqual(inQuote.horizontalIndent, bridge.styleSheet.quoteIndent)
        XCTAssertEqual(inQuote.horizontalBleed, 0, "no bleed inside a quote, decided where the atom is built")
        XCTAssertEqual(inQuote.slot(forLineWidth: 310), CGSize(width: 294, height: 147),
                       "294 wide and 147 tall: the aspect of the width it is actually drawn at")

        let top = bridge.mediaAtom(for: shape([item("x")]), within: [])
        guard let atTopLevel = top.attribute(.attachment, at: 0, effectiveRange: nil) as? MediaTextAttachment else {
            return XCTFail("no attachment on the top-level atom")
        }
        XCTAssertEqual(atTopLevel.horizontalBleed, 16, "\u{2026}while at top level the bleed still sets the height")
        XCTAssertEqual(atTopLevel.slot(forLineWidth: 310), CGSize(width: 310, height: 171),
                       "310 drawn, 342 of canvas: the hosted view bleeds out to it")
    }
}
