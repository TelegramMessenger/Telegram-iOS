import Foundation

public extension Locale {
    static var currentAppLocale: Locale {
        let appLocale: Locale
        if let appLocaleIdentifier = Locale.preferredLanguages.first  {
            appLocale = Locale(identifier: appLocaleIdentifier)
        } else {
            appLocale = Locale.current
        }
        return appLocale
    }
}
