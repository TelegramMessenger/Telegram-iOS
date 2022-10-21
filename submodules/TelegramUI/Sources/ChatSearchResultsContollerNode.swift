import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import MergeLists
import ChatListUI
import AccountContext
import ContextUI
import ChatListSearchItemHeader
import AnimationCache
import MultiAnimationRenderer

private enum ChatListSearchEntryStableId: Hashable {
    case messageId(MessageId)
    
    public static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
        switch lhs {
            case let .messageId(messageId):
                if case .messageId(messageId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ChatListSearchEntry: Comparable, Identifiable {
    case message(Message, RenderedPeer, CombinedPeerReadState?, ChatListPresentationData)
    
    public var stableId: ChatListSearchEntryStableId {
        switch self {
            case let .message(message, _, _, _):
                return .messageId(message.id)
        }
    }
    
    public static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, lhsPeer, lhsCombinedPeerReadState, lhsPresentationData):
                if case let .message(rhsMessage, rhsPeer, rhsCombinedPeerReadState, rhsPresentationData) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsPeer != rhsPeer {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsCombinedPeerReadState != rhsCombinedPeerReadState {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    public static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, _, _, _):
                if case let .message(rhsMessage, _, _, _) = rhs {
                    return lhsMessage.index < rhsMessage.index
                }
        }
        return false
    }
    
    public func item(context: AccountContext, interaction: ChatListNodeInteraction) -> ListViewItem {
        switch self {
            case let .message(message, peer, readState, presentationData):
                return ChatListItem(
                    presentationData: presentationData,
                    context: context,
                    chatListLocation: .chatList(groupId: .root),
                    filterData: nil,
                    index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: message.index)),
                    content: .peer(
                        messages: [EngineMessage(message)],
                        peer: EngineRenderedPeer(peer),
                        threadInfo: nil,
                        combinedReadState: readState.flatMap { EnginePeerReadCounters(state: $0, isMuted: false) },
                        isRemovedFromTotalUnreadCount: false,
                        presence: nil,
                        hasUnseenMentions: false,
                        hasUnseenReactions: false,
                        draftState: nil,
                        inputActivities: nil,
                        promoInfo: nil,
                        ignoreUnreadBadge: true,
                        displayAsMessage: true,
                        hasFailedMessages: false,
                        forumTopicData: nil
                    ),
                    editing: false,
                    hasActiveRevealControls: false,
                    selected: false,
                    header: nil,
                    enableContextActions: false,
                    hiddenOffset: false,
                    interaction: interaction
                )
        }
    }
}

public struct ChatListSearchContainerTransition {
    public let deletions: [ListViewDeleteItem]
    public let insertions: [ListViewInsertItem]
    public let updates: [ListViewUpdateItem]
    
    public init(deletions: [ListViewDeleteItem], insertions: [ListViewInsertItem], updates: [ListViewUpdateItem]) {
        self.deletions = deletions
        self.insertions = insertions
        self.updates = updates
    }
}

private func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], context: AccountContext, interaction: ChatListNodeInteraction) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates)
}

class ChatSearchResultsControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    private let location: SearchMessagesLocation
    private let searchQuery: String
    private var searchResult: SearchMessagesResult
    private var searchState: SearchMessagesState
    
    private var interaction: ChatListNodeInteraction?
    
    private let listNode: ListView
    
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var resultsUpdated: ((SearchMessagesResult, SearchMessagesState) -> Void)?
    var resultSelected: ((Int) -> Void)?
    
    private let presentationDataPromise: Promise<ChatListPresentationData>
    private let disposable = MetaDisposable()
    
    private var isLoadingMore = false
    private let loadMoreDisposable = MetaDisposable()
    
    private let previousEntries = Atomic<[ChatListSearchEntry]?>(value: nil)
    
    init(context: AccountContext, location: SearchMessagesLocation, searchQuery: String, searchResult: SearchMessagesResult, searchState: SearchMessagesState, presentInGlobalOverlay: @escaping (ViewController) -> Void) {
        self.context = context
        self.location = location
        self.searchQuery = searchQuery
        self.searchResult = searchResult
        self.searchState = searchState
         
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true))
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.isOpaque = false
        self.addSubnode(self.listNode)
        
        let signal = self.presentationDataPromise.get()
        |> map { presentationData -> [ChatListSearchEntry] in
            var entries: [ChatListSearchEntry] = []
            
            for message in searchResult.messages {
                var peer = RenderedPeer(message: message)
                if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                    if let channelPeer = message.peers[migrationReference.peerId] {
                        peer = RenderedPeer(peer: channelPeer)
                    }
                }
                entries.append(.message(message, peer, searchResult.readStates[peer.peerId], presentationData))
            }
            
            return entries
        }
        
        let interaction = ChatListNodeInteraction(context: context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, activateSearch: {
        }, peerSelected: { _, _, _, _ in
        }, disabledPeerSelected: { _, _ in
        }, togglePeerSelected: { _, _ in
        }, togglePeersSelection: { _, _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, _, message, _ in
            if let strongSelf = self {
                if let index = strongSelf.searchResult.messages.firstIndex(where: { $0.index == message.index }) {
                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                        strongSelf.resultSelected?(index)
                    } else {
                        strongSelf.resultSelected?(strongSelf.searchResult.messages.count - index - 1)
                    }
                }
                strongSelf.listNode.clearHighlightAnimated(true)
            }
        }, groupSelected: { _ in
        }, addContact: { _ in
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, setPeerThreadMuted: { _, _, _ in
        }, deletePeer: { _, _ in
        }, deletePeerThread: { _, _ in
        }, setPeerThreadStopped: { _, _, _ in
        }, setPeerThreadPinned: { _, _, _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        }, toggleArchivedFolderHiddenByDefault: {
        }, toggleThreadsSelection: { _, _ in
        }, hidePsa: { _ in
        }, activateChatPreview: { [weak self] item, node, gesture, _ in
            guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            switch item.content {
            case let .peer(messages, peer, _, _, _, _, _, _, _, _, _, _, _, _, _):
                if let message = messages.first {
                    let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peer.peerId), subject: .message(id: .id(message.id), highlight: true, timecode: nil), botStart: nil, mode: .standard(previewing: true))
                    chatController.canReadHistory.set(false)
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: .single(ContextController.Items(content: .list([]))), gesture: gesture)
                    presentInGlobalOverlay(contextController)
                } else {
                    gesture?.cancel()
                }
            default:
                gesture?.cancel()
            }
        }, present: { _ in
        })
        interaction.searchTextHighightState = searchQuery
        self.interaction = interaction
        
        self.disposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = strongSelf.previousEntries.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries, context: context, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            guard case let .known(value) = offset, value < 100.0 else {
                return
            }
            if strongSelf.searchResult.completed {
                return
            }
            if strongSelf.isLoadingMore {
                return
            }
            strongSelf.loadMore()
        }
    }
    
    deinit {
        self.disposable.dispose()
        self.loadMoreDisposable.dispose()
    }
    
    private func loadMore() {
        self.isLoadingMore = true
        
        self.loadMoreDisposable.set((self.context.engine.messages.searchMessages(location: self.location, query: self.searchQuery, state: self.searchState)
        |> deliverOnMainQueue).start(next: { [weak self] (updatedResult, updatedState) in
            guard let strongSelf = self else {
                return
            }
            guard let interaction = strongSelf.interaction else {
                return
            }
            
            strongSelf.isLoadingMore = false
            strongSelf.searchResult = updatedResult
            strongSelf.searchState = updatedState
            strongSelf.resultsUpdated?(updatedResult, updatedState)
            
            let context = strongSelf.context
            
            let signal = strongSelf.presentationDataPromise.get()
            |> map { presentationData -> [ChatListSearchEntry] in
                var entries: [ChatListSearchEntry] = []
                
                for message in updatedResult.messages {
                    var peer = RenderedPeer(message: message)
                    if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                        if let channelPeer = message.peers[migrationReference.peerId] {
                            peer = RenderedPeer(peer: channelPeer)
                        }
                    }
                    entries.append(.message(message, peer, nil, presentationData))
                }
                
                return entries
            }
            
            strongSelf.disposable.set((signal
            |> deliverOnMainQueue).start(next: { entries in
                if let strongSelf = self {
                    let previousEntries = strongSelf.previousEntries.swap(entries)
                    
                    let firstTime = previousEntries == nil
                    let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries, context: context, interaction: interaction)
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                }
            }))
        }))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataPromise.set(.single(ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)))

        self.listNode.forEachItemHeaderNode({ itemHeaderNode in
            if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                itemHeaderNode.updateTheme(theme: presentationData.theme)
            }
        })
    }
    
    private func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

