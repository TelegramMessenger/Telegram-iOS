import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum ChannelMembersSearchMode {
    case searchMembers
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

private final class ChannelMembersSearchEntry: Comparable, Identifiable {
    let index: Int
    let peer: Peer
    let section: ChannelMembersSearchSection
    
    init(index: Int, peer: Peer, section: ChannelMembersSearchSection) {
        self.index = index
        self.peer = peer
        self.section = section
    }
    
    var stableId: PeerId {
        return self.peer.id
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index == rhs.index && arePeersEqual(lhs.peer, rhs.peer) && lhs.section == rhs.section
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, peerSelected: @escaping (Peer) -> Void) -> ListViewItem {
        let peer = self.peer
        return ContactsPeerItem(theme: theme, strings: strings, account: account, peerMode: .peer, peer: self.peer, chatPeer: self.peer, status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: theme, strings: strings, actionTitle: nil, action: nil) }), action: { _ in
            peerSelected(peer)
        })
    }
}
struct ChannelMembersSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func channelMembersSearchContainerPreparedRecentTransition(from fromEntries: [ChannelMembersSearchEntry], to toEntries: [ChannelMembersSearchEntry], isSearching: Bool, account: Account, theme: PresentationTheme, strings: PresentationStrings, peerSelected: @escaping (Peer) -> Void) -> ChannelMembersSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, peerSelected: peerSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, peerSelected: peerSelected), directionHint: nil) }
    
    return ChannelMembersSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

final class ChannelMembersSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openPeer: (Peer) -> Void
    private let mode: ChannelMembersSearchMode
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var enqueuedTransitions: [(ChannelMembersSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(account: Account, peerId: PeerId, mode: ChannelMembersSearchMode, openPeer: @escaping (Peer) -> Void) {
        self.account = account
        self.openPeer = openPeer
        self.mode = mode
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
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
                if let query = query, !query.isEmpty {
                    let foundGroupMembers: Signal<[Peer], NoError>
                    let foundMembers: Signal<[RenderedChannelParticipant], NoError>
                    
                    switch mode {
                        case .searchMembers:
                            foundGroupMembers = searchGroupMembers(postbox: account.postbox, network: account.network, peerId: peerId, query: query)
                            foundMembers = .single([])
                        case .inviteActions:
                            foundGroupMembers = .single([])
                            foundMembers = channelMembers(postbox: account.postbox, network: account.network, peerId: peerId, filter: .search(query))
                    }
                    
                    let foundContacts: Signal<[Peer], NoError>
                    let foundRemotePeers: Signal<([FoundPeer], [FoundPeer]), NoError>
                    switch mode {
                        case .inviteActions:
                            foundContacts = account.postbox.searchContacts(query: query.lowercased())
                            foundRemotePeers = .single(([], [])) |> then(searchPeers(account: account, query: query)
                            |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                        case .searchMembers:
                            foundContacts = .single([])
                            foundRemotePeers = .single(([], []))
                    }
                    
                    return combineLatest(foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, themeAndStringsPromise.get())
                        |> map { foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, themeAndStrings -> [ChannelMembersSearchEntry]? in
                            var entries: [ChannelMembersSearchEntry] = []
                            
                            var existingPeerIds = Set<PeerId>()
                            
                            var index = 0
                            
                            for peer in foundGroupMembers {
                                if !existingPeerIds.contains(peer.id) {
                                    existingPeerIds.insert(peer.id)
                                    let section: ChannelMembersSearchSection
                                    switch mode {
                                        case .inviteActions:
                                            section = .members
                                        case .searchMembers:
                                            section = .none
                                    }
                                    entries.append(ChannelMembersSearchEntry(index: index, peer: peer, section: section))
                                    index += 1
                                }
                            }
                            
                            for participant in foundMembers {
                                if !existingPeerIds.contains(participant.peer.id) {
                                    existingPeerIds.insert(participant.peer.id)
                                    let section: ChannelMembersSearchSection
                                    switch mode {
                                        case .inviteActions:
                                            section = .members
                                        case .searchMembers:
                                            section = .none
                                    }
                                    entries.append(ChannelMembersSearchEntry(index: index, peer: participant.peer, section: section))
                                    index += 1
                                }
                            }
                            
                            for peer in foundContacts {
                                if !existingPeerIds.contains(peer.id) {
                                    existingPeerIds.insert(peer.id)
                                    entries.append(ChannelMembersSearchEntry(index: index, peer: peer, section: .contacts))
                                    index += 1
                                }
                            }
                            
                            for foundPeer in foundRemotePeers.0 {
                                let peer = foundPeer.peer
                                if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                                    existingPeerIds.insert(peer.id)
                                    entries.append(ChannelMembersSearchEntry(index: index, peer: peer, section: .global))
                                    index += 1
                                }
                            }
                            
                            for foundPeer in foundRemotePeers.1 {
                                let peer = foundPeer.peer
                                if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                                    existingPeerIds.insert(peer.id)
                                    entries.append(ChannelMembersSearchEntry(index: index, peer: peer, section: .global))
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
                    
                    let firstTime = previousEntries == nil
                    let transition = channelMembersSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, account: account, theme: themeAndStrings.0, strings: themeAndStrings.1, peerSelected: openPeer)
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
