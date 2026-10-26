import XCTest
import UIKit
import TelegramCore
@testable import TextFormat

private let testFont = UIFont.systemFont(ofSize: 17.0)

private func customEmojiAttribute(_ string: NSAttributedString, at index: Int) -> (fileId: Int64, range: NSRange)? {
    var effectiveRange = NSRange(location: 0, length: 0)
    guard let value = string.attribute(ChatTextInputAttributes.customEmoji, at: index, effectiveRange: &effectiveRange) as? ChatTextInputTextCustomEmojiAttribute else {
        return nil
    }
    return (value.fileId, effectiveRange)
}

private func hasCustomEmojiAttribute(_ string: NSAttributedString) -> Bool {
    var found = false
    string.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: string.length), options: [], using: { value, _, _ in
        if value != nil {
            found = true
        }
    })
    return found
}

private func applyEntities(_ text: String, _ entities: [MessageTextEntity]) -> NSAttributedString {
    return stringWithAppliedEntities(
        text,
        entities: entities,
        baseColor: .black,
        linkColor: .blue,
        baseFont: testFont,
        linkFont: testFont,
        boldFont: testFont,
        italicFont: testFont,
        boldItalicFont: testFont,
        fixedFont: testFont,
        blockQuoteFont: testFont,
        message: nil
    )
}

final class StringWithAppliedCustomEmojiEntitiesTests: XCTestCase {
    func testAttributeAppliedToEmojiAtEndOfText() {
        // A message that *ends* with a custom emoji is the common case, and the emoji's range ends
        // exactly at the end of the string.
        let text = "hi 😀"
        XCTAssertEqual((text as NSString).length, 5)

        let result = stringWithAppliedCustomEmojiEntities(NSAttributedString(string: text), entities: [
            MessageTextEntity(range: 3 ..< 5, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ], message: nil)

        let applied = customEmojiAttribute(result, at: 3)
        XCTAssertEqual(applied?.fileId, 42)
        XCTAssertEqual(applied?.range, NSRange(location: 3, length: 2))
    }

    func testAttributeAppliedToEmojiInsideText() {
        let result = stringWithAppliedCustomEmojiEntities(NSAttributedString(string: "😀 hi"), entities: [
            MessageTextEntity(range: 0 ..< 2, type: .CustomEmoji(stickerPack: nil, fileId: 7))
        ], message: nil)

        let applied = customEmojiAttribute(result, at: 0)
        XCTAssertEqual(applied?.fileId, 7)
        XCTAssertEqual(applied?.range, NSRange(location: 0, length: 2))
    }

    func testEntityStartingBeyondTextIsIgnored() {
        // Entity offsets are not trustworthy: they can describe a longer text than the one being
        // rendered (a live typing draft delivers text and entities as separate streamed values).
        let result = stringWithAppliedCustomEmojiEntities(NSAttributedString(string: "hi"), entities: [
            MessageTextEntity(range: 5 ..< 7, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ], message: nil)

        XCTAssertEqual(result.string, "hi")
        XCTAssertFalse(hasCustomEmojiAttribute(result))
    }

    func testEntityExtendingBeyondTextIsIgnored() {
        let result = stringWithAppliedCustomEmojiEntities(NSAttributedString(string: "hi 😀"), entities: [
            MessageTextEntity(range: 3 ..< 9, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ], message: nil)

        XCTAssertEqual(result.string, "hi 😀")
        XCTAssertFalse(hasCustomEmojiAttribute(result))
    }

    func testEmptyTextWithEntityIsIgnored() {
        let result = stringWithAppliedCustomEmojiEntities(NSAttributedString(string: ""), entities: [
            MessageTextEntity(range: 0 ..< 2, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ], message: nil)

        XCTAssertEqual(result.length, 0)
    }

    func testNonCustomEmojiEntitiesAreIgnored() {
        let result = stringWithAppliedCustomEmojiEntities(NSAttributedString(string: "hi 😀"), entities: [
            MessageTextEntity(range: 0 ..< 2, type: .Bold)
        ], message: nil)

        XCTAssertFalse(hasCustomEmojiAttribute(result))
    }
}

final class AdjustedEntityRangesTests: XCTestCase {
    private func adjust(_ text: String, _ entities: [MessageTextEntity], replacement: String) -> (string: NSMutableAttributedString, ranges: [NSRange?]) {
        let string = NSMutableAttributedString(string: text)
        let ranges = adjustedEntityRangesApplyingSubstitutions(string, entities: entities, baseAttributes: [:], formattedDateReplacement: { _, _ in
            return replacement
        })
        return (string, ranges)
    }

    func testRangesFollowSubstitutionWhenEntitiesAreSorted() {
        let text = "2026-01-01 12:00 hi 😀"
        let (string, ranges) = adjust(text, [
            MessageTextEntity(range: 0 ..< 16, type: .FormattedDate(format: .relative, date: 1767268800)),
            MessageTextEntity(range: 20 ..< 22, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ], replacement: "now")

        XCTAssertEqual(string.string, "now hi 😀")
        XCTAssertEqual(ranges[0], NSRange(location: 0, length: 3))
        XCTAssertEqual(ranges[1], NSRange(location: 7, length: 2))
        XCTAssertEqual((string.string as NSString).substring(with: ranges[1]!), "😀")
    }

    func testRangesFollowSubstitutionWhenEntitiesAreUnsorted() {
        // `addLocallyGeneratedEntities` appends client-detected entities after the server's, so the
        // array order does not follow the text order. The running substitution delta is only
        // correct when the entities are visited in text order.
        let text = "2026-01-01 12:00 hi 😀"
        let (string, ranges) = adjust(text, [
            MessageTextEntity(range: 20 ..< 22, type: .CustomEmoji(stickerPack: nil, fileId: 42)),
            MessageTextEntity(range: 0 ..< 16, type: .FormattedDate(format: .relative, date: 1767268800))
        ], replacement: "now")

        XCTAssertEqual(string.string, "now hi 😀")
        XCTAssertEqual(ranges[1], NSRange(location: 0, length: 3))
        XCTAssertEqual(ranges[0], NSRange(location: 7, length: 2))
        XCTAssertEqual((string.string as NSString).substring(with: ranges[0]!), "😀")
    }

    func testEntitySwallowedBySubstitutionHasNoRange() {
        // The bold entity sits inside the text the substitution replaces. Shifting it by the delta
        // would put it before the start of the string; there is nothing left for it to point at.
        let text = "2026-01-01 12:00 hi"
        let (string, ranges) = adjust(text, [
            MessageTextEntity(range: 0 ..< 16, type: .FormattedDate(format: .relative, date: 1767268800)),
            MessageTextEntity(range: 5 ..< 7, type: .Bold)
        ], replacement: "now")

        XCTAssertEqual(string.string, "now hi")
        XCTAssertEqual(ranges[0], NSRange(location: 0, length: 3))
        XCTAssertNil(ranges[1])
    }

    func testEntityBeyondTextHasNoRange() {
        let (_, ranges) = adjust("hi", [
            MessageTextEntity(range: 5 ..< 7, type: .Bold)
        ], replacement: "now")

        XCTAssertNil(ranges[0])
    }
}

final class StringWithAppliedEntitiesCustomEmojiTests: XCTestCase {
    // `stringWithAppliedEntities` applies the custom-emoji attribute itself. Callers must not
    // re-apply it from the entities' own offsets: those describe the source text, which the
    // substitution pass above is free to reshape.
    func testCustomEmojiAttributeIsApplied() {
        let result = applyEntities("hi 😀", [
            MessageTextEntity(range: 3 ..< 5, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ])

        let applied = customEmojiAttribute(result, at: 3)
        XCTAssertEqual(applied?.fileId, 42)
        XCTAssertEqual(applied?.range, NSRange(location: 3, length: 2))
    }

    func testCustomEmojiEntityBeyondTextIsIgnored() {
        let result = applyEntities("hi", [
            MessageTextEntity(range: 5 ..< 7, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ])

        XCTAssertEqual(result.string, "hi")
        XCTAssertFalse(hasCustomEmojiAttribute(result))
    }

    func testCustomEmojiEntityExtendingBeyondTextIsClamped() {
        let result = applyEntities("hi 😀", [
            MessageTextEntity(range: 3 ..< 9, type: .CustomEmoji(stickerPack: nil, fileId: 42))
        ])

        let applied = customEmojiAttribute(result, at: 3)
        XCTAssertEqual(applied?.fileId, 42)
        XCTAssertEqual(applied?.range, NSRange(location: 3, length: 2))
    }
}
