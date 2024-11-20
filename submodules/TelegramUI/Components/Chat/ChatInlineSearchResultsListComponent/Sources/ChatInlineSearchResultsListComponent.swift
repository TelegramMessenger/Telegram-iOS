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
import ChatPresentationInterfaceState
import ContactsPeerItem
import ItemListUI
import ChatListSearchItemHeader
import LottieComponent
import MultilineTextComponent

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
        case empty
        case tag(MemoryBuffer)
        case search(query: String, includeSavedPeers: Bool)
    }
    
    public let context: AccountContext
    public let presentation: Presentation
    public let peerId: EnginePeer.Id?
    public let contents: Contents
    public let insets: UIEdgeInsets
    public let inputHeight: CGFloat
    public let showEmptyResults: Bool
    public let messageSelected: (EngineMessage) -> Void
    public let peerSelected: (EnginePeer) -> Void
    public let loadTagMessages: (MemoryBuffer, MessageIndex?) -> Signal<MessageHistoryView, NoError>?
    public let getSearchResult: () -> Signal<SearchMessagesResult?, NoError>?
    public let getSavedPeers: (String) -> Signal<[(EnginePeer, MessageIndex?)], NoError>?
    public let loadMoreSearchResults: () -> Void
    
    public init(
        context: AccountContext,
        presentation: Presentation,
        peerId: EnginePeer.Id?,
        contents: Contents,
        insets: UIEdgeInsets,
        inputHeight: CGFloat,
        showEmptyResults: Bool,
        messageSelected: @escaping (EngineMessage) -> Void,
        peerSelected: @escaping (EnginePeer) -> Void,
        loadTagMessages: @escaping (MemoryBuffer, MessageIndex?) -> Signal<MessageHistoryView, NoError>?,
        getSearchResult: @escaping () -> Signal<SearchMessagesResult?, NoError>?,
        getSavedPeers: @escaping (String) -> Signal<[(EnginePeer, MessageIndex?)], NoError>?,
        loadMoreSearchResults: @escaping () -> Void
    ) {
        self.context = context
        self.presentation = presentation
        self.peerId = peerId
        self.contents = contents
        self.insets = insets
        self.inputHeight = inputHeight
        self.showEmptyResults = showEmptyResults
        self.messageSelected = messageSelected
        self.peerSelected = peerSelected
        self.loadTagMessages = loadTagMessages
        self.getSearchResult = getSearchResult
        self.getSavedPeers = getSavedPeers
        self.loadMoreSearchResults = loadMoreSearchResults
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
        if lhs.inputHeight != rhs.inputHeight {
            return false
        }
        if lhs.showEmptyResults != rhs.showEmptyResults {
            return false
        }
        return true
    }
    
    private enum Entry: Equatable, Comparable {
        enum Id: Hashable {
            case peer(EnginePeer.Id)
            case message(EngineMessage.Id)
        }
        
        case peer(EnginePeer)
        case message(EngineMessage)
        
        var id: Id {
            switch self {
            case let .peer(peer):
                return .peer(peer.id)
            case let .message(message):
                return .message(message.id)
            }
        }
        
        static func ==(lhs: Entry, rhs: Entry) -> Bool {
            switch lhs {
            case let .peer(peer):
                if case .peer(peer) = rhs {
                    return true
                } else {
                    return false
                }
            case let .message(message):
                if case .message(message) = rhs {
                    return true
                } else {
                    return false
                }
            }
        }
        
        static func <(lhs: Entry, rhs: Entry) -> Bool {
            switch lhs {
            case let .peer(lhsPeer):
                switch rhs {
                case let .peer(rhsPeer):
                    if lhsPeer.debugDisplayTitle != rhsPeer.debugDisplayTitle {
                        return lhsPeer.debugDisplayTitle < rhsPeer.debugDisplayTitle
                    }
                    return lhsPeer.id < rhsPeer.id
                case .message:
                    return true
                }
            case let .message(lhsMessage):
                switch rhs {
                case .peer:
                    return false
                case let .message(rhsMessage):
                    return lhsMessage.index > rhsMessage.index
                }
            }
        }
    }
    
    private struct ContentsState: Equatable {
        enum ContentId: Equatable {
            case empty
            case tag(MemoryBuffer)
            case search(String)
        }
        
        var id: Int
        var contentId: ContentId
        var entries: [Entry]
        var messages: [EngineMessage]
        var hasEarlier: Bool
        var hasLater: Bool
        
        init(id: Int, contentId: ContentId, entries: [Entry], messages: [EngineMessage], hasEarlier: Bool, hasLater: Bool) {
            self.id = id
            self.contentId = contentId
            self.entries = entries
            self.messages = messages
            self.hasEarlier = hasEarlier
            self.hasLater = hasLater
        }
    }
    
    public final class View: UIView {
        private var component: ChatInlineSearchResultsListComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let listNode: ListView
        private let emptyResultsTitle = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let emptyResultsAnimation = ComponentView<Empty>()
        
        private var tagContents: (index: MessageIndex?, disposable: Disposable?)?
        private var searchContents: (index: MessageIndex?, disposable: Disposable?)?
        
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
            
            self.listNode.beganInteractiveDragging = { [weak self] _ in
                guard let self else {
                    return
                }
                self.window?.endEditing(true)
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.tagContents?.disposable?.dispose()
            self.searchContents?.disposable?.dispose()
        }
        
        public func scrollToTop() {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
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
        
        func update(component: ChatInlineSearchResultsListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            switch component.contents {
            case .empty:
                self.backgroundColor = nil
            default:
                break
            }
            
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
                guard let visibleRange = displayedRange.visibleRange else {
                    return
                }
                var loadAroundIndex: MessageIndex?
                if visibleRange.firstIndex <= 5 {
                    if contentsState.hasLater {
                        loadAroundIndex = contentsState.messages.first?.index
                    }
                } else if visibleRange.lastIndex >= contentsState.messages.count - 5 {
                    if contentsState.hasEarlier {
                        loadAroundIndex = contentsState.messages.last?.index
                    }
                }
                
                if let (currentIndex, disposable) = self.tagContents {
                    if let loadAroundIndex, loadAroundIndex != currentIndex {
                        switch component.contents {
                        case .empty:
                            break
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
                                    
                                    let messages = view.entries.reversed().map { entry in
                                        return EngineMessage(entry.message)
                                    }
                                    
                                    let contentsId = self.nextContentsId
                                    self.nextContentsId += 1
                                    self.contentsState = ContentsState(
                                        id: contentsId,
                                        contentId: .tag(tag),
                                        entries: messages.map { message in
                                            return .message(message)
                                        },
                                        messages: messages,
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
                        case .search:
                            break
                        }
                    }
                } else if let (currentIndex, disposable) = self.searchContents {
                    if let loadAroundIndex, loadAroundIndex != currentIndex {
                        switch component.contents {
                        case .empty:
                            break
                        case .tag:
                            break
                        case .search:
                            self.searchContents = (loadAroundIndex, disposable)
                            
                            component.loadMoreSearchResults()
                        }
                    }
                }
            }
            
            switch component.contents {
            case .empty:
                if previousComponent?.contents != component.contents {
                    self.tagContents?.disposable?.dispose()
                    self.tagContents = nil
                    
                    self.searchContents?.disposable?.dispose()
                    self.searchContents = nil
                    
                    let contentsId = self.nextContentsId
                    self.nextContentsId += 1
                    self.contentsState = ContentsState(
                        id: contentsId,
                        contentId: .empty,
                        entries: [],
                        messages: [],
                        hasEarlier: false,
                        hasLater: false
                    )
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                    
                    if !self.didSetReady {
                        self.didSetReady = true
                        self.isReadyPromise.set(.single(true))
                    }
                }
            case let .tag(tag):
                if previousComponent?.contents != component.contents {
                    self.tagContents?.disposable?.dispose()
                    self.tagContents = nil
                    
                    self.searchContents?.disposable?.dispose()
                    self.searchContents = nil
                    
                    let disposable = MetaDisposable()
                    self.tagContents = (nil, disposable)
                    
                    if let historySignal = component.loadTagMessages(tag, self.tagContents?.index) {
                        disposable.set((historySignal
                        |> deliverOnMainQueue).startStrict(next: { [weak self] view in
                            guard let self else {
                                return
                            }
                            
                            let messages = view.entries.reversed().map { entry in
                                return EngineMessage(entry.message)
                            }
                            
                            let contentsId = self.nextContentsId
                            self.nextContentsId += 1
                            self.contentsState = ContentsState(
                                id: contentsId,
                                contentId: .tag(tag),
                                entries: messages.map { message in
                                    return .message(message)
                                },
                                messages: messages,
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
            case let .search(query, includeSavedPeers):
                if previousComponent?.contents != component.contents {
                    self.tagContents?.disposable?.dispose()
                    self.tagContents = nil
                    
                    self.searchContents?.disposable?.dispose()
                    self.searchContents = nil
                    
                    let disposable = MetaDisposable()
                    self.searchContents = (nil, disposable)
                    
                    let savedPeers: Signal<[(EnginePeer, MessageIndex?)], NoError>
                    if includeSavedPeers, !query.isEmpty, let savedPeersSignal = component.getSavedPeers(query) {
                        savedPeers = savedPeersSignal
                    } else {
                        savedPeers = .single([])
                    }
                    
                    if let historySignal = component.getSearchResult() {
                        disposable.set((savedPeers
                        |> mapToSignal { savedPeers -> Signal<([(EnginePeer, MessageIndex?)], SearchMessagesResult?), NoError> in
                            if savedPeers.isEmpty {
                                return historySignal
                                |> map { result in
                                    return ([], result)
                                }
                            } else {
                                return (.single(nil) |> then(historySignal))
                                |> map { result in
                                    return (savedPeers, result)
                                }
                            }
                        }
                        |> deliverOnMainQueue).startStrict(next: { [weak self] savedPeers, result in
                            guard let self else {
                                return
                            }
                            
                            let messages: [EngineMessage] = result?.messages.map { entry in
                                return EngineMessage(entry)
                            } ?? []
                            
                            var entries: [Entry] = []
                            for (peer, _) in savedPeers {
                                entries.append(.peer(peer))
                            }
                            for message in messages {
                                entries.append(.message(message))
                            }
                            entries.sort()
                            
                            let contentsId = self.nextContentsId
                            self.nextContentsId += 1
                            self.contentsState = ContentsState(
                                id: contentsId,
                                contentId: .search(query),
                                entries: entries,
                                messages: messages,
                                hasEarlier: !(result?.completed ?? true),
                                hasLater: false
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
                        peerSelected: { _, _, _, _, _ in
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
                        openPremiumGift: { _, _ in
                        },
                        openPremiumManagement: {
                        }, 
                        openActiveSessions: {
                        },
                        openBirthdaySetup: {
                        },
                        performActiveSessionAction: { _, _ in
                        },
                        openChatFolderUpdates: {
                        },
                        hideChatFolderUpdates: {
                        },
                        openStories: { _, _ in
                        },
                        openStarsTopup: { _ in
                        },
                        dismissNotice: { _ in
                        },
                        editPeer: { _ in
                        },
                        openWebApp: { _ in
                        }
                    )
                    self.chatListNodeInteraction = chatListNodeInteraction
                }
                
                var searchTextHighightState: String?
                if case let .search(query, _) = component.contents, !query.isEmpty {
                    searchTextHighightState = query.lowercased()
                }
                
                var allUpdated = false
                if chatListNodeInteraction.searchTextHighightState != searchTextHighightState {
                    chatListNodeInteraction.searchTextHighightState = searchTextHighightState
                    allUpdated = true
                }
                
                let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(
                    leftList: previousContentsState?.entries ?? [],
                    rightList: contentsState.entries,
                    isLess: { lhs, rhs in
                        return lhs < rhs
                    },
                    isEqual: { lhs, rhs in
                        return lhs == rhs
                    },
                    getId: { entry in
                        return entry.id
                    },
                    allUpdated: allUpdated
                )
                
                let displayMessagesHeader = contentsState.entries.count != contentsState.messages.count
                
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
                
                let listPresentationData = ItemListPresentationData(component.context.sharedContext.currentPresentationData.with({ $0 }))
                let peerSelected = component.peerSelected
                
                let entryToItem: (Entry) -> ListViewItem = { entry -> ListViewItem in
                    switch entry {
                    case let .peer(peer):
                        return ContactsPeerItem(
                            presentationData: listPresentationData,
                            sortOrder: component.presentation.nameSortOrder,
                            displayOrder: component.presentation.nameDisplayOrder,
                            context: component.context,
                            peerMode: .generalSearch(isSavedMessages: true),
                            peer: .peer(peer: peer, chatPeer: peer),
                            status: .none,
                            badge: nil,
                            requiresPremiumForMessaging: false,
                            enabled: true,
                            selection: .none,
                            editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                            index: nil,
                            header: displayMessagesHeader ? ChatListSearchItemHeader(type: .chats, theme: listPresentationData.theme, strings: listPresentationData.strings) : nil,
                            action: { [weak self] peer in
                                self?.listNode.clearHighlightAnimated(true)
                                
                                if case let .peer(peer?, _) = peer {
                                    peerSelected(peer)
                                }
                            },
                            animationCache: component.context.animationCache,
                            animationRenderer: component.context.animationRenderer
                        )
                    case let .message(message):
                        var effectiveAuthor: EnginePeer?
                        
                        if let forwardInfo = message.forwardInfo {
                            effectiveAuthor = forwardInfo.author.flatMap(EnginePeer.init)
                            if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                                effectiveAuthor = EnginePeer(TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil))
                            }
                        }
                        if let sourceAuthorInfo = message._asMessage().sourceAuthorInfo {
                            if let originalAuthor = sourceAuthorInfo.originalAuthor, let peer = message.peers[originalAuthor] {
                                effectiveAuthor = EnginePeer(peer)
                            } else if let authorSignature = sourceAuthorInfo.originalAuthorName {
                                effectiveAuthor = EnginePeer(TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil))
                            }
                        }
                        if effectiveAuthor == nil {
                            effectiveAuthor = message.author
                        }
                        
                        let renderedPeer: EngineRenderedPeer
                        if let effectiveAuthor, !component.showEmptyResults {
                            renderedPeer = EngineRenderedPeer(peer: effectiveAuthor)
                        } else {
                            var peers: [EnginePeer.Id: EnginePeer] = [:]
                            if let peer = message.peers[message.id.peerId] {
                                peers[message.id.peerId] = EnginePeer(peer)
                            }
                            renderedPeer = EngineRenderedPeer(peerId: message.id.peerId, peers: peers, associatedMedia: [:])
                        }
                        
                        return ChatListItem(
                            presentationData: chatListPresentationData,
                            context: component.context,
                            chatListLocation: component.peerId == component.context.account.peerId ? .savedMessagesChats : .chatList(groupId: .root),
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
                                mediaDraftContentType: nil,
                                inputActivities: nil,
                                promoInfo: nil,
                                ignoreUnreadBadge: false,
                                displayAsMessage: component.peerId != component.context.account.peerId && !component.showEmptyResults,
                                hasFailedMessages: false,
                                forumTopicData: nil,
                                topForumTopicItems: [],
                                autoremoveTimeout: nil,
                                storyState: nil,
                                requiresPremiumForMessaging: false,
                                displayAsTopicList: false,
                                tags: []
                            )),
                            editing: false,
                            hasActiveRevealControls: false,
                            selected: false,
                            header: displayMessagesHeader ? ChatListSearchItemHeader(type: .messages(location: nil), theme: listPresentationData.theme, strings: listPresentationData.strings) : nil,
                            enableContextActions: false,
                            hiddenOffset: false,
                            interaction: chatListNodeInteraction
                        )
                    }
                }
                
                var scrollToItem: ListViewScrollToItem?
                if previousContentsState?.contentId != contentsState.contentId && !contentsState.entries.isEmpty {
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
                            item: entryToItem(item),
                            directionHint: nil,
                            forceAnimateInsertion: false
                        )
                    },
                    updateIndicesAndItems: updateIndices.map { index, item, previousIndex in
                        return ListViewUpdateItem(
                            index: index,
                            previousIndex: previousIndex,
                            item: entryToItem(item),
                            directionHint: nil
                        )
                    },
                    options: [.Synchronous, .LowLatency, .PreferSynchronousDrawing, .PreferSynchronousResourceLoading],
                    scrollToItem: scrollToItem,
                    updateSizeAndInsets: nil,
                    updateOpaqueState: contentsState.id
                )
                
                switch component.contents {
                case .empty:
                    self.backgroundColor = nil
                default:
                    self.backgroundColor = component.presentation.theme.list.plainBackgroundColor
                }
            }
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            if component.showEmptyResults, let appliedContentsState = self.appliedContentsState, appliedContentsState.entries.isEmpty, case let .search(query, _) = component.contents, !query.isEmpty {
                let sideInset: CGFloat = 44.0
                let emptyAnimationHeight = 148.0
                let topInset: CGFloat = component.insets.top
                let bottomInset: CGFloat = max(component.insets.bottom, component.inputHeight)
                let visibleHeight = availableSize.height
                let emptyAnimationSpacing: CGFloat = 8.0
                let emptyTextSpacing: CGFloat = 8.0
                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: component.presentation.strings.HashtagSearch_NoResults, font: Font.semibold(17.0), textColor: component.presentation.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                
                let placeholderText: String
                if query.hasPrefix("$") {
                    placeholderText = component.presentation.strings.HashtagSearch_NoResultsQueryCashtagDescription(query).string
                } else {
                    placeholderText = component.presentation.strings.HashtagSearch_NoResultsQueryDescription(query).string
                }
                
                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: placeholderText, font: Font.regular(15.0), textColor: component.presentation.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
      
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsTextSize.height + emptyTextSpacing
                let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                
                let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
                
                let emptyResultsTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - emptyResultsTextSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsTextSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    transition.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTextFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsText.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
