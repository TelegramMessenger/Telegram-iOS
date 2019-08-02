import Foundation
import UIKit
import TelegramUIPreferences

public func makePresentationTheme(themeReference: PresentationThemeReference, accentColor: UIColor?, serviceBackgroundColor: UIColor, baseColor: PresentationThemeBaseColor?, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
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
    }
    return theme
}
