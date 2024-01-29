import UIKit
import ComponentFlow
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import AccountContext
import ChatListUI
import MergeLists
import ComponentDisplayAdapters
import TelegramPresentationData
import SwiftSignalKit
import TelegramUIPreferences
import UIKitRuntimeUtils

public final class ChatInlineSearchResultsListComponent: Component {
    public struct Presentation: Equatable {
        public var theme: PresentationTheme
        public var strings: PresentationStrings
        public var chatListFontSize: PresentationFontSize
        public var dateTimeFormat: PresentationDateTimeFormat
        public var nameSortOrder: PresentationPersonNameOrder
        public var nameDisplayOrder: PresentationPersonNameOrder
        
        public init(
            theme: PresentationTheme,
            strings: PresentationStrings,
            chatListFontSize: PresentationFontSize,
            dateTimeFormat: PresentationDateTimeFormat,
            nameSortOrder: PresentationPersonNameOrder,
            nameDisplayOrder: PresentationPersonNameOrder
        ) {
            self.theme = theme
            self.strings = strings
            self.chatListFontSize = chatListFontSize
            self.dateTimeFormat = dateTimeFormat
            self.nameSortOrder = nameSortOrder
            self.nameDisplayOrder = nameDisplayOrder
        }
        
        public static func ==(lhs: Presentation, rhs: Presentation) -> Bool {
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings != rhs.strings {
                return false
            }
            if lhs.chatListFontSize != rhs.chatListFontSize {
                return false
            }
            if lhs.dateTimeFormat != rhs.dateTimeFormat {
                return false
            }
            if lhs.nameSortOrder != rhs.nameSortOrder {
                return false
            }
            if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
                return false
            }
            return true
        }
    }
    
    public enum Contents: Equatable {
        case tag(MemoryBuffer)
    }
    
    public let context: AccountContext
    public let presentation: Presentation
    public let peerId: EnginePeer.Id
    public let contents: Contents
    public let insets: UIEdgeInsets
    public let messageSelected: (EngineMessage) -> Void
    public let loadTagMessages: (MemoryBuffer, MessageIndex?) -> Signal<MessageHistoryView, NoError>?
    
    public init(
        context: AccountContext,
        presentation: Presentation,
        peerId: EnginePeer.Id,
        contents: Contents,
        insets: UIEdgeInsets,
        messageSelected: @escaping (EngineMessage) -> Void,
        loadTagMessages: @escaping (MemoryBuffer, MessageIndex?) -> Signal<MessageHistoryView, NoError>?
    ) {
        self.context = context
        self.presentation = presentation
        self.peerId = peerId
        self.contents = contents
        self.insets = insets
        self.messageSelected = messageSelected
        self.loadTagMessages = loadTagMessages
    }
    
    public static func ==(lhs: ChatInlineSearchResultsListComponent, rhs: ChatInlineSearchResultsListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.presentation != rhs.presentation {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.contents != rhs.contents {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    private struct ContentsState: Equatable {
        var id: Int
        var tag: MemoryBuffer?
        var entries: [EngineMessage]
        var hasEarlier: Bool
        var hasLater: Bool
        
        init(id: Int, tag: MemoryBuffer?, entries: [EngineMessage], hasEarlier: Bool, hasLater: Bool) {
            self.id = id
            self.tag = tag
            self.entries = entries
            self.hasEarlier = hasEarlier
            self.hasLater = hasLater
        }
    }
    
    public final class View: UIView {
        private var component: ChatInlineSearchResultsListComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let listNode: ListView
        
        private var tagContents: (index: MessageIndex?, disposable: Disposable?)?
        
        private var nextContentsId: Int = 0
        private var contentsState: ContentsState?
        private var appliedContentsState: ContentsState?
        
        private var currentChatListPresentationData: (Presentation, ChatListPresentationData)?
        private var chatListNodeInteraction: ChatListNodeInteraction?
        
        private let isReadyPromise = Promise<Bool>()
        private var didSetReady: Bool = false
        public var isReady: Signal<Bool, NoError> {
            return self.isReadyPromise.get()
        }
        
        override public init(frame: CGRect) {
            self.listNode = ListView()
            
            super.init(frame: frame)
            
            self.addSubnode(self.listNode)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.tagContents?.disposable?.dispose()
        }
        
        public func animateIn() {
            self.listNode.layer.animateSublayerScale(from: 0.95, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            
            if let blurFilter = makeBlurFilter() {
                blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                self.listNode.layer.filters = [blurFilter]
                self.listNode.layer.animate(from: 30.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    self.listNode.layer.filters = []
                })
            }
        }
        
        public func animateOut() {
            self.listNode.layer.animateSublayerScale(from: 1.0, to: 0.95, duration: 0.3, removeOnCompletion: false)
            
            if let blurFilter = makeBlurFilter() {
                blurFilter.setValue(30.0 as NSNumber, forKey: "inputRadius")
                self.listNode.layer.filters = [blurFilter]
                self.listNode.layer.animate(from: 0.0 as NSNumber, to: 30.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, removeOnCompletion: false)
            }
        }
        
        func update(component: ChatInlineSearchResultsListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            self.backgroundColor = component.presentation.theme.list.plainBackgroundColor
            
            self.listNode.frame = CGRect(origin: CGPoint(), size: availableSize)
            let (listDuration, listCurve) = listViewAnimationDurationAndCurve(transition: transition.containedViewLayoutTransition)
            self.listNode.transaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: [.Synchronous, .LowLatency, .PreferSynchronousDrawing, .PreferSynchronousResourceLoading],
                updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                    size: availableSize,
                    insets: component.insets,
                    duration: listDuration,
                    curve: listCurve
                ),
                updateOpaqueState: nil
            )
            
            self.listNode.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
                guard let self else {
                    return
                }
                guard let stateId = opaqueTransactionState as? Int else {
                    return
                }
                guard let contentsState = self.contentsState, contentsState.id == stateId else {
                    return
                }
                guard let (currentIndex, disposable) = self.tagContents else {
                    return
                }
                guard let visibleRange = displayedRange.visibleRange else {
                    return
                }
                var loadAroundIndex: MessageIndex?
                if visibleRange.firstIndex <= 5 {
                    if contentsState.hasLater {
                        loadAroundIndex = contentsState.entries.first?.index
                    }
                } else if visibleRange.lastIndex >= contentsState.entries.count - 5 {
                    if contentsState.hasEarlier {
                        loadAroundIndex = contentsState.entries.last?.index
                    }
                }
                
                if let loadAroundIndex, loadAroundIndex != currentIndex {
                    switch component.contents {
                    case let .tag(tag):
                        disposable?.dispose()
                        let updatedDisposable = MetaDisposable()
                        self.tagContents = (loadAroundIndex, updatedDisposable)
                        
                        if let historySignal = component.loadTagMessages(tag, self.tagContents?.index) {
                            updatedDisposable.set((historySignal
                            |> deliverOnMainQueue).startStrict(next: { [weak self] view in
                                guard let self else {
                                    return
                                }
                                
                                let contentsId = self.nextContentsId
                                self.nextContentsId += 1
                                self.contentsState = ContentsState(
                                    id: contentsId,
                                    tag: tag,
                                    entries: view.entries.reversed().map { entry in
                                        return EngineMessage(entry.message)
                                    },
                                    hasEarlier: view.earlierId != nil,
                                    hasLater: view.laterId != nil
                                )
                                if !self.isUpdating {
                                    self.state?.updated(transition: .immediate)
                                }
                                
                                if !self.didSetReady {
                                    self.didSetReady = true
                                    self.isReadyPromise.set(.single(true))
                                }
                            }))
                        }
                    }
                }
            }
            
            switch component.contents {
            case let .tag(tag):
                if previousComponent?.contents != component.contents {
                    self.tagContents?.disposable?.dispose()
                    
                    let disposable = MetaDisposable()
                    self.tagContents = (nil, disposable)
                    
                    if let historySignal = component.loadTagMessages(tag, self.tagContents?.index) {
                        disposable.set((historySignal
                        |> deliverOnMainQueue).startStrict(next: { [weak self] view in
                            guard let self else {
                                return
                            }
                            
                            let contentsId = self.nextContentsId
                            self.nextContentsId += 1
                            self.contentsState = ContentsState(
                                id: contentsId,
                                tag: tag,
                                entries: view.entries.reversed().map { entry in
                                    return EngineMessage(entry.message)
                                },
                                hasEarlier: view.earlierId != nil,
                                hasLater: view.laterId != nil
                            )
                            if !self.isUpdating {
                                self.state?.updated(transition: .immediate)
                            }
                            
                            if !self.didSetReady {
                                self.didSetReady = true
                                self.isReadyPromise.set(.single(true))
                            }
                        }))
                    }
                }
            }
            
            if let contentsState = self.contentsState, self.contentsState != self.appliedContentsState {
                let previousContentsState = self.appliedContentsState
                self.appliedContentsState = self.contentsState
                
                let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(
                    leftList: previousContentsState?.entries ?? [],
                    rightList: contentsState.entries,
                    isLess: { lhs, rhs in
                        return lhs.index > rhs.index
                    },
                    isEqual: { lhs, rhs in
                        return lhs == rhs
                    },
                    getId: { message in
                        return message.stableId
                    },
                    allUpdated: false
                )
                
                let chatListPresentationData: ChatListPresentationData
                if let current = self.currentChatListPresentationData, current.0 == component.presentation {
                    chatListPresentationData = current.1
                } else {
                    chatListPresentationData = ChatListPresentationData(
                        theme: component.presentation.theme,
                        fontSize: component.presentation.chatListFontSize,
                        strings: component.presentation.strings,
                        dateTimeFormat: component.presentation.dateTimeFormat,
                        nameSortOrder: component.presentation.nameSortOrder,
                        nameDisplayOrder: component.presentation.nameDisplayOrder,
                        disableAnimations: false
                    )
                    self.currentChatListPresentationData = (component.presentation, chatListPresentationData)
                }
                
                let chatListNodeInteraction: ChatListNodeInteraction
                if let current = self.chatListNodeInteraction {
                    chatListNodeInteraction = current
                } else {
                    chatListNodeInteraction = ChatListNodeInteraction(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        activateSearch: {
                        },
                        peerSelected: { _, _, _, _ in
                        },
                        disabledPeerSelected: { _, _, _ in
                        },
                        togglePeerSelected: { _, _ in
                        },
                        togglePeersSelection: { _, _ in
                        },
                        additionalCategorySelected: { _ in
                        },
                        messageSelected: { [weak self] _, _, message, _ in
                            guard let self else {
                                return
                            }
                            self.listNode.clearHighlightAnimated(true)
                            
                            self.component?.messageSelected(message)
                        },
                        groupSelected: { _ in
                        },
                        addContact: { _ in
                        },
                        setPeerIdWithRevealedOptions: { _, _ in
                        },
                        setItemPinned: { _, _ in
                        },
                        setPeerMuted: { _, _ in
                        },
                        setPeerThreadMuted: { _, _, _ in
                        },
                        deletePeer: { _, _ in
                        },
                        deletePeerThread: { _, _ in
                        },
                        setPeerThreadStopped: { _, _, _ in
                        },
                        setPeerThreadPinned: { _, _, _ in
                        },
                        setPeerThreadHidden: { _, _, _ in
                        },
                        updatePeerGrouping: { _, _ in
                        },
                        togglePeerMarkedUnread: { _, _ in
                        },
                        toggleArchivedFolderHiddenByDefault: {
                        },
                        toggleThreadsSelection: { _, _ in
                        },
                        hidePsa: { _ in
                        },
                        activateChatPreview: { item, _, node, gesture, _ in
                            gesture?.cancel()
                        },
                        present: { _ in
                        },
                        openForumThread: { _, _ in
                        },
                        openStorageManagement: {
                        },
                        openPasswordSetup: {
                        },
                        openPremiumIntro: {
                        },
                        openPremiumGift: {
                        },
                        openActiveSessions: {
                        },
                        performActiveSessionAction: { _, _ in
                        },
                        openChatFolderUpdates: {
                        },
                        hideChatFolderUpdates: {
                        },
                        openStories: { _, _ in
                        },
                        dismissNotice: { _ in
                        }
                    )
                    self.chatListNodeInteraction = chatListNodeInteraction
                }
                
                let messageToItem: (EngineMessage) -> ListViewItem = { message -> ListViewItem in
                    var effectiveAuthor: EnginePeer?
                    
                    if let forwardInfo = message.forwardInfo {
                        effectiveAuthor = forwardInfo.author.flatMap(EnginePeer.init)
                        if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                            effectiveAuthor = EnginePeer(TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil))
                        }
                    }
                    if let sourceAuthorInfo = message._asMessage().sourceAuthorInfo {
                        if let originalAuthor = sourceAuthorInfo.originalAuthor, let peer = message.peers[originalAuthor] {
                            effectiveAuthor = EnginePeer(peer)
                        } else if let authorSignature = sourceAuthorInfo.originalAuthorName {
                            effectiveAuthor = EnginePeer(TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil))
                        }
                    }
                    if effectiveAuthor == nil {
                        effectiveAuthor = message.author
                    }
                    
                    let renderedPeer: EngineRenderedPeer
                    if let effectiveAuthor {
                        renderedPeer = EngineRenderedPeer(peer: effectiveAuthor)
                    } else {
                        renderedPeer = EngineRenderedPeer(peerId: message.id.peerId, peers: [:], associatedMedia: [:])
                    }
                    
                    return ChatListItem(
                        presentationData: chatListPresentationData,
                        context: component.context,
                        chatListLocation: .savedMessagesChats,
                        filterData: nil,
                        index: .forum(
                            pinnedIndex: .none,
                            timestamp: message.timestamp,
                            threadId: message.threadId ?? component.context.account.peerId.toInt64(),
                            namespace: message.id.namespace,
                            id: message.id.id
                        ),
                        content: .peer(ChatListItemContent.PeerData(
                            messages: [message],
                            peer: renderedPeer,
                            threadInfo: nil,
                            combinedReadState: nil,
                            isRemovedFromTotalUnreadCount: false,
                            presence: nil,
                            hasUnseenMentions: false,
                            hasUnseenReactions: false,
                            draftState: nil,
                            inputActivities: nil,
                            promoInfo: nil,
                            ignoreUnreadBadge: false,
                            displayAsMessage: false,
                            hasFailedMessages: false,
                            forumTopicData: nil,
                            topForumTopicItems: [],
                            autoremoveTimeout: nil,
                            storyState: nil,
                            requiresPremiumForMessaging: false,
                            displayAsTopicList: false
                        )),
                        editing: false,
                        hasActiveRevealControls: false,
                        selected: false,
                        header: nil,
                        enableContextActions: false,
                        hiddenOffset: false,
                        interaction: chatListNodeInteraction
                    )
                }
                
                var scrollToItem: ListViewScrollToItem?
                if previousContentsState?.tag != contentsState.tag && !contentsState.entries.isEmpty {
                    scrollToItem = ListViewScrollToItem(
                        index: 0,
                        position: .top(0.0),
                        animated: false,
                        curve: .Default(duration: nil),
                        directionHint: .Up
                    )
                }
                
                self.listNode.transaction(
                    deleteIndices: deleteIndices.map { index in
                        return ListViewDeleteItem(index: index, directionHint: nil)
                    },
                    insertIndicesAndItems: indicesAndItems.map { index, item, previousIndex in
                        return ListViewInsertItem(
                            index: index,
                            previousIndex: previousIndex,
                            item: messageToItem(item),
                            directionHint: nil,
                            forceAnimateInsertion: false
                        )
                    },
                    updateIndicesAndItems: updateIndices.map { index, item, previousIndex in
                        return ListViewUpdateItem(
                            index: index,
                            previousIndex: previousIndex,
                            item: messageToItem(item),
                            directionHint: nil
                        )
                    },
                    options: [.Synchronous, .LowLatency, .PreferSynchronousDrawing, .PreferSynchronousResourceLoading],
                    scrollToItem: scrollToItem,
                    updateSizeAndInsets: nil,
                    updateOpaqueState: contentsState.id
                )
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
