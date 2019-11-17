import Foundation
import UIKit
import Postbox
import TelegramUIPreferences

public func makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference, accentColor: UIColor?, bubbleColors: (UIColor, UIColor?)?, serviceBackgroundColor: UIColor, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch reference {
        case .dayClassic:
            theme = makeDefaultDayPresentationTheme(bubbleColors: nil, serviceBackgroundColor: serviceBackgroundColor, day: false, preview: preview)
        case .night:
            theme = makeDarkPresentationTheme(accentColor: accentColor, bubbleColors: bubbleColors, preview: preview)
        case .nightAccent:
            theme = makeDarkAccentPresentationTheme(accentColor: accentColor, bubbleColors: bubbleColors, preview: preview)
        case .day:
            theme = makeDefaultDayPresentationTheme(accentColor: accentColor, bubbleColors: bubbleColors, serviceBackgroundColor: serviceBackgroundColor, day: true, preview: preview)
    }
    return theme
}

public func makePresentationTheme(mediaBox: MediaBox, themeReference: PresentationThemeReference, accentColor: UIColor?, bubbleColors: (UIColor, UIColor?)?, serviceBackgroundColor: UIColor, preview: Bool = false) -> PresentationTheme? {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            theme = makeDefaultPresentationTheme(reference: reference, accentColor: accentColor, bubbleColors: bubbleColors, serviceBackgroundColor: serviceBackgroundColor, preview: preview)
        case let .local(info):
            if let path = mediaBox.completedResourcePath(info.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, resolvedWallpaper: info.resolvedWallpaper) {
                theme = loadedTheme
            } else {
                return nil
            }
        case let .cloud(info):
            if let file = info.theme.file, let path = mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data, resolvedWallpaper: info.resolvedWallpaper) {
                theme = loadedTheme
            } else {
                return nil
            }
    }
    return theme
}
