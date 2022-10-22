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

private struct ShareTopicEntry: Comparable, Identifiable {
    let index: Int32
    let peer: EngineRenderedPeer
    let id: Int64
    let threadData: MessageHistoryThreadData
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    var stableId: Int64 {
        return self.id
    }
    
    static func ==(lhs: ShareTopicEntry, rhs: ShareTopicEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.threadData != rhs.threadData {
            return false
        }
        
        return true
    }
    
    static func <(lhs: ShareTopicEntry, rhs: ShareTopicEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, interfaceInteraction: ShareControllerInteraction) -> GridItem {
        return ShareTopicGridItem(context: context, theme: self.theme, strings: self.strings, peer: self.peer, id: self.id, threadInfo: self.threadData, controllerInteraction: interfaceInteraction)
    }
}

private struct ShareGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let animated: Bool
}

private func preparedGridEntryTransition(context: AccountContext, from fromEntries: [ShareTopicEntry], to toEntries: [ShareTopicEntry], interfaceInteraction: ShareControllerInteraction) -> ShareGridTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interfaceInteraction: interfaceInteraction)) }
    
    return ShareGridTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: false)
}

private class CancelButtonNode: ASDisplayNode {
    let buttonNode: HighlightTrackingButtonNode
    private let arrowNode: ASImageNode
    private let labelNode: ImmediateTextNode
        
    var theme: PresentationTheme {
        didSet {
            self.updateThemeAndStrings()
        }
    }
    private let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.addSubnode(self.arrowNode)
        self.buttonNode.addSubnode(self.labelNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.arrowNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.arrowNode.alpha = 0.4
                strongSelf.labelNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.labelNode.alpha = 0.4
            } else {
                strongSelf.arrowNode.alpha = 1.0
                strongSelf.arrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                strongSelf.labelNode.alpha = 1.0
                strongSelf.labelNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.updateThemeAndStrings()
    }
    
    func updateThemeAndStrings() {
        self.labelNode.attributedText = NSAttributedString(string: self.strings.Common_Back, font: Font.regular(17.0), textColor: self.theme.rootController.navigationBar.accentTextColor)
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: 120.0, height: 56.0))
        
        self.buttonNode.frame = CGRect(origin: .zero, size: CGSize(width: labelSize.width + 16.0, height: self.buttonNode.frame.height))
        self.arrowNode.image = NavigationBarTheme.generateBackArrowImage(color: self.theme.rootController.navigationBar.accentTextColor)
        if let image = self.arrowNode.image {
            self.arrowNode.frame = CGRect(origin: self.arrowNode.frame.origin, size: image.size)
        }
        self.labelNode.frame = CGRect(origin: self.labelNode.frame.origin, size: labelSize)
        self.buttonNode.subnodeTransform = CATransform3DMakeTranslation(11.0, 0.0, 0.0)
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        self.buttonNode.frame = CGRect(origin: .zero, size: CGSize(width: self.buttonNode.frame.width, height: constrainedSize.height))
        self.arrowNode.frame = CGRect(origin: CGPoint(x: -19.0, y: floorToScreenPixels((constrainedSize.height - self.arrowNode.frame.size.height) / 2.0)), size: self.arrowNode.frame.size)
        self.labelNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((constrainedSize.height - self.labelNode.frame.size.height) / 2.0)), size: self.labelNode.frame.size)

        return CGSize(width: self.buttonNode.frame.width, height: 56.0)
    }
}

final class ShareTopicsContainerNode: ASDisplayNode, ShareContentContainerNode {
    func setEnsurePeerVisibleOnLayout(_ peerId: TelegramCore.EnginePeer.Id?) {
        
    }
    
    func updateSelectedPeers(animated: Bool) {
        
    }
    
    private let sharedContext: SharedAccountContext
    private let context: AccountContext
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let controllerInteraction: ShareControllerInteraction
            
    private let disposable = MetaDisposable()
    private var entries: [ShareTopicEntry] = []
    private var enqueuedTransitions: [(ShareGridTransaction, Bool)] = []
    
    let contentGridNode: GridNode
    private let headerNode: ASDisplayNode
    private let contentTitleNode: ASTextNode
    private let contentSubtitleNode: ASTextNode
    private let backNode: CancelButtonNode
    
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
        
    private var validLayout: (CGSize, CGFloat)?
    private var overrideGridOffsetTransition: ContainedViewLayoutTransition?
    
    let topicsValue = Promise<[EngineChatList.Item]>()
    
    var backPressed: () -> Void = {}
    
    init(sharedContext: SharedAccountContext, context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EnginePeer, topics: Signal<EngineChatList, NoError>, controllerInteraction: ShareControllerInteraction) {
        self.sharedContext = sharedContext
        self.context = context
        self.theme = theme
        self.strings = strings
        self.controllerInteraction = controllerInteraction
        
        self.topicsValue.set(topics
        |> map {
            return $0.items
        })
        
        let items: Signal<[ShareTopicEntry], NoError> = self.topicsValue.get()
        |> map { topics -> [ShareTopicEntry] in
            var entries: [ShareTopicEntry] = []
            var index: Int32 = 0
            
            for topic in topics {
                if case let .forum(_, _, threadId, _, _) = topic.index, let threadData = topic.threadData {
                    entries.append(ShareTopicEntry(index: index, peer: EngineRenderedPeer(peer: peer), id: threadId, threadData: threadData, theme: theme, strings: strings))
                    index += 1
                }
            }
            return entries
        }
        
        self.contentGridNode = GridNode()
        self.headerNode = ASDisplayNode()
        
        self.contentTitleNode = ASTextNode()
        self.contentTitleNode.maximumNumberOfLines = 1
        self.contentTitleNode.attributedText = NSAttributedString(string: peer.compactDisplayTitle, font: Font.medium(20.0), textColor: self.theme.actionSheet.primaryTextColor)
        self.contentTitleNode.textAlignment = .center
        
        self.contentSubtitleNode = ASTextNode()
        self.contentSubtitleNode.maximumNumberOfLines = 1
        self.contentSubtitleNode.isUserInteractionEnabled = false
        self.contentSubtitleNode.displaysAsynchronously = false
        self.contentSubtitleNode.truncationMode = .byTruncatingTail
        self.contentSubtitleNode.attributedText = NSAttributedString(string: strings.ShareMenu_SelectTopic, font: subtitleFont, textColor: self.theme.actionSheet.secondaryTextColor)
                           
        self.backNode = CancelButtonNode(theme: theme, strings: strings)
        
        super.init()
        
        self.addSubnode(self.contentGridNode)
        self.addSubnode(self.headerNode)
        
        self.headerNode.addSubnode(self.contentTitleNode)
        self.headerNode.addSubnode(self.contentSubtitleNode)
        self.headerNode.addSubnode(self.backNode)
                
        let previousItems = Atomic<[ShareTopicEntry]?>(value: [])
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
        
        self.backNode.buttonNode.addTarget(self, action: #selector(self.backButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    @objc private func backButtonPressed() {
        self.backPressed()
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
        
        let minimallyRevealedRowCount: CGFloat = 3.7
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let gridTopInset = max(0.0, size.height - floor(initiallyRevealedRowCount * itemWidth) - 14.0)
        return (gridTopInset, itemWidth)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func animateIn(sourceFrame: CGRect, scrollDelta: CGFloat) {
        self.headerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.backNode.alpha = 1.0
        self.backNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.backNode.layer.animatePosition(from: CGPoint(x: 20.0, y: 0.0), to: .zero, duration: 0.2, additive: true)
        
        self.contentTitleNode.alpha = 1.0
        self.contentTitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.contentTitleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 10.0), to: .zero, duration: 0.2, additive: true)
        self.contentTitleNode.layer.animateScale(from: 0.85, to: 1.0, duration: 0.2)
        
        self.contentSubtitleNode.alpha = 1.0
        self.contentSubtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.contentSubtitleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 10.0), to: .zero, duration: 0.2, additive: true)
        self.contentSubtitleNode.layer.animateScale(from: 0.85, to: 1.0, duration: 0.2)
        
        self.contentGridNode.layer.animatePosition(from: CGPoint(x: 0.0, y: scrollDelta), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        self.contentGridNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        self.contentGridNode.forEachItemNode { itemNode in
            itemNode.layer.animatePosition(from: sourceFrame.center, to: itemNode.position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            itemNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut(targetFrame: CGRect, scrollDelta: CGFloat, completion: @escaping () -> Void = {}) {
        self.headerNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.backNode.alpha = 0.0
        self.backNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.backNode.layer.animatePosition(from: .zero, to: CGPoint(x: 20.0, y: 0.0), duration: 0.2, additive: true)
        
        self.contentTitleNode.alpha = 0.0
        self.contentTitleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.contentTitleNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 10.0), duration: 0.2, additive: true)
        self.contentTitleNode.layer.animateScale(from: 1.0, to: 0.85, duration: 0.2)
        
        self.contentSubtitleNode.alpha = 0.0
        self.contentSubtitleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        self.contentSubtitleNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 10.0), duration: 0.2, additive: true)
        self.contentSubtitleNode.layer.animateScale(from: 1.0, to: 0.85, duration: 0.2)
        
        self.contentGridNode.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: scrollDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.contentGridNode.alpha = 0.0
        self.contentGridNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
            completion()
        })
        
        self.contentGridNode.forEachItemNode { itemNode in
            itemNode.layer.animatePosition(from: itemNode.position, to: targetFrame.center, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            itemNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
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
        
        let scrollToItem: GridNodeScrollToItem? = nil
        
        let delta = bottomInset
        var gridSize = CGSize(width: size.width - 12.0, height: size.height)
        gridSize.height -= delta
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToItem, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: gridTopInset, left: 0.0, bottom: 0.0, right: 0.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: gridLayoutTransition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        gridLayoutTransition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((size.width - gridSize.width) / 2.0), y: 0.0), size: gridSize))
        
        if firstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let nodes: [ASDisplayNode] = [self.backNode]
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
        
        let backSize = self.backNode.measure(CGSize(width: size.width, height: 56.0))
        let backFrame = CGRect(origin: CGPoint(x: 20.0, y: 6.0), size: CGSize(width: backSize.width, height: 56.0))
        transition.updateFrame(node: self.backNode, frame: backFrame)
        
        let titleSize = self.contentTitleNode.measure(CGSize(width: size.width - (backSize.width * 2.0 + 40.0), height: size.height))
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: 15.0), size: titleSize)
        transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
        
        let subtitleSize = self.contentSubtitleNode.measure(CGSize(width: size.width - 44.0 * 2.0 - 8.0 * 2.0, height: titleAreaHeight))
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: 40.0), size: subtitleSize)
        var originalSubtitleFrame = self.contentSubtitleNode.frame
        originalSubtitleFrame.origin.x = subtitleFrame.origin.x
        originalSubtitleFrame.size = subtitleFrame.size
        self.contentSubtitleNode.frame = originalSubtitleFrame
        transition.updateFrame(node: self.contentSubtitleNode, frame: subtitleFrame)
        

        
        self.contentOffsetUpdated?(presentationLayout.contentOffset.y, actualTransition)
    }
}
