import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import ItemListPeerItem
import PresentationDataUtils
import AccountContext
import PresentationDataUtils
import AppBundle
import GraphUI

private final class MessageStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openMessage: (EngineMessage.Id) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (EngineMessage.Id) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessage = openMessage
    }
}

private enum StatsSection: Int32 {
    case overview
    case interactions
    case reactions
    case publicForwards
}

private enum StatsEntry: ItemListNodeEntry {
    case overviewTitle(PresentationTheme, String)
    case overview(PresentationTheme, PostStats, Int32?)
    
    case interactionsTitle(PresentationTheme, String)
    case interactionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType, Bool)
    
    case reactionsTitle(PresentationTheme, String)
    case reactionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType, Bool)
    
    case publicForwardsTitle(PresentationTheme, String)
    case publicForward(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, EngineMessage)
    
    var section: ItemListSectionId {
        switch self {
            case .overviewTitle, .overview:
                return StatsSection.overview.rawValue
            case .interactionsTitle, .interactionsGraph:
                return StatsSection.interactions.rawValue
            case .reactionsTitle, .reactionsGraph:
                return StatsSection.reactions.rawValue
            case .publicForwardsTitle, .publicForward:
                return StatsSection.publicForwards.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .overviewTitle:
                return 0
            case .overview:
                return 1
            case .interactionsTitle:
                return 2
            case .interactionsGraph:
                return 3
            case .reactionsTitle:
                return 4
            case .reactionsGraph:
                return 5
            case .publicForwardsTitle:
                return 6
            case let .publicForward(index, _, _, _, _):
                return 7 + index
        }
    }
    
    static func ==(lhs: StatsEntry, rhs: StatsEntry) -> Bool {
        switch lhs {
            case let .overviewTitle(lhsTheme, lhsText):
                if case let .overviewTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText{
                    return true
                } else {
                    return false
                }
            case let .overview(lhsTheme, lhsStats, lhsPublicShares):
                if case let .overview(rhsTheme, rhsStats, rhsPublicShares) = rhs, lhsTheme === rhsTheme, lhsPublicShares == rhsPublicShares {
                    if let lhsMessageStats = lhsStats as? MessageStats, let rhsMessageStats = rhsStats as? MessageStats {
                        return lhsMessageStats == rhsMessageStats
                    } else if let lhsStoryStats = lhsStats as? StoryStats, let rhsStoryStats = rhsStats as? StoryStats {
                        return lhsStoryStats == rhsStoryStats
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            case let .interactionsTitle(lhsTheme, lhsText):
                if case let .interactionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .interactionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType, lhsNoInitialZoom):
                if case let .interactionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType, rhsNoInitialZoom) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType, lhsNoInitialZoom == rhsNoInitialZoom {
                    return true
                } else {
                    return false
                }
            case let .reactionsTitle(lhsTheme, lhsText):
                if case let .reactionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .reactionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType, lhsNoInitialZoom):
                if case let .reactionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType, rhsNoInitialZoom) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType, lhsNoInitialZoom == rhsNoInitialZoom {
                    return true
                } else {
                    return false
                }
            case let .publicForwardsTitle(lhsTheme, lhsText):
                if case let .publicForwardsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicForward(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsMessage):
                if case let .publicForward(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsMessage) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsMessage.id == rhsMessage.id {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: StatsEntry, rhs: StatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MessageStatsControllerArguments
        switch self {
            case let .overviewTitle(_, text),
                 let .interactionsTitle(_, text),
                 let .reactionsTitle(_, text),
                 let .publicForwardsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .overview(_, stats, publicShares):
                return StatsOverviewItem(presentationData: presentationData, stats: stats as! Stats, publicShares: publicShares, sectionId: self.section, style: .blocks)
            case let .interactionsGraph(_, _, _, graph, type, noInitialZoom), let .reactionsGraph(_, _, _, graph, type, noInitialZoom):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, noInitialZoom: noInitialZoom, getDetailsData: { date, completion in
                    let _ = arguments.loadDetailedGraph(graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                        if let graph = graph, case let .Loaded(_, data) = graph {
                            completion(data)
                        }
                    })
                }, sectionId: self.section, style: .blocks)
            case let .publicForward(_, _, _, _, message):
                var views: Int32 = 0
                for attribute in message.attributes {
                    if let viewsAttribute = attribute as? ViewCountMessageAttribute {
                        views = Int32(viewsAttribute.count)
                        break
                    }
                }
                
                let text: String = presentationData.strings.Stats_MessageViews(views)
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: EnginePeer(message.peers[message.id.peerId]!), height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(text, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), revealOptions: nil, switchValue: nil, enabled: true, highlighted: false, selectable: true, sectionId: self.section, action: {
                    arguments.openMessage(message.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, contextAction: nil)
        }
    }
}

private func messageStatsControllerEntries(data: PostStats?, messages: SearchMessagesResult?, forwards: StoryStatsPublicForwardsContext.State?, presentationData: PresentationData) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    if let data = data {
        entries.append(.overviewTitle(presentationData.theme, presentationData.strings.Stats_MessageOverview.uppercased()))
        entries.append(.overview(presentationData.theme, data, messages?.totalCount))
        
        var isStories = false
        if let _ = data as? StoryStats {
            isStories = true
        }
    
        if !data.interactionsGraph.isEmpty {
            entries.append(.interactionsTitle(presentationData.theme, presentationData.strings.Stats_MessageInteractionsTitle.uppercased()))
            
            var chartType: ChartType
            if data.interactionsGraphDelta == 3600 {
                chartType = .twoAxisHourlyStep
            } else if data.interactionsGraphDelta == 300 {
                chartType = .twoAxis5MinStep
            } else {
                chartType = .twoAxisStep
            }
            
            entries.append(.interactionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.interactionsGraph, chartType, isStories))
        }
        
        if !data.reactionsGraph.isEmpty {
            entries.append(.reactionsTitle(presentationData.theme, presentationData.strings.Stats_MessageReactionsTitle.uppercased()))
            entries.append(.reactionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.reactionsGraph, .bars, isStories))
        }

        if let messages, !messages.messages.isEmpty {
            entries.append(.publicForwardsTitle(presentationData.theme, presentationData.strings.Stats_MessagePublicForwardsTitle.uppercased()))
            var index: Int32 = 0
            for message in messages.messages {
                entries.append(.publicForward(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, EngineMessage(message)))
                index += 1
            }
        }
        
        if let forwards, !forwards.forwards.isEmpty {
            entries.append(.publicForwardsTitle(presentationData.theme, presentationData.strings.Stats_MessagePublicForwardsTitle.uppercased()))
            var index: Int32 = 0
            for forward in forwards.forwards {
                switch forward {
                case let .message(message):
                    entries.append(.publicForward(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, message))
                case let .story(story):
                    let _ = story
                }
                index += 1
            }
        }
    }
    
    return entries
}

public enum StatsSubject {
    case message(id: EngineMessage.Id)
    case story(peerId: EnginePeer.Id, id: Int32, item: EngineStoryItem?)
}

protocol PostStats {
    var views: Int { get }
    var forwards: Int { get }
    var interactionsGraph: StatsGraph { get }
    var interactionsGraphDelta: Int64 { get }
    var reactionsGraph: StatsGraph { get }
}

extension MessageStats: PostStats {
    
}

extension StoryStats: PostStats {
    
}

public func messageStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, subject: StatsSubject) -> ViewController {
    var navigateToMessageImpl: ((EngineMessage.Id) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<PostStats?>(nil)
    let messagesPromise = Promise<(SearchMessagesResult, SearchMessagesState)?>(nil)
    let forwardsPromise = Promise<StoryStatsPublicForwardsContext.State?>(nil)
    
    let anyStatsContext: Any
    let dataSignal: Signal<PostStats?, NoError>
    var loadDetailedGraphImpl: ((StatsGraph, Int64) -> Signal<StatsGraph?, NoError>)?
    
    var forwardsContext: StoryStatsPublicForwardsContext?
    switch subject {
    case let .message(id):
        let statsContext = MessageStatsContext(account: context.account, messageId: id)
        loadDetailedGraphImpl = { [weak statsContext] graph, x in
            return statsContext?.loadDetailedGraph(graph, x: x) ?? .single(nil)
        }
        dataSignal = statsContext.state
        |> map { state in
            return state.stats
        }
        dataPromise.set(.single(nil) |> then(dataSignal))
        anyStatsContext = statsContext
        
        let searchSignal = context.engine.messages.searchMessages(location: .publicForwards(messageId: id), query: "", state: nil)
        |> map(Optional.init)
        |> afterNext { result in
            if let result = result {
                for message in result.0.messages {
                    if let peer = message.peers[message.id.peerId], let peerReference = PeerReference(peer) {
                        let _ = context.engine.peers.updatedRemotePeer(peer: peerReference).start()
                    }
                }
            }
        }
        messagesPromise.set(.single(nil) |> then(searchSignal))
        forwardsPromise.set(.single(nil))
    case let .story(peerId, id, _):
        let statsContext = StoryStatsContext(account: context.account, peerId: peerId, storyId: id)
        loadDetailedGraphImpl = { [weak statsContext] graph, x in
            return statsContext?.loadDetailedGraph(graph, x: x) ?? .single(nil)
        }
        dataSignal = statsContext.state
        |> map { state in
            return state.stats
        }
        dataPromise.set(.single(nil) |> then(dataSignal))
        anyStatsContext = statsContext
        
        messagesPromise.set(.single(nil))
        
        forwardsContext = StoryStatsPublicForwardsContext(account: context.account, peerId: peerId, storyId: id)
        if let forwardsContext {
            forwardsPromise.set(
                .single(nil)
                |> then(
                    forwardsContext.state
                    |> map(Optional.init)
                )
            )
        } else {
            forwardsPromise.set(.single(nil))
        }
    }
    
    let arguments = MessageStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return loadDetailedGraphImpl?(graph, x) ?? .single(nil)
    }, openMessage: { messageId in
        navigateToMessageImpl?(messageId)
    })
    
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    
    let previousData = Atomic<PostStats?>(value: nil)
    
    let iconNodePromise = Promise<ASDisplayNode?>()
    if case let .story(peerId, id, storyItem) = subject, let storyItem {
        let _ = id
        iconNodePromise.set(
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue
            |> map { peer -> ASDisplayNode? in
                if let peer = peer?._asPeer() {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    return StoryIconNode(context: context, theme: presentationData.theme, peer: peer, storyItem: storyItem)
                } else {
                    return nil
                }
            }
        )

    } else {
        iconNodePromise.set(.single(nil))
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        presentationData,
        dataPromise.get(), 
        messagesPromise.get(),
        forwardsPromise.get(),
        longLoadingSignal,
        iconNodePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, data, search, forwards, longLoading, iconNode -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if data == nil {
            if longLoading {
                emptyStateItem = StatsEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings)
            } else {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
        
        let title: String
        switch subject {
        case .message:
            title = presentationData.strings.Stats_MessageTitle
        case .story:
            title = presentationData.strings.Stats_StoryTitle
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: iconNode.flatMap { ItemListNavigationButton(content: .node($0), style: .regular, enabled: true, action: { }) }, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: messageStatsControllerEntries(data: data, messages: search?.0, forwards: forwards, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
        let _ = anyStatsContext
        let _ = forwardsContext
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.contentOffsetChanged = { [weak controller] _, _ in
        controller?.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? StatsGraphItemNode {
                itemNode.resetInteraction()
            }
        })
    }
    controller.visibleBottomContentOffsetChanged = { [weak forwardsContext] offset in
        if case let .known(value) = offset, value < 100.0, case .story = subject {
            forwardsContext?.loadMore()
        }
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    navigateToMessageImpl = { [weak controller] messageId in
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
        )
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            if let navigationController = controller?.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
            }
        })
    }
    return controller
}
