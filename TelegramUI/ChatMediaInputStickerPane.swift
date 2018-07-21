import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputStickerPaneOpaqueState {
    let hasLower: Bool
    
    init(hasLower: Bool) {
        self.hasLower = hasLower
    }
}

final class ChatMediaInputStickerPane: ChatMediaInputPane {
    let gridNode: GridNode
    private let paneDidScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void
    private let fixPaneScroll: (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void
    private var didScrollPreviousOffset: CGFloat?
    private var didScrollPreviousState: ChatMediaInputPaneScrollState?
    
    init(theme: PresentationTheme, strings: PresentationStrings, paneDidScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void, fixPaneScroll: @escaping (ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void) {
        self.gridNode = GridNode()
        //self.gridNode.initialOffset = 54.0
        self.paneDidScroll = paneDidScroll
        self.fixPaneScroll = fixPaneScroll
        
        super.init()
        
        self.addSubnode(self.gridNode)
        self.gridNode.presentationLayoutUpdated = { [weak self] layout, transition in
            if let strongSelf = self, let opaqueState = strongSelf.gridNode.opaqueState as? ChatMediaInputStickerPaneOpaqueState {
                let offset: CGFloat
                if opaqueState.hasLower {
                    offset = -(layout.contentOffset.y + 41.0)
                } else {
                    offset = -(layout.contentOffset.y + 41.0)
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
        self.gridNode.scrollingCompleted = { [weak self] in
            if let strongSelf = self, let didScrollPreviousState = strongSelf.didScrollPreviousState {
                strongSelf.fixPaneScroll(strongSelf, didScrollPreviousState)
            }
        }
        self.gridNode.scrollView.alwaysBounceVertical = true
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 2.0
        var itemSide: CGFloat = floor((size.width - sideInset * 2.0) / 5.0)
        itemSide = min(itemSide, 75.0)
        let itemSize = CGSize(width: itemSide, height: itemSide)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset), preloadSize: 300.0, type: .fixed(itemSize: itemSize, lineSpacing: 0.0)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        transition.updateFrame(node: self.gridNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, StickerPackItem)? {
        if let itemNode = self.gridNode.itemNodeAtPoint(self.view.convert(point, to: self.gridNode.view)) as? ChatMediaInputStickerGridItemNode, let stickerPackItem = itemNode.stickerPackItem {
            return (itemNode, stickerPackItem)
        }
        return nil
    }
}
