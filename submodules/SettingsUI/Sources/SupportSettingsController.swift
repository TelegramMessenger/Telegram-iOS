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
private final class SupportSettingsControllerArguments {
    let updateSettings: (@escaping (SupportSettings) -> SupportSettings) -> Void
    let selectPeriod: (Int32) -> Void
    let loadMore: (Int32) -> Void

    init(updateSettings: @escaping (@escaping (SupportSettings) -> SupportSettings) -> Void, selectPeriod: @escaping (Int32) -> Void, loadMore: @escaping (Int32) -> Void) {
        self.updateSettings = updateSettings
        self.selectPeriod = selectPeriod
        self.loadMore = loadMore
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
        case let .hideKeyboardOnSwitchInfo(text), let .fixChatsOrderInfo(text), let .periodInfo(text), let .loadMoreInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .loadMore(title, holeTimestamp):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: holeTimestamp != nil ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if let holeTimestamp {
                    arguments.loadMore(holeTimestamp)
                }
            }, tag: SupportSettingsEntryTag.loadMore)
        }
    }
}

private func supportSettingsEntries(presentationData: PresentationData, settings: SupportSettings, loadState: SupportChatListLoadState) -> [SupportSettingsEntry] {
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

    return entries
}

public func supportSettingsController(context: AccountContext, focusOnItemTag: SupportSettingsEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
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
    })

    let settings = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.supportSettings))
    |> map { entry -> SupportSettings in
        return entry?.get(SupportSettings.self) ?? .default
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        settings,
        context.engine.messages.supportChatListLoadState(),
    )
    |> map { presentationData, settings, loadState -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Support_Settings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportSettingsEntries(presentationData: presentationData, settings: settings, loadState: loadState), style: .blocks, ensureVisibleItemTag: focusOnItemTag)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
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
