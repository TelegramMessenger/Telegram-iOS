import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let detailsHeaderHeight: CGFloat = 44.0
private let detailsInset: CGFloat = 17.0
private let titleInset: CGFloat = 22.0

final class InstantPageDetailsContentNode : ASDisplayNode {
    private let account: Account
    private let strings: PresentationStrings
    private let theme: InstantPageTheme
    
    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithNodes: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileNode] = [:]
    var visibleItemsWithNodes: [Int: InstantPageNode] = [:]
    
    var currentLayout: InstantPageLayout
    let contentSize: CGSize
    
    init(account: Account, strings: PresentationStrings, theme: InstantPageTheme, items: [InstantPageItem], contentSize: CGSize) {
        self.account = account
        self.strings = strings
        self.theme = theme
        
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
        
        var currentLayoutItemsWithViews: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int : Int] = [:]
        
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
            }
        }
        
        self.currentLayoutTiles = currentLayoutTiles
        self.currentLayoutItemsWithNodes = currentLayoutItemsWithViews
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
    }
    
    func updateVisibleItems() {
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
        let visibleBounds = self.bounds // self.scrollNode.view.bounds
        
        var topNode: ASDisplayNode?
        if let scrollSubnodes = self.subnodes {
            for node in scrollSubnodes.reversed() {
                if let node = node as? InstantPageTileNode {
                    topNode = node
                    break
                }
            }
        }
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            var tileVisibleFrame = tile.frame
            tileVisibleFrame.origin.y -= 400.0
            tileVisibleFrame.size.height += 400.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) {
                visibleTileIndices.insert(tileIndex)
                
                if visibleTiles[tileIndex] == nil {
                    let tileNode = InstantPageTileNode(tile: tile, backgroundColor: .clear)
                    tileNode.frame = tile.frame
                    if let topNode = topNode {
                        self.insertSubnode(tileNode, aboveSubnode: topNode)
                    } else {
                        self.insertSubnode(tileNode, at: 0)
                    }
                    topNode = tileNode
                    self.visibleTiles[tileIndex] = tileNode
                }
            }
        }
        
        var itemIndex = -1
        for item in self.currentLayoutItemsWithNodes {
            itemIndex += 1
            var itemThreshold: CGFloat = 0.0
            if let group = item.distanceThresholdGroup() {
                var count: Int = 0
                if let currentCount = self.distanceThresholdGroupCount[group] {
                    count = currentCount
                }
                itemThreshold = item.distanceThresholdWithGroupCount(count)
            }
            var itemFrame = item.frame
            itemFrame.origin.y -= itemThreshold
            itemFrame.size.height += itemThreshold * 2.0
            if visibleBounds.intersects(itemFrame) {
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
                    if let itemNode = item.node(account: self.account, strings: self.strings, theme: self.theme, openMedia: { [weak self] media in
                        //self?.openMedia(media)
                    }, openPeer: { [weak self] peerId in
                        //self?.openPeer(peerId)
                    }, openUrl: { [weak self] url in
                        //self?.openUrl(url)
                    }, updateWebEmbedHeight: { [weak self] height in
                        //self?.updateWebEmbedHeight(key, height)
                    }, updateDetailsExpanded: { _ in
                    }) {
                        itemNode.frame = item.frame
                        if let topNode = topNode {
                            self.insertSubnode(itemNode, aboveSubnode: topNode)
                        } else {
                            self.insertSubnode(itemNode, at: 0)
                        }
                        topNode = itemNode
                        self.visibleItemsWithNodes[itemIndex] = itemNode
                    }
                } else {
                    if (itemNode as! ASDisplayNode).frame != item.frame {
                        (itemNode as! ASDisplayNode).frame = item.frame
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
    private let separatorNode: ASDisplayNode
    private let contentNode: InstantPageDetailsContentNode
    
    private let updateExpanded: (Bool) -> Void
    var expanded: Bool
    
    init(account: Account, strings: PresentationStrings, theme: InstantPageTheme, item: InstantPageDetailsItem, updateDetailsExpanded: @escaping (Bool) -> Void) {
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
        
        self.titleTile = InstantPageTile(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: detailsHeaderHeight))
        self.titleTileNode = InstantPageTileNode(tile: self.titleTile, backgroundColor: .clear)
    
        let titleItems = layoutTextItemWithString(item.title, boundingWidth: frame.size.width - detailsInset * 2.0 - titleInset, offset: CGPoint(x: detailsInset + titleInset, y: 0.0)).0
        var offset: CGFloat?
        for var item in titleItems {
            var itemOffset = floorToScreenPixels((detailsHeaderHeight - item.frame.height) / 2.0)
            if item is InstantPageTextItem {
                offset = itemOffset
            } else if let offset = offset {
                itemOffset = offset
            }
            item.frame = item.frame.offsetBy(dx: 0.0, dy: itemOffset)
        }
        self.titleTile.items.append(contentsOf: titleItems)
        
        self.arrowNode = InstantPageDetailsArrowNode(color: theme.controlColor, open: item.initiallyExpanded)
        self.separatorNode = ASDisplayNode()
        
        self.contentNode = InstantPageDetailsContentNode(account: account, strings: strings, theme: theme, items: item.items, contentSize: CGSize(width: item.frame.width, height: item.frame.height))
        
        self.expanded = item.initiallyExpanded
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleTileNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.contentNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    if strongSelf.separatorNode.frame.minY < strongSelf.highlightedBackgroundNode.frame.maxY {
                        strongSelf.separatorNode.alpha = 0.0
                    }
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    if strongSelf.separatorNode.alpha < 1.0 {
                        strongSelf.separatorNode.alpha = 1.0
                        strongSelf.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    @objc func buttonPressed() {
        self.setExpanded(!self.expanded, animated: true)
    }
    
    func setExpanded(_ expanded: Bool, animated: Bool) {
        self.expanded = expanded
        self.arrowNode.setOpen(expanded, animated: animated)
        self.updateExpanded(expanded)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let size = layout.size
        let inset = detailsInset + self.item.safeInset
        
        let lineSize = CGSize(width: frame.width - inset, height: UIScreenPixel)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: item.rtl ? 0.0 : inset, y: size.height - lineSize.height), size: lineSize))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset = detailsInset + self.item.safeInset
        
        self.titleTileNode.frame = self.titleTile.frame
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: detailsHeaderHeight + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: detailsHeaderHeight))
        self.arrowNode.frame = CGRect(x: inset, y: floorToScreenPixels((detailsHeaderHeight - 8.0) / 2.0) + 1.0, width: 13.0, height: 8.0)
        self.contentNode.frame = CGRect(x: 0.0, y: detailsHeaderHeight, width: size.width, height: self.item.frame.height - detailsHeaderHeight)
        
        let lineSize = CGSize(width: frame.width - inset, height: UIScreenPixel)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: item.rtl ? 0.0 : inset, y: size.height - lineSize.height), size: lineSize)
        
        self.contentNode.updateVisibleItems()
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.arrowNode.color = theme.controlColor
        self.separatorNode.backgroundColor = theme.controlColor
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
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
