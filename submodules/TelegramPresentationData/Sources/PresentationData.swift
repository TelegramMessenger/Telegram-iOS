import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import AddressBook
import Display
import TelegramUIPreferences

public struct PresentationDateTimeFormat: Equatable {
    public let timeFormat: PresentationTimeFormat
    public let dateFormat: PresentationDateFormat
    public let dateSeparator: String
    public let decimalSeparator: String
    public let groupingSeparator: String
    
    public init(timeFormat: PresentationTimeFormat, dateFormat: PresentationDateFormat, dateSeparator: String, decimalSeparator: String, groupingSeparator: String) {
        self.timeFormat = timeFormat
        self.dateFormat = dateFormat
        self.dateSeparator = dateSeparator
        self.decimalSeparator = decimalSeparator
        self.groupingSeparator = groupingSeparator
    }
}

public struct PresentationVolumeControlStatusBarIcons: Equatable {
    public let offIcon: UIImage
    public let halfIcon: UIImage
    public let fullIcon: UIImage
    
    public var images: (UIImage, UIImage, UIImage) {
        return (self.offIcon, self.halfIcon, self.fullIcon)
    }
}

public struct PresentationAppIcon: Equatable {
    public let name: String
    public let imageName: String
    public let isDefault: Bool
    
    public init(name: String, imageName: String, isDefault: Bool = false) {
        self.name = name
        self.imageName = imageName
        self.isDefault = isDefault
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

extension PresentationStrings: Equatable {
    public static func ==(lhs: PresentationStrings, rhs: PresentationStrings) -> Bool {
        return lhs === rhs
    }
}

public final class PresentationData: Equatable {
    public let strings: PresentationStrings
    public let theme: PresentationTheme
    public let chatWallpaper: TelegramWallpaper
    public let volumeControlStatusBarIcons: PresentationVolumeControlStatusBarIcons
    public let fontSize: PresentationFontSize
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let nameSortOrder: PresentationPersonNameOrder
    public let disableAnimations: Bool
    public let largeEmoji: Bool
    
    public init(strings: PresentationStrings, theme: PresentationTheme, chatWallpaper: TelegramWallpaper, volumeControlStatusBarIcons: PresentationVolumeControlStatusBarIcons, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, nameSortOrder: PresentationPersonNameOrder, disableAnimations: Bool, largeEmoji: Bool) {
        self.strings = strings
        self.theme = theme
        self.chatWallpaper = chatWallpaper
        self.volumeControlStatusBarIcons = volumeControlStatusBarIcons
        self.fontSize = fontSize
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.nameSortOrder = nameSortOrder
        self.disableAnimations = disableAnimations
        self.largeEmoji = largeEmoji
    }
    
    public static func ==(lhs: PresentationData, rhs: PresentationData) -> Bool {
        return lhs.strings === rhs.strings && lhs.theme === rhs.theme && lhs.chatWallpaper == rhs.chatWallpaper && lhs.volumeControlStatusBarIcons == rhs.volumeControlStatusBarIcons && lhs.fontSize == rhs.fontSize && lhs.dateTimeFormat == rhs.dateTimeFormat && lhs.disableAnimations == rhs.disableAnimations && lhs.largeEmoji == rhs.largeEmoji
    }
}

public func dictFromLocalization(_ value: Localization) -> [String: String] {
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
    let bundle = Bundle(for: PresentationTheme.self)
    return PresentationVolumeControlStatusBarIcons(offIcon: UIImage(named: "Components/Volume/VolumeOff", in: bundle, compatibleWith: nil)!, halfIcon: UIImage(named: "Components/Volume/VolumeHalf", in: bundle, compatibleWith: nil)!, fullIcon: UIImage(named: "Components/Volume/VolumeFull", in: bundle, compatibleWith: nil)!)
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
    var dateSeparator = "/"
    if let dateString = DateFormatter.dateFormat(fromTemplate: "MdY", options: 0, locale: locale) {
        for separator in [".", "/", "-", "/"] {
            if dateString.contains(separator) {
                dateSeparator = separator
                break
            }
        }
        if dateString.contains("M\(dateSeparator)d") {
            dateFormat = .monthFirst
        } else {
            dateFormat = .dayFirst
        }
    } else {
        dateFormat = .dayFirst
    }

    let decimalSeparator = locale.decimalSeparator ?? "."
    let groupingSeparator = locale.groupingSeparator ?? ""
    return PresentationDateTimeFormat(timeFormat: timeFormat, dateFormat: dateFormat, dateSeparator: dateSeparator, decimalSeparator: decimalSeparator, groupingSeparator: groupingSeparator)
}

private func currentPersonNameSortOrder() -> PresentationPersonNameOrder {
    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
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
    public let automaticMediaDownloadSettings: MediaAutoDownloadSettings
    public let callListSettings: CallListSettings
    public let inAppNotificationSettings: InAppNotificationSettings
    public let mediaInputSettings: MediaInputSettings
    public let experimentalUISettings: ExperimentalUISettings
    
    public init(presentationData: PresentationData, automaticMediaDownloadSettings: MediaAutoDownloadSettings, callListSettings: CallListSettings, inAppNotificationSettings: InAppNotificationSettings, mediaInputSettings: MediaInputSettings, experimentalUISettings: ExperimentalUISettings) {
        self.presentationData = presentationData
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.callListSettings = callListSettings
        self.inAppNotificationSettings = inAppNotificationSettings
        self.mediaInputSettings = mediaInputSettings
        self.experimentalUISettings = experimentalUISettings
    }
}

public func currentPresentationDataAndSettings(accountManager: AccountManager) -> Signal<InitialPresentationDataAndSettings, NoError> {
    return accountManager.transaction { transaction -> InitialPresentationDataAndSettings in
        let localizationSettings: LocalizationSettings?
        if let current = transaction.getSharedData(SharedDataKeys.localizationSettings) as? LocalizationSettings {
            localizationSettings = current
        } else {
            localizationSettings = nil
        }
        
        let themeSettings: PresentationThemeSettings
        if let current = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        
        let automaticMediaDownloadSettings: MediaAutoDownloadSettings
        if let value = transaction.getSharedData(ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings) as? MediaAutoDownloadSettings {
            automaticMediaDownloadSettings = value
        } else {
            automaticMediaDownloadSettings = MediaAutoDownloadSettings.defaultSettings
        }
        
        let callListSettings: CallListSettings
        if let value = transaction.getSharedData(ApplicationSpecificSharedDataKeys.callListSettings) as? CallListSettings {
            callListSettings = value
        } else {
            callListSettings = CallListSettings.defaultSettings
        }
        
        let inAppNotificationSettings: InAppNotificationSettings
        if let value = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings) as? InAppNotificationSettings {
            inAppNotificationSettings = value
        } else {
            inAppNotificationSettings = InAppNotificationSettings.defaultSettings
        }
        
        let mediaInputSettings: MediaInputSettings
        if let value = transaction.getSharedData(ApplicationSpecificSharedDataKeys.mediaInputSettings) as? MediaInputSettings {
            mediaInputSettings = value
        } else {
            mediaInputSettings = MediaInputSettings.defaultSettings
        }
        
        let experimentalUISettings: ExperimentalUISettings = (transaction.getSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings) as? ExperimentalUISettings) ?? ExperimentalUISettings.defaultSettings
        
        let contactSettings: ContactSynchronizationSettings = (transaction.getSharedData(ApplicationSpecificSharedDataKeys.contactSynchronizationSettings) as? ContactSynchronizationSettings) ?? ContactSynchronizationSettings.defaultSettings
        
        let themeValue: PresentationTheme
        
        let effectiveTheme: PresentationThemeReference
        var effectiveChatWallpaper: TelegramWallpaper = themeSettings.chatWallpaper
        
        let parameters = AutomaticThemeSwitchParameters(settings: themeSettings.automaticThemeSwitchSetting)
        if automaticThemeShouldSwitchNow(parameters, currentTheme: themeSettings.theme) {
            effectiveTheme = themeSettings.automaticThemeSwitchSetting.theme
        } else {
            effectiveTheme = themeSettings.theme
        }
        
        let effectiveAccentColor = themeSettings.themeSpecificAccentColors[effectiveTheme.index]?.color
        themeValue = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: effectiveTheme, accentColor: effectiveAccentColor, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: themeSettings.themeSpecificAccentColors[effectiveTheme.index]?.baseColor ?? .blue)
        
        if effectiveTheme != themeSettings.theme {
            switch effectiveChatWallpaper {
                case .builtin, .color:
                    effectiveChatWallpaper = themeValue.chat.defaultWallpaper
                default:
                    break
            }
        }
        
        let dateTimeFormat = currentDateTimeFormat()
        let stringsValue: PresentationStrings
        if let localizationSettings = localizationSettings {
            stringsValue = PresentationStrings(primaryComponent: PresentationStringsComponent(languageCode: localizationSettings.primaryComponent.languageCode, localizedName: localizationSettings.primaryComponent.localizedName, pluralizationRulesCode: localizationSettings.primaryComponent.customPluralizationCode, dict: dictFromLocalization(localizationSettings.primaryComponent.localization)), secondaryComponent: localizationSettings.secondaryComponent.flatMap({ PresentationStringsComponent(languageCode: $0.languageCode, localizedName: $0.localizedName, pluralizationRulesCode: $0.customPluralizationCode, dict: dictFromLocalization($0.localization)) }), groupingSeparator: dateTimeFormat.groupingSeparator)
        } else {
            stringsValue = defaultPresentationStrings
        }
        let nameDisplayOrder = contactSettings.nameDisplayOrder
        let nameSortOrder = currentPersonNameSortOrder()
        return InitialPresentationDataAndSettings(presentationData: PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: effectiveChatWallpaper, volumeControlStatusBarIcons: volumeControlStatusBarIcons(), fontSize: themeSettings.fontSize, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, nameSortOrder: nameSortOrder, disableAnimations: themeSettings.disableAnimations, largeEmoji: themeSettings.largeEmoji), automaticMediaDownloadSettings: automaticMediaDownloadSettings, callListSettings: callListSettings, inAppNotificationSettings: inAppNotificationSettings, mediaInputSettings: mediaInputSettings, experimentalUISettings: experimentalUISettings)
    }
}

private var first = true

private func roundTimeToDay(_ timestamp: Int32) -> Int32 {
    let calendar = Calendar.current
    let offset = 0
    let components = calendar.dateComponents([.hour, .minute, .second], from: Date(timeIntervalSince1970: Double(timestamp + Int32(offset))))
    return Int32(components.hour! * 60 * 60 + components.minute! * 60 + components.second!)
}

private enum PreparedAutomaticThemeSwitchTrigger {
    case none
    case time(fromSeconds: Int32, toSeconds: Int32)
    case brightness(threshold: Double)
}

private struct AutomaticThemeSwitchParameters {
    let trigger: PreparedAutomaticThemeSwitchTrigger
    let theme: PresentationThemeReference
    
    init(settings: AutomaticThemeSwitchSetting) {
        let trigger: PreparedAutomaticThemeSwitchTrigger
        switch settings.trigger {
            case .none:
                trigger = .none
            case let .timeBased(setting):
                let fromValue: Int32
                let toValue: Int32
                switch setting {
                    case let .automatic(latitude, longitude, _):
                        let calculator = EDSunriseSet(date: Date(), timezone: TimeZone.current, latitude: latitude, longitude: longitude)!
                        fromValue = roundTimeToDay(Int32(calculator.sunset.timeIntervalSince1970))
                        toValue = roundTimeToDay(Int32(calculator.sunrise.timeIntervalSince1970))
                    case let .manual(fromSeconds, toSeconds):
                        fromValue = fromSeconds
                        toValue = toSeconds
                }
                trigger = .time(fromSeconds: fromValue, toSeconds: toValue)
            case let .brightness(threshold):
                trigger = .brightness(threshold: threshold)
        }
        self.trigger = trigger
        self.theme = settings.theme
    }
}

private func automaticThemeShouldSwitchNow(_ parameters: AutomaticThemeSwitchParameters, currentTheme: PresentationThemeReference) -> Bool {
    switch parameters.trigger {
        case .none:
            return false
        case let .time(fromValue, toValue):
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

public func automaticThemeShouldSwitchNow(settings: AutomaticThemeSwitchSetting, currentTheme: PresentationThemeReference) -> Bool {
    let parameters = AutomaticThemeSwitchParameters(settings: settings)
    return automaticThemeShouldSwitchNow(parameters, currentTheme: currentTheme)
}

private func automaticThemeShouldSwitch(_ settings: AutomaticThemeSwitchSetting, currentTheme: PresentationThemeReference) -> Signal<Bool, NoError> {
    if case .none = settings.trigger {
        return .single(false)
    } else {
        return Signal { subscriber in
            let parameters = AutomaticThemeSwitchParameters(settings: settings)
            subscriber.putNext(automaticThemeShouldSwitchNow(parameters, currentTheme: currentTheme))
            
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: {
                subscriber.putNext(automaticThemeShouldSwitchNow(parameters, currentTheme: currentTheme))
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

private func serviceColor(for data: Signal<MediaResourceData, NoError>) -> Signal<UIColor, NoError> {
    return data
    |> mapToSignal { data -> Signal<UIColor, NoError> in
        if data.complete, let image = UIImage(contentsOfFile: data.path) {
            return serviceColor(from: .single(image))
        }
        return .complete()
    }
}

public func serviceColor(from image: Signal<UIImage?, NoError>) -> Signal<UIColor, NoError> {
    return image
    |> mapToSignal { image -> Signal<UIColor, NoError> in
        if let image = image {
            let context = DrawingContext(size: CGSize(width: 1.0, height: 1.0), scale: 1.0, clear: false)
            context.withFlippedContext({ context in
                if let cgImage = image.cgImage {
                    context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
                }
            })
            return .single(serviceColor(with: context.colorAt(CGPoint())))
        }
        return .complete()
    }
}

public func serviceColor(with color: UIColor) -> UIColor {
    var hue:  CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
        if saturation > 0.0 {
            saturation = min(1.0, saturation + 0.05 + 0.1 * (1.0 - saturation))
        }
        brightness = max(0.0, brightness * 0.65)
        alpha = 0.4
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    return color
}

private var serviceBackgroundColorForWallpaper: (TelegramWallpaper, UIColor)?

public func chatServiceBackgroundColor(wallpaper: TelegramWallpaper, mediaBox: MediaBox) -> Signal<UIColor, NoError> {
    if wallpaper == serviceBackgroundColorForWallpaper?.0, let color = serviceBackgroundColorForWallpaper?.1 {
        return .single(color)
    } else {
        switch wallpaper {
        case .builtin:
            return .single(UIColor(rgb: 0x748391, alpha: 0.45))
        case let .color(color):
            return .single(serviceColor(with: UIColor(rgb: UInt32(bitPattern: color))))
        case let .image(representations, _):
            if let largest = largestImageRepresentation(representations) {
                return Signal<UIColor, NoError> { subscriber in
                    let fetch = mediaBox.fetchedResource(largest.resource, parameters: nil).start()
                    let data = serviceColor(for: mediaBox.resourceData(largest.resource)).start(next: { next in
                        subscriber.putNext(next)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    return ActionDisposable {
                        fetch.dispose()
                        data.dispose()
                    }
                }
                |> afterNext { color in
                    serviceBackgroundColorForWallpaper = (wallpaper, color)
                }
            } else {
                return .single(UIColor(rgb: 0x000000, alpha: 0.3))
            }
        case let .file(file):
            if file.isPattern {
                if let color = file.settings.color {
                    return .single(serviceColor(with: UIColor(rgb: UInt32(bitPattern: color))))
                } else {
                    return .single(UIColor(rgb: 0x000000, alpha: 0.3))
                }
            } else {
                return Signal<UIColor, NoError> { subscriber in
                    let data = serviceColor(for: mediaBox.resourceData(file.file.resource)).start(next: { next in
                        subscriber.putNext(next)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    return ActionDisposable {
                        data.dispose()
                    }
                }
                |> afterNext { color in
                    serviceBackgroundColorForWallpaper = (wallpaper, color)
                }
            }
        }
    }
}

public func updatedPresentationData(accountManager: AccountManager, applicationInForeground: Signal<Bool, NoError>) -> Signal<PresentationData, NoError> {
    return accountManager.sharedData(keys: [SharedDataKeys.localizationSettings, ApplicationSpecificSharedDataKeys.presentationThemeSettings, ApplicationSpecificSharedDataKeys.contactSynchronizationSettings])
    |> mapToSignal { sharedData -> Signal<PresentationData, NoError> in
        let themeSettings: PresentationThemeSettings
        if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings {
            themeSettings = current
        } else {
            themeSettings = PresentationThemeSettings.defaultSettings
        }
        
        let contactSettings: ContactSynchronizationSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings] as? ContactSynchronizationSettings ?? ContactSynchronizationSettings.defaultSettings
        
        let currentWallpaper: TelegramWallpaper
        if let themeSpecificWallpaper = themeSettings.themeSpecificChatWallpapers[themeSettings.theme.index] {
            currentWallpaper = themeSpecificWallpaper
        } else {
            currentWallpaper = themeSettings.chatWallpaper
        }
        
        return (.single(UIColor(rgb: 0x000000, alpha: 0.3))
        |> then(chatServiceBackgroundColor(wallpaper: currentWallpaper, mediaBox: accountManager.mediaBox)))
        |> mapToSignal { serviceBackgroundColor in
            return applicationInForeground
            |> mapToSignal { inForeground -> Signal<PresentationData, NoError> in
                if inForeground {
                    return automaticThemeShouldSwitch(themeSettings.automaticThemeSwitchSetting, currentTheme: themeSettings.theme)
                    |> distinctUntilChanged
                    |> map { shouldSwitch in
                        var effectiveTheme: PresentationThemeReference
                        var effectiveChatWallpaper: TelegramWallpaper = currentWallpaper
                        
                        if shouldSwitch {
                            let automaticTheme = themeSettings.automaticThemeSwitchSetting.theme
                            if let themeSpecificWallpaper = themeSettings.themeSpecificChatWallpapers[automaticTheme.index] {
                                effectiveChatWallpaper = themeSpecificWallpaper
                            }
                            effectiveTheme = automaticTheme
                        } else {
                            effectiveTheme = themeSettings.theme
                        }
                        
                        let effectiveAccentColor = themeSettings.themeSpecificAccentColors[effectiveTheme.index]?.color
                        let themeValue = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: effectiveTheme, accentColor: effectiveAccentColor, serviceBackgroundColor: serviceBackgroundColor, baseColor: themeSettings.themeSpecificAccentColors[effectiveTheme.index]?.baseColor ?? .blue)
                        
                        if effectiveTheme != themeSettings.theme && themeSettings.themeSpecificChatWallpapers[effectiveTheme.index] == nil {
                            switch effectiveChatWallpaper {
                                case .builtin, .color:
                                    effectiveChatWallpaper = themeValue.chat.defaultWallpaper
                                default:
                                    break
                            }
                        }
                        
                        let localizationSettings: LocalizationSettings?
                        if let current = sharedData.entries[SharedDataKeys.localizationSettings] as? LocalizationSettings {
                            localizationSettings = current
                        } else {
                            localizationSettings = nil
                        }
                        
                        let dateTimeFormat = currentDateTimeFormat()
                        let stringsValue: PresentationStrings
                        if let localizationSettings = localizationSettings {
                            stringsValue = PresentationStrings(primaryComponent: PresentationStringsComponent(languageCode: localizationSettings.primaryComponent.languageCode, localizedName: localizationSettings.primaryComponent.localizedName, pluralizationRulesCode: localizationSettings.primaryComponent.customPluralizationCode, dict: dictFromLocalization(localizationSettings.primaryComponent.localization)), secondaryComponent: localizationSettings.secondaryComponent.flatMap({ PresentationStringsComponent(languageCode: $0.languageCode, localizedName: $0.localizedName, pluralizationRulesCode: $0.customPluralizationCode, dict: dictFromLocalization($0.localization)) }), groupingSeparator: dateTimeFormat.groupingSeparator)
                        } else {
                            stringsValue = defaultPresentationStrings
                        }
                        let nameDisplayOrder = contactSettings.nameDisplayOrder
                        let nameSortOrder = currentPersonNameSortOrder()
                        
                        return PresentationData(strings: stringsValue, theme: themeValue, chatWallpaper: effectiveChatWallpaper, volumeControlStatusBarIcons: volumeControlStatusBarIcons(), fontSize: themeSettings.fontSize, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, nameSortOrder: nameSortOrder, disableAnimations: themeSettings.disableAnimations, largeEmoji: themeSettings.largeEmoji)
                    }
                } else {
                    return .complete()
                }
            }
        }
    }
}

public func defaultPresentationData() -> PresentationData {
    let dateTimeFormat = currentDateTimeFormat()
    let nameDisplayOrder: PresentationPersonNameOrder = .firstLast
    let nameSortOrder = currentPersonNameSortOrder()
    
    let themeSettings = PresentationThemeSettings.defaultSettings
    return PresentationData(strings: defaultPresentationStrings, theme: defaultPresentationTheme, chatWallpaper: .builtin(WallpaperSettings()), volumeControlStatusBarIcons: volumeControlStatusBarIcons(), fontSize: themeSettings.fontSize, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, nameSortOrder: nameSortOrder, disableAnimations: themeSettings.disableAnimations, largeEmoji: themeSettings.largeEmoji)
}
