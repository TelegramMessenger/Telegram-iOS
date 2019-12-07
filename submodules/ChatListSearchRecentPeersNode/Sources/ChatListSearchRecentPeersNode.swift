import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import MergeLists
import HorizontalPeerItem
import ListSectionHeaderNode
import ContextUI
import AccountContext

private func calculateItemCustomWidth(width: CGFloat) -> CGFloat {
    let itemInsets = UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 6.0)
    let minimalItemWidth: CGFloat = width > 301.0 ? 70.0 : 60.0
    let effectiveWidth1 = width - 12.0 - 12.0
    let effectiveWidth = width - itemInsets.left - itemInsets.right
    
    let itemsPerRow = Int(effectiveWidth1 / minimalItemWidth)
    let itemWidth = floor(effectiveWidth1 / CGFloat(itemsPerRow))
    
    let itemsInRow = Int(effectiveWidth / itemWidth)
    let itemsInRowWidth = CGFloat(itemsInRow) * itemWidth
    let remainingWidth = max(0.0, effectiveWidth - itemsInRowWidth)
    
    let itemSpacing = floorToScreenPixels(remainingWidth / CGFloat(itemsInRow + 1))
    
    return itemWidth + itemSpacing
}

private struct ChatListSearchRecentPeersEntry: Comparable, Identifiable {
    let index: Int
    let peer: Peer
    let presence: PeerPresence?
    let unreadBadge: (Int32, Bool)?
    let theme: PresentationTheme
    let strings: PresentationStrings
    let itemCustomWidth: CGFloat?
    var stableId: PeerId {
        return self.peer.id
    }
    
    static func ==(lhs: ChatListSearchRecentPeersEntry, rhs: ChatListSearchRecentPeersEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.itemCustomWidth != rhs.itemCustomWidth {
            return false
        }
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        if lhs.unreadBadge?.0 != rhs.unreadBadge?.0 {
            return false
        }
        if lhs.unreadBadge?.1 != rhs.unreadBadge?.1 {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    static func <(lhs: ChatListSearchRecentPeersEntry, rhs: ChatListSearchRecentPeersEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, mode: HorizontalPeerItemMode, peerSelected: @escaping (Peer) -> Void, peerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void, isPeerSelected: @escaping (PeerId) -> Bool) -> ListViewItem {
        return HorizontalPeerItem(theme: self.theme, strings: self.strings, mode: mode, context: context, peer: self.peer, presence: self.presence, unreadBadge: self.unreadBadge, action: peerSelected, contextAction: { peer, node, gesture in
            peerContextAction(peer, node, gesture)
        }, isPeerSelected: isPeerSelected, customWidth: self.itemCustomWidth)
    }
}

private struct ChatListSearchRecentNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
    let animated: Bool
}

private func preparedRecentPeersTransition(context: AccountContext, mode: HorizontalPeerItemMode, peerSelected: @escaping (Peer) -> Void, peerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void, isPeerSelected: @escaping (PeerId) -> Bool, share: Bool = false, from fromEntries: [ChatListSearchRecentPeersEntry], to toEntries: [ChatListSearchRecentPeersEntry], firstTime: Bool, animated: Bool) -> ChatListSearchRecentNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, mode: mode, peerSelected: peerSelected, peerContextAction: peerContextAction, isPeerSelected: isPeerSelected), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, mode: mode, peerSelected: peerSelected, peerContextAction: peerContextAction, isPeerSelected: isPeerSelected), directionHint: nil) }
    
    return ChatListSearchRecentNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, animated: animated)
}

public final class ChatListSearchRecentPeersNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    private let mode: HorizontalPeerItemMode
    private let sectionHeaderNode: ListSectionHeaderNode
    private let listView: ListView
    private let share: Bool
    
    private let peerSelected: (Peer) -> Void
    private let peerContextAction: (Peer, ASDisplayNode, ContextGesture?) -> Void
    private let isPeerSelected: (PeerId) -> Bool
    
    private let disposable = MetaDisposable()
    private let itemCustomWidthValuePromise: ValuePromise<CGFloat?> = ValuePromise(nil, ignoreRepeated: true)

    private var items: [ListViewItem] = []
    private var queuedTransitions: [ChatListSearchRecentNodeTransition] = []
    
    public init(context: AccountContext, theme: PresentationTheme, mode: HorizontalPeerItemMode, strings: PresentationStrings, peerSelected: @escaping (Peer) -> Void, peerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void, isPeerSelected: @escaping (PeerId) -> Bool, share: Bool = false) {
        self.theme = theme
        self.strings = strings
        self.themeAndStringsPromise = Promise((self.theme, self.strings))
        self.mode = mode
        self.share = share
        self.peerSelected = peerSelected
        self.peerContextAction = peerContextAction
        self.isPeerSelected = isPeerSelected
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        self.sectionHeaderNode.title = strings.DialogList_RecentTitlePeople.uppercased()
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init()
        
        self.addSubnode(self.sectionHeaderNode)
        self.addSubnode(self.listView)
        
        let peersDisposable = DisposableSet()
        
        let recent: Signal<([Peer], [PeerId: (Int32, Bool)], [PeerId : PeerPresence]), NoError> = recentPeers(account: context.account)
        |> filter { value -> Bool in
            switch value {
                case .disabled:
                    return false
                default:
                    return true
            }
        }
        |> mapToSignal { recent in
            switch recent {
                case .disabled:
                    return .single(([], [:], [:]))
                case let .peers(peers):
                    return combineLatest(queue: .mainQueue(), peers.filter { !$0.isDeleted }.map {context.account.postbox.peerView(id: $0.id)}) |> mapToSignal { peerViews -> Signal<([Peer], [PeerId: (Int32, Bool)], [PeerId: PeerPresence]), NoError> in
                        return context.account.postbox.unreadMessageCountsView(items: peerViews.map {
                            .peer($0.peerId)
                        })
                        |> map { values in
                            var peers: [Peer] = []
                            var unread: [PeerId: (Int32, Bool)] = [:]
                            var presences: [PeerId: PeerPresence] = [:]
                            for peerView in peerViews {
                                if let peer = peerViewMainPeer(peerView) {
                                    var isMuted: Bool = false
                                    if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                        switch notificationSettings.muteState {
                                            case .muted:
                                                isMuted = true
                                            default:
                                                break
                                        }
                                    }
                                    
                                    let unreadCount = values.count(for: .peer(peerView.peerId))
                                    if let unreadCount = unreadCount, unreadCount > 0 {
                                        unread[peerView.peerId] = (unreadCount, isMuted)
                                    }
                                    
                                    if let presence = peerView.peerPresences[peer.id] {
                                        presences[peer.id] = presence
                                    }
                                    
                                    peers.append(peer)
                                }
                            }
                            return (peers, unread, presences)
                        }
                    }
            }
        }
        
        let previous: Atomic<[ChatListSearchRecentPeersEntry]> = Atomic(value: [])
        let firstTime:Atomic<Bool> = Atomic(value: true)
        peersDisposable.add((combineLatest(queue: .mainQueue(), recent, self.itemCustomWidthValuePromise.get(), self.themeAndStringsPromise.get()) |> deliverOnMainQueue).start(next: { [weak self] peers, itemCustomWidth, themeAndStrings in
            if let strongSelf = self {
                var entries: [ChatListSearchRecentPeersEntry] = []
                for peer in peers.0 {
                    entries.append(ChatListSearchRecentPeersEntry(index: entries.count, peer: peer, presence: peers.2[peer.id], unreadBadge: peers.1[peer.id], theme: themeAndStrings.0, strings: themeAndStrings.1, itemCustomWidth: itemCustomWidth))
                }
                
                let animated = !firstTime.swap(false)
                
                let transition = preparedRecentPeersTransition(context: context, mode: mode, peerSelected: peerSelected, peerContextAction: peerContextAction, isPeerSelected: isPeerSelected, from: previous.swap(entries), to: entries, firstTime: !animated, animated: animated)

                strongSelf.enqueueTransition(transition)
            }
        }))
        if case .actionSheet = mode {
            peersDisposable.add(managedUpdatedRecentPeers(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network).start())
        }
        self.disposable.set(peersDisposable)
    }
    
    private func enqueueTransition(_ transition: ChatListSearchRecentNodeTransition) {
        self.queuedTransitions.append(transition)
        self.dequeueTransitions()
    }
    
    private func dequeueTransitions() {
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.firstTime {
                options.insert(.Synchronous)
                options.insert(.LowLatency)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            self.themeAndStringsPromise.set(.single((self.theme, self.strings)))
            
            self.sectionHeaderNode.title = strings.DialogList_RecentTitlePeople.uppercased()
            self.sectionHeaderNode.updateTheme(theme: theme)
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 114.0)
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 28.0))
        self.sectionHeaderNode.updateLayout(size: CGSize(width: size.width, height: 28.0), leftInset: leftInset, rightInset: rightInset)
        
        var insets = UIEdgeInsets()
        insets.top += leftInset
        insets.bottom += rightInset
        
        var itemCustomWidth: CGFloat?
        if self.share {
            insets.top = 7.0
            insets.bottom = 7.0
            
            itemCustomWidth = calculateItemCustomWidth(width: size.width)
        }
        
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 92.0, height: size.width)
        self.listView.position = CGPoint(x: size.width / 2.0, y: 92.0 / 2.0 + 28.0)
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: 92.0, height: size.width), insets: insets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.itemCustomWidthValuePromise.set(itemCustomWidth)
    }
    
    public func viewAndPeerAtPoint(_ point: CGPoint) -> (UIView, PeerId)? {
        let adjustedPoint = self.view.convert(point, to: self.listView.view)
        var selectedItemNode: ASDisplayNode?
        self.listView.forEachItemNode { itemNode in
            if itemNode.frame.contains(adjustedPoint) {
                selectedItemNode = itemNode
            }
        }
        if let selectedItemNode = selectedItemNode as? HorizontalPeerItemNode, let peer = selectedItemNode.item?.peer {
            return (selectedItemNode.view, peer.id)
        }
        return nil
    }
    
    public func updateSelectedPeers(animated: Bool) {
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? HorizontalPeerItemNode {
                itemNode.updateSelection(animated: animated)
            }
        }
    }
}
