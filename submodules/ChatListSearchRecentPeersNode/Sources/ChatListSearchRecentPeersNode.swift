import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
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
    let peer: EnginePeer
    let presence: EnginePeer.Presence?
    let unreadBadge: (Int32, Bool)?
    let theme: PresentationTheme
    let strings: PresentationStrings
    let itemCustomWidth: CGFloat?
    var stableId: EnginePeer.Id {
        return self.peer.id
    }
    
    static func ==(lhs: ChatListSearchRecentPeersEntry, rhs: ChatListSearchRecentPeersEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.itemCustomWidth != rhs.itemCustomWidth {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.presence != rhs.presence {
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
    
    func item(context: AccountContext, mode: HorizontalPeerItemMode, peerSelected: @escaping (EnginePeer) -> Void, peerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void, isPeerSelected: @escaping (EnginePeer.Id) -> Bool) -> ListViewItem {
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

private func preparedRecentPeersTransition(context: AccountContext, mode: HorizontalPeerItemMode, peerSelected: @escaping (EnginePeer) -> Void, peerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void, isPeerSelected: @escaping (EnginePeer.Id) -> Bool, share: Bool = false, from fromEntries: [ChatListSearchRecentPeersEntry], to toEntries: [ChatListSearchRecentPeersEntry], firstTime: Bool, animated: Bool) -> ChatListSearchRecentNodeTransition {
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
    private let listView: ListView
    private let share: Bool
    
    private let peerSelected: (EnginePeer) -> Void
    private let peerContextAction: (EnginePeer, ASDisplayNode, ContextGesture?) -> Void
    private let isPeerSelected: (EnginePeer.Id) -> Bool
    
    private let disposable = MetaDisposable()
    private let itemCustomWidthValuePromise: ValuePromise<CGFloat?> = ValuePromise(nil, ignoreRepeated: true)

    private var items: [ListViewItem] = []
    private var queuedTransitions: [ChatListSearchRecentNodeTransition] = []
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    public var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    public init(context: AccountContext, theme: PresentationTheme, mode: HorizontalPeerItemMode, strings: PresentationStrings, peerSelected: @escaping (EnginePeer) -> Void, peerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void, isPeerSelected: @escaping (EnginePeer.Id) -> Bool, share: Bool = false) {
        self.theme = theme
        self.strings = strings
        self.themeAndStringsPromise = Promise((self.theme, self.strings))
        self.mode = mode
        self.share = share
        self.peerSelected = peerSelected
        self.peerContextAction = peerContextAction
        self.isPeerSelected = isPeerSelected
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.addSubnode(self.listView)
        
        let peersDisposable = DisposableSet()
        
        let recent: Signal<([EnginePeer], [EnginePeer.Id: (Int32, Bool)], [EnginePeer.Id : EnginePeer.Presence]), NoError> = context.engine.peers.recentPeers()
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
                    return combineLatest(queue: .mainQueue(),
                        peers.filter {
                            !$0.isDeleted
                        }.map {
                            context.account.postbox.peerView(id: $0.id)
                        }
                    )
                    |> mapToSignal { peerViews -> Signal<([EnginePeer], [EnginePeer.Id: (Int32, Bool)], [EnginePeer.Id: EnginePeer.Presence]), NoError> in
                        return context.account.postbox.unreadMessageCountsView(items: peerViews.map {
                            .peer($0.peerId)
                        })
                        |> map { values in
                            var peers: [EnginePeer] = []
                            var unread: [EnginePeer.Id: (Int32, Bool)] = [:]
                            var presences: [EnginePeer.Id: EnginePeer.Presence] = [:]
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
                                        presences[peer.id] = EnginePeer.Presence(presence)
                                    }
                                    
                                    peers.append(EnginePeer(peer))
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
                
                if !strongSelf.didSetReady {
                    strongSelf.ready.set(.single(true))
                    strongSelf.didSetReady = true
                }
            }
        }))
        if case .actionSheet = mode {
            peersDisposable.add(context.engine.peers.managedUpdatedRecentPeers().start())
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
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
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
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 86.0)
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {        
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
        self.listView.position = CGPoint(x: size.width / 2.0, y: 92.0 / 2.0)
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: 92.0, height: size.width), insets: insets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.itemCustomWidthValuePromise.set(itemCustomWidth)
    }
    
    public func viewAndPeerAtPoint(_ point: CGPoint) -> (UIView, EnginePeer.Id)? {
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
