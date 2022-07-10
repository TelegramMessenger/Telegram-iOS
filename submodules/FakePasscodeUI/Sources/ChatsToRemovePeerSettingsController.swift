import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import FakePasscode

private final class ChatsToRemovePeerSettingsControllerArguments {
    let updateRemovalType: (PeerRemovalType) -> Void
    
    init(updateRemovalType: @escaping (PeerRemovalType) -> Void) {
        self.updateRemovalType = updateRemovalType
    }
}

private enum ChatsToRemovePeerSettingsSection: Int32 {
    case selectedChats
    case removalType
}

private enum ChatsToRemovePeerSettingsEntry: ItemListNodeEntry {
    case selectedChatsHeader(PresentationTheme, String)
    case selectedChatsAttrString(PresentationTheme, NSAttributedString)
    case removalTypeHeader(PresentationTheme, String)
    case removalTypeDelete(PresentationTheme, String, Bool)
    case removalTypeHide(PresentationTheme, String, Bool)
    case removalTypeInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .selectedChatsHeader, .selectedChatsAttrString:
                return ChatsToRemovePeerSettingsSection.selectedChats.rawValue
            case .removalTypeHeader, .removalTypeDelete, .removalTypeHide, .removalTypeInfo:
                return ChatsToRemovePeerSettingsSection.removalType.rawValue
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
        }
    }
}

private struct ChatsToRemovePeerSettingsState: Equatable {
    let removalType: PeerRemovalType?
    let hasVariousValues: Bool
    
    func withUpdatedRemovalType(_ removalType: PeerRemovalType) -> ChatsToRemovePeerSettingsState {
        return ChatsToRemovePeerSettingsState(removalType: removalType, hasVariousValues: self.hasVariousValues)
    }
}

private func chatsToRemovePeerSettingsEntries(context: AccountContext, presentationData: PresentationData, state: ChatsToRemovePeerSettingsState, selectedPeers: [RenderedPeer]) -> [ChatsToRemovePeerSettingsEntry] {
    var entries: [ChatsToRemovePeerSettingsEntry] = []
    
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
    entries.append(.removalTypeHeader(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeHeader.uppercased()))
    entries.append(.removalTypeDelete(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeDelete, state.removalType == .delete))
    entries.append(.removalTypeHide(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeHide, state.removalType == .hide))
    entries.append(.removalTypeInfo(presentationData.theme, presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_RemovalTypeInfo))
    
    return entries
}

public func chatsToRemovePeerSettingsController(context: AccountContext, peerIds: [PeerId], peersWithRemoveOptions: [PeerWithRemoveOptions], updatePeersRemoveOptions: @escaping([PeerId], PeerRemovalType) -> Void) -> ViewController {
    let initialValue: ChatsToRemovePeerSettingsState
    if peersWithRemoveOptions.isEmpty {
        initialValue = ChatsToRemovePeerSettingsState(removalType: nil, hasVariousValues: false)
    } else {
        let hasVariousValues = !peersWithRemoveOptions.allSatisfy { peersWithRemoveOptions.first!.removalType == $0.removalType }
        initialValue = ChatsToRemovePeerSettingsState(removalType: hasVariousValues ? nil : peersWithRemoveOptions.first!.removalType, hasVariousValues: hasVariousValues)
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
    })
    
    let peersSignal = context.account.postbox.transaction { transaction -> [RenderedPeer] in
        var peers: [RenderedPeer] = []
        for peerId in peerIds {
            if let peer = transaction.getPeer(peerId) {
                if let associatedPeerId = peer.associatedPeerId {
                    if let associatedPeer = transaction.getPeer(associatedPeerId) {
                        peers.append(RenderedPeer(peerId: peerId, peers: SimpleDictionary([peer.id: peer, associatedPeer.id: associatedPeer])))
                    }
                } else {
                    peers.append(RenderedPeer(peer: peer))
                }
            }
        }
        return peers
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), peersSignal)
    |> deliverOnMainQueue
    |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = chatsToRemovePeerSettingsEntries(context: context, presentationData: presentationData, state: state, selectedPeers: peers)
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            cancelImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.removalType != nil, action: {
            completeImpl?()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.FakePasscodes_AccountActions_ChatsToRemove_SettingsTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: nil)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        controller.dismiss(animated: false)
    })
    
    completeImpl = { [weak controller] in
        if let removalType = stateValue.with({ $0 }).removalType {
            controller?.dismiss()
            updatePeersRemoveOptions(peerIds, removalType)
        }
    }
    
    cancelImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
