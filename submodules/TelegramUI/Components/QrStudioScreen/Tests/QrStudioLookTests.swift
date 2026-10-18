import XCTest
@testable import QrStudioScreen

final class QrStudioLookTests: XCTestCase {
    func testEmojiToggleLimits() {
        var ids: [Int] = [1]
        XCTAssertFalse(qrStudioToggle(&ids, 1, limit: 6))
        XCTAssertEqual(ids, [1])
        for id in 2 ... 6 {
            XCTAssertTrue(qrStudioToggle(&ids, id, limit: 6))
        }
        XCTAssertEqual(ids, [1, 2, 3, 4, 5, 6])
        XCTAssertTrue(qrStudioToggle(&ids, 7, limit: 6))
        XCTAssertEqual(ids, [2, 3, 4, 5, 6, 7])
    }

    func testEmojiToggleKeepsOrderOnRemoval() {
        var ids: [Int] = [5, 3, 9]
        XCTAssertTrue(qrStudioToggle(&ids, 3, limit: 6))
        XCTAssertEqual(ids, [5, 9])
        XCTAssertTrue(qrStudioToggle(&ids, 3, limit: 6))
        XCTAssertEqual(ids, [5, 9, 3])
    }

    func testSettingsCodableRoundTrip() throws {
        let settings = QrStudioLookSettings(kind: 1, colorId: 5, emoji: [.unicode("🔥"), .custom(42), .unicode("🎉")], giftId: 77)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(QrStudioLookSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.emoji, [.unicode("🔥"), .custom(42), .unicode("🎉")])
    }

    func testSettingsResolveFallbacks() {
        let settings = QrStudioLookSettings(kind: 2, colorId: nil, emoji: [.unicode("🔥"), .unicode("❓"), .custom(42), .custom(43)], giftId: 77)
        let resolved = settings.resolve(unicodeFiles: ["🔥": "fire"], customFiles: [42: "c42"], giftIds: [1, 2], hasPremium: true)
        XCTAssertEqual(resolved.emoji.map { $0.1 }, ["fire", "c42"])
        XCTAssertEqual(resolved.kind, 0)
        XCTAssertNil(resolved.giftId)
    }

    func testSettingsResolveKeepsGiftUntilGiftsAreKnown() {
        let settings = QrStudioLookSettings(kind: 2, colorId: 2, emoji: [], giftId: 77)
        let pending: QrStudioLookSettings.Resolved<String> = settings.resolve(unicodeFiles: [:], customFiles: [:], giftIds: nil, hasPremium: false)
        XCTAssertEqual(pending.kind, 2)
        XCTAssertEqual(pending.giftId, 77)
        let known: QrStudioLookSettings.Resolved<String> = settings.resolve(unicodeFiles: [:], customFiles: [:], giftIds: [5, 77], hasPremium: false)
        XCTAssertEqual(known.kind, 2)
        XCTAssertEqual(known.giftId, 77)
    }

    func testSettingsResolveDropsCustomEmojiWithoutPremium() {
        let settings = QrStudioLookSettings(kind: 1, colorId: nil, emoji: [.custom(42), .unicode("🔥")], giftId: nil)
        let resolved = settings.resolve(unicodeFiles: ["🔥": "fire"], customFiles: [42: "c42"], giftIds: nil, hasPremium: false)
        XCTAssertEqual(resolved.emoji.map { $0.1 }, ["fire"])
        XCTAssertEqual(resolved.kind, 1)
    }

    func testSettingsResolveUnknownKindFallsBackToColor() {
        let settings = QrStudioLookSettings(kind: 9, colorId: nil, emoji: [], giftId: nil)
        let resolved: QrStudioLookSettings.Resolved<String> = settings.resolve(unicodeFiles: [:], customFiles: [:], giftIds: nil, hasPremium: false)
        XCTAssertEqual(resolved.kind, 0)
    }
}
