import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

final class ChatMediaInputTrendingItem: ListViewItem {
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let selectedItem: () -> Void
    let elevated: Bool
    let expanded: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    var selectable: Bool {
        return true
    }
    
    init(inputNodeInteraction: ChatMediaInputNodeInteraction, elevated: Bool, theme: PresentationTheme, strings: PresentationStrings, expanded: Bool, selected: @escaping () -> Void) {
        self.inputNodeInteraction = inputNodeInteraction
        self.elevated = elevated
        self.selectedItem = selected
        self.expanded = expanded
        self.theme = theme
        self.strings = strings
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputTrendingItemNode()
            node.contentSize = self.expanded ? expandedBoundingSize : boundingSize
            node.insets = ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)
            node.inputNodeInteraction = self.inputNodeInteraction
            node.updateIsHighlighted()
            node.updateAppearanceTransition(transition: .immediate)
            Queue.mainQueue().async {
                node.updateTheme(elevated: self.elevated, theme: self.theme, strings: self.strings, expanded: self.expanded)
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: self.expanded ? expandedBoundingSize : boundingSize, insets: ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)), { _ in
                (node() as? ChatMediaInputTrendingItemNode)?.updateTheme(elevated: self.elevated, theme: self.theme, strings: self.strings, expanded: self.expanded)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let boundingSize = CGSize(width: 72.0, height: 41.0)
private let expandedBoundingSize = CGSize(width: 72.0, height: 72.0)
private let boundingImageScale: CGFloat = 0.625
private let highlightSize = CGSize(width: 56.0, height: 56.0)
private let verticalOffset: CGFloat = 3.0 + UIScreenPixel

final class ChatMediaInputTrendingItemNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let scalingNode: ASDisplayNode
    private let imageNode: ASImageNode
    private let highlightNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    private var currentExpanded = false
    
    var currentCollectionId: ItemCollectionId?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    var elevated: Bool = false
    var theme: PresentationTheme?
    
    let badgeBackground: ASImageNode
    
    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        self.scalingNode = ASDisplayNode()
        
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.contentMode = .scaleAspectFit
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        self.badgeBackground.isHidden = true
        
        self.titleNode = ImmediateTextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.scalingNode)
        
        self.scalingNode.addSubnode(self.highlightNode)
        self.scalingNode.addSubnode(self.titleNode)
        self.scalingNode.addSubnode(self.imageNode)
        self.scalingNode.addSubnode(self.badgeBackground)
        
        self.currentCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue, id: 0)
    }
    
    func updateTheme(elevated: Bool, theme: PresentationTheme, strings: PresentationStrings, expanded: Bool) {
        let imageSize = CGSize(width: 26.0 * 1.85, height: 26.0 * 1.85)
        let imageFrame = CGRect(origin: CGPoint(x: floor((expandedBoundingSize.width - imageSize.width) / 2.0), y: floor((expandedBoundingSize.height - imageSize.height) / 2.0) + UIScreenPixel), size: imageSize)
        self.imageNode.frame = imageFrame
        
        if self.theme !== theme {
            self.theme = theme
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
            self.imageNode.image = PresentationResourcesChat.chatInputMediaPanelTrendingIconImage(theme)
            self.badgeBackground.image = generateFilledCircleImage(diameter: 10.0, color: theme.chat.inputPanel.mediaRecordingDotColor)
            
            if let image = self.badgeBackground.image {
                self.badgeBackground.frame = CGRect(origin: CGPoint(x: floor(imageFrame.maxX - image.size.width - 7.0), y: 18.0), size: image.size)
            }
            
            self.titleNode.attributedText = NSAttributedString(string: strings.Stickers_Trending, font: Font.regular(11.0), textColor: theme.chat.inputPanel.primaryTextColor)
        }
        
        if self.elevated != elevated {
            self.elevated = elevated
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedBoundingSize)
        self.scalingNode.bounds = CGRect(origin: CGPoint(), size: expandedBoundingSize)
        
        let boundsSize = expanded ? expandedBoundingSize : CGSize(width: boundingSize.height, height: boundingSize.height)
        let expandScale: CGFloat = expanded ? 1.0 : boundingImageScale
        let expandTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: 0.3, curve: .spring) : .immediate
        expandTransition.updateTransformScale(node: self.scalingNode, scale: expandScale)
        expandTransition.updatePosition(node: self.scalingNode, position: CGPoint(x: boundsSize.width / 2.0, y: boundsSize.height / 2.0 + (expanded ? -53.0 : -7.0)))

        let titleSize = self.titleNode.updateLayout(CGSize(width: expandedBoundingSize.width - 8.0, height: expandedBoundingSize.height))
        
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((expandedBoundingSize.width - titleSize.width) / 2.0), y: expandedBoundingSize.height - titleSize.height + 6.0), size: titleSize)
        let displayTitleFrame = expanded ? titleFrame : CGRect(origin: CGPoint(x: titleFrame.minX, y: self.imageNode.position.y - titleFrame.size.height), size: titleFrame.size)
        expandTransition.updateFrameAsPositionAndBounds(node: self.titleNode, frame: displayTitleFrame)
        expandTransition.updateTransformScale(node: self.titleNode, scale: expanded ? 1.0 : 0.001)
        
        let alphaTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: expanded ? 0.15 : 0.1, curve: .linear) : .immediate
        alphaTransition.updateAlpha(node: self.titleNode, alpha: expanded ? 1.0 : 0.0, delay: expanded ? 0.05 : 0.0)
        
        self.currentExpanded = expanded
        
        expandTransition.updateFrame(node: self.highlightNode, frame: expanded ? titleFrame.insetBy(dx: -7.0, dy: -2.0) : CGRect(origin: CGPoint(x: self.imageNode.position.x - highlightSize.width / 2.0, y: self.imageNode.position.y - highlightSize.height / 2.0), size: highlightSize))
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

