import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(PeerId)
    
    static func ==(lhs: ChatListRecentEntryStableId, rhs: ChatListRecentEntryStableId) -> Bool {
        switch lhs {
            case .topPeers:
                if case .topPeers = rhs {
                    return true
                } else {
                    return false
            }
            case let .peerId(peerId):
                if case .peerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .topPeers:
                return 0
            case let .peerId(peerId):
                return peerId.hashValue
        }
    }
}

private enum ChatListRecentEntry: Comparable, Identifiable {
    case topPeers([Peer], PresentationTheme, PresentationStrings)
    case peer(index: Int, peer: Peer, associatedPeer: Peer?, PresentationTheme, PresentationStrings, Bool)
    
    var stableId: ChatListRecentEntryStableId {
        switch self {
            case .topPeers:
                return .topPeers
            case let .peer(_, peer, _, _, _, _):
                return .peerId(peer.id)
        }
    }
    
    static func ==(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case let .topPeers(lhsPeers, lhsTheme, lhsStrings):
                if case let .topPeers(rhsPeers, rhsTheme, rhsStrings) = rhs {
                    if lhsPeers.count != rhsPeers.count {
                        return false
                    }
                    for i in 0 ..< lhsPeers.count {
                        if !lhsPeers[i].isEqual(rhsPeers[i]) {
                            return false
                        }
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsAssociatedPeer, lhsTheme, lhsStrings, lhsHasRevealControls):
                if case let .peer(rhsIndex, rhsPeer, rhsAssociatedPeer, rhsTheme, rhsStrings, rhsHasRevealControls) = rhs, lhsPeer.isEqual(rhsPeer) && arePeersEqual(lhsAssociatedPeer, rhsAssociatedPeer) && lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings && lhsHasRevealControls == rhsHasRevealControls {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case .topPeers:
                return true
            case let .peer(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .topPeers:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(account: Account, onlyWriteable: Bool, peerSelected: @escaping (Peer) -> Void, peerLongTapped: @escaping (Peer) -> Void, clearRecentlySearchedPeers: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, deletePeer: @escaping (PeerId) -> Void) -> ListViewItem {
        switch self {
            case let .topPeers(peers, theme, strings):
                return ChatListRecentPeersListItem(theme: theme, strings: strings, account: account, peers: peers, peerSelected: { peer in
                    peerSelected(peer)
                }, peerLongTapped: { peer in
                    peerLongTapped(peer)
                })
            case let .peer(_, peer, associatedPeer, theme, strings, hasRevealControls):
                let primaryPeer: Peer
                var chatPeer: Peer?
                if let associatedPeer = associatedPeer {
                    primaryPeer = associatedPeer
                    chatPeer = peer
                } else {
                    primaryPeer = peer
                    chatPeer = peer
                }
                
                var enabled = true
                if onlyWriteable {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer)
                    } else {
                        enabled = false
                    }
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, account: account, peerMode: .generalSearch, peer: primaryPeer, chatPeer: chatPeer, status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: true, editing: false, revealed: hasRevealControls), index: nil, header: ChatListSearchItemHeader(type: .recentPeers, theme: theme, strings: strings, actionTitle: strings.WebSearch_RecentSectionClear.uppercased(), action: {
                    clearRecentlySearchedPeers()
                }), action: { _ in
                    peerSelected(peer)
                }, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer)
        }
    }
}

enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    
    static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
        switch lhs {
            case let .localPeerId(peerId):
                if case .localPeerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .globalPeerId(peerId):
                if case .globalPeerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageId(messageId):
                if case .messageId(messageId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .localPeerId(peerId):
                return peerId.hashValue
            case let .globalPeerId(peerId):
                return peerId.hashValue
            case let .messageId(messageId):
                return messageId.hashValue
        }
    }
}


enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(Peer, Peer?, Int, PresentationTheme, PresentationStrings)
    case globalPeer(FoundPeer, Int, PresentationTheme, PresentationStrings)
    case message(Message, ChatListPresentationData)
    
    var stableId: ChatListSearchEntryStableId {
        switch self {
            case let .localPeer(peer, _, _, _, _):
                return .localPeerId(peer.id)
            case let .globalPeer(peer, _, _, _):
                return .globalPeerId(peer.peer.id)
            case let .message(message, _):
                return .messageId(message.id)
        }
    }
    
    static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(lhsPeer, lhsAssociatedPeer, lhsIndex, lhsTheme, lhsStrings):
                if case let .localPeer(rhsPeer, rhsAssociatedPeer, rhsIndex, rhsTheme, rhsStrings) = rhs, lhsPeer.isEqual(rhsPeer) && arePeersEqual(lhsAssociatedPeer, rhsAssociatedPeer) && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .globalPeer(lhsPeer, lhsIndex, lhsTheme, lhsStrings):
                if case let .globalPeer(rhsPeer, rhsIndex, rhsTheme, rhsStrings) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .message(lhsMessage, lhsPresentationData):
                if case let .message(rhsMessage, rhsPresentationData) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(_, _, lhsIndex, _, _):
                if case let .localPeer(_, _, rhsIndex, _, _) = rhs {
                    return lhsIndex <= rhsIndex
                } else {
                    return true
                }
            case let .globalPeer(_, lhsIndex, _, _):
                switch rhs {
                    case .localPeer:
                        return false
                    case let .globalPeer(_, rhsIndex, _, _):
                        return lhsIndex <= rhsIndex
                    case .message:
                        return true
                }
            case let .message(lhsMessage, _):
                if case let .message(rhsMessage, _) = rhs {
                    return MessageIndex(lhsMessage) < MessageIndex(rhsMessage)
                } else {
                    return false
                }
        }
    }
    
    func item(account: Account, enableHeaders: Bool, onlyWriteable: Bool, interaction: ChatListNodeInteraction) -> ListViewItem {
        switch self {
            case let .localPeer(peer, associatedPeer, _, theme, strings):
                let primaryPeer: Peer
                var chatPeer: Peer?
                if let associatedPeer = associatedPeer {
                    primaryPeer = associatedPeer
                    chatPeer = peer
                } else {
                    primaryPeer = peer
                    chatPeer = peer
                }
                
                var enabled = true
                if onlyWriteable {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer)
                    } else {
                        enabled = false
                    }
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, account: account, peerMode: .generalSearch, peer: primaryPeer, chatPeer: chatPeer, status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: ChatListSearchItemHeader(type: .localPeers, theme: theme, strings: strings, actionTitle: nil, action: nil), action: { _ in
                    interaction.peerSelected(peer)
                })
            case let .globalPeer(peer, _, theme, strings):
                var enabled = true
                if onlyWriteable {
                    enabled = canSendMessagesToPeer(peer.peer)
                }
                
                var suffixString = ""
                if let subscribers = peer.subscribers, subscribers != 0 {
                    if peer.peer is TelegramUser {
                        suffixString = ", \(strings.Conversation_StatusSubscribers(subscribers))"
                    } else if let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info {
                        suffixString = ", \(strings.Conversation_StatusSubscribers(subscribers))"
                    } else {
                        suffixString = ", \(strings.Conversation_StatusMembers(subscribers))"
                    }
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, account: account, peerMode: .generalSearch, peer: peer.peer, chatPeer: peer.peer, status: .addressName(suffixString), enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: ChatListSearchItemHeader(type: .globalPeers, theme: theme, strings: strings, actionTitle: nil, action: nil), action: { _ in
                    interaction.peerSelected(peer.peer)
                })
            case let .message(message, presentationData):
                return ChatListItem(presentationData: presentationData, account: account, peerGroupId: nil, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(message)), content: .peer(message: message, peer: RenderedPeer(message: message), combinedReadState: nil, notificationSettings: nil, summaryInfo: ChatListMessageTagSummaryInfo(), embeddedState: nil, inputActivities: nil), editing: false, hasActiveRevealControls: false, header: enableHeaders ? ChatListSearchItemHeader(type: .messages, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil) : nil, enableContextActions: false, interaction: interaction)
        }
    }
}

private struct ChatListSearchContainerRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

struct ChatListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let displayingResults: Bool
}

private func chatListSearchContainerPreparedRecentTransition(from fromEntries: [ChatListRecentEntry], to toEntries: [ChatListRecentEntry], account: Account, onlyWriteable: Bool, peerSelected: @escaping (Peer) -> Void, peerLongTapped: @escaping (Peer) -> Void, clearRecentlySearchedPeers: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, deletePeer: @escaping (PeerId) -> Void) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, onlyWriteable: onlyWriteable, peerSelected: peerSelected, peerLongTapped: peerLongTapped, clearRecentlySearchedPeers: clearRecentlySearchedPeers, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, onlyWriteable: onlyWriteable, peerSelected: peerSelected, peerLongTapped: peerLongTapped, clearRecentlySearchedPeers: clearRecentlySearchedPeers, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], displayingResults: Bool, account: Account, enableHeaders: Bool, onlyWriteable: Bool, interaction: ChatListNodeInteraction) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, enableHeaders: enableHeaders, onlyWriteable: onlyWriteable, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, enableHeaders: enableHeaders, onlyWriteable: onlyWriteable, interaction: interaction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults)
}

private struct ChatListSearchContainerNodeState: Equatable {
    let peerIdWithRevealedOptions: PeerId?
    
    init(peerIdWithRevealedOptions: PeerId? = nil) {
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
    }
    
    static func ==(lhs: ChatListSearchContainerNodeState, rhs: ChatListSearchContainerNodeState) -> Bool {
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        return true
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChatListSearchContainerNodeState {
        return ChatListSearchContainerNodeState(peerIdWithRevealedOptions: peerIdWithRevealedOptions)
    }
}

final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openMessage: (Peer, MessageId) -> Void
    
    private let recentListNode: ListView
    private let listNode: ListView
    
    private var enqueuedRecentTransitions: [(ChatListSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var validLayout: ContainerViewLayout?
    
    private let recentDisposable = MetaDisposable()
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<ChatListPresentationData>
    private var stateValue = ChatListSearchContainerNodeState()
    private let statePromise: ValuePromise<ChatListSearchContainerNodeState>
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    init(account: Account, onlyWriteable: Bool, groupId: PeerGroupId?, openPeer: @escaping (Peer) -> Void, openRecentPeerOptions: @escaping (Peer) -> Void, openMessage: @escaping (Peer, MessageId) -> Void) {
        self.account = account
        self.openMessage = openMessage
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, timeFormat: self.presentationData.timeFormat))
        
        self.recentListNode = ListView()
        self.listNode = ListView()
        
        self.statePromise = ValuePromise(self.stateValue, ignoreRepeated: true)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
    
        let presentationDataPromise = self.presentationDataPromise
        let foundItems = searchQuery.get()
            |> mapToSignal { query -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
                if let query = query, !query.isEmpty {
                    let accountPeer = account.postbox.loadedPeerWithId(account.peerId) |> take(1)
                    let foundLocalPeers = account.postbox.searchPeers(query: query.lowercased(), groupId: groupId)
                    let foundRemotePeers: Signal<([FoundPeer], [FoundPeer], Bool), NoError>
                    if groupId == nil {
                        foundRemotePeers = (.single(([], [], true)) |> then(searchPeers(account: account, query: query) |> map { ($0.0, $0.1, false) }
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())))
                    } else {
                        foundRemotePeers = .single(([], [], false))
                    }
                    let location: SearchMessagesLocation
                    if let groupId = groupId {
                        location = .group(groupId)
                    } else {
                        location = .general
                    }
                    let foundRemoteMessages: Signal<([Message], Bool), NoError> = .single(([], true)) |> then(searchMessages(account: account, location: location, query: query)
                        |> map { ($0, false) }
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                    
                    return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationDataPromise.get())
                        |> map { accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationData -> ([ChatListSearchEntry], Bool)? in
                            var entries: [ChatListSearchEntry] = []
                            let isSearching = foundRemotePeers.2 || foundRemoteMessages.1
                            var index = 0
                            
                            var existingPeerIds = Set<PeerId>()
                            
                            if presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(query.lowercased()) {
                                if !existingPeerIds.contains(accountPeer.id) {
                                    existingPeerIds.insert(accountPeer.id)
                                    entries.append(.localPeer(accountPeer, nil, index, presentationData.theme, presentationData.strings))
                                    index += 1
                                }
                            }
                            
                            for renderedPeer in foundLocalPeers {
                                if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != account.peerId {
                                    if !existingPeerIds.contains(peer.id) {
                                        existingPeerIds.insert(peer.id)
                                        var associatedPeer: Peer?
                                        if let associatedPeerId = peer.associatedPeerId {
                                            associatedPeer = renderedPeer.peers[associatedPeerId]
                                        }
                                        entries.append(.localPeer(peer, associatedPeer, index, presentationData.theme, presentationData.strings))
                                        index += 1
                                    }
                                }
                            }
                            
                            for peer in foundRemotePeers.0 {
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    entries.append(.localPeer(peer.peer, nil, index, presentationData.theme, presentationData.strings))
                                    index += 1
                                }
                            }

                            index = 0
                            for peer in foundRemotePeers.1 {
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    entries.append(.globalPeer(peer, index, presentationData.theme, presentationData.strings))
                                    index += 1
                                }
                            }
                            
                            index = 0
                            for message in foundRemoteMessages.0 {
                                entries.append(.message(message, presentationData))
                                index += 1
                            }
                            
                            return (entries, isSearching)
                        }
                } else {
                    return .single(nil)
                }
            }
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { [weak self] peer in
            openPeer(peer)
            let _ = addRecentlySearchedPeer(postbox: account.postbox, peerId: peer.id).start()
            self?.listNode.clearHighlightAnimated(true)
        }, messageSelected: { [weak self] message in
            if let peer = message.peers[message.id.peerId] {
                openMessage(peer, message.id)
            }
            self?.listNode.clearHighlightAnimated(true)
        }, groupSelected: { _ in 
        }, setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                        return state.withUpdatedPeerIdWithRevealedOptions(peerId)
                    } else {
                        return state
                    }
                }
            }
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _ in
        }, updatePeerGrouping: { _, _ in
        })
        
        let previousRecentItems = Atomic<[ChatListRecentEntry]?>(value: nil)
        let recentItemsTransition = combineLatest(recentlySearchedPeers(postbox: account.postbox), presentationDataPromise.get(), self.statePromise.get())
            |> mapToSignal { [weak self] peers, presentationData, state -> Signal<(ChatListSearchContainerRecentTransition, Bool), NoError> in
                var entries: [ChatListRecentEntry] = []
                if groupId == nil {
                    entries.append(.topPeers([], presentationData.theme, presentationData.strings))
                }
                var peerIds = Set<PeerId>()
                var index = 0
                loop: for renderedPeer in peers {
                    if let peer = renderedPeer.peers[renderedPeer.peerId] {
                        if peerIds.contains(peer.id) {
                            continue loop
                        }
                        peerIds.insert(peer.id)
                        
                        var associatedPeer: Peer?
                        if let associatedPeerId = peer.associatedPeerId {
                            associatedPeer = renderedPeer.peers[associatedPeerId]
                        }
                        entries.append(.peer(index: index, peer: peer, associatedPeer: associatedPeer, presentationData.theme, presentationData.strings, state.peerIdWithRevealedOptions == peer.id))
                        index += 1
                    }
                }
                let previousEntries = previousRecentItems.swap(entries)
                
                let transition = chatListSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, account: account, onlyWriteable: onlyWriteable, peerSelected: { peer in
                    self?.recentListNode.clearHighlightAnimated(true)
                    openPeer(peer)
                }, peerLongTapped: { peer in
                    openRecentPeerOptions(peer)
                }, clearRecentlySearchedPeers: {
                    self?.clearRecentSearch()
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    interaction.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, deletePeer: { peerId in
                    if let strongSelf = self {
                        let _ = removeRecentlySearchedPeer(postbox: strongSelf.account.postbox, peerId: peerId).start()
                    }
                })
                return .single((transition, previousEntries == nil))
        }
        
        self.recentDisposable.set((recentItemsTransition |> deliverOnMainQueue).start(next: { [weak self] (transition, firstTime) in
            if let strongSelf = self {
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.searchDisposable.set((foundItems
            |> deliverOnMainQueue).start(next: { [weak self] entriesAndFlags in
                if let strongSelf = self {
                    strongSelf._isSearching.set(entriesAndFlags?.1 ?? false)
                    
                    let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                    
                    let firstTime = previousEntries == nil
                    let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entriesAndFlags?.0 ?? [], displayingResults: entriesAndFlags?.0 != nil, account: account, enableHeaders: true, onlyWriteable: onlyWriteable, interaction: interaction)
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                }
            }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme {
                        strongSelf.updateTheme(theme: presentationData.theme)
                    }
                }
            })
        
        self.recentListNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.recentDisposable.dispose()
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = theme.chatList.backgroundColor
    }
    
    private func updateState(_ f: (ChatListSearchContainerNodeState) -> ChatListSearchContainerNodeState) {
        let state = f(self.stateValue)
        if state != self.stateValue {
            self.stateValue = state
            self.statePromise.set(state)
        }
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueRecentTransition(_ transition: ChatListSearchContainerRecentTransition, firstTime: Bool) {
        enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    private func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if displayingResults != !strongSelf.listNode.isHidden {
                        strongSelf.listNode.isHidden = !displayingResults
                        strongSelf.recentListNode.isHidden = displayingResults
                    }
                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout != nil
        self.validLayout = layout
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                case .easeInOut:
                    break
                case .spring:
                    curve = 7
                }
        }
        
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, Any)? {
        var selectedItemNode: ASDisplayNode?
        if !self.recentListNode.isHidden {
            let adjustedLocation = self.convert(location, to: self.recentListNode)
            self.recentListNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        } else {
            let adjustedLocation = self.convert(location, to: self.listNode)
            self.listNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        }
        if let selectedItemNode = selectedItemNode as? ChatListRecentPeersListItemNode {
            if let result = selectedItemNode.viewAndPeerAtPoint(self.convert(location, to: selectedItemNode)) {
                return (result.0, result.1)
            }
        } else if let selectedItemNode = selectedItemNode as? ContactsPeerItemNode, let peer = selectedItemNode.peer {
            return (selectedItemNode.view, peer.id)
        } else if let selectedItemNode = selectedItemNode as? ChatListItemNode, let item = selectedItemNode.item {
            switch item.content {
                case let .peer(message, peer, _, _, _, _, _):
                    return (selectedItemNode.view, message?.id ?? peer.peerId)
                case let .groupReference(groupId, _, _, _):
                    return (selectedItemNode.view, groupId)
            }
        }
        return nil
    }
    
    private func clearRecentSearch() {
        let _ = (clearRecentlySearchedPeers(postbox: self.account.postbox) |> deliverOnMainQueue).start()
    }
    
    func removePeerFromTopPeers(_ peerId: PeerId) {
        self.recentListNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListRecentPeersListItemNode {
                itemNode.removePeer(peerId)
            }
        }
    }
}
