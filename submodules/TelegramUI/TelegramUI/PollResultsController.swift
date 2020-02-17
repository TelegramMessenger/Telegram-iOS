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
private let collapsedInitialLimit: Int = 14

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

private enum PollResultsItemTag: ItemListItemTag, Equatable {
    case firstOptionPeer(opaqueIdentifier: Data)
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? PollResultsItemTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum PollResultsEntry: ItemListNodeEntry {
    case text(String)
    case optionPeer(optionId: Int, index: Int, peer: RenderedPeer, optionText: String, optionAdditionalText: String, optionCount: Int32, optionExpanded: Bool, opaqueIdentifier: Data, shimmeringAlternation: Int?, isFirstInOption: Bool)
    case optionExpand(optionId: Int, opaqueIdentifier: Data, text: String, enabled: Bool)
    
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
        case let .optionPeer(optionId, _, peer, optionText, optionAdditionalText, optionCount, optionExpanded, opaqueIdentifier, shimmeringAlternation, isFirstInOption):
            let header = ItemListPeerItemHeader(theme: presentationData.theme, strings: presentationData.strings, text: optionText, additionalText: optionAdditionalText, actionTitle: optionExpanded ? presentationData.strings.PollResults_Collapse : presentationData.strings.MessagePoll_VotedCount(optionCount), id: Int64(optionId), action: optionExpanded ? {
                arguments.collapseOption(opaqueIdentifier)
            } : nil)
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .dayFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: ""), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.peers[peer.peerId]!, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: shimmeringAlternation == nil, sectionId: self.section, action: {
                arguments.openPeer(peer)
            }, setPeerIdWithRevealedOptions: { _, _ in
            }, removePeer: { _ in
            }, noInsets: true, tag: isFirstInOption ? PollResultsItemTag.firstOptionPeer(opaqueIdentifier: opaqueIdentifier) : nil, header: header, shimmering: shimmeringAlternation.flatMap { ItemListPeerItemShimmering(alternationIndex: $0) })
        case let .optionExpand(_, opaqueIdentifier, text, enabled):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: self.section, editing: false, action: enabled ? {
                arguments.expandOption(opaqueIdentifier)
            } : nil)
        }
    }
}

private struct PollResultsControllerState: Equatable {
    var expandedOptions: [Data: Int] = [:]
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
        let percentage = optionPercentage.count > i ? optionPercentage[i] : 0
        let option = poll.options[i]
        let optionTextHeader = option.text.uppercased()
        let optionAdditionalTextHeader = " — \(percentage)%"
        if isEmpty {
            if let voterCount = optionVoterCount[i], voterCount != 0 {
                let displayCount: Int
                if Int(voterCount) > collapsedInitialLimit {
                    displayCount = collapsedResultCount
                } else {
                    displayCount = Int(voterCount)
                }
                for peerIndex in 0 ..< displayCount {
                    let fakeUser = TelegramUser(id: PeerId(namespace: -1, id: 0), accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
                    let peer = RenderedPeer(peer: fakeUser)
                    entries.append(.optionPeer(optionId: i, index: peerIndex, peer: peer, optionText: optionTextHeader, optionAdditionalText: optionAdditionalTextHeader, optionCount: voterCount, optionExpanded: false, opaqueIdentifier: option.opaqueIdentifier, shimmeringAlternation: peerIndex % 2, isFirstInOption: peerIndex == 0))
                }
                if displayCount < Int(voterCount) {
                    let remainingCount = Int(voterCount) - displayCount
                    entries.append(.optionExpand(optionId: i, opaqueIdentifier: option.opaqueIdentifier, text: presentationData.strings.PollResults_ShowMore(Int32(remainingCount)), enabled: false))
                }
            }
        } else {
            if let optionState = resultsState.options[option.opaqueIdentifier], !optionState.peers.isEmpty {
                var hasMore = false
                let optionExpandedAtCount = state.expandedOptions[option.opaqueIdentifier]
                
                let peers = optionState.peers
                let count = optionState.count
                
                let displayCount: Int
                if peers.count > collapsedInitialLimit + 1 {
                    if optionExpandedAtCount != nil {
                        displayCount = peers.count
                    } else {
                        displayCount = collapsedResultCount
                    }
                } else {
                    if let optionExpandedAtCount = optionExpandedAtCount {
                        if optionExpandedAtCount == collapsedInitialLimit + 1 && optionState.canLoadMore {
                            displayCount = collapsedResultCount
                        } else {
                            displayCount = peers.count
                        }
                    } else {
                        if !optionState.canLoadMore {
                            displayCount = peers.count
                        } else {
                            displayCount = collapsedResultCount
                        }
                    }
                }
                
                var peerIndex = 0
                inner: for peer in peers {
                    if peerIndex >= displayCount {
                        break inner
                    }
                    entries.append(.optionPeer(optionId: i, index: peerIndex, peer: peer, optionText: optionTextHeader, optionAdditionalText: optionAdditionalTextHeader, optionCount: Int32(count), optionExpanded: optionExpandedAtCount != nil, opaqueIdentifier: option.opaqueIdentifier, shimmeringAlternation: nil, isFirstInOption: peerIndex == 0))
                    peerIndex += 1
                }
                
                let remainingCount = count - peerIndex
                if remainingCount > 0 {
                    entries.append(.optionExpand(optionId: i, opaqueIdentifier: option.opaqueIdentifier, text: presentationData.strings.PollResults_ShowMore(Int32(remainingCount)), enabled: true))
                }
            }
        }
    }
    
    return entries
}

public func pollResultsController(context: AccountContext, messageId: MessageId, poll: TelegramMediaPoll, focusOnOptionWithOpaqueIdentifier: Data? = nil) -> ViewController {
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
            state.expandedOptions.removeValue(forKey: optionId)
            return state
        }
    }, expandOption: { optionId in
        let _ = (resultsContext.state
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak resultsContext] state in
            if let optionState = state.options[optionId] {
                updateState { state in
                    var state = state
                    state.expandedOptions[optionId] = optionState.peers.count
                    return state
                }
                
                if optionState.canLoadMore {
                    resultsContext?.loadMore(optionOpaqueIdentifier: optionId)
                }
            }
        })
    }, openPeer: { peer in
        if let peer = peer.peers[peer.peerId] {
            if let controller = context.sharedContext.makePeerInfoController(context: context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
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
        
        let previousWasEmptyValue = previousWasEmpty.swap(isEmpty)
        
        var totalVoters: Int32 = 0
        if let totalVotersValue = poll.results.totalVoters {
            totalVoters = totalVotersValue
        }
        
        let entries = pollResultsControllerEntries(presentationData: presentationData, poll: poll, state: state, resultsState: resultsState)
        
        var initialScrollToItem: ListViewScrollToItem?
        if let focusOnOptionWithOpaqueIdentifier = focusOnOptionWithOpaqueIdentifier, previousWasEmptyValue == nil {
            var isFirstOption = true
            loop: for i in 0 ..< entries.count {
                switch entries[i] {
                case let .optionPeer(optionPeer):
                    if optionPeer.opaqueIdentifier == focusOnOptionWithOpaqueIdentifier {
                        if !isFirstOption {
                            initialScrollToItem = ListViewScrollToItem(index: i, position: .top(0.0), animated: false, curve: .Default(duration: nil), directionHint: .Down)
                        }
                        break loop
                    }
                    isFirstOption = false
                default:
                    break
                }
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .textWithSubtitle(presentationData.strings.PollResults_Title, presentationData.strings.MessagePoll_VotedCount(totalVoters)), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, focusItemTag: nil, emptyStateItem: nil, initialScrollToItem: initialScrollToItem, crossfadeState: previousWasEmptyValue != nil && previousWasEmptyValue == true && isEmpty == false, animateChanges: false)
        
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

