import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AlertUI
import WallpaperResources
import ShareController
import AccountContext

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
    let updateTheme: (PresentationThemeReference) -> Void
    let selectFontSize: (PresentationFontSize) -> Void
    let openWallpaperSettings: () -> Void
    let selectAccentColor: (PresentationThemeAccentColor) -> Void
    let openAccentColorPicker: (PresentationThemeReference, PresentationThemeAccentColor?) -> Void
    let openAutoNightTheme: () -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let disableAnimations: (Bool) -> Void
    let selectAppIcon: (String) -> Void
    let presentThemeMenu: (PresentationThemeReference, Bool) -> Void
    let editTheme: (PresentationCloudTheme) -> Void
    
    init(context: AccountContext, updateTheme: @escaping (PresentationThemeReference) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void, selectAccentColor: @escaping (PresentationThemeAccentColor) -> Void, openAccentColorPicker: @escaping (PresentationThemeReference, PresentationThemeAccentColor?) -> Void, openAutoNightTheme: @escaping () -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, disableAnimations: @escaping (Bool) -> Void, selectAppIcon: @escaping (String) -> Void, presentThemeMenu: @escaping (PresentationThemeReference, Bool) -> Void, editTheme: @escaping (PresentationCloudTheme) -> Void) {
        self.context = context
        self.updateTheme = updateTheme
        self.selectFontSize = selectFontSize
        self.openWallpaperSettings = openWallpaperSettings
        self.selectAccentColor = selectAccentColor
        self.openAccentColorPicker = openAccentColorPicker
        self.openAutoNightTheme = openAutoNightTheme
        self.toggleLargeEmoji = toggleLargeEmoji
        self.disableAnimations = disableAnimations
        self.selectAppIcon = selectAppIcon
        self.presentThemeMenu = presentThemeMenu
        self.editTheme = editTheme
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
    case themeItem(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], PresentationThemeAccentColor?)
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
            case let .themeListHeader(lhsTheme, lhsText):
                if case let .themeListHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .themeItem(lhsTheme, lhsStrings, lhsThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsCurrentColor):
                if case let .themeItem(rhsTheme, rhsStrings, rhsThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsCurrentColor) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsCurrentColor == rhsCurrentColor {
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
            case let .chatPreview(theme, componentTheme, wallpaper, fontSize, strings, dateTimeFormat, nameDisplayOrder, items):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: componentTheme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, messageItems: items)
            case let .wallpaper(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
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
                    arguments.openAccentColorPicker(currentTheme, currentColor)
                }, tag: ThemeSettingsEntryTag.accentColor)
            case let .autoNightTheme(theme, text, value):
                return ItemListDisclosureItem(theme: theme, icon: nil, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openAutoNightTheme()
                })
            case let .themeListHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .themeItem(theme, strings, themes, currentTheme, themeSpecificAccentColors, _):
                return ThemeSettingsThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, themeSpecificAccentColors: themeSpecificAccentColors, currentTheme: currentTheme, updatedTheme: { theme in
                    if case let .cloud(theme) = theme, theme.theme.file == nil {
                        if theme.theme.isCreator {
                            arguments.editTheme(theme)
                        }
                    } else {
                        arguments.updateTheme(theme)
                    }
                }, longTapped: { theme in
                    arguments.presentThemeMenu(theme, theme.index == currentTheme.index)
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

private func themeSettingsControllerEntries(presentationData: PresentationData, theme: PresentationTheme, themeReference: PresentationThemeReference, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], availableThemes: [PresentationThemeReference], autoNightSettings: AutomaticThemeSwitchSetting, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, dateTimeFormat: PresentationDateTimeFormat, largeEmoji: Bool, disableAnimations: Bool, availableAppIcons: [PresentationAppIcon], currentAppIconName: String?) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    entries.append(.themeListHeader(presentationData.theme, strings.Appearance_ColorTheme.uppercased()))
    entries.append(.chatPreview(presentationData.theme, theme, wallpaper, fontSize, presentationData.strings, dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (presentationData.strings.Appearance_PreviewReplyAuthor, presentationData.strings.Appearance_PreviewReplyText), text: presentationData.strings.Appearance_PreviewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: presentationData.strings.Appearance_PreviewOutgoingText)]))
    
    entries.append(.themeItem(presentationData.theme, presentationData.strings, availableThemes, themeReference, themeSpecificAccentColors, themeSpecificAccentColors[themeReference.index]))
    
    if case let .builtin(theme) = themeReference, theme != .dayClassic {
        entries.append(.accentColor(presentationData.theme, themeReference, strings.Appearance_AccentColor, themeSpecificAccentColors[themeReference.index]))
    }
    
    entries.append(.wallpaper(presentationData.theme, strings.Settings_ChatBackground))
    
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
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    var updateThemeImpl: ((PresentationThemeReference) -> Void)?
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
    
    let arguments = ThemeSettingsControllerArguments(context: context, updateTheme: { theme in
        updateThemeImpl?(theme)
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
            
            let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: current.theme, accentColor: color.color, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: color.baseColor)
            var chatWallpaper = current.chatWallpaper
            if let wallpaper = current.themeSpecificChatWallpapers[current.theme.index], wallpaper.hasWallpaper {
            } else {
                chatWallpaper = theme.chat.defaultWallpaper
                themeSpecificChatWallpapers[current.theme.index] = chatWallpaper
            }
            
            return PresentationThemeSettings(chatWallpaper: chatWallpaper, theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
        }).start()
    }, openAccentColorPicker: { themeReference, currentColor in
        let controller = ThemeAccentColorController(context: context, currentTheme: themeReference, currentColor: currentColor?.color)
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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
    }, presentThemeMenu: { themeReference, isCurrent in
        guard case let .cloud(theme) = themeReference else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: theme.theme.title))
        if theme.theme.isCreator {
            items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_EditTheme, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
                    if let navigationController = getNavigationControllerImpl?() {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                    }
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }))
        }
        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_ShareTheme, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            let controller = ShareController(context: context, subject: .url("https://t.me/addtheme/\(theme.theme.slug)"), preferredAction: .default)
            presentControllerImpl?(controller, nil)
        }))
        items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_RemoveTheme, color: .destructive, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetButtonItem(title: presentationData.strings.Appearance_RemoveThemeConfirmation, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let _ = (cloudThemes.get() |> delay(0.5, queue: Queue.mainQueue())
                |> take(1)
                |> deliverOnMainQueue).start(next: { themes in
                    if isCurrent, let themeIndex = themes.firstIndex(where: { $0.id == theme.theme.id }) {
                        let newTheme: PresentationThemeReference
                        if themeIndex > 0 {
                            newTheme = .cloud(PresentationCloudTheme(theme: themes[themeIndex - 1], resolvedWallpaper: nil))
                        } else {
                            newTheme = .builtin(.nightAccent)
                        }
                        updateThemeImpl?(newTheme)
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
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, editTheme: { theme in
        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
            if let navigationController = getNavigationControllerImpl?() {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
            }
        })
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]), cloudThemes.get(), availableAppIcons, currentAppIconName.get())
    |> map { presentationData, sharedData, cloudThemes, availableAppIcons, currentAppIconName -> (ItemListControllerState, (ItemListNodeState<ThemeSettingsControllerEntry>, ThemeSettingsControllerEntry.ItemGenerationArguments)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
        
        let fontSize = settings.fontSize
        let dateTimeFormat = presentationData.dateTimeFormat
        let largeEmoji = presentationData.largeEmoji
        let disableAnimations = presentationData.disableAnimations
        
        let accentColor = settings.themeSpecificAccentColors[settings.theme.index]?.color
        let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: settings.theme, accentColor: accentColor, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: settings.themeSpecificAccentColors[settings.theme.index]?.baseColor ?? .blue, preview: true)

        let wallpaper: TelegramWallpaper
        if let themeSpecificWallpaper = settings.themeSpecificChatWallpapers[settings.theme.index] {
            wallpaper = themeSpecificWallpaper
        } else {
            wallpaper = settings.chatWallpaper
        }
        
        let rightNavigationButton = ItemListNavigationButton(content: .icon(.action), style: .regular, enabled: true, action: {
            moreImpl?()
        })
        
        let defaultThemes: [PresentationThemeReference] = [.builtin(.dayClassic), .builtin(.day), .builtin(.night), .builtin(.nightAccent)]
        let cloudThemes: [PresentationThemeReference] = cloudThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil)) }
        
        var availableThemes = defaultThemes
        if defaultThemes.first(where: { $0.index == settings.theme.index }) == nil && cloudThemes.first(where: { $0.index == settings.theme.index }) == nil {
            availableThemes.append(settings.theme)
        }
        availableThemes.append(contentsOf: cloudThemes)
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Appearance_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: themeSettingsControllerEntries(presentationData: presentationData, theme: theme, themeReference: settings.theme,  themeSpecificAccentColors: settings.themeSpecificAccentColors, availableThemes: availableThemes, autoNightSettings: settings.automaticThemeSwitchSetting, strings: presentationData.strings, wallpaper: wallpaper, fontSize: fontSize, dateTimeFormat: dateTimeFormat, largeEmoji: largeEmoji, disableAnimations: disableAnimations, availableAppIcons: availableAppIcons, currentAppIconName: currentAppIconName), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
                
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
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    updateThemeImpl = { theme in
        let presentationTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: theme, accentColor: nil, serviceBackgroundColor: .black, baseColor: nil)
        
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
                    
                    let chatWallpaper: TelegramWallpaper
                    if let themeSpecificWallpaper = current.themeSpecificChatWallpapers[updatedTheme.index] {
                        chatWallpaper = themeSpecificWallpaper
                    } else {
                        let presentationTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: updatedTheme, accentColor: current.themeSpecificAccentColors[updatedTheme.index]?.color, serviceBackgroundColor: .black, baseColor: nil)
                        chatWallpaper = resolvedWallpaper ?? presentationTheme.chat.defaultWallpaper
                    }
                    
                    return PresentationThemeSettings(chatWallpaper: chatWallpaper, theme: updatedTheme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
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
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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
        
        self.statusBar.statusBarStyle = .Hide
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
