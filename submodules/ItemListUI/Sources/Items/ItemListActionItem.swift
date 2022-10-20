import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

public enum ItemListActionKind {
    case generic
    case destructive
    case neutral
    case disabled
}

public enum ItemListActionAlignment {
    case natural
    case center
}

public class ItemListActionItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let kind: ItemListActionKind
    let alignment: ItemListActionAlignment
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    public let action: () -> Void
    let longTapAction: (() -> Void)?
    let clearHighlightAutomatically: Bool
    public let tag: Any?
    
    public init(presentationData: ItemListPresentationData, title: String, kind: ItemListActionKind, alignment: ItemListActionAlignment, sectionId: ItemListSectionId, style: ItemListStyle, action: @escaping () -> Void, longTapAction: (() -> Void)? = nil, clearHighlightAutomatically: Bool = true, tag: Any? = nil) {
        self.presentationData = presentationData
        self.title = title
        self.kind = kind
        self.alignment = alignment
        self.sectionId = sectionId
        self.style = style
        self.action = action
        self.longTapAction = longTapAction
        self.clearHighlightAutomatically = clearHighlightAutomatically
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListActionItemNode()
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListActionItemNode {
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
    
    public var selectable: Bool = true
    
    public func selected(listView: ListView){
        if self.clearHighlightAutomatically {
            listView.clearHighlightAnimated(true)
        }
        self.action()
    }
}

public class ItemListActionItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListActionItem?
    
    public var tag: ItemListItemTag? {
        return self.item?.tag as? ItemListItemTag
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        self.maskNode = ASImageNode()
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        
        self.addSubnode(self.activateArea)
    }
    
    public func asyncLayout() -> (_ item: ItemListActionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let textColor: UIColor
            switch item.kind {
            case .destructive:
                textColor = item.presentationData.theme.list.itemDestructiveColor
            case .generic:
                textColor = item.presentationData.theme.list.itemAccentColor
            case .neutral:
                textColor = item.presentationData.theme.list.itemPrimaryTextColor
            case .disabled:
                textColor = item.presentationData.theme.list.itemDisabledTextColor
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0)
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.title
                    
                    var accessibilityTraits: UIAccessibilityTraits = .button
                    switch item.kind {
                        case .disabled:
                            accessibilityTraits.insert(.notEnabled)
                        default:
                            break
                    }
                    strongSelf.activateArea.accessibilityTraits = accessibilityTraits
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    
                    let leftInset = 16.0 + params.leftInset
                    
                    switch item.style {
                        case .plain:
                            if strongSelf.backgroundNode.supernode != nil {
                               strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                            if strongSelf.maskNode.supernode != nil {
                                strongSelf.maskNode.removeFromSupernode()
                            }
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                        case .blocks:
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
                                    bottomStripeInset = 16.0 + params.leftInset
                                    bottomStripeOffset = -separatorHeight
                                    strongSelf.bottomStripeNode.isHidden = false
                                default:
                                    bottomStripeInset = 0.0
                                    bottomStripeOffset = 0.0
                                    hasBottomCorners = true
                                    strongSelf.bottomStripeNode.isHidden = hasCorners
                            }
                            
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                            
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    switch item.alignment {
                    case .natural:
                        strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: titleLayout.size)
                    case .center:
                        strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((params.width - params.leftInset - params.rightInset - titleLayout.size.width) / 2.0), y: 12.0), size: titleLayout.size)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && self.item?.kind != ItemListActionKind.disabled {
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func longTapped() {
        self.item?.longTapAction?()
    }
    
    override public var canBeLongTapped: Bool {
        return self.item?.longTapAction != nil
    }
}
