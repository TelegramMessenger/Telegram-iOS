import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox

private let iconImage = generateImage(CGSize(width: 26.0, height: 26.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0x9099A2).cgColor)
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    let diameter: CGFloat = 22.0
    context.strokeEllipse(in: CGRect(origin: CGPoint(x: floor((size.width - diameter) / 2.0), y: floor((size.width - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)))
    context.translateBy(x: 1.5, y: 2.5)
    context.move(to: CGPoint(x: 11.0, y: 5.5))
    context.addLine(to: CGPoint(x: 11.0, y: 11.0))
    context.addLine(to: CGPoint(x: 14.5, y: 14.5))
    context.strokePath()
})

final class ChatMediaInputRecentStickerPacksItem: ListViewItem {
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let selectedItem: () -> Void
    
    var selectable: Bool {
        return true
    }
    
    init(inputNodeInteraction: ChatMediaInputNodeInteraction, selected: @escaping () -> Void) {
        self.inputNodeInteraction = inputNodeInteraction
        self.selectedItem = selected
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ChatMediaInputRecentStickerPacksItemNode()
            node.contentSize = CGSize(width: 41.0, height: 41.0)
            node.insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            node.inputNodeInteraction = self.inputNodeInteraction
            completion(node, {
                return (nil, {})
            })
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets), {
        })
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let boundingSize = CGSize(width: 41.0, height: 41.0)
private let boundingImageSize = CGSize(width: 30.0, height: 30.0)
private let highlightSize = CGSize(width: 35.0, height: 35.0)
private let verticalOffset: CGFloat = 3.0 + UIScreenPixel

private let highlightBackground = generateStretchableFilledCircleImage(radius: 9.0, color: UIColor(0x9099A2, 0.2))

final class ChatMediaInputRecentStickerPacksItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    private let highlightNode: ASImageNode
    
    var currentCollectionId: ItemCollectionId?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    init() {
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.image = highlightBackground
        self.highlightNode.isHidden = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        
        self.highlightNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - highlightSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - highlightSize.height) / 2.0)), size: highlightSize)
        
        self.imageNode.image = iconImage
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.highlightNode)
        self.addSubnode(self.imageNode)
        
        self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0)
        
        let imageSize = CGSize(width: 26.0, height: 26.0)
        self.imageNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - imageSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - imageSize.height) / 2.0) + UIScreenPixel), size: imageSize)
    }
    
    deinit {
    }
    
    func updateStickerPackItem(account: Account, item: StickerPackItem?, collectionId: ItemCollectionId) {
        self.currentCollectionId = collectionId
        self.updateIsHighlighted()
    }
    
    func updateIsHighlighted() {
        if let currentCollectionId = self.currentCollectionId, let inputNodeInteraction = self.inputNodeInteraction {
            self.highlightNode.isHidden = inputNodeInteraction.highlightedItemCollectionId != currentCollectionId
        }
    }
}
