import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData

private func fixGridScrolling(_ gridNode: GridNode) {
    var searchItemNode: GridItemNode?
    var nextItemNode: GridItemNode?
    
    gridNode.forEachItemNode { itemNode in
        if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
            searchItemNode = itemNode
        } else if searchItemNode != nil && nextItemNode == nil, let itemNode = itemNode as? GridItemNode {
            nextItemNode = itemNode
        }
    }
    
    if let searchItemNode = searchItemNode {
        let contentInset = gridNode.scrollView.contentInset.top
        let itemFrame = gridNode.convert(searchItemNode.frame, to: gridNode.supernode)
        if itemFrame.contains(CGPoint(x: 0.0, y: contentInset)) {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
            
            var scrollIndex: Int?
            if itemFrame.minY + itemFrame.height * 0.6 < contentInset {
                for i in 0 ..< gridNode.items.count {
                    if let _ = gridNode.items[i] as? StickerPaneTrendingListGridItem {
                        scrollIndex = i
                        break
                    } else if let _ = gridNode.items[i] as? ChatMediaInputStickerGridItem {
                        scrollIndex = i
                        break
                    }
                }
            } else {
                for i in 0 ..< gridNode.items.count {
                    if let _ = gridNode.items[i] as? PaneSearchBarPlaceholderItem {
                        scrollIndex = i
                        break
                    }
                }
            }
            
            if let scrollIndex = scrollIndex {
                gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: scrollIndex, position: .top(0.0), transition: transition, directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { _ in })
            }
        }
    }
}

final class ChatMediaInputStickerPaneOpaqueState {
    let hasLower: Bool
    
    init(hasLower: Bool) {
        self.hasLower = hasLower
    }
}

final class ChatMediaInputStickerPane: ChatMediaInputPane {
    private var isExpanded: Bool?
    private var isPaneVisible = false
    let gridNode: GridNode
    private let paneDidScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void
    private let fixPaneScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void
    private var didScrollPreviousOffset: CGFloat?
    private var didScrollPreviousState: ChatMediaInputPaneScrollState?
    
    var beganScrolling: (() -> Void)?
    var endedScrolling: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, paneDidScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void, fixPaneScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void) {
        self.gridNode = GridNode()
        self.paneDidScroll = paneDidScroll
        self.fixPaneScroll = fixPaneScroll
        
        super.init()
        
        self.addSubnode(self.gridNode)
        self.gridNode.presentationLayoutUpdated = { [weak self] layout, transition in
            if let strongSelf = self, let opaqueState = strongSelf.gridNode.opaqueState as? ChatMediaInputStickerPaneOpaqueState {
                var offset: CGFloat
                if opaqueState.hasLower {
                    offset = -(layout.contentOffset.y + 41.0)
                } else {
                    offset = -(layout.contentOffset.y + 41.0)
                    offset = min(0.0, offset + 56.0)
                }
                var relativeChange: CGFloat = 0.0
                if let didScrollPreviousOffset = strongSelf.didScrollPreviousOffset {
                    relativeChange = offset - didScrollPreviousOffset
                }
                strongSelf.didScrollPreviousOffset = offset
                let state = ChatMediaInputPaneScrollState(absoluteOffset: offset, relativeChange: relativeChange)
                strongSelf.didScrollPreviousState = state
                if !transition.isAnimated {
                    strongSelf.paneDidScroll(strongSelf, state, transition)
                }
            }
        }
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.beganScrolling?()
        }
        self.gridNode.scrollingCompleted = { [weak self] in
            if let strongSelf = self {
                if let didScrollPreviousState = strongSelf.didScrollPreviousState {
                    strongSelf.fixPaneScroll(strongSelf, didScrollPreviousState)
                }
                fixGridScrolling(strongSelf.gridNode)
                strongSelf.endedScrolling?()
            }
        }
        self.gridNode.setupNode = { [weak self] itemNode in
            guard let strongSelf = self else {
                return
            }
            if let itemNode = itemNode as? ChatMediaInputStickerGridItemNode {
                itemNode.updateIsPanelVisible(strongSelf.isPaneVisible)
            } else if let itemNode = itemNode as? StickerPaneTrendingListGridItemNode {
                itemNode.updateIsPanelVisible(strongSelf.isPaneVisible)
            }
        }
        self.gridNode.scrollView.alwaysBounceVertical = true
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        var changedIsExpanded = false
        if let previousIsExpanded = self.isExpanded {
            if previousIsExpanded != isExpanded {
                changedIsExpanded = true
            }
        }
        self.isExpanded = isExpanded
        
        let maxItemSize: CGSize
        if case .tablet = deviceMetrics.type, size.width > 480.0 {
            maxItemSize = CGSize(width: 90.0, height: 96.0)
        } else {
            maxItemSize = CGSize(width: 75.0, height: 80.0)
        }
        
        let sideInset: CGFloat = 2.0
        var itemSide: CGFloat = floor((size.width - sideInset * 2.0) / 5.0)
        itemSide = min(itemSide, maxItemSize.width)
        let itemSize = CGSize(width: itemSide, height: max(itemSide, maxItemSize.height))
        
        var scrollToItem: GridNodeScrollToItem?
        if changedIsExpanded {
            if isExpanded {
                var scrollIndex: Int?
                for i in 0 ..< self.gridNode.items.count {
                    if let _ = self.gridNode.items[i] as? PaneSearchBarPlaceholderItem {
                        scrollIndex = i
                        break
                    }
                }
                if let scrollIndex = scrollIndex {
                    scrollToItem = GridNodeScrollToItem(index: scrollIndex, position: .top(0.0), transition: transition, directionHint: .down, adjustForSection: true, adjustForTopInset: true)
                }
            } else {
                var scrollIndex: Int?
                for i in 0 ..< self.gridNode.items.count {
                    if let _ = self.gridNode.items[i] as? ChatMediaInputStickerGridItem {
                        scrollIndex = i
                        break
                    }
                }
                if let scrollIndex = scrollIndex {
                    scrollToItem = GridNodeScrollToItem(index: scrollIndex, position: .top(0.0), transition: transition, directionHint: .down, adjustForSection: true, adjustForTopInset: true)
                }
            }
        }
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToItem, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset), preloadSize: isVisible ? 300.0 : 0.0, type: .fixed(itemSize: itemSize, fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        transition.updateFrame(node: self.gridNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        
        if self.isPaneVisible != isVisible {
            self.isPaneVisible = isVisible
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMediaInputStickerGridItemNode {
                    itemNode.updateIsPanelVisible(isVisible)
                } else if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                    itemNode.updateCanPlayMedia()
                } else if let itemNode = itemNode as? StickerPaneTrendingListGridItemNode {
                    itemNode.updateIsPanelVisible(isVisible)
                }
            }
        }
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, StickerPackItem)? {
        if let itemNode = self.gridNode.itemNodeAtPoint(self.view.convert(point, to: self.gridNode.view)) as? ChatMediaInputStickerGridItemNode, let stickerPackItem = itemNode.stickerPackItem {
            return (itemNode, stickerPackItem)
        }
        return nil
    }
}
