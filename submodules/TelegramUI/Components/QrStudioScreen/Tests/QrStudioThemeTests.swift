import XCTest
import GlassBackgroundComponent
import TelegramCore
import TelegramUIPreferences
@testable import QrStudioScreen

final class QrStudioThemeTests: XCTestCase {
    private func theme(_ id: String, _ rgb: [UInt32]) -> QrStudioTheme {
        return QrStudioTheme(id: id, reference: .builtin(.dayClassic), wallpaper: .color(rgb.first ?? 0), colors: rgb.map { QrStudioColor(rgb: $0) })
    }

    func testSelectingAThemeShowsIt() {
        var look = QrStudioLook()
        let classic = self.theme(QrStudioTheme.defaultId, [0xd6e4ef, 0x9fc2dd])
        look.themes = [classic]
        look.selectTheme(id: classic.id)
        XCTAssertEqual(look.kind, .color)
        XCTAssertEqual(look.backdrop, .theme(classic))
        XCTAssertEqual(look.settings.themeId, classic.id)
    }

    func testSelectingAPaletteClearsTheTheme() {
        var look = QrStudioLook()
        look.themes = [self.theme(QrStudioTheme.defaultId, [0xd6e4ef])]
        look.selectTheme(id: QrStudioTheme.defaultId)
        let palettes = (0 ..< 5).map { QrStudioPalette.profile(id: Int32($0), center: 0x6ec2b7 + UInt32($0), edge: 0x4891ad) }
        look.palettes = palettes
        look.selectPalette(id: 3)
        XCTAssertNil(look.themeId)
        XCTAssertEqual(look.backdrop, .color(palettes[3]))
    }

    func testEmojiAreSavedOnlyWhileEmojiIsTheActiveLook() {
        var look = QrStudioLook()
        look.kind = .emoji
        look.emoji = [QrStudioEmojiItem(file: TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 1), partialReference: nil, resource: LocalFileMediaResource(fileId: 1), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: []), unicode: "🔥")]
        XCTAssertEqual(look.settings.emoji, [.unicode("🔥")])
        look.kind = .color
        XCTAssertEqual(look.settings.emoji, [])
    }

    func testUnknownThemeFallsBackToThePalette() {
        var look = QrStudioLook()
        look.themeId = "🦄"
        XCTAssertEqual(look.backdrop, .color(look.palette))
    }

    func testBrightWallpaperUsesLightGlassAndDarkInk() {
        let light = self.theme("a", [0xd6e4ef, 0xbcd7ea])
        XCTAssertTrue(light.isLight)
        XCTAssertLessThan(light.ink.luminance, 0.4)
        let dark = self.theme("b", [0x1c2b40, 0x0d1520])
        XCTAssertFalse(dark.isLight)
    }

    func testEveryBackdropUsesUntintedRegularGlass() {
        let untinted = GlassBackgroundView.TintColor(kind: .custom(style: .default, color: .clear))
        XCTAssertEqual(QrStudioGlass.tint(.theme(self.theme("b", [0x1c2b40, 0x0d1520]))), untinted)
        XCTAssertEqual(QrStudioGlass.tint(.emoji([], palette: QrStudioPalette.fallback)), untinted)
        XCTAssertEqual(QrStudioGlass.tint(.color(QrStudioPalette.fallback)), untinted)
        XCTAssertTrue(QrStudioBackdrop.theme(self.theme("b", [0x1c2b40, 0x0d1520])).isLight)
    }

    func testSettingsKeepTheThemeAndOldSettingsHaveNone() throws {
        var look = QrStudioLook()
        look.themes = [self.theme("🎄", [0xffffff])]
        look.selectTheme(id: "🎄")
        let data = try JSONEncoder().encode(look.settings)
        XCTAssertEqual(try JSONDecoder().decode(QrStudioLookSettings.self, from: data).themeId, "🎄")
        let old = QrStudioLookSettings(kind: 0, colorId: nil, emoji: [], giftId: nil)
        var json = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "themeId")
        let decoded = try JSONDecoder().decode(QrStudioLookSettings.self, from: try JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.themeId)
    }
}
