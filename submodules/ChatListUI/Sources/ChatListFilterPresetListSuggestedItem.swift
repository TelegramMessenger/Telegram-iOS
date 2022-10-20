import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

public class ChatListFilterPresetListSuggestedItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let label: String
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let installAction: (() -> Void)?
    public let tag: ItemListItemTag?
    
    public init(
        presentationData: ItemListPresentationData,
        title: String,
        label: String,
        sectionId: ItemListSectionId,
        style: ItemListStyle,
        installAction: (() -> Void)?,
        tag: ItemListItemTag? = nil
    ) {
        self.presentationData = presentationData
        self.title = title
        self.label = label
        self.sectionId = sectionId
        self.style = style
        self.installAction = installAction
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListFilterPresetListSuggestedItemNode()
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
            if let nodeValue = node() as? ChatListFilterPresetListSuggestedItemNode {
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
    
    public var selectable: Bool = false
    
    public func selected(listView: ListView){
    }
}

public class ChatListFilterPresetListSuggestedItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let buttonBackgroundNode: ASImageNode
    private let buttonTitleNode: TextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ChatListFilterPresetListSuggestedItem?
    
    override public var canBeSelected: Bool {
        return false
    }
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
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
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.buttonBackgroundNode = ASImageNode()
        self.buttonBackgroundNode.isUserInteractionEnabled = false
        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.buttonBackgroundNode)
        self.addSubnode(self.buttonTitleNode)
        self.addSubnode(self.buttonNode)
        
        self.addSubnode(self.activateArea)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonBackgroundNode.alpha = 0.7
                } else {
                    strongSelf.buttonBackgroundNode.alpha = 1.0
                    strongSelf.buttonBackgroundNode.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.3)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.item?.installAction?()
    }
    
    public func asyncLayout() -> (_ item: ChatListFilterPresetListSuggestedItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let rightInset: CGFloat
            rightInset = 16.0 + params.rightInset
            
            var updatedTheme: PresentationTheme?
            var updatedButtonImage: UIImage?
            let buttonDiameter: CGFloat = 28.0
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedButtonImage = generateStretchableFilledCircleImage(diameter: buttonDiameter, color: item.presentationData.theme.list.itemCheckColors.fillColor)
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset
            
            let titleColor: UIColor
            titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.ChatListFolderSettings_AddRecommended, font: Font.semibold(14.0), textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let additionalTextRightInset: CGFloat = buttonTitleLayout.size.width + 14.0 * 2.0
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset - rightInset - additionalTextRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let detailFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
            
            let labelFont: UIFont
            let labelBadgeColor: UIColor
            var labelConstrain: CGFloat = params.width - params.rightInset - leftInset - 40.0 - titleLayout.size.width - 10.0
            
            labelBadgeColor = item.presentationData.theme.list.itemSecondaryTextColor
            labelFont = detailFont
            labelConstrain = params.width - params.rightInset - 40.0 - leftInset
            
            let multilineLabel = false
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: labelFont, textColor:labelBadgeColor), backgroundColor: nil, maximumNumberOfLines: multilineLabel ? 0 : 1, truncationType: .end, constrainedSize: CGSize(width: labelConstrain, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let verticalInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 3.0
            
            let height: CGFloat
            height = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + labelLayout.size.height
            
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.accessibilityValue = item.label
                    strongSelf.activateArea.accessibilityTraits = []
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    let _ = buttonTitleApply()
                    
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
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    
                    let labelFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    
                    let buttonSize = CGSize(width: buttonTitleLayout.size.width + 14.0 * 2.0, height: buttonDiameter)
                    let buttonFrame = CGRect(origin: CGPoint(x: params.width - rightInset - buttonSize.width, y: floor((layout.contentSize.height - buttonSize.height) / 2.0)), size: buttonSize)
                    strongSelf.buttonNode.frame = buttonFrame
                    if let updatedButtonImage = updatedButtonImage {
                        strongSelf.buttonBackgroundNode.image = updatedButtonImage
                    }
                    strongSelf.buttonBackgroundNode.frame = buttonFrame
                    strongSelf.buttonTitleNode.frame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - buttonTitleLayout.size.width) / 2.0), y: buttonFrame.minY + 1.0 + floor((buttonFrame.height - buttonTitleLayout.size.height) / 2.0)), size: buttonTitleLayout.size)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: height + UIScreenPixel))
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && false {
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
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
