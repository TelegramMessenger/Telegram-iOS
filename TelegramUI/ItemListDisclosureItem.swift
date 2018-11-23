import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

enum ItemListDisclosureItemTitleColor {
    case primary
    case accent
}

enum ItemListDisclosureStyle {
    case arrow
    case none
}

enum ItemListDisclosureLabelStyle {
    case text
    case badge(UIColor)
    case color(UIColor)
}

enum ItemListDisclosureKind {
    case generic
    case disabled
}

class ItemListDisclosureItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let icon: UIImage?
    let title: String
    let titleColor: ItemListDisclosureItemTitleColor
    let kind: ItemListDisclosureKind
    let label: String
    let labelStyle: ItemListDisclosureLabelStyle
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let disclosureStyle: ItemListDisclosureStyle
    let action: (() -> Void)?
    
    init(theme: PresentationTheme, icon: UIImage? = nil, title: String, kind: ItemListDisclosureKind = .generic, titleColor: ItemListDisclosureItemTitleColor = .primary, label: String, labelStyle: ItemListDisclosureLabelStyle = .text, sectionId: ItemListSectionId, style: ItemListStyle, disclosureStyle: ItemListDisclosureStyle = .arrow, action: (() -> Void)?) {
        self.theme = theme
        self.icon = icon
        self.title = title
        self.titleColor = titleColor
        self.kind = kind
        self.labelStyle = labelStyle
        self.label = label
        self.sectionId = sectionId
        self.style = style
        self.disclosureStyle = disclosureStyle
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListDisclosureItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListDisclosureItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let titleFont = Font.regular(17.0)
private let badgeFont = Font.regular(15.0)

class ItemListDisclosureItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let iconNode: ASImageNode
    let titleNode: TextNode
    let labelNode: TextNode
    let arrowNode: ASImageNode
    let labelBadgeNode: ASImageNode
    let labelImageNode: ASImageNode
    
    private var item: ItemListDisclosureItem?
    
    override var canBeSelected: Bool {
        if let item = self.item, let _ = item.action {
            return true
        } else {
            return false
        }
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isLayerBacked = true
        
        self.labelBadgeNode = ASImageNode()
        self.labelImageNode = ASImageNode()
        self.labelBadgeNode.displayWithoutProcessing = true
        self.labelBadgeNode.displaysAsynchronously = false
        self.labelBadgeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.arrowNode)
    }
    
    func asyncLayout() -> (_ item: ItemListDisclosureItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        let currentItem = self.item
        
        let currentHasBadge = self.labelBadgeNode.image != nil
        
        return { item, params, neighbors in
            let rightInset: CGFloat
            switch item.disclosureStyle {
                case .none:
                    rightInset = 16.0 + params.rightInset
                case .arrow:
                    rightInset = 34.0 + params.rightInset
            }
            
            var updateArrowImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            var updatedLabelBadgeImage: UIImage?
            var updatedLabelImage: UIImage?
            
            var badgeColor: UIColor?
            if case let .badge(color) = item.labelStyle {
                if item.label.count > 0 {
                    badgeColor = color
                }
            }
            if case let .color(color) = item.labelStyle {
                var updatedColor = true
                if let currentItem = currentItem, case let .color(previousColor) = currentItem.labelStyle, color.isEqual(previousColor) {
                    updatedColor = false
                }
                if updatedColor {
                    updatedLabelImage = generateFilledCircleImage(diameter: 17.0, color: color)
                }
            }
            
            let badgeDiameter: CGFloat = 20.0
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                if let badgeColor = badgeColor {
                    updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
                }
            } else if let badgeColor = badgeColor, !currentHasBadge {
                updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
            }
            
            var updateIcon = false
            if currentItem?.icon != item.icon {
                updateIcon = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            var leftInset = 16.0 + params.leftInset
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
                    contentSize = CGSize(width: params.width, height: 44.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
                    contentSize = CGSize(width: params.width, height: 44.0)
                    insets = itemListNeighborsGroupedInsets(neighbors)
            }
            
            if let _ = item.icon {
                leftInset += 43.0
            }
            
            let labelFont: UIFont
            let labelBadgeColor: UIColor
            if case .badge = item.labelStyle {
                labelBadgeColor = item.theme.list.plainBackgroundColor
                labelFont = badgeFont
            } else {
                labelBadgeColor =  item.theme.list.itemSecondaryTextColor
                labelFont = titleFont
            }
            
            let titleColor: UIColor
                switch item.kind {
                case .generic:
                    titleColor = item.titleColor == .accent ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor
                case .disabled:
                    titleColor = item.theme.list.itemDisabledTextColor
            }
                
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: labelFont, textColor:labelBadgeColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset - 40.0 - titleLayout.size.width - 10.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let icon = item.icon {
                        if strongSelf.iconNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconNode)
                        }
                        if updateIcon {
                            strongSelf.iconNode.image = icon
                        }
                        strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - icon.size.width) / 2.0), y: floor((layout.contentSize.height - icon.size.height) / 2.0)), size: icon.size)
                    } else if strongSelf.iconNode.supernode != nil {
                        strongSelf.iconNode.image = nil
                        strongSelf.iconNode.removeFromSupernode()
                    }
                    
                    if let updateArrowImage = updateArrowImage {
                        strongSelf.arrowNode.image = updateArrowImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    
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
                            switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topStripeNode.isHidden = true
                                default:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            let bottomStripeInset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = leftInset
                                default:
                                    bottomStripeInset = 0.0
                            }
                            
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size)
                    
                    if let updateBadgeImage = updatedLabelBadgeImage {
                        if strongSelf.labelBadgeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.labelBadgeNode, belowSubnode: strongSelf.labelNode)
                        }
                        strongSelf.labelBadgeNode.image = updateBadgeImage
                    }
                    if badgeColor == nil && strongSelf.labelBadgeNode.supernode != nil {
                        strongSelf.labelBadgeNode.image = nil
                        strongSelf.labelBadgeNode.removeFromSupernode()
                    }
                    
                    let badgeWidth = max(badgeDiameter, labelLayout.size.width + 10.0)
                    strongSelf.labelBadgeNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - badgeWidth, y: 12.0), size: CGSize(width: badgeWidth, height: badgeDiameter))
                    
                    if case .badge = item.labelStyle {
                        strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - badgeWidth + (badgeWidth - labelLayout.size.width) / 2.0, y: 13.0), size: labelLayout.size)
                    } else {
                        strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - labelLayout.size.width, y: 11.0), size: labelLayout.size)
                    }
 
                    if case .color = item.labelStyle {
                        if let updatedLabelImage = updatedLabelImage {
                            strongSelf.labelImageNode.image = updatedLabelImage
                        }
                        if strongSelf.labelImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.labelImageNode)
                        }
                        if let image = strongSelf.labelImageNode.image {
                            strongSelf.labelImageNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 50.0, y: floor((layout.contentSize.height - image.size.height) / 2.0)), size: image.size)
                        }
                    } else if strongSelf.labelImageNode.supernode != nil {
                        strongSelf.labelImageNode.removeFromSupernode()
                        strongSelf.labelImageNode.image = nil
                    }
                    
                    if let arrowImage = strongSelf.arrowNode.image {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 15.0 - arrowImage.size.width, y: 15.0), size: arrowImage.size)
                    }
                    
                    switch item.disclosureStyle {
                        case .none:
                            strongSelf.arrowNode.isHidden = true
                        case .arrow:
                            strongSelf.arrowNode.isHidden = false
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: 44.0 + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && self.item?.kind != ItemListDisclosureKind.disabled {
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
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
