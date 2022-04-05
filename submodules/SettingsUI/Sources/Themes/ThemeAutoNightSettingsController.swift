import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting
import AccountContext
import DeviceLocationManager
import Geocoding
import WallpaperResources
import Sunrise

private enum TriggerMode {
    case system
    case none
    case timeBased
    case brightness
}

private enum TimeBasedManualField {
    case from
    case to
}

private final class ThemeAutoNightSettingsControllerArguments {
    let context: AccountContext
    let updateMode: (TriggerMode) -> Void
    let updateTimeBasedAutomatic: (Bool) -> Void
    let openTimeBasedManual: (TimeBasedManualField) -> Void
    let updateTimeBasedAutomaticLocation: () -> Void
    let updateAutomaticBrightness: (Double) -> Void
    let updateTheme: (PresentationThemeReference) -> Void
    
    init(context: AccountContext, updateMode: @escaping (TriggerMode) -> Void, updateTimeBasedAutomatic: @escaping (Bool) -> Void, openTimeBasedManual: @escaping (TimeBasedManualField) -> Void, updateTimeBasedAutomaticLocation: @escaping () -> Void, updateAutomaticBrightness: @escaping (Double) -> Void, updateTheme: @escaping (PresentationThemeReference) -> Void) {
        self.context = context
        self.updateMode = updateMode
        self.updateTimeBasedAutomatic = updateTimeBasedAutomatic
        self.openTimeBasedManual = openTimeBasedManual
        self.updateTimeBasedAutomaticLocation = updateTimeBasedAutomaticLocation
        self.updateAutomaticBrightness = updateAutomaticBrightness
        self.updateTheme = updateTheme
    }
}

private enum ThemeAutoNightSettingsControllerSection: Int32 {
    case mode
    case settings
    case theme
}

private enum ThemeAutoNightSettingsControllerEntry: ItemListNodeEntry {
    case modeSystem(PresentationTheme, String, Bool)
    case modeDisabled(PresentationTheme, String, Bool)
    case modeTimeBased(PresentationTheme, String, Bool)
    case modeBrightness(PresentationTheme, String, Bool)
    
    case settingsHeader(PresentationTheme, String)
    case timeBasedAutomaticLocation(PresentationTheme, String, Bool)
    case timeBasedAutomaticLocationValue(PresentationTheme, String, String)
    case timeBasedManualFrom(PresentationTheme, String, String)
    case timeBasedManualTo(PresentationTheme, String, String)
    case brightnessValue(PresentationTheme, Double)
    case settingInfo(PresentationTheme, String)
    
    case themeHeader(PresentationTheme, String)
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], [Int64: TelegramWallpaper])
    
    var section: ItemListSectionId {
        switch self {
        case .modeSystem, .modeDisabled, .modeTimeBased, .modeBrightness:
            return ThemeAutoNightSettingsControllerSection.mode.rawValue
        case .settingsHeader, .timeBasedAutomaticLocation, .timeBasedAutomaticLocationValue, .timeBasedManualFrom, .timeBasedManualTo, .brightnessValue, .settingInfo:
            return ThemeAutoNightSettingsControllerSection.settings.rawValue
        case .themeHeader, .themeItem:
            return ThemeAutoNightSettingsControllerSection.theme.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .modeSystem:
                return 0
            case .modeDisabled:
                return 1
            case .modeTimeBased:
                return 2
            case .modeBrightness:
                return 3
            case .settingsHeader:
                return 4
            case .timeBasedAutomaticLocation:
                return 5
            case .timeBasedAutomaticLocationValue:
                return 6
            case .timeBasedManualFrom:
                return 7
            case .timeBasedManualTo:
                return 8
            case .brightnessValue:
                return 9
            case .settingInfo:
                return 10
            case .themeHeader:
                return 11
            case .themeItem:
                return 12
        }
    }
    
    static func ==(lhs: ThemeAutoNightSettingsControllerEntry, rhs: ThemeAutoNightSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .modeSystem(lhsTheme, lhsTitle, lhsValue):
                if case let .modeSystem(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .modeDisabled(lhsTheme, lhsTitle, lhsValue):
                if case let .modeDisabled(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .modeTimeBased(lhsTheme, lhsTitle, lhsValue):
                if case let .modeTimeBased(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .modeBrightness(lhsTheme, lhsTitle, lhsValue):
                if case let .modeBrightness(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .settingsHeader(lhsTheme, lhsTitle):
                if case let .settingsHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .timeBasedAutomaticLocation(lhsTheme, lhsTitle, lhsValue):
                if case let .timeBasedAutomaticLocation(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .timeBasedAutomaticLocationValue(lhsTheme, lhsTitle, lhsValue):
                if case let .timeBasedAutomaticLocationValue(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .timeBasedManualFrom(lhsTheme, lhsTitle, lhsValue):
                if case let .timeBasedManualFrom(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .timeBasedManualTo(lhsTheme, lhsTitle, lhsValue):
                if case let .timeBasedManualTo(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .brightnessValue(lhsTheme, lhsValue):
                if case let .brightnessValue(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(lhsTheme, lhsValue):
                if case let .settingInfo(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .themeHeader(lhsTheme, lhsValue):
                if case let .themeHeader(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsAllThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsThemeChatWallpapers):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsAllThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsThemeChatWallpapers) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsAllThemes == rhsAllThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsThemeChatWallpapers == rhsThemeChatWallpapers {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemeAutoNightSettingsControllerEntry, rhs: ThemeAutoNightSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ThemeAutoNightSettingsControllerArguments
        switch self {
            case let .modeSystem(_, title, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.system)
                })
            case let .modeDisabled(_, title, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.none)
                })
            case let .modeTimeBased(_, title, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.timeBased)
                })
            case let .modeBrightness(_, title, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.brightness)
                })
            case let .settingsHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .timeBasedAutomaticLocation(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateTimeBasedAutomatic(value)
                })
            case let .timeBasedAutomaticLocationValue(_, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: title, titleColor: .accent, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                    arguments.updateTimeBasedAutomaticLocation()
                })
            case let .timeBasedManualFrom(_, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: title, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openTimeBasedManual(.from)
                })
            case let .timeBasedManualTo(_, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: title, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openTimeBasedManual(.to)
                })
            case let .brightnessValue(theme, value):
                return ThemeSettingsBrightnessItem(theme: theme, value: Int32(value * 100.0), sectionId: self.section, updated: { value in
                    arguments.updateAutomaticBrightness(Double(value) / 100.0)
                })
            case let .settingInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .themeHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .themeItem(theme, strings, themes, allThemes, currentTheme, themeSpecificAccentColors, themeSpecificChatWallpapers):
            return ThemeSettingsThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, allThemes: allThemes, displayUnsupported: false, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, themePreferredBaseTheme: [:], currentTheme: currentTheme, updatedTheme: { theme in
                    arguments.updateTheme(theme)
                }, contextAction: nil)
        }
    }
}

private func themeAutoNightSettingsControllerEntries(theme: PresentationTheme, strings: PresentationStrings, settings: PresentationThemeSettings, switchSetting: AutomaticThemeSwitchSetting, availableThemes: [PresentationThemeReference], dateTimeFormat: PresentationDateTimeFormat) -> [ThemeAutoNightSettingsControllerEntry] {
    var entries: [ThemeAutoNightSettingsControllerEntry] = []
    
    let activeTriggerMode: TriggerMode
    switch switchSetting.trigger {
        case .system:
            if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                activeTriggerMode = .system
            } else {
                activeTriggerMode = .none
            }
        case .explicitNone:
            activeTriggerMode = .none
        case .timeBased:
            activeTriggerMode = .timeBased
        case .brightness:
            activeTriggerMode = .brightness
    }
    
    if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
        entries.append(.modeSystem(theme, strings.AutoNightTheme_System, activeTriggerMode == .system))
    }
    entries.append(.modeDisabled(theme, strings.AutoNightTheme_Disabled, activeTriggerMode == .none))
    entries.append(.modeTimeBased(theme, strings.AutoNightTheme_Scheduled, activeTriggerMode == .timeBased))
    entries.append(.modeBrightness(theme, strings.AutoNightTheme_Automatic, activeTriggerMode == .brightness))
    
    switch switchSetting.trigger {
        case .system, .explicitNone:
            break
        case let .timeBased(setting):
            entries.append(.settingsHeader(theme, strings.AutoNightTheme_ScheduleSection))
            var automaticLocation = false
            if case .automatic = setting {
                automaticLocation = true
            }
            entries.append(.timeBasedAutomaticLocation(theme, strings.AutoNightTheme_UseSunsetSunrise, automaticLocation))
            switch setting {
                case let .automatic(latitude, longitude, localizedName):
                    let calculator = EDSunriseSet(date: Date(), timezone: TimeZone.current, latitude: latitude, longitude: longitude)!
                    let sunset = roundTimeToDay(Int32(calculator.sunset.timeIntervalSince1970))
                    let sunrise = roundTimeToDay(Int32(calculator.sunrise.timeIntervalSince1970))
                    
                    entries.append(.timeBasedAutomaticLocationValue(theme, strings.AutoNightTheme_UpdateLocation, localizedName))
                    if sunset != 0 || sunrise != 0 {
                        entries.append(.settingInfo(theme, strings.AutoNightTheme_LocationHelp(stringForMessageTimestamp(timestamp: sunset, dateTimeFormat: dateTimeFormat, local: false), stringForMessageTimestamp(timestamp: sunrise, dateTimeFormat: dateTimeFormat, local: false)).string))
                    }
                case let .manual(fromSeconds, toSeconds):
                    entries.append(.timeBasedManualFrom(theme, strings.AutoNightTheme_ScheduledFrom, stringForMessageTimestamp(timestamp: fromSeconds, dateTimeFormat: dateTimeFormat, local: false)))
                    entries.append(.timeBasedManualTo(theme, strings.AutoNightTheme_ScheduledTo, stringForMessageTimestamp(timestamp: toSeconds, dateTimeFormat: dateTimeFormat, local: false)))
            }
        case let .brightness(threshold):
            entries.append(.settingsHeader(theme, strings.AutoNightTheme_AutomaticSection))
            entries.append(.brightnessValue(theme, threshold))
            entries.append(.settingInfo(theme, strings.AutoNightTheme_AutomaticHelp("\(Int(threshold * 100.0))").string.replacingOccurrences(of: "%%", with: "%")))
    }
    
    switch switchSetting.trigger {
        case .explicitNone:
            break
        case .system, .timeBased, .brightness:
            entries.append(.themeHeader(theme, strings.AutoNightTheme_PreferredTheme))
            
            let generalThemes: [PresentationThemeReference] = availableThemes.filter { reference in
                if case let .cloud(theme) = reference {
                    return theme.theme.settings == nil
                } else {
                    return true
                }
            }
            
            entries.append(.themeItem(theme, strings, generalThemes, availableThemes, switchSetting.theme, settings.themeSpecificAccentColors, settings.themeSpecificChatWallpapers))
    }
    
    return entries
}

private func roundTimeToDay(_ timestamp: Int32) -> Int32 {
    let calendar = Calendar.current
    let offset = 0
    let components = calendar.dateComponents([.hour, .minute, .second], from: Date(timeIntervalSince1970: Double(timestamp + Int32(offset))))
    return Int32(components.hour! * 60 * 60 + components.minute! * 60 + components.second!)
}

private func areSettingsValid(_ settings: AutomaticThemeSwitchSetting) -> Bool {
    switch settings.trigger {
        case .system, .explicitNone, .brightness:
            return true
        case let .timeBased(setting):
            switch setting {
                case let .automatic(latitude, longitude, _):
                    if !latitude.isZero || !longitude.isZero {
                        return true
                    } else {
                        return false
                    }
                case .manual:
                    return true
            }
    }
}

public func themeAutoNightSettingsController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let updateAutomaticBrightnessDisposable = MetaDisposable()
    
    let stagingSettingsPromise = ValuePromise<AutomaticThemeSwitchSetting?>(nil)
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
    
    let updateLocationDisposable = MetaDisposable()
    actionsDisposable.add(updateLocationDisposable)
    
    let updateSettings: (@escaping (AutomaticThemeSwitchSetting) -> AutomaticThemeSwitchSetting) -> Void = { f in
        let _ = (combineLatest(stagingSettingsPromise.get(), sharedData)
        |> take(1)
        |> deliverOnMainQueue).start(next: { stagingSettings, sharedData in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
            let updated = f(stagingSettings ?? settings.automaticThemeSwitchSetting)
            stagingSettingsPromise.set(updated)
            if areSettingsValid(updated) {
                let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    var current = current
                    current.automaticThemeSwitchSetting = updated
                    return current
                }).start()
            }
        })
    }
    
    let forceUpdateLocation: () -> Void = {
        let locationCoordinates = Signal<(Double, Double), NoError> { subscriber in
            return context.sharedContext.locationManager!.push(mode: DeviceLocationMode.preciseForeground, updated: { location, _ in
                subscriber.putNext((location.coordinate.latitude, location.coordinate.longitude))
                subscriber.putCompletion()
            })
        }
        let geocodedLocation = locationCoordinates
        |> mapToSignal { coordinates -> Signal<(Double, Double, String), NoError> in
            return reverseGeocodeLocation(latitude: coordinates.0, longitude: coordinates.1)
            |> map { locality in
                return (coordinates.0, coordinates.1, locality?.city ?? "")
            }
        }
        
        let disposable = (geocodedLocation
        |> take(1)
        |> deliverOnMainQueue).start(next: { location in
            updateSettings { settings in
                var settings = settings
                if case let .timeBased(setting) = settings.trigger, case .automatic = setting {
                    settings.trigger = .timeBased(setting: .automatic(latitude: location.0, longitude: location.1, localizedName: location.2))
                }
                return settings
            }
        })
        updateLocationDisposable.set(disposable)
    }
    
    let arguments = ThemeAutoNightSettingsControllerArguments(context: context, updateMode: { mode in
        var updateLocation = false
        updateSettings { settings in
            var settings = settings
            switch mode {
                case .system:
                    settings.trigger = .system
                case .none:
                    settings.trigger = .explicitNone
                case .timeBased:
                    if case .timeBased = settings.trigger {
                    } else {
                        settings.trigger = .timeBased(setting: .automatic(latitude: 0.0, longitude: 0.0, localizedName: ""))
                        updateLocation = true
                    }
                case .brightness:
                    if case .brightness = settings.trigger {
                    } else {
                        settings.trigger = .brightness(threshold: 0.2)
                    }
            }
            if updateLocation {
                forceUpdateLocation()
            }
            return settings
        }
    }, updateTimeBasedAutomatic: { value in
        var updateLocation = false
        updateSettings { settings in
            var settings = settings
            if case let .timeBased(setting) = settings.trigger {
                switch setting {
                    case .automatic:
                        if !value {
                            settings.trigger = .timeBased(setting: .manual(fromSeconds: 22 * 60 * 60, toSeconds: 9 * 60 * 60))
                        }
                    case .manual:
                        if value {
                            settings.trigger = .timeBased(setting: .automatic(latitude: 0.0, longitude: 0.0, localizedName: ""))
                            updateLocation = true
                        }
                }
            }
            if updateLocation {
                forceUpdateLocation()
            }
            return settings
        }
    }, openTimeBasedManual: { field in
        var currentValue: Int32
        switch field {
            case .from:
                currentValue = 22 * 60 * 60
            case .to:
                currentValue = 9 * 60 * 60
        }
        updateSettings { settings in
            let settings = settings
            switch settings.trigger {
                case let .timeBased(setting):
                        switch setting {
                            case let .manual(fromSeconds, toSeconds):
                                switch field {
                                    case .from:
                                        currentValue = fromSeconds
                                    case .to:
                                        currentValue = toSeconds
                                }
                            default:
                                break
                        }
                default:
                    break
            }
            
            presentControllerImpl?(ThemeAutoNightTimeSelectionActionSheet(context: context, currentValue: currentValue, applyValue: { value in
                guard let value = value else {
                    return
                }
                updateSettings { settings in
                    var settings = settings
                    switch settings.trigger {
                        case let .timeBased(setting):
                            switch setting {
                            case var .manual(fromSeconds, toSeconds):
                                switch field {
                                case .from:
                                    fromSeconds = value
                                case .to:
                                    toSeconds = value
                                }
                                settings.trigger = .timeBased(setting: .manual(fromSeconds: fromSeconds, toSeconds: toSeconds))
                            default:
                                break
                            }
                        default:
                            break
                    }
                    return settings
                }
            }))
            
            return settings
        }
    }, updateTimeBasedAutomaticLocation: {
        forceUpdateLocation()
    }, updateAutomaticBrightness: { value in
        updateAutomaticBrightnessDisposable.set((Signal<Never, NoError>.complete()
        |> delay(0.1, queue: Queue.mainQueue())).start(completed: {
            updateSettings { settings in
                var settings = settings
                switch settings.trigger {
                    case .brightness:
                        settings.trigger = .brightness(threshold: max(0.0, min(1.0, value)))
                    default:
                        break
                }
                return settings
            }
        }))
    }, updateTheme: { theme in
        guard let presentationTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: theme) else {
            return
        }
        
        let resolvedWallpaper: Signal<TelegramWallpaper?, NoError>
        if case let .file(file) = presentationTheme.chat.defaultWallpaper, file.id == 0 {
            resolvedWallpaper = cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
            |> map { wallpaper -> TelegramWallpaper? in
                return wallpaper?.wallpaper
            }
        } else {
            resolvedWallpaper = .single(nil)
        }
        
        let _ = (resolvedWallpaper
        |> mapToSignal { resolvedWallpaper -> Signal<Void, NoError> in
            var updatedTheme = theme
            if case let .cloud(info) = theme {
                updatedTheme = .cloud(PresentationCloudTheme(theme: info.theme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: info.theme.isCreator ? context.account.id : nil))
            }
            
            updateSettings { settings in
                var settings = settings
                settings.theme = updatedTheme
                return settings
            }
            
            return .complete()
        }).start()
    })
    
    let cloudThemes = Promise<[TelegramTheme]>()
    let updatedCloudThemes = telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
    cloudThemes.set(updatedCloudThemes)
    
    let signal = combineLatest(context.sharedContext.presentationData |> deliverOnMainQueue, sharedData |> deliverOnMainQueue, cloudThemes.get() |> deliverOnMainQueue, stagingSettingsPromise.get() |> deliverOnMainQueue)
    |> map { presentationData, sharedData, cloudThemes, stagingSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
        
        let defaultThemes: [PresentationThemeReference] = [.builtin(.night), .builtin(.nightAccent)]
        let cloudThemes: [PresentationThemeReference] = cloudThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil, creatorAccountId: $0.isCreator ? context.account.id : nil)) }
        
        var availableThemes = defaultThemes
        availableThemes.append(contentsOf: cloudThemes)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.AutoNightTheme_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: themeAutoNightSettingsControllerEntries(theme: presentationData.theme, strings: presentationData.strings, settings: settings, switchSetting: stagingSettings ?? settings.automaticThemeSwitchSetting, availableThemes: availableThemes, dateTimeFormat: presentationData.dateTimeFormat), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
