#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class EmojiMapperTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    private func ref() -> EmojiRef { EmojiRef(id: "star", instanceID: "i1", altText: ":star:") }

    func test_attributesForEmoji_carryAttachmentWithRef() {
        let attrs = mapper.attributes(for: CharacterAttributes(emoji: ref()), style: .body)
        let att = attrs[.attachment] as? EmojiTextAttachment
        XCTAssertNotNil(att, "an emoji run must carry an EmojiTextAttachment")
        XCTAssertEqual(att?.ref, ref())
        XCTAssertNotNil(attrs[.font], "the attachment is sized from the run's font, which must be present")
    }

    func test_emojiAttachmentBounds_isSquareSizedToFont() {
        let font = UIFont.systemFont(ofSize: 17)
        let att = EmojiTextAttachment(ref: ref(), scale: 1.0)
        let bounds = att.attachmentBounds(for: [.font: font], location: DummyLocation(),
                                          textContainer: nil, proposedLineFragment: .zero, position: .zero)
        XCTAssertEqual(bounds.width, bounds.height, accuracy: 0.01, "emoji box must be square")
        XCTAssertEqual(bounds.width, font.ascender - font.descender, accuracy: 0.5, "side = ascender + |descender|")
        XCTAssertEqual(bounds.origin.y, font.descender, accuracy: 0.5, "baseline-aligned (y = descender)")
    }

    func test_emojiScale_appliesToSide() {
        let font = UIFont.systemFont(ofSize: 17)
        let att = EmojiTextAttachment(ref: ref(), scale: 2.0)
        let bounds = att.attachmentBounds(for: [.font: font], location: DummyLocation(),
                                          textContainer: nil, proposedLineFragment: .zero, position: .zero)
        XCTAssertEqual(bounds.width, (font.ascender - font.descender) * 2.0, accuracy: 0.5)
    }

    func test_characterAttributesFromEmojiDict_recoversRefAndNothingElse() {
        let attrs = mapper.attributes(for: CharacterAttributes(emoji: ref()), style: .body)
        let back = mapper.characterAttributes(from: attrs)
        XCTAssertEqual(back.emoji, ref())
        XCTAssertNil(back.fontFamily, "the style font must not leak into the model")
        XCTAssertNil(back.foreground)
        XCTAssertFalse(back.bold)
    }

    func test_runsRoundTrip_keepsEmojiAsItsOwnRun() {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body, runs: [
            TextRun(text: "A"),
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
            TextRun(text: "B"),
        ])
        let attr = mapper.attributedString(for: block)
        XCTAssertEqual(attr.string, "A\u{FFFC}B")
        let runs = mapper.runs(from: attr)
        XCTAssertEqual(runs.count, 3)
        XCTAssertEqual(runs[1].text, "\u{FFFC}")
        XCTAssertEqual(runs[1].attributes.emoji, ref())
        XCTAssertNil(runs[0].attributes.emoji)
        XCTAssertNil(runs[2].attributes.emoji)
    }

    /// The host emoji box is a square sized to the glyph (`ascender + |descender|`) PLUS the per-style
    /// render boost (+4pt for body, so emoji read at a comfortable size), centered on the glyph box. It is
    /// derived from the attachment's own bounds, NOT the full line-fragment `selectionRects` rect (which is
    /// `lineHeight × lineHeightMultiple` tall and would stretch the emoji).
    func test_attachmentBox_squareSizedAndCenteredOnGlyph() {
        for style in [ParagraphStyleName.body, .heading1, .heading2, .heading3] {
            let font = mapper.styleSheet.font(for: style, attributes: CharacterAttributes())
            let boost: CGFloat = style == .body ? 4 : 0   // spec: body emoji are 4pt larger
            let block = ParagraphBlock(id: BlockID("e"), style: style, runs: [
                TextRun(text: "Agjy"),
                TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
            ])
            let layout = BlockLayout(attributedString: mapper.attributedString(for: block), width: 320)
            assertEmojiBox(layout, at: 4, font: font, boost: boost, label: "\(style)")
        }
    }

    /// Regression: an emoji on a WRAPPED (2nd+) line must land on its own line, not line 1. The segment's
    /// `baselinePosition` is relative to the line-fragment top, so the box's y must include the line origin.
    func test_attachmentBox_onWrappedLine_staysOnItsLine() {
        let font = mapper.styleSheet.font(for: .body, attributes: CharacterAttributes())
        let block = ParagraphBlock(id: BlockID("intro"), style: .body, runs: [
            TextRun(text: "Black holes are the strangest objects we know "),
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
            TextRun(text: ". Places where gravity pulls so hard that not even light escapes."),
        ])
        let layout = BlockLayout(attributedString: mapper.attributedString(for: block), width: 320)
        let off = (layout.attributedString.string as NSString).range(of: "\u{FFFC}").location
        // The emoji must be on a wrapped line for this test to be meaningful.
        let sel = layout.selectionRects(start: off, end: off + 1).first ?? .zero
        XCTAssertGreaterThan(sel.minY, 1.0, "test setup: emoji must be on a wrapped line, not line 1")
        assertEmojiBox(layout, at: off, font: font, boost: 4, label: "wrapped")
    }

    /// The +4pt body boost must NOT expand the line: it grows only the rendered view (overflowing into the
    /// leading), while the attachment's reserved layout box stays the glyph box. So a body line containing an
    /// emoji is exactly as tall as a text-only body line.
    func test_bodyEmoji_doesNotExpandLine() {
        let emoji = ParagraphBlock(id: BlockID("e"), style: .body, runs: [
            TextRun(text: "Agjy"),
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
        ])
        let text = ParagraphBlock(id: BlockID("t"), style: .body, runs: [TextRun(text: "Agjy")])
        let hEmoji = BlockLayout(attributedString: mapper.attributedString(for: emoji), width: 320).boundingHeight
        let hText = BlockLayout(attributedString: mapper.attributedString(for: text), width: 320).boundingHeight
        XCTAssertEqual(hEmoji, hText, accuracy: 0.01, "a body emoji (even +4pt) must not expand the line")
    }

    /// Shared invariants: the positioned emoji box is square, sized to the glyph box + boost, and centered on
    /// the glyph box (baseline box) within its OWN line.
    private func assertEmojiBox(_ layout: BlockLayout, at off: Int, font: UIFont, boost: CGFloat, label: String) {
        let glyphSide = font.ascender - font.descender
        guard let box = layout.attachmentBox(at: off) else {
            XCTFail("emoji at offset \(off) must have a positioned box (\(label))"); return
        }
        XCTAssertEqual(box.width, box.height, accuracy: 0.01, "the emoji box must be square (\(label))")
        XCTAssertEqual(box.width, glyphSide + boost, accuracy: 0.5, "box side = glyph + boost (\(label))")
        layout.layoutManager.enumerateTextSegments(in: layout.textRange(off, off + 1)!, type: .selection,
                                                    options: []) { _, frame, baselinePosition, _ in
            // The drawn text baseline is corrected (raw baseline − baselineDelta); the emoji tracks it.
            let baseline = frame.minY + baselinePosition - layout.baselineDelta
            // Centered on the glyph box: glyph box is baseline-aligned (top = baseline − ascender, side = glyphSide).
            XCTAssertEqual(box.midX, frame.minX + glyphSide / 2, accuracy: 0.5, "centered on glyph x (\(label))")
            XCTAssertEqual(box.midY, baseline - font.ascender + glyphSide / 2, accuracy: 0.5,
                           "centered on glyph box y (\(label))")
            return false
        }
    }

    func test_layoutReservesSquareBoxForEmoji() {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body,
                                   runs: [TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref()))])
        let layout = BlockLayout(attributedString: mapper.attributedString(for: block), width: 320)
        let rects = layout.selectionRects(start: 0, end: 1)
        XCTAssertFalse(rects.isEmpty, "the emoji must reserve a layout box")
        let font = mapper.styleSheet.font(for: .body, attributes: CharacterAttributes())
        XCTAssertEqual(rects[0].width, font.ascender - font.descender, accuracy: 4.0,
                       "the reserved box width ≈ the square side")
    }
}

/// A minimal NSTextLocation for exercising attachmentBounds in a unit test. (NSTextLocation is iOS 15+.)
@available(iOS 15.0, *)
private final class DummyLocation: NSObject, NSTextLocation {
    func compare(_ location: NSTextLocation) -> ComparisonResult { .orderedSame }
}
#endif
