import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import AddressBook

public struct PresentationDateTimeFormat: Equatable {
    let timeFormat: PresentationTimeFormat
    let dateFormat: PresentationDateFormat
    let dateSeparator: String
}

public struct PresentationVolumeControlStatusBarIcons: Equatable {
    let offIcon: UIImage
    let halfIcon: UIImage
    let fullIcon: UIImage
    
    public var images: (UIImage, UIImage, UIImage) {
        return (self.offIcon, self.halfIcon, self.fullIcon)
    }
}

public enum PresentationTimeFormat {
    case regular
    case military
}

public enum PresentationDateFormat {
    case monthFirst
    case dayFirst
}

public enum PresentationPersonNameOrder: Int32 {
    case firstLast = 0
    case lastFirst = 1
}

extension PresentationStrings : Equatable {
    public static func ==(lhs: PresentationStrings, rhs: PresentationStrings) -> Bool {
        return lhs === rhs
    }
}

public final class PresentationData: Equatable {
    public let strings: PresentationStrings
    public let theme: PresentationTheme
    public let chatWallpaper: TelegramWallpaper
    public let chatWallpaperOptions: WallpaperPresentationOptions
    public let volumeControlStatusBarIcons: PresentationVolumeControlStatusBarIcons
    public let fontSize: PresentationFontSize
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let nameSortOrder: PresentationPersonNameOrder
    public let disableAnimations: Bool
    
    public init(strings: PresentationStrings, theme: PresentationTheme, chatWallpaper: TelegramWallpaper, chatWallpaperOptions: WallpaperPresentationOptions, volumeControlStatusBarIcons: PresentationVolumeControlStatusBarIcons, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, nameSortOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.strings = strings
        self.theme = theme
        self.chatWallpaper = chatWallpaper
        self.chatWallpaperOptions = chatWallpaperOptions
        self.volumeControlStatusBarIcons = volumeControlStatusBarIcons
        self.fontSize = fontSize
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.nameSortOrder = nameSortOrder
        self.disableAnimations = disableAnimations
    }
    
    public static func ==(lhs: PresentationData, rhs: PresentationData) -> Bool {
        return lhs.strings === rhs.strings && lhs.theme === rhs.theme && lhs.chatWallpaper == rhs.chatWallpaper && lhs.chatWallpaperOptions == rhs.chatWallpaperOptions && lhs.volumeControlStatusBarIcons == rhs.volumeControlStatusBarIcons && lhs.fontSize == rhs.fontSize && lhs.dateTimeFormat == rhs.dateTimeFormat && lhs.disableAnimations == rhs.disableAnimations
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

private func volumeControlStatusBarIcons() -> PresentationVolumeControlStatusBarIcons {
    return PresentationVolumeControlStatusBarIcons(offIcon: UIImage(bundleImageName: "Components/Volume/VolumeOff")!, halfIcon: UIImage(bundleImageName: "Components/Volume/VolumeHalf")!, fullIcon: UIImage(bundleImageName: "Components/Volume/VolumeFull")!)
}

private func currentDateTimeFormat() -> PresentationDateTimeFormat {
    let locale = Locale.current
    let dateFormatter = DateFormatter()
    dateFormatter.locale = locale
    dateFormatter.dateStyle = .none
    dateFormatter.timeStyle = .medium
    dateFormatter.timeZone = TimeZone.current
    let dateString = dateFormatter.string(from: Date())
    
    let timeFormat: PresentationTimeFormat
    if dateString.contains(dateFormatter.amSymbol) || dateString.contains(dateFormatter.pmSymbol) {
        timeFormat = .regular
    } else {
        timeFormat = .military
    }
    
    let dateFormat: PresentationDateFormat
    let dateSeparator: String
    if let dateString = DateFormatter.dateFormat(fromTemplate: "MdY", options: 0, locale: locale) {
        if dateString.contains(".") {
            dateSeparator = "."
        } else if dateString.contains("/") {
            dateSeparator = "/"
        } else if dateString.contains("-") {
            dateSeparator = "-"
        } else {
            dateSeparator = "/"
        }
        
        if dateString.contains("M\(dateSeparator)d") {
            dateFormat = .monthFirst
        } else {
            dateFormat = .dayFirst
        }
    } else {
        dateSeparator = "/"
        dateFormat = .dayFirst
    }
    
    return PresentationDateTimeFormat(timeFormat: timeFormat, dateFormat: dateFormat, dateSeparator: dateSeparator)
}

private func currentPersonNameSortOrder() -> PresentationPersonNameOrder {
    if #available(iOSApplicationExtension 9.0, *) {
        switch CNContactsUserDefaults.shared().sortOrder {
            case .givenName:
                return .firstLast
            default:
                return .lastFirst
        }
    } else {
        if ABPersonGetSortOrdering() == kABPersonSortByFirstName {
            return .firstLast
        } else {
            return .lastFirst
        }
    }
}

public final class InitialPresentationDataAndSettings {
    public let presentationData: PresentationData
    public let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    public let limitsConfiguration: LimitsConfiguration
    public let callListSettings: CallListSettings
    public let inAppNotificationSettings: InAppNotificationSettings
    public let mediaInputSettings: MediaInputSettings
    public let experimentalUISettings: ExperimentalUISettings
    
    init(presentationData: PresentationData, automaticMediaDownloadSettings: AutomaticMediaDownloadSettings, limitsConfiguration: LimitsConfiguration, callListSettings: CallListSettings, inAppNotificationSettings: InAppNotificationSettings, mediaInputSettings: MediaInputSettings, experimentalUISettings: ExperimentalUISettings) {
        self.presentationData = presentationData
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.limitsConfiguration = limitsConfiguration
        self.callListSettings = callListSettings
        self.inAppNotificationSettings = inAppNotificationSettings
        self.mediaInputSettings = mediaInputSettings
        self.experimentalUISettings = experimentalUISettings
    }
}

public func currentPresentationDataAndSettings(postbox: Postbox) -> Signal<InitialPresentationDataAndSettings, NoError> {
    return postbox.transaction { transaction -> (PresentationThemeSettings, LocalizationSettings?, AutomaticMediaDownloadSettings, LimitsConfiguration, CallListSettings, InAppNotificationSettings, MediaInputSettings, ExperimentalUISettings, ContactSynchronizationSettings) in
        let themeSettings: PresentationThemeSettings
        if let current = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.presentationThemeSettings) as? PresentationThemeSettings {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        
        let localizationSettings: LocalizationSettings?
        if let current = transaction.getPreferencesEntry(key: PreferencesKeys.localizationSettings) as? LocalizationSettings {
            localizationSettings = current
        } else {
            localizationSettings = nil
        }
        
        let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
        if let value = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings) as? AutomaticMediaDownloadSettings {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
        }
        
        let limitsConfiguration: LimitsConfiguration
        if let value = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration {
            limitsConfiguration = value
        } else {
            limitsConfiguration = LimitsConfiguration.defaultValue
        }
        
        let callListSettings: CallListSettings
        if let value = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.callListSettings) as? CallListSettings {
            callListSettings = value
        } else {
            callListSettings = CallListSettings.defaultSettings
        }
        
        let inAppNotificationSettings: InAppNotificationSettings
        if let value = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings) as? InAppNotificationSettings {
            inAppNotificationSettings = value
        } else {
            inAppNotificationSettings = InAppNotificationSettings.defaultSettings
        }
        
        let mediaInputSettings: MediaInputSettings
        if let value = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.mediaInputSettings) as? MediaInputSettings {
            mediaInputSettings = value
        } else {
            mediaInputSettings = MediaInputSettings.defaultSettings
        }
        
        let experimentalUISettings: ExperimentalUISettings = (transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.experimentalUISettings) as? ExperimentalUISettings) ?? ExperimentalUISettings.defaultSettings
        
        let contactSettings: ContactSynchronizationSettings = (transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.contactSynchronizationSettings) as? ContactSynchronizationSettings) ?? ContactSynchronizationSettings.defaultSettings
        
        return (themeSettings, localizationSettings, automaticMediaDownloadSettings, limitsConfiguration, callListSettings, inAppNotificationSettings, mediaInputSettings, experimentalUISettings, contactSettings)
    }
    |> map { (themeSettings, localizationSettings, automaticMediaDownloadSettings, limitsConfiguration, callListSettings, inAppNotificationSettings, mediaInputSettings, experimentalUISettings, contactSettings) -> InitialPresentationDataAndSettings in
        let themeValue: PresentationTheme
        
        let effectiveTheme: PresentationThemeReference
        var effectiveChatWallpaper: TelegramWallpaper = themeSettings.chatWallpaper
        var effectiveChatWallpaperOptions: WallpaperPresentationOptions = themeSettings.chatWallpaperOptions
        
        if automaticThemeShouldSwitchNow(themeSettings.automaticThemeSwitchSetting, currentTheme: themeSettings.theme) {
            effectiveTheme = .builtin(themeSettings.automaticThemeSwitchSetting.theme)
            switch effectiveChatWallpaper {
                case .builtin, .color:
                    switch themeSettings.automaticThemeSwitchSetting.theme {
                        case .nightAccent:
                            effectiveChatWallpaper = .color(0x18222d)
                            effectiveChatWallpaperOptions = []
                        case .nightGrayscale:
                            effectiveChatWallpaper = .color(0x000000)
                            effectiveChatWallpaperOptions = []
                        default:
                            break
                    }
                default:
                    break
            }
        } else {
            effectiveTheme = themeSettings.theme
        }
        
        switch effectiveTheme {
            case let .builtin(reference):
                switch reference {
                    case .dayClassic:
                        themeValue = defaultPresentationTheme
                    case .nightGrayscale:
                        themeValue = defaultDarkPresentationTheme
                    case .nightAccent:
                        themeValue = defaultDarkAccentPresentationTheme
                    case .day:
                        themeValue = makeDefaultDayPresentationTheme(accentColor: themeSettings.themeAccentColor ?? defaultDayAccentColor)
                }
        }
        let stringsValue: PresentationStrings
        if let localizationSettings = localizationSettings {
            stringsValue = PresentationStrings(primaryComponent: PresentationStringsComponent(languageCode: localizationSettings.primaryComponent.languageCode, localizedName: localizationSettings.primaryComponent.localizedName, pluralizationRulesCode: localizationSettings.primaryComponent.customPluralizationCode, dict: dictFromLocalization(localizationSettings.primaryComponent.localization)), secondaryComponent: localizationSettings.secondaryComponent.flatMap({ PresentationStringsComponent(languageCode: $0.languageCode, localizedName: $0.localizedName, pluralizationRulesCode: $0.customPluralizationCode, dict: dictFromLocalization($0.localization)) }))
        } else {
            stringsValue = defaultPresentationStrings
        }
        let dateTimeFormat = currentDateTimeFormat()
        let nameDisplayOrder = contactSettings.nameDisplayOrder
        let nameSortOrder = currentPersonNameSortOrder()
        return InitialPresentationDataAndSettings(presentationData: PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: effectiveChatWallpaper, chatWallpaperOptions: effectiveChatWallpaperOptions, volumeControlStatusBarIcons: volumeControlStatusBarIcons(), fontSize: themeSettings.fontSize, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, nameSortOrder: nameSortOrder, disableAnimations: themeSettings.disableAnimations), automaticMediaDownloadSettings: automaticMediaDownloadSettings, limitsConfiguration: limitsConfiguration, callListSettings: callListSettings, inAppNotificationSettings: inAppNotificationSettings, mediaInputSettings: mediaInputSettings, experimentalUISettings: experimentalUISettings)
    }
}

private var first = true

private func roundTimeToDay(_ timestamp: Int32) -> Int32 {
    let calendar = Calendar.current
    let offset = 0
    let components = calendar.dateComponents([.hour, .minute, .second], from: Date(timeIntervalSince1970: Double(timestamp + Int32(offset))))
    return Int32(components.hour! * 60 * 60 + components.minute! * 60 + components.second!)
}

private func automaticThemeShouldSwitchNow(_ settings: AutomaticThemeSwitchSetting, currentTheme: PresentationThemeReference) -> Bool {
    switch currentTheme {
        case let .builtin(builtin):
            switch builtin {
                case .nightAccent, .nightGrayscale:
                    return false
                default:
                    break
            }
    }
    switch settings.trigger {
        case .none:
            return false
        case let .timeBased(setting):
            let fromValue: Int32
            let toValue: Int32
            switch setting {
                case let .automatic(automatic):
                    fromValue = automatic.sunset
                    toValue = automatic.sunrise
                case let .manual(fromSeconds, toSeconds):
                    fromValue = fromSeconds
                    toValue = toSeconds
            }
            let roundedTimestamp = roundTimeToDay(Int32(Date().timeIntervalSince1970))
            if roundedTimestamp >= fromValue || roundedTimestamp <= toValue {
                return true
            } else {
                return false
            }
        case let .brightness(threshold):
            return UIScreen.main.brightness <= CGFloat(threshold)
    }
}

private func automaticThemeShouldSwitch(_ settings: AutomaticThemeSwitchSetting, currentTheme: PresentationThemeReference) -> Signal<Bool, NoError> {
    if case .none = settings.trigger {
        return .single(false)
    } else {
        return Signal { subscriber in
            subscriber.putNext(automaticThemeShouldSwitchNow(settings, currentTheme: currentTheme))
            
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: {
                subscriber.putNext(automaticThemeShouldSwitchNow(settings, currentTheme: currentTheme))
            }, queue: Queue.mainQueue())
            timer.start()
            
            return ActionDisposable {
                timer.invalidate()
            }
        }
        |> runOn(Queue.mainQueue())
        |> distinctUntilChanged
    }
}

public func updatedPresentationData(postbox: Postbox, applicationBindings: TelegramApplicationBindings) -> Signal<PresentationData, NoError> {
    let preferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.presentationThemeSettings, PreferencesKeys.localizationSettings, ApplicationSpecificPreferencesKeys.contactSynchronizationSettings]))
    return postbox.combinedView(keys: [preferencesKey])
    |> mapToSignal { view -> Signal<PresentationData, NoError> in
        let themeSettings: PresentationThemeSettings
        if let current = (view.views[preferencesKey] as! PreferencesView).values[ApplicationSpecificPreferencesKeys.presentationThemeSettings] as? PresentationThemeSettings {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        
        let contactSettings: ContactSynchronizationSettings = (view.views[preferencesKey] as! PreferencesView).values[ApplicationSpecificPreferencesKeys.contactSynchronizationSettings] as? ContactSynchronizationSettings ?? ContactSynchronizationSettings.defaultSettings
        
        let themeSpecificSettings = postbox.transaction { transaction -> PresentationThemeSpecificSettings? in
            let key = ValueBoxKey(length: 8)
            key.setInt64(0, value: themeSettings.theme.index)
            if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.themeSpecificSettings, key: key)) as? PresentationThemeSpecificSettings {
                return entry
            } else {
                return nil
            }
        }
        
        return themeSpecificSettings
        |> mapToSignal { themeSpecificSettings in
            let currentWallpaper: TelegramWallpaper
            if let themeSpecificSettings = themeSpecificSettings {
                currentWallpaper = themeSpecificSettings.chatWallpaper
            } else {
                currentWallpaper = themeSettings.chatWallpaper
            }
            
            return (.single(UIColor(rgb: 0x000000, alpha: 0.3))
            |> then(chatServiceBackgroundColor(wallpaper: currentWallpaper, postbox: postbox)))
            |> mapToSignal { serviceBackgroundColor in
                return applicationBindings.applicationInForeground
                |> mapToSignal({ inForeground  -> Signal<PresentationData, NoError> in
                    if inForeground {
                        return automaticThemeShouldSwitch(themeSettings.automaticThemeSwitchSetting, currentTheme: themeSettings.theme)
                        |> distinctUntilChanged
                        |> map { shouldSwitch in
                            let themeValue: PresentationTheme
                            let effectiveTheme: PresentationThemeReference
                            var effectiveChatWallpaper: TelegramWallpaper = currentWallpaper
                            var effectiveChatWallpaperOptions: WallpaperPresentationOptions = themeSettings.chatWallpaperOptions
                            
                            if shouldSwitch {
                                effectiveTheme = .builtin(themeSettings.automaticThemeSwitchSetting.theme)
                                switch effectiveChatWallpaper {
                                    case .builtin, .color:
                                        switch themeSettings.automaticThemeSwitchSetting.theme {
                                            case .nightAccent:
                                                effectiveChatWallpaper = .color(0x18222d)
                                                effectiveChatWallpaperOptions = []
                                            case .nightGrayscale:
                                                effectiveChatWallpaper = .color(0x000000)
                                                effectiveChatWallpaperOptions = []
                                            default:
                                                break
                                        }
                                    default:
                                        break
                                }
                            } else {
                                effectiveTheme = themeSettings.theme
                            }
                            switch effectiveTheme {
                                case let .builtin(reference):
                                    switch reference {
                                        case .dayClassic:
                                            themeValue = makeDefaultPresentationTheme(serviceBackgroundColor: serviceBackgroundColor)
                                        case .nightGrayscale:
                                            themeValue = defaultDarkPresentationTheme
                                        case .nightAccent:
                                            themeValue = defaultDarkAccentPresentationTheme
                                        case .day:
                                            themeValue = makeDefaultDayPresentationTheme(accentColor: themeSettings.themeAccentColor ?? defaultDayAccentColor)
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
                                stringsValue = PresentationStrings(primaryComponent: PresentationStringsComponent(languageCode: localizationSettings.primaryComponent.languageCode, localizedName: localizationSettings.primaryComponent.localizedName, pluralizationRulesCode: localizationSettings.primaryComponent.customPluralizationCode, dict: dictFromLocalization(localizationSettings.primaryComponent.localization)), secondaryComponent: localizationSettings.secondaryComponent.flatMap({ PresentationStringsComponent(languageCode: $0.languageCode, localizedName: $0.localizedName, pluralizationRulesCode: $0.customPluralizationCode, dict: dictFromLocalization($0.localization)) }))
                            } else {
                                stringsValue = defaultPresentationStrings
                            }
                            
                            let dateTimeFormat = currentDateTimeFormat()
                            let nameDisplayOrder = contactSettings.nameDisplayOrder
                            let nameSortOrder = currentPersonNameSortOrder()

                            return PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: effectiveChatWallpaper, chatWallpaperOptions: effectiveChatWallpaperOptions, volumeControlStatusBarIcons: volumeControlStatusBarIcons(), fontSize: themeSettings.fontSize, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, nameSortOrder: nameSortOrder, disableAnimations: themeSettings.disableAnimations)
                        }
                    } else {
                        return .complete()
                    }
                })
            }
        }
    }
}

public func defaultPresentationData() -> PresentationData {
    let dateTimeFormat = currentDateTimeFormat()
    let nameDisplayOrder: PresentationPersonNameOrder = .firstLast
    let nameSortOrder = currentPersonNameSortOrder()
    
    let themeSettings = PresentationThemeSettings.defaultSettings
    return PresentationData(strings: defaultPresentationStrings, theme: defaultPresentationTheme, chatWallpaper: .builtin, chatWallpaperOptions: [], volumeControlStatusBarIcons: volumeControlStatusBarIcons(), fontSize: themeSettings.fontSize, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, nameSortOrder: nameSortOrder, disableAnimations: themeSettings.disableAnimations)
}
