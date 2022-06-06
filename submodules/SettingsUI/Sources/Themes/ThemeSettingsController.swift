import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
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
import UndoUI
import PremiumUI

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
            if let emoticon = theme.theme.emoticon {
                name = emoticon
            } else {
                name = theme.theme.title
            }
    }
    return name
}

private final class ThemeSettingsControllerArguments {
    let context: AccountContext
    let selectTheme: (PresentationThemeReference) -> Void
    let openThemeSettings: () -> Void
    let openWallpaperSettings: () -> Void
    let selectAccentColor: (PresentationThemeAccentColor?) -> Void
    let openAccentColorPicker: (PresentationThemeReference, Bool) -> Void
    let toggleNightTheme: (Bool) -> Void
    let openAutoNightTheme: () -> Void
    let openTextSize: () -> Void
    let openBubbleSettings: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (PresentationAppIcon) -> Void
    let editTheme: (PresentationCloudTheme) -> Void
    let themeContextAction: (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void
    let colorContextAction: (Bool, PresentationThemeReference, ThemeSettingsColorOption?, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (PresentationThemeReference) -> Void, openThemeSettings: @escaping () -> Void, openWallpaperSettings: @escaping () -> Void, selectAccentColor: @escaping (PresentationThemeAccentColor?) -> Void, openAccentColorPicker: @escaping (PresentationThemeReference, Bool) -> Void, toggleNightTheme: @escaping (Bool) -> Void, openAutoNightTheme: @escaping () -> Void, openTextSize: @escaping () -> Void, openBubbleSettings: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (PresentationAppIcon) -> Void, editTheme: @escaping (PresentationCloudTheme) -> Void, themeContextAction: @escaping (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void, colorContextAction: @escaping (Bool, PresentationThemeReference, ThemeSettingsColorOption?, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.selectTheme = selectTheme
        self.openThemeSettings = openThemeSettings
        self.openWallpaperSettings = openWallpaperSettings
        self.selectAccentColor = selectAccentColor
        self.openAccentColorPicker = openAccentColorPicker
        self.toggleNightTheme = toggleNightTheme
        self.openAutoNightTheme = openAutoNightTheme
        self.openTextSize = openTextSize
        self.openBubbleSettings = openBubbleSettings
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
    case nightMode
    case message
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
    case chatPreview(PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationChatBubbleCorners, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, [ChatPreviewMessageItem])
    case themes(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, Bool, [String: [StickerPackItem]], [Int64: PresentationThemeAccentColor], [Int64: TelegramWallpaper])
    case chatTheme(PresentationTheme, String)
    case wallpaper(PresentationTheme, String)
    case autoNight(PresentationTheme, String, Bool, Bool)
    case autoNightTheme(PresentationTheme, String, String)
    case textSize(PresentationTheme, String, String)
    case bubbleSettings(PresentationTheme, String, String)
    case iconHeader(PresentationTheme, String)
    case iconItem(PresentationTheme, PresentationStrings, [PresentationAppIcon], Bool, String?)
    case otherHeader(PresentationTheme, String)
    case largeEmoji(PresentationTheme, String, Bool)
    case animations(PresentationTheme, String, Bool)
    case animationsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .themeListHeader, .chatPreview, .themes, .chatTheme, .wallpaper:
                return ThemeSettingsControllerSection.chatPreview.rawValue
            case .autoNight, .autoNightTheme:
                return ThemeSettingsControllerSection.nightMode.rawValue
            case .textSize, .bubbleSettings:
                return ThemeSettingsControllerSection.message.rawValue
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
            case .themes:
                return 2
            case .chatTheme:
                return 3
            case .wallpaper:
                return 4
            case .autoNight:
                return 5
            case .autoNightTheme:
                return 6
            case .textSize:
                return 7
            case .bubbleSettings:
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
            case let .chatPreview(lhsTheme, lhsWallpaper, lhsFontSize, lhsChatBubbleCorners, lhsStrings, lhsTimeFormat, lhsNameOrder, lhsItems):
                if case let .chatPreview(rhsTheme, rhsWallpaper, rhsFontSize, rhsChatBubbleCorners, rhsStrings, rhsTimeFormat, rhsNameOrder, rhsItems) = rhs, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsChatBubbleCorners == rhsChatBubbleCorners, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder, lhsItems == rhsItems {
                    return true
                } else {
                    return false
                }
            case let .themes(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme, lhsNightMode, lhsAnimatedEmojiStickers, lhsThemeAccentColors, lhsThemeSpecificChatWallpapers):
                if case let .themes(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme, rhsNightMode, rhsAnimatedEmojiStickers, rhsThemeAccentColors, rhsThemeSpecificChatWallpapers) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme, lhsNightMode == rhsNightMode, lhsAnimatedEmojiStickers == rhsAnimatedEmojiStickers, lhsThemeAccentColors == rhsThemeAccentColors, lhsThemeSpecificChatWallpapers == rhsThemeSpecificChatWallpapers {
                    return true
                } else {
                    return false
                }
            case let .chatTheme(lhsTheme, lhsText):
                if case let .chatTheme(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .autoNight(lhsTheme, lhsText, lhsValue, lhsEnabled):
                if case let .autoNight(rhsTheme, rhsText, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
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
            case let .bubbleSettings(lhsTheme, lhsText, lhsValue):
                if case let .bubbleSettings(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .iconHeader(lhsTheme, lhsText):
                if case let .iconHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .iconItem(lhsTheme, lhsStrings, lhsIcons, lhsIsPremium, lhsValue):
                if case let .iconItem(rhsTheme, rhsStrings, rhsIcons, rhsIsPremium, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsIcons == rhsIcons, lhsIsPremium == rhsIsPremium, lhsValue == rhsValue {
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
            case let .chatPreview(theme, wallpaper, fontSize, chatBubbleCorners, strings, dateTimeFormat, nameDisplayOrder, items):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: theme, strings: strings, sectionId: self.section, fontSize: fontSize, chatBubbleCorners: chatBubbleCorners, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, messageItems: items)
            case let .themes(theme, strings, chatThemes, currentTheme, nightMode, animatedEmojiStickers, themeSpecificAccentColors, themeSpecificChatWallpapers):
                return ThemeCarouselThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: chatThemes, animatedEmojiStickers: animatedEmojiStickers, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, nightMode: nightMode, currentTheme: currentTheme, updatedTheme: { theme in
                arguments.selectTheme(theme)
            }, contextAction: { theme, node, gesture in
                arguments.themeContextAction(false, theme, node, gesture)
            }, tag: ThemeSettingsEntryTag.theme)
            case let .chatTheme(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openThemeSettings()
                })
            case let .wallpaper(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openWallpaperSettings()
                })
            case let .autoNight(_, title, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleNightTheme(value)
                }, tag: nil)
            case let .autoNightTheme(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAutoNightTheme()
                })
            case let .textSize(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openTextSize()
                })
            case let .bubbleSettings(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openBubbleSettings()
                })
            case let .themeListHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .iconHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .iconItem(theme, strings, icons, isPremium, value):
                return ThemeSettingsAppIconItem(theme: theme, strings: strings, sectionId: self.section, icons: icons, isPremium: isPremium, currentIconName: value, updated: { icon in
                    arguments.selectAppIcon(icon)
                })
            case let .otherHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .largeEmoji(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleLargeEmoji(value)
                }, tag: ThemeSettingsEntryTag.largeEmoji)
            case let .animations(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.disableAnimations(value)
                }, tag: ThemeSettingsEntryTag.animations)
            case let .animationsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func themeSettingsControllerEntries(presentationData: PresentationData, presentationThemeSettings: PresentationThemeSettings, themeReference: PresentationThemeReference, availableThemes: [PresentationThemeReference], availableAppIcons: [PresentationAppIcon], currentAppIconName: String?, isPremium: Bool, chatThemes: [PresentationThemeReference], animatedEmojiStickers: [String: [StickerPackItem]]) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    let strings = presentationData.strings
    let title = presentationData.autoNightModeTriggered ? strings.Appearance_ColorThemeNight.uppercased() : strings.Appearance_ColorTheme.uppercased()
    entries.append(.themeListHeader(presentationData.theme, title))
    entries.append(.chatPreview(presentationData.theme, presentationData.chatWallpaper, presentationData.chatFontSize, presentationData.chatBubbleCorners, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (presentationData.strings.Appearance_PreviewReplyAuthor, presentationData.strings.Appearance_PreviewReplyText), text: presentationData.strings.Appearance_PreviewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: presentationData.strings.Appearance_PreviewOutgoingText)]))
    
    entries.append(.themes(presentationData.theme, presentationData.strings, chatThemes, themeReference, presentationThemeSettings.automaticThemeSwitchSetting.force || presentationData.autoNightModeTriggered, animatedEmojiStickers, presentationThemeSettings.themeSpecificAccentColors, presentationThemeSettings.themeSpecificChatWallpapers))
    entries.append(.chatTheme(presentationData.theme, strings.Settings_ChatThemes))
    entries.append(.wallpaper(presentationData.theme, strings.Settings_ChatBackground))
    
    entries.append(.autoNight(presentationData.theme, strings.Appearance_NightTheme, presentationThemeSettings.automaticThemeSwitchSetting.force, !presentationData.autoNightModeTriggered || presentationThemeSettings.automaticThemeSwitchSetting.force))
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
    entries.append(.bubbleSettings(presentationData.theme, strings.Appearance_BubbleCornersSetting, ""))
    
    if !availableAppIcons.isEmpty {
        entries.append(.iconHeader(presentationData.theme, strings.Appearance_AppIcon.uppercased()))
        entries.append(.iconItem(presentationData.theme, presentationData.strings, availableAppIcons, isPremium, currentAppIconName))
    }
    
    entries.append(.otherHeader(presentationData.theme, strings.Appearance_Other.uppercased()))
    entries.append(.largeEmoji(presentationData.theme, strings.Appearance_LargeEmoji, presentationData.largeEmoji))
    entries.append(.animations(presentationData.theme, strings.Appearance_ReduceMotion, presentationData.reduceMotion))
    entries.append(.animationsInfo(presentationData.theme, strings.Appearance_ReduceMotionInfo))
    
    return entries
}

public protocol ThemeSettingsController {
    
}

private final class ThemeSettingsControllerImpl: ItemListController, ThemeSettingsController {
}

public func themeSettingsController(context: AccountContext, focusOnItemTag: ThemeSettingsEntryTag? = nil) -> ViewController {
    #if DEBUG
    BuiltinWallpaperData.generate(account: context.account)
    #endif

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var updateControllersImpl: ((([UIViewController]) -> [UIViewController]) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    var presentCrossfadeControllerImpl: ((Bool) -> Void)?
    
    var selectThemeImpl: ((PresentationThemeReference) -> Void)?
    var selectAccentColorImpl: ((PresentationThemeAccentColor?) -> Void)?
    var openAccentColorPickerImpl: ((PresentationThemeReference, Bool) -> Void)?
    
    let _ = telegramWallpapers(postbox: context.account.postbox, network: context.account.network).start()
    
    let currentAppIcon: PresentationAppIcon?
    var appIcons = context.sharedContext.applicationBindings.getAvailableAlternateIcons()
    if let alternateIconName = context.sharedContext.applicationBindings.getAlternateIconName() {
        currentAppIcon = appIcons.filter { $0.name == alternateIconName }.first
    } else {
        currentAppIcon = appIcons.filter { $0.isDefault }.first
    }
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    if premiumConfiguration.isPremiumDisabled {
        appIcons = appIcons.filter { !$0.isPremium } 
    }
    
    let availableAppIcons: Signal<[PresentationAppIcon], NoError> = .single(appIcons)
    let currentAppIconName = ValuePromise<String?>()
    currentAppIconName.set(currentAppIcon?.name ?? "Blue")
    
    let cloudThemes = Promise<[TelegramTheme]>()
    let updatedCloudThemes = telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
    cloudThemes.set(updatedCloudThemes)
    
    let removedThemeIndexesPromise = Promise<Set<Int64>>(Set())
    let removedThemeIndexes = Atomic<Set<Int64>>(value: Set())
    
    let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
    |> map { animatedEmoji -> [String: [StickerPackItem]] in
        var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
        switch animatedEmoji {
            case let .result(_, items, _):
                for item in items {
                    if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                        animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                        let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                        if animatedEmojiStickers[strippedEmoji] == nil {
                            animatedEmojiStickers[strippedEmoji] = [item]
                        }
                    }
                }
            default:
                break
        }
        return animatedEmojiStickers
    }
    
    let arguments = ThemeSettingsControllerArguments(context: context, selectTheme: { theme in
        selectThemeImpl?(theme)
    }, openThemeSettings: {
        pushControllerImpl?(themePickerController(context: context))
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(context: context))
    }, selectAccentColor: { accentColor in
        selectAccentColorImpl?(accentColor)
    }, openAccentColorPicker: { themeReference, create in
        openAccentColorPickerImpl?(themeReference, create)
    }, toggleNightTheme: { value in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            var current = current
            current.automaticThemeSwitchSetting.force = value
            return current
        }).start()
        presentCrossfadeControllerImpl?(true)
    }, openAutoNightTheme: {
        pushControllerImpl?(themeAutoNightSettingsController(context: context))
    }, openTextSize: {
        let _ = (context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            let settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
            pushControllerImpl?(TextSizeSelectionController(context: context, presentationThemeSettings: settings))
        })
    }, openBubbleSettings: {
        let _ = (context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            let settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
            pushControllerImpl?(BubbleSettingsController(context: context, presentationThemeSettings: settings))
        })
    }, toggleLargeEmoji: { largeEmoji in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedLargeEmoji(largeEmoji)
        }).start()
    }, disableAnimations: { reduceMotion in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedReduceMotion(reduceMotion)
        }).start()
    }, selectAppIcon: { icon in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> deliverOnMainQueue).start(next: { peer in
            let isPremium = peer?.isPremium ?? false
            if icon.isPremium && !isPremium {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumDemoScreen(context: context, subject: .appIcons, source: .other, action: {
                    let controller = PremiumIntroScreen(context: context, source: .appIcons)
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                pushControllerImpl?(controller)
            } else {
                currentAppIconName.set(icon.name)
                context.sharedContext.applicationBindings.requestSetAlternateIconName(icon.name, { _ in
                })
            }
        })
    }, editTheme: { theme in
        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
            if let navigationController = getNavigationControllerImpl?() {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
            }
        })
        pushControllerImpl?(controller)
    }, themeContextAction: { isCurrent, reference, node, gesture in
        let _ = (context.sharedContext.accountManager.transaction { transaction -> (PresentationThemeAccentColor?, TelegramWallpaper?) in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings)?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
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
                let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor?.color, bubbleColors: accentColor?.customBubbleColors ?? [], wallpaper: accentColor?.wallpaper)
                effectiveWallpaper = theme?.chat.defaultWallpaper ?? .builtin(WallpaperSettings())
            }
            return (accentColor, effectiveWallpaper)
        }
        |> mapToSignal { accentColor, wallpaper -> Signal<(PresentationThemeAccentColor?, TelegramWallpaper), NoError> in
            if case let .file(file) = wallpaper, file.id == 0 {
                return cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                |> map { cachedWallpaper in
                    if let wallpaper = cachedWallpaper?.wallpaper, case .file = wallpaper {
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
                return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: accentColor?.color, bubbleColors: accentColor?.customBubbleColors ?? [], serviceBackgroundColor: serviceBackgroundColor), wallpaper)
            }
        }
        |> deliverOnMainQueue).start(next: { theme, wallpaper in
            guard let theme = theme else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings
            let themeController = ThemePreviewController(context: context, previewTheme: theme, source: .settings(reference, wallpaper, true))
            var items: [ContextMenuItem] = []
            
            if case let .cloud(theme) = reference {
                if theme.theme.isCreator {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_EditTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
                            if let navigationController = getNavigationControllerImpl?() {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
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
                            let controller = ThemeAccentColorController(context: context, mode: .edit(settings: nil, theme: theme, wallpaper: wallpaper, generalThemeReference: reference.generalThemeReference, defaultThemeReference: nil, create: true, completion: { result, settings in
                                let controller = editThemeController(context: context, mode: .create(result, settings
                                ), navigateToChat: { peerId in
                                    if let navigationController = getNavigationControllerImpl?() {
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
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
                        let shareController = ShareController(context: context, subject: .url("https://t.me/addtheme/\(theme.theme.slug)"), preferredAction: .default)
                        shareController.actionCompleted = {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                        }
                        presentControllerImpl?(shareController, nil)
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
                                    if let settings = theme.theme.settings?.first {
                                        if settings.baseTheme == .night {
                                            selectAccentColorImpl?(PresentationThemeAccentColor(baseColor: .blue))
                                        } else {
                                            selectAccentColorImpl?(nil)
                                        }
                                    } else {
                                        let previousThemeIndex = themes.prefix(upTo: currentThemeIndex).reversed().firstIndex(where: { $0.file != nil })
                                        let newTheme: PresentationThemeReference
                                        if let previousThemeIndex = previousThemeIndex {
                                            let theme = themes[themes.index(before: previousThemeIndex.base)]
                                            newTheme = .cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil, creatorAccountId: theme.isCreator ? context.account.id : nil))
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
            
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: themeController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            presentInGlobalOverlayImpl?(contextController, nil)
        })
    }, colorContextAction: { isCurrent, reference, accentColor, node, gesture in
        let _ = (context.sharedContext.accountManager.transaction { transaction -> (ThemeSettingsColorOption?, TelegramWallpaper?) in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings)?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
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
            if let _ = accentColor, case let .cloud(theme) = reference, let settings = theme.theme.settings?.first {
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
                    var baseColor: PresentationThemeBaseColor?
                    switch accentColor {
                    case let .accentColor(value):
                        baseColor = value.baseColor
                    default:
                        break
                    }
                    theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: generalThemeReference, accentColor: accentColor?.accentColor, bubbleColors: accentColor?.customBubbleColors ?? [], wallpaper: accentColor?.wallpaper, baseColor: baseColor)
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
                    return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: generalThemeReference, accentColor: accentColor?.accentColor, bubbleColors: accentColor?.customBubbleColors ?? [], serviceBackgroundColor: serviceBackgroundColor), effectiveThemeReference, wallpaper)
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
            let themeController = ThemePreviewController(context: context, previewTheme: theme, source: .settings(effectiveThemeReference, wallpaper, true))
            var items: [ContextMenuItem] = []
            
            if let accentColor = accentColor {
                if case let .accentColor(color) = accentColor, color.baseColor != .custom {
                } else if case let .theme(theme) = accentColor, case let .cloud(cloudTheme) = theme {
                    if cloudTheme.theme.isCreator && cloudThemeExists {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Appearance_EditTheme, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            let controller = editThemeController(context: context, mode: .edit(cloudTheme), navigateToChat: { peerId in
                                if let navigationController = getNavigationControllerImpl?() {
                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
                                }
                            })
                            
                            c.dismiss(completion: {
                                pushControllerImpl?(controller)
                            })
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: strings.Theme_Context_ChangeColors, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            guard let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: effectiveThemeReference, preview: false) else {
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
                                var hasSettings = false
                                var settings: TelegramThemeSettings?
                                if case let .cloud(cloudTheme) = effectiveThemeReference, let themeSettings = cloudTheme.theme.settings?.first {
                                    hasSettings = true
                                    settings = themeSettings
                                }
                                let controller = ThemeAccentColorController(context: context, mode: .edit(settings: settings, theme: theme, wallpaper: wallpaper, generalThemeReference: effectiveThemeReference.generalThemeReference, defaultThemeReference: nil, create: true, completion: { result, settings in
                                    let controller = editThemeController(context: context, mode: .create(hasSettings ? nil : result, hasSettings ? settings : nil), navigateToChat: { peerId in
                                        if let navigationController = getNavigationControllerImpl?() {
                                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
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
                            let shareController = ShareController(context: context, subject: .url("https://t.me/addtheme/\(cloudTheme.theme.slug)"), preferredAction: .default)
                            shareController.actionCompleted = {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                            }
                            presentControllerImpl?(shareController, nil)
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
                                        
                                        if isCurrent, let settings = cloudTheme.theme.settings?.first {
                                            let colorThemes = themes.filter { theme in
                                                if let _ = theme.settings {
                                                    return true
                                                } else {
                                                    return false
                                                }
                                            }
                                            
                                            if let currentThemeIndex = colorThemes.firstIndex(where: { $0.id == cloudTheme.theme.id }) {
                                                let previousThemeIndex = themes.prefix(upTo: currentThemeIndex).reversed().firstIndex(where: { $0.file != nil })
                                                if let previousThemeIndex = previousThemeIndex {
                                                    let theme = themes[themes.index(before: previousThemeIndex.base)]
                                                    selectThemeImpl?(.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil, creatorAccountId: theme.isCreator ? context.account.id : nil)))
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
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: themeController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            presentInGlobalOverlayImpl?(contextController, nil)
        })
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings, SharedDataKeys.chatThemes]), cloudThemes.get(), availableAppIcons, currentAppIconName.get(), removedThemeIndexesPromise.get(), animatedEmojiStickers, context.account.postbox.peerView(id: context.account.peerId))
    |> map { presentationData, sharedData, cloudThemes, availableAppIcons, currentAppIconName, removedThemeIndexes, animatedEmojiStickers, peerView -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
    
        let isPremium = peerView.peers[peerView.peerId]?.isPremium ?? false
        
        let themeReference: PresentationThemeReference
        if presentationData.autoNightModeTriggered {
            if let _ = settings.theme.emoticon {
                themeReference = settings.theme
            } else {
                themeReference = settings.automaticThemeSwitchSetting.theme
            }
        } else {
            themeReference = settings.theme
        }
        
        var defaultThemes: [PresentationThemeReference] = []
        if presentationData.autoNightModeTriggered {
            defaultThemes.append(contentsOf: [.builtin(.nightAccent), .builtin(.night)])
        } else {
            defaultThemes.append(contentsOf: [
                .builtin(.dayClassic),
                .builtin(.nightAccent),
                .builtin(.day),
                .builtin(.night)
            ])
        }
        
        let cloudThemes: [PresentationThemeReference] = cloudThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil, creatorAccountId: $0.isCreator ? context.account.id : nil)) }.filter { !removedThemeIndexes.contains($0.index) }
        
        var availableThemes = defaultThemes
        if defaultThemes.first(where: { $0.index == themeReference.index }) == nil && cloudThemes.first(where: { $0.index == themeReference.index }) == nil {
            availableThemes.append(themeReference)
        }
        availableThemes.append(contentsOf: cloudThemes)
        
        var chatThemes = cloudThemes.filter { $0.emoticon != nil }
        chatThemes.insert(.builtin(.dayClassic), at: 0)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: themeSettingsControllerEntries(presentationData: presentationData, presentationThemeSettings: settings, themeReference: themeReference, availableThemes: availableThemes, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName, isPremium: isPremium, chatThemes: chatThemes, animatedEmojiStickers: animatedEmojiStickers), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
        
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
            var themeItemNode: ThemeCarouselThemeItemNode?
            
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
                            if let itemNode = node as? ThemeCarouselThemeItemNode {
                                themeItemNode = itemNode
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
            }
            
            let sectionInset = max(16.0, floor((controller.displayNode.frame.width - 674.0) / 2.0))
            
            let crossfadeController = ThemeSettingsCrossfadeController(view: view, topOffset: topOffset, bottomOffset: bottomOffset, leftOffset: leftOffset, sideInset: sectionInset)
            crossfadeController.didAppear = { [weak themeItemNode] in
                if view != nil {
                    themeItemNode?.animateCrossfadeTransition()
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
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings)?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
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
            if case let .cloud(info) = currentTheme, let settings = info.theme.settings?.first {
                currentThemeBaseIndex = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)).index
            } else {
                currentThemeBaseIndex = currentTheme.index
            }
            
            var baseThemeIndex: Int64?
            var updatedThemeBaseIndex: Int64?
            if case let .cloud(info) = theme {
                updatedTheme = .cloud(PresentationCloudTheme(theme: info.theme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: info.theme.isCreator ? context.account.id : nil))
                if let settings = info.theme.settings?.first {
                    baseThemeIndex = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)).index
                    updatedThemeBaseIndex = baseThemeIndex
                }
            } else {
                updatedThemeBaseIndex = theme.index
            }

            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                if case let .cloud(info) = updatedTheme, info.theme.settings?.contains(where: { $0.baseTheme == .night || $0.baseTheme == .tinted }) ?? false {
                    updatedAutomaticThemeSwitchSetting.theme = updatedTheme
                } else if case let .builtin(theme) = updatedTheme {
                    if [.day, .dayClassic].contains(theme) {
                        if updatedAutomaticThemeSwitchSetting.theme.emoticon != nil || [.builtin(.dayClassic), .builtin(.day)].contains(updatedAutomaticThemeSwitchSetting.theme.generalThemeReference) {
                            updatedAutomaticThemeSwitchSetting.theme = .builtin(.night)
                        }
                    } else {
                        updatedAutomaticThemeSwitchSetting.theme = updatedTheme
                    }
                }
                return current.withUpdatedTheme(updatedTheme).withUpdatedAutomaticThemeSwitchSetting(updatedAutomaticThemeSwitchSetting)

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
                    let _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .wallpaper(wallpaper: .slug(file.slug), resource: file.file.resource)).start()

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
                if case let .cloud(theme) = currentTheme, let settings = theme.theme.settings?.first {
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
                
                guard let _ = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: generalThemeReference, accentColor: accentColor?.color, wallpaper: presetWallpaper, baseColor: accentColor?.baseColor) else {
                    return current
                }
                
                let themePreferredBaseTheme = current.themePreferredBaseTheme
                var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                var themeSpecificAccentColors = current.themeSpecificAccentColors
                themeSpecificAccentColors[generalThemeReference.index] = accentColor?.withUpdatedWallpaper(presetWallpaper)
                
                if case .builtin = generalThemeReference {
                    let index = coloredThemeIndex(reference: currentTheme, accentColor: accentColor)
                    if let wallpaper = current.themeSpecificChatWallpapers[index] {
                        if wallpaper.isColorOrGradient || wallpaper.isPattern || wallpaper.isBuiltin {
                            themeSpecificChatWallpapers[index] = presetWallpaper
                        }
                    } else {
                        themeSpecificChatWallpapers[index] = presetWallpaper
                    }
                }
                
                return PresentationThemeSettings(theme: updatedTheme, themePreferredBaseTheme: themePreferredBaseTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, chatBubbleSettings: current.chatBubbleSettings, automaticThemeSwitchSetting: updatedAutomaticThemeSwitchSetting, largeEmoji: current.largeEmoji, reduceMotion: current.reduceMotion)
            }).start()
            
            presentCrossfadeControllerImpl?(true)
        })
    }
    return controller
}

public final class ThemeSettingsCrossfadeController: ViewController {
    private var snapshotView: UIView?
    
    private var topSnapshotView: UIView?
    private var bottomSnapshotView: UIView?
    private var sideSnapshotView: UIView?
    
    private var leftSnapshotView: UIView?
    private var rightSnapshotView: UIView?
    
    var didAppear: (() -> Void)?
    
    public init(view: UIView? = nil, topOffset: CGFloat? = nil, bottomOffset: CGFloat? = nil, leftOffset: CGFloat? = nil, sideInset: CGFloat = 0.0) {
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
            
            if sideInset > 0.0 {
                if let view = view.snapshotView(afterScreenUpdates: false) {
                    let clipView = UIView()
                    clipView.clipsToBounds = true
                    clipView.addSubview(view)
                    
                    view.clipsToBounds = true
                    view.contentMode = .topLeft
                    
                    if let topOffset = topOffset, let bottomOffset = bottomOffset {
                        var frame = view.frame
                        frame.origin.y = topOffset
                        frame.size.width = sideInset
                        frame.size.height = bottomOffset - topOffset
                        clipView.frame = frame
                        
                        frame = view.frame
                        frame.origin.y = -topOffset
                        frame.size.width = sideInset
                        frame.size.height = bottomOffset
                        view.frame = frame
                    }
                
                    self.leftSnapshotView = clipView
                }
                if let view = view.snapshotView(afterScreenUpdates: false) {
                    let clipView = UIView()
                    clipView.clipsToBounds = true
                    clipView.addSubview(view)
                    
                    view.clipsToBounds = true
                    view.contentMode = .topRight
                    
                    if let topOffset = topOffset, let bottomOffset = bottomOffset {
                        var frame = view.frame
                        frame.origin.x = frame.width - sideInset
                        frame.origin.y = topOffset
                        frame.size.width = sideInset
                        frame.size.height = bottomOffset - topOffset
                        clipView.frame = frame
                        
                        frame = view.frame
                        frame.origin.y = -topOffset
                        frame.size.width = sideInset
                        frame.size.height = bottomOffset
                        view.frame = frame
                    }
                
                    self.rightSnapshotView = clipView
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
        if let leftSnapshotView = self.leftSnapshotView {
             self.displayNode.view.addSubview(leftSnapshotView)
        }
        if let rightSnapshotView = self.rightSnapshotView {
             self.displayNode.view.addSubview(rightSnapshotView)
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
