import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext

private let tileSpacing: CGFloat = 4.0
let tileHeight: CGFloat = 180.0

enum VoiceChatTileLayoutMode {
    case pairs
    case rows
    case grid
}

final class VoiceChatTileGridNode: ASDisplayNode {
    private let context: AccountContext
    
    private var items: [VoiceChatTileItem] = []
    fileprivate var itemNodes: [String: VoiceChatTileItemNode] = [:]
    private var isFirstTime = true
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    var tileNodes: [VoiceChatTileItemNode] {
        return Array(self.itemNodes.values)
    }
    
    init(context: AccountContext) {
        self.context = context
        
        super.init()
        
        self.clipsToBounds = true
    }
    
    var visibility = true {
        didSet {
            for (_, tileNode) in self.itemNodes {
                tileNode.visibility = self.visibility
            }
        }
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        for itemNode in self.itemNodes.values {
            var localRect = rect
            localRect.origin = localRect.origin.offsetBy(dx: itemNode.frame.minX, dy: itemNode.frame.minY)
            localRect.size = itemNode.frame.size
            itemNode.updateAbsoluteRect(localRect, within: containerSize)
        }
    }
    
    func update(size: CGSize, layoutMode: VoiceChatTileLayoutMode, items: [VoiceChatTileItem], transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) -> CGSize {
        let wasEmpty = self.items.isEmpty
        self.items = items
        
        var validIds: [String] = []
        
        let colsCount: CGFloat
        if case .grid = layoutMode {
            if items.count < 3 {
                colsCount = 1
            } else if items.count < 5 {
                colsCount = 2
            } else {
                colsCount = 3
            }
        } else {
            colsCount = 2
        }
        let rowsCount = ceil(CGFloat(items.count) / colsCount)
        
        let genericItemWidth = floorToScreenPixels((size.width - tileSpacing * (colsCount - 1)) / colsCount)
        let lastRowItemsAreWide: Bool
        let lastRowItemWidth: CGFloat
        if case .grid = layoutMode {
            lastRowItemsAreWide = [1, 2].contains(items.count) || items.count % Int(colsCount) != 0
            var lastRowItemsCount = CGFloat(items.count % Int(colsCount))
            if lastRowItemsCount.isZero {
                lastRowItemsCount = colsCount
            }
            lastRowItemWidth = floorToScreenPixels((size.width - tileSpacing * (lastRowItemsCount - 1)) / lastRowItemsCount)
        } else {
            lastRowItemsAreWide = items.count == 1 || items.count % Int(colsCount) != 0
            lastRowItemWidth = size.width
        }

        let isFirstTime = self.isFirstTime
        if isFirstTime {
            self.isFirstTime = false
        }
        
        var availableWidth = min(size.width, size.height)
        var itemHeight = tileHeight
        if case .grid = layoutMode {
            itemHeight = size.height / rowsCount - (tileSpacing * (rowsCount - 1))
        }
        
        for i in 0 ..< self.items.count {
            let item = self.items[i]
            let col = CGFloat(i % Int(colsCount))
            let row = floor(CGFloat(i) / colsCount)
            let isLastRow = row == (rowsCount - 1)
            
            let rowItemWidth = isLastRow && lastRowItemsAreWide ? lastRowItemWidth : genericItemWidth
            let itemSize = CGSize(
                width: rowItemWidth,
                height: itemHeight
            )
            
            if case .grid = layoutMode {
                availableWidth = rowItemWidth
            }

            let itemFrame = CGRect(origin: CGPoint(x: col * (rowItemWidth + tileSpacing), y: row * (itemHeight + tileSpacing)), size: itemSize)
            
            validIds.append(item.id)
            var itemNode: VoiceChatTileItemNode?
            var wasAdded = false
            if let current = self.itemNodes[item.id] {
                itemNode = current
                current.update(size: itemSize, availableWidth: availableWidth, item: item, transition: transition)
            } else {
                wasAdded = true
                let addedItemNode = VoiceChatTileItemNode(context: self.context)
                itemNode = addedItemNode
                addedItemNode.update(size: itemSize, availableWidth: availableWidth, item: item, transition: .immediate)
                self.itemNodes[self.items[i].id] = addedItemNode
                self.addSubnode(addedItemNode)
            }
            if let itemNode = itemNode {
                itemNode.visibility = self.visibility
                let itemTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
                itemTransition.updateFrameAsPositionAndBounds(node: itemNode, frame: itemFrame)
                if wasAdded && !isFirstTime {
                    itemNode.layer.animateScale(from: 0.0, to: 1.0, duration: wasEmpty ? 0.4 : 0.3)
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                
                if let (rect, containerSize) = self.absoluteLocation {
                    var localRect = rect
                    localRect.origin = localRect.origin.offsetBy(dx: itemFrame.minX, dy: itemFrame.minY)
                    localRect.size = itemFrame.size
                    itemNode.updateAbsoluteRect(localRect, within: containerSize)
                }
            }
        }
        
        var removeIds: [String] = []
        for (id, _) in self.itemNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                itemNode.layer.animateScale(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, additive: true)
                itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        if case let .animated(duration, _) = transition {
            Queue.mainQueue().after(duration) {
                completion()
            }
        } else {
            completion()
        }
        
        let rowCount = ceil(CGFloat(self.items.count) / 2.0)
        return CGSize(width: size.width, height: rowCount * (itemHeight + tileSpacing))
    }
}

final class VoiceChatTilesGridItem: ListViewItem {
    let context: AccountContext
    let tiles: [VoiceChatTileItem]
    let layoutMode: VoiceChatTileLayoutMode
    let getIsExpanded: () -> Bool
    
    init(context: AccountContext, tiles: [VoiceChatTileItem], layoutMode: VoiceChatTileLayoutMode, getIsExpanded: @escaping () -> Bool) {
        self.context = context
        self.tiles = tiles
        self.layoutMode = layoutMode
        self.getIsExpanded = getIsExpanded
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatTilesGridItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? VoiceChatTilesGridItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

final class VoiceChatTilesGridItemNode: ListViewItemNode {
    private var item: VoiceChatTilesGridItem?
    
    private var tileGridNode: VoiceChatTileGridNode?
    let backgroundNode: ASDisplayNode
    let cornersNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    var tileNodes: [VoiceChatTileItemNode] {
        if let values = self.tileGridNode?.itemNodes.values {
            return Array(values)
        } else {
            return []
        }
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        
        self.cornersNode = ASImageNode()
        self.cornersNode.displaysAsynchronously = false
        self.cornersNode.image = decorationCornersImage(top: true, bottom: false, dark: false)
        
        super.init(layerBacked: false, dynamicBounce: false)
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.cornersNode)
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        if let tileGridNode = self.tileGridNode {
            var gridFrame = tileGridNode.frame
            gridFrame.size.height = currentValue
            tileGridNode.frame = gridFrame
        }
        
        var backgroundFrame = self.backgroundNode.frame
        backgroundFrame.size.height = currentValue
        self.backgroundNode.frame = backgroundFrame
        
        var cornersFrame = self.cornersNode.frame
        cornersFrame.origin.y = currentValue
        self.cornersNode.frame = cornersFrame
    }
    
    func asyncLayout() -> (_ item: VoiceChatTilesGridItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        return { item, params in
            let rowCount = ceil(CGFloat(item.tiles.count) / 2.0)
            let contentSize = CGSize(width: params.width, height: rowCount * (tileHeight + tileSpacing))
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let tileGridNode: VoiceChatTileGridNode
                    if let current = strongSelf.tileGridNode {
                        tileGridNode = current
                    } else {
                        strongSelf.backgroundNode.backgroundColor = item.getIsExpanded() ? fullscreenBackgroundColor  : panelBackgroundColor
                        strongSelf.cornersNode.image = decorationCornersImage(top: true, bottom: false, dark: item.getIsExpanded())
                        
                        tileGridNode = VoiceChatTileGridNode(context: item.context)
                        tileGridNode.visibility = strongSelf.gridVisibility
                        strongSelf.addSubnode(tileGridNode)
                        strongSelf.tileGridNode = tileGridNode
                    }

                    
                    if let (rect, size) = strongSelf.absoluteLocation {
                        tileGridNode.updateAbsoluteRect(rect, within: size)
                    }
                    
                    let transition: ContainedViewLayoutTransition = currentItem == nil ? .immediate : .animated(duration: 0.3, curve: .easeInOut)
                    let tileGridSize = tileGridNode.update(size: CGSize(width: params.width - params.leftInset - params.rightInset, height: params.availableHeight), layoutMode: item.layoutMode, items: item.tiles, transition: transition)
                    if currentItem == nil {
                        tileGridNode.frame = CGRect(x: params.leftInset, y: 0.0, width: tileGridSize.width, height: tileGridSize.height)
                        strongSelf.backgroundNode.frame = tileGridNode.frame
                        strongSelf.cornersNode.frame = CGRect(x: params.leftInset, y: layout.size.height, width: tileGridSize.width, height: 50.0)
                    } else {
                        transition.updateFrame(node: tileGridNode, frame: CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: tileGridSize))
                        transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: tileGridSize))
                        strongSelf.cornersNode.frame = CGRect(x: params.leftInset, y: layout.size.height, width: tileGridSize.width, height: 50.0)
                    }
                }
            })
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        self.tileGridNode?.updateAbsoluteRect(rect, within: containerSize)
    }
    
    var gridVisibility: Bool = true {
        didSet {
            self.tileGridNode?.visibility = self.gridVisibility
        }
    }
    
    func snapshotForDismissal() {
        if let snapshotView = self.tileGridNode?.view.snapshotView(afterScreenUpdates: false) {
            self.tileGridNode?.view.addSubview(snapshotView)
        }
    }
}
