#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Proves the TextKit-1 `EmojiTextAttachment.attachmentBounds(for:proposedLineFragment:glyphPosition:
/// characterIndex:)` override sizes the emoji box correctly under `BlockLayoutTK1` — the TK1 analog of
/// `EmojiMapperTests.test_attachmentBox_squareSizedAndCenteredOnGlyph` (which exercises the TK2 path).
final class BlockLayoutTK1EmojiTests: XCTestCase {
    private let mapper = AttributedStringMapper()
    private func ref() -> EmojiRef { EmojiRef(id: "star", instanceID: "i1", altText: ":star:") }

    func test_tk1_attachmentBox_squareSizedToGlyphPlusBoost() {
        for style in [ParagraphStyleName.body, .heading1, .heading2, .heading3] {
            let font = mapper.styleSheet.font(for: style, attributes: CharacterAttributes())
            let boost: CGFloat = style == .body ? 4 : 0
            let block = ParagraphBlock(id: BlockID("e"), style: style, runs: [
                TextRun(text: "Agjy"),
                TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
            ])
            let layout = BlockLayoutTK1(attributedString: mapper.attributedString(for: block), width: 320)
            guard let box = layout.attachmentBox(at: 4) else {
                XCTFail("emoji must have a positioned box (\(style))"); continue
            }
            let glyphSide = font.ascender - font.descender
            XCTAssertEqual(box.width, box.height, accuracy: 0.01, "square (\(style))")
            XCTAssertEqual(box.width, glyphSide + boost, accuracy: 0.5, "side = glyph + boost (\(style))")
        }
    }

    /// The hosted emoji box must sit on the SAME baseline TextKit 1 DRAWS the neighbouring text at — which is
    /// the corrected baseline (raw `location(forGlyphAt:)` − `baselineDelta`), since both engines place the
    /// first baseline at the font's ascender (the text glyphs and the emoji shift up together). Reference =
    /// `lineFragmentRect.minY + location(forGlyphAt: 0).y − baselineDelta` (glyph 0 = "A"). For a no-boost
    /// style the box spans baseline−ascender … baseline−descender (a glyph cell).
    func test_tk1_emoji_sitsOnTextBaseline() {
        for style in [ParagraphStyleName.heading1, .caption, .heading2] {   // boost == 0 styles
            let font = mapper.styleSheet.font(for: style, attributes: CharacterAttributes())
            let block = ParagraphBlock(id: BlockID("e"), style: style, runs: [
                TextRun(text: "Agjy"),
                TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
            ])
            let l = BlockLayoutTK1(attributedString: mapper.attributedString(for: block), width: 320)
            guard let box = l.attachmentBox(at: 4) else { XCTFail("no box (\(style))"); continue }
            let lm = l.layoutManager
            let lineRect = lm.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
            let textBaseline = lineRect.minY + lm.location(forGlyphAt: 0).y - l.baselineDelta
            XCTAssertEqual(box.minY, textBaseline - font.ascender, accuracy: 0.5, "box top = baseline−ascender (\(style))")
            XCTAssertEqual(box.maxY, textBaseline - font.descender, accuracy: 0.5, "box bottom = baseline−descender (\(style))")
        }
    }

    func test_tk1_bodyEmoji_doesNotExpandLine() {
        let emoji = ParagraphBlock(id: BlockID("e"), style: .body, runs: [
            TextRun(text: "Agjy"),
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
        ])
        let text = ParagraphBlock(id: BlockID("t"), style: .body, runs: [TextRun(text: "Agjy")])
        let hEmoji = BlockLayoutTK1(attributedString: mapper.attributedString(for: emoji), width: 320).boundingHeight
        let hText = BlockLayoutTK1(attributedString: mapper.attributedString(for: text), width: 320).boundingHeight
        XCTAssertEqual(hEmoji, hText, accuracy: 0.01, "the +4pt body boost must not expand the line")
    }
}
#endif
