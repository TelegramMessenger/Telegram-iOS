import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

enum ChatMediaInputMetaSectionItemType {
    case savedStickers
    case recentStickers
}

final class ChatMediaInputMetaSectionItem: ListViewItem {
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let type: ChatMediaInputMetaSectionItemType
    let theme: PresentationTheme
    let selectedItem: () -> Void
    
    var selectable: Bool {
        return true
    }
    
    init(inputNodeInteraction: ChatMediaInputNodeInteraction, type: ChatMediaInputMetaSectionItemType, theme: PresentationTheme, selected: @escaping () -> Void) {
        self.inputNodeInteraction = inputNodeInteraction
        self.type = type
        self.selectedItem = selected
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputMetaSectionItemNode()
            node.contentSize = CGSize(width: 41.0, height: 41.0)
            node.insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            node.inputNodeInteraction = self.inputNodeInteraction
            node.setItem(item: self)
            node.updateTheme(theme: self.theme)
            node.updateIsHighlighted()
            node.updateAppearanceTransition(transition: .immediate)
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: node().contentSize, insets: node().insets), { _ in
                (node() as? ChatMediaInputMetaSectionItemNode)?.setItem(item: self)
                (node() as? ChatMediaInputMetaSectionItemNode)?.updateTheme(theme: self.theme)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let boundingSize = CGSize(width: 41.0, height: 41.0)
private let boundingImageSize = CGSize(width: 30.0, height: 30.0)
private let highlightSize = CGSize(width: 35.0, height: 35.0)
private let verticalOffset: CGFloat = 3.0 + UIScreenPixel

final class ChatMediaInputMetaSectionItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    private let highlightNode: ASImageNode
    
    var item: ChatMediaInputMetaSectionItem?
    var currentCollectionId: ItemCollectionId?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    var theme: PresentationTheme?
    
    init() {
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        
        self.highlightNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - highlightSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - highlightSize.height) / 2.0)), size: highlightSize)
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.highlightNode)
        self.addSubnode(self.imageNode)
        
        let imageSize = CGSize(width: 26.0, height: 26.0)
        self.imageNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - imageSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - imageSize.height) / 2.0) + UIScreenPixel), size: imageSize)
    }
    
    func setItem(item: ChatMediaInputMetaSectionItem) {
        self.item = item
        switch item.type {
            case .savedStickers:
                self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0)
            case .recentStickers:
                self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0)
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
            if let item = self.item {
                switch item.type {
                    case .savedStickers:
                        self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelSavedStickersIcon(theme)
                    case .recentStickers:
                        self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelRecentStickersIcon(theme)
                }
            }
        }
    }
    
    func updateIsHighlighted() {
        if let currentCollectionId = self.currentCollectionId, let inputNodeInteraction = self.inputNodeInteraction {
            self.highlightNode.isHidden = inputNodeInteraction.highlightedItemCollectionId != currentCollectionId
        }
    }
    
    func updateAppearanceTransition(transition: ContainedViewLayoutTransition) {
        if let inputNodeInteraction = self.inputNodeInteraction {
            transition.updateSublayerTransformScale(node: self, scale: inputNodeInteraction.appearanceTransition)
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        self.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
    }
}
