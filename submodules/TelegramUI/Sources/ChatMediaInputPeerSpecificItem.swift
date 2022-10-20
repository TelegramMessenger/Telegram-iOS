import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AvatarNode
import AccountContext

final class ChatMediaInputPeerSpecificItem: ListViewItem {
    let context: AccountContext
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let collectionId: ItemCollectionId
    let peer: Peer
    let expanded: Bool
    let selectedItem: () -> Void
    let theme: PresentationTheme
    
    var selectable: Bool {
        return true
    }
    
    init(context: AccountContext, inputNodeInteraction: ChatMediaInputNodeInteraction, collectionId: ItemCollectionId, peer: Peer, theme: PresentationTheme, expanded: Bool, selected: @escaping () -> Void) {
        self.context = context
        self.inputNodeInteraction = inputNodeInteraction
        self.collectionId = collectionId
        self.peer = peer
        self.selectedItem = selected
        self.expanded = expanded
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputPeerSpecificItemNode()
            node.contentSize = self.expanded ? expandedBoundingSize : boundingSize
            node.insets = ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)
            node.inputNodeInteraction = self.inputNodeInteraction
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        node.updateItem(context: self.context, peer: self.peer, collectionId: self.collectionId, theme: self.theme, expanded: self.expanded)
                        node.updateAppearanceTransition(transition: .immediate)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: self.expanded ? expandedBoundingSize : boundingSize, insets: ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)), { _ in
                (node() as? ChatMediaInputPeerSpecificItemNode)?.updateItem(context: self.context, peer: self.peer, collectionId: self.collectionId, theme: self.theme, expanded: self.expanded)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let avatarFont = avatarPlaceholderFont(size: 19.0)
private let boundingSize = CGSize(width: 72.0, height: 41.0)
private let expandedBoundingSize = CGSize(width: 72.0, height: 72.0)
private let boundingImageSize = CGSize(width: 45.0, height: 45.0)
private let boundingImageScale: CGFloat = 0.625
private let highlightSize = CGSize(width: 56.0, height: 56.0)
private let verticalOffset: CGFloat = 3.0

final class ChatMediaInputPeerSpecificItemNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let scalingNode: ASDisplayNode
    private let avatarNode: AvatarNode
    private let highlightNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var currentCollectionId: ItemCollectionId?
    private var currentExpanded = false
    private var theme: PresentationTheme?
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        self.scalingNode = ASDisplayNode()
        
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()

        self.titleNode = ImmediateTextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.scalingNode)
        
        self.scalingNode.addSubnode(self.highlightNode)
        self.scalingNode.addSubnode(self.titleNode)
        self.scalingNode.addSubnode(self.avatarNode)
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    func updateItem(context: AccountContext, peer: Peer, collectionId: ItemCollectionId, theme: PresentationTheme, expanded: Bool) {
        self.currentCollectionId = collectionId
        
        if self.theme !== theme {
            self.theme = theme
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
            
            self.titleNode.attributedText = NSAttributedString(string: EnginePeer(peer).compactDisplayTitle, font: Font.regular(11.0), textColor: theme.chat.inputPanel.primaryTextColor)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedBoundingSize)
        self.scalingNode.bounds = CGRect(origin: CGPoint(), size: expandedBoundingSize)
        
        let boundsSize = expanded ? expandedBoundingSize : CGSize(width: boundingSize.height, height: boundingSize.height)
        let imageSize = CGSize(width: 26.0 * 1.6, height: 26.0 * 1.6)
        
        let expandScale: CGFloat = expanded ? 1.0 : boundingImageScale
        let expandTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: 0.3, curve: .spring) : .immediate
        expandTransition.updateTransformScale(node: self.scalingNode, scale: expandScale)
        expandTransition.updatePosition(node: self.scalingNode, position: CGPoint(x: boundsSize.width / 2.0, y: boundsSize.height / 2.0 + (expanded ? -53.0 : -7.0)))

        let titleSize = self.titleNode.updateLayout(CGSize(width: expandedBoundingSize.width - 8.0, height: expandedBoundingSize.height))
        
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((expandedBoundingSize.width - titleSize.width) / 2.0), y: expandedBoundingSize.height - titleSize.height + 6.0), size: titleSize)
        let displayTitleFrame = expanded ? titleFrame : CGRect(origin: CGPoint(x: titleFrame.minX, y: self.avatarNode.position.y - titleFrame.size.height), size: titleFrame.size)
        expandTransition.updateFrameAsPositionAndBounds(node: self.titleNode, frame: displayTitleFrame)
        expandTransition.updateTransformScale(node: self.titleNode, scale: expanded ? 1.0 : 0.001)
        
        let alphaTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: expanded ? 0.15 : 0.1, curve: .linear) : .immediate
        alphaTransition.updateAlpha(node: self.titleNode, alpha: expanded ? 1.0 : 0.0, delay: expanded ? 0.05 : 0.0)
        
        self.currentExpanded = expanded
        
        self.avatarNode.bounds = CGRect(origin: CGPoint(), size: imageSize)
        self.avatarNode.position = CGPoint(x: expandedBoundingSize.height / 2.0, y: expandedBoundingSize.width / 2.0)
        self.avatarNode.frame = self.avatarNode.frame
        expandTransition.updateFrame(node: self.highlightNode, frame: expanded ? titleFrame.insetBy(dx: -7.0, dy: -2.0) : CGRect(origin: CGPoint(x: self.avatarNode.position.x - highlightSize.width / 2.0, y: self.avatarNode.position.y - highlightSize.height / 2.0), size: highlightSize))
        
        self.avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer))
    }
    
    func updateIsHighlighted() {
        assert(Queue.mainQueue().isCurrent())
        if let currentCollectionId = self.currentCollectionId, let inputNodeInteraction = self.inputNodeInteraction {
            self.highlightNode.isHidden = inputNodeInteraction.highlightedItemCollectionId != currentCollectionId
        }
    }
    
    func updateAppearanceTransition(transition: ContainedViewLayoutTransition) {
        assert(Queue.mainQueue().isCurrent())
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
