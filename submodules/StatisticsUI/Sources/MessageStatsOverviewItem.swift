import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

class MessageStatsOverviewItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let stats: MessageStats
    let publicShares: Int32?
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(presentationData: ItemListPresentationData, stats: MessageStats, publicShares: Int32?, sectionId: ItemListSectionId, style: ItemListStyle) {
        self.presentationData = presentationData
        self.stats = stats
        self.publicShares = publicShares
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MessageStatsOverviewItemNode()
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? MessageStatsOverviewItemNode {
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
    
    var selectable: Bool = false
}

class MessageStatsOverviewItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let leftValueLabel: ImmediateTextNode
    private let centerValueLabel: ImmediateTextNode
    private let rightValueLabel: ImmediateTextNode
    
    private let leftTitleLabel: ImmediateTextNode
    private let centerTitleLabel: ImmediateTextNode
    private let rightTitleLabel: ImmediateTextNode
    
    private var item: MessageStatsOverviewItem?
        
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
      
        self.leftValueLabel = ImmediateTextNode()
        self.centerValueLabel = ImmediateTextNode()
        self.rightValueLabel = ImmediateTextNode()
        
        self.leftTitleLabel = ImmediateTextNode()
        self.centerTitleLabel = ImmediateTextNode()
        self.rightTitleLabel = ImmediateTextNode()
    
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.leftValueLabel)
        self.addSubnode(self.centerValueLabel)
        self.addSubnode(self.rightValueLabel)
        
        self.addSubnode(self.leftTitleLabel)
        self.addSubnode(self.centerTitleLabel)
        self.addSubnode(self.rightTitleLabel)
    }
    
    func asyncLayout() -> (_ item: MessageStatsOverviewItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLeftValueLabelLayout = TextNode.asyncLayout(self.leftValueLabel)
        let makeRightValueLabelLayout = TextNode.asyncLayout(self.rightValueLabel)
        let makeCenterValueLabelLayout = TextNode.asyncLayout(self.centerValueLabel)
        
        let makeLeftTitleLabelLayout = TextNode.asyncLayout(self.leftTitleLabel)
        let makeRightTitleLabelLayout = TextNode.asyncLayout(self.rightTitleLabel)
        let makeCenterTitleLabelLayout = TextNode.asyncLayout(self.centerTitleLabel)
    
        let currentItem = self.item
        
        return { item, params, neighbors in
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let topInset: CGFloat = 14.0
            let sideInset: CGFloat = 16.0
            
            var height: CGFloat = topInset * 2.0
            
            let leftInset = params.leftInset
            let rightInset = params.rightInset
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let valueFont = Font.semibold(item.presentationData.fontSize.itemListBaseFontSize)
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            let leftValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let rightValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let centerValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?

            let leftTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let rightTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let centerTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
                    
            leftValueLabelLayoutAndApply = makeLeftValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: compactNumericCountString(item.stats.views), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            centerValueLabelLayoutAndApply = makeCenterValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.publicShares.flatMap { compactNumericCountString(Int($0)) } ?? "–", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            rightValueLabelLayoutAndApply = makeRightValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.publicShares.flatMap { "≈\( compactNumericCountString(max(0, item.stats.forwards - Int($0))))" } ?? "–", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        
            leftTitleLabelLayoutAndApply = makeLeftTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_Message_Views, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            centerTitleLabelLayoutAndApply = makeCenterTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_Message_PublicShares, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            rightTitleLabelLayoutAndApply = makeRightTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_Message_PrivateShares, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            height += rightValueLabelLayoutAndApply!.0.size.height + rightTitleLabelLayoutAndApply!.0.size.height
            
            let contentSize = CGSize(width: params.width, height: height)            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                                     
                    let _ = leftValueLabelLayoutAndApply?.1()
                    let _ = centerValueLabelLayoutAndApply?.1()
                    let _ = rightValueLabelLayoutAndApply?.1()
                    let _ = leftTitleLabelLayoutAndApply?.1()
                    let _ = centerTitleLabelLayoutAndApply?.1()
                    let _ = rightTitleLabelLayoutAndApply?.1()
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                    }
                    
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
                    
                    let maxLeftWidth = max(leftValueLabelLayoutAndApply?.0.size.width ?? 0.0, leftTitleLabelLayoutAndApply?.0.size.width ?? 0.0)
                    let maxCenterWidth = max(centerValueLabelLayoutAndApply?.0.size.width ?? 0.0, centerTitleLabelLayoutAndApply?.0.size.width ?? 0.0)
                    let maxRightWidth = max(rightValueLabelLayoutAndApply?.0.size.width ?? 0.0, rightTitleLabelLayoutAndApply?.0.size.width ?? 0.0)
                    
                    let horizontalSpacing = min(60, (params.width - leftInset - rightInset - sideInset * 2.0 - maxLeftWidth - maxCenterWidth - maxRightWidth) / 2.0)
                    
                    var x: CGFloat = leftInset + (params.width - leftInset - rightInset - maxLeftWidth - maxCenterWidth - maxRightWidth - horizontalSpacing * 2.0) / 2.0
                    if let leftValueLabelLayout = leftValueLabelLayoutAndApply?.0, let leftTitleLabelLayout = leftTitleLabelLayoutAndApply?.0 {
                        strongSelf.leftValueLabel.frame = CGRect(origin: CGPoint(x: x, y: topInset), size: leftValueLabelLayout.size)
                        strongSelf.leftTitleLabel.frame = CGRect(origin: CGPoint(x: x, y: strongSelf.leftValueLabel.frame.maxY), size: leftTitleLabelLayout.size)
                        x += max(leftValueLabelLayout.size.width, leftTitleLabelLayout.size.width) + horizontalSpacing
                    }
                    
                    if let centerValueLabelLayout = centerValueLabelLayoutAndApply?.0, let centerTitleLabelLayout = centerTitleLabelLayoutAndApply?.0 {
                        strongSelf.centerValueLabel.frame = CGRect(origin: CGPoint(x: x, y: topInset), size: centerValueLabelLayout.size)
                        strongSelf.centerTitleLabel.frame = CGRect(origin: CGPoint(x: x, y: strongSelf.centerValueLabel.frame.maxY), size: centerTitleLabelLayout.size)
                        x += max(centerValueLabelLayout.size.width, centerTitleLabelLayout.size.width) + horizontalSpacing
                    }
                                        
                    if let rightValueLabelLayout = rightValueLabelLayoutAndApply?.0, let rightTitleLabelLayout = rightTitleLabelLayoutAndApply?.0 {
                        strongSelf.rightValueLabel.frame = CGRect(origin: CGPoint(x: x, y: topInset), size: rightValueLabelLayout.size)
                        strongSelf.rightTitleLabel.frame = CGRect(origin: CGPoint(x: x, y: strongSelf.rightValueLabel.frame.maxY), size: rightTitleLabelLayout.size)
                    }
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

