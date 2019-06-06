import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ThemeSettingsControllerArguments {
    let context: AccountContext
    let selectTheme: (Int32) -> Void
    let selectFontSize: (PresentationFontSize) -> Void
    let openWallpaperSettings: () -> Void
    let openAccentColor: (Int32) -> Void
    let openAutoNightTheme: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (String) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (Int32) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, openAccentColor: @escaping (Int32) -> Void, openAutoNightTheme: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void) {
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
    case fontSize
    case chatPreview
    case theme
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
    case fontSizeHeader(PresentationTheme, String)
    case fontSize(PresentationTheme, PresentationFontSize)
    case chatPreviewHeader(PresentationTheme, String)
    case chatPreview(PresentationTheme, PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder)
    case wallpaper(PresentationTheme, String)
    case accentColor(PresentationTheme, String, Int32)
    case autoNightTheme(PresentationTheme, String, String)
    case themeListHeader(PresentationTheme, String)
    case themeItem(PresentationTheme, PresentationStrings, [PresentationBuiltinThemeReference], PresentationBuiltinThemeReference)
    case iconHeader(PresentationTheme, String)
    case iconItem(PresentationTheme, PresentationStrings, [PresentationAppIcon], String?)
    case otherHeader(PresentationTheme, String)
    case largeEmoji(PresentationTheme, String, Bool)
    case animations(PresentationTheme, String, Bool)
    case animationsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .fontSizeHeader, .fontSize:
                return ThemeSettingsControllerSection.fontSize.rawValue
            case .chatPreviewHeader, .chatPreview, .wallpaper:
                return ThemeSettingsControllerSection.chatPreview.rawValue
            case .themeListHeader, .themeItem, .accentColor, .autoNightTheme:
                return ThemeSettingsControllerSection.theme.rawValue
            case .iconHeader, .iconItem:
                return ThemeSettingsControllerSection.icon.rawValue
            case .otherHeader, .largeEmoji, .animations, .animationsInfo:
                return ThemeSettingsControllerSection.other.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .fontSizeHeader:
                return 0
            case .fontSize:
                return 1
            case .chatPreviewHeader:
                return 2
            case .chatPreview:
                return 3
            case .wallpaper:
                return 4
            case .themeListHeader:
                return 5
            case .themeItem:
                return 6
            case .accentColor:
                return 7
            case .autoNightTheme:
                return 8
            case .iconHeader:
                return 100
            case .iconItem:
                return 101
            case .otherHeader:
                return 102
            case .largeEmoji:
                return 103
            case .animations:
                return 104
            case .animationsInfo:
                return 105
        }
    }
    
    static func ==(lhs: ThemeSettingsControllerEntry, rhs: ThemeSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .chatPreviewHeader(lhsTheme, lhsText):
                if case let .chatPreviewHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
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
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme {
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
            case let .chatPreviewHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .chatPreview(theme, componentTheme, wallpaper, fontSize, strings, dateTimeFormat, nameDisplayOrder):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: componentTheme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder)
            case let .wallpaper(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openWallpaperSettings()
                })
            case let .accentColor(theme, text, color):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, label: "", labelStyle: .color(UIColor(rgb: UInt32(bitPattern: color))), sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAccentColor(color)
                }, tag: ThemeSettingsEntryTag.accentColor)
            case let .autoNightTheme(theme, text, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAutoNightTheme()
                })
            case let .themeListHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .themeItem(theme, strings, themes, currentTheme):
                return ThemeSettingsThemeItem(theme: theme, strings: strings, sectionId: self.section, themes: themes.map { ($0, .white) }, currentTheme: currentTheme, updated: { theme in
                    arguments.selectTheme(theme.rawValue)
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

private func themeSettingsControllerEntries(presentationData: PresentationData, theme: PresentationTheme, themeAccentColor: Int32?, autoNightSettings: AutomaticThemeSwitchSetting, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, largeEmoji: Bool, disableAnimations: Bool, availableAppIcons: [PresentationAppIcon], currentAppIconName: String?) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    entries.append(.fontSizeHeader(presentationData.theme, strings.Appearance_TextSize.uppercased()))
    entries.append(.fontSize(presentationData.theme, fontSize))
    entries.append(.chatPreviewHeader(presentationData.theme, strings.Appearance_Preview))
    entries.append(.chatPreview(presentationData.theme, theme, wallpaper, fontSize, presentationData.strings, dateTimeFormat, presentationData.nameDisplayOrder))
    entries.append(.wallpaper(presentationData.theme, strings.Settings_ChatBackground))
    
    entries.append(.themeListHeader(presentationData.theme, strings.Appearance_ColorTheme.uppercased()))
    if case let .builtin(theme) = theme.name {
        entries.append(.themeItem(presentationData.theme, presentationData.strings, [.dayClassic, .day, .nightAccent, .nightGrayscale], theme.reference))
    }

    if theme.name == .builtin(.day) {
        entries.append(.accentColor(presentationData.theme, strings.Appearance_AccentColor, themeAccentColor ?? defaultDayAccentColor))
    }
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
    
    let availableAppIcons: Signal<[PresentationAppIcon], NoError> = .single(context.sharedContext.applicationBindings.getAvailableAlternateIcons())
    let currentAppIconName = ValuePromise<String?>()
    currentAppIconName.set(context.sharedContext.applicationBindings.getAlternateIconName() ?? "Black")
    
    let arguments = ThemeSettingsControllerArguments(context: context, selectTheme: { index in
        let theme: PresentationThemeReference
        switch index {
            case 1:
                theme = .builtin(.nightGrayscale)
            case 2:
                theme = .builtin(.day)
            case 3:
                theme = .builtin(.nightAccent)
            default:
                theme = .builtin(.dayClassic)
        }
        
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
                    switch index {
                        case 1:
                            wallpaper = .color(0xffffff)
                        case 2:
                            wallpaper = .color(0x000000)
                        case 3:
                            wallpaper = .color(0x18222d)
                        default:
                            wallpaper = .builtin(WallpaperSettings())
                    }
                }
                
                return PresentationThemeSettings(chatWallpaper: wallpaper, theme: theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            })
        }).start()
    }, selectFontSize: { size in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: size, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, openAccentColor: { color in
        presentControllerImpl?(ThemeAccentColorActionSheet(context: context, currentValue: color, applyValue: { color in
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeAccentColor: color, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            }).start()
        }))
    }, openAutoNightTheme: {
        pushControllerImpl?(themeAutoNightSettingsController(context: context))
    }, toggleLargeEmoji: { largeEmoji in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: largeEmoji,  disableAnimations: current.disableAnimations)
        }).start()
    }, disableAnimations: { disabled in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: disabled)
        }).start()
    }, selectAppIcon: { name in
        context.sharedContext.applicationBindings.requestSetAlternateIconName(name, { succeed in
            if succeed {
                currentAppIconName.set(name)
            }
        })
    })
    
    let previousTheme = Atomic<PresentationTheme?>(value: nil)
    
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
                        theme = makeDefaultDayPresentationTheme(accentColor: settings.themeAccentColor ?? defaultDayAccentColor, serviceBackgroundColor: defaultServiceBackgroundColor)
            }
        }
        wallpaper = settings.chatWallpaper
        fontSize = settings.fontSize
        
        dateTimeFormat = presentationData.dateTimeFormat
        largeEmoji = settings.largeEmoji
        disableAnimations = settings.disableAnimations
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: themeSettingsControllerEntries(presentationData: presentationData, theme: theme, themeAccentColor: settings.themeAccentColor, autoNightSettings: settings.automaticThemeSwitchSetting, strings: presentationData.strings, wallpaper: wallpaper, fontSize: fontSize, dateTimeFormat: dateTimeFormat, largeEmoji: largeEmoji, disableAnimations: disableAnimations, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
        
        if previousTheme.swap(theme)?.name != theme.name {
            //presentControllerImpl?(ThemeSettingsCrossfadeController())
        }
        
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
