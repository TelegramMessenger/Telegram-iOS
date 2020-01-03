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
import MediaResources
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
    let selectAccentColor: (PresentationThemeAccentColor?) -> Void
    let openAccentColorPicker: (PresentationThemeReference, Bool) -> Void
    let openAutoNightTheme: () -> Void
    let openTextSize: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (String) -> Void
    let editTheme: (PresentationCloudTheme) -> Void
    let themeContextAction: (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void
    let colorContextAction: (Bool, PresentationThemeReference, ThemeSettingsColorOption?, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (PresentationThemeReference) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, selectAccentColor: @escaping (PresentationThemeAccentColor?) -> Void, openAccentColorPicker: @escaping (PresentationThemeReference, Bool) -> Void, openAutoNightTheme: @escaping () -> Void, openTextSize: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void, editTheme: @escaping (PresentationCloudTheme) -> Void, themeContextAction: @escaping (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void, colorContextAction: @escaping (Bool, PresentationThemeReference, ThemeSettingsColorOption?, ASDisplayNode, ContextGesture?) -> Void) {
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
        self.themeContextAction = themeContextAction
        self.colorContextAction = colorContextAction
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
    case chatPreview(PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, [ChatPreviewMessageItem])
    case wallpaper(PresentationTheme, String)
    case accentColor(PresentationTheme, PresentationThemeReference, PresentationThemeReference, [PresentationThemeReference], ThemeSettingsColorOption?)
    case autoNightTheme(PresentationTheme, String, String)
    case textSize(PresentationTheme, String, String)
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], [Int64: TelegramWallpaper], PresentationThemeAccentColor?)
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
            case let .chatPreview(lhsTheme, lhsWallpaper, lhsFontSize, lhsStrings, lhsTimeFormat, lhsNameOrder, lhsItems):
                if case let .chatPreview(rhsTheme, rhsWallpaper, rhsFontSize, rhsStrings, rhsTimeFormat, rhsNameOrder, rhsItems) = rhs, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder, lhsItems == rhsItems {
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
            case let .accentColor(lhsTheme, lhsGeneralTheme, lhsCurrentTheme, lhsThemes, lhsColor):
                if case let .accentColor(rhsTheme, rhsGeneralTheme, rhsCurrentTheme, rhsThemes, rhsColor) = rhs, lhsTheme === rhsTheme, lhsCurrentTheme == rhsCurrentTheme, lhsThemes == rhsThemes, lhsColor == rhsColor {
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
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsAllThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsThemeSpecificChatWallpapers, lhsCurrentColor):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsAllThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsThemeSpecificChatWallpapers, rhsCurrentColor) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsAllThemes == rhsAllThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsThemeSpecificChatWallpapers == rhsThemeSpecificChatWallpapers, lhsCurrentColor == rhsCurrentColor {
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
            case let .chatPreview(theme, wallpaper, fontSize, strings, dateTimeFormat, nameDisplayOrder, items):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: theme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, messageItems: items)
            case let .wallpaper(theme, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openWallpaperSettings()
                })
            case let .accentColor(theme, generalThemeReference, currentTheme, themes, color):
                var colorItems: [ThemeSettingsAccentColor] = []
                
                for theme in themes {
                    colorItems.append(.theme(theme))
                }
                                
                var defaultColor: PresentationThemeAccentColor? = PresentationThemeAccentColor(baseColor: .blue)
                var colors = PresentationThemeBaseColor.allCases
                colors = colors.filter { $0 != .custom && $0 != .preset && $0 != .theme }
                if case let .builtin(name) = generalThemeReference {
                    if name == .dayClassic {
                        colorItems.append(.default)
                        defaultColor = nil
                        
                        for preset in dayClassicColorPresets {
                            colorItems.append(.preset(preset))
                        }
                    } else if name == .day {
                        colorItems.append(.color(.blue))
                        colors = colors.filter { $0 != .blue }
                        
                        for preset in dayColorPresets {
                            colorItems.append(.preset(preset))
                        }
                    } else if name == .night {
                        colorItems.append(.color(.blue))
                        colors = colors.filter { $0 != .blue }
                        
                        for preset in nightColorPresets {
                            colorItems.append(.preset(preset))
                        }
                    }
                    if name != .day {
                        colors = colors.filter { $0 != .black }
                    }
                    if name == .night {
                        colors = colors.filter { $0 != .gray }
                        defaultColor = PresentationThemeAccentColor(baseColor: .white)
                    } else {
                        colors = colors.filter { $0 != .white }
                    }
                }
                var currentColor = color ?? defaultColor.flatMap { .accentColor($0) }
                if let color = currentColor, case let .accentColor(accentColor) = color, accentColor.baseColor == .theme {
                    var themeExists = false
                    if let _ = themes.first(where: { $0.index == accentColor.themeIndex }) {
                        themeExists = true
                    }
                    if !themeExists {
                        currentColor = defaultColor.flatMap { .accentColor($0) }
                    }
                }
                colorItems.append(contentsOf: colors.map { .color($0) })
                
                return ThemeSettingsAccentColorItem(theme: theme, sectionId: self.section, generalThemeReference: generalThemeReference, themeReference: currentTheme, colors: colorItems, currentColor: currentColor, updated: { color in
                    if let color = color {
                        switch color {
                            case let .accentColor(color):
                                arguments.selectAccentColor(color)
                            case let .theme(theme):
                                arguments.selectTheme(theme)
                        }
                    } else {
                        arguments.selectAccentColor(nil)
                    }
                }, contextAction: { isCurrent, theme, color, node, gesture in
                    arguments.colorContextAction(isCurrent, theme, color, node, gesture)
                }, openColorPicker: { create in
                    arguments.openAccentColorPicker(currentTheme, create)
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
            case let .themeItem(theme, strings, themes, allThemes, currentTheme, themeSpecificAccentColors, themeSpecificChatWallpapers, _):
                return ThemeSettingsThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, allThemes: allThemes, displayUnsupported: true, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, currentTheme: currentTheme, updatedTheme: { theme in
                    if case let .cloud(theme) = theme, theme.theme.file == nil && theme.theme.settings == nil {
                        if theme.theme.isCreator {
                            arguments.editTheme(theme)
                        }
                    } else {
                        arguments.selectTheme(theme)
                    }
                }, contextAction: { theme, node, gesture in
                    arguments.themeContextAction(theme.index == currentTheme.index, theme, node, gesture)
                }, tag: ThemeSettingsEntryTag.theme)
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

private func themeSettingsControllerEntries(presentationData: PresentationData, presentationThemeSettings: PresentationThemeSettings, themeReference: PresentationThemeReference, availableThemes: [PresentationThemeReference], availableAppIcons: [PresentationAppIcon], currentAppIconName: String?) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    let strings = presentationData.strings
    let title = presentationData.autoNightModeTriggered ? strings.Appearance_ColorThemeNight.uppercased() : strings.Appearance_ColorTheme.uppercased()
    entries.append(.themeListHeader(presentationData.theme, title))
    entries.append(.chatPreview(presentationData.theme, presentationData.chatWallpaper, presentationData.chatFontSize, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (presentationData.strings.Appearance_PreviewReplyAuthor, presentationData.strings.Appearance_PreviewReplyText), text: presentationData.strings.Appearance_PreviewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: presentationData.strings.Appearance_PreviewOutgoingText)]))
    
    let generalThemes: [PresentationThemeReference] = availableThemes.filter { reference in
        if case let .cloud(theme) = reference {
            return theme.theme.settings == nil
        } else {
            return true
        }
    }
    
    let generalThemeReference: PresentationThemeReference
    if case let .cloud(theme) = themeReference, let settings = theme.theme.settings {
        generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme))
    } else {
        generalThemeReference = themeReference
    }
    
    entries.append(.themeItem(presentationData.theme, presentationData.strings, generalThemes, availableThemes, themeReference, presentationThemeSettings.themeSpecificAccentColors, presentationThemeSettings.themeSpecificChatWallpapers, presentationThemeSettings.themeSpecificAccentColors[themeReference.index]))
    
    if case let .builtin(builtinTheme) = generalThemeReference {
        let colorThemes = availableThemes.filter { reference in
            if case let .cloud(theme) = reference, let settings = theme.theme.settings, settings.baseTheme == builtinTheme.baseTheme {
                return true
            } else {
                return false
            }
        }
        
        var colorOption: ThemeSettingsColorOption?
        if case let .builtin(theme) = themeReference {
            colorOption = presentationThemeSettings.themeSpecificAccentColors[themeReference.index].flatMap { .accentColor($0) }
        } else {
            colorOption = .theme(themeReference)
        }
        
        entries.append(.accentColor(presentationData.theme, generalThemeReference, themeReference, colorThemes, colorOption))
    }
    
    entries.append(.wallpaper(presentationData.theme, strings.Settings_ChatBackground))
    
    let autoNightMode: String
    switch presentationThemeSettings.automaticThemeSwitchSetting.trigger {
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
        if presentationThemeSettings.fontSize.baseDisplaySize == presentationThemeSettings.listsFontSize.baseDisplaySize {
            textSizeValue = "\(Int(presentationThemeSettings.fontSize.baseDisplaySize))pt"
        } else {
            textSizeValue = "\(Int(presentationThemeSettings.fontSize.baseDisplaySize))pt / \(Int(presentationThemeSettings.listsFontSize.baseDisplaySize))pt"
        }
    }
    entries.append(.textSize(presentationData.theme, strings.Appearance_TextSizeSetting, textSizeValue))
    
    if !availableAppIcons.isEmpty {
        entries.append(.iconHeader(presentationData.theme, strings.Appearance_AppIcon.uppercased()))
        entries.append(.iconItem(presentationData.theme, presentationData.strings, availableAppIcons, currentAppIconName))
    }
    
    entries.append(.otherHeader(presentationData.theme, strings.Appearance_Other.uppercased()))
    entries.append(.largeEmoji(presentationData.theme, strings.Appearance_LargeEmoji, presentationData.largeEmoji))
    entries.append(.animations(presentationData.theme, strings.Appearance_ReduceMotion, presentationData.disableAnimations))
    entries.append(.animationsInfo(presentationData.theme, strings.Appearance_ReduceMotionInfo))
    
    return entries
}

public protocol ThemeSettingsController {
    
}

private final class ThemeSettingsControllerImpl: ItemListController, ThemeSettingsController {
}

public func themeSettingsController(context: AccountContext, focusOnItemTag: ThemeSettingsEntryTag? = nil) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var updateControllersImpl: ((([UIViewController]) -> [UIViewController]) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    var presentCrossfadeControllerImpl: ((Bool) -> Void)?
    
    var selectThemeImpl: ((PresentationThemeReference) -> Void)?
    var selectAccentColorImpl: ((PresentationThemeAccentColor?) -> Void)?
    var openAccentColorPickerImpl: ((PresentationThemeReference, Bool) -> Void)?
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
    
    let removedThemeIndexesPromise = Promise<Set<Int64>>(Set())
    let removedThemeIndexes = Atomic<Set<Int64>>(value: Set())
    
    let arguments = ThemeSettingsControllerArguments(context: context, selectTheme: { theme in
        selectThemeImpl?(theme)
    }, selectFontSize: { _ in
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, selectAccentColor: { accentColor in
        selectAccentColorImpl?(accentColor)
    }, openAccentColorPicker: { themeReference, create in
        openAccentColorPickerImpl?(themeReference, create)
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
            return current.withUpdatedLargeEmoji(largeEmoji)
        }).start()
    }, disableAnimations: { disableAnimations in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedDisableAnimations(disableAnimations)
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
    }, themeContextAction: { isCurrent, reference, node, gesture in
        let _ = (context.sharedContext.accountManager.transaction { transaction -> (PresentationThemeAccentColor?, TelegramWallpaper?) in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
            let accentColor = settings.themeSpecificAccentColors[reference.index]
            var wallpaper: TelegramWallpaper?
            if let accentColor = accentColor {
                wallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: reference, accentColor: accentColor)]
            }
            if wallpaper == nil {
                wallpaper = settings.themeSpecificChatWallpapers[reference.index]
            }
            return (accentColor, wallpaper)
        }
        |> map { accentColor, wallpaper -> (PresentationThemeAccentColor?, TelegramWallpaper) in
            let effectiveWallpaper: TelegramWallpaper
            if let wallpaper = wallpaper {
                effectiveWallpaper = wallpaper
            } else {
                let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor?.color, bubbleColors: accentColor?.customBubbleColors, wallpaper: accentColor?.wallpaper)
                effectiveWallpaper = theme?.chat.defaultWallpaper ?? .builtin(WallpaperSettings())
            }
            return (accentColor, effectiveWallpaper)
        }
        |> mapToSignal { accentColor, wallpaper -> Signal<(PresentationThemeAccentColor?, TelegramWallpaper), NoError> in
            if case let .file(file) = wallpaper, file.id == 0 {
                return cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                |> map { cachedWallpaper in
                    if let wallpaper = cachedWallpaper?.wallpaper, case let .file(file) = wallpaper {
                        return (accentColor, wallpaper)
                    } else {
                        return (accentColor, .builtin(WallpaperSettings()))
                    }
                }
            } else {
                return .single((accentColor, wallpaper))
            }
        }
        |> mapToSignal { accentColor, wallpaper -> Signal<(PresentationTheme?, TelegramWallpaper?), NoError> in
            return chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: context.sharedContext.accountManager.mediaBox)
            |> map { serviceBackgroundColor in
                return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor?.color, bubbleColors: accentColor?.customBubbleColors, serviceBackgroundColor: serviceBackgroundColor), wallpaper)
            }
        }
        |> deliverOnMainQueue).start(next: { theme, wallpaper in
            guard let theme = theme else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings
            let themeController = ThemePreviewController(context: context, previewTheme: theme, source: .settings(reference, wallpaper))
            var items: [ContextMenuItem] = []
            
            if case let .cloud(theme) = reference {
                if theme.theme.isCreator {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_EditTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
                            if let navigationController = getNavigationControllerImpl?() {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                            }
                        })
                        
                        c.dismiss(completion: {
                            pushControllerImpl?(controller)
                        })
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: strings.Theme_Context_ChangeColors, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, preview: false) else {
                            return
                        }
                        
                        let resolvedWallpaper: Signal<TelegramWallpaper, NoError>
                        if case let .file(file) = theme.chat.defaultWallpaper, file.id == 0 {
                            resolvedWallpaper = cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                            |> map { cachedWallpaper -> TelegramWallpaper in
                                return cachedWallpaper?.wallpaper ?? theme.chat.defaultWallpaper
                            }
                        } else {
                            resolvedWallpaper = .single(theme.chat.defaultWallpaper)
                        }
                        
                        let _ = (resolvedWallpaper
                        |> deliverOnMainQueue).start(next: { wallpaper in
                            let controller = ThemeAccentColorController(context: context, mode: .edit(theme: theme, wallpaper: wallpaper, generalThemeReference: reference.generalThemeReference, defaultThemeReference: nil, create: true, completion: { result, settings in
                                let controller = editThemeController(context: context, mode: .create(result, nil), navigateToChat: { peerId in
                                    if let navigationController = getNavigationControllerImpl?() {
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                                    }
                                })
                                updateControllersImpl?({ controllers in
                                    var controllers = controllers
                                    controllers = controllers.filter { controller in
                                        if controller is ThemeAccentColorController {
                                            return false
                                        }
                                        return true
                                    }
                                    controllers.append(controller)
                                    return controllers
                                })
                            }))
                            
                            c.dismiss(completion: {
                                pushControllerImpl?(controller)
                            })
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
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_RemoveThemeConfirmation, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            let _ = (cloudThemes.get()
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { themes in
                                removedThemeIndexesPromise.set(.single(removedThemeIndexes.modify({ value in
                                    var updated = value
                                    updated.insert(theme.theme.id)
                                    return updated
                                })))
                                
                                if isCurrent, let currentThemeIndex = themes.firstIndex(where: { $0.id == theme.theme.id }) {
                                    if let settings = theme.theme.settings {
                                        if settings.baseTheme == .night {
                                            selectAccentColorImpl?(PresentationThemeAccentColor(baseColor: .blue))
                                        } else {
                                            selectAccentColorImpl?(nil)
                                        }
                                    } else {
                                        let previousThemeIndex = themes.prefix(upTo: currentThemeIndex).reversed().firstIndex(where: { $0.file != nil })
                                        let newTheme: PresentationThemeReference
                                        if let previousThemeIndex = previousThemeIndex {
                                            newTheme = .cloud(PresentationCloudTheme(theme: themes[themes.index(before: previousThemeIndex.base)], resolvedWallpaper: nil))
                                        } else {
                                            newTheme = .builtin(.nightAccent)
                                        }
                                        selectThemeImpl?(newTheme)
                                    }
                                }
                                
                                let _ = deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme.theme).start()
                            })
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        presentControllerImpl?(actionSheet, nil)
                    })
                })))
            } else {
                items.append(.action(ContextMenuActionItem(text: strings.Theme_Context_ChangeColors, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor)
                }, action: { c, f in
                    c.dismiss(completion: {
                        let controller = ThemeAccentColorController(context: context, mode: .colors(themeReference: reference, create: true))
                        pushControllerImpl?(controller)
                    })
                })))
            }
            
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: themeController, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
            presentInGlobalOverlayImpl?(contextController, nil)
        })
    }, colorContextAction: { isCurrent, reference, accentColor, node, gesture in
        let _ = (context.sharedContext.accountManager.transaction { transaction -> (ThemeSettingsColorOption?, TelegramWallpaper?) in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
            var wallpaper: TelegramWallpaper?
            if let accentColor = accentColor {
                switch accentColor {
                    case let .accentColor(accentColor):
                        wallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: reference, accentColor: accentColor)]
                        if wallpaper == nil {
                            wallpaper = settings.themeSpecificChatWallpapers[reference.index]
                        }
                    case let .theme(theme):
                        wallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: theme, accentColor: nil)]
                }
            } else if wallpaper == nil {
                wallpaper = settings.themeSpecificChatWallpapers[reference.index]
            }
            return (accentColor, wallpaper)
        } |> mapToSignal { accentColor, wallpaper -> Signal<(PresentationTheme?, PresentationThemeReference, Bool, TelegramWallpaper?), NoError> in
            let generalThemeReference: PresentationThemeReference
            if let accentColor = accentColor, case let .cloud(theme) = reference, let settings = theme.theme.settings {
                generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme))
            } else {
                generalThemeReference = reference
            }
            
            let effectiveWallpaper: TelegramWallpaper
            let effectiveThemeReference: PresentationThemeReference
            if let accentColor = accentColor, case let .theme(themeReference) = accentColor {
                effectiveThemeReference = themeReference
            } else {
                effectiveThemeReference = reference
            }
            
            if let wallpaper = wallpaper {
                effectiveWallpaper = wallpaper
            } else {
                let theme: PresentationTheme?
                if let accentColor = accentColor, case let .theme(themeReference) = accentColor {
                    theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference)
                } else {
                    theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: generalThemeReference, accentColor: accentColor?.accentColor, bubbleColors: accentColor?.customBubbleColors, wallpaper: accentColor?.wallpaper)
                }
                effectiveWallpaper = theme?.chat.defaultWallpaper ?? .builtin(WallpaperSettings())
            }
            
            let wallpaperSignal: Signal<TelegramWallpaper, NoError>
            if case let .file(file) = effectiveWallpaper, file.id == 0 {
                wallpaperSignal = cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                |> map { cachedWallpaper in
                    return cachedWallpaper?.wallpaper ?? effectiveWallpaper
                }
            } else {
                wallpaperSignal = .single(effectiveWallpaper)
            }
            
            return wallpaperSignal
            |> mapToSignal { wallpaper in
                return chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: context.sharedContext.accountManager.mediaBox)
                |> map { serviceBackgroundColor in
                    return (wallpaper, serviceBackgroundColor)
                }
            }
            |> map { wallpaper, serviceBackgroundColor -> (PresentationTheme?, PresentationThemeReference, TelegramWallpaper) in
                if let accentColor = accentColor, case let .theme(themeReference) = accentColor {
                    return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, serviceBackgroundColor: serviceBackgroundColor), effectiveThemeReference, wallpaper)
                } else {
                    return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: generalThemeReference, accentColor: accentColor?.accentColor, bubbleColors: accentColor?.customBubbleColors, serviceBackgroundColor: serviceBackgroundColor), effectiveThemeReference, wallpaper)
                }
            }
            |> mapToSignal { theme, reference, wallpaper in
                if case let .cloud(info) = reference {
                    return cloudThemes.get()
                    |> take(1)
                    |> map { themes -> Bool in
                        if let _ = themes.first(where: { $0.id == info.theme.id }) {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> map { cloudThemeExists -> (PresentationTheme?, PresentationThemeReference, Bool, TelegramWallpaper) in
                        return (theme, reference, cloudThemeExists, wallpaper)
                    }
                } else {
                    return .single((theme, reference, false, wallpaper))
                }
            }
        }
        |> deliverOnMainQueue).start(next: { theme, effectiveThemeReference, cloudThemeExists, wallpaper in
            guard let theme = theme else {
                return
            }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings
            let themeController = ThemePreviewController(context: context, previewTheme: theme, source: .settings(effectiveThemeReference, wallpaper))
            var items: [ContextMenuItem] = []
            
            if let accentColor = accentColor {
                if case let .accentColor(color) = accentColor, color.baseColor != .custom {
                } else if case let .theme(theme) = accentColor, case let .cloud(cloudTheme) = theme {
                    if cloudTheme.theme.isCreator && cloudThemeExists {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_EditTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            let controller = editThemeController(context: context, mode: .edit(cloudTheme), navigateToChat: { peerId in
                                if let navigationController = getNavigationControllerImpl?() {
                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                                }
                            })
                            
                            c.dismiss(completion: {
                                pushControllerImpl?(controller)
                            })
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: strings.Theme_Context_ChangeColors, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, preview: false) else {
                                return
                            }
                            
                            let resolvedWallpaper: Signal<TelegramWallpaper, NoError>
                            if case let .file(file) = theme.chat.defaultWallpaper, file.id == 0 {
                                resolvedWallpaper = cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                                |> map { cachedWallpaper -> TelegramWallpaper in
                                    return cachedWallpaper?.wallpaper ?? theme.chat.defaultWallpaper
                                }
                            } else {
                                resolvedWallpaper = .single(theme.chat.defaultWallpaper)
                            }
                            
                            let _ = (resolvedWallpaper
                            |> deliverOnMainQueue).start(next: { wallpaper in
                                let controller = ThemeAccentColorController(context: context, mode: .edit(theme: theme, wallpaper: wallpaper, generalThemeReference: reference.generalThemeReference, defaultThemeReference: nil, create: true, completion: { result, settings in
                                    let controller = editThemeController(context: context, mode: .create(result, nil), navigateToChat: { peerId in
                                        if let navigationController = getNavigationControllerImpl?() {
                                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                                        }
                                    })
                                    updateControllersImpl?({ controllers in
                                        var controllers = controllers
                                        controllers = controllers.filter { controller in
                                            if controller is ThemeAccentColorController {
                                                return false
                                            }
                                            return true
                                        }
                                        controllers.append(controller)
                                        return controllers
                                    })
                                }))
                                
                                c.dismiss(completion: {
                                    pushControllerImpl?(controller)
                                })
                            })
                        })))
                    }
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_ShareTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        c.dismiss(completion: {
                            let controller = ShareController(context: context, subject: .url("https://t.me/addtheme/\(cloudTheme.theme.slug)"), preferredAction: .default)
                            presentControllerImpl?(controller, nil)
                        })
                    })))
                    if cloudThemeExists {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_RemoveTheme, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, f in
                            c.dismiss(completion: {
                                let actionSheet = ActionSheetController(presentationData: presentationData)
                                var items: [ActionSheetItem] = []
                                items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_RemoveThemeConfirmation, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    let _ = (cloudThemes.get()
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { themes in
                                        removedThemeIndexesPromise.set(.single(removedThemeIndexes.modify({ value in
                                             var updated = value
                                             updated.insert(cloudTheme.theme.id)
                                             return updated
                                         })))
                                        
                                        if isCurrent, let settings = cloudTheme.theme.settings {
                                            let colorThemes = themes.filter { theme in
                                                if let settings = theme.settings {
                                                    return true
                                                } else {
                                                    return false
                                                }
                                            }
                                            
                                            if let currentThemeIndex = colorThemes.firstIndex(where: { $0.id == cloudTheme.theme.id }) {
                                                let previousThemeIndex = themes.prefix(upTo: currentThemeIndex).reversed().firstIndex(where: { $0.file != nil })
                                                let newTheme: PresentationThemeReference
                                                if let previousThemeIndex = previousThemeIndex {
                                                    selectThemeImpl?(.cloud(PresentationCloudTheme(theme: themes[themes.index(before: previousThemeIndex.base)], resolvedWallpaper: nil)))
                                                } else {
                                                    if settings.baseTheme == .night {
                                                        selectAccentColorImpl?(PresentationThemeAccentColor(baseColor: .blue))
                                                    } else {
                                                        selectAccentColorImpl?(nil)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        let _ = deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: cloudTheme.theme).start()
                                    })
                                }))
                                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                ])])
                                presentControllerImpl?(actionSheet, nil)
                            })
                        })))
                    }
                }
            }
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: themeController, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
            presentInGlobalOverlayImpl?(contextController, nil)
        })
    })
    
    let previousThemeReference = Atomic<PresentationThemeReference?>(value: nil)
    let previousAccentColor = Atomic<PresentationThemeAccentColor?>(value: nil)
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]), cloudThemes.get(), availableAppIcons, currentAppIconName.get(), removedThemeIndexesPromise.get())
        |> map { presentationData, sharedData, cloudThemes, availableAppIcons, currentAppIconName, removedThemeIndexes -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        
        let dateTimeFormat = presentationData.dateTimeFormat
        let largeEmoji = presentationData.largeEmoji
        let disableAnimations = presentationData.disableAnimations
    
        let themeReference: PresentationThemeReference
        if presentationData.autoNightModeTriggered {
            themeReference = settings.automaticThemeSwitchSetting.theme
        } else {
            themeReference = settings.theme
        }
        
        let accentColor = settings.themeSpecificAccentColors[themeReference.index]
        
        let rightNavigationButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
            moreImpl?()
        })
        
        var defaultThemes: [PresentationThemeReference] = []
        if presentationData.autoNightModeTriggered {
        } else {
            defaultThemes.append(contentsOf: [.builtin(.dayClassic), .builtin(.day)])
        }
        defaultThemes.append(contentsOf: [.builtin(.night), .builtin(.nightAccent)])
        
        let cloudThemes: [PresentationThemeReference] = cloudThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil)) }.filter { !removedThemeIndexes.contains($0.index) }
        
        var availableThemes = defaultThemes
        if defaultThemes.first(where: { $0.index == themeReference.index }) == nil && cloudThemes.first(where: { $0.index == themeReference.index }) == nil {
            availableThemes.append(themeReference)
        }
        availableThemes.append(contentsOf: cloudThemes)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: themeSettingsControllerEntries(presentationData: presentationData, presentationThemeSettings: settings, themeReference: themeReference, availableThemes: availableThemes, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ThemeSettingsControllerImpl(context: context, state: signal)
    controller.alwaysSynchronous = true
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
    }
    updateControllersImpl = { [weak controller] f in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.setViewControllers(f(navigationController.viewControllers), animated: true)
        }
    }
    presentInGlobalOverlayImpl = { [weak controller] c, a in
        controller?.presentInGlobalOverlay(c, with: a)
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    presentCrossfadeControllerImpl = { [weak controller] hasAccentColors in
        if let controller = controller, controller.isNodeLoaded, let navigationController = controller.navigationController as? NavigationController, navigationController.topViewController === controller {
            var topOffset: CGFloat?
            var bottomOffset: CGFloat?
            var leftOffset: CGFloat?
            var themeItemNode: ThemeSettingsThemeItemNode?
            var colorItemNode: ThemeSettingsAccentColorItemNode?
            
            var view: UIView?
            if #available(iOS 11.0, *) {
                view = controller.navigationController?.view
            }
            
            let controllerFrame = controller.view.convert(controller.view.bounds, to: controller.navigationController?.view)
            if controllerFrame.minX > 0.0 {
                leftOffset = controllerFrame.minX
            }
            if controllerFrame.minY > 100.0 {
                view = nil
            }
            
            controller.forEachItemNode { node in
                if let itemNode = node as? ItemListItemNode {
                    if let itemTag = itemNode.tag {
                        if itemTag.isEqual(to: ThemeSettingsEntryTag.theme) {
                            let frame = node.view.convert(node.view.bounds, to: controller.navigationController?.view)
                            topOffset = frame.minY
                            bottomOffset = frame.maxY
                            if let itemNode = node as? ThemeSettingsThemeItemNode {
                                themeItemNode = itemNode
                            }
                        } else if itemTag.isEqual(to: ThemeSettingsEntryTag.accentColor) && hasAccentColors {
                            let frame = node.view.convert(node.view.bounds, to: controller.navigationController?.view)
                            bottomOffset = frame.maxY
                            if let itemNode = node as? ThemeSettingsAccentColorItemNode {
                                colorItemNode = itemNode
                            }
                        }
                    }
                }
            }
            
            if let navigationBar = controller.navigationBar {
                if let offset = topOffset {
                    topOffset = max(offset, navigationBar.frame.maxY)
                } else {
                    topOffset = navigationBar.frame.maxY
                }
            }
            
            if view != nil {
                themeItemNode?.prepareCrossfadeTransition()
                colorItemNode?.prepareCrossfadeTransition()
            }
            
            let crossfadeController = ThemeSettingsCrossfadeController(view: view, topOffset: topOffset, bottomOffset: bottomOffset, leftOffset: leftOffset)
            crossfadeController.didAppear = { [weak themeItemNode, weak colorItemNode] in
                if view != nil {
                    themeItemNode?.animateCrossfadeTransition()
                    colorItemNode?.animateCrossfadeTransition()
                }
            }
            
            context.sharedContext.presentGlobalController(crossfadeController, nil)
        }
    }
    selectThemeImpl = { theme in
        guard let presentationTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: theme) else {
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
        
        let currentTheme = context.sharedContext.accountManager.transaction { transaction -> (PresentationThemeReference) in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
            if autoNightModeTriggered {
                return settings.automaticThemeSwitchSetting.theme
            } else {
                return settings.theme
            }
        }
        
        let _ = (combineLatest(resolvedWallpaper, currentTheme)
        |> map { resolvedWallpaper, currentTheme -> Bool in
            var updatedTheme = theme
            var currentThemeBaseIndex: Int64?
            if case let .cloud(info) = currentTheme, let settings = info.theme.settings {
                currentThemeBaseIndex = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)).index
            } else {
                currentThemeBaseIndex = currentTheme.index
            }
            
            var baseThemeIndex: Int64?
            var updatedThemeBaseIndex: Int64?
            if case let .cloud(info) = theme {
                updatedTheme = .cloud(PresentationCloudTheme(theme: info.theme, resolvedWallpaper: resolvedWallpaper))
                if let settings = info.theme.settings {
                    baseThemeIndex = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)).index
                    updatedThemeBaseIndex = baseThemeIndex
                }
            } else {
                updatedThemeBaseIndex = theme.index
            }

            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var updatedThemeSpecificAccentColors = current.themeSpecificAccentColors
                if let baseThemeIndex = baseThemeIndex {
                    updatedThemeSpecificAccentColors[baseThemeIndex] = PresentationThemeAccentColor(themeIndex: updatedTheme.index)
                }
                
                if autoNightModeTriggered {
                    var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                    updatedAutomaticThemeSwitchSetting.theme = updatedTheme
                    
                    return current.withUpdatedAutomaticThemeSwitchSetting(updatedAutomaticThemeSwitchSetting).withUpdatedThemeSpecificAccentColors(updatedThemeSpecificAccentColors)
                } else {
                    return current.withUpdatedTheme(updatedTheme).withUpdatedThemeSpecificAccentColors(updatedThemeSpecificAccentColors)
                }
            }).start()
            
            return currentThemeBaseIndex != updatedThemeBaseIndex
        } |> deliverOnMainQueue).start(next: { crossfadeAccentColors in
            presentCrossfadeControllerImpl?((cloudTheme == nil || cloudTheme?.settings != nil) && !crossfadeAccentColors)
        })
    }
    openAccentColorPickerImpl = { [weak controller] themeReference, create in
        if let _ = controller?.navigationController?.viewControllers.first(where: { $0 is ThemeAccentColorController }) {
            return
        }
        let controller = ThemeAccentColorController(context: context, mode: .colors(themeReference: themeReference, create: create))
        pushControllerImpl?(controller)
    }
    selectAccentColorImpl = { accentColor in
        var wallpaperSignal: Signal<TelegramWallpaper?, NoError> = .single(nil)
        if let colorWallpaper = accentColor?.wallpaper, case let .file(file) = colorWallpaper {
            wallpaperSignal = cachedWallpaper(account: context.account, slug: file.slug, settings: colorWallpaper.settings)
            |> mapToSignal { cachedWallpaper in
                if let wallpaper = cachedWallpaper?.wallpaper, case let .file(file) = wallpaper {
                    let resource = file.file.resource
                    let representation = CachedPatternWallpaperRepresentation(color: file.settings.color ?? 0xd6e2ee, bottomColor: file.settings.bottomColor, intensity: file.settings.intensity ?? 50, rotation: file.settings.rotation)
                            
                    let _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .wallpaper(wallpaper: .slug(file.slug), resource: file.file.resource)).start()

                    let _ = (context.account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: false, fetch: true)
                    |> filter({ $0.complete })).start(next: { data in
                        if data.complete, let path = context.account.postbox.mediaBox.completedResourcePath(resource) {
                            if let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                                context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: maybeData, synchronous: true)
                            }
                            if let maybeData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: .mappedRead) {
                                context.sharedContext.accountManager.mediaBox.storeCachedResourceRepresentation(resource, representation: representation, data: maybeData)
                            }
                        }
                    })
                    return .single(wallpaper)
    
                } else {
                    return .single(nil)
                }
            }
        }
        
        let _ = (wallpaperSignal
        |> deliverOnMainQueue).start(next: { presetWallpaper in
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
                var currentTheme = current.theme
                if autoNightModeTriggered {
                    currentTheme = current.automaticThemeSwitchSetting.theme
                }
                
                let generalThemeReference: PresentationThemeReference
                if case let .cloud(theme) = currentTheme, let settings = theme.theme.settings {
                    generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme))
                } else {
                    generalThemeReference = currentTheme
                }
                
                currentTheme = generalThemeReference
                var updatedTheme = current.theme
                var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                
                if autoNightModeTriggered {
                    updatedAutomaticThemeSwitchSetting.theme = generalThemeReference
                } else {
                    updatedTheme = generalThemeReference
                }
                
                guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: generalThemeReference, accentColor: accentColor?.color, wallpaper: presetWallpaper) else {
                    return current
                }
                
                var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                var themeSpecificAccentColors = current.themeSpecificAccentColors
                themeSpecificAccentColors[generalThemeReference.index] = accentColor?.withUpdatedWallpaper(presetWallpaper)
                
                if case let .builtin(theme) = generalThemeReference {
                    let index = coloredThemeIndex(reference: currentTheme, accentColor: accentColor)
                    if let wallpaper = current.themeSpecificChatWallpapers[index] {
                        if wallpaper.isColorOrGradient || wallpaper.isPattern || wallpaper.isBuiltin {
                            themeSpecificChatWallpapers[index] = presetWallpaper
                        }
                    } else {
                        themeSpecificChatWallpapers[index] = presetWallpaper
                    }
                }
                
                return PresentationThemeSettings(theme: updatedTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, automaticThemeSwitchSetting: updatedAutomaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            }).start()
            
            presentCrossfadeControllerImpl?(true)
        })
    }
    moreImpl = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_CreateTheme, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            let _ = (context.sharedContext.accountManager.transaction { transaction -> PresentationThemeReference in
                let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
                
                let themeReference: PresentationThemeReference
                let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
                if autoNightModeTriggered {
                    themeReference = settings.automaticThemeSwitchSetting.theme
                } else {
                    themeReference = settings.theme
                }
                
                return themeReference
            }
            |> deliverOnMainQueue).start(next: { themeReference in
                let controller = editThemeController(context: context, mode: .create(nil, nil), navigateToChat: { peerId in
                    if let navigationController = getNavigationControllerImpl?() {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                    }
                })
                pushControllerImpl?(controller)
            })
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }
    return controller
}

public final class ThemeSettingsCrossfadeController: ViewController {
    private var snapshotView: UIView?
    
    private var topSnapshotView: UIView?
    private var bottomSnapshotView: UIView?
    private var sideSnapshotView: UIView?
    
    fileprivate var didAppear: (() -> Void)?
    
    public init(view: UIView? = nil, topOffset: CGFloat? = nil, bottomOffset: CGFloat? = nil, leftOffset: CGFloat? = nil) {
        if let view = view {
            if var leftOffset = leftOffset {
                leftOffset += UIScreenPixel
                
                if let view = view.snapshotView(afterScreenUpdates: false) {
                    let clipView = UIView()
                    clipView.clipsToBounds = true
                    clipView.addSubview(view)
                    
                    view.clipsToBounds = true
                    view.contentMode = .topLeft
                    
                    if let topOffset = topOffset, let bottomOffset = bottomOffset {
                        var frame = view.frame
                        frame.origin.y = topOffset
                        frame.size.width = leftOffset
                        frame.size.height = bottomOffset - topOffset
                        clipView.frame = frame
                        
                        frame = view.frame
                        frame.origin.y = -topOffset
                        frame.size.width = leftOffset
                        frame.size.height = bottomOffset
                        view.frame = frame
                    }
                
                    self.sideSnapshotView = clipView
                }
            }
            
            if let view = view.snapshotView(afterScreenUpdates: false) {
                view.clipsToBounds = true
                view.contentMode = .top
                if let topOffset = topOffset {
                    var frame = view.frame
                    frame.size.height = topOffset
                    view.frame = frame
                }
                self.topSnapshotView = view
            }
            
            if let view = view.snapshotView(afterScreenUpdates: false) {
                view.clipsToBounds = true
                view.contentMode = .bottom
                if let bottomOffset = bottomOffset {
                    var frame = view.frame
                    frame.origin.y = bottomOffset
                    frame.size.height -= bottomOffset
                    view.frame = frame
                }
                self.bottomSnapshotView = view
            }
        } else {
            self.snapshotView = UIScreen.main.snapshotView(afterScreenUpdates: false)
        }
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
        if let topSnapshotView = self.topSnapshotView {
            self.displayNode.view.addSubview(topSnapshotView)
        }
        if let bottomSnapshotView = self.bottomSnapshotView {
            self.displayNode.view.addSubview(bottomSnapshotView)
        }
        if let sideSnapshotView = self.sideSnapshotView {
             self.displayNode.view.addSubview(sideSnapshotView)
         }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
        
        self.didAppear?()
    }
}
