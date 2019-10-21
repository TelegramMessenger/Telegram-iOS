import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

final class ChatMediaInputTrendingItem: ListViewItem {
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let selectedItem: () -> Void
    let elevated: Bool
    let theme: PresentationTheme
    
    var selectable: Bool {
        return true
    }
    
    init(inputNodeInteraction: ChatMediaInputNodeInteraction, elevated: Bool, theme: PresentationTheme, selected: @escaping () -> Void) {
        self.inputNodeInteraction = inputNodeInteraction
        self.elevated = elevated
        self.selectedItem = selected
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputTrendingItemNode()
            node.contentSize = CGSize(width: 41.0, height: 41.0)
            node.insets = ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)
            node.inputNodeInteraction = self.inputNodeInteraction
            node.updateTheme(elevated: self.elevated, theme: self.theme)
            node.updateIsHighlighted()
            node.updateAppearanceTransition(transition: .immediate)
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: node().contentSize, insets: ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)), { _ in
                (node() as? ChatMediaInputTrendingItemNode)?.updateTheme(elevated: self.elevated, theme: self.theme)
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

final class ChatMediaInputTrendingItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    private let highlightNode: ASImageNode
    
    var currentCollectionId: ItemCollectionId?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    var elevated: Bool = false
    var theme: PresentationTheme?
    
    let badgeBackground: ASImageNode
    
    init() {
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.contentMode = .center
        self.imageNode.contentsScale = UIScreenScale
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        self.badgeBackground.isHidden = true
        
        self.highlightNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - highlightSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - highlightSize.height) / 2.0)), size: highlightSize)
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.highlightNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.badgeBackground)
        
        self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue, id: 0)
    }
    
    deinit {
    }
    
    func updateTheme(elevated: Bool, theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
            self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelTrendingIconImage(theme)
            self.badgeBackground.image = generateFilledCircleImage(diameter: 10.0, color: theme.chat.inputPanel.mediaRecordingDotColor)
            
            let imageSize = CGSize(width: 26.0, height: 26.0)
            let imageFrame = CGRect(origin: CGPoint(x: floor((boundingSize.width - imageSize.width) / 2.0) + verticalOffset, y: floor((boundingSize.height - imageSize.height) / 2.0) + UIScreenPixel), size: imageSize)
            self.imageNode.frame = imageFrame
            
            if let image = self.badgeBackground.image {
                self.badgeBackground.frame = CGRect(origin: CGPoint(x: imageFrame.maxX - image.size.width - 1.0, y: imageFrame.maxY - image.size.width + 1.0), size: image.size)
            }
        }
        
        if self.elevated != elevated {
            self.elevated = elevated
            self.badgeBackground.isHidden = !self.elevated
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
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

