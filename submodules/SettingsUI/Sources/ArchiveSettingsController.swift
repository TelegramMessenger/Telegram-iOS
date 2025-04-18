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
import UndoUI

private final class ArchiveSettingsControllerArguments {
    let updateUnmuted: (Bool) -> Void
    let updateFolders: (Bool) -> Void
    let updateUnknown: (Bool?) -> Void
    
    init(
        updateUnmuted: @escaping (Bool) -> Void,
        updateFolders: @escaping (Bool) -> Void,
        updateUnknown: @escaping (Bool?) -> Void
    ) {
        self.updateUnmuted = updateUnmuted
        self.updateFolders = updateFolders
        self.updateUnknown = updateUnknown
    }
}

private enum ArchiveSettingsSection: Int32 {
    case unmuted
    case folders
    case unknown
}

private enum ArchiveSettingsControllerEntry: ItemListNodeEntry {
    case unmutedHeader
    case unmutedValue(Bool)
    case unmutedFooter
    
    case foldersHeader
    case foldersValue(Bool)
    case foldersFooter
    
    case unknownHeader
    case unknownValue(isOn: Bool, isLocked: Bool)
    case unknownFooter
    
    var section: ItemListSectionId {
        switch self {
        case .unmutedHeader, .unmutedValue, .unmutedFooter:
            return ArchiveSettingsSection.unmuted.rawValue
        case .foldersHeader, .foldersValue, .foldersFooter:
            return ArchiveSettingsSection.folders.rawValue
        case .unknownHeader, .unknownValue, .unknownFooter:
            return ArchiveSettingsSection.unknown.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .unmutedHeader:
            return 0
        case .unmutedValue:
            return 1
        case .unmutedFooter:
            return 2
        case .foldersHeader:
            return 3
        case .foldersValue:
            return 4
        case .foldersFooter:
            return 5
        case .unknownHeader:
            return 6
        case .unknownValue:
            return 7
        case .unknownFooter:
            return 8
        }
    }
        
    static func <(lhs: ArchiveSettingsControllerEntry, rhs: ArchiveSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ArchiveSettingsControllerArguments
        switch self {
        case .unmutedHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.ArchiveSettings_UnmutedChatsHeader, sectionId: self.section)
        case let .unmutedValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: presentationData.strings.ArchiveSettings_KeepArchived, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateUnmuted(value)
            })
        case .unmutedFooter:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.ArchiveSettings_UnmutedChatsFooter), sectionId: self.section)
        case .foldersHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.ArchiveSettings_FolderChatsHeader, sectionId: self.section)
        case let .foldersValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: presentationData.strings.ArchiveSettings_KeepArchived, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFolders(value)
            })
        case .foldersFooter:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.ArchiveSettings_FolderChatsFooter), sectionId: self.section)
        case .unknownHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.ArchiveSettings_UnknownChatsHeader, sectionId: self.section)
        case let .unknownValue(isOn, isLocked):
            return ItemListSwitchItem(presentationData: presentationData, title: presentationData.strings.ArchiveSettings_AutomaticallyArchive, value: isOn, enableInteractiveChanges: !isLocked, enabled: true, displayLocked: isLocked, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateUnknown(value)
            }, activatedWhileDisabled: {
                arguments.updateUnknown(nil)
            })
        case .unknownFooter:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.ArchiveSettings_UnknownChatsFooter), sectionId: self.section)
        }
    }
}

private func archiveSettingsControllerEntries(
    presentationData: PresentationData,
    settings: GlobalPrivacySettings,
    isPremium: Bool,
    isPremiumEnabled: Bool
) -> [ArchiveSettingsControllerEntry] {
    var entries: [ArchiveSettingsControllerEntry] = []
    
    entries.append(.unmutedHeader)
    entries.append(.unmutedValue(settings.keepArchivedUnmuted))
    entries.append(.unmutedFooter)
    
    if !settings.keepArchivedUnmuted {
        entries.append(.foldersHeader)
        entries.append(.foldersValue(settings.keepArchivedFolders))
        entries.append(.foldersFooter)
    }
    
    if isPremium || isPremiumEnabled {
        entries.append(.unknownHeader)
        entries.append(.unknownValue(isOn: isPremium && settings.automaticallyArchiveAndMuteNonContacts, isLocked: !isPremium))
        entries.append(.unknownFooter)
    }
    
    return entries
}

public func archiveSettingsController(context: AccountContext) -> ViewController {
    let updateDisposable = MetaDisposable()
    
    updateDisposable.set(context.engine.privacy.requestAccountPrivacySettings().start())
    
    var presentUndoImpl: ((UndoOverlayContent) -> Void)?
    var presentPremiumImpl: (() -> Void)?
    
    let arguments = ArchiveSettingsControllerArguments(
        updateUnmuted: { value in
            let _ = context.engine.privacy.updateAccountKeepArchivedUnmuted(value: value).start()
        },
        updateFolders: { value in
            let _ = context.engine.privacy.updateAccountKeepArchivedFolders(value: value).start()
        },
        updateUnknown: { value in
            if let value {
                let _ = context.engine.privacy.updateAccountAutoArchiveChats(value: value).start()
            } else {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentUndoImpl?(.premiumPaywall(title: nil, text: presentationData.strings.ArchiveSettings_TooltipPremiumRequired, customUndoText: nil, timeout: nil, linkAction: { _ in
                    presentPremiumImpl?()
                }))
            }
        }
    )
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.GlobalPrivacy()),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.App()),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings, appConfiguration, accountPeer -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = accountPeer?.isPremium ?? false
        let isPremiumDisabled = PremiumConfiguration.with(appConfiguration: appConfiguration).isPremiumDisabled
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ArchiveSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: archiveSettingsControllerEntries(
            presentationData: presentationData,
            settings: settings,
            isPremium: isPremium,
            isPremiumEnabled: !isPremiumDisabled
        ), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    
    presentUndoImpl = { [weak controller] content in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, action: { _ in
            return false
        }), in: .current)
    }
    presentPremiumImpl = { [weak controller] in
        guard let controller else {
            return
        }
        let premiumController = context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
        controller.push(premiumController)
    }
    
    return controller
}
