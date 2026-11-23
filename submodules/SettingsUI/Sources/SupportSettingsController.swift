import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting
import AlertUI
import LegacyMediaPickerUI
import SupportTemplates
import TranslateUI
import ChatListUI

private let supportChatLoadPeriods: [Int32] = [
    1 * 24 * 60 * 60,
    7 * 24 * 60 * 60,
    30 * 24 * 60 * 60,
    365 * 24 * 60 * 60,
    SupportSettings.allChatsLoadPeriod
]

private func supportChatLoadPeriodTitle(strings: PresentationStrings, period: Int32) -> String {
    if period == SupportSettings.allChatsLoadPeriod {
        return strings.Support_ChatLoading_All
    }
    return timeIntervalString(strings: strings, value: period)
}

private func supportSwitchBehaviors(strings: PresentationStrings) -> [(behavior: SupportSwitchBehavior, title: String)] {
    return [
        (.none, strings.Support_Switching_JustSend),
        (.next, strings.Support_Switching_Next),
        (.previous, strings.Support_Switching_Previous)
    ]
}

private func supportTemplateFileInfo(strings: PresentationStrings, file: SupportTemplatesFileInfo) -> String {
    let templates = strings.Support_Templates_FileTemplates(Int32(file.templateCount))
    let edited = strings.Support_Templates_FileEdited(Int32(file.editCount))
    switch (file.editCount > 0, file.hasUrl) {
    case (false, false):
        return templates
    case (true, false):
        return strings.Support_Templates_FileInfoEdited.replacingOccurrences(of: "{templates}", with: templates).replacingOccurrences(of: "{edited}", with: edited)
    case (false, true):
        return strings.Support_Templates_FileInfoUrl.replacingOccurrences(of: "{templates}", with: templates)
    case (true, true):
        return strings.Support_Templates_FileInfoEditedUrl.replacingOccurrences(of: "{templates}", with: templates).replacingOccurrences(of: "{edited}", with: edited)
    }
}

private final class SupportSettingsControllerArguments {
    let updateSettings: (@escaping (SupportSettings) -> SupportSettings) -> Void
    let selectPeriod: (Int32) -> Void
    let loadMore: (Int32) -> Void
    let importTemplates: () -> Void
    let reloadTemplates: () -> Void
    let setRevealedTemplateFile: (String?, String?) -> Void
    let removeTemplateFile: (String) -> Void
    let openTemplates: (SupportTemplatesSource) -> Void

    init(updateSettings: @escaping (@escaping (SupportSettings) -> SupportSettings) -> Void, selectPeriod: @escaping (Int32) -> Void, loadMore: @escaping (Int32) -> Void, importTemplates: @escaping () -> Void, reloadTemplates: @escaping () -> Void, setRevealedTemplateFile: @escaping (String?, String?) -> Void, removeTemplateFile: @escaping (String) -> Void, openTemplates: @escaping (SupportTemplatesSource) -> Void) {
        self.updateSettings = updateSettings
        self.selectPeriod = selectPeriod
        self.loadMore = loadMore
        self.importTemplates = importTemplates
        self.reloadTemplates = reloadTemplates
        self.setRevealedTemplateFile = setRevealedTemplateFile
        self.removeTemplateFile = removeTemplateFile
        self.openTemplates = openTemplates
    }
}

public enum SupportSettingsEntryTag: ItemListItemTag, Equatable {
    case sendSilently
    case period
    case loadMore

    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? SupportSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum SupportSettingsSection: Int32 {
    case switching
    case sending
    case order
    case period
    case loading
    case templates
}

private enum SupportSettingsEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case switchHeader
        case switchBehavior(Int32)
        case sendSilently
        case hideKeyboardOnSwitch
        case hideKeyboardOnSwitchInfo
        case fixChatsOrder
        case fixChatsOrderInfo
        case periodHeader
        case period(Int32)
        case periodInfo
        case loadMore
        case loadMoreInfo
        case templatesHeader
        case templatesAutocomplete
        case templatesOwn
        case templatesImport
        case templatesReload
        case templatesFile(String)
        case templatesInfo
    }

    case switchHeader(String)
    case switchBehavior(index: Int32, behavior: SupportSwitchBehavior, title: String, isSelected: Bool)
    case sendSilently(String, Bool)
    case hideKeyboardOnSwitch(String, Bool)
    case hideKeyboardOnSwitchInfo(String)
    case fixChatsOrder(String, Bool)
    case fixChatsOrderInfo(String)
    case periodHeader(String)
    case period(index: Int32, period: Int32, title: String, isSelected: Bool)
    case periodInfo(String)
    case loadMore(title: String, holeTimestamp: Int32?)
    case loadMoreInfo(String)
    case templatesHeader(String)
    case templatesAutocomplete(String, Bool)
    case templatesOwn(title: String, label: String)
    case templatesImport(String)
    case templatesReload(title: String, isEnabled: Bool)
    case templatesFile(index: Int32, name: String, info: String, isRevealed: Bool)
    case templatesInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .switchHeader, .switchBehavior:
            return SupportSettingsSection.switching.rawValue
        case .sendSilently, .hideKeyboardOnSwitch, .hideKeyboardOnSwitchInfo:
            return SupportSettingsSection.sending.rawValue
        case .fixChatsOrder, .fixChatsOrderInfo:
            return SupportSettingsSection.order.rawValue
        case .periodHeader, .period, .periodInfo:
            return SupportSettingsSection.period.rawValue
        case .loadMore, .loadMoreInfo:
            return SupportSettingsSection.loading.rawValue
        case .templatesHeader, .templatesAutocomplete, .templatesOwn, .templatesImport, .templatesReload, .templatesFile, .templatesInfo:
            return SupportSettingsSection.templates.rawValue
        }
    }

    var stableId: StableId {
        switch self {
        case .switchHeader:
            return .switchHeader
        case let .switchBehavior(_, behavior, _, _):
            return .switchBehavior(behavior.rawValue)
        case .sendSilently:
            return .sendSilently
        case .hideKeyboardOnSwitch:
            return .hideKeyboardOnSwitch
        case .hideKeyboardOnSwitchInfo:
            return .hideKeyboardOnSwitchInfo
        case .fixChatsOrder:
            return .fixChatsOrder
        case .fixChatsOrderInfo:
            return .fixChatsOrderInfo
        case .periodHeader:
            return .periodHeader
        case let .period(_, period, _, _):
            return .period(period)
        case .periodInfo:
            return .periodInfo
        case .loadMore:
            return .loadMore
        case .loadMoreInfo:
            return .loadMoreInfo
        case .templatesHeader:
            return .templatesHeader
        case .templatesAutocomplete:
            return .templatesAutocomplete
        case .templatesOwn:
            return .templatesOwn
        case .templatesImport:
            return .templatesImport
        case .templatesReload:
            return .templatesReload
        case let .templatesFile(_, name, _, _):
            return .templatesFile(name)
        case .templatesInfo:
            return .templatesInfo
        }
    }

    var sortIndex: Int32 {
        switch self {
        case .switchHeader:
            return 0
        case let .switchBehavior(index, _, _, _):
            return 1 + index
        case .sendSilently:
            return 4
        case .hideKeyboardOnSwitch:
            return 5
        case .hideKeyboardOnSwitchInfo:
            return 6
        case .fixChatsOrder:
            return 9
        case .fixChatsOrderInfo:
            return 10
        case .periodHeader:
            return 25
        case let .period(index, _, _, _):
            return 26 + index
        case .periodInfo:
            return 100
        case .loadMore:
            return 101
        case .loadMoreInfo:
            return 102
        case .templatesHeader:
            return 104
        case .templatesAutocomplete:
            return 105
        case .templatesOwn:
            return 106
        case .templatesImport:
            return 107
        case .templatesReload:
            return 108
        case let .templatesFile(index, _, _, _):
            return 109 + index
        case .templatesInfo:
            return Int32.max
        }
    }

    static func <(lhs: SupportSettingsEntry, rhs: SupportSettingsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportSettingsControllerArguments
        switch self {
        case let .switchHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .switchBehavior(_, behavior, title, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateSettings { settings in
                    var settings = settings
                    settings.switchBehavior = behavior
                    return settings
                }
            })
        case let .sendSilently(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSettings { settings in
                    var settings = settings
                    settings.sendAllSilently = value
                    return settings
                }
            }, tag: SupportSettingsEntryTag.sendSilently)
        case let .hideKeyboardOnSwitch(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSettings { settings in
                    var settings = settings
                    settings.hideKeyboardOnSwitch = value
                    return settings
                }
            })
        case let .fixChatsOrder(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSettings { settings in
                    var settings = settings
                    settings.fixChatsOrder = value
                    return settings
                }
            })
        case let .periodHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section, tag: SupportSettingsEntryTag.period)
        case let .period(_, period, title, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                if !isSelected {
                    arguments.selectPeriod(period)
                }
            })
        case let .hideKeyboardOnSwitchInfo(text), let .fixChatsOrderInfo(text), let .periodInfo(text), let .loadMoreInfo(text), let .templatesInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .templatesHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .templatesAutocomplete(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSettings { settings in
                    var settings = settings
                    settings.templatesAutocomplete = value
                    return settings
                }
            })
        case let .templatesOwn(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openTemplates(.own)
            })
        case let .templatesImport(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.importTemplates()
            })
        case let .templatesReload(title, isEnabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: isEnabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if isEnabled {
                    arguments.reloadTemplates()
                }
            })
        case let .templatesFile(_, name, info, isRevealed):
            return LocalizationListItem(presentationData: presentationData, systemStyle: .glass, id: name, title: name, subtitle: info, checked: false, activity: false, loading: false, editing: LocalizationListItemEditing(editable: true, editing: false, revealed: isRevealed, reorderable: false), sectionId: self.section, alwaysPlain: false, action: {
                arguments.openTemplates(.file(name))
            }, setItemWithRevealedOptions: { id, fromId in
                arguments.setRevealedTemplateFile(id, fromId)
            }, removeItem: { id in
                arguments.removeTemplateFile(id)
            })
        case let .loadMore(title, holeTimestamp):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: holeTimestamp != nil ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if let holeTimestamp {
                    arguments.loadMore(holeTimestamp)
                }
            }, tag: SupportSettingsEntryTag.loadMore)
        }
    }
}

func supportTemplatesStateSignal(manager: SupportTemplatesManager?) -> Signal<SupportTemplatesState?, NoError> {
    guard let manager else {
        return .single(nil)
    }
    return Signal { subscriber in
        let token = manager.addStateObserver { state in
            subscriber.putNext(state)
        }
        return ActionDisposable {
            manager.removeStateObserver(token)
        }
    }
}

private func supportSettingsEntries(presentationData: PresentationData, settings: SupportSettings, loadState: SupportChatListLoadState, templates: SupportTemplatesState?, revealedTemplateFile: String?) -> [SupportSettingsEntry] {
    let strings = presentationData.strings
    var entries: [SupportSettingsEntry] = []

    entries.append(.switchHeader(strings.Support_Switching_Header))
    for (index, option) in supportSwitchBehaviors(strings: strings).enumerated() {
        entries.append(.switchBehavior(index: Int32(index), behavior: option.behavior, title: option.title, isSelected: option.behavior == settings.switchBehavior))
    }

    entries.append(.sendSilently(strings.Support_Settings_SendSilently, settings.sendAllSilently))
    entries.append(.hideKeyboardOnSwitch(strings.Support_HideKeyboard_Title, settings.hideKeyboardOnSwitch))
    entries.append(.hideKeyboardOnSwitchInfo(strings.Support_HideKeyboard_Info))

    entries.append(.fixChatsOrder(strings.Support_FixOrder_Title, settings.fixChatsOrder))
    entries.append(.fixChatsOrderInfo(strings.Support_FixOrder_Info))

    entries.append(.periodHeader(strings.Support_ChatLoading_Header))
    for (index, period) in supportChatLoadPeriods.enumerated() {
        entries.append(.period(index: Int32(index), period: period, title: supportChatLoadPeriodTitle(strings: strings, period: period), isSelected: period == settings.chatLoadPeriod))
    }
    entries.append(.periodInfo(strings.Support_ChatLoading_Info))

    switch loadState {
    case .allLoaded:
        break
    case .loading:
        entries.append(.loadMore(title: strings.Support_ChatLoading_Loading, holeTimestamp: nil))
    case let .held(holeTimestamp):
        let date = stringForMediumDate(timestamp: holeTimestamp, strings: strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: false)
        entries.append(.loadMore(title: strings.Support_ChatLoading_LoadMore, holeTimestamp: holeTimestamp))
        entries.append(.loadMoreInfo(strings.Support_ChatLoading_LoadedBackTo.replacingOccurrences(of: "{date}", with: date)))
    }

    if let templates {
        entries.append(.templatesHeader(strings.Support_Templates_Header))
        entries.append(.templatesAutocomplete(strings.Support_Templates_Autocomplete, settings.templatesAutocomplete))
        entries.append(.templatesOwn(title: strings.Support_Templates_MyTemplates, label: templates.ownTemplateCount == 0 ? "" : "\(templates.ownTemplateCount)"))
        entries.append(.templatesImport(strings.Support_Templates_Import))
        entries.append(.templatesReload(title: templates.isReloading ? strings.Support_Templates_Reloading : strings.Support_Templates_Reload, isEnabled: !templates.isReloading))
        for (index, file) in templates.files.enumerated() {
            entries.append(.templatesFile(index: Int32(index), name: file.name, info: supportTemplateFileInfo(strings: strings, file: file), isRevealed: file.name == revealedTemplateFile))
        }
        if templates.errors.isEmpty {
            entries.append(.templatesInfo(strings.Support_Templates_SettingsInfo))
        } else {
            entries.append(.templatesInfo(strings.Support_Templates_LastReload.replacingOccurrences(of: "{errors}", with: templates.errors.map { supportTemplatesErrorText($0, presentationData: presentationData) }.joined(separator: "\n\n"))))
        }
    }

    return entries
}

public func supportSettingsController(context: AccountContext, focusOnItemTag: SupportSettingsEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let showTemplatesResult: (SupportTemplatesReloadResult, String) -> Void = { result, successText in
        supportPresentTemplatesReloadResult(context: context, result: result, successText: successText, elevatedLayout: false, present: { controller in
            presentControllerImpl?(controller, nil)
        })
    }

    let revealedTemplateFile = Atomic<String?>(value: nil)
    let revealedTemplateFilePromise = ValuePromise<String?>(nil, ignoreRepeated: true)

    let setPeriod: (Int32) -> Void = { period in
        let _ = updateSupportSettingsInteractively(engine: context.engine, { settings in
            var settings = settings
            settings.chatLoadPeriod = period
            return settings
        }).startStandalone()
    }

    let arguments = SupportSettingsControllerArguments(updateSettings: { f in
        let _ = updateSupportSettingsInteractively(engine: context.engine, f).startStandalone()
    }, selectPeriod: { period in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let title: String
        let text: String
        let actionTitle: String
        let actionType: TextAlertActionType
        if period == SupportSettings.allChatsLoadPeriod {
            title = presentationData.strings.Support_ChatLoading_AllTitle
            text = presentationData.strings.Support_ChatLoading_AllText
            actionTitle = presentationData.strings.Support_ChatLoading_AllAction
            actionType = .destructiveAction
        } else if period >= 365 * 24 * 60 * 60 {
            title = presentationData.strings.Support_ChatLoading_YearTitle
            text = presentationData.strings.Support_ChatLoading_YearText
            actionTitle = presentationData.strings.Support_ChatLoading_LoadAction
            actionType = .defaultAction
        } else if period >= 30 * 24 * 60 * 60 {
            title = presentationData.strings.Support_ChatLoading_MonthTitle
            text = presentationData.strings.Support_ChatLoading_MonthText
            actionTitle = presentationData.strings.Support_ChatLoading_LoadAction
            actionType = .defaultAction
        } else {
            setPeriod(period)
            return
        }
        presentControllerImpl?(textAlertController(context: context, title: title, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        }), TextAlertAction(type: actionType, title: actionTitle, action: {
            setPeriod(period)
        })]), nil)
    }, loadMore: { holeTimestamp in
        context.supportContext?.loadMoreChats(holeTimestamp: holeTimestamp)
    }, importTemplates: {
        guard let manager = context.supportTemplates else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(legacyICloudFilePicker(theme: presentationData.theme, mode: .import, hasMultiselection: true, documentTypes: ["public.plain-text"], completion: { urls in
            if urls.isEmpty {
                return
            }
            manager.importFiles(urls, completion: { result in
                showTemplatesResult(result, presentationData.strings.Support_Templates_Imported)
            })
        }), nil)
    }, reloadTemplates: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.supportTemplates?.reload(completion: { result in
            showTemplatesResult(result, presentationData.strings.Support_Templates_Reloaded)
        })
    }, setRevealedTemplateFile: { id, fromId in
        let updated = revealedTemplateFile.modify { current in
            if (id == nil && fromId == current) || (id != nil && fromId == nil) {
                return id
            }
            return current
        }
        revealedTemplateFilePromise.set(updated)
    }, removeTemplateFile: { name in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Support_Templates_RemoveFileText.replacingOccurrences(of: "{name}", with: name), actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        }), TextAlertAction(type: .destructiveAction, title: presentationData.strings.Support_Templates_RemoveFileAction, action: {
            context.supportTemplates?.removeFile(name: name)
        })]), nil)
    }, openTemplates: { source in
        if let manager = context.supportTemplates {
            pushControllerImpl?(supportTemplatesListController(context: context, manager: manager, source: source))
        }
    })

    let settings = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.supportSettings))
    |> map { entry -> SupportSettings in
        return entry?.get(SupportSettings.self) ?? .default
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        settings,
        context.engine.messages.supportChatListLoadState(),
        supportTemplatesStateSignal(manager: context.supportTemplates),
        revealedTemplateFilePromise.get(),
    )
    |> map { presentationData, settings, loadState, templates, revealedTemplateFile -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Support_Settings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportSettingsEntries(presentationData: presentationData, settings: settings, loadState: loadState, templates: templates, revealedTemplateFile: revealedTemplateFile), style: .blocks, ensureVisibleItemTag: focusOnItemTag)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }

    if let focusOnItemTag {
        var didFocusOnItem = false
        controller.afterTransactionCompleted = { [weak controller] in
            if !didFocusOnItem, let controller {
                controller.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag, tag.isEqual(to: focusOnItemTag) {
                        didFocusOnItem = true
                        itemNode.displayHighlight()
                    }
                }
            }
        }
    }

    return controller
}
