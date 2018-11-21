import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let detailsInset: CGFloat = 17.0
private let titleInset: CGFloat = 22.0

final class InstantPageDetailsContentNode : ASDisplayNode {
    private let account: Account
    private let strings: PresentationStrings
    private let theme: InstantPageTheme
    
    private let openMedia: (InstantPageMedia) -> Void
    private let openPeer: (PeerId) -> Void
    private let openUrl: (InstantPageUrlItem) -> Void
    
    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithNodes: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileNode] = [:]
    var visibleItemsWithNodes: [Int: InstantPageNode] = [:]
    
    var currentWebEmbedHeights: [Int : CGFloat] = [:]
    var currentExpandedDetails: [Int : Bool]?
    var currentDetailsItems: [InstantPageDetailsItem] = []
    
    var requestLayoutUpdate: ((Bool) -> Void)?
    
    var currentLayout: InstantPageLayout
    let contentSize: CGSize
    
    private var previousVisibleBounds: CGRect?
    
    init(account: Account, strings: PresentationStrings, theme: InstantPageTheme, items: [InstantPageItem], contentSize: CGSize, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void) {
        self.account = account
        self.strings = strings
        self.theme = theme
        
        self.openMedia = openMedia
        self.openPeer = openPeer
        self.openUrl = openUrl
        
        self.currentLayout = InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        self.contentSize = contentSize
        
        super.init()
        
        self.updateLayout()
    }
    
    private func updateLayout() {
        for (_, tileNode) in self.visibleTiles {
            tileNode.removeFromSupernode()
        }
        self.visibleTiles.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: contentSize.width)
        
        var currentDetailsItems: [InstantPageDetailsItem] = []
        var currentLayoutItemsWithViews: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int : Int] = [:]
        
        var expandedDetails: [Int : Bool] = [:]
        
        var detailsIndex = -1
        for item in self.currentLayout.items {
            if item.wantsNode {
                currentLayoutItemsWithViews.append(item)
                if let group = item.distanceThresholdGroup() {
                    let count: Int
                    if let currentCount = distanceThresholdGroupCount[Int(group)] {
                        count = currentCount
                    } else {
                        count = 0
                    }
                    distanceThresholdGroupCount[Int(group)] = count + 1
                }
                if let detailsItem = item as? InstantPageDetailsItem {
                    detailsIndex += 1
                    expandedDetails[detailsIndex] = detailsItem.initiallyExpanded
                    currentDetailsItems.append(detailsItem)
                }
            }
        }
        
        if self.currentExpandedDetails == nil {
            self.currentExpandedDetails = expandedDetails
        }
        
        self.currentLayoutTiles = currentLayoutTiles
        self.currentLayoutItemsWithNodes = currentLayoutItemsWithViews
        self.currentDetailsItems = currentDetailsItems
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
    }
    
    var effectiveContentSize: CGSize {
        var contentSize = self.contentSize
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            contentSize.height += -item.frame.height + (expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight)
        }
        return contentSize
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool = false) {
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
        self.previousVisibleBounds = visibleBounds
    
        var topNode: ASDisplayNode?
        let topTileNode = topNode
        if let scrollSubnodes = self.subnodes {
            for node in scrollSubnodes.reversed() {
                if let node = node as? InstantPageTileNode {
                    topNode = node
                    break
                }
            }
        }
        
        var collapseOffset: CGFloat = 0.0
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.3, curve: .spring)
        } else {
            transition = .immediate
        }
        
        var itemIndex = -1
        var embedIndex = -1
        var detailsIndex = -1
        
        for item in self.currentLayoutItemsWithNodes {
            itemIndex += 1
            if item is InstantPageWebEmbedItem {
                embedIndex += 1
            }
            if item is InstantPageDetailsItem {
                detailsIndex += 1
            }
            
            var itemThreshold: CGFloat = 0.0
            if let group = item.distanceThresholdGroup() {
                var count: Int = 0
                if let currentCount = self.distanceThresholdGroupCount[group] {
                    count = currentCount
                }
                itemThreshold = item.distanceThresholdWithGroupCount(count)
            }
            
            var itemFrame = item.frame.offsetBy(dx: 0.0, dy: -collapseOffset)
            var thresholdedItemFrame = itemFrame
            thresholdedItemFrame.origin.y -= itemThreshold
            thresholdedItemFrame.size.height += itemThreshold * 2.0
            
            if let detailsItem = item as? InstantPageDetailsItem, let expanded = self.currentExpandedDetails?[detailsIndex] {
                let height = expanded ? self.effectiveSizeForDetails(detailsItem).height : detailsItem.titleHeight
                collapseOffset += itemFrame.height - height
                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: height))
            }
            
            if visibleBounds.intersects(thresholdedItemFrame) {
                visibleItemIndices.insert(itemIndex)
                
                var itemNode = self.visibleItemsWithNodes[itemIndex]
                if let currentItemNode = itemNode {
                    if !item.matchesNode(currentItemNode) {
                        (currentItemNode as! ASDisplayNode).removeFromSupernode()
                        self.visibleItemsWithNodes.removeValue(forKey: itemIndex)
                        itemNode = nil
                    }
                }
                
                if itemNode == nil {
                    let itemIndex = itemIndex
                    let detailsIndex = detailsIndex
                    if let newNode = item.node(account: self.account, strings: self.strings, theme: theme, openMedia: { [weak self] media in
                        self?.openMedia(media)
                    }, openPeer: { [weak self] peerId in
                        self?.openPeer(peerId)
                    }, openUrl: { [weak self] url in
                        self?.openUrl(url)
                    }, updateWebEmbedHeight: { [weak self] height in
                    }, updateDetailsExpanded: { [weak self] expanded in
                        self?.updateDetailsExpanded(detailsIndex, expanded)
                    }, currentExpandedDetails: self.currentExpandedDetails) {
                        newNode.frame = itemFrame
                        newNode.updateLayout(size: itemFrame.size, transition: transition)
                        if let topNode = topNode {
                            self.insertSubnode(newNode, aboveSubnode: topNode)
                        } else {
                            self.insertSubnode(newNode, at: 0)
                        }
                        topNode = newNode
                        self.visibleItemsWithNodes[itemIndex] = newNode
                        itemNode = newNode
                        
                        if let itemNode = itemNode as? InstantPageDetailsNode {
                            itemNode.requestLayoutUpdate = { [weak self] animated in
                                self?.requestLayoutUpdate?(animated)
                            }
                        }
                    }
                } else {
                    if (itemNode as! ASDisplayNode).frame != itemFrame {
                        transition.updateFrame(node: (itemNode as! ASDisplayNode), frame: itemFrame)
                        itemNode?.updateLayout(size: itemFrame.size, transition: transition)
                    }
                }
                
                if let itemNode = itemNode as? InstantPageDetailsNode {
                    itemNode.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -itemNode.frame.minX, dy: -itemNode.frame.minY), animated: animated)
                }
            }
        }
        
        topNode = topTileNode
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            
            let tileFrame = effectiveFrameForTile(tile)
            var tileVisibleFrame = tileFrame
            tileVisibleFrame.origin.y -= 400.0
            tileVisibleFrame.size.height += 400.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) {
                visibleTileIndices.insert(tileIndex)
                
                if self.visibleTiles[tileIndex] == nil {
                    let tileNode = InstantPageTileNode(tile: tile, backgroundColor: theme.pageBackgroundColor)
                    tileNode.frame = tileFrame
                    if let topNode = topNode {
                        self.insertSubnode(tileNode, aboveSubnode: topNode)
                    } else {
                        self.insertSubnode(tileNode, at: 0)
                    }
                    topNode = tileNode
                    self.visibleTiles[tileIndex] = tileNode
                } else {
                    if visibleTiles[tileIndex]!.frame != tileFrame {
                        transition.updateFrame(node: self.visibleTiles[tileIndex]!, frame: tileFrame)
                    }
                }
            }
        }
        
        var removeTileIndices: [Int] = []
        for (index, tileNode) in self.visibleTiles {
            if !visibleTileIndices.contains(index) {
                removeTileIndices.append(index)
                tileNode.removeFromSupernode()
            }
        }
        for index in removeTileIndices {
            self.visibleTiles.removeValue(forKey: index)
        }
        
        var removeItemIndices: [Int] = []
        for (index, itemNode) in self.visibleItemsWithNodes {
            if !visibleItemIndices.contains(index) {
                removeItemIndices.append(index)
                (itemNode as! ASDisplayNode).removeFromSupernode()
            } else {
                var itemFrame = (itemNode as! ASDisplayNode).frame
                let itemThreshold: CGFloat = 200.0
                itemFrame.origin.y -= itemThreshold
                itemFrame.size.height += itemThreshold * 2.0
                itemNode.updateIsVisible(visibleBounds.intersects(itemFrame))
            }
        }
        for index in removeItemIndices {
            self.visibleItemsWithNodes.removeValue(forKey: index)
        }
    }
    
    private func updateWebEmbedHeight(_ index: Int, _ height: CGFloat) {
//        let currentHeight = self.currentWebEmbedHeights[index]
//        if height != currentHeight {
//            if let currentHeight = currentHeight, currentHeight > height {
//                return
//            }
//            self.currentWebEmbedHeights[index] = height
//
//            let signal: Signal<Void, NoError> = (.complete() |> delay(0.08, queue: Queue.mainQueue()))
//            self.updateLayoutDisposable.set(signal.start(completed: { [weak self] in
//                if let strongSelf = self {
//                    strongSelf.updateLayout()
//                    strongSelf.updateVisibleItems()
//                }
//            }))
//        }
    }
    
    func updateDetailsExpanded(_ index: Int, _ expanded: Bool, animated: Bool = true, requestLayout: Bool = true) {
        if var currentExpandedDetails = self.currentExpandedDetails {
            currentExpandedDetails[index] = expanded
            self.currentExpandedDetails = currentExpandedDetails
        }
        self.requestLayoutUpdate?(animated)
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        for (_, itemNode) in self.visibleItemsWithNodes {
            if let transitionNode = itemNode.transitionNode(media: media) {
                return transitionNode
            }
        }
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        for (_, itemNode) in self.visibleItemsWithNodes {
            itemNode.updateHiddenMedia(media: media)
        }
    }
    
    private func scrollableContentOffset(item: InstantPageScrollableItem) -> CGPoint {
        var contentOffset = CGPoint()
        for (_, itemNode) in self.visibleItemsWithNodes {
            if let itemNode = itemNode as? InstantPageScrollableNode, itemNode.item === item {
                contentOffset = itemNode.contentOffset
                break
            }
        }
        return contentOffset
    }
    
    func nodeForDetailsItem(_ item: InstantPageDetailsItem) -> InstantPageDetailsNode? {
        for (_, itemNode) in self.visibleItemsWithNodes {
            if let detailsNode = itemNode as? InstantPageDetailsNode, detailsNode.item === item {
                return detailsNode
            }
        }
        return nil
    }
    
    private func effectiveSizeForDetails(_ item: InstantPageDetailsItem) -> CGSize {
        if let node = nodeForDetailsItem(item) {
            return CGSize(width: item.frame.width, height: node.effectiveContentSize.height + item.titleHeight)
        } else {
            return item.frame.size
        }
    }
    
    private func effectiveFrameForTile(_ tile: InstantPageTile) -> CGRect {
        let layoutOrigin = tile.frame.origin
        var origin = layoutOrigin
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        return CGRect(origin: origin, size: tile.frame.size)
    }
    
    fileprivate func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        let layoutOrigin = item.frame.origin
        var origin = layoutOrigin
        
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        
        if let item = item as? InstantPageDetailsItem {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
            return CGRect(origin: origin, size: CGSize(width: item.frame.width, height: height))
        } else {
            return CGRect(origin: origin, size: item.frame.size)
        }
    }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        for item in self.currentLayout.items {
            let itemFrame = self.effectiveFrameForItem(item)
            if itemFrame.contains(location) {
                if let item = item as? InstantPageTextItem, item.selectable {
                    return (item, CGPoint(x: itemFrame.minX - item.frame.minX, y: itemFrame.minY - item.frame.minY))
                } else if let item = item as? InstantPageScrollableItem {
                    let contentOffset = scrollableContentOffset(item: item)
                    if let (textItem, parentOffset) = item.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY)) {
                        return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x - contentOffset.x, dy: parentOffset.y))
                    }
                } else if let item = item as? InstantPageDetailsItem {
                    for (_, itemNode) in self.visibleItemsWithNodes {
                        if let itemNode = itemNode as? InstantPageDetailsNode, itemNode.item === item {
                            if let (textItem, parentOffset) = itemNode.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX, dy: -itemFrame.minY)) {
                                return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x, dy: parentOffset.y))
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    
    func tapActionAtPoint(_ point: CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction {
        for item in self.currentLayout.items {
            let frame = self.effectiveFrameForItem(item)
            if frame.contains(point) {
                if item is InstantPagePeerReferenceItem {
                    return .fail
                } else if item is InstantPageAudioItem {
                    return .fail
                } else if item is InstantPageArticleItem {
                    return .fail
                } else if item is InstantPageFeedbackItem {
                    return .fail
                } else if let item = item as? InstantPageDetailsItem {
                    for (_, itemNode) in self.visibleItemsWithNodes {
                        if let itemNode = itemNode as? InstantPageDetailsNode, itemNode.item === item {
                            return itemNode.tapActionAtPoint(point.offsetBy(dx: -itemNode.frame.minX, dy: -itemNode.frame.minY))
                        }
                    }
                }
                break
            }
        }
        return .waitForSingleTap
    }
}

final class InstantPageDetailsNode: ASDisplayNode, InstantPageNode {
    private let account: Account
    private let strings: PresentationStrings
    private let theme: InstantPageTheme
    let item: InstantPageDetailsItem
    
    private let titleTile: InstantPageTile
    private let titleTileNode: InstantPageTileNode
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let arrowNode: InstantPageDetailsArrowNode
    let separatorNode: ASDisplayNode
    let contentNode: InstantPageDetailsContentNode
    
    private let updateExpanded: (Bool) -> Void
    var expanded: Bool
    
    var previousNode: InstantPageDetailsNode?
    
    var requestLayoutUpdate: ((Bool) -> Void)?
    
    init(account: Account, strings: PresentationStrings, theme: InstantPageTheme, item: InstantPageDetailsItem, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, currentlyExpanded: Bool?, updateDetailsExpanded: @escaping (Bool) -> Void) {
        self.account = account
        self.strings = strings
        self.theme = theme
        self.item = item
        
        self.updateExpanded = updateDetailsExpanded
        
        let frame = item.frame
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.titleTile = InstantPageTile(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: item.titleHeight))
        self.titleTile.items.append(contentsOf: item.titleItems)
        self.titleTileNode = InstantPageTileNode(tile: self.titleTile, backgroundColor: .clear)
        
        if let expanded = currentlyExpanded {
            self.expanded = expanded
        } else {
            self.expanded = item.initiallyExpanded
        }
        
        self.arrowNode = InstantPageDetailsArrowNode(color: theme.controlColor, open: self.expanded)
        self.separatorNode = ASDisplayNode()
        
        self.contentNode = InstantPageDetailsContentNode(account: account, strings: strings, theme: theme, items: item.items, contentSize: CGSize(width: item.frame.width, height: item.frame.height - item.titleHeight), openMedia: openMedia, openPeer: openPeer, openUrl: openUrl)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.contentNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleTileNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.separatorNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    strongSelf.separatorNode.alpha = 0.0
                    if let previousSeparator = strongSelf.previousNode?.separatorNode {
                        previousSeparator.alpha = 0.0
                    }
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    strongSelf.separatorNode.alpha = 1.0
                    strongSelf.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    if let previousSeparator = strongSelf.previousNode?.separatorNode {
                        previousSeparator.alpha = 1.0
                        previousSeparator.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.contentNode.requestLayoutUpdate = { [weak self] animated in
            self?.requestLayoutUpdate?(animated)
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    @objc func buttonPressed() {
        self.setExpanded(!self.expanded, animated: true)
        self.updateExpanded(expanded)
    }
    
    func setExpanded(_ expanded: Bool, animated: Bool) {
        self.expanded = expanded
        self.arrowNode.setOpen(expanded, animated: animated)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset = detailsInset + self.item.safeInset
        
        self.titleTileNode.frame = self.titleTile.frame
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: self.item.titleHeight + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: self.item.titleHeight))
        self.arrowNode.frame = CGRect(x: inset, y: floorToScreenPixels((self.item.titleHeight - 8.0) / 2.0) + 1.0, width: 13.0, height: 8.0)
        self.contentNode.frame = CGRect(x: 0.0, y: self.item.titleHeight, width: size.width, height: self.item.frame.height - self.item.titleHeight)
        
        let lineSize = CGSize(width: self.frame.width - inset, height: UIScreenPixel)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: self.item.rtl ? 0.0 : inset, y: self.item.titleHeight - lineSize.height), size: lineSize)
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return self.contentNode.transitionNode(media: media)
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.contentNode.updateHiddenMedia(media: media)
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.arrowNode.color = theme.controlColor
        self.separatorNode.backgroundColor = theme.controlColor
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool) {
        if self.bounds.height > self.item.titleHeight {
            self.contentNode.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -self.contentNode.frame.minX, dy: -self.contentNode.frame.minY), animated: animated)
        }
    }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        if self.titleTileNode.frame.contains(location) {
            for case let item as InstantPageTextItem in self.item.titleItems {
                if item.frame.contains(location) {
                    return (item, self.titleTileNode.frame.origin)
                }
            }
        }
        else if let (textItem, parentOffset) = self.contentNode.textItemAtLocation(location.offsetBy(dx: -self.contentNode.frame.minX, dy: -self.contentNode.frame.minY)) {
            return (textItem, self.contentNode.frame.origin.offsetBy(dx: parentOffset.x, dy: parentOffset.y))
        }
        return nil
    }
    
    func tapActionAtPoint(_ point: CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction {
        if self.titleTileNode.frame.contains(point) {
            if self.item.linkSelectionRects(at: point).isEmpty {
                return .fail
            }
        } else if self.contentNode.frame.contains(point) {
            return self.contentNode.tapActionAtPoint(_: point.offsetBy(dx: -self.contentNode.frame.minX, dy: -self.contentNode.frame.minY))
        }
        return .waitForSingleTap
    }
    
    var effectiveContentSize: CGSize {
        return self.contentNode.effectiveContentSize
    }
    
    func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        return self.contentNode.effectiveFrameForItem(item).offsetBy(dx: 0.0, dy: self.item.titleHeight)
    }
}

private final class InstantPageDetailsArrowNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

final class InstantPageDetailsArrowNode : ASDisplayNode {
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    private (set) var open: Bool
    
    private var progress: CGFloat = 0.0
    private var targetProgress: CGFloat?
    
    private var displayLink: CADisplayLink?
    
    init(color: UIColor, open: Bool) {
        self.color = color
        self.open = open
        self.progress = open ? 1.0 : 0.0
        
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
        
        class DisplayLinkProxy: NSObject {
            weak var target: InstantPageDetailsArrowNode?
            init(target: InstantPageDetailsArrowNode) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink?.isPaused = true
        self.displayLink?.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    func setOpen(_ open: Bool, animated: Bool) {
        self.open = open
        let openProgress: CGFloat = open ? 1.0 : 0.0
        if animated {
            self.targetProgress = openProgress
            self.displayLink?.isPaused = false
        } else {
            self.progress = openProgress
            self.targetProgress = nil
            self.displayLink?.isPaused = true
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        if self.targetProgress != nil {
            self.displayLink?.isPaused = false
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        self.displayLink?.isPaused = true
    }
    
    private func displayLinkEvent() {
        if let targetProgress = self.targetProgress {
            let sign = CGFloat(targetProgress - self.progress > 0 ? 1 : -1)
            self.progress += 0.14 * sign
            if sign > 0 && self.progress > targetProgress {
                self.progress = 1.0
                self.targetProgress = nil
                self.displayLink?.isPaused = true
            } else if sign < 0 && self.progress < targetProgress {
                self.progress = 0.0
                self.targetProgress = nil
                self.displayLink?.isPaused = true
            }
        }
        
        self.setNeedsDisplay()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantPageDetailsArrowNodeParameters(color: self.color, progress: self.progress)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let parameters = parameters as? InstantPageDetailsArrowNodeParameters {
            context.setStrokeColor(parameters.color.cgColor)
            context.setLineCap(.round)
            context.setLineWidth(2.0)
            
            context.move(to: CGPoint(x: 1.0, y: 1.0 + 5.0 * parameters.progress))
            context.addLine(to: CGPoint(x: 6.0, y: 6.0 - 5.0 * parameters.progress))
            context.addLine(to: CGPoint(x: 11.0, y: 1.0 + 5.0 * parameters.progress))
            context.strokePath()
        }
    }
}
