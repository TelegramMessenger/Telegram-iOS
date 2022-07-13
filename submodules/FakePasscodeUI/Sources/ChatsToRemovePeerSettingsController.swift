import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import UIKit
import FakePasscode

private final class ChatsToRemovePeerSettingsControllerArguments {
    let updateRemovalType: (PeerRemovalType) -> Void
    let updateDeleteFromCompanion: (Bool) -> Void
    
    init(updateRemovalType: @escaping (PeerRemovalType) -> Void, updateDeleteFromCompanion: @escaping (Bool) -> Void) {
        self.updateRemovalType = updateRemovalType
        self.updateDeleteFromCompanion = updateDeleteFromCompanion
    }
}

private enum ChatsToRemovePeerSettingsSection: Int32 {
    case selectedChats
    case removalType
    case deleteOptions
}

private enum ChatsToRemovePeerSettingsEntry: ItemListNodeEntry {
    case selectedChatsHeader(PresentationTheme, String)
    case selectedChatsAttrString(PresentationTheme, NSAttributedString)
    case removalTypeHeader(PresentationTheme, String)
    case removalTypeDelete(PresentationTheme, String, Bool)
    case removalTypeHide(PresentationTheme, String, Bool)
    case removalTypeInfo(PresentationTheme, String)
    case deleteFromCompanion(PresentationTheme, String, Bool)
    case deleteFromCompanionInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .selectedChatsHeader, .selectedChatsAttrString:
                return ChatsToRemovePeerSettingsSection.selectedChats.rawValue
            case .removalTypeHeader, .removalTypeDelete, .removalTypeHide, .removalTypeInfo:
                return ChatsToRemovePeerSettingsSection.removalType.rawValue
            case .deleteFromCompanion, .deleteFromCompanionInfo:
                return ChatsToRemovePeerSettingsSection.deleteOptions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .selectedChatsHeader:
                return 0
            case .selectedChatsAttrString:
                return 1
            case .removalTypeHeader:
                return 2
            case .removalTypeDelete:
                return 3
            case .removalTypeHide:
                return 4
            case .removalTypeInfo:
                return 5
            case .deleteFromCompanion:
                return 6
            case .deleteFromCompanionInfo:
                return 7
        }
    }
    
    static func <(lhs: ChatsToRemovePeerSettingsEntry, rhs: ChatsToRemovePeerSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatsToRemovePeerSettingsControllerArguments
        switch self {
            case let .selectedChatsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .selectedChatsAttrString(_, attrString):
                return ItemListTextItem(presentationData: presentationData, text: .attributedString(attrString), sectionId: self.section)
            case let .removalTypeHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .removalTypeDelete(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateRemovalType(.delete)
                })
            case let .removalTypeHide(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateRemovalType(.hide)
                })
            case let .removalTypeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .deleteFromCompanion(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateDeleteFromCompanion(value)
                })
            case let .deleteFromCompanionInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChatsToRemovePeerSettingsState: Equatable {
    let removalType: PeerRemovalType?
    let shouldHaveOptionDeleteFromCompanion: Bool
    let deleteFromCompanion: Bool
    
    func withUpdatedRemovalType(_ removalType: PeerRemovalType) -> ChatsToRemovePeerSettingsState {
        return ChatsToRemovePeerSettingsState(removalType: removalType, shouldHaveOptionDeleteFromCompanion: self.shouldHaveOptionDeleteFromCompanion, deleteFromCompanion: self.deleteFromCompanion)
    }
    
    func withUpdatedDeleteFromCompanion(_ deleteFromCompanion: Bool) -> ChatsToRemovePeerSettingsState {
        return ChatsToRemovePeerSettingsState(removalType: self.removalType, shouldHaveOptionDeleteFromCompanion: self.shouldHaveOptionDeleteFromCompanion, deleteFromCompanion: deleteFromCompanion)
    }
}

private func chatsToRemovePeerSettingsEntries(context: AccountContext, presentationData: PresentationData, state: ChatsToRemovePeerSettingsState, selectedPeers: [RenderedPeer]) -> [ChatsToRemovePeerSettingsEntry] {
    var entries: [ChatsToRemovePeerSettingsEntry] = []
    
    if selectedPeers.count > 1 {
        let selectedChatsAttrString = selectedPeers.map { peer -> NSAttributedString in
            let peerName = peer.peer!.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(peer.chatMainPeer!).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            
            return NSAttributedString(string: peerName, font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize), textColor: peer.peer! is TelegramSecretChat ? presentationData.theme.chatList.secretTitleColor : presentationData.theme.list.itemPrimaryTextColor)
        }.reduce(into: NSMutableAttributedString()) { partialResult, attrString in
            if partialResult.length != .zero {
                partialResult.append(NSAttributedString(string: ", "))
            }
            partialResult.append(attrString)
        }
        
        entries.append(.selectedChatsHeader(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_SelectedChatsHeader.uppercased()))
        entries.append(.selectedChatsAttrString(presentationData.theme, selectedChatsAttrString))
    }
    
    entries.append(.removalTypeHeader(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeHeader.uppercased()))
    entries.append(.removalTypeDelete(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeDelete, state.removalType == .delete))
    entries.append(.removalTypeHide(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeHide, state.removalType == .hide))
    entries.append(.removalTypeInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeInfo))
    
    if state.removalType == .delete && state.shouldHaveOptionDeleteFromCompanion {
        entries.append(.deleteFromCompanion(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_DeleteFromCompanion, state.deleteFromCompanion))
        entries.append(.deleteFromCompanionInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_DeleteFromCompanionInfo))
    }
    
    return entries
}

public func chatsToRemovePeerSettingsController(context: AccountContext, peers: [RenderedPeer], peersWithRemoveOptions: [PeerWithRemoveOptions], updatePeersRemoveOptions: @escaping([PeerId], PeerRemovalType, Bool) -> Void) -> ViewController {
    let initialValue: ChatsToRemovePeerSettingsState
    let hasPeersWhichShouldHaveOptionDeleteFromCompanion = peers.contains(where: { peerShouldHaveOptionDeleteFromCompanion($0.peer!, context) })
    if peersWithRemoveOptions.isEmpty {
        initialValue = ChatsToRemovePeerSettingsState(removalType: nil, shouldHaveOptionDeleteFromCompanion: hasPeersWhichShouldHaveOptionDeleteFromCompanion, deleteFromCompanion: false)
    } else {
        let hasVariousRemovalTypeValues = !peersWithRemoveOptions.allSatisfy { peersWithRemoveOptions.first!.removalType == $0.removalType }
        let deleteFromCompanion = peersWithRemoveOptions.filter { removeOptions in
            if removeOptions.removalType == .delete, let peer = peers.first(where: { $0.peerId == removeOptions.peerId }) {
                return peerShouldHaveOptionDeleteFromCompanion(peer.peer!, context)
            }
            return false
        }.allSatisfy { $0.deleteFromCompanion }
        initialValue = ChatsToRemovePeerSettingsState(removalType: hasVariousRemovalTypeValues ? nil : peersWithRemoveOptions.first!.removalType, shouldHaveOptionDeleteFromCompanion: hasPeersWhichShouldHaveOptionDeleteFromCompanion, deleteFromCompanion: deleteFromCompanion)
    }
    let stateValue = Atomic(value: initialValue)
    let statePromise = ValuePromise(initialValue, ignoreRepeated: true)
    
    let updateState: ((ChatsToRemovePeerSettingsState) -> ChatsToRemovePeerSettingsState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
    }
    
    var completeImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    
    let arguments = ChatsToRemovePeerSettingsControllerArguments(updateRemovalType: { removalType in
        updateState { current in
            return current.withUpdatedRemovalType(removalType)
        }
    }, updateDeleteFromCompanion: { deleteFromCompanion in
        updateState { current in
            return current.withUpdatedDeleteFromCompanion(deleteFromCompanion)
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = chatsToRemovePeerSettingsEntries(context: context, presentationData: presentationData, state: state, selectedPeers: peers)
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            cancelImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.removalType != nil, action: {
            completeImpl?()
        })
        
        let title: String
        if peers.count > 1 {
            title = presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_SettingsTitle
        } else {
            let peer = peers.first!
            title = peer.peer!.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(peer.chatMainPeer!).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        }
        
        // .textWithSubtitle to enable controller.navigationItem.titleView
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .textWithSubtitle(title, ""), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: nil)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        controller.dismiss(animated: false)
    })
    
    completeImpl = { [weak controller] in
        let state = stateValue.with { $0 }
        if let removalType = state.removalType {
            controller?.dismiss()
            updatePeersRemoveOptions(peers.map({ $0.peerId }), removalType, removalType == .delete && state.deleteFromCompanion)
        }
    }
    
    cancelImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    if peers.count == 1, let peer = peers.first, peer.peer! is TelegramSecretChat {
        let _ = (controller.ready.get()
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { _ in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if let image = PresentationResourcesChat.chatTitleLockIcon(presentationData.theme) {
                let titleLeftIconNode = ASImageNode()
                titleLeftIconNode.isLayerBacked = true
                titleLeftIconNode.displayWithoutProcessing = true
                titleLeftIconNode.displaysAsynchronously = false
                
                titleLeftIconNode.image = image
                titleLeftIconNode.frame = CGRect(origin: CGPoint(x: -image.size.width - 3.0 - UIScreenPixel, y: 4.0), size: image.size)
                
                assert(controller.navigationItem.titleView != nil)
                controller.navigationItem.titleView?.subviews.first?.addSubnode(titleLeftIconNode)
            }
        })
    }
    
    return controller
}
