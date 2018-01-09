import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

public enum PresentationTimeFormat {
    case regular
    case military
}

public final class PresentationData: Equatable {
    public let strings: PresentationStrings
    public let theme: PresentationTheme
    public let chatWallpaper: TelegramWallpaper
    public let fontSize: PresentationFontSize
    public let timeFormat: PresentationTimeFormat
    
    public init(strings: PresentationStrings, theme: PresentationTheme, chatWallpaper: TelegramWallpaper, fontSize: PresentationFontSize, timeFormat: PresentationTimeFormat) {
        self.strings = strings
        self.theme = theme
        self.chatWallpaper = chatWallpaper
        self.fontSize = fontSize
        self.timeFormat = timeFormat
    }
    
    public static func ==(lhs: PresentationData, rhs: PresentationData) -> Bool {
        return lhs.strings === rhs.strings && lhs.theme === rhs.theme && lhs.chatWallpaper == rhs.chatWallpaper && lhs.fontSize == rhs.fontSize && lhs.timeFormat == rhs.timeFormat
    }
}

func dictFromLocalization(_ value: Localization) -> [String: String] {
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

private func currentTimeFormat() -> PresentationTimeFormat {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    dateFormatter.dateStyle = .none
    dateFormatter.timeStyle = .medium
    dateFormatter.timeZone = TimeZone.current
    let dateString = dateFormatter.string(from: Date())
    
    if dateString.contains(dateFormatter.amSymbol) || dateString.contains(dateFormatter.pmSymbol) {
        return .regular
    } else {
        return .military
    }
}

public func currentPresentationDataAndSettings(postbox: Postbox) -> Signal<(PresentationData, AutomaticMediaDownloadSettings, LoggingSettings, CallListSettings), NoError> {
    return postbox.modify { modifier -> (PresentationThemeSettings, LocalizationSettings?, AutomaticMediaDownloadSettings, LoggingSettings, CallListSettings) in
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
        
        let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
        if let value = modifier.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings) as? AutomaticMediaDownloadSettings {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
        }
        
        let loggingSettings: LoggingSettings
        if let value = modifier.getPreferencesEntry(key: PreferencesKeys.loggingSettings) as? LoggingSettings {
            loggingSettings = value
        } else {
            loggingSettings = LoggingSettings.defaultSettings
        }
        
        let callListSettings: CallListSettings
        if let value = modifier.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.callListSettings) as? CallListSettings {
            callListSettings = value
        } else {
            callListSettings = CallListSettings.defaultSettings
        }
        
        return (themeSettings, localizationSettings, automaticMediaDownloadSettings, loggingSettings, callListSettings)
    } |> map { (themeSettings, localizationSettings, automaticMediaDownloadSettings, loggingSettings, callListSettings) -> (PresentationData, AutomaticMediaDownloadSettings, LoggingSettings, CallListSettings) in
        let themeValue: PresentationTheme
        switch themeSettings.theme {
            case let .builtin(reference):
                switch reference {
                    case .dayClassic:
                        themeValue = defaultPresentationTheme
                    case .nightGrayscale:
                        themeValue = defaultDarkPresentationTheme
                    case .nightAccent:
                        themeValue = defaultDarkAccentPresentationTheme
                    case .day:
                        themeValue = defaultDayPresentationTheme
                }
        }
        let stringsValue: PresentationStrings
        if let localizationSettings = localizationSettings {
            stringsValue = PresentationStrings(languageCode: localizationSettings.languageCode, dict: dictFromLocalization(localizationSettings.localization))
        } else {
            stringsValue = defaultPresentationStrings
        }
        let timeFormat: PresentationTimeFormat = currentTimeFormat()
        return (PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: themeSettings.chatWallpaper, fontSize: themeSettings.fontSize, timeFormat: timeFormat), automaticMediaDownloadSettings, loggingSettings, callListSettings)
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
                    case .dayClassic:
                        themeValue = defaultPresentationTheme
                    case .nightGrayscale:
                        themeValue = defaultDarkPresentationTheme
                    case .nightAccent:
                        themeValue = defaultDarkAccentPresentationTheme
                    case .day:
                        themeValue = defaultDayPresentationTheme
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
        
        let timeFormat: PresentationTimeFormat = currentTimeFormat()
        
        return PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: themeSettings.chatWallpaper, fontSize: themeSettings.fontSize, timeFormat: timeFormat)
    }
}
