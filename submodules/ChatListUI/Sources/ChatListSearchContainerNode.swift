import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ContactsPeerItem
import ChatListSearchItemHeader
import ContactListUI
import ContextUI
import PhoneNumberFormat
import ItemListUI
import SearchBarNode
import ListMessageItem
import TelegramBaseController
import OverlayStatusController
import UniversalMediaPlayer
import PresentationDataUtils
import AnimatedStickerNode
import AppBundle
import GalleryData
import InstantPageUI
import ChatInterfaceState
import ShareController
import UndoUI
import TextFormat
import Postbox
import TelegramAnimatedStickerNode

private enum ChatListTokenId: Int32 {
    case archive
    case filter
    case peer
    case date
}

final class ChatListSearchInteraction {
    let openPeer: (EnginePeer, EnginePeer?, Bool) -> Void
    let openDisabledPeer: (EnginePeer) -> Void
    let openMessage: (EnginePeer, EngineMessage.Id, Bool) -> Void
    let openUrl: (String) -> Void
    let clearRecentSearch: () -> Void
    let addContact: (String) -> Void
    let toggleMessageSelection: (EngineMessage.Id, Bool) -> Void
    let messageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?, ChatListSearchPaneKey, (id: String, size: Int, isFirstInList: Bool)?) -> Void)
    let mediaMessageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)
    let peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?
    let present: (ViewController, Any?) -> Void
    let dismissInput: () -> Void
    let getSelectedMessageIds: () -> Set<EngineMessage.Id>?
    
    init(openPeer: @escaping (EnginePeer, EnginePeer?, Bool) -> Void, openDisabledPeer: @escaping (EnginePeer) -> Void, openMessage: @escaping (EnginePeer, EngineMessage.Id, Bool) -> Void, openUrl: @escaping (String) -> Void, clearRecentSearch: @escaping () -> Void, addContact: @escaping (String) -> Void, toggleMessageSelection: @escaping (EngineMessage.Id, Bool) -> Void, messageContextAction: @escaping ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?, ChatListSearchPaneKey, (id: String, size: Int, isFirstInList: Bool)?) -> Void), mediaMessageContextAction: @escaping ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void), peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void, getSelectedMessageIds: @escaping () -> Set<EngineMessage.Id>?) {
        self.openPeer = openPeer
        self.openDisabledPeer = openDisabledPeer
        self.openMessage = openMessage
        self.openUrl = openUrl
        self.clearRecentSearch = clearRecentSearch
        self.addContact = addContact
        self.toggleMessageSelection = toggleMessageSelection
        self.messageContextAction = messageContextAction
        self.mediaMessageContextAction = mediaMessageContextAction
        self.peerContextAction = peerContextAction
        self.present = present
        self.dismissInput = dismissInput
        self.getSelectedMessageIds = getSelectedMessageIds
    }
}

private struct ChatListSearchContainerNodeSearchState: Equatable {
    var selectedMessageIds: Set<EngineMessage.Id>?
    
    func withUpdatedSelectedMessageIds(_ selectedMessageIds: Set<EngineMessage.Id>?) -> ChatListSearchContainerNodeSearchState {
        return ChatListSearchContainerNodeSearchState(selectedMessageIds: selectedMessageIds)
    }
}

public final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let peersFilter: ChatListNodePeersFilter
    private let groupId: EngineChatList.Group
    private let displaySearchFilters: Bool
    private let hasDownloads: Bool
    private var interaction: ChatListSearchInteraction?
    private let openMessage: (EnginePeer, EngineMessage.Id, Bool) -> Void
    private let navigationController: NavigationController?
    
    let filterContainerNode: ChatListSearchFiltersContainerNode
    private let paneContainerNode: ChatListSearchPaneContainerNode
    private var selectionPanelNode: ChatListSearchMessageSelectionPanelNode?
    
    private var present: ((ViewController, Any?) -> Void)?
    private var presentInGlobalOverlay: ((ViewController, Any?) -> Void)?
    
    private let activeActionDisposable = MetaDisposable()
        
    private var searchQueryValue: String?
    private let searchQuery = Promise<String?>(nil)
    private var searchOptionsValue: ChatListSearchOptions?
    private let searchOptions = Promise<ChatListSearchOptions?>(nil)
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let suggestedDates = Promise<[(Date?, Date, String?)]>([])
    private var suggestedFilters: [ChatListSearchFilter]?
    private let suggestedFiltersDisposable = MetaDisposable()
    
    private var shareStatusDisposable: MetaDisposable?
    
    private var stateValue = ChatListSearchContainerNodeSearchState()
    private let statePromise = ValuePromise<ChatListSearchContainerNodeSearchState>()
    
    private var selectedFilter: ChatListSearchFilterEntry?
    private var selectedFilterPromise = Promise<ChatListSearchFilterEntry?>()
    private var transitionFraction: CGFloat = 0.0
    
    private weak var copyProtectionTooltipController: TooltipController?
    
    private var didSetReady: Bool = false
    private let _ready = Promise<Void>()
    public override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, filter: ChatListNodePeersFilter, groupId: EngineChatList.Group, displaySearchFilters: Bool, hasDownloads: Bool, initialFilter: ChatListSearchFilter = .chats, openPeer originalOpenPeer: @escaping (EnginePeer, EnginePeer?, Bool) -> Void, openDisabledPeer: @escaping (EnginePeer) -> Void, openRecentPeerOptions: @escaping (EnginePeer) -> Void, openMessage originalOpenMessage: @escaping (EnginePeer, EngineMessage.Id, Bool) -> Void, addContact: ((String) -> Void)?, peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, present: @escaping (ViewController, Any?) -> Void, presentInGlobalOverlay: @escaping (ViewController, Any?) -> Void, navigationController: NavigationController?) {
        self.context = context
        self.peersFilter = filter
        self.groupId = groupId
        self.displaySearchFilters = displaySearchFilters
        self.hasDownloads = hasDownloads
        self.navigationController = navigationController
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        self.selectedFilter = .filter(initialFilter)
        self.selectedFilterPromise.set(.single(self.selectedFilter))
        
        self.openMessage = originalOpenMessage
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
    
        self.filterContainerNode = ChatListSearchFiltersContainerNode()
        self.paneContainerNode = ChatListSearchPaneContainerNode(context: context, updatedPresentationData: updatedPresentationData, peersFilter: self.peersFilter, groupId: groupId, searchQuery: self.searchQuery.get(), searchOptions: self.searchOptions.get(), navigationController: navigationController)
        self.paneContainerNode.clipsToBounds = true
        
        super.init()
                
        self.backgroundColor = filter.contains(.excludeRecent) ? nil : self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.paneContainerNode)
                
        let interaction = ChatListSearchInteraction(openPeer: { peer, chatPeer, value in
            originalOpenPeer(peer, chatPeer, value)
            if peer.id.namespace != Namespaces.Peer.SecretChat {
                addAppLogEvent(postbox: context.account.postbox, type: "search_global_open_peer", peerId: peer.id)
            }
        }, openDisabledPeer: { peer in
            openDisabledPeer(peer)
        }, openMessage: { peer, messageId, deactivateOnAction in
            originalOpenMessage(peer, messageId, deactivateOnAction)
            if peer.id.namespace != Namespaces.Peer.SecretChat {
                addAppLogEvent(postbox: context.account.postbox, type: "search_global_open_message", peerId: peer.id, data: .dictionary(["msg_id": .number(Double(messageId.id))]))
            }
        }, openUrl: { [weak self] url in
            openUserGeneratedUrl(context: context, peerId: nil, url: url, concealed: false, present: { c in
                present(c, nil)
            }, openResolved: { [weak self] resolved in
                context.sharedContext.openResolvedUrl(resolved, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, openPeer: { peerId, navigation in
                    
                }, sendFile: nil,
                sendSticker: nil,
                requestMessageActionUrlAuth: nil,
                joinVoiceChat: nil,
                present: { c, a in
                    present(c, a)
                }, dismissInput: {
                    self?.dismissInput()
                }, contentContext: nil)
            })
        }, clearRecentSearch: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let presentationData = strongSelf.presentationData
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.ChatList_ClearSearchHistory),
                ActionSheetButtonItem(title: presentationData.strings.WebSearch_RecentSectionClear, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.engine.peers.clearRecentlySearchedPeers()
                    |> deliverOnMainQueue).start()
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            strongSelf.dismissInput()
            strongSelf.present?(actionSheet, nil)
        }, addContact: { phoneNumber in
            addContact?(phoneNumber)
        }, toggleMessageSelection: { [weak self] messageId, selected in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    var selectedMessageIds = state.selectedMessageIds ?? Set()
                    if selected {
                        selectedMessageIds.insert(messageId)
                    } else {
                        selectedMessageIds.remove(messageId)
                    }
                    return state.withUpdatedSelectedMessageIds(selectedMessageIds)
                }
            }
        }, messageContextAction: { [weak self] message, node, rect, gesture, paneKey, downloadResource in
            self?.messageContextAction(message, node: node, rect: rect, gesture: gesture, paneKey: paneKey, downloadResource: downloadResource)
        }, mediaMessageContextAction: { [weak self] message, node, rect, gesture in
            self?.mediaMessageContextAction(message, node: node, rect: rect, gesture: gesture)
        }, peerContextAction: { peer, source, node, gesture in
            peerContextAction?(peer, source, node, gesture)
        }, present: { c, a in
            present(c, a)
        }, dismissInput: { [weak self] in
            self?.dismissInput()
        }, getSelectedMessageIds: { [weak self] () -> Set<EngineMessage.Id>? in
            if let strongSelf = self {
                return strongSelf.stateValue.selectedMessageIds
            } else {
                return nil
            }
        })
        self.paneContainerNode.interaction = interaction
        
        self.paneContainerNode.currentPaneUpdated = { [weak self] key, transitionFraction, transition in
            if let strongSelf = self, let key = key {
                var filterKey: ChatListSearchFilter
                switch key {
                    case .chats:
                        filterKey = .chats
                    case .media:
                        filterKey = .media
                    case .downloads:
                        filterKey = .downloads
                    case .links:
                        filterKey = .links
                    case .files:
                        filterKey = .files
                    case .music:
                        filterKey = .music
                    case .voice:
                        filterKey = .voice
                }
                strongSelf.selectedFilter = .filter(filterKey)
                strongSelf.selectedFilterPromise.set(.single(strongSelf.selectedFilter))
                strongSelf.transitionFraction = transitionFraction
                
                if let (layout, _) = strongSelf.validLayout {
                    let filters: [ChatListSearchFilter]
                    if let suggestedFilters = strongSelf.suggestedFilters, !suggestedFilters.isEmpty {
                        filters = suggestedFilters
                    } else {
                        filters = defaultAvailableSearchPanes(hasDownloads: strongSelf.hasDownloads).map(\.filter)
                    }
                    strongSelf.filterContainerNode.update(size: CGSize(width: layout.size.width - 40.0, height: 38.0), sideInset: layout.safeInsets.left - 20.0, filters: filters.map { .filter($0) }, selectedFilter: strongSelf.selectedFilter?.id, transitionFraction: strongSelf.transitionFraction, presentationData: strongSelf.presentationData, transition: transition)
                }
            }
        }
        
        self.filterContainerNode.filterPressed = { [weak self] filter in
            guard let strongSelf = self else {
                return
            }
            
            var key: ChatListSearchPaneKey?
            var date = strongSelf.currentSearchOptions.date
            var peer = strongSelf.currentSearchOptions.peer
            
            switch filter {
                case .chats:
                    key = .chats
                case .media:
                    key = .media
                case .downloads:
                    key = .downloads
                case .links:
                    key = .links
                case .files:
                    key = .files
                case .music:
                    key = .music
                case .voice:
                    key = .voice
                case let .date(minDate, maxDate, title):
                    date = (minDate, maxDate, title)
                case let .peer(id, isGroup, _, compactDisplayTitle):
                    peer = (id, isGroup, compactDisplayTitle)
            }
            
            if let key = key {
                strongSelf.paneContainerNode.requestSelectPane(key)
            } else {
                strongSelf.updateSearchOptions(strongSelf.currentSearchOptions.withUpdatedDate(date).withUpdatedPeer(peer), clearQuery: true)
            }
        }
        
        self.filterContainerNode.filterPressed?(initialFilter)
        
        let searchQuerySignal = self.searchQuery.get()
        
        let suggestedPeers = self.selectedFilterPromise.get()
        |> map { filter -> Bool in
            guard let filter = filter else {
                return false
            }
            switch filter {
            case let .filter(filter):
                switch filter {
                case .downloads:
                    return false
                default:
                    return true
                }
            }
        }
        |> distinctUntilChanged
        |> mapToSignal { value -> Signal<String?, NoError> in
            if value {
                return searchQuerySignal
            } else {
                return .single(nil)
            }
        }
        |> mapToSignal { query -> Signal<[EnginePeer], NoError> in
            if let query = query {
                return context.account.postbox.searchPeers(query: query.lowercased())
                |> map { local -> [EnginePeer] in
                    return Array(local.compactMap { $0.peer }.prefix(10).map(EnginePeer.init))
                }
            } else {
                return .single([])
            }
        }
        
        let accountPeer = self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> take(1)
        
        self.suggestedFiltersDisposable.set((combineLatest(suggestedPeers, self.suggestedDates.get(), self.selectedFilterPromise.get(), self.searchQuery.get(), accountPeer)
        |> mapToSignal { peers, dates, selectedFilter, searchQuery, accountPeer -> Signal<([EnginePeer], [(Date?, Date, String?)], ChatListSearchFilterEntryId?, String?, EnginePeer?), NoError> in
            if searchQuery?.isEmpty ?? true {
                return .single((peers, dates, selectedFilter?.id, searchQuery, EnginePeer(accountPeer)))
            } else {
                return (.complete() |> delay(0.25, queue: Queue.mainQueue()))
                |> then(.single((peers, dates, selectedFilter?.id, searchQuery, EnginePeer(accountPeer))))
            }
        } |> map { peers, dates, selectedFilter, searchQuery, accountPeer -> [ChatListSearchFilter] in
            var suggestedFilters: [ChatListSearchFilter] = []
            if !dates.isEmpty {
                let formatter = DateFormatter()
                formatter.timeStyle = .none
                formatter.dateStyle = .medium
                
                for (minDate, maxDate, string) in dates {
                    let title = string ?? formatter.string(from: maxDate)
                    suggestedFilters.append(.date(minDate.flatMap { Int32($0.timeIntervalSince1970) }, Int32(maxDate.timeIntervalSince1970), title))
                }
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var existingPeerIds = Set<EnginePeer.Id>()
            var peers = peers
            if let accountPeer = accountPeer, let lowercasedQuery = searchQuery?.lowercased(), lowercasedQuery.count > 1 && (presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery)) {
                peers.insert(accountPeer, at: 0)
            }
            
            if !peers.isEmpty && selectedFilter != .filter(ChatListSearchFilter.chats.id) {
                for peer in peers {
                    if existingPeerIds.contains(peer.id) {
                        continue
                    }
                    let isGroup: Bool
                    if peer.id.namespace == Namespaces.Peer.SecretChat {
                        continue
                    } else if case let .channel(channel) = peer, case .group = channel.info {
                        isGroup = true
                    } else if peer.id.namespace == Namespaces.Peer.CloudGroup {
                        isGroup = true
                    } else {
                        isGroup = false
                    }
                    
                    var title: String = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    var compactDisplayTitle = peer.compactDisplayTitle
                    if peer.id == accountPeer?.id {
                        title = presentationData.strings.DialogList_SavedMessages
                        compactDisplayTitle = title
                    }
                    suggestedFilters.append(.peer(peer.id, isGroup, title, compactDisplayTitle))
                    existingPeerIds.insert(peer.id)
                }
            }
            return suggestedFilters
        } |> deliverOnMainQueue).start(next: { [weak self] filters in
            guard let strongSelf = self else {
                return
            }
            var filteredFilters: [ChatListSearchFilter] = []
            for filter in filters {
                if case .date = filter, strongSelf.searchOptionsValue?.date == nil {
                    filteredFilters.append(filter)
                }
                if case .peer = filter, strongSelf.searchOptionsValue?.peer == nil {
                    filteredFilters.append(filter)
                }
            }

            let previousFilters = strongSelf.suggestedFilters
            strongSelf.suggestedFilters = filteredFilters
            
            if filteredFilters != previousFilters {
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            }
        }))
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData

                if previousTheme !== presentationData.theme {
                    strongSelf.updateTheme(theme: presentationData.theme)
                }
            }
        })
        
        self._ready.set(self.paneContainerNode.isReady.get()
        |> map { _ in Void() })
    }
    
    deinit {
        self.activeActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.suggestedFiltersDisposable.dispose()
        self.shareStatusDisposable?.dispose()
        
        self.copyProtectionTooltipController?.dismiss()
    }
    
    private func updateState(_ f: (ChatListSearchContainerNodeSearchState) -> ChatListSearchContainerNodeSearchState) {
        let state = f(self.stateValue)
        if state != self.stateValue {
            self.stateValue = state
            self.statePromise.set(state)
        }
        for pane in self.paneContainerNode.currentPanes.values {
            pane.node.updateSelectedMessages(animated: true)
        }
        self.selectionPanelNode?.selectedMessages = self.stateValue.selectedMessageIds ?? []
    }

    private var currentSearchOptions: ChatListSearchOptions {
        return self.searchOptionsValue ?? ChatListSearchOptions(peer: nil, date: nil)
    }
    
    public override func searchTokensUpdated(tokens: [SearchBarToken]) {
        var updatedOptions = self.searchOptionsValue
        var tokensIdSet = Set<AnyHashable>()
        for token in tokens {
            tokensIdSet.insert(token.id)
        }
        if !tokensIdSet.contains(ChatListTokenId.date.rawValue) && updatedOptions?.date != nil {
             updatedOptions = updatedOptions?.withUpdatedDate(nil)
        }
        if !tokensIdSet.contains(ChatListTokenId.peer.rawValue) && updatedOptions?.peer != nil {
             updatedOptions = updatedOptions?.withUpdatedPeer(nil)
        }
        self.updateSearchOptions(updatedOptions)
    }
    
    private func updateSearchOptions(_ options: ChatListSearchOptions?, clearQuery: Bool = false) {
        var options = options
        var tokens: [SearchBarToken] = []
        if self.groupId == .archive {
            tokens.append(SearchBarToken(id: ChatListTokenId.archive.rawValue, icon: UIImage(bundleImageName: "Chat List/Search/Archive"), title: self.presentationData.strings.ChatList_Archive, permanent: true))
        }
        
        if options?.isEmpty ?? true {
            options = nil
        }
        self.searchOptionsValue = options
        self.searchOptions.set(.single(options))
        
        if let (peerId, isGroup, peerName) = options?.peer {
            let image: UIImage?
            if isGroup {
                image = UIImage(bundleImageName: "Chat List/Search/Group")
            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                image = UIImage(bundleImageName: "Chat List/Search/Channel")
            } else {
                image = UIImage(bundleImageName: "Chat List/Search/User")
            }
            tokens.append(SearchBarToken(id: ChatListTokenId.peer.rawValue, icon: image, title: peerName, permanent: false))
        }
        
        if let (_, _, dateTitle) = options?.date {
            tokens.append(SearchBarToken(id: ChatListTokenId.date.rawValue, icon: UIImage(bundleImageName: "Chat List/Search/Calendar"), title: dateTitle, permanent: false))
            
            self.suggestedDates.set(.single([]))
        }
        
        if clearQuery {
            self.setQuery?(nil, tokens, "")
        } else {
            self.setQuery?(nil, tokens, self.searchQueryValue ?? "")
        }
    }
    
    private func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = self.peersFilter.contains(.excludeRecent) ? nil : theme.chatList.backgroundColor
        
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    override public func searchTextUpdated(text: String) {
        let searchQuery: String? = !text.isEmpty ? text : nil
        self.searchQuery.set(.single(searchQuery))
        self.searchQueryValue = searchQuery
        
        self.suggestedDates.set(.single(suggestDates(for: text, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat)))
    }
    
    public func search(filter: ChatListSearchFilter, query: String?) {
        let key: ChatListSearchPaneKey
        switch filter {
            case .media:
                key = .media
            case .links:
                key = .links
            case .files:
                key = .files
            case .music:
                key = .music
            case .voice:
                key = .voice
            case .downloads:
                key = .downloads
            default:
                key = .chats
        }
        self.paneContainerNode.requestSelectPane(key)
        self.updateSearchOptions(nil)
        self.searchTextUpdated(text: query ?? "")
        
        var tokens: [SearchBarToken] = []
        if self.groupId == .archive {
            tokens.append(SearchBarToken(id: ChatListTokenId.archive.rawValue, icon: UIImage(bundleImageName: "Chat List/Search/Archive"), title: self.presentationData.strings.ChatList_Archive, permanent: true))
        }
        self.setQuery?(nil, tokens, query ?? "")
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.validLayout = (layout, navigationBarHeight)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.filterContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight + 6.0), size: CGSize(width: layout.size.width, height: 38.0)))
        
        let filters: [ChatListSearchFilter]
        if let suggestedFilters = self.suggestedFilters, !suggestedFilters.isEmpty {
            filters = suggestedFilters
        } else {
            filters = defaultAvailableSearchPanes(hasDownloads: self.hasDownloads).map(\.filter)
        }
        
        let overflowInset: CGFloat = 20.0
        self.filterContainerNode.update(size: CGSize(width: layout.size.width - overflowInset * 2.0, height: 38.0), sideInset: layout.safeInsets.left - overflowInset, filters: filters.map { .filter($0) }, selectedFilter: self.selectedFilter?.id, transitionFraction: self.transitionFraction, presentationData: self.presentationData, transition: .animated(duration: 0.4, curve: .spring))
        
        var bottomIntrinsicInset = layout.intrinsicInsets.bottom
        if case .root = self.groupId {
            if layout.safeInsets.left > overflowInset {
                bottomIntrinsicInset -= 34.0
            } else {
                bottomIntrinsicInset -= 49.0
            }
        }
        
        if let selectedMessageIds = self.stateValue.selectedMessageIds {
            var wasAdded = false
            let selectionPanelNode: ChatListSearchMessageSelectionPanelNode
            if let current = self.selectionPanelNode {
                selectionPanelNode = current
            } else {
                wasAdded = true
                selectionPanelNode = ChatListSearchMessageSelectionPanelNode(context: self.context, deleteMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.deleteMessages(messageIds: nil)
                }, shareMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.stateValue.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> [EngineMessage] in
                        var messages: [EngineMessage] = []
                        for id in messageIds {
                            if let message = transaction.getMessage(id) {
                                messages.append(EngineMessage(message))
                            }
                        }
                        return messages
                    }
                    |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            }).map({ $0._asMessage() })), externalShare: true, immediateExternalShare: true)
                            strongSelf.dismissInput()
                            strongSelf.present?(shareController, nil)
                        }
                    })
                }, forwardMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.forwardMessages(messageIds: nil)
                }, displayCopyProtectionTip: { [weak self] node, save in
                    guard let strongSelf = self, let messageIds = strongSelf.stateValue.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> [EngineMessage] in
                        var messages: [EngineMessage] = []
                        for id in messageIds {
                            if let message = transaction.getMessage(id) {
                                messages.append(EngineMessage(message))
                            }
                        }
                        return messages
                    }
                    |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            enum PeerType {
                                case group
                                case channel
                                case bot
                            }
                            var type: PeerType = .group
                            for message in messages {
                                if let user = message.author?._asPeer() as? TelegramUser, user.botInfo != nil {
                                    type = .bot
                                    break
                                } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                                    type = .channel
                                    break
                                }
                            }
                            
                            let text: String
                            switch type {
                            case .group:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledGroup : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledGroup
                            case .channel:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledChannel : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledChannel
                            case .bot:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledBot : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledBot
                            }
                            
                            strongSelf.copyProtectionTooltipController?.dismiss()
                            let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                            strongSelf.copyProtectionTooltipController = tooltipController
                            tooltipController.dismissed = { [weak tooltipController] _ in
                                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.copyProtectionTooltipController === tooltipController {
                                    strongSelf.copyProtectionTooltipController = nil
                                }
                            }
                            strongSelf.present?(tooltipController, TooltipControllerPresentationArguments(sourceNodeAndRect: {
                                if let strongSelf = self {
                                    let rect = node.view.convert(node.view.bounds, to: strongSelf.view).offsetBy(dx: 0.0, dy: 3.0)
                                    return (strongSelf, rect)
                                }
                                return nil
                            }))
                        }
                    })
                })
                selectionPanelNode.chatAvailableMessageActions = { [weak self] messageIds -> Signal<ChatAvailableMessageActions, NoError> in
                    guard let strongSelf = self else {
                        return .complete()
                    }

                    let (peers, messages) = strongSelf.currentMessages
                    return strongSelf.context.sharedContext.chatAvailableMessageActions(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds, messages: messages, peers: peers)
                }
                self.selectionPanelNode = selectionPanelNode
                self.addSubnode(selectionPanelNode)
            }
            selectionPanelNode.selectedMessages = selectedMessageIds
            
            let panelHeight = selectionPanelNode.update(layout: layout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: -(layout.intrinsicInsets.bottom - bottomIntrinsicInset), right: 0.0)), presentationData: self.presentationData, transition: wasAdded ? .immediate : transition)
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            if wasAdded {
                selectionPanelNode.frame = panelFrame
                transition.animatePositionAdditive(node: selectionPanelNode, offset: CGPoint(x: 0.0, y: panelHeight))
            } else {
                transition.updateFrame(node: selectionPanelNode, frame: panelFrame)
            }
            
            bottomIntrinsicInset = panelHeight
        } else if let selectionPanelNode = self.selectionPanelNode {
            self.selectionPanelNode = nil
            transition.updateFrame(node: selectionPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: selectionPanelNode.bounds.size), completion: { [weak selectionPanelNode] _ in
                selectionPanelNode?.removeFromSupernode()
            })
        }
        
        transition.updateFrame(node: self.paneContainerNode, frame: CGRect(x: 0.0, y: topInset, width: layout.size.width, height: layout.size.height - topInset))
        
        var bottomInset = layout.intrinsicInsets.bottom
        if let inputHeight = layout.inputHeight {
            bottomInset = inputHeight
        } else if let _ = self.selectionPanelNode {
            bottomInset = bottomIntrinsicInset
        } else if case .root = self.groupId {
            bottomInset -= bottomIntrinsicInset
        }
        
        let availablePanes: [ChatListSearchPaneKey]
        if self.displaySearchFilters {
            availablePanes = defaultAvailableSearchPanes(hasDownloads: self.hasDownloads)
        } else {
            availablePanes = [.chats]
        }

        self.paneContainerNode.update(size: CGSize(width: layout.size.width, height: layout.size.height - topInset), sideInset: layout.safeInsets.left, bottomInset: bottomInset, visibleHeight: layout.size.height - topInset, presentationData: self.presentationData, availablePanes: availablePanes, transition: transition)
    }
    
    private var currentMessages: ([EnginePeer.Id: EnginePeer], [EngineMessage.Id: EngineMessage]) {
        var peers: [EnginePeer.Id: EnginePeer] = [:]
        let messages: [EngineMessage.Id: EngineMessage] = self.paneContainerNode.allCurrentMessages()
        for (_, message) in messages {
            for (_, peer) in message.peers {
                peers[peer.id] = EnginePeer(peer)
            }
        }
        return (peers, messages)
    }
    
    override public func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        if let node = self.paneContainerNode.currentPane?.node {
            let adjustedLocation = self.convert(location, to: node)
            return self.paneContainerNode.currentPane?.node.previewViewAndActionAtLocation(adjustedLocation)
        } else {
            return nil
        }
    }
    
    override public func scrollToTop() {
        let _ = self.paneContainerNode.scrollToTop()
    }
    
    private func messageContextAction(_ message: EngineMessage, node: ASDisplayNode?, rect: CGRect?, gesture anyRecognizer: UIGestureRecognizer?, paneKey: ChatListSearchPaneKey, downloadResource: (id: String, size: Int, isFirstInList: Bool)?) {
        guard let node = node as? ContextExtractedContentContainingNode else {
            return
        }
        
        let gesture: ContextGesture? = anyRecognizer as? ContextGesture
        
        if paneKey == .downloads {
            let isCachedValue: Signal<Bool, NoError>
            if let downloadResource = downloadResource {
                isCachedValue = self.context.account.postbox.mediaBox.resourceStatus(MediaResourceId(downloadResource.id), resourceSize: downloadResource.size)
                |> map { status -> Bool in
                    switch status {
                    case .Local:
                        return true
                    default:
                        return false
                    }
                }
                |> distinctUntilChanged
            } else {
                isCachedValue = .single(false)
            }
            
            let shouldBeDismissed: Signal<Bool, NoError> = Signal { subscriber in
                subscriber.putNext(false)
                let previous = Atomic<Bool?>(value: nil)
                return isCachedValue.start(next: { value in
                    let previousSwapped = previous.swap(value)
                    if let previousSwapped = previousSwapped, previousSwapped != value {
                        subscriber.putNext(true)
                        subscriber.putCompletion()
                    }
                })
            }
            
            let items = combineLatest(queue: .mainQueue(),
                context.sharedContext.chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: [message.id], messages: [message.id: message], peers: [:]),
                isCachedValue |> take(1)
            )
            |> deliverOnMainQueue
            |> map { [weak self] actions, isCachedValue -> [ContextMenuItem] in
                guard let strongSelf = self else {
                    return []
                }
                
                var items: [ContextMenuItem] = []
                
                if isCachedValue {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.DownloadList_DeleteFromCache, textColor: .primary, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        guard let strongSelf = self, let downloadResource = downloadResource else {
                            f(.default)
                            return
                        }
                        let _ = (strongSelf.context.account.postbox.mediaBox.removeCachedResources([MediaResourceId(downloadResource.id)], notify: true)
                        |> deliverOnMainQueue).start(completed: {
                            f(.dismissWithoutContent)
                        })
                    })))
                } else {
                    if let downloadResource = downloadResource, !downloadResource.isFirstInList {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.DownloadList_RaisePriority, textColor: .primary, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Raise"), color: theme.contextMenu.primaryColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                f(.default)
                                return
                            }
                            
                            strongSelf.context.fetchManager.raisePriority(resourceId: downloadResource.id)
                            
                            Queue.mainQueue().after(0.2, {
                                f(.default)
                            })
                        })))
                    }
                    
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.DownloadList_CancelDownloading, textColor: .primary, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        guard let strongSelf = self, let downloadResource = downloadResource else {
                            f(.default)
                            return
                        }
                        
                        strongSelf.context.fetchManager.cancelInteractiveFetches(resourceId: downloadResource.id)
                        
                        f(.dismissWithoutContent)
                    })))
                }
                
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c.dismiss(completion: { [weak self] in
                        self?.openMessage(EnginePeer(message.peers[message.id.peerId]!), message.id, false)
                    })
                })))
                
                if isCachedValue {
                    if !items.isEmpty {
                        items.append(.separator)
                    }
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                        c.dismiss(completion: {
                            if let strongSelf = self {
                                strongSelf.dismissInput()
                                
                                strongSelf.updateState { state in
                                    return state.withUpdatedSelectedMessageIds([message.id])
                                }
                                
                                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                                }
                            }
                        })
                    })))
                }
                
                /*if !actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty {
                    if !items.isEmpty {
                        items.append(.separator)
                    }
                    
                    if actions.options.contains(.deleteLocally) {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe, textColor: .destructive, icon: { _ in
                            return nil
                        }, action: { controller, f in
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: [message.id], type: .forLocalPeer).start()
                            f(.dismissWithoutContent)
                        })))
                    }
                    
                    if actions.options.contains(.deleteGlobally) {
                        let text: String
                        if let mainPeer = message.peers[message.id.peerId] {
                            if mainPeer is TelegramUser {
                                text = strongSelf.presentationData.strings.ChatList_DeleteForEveryone(EnginePeer(mainPeer).compactDisplayTitle).string
                            } else {
                                text = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                            }
                        } else {
                            text = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                        }
                        items.append(.action(ContextMenuActionItem(text: text, textColor: .destructive, icon: { _ in
                            return nil
                        }, action: { controller, f in
                            let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: [message.id], type: .forEveryone).start()
                            f(.dismissWithoutContent)
                        })))
                    }
                }*/
                
                return items
            }
            
            let controller = ContextController(account: self.context.account, presentationData: self.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node, shouldBeDismissed: shouldBeDismissed)), items: items |> map { ContextController.Items(content: .list($0)) }, recognizer: nil, gesture: gesture)
            self.presentInGlobalOverlay?(controller, nil)
            
            return
        }
        
        let _ = storedMessageFromSearch(account: self.context.account, message: message._asMessage()).start()
        
        var linkForCopying: String?
        var currentSupernode: ASDisplayNode? = node
        while true {
            if currentSupernode == nil {
                break
            } else if let currentSupernode = currentSupernode as? ListMessageSnippetItemNode {
                linkForCopying = currentSupernode.currentPrimaryUrl
                break
            } else {
                currentSupernode = currentSupernode?.supernode
            }
        }
        
        let context = self.context
        let (peers, messages) = self.currentMessages
        let items = context.sharedContext.chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: [message.id], messages: messages, peers: peers)
        |> map { [weak self] actions -> [ContextMenuItem] in
            guard let strongSelf = self else {
                return []
            }
            var items: [ContextMenuItem] = []
            
            if let linkForCopying = linkForCopying {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c.dismiss(completion: {})
                    UIPasteboard.general.string = linkForCopying
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    self?.present?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c.dismiss(completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.forwardMessages(messageIds: Set([message.id]))
                    }
                })
            })))
            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c.dismiss(completion: { [weak self] in
                    self?.openMessage(EnginePeer(message.peers[message.id.peerId]!), message.id, false)
                })
            })))
            
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c.dismiss(completion: {
                    if let strongSelf = self {
                        strongSelf.dismissInput()
                        
                        strongSelf.updateState { state in
                            return state.withUpdatedSelectedMessageIds([message.id])
                        }
                        
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                        }
                    }
                })
            })))
            return items
        }
        
        let controller = ContextController(account: self.context.account, presentationData: self.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: items |> map { ContextController.Items(content: .list($0)) }, recognizer: nil, gesture: gesture)
        self.presentInGlobalOverlay?(controller, nil)
    }
    
    private func mediaMessageContextAction(_ message: EngineMessage, node: ASDisplayNode?, rect: CGRect?, gesture anyRecognizer: UIGestureRecognizer?) {
        let gesture: ContextGesture? = anyRecognizer as? ContextGesture
        let _ = (chatMediaListPreviewControllerData(context: self.context, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), message: message._asMessage(), standalone: true, reverseMessageGalleryOrder: false, navigationController: self.navigationController)
            |> deliverOnMainQueue).start(next: { [weak self] previewData in
                guard let strongSelf = self else {
                    gesture?.cancel()
                    return
                }
                if let previewData = previewData {
                    let context = strongSelf.context
                    let strings = strongSelf.presentationData.strings
                    
                    let (peers, messages) = strongSelf.currentMessages
                    let items = context.sharedContext.chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: [message.id], messages: messages, peers: peers)
                    |> map { actions -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = []
                        
                        items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c.dismiss(completion: {
                                self?.openMessage(EnginePeer(message.peers[message.id.peerId]!), message.id, false)
                            })
                        })))
                        
                        if let peer = message.peers[message.id.peerId], peer.isCopyProtectionEnabled {
                            
                        } else {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                                c.dismiss(completion: {
                                    if let strongSelf = self {
                                        strongSelf.forwardMessages(messageIds: [message.id])
                                    }
                                })
                            })))
                        }
                        
                        items.append(.separator)
                        items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuSelect, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            if let strongSelf = self {
                                strongSelf.dismissInput()
                                
                                strongSelf.updateState { state in
                                    return state.withUpdatedSelectedMessageIds([message.id])
                                }
                                
                                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                                }
                            }
                            
                            f(.default)
                        })))
                        
                        return items
                    }
                    
                    switch previewData {
                        case let .gallery(gallery):
                            gallery.setHintWillBePresentedInPreviewingContext(true)
                            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                            strongSelf.presentInGlobalOverlay?(contextController, nil)
                        case .instantPage:
                            break
                    }
                }
            })
    }
    
    public override func searchTextClearTokens() {
        self.updateSearchOptions(nil)
        self.setQuery?(nil, [], self.searchQueryValue ?? "")
    }
    
    func deleteMessages(messageIds: Set<EngineMessage.Id>?) {
        let isDownloads = self.paneContainerNode.currentPaneKey == .downloads
        
        if let messageIds = messageIds ?? self.stateValue.selectedMessageIds, !messageIds.isEmpty {
            if isDownloads {
                let _ = (self.context.account.postbox.transaction { transaction -> [Message] in
                    return messageIds.compactMap(transaction.getMessage)
                }
                |> deliverOnMainQueue).start(next: { [weak self] messages in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let title: String
                    let text: String
                    
                    title = strongSelf.presentationData.strings.DownloadList_RemoveFileAlertTitle(Int32(messages.count))
                    text = strongSelf.presentationData.strings.DownloadList_RemoveFileAlertText(Int32(messages.count))
                    
                    strongSelf.present?(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: title, text: text, actions: [
                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                        }),
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.DownloadList_RemoveFileAlertRemove, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            var resourceIds = Set<MediaResourceId>()
                            for message in messages {
                                for media in message.media {
                                    if let file = media as? TelegramMediaFile {
                                        resourceIds.insert(file.resource.id)
                                    }
                                }
                            }
                            
                            let _ = (strongSelf.context.account.postbox.mediaBox.removeCachedResources(resourceIds, force: true, notify: true)
                            |> deliverOnMainQueue).start(completed: {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.updateState { state in
                                    return state.withUpdatedSelectedMessageIds(nil)
                                }
                                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                                }
                            })
                        })
                    ], actionLayout: .horizontal, parseMarkdown: true), nil)
                })
            } else {
                let (peers, messages) = self.currentMessages
                let _ = (self.context.account.postbox.transaction { transaction -> Void in
                    for id in messageIds {
                        if transaction.getMessage(id) == nil, let message = messages[id] {
                            storeMessageFromSearch(transaction: transaction, message: message._asMessage())
                        }
                    }
                }).start()
                
                self.activeActionDisposable.set((self.context.sharedContext.chatAvailableMessageActions(postbox: self.context.account.postbox, accountPeerId: self.context.account.peerId, messageIds: messageIds, messages: messages, peers: peers)
                |> deliverOnMainQueue).start(next: { [weak self] actions in
                    if let strongSelf = self, !actions.options.isEmpty {
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        var items: [ActionSheetItem] = []
                        let personalPeerName: String? = nil
                        
                        if actions.options.contains(.deleteGlobally) {
                            let globalTitle: String
                            if let personalPeerName = personalPeerName {
                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                            } else {
                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                            }
                            items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
                                    
                                    strongSelf.updateState { state in
                                        return state.withUpdatedSelectedMessageIds(nil)
                                    }
                                    if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                                    }
                                }
                            }))
                        }
                        if actions.options.contains(.deleteLocally) {
                            let localOptionText = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                            items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).start()
                                    
                                    strongSelf.updateState { state in
                                        return state.withUpdatedSelectedMessageIds(nil)
                                    }
                                    if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                                    }
                                }
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.view.endEditing(true)
                        strongSelf.present?(actionSheet, nil)
                    }
                }))
            }
        }
    }
    
    func forwardMessages(messageIds: Set<EngineMessage.Id>?) {
        let messageIds = messageIds ?? self.stateValue.selectedMessageIds
        if let messageIds = messageIds, !messageIds.isEmpty {
            let messages = self.paneContainerNode.allCurrentMessages()
            let _ = (self.context.account.postbox.transaction { transaction -> Void in
                for id in messageIds {
                    if transaction.getMessage(id) == nil, let message = messages[id] {
                        storeMessageFromSearch(transaction: transaction, message: message._asMessage())
                    }
                }
            }).start()
            
            let peerSelectionController = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: [.onlyWriteable, .excludeDisabled], multipleSelection: true))
            peerSelectionController.multiplePeersSelected = { [weak self, weak peerSelectionController] peers, peerMap, messageText, mode, forwardOptions in
                guard let strongSelf = self, let strongController = peerSelectionController else {
                    return
                }
                strongController.dismiss()
                                
                var result: [EnqueueMessage] = []
                if messageText.string.count > 0 {
                    let inputText = convertMarkdownToAttributes(messageText)
                    for text in breakChatInputText(trimChatInputText(inputText)) {
                        if text.length != 0 {
                            var attributes: [EngineMessage.Attribute] = []
                            let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                            if !entities.isEmpty {
                                attributes.append(TextEntitiesMessageAttribute(entities: entities))
                            }
                            result.append(.message(text: text.string, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                        }
                    }
                }
                
                var attributes: [EngineMessage.Attribute] = []
                attributes.append(ForwardOptionsMessageAttribute(hideNames: forwardOptions?.hideNames == true, hideCaptions: forwardOptions?.hideCaptions == true))
                
                result.append(contentsOf: messageIds.map { messageId -> EnqueueMessage in
                    return .forward(source: messageId, grouping: .auto, attributes: attributes, correlationId: nil)
                })
                
                var displayPeers: [EnginePeer] = []
                for peer in peers {
                    let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: result)
                    |> deliverOnMainQueue).start(next: { messageIds in
                        if let strongSelf = self {
                            let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                guard let id = id else {
                                    return nil
                                }
                                return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                    if status != nil {
                                        return .never()
                                    } else {
                                        return .single(true)
                                    }
                                }
                                |> take(1)
                            })
                            if strongSelf.shareStatusDisposable == nil {
                                strongSelf.shareStatusDisposable = MetaDisposable()
                            }
                            strongSelf.shareStatusDisposable?.set((combineLatest(signals)
                            |> deliverOnMainQueue).start())
                        }
                    })
                    if let secretPeer = peer as? TelegramSecretChat {
                        if let peer = peerMap[secretPeer.regularPeerId] {
                            displayPeers.append(EnginePeer(peer))
                        }
                    } else {
                        displayPeers.append(EnginePeer(peer))
                    }
                }
                    
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                var savedMessages = false
                if displayPeers.count == 1, let peerId = displayPeers.first?.id, peerId == strongSelf.context.account.peerId {
                    text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                    savedMessages = true
                } else {
                    if displayPeers.count == 1, let peer = displayPeers.first {
                        let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                    } else if displayPeers.count == 2, let firstPeer = displayPeers.first, let secondPeer = displayPeers.last {
                        let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                    } else if let peer = displayPeers.first {
                        let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(displayPeers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(displayPeers.count - 1)").string
                    } else {
                        text = ""
                    }
                }
                
                (strongSelf.navigationController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            }
            peerSelectionController.peerSelected = { [weak self, weak peerSelectionController] peer in
                let peerId = peer.id
                if let strongSelf = self, let _ = peerSelectionController {
                    if peerId == strongSelf.context.account.peerId {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        (strongSelf.navigationController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .window(.root))
                        
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                            return .forward(source: id, grouping: .auto, attributes: [], correlationId: nil)
                        })
                        |> deliverOnMainQueue).start(next: { [weak self] messageIds in
                            if let strongSelf = self {
                                let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                    guard let id = id else {
                                        return nil
                                    }
                                    return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                    |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                        if status != nil {
                                            return .never()
                                        } else {
                                            return .single(true)
                                        }
                                    }
                                    |> take(1)
                                })
                                strongSelf.activeActionDisposable.set((combineLatest(signals)
                                |> deliverOnMainQueue).start(completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.present?(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .success), nil)
                                }))
                            }
                        })
                        if let peerSelectionController = peerSelectionController {
                            peerSelectionController.dismiss()
                        }

                        strongSelf.updateState { state in
                            return state.withUpdatedSelectedMessageIds(nil)
                        }
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                        }
                    } else {
                        let _ = (ChatInterfaceState.update(engine: strongSelf.context.engine, peerId: peerId, threadId: nil, { currentState in
                            return currentState.withUpdatedForwardMessageIds(Array(messageIds))
                        })
                        |> deliverOnMainQueue).start(completed: {
                            if let strongSelf = self {
                                let controller = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
                                controller.purposefulAction = { [weak self] in
                                    self?.cancel?()
                                }
                                
                                if let navigationController = strongSelf.navigationController, let peerSelectionControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 is PeerSelectionController }) {
                                    var viewControllers = navigationController.viewControllers
                                    viewControllers.insert(controller, at: peerSelectionControllerIndex)
                                    navigationController.setViewControllers(viewControllers, animated: false)
                                    Queue.mainQueue().after(0.2) {
                                        peerSelectionController?.dismiss()
                                    }
                                } else {
                                    strongSelf.navigationController?.pushViewController(controller, animated: false, completion: {
                                        if let peerSelectionController = peerSelectionController {
                                            peerSelectionController.dismiss()
                                        }
                                    })
                                }

                                strongSelf.updateState { state in
                                    return state.withUpdatedSelectedMessageIds(nil)
                                }
                                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                                }
                            }
                        })
                    }
                }
            }
            self.navigationController?.pushViewController(peerSelectionController)
        }
    }
    
    private func dismissInput() {
        self.view.window?.endEditing(true)
    }
}

private final class MessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    let shouldBeDismissed: Signal<Bool, NoError>
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode, shouldBeDismissed: Signal<Bool, NoError>? = nil) {
        self.sourceNode = sourceNode
        self.shouldBeDismissed = shouldBeDismissed ?? .single(false)
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        self.controller.didAppearInContextPreview()
    }
}

final class ActionSheetAnimationAndTextItem: ActionSheetItem {
    public let title: String
    public let text: String
    
    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetAnimationAndTextItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetAnimationAndTextItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

final class ActionSheetAnimationAndTextItemNode: ActionSheetItemNode {
    private let defaultFont: UIFont
    
    private let theme: ActionSheetControllerTheme
    
    private var item: ActionSheetAnimationAndTextItem?
    
    private let animationNode: AnimatedStickerNode
    private let textLabel: ImmediateTextNode
    private let titleLabel: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ClearDownloadList"), width: 256, height: 256, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.titleLabel = ImmediateTextNode()
        self.titleLabel.isUserInteractionEnabled = false
        self.titleLabel.maximumNumberOfLines = 0
        self.titleLabel.displaysAsynchronously = false
        self.titleLabel.truncationType = .end
        self.titleLabel.isAccessibilityElement = false
        
        self.textLabel = ImmediateTextNode()
        self.textLabel.isUserInteractionEnabled = false
        self.textLabel.maximumNumberOfLines = 0
        self.textLabel.displaysAsynchronously = false
        self.textLabel.truncationType = .end
        self.textLabel.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        self.accessibilityArea.accessibilityTraits = .staticText
        
        super.init(theme: theme)
        
        self.addSubnode(self.animationNode)
        
        self.titleLabel.isUserInteractionEnabled = false
        self.textLabel.isUserInteractionEnabled = false
        
        self.addSubnode(self.titleLabel)
        self.addSubnode(self.textLabel)
        
        self.addSubnode(self.accessibilityArea)
    }
    
    func setItem(_ item: ActionSheetAnimationAndTextItem) {
        self.item = item
        
        let defaultTitleFont = Font.semibold(floor(theme.baseFontSize * 17.0 / 17.0))
        let defaultFont = Font.regular(floor(theme.baseFontSize * 16.0 / 17.0))
        
        self.titleLabel.attributedText = NSAttributedString(string: item.title, font: defaultTitleFont, textColor: self.theme.primaryTextColor, paragraphAlignment: .center)
        self.textLabel.attributedText = NSAttributedString(string: item.text, font: defaultFont, textColor: self.theme.secondaryTextColor, paragraphAlignment: .center)
        self.accessibilityArea.accessibilityLabel = item.title
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let topInset: CGFloat = 20.0
        let textSpacing: CGFloat = 10.0
        let bottomInset: CGFloat = 16.0
        let imageInset: CGFloat = 6.0
        
        let titleSize = self.titleLabel.updateLayout(CGSize(width: max(1.0, constrainedSize.width - 20.0), height: constrainedSize.height))
        let textSize = self.textLabel.updateLayout(CGSize(width: max(1.0, constrainedSize.width - 20.0), height: constrainedSize.height))
        var size = CGSize(width: constrainedSize.width, height: max(57.0, titleSize.height + textSpacing + textSize.height + bottomInset))
        
        let imageSize = CGSize(width: 140.0, height: 140.0)
        size.height += topInset + 160.0 + imageInset
        
        self.animationNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: topInset), size: imageSize)
        self.animationNode.updateLayout(size: imageSize)
       
        self.titleLabel.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - textSize.height - textSpacing - bottomInset), size: titleSize)
        self.textLabel.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: size.height - textSize.height - bottomInset), size: textSize)
        
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
