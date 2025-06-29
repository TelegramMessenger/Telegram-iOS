import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import ItemListUI
import ComponentFlow
import ListActionItemComponent
import MultilineTextComponent
import TelegramStringFormatting
import StarsAvatarComponent

final class StarsTransactionItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let transaction: StarsContext.State.Transaction
    let action: () -> Void
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        transaction: StarsContext.State.Transaction,
        action: @escaping () -> Void,
        sectionId: ItemListSectionId,
        style: ItemListStyle
    ) {
        self.context = context
        self.presentationData = presentationData
        self.transaction = transaction
        self.action = action
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = StarsTransactionItemNode()
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
            if let nodeValue = node() as? StarsTransactionItemNode {
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
    
    var selectable: Bool = true
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

final class StarsTransactionItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let componentView: ComponentView<Empty>
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: StarsTransactionItem?
    
    var tag: ItemListItemTag? = nil
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.componentView = ComponentView<Empty>()
    
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    func asyncLayout() -> (_ item: StarsTransactionItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
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
            
            let height: CGFloat = 78.0

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
                    strongSelf.item = item
                        
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityTraits = []
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
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
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    let fontBaseDisplaySize = 17.0
                    
                    let itemTitle: String
                    let itemSubtitle: String?
                    var itemDate: String
                    switch item.transaction.peer {
                    case let .peer(peer):
                        if item.transaction.flags.contains(.isPaidMessage) {
                            itemTitle = peer.displayTitle(strings: item.presentationData.strings, displayOrder: .firstLast)
                            itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_PaidMessage(item.transaction.paidMessageCount ?? 1)
                        } else if !item.transaction.media.isEmpty {
                            itemTitle = item.presentationData.strings.Stars_Intro_Transaction_MediaPurchase
                            itemSubtitle = peer.displayTitle(strings: item.presentationData.strings, displayOrder: .firstLast)
                        } else if let title = item.transaction.title {
                            itemTitle = title
                            itemSubtitle = peer.displayTitle(strings: item.presentationData.strings, displayOrder: .firstLast)
                        } else {
                            if item.transaction.flags.contains(.isReaction) {
                                itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_Reaction_Title
                            } else if let _ = item.transaction.subscriptionPeriod {
                                itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_SubscriptionFee_Title
                            } else {
                                itemSubtitle = nil
                            }
                            itemTitle = peer.displayTitle(strings: item.presentationData.strings, displayOrder: .firstLast)
                        }
                    case .appStore:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_AppleTopUp_Title
                        itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_AppleTopUp_Subtitle
                    case .playMarket:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_GoogleTopUp_Title
                        itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_GoogleTopUp_Subtitle
                    case .fragment:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_FragmentWithdrawal_Title
                        itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_FragmentWithdrawal_Subtitle
                    case .premiumBot:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_PremiumBotTopUp_Title
                        itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_PremiumBotTopUp_Subtitle
                    case .ads:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_TelegramAds_Title
                        itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_TelegramAds_Subtitle
                    case .apiLimitExtension:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_TelegramBotApi_Title
                        if let floodskipNumber = item.transaction.floodskipNumber {
                            itemSubtitle = item.presentationData.strings.Stars_Intro_Transaction_TelegramBotApi_Messages(floodskipNumber)
                        } else {
                            itemSubtitle = nil
                        }
                    case .unsupported:
                        itemTitle = item.presentationData.strings.Stars_Intro_Transaction_Unsupported_Title
                        itemSubtitle = nil
                    }
                    
                    let itemLabel: NSAttributedString
                    let formattedLabel = formatCurrencyAmountText(item.transaction.count, dateTimeFormat: item.presentationData.dateTimeFormat, showPlus: true)
                    
                    let smallLabelFont = Font.with(size: floor(fontBaseDisplaySize / 17.0 * 13.0))
                    let labelFont = Font.medium(fontBaseDisplaySize)
                    let labelColor = formattedLabel.hasPrefix("-") ? item.presentationData.theme.list.itemDestructiveColor : item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                    itemLabel = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
                    
                    var itemDateColor = item.presentationData.theme.list.itemSecondaryTextColor
                    itemDate = stringForMediumCompactDate(timestamp: item.transaction.date, strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat)
                    if item.transaction.flags.contains(.isRefund) {
                        itemDate += " – \(item.presentationData.strings.Stars_Intro_Transaction_Refund)"
                    } else if item.transaction.flags.contains(.isPending) {
                        itemDate += " – \(item.presentationData.strings.Monetization_Transaction_Pending)"
                    } else if item.transaction.flags.contains(.isFailed) {
                        itemDate += " – \(item.presentationData.strings.Monetization_Transaction_Failed)"
                        itemDateColor = item.presentationData.theme.list.itemDestructiveColor
                    }
                    
                    var titleComponents: [AnyComponentWithIdentity<Empty>] = []
                    titleComponents.append(
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: itemTitle,
                                font: Font.semibold(fontBaseDisplaySize),
                                textColor: item.presentationData.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    if let itemSubtitle {
                        titleComponents.append(
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: itemSubtitle,
                                    font: Font.regular(fontBaseDisplaySize * 16.0 / 17.0),
                                    textColor: item.presentationData.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )))
                        )
                    }
                    titleComponents.append(
                        AnyComponentWithIdentity(id: AnyHashable(2), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: itemDate,
                                font: Font.regular(floor(fontBaseDisplaySize * 14.0 / 17.0)),
                                textColor: itemDateColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    
                    let itemIconName: String
                    let itemIconColor: UIColor?
                    switch item.transaction.count.currency {
                    case .stars:
                        itemIconName = "Premium/Stars/StarMedium"
                        itemIconColor = nil
                    case .ton:
                        itemIconName = "Ads/TonAbout"
                        itemIconColor = labelColor
                    }
                    
                    let itemSize = strongSelf.componentView.update(
                        transition: .immediate,
                        component: AnyComponent(ListActionItemComponent(
                            theme: item.presentationData.theme,
                            title: AnyComponent(VStack(titleComponents, alignment: .left, spacing: 2.0)),
                            contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 8.0, right: 0.0),
                            leftIcon: .custom(AnyComponentWithIdentity(id: "avatar", component: AnyComponent(StarsAvatarComponent(context: item.context, theme: item.presentationData.theme, peer: item.transaction.peer, photo: nil, media: [], uniqueGift: nil, backgroundColor: item.presentationData.theme.list.itemBlocksBackgroundColor))), false),
                            icon: nil,
                            accessory: .custom(ListActionItemComponent.CustomAccessory(component: AnyComponentWithIdentity(id: "label", component: AnyComponent(StarsLabelComponent(text: itemLabel, iconName: itemIconName, iconColor: itemIconColor))), insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16.0))),
                            action: { [weak self] _ in
                                guard let self, let item = self.item else {
                                    return
                                }
                                if !item.transaction.flags.contains(.isLocal) {
                                    item.action()
                                }
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: params.width - params.leftInset - params.rightInset, height: height)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: itemSize)
                    if let itemComponentView = strongSelf.componentView.view {
                        if itemComponentView.superview == nil {
                            strongSelf.view.addSubview(itemComponentView)
                        }
                        itemComponentView.isUserInteractionEnabled = false
                        itemComponentView.frame = itemFrame
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
