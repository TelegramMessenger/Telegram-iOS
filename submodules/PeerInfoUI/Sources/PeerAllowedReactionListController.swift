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

private enum PeerReactionsMode {
    case all
    case some
    case empty
}

private final class PeerAllowedReactionListControllerArguments {
    let context: AccountContext
    let setMode: (PeerReactionsMode, Bool) -> Void
    let toggleItem: (MessageReaction.Reaction) -> Void
    
    init(
        context: AccountContext,
        setMode: @escaping (PeerReactionsMode, Bool) -> Void,
        toggleItem: @escaping (MessageReaction.Reaction) -> Void
    ) {
        self.context = context
        self.setMode = setMode
        self.toggleItem = toggleItem
    }
}

private enum PeerAllowedReactionListControllerSection: Int32 {
    case all
    case items
}

private enum PeerAllowedReactionListControllerEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case allowSwitch
        case allowAllHeader
        case allowAll
        case allowSome
        case allowNone
        case allowAllInfo
        case itemsHeader
        case item(MessageReaction.Reaction)
    }
    
    case allowSwitch(text: String, value: Bool)
    case allowAllHeader(String)
    case allowAll(text: String, isEnabled: Bool)
    case allowSome(text: String, isEnabled: Bool)
    case allowNone(text: String, isEnabled: Bool)
    case allowAllInfo(String)
    
    case itemsHeader(String)
    case item(index: Int, value: MessageReaction.Reaction, availableReactions: AvailableReactions?, reaction: MessageReaction.Reaction, text: String, isEnabled: Bool, allDisabled: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .allowSwitch, .allowAllHeader, .allowAll, .allowSome, .allowNone, .allowAllInfo:
            return PeerAllowedReactionListControllerSection.all.rawValue
        case .itemsHeader, .item:
            return PeerAllowedReactionListControllerSection.items.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .allowSwitch:
            return .allowSwitch
        case .allowAllHeader:
            return .allowAllHeader
        case .allowAll:
            return .allowAll
        case .allowSome:
            return .allowSome
        case .allowNone:
            return .allowNone
        case .allowAllInfo:
            return .allowAllInfo
        case .itemsHeader:
            return .itemsHeader
        case let .item(_, value, _, _, _, _, _):
            return .item(value)
        }
    }
    
    var sortId: Int {
        switch self {
        case .allowSwitch:
            return 0
        case .allowAllHeader:
            return 1
        case .allowAll:
            return 2
        case .allowSome:
            return 3
        case .allowNone:
            return 4
        case .allowAllInfo:
            return 5
        case .itemsHeader:
            return 6
        case let .item(index, _, _, _, _, _, _):
            return 100 + index
        }
    }
    
    static func ==(lhs: PeerAllowedReactionListControllerEntry, rhs: PeerAllowedReactionListControllerEntry) -> Bool {
        switch lhs {
        case let .allowSwitch(text, value):
            if case .allowSwitch(text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .allowAllHeader(text):
            if case .allowAllHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .allowAll(text, isEnabled):
            if case .allowAll(text, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        case let .allowSome(text, isEnabled):
            if case .allowSome(text, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        case let .allowNone(text, isEnabled):
            if case .allowNone(text, isEnabled) = rhs {
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
        case let .item(index, value, availableReactions, reaction, text, isEnabled, allDisabled):
            if case .item(index, value, availableReactions, reaction, text, isEnabled, allDisabled) = rhs {
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
        case let .allowSwitch(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                if value {
                    arguments.setMode(.some, false)
                } else {
                    arguments.setMode(.empty, false)
                }
            })
        case let .allowAllHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .allowAll(text, isEnabled):
            return ItemListCheckboxItem(
                presentationData: presentationData,
                icon: nil,
                iconSize: nil,
                iconPlacement: .default,
                title: text,
                subtitle: nil,
                style: .right,
                color: .accent,
                textColor: .primary,
                checked: isEnabled,
                zeroSeparatorInsets: false,
                sectionId: self.section,
                action: {
                    arguments.setMode(.all, true)
                },
                deleteAction: nil
            )
        case let .allowSome(text, isEnabled):
            return ItemListCheckboxItem(
                presentationData: presentationData,
                icon: nil,
                iconSize: nil,
                iconPlacement: .default,
                title: text,
                subtitle: nil,
                style: .right,
                color: .accent,
                textColor: .primary,
                checked: isEnabled,
                zeroSeparatorInsets: false,
                sectionId: self.section,
                action: {
                    arguments.setMode(.some, true)
                },
                deleteAction: nil
            )
        case let .allowNone(text, isEnabled):
            return ItemListCheckboxItem(
                presentationData: presentationData,
                icon: nil,
                iconSize: nil,
                iconPlacement: .default,
                title: text,
                subtitle: nil,
                style: .right,
                color: .accent,
                textColor: .primary,
                checked: isEnabled,
                zeroSeparatorInsets: false,
                sectionId: self.section,
                action: {
                    arguments.setMode(.empty, true)
                },
                deleteAction: nil
            )
        case let .allowAllInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .itemsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .item(_, value, availableReactions, reaction, text, isEnabled, allDisabled):
            return ItemListReactionItem(
                context: arguments.context,
                presentationData: presentationData,
                availableReactions: availableReactions,
                reaction: reaction,
                title: text,
                value: isEnabled,
                enabled: !allDisabled,
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
    var updatedMode: PeerReactionsMode?
    var updatedAllowedReactions: Set<MessageReaction.Reaction>? = nil
}

private func peerAllowedReactionListControllerEntries(
    presentationData: PresentationData,
    availableReactions: AvailableReactions?,
    peer: Peer?,
    cachedData: CachedPeerData?,
    state: PeerAllowedReactionListControllerState
) -> [PeerAllowedReactionListControllerEntry] {
    var entries: [PeerAllowedReactionListControllerEntry] = []
    
    if let peer = peer, let availableReactions = availableReactions, let allowedReactions = state.updatedAllowedReactions, let mode = state.updatedMode {
        if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
            entries.append(.allowSwitch(text: presentationData.strings.PeerInfo_AllowedReactions_AllowAllText, value: mode != .empty))
            
            entries.append(.itemsHeader(presentationData.strings.PeerInfo_AllowedReactions_ReactionListHeader))
            var index = 0
            for availableReaction in availableReactions.reactions {
                if !availableReaction.isEnabled {
                    continue
                }
                entries.append(.item(index: index, value: availableReaction.value, availableReactions: availableReactions, reaction: availableReaction.value, text: availableReaction.title, isEnabled: allowedReactions.contains(availableReaction.value), allDisabled: mode == .empty))
                index += 1
            }
        } else {
            entries.append(.allowAllHeader(presentationData.strings.PeerInfo_AllowedReactions_ReactionListHeader))
            
            entries.append(.allowAll(text: presentationData.strings.PeerInfo_AllowedReactions_OptionAllReactions, isEnabled: mode == .all))
            entries.append(.allowSome(text: presentationData.strings.PeerInfo_AllowedReactions_OptionSomeReactions, isEnabled: mode == .some))
            entries.append(.allowNone(text: presentationData.strings.PeerInfo_AllowedReactions_OptionNoReactions, isEnabled: mode == .empty))
            
            let allInfoText: String
            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                switch mode {
                case .all:
                    allInfoText = presentationData.strings.PeerInfo_AllowedReactions_GroupOptionAllInfo
                case .some:
                    allInfoText = presentationData.strings.PeerInfo_AllowedReactions_GroupOptionSomeInfo
                case .empty:
                    allInfoText = presentationData.strings.PeerInfo_AllowedReactions_GroupOptionNoInfo
                }
            } else {
                switch mode {
                case .all:
                    allInfoText = presentationData.strings.PeerInfo_AllowedReactions_GroupOptionAllInfo
                case .some:
                    allInfoText = presentationData.strings.PeerInfo_AllowedReactions_GroupOptionSomeInfo
                case .empty:
                    allInfoText = presentationData.strings.PeerInfo_AllowedReactions_GroupOptionNoInfo
                }
            }
            
            entries.append(.allowAllInfo(allInfoText))
        
            if mode == .some {
                entries.append(.itemsHeader(presentationData.strings.PeerInfo_AllowedReactions_ReactionListHeader))
                var index = 0
                for availableReaction in availableReactions.reactions {
                    if !availableReaction.isEnabled {
                        continue
                    }
                    entries.append(.item(index: index, value: availableReaction.value, availableReactions: availableReactions, reaction: availableReaction.value, text: availableReaction.title, isEnabled: allowedReactions.contains(availableReaction.value), allDisabled: false))
                    index += 1
                }
            }
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
    actionsDisposable.add((combineLatest(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.AllowedReactions(id: peerId)), context.engine.stickers.availableReactions() |> take(1))
    |> deliverOnMainQueue).start(next: { allowedReactions, availableReactions in
        updateState { state in
            var state = state
            
            switch allowedReactions {
            case .unknown:
                break
            case let .known(value):
                switch value {
                case .all:
                    state.updatedMode = .all
                    if let availableReactions = availableReactions {
                        state.updatedAllowedReactions = Set(availableReactions.reactions.filter(\.isEnabled).map(\.value))
                    } else {
                        state.updatedAllowedReactions = Set()
                    }
                case let .limited(reactions):
                    state.updatedMode = .some
                    state.updatedAllowedReactions = Set(reactions)
                case .empty:
                    state.updatedMode = .empty
                    state.updatedAllowedReactions = Set()
                }
            }
            
            return state
        }
    }))
    
    let arguments = PeerAllowedReactionListControllerArguments(
        context: context,
        setMode: { mode, resetItems in
            let _ = (context.engine.stickers.availableReactions()
            |> take(1)
            |> deliverOnMainQueue).start(next: { availableReactions in
                guard let availableReactions = availableReactions else {
                    return
                }
                updateState { state in
                    var state = state
                    state.updatedMode = mode
                    
                    if var updatedAllowedReactions = state.updatedAllowedReactions {
                        switch mode {
                        case .all:
                            if resetItems {
                                updatedAllowedReactions.removeAll()
                                for availableReaction in availableReactions.reactions {
                                    if !availableReaction.isEnabled {
                                        continue
                                    }
                                    updatedAllowedReactions.insert(availableReaction.value)
                                }
                            }
                        case .some:
                            if resetItems {
                                updatedAllowedReactions.removeAll()
                                if let thumbsUp = availableReactions.reactions.first(where: { $0.value == .builtin("👍") }) {
                                    updatedAllowedReactions.insert(thumbsUp.value)
                                }
                                if let thumbsDown = availableReactions.reactions.first(where: { $0.value == .builtin("👎") }) {
                                    updatedAllowedReactions.insert(thumbsDown.value)
                                }
                            } else {
                                updatedAllowedReactions.removeAll()
                                for availableReaction in availableReactions.reactions {
                                    if !availableReaction.isEnabled {
                                        continue
                                    }
                                    updatedAllowedReactions.insert(availableReaction.value)
                                }
                            }
                        case .empty:
                            if resetItems {
                                updatedAllowedReactions.removeAll()
                            }
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
                        if state.updatedMode == .all {
                            state.updatedMode = .some
                        }
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
            animateChanges: false
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.willDisappear = { _ in
        let _ = (combineLatest(
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.AllowedReactions(id: peerId)
            ),
            context.engine.stickers.availableReactions() |> take(1)
        )
        |> deliverOnMainQueue).start(next: { data, availableReactions in
            let (peer, initialAllowedReactions) = data
            
            guard let peer = peer, let availableReactions = availableReactions else {
                return
            }
            
            let state = stateValue.with({ $0 })
            guard let updatedMode = state.updatedMode, let updatedAllowedReactions = state.updatedAllowedReactions else {
                return
            }
            
            let updatedValue: PeerAllowedReactions
            switch updatedMode {
            case .all:
                updatedValue = .all
            case .some:
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    if updatedAllowedReactions == Set(availableReactions.reactions.filter(\.isEnabled).map(\.value)) {
                        updatedValue = .all
                    } else {
                        updatedValue = .limited(Array(updatedAllowedReactions))
                    }
                } else {
                    updatedValue = .limited(Array(updatedAllowedReactions))
                }
            case .empty:
                updatedValue = .empty
            }
            
            if initialAllowedReactions != .known(updatedValue) {
                let _ = context.engine.peers.updatePeerAllowedReactions(peerId: peerId, allowedReactions: updatedValue).start()
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
