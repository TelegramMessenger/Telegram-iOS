import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

private final class ThemeSettingsControllerArguments {
    let context: AccountContext
    let selectTheme: (PresentationThemeReference) -> Void
    let selectFontSize: (PresentationFontSize) -> Void
    let openWallpaperSettings: () -> Void
    let openAccentColor: (Int32) -> Void
    let openAutoNightTheme: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (String) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (PresentationThemeReference) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, openAccentColor: @escaping (Int32) -> Void, openAutoNightTheme: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void) {
        self.context = context
        self.selectTheme = selectTheme
        self.selectFontSize = selectFontSize
        self.openWallpaperSettings = openWallpaperSettings
        self.openAccentColor = openAccentColor
        self.openAutoNightTheme = openAutoNightTheme
        self.toggleLargeEmoji = toggleLargeEmoji
        self.disableAnimations = disableAnimations
        self.selectAppIcon = selectAppIcon
    }
}

private enum ThemeSettingsControllerSection: Int32 {
    case chatPreview
    case background
    case fontSize
    case icon
    case other
}

public enum ThemeSettingsEntryTag: ItemListItemTag {
    case fontSize
    case theme
    case accentColor
    case icon
    case largeEmoji
    case animations
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ThemeSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum ThemeSettingsControllerEntry: ItemListNodeEntry {
    case themeListHeader(PresentationTheme, String)
    case fontSizeHeader(PresentationTheme, String)
    case fontSize(PresentationTheme, PresentationFontSize)
    case chatPreview(PresentationTheme, PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder)
    case wallpaper(PresentationTheme, String)
    case accentColor(PresentationTheme, String, PresentationThemeAccentColor?)
    case autoNightTheme(PresentationTheme, String, String)
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor])
    case iconHeader(PresentationTheme, String)
    case iconItem(PresentationTheme, PresentationStrings, [PresentationAppIcon], String?)
    case otherHeader(PresentationTheme, String)
    case largeEmoji(PresentationTheme, String, Bool)
    case animations(PresentationTheme, String, Bool)
    case animationsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .themeListHeader, .chatPreview, .themeItem, .accentColor:
                return ThemeSettingsControllerSection.chatPreview.rawValue
            case .fontSizeHeader, .fontSize:
                return ThemeSettingsControllerSection.fontSize.rawValue
            case .wallpaper, .autoNightTheme:
                return ThemeSettingsControllerSection.background.rawValue
            case .iconHeader, .iconItem:
                return ThemeSettingsControllerSection.icon.rawValue
            case .otherHeader, .largeEmoji, .animations, .animationsInfo:
                return ThemeSettingsControllerSection.other.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .themeListHeader:
                return 0
            case .chatPreview:
                return 1
            case .themeItem:
                return 2
            case .accentColor:
                return 3
            case .wallpaper:
                return 4
            case .autoNightTheme:
                return 5
            case .fontSizeHeader:
                return 6
            case .fontSize:
                return 7
            case .iconHeader:
                return 8
            case .iconItem:
                return 9
            case .otherHeader:
                return 10
            case .largeEmoji:
                return 11
            case .animations:
                return 12
            case .animationsInfo:
                return 13
        }
    }
    
    static func ==(lhs: ThemeSettingsControllerEntry, rhs: ThemeSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .chatPreview(lhsTheme, lhsComponentTheme, lhsWallpaper, lhsFontSize, lhsStrings, lhsTimeFormat, lhsNameOrder):
                if case let .chatPreview(rhsTheme, rhsComponentTheme, rhsWallpaper, rhsFontSize, rhsStrings, rhsTimeFormat, rhsNameOrder) = rhs, lhsComponentTheme === rhsComponentTheme, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder {
                    return true
                } else {
                    return false
                }
            case let .wallpaper(lhsTheme, lhsText):
                if case let .wallpaper(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .accentColor(lhsTheme, lhsText, lhsColor):
                if case let .accentColor(rhsTheme, rhsText, rhsColor) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsColor == rhsColor {
                    return true
                } else {
                    return false
                }
            case let .autoNightTheme(lhsTheme, lhsText, lhsValue):
                if case let .autoNightTheme(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .themeListHeader(lhsTheme, lhsText):
                if case let .themeListHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme, lhsThemeAccentColor):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme, rhsThemeAccentColor) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColor == rhsThemeAccentColor {
                    return true
                } else {
                    return false
                }
            case let .fontSizeHeader(lhsTheme, lhsText):
                if case let .fontSizeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .fontSize(lhsTheme, lhsFontSize):
                if case let .fontSize(rhsTheme, rhsFontSize) = rhs, lhsTheme === rhsTheme, lhsFontSize == rhsFontSize {
                    return true
                } else {
                    return false
                }
            case let .iconHeader(lhsTheme, lhsText):
                if case let .iconHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .iconItem(lhsTheme, lhsStrings, lhsIcons, lhsValue):
                if case let .iconItem(rhsTheme, rhsStrings, rhsIcons, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsIcons == rhsIcons, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .otherHeader(lhsTheme, lhsText):
                if case let .otherHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .largeEmoji(lhsTheme, lhsTitle, lhsValue):
                if case let .largeEmoji(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .animations(lhsTheme, lhsTitle, lhsValue):
                if case let .animations(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .animationsInfo(lhsTheme, lhsText):
                if case let .animationsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemeSettingsControllerEntry, rhs: ThemeSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ThemeSettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .fontSizeHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .fontSize(theme, fontSize):
                return ThemeSettingsFontSizeItem(theme: theme, fontSize: fontSize, sectionId: self.section, updated: { value in
                    arguments.selectFontSize(value)
                }, tag: ThemeSettingsEntryTag.fontSize)
            case let .chatPreview(theme, componentTheme, wallpaper, fontSize, strings, dateTimeFormat, nameDisplayOrder):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: componentTheme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder)
            case let .wallpaper(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openWallpaperSettings()
                })
            case let .accentColor(theme, text, color):
                let colorValue = color?.baseColor.colorValue ?? defaultDayAccentColor
                let accentColor = UIColor(rgb: UInt32(bitPattern: colorValue))
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, label: "", labelStyle: .color(accentColor), sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAccentColor(colorValue)
                }, tag: ThemeSettingsEntryTag.accentColor)
//                return ThemeSettingsAccentColorItem(theme: theme, sectionId: self.section, colors: PresentationThemeBaseColor.allCases, currentColor: color ?? PresentationThemeAccentColor(baseColor: .blue, value: 0.5), updated: { color in
//                    let _ = updatePresentationThemeSettingsInteractively(accountManager: arguments.context.sharedContext.accountManager, { current in
//                        var themeSpecificAccentColors = current.themeSpecificAccentColors
//                        themeSpecificAccentColors[current.theme.index] = color
//                        return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
//                    }).start()
//                }, toggleSlider: {
//                })
            case let .autoNightTheme(theme, text, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAutoNightTheme()
                })
            case let .themeListHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .themeItem(theme, strings, themes, currentTheme, themeSpecificAccentColors):
                return ThemeSettingsThemeItem(theme: theme, strings: strings, sectionId: self.section, themes: themes, themeSpecificAccentColors: themeSpecificAccentColors, currentTheme: currentTheme, updated: { theme in
                    arguments.selectTheme(theme)
                })
            case let .iconHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .iconItem(theme, strings, icons, value):
                return ThemeSettingsAppIconItem(theme: theme, strings: strings, sectionId: self.section, icons: icons, currentIconName: value, updated: { iconName in
                    arguments.selectAppIcon(iconName)
                })
            case let .otherHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .largeEmoji(theme, title, value):
                return ItemListSwitchItem(theme: theme, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleLargeEmoji(value)
                }, tag: ThemeSettingsEntryTag.largeEmoji)
            case let .animations(theme, title, value):
                return ItemListSwitchItem(theme: theme, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.disableAnimations(value)
                }, tag: ThemeSettingsEntryTag.animations)
            case let .animationsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private func themeSettingsControllerEntries(presentationData: PresentationData, theme: PresentationTheme, themeReference: PresentationThemeReference, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], autoNightSettings: AutomaticThemeSwitchSetting, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, largeEmoji: Bool, disableAnimations: Bool, availableAppIcons: [PresentationAppIcon], currentAppIconName: String?) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    entries.append(.themeListHeader(presentationData.theme, strings.Appearance_ColorTheme.uppercased()))
    entries.append(.chatPreview(presentationData.theme, theme, wallpaper, fontSize, presentationData.strings, dateTimeFormat, presentationData.nameDisplayOrder))
    if case .builtin = themeReference {
        entries.append(.themeItem(presentationData.theme, presentationData.strings, [.builtin(.dayClassic), .builtin(.day), .builtin(.nightAccent), .builtin(.nightGrayscale)], themeReference, themeSpecificAccentColors))
    }
    if theme.name == .builtin(.day) {
        entries.append(.accentColor(presentationData.theme, strings.Appearance_AccentColor, themeSpecificAccentColors[themeReference.index]))
    }
    
    entries.append(.wallpaper(presentationData.theme, strings.Settings_ChatBackground))

    if theme.name == .builtin(.day) || theme.name == .builtin(.dayClassic) {
        let title: String
        switch autoNightSettings.trigger {
        case .none:
            title = strings.AutoNightTheme_Disabled
        case .timeBased:
            title = strings.AutoNightTheme_Scheduled
        case .brightness:
            title = strings.AutoNightTheme_Automatic
        }
        entries.append(.autoNightTheme(presentationData.theme, strings.Appearance_AutoNightTheme, title))
    }
    
    entries.append(.fontSizeHeader(presentationData.theme, strings.Appearance_TextSize.uppercased()))
    entries.append(.fontSize(presentationData.theme, fontSize))
    
    if !availableAppIcons.isEmpty {
        entries.append(.iconHeader(presentationData.theme, strings.Appearance_AppIcon.uppercased()))
        entries.append(.iconItem(presentationData.theme, presentationData.strings, availableAppIcons, currentAppIconName))
    }
    
    entries.append(.otherHeader(presentationData.theme, strings.Appearance_Other.uppercased()))
    entries.append(.largeEmoji(presentationData.theme, strings.Appearance_LargeEmoji, largeEmoji))
    entries.append(.animations(presentationData.theme, strings.Appearance_ReduceMotion, disableAnimations))
    entries.append(.animationsInfo(presentationData.theme, strings.Appearance_ReduceMotionInfo))
    
    return entries
}

public func themeSettingsController(context: AccountContext, focusOnItemTag: ThemeSettingsEntryTag? = nil) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let _ = telegramWallpapers(postbox: context.account.postbox, network: context.account.network).start()
    
    let currentAppIcon: PresentationAppIcon?
    let appIcons = context.sharedContext.applicationBindings.getAvailableAlternateIcons()
    if let alternateIconName = context.sharedContext.applicationBindings.getAlternateIconName() {
        currentAppIcon = appIcons.filter { $0.name == alternateIconName }.first
    } else {
        currentAppIcon = appIcons.filter { $0.isDefault }.first
    }
    
    let availableAppIcons: Signal<[PresentationAppIcon], NoError> = .single(appIcons)
    let currentAppIconName = ValuePromise<String?>()
    currentAppIconName.set(currentAppIcon?.name ?? "Blue")
    
    let arguments = ThemeSettingsControllerArguments(context: context, selectTheme: { theme in
        let _ = (context.sharedContext.accountManager.transaction { transaction -> Void in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
                let current: PresentationThemeSettings
                if let entry = entry as? PresentationThemeSettings {
                    current = entry
                } else {
                    current = PresentationThemeSettings.defaultSettings
                }
                
                let wallpaper: TelegramWallpaper
                
                if let themeSpecificWallpaper = current.themeSpecificChatWallpapers[theme.index] {
                    wallpaper = themeSpecificWallpaper
                } else {
                    if case let .builtin(theme) = theme {
                        switch theme {
                            case .day:
                                wallpaper = .color(0xffffff)
                            case .dayClassic:
                                wallpaper = .builtin(WallpaperSettings())
                            case .nightAccent:
                                wallpaper = .color(0x18222d)
                            case .nightGrayscale:
                                wallpaper = .color(0x000000)
                        }
                    } else {
                        wallpaper = .builtin(WallpaperSettings())
                    }
                }
                
                return PresentationThemeSettings(chatWallpaper: wallpaper, theme: theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            })
        }).start()
    }, selectFontSize: { size in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: size, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, openAccentColor: { color in
        presentControllerImpl?(ThemeAccentColorActionSheet(context: context, currentValue: color, applyValue: { color in
            let themeAccentColor: PresentationThemeBaseColor
            switch color {
                case 0xf83b4c:
                    themeAccentColor = .red
                case 0xff7519:
                    themeAccentColor = .orange
                case 0xeba239:
                    themeAccentColor = .yellow
                case 0x29b327:
                    themeAccentColor = .green
                case 0x00c2ed:
                    themeAccentColor = .cyan
                case 0x007ee5:
                    themeAccentColor = .blue
                case 0x7748ff:
                    themeAccentColor = .purple
                case 0xff5da2:
                    themeAccentColor = .pink
                default:
                    themeAccentColor = .blue
            }
            
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var themeSpecificAccentColors = current.themeSpecificAccentColors
                themeSpecificAccentColors[current.theme.index] = PresentationThemeAccentColor(baseColor: themeAccentColor, value: 0.5)

                return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            }).start()
        }))
    }, openAutoNightTheme: {
        pushControllerImpl?(themeAutoNightSettingsController(context: context))
    }, toggleLargeEmoji: { largeEmoji in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: largeEmoji,  disableAnimations: current.disableAnimations)
        }).start()
    }, disableAnimations: { disabled in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: disabled)
        }).start()
    }, selectAppIcon: { name in
        currentAppIconName.set(name)
        context.sharedContext.applicationBindings.requestSetAlternateIconName(name, { _ in
        })
    })
        
    let signal = combineLatest(context.sharedContext.presentationData |> deliverOnMainQueue, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]) |> deliverOnMainQueue, availableAppIcons, currentAppIconName.get() |> deliverOnMainQueue)
    |> map { presentationData, sharedData, availableAppIcons, currentAppIconName -> (ItemListControllerState, (ItemListNodeState<ThemeSettingsControllerEntry>, ThemeSettingsControllerEntry.ItemGenerationArguments)) in
        let theme: PresentationTheme
        let fontSize: PresentationFontSize
        let wallpaper: TelegramWallpaper
        let dateTimeFormat: PresentationDateTimeFormat
        let largeEmoji: Bool
        let disableAnimations: Bool
        
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        switch settings.theme {
            case let .builtin(reference):
                switch reference {
                    case .dayClassic:
                        theme = defaultPresentationTheme
                    case .nightGrayscale:
                        theme = defaultDarkPresentationTheme
                    case .nightAccent:
                        theme = defaultDarkAccentPresentationTheme
                    case .day:
                        theme = makeDefaultDayPresentationTheme(accentColor: settings.themeSpecificAccentColors[settings.theme.index]?.color ?? defaultDayAccentColor, serviceBackgroundColor: defaultServiceBackgroundColor)
            }
        }
        wallpaper = settings.chatWallpaper
        fontSize = settings.fontSize
        
        dateTimeFormat = presentationData.dateTimeFormat
        largeEmoji = settings.largeEmoji
        disableAnimations = settings.disableAnimations
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: themeSettingsControllerEntries(presentationData: presentationData, theme: theme, themeReference: settings.theme, themeSpecificAccentColors: settings.themeSpecificAccentColors, autoNightSettings: settings.automaticThemeSwitchSetting, strings: presentationData.strings, wallpaper: wallpaper, fontSize: fontSize, dateTimeFormat: dateTimeFormat, largeEmoji: largeEmoji, disableAnimations: disableAnimations, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
                
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

public final class ThemeSettingsCrossfadeController: ViewController {
    private let snapshotView: UIView?
    
    public init() {
        self.snapshotView = UIScreen.main.snapshotView(afterScreenUpdates: false)
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Hide
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ViewControllerTracingNode()
        
        self.displayNode.backgroundColor = nil
        self.displayNode.isOpaque = false
        if let snapshotView = self.snapshotView {
            self.displayNode.view.addSubview(snapshotView)
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
