import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext

private let tileSpacing: CGFloat = 4.0
let tileHeight: CGFloat = 180.0

final class VoiceChatTileGridNode: ASDisplayNode {
    private let context: AccountContext
    
    private var items: [VoiceChatTileItem] = []
    fileprivate var itemNodes: [String: VoiceChatTileItemNode] = [:]
    private var isFirstTime = true
    
    init(context: AccountContext) {
        self.context = context
        
        super.init()
        
        self.clipsToBounds = true
    }
    
    func update(size: CGSize, items: [VoiceChatTileItem], transition: ContainedViewLayoutTransition) -> CGSize {
        self.items = items
        
        var validIds: [String] = []

        let halfWidth = floorToScreenPixels((size.width - tileSpacing) / 2.0)
        let lastItemIsWide = items.count % 2 != 0

        let isFirstTime = self.isFirstTime
        if isFirstTime {
            self.isFirstTime = false
        }
        
        for i in 0 ..< self.items.count {
            let item = self.items[i]
            let isLast = i == self.items.count - 1
            
            let itemSize = CGSize(
                width: isLast && lastItemIsWide ? size.width : halfWidth,
                height: tileHeight
            )
            let col = CGFloat(i % 2)
            let row = floor(CGFloat(i) / 2.0)
            let itemFrame = CGRect(origin: CGPoint(x: col * (halfWidth + tileSpacing), y: row * (tileHeight + tileSpacing)), size: itemSize)
            
            validIds.append(item.id)
            var itemNode: VoiceChatTileItemNode?
            var wasAdded = false
            if let current = self.itemNodes[item.id] {
                itemNode = current
                current.update(size: itemSize, availableWidth: size.width, item: item, transition: transition)
            } else {
                wasAdded = true
                let addedItemNode = VoiceChatTileItemNode(context: self.context)
                itemNode = addedItemNode
                addedItemNode.update(size: itemSize, availableWidth: size.width, item: item, transition: .immediate)
                self.itemNodes[self.items[i].id] = addedItemNode
                self.addSubnode(addedItemNode)
            }
            if let itemNode = itemNode {
                if wasAdded {
                    itemNode.frame = itemFrame
                    if !isFirstTime {
                        itemNode.layer.animateScale(from: 0.0, to: 1.0, duration: 0.3)
                        itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                } else {
                    transition.updateFrame(node: itemNode, frame: itemFrame)
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
                itemNode.layer.animateScale(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        let rowCount = ceil(CGFloat(self.items.count) / 2.0)
        return CGSize(width: size.width, height: rowCount * (tileHeight + tileSpacing))
    }
}

final class VoiceChatTilesGridItem: ListViewItem {
    let context: AccountContext
    let tiles: [VoiceChatTileItem]
    let getIsExpanded: () -> Bool
    
    init(context: AccountContext, tiles: [VoiceChatTileItem], getIsExpanded: @escaping () -> Bool) {
        self.context = context
        self.tiles = tiles
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
                        strongSelf.addSubnode(tileGridNode)
                        strongSelf.tileGridNode = tileGridNode
                    }

                    let transition: ContainedViewLayoutTransition = currentItem == nil ? .immediate : .animated(duration: 0.3, curve: .easeInOut)
                    let tileGridSize = tileGridNode.update(size: CGSize(width: params.width - params.leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), items: item.tiles, transition: transition)
                    if currentItem == nil {
                        tileGridNode.frame = CGRect(x: params.leftInset, y: 0.0, width: tileGridSize.width, height: 0.0)
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
}
