import XCTest
@testable import QrStudioScreen

final class QrStudioServerLookTests: XCTestCase {
    func testColorModeSendsOnlyTheBackdrop() {
        let backdrop = QrStudioLookSettings(kind: 0, colorId: nil, emoji: [.unicode("🔥")], giftId: nil, backdropId: 5)
        XCTAssertEqual(backdrop.serverLook(hasPremium: true), .emojiBackdrop(emoji: nil, backdropId: 5))
        let profileColor = QrStudioLookSettings(kind: 0, colorId: 7, emoji: [], giftId: nil)
        XCTAssertEqual(profileColor.serverLook(hasPremium: true), .default)
    }

    func testAnyThemeIsTheServerDefault() {
        let classic = QrStudioLookSettings(kind: 0, colorId: 7, emoji: [], giftId: nil, themeId: QrStudioTheme.defaultId, backdropId: 5)
        XCTAssertEqual(classic.serverLook(hasPremium: true), .default)
        let cloud = QrStudioLookSettings(kind: 0, colorId: nil, emoji: [], giftId: nil, themeId: "🎄")
        XCTAssertEqual(cloud.serverLook(hasPremium: true), .default)
    }

    func testEmojiAreSentWithTheirBackdrop() {
        let settings = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.unicode("🔥"), .custom(42), .unicode("🎉")], giftId: 9, backdropId: 4)
        XCTAssertEqual(settings.serverLook(hasPremium: true), .emojiBackdrop(emoji: [.unicode("🔥"), .custom(42), .unicode("🎉")], backdropId: 4))
        XCTAssertEqual(settings.serverLook(hasPremium: false), .emojiBackdrop(emoji: [.unicode("🔥"), .unicode("🎉")], backdropId: 4))
        let noBackdrop = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.unicode("🔥")], giftId: nil)
        XCTAssertEqual(noBackdrop.serverLook(hasPremium: true), .emojiBackdrop(emoji: [.unicode("🔥")], backdropId: nil))
    }

    func testEmojiThatCannotBeSentLeaveTheBackdrop() {
        let onlyCustom = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.custom(42)], giftId: nil, backdropId: 4)
        XCTAssertEqual(onlyCustom.serverLook(hasPremium: false), .emojiBackdrop(emoji: nil, backdropId: 4))
        let onlyCustomNoBackdrop = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.custom(42)], giftId: nil)
        XCTAssertEqual(onlyCustomNoBackdrop.serverLook(hasPremium: false), .default)
    }

    func testGift() {
        XCTAssertEqual(QrStudioLookSettings(kind: 2, colorId: nil, emoji: [], giftId: 77).serverLook(hasPremium: false), .gift(77))
        XCTAssertEqual(QrStudioLookSettings(kind: 2, colorId: nil, emoji: [], giftId: nil).serverLook(hasPremium: false), .default)
    }

    func testApplyingTheServerLookKeepsTheCodeSettings() {
        var local = QrStudioLookSettings(kind: 0, colorId: 3, emoji: [.unicode("🔥")], giftId: nil, themeId: "🎄")
        local.codeRemoveFee = true
        local.codeExpires = true

        let backdrop = local.applying(.emojiBackdrop(emoji: nil, backdropId: 5))
        XCTAssertEqual(backdrop.kind, 0)
        XCTAssertEqual(backdrop.backdropId, 5)
        XCTAssertNil(backdrop.themeId)
        XCTAssertEqual(backdrop.codeExpires, true)
        XCTAssertEqual(backdrop.serverLook(hasPremium: true), .emojiBackdrop(emoji: nil, backdropId: 5))

        let emoji = local.applying(.emojiBackdrop(emoji: [.custom(1), .unicode("🎉")], backdropId: 4))
        XCTAssertEqual(emoji.kind, 1)
        XCTAssertEqual(emoji.emoji, [.custom(1), .unicode("🎉")])
        XCTAssertEqual(emoji.backdropId, 4)
        XCTAssertEqual(emoji.codeRemoveFee, true)
        XCTAssertNil(emoji.themeId)
        XCTAssertEqual(emoji.serverLook(hasPremium: true), .emojiBackdrop(emoji: [.custom(1), .unicode("🎉")], backdropId: 4))

        let emojiOnly = backdrop.applying(.emojiBackdrop(emoji: [.unicode("🎉")], backdropId: nil))
        XCTAssertEqual(emojiOnly.kind, 1)
        XCTAssertNil(emojiOnly.backdropId)

        let gift = local.applying(.gift(8))
        XCTAssertEqual(gift.serverLook(hasPremium: false), .gift(8))

        let reset = backdrop.applying(.default)
        XCTAssertEqual(reset.kind, 0)
        XCTAssertNil(reset.themeId)
        XCTAssertNil(reset.colorId)
        XCTAssertNil(reset.backdropId)
        XCTAssertEqual(reset.serverLook(hasPremium: true), .default)
    }
}
