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
    let selectAccentColor: (PresentationThemeAccentColor) -> Void
    let toggleColorSlider: (Bool) -> Void
    let openAutoNightTheme: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (String) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (PresentationThemeReference) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, selectAccentColor: @escaping (PresentationThemeAccentColor) -> Void, toggleColorSlider: @escaping (Bool) -> Void, openAutoNightTheme: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void) {
        self.context = context
        self.selectTheme = selectTheme
        self.selectFontSize = selectFontSize
        self.openWallpaperSettings = openWallpaperSettings
        self.selectAccentColor = selectAccentColor
        self.toggleColorSlider = toggleColorSlider
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
    case tint
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
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], PresentationThemeAccentColor?, Bool)
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
                return 4
            case .wallpaper:
                return 5
            case .autoNightTheme:
                return 6
            case .fontSizeHeader:
                return 7
            case .fontSize:
                return 8
            case .iconHeader:
                return 9
            case .iconItem:
                return 10
            case .otherHeader:
                return 11
            case .largeEmoji:
                return 12
            case .animations:
                return 13
            case .animationsInfo:
                return 14
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
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsCurrentColor, lhsDisplayColorSlider):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsCurrentColor, rhsDisplayColorSlider) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsCurrentColor == rhsCurrentColor, lhsDisplayColorSlider == rhsDisplayColorSlider {
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
            case let .accentColor(theme, _, color):
                var colors = PresentationThemeBaseColor.allCases
                if theme.overallDarkAppearance {
                    colors = colors.filter { $0 != .black }
                }
                
                let defaultColor: PresentationThemeAccentColor
                if case let .builtin(name) = theme.name, name == .night {
                    colors = colors.filter { $0 != .gray }
                    defaultColor = PresentationThemeAccentColor(baseColor: .white, value: 0.5)
                } else {
                    colors = colors.filter { $0 != .white }
                    defaultColor = PresentationThemeAccentColor(baseColor: .blue, value: 0.5)
                }
                
                return ThemeSettingsAccentColorItem(theme: theme, sectionId: self.section, colors: colors, currentColor: color ?? defaultColor, updated: { color in
                    arguments.selectAccentColor(color)
                }, toggleSlider: { baseColor in
                    arguments.toggleColorSlider(baseColor == .white || baseColor == .black)
                }, tag: ThemeSettingsEntryTag.accentColor)
            case let .autoNightTheme(theme, text, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAutoNightTheme()
                })
            case let .themeListHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .themeItem(theme, strings, themes, currentTheme, themeSpecificAccentColors, currentColor, displayColorSlider):
                return ThemeSettingsThemeItem(theme: theme, strings: strings, sectionId: self.section, themes: themes, themeSpecificAccentColors: themeSpecificAccentColors, currentTheme: currentTheme, updatedTheme: { theme in
                    arguments.selectTheme(theme)
                }, currentColor: currentColor, updatedColor: { color in
                    arguments.selectAccentColor(color)
                }, displayColorSlider: displayColorSlider)
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

private struct ThemeSettingsState: Equatable {
    let displayColorSlider: Bool
    
    init(displayColorSlider: Bool) {
        self.displayColorSlider = displayColorSlider
    }
    
    func withDisplayColorSlider(_ displayColorSlider: Bool) -> ThemeSettingsState {
        return ThemeSettingsState(displayColorSlider: displayColorSlider)
    }
}

private func themeSettingsControllerEntries(presentationData: PresentationData, theme: PresentationTheme, themeReference: PresentationThemeReference, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], autoNightSettings: AutomaticThemeSwitchSetting, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, largeEmoji: Bool, disableAnimations: Bool, availableAppIcons: [PresentationAppIcon], currentAppIconName: String?, displayColorSlider: Bool) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    entries.append(.themeListHeader(presentationData.theme, strings.Appearance_ColorTheme.uppercased()))
    entries.append(.chatPreview(presentationData.theme, theme, wallpaper, fontSize, presentationData.strings, dateTimeFormat, presentationData.nameDisplayOrder))
    
    let availableThemes: [PresentationThemeReference] = [.builtin(.dayClassic), .builtin(.day), .builtin(.night), .builtin(.nightAccent)]
    entries.append(.themeItem(presentationData.theme, presentationData.strings, availableThemes, themeReference, themeSpecificAccentColors, themeSpecificAccentColors[themeReference.index], displayColorSlider))
    
    if theme.name != .builtin(.dayClassic) {
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
    let initialState = ThemeSettingsState(displayColorSlider: false)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ThemeSettingsState) -> ThemeSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
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
                
                let chatWallpaper: TelegramWallpaper
                if let themeSpecificWallpaper = current.themeSpecificChatWallpapers[theme.index] {
                    chatWallpaper = themeSpecificWallpaper
                } else {
                    let accentColor = current.themeSpecificAccentColors[theme.index]?.color
                    let theme = makePresentationTheme(themeReference: theme, accentColor: accentColor, serviceBackgroundColor: defaultServiceBackgroundColor)
                    chatWallpaper = theme.chat.defaultWallpaper
                }
                
                return PresentationThemeSettings(chatWallpaper: chatWallpaper, theme: theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            })
        }).start()
    }, selectFontSize: { size in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: size, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, selectAccentColor: { color in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            var themeSpecificAccentColors = current.themeSpecificAccentColors
            themeSpecificAccentColors[current.theme.index] = color
            
            var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
            
            let theme = makePresentationTheme(themeReference: current.theme, accentColor: color.color, serviceBackgroundColor: defaultServiceBackgroundColor)
            var chatWallpaper = current.chatWallpaper
            if let wallpaper = current.themeSpecificChatWallpapers[current.theme.index], wallpaper.hasWallpaper {
            } else {
                chatWallpaper = theme.chat.defaultWallpaper
                themeSpecificChatWallpapers[current.theme.index] = chatWallpaper
            }
            
            if color.baseColor == .white || color.baseColor == .black {
                updateState { $0.withDisplayColorSlider(false) }
            }

            return PresentationThemeSettings(chatWallpaper: chatWallpaper, theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, toggleColorSlider: { forceHidden in
        //updateState { $0.withDisplayColorSlider(forceHidden ? false : !$0.displayColorSlider) }
    }, openAutoNightTheme: {
        pushControllerImpl?(themeAutoNightSettingsController(context: context))
    }, toggleLargeEmoji: { largeEmoji in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: largeEmoji,  disableAnimations: current.disableAnimations)
        }).start()
    }, disableAnimations: { value in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: value)
        }).start()
    }, selectAppIcon: { name in
        currentAppIconName.set(name)
        context.sharedContext.applicationBindings.requestSetAlternateIconName(name, { _ in
        })
    })
        
    let signal = combineLatest(context.sharedContext.presentationData |> deliverOnMainQueue, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]) |> deliverOnMainQueue, availableAppIcons, currentAppIconName.get() |> deliverOnMainQueue, statePromise.get() |> deliverOnMainQueue)
    |> map { presentationData, sharedData, availableAppIcons, currentAppIconName, state -> (ItemListControllerState, (ItemListNodeState<ThemeSettingsControllerEntry>, ThemeSettingsControllerEntry.ItemGenerationArguments)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        
        let fontSize = settings.fontSize
        let dateTimeFormat = presentationData.dateTimeFormat
        let largeEmoji = presentationData.largeEmoji
        let disableAnimations = presentationData.disableAnimations
        
        let accentColor = settings.themeSpecificAccentColors[settings.theme.index]?.color
        let theme = makePresentationTheme(themeReference: settings.theme, accentColor: accentColor, serviceBackgroundColor: defaultServiceBackgroundColor, preview: true)

        let wallpaper: TelegramWallpaper
        if let themeSpecificWallpaper = settings.themeSpecificChatWallpapers[settings.theme.index] {
            wallpaper = themeSpecificWallpaper
        } else {
            wallpaper = settings.chatWallpaper
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: themeSettingsControllerEntries(presentationData: presentationData, theme: theme, themeReference: settings.theme, themeSpecificAccentColors: settings.themeSpecificAccentColors, autoNightSettings: settings.automaticThemeSwitchSetting, strings: presentationData.strings, wallpaper: wallpaper, fontSize: fontSize, dateTimeFormat: dateTimeFormat, largeEmoji: largeEmoji, disableAnimations: disableAnimations, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName, displayColorSlider: state.displayColorSlider), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
                
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
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
