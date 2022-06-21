import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
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
    let openMessage: (MessageId) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (MessageId) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessage = openMessage
    }
}

private enum StatsSection: Int32 {
    case overview
    case interactions
    case publicForwards
}

private enum StatsEntry: ItemListNodeEntry {
    case overviewTitle(PresentationTheme, String)
    case overview(PresentationTheme, MessageStats, Int32?)
    
    case interactionsTitle(PresentationTheme, String)
    case interactionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case publicForwardsTitle(PresentationTheme, String)
    case publicForward(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Message)
    
    var section: ItemListSectionId {
        switch self {
            case .overviewTitle, .overview:
                return StatsSection.overview.rawValue
            case .interactionsTitle, .interactionsGraph:
                return StatsSection.interactions.rawValue
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
            case .publicForwardsTitle:
                return 4
            case let .publicForward(index, _, _, _, _):
                return 5 + index
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
                if case let .overview(rhsTheme, rhsStats, rhsPublicShares) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats, lhsPublicShares == rhsPublicShares {
                    return true
                } else {
                    return false
                }
            case let .interactionsTitle(lhsTheme, lhsText):
                if case let .interactionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .interactionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .interactionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
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
                 let .publicForwardsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .overview(_, stats, publicShares):
                return MessageStatsOverviewItem(presentationData: presentationData, stats: stats, publicShares: publicShares, sectionId: self.section, style: .blocks)
            case let .interactionsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, getDetailsData: { date, completion in
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

private func messageStatsControllerEntries(data: MessageStats?, messages: SearchMessagesResult?, presentationData: PresentationData) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    if let data = data {
        entries.append(.overviewTitle(presentationData.theme, presentationData.strings.Stats_MessageOverview.uppercased()))
        entries.append(.overview(presentationData.theme, data, messages?.totalCount))
    
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
            
            entries.append(.interactionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.interactionsGraph, chartType))
        }

        if let messages = messages, !messages.messages.isEmpty {
            entries.append(.publicForwardsTitle(presentationData.theme, presentationData.strings.Stats_MessagePublicForwardsTitle.uppercased()))
            var index: Int32 = 0
            for message in messages.messages {
                entries.append(.publicForward(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, message))
                index += 1
            }
        }
    }
    
    return entries
}

public func messageStatsController(context: AccountContext, messageId: MessageId, cachedPeerData: CachedPeerData) -> ViewController {
    var navigateToMessageImpl: ((MessageId) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<MessageStats?>(nil)
    let messagesPromise = Promise<(SearchMessagesResult, SearchMessagesState)?>(nil)
    
    var datacenterId: Int32 = 0
    if let cachedData = cachedPeerData as? CachedChannelData {
        datacenterId = cachedData.statsDatacenterId
    }
        
    let statsContext = MessageStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, messageId: messageId)
    let dataSignal: Signal<MessageStats?, NoError> = statsContext.state
    |> map { state in
        return state.stats
    }
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    let arguments = MessageStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openMessage: { messageId in
        navigateToMessageImpl?(messageId)
    })
    
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    
    let previousData = Atomic<MessageStats?>(value: nil)
    
    let searchSignal = context.engine.messages.searchMessages(location: .publicForwards(messageId: messageId, datacenterId: Int(datacenterId)), query: "", state: nil)
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
    
    let signal = combineLatest(context.sharedContext.presentationData, dataPromise.get(), messagesPromise.get(), longLoadingSignal)
    |> deliverOnMainQueue
    |> map { presentationData, data, search, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if data == nil {
            if longLoading {
                emptyStateItem = StatsEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings)
            } else {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Stats_MessageTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: messageStatsControllerEntries(data: data, messages: search?.0, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
        let _ = statsContext.state
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.contentOffsetChanged = { [weak controller] _, _ in
        controller?.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? StatsGraphItemNode {
                itemNode.resetInteraction()
            }
        })
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    navigateToMessageImpl = { [weak controller] messageId in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: messageId.peerId), subject: .message(id: .id(messageId), highlight: true, timecode: nil), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
        }
    }
    return controller
}
