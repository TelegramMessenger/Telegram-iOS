import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AvatarNode
import AccountContext
import PeerPresenceStatusManager
import AppBundle
import SegmentedControlNode
import ContextUI

private let subtitleFont = Font.regular(12.0)

extension CGPoint {
    func angle(to other: CGPoint) -> CGFloat {
        let originX = other.x - self.x
        let originY = other.y - self.y
        let bearingRadians = atan2f(Float(originY), Float(originX))
        return CGFloat(bearingRadians)
    }
    
    func distance(to other: CGPoint) -> CGFloat {
        return sqrt((self.x - other.x) * (self.x - other.x) + (self.y - other.y) * (self.y - other.y))
    }
    
    func offsetBy(distance: CGFloat, inDirection radians: CGFloat) -> CGPoint {
        let vertical = sin(radians) * distance
        let horizontal = cos(radians) * distance
        return self.offsetBy(dx: horizontal, dy: vertical)
    }
}

private struct SharePeerEntry: Comparable, Identifiable {
    let index: Int32
    let peer: EngineRenderedPeer
    let presence: EnginePeer.Presence?
    let threadId: Int64?
    let threadData: MessageHistoryThreadData?
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    var stableId: Int64 {
        return self.peer.peerId.toInt64()
    }
    
    static func ==(lhs: SharePeerEntry, rhs: SharePeerEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.presence != rhs.presence {
            return false
        }
        if lhs.threadId != rhs.threadId {
            return false
        }
        if lhs.threadData != rhs.threadData {
            return false
        }
        
        return true
    }
    
    static func <(lhs: SharePeerEntry, rhs: SharePeerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, interfaceInteraction: ShareControllerInteraction) -> GridItem {
        return ShareControllerPeerGridItem(context: context, theme: self.theme, strings: self.strings, peer: self.peer, presence: self.presence, topicId: self.threadId, threadData: self.threadData, controllerInteraction: interfaceInteraction, search: false)
    }
}

private struct ShareGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let animated: Bool
}

private let avatarFont = avatarPlaceholderFont(size: 17.0)

private func preparedGridEntryTransition(context: AccountContext, from fromEntries: [SharePeerEntry], to toEntries: [SharePeerEntry], interfaceInteraction: ShareControllerInteraction) -> ShareGridTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction)) }
    
    return ShareGridTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: false)
}

final class SharePeersContainerNode: ASDisplayNode, ShareContentContainerNode {
    private let sharedContext: SharedAccountContext
    private let context: AccountContext
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let nameDisplayOrder: PresentationPersonNameOrder
    private let controllerInteraction: ShareControllerInteraction
    private let switchToAnotherAccount: () -> Void
    private let debugAction: () -> Void
    private let extendedInitialReveal: Bool
    
    let accountPeer: EnginePeer
    private let foundPeers = Promise<[EngineRenderedPeer]>([])
    
    private let disposable = MetaDisposable()
    private var entries: [SharePeerEntry] = []
    private var enqueuedTransitions: [(ShareGridTransaction, Bool)] = []
    
    let contentGridNode: GridNode
    private let headerNode: ASDisplayNode
    private let contentTitleNode: ASTextNode
    private let contentSubtitleNode: ImmediateTextNode
    private let contentTitleAccountNode: AvatarNode
    private let contentSeparatorNode: ASDisplayNode
    private let searchButtonNode: HighlightableButtonNode
    
    private let shareButtonNode: HighlightableButtonNode
    private let shareReferenceNode: ContextReferenceContentNode
    private let shareContainerNode: ContextControllerSourceNode
    private let segmentedNode: SegmentedControlNode
    
    private let segmentedValues: [ShareControllerSegmentedValue]?
    
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    var openSearch: (() -> Void)?
    var openShare: ((ASDisplayNode, ContextGesture?) -> Void)?
    var segmentedSelectedIndexUpdated: ((Int) -> Void)?
    
    private var ensurePeerVisibleOnLayout: PeerId?
    private var validLayout: (CGSize, CGFloat)?
    private var overrideGridOffsetTransition: ContainedViewLayoutTransition?
    
    let peersValue = Promise<[(EngineRenderedPeer, EnginePeer.Presence?)]>()
    
    private var _tick: Int = 0 {
        didSet {
            self.tick.set(self._tick)
        }
    }
    private let tick = ValuePromise<Int>(0)
    
    init(sharedContext: SharedAccountContext, context: AccountContext, switchableAccounts: [AccountWithInfo], theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, peers: [(EngineRenderedPeer, EnginePeer.Presence?)], accountPeer: EnginePeer, controllerInteraction: ShareControllerInteraction, externalShare: Bool, switchToAnotherAccount: @escaping () -> Void, debugAction: @escaping () -> Void, extendedInitialReveal: Bool, segmentedValues: [ShareControllerSegmentedValue]?) {
        self.sharedContext = sharedContext
        self.context = context
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.controllerInteraction = controllerInteraction
        self.accountPeer = accountPeer
        self.switchToAnotherAccount = switchToAnotherAccount
        self.debugAction = debugAction
        self.extendedInitialReveal = extendedInitialReveal
        self.segmentedValues = segmentedValues
        
        self.peersValue.set(.single(peers))
        
        let items: Signal<[SharePeerEntry], NoError> = combineLatest(self.peersValue.get(), self.foundPeers.get(), self.tick.get())
        |> map { [weak controllerInteraction] initialPeers, foundPeers, _ -> [SharePeerEntry] in
            var entries: [SharePeerEntry] = []
            var index: Int32 = 0
            
            var existingPeerIds: Set<PeerId> = Set()
            entries.append(SharePeerEntry(index: index, peer: EngineRenderedPeer(peer: accountPeer), presence: nil, threadId: nil, threadData: nil, theme: theme, strings: strings))
            existingPeerIds.insert(accountPeer.id)
            index += 1
            
            for peer in foundPeers.reversed() {
                if !existingPeerIds.contains(peer.peerId) {
                    entries.append(SharePeerEntry(index: index, peer: peer, presence: nil, threadId: nil, threadData: nil, theme: theme, strings: strings))
                    existingPeerIds.insert(peer.peerId)
                    index += 1
                }
            }
            
            for (peer, presence) in initialPeers {
                if !existingPeerIds.contains(peer.peerId) {
                    let thread = controllerInteraction?.selectedTopics[peer.peerId]
                    entries.append(SharePeerEntry(index: index, peer: peer, presence: presence, threadId: thread?.0, threadData: thread?.1, theme: theme, strings: strings))
                    existingPeerIds.insert(peer.peerId)
                    index += 1
                }
            }
            return entries
        }
        
        self.contentGridNode = GridNode()
        self.headerNode = ASDisplayNode()
        
        self.contentTitleNode = ASTextNode()
        self.contentTitleNode.attributedText = NSAttributedString(string: strings.ShareMenu_ShareTo, font: Font.medium(20.0), textColor: self.theme.actionSheet.primaryTextColor)
        
        self.contentSubtitleNode = ImmediateTextNode()
        self.contentSubtitleNode.maximumNumberOfLines = 1
        self.contentSubtitleNode.isUserInteractionEnabled = false
        self.contentSubtitleNode.displaysAsynchronously = false
        self.contentSubtitleNode.truncationMode = .byTruncatingTail
        self.contentSubtitleNode.attributedText = NSAttributedString(string: strings.ShareMenu_SelectChats, font: subtitleFont, textColor: self.theme.actionSheet.secondaryTextColor)
        
        self.contentTitleAccountNode = AvatarNode(font: avatarFont)
        var hasOtherAccounts = false
        if switchableAccounts.count > 1, let info = switchableAccounts.first(where: { $0.account.id == context.account.id }) {
            hasOtherAccounts = true
            self.contentTitleAccountNode.setPeer(context: context, theme: theme, peer: EnginePeer(info.peer), emptyColor: nil, synchronousLoad: false)
        } else {
            self.contentTitleAccountNode.isHidden = true
        }
        
        self.searchButtonNode = HighlightableButtonNode()
        self.searchButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Share/SearchIcon"), color: self.theme.actionSheet.controlAccentColor), for: [])
        
        self.shareButtonNode = HighlightableButtonNode()
        self.shareButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Share/ShareIcon"), color: self.theme.actionSheet.controlAccentColor), for: [])
                 
        self.shareReferenceNode = ContextReferenceContentNode()
        self.shareContainerNode = ContextControllerSourceNode()
        self.shareContainerNode.animateScale = false
        
        let segmentedItems: [SegmentedControlItem]
        if let segmentedValues = segmentedValues {
            segmentedItems = segmentedValues.map { SegmentedControlItem(title: $0.title) }
        } else {
            segmentedItems = []
        }
        self.segmentedNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: segmentedItems, selectedIndex: 0)
        self.segmentedNode.isHidden = segmentedValues == nil
        
        self.contentTitleNode.isHidden = self.segmentedValues != nil
        self.contentSubtitleNode.isHidden = self.segmentedValues != nil
        
        self.contentSeparatorNode = ASDisplayNode()
        self.contentSeparatorNode.isLayerBacked = true
        self.contentSeparatorNode.displaysAsynchronously = false
        self.contentSeparatorNode.backgroundColor = self.theme.actionSheet.opaqueItemSeparatorColor
        
        if !externalShare || hasOtherAccounts {
            self.shareButtonNode.isHidden = true
        }
        
        super.init()
        
        self.addSubnode(self.contentGridNode)
        self.addSubnode(self.headerNode)
        
        self.headerNode.addSubnode(self.contentTitleNode)
        self.headerNode.addSubnode(self.contentSubtitleNode)
        self.headerNode.addSubnode(self.contentTitleAccountNode)
        self.headerNode.addSubnode(self.segmentedNode)
        self.headerNode.addSubnode(self.searchButtonNode)
        
        self.shareContainerNode.addSubnode(self.shareReferenceNode)
        self.shareButtonNode.addSubnode(self.shareContainerNode)
        
        self.headerNode.addSubnode(self.shareButtonNode)
        
        self.addSubnode(self.contentSeparatorNode)
        
        self.shareContainerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openShare?(strongSelf.shareReferenceNode, gesture)
        }
        
        let previousItems = Atomic<[SharePeerEntry]?>(value: [])
        self.disposable.set((items
        |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousItems.swap(entries)
                strongSelf.entries = entries
                
                let firstTime = previousEntries == nil
                let transition = preparedGridEntryTransition(context: context, from: previousEntries ?? [], to: entries, interfaceInteraction: controllerInteraction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))

        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
        
        self.searchButtonNode.addTarget(self, action: #selector(self.searchPressed), forControlEvents: .touchUpInside)
        self.shareButtonNode.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
        self.contentTitleAccountNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.accountTapGesture(_:))))
        
        self.segmentedNode.selectedIndexChanged = { [weak self] index in
            self?.segmentedSelectedIndexUpdated?(index)
        }

        self.contentTitleNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.debugTapGesture(_:))))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func enqueueTransition(_ transition: ShareGridTransaction, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var itemTransition: ContainedViewLayoutTransition = .immediate
            if transition.animated {
                itemTransition = .animated(duration: 0.3, curve: .spring)
            }
            self.contentGridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: nil, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        }
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
        self.ensurePeerVisibleOnLayout = peerId
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    private func calculateMetrics(size: CGSize) -> (topInset: CGFloat, itemWidth: CGFloat) {
        let itemCount = self.entries.count
        
        let itemInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)
        let minimalItemWidth: CGFloat = size.width > 301.0 ? 70.0 : 60.0
        let effectiveWidth = size.width - itemInsets.left - itemInsets.right
        
        let itemsPerRow = Int(effectiveWidth / minimalItemWidth)
        
        let itemWidth = floor(effectiveWidth / CGFloat(itemsPerRow))
        var rowCount = itemCount / itemsPerRow + (itemCount % itemsPerRow != 0 ? 1 : 0)
        rowCount = max(rowCount, 4)
        
        let minimallyRevealedRowCount: CGFloat
        if self.extendedInitialReveal {
            minimallyRevealedRowCount = 4.6
        } else {
            minimallyRevealedRowCount = 3.7
        }
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let gridTopInset = max(0.0, size.height - floor(initiallyRevealedRowCount * itemWidth) - 14.0)
        return (gridTopInset, itemWidth)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func frameForPeerId(_ peerId: EnginePeer.Id) -> CGRect? {
        var node: ASDisplayNode?
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                node = itemNode
            }
        }
        if let node = node {
            return node.frame.offsetBy(dx: 0.0, dy: -10.0)
        } else {
            return nil
        }
    }
        
    func prepareForAnimateIn() {
        self.searchButtonNode.alpha = 0.0
        self.shareButtonNode.alpha = 0.0
        self.contentTitleNode.alpha = 0.0
        self.contentSubtitleNode.alpha = 0.0
        self.contentGridNode.alpha = 0.0
    }
    
    func animateIn(peerId: EnginePeer.Id, scrollDelta: CGFloat) -> CGRect? {
        self.headerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.searchButtonNode.alpha = 1.0
        self.searchButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.searchButtonNode.layer.animatePosition(from: CGPoint(x: -20.0, y: 0.0), to: .zero, duration: 0.2, additive: true)

        self.shareButtonNode.alpha = 1.0
        self.shareButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.shareButtonNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 0.0), to: .zero, duration: 0.2, additive: true)
        
        self.contentTitleNode.alpha = 1.0
        self.contentTitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.contentTitleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -10.0), to: .zero, duration: 0.2, additive: true)
        self.contentTitleNode.layer.animateScale(from: 0.85, to: 1.0, duration: 0.2)
        
        self.contentSubtitleNode.alpha = 1.0
        self.contentSubtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.contentSubtitleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -10.0), to: .zero, duration: 0.2, additive: true)
        self.contentSubtitleNode.layer.animateScale(from: 0.85, to: 1.0, duration: 0.2)
        
        self.contentGridNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        if let targetFrame = self.frameForPeerId(peerId), let (size, bottomInset) = self.validLayout {
            let clippedNode = ASDisplayNode()
            clippedNode.clipsToBounds = true
            clippedNode.cornerRadius = 16.0
            clippedNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.headerNode.frame.minY - 15.0), size: CGSize(width: size.width, height: size.height - bottomInset + 15.0))
            self.contentGridNode.view.superview?.insertSubview(clippedNode.view, aboveSubview: self.contentGridNode.view)
            
            clippedNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            let maskView = UIView()
            maskView.frame = clippedNode.bounds
            
            let maskImageView = UIImageView()
            maskImageView.image = generatePeersMaskImage()
            maskImageView.frame = maskView.bounds.offsetBy(dx: 0.0, dy: 36.0)
            maskView.addSubview(maskImageView)
            clippedNode.view.mask = maskView
            
            self.contentGridNode.alpha = 1.0
            self.contentGridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                    itemNode.layer.animateScale(from: 1.35, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak clippedNode] _ in
                        clippedNode?.view.removeFromSuperview()
                    })
                } else if let snapshotView = itemNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = itemNode.view.convert(itemNode.bounds, to: clippedNode.view)
                    
                    clippedNode.view.addSubview(snapshotView)
                    
                    itemNode.alpha = 0.0
                    let angle = targetFrame.center.angle(to: itemNode.position)
                    let distance = targetFrame.center.distance(to: itemNode.position)
                    let newDistance = distance * 2.8
                    let newPosition = snapshotView.center.offsetBy(distance: newDistance, inDirection: angle)
                    snapshotView.layer.animatePosition(from: newPosition, to: snapshotView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    snapshotView.layer.animateScale(from: 1.35, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak itemNode] _ in
                        itemNode?.alpha = 1.0
                    })
                    snapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, removeOnCompletion: false)
                }
            }
                        
            return targetFrame
        } else {
            return nil
        }
    }
    
    func animateOut(peerId: EnginePeer.Id, scrollDelta: CGFloat) -> CGRect? {
        self.headerNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.searchButtonNode.alpha = 0.0
        self.searchButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.searchButtonNode.layer.animatePosition(from: .zero, to: CGPoint(x: -20.0, y: 0.0), duration: 0.2, additive: true)
        
        self.shareButtonNode.alpha = 0.0
        self.shareButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.shareButtonNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 0.0), duration: 0.2, additive: true)
        
        self.contentTitleNode.alpha = 0.0
        self.contentTitleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.contentTitleNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -10.0), duration: 0.2, additive: true)
        self.contentTitleNode.layer.animateScale(from: 1.0, to: 0.85, duration: 0.3)
        
        self.contentSubtitleNode.alpha = 0.0
        self.contentSubtitleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.contentSubtitleNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -10.0), duration: 0.2, additive: true)
        self.contentSubtitleNode.layer.animateScale(from: 1.0, to: 0.85, duration: 0.3)
        
        self.contentGridNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        if let sourceFrame = self.frameForPeerId(peerId), let (size, bottomInset) = self.validLayout {
            let clippedNode = ASDisplayNode()
            clippedNode.clipsToBounds = true
            clippedNode.cornerRadius = 16.0
            clippedNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.headerNode.frame.minY - 15.0), size: CGSize(width: size.width, height: size.height - bottomInset + 15.0))
            self.contentGridNode.view.superview?.insertSubview(clippedNode.view, aboveSubview: self.contentGridNode.view)
            
            clippedNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            let maskView = UIView()
            maskView.frame = clippedNode.bounds
            
            let maskImageView = UIImageView()
            maskImageView.image = generatePeersMaskImage()
            maskImageView.frame = maskView.bounds.offsetBy(dx: 0.0, dy: 36.0)
            maskView.addSubview(maskImageView)
            clippedNode.view.mask = maskView
            
            self.contentGridNode.forEachItemNode { itemNode in
                if let snapshotView = itemNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = itemNode.view.convert(itemNode.bounds, to: clippedNode.view)
                    clippedNode.view.addSubview(snapshotView)
                    
                    if let itemNode = itemNode as? ShareControllerPeerGridItemNode, itemNode.peerId == peerId {
                        
                    } else {
                        let angle = sourceFrame.center.angle(to: itemNode.position)
                        let distance = sourceFrame.center.distance(to: itemNode.position)
                        let newDistance = distance * 2.8
                        let newPosition = snapshotView.center.offsetBy(distance: newDistance, inDirection: angle)
                        snapshotView.layer.animatePosition(from: snapshotView.center, to: newPosition, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    snapshotView.layer.animateScale(from: 1.0, to: 1.35, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
            
            clippedNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak clippedNode] _ in
                clippedNode?.view.removeFromSuperview()
            })
            
            self.contentGridNode.alpha = 0.0
            
            return sourceFrame
        } else {
            return nil
        }
    }
    
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = (size, bottomInset)
        
        let gridLayoutTransition: ContainedViewLayoutTransition
        if firstLayout {
            gridLayoutTransition = .immediate
            self.overrideGridOffsetTransition = transition
        } else {
            gridLayoutTransition = transition
            self.overrideGridOffsetTransition = nil
        }
        
        let (gridTopInset, itemWidth) = self.calculateMetrics(size: size)
        
        var scrollToItem: GridNodeScrollToItem?
        if let ensurePeerVisibleOnLayout = self.ensurePeerVisibleOnLayout {
            self.ensurePeerVisibleOnLayout = nil
            if let index = self.entries.firstIndex(where: { $0.peer.peerId == ensurePeerVisibleOnLayout }) {
                scrollToItem = GridNodeScrollToItem(index: index, position: .visible, transition: transition, directionHint: .up, adjustForSection: false)
            }
        }
        
        let gridSize = CGSize(width: size.width - 10.0, height: size.height)
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToItem, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 0.0, bottom: bottomInset, right: 0.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: gridLayoutTransition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        gridLayoutTransition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((size.width - gridSize.width) / 2.0), y: 0.0), size: gridSize))
        
        if firstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        guard let (size, _) = self.validLayout else {
            return
        }
        
        let actualTransition = self.overrideGridOffsetTransition ?? transition
        self.overrideGridOffsetTransition = nil
        
        let titleAreaHeight: CGFloat = 64.0
        
        let rawTitleOffset = -titleAreaHeight - presentationLayout.contentOffset.y
        let titleOffset = max(-titleAreaHeight, rawTitleOffset)
        
        let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: titleOffset), size: CGSize(width: size.width, height: 64.0))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        
        let titleSize = self.contentTitleNode.measure(size)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: 15.0), size: titleSize)
        transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
        
        let subtitleSize = self.contentSubtitleNode.updateLayout(CGSize(width: size.width - 44.0 * 2.0 - 8.0 * 2.0, height: titleAreaHeight))
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: 40.0), size: subtitleSize)
        var originalSubtitleFrame = self.contentSubtitleNode.frame
        originalSubtitleFrame.origin.x = subtitleFrame.origin.x
        originalSubtitleFrame.size = subtitleFrame.size
        self.contentSubtitleNode.frame = originalSubtitleFrame
        transition.updateFrame(node: self.contentSubtitleNode, frame: subtitleFrame)
          
        let titleButtonSize = CGSize(width: 44.0, height: 44.0)
        let searchButtonFrame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: titleButtonSize)
        transition.updateFrame(node: self.searchButtonNode, frame: searchButtonFrame)
        
        let shareButtonFrame = CGRect(origin: CGPoint(x: size.width - titleButtonSize.width - 12.0, y: 12.0), size: titleButtonSize)
        transition.updateFrame(node: self.shareButtonNode, frame: shareButtonFrame)
        transition.updateFrame(node: self.shareContainerNode, frame: CGRect(origin: CGPoint(), size: titleButtonSize))
        transition.updateFrame(node: self.shareReferenceNode, frame: CGRect(origin: CGPoint(), size: titleButtonSize))
        
        let segmentedSize = self.segmentedNode.updateLayout(.sizeToFit(maximumWidth: size.width - titleButtonSize.width * 2.0, minimumWidth: 160.0, height: 32.0), transition: transition)
        transition.updateFrame(node: self.segmentedNode, frame: CGRect(origin: CGPoint(x: floor((size.width - segmentedSize.width) / 2.0), y: 18.0), size: segmentedSize))
        
        let avatarButtonSize = CGSize(width: 36.0, height: 36.0)
        let avatarButtonFrame = CGRect(origin: CGPoint(x: size.width - avatarButtonSize.width - 20.0, y: 15.0), size: avatarButtonSize)
        transition.updateFrame(node: self.contentTitleAccountNode, frame: avatarButtonFrame)
        
        transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: titleOffset + titleAreaHeight), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        if rawTitleOffset.isLess(than: -titleAreaHeight) {
            self.contentSeparatorNode.alpha = 1.0
        } else {
            self.contentSeparatorNode.alpha = 0.0
        }
        
        self.contentOffsetUpdated?(presentationLayout.contentOffset.y, actualTransition)
    }
    
    func updateVisibleItemsSelection(animated: Bool) {
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: animated)
            }
        }
    }
    
    func updateFoundPeers() {
        self.foundPeers.set(.single(self.controllerInteraction.foundPeers))
    }
    
    func update() {
        self._tick += 1
    }
    
    func updateSelectedPeers(animated: Bool = true) {
        if self.segmentedValues != nil {
            self.contentTitleNode.isHidden = true
            self.contentSubtitleNode.isHidden = true
        } else {
            self.contentTitleNode.isHidden = false
            self.contentSubtitleNode.isHidden = false
            
            var subtitleText = self.strings.ShareMenu_SelectChats
            if !self.controllerInteraction.selectedPeers.isEmpty {
                subtitleText = self.controllerInteraction.selectedPeers.reduce("", { string, peer in
                    let text: String
                    if peer.peerId == self.accountPeer.id {
                        text = self.strings.DialogList_SavedMessages
                    } else {
                        text = peer.chatMainPeer?.displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder) ?? ""
                    }
                    
                    if !string.isEmpty {
                        return string + ", " + text
                    } else {
                        return string + text
                    }
                })
            }
            self.contentSubtitleNode.attributedText = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: self.theme.actionSheet.secondaryTextColor)
        }
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: animated)
            }
        }
    }
    
    @objc func searchPressed() {
        self.openSearch?()
    }
    
    @objc func sharePressed() {
        self.openShare?(self.shareReferenceNode, nil)
    }
        
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let nodes: [ASDisplayNode] = [self.searchButtonNode, self.shareButtonNode, self.contentTitleAccountNode]
        for node in nodes {
            let nodeFrame = node.frame
            if node.isHidden {
                continue
            }
            if let result = node.hitTest(point.offsetBy(dx: -nodeFrame.minX, dy: -nodeFrame.minY), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    @objc private func accountTapGesture(_ recognizer: UITapGestureRecognizer) {
        self.switchToAnotherAccount()
    }

    private var debugTapCounter: (Double, Int) = (0.0, 0)

    @objc private func debugTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let timestamp = CACurrentMediaTime()
            if self.debugTapCounter.0 < timestamp - 0.4 {
                self.debugTapCounter.0 = timestamp
                self.debugTapCounter.1 = 0
            }

            if self.debugTapCounter.0 >= timestamp - 0.4 {
                self.debugTapCounter.0 = timestamp
                self.debugTapCounter.1 += 1
            }

            if self.debugTapCounter.1 >= 10 {
                self.debugTapCounter.1 = 0

                self.debugAction()
            }
        }
    }
}

func generatePeersMaskImage() -> UIImage? {
    return generateImage(CGSize(width: 100.0, height: 100.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 16.0, dy: 16.0), cornerRadius: 16.0)
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: .zero, blur: 40.0, color: UIColor.white.cgColor)
        
        for _ in 0 ..< 10 {
            context.addPath(path.cgPath)
            context.fillPath()
        }
    })?.stretchableImage(withLeftCapWidth: 49, topCapHeight: 49)
}
