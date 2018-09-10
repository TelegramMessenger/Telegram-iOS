import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum ChannelMembersSearchMode {
    case searchMembers
    case searchAdmins
    case searchBanned
    case banAndPromoteActions
    case inviteActions
}

private enum ChannelMembersSearchSection {
    case none
    case members
    case contacts
    case global
    
    var chatListHeaderType: ChatListSearchItemHeaderType? {
        switch self {
            case .none:
                return nil
            case .members:
                return .members
            case .contacts:
                return .contacts
            case .global:
                return .globalPeers
        }
    }
}

private enum ChannelMembersSearchContent: Equatable {
    case peer(Peer)
    case participant(RenderedChannelParticipant, String?, Bool)
    
    static func ==(lhs: ChannelMembersSearchContent, rhs: ChannelMembersSearchContent) -> Bool {
        switch lhs {
            case let .peer(lhsPeer):
                if case let .peer(rhsPeer) = rhs {
                    return lhsPeer.isEqual(rhsPeer)
                } else {
                    return false
                }
            case let .participant(participant, label, enabled):
                if case .participant(participant, label, enabled) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .peer(peer):
                return peer.id
            case let .participant(participant, _, _):
                return participant.peer.id
        }
    }
}

private final class ChannelMembersSearchEntry: Comparable, Identifiable {
    let index: Int
    let content: ChannelMembersSearchContent
    let section: ChannelMembersSearchSection
    
    init(index: Int, content: ChannelMembersSearchContent, section: ChannelMembersSearchSection) {
        self.index = index
        self.content = content
        self.section = section
    }
    
    var stableId: PeerId {
        return self.content.peerId
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.content == rhs.content && lhs.section == rhs.section
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, peerSelected: @escaping (Peer, RenderedChannelParticipant?) -> Void) -> ListViewItem {
        switch self.content {
            case let .peer(peer):
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .peer, peer: .peer(peer: peer, chatPeer: peer), status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: theme, strings: strings, actionTitle: nil, action: nil) }), action: { _ in
                    peerSelected(peer, nil)
                })
            case let .participant(participant, label, enabled):
                let status: ContactsPeerItemStatus
                if let label = label {
                    status = .custom(label)
                } else {
                    status = .none
                }
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .peer, peer: .peer(peer: participant.peer, chatPeer: participant.peer), status: status, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: theme, strings: strings, actionTitle: nil, action: nil) }), action: { _ in
                    peerSelected(participant.peer, participant)
                })
        }
    }
}
struct ChannelMembersSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func channelMembersSearchContainerPreparedRecentTransition(from fromEntries: [ChannelMembersSearchEntry], to toEntries: [ChannelMembersSearchEntry], isSearching: Bool, account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, peerSelected: @escaping (Peer, RenderedChannelParticipant?) -> Void) -> ChannelMembersSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, peerSelected: peerSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, peerSelected: peerSelected), directionHint: nil) }
    
    return ChannelMembersSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

final class ChannelMembersSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    private let mode: ChannelMembersSearchMode
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var enqueuedTransitions: [(ChannelMembersSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder)>
    
    
    init(account: Account, peerId: PeerId, mode: ChannelMembersSearchMode, filters: [ChannelMembersSearchFilter], openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void, updateActivity: @escaping(Bool)->Void) {
        self.account = account
        self.openPeer = openPeer
        self.mode = mode
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings, self.presentationData.nameSortOrder, self.presentationData.nameDisplayOrder))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        self.listNode = ListView()
        
        super.init()
        
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        let foundItems = searchQuery.get()
            |> mapToSignal { query -> Signal<[ChannelMembersSearchEntry]?, NoError> in
                updateActivity(true)
                if let query = query, !query.isEmpty {
                    let foundGroupMembers: Signal<[RenderedChannelParticipant], NoError>
                    let foundMembers: Signal<[RenderedChannelParticipant], NoError>
                    
                    switch mode {
                        case .searchMembers, .banAndPromoteActions:
                            foundGroupMembers = Signal { subscriber in
                                let (disposable, listControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: account.postbox, network: account.network, peerId: peerId, searchQuery: query, updated: { state in
                                    if case .ready = state.loadingState {
                                        subscriber.putNext(state.list)
                                        subscriber.putCompletion()
                                    }
                                })
                                return disposable
                            } |> runOn(Queue.mainQueue())
                            foundMembers = .single([])
                        case .inviteActions:
                            foundGroupMembers = .single([])
                            foundMembers = channelMembers(postbox: account.postbox, network: account.network, peerId: peerId, category: .recent(.search(query)))
                            |> map { $0 ?? [] }
                    case .searchAdmins:
                        foundGroupMembers = Signal { subscriber in
                            let (disposable, listControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.admins(postbox: account.postbox, network: account.network, peerId: peerId, searchQuery: query, updated: { state in
                                if case .ready = state.loadingState {
                                    subscriber.putNext(state.list)
                                    subscriber.putCompletion()
                                }
                            })
                            return disposable
                            } |> runOn(Queue.mainQueue())
                        foundMembers = .single([])
                    case .searchBanned:
                        foundGroupMembers = Signal { subscriber in
                            let (disposable, listControl) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.restrictedAndBanned(postbox: account.postbox, network: account.network, peerId: peerId, searchQuery: query, updated: { state in
                                if case .ready = state.loadingState {
                                    subscriber.putNext(state.list)
                                    subscriber.putCompletion()
                                }
                            })
                            return disposable
                            } |> runOn(Queue.mainQueue())
                        foundMembers = .single([])
                    }
                    
                    let foundContacts: Signal<[Peer], NoError>
                    let foundRemotePeers: Signal<([FoundPeer], [FoundPeer]), NoError>
                    switch mode {
                        case .inviteActions, .banAndPromoteActions:
                            foundContacts = account.postbox.searchContacts(query: query.lowercased())
                            foundRemotePeers = .single(([], [])) |> then(searchPeers(account: account, query: query)
                            |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                        case .searchMembers, .searchBanned, .searchAdmins:
                            foundContacts = .single([])
                            foundRemotePeers = .single(([], []))
                    }
                    
                    return combineLatest(foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, themeAndStringsPromise.get())
                        |> map { foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, themeAndStrings -> [ChannelMembersSearchEntry]? in
                            var entries: [ChannelMembersSearchEntry] = []
                            
                            var existingPeerIds = Set<PeerId>()
                            for filter in filters {
                                switch filter {
                                case let .exclude(ids):
                                    existingPeerIds = existingPeerIds.union(ids)
                                case .disable:
                                    break
                                }
                            }
                            switch mode {
                                case .inviteActions, .banAndPromoteActions:
                                    existingPeerIds.insert(account.peerId)
                                case .searchMembers, .searchAdmins, .searchBanned:
                                    break
                            }
                            
                            var index = 0
                            
                            for participant in foundGroupMembers {
                                if !existingPeerIds.contains(participant.peer.id) {
                                    existingPeerIds.insert(participant.peer.id)
                                    let section: ChannelMembersSearchSection
                                    switch mode {
                                        case .inviteActions, .banAndPromoteActions:
                                            section = .members
                                        case .searchMembers, .searchBanned, .searchAdmins:
                                            section = .none
                                    }
                                    
                                    var label: String?
                                    var enabled = true
                                    if case .banAndPromoteActions = mode {
                                        if case .creator = participant.participant {
                                            label = themeAndStrings.1.Channel_Management_LabelCreator
                                            enabled = false
                                        }
                                    }
                                    switch mode {
                                    case .searchAdmins:
                                        switch participant.participant {
                                        case .creator:
                                            label = themeAndStrings.1.Channel_Management_LabelCreator
                                        case let .member(_, _, adminInfo, _):
                                            if let adminInfo = adminInfo {
                                                if let peer = participant.peers[adminInfo.promotedBy] {
                                                    label = themeAndStrings.1.Channel_Management_PromotedBy(peer.displayTitle).0
                                                }
                                            }
                                        }
                                    case .searchBanned:
                                        switch participant.participant {
                                        case let .member(_, _, _, banInfo):
                                            if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                                                label = themeAndStrings.1.Channel_Management_RestrictedBy(peer.displayTitle).0
                                            }
                                        default:
                                            break
                                        }
                                    default:
                                        break
                                    }
                                    entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant, label, enabled), section: section))
                                    index += 1
                                }
                            }
                            
                            for participant in foundMembers {
                                if !existingPeerIds.contains(participant.peer.id) {
                                    existingPeerIds.insert(participant.peer.id)
                                    let section: ChannelMembersSearchSection
                                    switch mode {
                                        case .inviteActions, .banAndPromoteActions:
                                            section = .members
                                        case .searchMembers, .searchBanned, .searchAdmins:
                                            section = .none
                                    }
                                    
                                    var label: String?
                                    var enabled = true
                                    if case .banAndPromoteActions = mode {
                                        if case .creator = participant.participant {
                                            label = themeAndStrings.1.Channel_Management_LabelCreator
                                            enabled = false
                                        }
                                    }
                                    
                                    
                                    entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant, label, enabled), section: section))
                                    index += 1
                                }
                            }
                            
                            for peer in foundContacts {
                                if !existingPeerIds.contains(peer.id) {
                                    existingPeerIds.insert(peer.id)
                                    entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .contacts))
                                    index += 1
                                }
                            }
                            
                            for foundPeer in foundRemotePeers.0 {
                                let peer = foundPeer.peer
                                if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                                    existingPeerIds.insert(peer.id)
                                    entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global))
                                    index += 1
                                }
                            }
                            
                            for foundPeer in foundRemotePeers.1 {
                                let peer = foundPeer.peer
                                if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                                    existingPeerIds.insert(peer.id)
                                    entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global))
                                    index += 1
                                }
                            }
                            
                            return entries
                    }
                } else {
                    return .single(nil)
                }
        }
        
        let previousSearchItems = Atomic<[ChannelMembersSearchEntry]?>(value: nil)

        self.searchDisposable.set((combineLatest(foundItems, self.themeAndStringsPromise.get())
            |> deliverOnMainQueue).start(next: { [weak self] entries, themeAndStrings in
                if let strongSelf = self {
                    let previousEntries = previousSearchItems.swap(entries)
                    updateActivity(false)
                    let firstTime = previousEntries == nil
                    let transition = channelMembersSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, account: account, theme: themeAndStrings.0, strings: themeAndStrings.1, nameSortOrder: themeAndStrings.2, nameDisplayOrder: themeAndStrings.3, peerSelected: openPeer)
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                }
            }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                    }
                }
            })
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: ChannelMembersSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
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
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
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
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}
