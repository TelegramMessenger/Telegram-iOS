import Foundation
import Postbox
import SyncCore
import TelegramUIPreferences

private func patternWallpaper(slug: String, colors: [UInt32], intensity: Int32?, rotation: Int32?) -> TelegramWallpaper {
    return TelegramWallpaper.file(id: 0, accessHash: 0, isCreator: false, isDefault: true, isPattern: true, isDark: false, slug: slug, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "", size: nil, attributes: []), settings: WallpaperSettings(colors: colors, intensity: intensity ?? 50, rotation: rotation))
}

var dayClassicColorPresets: [PresentationThemeAccentColor] = [
    // Pink with Blue
    PresentationThemeAccentColor(index: 106, baseColor: .preset, accentColor: 0xfff55783, bubbleColors: (0xffd6f5ff, 0xffc9fdfe), wallpaper: patternWallpaper(slug: "fqv01SQemVIBAAAApND8LDRUhRU", colors: [0x8dc0eb, 0xb9d1ea, 0xc6b1ef, 0xebd7ef], intensity: 50, rotation: nil)),

    // Pink with Gold
    PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0xFFFF5FA9, bubbleColors: (0xFFFFF4D7, nil), wallpaper: patternWallpaper(slug: "9GcNVISdSVADAAAAUcw5BYjELW4", colors: [0xeaa36e, 0xf0e486, 0xf29ebf, 0xe8c06e], intensity: 50, rotation: nil)),

    // Green
    PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0xFF5A9E29, bubbleColors: (0xffFFF8DF, nil), wallpaper: patternWallpaper(slug: "-Xc-np9y2VMCAAAARKr0yNNPYW0", colors: [0x7fc289, 0xe4d573, 0xafd677, 0xf0c07a], intensity: 50, rotation: nil)),

    // Purple
    PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0xFF7E5FE5, bubbleColors: (0xFFF5e2FF, nil), wallpaper: patternWallpaper(slug: "JrNEYdNhSFABAAAA9WtRdJkPRbY", colors: [0xe4b2ea, 0x8376c2, 0xeab9d9, 0xb493e6], intensity: 50, rotation: nil)),

    // Light Blue
    PresentationThemeAccentColor(index: 107, baseColor: .preset, accentColor: 0xFF2CB9ED, bubbleColors: (0xFFADF7B5, 0xFFFCFF8B), wallpaper: patternWallpaper(slug: "CJNyxPMgSVAEAAAAvW9sMwc51cw", colors: [0x1a2e1a, 0x47623c, 0x222e24, 0x314429], intensity: 50, rotation: nil)),

    // Mint
    PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0xFF199972, bubbleColors: (0xFFFFFEC7, nil), wallpaper: patternWallpaper(slug: "CJNyxPMgSVAEAAAAvW9sMwc51cw", colors: [0xdceb92, 0x8fe1d6, 0x67a3f2, 0x85d685], intensity: 50, rotation: nil)),

    // Pink with Green
    PresentationThemeAccentColor(index: 105, baseColor: .preset, accentColor: 0xFFDA90D9, bubbleColors: (0xFF94FFF9, 0xFFCCFFC7), wallpaper: patternWallpaper(slug: "mP3FG_iwSFAFAAAA2AklJO978pA", colors: [0xffc3b2, 0xe2c0ff, 0xffe7b2], intensity: 50, rotation: nil))
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
