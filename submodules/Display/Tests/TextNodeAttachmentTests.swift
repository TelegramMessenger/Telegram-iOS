import XCTest
import UIKit
import CoreText
@testable import Display

/// An image attachment (`.attachment` with a `UIImage` on a U+FFFC that a run delegate sizes, as the chat list's rich
/// preview icons are) is drawn centred in the frame the layout records for it. That frame has to be the attachment's
/// own glyph slot whatever the direction of the line: an icon at the logical end of a right-to-left line sits at the
/// line's left edge, not its right.
final class TextNodeAttachmentTests: XCTestCase {
    private final class RunDelegateData {
        let width: CGFloat

        init(width: CGFloat) {
            self.width = width
        }
    }

    private static let attachmentWidth: CGFloat = 20.0
    private let font = UIFont.systemFont(ofSize: 15.0)

    private func makeString(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [.font: self.font, .foregroundColor: UIColor.black])
        let image = UIGraphicsImageRenderer(size: CGSize(width: TextNodeAttachmentTests.attachmentWidth, height: 16.0)).image { _ in }
        let nsText = text as NSString
        for index in 0 ..< nsText.length where nsText.character(at: index) == 0xfffc {
            var callbacks = CTRunDelegateCallbacks(
                version: kCTRunDelegateCurrentVersion,
                dealloc: { dataRef in
                    Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                },
                getAscent: { _ in
                    return 12.0
                },
                getDescent: { _ in
                    return 4.0
                },
                getWidth: { dataRef in
                    return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().width
                }
            )
            let data = RunDelegateData(width: TextNodeAttachmentTests.attachmentWidth)
            let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(data).toOpaque())!
            let range = NSRange(location: index, length: 1)
            result.addAttribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), value: runDelegate, range: range)
            result.addAttribute(.attachment, value: image, range: range)
        }
        return result
    }

    private func layout(_ string: NSAttributedString, maximumNumberOfLines: Int, width: CGFloat = 1000.0) -> TextNodeLayout {
        return TextNode.calculateLayout(
            attributedString: string,
            minimumNumberOfLines: 0,
            maximumNumberOfLines: maximumNumberOfLines,
            truncationType: .end,
            backgroundColor: nil,
            constrainedSize: CGSize(width: width, height: .greatestFiniteMagnitude),
            alignment: .natural,
            verticalAlignment: .top,
            lineSpacingFactor: 0.12,
            cutout: nil,
            insets: UIEdgeInsets(),
            lineColor: nil,
            textShadowColor: nil,
            textShadowBlur: nil,
            textStroke: nil,
            displaySpoilers: false,
            displayEmbeddedItemsUnderSpoilers: false,
            customTruncationToken: nil
        )
    }

    /// Where CoreText places the attachment's glyph, from the same string set as one line (or its first `length`
    /// characters, a wrapped first line).
    private func glyphSlot(_ string: NSAttributedString, at index: Int, length: Int? = nil) -> (minX: CGFloat, maxX: CGFloat)? {
        let typesetter = CTTypesetterCreateWithAttributedString(string)
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: 0, length: length ?? string.length))
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let range = CTRunGetStringRange(run)
            guard index >= range.location && index < range.location + range.length else {
                continue
            }
            var position = CGPoint()
            CTRunGetPositions(run, CFRange(location: 0, length: 1), &position)
            return (position.x, position.x + CGFloat(CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)))
        }
        return nil
    }

    private func assertAttachmentCoversItsGlyph(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let string = self.makeString(text)
        let index = (text as NSString).range(of: "\u{fffc}").location
        guard let slot = self.glyphSlot(string, at: index) else {
            XCTFail("no glyph for the attachment", file: file, line: line)
            return
        }
        // 2: the chat list preview's first line; 1: the last-line path.
        for maximumNumberOfLines in [2, 1] {
            let frames = self.layout(string, maximumNumberOfLines: maximumNumberOfLines).lineAttachmentFrames
            XCTAssertEqual(frames.count, 1, "lines: \(maximumNumberOfLines)", file: file, line: line)
            guard let frame = frames.first?.frame else {
                continue
            }
            XCTAssertEqual(frame.minX, slot.minX, accuracy: 1.0, "lines: \(maximumNumberOfLines)", file: file, line: line)
            XCTAssertEqual(frame.maxX, slot.maxX, accuracy: 1.0, "lines: \(maximumNumberOfLines)", file: file, line: line)
        }
    }

    /// The reported preview: an Arabic paragraph followed by a table without a title.
    func test_rightToLeftLine_attachmentAtLogicalEnd_coversItsGlyphAtTheLeft() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة الصحفية القنوات (59) \u{fffc}")
    }

    func test_rightToLeftLine_attachmentAtLogicalEndWithoutSpace_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة الصحفية القنوات\u{fffc}")
    }

    func test_rightToLeftLine_attachmentAtLogicalStart_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("\u{fffc} مجلد غزة الصحفية القنوات (59)")
    }

    func test_rightToLeftLine_attachmentInTheMiddle_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة \u{fffc} الصحفية القنوات")
    }

    func test_rightToLeftLineWithLatin_attachmentAtLogicalEnd_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة Hello world \u{fffc}")
    }

    func test_leftToRightLine_attachmentAtStart_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("\u{fffc} Beli Produk Buka Bot")
    }

    func test_leftToRightLine_attachmentAtEnd_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("Beli Produk Buka Bot \u{fffc}")
    }

    func test_leftToRightLineWithArabic_attachmentAtEnd_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("Hello مجلد غزة \u{fffc}")
    }

    /// One character after the attachment still counts as the end of the line for the layout.
    func test_rightToLeftLine_attachmentFollowedByOneCharacter_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة الصحفية القنوات \u{fffc}.")
    }

    func test_leftToRightLine_attachmentFollowedByOneCharacter_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("Beli Produk Buka Bot \u{fffc}x")
    }

    /// Between Latin words the attachment runs left to right, inside a right-to-left line: its end is not the line's
    /// right edge.
    func test_rightToLeftLine_leftToRightAttachmentFollowedByOneCharacter_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة Hello \u{fffc}x")
    }

    /// An attachment touching text of the other direction, with no space between them (an inline formula): the line
    /// offsets at that boundary belong to the neighbouring run as much as to the attachment.
    func test_rightToLeftLine_attachmentRightAfterLatin_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة Hello\u{fffc}")
    }

    func test_rightToLeftLine_attachmentRightAfterDigits_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة 59\u{fffc}")
    }

    func test_rightToLeftLine_attachmentRightAfterLatinFollowedByOneCharacter_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة Hello\u{fffc}.")
    }

    func test_rightToLeftLine_attachmentBetweenLatinAndArabic_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة Hello\u{fffc} الصحفية")
    }

    func test_leftToRightLine_attachmentRightBeforeArabic_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("Hello\u{fffc}مجلد")
    }

    func test_leftToRightLine_attachmentRightBeforeArabicInTheMiddle_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("Hello \u{fffc}مجلد world")
    }

    func test_rightToLeftLine_attachmentRightBeforeLatin_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("مجلد غزة \u{fffc}Hello")
    }

    func test_leftToRightLine_attachmentRightAfterArabic_coversItsGlyph() {
        self.assertAttachmentCoversItsGlyph("Hello مجلد\u{fffc}")
    }

    /// A truncated last line that keeps the attachment and elides what follows it.
    func test_truncatedLine_attachmentBeforeTheTruncationToken_coversItsGlyph() {
        let prefix = "Beli Produk Buka Bot \u{fffc}"
        let text = prefix + "WWWWWW"
        let string = self.makeString(text)
        let index = (text as NSString).range(of: "\u{fffc}").location
        let width = ceil(CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(self.makeString(prefix + "\u{2026}")), nil, nil, nil))) + 2.0
        guard let slot = self.glyphSlot(string, at: index) else {
            XCTFail("no glyph for the attachment")
            return
        }
        let layout = self.layout(string, maximumNumberOfLines: 1, width: width)
        XCTAssertTrue(layout.truncated)
        let frames = layout.lineAttachmentFrames
        XCTAssertEqual(frames.count, 1)
        guard let frame = frames.first?.frame else {
            return
        }
        XCTAssertEqual(frame.minX, slot.minX, accuracy: 1.0)
        XCTAssertEqual(frame.maxX, slot.maxX, accuracy: 1.0)
    }

    /// The chat list preview's first line, wrapped right after a left-to-right attachment in a right-to-left paragraph.
    func test_wrappedRightToLeftLine_endingAtLeftToRightAttachment_coversItsGlyph() {
        let prefix = "مجلد غزة Hello \u{fffc}"
        let text = prefix + " World is here and more"
        let string = self.makeString(text)
        let index = (text as NSString).range(of: "\u{fffc}").location
        let width = ceil(CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(self.makeString(prefix)), nil, nil, nil))) + 2.0
        let firstLineLength = CTTypesetterSuggestLineBreak(CTTypesetterCreateWithAttributedString(string), 0, Double(width))
        XCTAssertEqual(firstLineLength, index + 2, "the first line should end right after the attachment and its space")
        guard let slot = self.glyphSlot(string, at: index, length: firstLineLength) else {
            XCTFail("no glyph for the attachment")
            return
        }
        let frames = self.layout(string, maximumNumberOfLines: 2, width: width).lineAttachmentFrames
        XCTAssertEqual(frames.count, 1)
        guard let frame = frames.first?.frame else {
            return
        }
        XCTAssertEqual(frame.minX, slot.minX, accuracy: 1.0)
        XCTAssertEqual(frame.maxX, slot.maxX, accuracy: 1.0)
    }
}
