import Foundation
import UIKit
import TelegramUIPreferences

public func makePresentationTheme(themeReference: PresentationThemeReference, accentColor: UIColor?, serviceBackgroundColor: UIColor, preview: Bool = false) -> PresentationTheme {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            switch reference {
                case .dayClassic:
                    theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: serviceBackgroundColor, day: false, preview: preview)
                case .night:
                    theme = makeDarkPresentationTheme(accentColor: accentColor, preview: preview)
                case .nightAccent:
                    theme = makeDarkAccentPresentationTheme(accentColor: accentColor, preview: preview)
                case .day:
                    theme = makeDefaultDayPresentationTheme(accentColor: accentColor, serviceBackgroundColor: serviceBackgroundColor, day: true, preview: preview)
            }
    }
    return theme
}
