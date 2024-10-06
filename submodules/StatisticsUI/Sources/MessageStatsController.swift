import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
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
import StoryContainerScreen
import ContextUI

private final class MessageStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openMessage: (EngineMessage.Id) -> Void
    let openStory: (EnginePeer.Id, EngineStoryItem, UIView) -> Void
    let storyContextAction: (EnginePeer.Id, ASDisplayNode, ContextGesture?, Bool) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (EngineMessage.Id) -> Void, openStory: @escaping (EnginePeer.Id, EngineStoryItem, UIView) -> Void, storyContextAction: @escaping (EnginePeer.Id, ASDisplayNode, ContextGesture?, Bool) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessage = openMessage
        self.openStory = openStory
        self.storyContextAction = storyContextAction
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
    case overview(PresentationTheme, PostStats, EngineStoryItem.Views?, Int32?)
    
    case interactionsTitle(PresentationTheme, String)
    case interactionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType, Bool)
    
    case reactionsTitle(PresentationTheme, String)
    case reactionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType, Bool)
    
    case publicForwardsTitle(PresentationTheme, String)
    case publicForward(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsPostItem)
    
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
            case let .overview(lhsTheme, lhsStats, lhsViews, lhsPublicShares):
                if case let .overview(rhsTheme, rhsStats, rhsViews, rhsPublicShares) = rhs, lhsTheme === rhsTheme, lhsViews == rhsViews, lhsPublicShares == rhsPublicShares {
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
            case let .publicForward(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPost):
                if case let .publicForward(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPost) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsPost == rhsPost {
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
            case let .overview(_, stats, storyViews, publicShares):
                return StatsOverviewItem(context: arguments.context, presentationData: presentationData, isGroup: false, stats: stats as? Stats, storyViews: storyViews, publicShares: publicShares, sectionId: self.section, style: .blocks)
            case let .interactionsGraph(_, _, _, graph, type, noInitialZoom), let .reactionsGraph(_, _, _, graph, type, noInitialZoom):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, noInitialZoom: noInitialZoom, getDetailsData: { date, completion in
                    let _ = arguments.loadDetailedGraph(graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                        if let graph = graph, case let .Loaded(_, data) = graph {
                            completion(data)
                        }
                    })
                }, sectionId: self.section, style: .blocks)
            case let .publicForward(_, _, _, _, item):
                var views: Int32 = 0
                var forwards: Int32 = 0
                var reactions: Int32 = 0
            
                var isStory = false
                let peer: Peer
                switch item {
                case let .message(message):
                    peer = message.peers[message.id.peerId]!
                    for attribute in message.attributes {
                        if let viewsAttribute = attribute as? ViewCountMessageAttribute {
                            views = Int32(viewsAttribute.count)
                        } else if let forwardsAttribute = attribute as? ForwardCountMessageAttribute {
                            forwards = Int32(forwardsAttribute.count)
                        } else if let reactionsAttribute = attribute as? ReactionsMessageAttribute {
                            reactions = reactionsAttribute.reactions.reduce(0, { partialResult, reaction in
                                return partialResult + reaction.count
                            })
                        }
                    }
                case let .story(peerValue, story):
                    peer = peerValue._asPeer()
                    views = Int32(story.views?.seenCount ?? 0)
                    forwards = Int32(story.views?.forwardCount ?? 0)
                    reactions = Int32(story.views?.reactedCount ?? 0)
                    isStory = true
                }
                return StatsMessageItem(context: arguments.context, presentationData: presentationData, peer: peer, item: item, views: views, reactions: reactions, forwards: forwards, isPeer: true, sectionId: self.section, style: .blocks, action: {
                    switch item {
                    case let .message(message):
                        arguments.openMessage(message.id)
                    case .story:
                        break
                    }
                }, openStory: { view in
                    if case let .story(peer, story) = item {
                        arguments.openStory(peer.id, story, view)
                    }
                }, contextAction: { node, gesture in
                    arguments.storyContextAction(peer.id, node, gesture, !isStory)
                })
        }
    }
}

private func messageStatsControllerEntries(data: PostStats?, storyViews: EngineStoryItem.Views?, forwards: StoryStatsPublicForwardsContext.State?, presentationData: PresentationData) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    if let data = data {
        entries.append(.overviewTitle(presentationData.theme, presentationData.strings.Stats_MessageOverview.uppercased()))
        
        var publicShares: Int32?
        if let forwards {
            publicShares = forwards.count
        }
        entries.append(.overview(presentationData.theme, data, storyViews, publicShares))
        
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

        if let forwards, !forwards.forwards.isEmpty {
            entries.append(.publicForwardsTitle(presentationData.theme, presentationData.strings.Stats_MessagePublicForwardsTitle.uppercased()))
            var index: Int32 = 0
            for forward in forwards.forwards {
                switch forward {
                case let .message(message):
                    entries.append(.publicForward(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, .message(message._asMessage())))
                case let .story(peer, story):
                    entries.append(.publicForward(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, .story(peer, story)))
                }
                index += 1
            }
        }
    }
    
    return entries
}

public enum StatsSubject {
    case message(id: EngineMessage.Id)
    case story(peerId: EnginePeer.Id, id: Int32, item: EngineStoryItem, fromStory: Bool)
}

protocol PostStats {
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
    let forwardsPromise = Promise<StoryStatsPublicForwardsContext.State?>(nil)
    
    let anyStatsContext: Any
    let dataSignal: Signal<PostStats?, NoError>
    var loadDetailedGraphImpl: ((StatsGraph, Int64) -> Signal<StatsGraph?, NoError>)?
    var openStoryImpl: ((EnginePeer.Id, EngineStoryItem, UIView) -> Void)?
    var storyContextActionImpl: ((EnginePeer.Id, ASDisplayNode, ContextGesture?, Bool) -> Void)?
    
    let forwardsContext: StoryStatsPublicForwardsContext
    let peerId: EnginePeer.Id
    var storyItem: EngineStoryItem?
    switch subject {
    case let .message(id):
        peerId = id.peerId
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
        
        forwardsContext = StoryStatsPublicForwardsContext(account: context.account, subject: .message(messageId: id))
    case let .story(peerIdValue, id, item, _):
        peerId = peerIdValue
        storyItem = item
        
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
                
        forwardsContext = StoryStatsPublicForwardsContext(account: context.account, subject: .story(peerId: peerId, id: id))
    }
    
    forwardsPromise.set(
        .single(nil)
        |> then(
            forwardsContext.state
            |> map(Optional.init)
        )
    )
    
    let arguments = MessageStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return loadDetailedGraphImpl?(graph, x) ?? .single(nil)
    }, openMessage: { messageId in
        navigateToMessageImpl?(messageId)
    }, openStory: { peerId, story, view in
        openStoryImpl?(peerId, story, view)
    }, storyContextAction: { peerId, node, gesture, isMessage in
        storyContextActionImpl?(peerId, node, gesture, isMessage)
    })
    
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    
    let previousData = Atomic<PostStats?>(value: nil)
    
    let iconNodePromise = Promise<ASDisplayNode?>()
    if case let .story(peerId, id, storyItem, fromStory) = subject, !fromStory {
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
        forwardsPromise.get(),
        longLoadingSignal,
        iconNodePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, data, forwards, longLoading, iconNode -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
        var storyViews: EngineStoryItem.Views?
        switch subject {
        case .message:
            title = presentationData.strings.Stats_MessageTitle
        case let .story(_, _, storyItem, _):
            title = presentationData.strings.Stats_StoryTitle
            storyViews = storyItem.views
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: iconNode.flatMap { ItemListNavigationButton(content: .node($0), style: .regular, enabled: true, action: { [weak iconNode] in
            if let iconNode, let storyItem {
                openStoryImpl?(peerId, storyItem, iconNode.view)
            }
        }) }, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: messageStatsControllerEntries(data: data, storyViews: storyViews, forwards: forwards, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
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
        if case let .known(value) = offset, value < 100.0 {
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
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
            }
        })
    }
    openStoryImpl = { [weak controller] peerId, story, sourceView in
        let storyContent = SingleStoryContentContextImpl(context: context, storyId: StoryId(peerId: peerId, id: story.id), storyItem: story, readGlobally: false)
        let _ = (storyContent.state
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak controller, weak sourceView] _ in
            guard let controller, let sourceView else {
                return
            }
            let transitionIn = StoryContainerScreen.TransitionIn(
                sourceView: sourceView,
                sourceRect: sourceView.bounds,
                sourceCornerRadius: sourceView.bounds.width * 0.5,
                sourceIsAvatar: false
            )
        
            let storyContainerScreen = StoryContainerScreen(
                context: context,
                content: storyContent,
                transitionIn: transitionIn,
                transitionOut: { [weak sourceView] peerId, storyIdValue in
                    if let sourceView {
                        let destinationView = sourceView
                        return StoryContainerScreen.TransitionOut(
                            destinationView: destinationView,
                            transitionView: StoryContainerScreen.TransitionView(
                                makeView: { [weak destinationView] in
                                    let parentView = UIView()
                                    if let copyView = destinationView?.snapshotContentTree(unhide: true) {
                                        parentView.addSubview(copyView)
                                    }
                                    return parentView
                                },
                                updateView: { copyView, state, transition in
                                    guard let view = copyView.subviews.first else {
                                        return
                                    }
                                    let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                    transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                    transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                },
                                insertCloneTransitionView: nil
                            ),
                            destinationRect: destinationView.bounds,
                            destinationCornerRadius: destinationView.bounds.width * 0.5,
                            destinationIsAvatar: false,
                            completed: { [weak sourceView] in
                                guard let sourceView else {
                                    return
                                }
                                sourceView.isHidden = false
                            }
                        )
                    } else {
                        return nil
                    }
                }
            )
            controller.push(storyContainerScreen)
        })
    }
    storyContextActionImpl = { [weak controller] peerId, sourceNode, gesture, isMessage in
        guard let controller = controller, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
            return
        }
        
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        var items: [ContextMenuItem] = []
        
        let title: String
        let iconName: String
        if isMessage {
            title = presentationData.strings.Conversation_ViewInChannel
            iconName = "Chat/Context Menu/GoToMessage"
        } else {
            if peerId.isGroupOrChannel {
                title = presentationData.strings.ChatList_ContextOpenChannel
                iconName = "Chat/Context Menu/Channels"
            } else {
                title = presentationData.strings.Conversation_ContextMenuOpenProfile
                iconName = "Chat/Context Menu/User"
            }
        }
        
        items.append(.action(ContextMenuActionItem(text: title, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: iconName), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, _ in
            c?.dismiss(completion: {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer, let navigationController = controller?.navigationController as? NavigationController else {
                        return
                    }
                    if case .user = peer {
                        if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: peer.largeProfileImage != nil, fromChat: false, requestsContext: nil) {
                            navigationController.pushViewController(controller)
                        }
                    } else {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: nil))
                    }
                })
            })
        })))
        
        let contextController = ContextController(presentationData: presentationData, source: .extracted(ChannelStatsContextExtractedContentSource(controller: controller, sourceNode: sourceNode, keepInPlace: false)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        controller.presentInGlobalOverlay(contextController)
    }
    return controller
}
