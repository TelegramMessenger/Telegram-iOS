import Foundation
import UIKit
import Postbox
import SyncCore
import TelegramUIPreferences

public func makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference, customIndex: Int64? = nil, serviceBackgroundColor: UIColor?, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch reference {
        case .dayClassic:
            theme = makeDefaultDayPresentationTheme(customIndex: customIndex, serviceBackgroundColor: serviceBackgroundColor, day: false, preview: preview)
        case .day:
            theme = makeDefaultDayPresentationTheme(customIndex: customIndex, serviceBackgroundColor: serviceBackgroundColor, day: true, preview: preview)
        case .night:
            theme = makeDefaultDarkPresentationTheme(customIndex: customIndex, preview: preview)
        case .nightAccent:
            theme = makeDefaultDarkTintedPresentationTheme(customIndex: customIndex, preview: preview)
    }
    return theme
}

public func customizePresentationTheme(_ theme: PresentationTheme, editing: Bool, accentColor: UIColor?, backgroundColors: (UIColor, UIColor?)?, bubbleColors: (UIColor, UIColor?)?, wallpaper: TelegramWallpaper? = nil) -> PresentationTheme {
    if accentColor == nil && bubbleColors == nil && backgroundColors == nil {
        return theme
    }
    switch theme.referenceTheme {
        case .day, .dayClassic:
            return customizeDefaultDayTheme(theme: theme, editing: editing, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper, serviceBackgroundColor: nil)
        case .night:
            return customizeDefaultDarkPresentationTheme(theme: theme, editing: editing, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
        case .nightAccent:
            return customizeDefaultDarkTintedPresentationTheme(theme: theme, editing: editing, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
    }
    
    return theme
}

public func makePresentationTheme(mediaBox: MediaBox, themeReference: PresentationThemeReference, customIndex: Int64? = nil, accentColor: UIColor? = nil, backgroundColors: (UIColor, UIColor?)? = nil, bubbleColors: (UIColor, UIColor?)? = nil, wallpaper: TelegramWallpaper? = nil, serviceBackgroundColor: UIColor? = nil, preview: Bool = false) -> PresentationTheme? {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            let defaultTheme = makeDefaultPresentationTheme(reference: reference, customIndex: customIndex, serviceBackgroundColor: serviceBackgroundColor, preview: preview)
            theme = customizePresentationTheme(defaultTheme, editing: true, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
        case let .local(info):
            if let path = mediaBox.completedResourcePath(info.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, themeReference: themeReference, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
        case let .cloud(info):
            if let settings = info.theme.settings {
                if let loadedTheme =  makePresentationTheme(mediaBox: mediaBox, themeReference: .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)), customIndex: themeReference.index, accentColor: accentColor ?? UIColor(rgb: UInt32(bitPattern: settings.accentColor)), backgroundColors: nil, bubbleColors: bubbleColors ?? settings.messageColors.flatMap { (UIColor(rgb: UInt32(bitPattern: $0.top)), UIColor(rgb: UInt32(bitPattern: $0.bottom))) }, wallpaper:  wallpaper ?? settings.wallpaper, serviceBackgroundColor: serviceBackgroundColor, preview: preview) {
                    theme = loadedTheme
                } else {
                    return nil
                }
            } else if let file = info.theme.file, let path = mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, themeReference: themeReference, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
    }
    return theme
}
