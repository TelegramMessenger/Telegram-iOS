import XCTest
@testable import QrStudioScreen

final class QrStudioServerLookTests: XCTestCase {
    func testColorIsSentOnlyWithPremium() {
        let settings = QrStudioLookSettings(kind: 0, colorId: 7, emoji: [], giftId: nil)
        XCTAssertEqual(settings.serverLook(hasPremium: true), .color(7))
        XCTAssertEqual(settings.serverLook(hasPremium: false), .default)
    }

    func testAnyThemeIsTheServerDefault() {
        let classic = QrStudioLookSettings(kind: 0, colorId: 7, emoji: [], giftId: nil, themeId: QrStudioTheme.defaultId)
        XCTAssertEqual(classic.serverLook(hasPremium: true), .default)
        let cloud = QrStudioLookSettings(kind: 0, colorId: nil, emoji: [], giftId: nil, themeId: "🎄")
        XCTAssertEqual(cloud.serverLook(hasPremium: true), .default)
    }

    func testEmojiKeepOrderAndDropCustomWithoutPremium() {
        let settings = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.unicode("🔥"), .custom(42), .unicode("🎉")], giftId: 9)
        XCTAssertEqual(settings.serverLook(hasPremium: true), .emoji([.unicode("🔥"), .custom(42), .unicode("🎉")]))
        XCTAssertEqual(settings.serverLook(hasPremium: false), .emoji([.unicode("🔥"), .unicode("🎉")]))
        let onlyCustom = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.custom(42)], giftId: nil)
        XCTAssertEqual(onlyCustom.serverLook(hasPremium: false), .default)
    }

    func testGift() {
        XCTAssertEqual(QrStudioLookSettings(kind: 2, colorId: nil, emoji: [], giftId: 77).serverLook(hasPremium: false), .gift(77))
        XCTAssertEqual(QrStudioLookSettings(kind: 2, colorId: nil, emoji: [], giftId: nil).serverLook(hasPremium: false), .default)
    }

    func testApplyingTheServerLookKeepsTheCodeSettings() {
        var local = QrStudioLookSettings(kind: 0, colorId: 3, emoji: [.unicode("🔥")], giftId: nil, themeId: "🎄")
        local.codeRemoveFee = true
        local.codeExpires = true

        let color = local.applying(.color(5))
        XCTAssertEqual(color.serverLook(hasPremium: true), .color(5))
        XCTAssertNil(color.themeId)
        XCTAssertEqual(color.codeExpires, true)

        let emoji = local.applying(.emoji([.custom(1), .unicode("🎉")]))
        XCTAssertEqual(emoji.kind, 1)
        XCTAssertEqual(emoji.emoji, [.custom(1), .unicode("🎉")])
        XCTAssertEqual(emoji.codeRemoveFee, true)
        XCTAssertNil(emoji.themeId)

        let gift = local.applying(.gift(8))
        XCTAssertEqual(gift.serverLook(hasPremium: false), .gift(8))

        let reset = color.applying(.default)
        XCTAssertEqual(reset.kind, 0)
        XCTAssertNil(reset.themeId)
        XCTAssertNil(reset.colorId)
        XCTAssertEqual(reset.serverLook(hasPremium: true), .default)
    }
}
