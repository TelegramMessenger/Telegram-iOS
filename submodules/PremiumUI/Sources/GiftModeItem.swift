import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AvatarNode

public final class GiftModeItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let context: AccountContext
    let iconName: String?
    let title: String
    let subtitle: String?
    let subtitleActive: Bool
    let label: String?
    let badge: String?
    let isSelected: Bool
    public let sectionId: ItemListSectionId
    let action: (() -> Void)?
    
    public init(presentationData: ItemListPresentationData, context: AccountContext, iconName: String? = nil, title: String, subtitle: String?, subtitleActive: Bool = false, label: String?, badge: String?, isSelected: Bool, sectionId: ItemListSectionId, action: (() -> Void)?) {
        self.presentationData = presentationData
        self.iconName = iconName
        self.context = context
        self.title = title
        self.subtitle = subtitle
        self.subtitleActive = subtitleActive
        self.label = label
        self.badge = badge
        self.isSelected = isSelected
        self.sectionId = sectionId
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = GiftModeItemNode()
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? GiftModeItemNode {
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
    
    public var selectable: Bool = true
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

class GiftModeItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    fileprivate var avatarNode: ASImageNode?
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let labelNode: TextNode
    private let badgeTextNode: TextNode
    private var badgeBackgroundNode: ASImageNode?
    
    private var layoutParams: (GiftModeItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var selectableControlNode: ItemListSelectableControlNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private let fetchDisposable = MetaDisposable()
    
    override var canBeSelected: Bool {
        return true
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.containerNode = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
                
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.badgeTextNode = TextNode()
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.contentMode = .left
        self.badgeTextNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.labelNode)
        self.addSubnode(self.activateArea)
    }
        
    override func tapped() {
        guard let item = self.layoutParams?.0 else {
            return
        }
        item.action?()
    }
    
    func asyncLayout() -> (_ item: GiftModeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let selectableControlLayout = ItemListSelectableControlNode.asyncLayout(self.selectableControlNode)
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, neighbors in
            let titleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 17.0 / 17.0))
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
                        
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let rightInset: CGFloat = params.rightInset
            
            let titleAttributedString = NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let statusAttributedString = NSAttributedString(string: item.subtitle ?? "", font: statusFont, textColor: item.subtitleActive ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
            let labelAttributedString = NSAttributedString(string: item.label ?? "", font: titleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 17.0 + params.leftInset
            
            var avatarInset: CGFloat = 0.0
            if let _ = item.iconName {
                avatarInset += 40.0
            }
            
            let verticalInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 2.0
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let separatorHeight = UIScreenPixel
            
            var selectableControlSizeAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            var editingOffset: CGFloat = 0.0
            
            let sizeAndApply = selectableControlLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, item.isSelected, false)
            selectableControlSizeAndApply = sizeAndApply
            editingOffset = sizeAndApply.0
                        
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: labelAttributedString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: .greatestFiniteMagnitude)))
            
            let textConstrainedWidth = params.width - leftInset - 8.0 - editingOffset - rightInset - labelLayout.size.width - avatarInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude)))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textConstrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.size.height)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
                        
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors)
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = titleAttributedString.string
                    strongSelf.activateArea.accessibilityValue = statusAttributedString.string
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    let iconSize = CGSize(width: 40.0, height: 40.0)
                    if let iconName = item.iconName {
                        let iconNode: ASImageNode
                        
                        if let current = strongSelf.avatarNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.displaysAsynchronously = false
                            strongSelf.addSubnode(iconNode)
                            
                            strongSelf.avatarNode = iconNode
                        }
                        
                        let colors: [UIColor]
                        if iconName.contains("away") {
                            colors = [UIColor(rgb: 0x4faaff), UIColor(rgb: 0x017aff)]
                        } else {
                            colors = [UIColor(rgb: 0xc36eff), UIColor(rgb: 0x8c61fa)]
                        }
                        if iconNode.image == nil {
                            iconNode.image = generateAvatarImage(size: iconSize, icon: generateTintedImage(image: UIImage(bundleImageName: iconName), color: .white), iconScale: 1.0, cornerRadius: 20.0, color: .blue, customColors: colors.reversed())
                        }
                        
                        let iconFrame = CGRect(origin: CGPoint(x: leftInset + 38.0, y: floorToScreenPixels((layout.contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                        iconNode.frame = iconFrame
                    }
                    
                    if let selectableControlSizeAndApply = selectableControlSizeAndApply {
                        let selectableControlSize = CGSize(width: selectableControlSizeAndApply.0, height: layout.contentSize.height)
                        let selectableControlFrame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: selectableControlSize)
                        if strongSelf.selectableControlNode == nil {
                            let selectableControlNode = selectableControlSizeAndApply.1(selectableControlSize, false)
                            strongSelf.selectableControlNode = selectableControlNode
                            strongSelf.addSubnode(selectableControlNode)
                            selectableControlNode.frame = selectableControlFrame
                            transition.animatePosition(node: selectableControlNode, from: CGPoint(x: -selectableControlFrame.size.width / 2.0, y: selectableControlFrame.midY))
                            selectableControlNode.alpha = 0.0
                            transition.updateAlpha(node: selectableControlNode, alpha: 1.0)
                        } else if let selectableControlNode = strongSelf.selectableControlNode {
                            transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
                            let _ = selectableControlSizeAndApply.1(selectableControlSize, true)
                        }
                    } else if let selectableControlNode = strongSelf.selectableControlNode {
                        var selectableControlFrame = selectableControlNode.frame
                        selectableControlFrame.origin.x = -selectableControlFrame.size.width
                        strongSelf.selectableControlNode = nil
                        transition.updateAlpha(node: selectableControlNode, alpha: 0.0)
                        transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame, completion: { [weak selectableControlNode] _ in
                            selectableControlNode?.removeFromSupernode()
                        })
                    }
                                        
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = labelApply()
                                                            
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
                        strongSelf.addSubnode(strongSelf.maskNode)
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
                            bottomStripeInset = leftInset + editingOffset
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
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset, y: verticalInset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                    transition.updateFrame(node: strongSelf.labelNode, frame: CGRect(origin: CGPoint(x: layoutSize.width - rightInset - labelLayout.size.width - 18.0, y: floorToScreenPixels((layout.contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size))
                                        
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: strongSelf.backgroundNode.frame.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
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
