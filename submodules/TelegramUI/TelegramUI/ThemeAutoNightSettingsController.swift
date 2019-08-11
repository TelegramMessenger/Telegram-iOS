import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramUIPrivateModule

private enum TriggerMode {
    case none
    case timeBased
    case brightness
}

private enum TimeBasedManualField {
    case from
    case to
}

private final class ThemeAutoNightSettingsControllerArguments {
    let updateMode: (TriggerMode) -> Void
    let updateTimeBasedAutomatic: (Bool) -> Void
    let openTimeBasedManual: (TimeBasedManualField) -> Void
    let updateTimeBasedAutomaticLocation: () -> Void
    let updateAutomaticBrightness: (Double) -> Void
    let updateTheme: (PresentationBuiltinThemeReference) -> Void
    
    init(updateMode: @escaping (TriggerMode) -> Void, updateTimeBasedAutomatic: @escaping (Bool) -> Void, openTimeBasedManual: @escaping (TimeBasedManualField) -> Void, updateTimeBasedAutomaticLocation: @escaping () -> Void, updateAutomaticBrightness: @escaping (Double) -> Void, updateTheme: @escaping (PresentationBuiltinThemeReference) -> Void) {
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
    case themeNightBlue(PresentationTheme, String, Bool)
    case themeNight(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .modeDisabled, .modeTimeBased, .modeBrightness:
            return ThemeAutoNightSettingsControllerSection.mode.rawValue
        case .settingsHeader, .timeBasedAutomaticLocation, .timeBasedAutomaticLocationValue, .timeBasedManualFrom, .timeBasedManualTo, .brightnessValue, .settingInfo:
            return ThemeAutoNightSettingsControllerSection.settings.rawValue
        case .themeHeader, .themeNightBlue, .themeNight:
            return ThemeAutoNightSettingsControllerSection.theme.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .modeDisabled:
                return 0
            case .modeTimeBased:
                return 1
            case .modeBrightness:
                return 2
            case .settingsHeader:
                return 3
            case .timeBasedAutomaticLocation:
                return 4
            case .timeBasedAutomaticLocationValue:
                return 5
            case .timeBasedManualFrom:
                return 6
            case .timeBasedManualTo:
                return 7
            case .brightnessValue:
                return 8
            case .settingInfo:
                return 9
            case .themeHeader:
                return 10
            case .themeNightBlue:
                return 11
            case .themeNight:
                return 12
        }
    }
    
    static func ==(lhs: ThemeAutoNightSettingsControllerEntry, rhs: ThemeAutoNightSettingsControllerEntry) -> Bool {
        switch lhs {
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
            case let .themeNightBlue(lhsTheme, lhsTitle, lhsValue):
                if case let .themeNightBlue(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .themeNight(lhsTheme, lhsTitle, lhsValue):
                if case let .themeNight(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemeAutoNightSettingsControllerEntry, rhs: ThemeAutoNightSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ThemeAutoNightSettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .modeDisabled(theme, title, value):
                return ItemListCheckboxItem(theme: theme, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.none)
                })
            case let .modeTimeBased(theme, title, value):
                return ItemListCheckboxItem(theme: theme, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.timeBased)
                })
            case let .modeBrightness(theme, title, value):
                return ItemListCheckboxItem(theme: theme, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateMode(.brightness)
                })
            case let .settingsHeader(theme, title):
                return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
            case let .timeBasedAutomaticLocation(theme, title, value):
                return ItemListSwitchItem(theme: theme, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateTimeBasedAutomatic(value)
                })
            case let .timeBasedAutomaticLocationValue(theme, title, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: title, titleColor: .accent, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                    arguments.updateTimeBasedAutomaticLocation()
                })
            case let .timeBasedManualFrom(theme, title, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: title, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openTimeBasedManual(.from)
                })
            case let .timeBasedManualTo(theme, title, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: title, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openTimeBasedManual(.to)
                })
            case let .brightnessValue(theme, value):
                return ThemeSettingsBrightnessItem(theme: theme, value: Int32(value * 100.0), sectionId: self.section, updated: { value in
                    arguments.updateAutomaticBrightness(Double(value) / 100.0)
                })
            case let .settingInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .themeHeader(theme, title):
                return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
            case let .themeNightBlue(theme, title, value):
                return ItemListCheckboxItem(theme: theme, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateTheme(.nightAccent)
                })
            case let .themeNight(theme, title, value):
                return ItemListCheckboxItem(theme: theme, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateTheme(.night)
                })
        }
    }
}

private func themeAutoNightSettingsControllerEntries(theme: PresentationTheme, strings: PresentationStrings, switchSetting: AutomaticThemeSwitchSetting, dateTimeFormat: PresentationDateTimeFormat) -> [ThemeAutoNightSettingsControllerEntry] {
    var entries: [ThemeAutoNightSettingsControllerEntry] = []
    
    let activeTriggerMode: TriggerMode
    switch switchSetting.trigger {
        case .none:
            activeTriggerMode = .none
        case .timeBased:
            activeTriggerMode = .timeBased
        case .brightness:
            activeTriggerMode = .brightness
    }
    
    entries.append(.modeDisabled(theme, strings.AutoNightTheme_Disabled, activeTriggerMode == .none))
    entries.append(.modeTimeBased(theme, strings.AutoNightTheme_Scheduled, activeTriggerMode == .timeBased))
    entries.append(.modeBrightness(theme, strings.AutoNightTheme_Automatic, activeTriggerMode == .brightness))
    
    switch switchSetting.trigger {
        case .none:
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
                        entries.append(.settingInfo(theme, strings.AutoNightTheme_LocationHelp(stringForMessageTimestamp(timestamp: sunset, dateTimeFormat: dateTimeFormat, local: false), stringForMessageTimestamp(timestamp: sunrise, dateTimeFormat: dateTimeFormat, local: false)).0))
                    }
                case let .manual(fromSeconds, toSeconds):
                    entries.append(.timeBasedManualFrom(theme, strings.AutoNightTheme_ScheduledFrom, stringForMessageTimestamp(timestamp: fromSeconds, dateTimeFormat: dateTimeFormat, local: false)))
                    entries.append(.timeBasedManualTo(theme, strings.AutoNightTheme_ScheduledTo, stringForMessageTimestamp(timestamp: toSeconds, dateTimeFormat: dateTimeFormat, local: false)))
            }
        case let .brightness(threshold):
            entries.append(.settingsHeader(theme, strings.AutoNightTheme_AutomaticSection))
            entries.append(.brightnessValue(theme, threshold))
            entries.append(.settingInfo(theme, strings.AutoNightTheme_AutomaticHelp("\(Int(threshold * 100.0))").0.replacingOccurrences(of: "%%", with: "%")))
    }
    
    switch switchSetting.trigger {
        case .none:
            break
        case .timeBased, .brightness:
            entries.append(.themeHeader(theme, strings.AutoNightTheme_PreferredTheme))
            entries.append(.themeNightBlue(theme, strings.Appearance_ThemeCarouselTintedNight, switchSetting.theme == .nightAccent))
            entries.append(.themeNight(theme, strings.Appearance_ThemeCarouselNewNight, switchSetting.theme == .night))
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
        case .none:
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
        case .brightness:
            return true
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
            let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
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
            return context.sharedContext.locationManager!.push(mode: DeviceLocationMode.precise, updated: { coordinate in
                subscriber.putNext((coordinate.latitude, coordinate.longitude))
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
    
    let arguments = ThemeAutoNightSettingsControllerArguments(updateMode: { mode in
        var updateLocation = false
        updateSettings { settings in
            var settings = settings
            switch mode {
                case .none:
                    settings.trigger = .none
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
        updateSettings { settings in
            var settings = settings
            settings.theme = theme
            return settings
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData |> deliverOnMainQueue, sharedData |> deliverOnMainQueue, stagingSettingsPromise.get() |> deliverOnMainQueue)
    |> map { presentationData, sharedData, stagingSettings -> (ItemListControllerState, (ItemListNodeState<ThemeAutoNightSettingsControllerEntry>, ThemeAutoNightSettingsControllerEntry.ItemGenerationArguments)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.AutoNightTheme_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: themeAutoNightSettingsControllerEntries(theme: presentationData.theme, strings: presentationData.strings, switchSetting: stagingSettings ?? settings.automaticThemeSwitchSetting, dateTimeFormat: presentationData.dateTimeFormat), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
