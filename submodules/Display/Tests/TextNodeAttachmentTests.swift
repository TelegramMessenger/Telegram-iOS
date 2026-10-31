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

    private func layout(_ string: NSAttributedString, maximumNumberOfLines: Int) -> TextNodeLayout {
        return TextNode.calculateLayout(
            attributedString: string,
            minimumNumberOfLines: 0,
            maximumNumberOfLines: maximumNumberOfLines,
            truncationType: .end,
            backgroundColor: nil,
            constrainedSize: CGSize(width: 1000.0, height: .greatestFiniteMagnitude),
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

    /// Where CoreText places the attachment's glyph, from the same string set as one line.
    private func glyphSlot(_ string: NSAttributedString, at index: Int) -> (minX: CGFloat, maxX: CGFloat)? {
        let line = CTLineCreateWithAttributedString(string)
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
            XCTAssertEqual(frame.midX, (slot.minX + slot.maxX) * 0.5, accuracy: 1.0, "lines: \(maximumNumberOfLines)", file: file, line: line)
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
}
