import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

public enum ItemListCheckboxItemStyle {
    case left
    case right
}

public enum ItemListCheckboxItemColor {
    case accent
    case secondary
}

public class ItemListCheckboxItem: ListViewItem, ItemListItem {
    public enum IconPlacement {
        case `default`
        case check
    }
    
    public enum TextColor {
        case primary
        case accent
    }
    
    let presentationData: ItemListPresentationData
    let icon: UIImage?
    let iconSize: CGSize?
    let iconPlacement: IconPlacement
    let title: String
    let style: ItemListCheckboxItemStyle
    let color: ItemListCheckboxItemColor
    let textColor: TextColor
    let checked: Bool
    let zeroSeparatorInsets: Bool
    public let sectionId: ItemListSectionId
    let action: () -> Void
    let deleteAction: (() -> Void)?
    
    public init(presentationData: ItemListPresentationData, icon: UIImage? = nil, iconSize: CGSize? = nil, iconPlacement: IconPlacement = .default, title: String, style: ItemListCheckboxItemStyle, color: ItemListCheckboxItemColor = .accent, textColor: TextColor = .primary, checked: Bool, zeroSeparatorInsets: Bool, sectionId: ItemListSectionId, action: @escaping () -> Void, deleteAction: (() -> Void)? = nil) {
        self.presentationData = presentationData
        self.icon = icon
        self.iconSize = iconSize
        self.iconPlacement = iconPlacement
        self.title = title
        self.style = style
        self.color = color
        self.textColor = textColor
        self.checked = checked
        self.zeroSeparatorInsets = zeroSeparatorInsets
        self.sectionId = sectionId
        self.action = action
        self.deleteAction = deleteAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListCheckboxItemNode()
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
            if let nodeValue = node() as? ItemListCheckboxItemNode {
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
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

public class ItemListCheckboxItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let activateArea: AccessibilityAreaNode
    
    private let contentParentNode: ASDisplayNode
    private let contentContainerNode: ASDisplayNode
    private let imageNode: ASImageNode
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    
    private var item: ItemListCheckboxItem?
    
    override public var controlsContainer: ASDisplayNode {
        return self.contentParentNode
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.contentParentNode = ASDisplayNode()
        self.contentContainerNode = ASDisplayNode()
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.displaysAsynchronously = false
        
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
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.contentParentNode)
        self.contentParentNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.imageNode)
        self.contentContainerNode.addSubnode(self.iconNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.addSubnode(self.activateArea)
        
        self.activateArea.activate = { [weak self] in
            self?.item?.action()
            return true
        }
    }
    
    public func asyncLayout() -> (_ item: ItemListCheckboxItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var leftInset: CGFloat = params.leftInset
            
            switch item.style {
            case .left:
                leftInset += 62.0
            case .right:
                leftInset += 16.0
            }
            
            let iconInset: CGFloat = 62.0
            if item.icon != nil {
                switch item.iconPlacement {
                case .default:
                    leftInset += iconInset
                case .check:
                    break
                }
            }
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            let titleColor: UIColor
            switch item.textColor {
            case .primary:
                titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            case .accent:
                titleColor = item.presentationData.theme.list.itemAccentColor
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 28.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            var updateCheckImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            if currentItem?.presentationData.theme !== item.presentationData.theme || currentItem?.color != item.color {
                switch item.color {
                case .accent:
                    updateCheckImage = PresentationResourcesItemList.checkIconImage(item.presentationData.theme)
                case .secondary:
                    updateCheckImage = PresentationResourcesItemList.secondaryCheckIconImage(item.presentationData.theme)
                }
            }

            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.contentParentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: layout.contentSize.height))
                    strongSelf.contentContainerNode.frame = CGRect(origin: CGPoint(x: strongSelf.contentContainerNode.frame.minX, y: 0.0), size: CGSize(width: params.width, height: layout.contentSize.height))
                    
                    strongSelf.activateArea.accessibilityLabel = item.title
                    if item.checked {
                        strongSelf.activateArea.accessibilityValue = "Selected"
                    } else {
                        strongSelf.activateArea.accessibilityValue = ""
                    }
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    if let updateCheckImage = updateCheckImage {
                        strongSelf.iconNode.image = updateCheckImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    
                    if let image = strongSelf.iconNode.image {
                        switch item.style {
                        case .left:
                            strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - image.size.width) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                        case .right:
                            strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - image.size.width - floor((44.0 - image.size.width) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                        }
                    }
                    strongSelf.iconNode.isHidden = !item.checked
                    
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
                        strongSelf.insertSubnode(strongSelf.maskNode, aboveSubnode: strongSelf.contentParentNode)
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
                    if item.zeroSeparatorInsets {
                        bottomStripeInset = 0.0
                    } else {
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size)
                    
                    if let icon = item.icon {
                        let iconSize = item.iconSize ?? icon.size
                        strongSelf.imageNode.image = icon
                        
                        let iconFrame: CGRect
                        switch item.iconPlacement {
                        case .default:
                            iconFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - iconSize.width) / 2.0), y: floor((layout.contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                        case .check:
                            iconFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - iconSize.width) / 2.0), y: floor((contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                        }
                        strongSelf.imageNode.frame = iconFrame
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: strongSelf.backgroundNode.frame.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if item.deleteAction != nil {
                        strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                    } else {
                        strongSelf.setRevealOptions((left: [], right: []))
                    }
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(x: offset, y: self.contentContainerNode.frame.minY), size: self.contentContainerNode.bounds.size))
    }

    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let item = self.item {
            item.deleteAction?()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        
        return result
    }
}
