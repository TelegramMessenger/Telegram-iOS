import XCTest
import UIKit
import CoreText
import TelegramCore
import TextFormat
import RichTextButtonIcons
@testable import InstantPageUI

/// An inline `RichText.textButton` carries the same type icon a block-row pill does, but placed
/// differently: an inline pill is only ~20pt tall, far too short for a corner badge, so the icon
/// trails the label on the same optical line and the pill grows to hold it.
///
/// These tests pin the geometry that follows from that — the growth is unconditional, so it moves the
/// line break of the paragraph the pill sits in, and everything derived from the label's origin
/// (custom-emoji squares above all) has to stay put.
final class InstantPageInlineButtonIconTests: XCTestCase {
    private let label = makePlainLabelPiece("Open")

    /// `.url` resolves to the link icon; `.disabled` is iconless by intent, and is the comparison
    /// throughout. (`.callback` would do as well but its payload is a Postbox `MemoryBuffer`, which
    /// this test target cannot construct.)
    private func button(_ action: ReplyMarkupButtonAction) -> InstantPageButton {
        return InstantPageButton(text: .plain("Open"), action: action, color: nil)
    }

    private func inlineAttachment(_ action: ReplyMarkupButtonAction, maxWidth: CGFloat? = nil) -> InstantPageInlineButtonAttachment {
        return instantPageInlineButtonAttachment(button: self.button(action), labelString: self.label, maxWidth: maxWidth)
    }

    // MARK: - Width

    func testAnIconBearingInlinePillIsWiderByExactlyTheIconReserve() {
        let withIcon = self.inlineAttachment(.url("https://telegram.org"))
        let withoutIcon = self.inlineAttachment(.disabled)

        XCTAssertEqual(withIcon.size.width - withoutIcon.size.width, richTextInlineButtonIconReserve, accuracy: 0.01)
    }

    /// The icon rides on the same line as the label, so it must not make the pill taller — a taller
    /// pill would push the whole text line apart.
    func testTheIconDoesNotChangeThePillsHeight() {
        let withIcon = self.inlineAttachment(.url("https://telegram.org"))
        let withoutIcon = self.inlineAttachment(.disabled)

        XCTAssertEqual(withIcon.size.height, withoutIcon.size.height, accuracy: 0.01)
        XCTAssertEqual(withIcon.ascent, withoutIcon.ascent, accuracy: 0.01)
        XCTAssertEqual(withIcon.descent, withoutIcon.descent, accuracy: 0.01)
    }

    func testAnIconlessInlinePillReservesNothing() {
        XCTAssertEqual(self.inlineAttachment(.disabled).iconReserve, 0.0)
    }

    func testAnIconBearingInlinePillReservesTheIconAndItsGap() {
        XCTAssertEqual(self.inlineAttachment(.url("https://telegram.org")).iconReserve, richTextInlineButtonIconReserve)
    }

    /// A block-row pill keeps its corner badge, whose room comes from the row layout's side inset —
    /// NOT from the pill's own width. Adding the inline reserve there would widen every row button.
    func testABlockRowPillReservesNoInlineIconWidth() {
        let attachment = instantPageInlineButtonAttachment(
            button: self.button(.url("https://telegram.org")),
            labelString: makePlainLabelPiece("Open"),
            horizontalPadding: instantPageBlockButtonHorizontalPadding,
            iconPlacement: .blockBadge)
        XCTAssertEqual(attachment.iconReserve, 0.0)
    }

    // MARK: - Placement

    /// The reserve is trailing room, so the label starts exactly where it would have without an icon.
    /// This is the failure the attachment's `horizontalPadding` note warns about: recover the label's
    /// ink width from `size.width` without subtracting the reserve and the label slides right by half
    /// of it, dragging the emoji squares with it.
    func testTheLabelStillStartsAtTheHorizontalPadding() {
        let attachment = self.inlineAttachment(.url("https://telegram.org"))
        let origin = instantPageButtonLabelOrigin(attachment: attachment, pillSize: attachment.size)

        XCTAssertEqual(origin.x, instantPageInlineButtonHorizontalPadding, accuracy: 0.01)
    }

    /// The icon's trailing edge lands on the pill's ordinary padding — exactly where the label's would
    /// have. That is what makes the pill read as "label, then icon" rather than "label with a gap".
    func testTheIconSitsInsideTheTrailingPadding() {
        let attachment = self.inlineAttachment(.url("https://telegram.org"))
        let frame = instantPageInlineButtonIconFrame(attachment: attachment, pillSize: attachment.size)

        XCTAssertEqual(frame.maxX, attachment.size.width - instantPageInlineButtonHorizontalPadding, accuracy: 0.01)
        XCTAssertEqual(frame.size.width, richTextButtonIconSize.width, accuracy: 0.01)
        XCTAssertEqual(frame.size.height, richTextButtonIconSize.height, accuracy: 0.01)
    }

    func testTheIconIsSeparatedFromTheLabelByTheIconSpacing() {
        let attachment = self.inlineAttachment(.url("https://telegram.org"))
        let origin = instantPageButtonLabelOrigin(attachment: attachment, pillSize: attachment.size)
        let labelInkWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attachment.labelString), nil, nil, nil))
        let frame = instantPageInlineButtonIconFrame(attachment: attachment, pillSize: attachment.size)

        XCTAssertEqual(frame.minX - (origin.x + labelInkWidth), richTextInlineButtonIconSpacing, accuracy: 0.01)
    }

    /// Centred on the label's CAP box, not on the pill box. The two differ by ~0.6pt at 15pt, and the
    /// cap box is the one that reads as aligned: a pill's box is asymmetric around the text because it
    /// includes the descender.
    func testTheIconIsCentredOnTheLabelsCapBox() {
        let attachment = self.inlineAttachment(.url("https://telegram.org"))
        let origin = instantPageButtonLabelOrigin(attachment: attachment, pillSize: attachment.size)
        let frame = instantPageInlineButtonIconFrame(attachment: attachment, pillSize: attachment.size)

        // `origin.y` is the label's baseline; the cap box spans `capHeight` above it.
        let capBoxCentre = origin.y - testButtonLabelFont.capHeight / 2.0
        XCTAssertEqual(frame.midY, capBoxCentre, accuracy: 0.01)
    }

    /// A row pill's frame is stretched to the column width, so its label centres within it. The icon
    /// has to travel with the label rather than pinning to the pill edge, or the two separate.
    func testTheIconFollowsTheLabelWhenThePillIsWiderThanItsNaturalSize() {
        let attachment = self.inlineAttachment(.url("https://telegram.org"))
        let stretched = CGSize(width: attachment.size.width + 60.0, height: attachment.size.height)
        let origin = instantPageButtonLabelOrigin(attachment: attachment, pillSize: stretched)
        let frame = instantPageInlineButtonIconFrame(attachment: attachment, pillSize: stretched)
        let labelInkWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attachment.labelString), nil, nil, nil))

        XCTAssertEqual(frame.minX - (origin.x + labelInkWidth), richTextInlineButtonIconSpacing, accuracy: 0.01)
        // The label+icon group centres as a unit, so there is equal slack on both sides.
        XCTAssertEqual(origin.x, stretched.width - frame.maxX, accuracy: 0.01)
    }

    // MARK: - Truncation

    /// The reserve is real width, so it comes out of the room a capped pill has for its label. Failing
    /// to charge it there would overflow the line by exactly the icon.
    func testTheIconReserveComesOutOfTheTruncationBudget() {
        let longLabel = makePlainLabelPiece("A rather long button label")
        let cap: CGFloat = 120.0
        let withIcon = instantPageInlineButtonAttachment(
            button: self.button(.url("https://telegram.org")), labelString: longLabel, maxWidth: cap)
        let withoutIcon = instantPageInlineButtonAttachment(
            button: self.button(.disabled), labelString: longLabel, maxWidth: cap)

        XCTAssertTrue(withIcon.isTruncated, "the label is far too long for a 120pt pill")
        XCTAssertTrue(withoutIcon.isTruncated)
        XCTAssertLessThanOrEqual(withIcon.size.width, cap, "an icon-bearing pill must still fit its cap")
        XCTAssertLessThan(withIcon.labelString.length, withoutIcon.labelString.length,
                          "the icon takes its room from the label, so less of the label survives")
    }

    // MARK: - Custom emoji

    /// Emoji squares are derived from the label's origin, so the reserve must leave them untouched.
    func testCustomEmojiPlacementsAreUnaffectedByTheIconReserve() {
        let emojiLabel = makeTestLabel([
            makePlainLabelPiece("Buy "),
            makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)
        ])
        let withIcon = instantPageInlineButtonAttachment(
            button: self.button(.url("https://telegram.org")), labelString: emojiLabel)
        let withoutIcon = instantPageInlineButtonAttachment(
            button: self.button(.disabled), labelString: emojiLabel)

        let withIconPlacements = instantPageButtonEmojiPlacements(attachment: withIcon, pillSize: withIcon.size)
        let withoutIconPlacements = instantPageButtonEmojiPlacements(attachment: withoutIcon, pillSize: withoutIcon.size)

        XCTAssertEqual(withIconPlacements.count, 1)
        XCTAssertEqual(withoutIconPlacements.count, 1)
        guard let a = withIconPlacements.first, let b = withoutIconPlacements.first else {
            return
        }
        XCTAssertEqual(a.frame.minX, b.frame.minX, accuracy: 0.01)
        XCTAssertEqual(a.frame.minY, b.frame.minY, accuracy: 0.01)
        XCTAssertEqual(a.frame.width, b.frame.width, accuracy: 0.01)
    }

    // MARK: - Through the real construction path

    /// The arm that actually builds inline pills has to ask for the reserve — testing the measurement
    /// helper alone would pass with the production path still handing out unreserved pills.
    func testTheTextButtonArmReservesTheIcon() {
        let stack = InstantPageTextStyleStack()
        stack.push(.textColor(.black))
        stack.push(.fontSize(17.0))
        let string = attributedStringForRichText(
            .textButton(InstantPageButton(text: .plain("Open"), action: .url("https://telegram.org"), color: nil)),
            styleStack: stack)

        let attachment = string.attribute(NSAttributedString.Key(rawValue: InstantPageInlineButtonAttribute),
                                          at: 0, effectiveRange: nil) as? InstantPageInlineButtonAttachment
        XCTAssertEqual(attachment?.iconReserve, richTextInlineButtonIconReserve)
    }

    /// The pill's advance lives entirely on its placeholder's run delegate, so a reserve that reached
    /// `size` but not the delegate would draw the icon over the following word.
    func testTheReservedWidthReachesTheRunDelegate() {
        let stack = InstantPageTextStyleStack()
        stack.push(.textColor(.black))
        stack.push(.fontSize(17.0))
        let string = attributedStringForRichText(
            .textButton(InstantPageButton(text: .plain("Open"), action: .url("https://telegram.org"), color: nil)),
            styleStack: stack)

        guard let attachment = string.attribute(NSAttributedString.Key(rawValue: InstantPageInlineButtonAttribute),
                                                at: 0, effectiveRange: nil) as? InstantPageInlineButtonAttachment else {
            XCTFail("no pill attachment")
            return
        }
        let advance = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(string), nil, nil, nil))
        XCTAssertEqual(advance, attachment.size.width, accuracy: 0.01)
    }
}
