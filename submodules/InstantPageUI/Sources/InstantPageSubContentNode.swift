import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

final class InstantPageSubContentNode : ASDisplayNode {
    private let context: AccountContext
    private let strings: PresentationStrings
    private let nameDisplayOrder: PresentationPersonNameOrder
    private let sourcePeerType: MediaAutoDownloadPeerType
    private let theme: InstantPageTheme
    
    private let openMedia: (InstantPageMedia) -> Void
    private let longPressMedia: (InstantPageMedia) -> Void
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
    let inOverlayPanel: Bool
    
    private var previousVisibleBounds: CGRect?
    
    init(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, sourcePeerType: MediaAutoDownloadPeerType, theme: InstantPageTheme, items: [InstantPageItem], contentSize: CGSize, inOverlayPanel: Bool = false, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void) {
        self.context = context
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.sourcePeerType = sourcePeerType
        self.theme = theme
        
        self.openMedia = openMedia
        self.longPressMedia = longPressMedia
        self.openPeer = openPeer
        self.openUrl = openUrl
        
        self.currentLayout = InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        self.contentSize = contentSize
        self.inOverlayPanel = inOverlayPanel
        
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
        var distanceThresholdGroupCount: [Int: Int] = [:]
        
        var expandedDetails: [Int: Bool] = [:]
        
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
                        currentItemNode.removeFromSupernode()
                        self.visibleItemsWithNodes.removeValue(forKey: itemIndex)
                        itemNode = nil
                    }
                }
                
                if itemNode == nil {
                    let itemIndex = itemIndex
                    let detailsIndex = detailsIndex
                    if let newNode = item.node(context: self.context, strings: self.strings, nameDisplayOrder: self.nameDisplayOrder, theme: theme, sourcePeerType: self.sourcePeerType, openMedia: { [weak self] media in
                        self?.openMedia(media)
                        }, longPressMedia: { [weak self] media in
                            self?.longPressMedia(media)
                        }, activatePinchPreview: nil, pinchPreviewFinished: nil, openPeer: { [weak self] peerId in
                            self?.openPeer(peerId)
                        }, openUrl: { [weak self] url in
                            self?.openUrl(url)
                        }, updateWebEmbedHeight: { _ in
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
                    if let itemNode = itemNode, itemNode.frame != itemFrame {
                        transition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.updateLayout(size: itemFrame.size, transition: transition)
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
                    let tileNode = InstantPageTileNode(tile: tile, backgroundColor: self.inOverlayPanel ? self.theme.overlayPanelColor : self.theme.pageBackgroundColor)
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
                itemNode.removeFromSupernode()
            } else {
                var itemFrame = itemNode.frame
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
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
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
    
    func scrollableContentOffset(item: InstantPageScrollableItem) -> CGPoint {
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
    
    func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
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
