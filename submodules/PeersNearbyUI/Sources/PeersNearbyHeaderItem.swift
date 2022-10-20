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

class PeersNearbyHeaderItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let text: String
    let sectionId: ItemListSectionId
    
    init(context: AccountContext, theme: PresentationTheme, text: String, sectionId: ItemListSectionId) {
        self.context = context
        self.theme = theme
        self.text = text
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeersNearbyHeaderItemNode()
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
            guard let nodeValue = node() as? PeersNearbyHeaderItemNode else {
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

class PeersNearbyHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private var animationNode: AnimatedStickerNode
    
    private var item: PeersNearbyHeaderItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
                
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.animationNode)
    }
    
    func asyncLayout() -> (_ item: PeersNearbyHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 32.0 + params.leftInset
            let topInset: CGFloat = 92.0
            
            let attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: item.theme.list.freeTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    if strongSelf.item == nil {
                        strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "Compass"), width: 192, height: 192, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                        strongSelf.animationNode.visibility = true
                    }
                    strongSelf.item = item
                    strongSelf.accessibilityLabel = attributedText.string
                                        
                    let iconSize = CGSize(width: 96.0, height: 96.0)
                    strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: -10.0), size: iconSize)
                    strongSelf.animationNode.updateLayout(size: iconSize)
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleLayout.size.width) / 2.0), y: topInset + 8.0), size: titleLayout.size)
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
