import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AnimatedStickerNode
import AppBundle

class InviteLinkInviteManageItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId = 0
    
    let theme: PresentationTheme
    let text: String
    let standalone: Bool
    let action: () -> Void
    
    init(theme: PresentationTheme, text: String, standalone: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.text = text
        self.standalone = standalone
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = InviteLinkInviteManageItemNode()
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
            guard let nodeValue = node() as? InviteLinkInviteManageItemNode else {
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

private let titleFont = Font.medium(23.0)
private let textFont = Font.regular(13.0)

class InviteLinkInviteManageItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    
    private var item: InviteLinkInviteManageItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.buttonNode = HighlightableButtonNode()
      
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.item?.action()
    }
    
    func asyncLayout() -> (_ item: InviteLinkInviteManageItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize = CGSize(width: params.width, height: 70.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.backgroundNode.backgroundColor = item.standalone ? .clear : item.theme.list.blocksBackgroundColor
                    
                    strongSelf.buttonNode.setTitle(item.text, with: Font.regular(17.0), with: item.theme.actionSheet.controlAccentColor, for: .normal)
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: 1000.0))

                    let size = strongSelf.buttonNode.measure(layout.contentSize)
                    strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.contentSize.width - size.width) / 2.0), y: floorToScreenPixels((layout.contentSize.height - size.height) / 2.0)), size: size)
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
