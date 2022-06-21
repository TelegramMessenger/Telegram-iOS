import Foundation
import UIKit
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
import LegacyMediaPickerUI
import WallpaperResources
import AccountContext
import MediaResources

private final class EditThemeControllerArguments {
    let context: AccountContext
    let updateState: ((EditThemeControllerState) -> EditThemeControllerState) -> Void
    let openColors: () -> Void
    let openFile: () -> Void
    let toggleDark: () -> Void
    let convertToPresetTheme: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((EditThemeControllerState) -> EditThemeControllerState) -> Void, openColors: @escaping () -> Void, openFile: @escaping () -> Void, toggleDark: @escaping () -> Void, convertToPresetTheme: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.openColors = openColors
        self.openFile = openFile
        self.toggleDark = toggleDark
        self.convertToPresetTheme = convertToPresetTheme
    }
}

private enum EditThemeEntryTag: ItemListItemTag {
    case title
    case slug
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? EditThemeEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum EditThemeControllerSection: Int32 {
    case info
    case chatPreview
}

private enum EditThemeControllerEntry: ItemListNodeEntry {
    case title(PresentationTheme, PresentationStrings, String, String, Bool)
    case slug(PresentationTheme, PresentationStrings, String, String, Bool)
    case slugInfo(PresentationTheme, String)
    case chatPreviewHeader(PresentationTheme, String)
    case chatPreview(PresentationTheme, PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationChatBubbleCorners, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, [ChatPreviewMessageItem])
    case changeColors(PresentationTheme, String)
    case toggleDark(PresentationTheme, String)
    case convertToPresetTheme(PresentationTheme, String)
    case uploadTheme(PresentationTheme, String)
    case uploadInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .title, .slug, .slugInfo:
                return EditThemeControllerSection.info.rawValue
            case .chatPreviewHeader, .chatPreview, .changeColors, .toggleDark, .convertToPresetTheme, .uploadTheme, .uploadInfo:
                return EditThemeControllerSection.chatPreview.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .title:
                return 0
            case .slug:
                return 1
            case .slugInfo:
                return 2
            case .chatPreviewHeader:
                return 3
            case .chatPreview:
                return 4
            case .changeColors:
                return 5
            case .toggleDark:
                return 6
            case .convertToPresetTheme:
                return 7
            case .uploadTheme:
                return 8
            case .uploadInfo:
                return 9
        }
    }
    
    static func ==(lhs: EditThemeControllerEntry, rhs: EditThemeControllerEntry) -> Bool {
        switch lhs {
            case let .title(lhsTheme, lhsStrings, lhsTitle, lhsValue, lhsDone):
                if case let .title(rhsTheme, rhsStrings, rhsTitle, rhsValue, rhsDone) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsDone == rhsDone {
                    return true
                } else {
                    return false
                }
            case let .slug(lhsTheme, lhsStrings, lhsTitle, lhsValue, lhsEnabled):
                if case let .slug(rhsTheme, rhsStrings, rhsTitle, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .slugInfo(lhsTheme, lhsText):
                if case let .slugInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .chatPreviewHeader(lhsTheme, lhsText):
                if case let .chatPreviewHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .chatPreview(lhsTheme, lhsComponentTheme, lhsWallpaper, lhsFontSize, lhsChatBubbleCorners, lhsStrings, lhsTimeFormat, lhsNameOrder, lhsItems):
                if case let .chatPreview(rhsTheme, rhsComponentTheme, rhsWallpaper, rhsFontSize, rhsChatBubbleCorners, rhsStrings, rhsTimeFormat, rhsNameOrder, rhsItems) = rhs, lhsComponentTheme === rhsComponentTheme, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsChatBubbleCorners == rhsChatBubbleCorners, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder, lhsItems == rhsItems {
                    return true
                } else {
                    return false
                }
            case let .changeColors(lhsTheme, lhsText):
                if case let .changeColors(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .toggleDark(lhsTheme, lhsText):
                if case let .toggleDark(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .convertToPresetTheme(lhsTheme, lhsText):
                if case let .convertToPresetTheme(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .uploadTheme(lhsTheme, lhsText):
                if case let .uploadTheme(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .uploadInfo(lhsTheme, lhsText):
                if case let .uploadInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: EditThemeControllerEntry, rhs: EditThemeControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EditThemeControllerArguments
        switch self {
            case let .title(_, _, title, text, _):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: title, type: .regular(capitalization: true, autocorrection: false), returnKeyType: .default, clearType: .onFocus, tag: EditThemeEntryTag.title, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.title = value
                        return state
                    }
                }, action: {
                    
                })
            case let .slug(_, _, title, text, enabled):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "t.me/addtheme/", textColor: presentationData.theme.list.itemPrimaryTextColor), text: text, placeholder: title, type: .username, clearType: .onFocus, enabled: enabled, tag: EditThemeEntryTag.slug, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.slug = value
                        return state
                    }
                }, action: {
                    
                })
            case let .slugInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .chatPreviewHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .chatPreview(theme, componentTheme, wallpaper, fontSize, chatBubbleCorners, strings, dateTimeFormat, nameDisplayOrder, items):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: componentTheme, strings: strings, sectionId: self.section, fontSize: fontSize, chatBubbleCorners: chatBubbleCorners, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, messageItems: items)
            case let .changeColors(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openColors()
                })
            case let .toggleDark(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.toggleDark()
                })
            case let .convertToPresetTheme(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.convertToPresetTheme()
                })
            case let .uploadTheme(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openFile()
                })
            case let .uploadInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        }
    }
}

public enum EditThemeControllerMode: Equatable {
    case create(PresentationTheme?, TelegramThemeSettings?)
    case edit(PresentationCloudTheme)
}

private struct EditThemeControllerState: Equatable {
    var mode: EditThemeControllerMode
    var title: String
    var slug: String
    var updatedTheme: PresentationTheme?
    var updating: Bool
    var converting: Bool
}

private func editThemeControllerEntries(presentationData: PresentationData, state: EditThemeControllerState, previewTheme: PresentationTheme, hasSettings: Bool) -> [EditThemeControllerEntry] {
    var entries: [EditThemeControllerEntry] = []
    
    var isCreate = false
    if case .create = state.mode {
        isCreate = true
    }
    entries.append(.title(presentationData.theme, presentationData.strings, presentationData.strings.EditTheme_Title, state.title, isCreate))
    
    let infoText: String
    let uploadText: String
    let uploadInfo: String
    let previewIncomingReplyName: String
    let previewIncomingReplyText: String
    let previewIncomingText: String
    let previewOutgoingText: String
    switch state.mode {
        case .create:
            infoText = presentationData.strings.EditTheme_Create_TopInfo
            uploadText = presentationData.strings.EditTheme_UploadNewTheme
            uploadInfo = presentationData.strings.EditTheme_Create_BottomInfo
            previewIncomingReplyName = presentationData.strings.EditTheme_Create_Preview_IncomingReplyName
            previewIncomingReplyText = presentationData.strings.EditTheme_Create_Preview_IncomingReplyText
            previewIncomingText = presentationData.strings.EditTheme_Create_Preview_IncomingText
            previewOutgoingText = presentationData.strings.EditTheme_Create_Preview_OutgoingText
        case let .edit(theme):
            if let _ = theme.theme.file {
                infoText = presentationData.strings.EditTheme_Edit_TopInfo
                uploadText = presentationData.strings.EditTheme_UploadEditedTheme
                uploadInfo = presentationData.strings.EditTheme_Edit_BottomInfo
                previewIncomingReplyName = presentationData.strings.EditTheme_Expand_Preview_IncomingReplyName
                previewIncomingReplyText = presentationData.strings.EditTheme_Expand_Preview_IncomingReplyText
                previewIncomingText = presentationData.strings.EditTheme_Expand_Preview_IncomingText
                previewOutgoingText = presentationData.strings.EditTheme_Expand_Preview_OutgoingText
            } else {
                infoText = presentationData.strings.EditTheme_Expand_TopInfo
                uploadText = presentationData.strings.EditTheme_UploadNewTheme
                uploadInfo = presentationData.strings.EditTheme_Expand_BottomInfo
                previewIncomingReplyName = presentationData.strings.EditTheme_Edit_Preview_IncomingReplyName
                previewIncomingReplyText = presentationData.strings.EditTheme_Edit_Preview_IncomingReplyText
                previewIncomingText = presentationData.strings.EditTheme_Edit_Preview_IncomingText
                previewOutgoingText = presentationData.strings.EditTheme_Edit_Preview_OutgoingText
            }
    }
    
    if case .edit = state.mode {
        entries.append(.slug(presentationData.theme, presentationData.strings, presentationData.strings.EditTheme_ShortLink, state.slug, true))
    }
    
    entries.append(.slugInfo(presentationData.theme, infoText))
    
    entries.append(.chatPreviewHeader(presentationData.theme, presentationData.strings.EditTheme_Preview.uppercased()))
    entries.append(.chatPreview(presentationData.theme, previewTheme, previewTheme.chat.defaultWallpaper, presentationData.chatFontSize, presentationData.chatBubbleCorners, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, [ChatPreviewMessageItem(outgoing: false, reply: (previewIncomingReplyName, previewIncomingReplyText), text: previewIncomingText), ChatPreviewMessageItem(outgoing: true, reply: nil, text: previewOutgoingText)]))
    
    entries.append(.changeColors(presentationData.theme, presentationData.strings.EditTheme_ChangeColors))
    if hasSettings {
        if previewTheme.overallDarkAppearance {
//            entries.append(.toggleDark(presentationData.theme, "Toggle Base Theme"))
        }
    } else {
        if !isCreate {
//            entries.append(.convertToPresetTheme(presentationData.theme, "Convert to Preset Theme"))
        }
        entries.append(.uploadTheme(presentationData.theme, uploadText))
        entries.append(.uploadInfo(presentationData.theme, uploadInfo))
    }
    
    return entries
}

public func editThemeController(context: AccountContext, mode: EditThemeControllerMode, navigateToChat: ((PeerId) -> Void)? = nil, completion: ((PresentationThemeReference) -> Void)? = nil) -> ViewController {
    let initialState: EditThemeControllerState
    let previewThemePromise = Promise<PresentationTheme>()
    let settingsPromise = Promise<TelegramThemeSettings?>(nil)
    let hasSettings: Bool
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    switch mode {
        case let .create(existingTheme, settings):
            let theme: PresentationTheme
            let wallpaper: TelegramWallpaper
            if let existingTheme = existingTheme {
                theme = existingTheme
                wallpaper = theme.chat.defaultWallpaper
                settingsPromise.set(.single(settings))
                hasSettings = settings != nil
            } else if let settings = settings {
                theme = makePresentationTheme(settings: settings) ?? presentationData.theme
                wallpaper = theme.chat.defaultWallpaper
                settingsPromise.set(.single(settings))
                hasSettings = true
            } else {
                theme = presentationData.theme
                wallpaper = presentationData.chatWallpaper
                settingsPromise.set(.single(nil))
                hasSettings = false
            }
            initialState = EditThemeControllerState(mode: mode, title: generateThemeName(accentColor: theme.rootController.navigationBar.buttonColor), slug: "", updatedTheme: nil, updating: false, converting: false)
            previewThemePromise.set(.single(theme.withUpdated(name: "", defaultWallpaper: wallpaper)))
        case let .edit(info):
            hasSettings = info.theme.settings != nil
            settingsPromise.set(.single(info.theme.settings?.first))
            if let file = info.theme.file, let path = context.sharedContext.accountManager.mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let theme = makePresentationTheme(data: data, resolvedWallpaper: info.resolvedWallpaper) {
                if case let .file(file) = theme.chat.defaultWallpaper, file.id == 0 {
                    previewThemePromise.set(cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                    |> map ({ wallpaper -> PresentationTheme in
                        if let wallpaper = wallpaper {
                            return theme.withUpdated(name: nil, defaultWallpaper: wallpaper.wallpaper)
                        } else {
                            return theme.withUpdated(name: nil, defaultWallpaper: .color(theme.chatList.backgroundColor.argb))
                        }
                    }))
                } else {
                    previewThemePromise.set(.single(theme.withUpdated(name: nil, defaultWallpaper: info.resolvedWallpaper)))
                }
            } else {
                previewThemePromise.set(.single(presentationData.theme.withUpdated(name: "", defaultWallpaper: presentationData.chatWallpaper)))
                
            }
            initialState = EditThemeControllerState(mode: mode, title: info.theme.title, slug: info.theme.slug, updatedTheme: nil, updating: false, converting: false)
    }
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((EditThemeControllerState) -> EditThemeControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var errorImpl: ((EditThemeEntryTag) -> Void)?
    
    var generalThemeReference: PresentationThemeReference?
    if case let .edit(cloudTheme) = mode {
        generalThemeReference = PresentationThemeReference.cloud(cloudTheme).generalThemeReference
    } else if case let .create(existingTheme, _) = mode, existingTheme == nil {
        generalThemeReference = PresentationThemeReference.builtin(presentationData.theme.referenceTheme)
    }
    
    let arguments = EditThemeControllerArguments(context: context, updateState: { f in
        updateState(f)
    }, openColors: {
        let _ = (combineLatest(queue: Queue.mainQueue(), previewThemePromise.get(), settingsPromise.get())
        |> take(1)).start(next: { theme, previousSettings in
            var controllerDismissImpl: (() -> Void)?
            var generalThemeReference = generalThemeReference
            if let settings = previousSettings {
                generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme))
            }
            let controller = ThemeAccentColorController(context: context, mode: .edit(settings: previousSettings, theme: theme, wallpaper: nil, generalThemeReference: generalThemeReference, defaultThemeReference: nil, create: false, completion: { updatedTheme, settings in
                updateState { current in
                    var state = current
                    previewThemePromise.set(.single(updatedTheme))
                    state.updatedTheme = updatedTheme
                    return state
                }
                if previousSettings != nil {
                    settingsPromise.set(.single(settings))
                }
                controllerDismissImpl?()
            }))
            controllerDismissImpl = { [weak controller] in
                controller?.dismiss()
            }
            pushControllerImpl?(controller)
        })
    }, openFile: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = legacyICloudFilePicker(theme: presentationData.theme, mode: .import, documentTypes: ["org.telegram.Telegram-iOS.theme"], completion: { urls in
            if let url = urls.first{
                if let data = try? Data(contentsOf: url), let theme = makePresentationTheme(data: data) {
                    if case let .file(file) = theme.chat.defaultWallpaper, file.id == 0 {
                        let _ = (cachedWallpaper(account: context.account, slug: file.slug, settings: file.settings)
                        |> mapToSignal { wallpaper -> Signal<TelegramWallpaper?, NoError> in
                            if let wallpaper = wallpaper, case let .file(file) = wallpaper.wallpaper {
                                var convertedRepresentations: [ImageRepresentationWithReference] = []
                                convertedRepresentations.append(ImageRepresentationWithReference(representation: TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 100, height: 100), resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil), reference: .wallpaper(wallpaper: .slug(file.slug), resource: file.file.resource)))
                                return wallpaperDatas(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: .standalone(media: file.file), representations: convertedRepresentations, alwaysShowThumbnailFirst: false, thumbnail: false, onlyFullSize: true, autoFetchFullSize: true, synchronousLoad: false)
                                |> mapToSignal { _, fullSizeData, complete -> Signal<TelegramWallpaper?, NoError> in
                                    guard complete, let fullSizeData = fullSizeData else {
                                        return .complete()
                                    }
                                    context.sharedContext.accountManager.mediaBox.storeResourceData(file.file.resource.id, data: fullSizeData, synchronous: true)
                                    return .single(wallpaper.wallpaper)
                                }
                            } else {
                                return .single(nil)
                            }
                        }
                        |> deliverOnMainQueue).start(next: { wallpaper in
                            let updatedTheme = theme.withUpdated(name: nil, defaultWallpaper: wallpaper)
                            updateState { current in
                                var state = current
                                previewThemePromise.set(.single(updatedTheme))
                                state.updatedTheme = updatedTheme
                                return state
                            }
                        })
                    } else {
                        updateState { current in
                            var state = current
                            previewThemePromise.set(.single(theme))
                            state.updatedTheme = theme
                            return state
                        }
                    }
                    settingsPromise.set(.single(nil))
                }
                else {
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.EditTheme_FileReadError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            }
        })
        presentControllerImpl?(controller, nil)
    }, toggleDark: {
        let _ = (combineLatest(queue: Queue.mainQueue(), previewThemePromise.get(), settingsPromise.get())
        |> take(1)).start(next: { theme, previousSettings in
            var updatedTheme = theme
            var updatedSettings: TelegramThemeSettings?
            
            if let themeSettings = previousSettings {
                if updatedTheme.referenceTheme == .night {
                    updatedTheme = updatedTheme.withUpdated(referenceTheme: .nightAccent)
                    updatedSettings = TelegramThemeSettings(baseTheme: .tinted, accentColor: themeSettings.accentColor, outgoingAccentColor: themeSettings.outgoingAccentColor, messageColors: themeSettings.messageColors, animateMessageColors: themeSettings.animateMessageColors, wallpaper: themeSettings.wallpaper)
                    if let settings = updatedSettings, let theme = makePresentationTheme(settings: settings) {
                        updatedTheme = theme
                    }
                } else if updatedTheme.referenceTheme == .nightAccent {
                    updatedSettings = TelegramThemeSettings(baseTheme: .night, accentColor: themeSettings.accentColor, outgoingAccentColor: themeSettings.outgoingAccentColor, messageColors: themeSettings.messageColors, animateMessageColors: themeSettings.animateMessageColors, wallpaper: themeSettings.wallpaper)
                    if let settings = updatedSettings, let theme = makePresentationTheme(settings: settings) {
                        updatedTheme = theme
                    }
                }
            }
            
            updateState { current in
                var state = current
                previewThemePromise.set(.single(updatedTheme))
                state.updatedTheme = updatedTheme
                return state
            }
            if previousSettings != nil {
                settingsPromise.set(.single(updatedSettings))
            }
        })
    }, convertToPresetTheme: {
        let _ = (previewThemePromise.get()
        |> take(1)).start(next: { theme in
            var outgoingAccentColor: UIColor?
            if case .classic = theme.referenceTheme.baseTheme {
                outgoingAccentColor = theme.chat.message.outgoing.accentTextColor
            }
            let settings = TelegramThemeSettings(baseTheme: theme.referenceTheme.baseTheme, accentColor: theme.rootController.navigationBar.accentTextColor, outgoingAccentColor: outgoingAccentColor, messageColors: theme.chat.message.outgoing.bubble.withWallpaper.fill.map { $0.argb }, animateMessageColors: theme.chat.animateMessageColors, wallpaper: theme.chat.defaultWallpaper)
            settingsPromise.set(.single(settings))
            updateState { current in
                var state = current
                state.converting = true
                return state
            }
        })
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), previewThemePromise.get(), settingsPromise.get())
    |> map { presentationData, state, previewTheme, currentSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        var focusItemTag: ItemListItemTag?
        if case .create = state.mode {
            focusItemTag = EditThemeEntryTag.title
        }
        
        let rightNavigationButton: ItemListNavigationButton
        if state.updating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            let isComplete: Bool
            if case .create = mode {
                isComplete = !state.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
            } else {
                isComplete = !state.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty && !state.slug.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
            }
            
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: isComplete, action: {
                if state.title.count > 128 {
                    errorImpl?(.title)
                    return
                }
                if case .create = mode {
                } else if state.slug.count < 5 || state.slug.count > 64 {
                    errorImpl?(.slug)
                    return
                }
                
                dismissInputImpl?()
                arguments.updateState { current in
                    var state = current
                    state.updating = true
                    return state
                }
                
                let _ = (combineLatest(queue: Queue.mainQueue(), previewThemePromise.get(), settingsPromise.get())
                |> take(1)).start(next: { previewTheme, settings in
                    let saveThemeTemplateFile: (String, LocalFileMediaResource, @escaping () -> Void) -> Void = { title, resource, completion in
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: resource.fileId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgtheme-ios", size: nil, attributes: [.FileName(fileName: "\(title).tgios-theme")])
                        let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

                        let _ = enqueueMessages(account: context.account, peerId: context.account.peerId, messages: [message]).start()

                        if let navigateToChat = navigateToChat {
                            presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.EditTheme_ThemeTemplateAlertTitle, text: presentationData.strings.EditTheme_ThemeTemplateAlertText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_SavedMessages, action: {
                                completion()
                                navigateToChat(context.account.peerId)
                            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                completion()
                            })], actionLayout: .vertical), nil)
                        } else {
                            completion()
                        }
                    }
                    
                    let theme: PresentationTheme?
                    let hasCustomFile: Bool
                    if let updatedTheme = state.updatedTheme {
                        theme = updatedTheme.withUpdated(name: state.title, defaultWallpaper: nil)
                        hasCustomFile = true
                    } else {
                        if case let .edit(info) = mode, let _ = info.theme.file {
                            theme = nil
                            hasCustomFile = true
                        } else {
                            theme = previewTheme.withUpdated(name: state.title, defaultWallpaper: nil)
                            hasCustomFile = false
                        }
                    }
                    
                    let themeResource: LocalFileMediaResource?
                    let themeData: Data?
                    let themeThumbnailData: Data?
                    if let theme = theme, let themeString = encodePresentationTheme(theme), let data = themeString.data(using: .utf8) {
                        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        themeResource = resource
                        themeData = data
                        
                        var wallpaperImage: UIImage?
                        if case .file = theme.chat.defaultWallpaper {
                            wallpaperImage = chatControllerBackgroundImage(theme: theme, wallpaper: theme.chat.defaultWallpaper, mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: false)
                        }
                        let themeThumbnail = generateImage(CGSize(width: 213, height: 320.0), contextGenerator: { size, context in
                            if let image = generateImage(CGSize(width: 194.0, height: 291.0), contextGenerator: { size, c in
                                drawThemeImage(context: c, theme: theme, wallpaperImage: wallpaperImage, size: size)
                            })?.cgImage {
                                context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                            }
                        }, scale: 1.0)
                        themeThumbnailData = themeThumbnail?.jpegData(compressionQuality: 0.6)
                    } else {
                        themeResource = nil
                        themeData = nil
                        themeThumbnailData = nil
                    }
                    
                    let resolvedWallpaper: TelegramWallpaper?
                    if let theme = theme, case let .file(file) = theme.chat.defaultWallpaper, file.id != 0 {
                        resolvedWallpaper = theme.chat.defaultWallpaper
                        updateCachedWallpaper(account: context.account, wallpaper: theme.chat.defaultWallpaper)
                    } else {
                        resolvedWallpaper = nil
                    }
                    
                    
                    let prepare: Signal<CreateThemeResult, CreateThemeError>
                    if let resolvedWallpaper = resolvedWallpaper, case let .file(file) = resolvedWallpaper, resolvedWallpaper.isPattern {
                        let resource = file.file.resource
                        
                        var data: Data?
                        if let path = context.account.postbox.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                            data = maybeData
                        } else if let path = context.sharedContext.accountManager.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                            data = maybeData
                        }
                        
                        if let data = data {
                            context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                            prepare = .complete()
                        } else {
                            prepare = .complete()
                        }
                    } else {
                        prepare = .complete()
                    }
                    
                    switch mode {
                        case .create:
                            if let themeResource = themeResource {
                                let _ = (prepare |> then(createTheme(account: context.account, title: state.title, resource: themeResource, thumbnailData: themeThumbnailData, settings: settings.flatMap { [$0] })
                                |> deliverOnMainQueue)).start(next: { next in
                                    if case let .result(resultTheme) = next {
                                        let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                        let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                            if let resource = resultTheme.file?.resource, let data = themeData {
                                                context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                            }
                                            
                                            let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: context.account.id))
                                                                                           
                                            var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                            themeSpecificChatWallpapers[themeReference.index] = nil
                                            
                                            return PresentationThemeSettings(theme: themeReference, themePreferredBaseTheme: current.themePreferredBaseTheme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, chatBubbleSettings: current.chatBubbleSettings, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, reduceMotion: current.reduceMotion)
                                        }) |> deliverOnMainQueue).start(completed: {
                                            if !hasCustomFile {
                                                saveThemeTemplateFile(state.title, themeResource, {
                                                    dismissImpl?()
                                                })
                                            } else {
                                                dismissImpl?()
                                            }
                                        })
                                    }
                                }, error: { error in
                                    arguments.updateState { current in
                                        var state = current
                                        state.updating = false
                                        return state
                                    }
                                })
                            }
                        case let .edit(info):
                            let _ = (prepare |> then(updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: info.theme, title: state.title, slug: state.slug, resource: state.converting ? nil : themeResource, settings: settings.flatMap { [$0] })
                            |> deliverOnMainQueue)).start(next: { next in
                                if case let .result(resultTheme) = next {
                                    let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                    let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                        if let resource = resultTheme.file?.resource, let data = themeData {
                                            context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                        }
                                        
                                        let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: context.account.id))
                                                                                       
                                        var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                        themeSpecificChatWallpapers[themeReference.index] = nil
                                        
                                        return PresentationThemeSettings(theme: themeReference, themePreferredBaseTheme: current.themePreferredBaseTheme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, chatBubbleSettings: current.chatBubbleSettings, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, reduceMotion: current.reduceMotion)
                                    }) |> deliverOnMainQueue).start(completed: {
                                        if let themeResource = themeResource, !hasCustomFile {
                                            saveThemeTemplateFile(state.title, themeResource, {
                                                dismissImpl?()
                                            })
                                        } else {
                                            dismissImpl?()
                                        }
                                    })
                                }
                            }, error: { error in
                                arguments.updateState { current in
                                    var state = current
                                    state.updating = false
                                    return state
                                }
                                
                                var errorText: String?
                                switch error {
                                    case .slugOccupied:
                                        errorText = presentationData.strings.EditTheme_ErrorLinkTaken
                                    case .slugInvalid:
                                        errorText = presentationData.strings.EditTheme_ErrorInvalidCharacters
                                    default:
                                        break
                                }
                                
                                if let errorText = errorText {
                                    presentControllerImpl?(textAlertController(context: context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                }
                            })
                    }
                })
            })
        }
        
        let title: String
        switch mode {
            case .create:
                title = presentationData.strings.EditTheme_CreateTitle
            case let .edit(theme):
                if theme.theme.file == nil {
                    title = presentationData.strings.EditTheme_CreateTitle
                } else {
                    title = presentationData.strings.EditTheme_EditTitle
                }
        }
        let hasSettings = hasSettings || currentSettings != nil
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: editThemeControllerEntries(presentationData: presentationData, state: state, previewTheme: previewTheme, hasSettings: hasSettings), style: .blocks, focusItemTag: focusItemTag, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    let hapticFeedback = HapticFeedback()
    errorImpl = { [weak controller] targetTag in
        hapticFeedback.error()
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                itemNode.animateError()
            }
        }
    }
    return controller
}
