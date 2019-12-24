import Foundation
import Postbox
import SyncCore
import TelegramUIPreferences

private func patternWallpaper(slug: String, topColor: Int32, bottomColor: Int32?, intensity: Int32?, rotation: Int32?) -> TelegramWallpaper {
   return TelegramWallpaper.file(id: 0, accessHash: 0, isCreator: false, isDefault: true, isPattern: true, isDark: false, slug: slug, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "", size: nil, attributes: []), settings: WallpaperSettings(color: topColor, bottomColor: bottomColor, intensity: intensity ?? 50, rotation: rotation))
}

var dayClassicColorPresets: [PresentationThemeAccentColor] = [
    PresentationThemeAccentColor(index: 106, baseColor: .preset, accentColor: 0xf55783, bubbleColors: (0xd6f5ff, nil), wallpaper: patternWallpaper(slug: "p-pXcflrmFIBAAAAvXYQk-mCwZU", topColor: 0xfce3ec, bottomColor: nil, intensity: 40, rotation: nil)),
    PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0xff5fa9, bubbleColors: (0xfff4d7, nil), wallpaper: patternWallpaper(slug: "51nnTjx8mFIBAAAAaFGJsMIvWkk", topColor: 0xf6b594, bottomColor: 0xebf6cd, intensity: 46, rotation: 45)),
    PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0x5a9e29, bubbleColors: (0xdcf8c6, nil), wallpaper: patternWallpaper(slug: "R3j69wKskFIBAAAAoUdXWCKMzCM", topColor: 0xede6dd, bottomColor: nil, intensity: 50, rotation: nil)),
    PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0x7e5fe5, bubbleColors: (0xf5e2ff, nil), wallpaper: patternWallpaper(slug: "nQcFYJe1mFIBAAAAcI95wtIK0fk", topColor: 0xfcccf4, bottomColor: 0xae85f0, intensity: 54, rotation: nil)),
    PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0x199972, bubbleColors: (0xfffec7, nil), wallpaper: patternWallpaper(slug: "fqv01SQemVIBAAAApND8LDRUhRU", topColor: 0xc1e7cb, bottomColor: nil, intensity: 50, rotation: nil)),
    PresentationThemeAccentColor(index: 105, baseColor: .preset, accentColor: 0x009eee, bubbleColors: (0x94fff9, 0xccffc7), wallpaper: patternWallpaper(slug: "p-pXcflrmFIBAAAAvXYQk-mCwZU", topColor: 0xffbca6, bottomColor: 0xff63bd, intensity: 57, rotation: 225))
]

var dayColorPresets: [PresentationThemeAccentColor] = [
    PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0x007aff, bubbleColors: (0x007aff, 0xff53f4), wallpaper: nil),
    PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0x00b09b, bubbleColors: (0xaee946, 0x00b09b), wallpaper: nil),
    PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0xd33213, bubbleColors: (0xf9db00, 0xd33213), wallpaper: nil),
    PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0xea8ced, bubbleColors: (0xea8ced, 0x00c2ed), wallpaper: nil)
]

var nightColorPresets: [PresentationThemeAccentColor] = [
    PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0x007aff, bubbleColors: (0x007aff, 0xff53f4), wallpaper: nil),
    PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0x00b09b, bubbleColors: (0xaee946, 0x00b09b), wallpaper: nil),
    PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0xd33213, bubbleColors: (0xf9db00, 0xd33213), wallpaper: nil),
    PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0xea8ced, bubbleColors: (0xea8ced, 0x00c2ed), wallpaper: nil)
]
