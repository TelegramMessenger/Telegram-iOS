import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AlertUI
import PresentationDataUtils
import WallpaperResources
import ShareController
import AccountContext
import ContextUI

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

func themeDisplayName(strings: PresentationStrings, reference: PresentationThemeReference) -> String {
    let name: String
    switch reference {
        case let .builtin(theme):
            switch theme {
                case .dayClassic:
                    name = strings.Appearance_ThemeCarouselClassic
                case .day:
                    name = strings.Appearance_ThemeCarouselDay
                case .night:
                    name = strings.Appearance_ThemeCarouselNewNight
                case .nightAccent:
                    name = strings.Appearance_ThemeCarouselTintedNight
            }
        case let .local(theme):
            name = theme.title
        case let .cloud(theme):
            name = theme.theme.title
    }
    return name
}

private final class ThemeSettingsControllerArguments {
    let context: AccountContext
    let selectTheme: (PresentationThemeReference) -> Void
    let selectFontSize: (PresentationFontSize) -> Void
    let openWallpaperSettings: () -> Void
    let selectAccentColor: (PresentationThemeAccentColor) -> Void
    let openAccentColorPicker: (PresentationThemeReference) -> Void
    let openAutoNightTheme: () -> Void
    let openTextSize: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (String) -> Void
    let editTheme: (PresentationCloudTheme) -> Void
    let contextAction: (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (PresentationThemeReference) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, selectAccentColor: @escaping (PresentationThemeAccentColor) -> Void, openAccentColorPicker: @escaping (PresentationThemeReference) -> Void, openAutoNightTheme: @escaping () -> Void, openTextSize: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void, editTheme: @escaping (PresentationCloudTheme) -> Void, contextAction: @escaping (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.selectTheme = selectTheme
        self.selectFontSize = selectFontSize
        self.openWallpaperSettings = openWallpaperSettings
        self.selectAccentColor = selectAccentColor
        self.openAccentColorPicker = openAccentColorPicker
        self.openAutoNightTheme = openAutoNightTheme
        self.openTextSize = openTextSize
        self.toggleLargeEmoji = toggleLargeEmoji
        self.disableAnimations = disableAnimations
        self.selectAppIcon = selectAppIcon
        self.editTheme = editTheme
        self.contextAction = contextAction
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
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
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
    case chatPreview(PresentationTheme, PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, [ChatPreviewMessageItem])
    case wallpaper(PresentationTheme, String)
    case accentColor(PresentationTheme, PresentationThemeReference, String, PresentationThemeAccentColor?)
    case autoNightTheme(PresentationTheme, String, String)
    case textSize(PresentationTheme, String, String)
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], [Int64: PresentationThemeColorPair], PresentationThemeAccentColor?)
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
            case .wallpaper, .autoNightTheme, .textSize:
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
            case .textSize:
                return 7
            case .fontSizeHeader:
                return 8
            case .fontSize:
                return 9
            case .iconHeader:
                return 10
            case .iconItem:
                return 11
            case .otherHeader:
                return 12
            case .largeEmoji:
                return 13
            case .animations:
                return 14
            case .animationsInfo:
                return 15
        }
    }
    
    static func ==(lhs: ThemeSettingsControllerEntry, rhs: ThemeSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .chatPreview(lhsTheme, lhsComponentTheme, lhsWallpaper, lhsFontSize, lhsStrings, lhsTimeFormat, lhsNameOrder, lhsItems):
                if case let .chatPreview(rhsTheme, rhsComponentTheme, rhsWallpaper, rhsFontSize, rhsStrings, rhsTimeFormat, rhsNameOrder, rhsItems) = rhs, lhsComponentTheme === rhsComponentTheme, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder, lhsItems == rhsItems {
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
            case let .accentColor(lhsTheme, lhsCurrentTheme, lhsText, lhsColor):
                if case let .accentColor(rhsTheme, rhsCurrentTheme, rhsText, rhsColor) = rhs, lhsTheme === rhsTheme, lhsCurrentTheme == rhsCurrentTheme, lhsText == rhsText, lhsColor == rhsColor {
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
            case let .textSize(lhsTheme, lhsText, lhsValue):
                if case let .textSize(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsThemeBubbleColors, lhsCurrentColor):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsThemeBubbleColors, rhsCurrentColor) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsThemeBubbleColors == rhsThemeBubbleColors, lhsCurrentColor == rhsCurrentColor {
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ThemeSettingsControllerArguments
        switch self {
            case let .fontSizeHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .fontSize(theme, fontSize):
                return ThemeSettingsFontSizeItem(theme: theme, fontSize: fontSize, sectionId: self.section, updated: { value in
                    arguments.selectFontSize(value)
                }, tag: ThemeSettingsEntryTag.fontSize)
            case let .chatPreview(theme, componentTheme, wallpaper, fontSize, strings, dateTimeFormat, nameDisplayOrder, items):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: componentTheme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, messageItems: items)
            case let .wallpaper(theme, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openWallpaperSettings()
                })
            case let .accentColor(theme, currentTheme, _, color):
                var defaultColor = PresentationThemeAccentColor(baseColor: .blue)
                var colors = PresentationThemeBaseColor.allCases
                if case let .builtin(name) = currentTheme {
                    if name == .night || name == .nightAccent {
                        colors = colors.filter { $0 != .black }
                    }
                    if name == .night {
                        colors = colors.filter { $0 != .gray }
                        defaultColor = PresentationThemeAccentColor(baseColor: .white)
                    } else {
                        colors = colors.filter { $0 != .white }
                    }
                }
                let currentColor = color ?? defaultColor
                if currentColor.baseColor != .custom {
                    colors = colors.filter { $0 != .custom }
                }
                return ThemeSettingsAccentColorItem(theme: theme, sectionId: self.section, colors: colors, currentColor: currentColor, updated: { color in
                    arguments.selectAccentColor(color)
                }, openColorPicker: {
                    arguments.openAccentColorPicker(currentTheme)
                }, tag: ThemeSettingsEntryTag.accentColor)
            case let .autoNightTheme(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAutoNightTheme()
                })
            case let .textSize(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openTextSize()
                })
            case let .themeListHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .themeItem(theme, strings, themes, currentTheme, themeSpecificAccentColors, themeSpecificBubbleColors, _):
                return ThemeSettingsThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, displayUnsupported: true, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificBubbleColors: themeSpecificBubbleColors, currentTheme: currentTheme, updatedTheme: { theme in
                    if case let .cloud(theme) = theme, theme.theme.file == nil {
                        if theme.theme.isCreator {
                            arguments.editTheme(theme)
                        }
                    } else {
                        arguments.selectTheme(theme)
                    }
                }, contextAction: { theme, node, gesture in
                    arguments.contextAction(theme.index == currentTheme.index, theme, node, gesture)
                })
            case let .iconHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .iconItem(theme, strings, icons, value):
                return ThemeSettingsAppIconItem(theme: theme, strings: strings, sectionId: self.section, icons: icons, currentIconName: value, updated: { iconName in
                    arguments.selectAppIcon(iconName)
                })
            case let .otherHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .largeEmoji(theme, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleLargeEmoji(value)
                }, tag: ThemeSettingsEntryTag.largeEmoji)
            case let .animations(theme, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.disableAnimations(value)
                }, tag: ThemeSettingsEntryTag.animations)
            case let .animationsInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func themeSettingsControllerEntries(presentationData: PresentationData, presentationThemeSettings: PresentationThemeSettings, theme: PresentationTheme, themeReference: PresentationThemeReference, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificBubbleColors: [Int64: PresentationThemeColorPair], availableThemes: [PresentationThemeReference], autoNightSettings: AutomaticThemeSwitchSetting, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, largeEmoji: Bool, disableAnimations: Bool, availableAppIcons: [PresentationAppIcon], currentAppIconName: String?) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    let title = presentationData.autoNightModeTriggered ? strings.Appearance_ColorThemeNight.uppercased() : strings.Appearance_ColorTheme.uppercased()
    entries.append(.themeListHeader(presentationData.theme, title))
    entries.append(.chatPreview(presentationData.theme, theme, wallpaper, fontSize, presentationData.strings, dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (presentationData.strings.Appearance_PreviewReplyAuthor, presentationData.strings.Appearance_PreviewReplyText), text: presentationData.strings.Appearance_PreviewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: presentationData.strings.Appearance_PreviewOutgoingText)]))
    
    entries.append(.themeItem(presentationData.theme, presentationData.strings, availableThemes, themeReference, themeSpecificAccentColors, themeSpecificBubbleColors, themeSpecificAccentColors[themeReference.index]))
    
    if case let .builtin(theme) = themeReference, theme != .dayClassic {
        entries.append(.accentColor(presentationData.theme, themeReference, strings.Appearance_AccentColor, themeSpecificAccentColors[themeReference.index]))
    }
    
    entries.append(.wallpaper(presentationData.theme, strings.Settings_ChatBackground))
    
    let autoNightMode: String
    switch autoNightSettings.trigger {
        case .system:
            if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                autoNightMode = strings.AutoNightTheme_System
            } else {
                autoNightMode = strings.AutoNightTheme_Disabled
            }
        case .explicitNone:
            autoNightMode = strings.AutoNightTheme_Disabled
        case .timeBased:
            autoNightMode = strings.AutoNightTheme_Scheduled
        case .brightness:
            autoNightMode = strings.AutoNightTheme_Automatic
    }
    entries.append(.autoNightTheme(presentationData.theme, strings.Appearance_AutoNightTheme, autoNightMode))
    
    let textSizeValue: String
    if presentationThemeSettings.useSystemFont {
        textSizeValue = strings.Appearance_TextSize_Automatic
    } else {
        textSizeValue = "\(Int(presentationThemeSettings.fontSize.baseDisplaySize))pt"
    }
    entries.append(.textSize(presentationData.theme, strings.Appearance_TextSizeSetting, textSizeValue))
    
    //entries.append(.fontSizeHeader(presentationData.theme, strings.Appearance_TextSize.uppercased()))
    //entries.append(.fontSize(presentationData.theme, fontSize))
    
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
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    var selectThemeImpl: ((PresentationThemeReference) -> Void)?
    var moreImpl: (() -> Void)?
    
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
    
    let cloudThemes = Promise<[TelegramTheme]>()
    let updatedCloudThemes = telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
    cloudThemes.set(updatedCloudThemes)
    
    let arguments = ThemeSettingsControllerArguments(context: context, selectTheme: { theme in
        selectThemeImpl?(theme)
    }, selectFontSize: { size in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificBubbleColors: current.themeSpecificBubbleColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: size, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, selectAccentColor: { color in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
            var currentTheme = current.theme
            if autoNightModeTriggered {
                currentTheme = current.automaticThemeSwitchSetting.theme
            }

            guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: currentTheme, accentColor: color.color, bubbleColors: nil, serviceBackgroundColor: defaultServiceBackgroundColor) else {
                return current
            }
            
            var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
            var themeSpecificAccentColors = current.themeSpecificAccentColors
            var themeSpecificBubbleColors = current.themeSpecificBubbleColors
            themeSpecificAccentColors[currentTheme.index] = color
            themeSpecificBubbleColors[currentTheme.index] = nil

            if let wallpaper = current.themeSpecificChatWallpapers[currentTheme.index], wallpaper.hasWallpaper {
            } else {
                themeSpecificChatWallpapers[currentTheme.index] = theme.chat.defaultWallpaper
            }
            
            return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificBubbleColors: themeSpecificBubbleColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, openAccentColorPicker: { themeReference in
        let controller = ThemeAccentColorController(context: context, themeReference: themeReference, section: .accent)
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openAutoNightTheme: {
        pushControllerImpl?(themeAutoNightSettingsController(context: context))
    }, openTextSize: {
        let _ = (context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            let settings = (view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
            pushControllerImpl?(TextSizeSelectionController(context: context, presentationThemeSettings: settings))
        })
    }, toggleLargeEmoji: { largeEmoji in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificBubbleColors: current.themeSpecificBubbleColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: largeEmoji,  disableAnimations: current.disableAnimations)
        }).start()
    }, disableAnimations: { value in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificBubbleColors: current.themeSpecificBubbleColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: value)
        }).start()
    }, selectAppIcon: { name in
        currentAppIconName.set(name)
        context.sharedContext.applicationBindings.requestSetAlternateIconName(name, { _ in
        })
    }, editTheme: { theme in
        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
            if let navigationController = getNavigationControllerImpl?() {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
            }
        })
        pushControllerImpl?(controller)
    }, contextAction: { isCurrent, reference, node, gesture in
        let _ = (context.sharedContext.accountManager.transaction { transaction in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
            
            let accentColor = settings.themeSpecificAccentColors[reference.index]?.color
            let bubbleColors = settings.themeSpecificBubbleColors[reference.index]?.colors
            
            return (accentColor, bubbleColors)
        } |> map { accentColor, bubbleColors in
            return makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor, bubbleColors: bubbleColors, serviceBackgroundColor: defaultServiceBackgroundColor)
        }
        |> deliverOnMainQueue).start(next: { theme in
            guard let theme = theme else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings
            let themeController = ThemePreviewController(context: context, previewTheme: theme, source: .settings(reference))
            var items: [ContextMenuItem] = []
            
            if !isCurrent {
                items.append(.action(ContextMenuActionItem(text: strings.Theme_Context_Apply, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                    c.dismiss(completion: {
                        selectThemeImpl?(reference)
                    })
                })))
            }
            if case let .cloud(theme) = reference {
                if theme.theme.isCreator {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_EditTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
                            if let navigationController = getNavigationControllerImpl?() {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                            }
                        })
                        
                        c.dismiss(completion: {
                            pushControllerImpl?(controller)
                        })
                    })))
                }
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_ShareTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                    c.dismiss(completion: {
                        let controller = ShareController(context: context, subject: .url("https://t.me/addtheme/\(theme.theme.slug)"), preferredAction: .default)
                        presentControllerImpl?(controller, nil)
                    })
                })))
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_RemoveTheme, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, f in
                    c.dismiss(completion: {
                        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_RemoveThemeConfirmation, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            let _ = (cloudThemes.get() |> delay(0.5, queue: Queue.mainQueue())
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { themes in
                                if isCurrent, let currentThemeIndex = themes.firstIndex(where: { $0.id == theme.theme.id }) {
                                    let previousThemeIndex = themes.prefix(upTo: currentThemeIndex).reversed().firstIndex(where: { $0.file != nil })
                                    let newTheme: PresentationThemeReference
                                    if let previousThemeIndex = previousThemeIndex {
                                        newTheme = .cloud(PresentationCloudTheme(theme: themes[themes.index(before: previousThemeIndex.base)], resolvedWallpaper: nil))
                                    } else {
                                        newTheme = .builtin(.nightAccent)
                                    }
                                    selectThemeImpl?(newTheme)
                                }
                                
                                let _ = deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme.theme).start()
                            })
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        presentControllerImpl?(actionSheet, nil)
                    })
                })))
            }
            
            let contextController = ContextController(account: context.account, theme: presentationData.theme, strings: presentationData.strings, source: .controller(ContextControllerContentSourceImpl(controller: themeController, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
            presentInGlobalOverlayImpl?(contextController, nil)
        })
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]), cloudThemes.get(), availableAppIcons, currentAppIconName.get())
    |> map { presentationData, sharedData, cloudThemes, availableAppIcons, currentAppIconName -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        
        let fontSize = settings.fontSize
        let dateTimeFormat = presentationData.dateTimeFormat
        let largeEmoji = presentationData.largeEmoji
        let disableAnimations = presentationData.disableAnimations
    
        let themeReference: PresentationThemeReference
        if presentationData.autoNightModeTriggered {
            themeReference = settings.automaticThemeSwitchSetting.theme
        } else {
            themeReference = settings.theme
        }
        
        let theme = presentationData.theme
        let accentColor = settings.themeSpecificAccentColors[themeReference.index]?.color
        let wallpaper = presentationData.chatWallpaper
        
        let rightNavigationButton = ItemListNavigationButton(content: .icon(.action), style: .regular, enabled: true, action: {
            moreImpl?()
        })
        
        var defaultThemes: [PresentationThemeReference] = []
        if presentationData.autoNightModeTriggered {
        } else {
            defaultThemes.append(contentsOf: [.builtin(.dayClassic), .builtin(.day)])
        }
        defaultThemes.append(contentsOf: [.builtin(.night), .builtin(.nightAccent)])
        
        let cloudThemes: [PresentationThemeReference] = cloudThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil)) }
        
        var availableThemes = defaultThemes
        if defaultThemes.first(where: { $0.index == themeReference.index }) == nil && cloudThemes.first(where: { $0.index == themeReference.index }) == nil {
            availableThemes.append(themeReference)
        }
        availableThemes.append(contentsOf: cloudThemes)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: themeSettingsControllerEntries(presentationData: presentationData, presentationThemeSettings: settings, theme: theme, themeReference: themeReference, themeSpecificAccentColors: settings.themeSpecificAccentColors, themeSpecificBubbleColors: settings.themeSpecificBubbleColors, availableThemes: availableThemes, autoNightSettings: settings.automaticThemeSwitchSetting, strings: presentationData.strings, wallpaper: wallpaper, fontSize: fontSize, dateTimeFormat: dateTimeFormat, largeEmoji: largeEmoji, disableAnimations: disableAnimations, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
                
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
    }
    presentInGlobalOverlayImpl = { [weak controller] c, a in
        controller?.presentInGlobalOverlay(c, with: a)
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    selectThemeImpl = { theme in
        guard let presentationTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: theme, accentColor: nil, bubbleColors: nil, serviceBackgroundColor: .black) else {
            return
        }
        
        let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
        
        let resolvedWallpaper: Signal<TelegramWallpaper?, NoError>
        if case let .file(file) = presentationTheme.chat.defaultWallpaper, file.id == 0 {
            resolvedWallpaper = cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
            |> map { wallpaper -> TelegramWallpaper? in
                return wallpaper?.wallpaper
            }
        } else {
            resolvedWallpaper = .single(nil)
        }
        
        var cloudTheme: TelegramTheme?
        if case let .cloud(theme) = theme {
            cloudTheme = theme.theme
        }
        let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: cloudTheme).start()
        
        let _ = (resolvedWallpaper
        |> mapToSignal { resolvedWallpaper -> Signal<Void, NoError> in
            var updatedTheme = theme
            if case let .cloud(info) = theme {
                updatedTheme = .cloud(PresentationCloudTheme(theme: info.theme, resolvedWallpaper: resolvedWallpaper))
            }
            return (context.sharedContext.accountManager.transaction { transaction -> Void in
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
                    let current: PresentationThemeSettings
                    if let entry = entry as? PresentationThemeSettings {
                        current = entry
                    } else {
                        current = PresentationThemeSettings.defaultSettings
                    }
                    
                    var theme = current.theme
                    var automaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                    if autoNightModeTriggered {
                        automaticThemeSwitchSetting.theme = updatedTheme
                    } else {
                        theme = updatedTheme
                    }
                                                            
                    return PresentationThemeSettings(theme: theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificBubbleColors: current.themeSpecificBubbleColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                })
            })
        }).start()
    }
    moreImpl = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_CreateTheme, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            let controller = editThemeController(context: context, mode: .create, navigateToChat: { peerId in
                if let navigationController = getNavigationControllerImpl?() {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                }
            })
            pushControllerImpl?(controller)
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }
    return controller
}

public final class ThemeSettingsCrossfadeController: ViewController {
    private let snapshotView: UIView?
    
    public init() {
        self.snapshotView = UIScreen.main.snapshotView(afterScreenUpdates: false)
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ViewControllerTracingNode()
        
        self.displayNode.backgroundColor = nil
        self.displayNode.isOpaque = false
        self.displayNode.isUserInteractionEnabled = false
        if let snapshotView = self.snapshotView {
            self.displayNode.view.addSubview(snapshotView)
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
