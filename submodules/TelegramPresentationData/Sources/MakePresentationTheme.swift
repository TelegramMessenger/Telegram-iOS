import Foundation
import UIKit
import Postbox
import SyncCore
import TelegramUIPreferences

public func makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference, serviceBackgroundColor: UIColor?, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch reference {
        case .dayClassic:
            theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: serviceBackgroundColor, day: false, preview: preview)
        case .day:
            theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: serviceBackgroundColor, day: true, preview: preview)
        case .night:
            theme = makeDefaultDarkPresentationTheme(preview: preview)
        case .nightAccent:
            theme = makeDefaultDarkTintedPresentationTheme(preview: preview)
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

public func makePresentationTheme(mediaBox: MediaBox, themeReference: PresentationThemeReference, accentColor: UIColor? = nil, backgroundColors: (UIColor, UIColor?)? = nil, bubbleColors: (UIColor, UIColor?)? = nil, wallpaper: TelegramWallpaper? = nil, serviceBackgroundColor: UIColor? = nil, preview: Bool = false) -> PresentationTheme? {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            let defaultTheme = makeDefaultPresentationTheme(reference: reference, serviceBackgroundColor: serviceBackgroundColor, preview: preview)
            theme = customizePresentationTheme(defaultTheme, editing: true, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
        case let .local(info):
            if let path = mediaBox.completedResourcePath(info.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
        case let .cloud(info):
            if let file = info.theme.file, let path = mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
    }
    return theme
}
