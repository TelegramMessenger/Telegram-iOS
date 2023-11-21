import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import PeerInfoVisualMediaPaneNode
import ChatControllerInteraction

private struct RecommendedChannelsListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let animated: Bool
}

private enum RecommendedChannelsListEntryStableId: Hashable {
    case addMember
    case peer(PeerId)
}

private enum RecommendedChannelsListEntry: Comparable, Identifiable {
    case peer(theme: PresentationTheme, index: Int, peer: EnginePeer, subscribers: Int32)
        
    var stableId: RecommendedChannelsListEntryStableId {
        switch self {
            case let .peer(_, _, peer, _):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: RecommendedChannelsListEntry, rhs: RecommendedChannelsListEntry) -> Bool {
        switch lhs {
            case let .peer(lhsTheme, lhsIndex, lhsPeer, lhsSubscribers):
                if case let .peer(rhsTheme, rhsIndex, rhsPeer, rhsSubscribers) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsPeer == rhsPeer, lhsSubscribers == rhsSubscribers {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: RecommendedChannelsListEntry, rhs: RecommendedChannelsListEntry) -> Bool {
        switch lhs {
            case let .peer(_, lhsIndex, _, _):
                switch rhs {
                    case let .peer(_, rhsIndex, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, action: @escaping (EnginePeer) -> Void) -> ListViewItem {
        switch self {
            case let .peer(_, _, peer, subscribers):
                let subtitle = presentationData.strings.Conversation_StatusSubscribers(subscribers)
                return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: peer, presence: nil, text: .text(subtitle, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: 0, action: {
                    action(peer)
                }, setPeerIdWithRevealedOptions: { _, _ in
                }, removePeer: { _ in
                }, contextAction: nil, hasTopStripe: false, noInsets: true, noCorners: true, disableInteractiveTransitionIfNecessary: true)
        }
    }
}

private func preparedTransition(from fromEntries: [RecommendedChannelsListEntry], to toEntries: [RecommendedChannelsListEntry], context: AccountContext, presentationData: PresentationData, action: @escaping (EnginePeer) -> Void) -> RecommendedChannelsListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, action: action), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, action: action), directionHint: nil) }
    
    return RecommendedChannelsListTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: toEntries.count < fromEntries.count)
}

final class PeerInfoRecommendedChannelsPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let chatControllerInteraction: ChatControllerInteraction
    
    weak var parentController: ViewController?
    
    private let listNode: ListView
    private var currentEntries: [RecommendedChannelsListEntry] = []
    private var currentState: RecommendedChannels?
    private var canLoadMore: Bool = false
    private var enqueuedTransactions: [RecommendedChannelsListTransaction] = []
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool)?
    private let presentationDataPromise = Promise<PresentationData>()
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    var status: Signal<PeerInfoStatusData?, NoError> {
        return .single(nil)
    }

    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    var tabBarOffset: CGFloat {
        return 0.0
    }
        
    private var disposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.chatControllerInteraction = chatControllerInteraction
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.disposable = (combineLatest(queue: .mainQueue(),
            self.presentationDataPromise.get(),
            context.engine.peers.recommendedChannels(peerId: peerId)
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData, recommendedChannels in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateState(recommendedChannels: recommendedChannels, presentationData: presentationData)
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func ensureMessageIsVisible(id: MessageId) {
    }
    
    func scrollToTop() -> Bool {
        if !self.listNode.scrollToOffsetFromTop(0.0, animated: true) {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            return true
        } else {
            return false
        }
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.currentParams == nil
        self.currentParams = (size, isScrollingLockedAtTop)
        self.presentationDataPromise.set(.single(presentationData))
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)

        var scrollToItem: ListViewScrollToItem?
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            default:
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: duration), directionHint: .Up)
            }
        }
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
        
        if isFirstLayout, let recommendedChannels = self.currentState {
            self.updateState(recommendedChannels: recommendedChannels, presentationData: presentationData)
        }
    }
    
    private func updateState(recommendedChannels: RecommendedChannels?, presentationData: PresentationData) {
        var entries: [RecommendedChannelsListEntry] = []
        
        if let channels = recommendedChannels?.channels {
            for channel in channels {
                entries.append(.peer(theme: presentationData.theme, index: entries.count, peer: channel.peer, subscribers: channel.subscribers))
            }
        }
        
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, action: { [weak self] peer in
            self?.chatControllerInteraction.openPeer(peer, .default, nil, .default)
        })
        self.currentEntries = entries
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
    }
    
    private func dequeueTransaction() {
        guard let _ = self.currentParams, let transaction = self.enqueuedTransactions.first else {
            return
        }
        
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if transaction.animated {
            options.insert(.AnimateInsertion)
        } else {
            options.insert(.Synchronous)
        }
        
        self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf.ready.set(.single(true))
            }
        })
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            self.listNode.transferVelocity(velocity)
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
    }
    
    func updateSelectedMessages(animated: Bool) {
    }
}
