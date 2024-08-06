import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TemporaryCachedPeerDataManager
import Postbox

public extension ShareWithPeersScreen {
    final class State {
        let sendAsPeers: [EnginePeer]
        let peers: [EnginePeer]
        let peersMap: [EnginePeer.Id: EnginePeer]
        let savedSelectedPeers: [Stories.Item.Privacy.Base: [EnginePeer.Id]]
        let presences: [EnginePeer.Id: EnginePeer.Presence]
        let invitedAt: [EnginePeer.Id: Int32]
        let participants: [EnginePeer.Id: Int]
        let closeFriendsPeers: [EnginePeer]
        let grayListPeers: [EnginePeer]
        
        fileprivate init(
            sendAsPeers: [EnginePeer] = [],
            peers: [EnginePeer],
            peersMap: [EnginePeer.Id: EnginePeer] = [:],
            savedSelectedPeers: [Stories.Item.Privacy.Base: [EnginePeer.Id]] = [:],
            presences: [EnginePeer.Id: EnginePeer.Presence] = [:],
            invitedAt: [EnginePeer.Id: Int32] = [:],
            participants: [EnginePeer.Id: Int] = [:],
            closeFriendsPeers: [EnginePeer] = [],
            grayListPeers: [EnginePeer] = []
        ) {
            self.sendAsPeers = sendAsPeers
            self.peers = peers
            self.peersMap = peersMap
            self.savedSelectedPeers = savedSelectedPeers
            self.presences = presences
            self.invitedAt = invitedAt
            self.participants = participants
            self.closeFriendsPeers = closeFriendsPeers
            self.grayListPeers = grayListPeers
        }
    }
    
    final class StateContext {
        public enum Subject: Equatable {
            case peers(peers: [EnginePeer], peerId: EnginePeer.Id?)
            case stories(editing: Bool)
            case chats(blocked: Bool)
            case contacts(base: EngineStoryPrivacy.Base)
            case contactsSearch(query: String, onlyContacts: Bool)
            case members(isGroup: Bool, peerId: EnginePeer.Id, searchQuery: String?)
            case channels(isGroup: Bool, exclude: Set<EnginePeer.Id>, searchQuery: String?)
        }
        
        var stateValue: State?
        
        public let subject: Subject
        public let editing: Bool
        public private(set) var initialPeerIds: Set<EnginePeer.Id> = Set()
        let blockedPeersContext: BlockedPeersContext?
        
        private var stateDisposable: Disposable?
        private let stateSubject = Promise<State>()
        public var state: Signal<State, NoError> {
            return self.stateSubject.get()
        }
        private var listControl: PeerChannelMemberCategoryControl?
        
        private let readySubject = ValuePromise<Bool>(false, ignoreRepeated: true)
        public var ready: Signal<Bool, NoError> {
            return self.readySubject.get()
        }
        
        public init(
            context: AccountContext,
            subject: Subject = .chats(blocked: false),
            editing: Bool = false,
            initialSelectedPeers: [EngineStoryPrivacy.Base: [EnginePeer.Id]] = [:],
            initialPeerIds: Set<EnginePeer.Id> = Set(),
            closeFriends: Signal<[EnginePeer], NoError> = .single([]),
            adminedChannels: Signal<[EnginePeer], NoError> = .single([]),
            blockedPeersContext: BlockedPeersContext? = nil
        ) {
            self.subject = subject
            self.editing = editing
            self.initialPeerIds = initialPeerIds
            self.blockedPeersContext = blockedPeersContext
            
            let grayListPeers: Signal<[EnginePeer], NoError>
            if let blockedPeersContext {
                grayListPeers = blockedPeersContext.state
                |> map { state -> [EnginePeer] in
                    return state.peers.compactMap { $0.peer.flatMap(EnginePeer.init) }
                }
            } else {
                grayListPeers = .single([])
            }
             
            switch subject {
            case let .peers(peers, _):
                self.stateDisposable = (.single(peers)
                |> mapToSignal { peers -> Signal<([EnginePeer], [EnginePeer.Id: Optional<Int>]), NoError> in
                    return context.engine.data.subscribe(
                        EngineDataMap(peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                    )
                    |> map { participantCountMap -> ([EnginePeer], [EnginePeer.Id: Optional<Int>]) in
                        return (peers, participantCountMap)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] peers, participantCounts in
                    guard let self else {
                        return
                    }
                    var participants: [EnginePeer.Id: Int] = [:]
                    for (key, value) in participantCounts {
                        if let value {
                            participants[key] = value
                        }
                    }
                    
                    let state = State(
                        sendAsPeers: peers,
                        peers: [],
                        participants: participants
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))

                    self.readySubject.set(true)
                })
            case .stories:
                let savedEveryoneExceptionPeers = peersListStoredState(engine: context.engine, base: .everyone)
                let savedContactsExceptionPeers = peersListStoredState(engine: context.engine, base: .contacts)
                let savedSelectedPeers = peersListStoredState(engine: context.engine, base: .nobody)
                
                let savedPeers = combineLatest(
                    savedEveryoneExceptionPeers,
                    savedContactsExceptionPeers,
                    savedSelectedPeers
                ) |> mapToSignal { everyone, contacts, selected -> Signal<([EnginePeer.Id: EnginePeer], [EnginePeer.Id], [EnginePeer.Id], [EnginePeer.Id]), NoError> in
                    var everyone = everyone
                    if let initialPeerIds = initialSelectedPeers[.everyone] {
                        everyone = initialPeerIds
                    }
                    var everyonePeerSignals: [Signal<EnginePeer?, NoError>] = []
                    if everyone.count < 3 {
                        for peerId in everyone {
                            everyonePeerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                        }
                    }
                    
                    var contacts = contacts
                    if let initialPeerIds = initialSelectedPeers[.contacts] {
                        contacts = initialPeerIds
                    }
                    var contactsPeerSignals: [Signal<EnginePeer?, NoError>] = []
                    if contacts.count < 3 {
                        for peerId in contacts {
                            contactsPeerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                        }
                    }
                    
                    var selected = selected
                    if let initialPeerIds = initialSelectedPeers[.nobody] {
                        selected = initialPeerIds
                    }
                    var selectedPeerSignals: [Signal<EnginePeer?, NoError>] = []
                    if selected.count < 3 {
                        for peerId in selected {
                            selectedPeerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                        }
                    }
                    return combineLatest(
                        combineLatest(everyonePeerSignals),
                        combineLatest(contactsPeerSignals),
                        combineLatest(selectedPeerSignals)
                    ) |> map { everyonePeers, contactsPeers, selectedPeers -> ([EnginePeer.Id: EnginePeer], [EnginePeer.Id], [EnginePeer.Id], [EnginePeer.Id]) in
                        var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                        for peer in everyonePeers {
                            if let peer {
                                peersMap[peer.id] = peer
                            }
                        }
                        for peer in contactsPeers {
                            if let peer {
                                peersMap[peer.id] = peer
                            }
                        }
                        for peer in selectedPeers {
                            if let peer {
                                peersMap[peer.id] = peer
                            }
                        }
                        return (
                            peersMap,
                            everyone,
                            contacts,
                            selected
                        )
                    }
                }
                
                let adminedChannelsWithParticipants = adminedChannels
                |> mapToSignal { peers -> Signal<([EnginePeer], [EnginePeer.Id: Optional<Int>]), NoError> in
                    return context.engine.data.subscribe(
                        EngineDataMap(peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                    )
                    |> map { participantCountMap -> ([EnginePeer], [EnginePeer.Id: Optional<Int>]) in
                        return (peers, participantCountMap)
                    }
                }
            
                self.stateDisposable = combineLatest(
                    queue: Queue.mainQueue(),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
                    adminedChannelsWithParticipants,
                    savedPeers,
                    closeFriends,
                    grayListPeers
                )
                .start(next: { [weak self] accountPeer, adminedChannelsWithParticipants, savedPeers, closeFriends, grayListPeers in
                    guard let self else {
                        return
                    }
                    
                    let (adminedChannels, participantCounts) = adminedChannelsWithParticipants
                    var participants: [EnginePeer.Id: Int] = [:]
                    for (key, value) in participantCounts {
                        if let value {
                            participants[key] = value
                        }
                    }
                    
                    var sendAsPeers: [EnginePeer] = []
                    if let accountPeer {
                        sendAsPeers.append(accountPeer)
                    }
                    for channel in adminedChannels {
                        if case let .channel(channel) = channel, channel.hasPermission(.postStories) {
                            if !sendAsPeers.contains(where: { $0.id == channel.id }) {
                                sendAsPeers.append(contentsOf: adminedChannels)
                            }
                        }
                    }

                    let (peersMap, everyonePeers, contactsPeers, selectedPeers) = savedPeers
                    var savedSelectedPeers: [Stories.Item.Privacy.Base: [EnginePeer.Id]] = [:]
                    savedSelectedPeers[.everyone] = everyonePeers
                    savedSelectedPeers[.contacts] = contactsPeers
                    savedSelectedPeers[.nobody] = selectedPeers
                    let state = State(
                        sendAsPeers: sendAsPeers,
                        peers: [],
                        peersMap: peersMap,
                        savedSelectedPeers: savedSelectedPeers,
                        participants: participants,
                        closeFriendsPeers: closeFriends,
                        grayListPeers: grayListPeers
                    )
                    
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case let .chats(isGrayList):
                self.stateDisposable = (combineLatest(
                    context.engine.messages.chatList(group: .root, count: 200) |> take(1),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)),
                    context.engine.data.get(EngineDataMap(Array(self.initialPeerIds).map(TelegramEngine.EngineData.Item.Peer.Peer.init))),
                    grayListPeers
                )
                |> mapToSignal { chatList, contacts, initialPeers, grayListPeers -> Signal<(EngineChatList, EngineContactList, [EnginePeer.Id: Optional<EnginePeer>], [EnginePeer.Id: Optional<Int>], [EnginePeer]), NoError> in
                    return context.engine.data.subscribe(
                        EngineDataMap(chatList.items.map(\.renderedPeer.peerId).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                    )
                    |> map { participantCountMap -> (EngineChatList, EngineContactList, [EnginePeer.Id: Optional<EnginePeer>], [EnginePeer.Id: Optional<Int>], [EnginePeer]) in
                        return (chatList, contacts, initialPeers, participantCountMap, grayListPeers)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] chatList, contacts, initialPeers, participantCounts, grayListPeers in
                    guard let self else {
                        return
                    }
                    
                    var participants: [EnginePeer.Id: Int] = [:]
                    for (key, value) in participantCounts {
                        if let value {
                            participants[key] = value
                        }
                    }
                    
                    var grayListPeersIds = Set<EnginePeer.Id>()
                    for peer in grayListPeers {
                        grayListPeersIds.insert(peer.id)
                    }
                    
                    var existingIds = Set<EnginePeer.Id>()
                    var selectedPeers: [EnginePeer] = []
                    
                    if isGrayList {
                        self.initialPeerIds = Set(grayListPeers.map { $0.id })
                    }
                    
                    for item in chatList.items.reversed() {
                        if let peer = item.renderedPeer.peer {
                            if self.initialPeerIds.contains(peer.id) || isGrayList && grayListPeersIds.contains(peer.id) {
                                selectedPeers.append(peer)
                                existingIds.insert(peer.id)
                            }
                        }
                    }
                    
                    for peerId in self.initialPeerIds {
                        if !existingIds.contains(peerId), let maybePeer = initialPeers[peerId], let peer = maybePeer {
                            selectedPeers.append(peer)
                            existingIds.insert(peerId)
                        }
                    }
                    
                    if isGrayList {
                        for peer in grayListPeers {
                            if !existingIds.contains(peer.id) {
                                selectedPeers.append(peer)
                                existingIds.insert(peer.id)
                            }
                        }
                    }
                    
                    var presences: [EnginePeer.Id: EnginePeer.Presence] = [:]
                    for item in chatList.items {
                        presences[item.renderedPeer.peerId] = item.presence
                    }
                    
                    var peers: [EnginePeer] = []
                    peers = chatList.items.filter { peer in
                        if let peer = peer.renderedPeer.peer {
                            if case .secretChat = peer {
                                return false
                            }
                            if self.initialPeerIds.contains(peer.id) {
                                return false
                            }
                            if peer.id == context.account.peerId {
                                return false
                            }
                            if peer.isService || peer.isDeleted {
                                return false
                            }
                            if case let .user(user) = peer {
                                if user.botInfo != nil {
                                    return false
                                }
                            }
                            if case let .channel(channel) = peer {
                                if case .broadcast = channel.info {
                                    return false
                                }
                            }
                            return true
                        } else {
                            return false
                        }
                    }.reversed().compactMap { $0.renderedPeer.peer }
                    for peer in peers {
                        existingIds.insert(peer.id)
                    }
                    peers.insert(contentsOf: selectedPeers, at: 0)
                    
                    let state = State(
                        peers: peers,
                        presences: presences,
                        participants: participants,
                        grayListPeers: grayListPeers
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case let .contacts(base):
                self.stateDisposable = (context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)
                )
                |> deliverOnMainQueue).start(next: { [weak self] contactList in
                    guard let self else {
                        return
                    }
                    
                    var selectedPeers: [EnginePeer] = []
                    if case .closeFriends = base {
                        for peer in contactList.peers {
                            if case let .user(user) = peer, user.flags.contains(.isCloseFriend) {
                                selectedPeers.append(peer)
                            }
                        }
                        self.initialPeerIds = Set(selectedPeers.map { $0.id })
                    } else {
                        for peer in contactList.peers {
                            if case let .user(user) = peer, initialPeerIds.contains(user.id), !user.isDeleted {
                                selectedPeers.append(peer)
                            }
                        }
                        self.initialPeerIds = initialPeerIds
                    }
                    selectedPeers = selectedPeers.sorted(by: { lhs, rhs in
                        let result = lhs.indexName.isLessThan(other: rhs.indexName, ordering: .firstLast)
                        if result == .orderedSame {
                            return lhs.id < rhs.id
                        } else {
                            return result == .orderedAscending
                        }
                    })
                    
                    var peers: [EnginePeer] = []
                    peers = contactList.peers.filter { !self.initialPeerIds.contains($0.id) && $0.id != context.account.peerId && !$0.isDeleted }.sorted(by: { lhs, rhs in
                        let result = lhs.indexName.isLessThan(other: rhs.indexName, ordering: .firstLast)
                        if result == .orderedSame {
                            return lhs.id < rhs.id
                        } else {
                            return result == .orderedAscending
                        }
                    })
                    peers.insert(contentsOf: selectedPeers, at: 0)
                    
                    let state = State(
                        peers: peers,
                        presences: contactList.presences
                    )
                                        
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case let .contactsSearch(query, onlyContacts):
                let signal: Signal<([EngineRenderedPeer], [EnginePeer.Id: Optional<EnginePeer.Presence>], [EnginePeer.Id: Optional<Int>]), NoError>
                if onlyContacts {
                    signal = combineLatest(
                        context.engine.contacts.searchLocalPeers(query: query),
                        context.engine.contacts.searchContacts(query: query)
                    )
                    |> map { peers, contacts in
                        let contactIds = Set(contacts.0.map { $0.id })
                        return (peers.filter { contactIds.contains($0.peerId) }, [:], [:])
                    }
                } else {
                    signal = context.engine.contacts.searchLocalPeers(query: query)
                    |> mapToSignal { peers in
                        return context.engine.data.subscribe(
                            EngineDataMap(peers.map(\.peerId).map(TelegramEngine.EngineData.Item.Peer.Presence.init)),
                            EngineDataMap(peers.map(\.peerId).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                        )
                        |> map { presenceMap, participantCountMap -> ([EngineRenderedPeer], [EnginePeer.Id: Optional<EnginePeer.Presence>], [EnginePeer.Id: Optional<Int>]) in
                            return (peers, presenceMap, participantCountMap)
                        }
                    }
                }
                self.stateDisposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self] peers, presenceMap, participantCounts in
                    guard let self else {
                        return
                    }
                    
                    var presences: [EnginePeer.Id: EnginePeer.Presence] = [:]
                    for (key, value) in presenceMap {
                        if let value {
                            presences[key] = value
                        }
                    }
                    
                    var participants: [EnginePeer.Id: Int] = [:]
                    for (key, value) in participantCounts {
                        if let value {
                            participants[key] = value
                        }
                    }
                                                            
                    let state = State(
                        peers: peers.compactMap { $0.peer }.filter { peer in
                            if case .secretChat = peer {
                                return false
                            } else if case let .user(user) = peer {
                                if user.id == context.account.peerId {
                                    return false
                                } else if user.botInfo != nil {
                                    return false
                                } else if peer.isService {
                                    return false
                                } else if user.isDeleted {
                                    return false
                                } else {
                                    return true
                                }
                            } else if case let .channel(channel) = peer {
                                if case .broadcast = channel.info {
                                    return false
                                }
                                return true
                            } else {
                                return true
                            }
                        },
                        presences: presences,
                        participants: participants
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case let .members(_, peerId, searchQuery):
                let membersState = Promise<ChannelMemberListState>()
                let contactsState = Promise<ChannelMemberListState>()

                let disposableAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)
                disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: searchQuery, updated: { state in
                    membersState.set(.single(state))
                })
                
                let contactsDisposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.contacts(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: searchQuery, updated: { state in
                    contactsState.set(.single(state))
                })
                
                let dataDisposable = combineLatest(
                    queue: Queue.mainQueue(),
                    contactsState.get(),
                    membersState.get()
                ).startStrict(next: { [weak self] contactsState, memberState in
                    guard let self else {
                        return
                    }
                    var peers: [EnginePeer] = []
                    var invitedAt: [EnginePeer.Id: Int32] = [:]
                    
                    var existingPeersIds = Set<EnginePeer.Id>()
                    for participant in contactsState.list {
                        if participant.peer.isDeleted || existingPeersIds.contains(participant.peer.id) || participant.participant.adminInfo != nil {
                            continue
                        }
                        
                        if case let .member(_, date, _, _, _, _) = participant.participant {
                            invitedAt[participant.peer.id] = date
                        } else {
                            continue
                        }
                        
                        peers.append(EnginePeer(participant.peer))
                        existingPeersIds.insert(participant.peer.id)
                    }
                    
                    for participant in memberState.list {
                        if participant.peer.isDeleted || existingPeersIds.contains(participant.peer.id) || participant.participant.adminInfo != nil {
                            continue
                        }
                        if let user = participant.peer as? TelegramUser, user.botInfo != nil {
                            continue
                        }
                        
                        if case let .member(_, date, _, _, _, _) = participant.participant {
                            invitedAt[participant.peer.id] = date
                        } else {
                            continue
                        }
                        
                        peers.append(EnginePeer(participant.peer))
                    }
                    
                    let state = State(
                        peers: peers,
                        invitedAt: invitedAt
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
                
                let combinedDisposable = DisposableSet()
                combinedDisposable.add(contactsDisposableAndLoadMoreControl.0)
                combinedDisposable.add(disposableAndLoadMoreControl.0)
                combinedDisposable.add(dataDisposable)
                
                self.stateDisposable = combinedDisposable
                
                self.listControl = disposableAndLoadMoreControl.1
            case let .channels(_, excludePeerIds, searchQuery):
                self.stateDisposable = (combineLatest(
                    context.engine.messages.chatList(group: .root, count: 500) |> take(1),
                    searchQuery.flatMap { context.engine.contacts.searchLocalPeers(query: $0) } ?? .single([]),
                    context.engine.data.get(EngineDataMap(Array(self.initialPeerIds).map(TelegramEngine.EngineData.Item.Peer.Peer.init)))
                )
                |> mapToSignal { chatList, searchResults, initialPeers -> Signal<(EngineChatList, [EngineRenderedPeer], [EnginePeer.Id: Optional<EnginePeer>], [EnginePeer.Id: Optional<Int>]), NoError> in
                    var peerIds: [EnginePeer.Id] = []
                    peerIds.append(contentsOf: chatList.items.map(\.renderedPeer.peerId))
                    peerIds.append(contentsOf: searchResults.map(\.peerId))
                    peerIds.append(contentsOf: initialPeers.compactMap(\.value?.id))
                    return context.engine.data.subscribe(
                        EngineDataMap(chatList.items.map(\.renderedPeer.peerId).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                    )
                    |> map { participantCountMap -> (EngineChatList, [EngineRenderedPeer], [EnginePeer.Id: Optional<EnginePeer>], [EnginePeer.Id: Optional<Int>]) in
                        return (chatList, searchResults, initialPeers, participantCountMap)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] chatList, searchResults, initialPeers, participantCounts in
                    guard let self else {
                        return
                    }
                    
                    var participants: [EnginePeer.Id: Int] = [:]
                    for (key, value) in participantCounts {
                        if let value {
                            participants[key] = value
                        }
                    }
                    
                    var existingIds = Set<EnginePeer.Id>()
                    var selectedPeers: [EnginePeer] = []
                                                         
                    for item in chatList.items.reversed() {
                        if let peer = item.renderedPeer.peer {
                            if self.initialPeerIds.contains(peer.id) {
                                selectedPeers.append(peer)
                                existingIds.insert(peer.id)
                            }
                        }
                    }
                    
                    for peerId in self.initialPeerIds {
                        if !existingIds.contains(peerId), let maybePeer = initialPeers[peerId], let peer = maybePeer {
                            selectedPeers.append(peer)
                            existingIds.insert(peerId)
                        }
                    }
                    
                    for item in searchResults {
                        if let peer = item.peer, case .channel = peer {
                            selectedPeers.append(peer)
                            existingIds.insert(peer.id)
                        }
                    }
                 
                    let queryTokens = stringIndexTokens(searchQuery ?? "", transliteration: .combined)
                    func peerMatchesTokens(peer: EnginePeer, tokens: [ValueBoxKey]) -> Bool {
                        if matchStringIndexTokens(peer.indexName._asIndexName().indexTokens, with: queryTokens) {
                            return true
                        }
                        return false
                    }
                    
                    var peers: [EnginePeer] = []
                    peers = chatList.items.filter { peer in
                        if let peer = peer.renderedPeer.peer {
                            if existingIds.contains(peer.id) {
                                return false
                            }
                            if excludePeerIds.contains(peer.id) {
                                return false
                            }
                            if peer.isFake || peer.isScam {
                                return false
                            }
                            if let _ = searchQuery, !peerMatchesTokens(peer: peer, tokens: queryTokens) {
                                return false
                            }
                            if self.initialPeerIds.contains(peer.id) {
                                return false
                            }
                            if case .channel = peer {
                                return true
                            }
                            return false
                        } else {
                            return false
                        }
                    }.reversed().compactMap { $0.renderedPeer.peer }
                    for peer in peers {
                        existingIds.insert(peer.id)
                    }
                    peers.insert(contentsOf: selectedPeers, at: 0)
                    
                    let state = State(
                        peers: peers,
                        participants: participants
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            }
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
    }
}

final class PeersListStoredState: Codable {
    private enum CodingKeys: String, CodingKey {
        case peerIds
    }
    
    public let peerIds: [EnginePeer.Id]
    
    public init(peerIds: [EnginePeer.Id]) {
        self.peerIds = peerIds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.peerIds = try container.decode([Int64].self, forKey: .peerIds).map { EnginePeer.Id($0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: .peerIds)
    }
}

private func peersListStoredState(engine: TelegramEngine, base: Stories.Item.Privacy.Base) -> Signal<[EnginePeer.Id], NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: base.rawValue)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.shareWithPeersState, id: key))
    |> map { entry -> [EnginePeer.Id] in
        return entry?.get(PeersListStoredState.self)?.peerIds ?? []
    }
}

func updatePeersListStoredState(engine: TelegramEngine, base: Stories.Item.Privacy.Base, peerIds: [EnginePeer.Id]) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: base.rawValue)
    
    let state = PeersListStoredState(peerIds: peerIds)
    return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.shareWithPeersState, id: key, item: state)
}
