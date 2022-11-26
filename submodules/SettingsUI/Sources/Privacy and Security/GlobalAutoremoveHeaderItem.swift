import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AccountContext

class GlobalAutoremoveHeaderItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    
    init(context: AccountContext, theme: PresentationTheme, sectionId: ItemListSectionId) {
        self.context = context
        self.theme = theme
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = GlobalAutoremoveHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
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
            guard let nodeValue = node() as? GlobalAutoremoveHeaderItemNode else {
                assertionFailure()
                return
            }
            
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private let titleFont = Font.regular(13.0)

class GlobalAutoremoveHeaderItemNode: ListViewItemNode {
    private var animationNode: AnimatedStickerNode
    
    private var item: GlobalAutoremoveHeaderItem?
    
    init() {
        self.animationNode = DefaultAnimatedStickerNodeImpl()
                
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.animationNode)
    }
    
    func asyncLayout() -> (_ item: GlobalAutoremoveHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            //let leftInset: CGFloat = 32.0 + params.leftInset
            let topInset: CGFloat = 110.0
            
            let contentSize = CGSize(width: params.width, height: topInset)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    if strongSelf.item == nil {
                        strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "GlobalAutoRemove"), width: 220, height: 220, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                        strongSelf.animationNode.visibility = true
                    }
                    strongSelf.item = item
                                        
                    let iconSize = CGSize(width: 110.0, height: 110.0)
                    strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: -10.0), size: iconSize)
                    strongSelf.animationNode.updateLayout(size: iconSize)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
