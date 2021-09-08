import Foundation
import UIKit
import Postbox
import TelegramUIPreferences
import TelegramCore

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

public func customizePresentationTheme(_ theme: PresentationTheme, specialMode: Bool = false, editing: Bool, title: String? = nil, accentColor: UIColor?, backgroundColors: [UInt32], bubbleColors: [UInt32], animateBubbleColors: Bool?, wallpaper: TelegramWallpaper? = nil, baseColor: PresentationThemeBaseColor? = nil) -> PresentationTheme {
    if accentColor == nil && bubbleColors.isEmpty && backgroundColors.isEmpty && wallpaper == nil {
        return theme
    }
    switch theme.referenceTheme {
        case .day, .dayClassic:
            return customizeDefaultDayTheme(theme: theme, specialMode: specialMode, editing: editing, title: title, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, animateBubbleColors: animateBubbleColors ?? false, wallpaper: wallpaper, serviceBackgroundColor: nil)
        case .night:
            return customizeDefaultDarkPresentationTheme(theme: theme, editing: editing, title: title, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, animateBubbleColors: animateBubbleColors ?? false, wallpaper: wallpaper, baseColor: baseColor)
        case .nightAccent:
            return customizeDefaultDarkTintedPresentationTheme(theme: theme, editing: editing, title: title, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, animateBubbleColors: animateBubbleColors ?? false, wallpaper: wallpaper, baseColor: baseColor)
    }
}

public func makePresentationTheme(settings: TelegramThemeSettings, specialMode: Bool = false, title: String? = nil, serviceBackgroundColor: UIColor? = nil) -> PresentationTheme? {
    var baseTheme: TelegramBaseTheme = settings.baseTheme
    if specialMode && baseTheme == .night {
        baseTheme = .tinted
    }
    let defaultTheme = makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference(baseTheme: baseTheme), extendingThemeReference: nil, serviceBackgroundColor: serviceBackgroundColor, preview: false)
    return customizePresentationTheme(defaultTheme, specialMode: specialMode, editing: true, title: title, accentColor: UIColor(argb: settings.accentColor), backgroundColors: [], bubbleColors: settings.messageColors, animateBubbleColors: settings.animateMessageColors, wallpaper: settings.wallpaper)
}

public func makePresentationTheme(mediaBox: MediaBox, themeReference: PresentationThemeReference, extendingThemeReference: PresentationThemeReference? = nil, accentColor: UIColor? = nil, backgroundColors: [UInt32] = [], bubbleColors: [UInt32] = [], animateBubbleColors: Bool? = nil, wallpaper: TelegramWallpaper? = nil, baseColor: PresentationThemeBaseColor? = nil, serviceBackgroundColor: UIColor? = nil, specialMode: Bool = false, preview: Bool = false) -> PresentationTheme? {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            let defaultTheme = makeDefaultPresentationTheme(reference: reference, extendingThemeReference: extendingThemeReference, serviceBackgroundColor: serviceBackgroundColor, preview: preview)
            theme = customizePresentationTheme(defaultTheme, specialMode: specialMode, editing: true, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, animateBubbleColors: animateBubbleColors, wallpaper: wallpaper, baseColor: baseColor)
        case let .local(info):
            if let path = mediaBox.completedResourcePath(info.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, themeReference: themeReference, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, animateBubbleColors: animateBubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
        case let .cloud(info):
            if let settings = info.theme.settings {
                if let loadedTheme = makePresentationTheme(mediaBox: mediaBox, themeReference: .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)), extendingThemeReference: themeReference, accentColor: accentColor ?? UIColor(argb: settings.accentColor), backgroundColors: [], bubbleColors: bubbleColors.isEmpty ? settings.messageColors : bubbleColors, animateBubbleColors: animateBubbleColors ?? settings.animateMessageColors, wallpaper: wallpaper ?? settings.wallpaper, serviceBackgroundColor: serviceBackgroundColor, preview: preview) {
                    theme = loadedTheme
                } else {
                    return nil
                }
            } else if let file = info.theme.file, let path = mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, themeReference: themeReference, resolvedWallpaper: info.resolvedWallpaper) {
                theme = customizePresentationTheme(loadedTheme, editing: false, accentColor: accentColor, backgroundColors: backgroundColors, bubbleColors: bubbleColors, animateBubbleColors: animateBubbleColors, wallpaper: wallpaper)
            } else {
                return nil
            }
    }
    return theme
}
