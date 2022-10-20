import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

class CreatePollOptionActionItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let enabled: Bool
    let tag: ItemListItemTag?
    let sectionId: ItemListSectionId
    let action: () -> Void
    
    init(theme: PresentationTheme, title: String, enabled: Bool, tag: ItemListItemTag?, sectionId: ItemListSectionId, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.enabled = enabled
        self.tag = tag
        self.sectionId = sectionId
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CreatePollOptionActionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? CreatePollOptionActionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool {
        return self.enabled
    }
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)

class CreatePollOptionActionItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    
    private var item: CreatePollOptionActionItem?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
    }
    
    func asyncLayout() -> (_ item: CreatePollOptionActionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            var updatedIcon: UIImage?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updatedIcon = PresentationResourcesItemList.addPhoneIcon(item.theme)
            }
            let leftInset: CGFloat = 60.0 + params.leftInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.enabled ? item.theme.list.itemAccentColor : item.theme.list.itemDisabledTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: 44.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let updatedIcon = updatedIcon {
                        strongSelf.iconNode.image = updatedIcon
                    }
                    if let image = strongSelf.iconNode.image {
                        transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - image.size.width) / 2.0 - 3.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size))
                    }
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                    }
                    
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: strongSelf.backgroundNode.frame.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
