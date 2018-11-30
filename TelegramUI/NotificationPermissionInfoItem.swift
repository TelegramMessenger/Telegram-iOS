import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class NotificationPermissionInfoItem: ListViewItem, ItemListItem {
    let selectable: Bool = false
    let sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId) {
        self.theme = theme
        self.strings = strings
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = NotificationPermissionInfoItemNode()
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
            if let nodeValue = node() as? NotificationPermissionInfoItemNode {
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
}

private let titleFont = Font.semibold(17.0)
private let textFont = Font.regular(16.0)
private let badgeFont = Font.regular(15.0)

class NotificationPermissionInfoItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    let badgeNode: ASImageNode
    let labelNode: TextNode
    let titleNode: TextNode
    let textNode: TextNode
    
    private var item: NotificationPermissionInfoItem?
    
    override var canBeSelected: Bool {
        return false
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.badgeNode = ASImageNode()
        self.badgeNode.displayWithoutProcessing = true
        self.badgeNode.displaysAsynchronously = false
        self.badgeNode.isLayerBacked = true
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
    
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.badgeNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (_ item: NotificationPermissionInfoItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
    
            var updatedTheme: PresentationTheme?
            var updatedBadgeImage: UIImage?
            
            let badgeDiameter: CGFloat = 20.0
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updatedBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: item.theme.list.itemDestructiveColor)
            }
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
            let itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "!", font: badgeFont, textColor: item.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: badgeDiameter, height: badgeDiameter), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Turn ON Notifications", font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - badgeDiameter - 8.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Don't miss important messages from your friends and coworkers.", font: textFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: titleLayout.size.height + textLayout.size.height + 36.0)
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                    }
                    
                    let _ = labelApply()
                    let _ = titleApply()
                    let _ = textApply()
                    
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
                    
                    if let updateBadgeImage = updatedBadgeImage {
                        if strongSelf.badgeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.badgeNode, belowSubnode: strongSelf.labelNode)
                        }
                        strongSelf.badgeNode.image = updateBadgeImage
                    }
                    
                    strongSelf.badgeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 16.0), size: CGSize(width: badgeDiameter, height: badgeDiameter))
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.badgeNode.frame.midX - labelLayout.size.width / 2.0, y: strongSelf.badgeNode.frame.minY + 1.0), size: labelLayout.size)
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: strongSelf.badgeNode.frame.maxX + 8.0, y: 16.0), size: titleLayout.size)
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + 9.0), size: textLayout.size)
                }
            })
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
