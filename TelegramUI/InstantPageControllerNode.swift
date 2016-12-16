import Foundation
import TelegramCore
import AsyncDisplayKit
import Display

final class InstantPageControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let account: Account
    
    private var webPage: TelegramMediaWebpage?
    
    private var containerLayout: ContainerViewLayout?
    private let scrollNode: ASScrollNode
    
    var currentLayout: InstantPageLayout?
    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithViews: [InstantPageItem] = []
    var currentLayoutItemsWithLinks: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileNode] = [:]
    var visibleItemsWithViews: [Int: InstantPageNode] = [:]
    var visibleLinkSelectionViews: [Int: InstantPageLinkSelectionView] = [:]
    
    var previousContentOffset: CGPoint?
    var isDeceleratingBecauseOfDragging = false
    
    init(account: Account) {
        self.account = account
        
        self.scrollNode = ASScrollNode()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = .white
        self.addSubnode(self.scrollNode)
        self.scrollNode.view.delegate = self
    }
    
    func updateWebPage(_ webPage: TelegramMediaWebpage?) {
        if self.webPage != webPage {
            self.webPage = webPage
            
            self.currentLayout = nil
            self.updateLayout()
            
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            if let containerLayout = self.containerLayout {
                self.containerLayoutUpdated(containerLayout, navigationBarHeight: 0.0, transition: .immediate)
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        
        if self.scrollNode.bounds.size != layout.size {
            if !self.scrollNode.bounds.size.width.isEqual(to: layout.size.width) {
                self.updateLayout()
            }
            self.scrollNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            //_scrollViewHeader.frame = CGRectMake(0.0f, -2000.0f, bounds.size.width, 2000.0f);
            //self.scrollView.contentInset = UIEdgeInsetsMake(_statusBarHeight + 44.0f, 0.0f, 0.0f, 0.0f);
            if self.visibleItemsWithViews.isEmpty && self.visibleTiles.isEmpty {
                self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: 0.0)
            }
            self.updateVisibleItems()
            self.updateNavigationBar()
        }
    }
    
    private func updateLayout() {
        guard let containerLayout = self.containerLayout, let webPage = self.webPage else {
            return
        }
        
        let currentLayout = instantPageLayoutForWebPage(webPage, boundingWidth: containerLayout.size.width)
        
        for (_, tileNode) in self.visibleTiles {
            tileNode.removeFromSupernode()
        }
        self.visibleTiles.removeAll()
        
        for (_, linkView) in self.visibleLinkSelectionViews {
            linkView.removeFromSuperview()
        }
        self.visibleLinkSelectionViews.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: containerLayout.size.width)
        
        var currentLayoutItemsWithViews: [InstantPageItem] = []
        var currentLayoutItemsWithLinks: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int: Int] = [:]
        
        for item in currentLayout.items {
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
            if item.hasLinks {
                currentLayoutItemsWithLinks.append(item)
            }
        }
        
        self.currentLayout = currentLayout
        self.currentLayoutTiles = currentLayoutTiles
        self.currentLayoutItemsWithViews = currentLayoutItemsWithViews
        self.currentLayoutItemsWithLinks = currentLayoutItemsWithLinks
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
        
        self.scrollNode.view.contentSize = currentLayout.contentSize
    }
    
    func updateVisibleItems() {
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        var visibleItemLinkIndices = Set<Int>()
        
        var visibleBounds = self.scrollNode.view.bounds
        
        var topNode: ASDisplayNode?
        for node in self.scrollNode.subnodes.reversed() {
            if let node = node as? InstantPageTileNode {
                topNode = node
                break
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
                    let tileNode = InstantPageTileNode(tile: tile)
                    tileNode.frame = tile.frame
                    if let topNode = topNode {
                        self.scrollNode.insertSubnode(tileNode, aboveSubnode: topNode)
                    } else {
                        self.scrollNode.insertSubnode(tileNode, at: 0)
                    }
                    topNode = tileNode
                    self.visibleTiles[tileIndex] = tileNode
                }
            }
        }
        
        var itemIndex = -1
        for item in self.currentLayoutItemsWithViews {
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
                
                var itemNode = self.visibleItemsWithViews[itemIndex]
                if let currentItemNode = itemNode {
                    if !item.matchesNode(currentItemNode) {
                        (currentItemNode as! ASDisplayNode).removeFromSupernode()
                        self.visibleItemsWithViews.removeValue(forKey: itemIndex)
                        itemNode = nil
                    }
                }
                
                if itemNode == nil {
                    if let itemNode = item.node(account: self.account) {
                        (itemNode as! ASDisplayNode).frame = item.frame
                        if let topNode = topNode {
                            self.scrollNode.insertSubnode(itemNode as! ASDisplayNode, aboveSubnode: topNode)
                        } else {
                            self.scrollNode.insertSubnode(itemNode as! ASDisplayNode, at: 0)
                        }
                        topNode = itemNode as! ASDisplayNode
                        self.visibleItemsWithViews[itemIndex] = itemNode
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
        for (index, itemNode) in self.visibleItemsWithViews {
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
            self.visibleItemsWithViews.removeValue(forKey: index)
        }
        
        /*
        itemIndex = -1;
        for (id<TGInstantPageLayoutItem> item in _currentLayoutItemsWithLinks) {
            itemIndex++;
            CGRect itemFrame = item.frame;
            if (CGRectIntersectsRect(itemFrame, visibleBounds)) {
                [visibleItemLinkIndices addObject:@(itemIndex)];
                
                if (_visibleLinkSelectionViews[@(itemIndex)] == nil) {
                    NSArray<TGInstantPageLinkSelectionView *> *linkViews = [item linkSelectionViews];
                    for (TGInstantPageLinkSelectionView *linkView in linkViews) {
                        linkView.itemTapped = _urlItemTapped;
                        
                        [_scrollView addSubview:linkView];
                    }
                    _visibleLinkSelectionViews[@(itemIndex)] = linkViews;
                }
            }
        }
        
        NSMutableArray *removeItemLinkIndices = [[NSMutableArray alloc] init];
        [_visibleLinkSelectionViews enumerateKeysAndObjectsUsingBlock:^(NSNumber *nIndex, NSArray<TGInstantPageLinkSelectionView *> *linkViews, __unused BOOL *stop) {
        if (![visibleItemLinkIndices containsObject:nIndex]) {
        for (UIView *linkView in linkViews) {
        [linkView removeFromSuperview];
        }
        [removeItemLinkIndices addObject:nIndex];
        }
        }];
        [_visibleLinkSelectionViews removeObjectsForKeys:removeItemLinkIndices];*/
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateVisibleItems()
        self.updateNavigationBar()
        self.previousContentOffset = self.scrollNode.view.contentOffset
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.isDeceleratingBecauseOfDragging = decelerate
        if !decelerate {
            self.updateNavigationBar(forceState: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.updateNavigationBar(forceState: true)
        self.isDeceleratingBecauseOfDragging = false
    }
    
    func updateNavigationBar(forceState: Bool = false) {
        
    }
}
