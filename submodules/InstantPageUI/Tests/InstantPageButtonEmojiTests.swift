import XCTest
import UIKit
import CoreText
import TelegramCore
import TextFormat
@testable import InstantPageUI

/// Mirrors the `.textCustomEmoji` arm of `attributedStringForRichText`
/// (`InstantPageTextItem.swift:969`) exactly: a ONE-character placeholder whose run delegate
/// reports the BODY-TEXT emoji size and the font's raw (negative) descender. Button-label
/// handling has to correct both, so the tests must start from the uncorrected shape.
func makeBodyTextEmojiPlaceholder(font: UIFont, fileId: Int64) -> NSAttributedString {
    struct RunStruct {
        let ascent: CGFloat
        let descent: CGFloat
        let width: CGFloat
    }
    let itemSize = font.ascender - font.descender + 4.0 * font.pointSize / 17.0
    let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
    extentBuffer.initialize(to: RunStruct(ascent: font.ascender, descent: font.descender, width: itemSize))
    var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { pointer in
        pointer.assumingMemoryBound(to: RunStruct.self).deallocate()
    }, getAscent: { pointer -> CGFloat in
        return pointer.assumingMemoryBound(to: RunStruct.self).pointee.ascent
    }, getDescent: { pointer -> CGFloat in
        return pointer.assumingMemoryBound(to: RunStruct.self).pointee.descent
    }, getWidth: { pointer -> CGFloat in
        return pointer.assumingMemoryBound(to: RunStruct.self).pointee.width
    })
    let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)!
    let result = NSMutableAttributedString(string: instantPageInlineAttachmentPlaceholder, attributes: [
        .font: font,
        .foregroundColor: UIColor.black
    ])
    result.addAttributes([
        kCTRunDelegateAttributeName as NSAttributedString.Key: delegate,
        ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(
            interactivelySelectedFromPackId: nil,
            fileId: fileId,
            file: nil
        )
    ], range: NSRange(location: 0, length: 1))
    return result
}

/// The 15pt semibold face an inline pill's label is built with — `.fontSize(15)` + `.medium`
/// pushed onto the style stack by the `.textButton` arm.
let testButtonLabelFont: UIFont = UIFont.systemFont(ofSize: 15.0, weight: .medium)

func makeTestButton() -> InstantPageButton {
    return InstantPageButton(text: .plain("Buy"), action: .url("https://telegram.org"), color: nil)
}

func makeTestLabel(_ pieces: [NSAttributedString]) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for piece in pieces {
        result.append(piece)
    }
    return result
}

func makePlainLabelPiece(_ text: String) -> NSAttributedString {
    return NSAttributedString(string: text, attributes: [
        .font: testButtonLabelFont,
        .foregroundColor: UIColor.black
    ])
}

final class InstantPageButtonEmojiTests: XCTestCase {
    /// An emoji inside a pill must never be clipped by the capsule, so its square has to fit
    /// inside the label box the pill reserves (pill height minus the vertical padding).
    func testEmojiFitsInsideThePillsLabelBox() {
        let label = makeTestLabel([
            makePlainLabelPiece("Buy "),
            makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)
        ])
        let attachment = instantPageInlineButtonAttachment(button: makeTestButton(), labelString: label)

        let labelBoxHeight = attachment.ascent + attachment.descent - instantPageInlineButtonVerticalPadding * 2.0
        let side = instantPageButtonLabelEmojiSide(font: testButtonLabelFont)
        XCTAssertLessThanOrEqual(side, labelBoxHeight + 0.01)
    }

    /// The reserved advance and the drawn square must be the same number, or the label's other
    /// glyphs shift. Measured as the width the emoji adds on top of the same label without it.
    func testEmojiReservesExactlyItsSquareSide() {
        let button = makeTestButton()
        let withoutEmoji = instantPageInlineButtonAttachment(
            button: button,
            labelString: makeTestLabel([makePlainLabelPiece("Buy ")])
        )
        let withEmoji = instantPageInlineButtonAttachment(
            button: button,
            labelString: makeTestLabel([
                makePlainLabelPiece("Buy "),
                makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)
            ])
        )

        let added = withEmoji.size.width - withoutEmoji.size.width
        XCTAssertEqual(added, instantPageButtonLabelEmojiSide(font: testButtonLabelFont), accuracy: 0.01)
    }

    /// A label that is ONLY an emoji has no other run contributing a positive descent, so the
    /// uncorrected (negative) delegate descent collapses the pill. It must measure the same
    /// height as a pill holding ordinary text in the same font.
    func testEmojiOnlyLabelDoesNotCollapseThePill() {
        let button = makeTestButton()
        let textOnly = instantPageInlineButtonAttachment(
            button: button,
            labelString: makeTestLabel([makePlainLabelPiece("Buy")])
        )
        let emojiOnly = instantPageInlineButtonAttachment(
            button: button,
            labelString: makeTestLabel([makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)])
        )

        XCTAssertGreaterThan(emojiOnly.descent, 0.0)
        // Loose accuracy on purpose: the claim is "does not collapse" — the uncorrected delegate
        // gives ≈12.9pt against ≈19.7pt — not that CoreText's reported ascent for a glyph run is
        // bit-identical to `UIFont.ascender`.
        XCTAssertEqual(emojiOnly.size.height, textOnly.size.height, accuracy: 0.5)
    }

    /// A button label with no emoji must be untouched — the rewrite has to be inert on the
    /// overwhelmingly common path.
    func testLabelWithoutEmojiIsUnchanged() {
        let button = makeTestButton()
        let label = makeTestLabel([makePlainLabelPiece("Buy now")])
        let attachment = instantPageInlineButtonAttachment(button: button, labelString: label)

        XCTAssertEqual(attachment.labelString.string, "Buy now")
        XCTAssertNil(attachment.labelString.attribute(
            kCTRunDelegateAttributeName as NSAttributedString.Key,
            at: 0,
            effectiveRange: nil
        ))
    }
}

final class InstantPageButtonEmojiPlacementTests: XCTestCase {
    /// One placement per emoji, in label order.
    func testOnePlacementPerEmoji() {
        let label = makeTestLabel([
            makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 11),
            makePlainLabelPiece(" Buy "),
            makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 22)
        ])
        let attachment = instantPageInlineButtonAttachment(button: makeTestButton(), labelString: label)
        let placements = instantPageButtonEmojiPlacements(attachment: attachment, pillSize: attachment.size)

        XCTAssertEqual(placements.count, 2)
        XCTAssertEqual(placements[0].emoji.fileId, 11)
        XCTAssertEqual(placements[1].emoji.fileId, 22)
        XCTAssertLessThan(placements[0].frame.minX, placements[1].frame.minX)
    }

    /// The whole point of Task 1's sizing: a placement must sit entirely inside the pill, or the
    /// capsule clip shaves it.
    func testPlacementsFitInsideThePill() {
        let label = makeTestLabel([
            makePlainLabelPiece("Buy "),
            makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)
        ])
        let attachment = instantPageInlineButtonAttachment(button: makeTestButton(), labelString: label)
        let pillRect = CGRect(origin: CGPoint(), size: attachment.size)
        let placements = instantPageButtonEmojiPlacements(attachment: attachment, pillSize: attachment.size)

        XCTAssertEqual(placements.count, 1)
        XCTAssertTrue(pillRect.insetBy(dx: -0.01, dy: -0.01).contains(placements[0].frame))
    }

    /// Same for an emoji-only label, the case Task 1's descent fix exists for.
    func testEmojiOnlyPlacementFitsInsideThePill() {
        let label = makeTestLabel([makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)])
        let attachment = instantPageInlineButtonAttachment(button: makeTestButton(), labelString: label)
        let pillRect = CGRect(origin: CGPoint(), size: attachment.size)
        let placements = instantPageButtonEmojiPlacements(attachment: attachment, pillSize: attachment.size)

        XCTAssertEqual(placements.count, 1)
        XCTAssertTrue(pillRect.insetBy(dx: -0.01, dy: -0.01).contains(placements[0].frame))
    }

    /// A justified `pageBlockButtonRow` stretches its pills to an equal column width and the pill
    /// centres its label inside that. The emoji must travel with the label, not stay pinned to the
    /// left padding.
    func testPlacementFollowsTheLabelWhenThePillIsStretched() {
        let label = makeTestLabel([
            makePlainLabelPiece("Buy "),
            makeBodyTextEmojiPlaceholder(font: testButtonLabelFont, fileId: 1)
        ])
        let attachment = instantPageInlineButtonAttachment(button: makeTestButton(), labelString: label)
        let stretched = CGSize(width: attachment.size.width + 100.0, height: 40.0)

        let natural = instantPageButtonEmojiPlacements(attachment: attachment, pillSize: attachment.size)
        let widened = instantPageButtonEmojiPlacements(attachment: attachment, pillSize: stretched)

        XCTAssertEqual(widened[0].frame.minX - natural[0].frame.minX, 50.0, accuracy: 0.01)
        XCTAssertTrue(CGRect(origin: CGPoint(), size: stretched).contains(widened[0].frame))
    }

    /// A label with no emoji produces no placements — Task 3 must not allocate layers for it.
    func testNoPlacementsWithoutEmoji() {
        let attachment = instantPageInlineButtonAttachment(
            button: makeTestButton(),
            labelString: makeTestLabel([makePlainLabelPiece("Buy now")])
        )
        XCTAssertTrue(instantPageButtonEmojiPlacements(attachment: attachment, pillSize: attachment.size).isEmpty)
    }
}
