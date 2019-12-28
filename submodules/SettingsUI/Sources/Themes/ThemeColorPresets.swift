import Foundation
import Postbox
import SyncCore
import TelegramUIPreferences

private func patternWallpaper(slug: String, topColor: UInt32, bottomColor: UInt32?, intensity: Int32?, rotation: Int32?) -> TelegramWallpaper {
   return TelegramWallpaper.file(id: 0, accessHash: 0, isCreator: false, isDefault: true, isPattern: true, isDark: false, slug: slug, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "", size: nil, attributes: []), settings: WallpaperSettings(color: topColor, bottomColor: bottomColor, intensity: intensity ?? 50, rotation: rotation))
}

var dayClassicColorPresets: [PresentationThemeAccentColor] = [
    PresentationThemeAccentColor(index: 106, baseColor: .preset, accentColor: 0xfff55783, bubbleColors: (0xffd6f5ff, 0xffc9fdfe), wallpaper: patternWallpaper(slug: "p-pXcflrmFIBAAAAvXYQk-mCwZU", topColor: 0xfffce3ec, bottomColor: 0xfffec8ff, intensity: 50, rotation: 45)),
    PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0xffff5fa9, bubbleColors: (0xfffff4d7, nil), wallpaper: patternWallpaper(slug: "51nnTjx8mFIBAAAAaFGJsMIvWkk", topColor: 0xfff6b594, bottomColor: 0xffebf6cd, intensity: 46, rotation: 45)),
    PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0xff5a9e29, bubbleColors: (0xfffff8df, 0xffdcf8c6), wallpaper: patternWallpaper(slug: "R3j69wKskFIBAAAAoUdXWCKMzCM", topColor: 0xffede6dd, bottomColor: 0xffffd59e, intensity: 50, rotation: nil)),
    PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0xff7e5fe5, bubbleColors: (0xfff5e2ff, nil), wallpaper: patternWallpaper(slug: "nQcFYJe1mFIBAAAAcI95wtIK0fk", topColor: 0xfffcccf4, bottomColor: 0xffae85f0, intensity: 54, rotation: nil)),
    PresentationThemeAccentColor(index: 107, baseColor: .preset, accentColor: 0xff2cb9ed, bubbleColors: (0xffadf7b5, 0xfffcff8b), wallpaper: patternWallpaper(slug: "nQcFYJe1mFIBAAAAcI95wtIK0fk", topColor: 0xff1a2d1a, bottomColor: 0xff5f6f54, intensity: 50, rotation: 225)),
    PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0xff199972, bubbleColors: (0xfffffec7, nil), wallpaper: patternWallpaper(slug: "fqv01SQemVIBAAAApND8LDRUhRU", topColor: 0xffc1e7cb, bottomColor: nil, intensity: 50, rotation: nil)),
    PresentationThemeAccentColor(index: 105, baseColor: .preset, accentColor: 0x0ff09eee, bubbleColors: (0xff94fff9, 0xffccffc7), wallpaper: patternWallpaper(slug: "p-pXcflrmFIBAAAAvXYQk-mCwZU", topColor: 0xffffbca6, bottomColor: 0xffff63bd, intensity: 57, rotation: 225))
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
