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
    let colorContextAction: (PresentationThemeReference, PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (PresentationThemeReference) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, selectAccentColor: @escaping (PresentationThemeAccentColor?) -> Void, openAccentColorPicker: @escaping (PresentationThemeReference, Bool) -> Void, openAutoNightTheme: @escaping () -> Void, openTextSize: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void, editTheme: @escaping (PresentationCloudTheme) -> Void, themeContextAction: @escaping (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void, colorContextAction: @escaping (PresentationThemeReference, PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void) {
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
    case chatPreview(PresentationTheme, PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, [ChatPreviewMessageItem])
    case wallpaper(PresentationTheme, String)
    case accentColor(PresentationTheme, PresentationThemeReference, PresentationThemeCustomColors?, PresentationThemeAccentColor?)
    case autoNightTheme(PresentationTheme, String, String)
    case textSize(PresentationTheme, String, String)
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], [Int64: TelegramWallpaper], PresentationThemeAccentColor?)
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
            case let .accentColor(lhsTheme, lhsCurrentTheme, lhsCustomColors, lhsColor):
                if case let .accentColor(rhsTheme, rhsCurrentTheme, rhsCustomColors, rhsColor) = rhs, lhsTheme === rhsTheme, lhsCurrentTheme == rhsCurrentTheme, lhsCustomColors == rhsCustomColors, lhsColor == rhsColor {
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
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsThemeSpecificChatWallpapers, lhsCurrentColor):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsThemeSpecificChatWallpapers, rhsCurrentColor) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsThemeSpecificChatWallpapers == rhsThemeSpecificChatWallpapers, lhsCurrentColor == rhsCurrentColor {
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
            case let .accentColor(theme, currentTheme, customColors, color):
                var colorItems: [ThemeSettingsAccentColor] = []
                var defaultColor: PresentationThemeAccentColor? = PresentationThemeAccentColor(baseColor: .blue)
                var colors = PresentationThemeBaseColor.allCases
                colors = colors.filter { $0 != .custom && $0 != .preset }
                if case let .builtin(name) = currentTheme {
                    if name == .dayClassic {
                        colorItems.append(.default)
                        defaultColor = nil
                        
                        let createPaper: (String, Int32, Int32?, Int32?, Int32?) -> TelegramWallpaper = { slug, topColor, bottomColor, intensity, rotation in
                           return TelegramWallpaper.file(id: 0, accessHash: 0, isCreator: false, isDefault: true, isPattern: true, isDark: false, slug: slug, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "", size: nil, attributes: []), settings: WallpaperSettings(blur: false, motion: false, color: topColor, bottomColor: bottomColor, intensity: intensity ?? 50, rotation: rotation))
                        }
                        
                        colorItems.append(.preset(PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0x7e5fe5, bubbleColors: (0xf5e2ff, nil), wallpaper: createPaper("nQcFYJe1mFIBAAAAcI95wtIK0fk", 0xfcccf4, 0xae85f0, 54, nil)))) // amethyst dust
                        colorItems.append(.preset(PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0xff5fa9, bubbleColors: (0xfff4d7, nil), wallpaper: createPaper("51nnTjx8mFIBAAAAaFGJsMIvWkk", 0xf6b594, 0xebf6cd, 46, 45)))) // bubbly
                        colorItems.append(.preset(PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0x199972, bubbleColors: (0xfffec7, nil), wallpaper: createPaper("fqv01SQemVIBAAAApND8LDRUhRU", 0xc1e7cb, nil, 50, nil)))) // downtown
                        colorItems.append(.preset(PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0x5a9e29, bubbleColors: (0xdcf8c6, nil), wallpaper: createPaper("R3j69wKskFIBAAAAoUdXWCKMzCM", 0xede6dd, nil, 50, nil)))) // green
                        colorItems.append(.preset(PresentationThemeAccentColor(index: 105, baseColor: .preset, accentColor: 0x009eee, bubbleColors: (0x94fff9, 0xccffc7), wallpaper: createPaper("p-pXcflrmFIBAAAAvXYQk-mCwZU", 0xffbca6, 0xff63bd, 57, 225)))) // blue lolly
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
                let currentColor = color ?? defaultColor
                colorItems.append(contentsOf: colors.map { .color($0) })
                
                if let customColors = customColors {
                    colorItems.append(contentsOf: customColors.colors.map { .custom($0) })
                } else {
                    if let currentColor = currentColor, currentColor.baseColor == .custom {
                        colorItems.append(.custom(currentColor))
                    }
                }
                
                return ThemeSettingsAccentColorItem(theme: theme, sectionId: self.section, themeReference: currentTheme, colors: colorItems, currentColor: currentColor, updated: { color in
                    arguments.selectAccentColor(color)
                }, contextAction: { theme, color, node, gesture in
                     arguments.colorContextAction(theme, color, node, gesture)
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
            case let .themeItem(theme, strings, themes, currentTheme, themeSpecificAccentColors, themeSpecificChatWallpapers, _):
                return ThemeSettingsThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, displayUnsupported: true, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, currentTheme: currentTheme, updatedTheme: { theme in
                    if case let .cloud(theme) = theme, theme.theme.file == nil {
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
    entries.append(.chatPreview(presentationData.theme, presentationData.theme, presentationData.chatWallpaper, presentationData.fontSize, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (presentationData.strings.Appearance_PreviewReplyAuthor, presentationData.strings.Appearance_PreviewReplyText), text: presentationData.strings.Appearance_PreviewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: presentationData.strings.Appearance_PreviewOutgoingText)]))
    
    var wallpaper: TelegramWallpaper?
    if let accentColor = presentationThemeSettings.themeSpecificAccentColors[themeReference.index] {
        wallpaper = presentationThemeSettings.themeSpecificChatWallpapers[themeReference.index &+ Int64(accentColor.index)]
    }
    
    entries.append(.themeItem(presentationData.theme, presentationData.strings, availableThemes, themeReference, presentationThemeSettings.themeSpecificAccentColors, presentationThemeSettings.themeSpecificChatWallpapers, presentationThemeSettings.themeSpecificAccentColors[themeReference.index]))
    
    if case let .builtin(theme) = themeReference {
        entries.append(.accentColor(presentationData.theme, themeReference, presentationThemeSettings.themeSpecificCustomColors[themeReference.index], presentationThemeSettings.themeSpecificAccentColors[themeReference.index]))
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
        textSizeValue = "\(Int(presentationThemeSettings.fontSize.baseDisplaySize))pt"
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
    var presentCrossfadeControllerImpl: (() -> Void)?
    
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
    }, selectFontSize: { fontSize in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedFontSize(fontSize)
        }).start()
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, selectAccentColor: { color in
        var wallpaperSignal: Signal<TelegramWallpaper?, NoError> = .single(nil)
        if let colorWallpaper = color?.wallpaper, case let .file(file) = colorWallpaper {
            wallpaperSignal = cachedWallpaper(account: context.account, slug: file.slug, settings: colorWallpaper.settings)
            |> mapToSignal { cachedWallpaper in
                if let wallpaper = cachedWallpaper?.wallpaper, case let .file(file) = wallpaper {
                    let resource = file.file.resource
                    let representation = CachedPatternWallpaperRepresentation(color: file.settings.color ?? 0xd6e2ee, bottomColor: file.settings.bottomColor, intensity: file.settings.intensity ?? 50, rotation: file.settings.rotation)
                    
                    var data: Data?
                    if let path = context.account.postbox.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    } else if let path = context.sharedContext.accountManager.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    }
                    
                    if let data = data {
                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        return (context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: true, fetch: true)
                        |> filter({ $0.complete })
                        |> take(1)
                        |> mapToSignal { _ -> Signal<TelegramWallpaper?, NoError> in
                            return .single(wallpaper)
                        })
                    } else {
                        return .single(nil)
                    }
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

                guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: currentTheme, accentColor: color?.color) else {
                    return current
                }
                
                var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                var themeSpecificAccentColors = current.themeSpecificAccentColors
                themeSpecificAccentColors[currentTheme.index] = color
                
                if case let .builtin(theme) = currentTheme {
                    if let wallpaper = presetWallpaper, let color = color {
                        themeSpecificChatWallpapers[currentTheme.index &+ Int64(color.index)] = wallpaper
                    } else if let wallpaper = current.themeSpecificChatWallpapers[currentTheme.index], wallpaper.isColorOrGradient || wallpaper.isPattern || wallpaper.isBuiltin {
                        themeSpecificChatWallpapers[currentTheme.index] = nil
                        if let color = color {
                            themeSpecificChatWallpapers[currentTheme.index &+ Int64(color.index)] = nil
                        }
                    }
                }
                
                return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificCustomColors: current.themeSpecificCustomColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
            }).start()
        })
    }, openAccentColorPicker: { themeReference, create in
        let controller = ThemeAccentColorController(context: context, mode: .colors(themeReference: themeReference, create: create))
        pushControllerImpl?(controller)
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
                wallpaper = settings.themeSpecificChatWallpapers[reference.index &+ Int64(accentColor.index)]
            }
            if wallpaper == nil {
                settings.themeSpecificChatWallpapers[reference.index]
            }
            return (accentColor, wallpaper)
        } |> map { accentColor, wallpaper in
            return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor?.color, bubbleColors: accentColor?.customBubbleColors), wallpaper)
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
                            let controller = ThemeAccentColorController(context: context, mode: .edit(theme: theme, wallpaper: wallpaper, defaultThemeReference: nil, create: true, completion: { result in
                                let controller = editThemeController(context: context, mode: .create(result), navigateToChat: { peerId in
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
    }, colorContextAction: { reference, accentColor, node, gesture in
        guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor?.color, bubbleColors: accentColor?.customBubbleColors) else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        let themeController = ThemePreviewController(context: context, previewTheme: theme, source: .settings(reference, nil))
        var items: [ContextMenuItem] = []

        if let accentColor = accentColor, accentColor.baseColor == .custom {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_RemoveThemeColor, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { c, f in
                c.dismiss(completion: {
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_RemoveThemeColorConfirmation, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                            let themeReference: PresentationThemeReference
                            if presentationData.autoNightModeTriggered {
                                themeReference = current.automaticThemeSwitchSetting.theme
                            } else {
                                themeReference = current.theme
                            }
                            
                            var themeSpecificAccentColors = current.themeSpecificAccentColors
                            var themeSpecificCustomColors = current.themeSpecificCustomColors
                            var customColors = themeSpecificCustomColors[themeReference.index]?.colors ?? []
                            
                            var updatedAccentColor: PresentationThemeAccentColor
                            if let index = customColors.firstIndex(where: { $0.index == accentColor.index }) {
                                if index > 0 {
                                    updatedAccentColor = customColors[index - 1]
                                } else {
                                    if case let .builtin(theme) = themeReference {
                                        let updatedBaseColor: PresentationThemeBaseColor
                                        switch theme {
                                            case .dayClassic, .nightAccent:
                                                updatedBaseColor = .gray
                                            case .day:
                                                updatedBaseColor = .black
                                            case .night:
                                                updatedBaseColor = .white
                                        }
                                        updatedAccentColor = PresentationThemeAccentColor(baseColor: updatedBaseColor)
                                    } else {
                                        updatedAccentColor = PresentationThemeAccentColor(baseColor: .blue)
                                    }
                                }
                                customColors.remove(at: index)
                            } else {
                                updatedAccentColor = PresentationThemeAccentColor(baseColor: .blue)
                            }
                            
                            themeSpecificAccentColors[themeReference.index] = updatedAccentColor
                            themeSpecificCustomColors[themeReference.index] = PresentationThemeCustomColors(colors: customColors)
                            return current.withUpdatedThemeSpecificCustomColors(themeSpecificCustomColors).withUpdatedThemeSpecificAccentColors(themeSpecificAccentColors)
                        }).start()
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
        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: themeController, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
        presentInGlobalOverlayImpl?(contextController, nil)
    })
    
    let previousThemeReference = Atomic<PresentationThemeReference?>(value: nil)
    let previousAccentColor = Atomic<PresentationThemeAccentColor?>(value: nil)
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]), cloudThemes.get(), availableAppIcons, currentAppIconName.get())
    |> map { presentationData, sharedData, cloudThemes, availableAppIcons, currentAppIconName -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        
        let fontSize = presentationData.fontSize
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
        
        let cloudThemes: [PresentationThemeReference] = cloudThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil)) }
        
        var availableThemes = defaultThemes
        if defaultThemes.first(where: { $0.index == themeReference.index }) == nil && cloudThemes.first(where: { $0.index == themeReference.index }) == nil {
            availableThemes.append(themeReference)
        }
        availableThemes.append(contentsOf: cloudThemes)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: themeSettingsControllerEntries(presentationData: presentationData, presentationThemeSettings: settings, themeReference: themeReference, availableThemes: availableThemes, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
        
        let previousThemeIndex = previousThemeReference.swap(themeReference)?.index
        let previousAccentColor = previousAccentColor.swap(accentColor)
        if previousThemeIndex != nil && (previousThemeIndex != themeReference.index || previousAccentColor != accentColor) {
            presentCrossfadeControllerImpl?()
        }
                
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
    presentCrossfadeControllerImpl = { [weak controller] in
        if let controller = controller, controller.isNodeLoaded, let navigationController = controller.navigationController as? NavigationController, navigationController.topViewController === controller {
            var topOffset: CGFloat?
            var bottomOffset: CGFloat?
            var themeItemNode: ThemeSettingsThemeItemNode?
            var colorItemNode: ThemeSettingsAccentColorItemNode?
            
            controller.forEachItemNode { node in
                if let itemNode = node as? ItemListItemNode {
                    if let itemTag = itemNode.tag {
                        if itemTag.isEqual(to: ThemeSettingsEntryTag.theme) {
                            let frame = node.convert(node.bounds, to: controller.displayNode)
                            topOffset = frame.minY
                            bottomOffset = frame.maxY
                            if let itemNode = node as? ThemeSettingsThemeItemNode {
                                themeItemNode = itemNode
                            }
                        } else if itemTag.isEqual(to: ThemeSettingsEntryTag.accentColor) {
                            let frame = node.convert(node.bounds, to: controller.displayNode)
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
            
            themeItemNode?.prepareCrossfadeTransition()
            colorItemNode?.prepareCrossfadeTransition()
            
            let crossfadeController = ThemeSettingsCrossfadeController(view: controller.view, topOffset: topOffset, bottomOffset: bottomOffset)
            crossfadeController.didAppear = { [weak themeItemNode, weak colorItemNode] in
                themeItemNode?.animateCrossfadeTransition()
                colorItemNode?.animateCrossfadeTransition()
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
        
        let _ = (resolvedWallpaper
        |> mapToSignal { resolvedWallpaper -> Signal<Void, NoError> in
            var updatedTheme = theme
            if case let .cloud(info) = theme {
                updatedTheme = .cloud(PresentationCloudTheme(theme: info.theme, resolvedWallpaper: resolvedWallpaper))
            }
            return updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                if autoNightModeTriggered {
                    var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                    updatedAutomaticThemeSwitchSetting.theme = updatedTheme
                    return current.withUpdatedAutomaticThemeSwitchSetting(updatedAutomaticThemeSwitchSetting)
                } else {
                    return current.withUpdatedTheme(updatedTheme)
                }
            })
        }).start()
    }
    moreImpl = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_CreateTheme, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            let _ = (context.sharedContext.accountManager.transaction { transaction -> PresentationThemeReference? in
                let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings) as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
                
                var themeReference: PresentationThemeReference?
                let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
                if autoNightModeTriggered {
                    themeReference = settings.automaticThemeSwitchSetting.theme
                } else {
                    themeReference = settings.theme
                }
                
                if let themeReference = themeReference, case .builtin = themeReference {
                } else {
                    themeReference = nil
                }
                return themeReference
            }
            |> deliverOnMainQueue).start(next: { themeReference in
                let controller = ThemeAccentColorController(context: context, mode: .edit(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, defaultThemeReference: themeReference, create: true, completion: { result in
                    let controller = editThemeController(context: context, mode: .create(result), navigateToChat: { peerId in
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
    
    fileprivate var didAppear: (() -> Void)?
    
    public init(view: UIView? = nil, topOffset: CGFloat? = nil, bottomOffset: CGFloat? = nil) {
        if let view = view {
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
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
        
        self.didAppear?()
    }
}
