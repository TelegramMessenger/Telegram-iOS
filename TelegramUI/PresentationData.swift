import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

public final class PresentationData: Equatable {
    public let strings: PresentationStrings
    public let theme: PresentationTheme
    public let chatWallpaper: TelegramWallpaper
    
    public init(strings: PresentationStrings, theme: PresentationTheme, chatWallpaper: TelegramWallpaper) {
        self.strings = strings
        self.theme = theme
        self.chatWallpaper = chatWallpaper
    }
    
    public static func ==(lhs: PresentationData, rhs: PresentationData) -> Bool {
        return lhs.strings === rhs.strings && lhs.theme == rhs.theme && lhs.chatWallpaper == rhs.chatWallpaper
    }
}

private func dictFromLocalization(_ value: Localization) -> [String: String] {
    var dict: [String: String] = [:]
    for entry in value.entries {
        switch entry {
            case let .string(key, value):
                dict[key] = value
            case let .pluralizedString(key, zero, one, two, few, many, other):
                if let zero = zero {
                    dict["\(key)_zero"] = zero
                }
                if let one = one {
                    dict["\(key)_1"] = one
                }
                if let two = two {
                    dict["\(key)_2"] = two
                }
                if let few = few {
                    dict["\(key)_3_10"] = few
                }
                if let many = many {
                    dict["\(key)_many"] = many
                }
                dict["\(key)_any"] = other
        }
    }
    return dict
}

public func currentPresentationData(postbox: Postbox) -> Signal<PresentationData, NoError> {
    return postbox.modify { modifier -> (PresentationThemeSettings, LocalizationSettings?) in
        let themeSettings: PresentationThemeSettings
        if let current = modifier.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.presentationThemeSettings) as? PresentationThemeSettings {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        
        let localizationSettings: LocalizationSettings?
        if let current = modifier.getPreferencesEntry(key: PreferencesKeys.localizationSettings) as? LocalizationSettings {
            localizationSettings = current
        } else {
            localizationSettings = nil
        }
        
        return (themeSettings, localizationSettings)
    } |> map { (themeSettings, localizationSettings) -> PresentationData in
        let themeValue: PresentationTheme
        switch themeSettings.theme {
            case let .builtin(reference):
                switch reference {
                    case .light:
                        themeValue = defaultPresentationTheme
                    case .dark:
                        themeValue = defaultDarkPresentationTheme
                }
        }
        let stringsValue: PresentationStrings
        if let localizationSettings = localizationSettings {
            stringsValue = PresentationStrings(languageCode: localizationSettings.languageCode, dict: dictFromLocalization(localizationSettings.localization))
        } else {
            stringsValue = defaultPresentationStrings
        }
        return PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: themeSettings.chatWallpaper)
    }
}

private var first = true

public func updatedPresentationData(postbox: Postbox) -> Signal<PresentationData, NoError> {
    let preferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.presentationThemeSettings, PreferencesKeys.localizationSettings]))
    return postbox.combinedView(keys: [preferencesKey])
    |> map { view -> PresentationData in
        let themeSettings: PresentationThemeSettings
        if let current = (view.views[preferencesKey] as! PreferencesView).values[ApplicationSpecificPreferencesKeys.presentationThemeSettings] as? PresentationThemeSettings {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        let themeValue: PresentationTheme
        switch themeSettings.theme {
            case let .builtin(reference):
                switch reference {
                    case .light:
                        themeValue = defaultPresentationTheme
                    case .dark:
                        themeValue = defaultDarkPresentationTheme
                }
        }
        
        let localizationSettings: LocalizationSettings?
        if let current = (view.views[preferencesKey] as! PreferencesView).values[PreferencesKeys.localizationSettings] as? LocalizationSettings {
            localizationSettings = current
        } else {
            localizationSettings = nil
        }
        
        let stringsValue: PresentationStrings
        if let localizationSettings = localizationSettings {
            stringsValue = PresentationStrings(languageCode: localizationSettings.languageCode, dict: dictFromLocalization(localizationSettings.localization))
        } else {
            stringsValue = defaultPresentationStrings
        }
        
        return PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: themeSettings.chatWallpaper)
    }
}
