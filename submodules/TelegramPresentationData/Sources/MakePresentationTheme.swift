import Foundation
import UIKit
import TelegramUIPreferences

public func makePresentationTheme(themeReference: PresentationThemeReference, accentColor: UIColor, serviceBackgroundColor: UIColor) -> PresentationTheme {
    let theme: PresentationTheme
    switch themeReference {
        case let .builtin(reference):
            switch reference {
                case .dayClassic:
                    theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: serviceBackgroundColor)
                case .night:
                    theme = makeDarkPresentationTheme(accentColor: accentColor)
                case .nightAccent:
                    theme = makeDarkAccentPresentationTheme(accentColor: accentColor)
                case .day:
                    theme = makeDefaultDayPresentationTheme(accentColor: accentColor, serviceBackgroundColor: serviceBackgroundColor)
            }
    }
    return theme
}
