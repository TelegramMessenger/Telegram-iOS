import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import PresentationDataUtils

private final class PeerAllowedReactionListControllerArguments {
    let context: AccountContext
    let toggleAll: () -> Void
    let toggleItem: (String) -> Void
    
    init(
        context: AccountContext,
        toggleAll: @escaping () -> Void,
        toggleItem: @escaping (String) -> Void
    ) {
        self.context = context
        self.toggleAll = toggleAll
        self.toggleItem = toggleItem
    }
}

private enum PeerAllowedReactionListControllerSection: Int32 {
    case all
    case items
}

private enum PeerAllowedReactionListControllerEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case allowAll
        case allowAllInfo
        case itemsHeader
        case item(String)
    }
    
    case allowAll(text: String, isEnabled: Bool)
    case allowAllInfo(String)
    
    case itemsHeader(String)
    case item(index: Int, value: String, availableReactions: AvailableReactions?, reaction: String, text: String, isEnabled: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .allowAll, .allowAllInfo:
            return PeerAllowedReactionListControllerSection.all.rawValue
        case .itemsHeader, .item:
            return PeerAllowedReactionListControllerSection.items.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .allowAll:
            return .allowAll
        case .allowAllInfo:
            return .allowAllInfo
        case .itemsHeader:
            return .itemsHeader
        case let .item(_, value, _, _, _, _):
            return .item(value)
        }
    }
    
    var sortId: Int {
        switch self {
        case .allowAll:
            return 0
        case .allowAllInfo:
            return 1
        case .itemsHeader:
            return 2
        case let .item(index, _, _, _, _, _):
            return 100 + index
        }
    }
    
    static func ==(lhs: PeerAllowedReactionListControllerEntry, rhs: PeerAllowedReactionListControllerEntry) -> Bool {
        switch lhs {
        case let .allowAll(text, isEnabled):
            if case .allowAll(text, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        case let .allowAllInfo(text):
            if case .allowAllInfo(text) = rhs {
                return true
            } else {
                return false
            }
        case let .itemsHeader(text):
            if case .itemsHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .item(index, value, availableReactions, reaction, text, isEnabled):
            if case .item(index, value, availableReactions, reaction, text, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: PeerAllowedReactionListControllerEntry, rhs: PeerAllowedReactionListControllerEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeerAllowedReactionListControllerArguments
        switch self {
        case let .allowAll(text, isEnabled):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: isEnabled, sectionId: self.section, style: .blocks, updated: { _ in
                arguments.toggleAll()
            })
        case let .allowAllInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .itemsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .item(_, value, availableReactions, reaction, text, isEnabled):
            return ItemListReactionItem(
                context: arguments.context,
                presentationData: presentationData,
                availableReactions: availableReactions,
                reaction: reaction,
                title: text,
                value: isEnabled,
                sectionId: self.section,
                style: .blocks,
                updated: { _ in
                    arguments.toggleItem(value)
                }
            )
        }
    }
}

private struct PeerAllowedReactionListControllerState: Equatable {
    var updatedAllowedReactions: Set<String>? = nil
}

private func peerAllowedReactionListControllerEntries(
    presentationData: PresentationData,
    availableReactions: AvailableReactions?,
    peer: Peer?,
    cachedData: CachedPeerData?,
    state: PeerAllowedReactionListControllerState
) -> [PeerAllowedReactionListControllerEntry] {
    var entries: [PeerAllowedReactionListControllerEntry] = []
    
    if let availableReactions = availableReactions, let allowedReactions = state.updatedAllowedReactions {
        entries.append(.allowAll(text: presentationData.strings.PeerInfo_AllowedReactions_AllowAllText, isEnabled: !allowedReactions.isEmpty))
        let allInfoText: String
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
            allInfoText = presentationData.strings.PeerInfo_AllowedReactions_AllowAllChannelInfo
        } else {
            allInfoText = presentationData.strings.PeerInfo_AllowedReactions_AllowAllGroupInfo
        }
        entries.append(.allowAllInfo(allInfoText))
        
        entries.append(.itemsHeader(presentationData.strings.PeerInfo_AllowedReactions_ReactionListHeader))
        var index = 0
        for availableReaction in availableReactions.reactions {
            if !availableReaction.isEnabled {
                continue
            }
            entries.append(.item(index: index, value: availableReaction.value, availableReactions: availableReactions, reaction: availableReaction.value, text: availableReaction.title, isEnabled: allowedReactions.contains(availableReaction.value)))
            index += 1
        }
    }
    
    return entries
}

public func peerAllowedReactionListController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peerId: PeerId
) -> ViewController {
    let statePromise = ValuePromise(PeerAllowedReactionListControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeerAllowedReactionListControllerState())
    let updateState: ((PeerAllowedReactionListControllerState) -> PeerAllowedReactionListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    let _ = dismissImpl
    
    let actionsDisposable = DisposableSet()
    actionsDisposable.add((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.AllowedReactions(id: peerId))
    |> deliverOnMainQueue).start(next: { allowedReactions in
        updateState { state in
            var state = state
            state.updatedAllowedReactions = allowedReactions.flatMap(Set.init)
            return state
        }
    }))
    
    let arguments = PeerAllowedReactionListControllerArguments(
        context: context,
        toggleAll: {
            let _ = (context.engine.stickers.availableReactions()
            |> take(1)
            |> deliverOnMainQueue).start(next: { availableReactions in
                guard let availableReactions = availableReactions else {
                    return
                }
                updateState { state in
                    var state = state
                    if var updatedAllowedReactions = state.updatedAllowedReactions {
                        if updatedAllowedReactions.isEmpty {
                            for availableReaction in availableReactions.reactions {
                                if !availableReaction.isEnabled {
                                    continue
                                }
                                updatedAllowedReactions.insert(availableReaction.value)
                            }
                        } else {
                            updatedAllowedReactions.removeAll()
                        }
                        state.updatedAllowedReactions = updatedAllowedReactions
                    }
                    return state
                }
            })
        },
        toggleItem: { reaction in
            updateState { state in
                var state = state
                if var updatedAllowedReactions = state.updatedAllowedReactions {
                    if updatedAllowedReactions.contains(reaction) {
                        updatedAllowedReactions.remove(reaction)
                    } else {
                        updatedAllowedReactions.insert(reaction)
                    }
                    state.updatedAllowedReactions = updatedAllowedReactions
                }
                return state
            }
        }
    )
    
    let peerView = context.account.viewTracker.peerView(peerId)
    |> deliverOnMainQueue
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        peerView
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, availableReactions, peerView -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let title: String = presentationData.strings.PeerInfo_AllowedReactions_Title
        
        let entries = peerAllowedReactionListControllerEntries(
            presentationData: presentationData,
            availableReactions: availableReactions,
            peer: peerView.peers[peerId],
            cachedData: peerView.cachedData,
            state: state
        )
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.willDisappear = { _ in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.AllowedReactions(id: peerId))
        |> deliverOnMainQueue).start(next: { initialAllowedReactionList in
            let initialAllowedReactions = initialAllowedReactionList.flatMap(Set.init)
            
            let updatedAllowedReactions = stateValue.with({ $0 }).updatedAllowedReactions
            if let updatedAllowedReactions = updatedAllowedReactions, initialAllowedReactions != updatedAllowedReactions {
                let _ = context.engine.peers.updatePeerAllowedReactions(peerId: peerId, allowedReactions: Array(updatedAllowedReactions)).start()
            }
        })
    }
    dismissImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.dismiss()
    }
    
    return controller
}
