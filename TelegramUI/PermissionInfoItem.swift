import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class PermissionInfoItem: ListViewItem {
    let selectable: Bool = false
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let subject: DeviceAccessSubject
    let type: AccessType
    let style: ItemListStyle
    let suppressed: Bool
    let close: () -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, subject: DeviceAccessSubject, type: AccessType, style: ItemListStyle, suppressed: Bool, close: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.subject = subject
        self.type = type
        self.style = style
        self.suppressed = suppressed
        self.close = close
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PermissionInfoItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, nil)
            
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
            if let nodeValue = node() as? PermissionInfoItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

class PermissionInfoItemListItem: PermissionInfoItem, ItemListItem {
    let sectionId: ItemListSectionId
    
    init(theme: PresentationTheme, strings: PresentationStrings, subject: DeviceAccessSubject, type: AccessType, style: ItemListStyle, sectionId: ItemListSectionId, suppressed: Bool, close: @escaping () -> Void) {
        self.sectionId = sectionId
        super.init(theme: theme, strings: strings, subject: subject, type: type, style: style, suppressed: suppressed, close: close)
    }
    
    override func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PermissionInfoItemNode()
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
    
    override func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? PermissionInfoItemNode {
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
}

private let titleFont = Font.semibold(17.0)
private let textFont = Font.regular(16.0)
private let badgeFont = Font.regular(15.0)

class PermissionInfoItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let closeButton: HighlightableButtonNode

    let badgeNode: ASImageNode
    let labelNode: TextNode
    let titleNode: TextNode
    let textNode: TextNode
    
    private var item: PermissionInfoItem?
    
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
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.badgeNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.closeButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closeButtonPressed), forControlEvents: .touchUpInside)
    }
    
    func asyncLayout() -> (_ item: PermissionInfoItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors?) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
    
            var updatedTheme: PresentationTheme?
            var updatedBadgeImage: UIImage?
            
            var updatedCloseIcon: UIImage?
            
            let badgeDiameter: CGFloat = 20.0
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updatedBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: item.theme.list.itemDestructiveColor)
                updatedCloseIcon = PresentationResourcesItemList.itemListCloseIconImage(item.theme)
            }
            
            let insets: UIEdgeInsets
            if let neighbors = neighbors {
                insets = itemListNeighborsGroupedInsets(neighbors)
            } else {
                insets = UIEdgeInsets()
            }
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
                case .blocks:
                    itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
            }
            
            let title: String
            let text: String
            switch item.subject {
                case .contacts:
                    title = item.strings.Contacts_PermissionsTitle
                    text = item.strings.Contacts_PermissionsText
                case .notifications:
                    switch item.type {
                        case .unreachable:
                            title = item.strings.Notifications_PermissionsUnreachableTitle
                            text = item.strings.Notifications_PermissionsUnreachableText
                        default:
                            title = item.strings.Notifications_PermissionsTitle
                            text = item.strings.Notifications_PermissionsText
                    }
                default:
                    title = ""
                    text = ""
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "!", font: badgeFont, textColor: item.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: badgeDiameter, height: badgeDiameter), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - badgeDiameter - 8.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: textFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
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
                    if let neighbors = neighbors {
                        switch neighbors.top {
                            case .sameSection(false):
                                strongSelf.topStripeNode.isHidden = true
                            default:
                                strongSelf.topStripeNode.isHidden = false
                        }
                    }
                    let bottomStripeInset: CGFloat
                    if let neighbors = neighbors {
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                            default:
                                bottomStripeInset = 0.0
                        }
                    } else {
                        bottomStripeInset = leftInset
                    }
                    
                    if let item = strongSelf.item {
                        switch (item.subject, item.type, item.suppressed) {
                            case (.contacts, _, false), (.notifications, .unreachable, _):
                                strongSelf.closeButton.isHidden = false
                            default:
                                strongSelf.closeButton.isHidden = true
                        }
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
                    
                    if let updatedCloseIcon = updatedCloseIcon {
                        strongSelf.closeButton.setImage(updatedCloseIcon, for: [])
                    }
                    
                    strongSelf.badgeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 16.0), size: CGSize(width: badgeDiameter, height: badgeDiameter))
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.badgeNode.frame.midX - labelLayout.size.width / 2.0, y: strongSelf.badgeNode.frame.minY + 1.0), size: labelLayout.size)
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: strongSelf.badgeNode.frame.maxX + 8.0, y: 16.0), size: titleLayout.size)
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + 9.0), size: textLayout.size)
                    
                    strongSelf.closeButton.frame = CGRect(x: params.width - rightInset - 21.0, y: 10.0, width: 32.0, height: 32.0)
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
    
    @objc func closeButtonPressed() {
        if let item = self.item {
            item.close()
        }
    }
}
