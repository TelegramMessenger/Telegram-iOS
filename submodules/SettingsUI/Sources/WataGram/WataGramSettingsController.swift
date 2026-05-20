import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class WataGramSettingsControllerArguments {
    let toggleReadReceipts: (Bool) -> Void
    let toggleTypingIndicator: (Bool) -> Void
    let toggleOnlineStatus: (Bool) -> Void
    let toggleStorySeen: (Bool) -> Void

    init(
        toggleReadReceipts: @escaping (Bool) -> Void,
        toggleTypingIndicator: @escaping (Bool) -> Void,
        toggleOnlineStatus: @escaping (Bool) -> Void,
        toggleStorySeen: @escaping (Bool) -> Void
    ) {
        self.toggleReadReceipts = toggleReadReceipts
        self.toggleTypingIndicator = toggleTypingIndicator
        self.toggleOnlineStatus = toggleOnlineStatus
        self.toggleStorySeen = toggleStorySeen
    }
}

private enum WataGramSettingsSection: Int32 {
    case ghostMode
}

private enum WataGramSettingsEntry: ItemListNodeEntry {
    case ghostModeHeader
    case readReceipts(Bool)
    case typingIndicator(Bool)
    case onlineStatus(Bool)
    case storySeen(Bool)
    case ghostModeFooter

    var section: ItemListSectionId {
        return WataGramSettingsSection.ghostMode.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .ghostModeHeader:
            return 0
        case .readReceipts:
            return 1
        case .typingIndicator:
            return 2
        case .onlineStatus:
            return 3
        case .storySeen:
            return 4
        case .ghostModeFooter:
            return 5
        }
    }

    static func <(lhs: WataGramSettingsEntry, rhs: WataGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! WataGramSettingsControllerArguments
        switch self {
        case .ghostModeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "GHOST MODE", sectionId: self.section)
        case let .readReceipts(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Don't send read receipts", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleReadReceipts(value)
            })
        case let .typingIndicator(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Don't send typing status", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleTypingIndicator(value)
            })
        case let .onlineStatus(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Don't update online status", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleOnlineStatus(value)
            })
        case let .storySeen(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Don't mark stories as seen", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleStorySeen(value)
            })
        case .ghostModeFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("These options stop the app from sending read receipts, typing indicators, online status updates, and story view marks to Telegram servers. Other people will not know that you've read their messages or seen their stories. Note: this is a client-side modification and may technically violate the Telegram Terms of Service."), sectionId: self.section)
        }
    }
}

private func wataGramSettingsControllerEntries(settings: WataGramSettings) -> [WataGramSettingsEntry] {
    var entries: [WataGramSettingsEntry] = []
    entries.append(.ghostModeHeader)
    entries.append(.readReceipts(settings.ghostModeReadReceipts))
    entries.append(.typingIndicator(settings.ghostModeTypingIndicator))
    entries.append(.onlineStatus(settings.ghostModeOnlineStatus))
    entries.append(.storySeen(settings.ghostModeStorySeen))
    entries.append(.ghostModeFooter)
    return entries
}

public func wataGramSettingsController(context: AccountContext) -> ViewController {
    let arguments = WataGramSettingsControllerArguments(
        toggleReadReceipts: { value in
            let _ = updateWataGramSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.ghostModeReadReceipts = value
                return current
            }).startStandalone()
        },
        toggleTypingIndicator: { value in
            let _ = updateWataGramSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.ghostModeTypingIndicator = value
                return current
            }).startStandalone()
        },
        toggleOnlineStatus: { value in
            let _ = updateWataGramSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.ghostModeOnlineStatus = value
                return current
            }).startStandalone()
        },
        toggleStorySeen: { value in
            let _ = updateWataGramSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.ghostModeStorySeen = value
                return current
            }).startStandalone()
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.wataGramSettings])
    )
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings: WataGramSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.wataGramSettings]?.get(WataGramSettings.self) ?? .defaultSettings

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("WataGram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: wataGramSettingsControllerEntries(settings: settings),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
