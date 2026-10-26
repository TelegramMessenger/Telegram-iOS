import XCTest
import UIKit
import CoreText
import TelegramCore
import TextFormat
@testable import InstantPageUI

/// An inline attachment — custom emoji, image, formula, button pill — is a one-character cell in the
/// laid-out string whose width comes from a `CTRunDelegate`. While that character was a SPACE,
/// CoreText treated it as trailing whitespace at a break opportunity, and trailing whitespace is
/// allowed to hang past the container's right edge. For a real space that is correct and invisible;
/// for an attachment cell it meant the attachment rendered OUTSIDE the bubble instead of wrapping.
///
/// These tests pin the property, not the character: whatever placeholder is used, no attachment cell
/// may ever draw past `boundingWidth`.
///
/// **Sweeping is the method, not thoroughness for its own sake.** The hang only appears at the widths
/// where an attachment happens to land at a line end, and those widths differ per atom and per
/// sentence shape — hand-picked constants silently stop testing anything. Measured against the
/// pre-fix code, the sweep below catches the emoji at 14 widths, the image at 7 and the pill at 5;
/// several hand-picked widths caught none of them.
final class InstantPageInlineAttachmentWrappingTests: XCTestCase {
    private let font = UIFont.systemFont(ofSize: 17.0)

    // MARK: Building the renderer's own strings

    /// Goes through the production `attributedStringForRichText`, so the placeholder character and the
    /// run delegate are the real ones rather than a copy that can drift.
    private func paragraph(_ text: RichText, boundingWidth: CGFloat? = nil) -> NSAttributedString {
        let stack = InstantPageTextStyleStack()
        stack.push(.fontSerif(false))
        stack.push(.fontSize(self.font.pointSize))
        stack.push(.textColor(.black))
        stack.push(.linkColor(.blue))
        return attributedStringForRichText(text, styleStack: stack, boundingWidth: boundingWidth,
                                           inlineButtonMaxWidth: boundingWidth)
    }

    private func emoji(_ fileId: Int64 = 1) -> RichText {
        return .textCustomEmoji(fileId: fileId, alt: "🙂")
    }

    /// `EngineMedia.Id`, not the raw Postbox `MediaId` — TelegramCore does not re-export Postbox (see
    /// the engine typealias cheat sheet in the root CLAUDE.md); the two are the same type.
    private func inlineImage(_ id: Int64 = 1, side: Int32 = 40) -> RichText {
        return .image(id: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id),
                      dimensions: PixelDimensions(width: side, height: side))
    }

    private func button(_ title: String = "Buy") -> RichText {
        return .textButton(InstantPageButton(text: .plain(title), action: .url("https://telegram.org"), color: nil))
    }

    // NO formula case anywhere in this file, deliberately. `.formula` takes the same placeholder and
    // therefore the same fix, but it cannot be exercised from this test host: `instantPageMathAttachment`
    // goes through SwiftMath, whose bundled font is missing from the unit-test bundle, and it then traps
    // in `MTFont.swift` (force-unwrap of a nil font) rather than returning nil — building one crashes the
    // whole suite. That arm is covered by sharing the constant, and by inspection.

    // MARK: The measurement

    /// The four sentence shapes an attachment can sit in. Each puts the atom at a different distance
    /// from a break opportunity, and pre-fix they failed at DIFFERENT widths — `mid` never failed for
    /// the image or the pill, `nospace` never failed for the pill.
    private func shapes(_ atom: RichText) -> [(name: String, text: RichText)] {
        return [
            ("mid", .concat([.plain("one two three "), atom, .plain(" four")])),
            ("trailing", .concat([.plain("one two three "), atom])),
            ("no leading space", .concat([.plain("one two three"), atom])),
            ("two atoms", .concat([.plain("one two "), atom, .plain(" three four "), atom]))
        ]
    }

    /// The rightmost edge reached by ANY attachment cell, over every line.
    private func maxAttachmentX(_ text: RichText, width: CGFloat) -> CGFloat {
        let (item, _, _) = layoutTextItem(self.paragraph(text, boundingWidth: width),
                                          boundingWidth: width, offset: .zero)
        var maxX: CGFloat = 0.0
        for line in item?.lines ?? [] {
            for emojiItem in line.emojiItems { maxX = max(maxX, emojiItem.frame.maxX) }
            for imageItem in line.imageItems { maxX = max(maxX, imageItem.frame.maxX) }
            for formulaItem in line.formulaItems { maxX = max(maxX, formulaItem.frame.maxX) }
            for buttonItem in line.buttonItems { maxX = max(maxX, buttonItem.frame.maxX) }
        }
        return maxX
    }

    /// Sweeps every shape × every width and reports every overflow at once, so a failure shows the
    /// whole pattern rather than the first width that happens to break.
    private func assertNeverOverflows(_ atom: RichText, _ label: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        var overflows: [String] = []
        for shape in self.shapes(atom) {
            for width in stride(from: 60.0, through: 300.0, by: 5.0) {
                let maxX = self.maxAttachmentX(shape.text, width: width)
                if maxX > width + 0.5 {
                    overflows.append("\(shape.name)@\(Int(width)) → \(String(format: "%.1f", maxX))")
                }
            }
        }
        XCTAssertEqual(overflows, [], "\(label) overflows the container", file: file, line: line)
    }

    // MARK: One test per arm, so a failure names the arm

    func test_customEmoji_neverOverflowsTheContainer() {
        self.assertNeverOverflows(self.emoji(), "a custom emoji")
    }

    func test_inlineImage_neverOverflowsTheContainer() {
        self.assertNeverOverflows(self.inlineImage(), "an inline image")
    }

    func test_buttonPill_neverOverflowsTheContainer() {
        self.assertNeverOverflows(self.button(), "a button pill")
    }

    // MARK: Properties that must survive the placeholder change

    /// The wrap must be a genuine fit decision, not the placeholder having become unconditionally
    /// break-forcing: given room, the attachment stays on the line with its text.
    func test_attachmentThatFits_staysOnTheLine() throws {
        for (label, atom) in [("emoji", self.emoji()), ("image", self.inlineImage()), ("pill", self.button())] {
            let text = RichText.concat([.plain("one two"), atom])
            let (item, _, _) = layoutTextItem(self.paragraph(text, boundingWidth: 1000.0),
                                              boundingWidth: 1000.0, offset: .zero)
            XCTAssertEqual(try XCTUnwrap(item).lines.count, 1, "\(label) should not wrap at 1000pt")
        }
    }

    /// An attachment BETWEEN two words must not glue them into one unbreakable run — the failure mode
    /// of "fix it with a no-break space" (`U+00A0` is line-break class GL, which suppresses breaks on
    /// both sides). A narrow container has to wrap somewhere, and both atoms must still be placed.
    func test_interiorAttachments_doNotPreventWrapping() throws {
        let text = RichText.concat([
            .plain("alpha "), self.emoji(1), .plain(" bravo "), self.inlineImage(2), .plain(" charlie")
        ])
        let (item, _, size) = layoutTextItem(self.paragraph(text, boundingWidth: 90.0),
                                             boundingWidth: 90.0, offset: .zero)
        let lines = try XCTUnwrap(item).lines
        XCTAssertGreaterThan(lines.count, 1, "a narrow container must still wrap around the attachments")
        XCTAssertLessThanOrEqual(size.width, 90.0 + 0.5, "no line may exceed the container width")
        XCTAssertEqual(lines.flatMap { $0.emojiItems }.count, 1, "the emoji is still placed")
        XCTAssertEqual(lines.flatMap { $0.imageItems }.count, 1, "the image is still placed")
    }

    /// The placeholder must not be whitespace — that is the whole mechanism. Stated directly so the
    /// reason survives a future "simplify" pass that only reads the constant.
    func test_placeholderIsNotWhitespace() throws {
        XCTAssertEqual(instantPageInlineAttachmentPlaceholder.count, 1, "exactly one character of advance")
        let scalar = try XCTUnwrap(instantPageInlineAttachmentPlaceholder.unicodeScalars.first)
        XCTAssertFalse(CharacterSet.whitespacesAndNewlines.contains(scalar),
                       "a whitespace placeholder is allowed to hang past the line's right edge")
    }

    /// Every attachment run is skipped at draw time — leaving one drawn paints a `.notdef` box under
    /// the hosted view. Asserted through the shared predicate the draw loop calls.
    func test_everyAttachmentRunIsSkippedAtDrawTime() throws {
        let text = RichText.concat([
            .plain("text "), self.emoji(1), self.inlineImage(2), self.button("Go"), .plain(" more")
        ])
        let string = self.paragraph(text, boundingWidth: 1000.0)
        let line = CTLineCreateWithAttributedString(string as CFAttributedString)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(line) as? [CTRun])

        var skipped = 0
        var drawn = 0
        for run in runs {
            if instantPageRunIsInlineAttachment(run) { skipped += 1 } else { drawn += 1 }
        }
        XCTAssertEqual(skipped, 3, "emoji, image and pill runs are all skipped")
        XCTAssertGreaterThan(drawn, 0, "the real text runs are still drawn")
    }
}
