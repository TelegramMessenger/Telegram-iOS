import Foundation
import UIKit
import Postbox
import TelegramUIPreferences

public func makeDefaultPresentationTheme(reference: PresentationBuiltinThemeReference, accentColor: UIColor?, serviceBackgroundColor: UIColor, baseColor: PresentationThemeBaseColor?, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch reference {
        case .dayClassic:
            theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: serviceBackgroundColor, baseColor: baseColor, day: false, preview: preview)
        case .night:
            theme = makeDarkPresentationTheme(accentColor: accentColor, baseColor: baseColor, preview: preview)
        case .nightAccent:
            theme = makeDarkAccentPresentationTheme(accentColor: accentColor, baseColor: baseColor, preview: preview)
        case .day:
            theme = makeDefaultDayPresentationTheme(accentColor: accentColor, serviceBackgroundColor: serviceBackgroundColor, baseColor: baseColor, day: true, preview: preview)
    }
    return theme
}

public func makePresentationTheme(mediaBox: MediaBox, themeReference: PresentationThemeReference, accentColor: UIColor?, serviceBackgroundColor: UIColor, baseColor: PresentationThemeBaseColor?, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            theme = makeDefaultPresentationTheme(reference: reference, accentColor: accentColor, serviceBackgroundColor: serviceBackgroundColor, baseColor: baseColor, preview: preview)
        case let .local(info):
            if let path = mediaBox.completedResourcePath(info.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data) {
                theme = loadedTheme
            } else {
                theme = makeDefaultPresentationTheme(reference: .dayClassic, accentColor: nil, serviceBackgroundColor: serviceBackgroundColor, baseColor: baseColor, preview: preview)
            }
        case let .cloud(info):
            if let path = mediaBox.completedResourcePath(info.file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead), let loadedTheme = makePresentationTheme(data: data) {
                theme = loadedTheme
            } else {
                theme = makeDefaultPresentationTheme(reference: .dayClassic, accentColor: nil, serviceBackgroundColor: serviceBackgroundColor, baseColor: baseColor, preview: preview)
            }
    }
    return theme
}
