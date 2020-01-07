import Foundation
import Postbox
import SyncCore
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ItemListUI
import Display
import ItemListPeerItem
import ItemListPeerActionItem

private let collapsedResultCount: Int = 10

private final class PollResultsControllerArguments {
    let context: AccountContext
    let collapseOption: (Data) -> Void
    let expandOption: (Data) -> Void
    let openPeer: (RenderedPeer) -> Void
    
    init(context: AccountContext, collapseOption: @escaping (Data) -> Void, expandOption: @escaping (Data) -> Void, openPeer: @escaping (RenderedPeer) -> Void) {
        self.context = context
        self.collapseOption = collapseOption
        self.expandOption = expandOption
        self.openPeer = openPeer
    }
}

private enum PollResultsSection {
    case text
    case option(Int)
    
    var rawValue: Int32 {
        switch self {
        case .text:
            return 0
        case let .option(index):
            return 1 + Int32(index)
        }
    }
}

private enum PollResultsEntryId: Hashable {
    case text
    case optionPeer(Int, Int)
    case optionExpand(Int)
}

private enum PollResultsEntry: ItemListNodeEntry {
    case text(String)
    case optionPeer(optionId: Int, index: Int, peer: RenderedPeer, optionText: String, optionPercentage: Int, optionExpanded: Bool, opaqueIdentifier: Data)
    case optionExpand(optionId: Int, opaqueIdentifier: Data, text: String)
    
    var section: ItemListSectionId {
        switch self {
        case .text:
            return PollResultsSection.text.rawValue
        case let .optionPeer(optionPeer):
            return PollResultsSection.option(optionPeer.optionId).rawValue
        case let .optionExpand(optionExpand):
            return PollResultsSection.option(optionExpand.optionId).rawValue
        }
    }
    
    var stableId: PollResultsEntryId {
        switch self {
        case .text:
            return .text
        case let .optionPeer(optionPeer):
            return .optionPeer(optionPeer.optionId, optionPeer.index)
        case let .optionExpand(optionExpand):
            return .optionExpand(optionExpand.optionId)
        }
    }
    
    static func <(lhs: PollResultsEntry, rhs: PollResultsEntry) -> Bool {
        switch lhs {
        case .text:
            switch rhs {
            case .text:
                return false
            default:
                return true
            }
        case let .optionPeer(lhsOptionPeer):
            switch rhs {
            case .text:
                return false
            case let .optionPeer(rhsOptionPeer):
                if lhsOptionPeer.optionId == rhsOptionPeer.optionId {
                    return lhsOptionPeer.index < rhsOptionPeer.index
                } else {
                    return lhsOptionPeer.optionId < rhsOptionPeer.optionId
                }
            case let .optionExpand(rhsOptionExpand):
                if lhsOptionPeer.optionId == rhsOptionExpand.optionId {
                    return true
                } else {
                    return lhsOptionPeer.optionId < rhsOptionExpand.optionId
                }
            }
        case let .optionExpand(lhsOptionExpand):
            switch rhs {
            case .text:
                return false
            case let .optionPeer(rhsOptionPeer):
                if lhsOptionExpand.optionId == rhsOptionPeer.optionId {
                    return false
                } else {
                    return lhsOptionExpand.optionId < rhsOptionPeer.optionId
                }
            case let .optionExpand(rhsOptionExpand):
                if lhsOptionExpand.optionId == rhsOptionExpand.optionId {
                    return false
                } else {
                    return lhsOptionExpand.optionId < rhsOptionExpand.optionId
                }
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PollResultsControllerArguments
        switch self {
        case let .text(text):
            return ItemListTextItem(presentationData: presentationData, text: .large(text), sectionId: self.section)
        case let .optionPeer(optionId, _, peer, optionText, optionPercentage, optionExpanded, opaqueIdentifier):
            let header = ItemListPeerItemHeader(theme: presentationData.theme, strings: presentationData.strings, text: optionText, actionTitle: optionExpanded ? presentationData.strings.PollResults_Collapse : "\(optionPercentage)%", id: Int64(optionId), action: optionExpanded ? {
                arguments.collapseOption(opaqueIdentifier)
            } : nil)
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .dayFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: ""), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.peers[peer.peerId]!, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openPeer(peer)
            }, setPeerIdWithRevealedOptions: { _, _ in
            }, removePeer: { _ in
            }, noInsets: true, header: header)
        case let .optionExpand(_, opaqueIdentifier, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandOption(opaqueIdentifier)
            })
        }
    }
}

private struct PollResultsControllerState: Equatable {
    var expandedOptions = Set<Data>()
}

private func pollResultsControllerEntries(presentationData: PresentationData, poll: TelegramMediaPoll, state: PollResultsControllerState, resultsState: PollResultsState) -> [PollResultsEntry] {
    var entries: [PollResultsEntry] = []
    
    var isEmpty = false
    for (_, optionState) in resultsState.options {
        if !optionState.hasLoadedOnce {
            isEmpty = true
            break
        }
    }
    
    entries.append(.text(poll.text))
    
    if isEmpty {
        return entries
    }
    
    var optionVoterCount: [Int: Int32] = [:]
    let totalVoterCount = poll.results.totalVoters ?? 0
    var optionPercentage: [Int] = []
    
    if totalVoterCount != 0 {
        if let voters = poll.results.voters, let totalVoters = poll.results.totalVoters {
            for i in 0 ..< poll.options.count {
                inner: for optionVoters in voters {
                    if optionVoters.opaqueIdentifier == poll.options[i].opaqueIdentifier {
                        optionVoterCount[i] = optionVoters.count
                        break inner
                    }
                }
            }
        }
        
        optionPercentage = countNicePercent(votes: (0 ..< poll.options.count).map({ Int(optionVoterCount[$0] ?? 0) }), total: Int(totalVoterCount))
    }
    
    for i in 0 ..< poll.options.count {
        let option = poll.options[i]
        if let optionState = resultsState.options[option.opaqueIdentifier], !optionState.peers.isEmpty {
            let percentage = optionPercentage.count > i ? optionPercentage[i] : 0
            var peerIndex = 0
            var hasMore = false
            let optionExpanded = state.expandedOptions.contains(option.opaqueIdentifier)
            
            var peers = optionState.peers
            var count = optionState.count
            /*#if DEBUG
            for _ in 0 ..< 10 {
                peers += peers
            }
            count = max(count, peers.count)
            #endif*/
            
            inner: for peer in peers {
                if !optionExpanded && peerIndex >= collapsedResultCount {
                    hasMore = true
                    break inner
                }
                entries.append(.optionPeer(optionId: i, index: peerIndex, peer: peer, optionText: option.text, optionPercentage: percentage, optionExpanded: optionExpanded, opaqueIdentifier: option.opaqueIdentifier))
                peerIndex += 1
            }
            
            if hasMore {
                let remainingCount = count - peerIndex
                entries.append(.optionExpand(optionId: i, opaqueIdentifier: option.opaqueIdentifier, text: presentationData.strings.PollResults_ShowMore(Int32(remainingCount))))
            }
        }
    }
    
    return entries
}

public func pollResultsController(context: AccountContext, messageId: MessageId, poll: TelegramMediaPoll) -> ViewController {
    let statePromise = ValuePromise(PollResultsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PollResultsControllerState())
    let updateState: ((PollResultsControllerState) -> PollResultsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resultsContext = PollResultsContext(account: context.account, messageId: messageId, poll: poll)
    
    let arguments = PollResultsControllerArguments(context: context,
    collapseOption: { optionId in
        updateState { state in
            var state = state
            state.expandedOptions.remove(optionId)
            return state
        }
    }, expandOption: { optionId in
        updateState { state in
            var state = state
            state.expandedOptions.insert(optionId)
            return state
        }
        let _ = (resultsContext.state
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak resultsContext] state in
            if let optionState = state.options[optionId] {
                if optionState.canLoadMore && optionState.peers.count <= collapsedResultCount {
                    resultsContext?.loadMore(optionOpaqueIdentifier: optionId)
                }
            }
        })
    }, openPeer: { peer in
        if let peer = peer.peers[peer.peerId] {
            if let controller = context.sharedContext.makePeerInfoController(context: context, peer: peer, mode: .generic) {
                pushControllerImpl?(controller)
            }
        }
    })
    
    let previousWasEmpty = Atomic<Bool?>(value: nil)
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        resultsContext.state
    )
    |> map { presentationData, state, resultsState -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        var isEmpty = false
        for (_, optionState) in resultsState.options {
            if !optionState.hasLoadedOnce {
                isEmpty = true
                break
            }
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if isEmpty {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let previousWasEmptyValue = previousWasEmpty.swap(isEmpty)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PollResults_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: pollResultsControllerEntries(presentationData: presentationData, poll: poll, state: state, resultsState: resultsState), style: .blocks, focusItemTag: nil, ensureVisibleItemTag: nil, emptyStateItem: emptyStateItem, crossfadeState: previousWasEmptyValue != nil && previousWasEmptyValue == true && isEmpty == false, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    controller.isOpaqueWhenInOverlay = true
    controller.blocksBackgroundWhenInOverlay = true
    
    return controller
}

