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
import ItemListPeerActionItem
import AnimationUI

private final class ThemePickerControllerArguments {
    let context: AccountContext
    let selectTheme: (TelegramBaseTheme?, PresentationThemeReference, Bool) -> Void
    let previewTheme: (PresentationThemeReference, Bool, Bool, [Int64: PresentationThemeAccentColor]) -> Void
    let selectAccentColor: (TelegramBaseTheme?, PresentationThemeAccentColor?) -> Void
    let openAccentColorPicker: (PresentationThemeReference, Bool) -> Void
    let editTheme: (PresentationCloudTheme) -> Void
    let editCurrentTheme: () -> Void
    let createNewTheme: () -> Void
    let themeContextAction: (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void
    let colorContextAction: (Bool, PresentationThemeReference, ThemeSettingsColorOption?, ASDisplayNode, ContextGesture?) -> Void
    
    init(context: AccountContext, selectTheme: @escaping (TelegramBaseTheme?, PresentationThemeReference, Bool) -> Void, previewTheme: @escaping (PresentationThemeReference, Bool, Bool, [Int64: PresentationThemeAccentColor]) -> Void, selectAccentColor: @escaping (TelegramBaseTheme?, PresentationThemeAccentColor?) -> Void, openAccentColorPicker: @escaping (PresentationThemeReference, Bool) -> Void, editTheme: @escaping (PresentationCloudTheme) -> Void, editCurrentTheme: @escaping () -> Void, createNewTheme: @escaping () -> Void, themeContextAction: @escaping (Bool, PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void, colorContextAction: @escaping (Bool, PresentationThemeReference, ThemeSettingsColorOption?, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.selectTheme = selectTheme
        self.previewTheme = previewTheme
        self.selectAccentColor = selectAccentColor
        self.openAccentColorPicker = openAccentColorPicker
        self.editTheme = editTheme
        self.editCurrentTheme = editCurrentTheme
        self.createNewTheme = createNewTheme
        self.themeContextAction = themeContextAction
        self.colorContextAction = colorContextAction
    }
}

private enum ThemePickerControllerSection: Int32 {
    case themes
    case custom
    case other
}

private enum ThemePickerControllerEntry: ItemListNodeEntry {
    case themesHeader(PresentationTheme, String)
    case themes(PresentationTheme, PresentationStrings, [PresentationThemeReference], PresentationThemeReference, Bool, [String: [StickerPackItem]], [Int64: PresentationThemeAccentColor], [Int64: TelegramWallpaper])
    case customHeader(PresentationTheme, String)
    case chatPreview(PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationChatBubbleCorners, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, [ChatPreviewMessageItem])
    case theme(PresentationTheme, PresentationStrings, [PresentationThemeReference], [PresentationThemeReference], PresentationThemeReference, [Int64: PresentationThemeAccentColor], [Int64: TelegramWallpaper], PresentationThemeAccentColor?, [Int64: TelegramBaseTheme])
    case accentColor(PresentationTheme, PresentationThemeReference, PresentationThemeReference, [PresentationThemeReference], ThemeSettingsColorOption?)
    case editTheme(PresentationTheme, String)
    case createTheme(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .themesHeader, .themes:
                return ThemePickerControllerSection.themes.rawValue
            case .customHeader, .chatPreview, .theme, .accentColor:
                return ThemePickerControllerSection.custom.rawValue
            case .editTheme, .createTheme:
                return ThemePickerControllerSection.other.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .themesHeader:
                return 0
            case .themes:
                return 1
            case .customHeader:
                return 2
            case .chatPreview:
                return 3
            case .theme:
                return 4
            case .accentColor:
                return 5
            case .editTheme:
                return 6
            case .createTheme:
                return 7
        }
    }
    
    static func ==(lhs: ThemePickerControllerEntry, rhs: ThemePickerControllerEntry) -> Bool {
        switch lhs {
            case let .themesHeader(lhsTheme, lhsText):
                if case let .themesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .customHeader(lhsTheme, lhsText):
                if case let .customHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .chatPreview(lhsTheme, lhsWallpaper, lhsFontSize, lhsChatBubbleCorners, lhsStrings, lhsTimeFormat, lhsNameOrder, lhsItems):
                if case let .chatPreview(rhsTheme, rhsWallpaper, rhsFontSize, rhsChatBubbleCorners, rhsStrings, rhsTimeFormat, rhsNameOrder, rhsItems) = rhs, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsChatBubbleCorners == rhsChatBubbleCorners, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder, lhsItems == rhsItems {
                    return true
                } else {
                    return false
                }
            case let .theme(lhsTheme, lhsStrings, lhsThemes, lhsAllThemes, lhsCurrentTheme, lhsThemeAccentColors, lhsThemeSpecificChatWallpapers, lhsCurrentColor, lhsThemePreferredBaseTheme):
                if case let .theme(rhsTheme, rhsStrings, rhsThemes, rhsAllThemes, rhsCurrentTheme, rhsThemeAccentColors, rhsThemeSpecificChatWallpapers, rhsCurrentColor, rhsThemePreferredBaseTheme) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsThemes == rhsThemes, lhsAllThemes == rhsAllThemes, lhsCurrentTheme == rhsCurrentTheme, lhsThemeAccentColors == rhsThemeAccentColors, lhsThemeSpecificChatWallpapers == rhsThemeSpecificChatWallpapers, lhsCurrentColor == rhsCurrentColor, lhsThemePreferredBaseTheme == rhsThemePreferredBaseTheme {
                    return true
                } else {
                    return false
                }
            case let .accentColor(lhsTheme, _, lhsCurrentTheme, lhsThemes, lhsColor):
                if case let .accentColor(rhsTheme, _, rhsCurrentTheme, rhsThemes, rhsColor) = rhs, lhsTheme === rhsTheme, lhsCurrentTheme == rhsCurrentTheme, lhsThemes == rhsThemes, lhsColor == rhsColor {
                    return true
                } else {
                    return false
                }
            case let .editTheme(lhsTheme, lhsText):
                if case let .editTheme(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .createTheme(lhsTheme, lhsText):
                if case let .createTheme(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemePickerControllerEntry, rhs: ThemePickerControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ThemePickerControllerArguments
        switch self {
            case let .themesHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .themes(theme, strings, themes, currentTheme, nightMode, animatedEmojiStickers, themeSpecificAccentColors, themeSpecificChatWallpapers):
                return ThemeGridThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, animatedEmojiStickers: animatedEmojiStickers, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, nightMode: nightMode, currentTheme: currentTheme, updatedTheme: { theme in
                arguments.previewTheme(theme, nightMode, true, themeSpecificAccentColors)
            }, contextAction: { theme, node, gesture in
                arguments.themeContextAction(false, theme, node, gesture)
            }, tag: nil)
            case let .customHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .chatPreview(theme, wallpaper, fontSize, chatBubbleCorners, strings, dateTimeFormat, nameDisplayOrder, items):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: theme, strings: strings, sectionId: self.section, fontSize: fontSize, chatBubbleCorners: chatBubbleCorners, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, messageItems: items)
            case let .theme(theme, strings, themes, allThemes, currentTheme, themeSpecificAccentColors, themeSpecificChatWallpapers, _, themePreferredBaseTheme):
                return ThemeSettingsThemeItem(context: arguments.context, theme: theme, strings: strings, sectionId: self.section, themes: themes, allThemes: allThemes, displayUnsupported: true, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, themePreferredBaseTheme: themePreferredBaseTheme, currentTheme: currentTheme, updatedTheme: { theme in
                    if case let .cloud(theme) = theme, theme.theme.file == nil && theme.theme.settings == nil {
                        if theme.theme.isCreator {
                            arguments.editTheme(theme)
                        }
                    } else {
                        arguments.selectTheme(nil, theme, false)
                    }
                }, contextAction: { theme, node, gesture in
                    arguments.themeContextAction(theme.index == currentTheme.index, theme, node, gesture)
                }, tag: ThemeSettingsEntryTag.theme)

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
                if let index = colorItems.firstIndex(where: { item in
                    if case .default = item {
                        return true
                    } else {
                        return false
                    }
                }) {
                    if index > 0 {
                        let item = colorItems[index]
                        colorItems.remove(at: index)
                        colorItems.insert(item, at: 1)
                    }
                }
            
                
                let baseTheme: TelegramBaseTheme?
                if case let .builtin(theme) = generalThemeReference {
                    baseTheme = theme.baseTheme
                } else {
                    baseTheme = nil
                }
            
                return ThemeSettingsAccentColorItem(theme: theme, sectionId: self.section, generalThemeReference: generalThemeReference, themeReference: currentTheme, colors: colorItems, currentColor: currentColor, updated: { color in
                    if let color = color {
                        switch color {
                            case let .accentColor(color):
                                arguments.selectAccentColor(baseTheme, color)
                            case let .theme(theme):
                                arguments.selectTheme(baseTheme, theme, false)
                        }
                    } else {
                        arguments.selectAccentColor(nil, nil)
                    }
                }, contextAction: { isCurrent, theme, color, node, gesture in
                    arguments.colorContextAction(isCurrent, theme, color, node, gesture)
                }, openColorPicker: { create in
                    arguments.openAccentColorPicker(currentTheme, create)
                }, tag: ThemeSettingsEntryTag.accentColor)
            case let .editTheme(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.editThemeIcon(theme), title: text, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.editCurrentTheme()
                })
            case let .createTheme(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.createNewTheme()
                })
        }
    }
}

private func themePickerControllerEntries(presentationData: PresentationData, presentationThemeSettings: PresentationThemeSettings, themeReference: PresentationThemeReference, availableThemes: [PresentationThemeReference], chatThemes: [PresentationThemeReference], nightMode: Bool, animatedEmojiStickers: [String: [StickerPackItem]]) -> [ThemePickerControllerEntry] {
    var entries: [ThemePickerControllerEntry] = []
    
    entries.append(.themesHeader(presentationData.theme, presentationData.strings.Themes_SelectTheme.uppercased()))
    entries.append(.themes(presentationData.theme, presentationData.strings, chatThemes, themeReference, nightMode, animatedEmojiStickers, presentationThemeSettings.themeSpecificAccentColors, presentationThemeSettings.themeSpecificChatWallpapers))
    
    entries.append(.customHeader(presentationData.theme, presentationData.strings.Themes_BuildOwn.uppercased()))
    entries.append(.chatPreview(presentationData.theme, presentationData.chatWallpaper, presentationData.chatFontSize, presentationData.chatBubbleCorners, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (presentationData.strings.Appearance_PreviewReplyAuthor, presentationData.strings.Appearance_PreviewReplyText), text: presentationData.strings.Appearance_PreviewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: presentationData.strings.Appearance_PreviewOutgoingText)]))
    
    let generalThemes: [PresentationThemeReference] = availableThemes.filter { reference in
        if case let .cloud(theme) = reference {
            return theme.theme.settings == nil
        } else {
            return true
        }
    }

    let generalThemeReference: PresentationThemeReference
    if case let .cloud(theme) = themeReference, let settings = theme.theme.settings {
        if let baseTheme = presentationThemeSettings.themePreferredBaseTheme[themeReference.index] {
            generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: baseTheme))
        } else if let first = settings.first {
            generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: first.baseTheme))
        } else {
            generalThemeReference = themeReference
        }
    } else {
        generalThemeReference = themeReference
    }
    
    entries.append(.theme(presentationData.theme, presentationData.strings, generalThemes, availableThemes, themeReference, presentationThemeSettings.themeSpecificAccentColors, presentationThemeSettings.themeSpecificChatWallpapers, presentationThemeSettings.themeSpecificAccentColors[themeReference.index], presentationThemeSettings.themePreferredBaseTheme))

    if case let .builtin(builtinTheme) = generalThemeReference {
        let colorThemes = availableThemes.filter { reference in
            if case let .cloud(theme) = reference, let settings = theme.theme.settings, settings.contains(where: { $0.baseTheme == builtinTheme.baseTheme }) {
                return true
            } else {
                return false
            }
        }

        var colorOption: ThemeSettingsColorOption?
        if case .builtin = themeReference {
            colorOption = presentationThemeSettings.themeSpecificAccentColors[themeReference.index].flatMap { .accentColor($0) }
        } else {
            colorOption = .theme(themeReference)
        }

        entries.append(.accentColor(presentationData.theme, generalThemeReference, themeReference, colorThemes, colorOption))
    }
    
    entries.append(.editTheme(presentationData.theme, presentationData.strings.Themes_EditCurrentTheme))
    entries.append(.createTheme(presentationData.theme, presentationData.strings.Themes_CreateNewTheme))
    
    return entries
}

public protocol ThemePickerController {
    
}

private final class ThemePickerControllerImpl: ItemListController, ThemePickerController {
}

public func themePickerController(context: AccountContext, focusOnItemTag: ThemeSettingsEntryTag? = nil) -> ViewController {
    #if DEBUG
    BuiltinWallpaperData.generate(account: context.account)
    #endif

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var updateControllersImpl: ((([UIViewController]) -> [UIViewController]) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    var presentCrossfadeControllerImpl: ((Bool) -> Void)?
    
    var selectThemeImpl: ((TelegramBaseTheme?, PresentationThemeReference, Bool) -> Void)?
    var selectAccentColorImpl: ((TelegramBaseTheme?, PresentationThemeAccentColor?) -> Void)?
    var openAccentColorPickerImpl: ((PresentationThemeReference, Bool) -> Void)?
    
    let _ = telegramWallpapers(postbox: context.account.postbox, network: context.account.network).start()
    
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
    
    let nightModePreviewPromise = ValuePromise<Bool>(false)
    
    let arguments = ThemePickerControllerArguments(context: context, selectTheme: { baseTheme, theme, preset in
        selectThemeImpl?(baseTheme, theme, preset)
    }, previewTheme: { initialThemeReference, nightMode, custom, themeSpecificAccentColors in
        var themeReference = initialThemeReference
        if nightMode, case .builtin(.dayClassic) = themeReference {
            themeReference = .builtin(.night)
        }
        let themeSpecificColor = themeSpecificAccentColors[themeReference.index]
        var accentColor = themeSpecificColor?.accentColor.flatMap { UIColor(rgb: $0) }
        if accentColor == nil, case .builtin(.night) = themeReference {
            accentColor = themeSpecificColor?.colorFor(baseTheme: .night)
        }
        if let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, baseTheme: nightMode ? .night : .classic, accentColor: accentColor, bubbleColors: themeSpecificColor?.bubbleColors ?? []) {
            let controller = ThemePreviewController(context: context, previewTheme: theme, source: .settings(themeReference, nil, false))
            if custom {
                controller.customApply = {
                    selectThemeImpl?(nil, initialThemeReference, true)
                }
            }
            pushControllerImpl?(controller)
        }
    }, selectAccentColor: { currentBaseTheme, accentColor in
        selectAccentColorImpl?(currentBaseTheme, accentColor)
    }, openAccentColorPicker: { themeReference, create in
        openAccentColorPickerImpl?(themeReference, create)
    }, editTheme: { theme in
        let controller = editThemeController(context: context, mode: .edit(theme), navigateToChat: { peerId in
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer = peer else {
                    return
                }
                if let navigationController = getNavigationControllerImpl?() {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                }
            })
        })
        pushControllerImpl?(controller)
    }, editCurrentTheme: {
        let _ = (context.sharedContext.accountManager.transaction { transaction -> PresentationThemeReference in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings)?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
            
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
            if case let .cloud(cloudTheme) = themeReference, cloudTheme.theme.settings?.isEmpty ?? true {
                let controller = editThemeController(context: context, mode: .edit(cloudTheme), navigateToChat: { peerId in
                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        if let navigationController = getNavigationControllerImpl?() {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                        }
                    })
                })
                pushControllerImpl?(controller)
            } else {
                openAccentColorPickerImpl?(themeReference, false)
            }
        })
    }, createNewTheme: {
        let _ = (context.sharedContext.accountManager.transaction { transaction -> PresentationThemeReference in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings)?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
            
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
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer else {
                        return
                    }
                    if let navigationController = getNavigationControllerImpl?() {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                    }
                })
            })
            pushControllerImpl?(controller)
        })
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
                var effectiveAccentColor: UIColor? = accentColor?.color
                if case let .builtin(theme) = reference {
                    effectiveAccentColor = accentColor?.colorFor(baseTheme: (theme).baseTheme)
                }
                if reference == .builtin(.night), effectiveAccentColor == nil {
                    effectiveAccentColor = UIColor(rgb: 0x3e88f7)
                }
                return (makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: reference, accentColor: effectiveAccentColor, bubbleColors: accentColor?.customBubbleColors ?? [], serviceBackgroundColor: serviceBackgroundColor), wallpaper)
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
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                            |> deliverOnMainQueue).start(next: { peer in
                                guard let peer = peer else {
                                    return
                                }
                                if let navigationController = getNavigationControllerImpl?() {
                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                                }
                            })
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
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                    |> deliverOnMainQueue).start(next: { peer in
                                        guard let peer = peer else {
                                            return
                                        }
                                        if let navigationController = getNavigationControllerImpl?() {
                                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                                        }
                                    })
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
                if !theme.theme.isDefault {
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
                                                selectAccentColorImpl?(nil, PresentationThemeAccentColor(baseColor: .blue))
                                            } else {
                                                selectAccentColorImpl?(nil, nil)
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
                                            selectThemeImpl?(nil, newTheme, false)
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
                }
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
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> deliverOnMainQueue).start(next: { peer in
                                    guard let peer = peer else {
                                        return
                                    }
                                    if let navigationController = getNavigationControllerImpl?() {
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                                    }
                                })
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
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                        |> deliverOnMainQueue).start(next: { peer in
                                            guard let peer = peer else {
                                                return
                                            }
                                            if let navigationController = getNavigationControllerImpl?() {
                                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                                            }
                                        })
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
                    if cloudThemeExists && !cloudTheme.theme.isDefault {
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
                                                    selectThemeImpl?(nil, .cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil, creatorAccountId: theme.isCreator ? context.account.id : nil)), false)
                                                } else {
                                                    if settings.baseTheme == .night {
                                                        selectAccentColorImpl?(nil, PresentationThemeAccentColor(baseColor: .blue))
                                                    } else {
                                                        selectAccentColorImpl?(nil, nil)
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
    
    let switchNode = SwitchIconNode(theme: context.sharedContext.currentPresentationData.with({ $0 }).theme)
    let previousNightModePreview = Atomic<Bool>(value: false)
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings, SharedDataKeys.chatThemes]), cloudThemes.get(), removedThemeIndexesPromise.get(), animatedEmojiStickers, nightModePreviewPromise.get())
    |> map { [weak switchNode] presentationData, sharedData, cloudThemes, removedThemeIndexes, animatedEmojiStickers, nightModePreview -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
    
        var presentationData = presentationData
        if nightModePreview {
            let preferredBaseTheme: TelegramBaseTheme = .night
            
            let automaticTheme = settings.automaticThemeSwitchSetting.theme
            var effectiveColors = settings.themeSpecificAccentColors[automaticTheme.index]
            if automaticTheme == .builtin(.night) && effectiveColors == nil {
                effectiveColors = PresentationThemeAccentColor(baseColor: .blue)
            }
            let themeSpecificWallpaper = (settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: automaticTheme, accentColor: effectiveColors)] ?? settings.themeSpecificChatWallpapers[automaticTheme.index])
            
            let darkTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: automaticTheme, baseTheme: preferredBaseTheme, accentColor: effectiveColors?.color, bubbleColors: effectiveColors?.customBubbleColors ?? [], wallpaper: effectiveColors?.wallpaper, baseColor: effectiveColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
            var darkWallpaper = presentationData.chatWallpaper
            if let themeSpecificWallpaper = themeSpecificWallpaper {
                darkWallpaper = themeSpecificWallpaper
            } else {
                switch darkWallpaper {
                    case .builtin, .color, .gradient:
                        darkWallpaper = darkTheme.chat.defaultWallpaper
                    case .file:
                        if darkWallpaper.isPattern {
                            darkWallpaper = darkTheme.chat.defaultWallpaper
                        }
                    default:
                        break
                }
            }
        
            presentationData = presentationData.withUpdated(theme: darkTheme).withUpdated(chatWallpaper: darkWallpaper)
        }
        
        let previousNightModePreview = previousNightModePreview.swap(nightModePreview)
        if previousNightModePreview != nightModePreview {
            switchNode?.play(isDark: !nightModePreview, theme: presentationData.theme)
        } else {
            switchNode?.updateTheme(presentationData.theme)
        }
        
        var themeReference = settings.theme
        if presentationData.autoNightModeTriggered {
            themeReference = settings.automaticThemeSwitchSetting.theme
        }
        
        let rightNavigationButton: ItemListNavigationButton?
        if !presentationData.autoNightModeTriggered, let switchNode = switchNode {
            rightNavigationButton = ItemListNavigationButton(content: .node(switchNode), style: .regular, enabled: true, action: {
                nightModePreviewPromise.set(!nightModePreview)
                presentCrossfadeControllerImpl?(false)
            })
        } else {
            rightNavigationButton = nil
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
        
        let nightMode = nightModePreview || presentationData.autoNightModeTriggered
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Themes_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: themePickerControllerEntries(presentationData: presentationData, presentationThemeSettings: settings, themeReference: themeReference, availableThemes: availableThemes, chatThemes: chatThemes, nightMode: nightMode, animatedEmojiStickers: animatedEmojiStickers), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        let _ = switchNode.description
    }
    
    let controller = ThemePickerControllerImpl(context: context, state: signal)
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
            
            let sectionInset = max(16.0, floor((controller.displayNode.frame.width - 674.0) / 2.0))
            
            let crossfadeController = ThemeSettingsCrossfadeController(view: view, topOffset: topOffset, bottomOffset: bottomOffset, leftOffset: leftOffset, sideInset: sectionInset)
            crossfadeController.didAppear = { [weak themeItemNode, weak colorItemNode] in
                if view != nil {
                    themeItemNode?.animateCrossfadeTransition()
                    colorItemNode?.animateCrossfadeTransition()
                }
            }
            
            context.sharedContext.presentGlobalController(crossfadeController, nil)
        }
    }
    selectThemeImpl = { baseTheme, theme, preset in
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
            var updatedBaseTheme: TelegramBaseTheme?
            if case let .cloud(info) = theme {
                updatedTheme = .cloud(PresentationCloudTheme(theme: info.theme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: info.theme.isCreator ? context.account.id : nil))
                if let baseTheme = baseTheme, let settings = info.theme.settings?.first(where: { $0.baseTheme == baseTheme }) {
                    updatedBaseTheme = baseTheme
                    baseThemeIndex = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)).index
                    updatedThemeBaseIndex = baseThemeIndex
                } else if let settings = info.theme.settings?.first {
                    baseThemeIndex = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)).index
                    updatedThemeBaseIndex = baseThemeIndex
                }
            } else {
                updatedThemeBaseIndex = theme.index
            }

            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var updatedThemePreferredBaseTheme = current.themePreferredBaseTheme
                if let updatedBaseTheme = updatedBaseTheme {
                    updatedThemePreferredBaseTheme[updatedTheme.index] = updatedBaseTheme
                }
                var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                if case let .cloud(info) = updatedTheme, info.theme.settings?.contains(where: { $0.baseTheme == .night || $0.baseTheme == .tinted }) ?? false {
                    updatedAutomaticThemeSwitchSetting.theme = updatedTheme
                } else if autoNightModeTriggered && !preset {
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
                } else if case let .builtin(theme) = updatedTheme {
                    if [.day, .dayClassic].contains(theme) {
                        updatedAutomaticThemeSwitchSetting.theme = .builtin(.night)
                    } else {
                        updatedAutomaticThemeSwitchSetting.theme = updatedTheme
                    }
                }
                return current.withUpdatedTheme(updatedTheme).withUpdatedThemePreferredBaseTheme(updatedThemePreferredBaseTheme).withUpdatedAutomaticThemeSwitchSetting(updatedAutomaticThemeSwitchSetting)
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
    selectAccentColorImpl = { currentBaseTheme, accentColor in
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
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

private func iconColors(theme: PresentationTheme) -> [String: UIColor] {
    let accentColor = theme.actionSheet.controlAccentColor
    var colors: [String: UIColor] = [:]
    colors["Sunny.Path 14.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 15.Path.Stroke 1"] = accentColor
    colors["Path.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 39.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 24.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 25.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 18.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 41.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 43.Path.Stroke 1"] = accentColor
    colors["Path 10.Path.Fill 1"] = accentColor
    colors["Path 11.Path.Fill 1"] = accentColor
    return colors
}

private class SwitchIconNode: ASDisplayNode {
    private let animationContainerNode: ASDisplayNode
    private var animationNode: AnimationNode
    
    private var isDark = true
    
    init(theme: PresentationTheme) {
        let switchThemeSize = CGSize(width: 26.0, height: 26.0)
        
        self.animationContainerNode = ASDisplayNode()
        self.animationContainerNode.isUserInteractionEnabled = false
        self.animationNode = AnimationNode(animation: "anim_sun", colors: iconColors(theme: theme), scale: 1.0)
        self.animationNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.animationContainerNode)
        self.animationContainerNode.addSubnode(self.animationNode)
        
        self.animationContainerNode.frame = CGRect(origin: CGPoint(), size: switchThemeSize)
        self.animationNode.frame = CGRect(origin: CGPoint(), size: switchThemeSize)
        
        self.frame = CGRect(origin: CGPoint(), size: switchThemeSize)
    }
    
    func play(isDark: Bool, theme: PresentationTheme) {
        self.isDark = isDark
        self.animationNode.setAnimation(name: isDark ? "anim_sun_reverse" : "anim_sun", colors: iconColors(theme: theme))
        self.animationNode.playOnce()
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.animationNode.setAnimation(name: self.isDark ? "anim_sun" : "anim_sun_reverse", colors: iconColors(theme: theme))
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return self.animationContainerNode.frame.size
    }
}
