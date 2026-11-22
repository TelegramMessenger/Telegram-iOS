#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class ButtonRenderingTests: XCTestCase {
    private func makeMapper() -> AttributedStringMapper {
        return AttributedStringMapper()
    }

    private func render(_ mapper: AttributedStringMapper, _ runs: [TextRun]) -> NSAttributedString {
        mapper.attributedString(for: ParagraphBlock(id: BlockID.generate(), style: .body, runs: runs))
    }

    private func button(_ label: String, color: ButtonColor? = .danger) -> ButtonRef {
        ButtonRef(label: [TextRun(text: label)], action: .url("https://telegram.org"), color: color)
    }

    private func buttonRun(_ label: String) -> TextRun {
        var attributes = CharacterAttributes.plain
        attributes.button = button(label)
        return TextRun(text: "\u{FFFC}", attributes: attributes)
    }

    /// The pill must occupy exactly one UTF-16 position, like a custom emoji or a formula.
    func test_inlineButton_isOneCharacterInTheRenderedString() {
        let string = render(makeMapper(), [TextRun(text: "a"), buttonRun("Go"), TextRun(text: "b")])
        XCTAssertEqual(string.length, 3)
    }

    func test_inlineButton_carriesItsAttachment() {
        let string = render(makeMapper(), [buttonRun("Go")])
        let attachment = string.attribute(.attachment, at: 0, effectiveRange: nil) as? ButtonTextAttachment
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.button.labelText, "Go")
    }

    /// The attachment must carry its OWN measurements: the layout raises the line's ascent and descent
    /// from it and has no style stack with which to re-measure.
    func test_attachment_carriesItsOwnMeasurements() {
        let mapper = makeMapper()
        let attachment = mapper.buttonAttachment(button: button("Go"), isBlockPill: false, maxWidth: nil)
        XCTAssertGreaterThan(attachment.size.width, 0)
        XCTAssertGreaterThan(attachment.size.height, 0)
        // The pill's ink box is the label box plus 2x the vertical padding.
        XCTAssertEqual(attachment.ascent + attachment.descent, attachment.size.height, accuracy: 0.01)
        XCTAssertEqual(attachment.horizontalPadding, RichTextButtonMetrics.default.inlineHorizontalPadding)
    }

    /// The round-trip invariant: theme and geometry are render-time only and never reach the model.
    func test_inlineButton_roundTripsThroughTheMapper() {
        let mapper = makeMapper()
        let original = [TextRun(text: "a"), buttonRun("Go")]
        let restored = mapper.runs(from: render(mapper, original), style: .body)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[1].text, "\u{FFFC}")
        XCTAssertEqual(restored[1].attributes.button, original[1].attributes.button)
    }

    /// A label wider than the cap is truncated, not overflowed: a pill alone on a line cannot be
    /// re-broken by the line-breaker, so the label has to shrink instead.
    func test_overlongLabel_isTruncated() {
        let mapper = makeMapper()
        let long = String(repeating: "wide ", count: 60)
        let unclamped = mapper.buttonAttachment(button: ButtonRef(label: [TextRun(text: long)], action: .disabled), isBlockPill: false, maxWidth: nil)
        let clamped = mapper.buttonAttachment(button: ButtonRef(label: [TextRun(text: long)], action: .disabled), isBlockPill: false, maxWidth: 120.0)
        XCTAssertGreaterThan(unclamped.size.width, 120.0)
        XCTAssertLessThanOrEqual(clamped.size.width, 120.0)
        XCTAssertTrue(clamped.labelString.string.hasSuffix("\u{2026}"))
    }

    /// A block pill uses the larger font and the wider padding.
    func test_blockPill_usesBlockGeometry() {
        let mapper = makeMapper()
        let inline = mapper.buttonAttachment(button: button("Go"), isBlockPill: false, maxWidth: nil)
        let block = mapper.buttonAttachment(button: button("Go"), isBlockPill: true, maxWidth: nil)
        XCTAssertEqual(block.horizontalPadding, RichTextButtonMetrics.default.blockHorizontalPadding)
        XCTAssertGreaterThan(block.size.width, inline.size.width)
    }

    /// The label carries the pill's own typography (semibold, fixed size), not the paragraph's.
    func test_label_usesPillTypographyNotTheParagraphs() {
        let mapper = makeMapper()
        let attachment = mapper.buttonAttachment(button: button("Go"), isBlockPill: false, maxWidth: nil)
        let font = attachment.labelString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, RichTextButtonMetrics.default.inlineFontSize)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    /// A disabled pill dims its label; danger/success tint theirs. Resolved in ONE place so the inline
    /// pill and the block row cannot disagree.
    func test_resolvedButtonColors_mirrorTheRenderer() {
        let theme = RichTextEditorTheme.default
        let neutral = theme.resolvedButtonColors(color: nil, isDisabled: false)
        XCTAssertEqual(neutral.label, theme.buttonNeutralLabel)
        let danger = theme.resolvedButtonColors(color: .danger, isDisabled: false)
        XCTAssertEqual(danger.label, theme.buttonDanger)
        let disabled = theme.resolvedButtonColors(color: .danger, isDisabled: true)
        var alpha: CGFloat = 0
        disabled.label.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.4, accuracy: 0.01)
    }
}
#endif
