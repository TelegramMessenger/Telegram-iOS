import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class SupportSettingsControllerArguments {
    let updateSettings: (@escaping (SupportSettings) -> SupportSettings) -> Void

    init(updateSettings: @escaping (@escaping (SupportSettings) -> SupportSettings) -> Void) {
        self.updateSettings = updateSettings
    }
}

public enum SupportSettingsEntryTag: ItemListItemTag, Equatable {
    case sendSilently

    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? SupportSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum SupportSettingsSection: Int32 {
    case sending
}

private enum SupportSettingsEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case sendSilently
    }

    case sendSilently(String, Bool)

    var section: ItemListSectionId {
        switch self {
        case .sendSilently:
            return SupportSettingsSection.sending.rawValue
        }
    }

    var stableId: StableId {
        switch self {
        case .sendSilently:
            return .sendSilently
        }
    }

    var sortIndex: Int32 {
        switch self {
        case .sendSilently:
            return 4
        }
    }

    static func <(lhs: SupportSettingsEntry, rhs: SupportSettingsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportSettingsControllerArguments
        switch self {
        case let .sendSilently(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSettings { settings in
                    var settings = settings
                    settings.sendAllSilently = value
                    return settings
                }
            }, tag: SupportSettingsEntryTag.sendSilently)
        }
    }
}

private func supportSettingsEntries(presentationData: PresentationData, settings: SupportSettings) -> [SupportSettingsEntry] {
    let strings = presentationData.strings
    var entries: [SupportSettingsEntry] = []

    entries.append(.sendSilently(strings.Support_Settings_SendSilently, settings.sendAllSilently))
    return entries
}

public func supportSettingsController(context: AccountContext, focusOnItemTag: SupportSettingsEntryTag? = nil) -> ViewController {
    let arguments = SupportSettingsControllerArguments(updateSettings: { f in
        let _ = updateSupportSettingsInteractively(engine: context.engine, f).startStandalone()
    })

    let settings = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.supportSettings))
    |> map { entry -> SupportSettings in
        return entry?.get(SupportSettings.self) ?? .default
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        settings,
    )
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Support_Settings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportSettingsEntries(presentationData: presentationData, settings: settings), style: .blocks, ensureVisibleItemTag: focusOnItemTag)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
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
