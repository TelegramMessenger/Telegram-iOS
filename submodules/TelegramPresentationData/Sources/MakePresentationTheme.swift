import Foundation
import UIKit
import Postbox
import SyncCore
import TelegramUIPreferences

public func makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference, extendingThemeReference: PresentationThemeReference? = nil, serviceBackgroundColor: UIColor?, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch reference {
        case .dayClassic:
            theme = makeDefaultDayPresentationTheme(extendingThemeReference: extendingThemeReference, serviceBackgroundColor: serviceBackgroundColor, day: false, preview: preview)
        case .day:
            theme = makeDefaultDayPresentationTheme(extendingThemeReference: extendingThemeReference, serviceBackgroundColor: serviceBackgroundColor, day: true, preview: preview)
        case .night:
            theme = makeDefaultDarkPresentationTheme(extendingThemeReference: extendingThemeReference, preview: preview)
        case .nightAccent:
            theme = makeDefaultDarkTintedPresentationTheme(extendingThemeReference: extendingThemeReference, preview: preview)
    }
    return theme
}

public func customizePresentationTheme(_ theme: PresentationTheme, editing: Bool, title: String? = nil, accentColor: UIColor?, backgroundColors: (UIColor, UIColor?)?, bubbleColors: (UIColor, UIColor?)?, wallpaper: TelegramWallpaper? = nil) -> PresentationTheme {
    if accentColor == nil && bubbleColors == nil && backgroundColors == nil && wallpaper == nil {
        return theme
    }
    switch theme.referenceTheme {
        case .day, .dayClassic:
            return customizeDefaultDayTheme(theme: theme, editing: editing, title: title, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper, serviceBackgroundColor: nil)
        case .night:
            return customizeDefaultDarkPresentationTheme(theme: theme, editing: editing, title: title, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
        case .nightAccent:
            return customizeDefaultDarkTintedPresentationTheme(theme: theme, editing: editing, title: title, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
    }
    
    return theme
}

public func makePresentationTheme(settings: TelegramThemeSettings, title: String? = nil, serviceBackgroundColor: UIColor? = nil) -> PresentationTheme? {
    let defaultTheme = makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference(baseTheme: settings.baseTheme), extendingThemeReference: nil, serviceBackgroundColor: serviceBackgroundColor, preview: false)
    return customizePresentationTheme(defaultTheme, editing: true, title: title, accentColor: UIColor(argb: settings.accentColor), backgroundColors: nil, bubbleColors: settings.messageColors.flatMap { (UIColor(argb: $0.top), UIColor(argb: $0.bottom)) }, wallpaper: settings.wallpaper)
}

public func makePresentationTheme(mediaBox: MediaBox, themeReference: PresentationThemeReference, extendingThemeReference: PresentationThemeReference? = nil, accentColor: UIColor? = nil, backgroundColors: (UIColor, UIColor?)? = nil, bubbleColors: (UIColor, UIColor?)? = nil, wallpaper: TelegramWallpaper? = nil, serviceBackgroundColor: UIColor? = nil, preview: Bool = false) -> PresentationTheme? {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            let defaultTheme = makeDefaultPresentationTheme(reference: reference, extendingThemeReference: extendingThemeReference, serviceBackgroundColor: serviceBackgroundColor, preview: preview)
            theme = customizePresentationTheme(defaultTheme, editing: true, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
        case let .local(info):
            if let path = mediaBox.completedResourcePath(info.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, themeReference: themeReference, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
        case let .cloud(info):
            if let settings = info.theme.settings {
                if let loadedTheme = makePresentationTheme(mediaBox: mediaBox, themeReference: .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)), extendingThemeReference: themeReference, accentColor: accentColor ?? UIColor(argb: settings.accentColor), backgroundColors: nil, bubbleColors: bubbleColors ?? settings.messageColors.flatMap { (UIColor(argb: $0.top), UIColor(argb: $0.bottom)) }, wallpaper:  wallpaper ?? settings.wallpaper, serviceBackgroundColor: serviceBackgroundColor, preview: preview) {
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
