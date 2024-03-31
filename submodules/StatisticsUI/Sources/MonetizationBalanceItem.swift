import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import SolidRoundedButtonNode
import TelegramCore
import TextFormat

final class MonetizationBalanceItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let stats: RevenueStats
    let canWithdraw: Bool
    let isEnabled: Bool
    let withdrawAction: () -> Void
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        stats: RevenueStats,
        canWithdraw: Bool,
        isEnabled: Bool,
        withdrawAction: @escaping () -> Void,
        sectionId: ItemListSectionId,
        style: ItemListStyle
    ) {
        self.context = context
        self.presentationData = presentationData
        self.stats = stats
        self.canWithdraw = canWithdraw
        self.isEnabled = isEnabled
        self.withdrawAction = withdrawAction
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MonetizationBalanceItemNode()
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
            if let nodeValue = node() as? MonetizationBalanceItemNode {
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

final class MonetizationBalanceItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let iconNode: ASImageNode
    private let balanceTextNode: TextNode
    private let valueTextNode: TextNode
    
    private var withdrawButtonNode: SolidRoundedButtonNode?
        
    private let activateArea: AccessibilityAreaNode
    
    private var item: MonetizationBalanceItem?
    
    override var canBeSelected: Bool {
        return false
    }
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.isUserInteractionEnabled = false
        self.iconNode.displaysAsynchronously = false
        
        self.balanceTextNode = TextNode()
        self.balanceTextNode.isUserInteractionEnabled = false
        self.balanceTextNode.displaysAsynchronously = false
        
        self.valueTextNode = TextNode()
        self.valueTextNode.isUserInteractionEnabled = false
        self.valueTextNode.displaysAsynchronously = false
    
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.balanceTextNode)
        self.addSubnode(self.valueTextNode)
    }
    
    func asyncLayout() -> (_ item: MonetizationBalanceItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeBalanceTextLayout = TextNode.asyncLayout(self.balanceTextNode)
        let makeValueTextLayout = TextNode.asyncLayout(self.valueTextNode)
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset
            let rightInset = 16.0 + params.rightInset
            let constrainedWidth = params.width - leftInset - rightInset
            
            let integralFont = Font.with(size: 48.0, design: .round, weight: .semibold)
            let fractionalFont = Font.with(size: 24.0, design: .round, weight: .semibold)
            
            let cryptoValue = formatBalanceText(item.stats.availableBalance, decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
            
            let amountString = amountAttributedString(cryptoValue, integralFont: integralFont, fractionalFont: fractionalFont, color: item.presentationData.theme.list.itemPrimaryTextColor)

            let (balanceLayout, balanceApply) = makeBalanceTextLayout(TextNodeLayoutArguments(attributedString: amountString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let value = item.stats.availableBalance == 0 ? "" : "≈\(formatUsdValue(item.stats.availableBalance, rate: item.stats.usdRate))"
            let (valueLayout, valueApply) = makeValueTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: value, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let verticalInset: CGFloat = 13.0
            let buttonHeight: CGFloat = 50.0
            let buttonSpacing: CGFloat = 12.0
            
            var height: CGFloat = verticalInset * 2.0 + balanceLayout.size.height
            if valueLayout.size.height > 0.0 {
                height += valueLayout.size.height
            } else {
                height -= 6.0
            }
            if item.canWithdraw {
                height += buttonHeight + buttonSpacing
            }

            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = .clear
                insets = UIEdgeInsets()
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
                        
            contentSize = CGSize(width: params.width, height: height)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    let themeUpdated = strongSelf.item?.presentationData.theme !== item.presentationData.theme
                    strongSelf.item = item
                    
                    let _ = balanceApply()
                    let _ = valueApply()
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityTraits = []
                    
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
                    
                    if themeUpdated {
                        strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonBig"), color: item.presentationData.theme.list.itemAccentColor)
                    }

                    var emojiItemSize = CGSize()
                    if let icon = strongSelf.iconNode.image {
                        emojiItemSize = icon.size
                    }
                                        
                    let balanceTotalWidth: CGFloat = emojiItemSize.width + balanceLayout.size.width
                    let balanceTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - balanceTotalWidth) / 2.0) + emojiItemSize.width, y: verticalInset), size: balanceLayout.size)
                    strongSelf.balanceTextNode.frame = balanceTextFrame
                    
                    strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: balanceTextFrame.minX - emojiItemSize.width - 7.0, y: floorToScreenPixels(balanceTextFrame.midY - emojiItemSize.height / 2.0) - 3.0), size: emojiItemSize)
                    
                    strongSelf.valueTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - valueLayout.size.width) / 2.0), y: balanceTextFrame.maxY - 5.0), size: valueLayout.size)
                                      
                    if item.canWithdraw {
                        let withdrawButtonNode: SolidRoundedButtonNode
                        if let currentWithdrawButtonNode = strongSelf.withdrawButtonNode {
                            withdrawButtonNode = currentWithdrawButtonNode
                        } else {
                            var buttonTheme = SolidRoundedButtonTheme(theme: item.presentationData.theme)
                            buttonTheme = buttonTheme.withUpdated(disabledBackgroundColor: buttonTheme.backgroundColor, disabledForegroundColor: buttonTheme.foregroundColor.withAlphaComponent(0.6))
                            withdrawButtonNode = SolidRoundedButtonNode(theme: buttonTheme, height: buttonHeight, cornerRadius: 11.0)
                            withdrawButtonNode.pressed = { [weak self] in
                                if let self, let item = self.item, item.isEnabled {
                                    item.withdrawAction()
                                }
                            }
                            strongSelf.addSubnode(withdrawButtonNode)
                            strongSelf.withdrawButtonNode = withdrawButtonNode
                        }
                        withdrawButtonNode.title = item.presentationData.strings.Monetization_BalanceWithdraw
                        withdrawButtonNode.isEnabled = item.isEnabled
                        
                        let buttonWidth = contentSize.width - leftInset - rightInset
                        let _ = withdrawButtonNode.updateLayout(width: buttonWidth, transition: .immediate)
                        withdrawButtonNode.frame = CGRect(x: leftInset, y: strongSelf.valueTextNode.frame.maxY + buttonSpacing + 3.0, width: buttonWidth, height: buttonHeight)
                    } else {
                        strongSelf.withdrawButtonNode?.removeFromSupernode()
                        strongSelf.withdrawButtonNode = nil
                    }
                }
            })
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
