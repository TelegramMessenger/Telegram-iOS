import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

class StatsOverviewItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let stats: ChannelStats
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(presentationData: ItemListPresentationData, stats: ChannelStats, sectionId: ItemListSectionId, style: ItemListStyle) {
        self.presentationData = presentationData
        self.stats = stats
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = StatsOverviewItemNode()
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
            if let nodeValue = node() as? StatsOverviewItemNode {
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

class StatsOverviewItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let followersValueLabel: ImmediateTextNode
    private let viewsPerPostValueLabel: ImmediateTextNode
    private let sharesPerPostValueLabel: ImmediateTextNode
    private let enabledNotificationsValueLabel: ImmediateTextNode
    
    private let followersTitleLabel: ImmediateTextNode
    private let viewsPerPostTitleLabel: ImmediateTextNode
    private let sharesPerPostTitleLabel: ImmediateTextNode
    private let enabledNotificationsTitleLabel: ImmediateTextNode
    
    private let followersDeltaLabel: ImmediateTextNode
    private let viewsPerPostDeltaLabel: ImmediateTextNode
    private let sharesPerPostDeltaLabel: ImmediateTextNode
    
    private var item: StatsOverviewItem?
        
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
      
        self.followersValueLabel = ImmediateTextNode()
        self.viewsPerPostValueLabel = ImmediateTextNode()
        self.sharesPerPostValueLabel = ImmediateTextNode()
        self.enabledNotificationsValueLabel = ImmediateTextNode()
        
        self.followersTitleLabel = ImmediateTextNode()
        self.viewsPerPostTitleLabel = ImmediateTextNode()
        self.sharesPerPostTitleLabel = ImmediateTextNode()
        self.enabledNotificationsTitleLabel = ImmediateTextNode()
        
        self.followersDeltaLabel = ImmediateTextNode()
        self.viewsPerPostDeltaLabel = ImmediateTextNode()
        self.sharesPerPostDeltaLabel = ImmediateTextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.followersValueLabel)
        self.addSubnode(self.viewsPerPostValueLabel)
        self.addSubnode(self.sharesPerPostValueLabel)
        self.addSubnode(self.enabledNotificationsValueLabel)
        
        self.addSubnode(self.followersTitleLabel)
        self.addSubnode(self.viewsPerPostTitleLabel)
        self.addSubnode(self.sharesPerPostTitleLabel)
        self.addSubnode(self.enabledNotificationsTitleLabel)
        
        self.addSubnode(self.followersDeltaLabel)
        self.addSubnode(self.viewsPerPostDeltaLabel)
        self.addSubnode(self.sharesPerPostDeltaLabel)
    }
    
    func asyncLayout() -> (_ item: StatsOverviewItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeFollowersValueLabelLayout = TextNode.asyncLayout(self.followersValueLabel)
        let makeViewsPerPostValueLabelLayout = TextNode.asyncLayout(self.viewsPerPostValueLabel)
        let makeSharesPerPostValueLabelLayout = TextNode.asyncLayout(self.sharesPerPostValueLabel)
        let makeEnabledNotificationsValueLabelLayout = TextNode.asyncLayout(self.enabledNotificationsValueLabel)
        
        let makeFollowersTitleLabelLayout = TextNode.asyncLayout(self.followersTitleLabel)
        let makeViewsPerPostTitleLabelLayout = TextNode.asyncLayout(self.viewsPerPostTitleLabel)
        let makeSharesPerPostTitleLabelLayout = TextNode.asyncLayout(self.sharesPerPostTitleLabel)
        let makeEnabledNotificationsTitleLabelLayout = TextNode.asyncLayout(self.enabledNotificationsTitleLabel)
        
        let makeFollowersDeltaLabelLayout = TextNode.asyncLayout(self.followersDeltaLabel)
        let makeViewsPerPostDeltaLabelLayout = TextNode.asyncLayout(self.viewsPerPostDeltaLabel)
        let makeSharesPerPostDeltaLabelLayout = TextNode.asyncLayout(self.sharesPerPostDeltaLabel)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let leftInset = params.leftInset
            let rightInset: CGFloat = params.rightInset
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let valueFont = Font.semibold(item.presentationData.fontSize.itemListBaseFontSize)
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            let deltaFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            let displayInteractions = item.stats.sharesPerPost.current > 0 || item.stats.viewsPerPost.current > 0
            
            let (followersValueLabelLayout, followersValueLabelApply) = makeFollowersValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: compactNumericCountString(Int(item.stats.followers.current)), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
             
            let (viewsPerPostValueLabelLayout, viewsPerPostValueLabelApply) = makeViewsPerPostValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayInteractions ? compactNumericCountString(Int(item.stats.viewsPerPost.current)) : "", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (sharesPerPostValueLabelLayout, sharesPerPostValueLabelApply) = makeSharesPerPostValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayInteractions ? compactNumericCountString(Int(item.stats.sharesPerPost.current)) : "", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var enabledNotifications: Double = 0.0
            if item.stats.enabledNotifications.total > 0 {
                enabledNotifications = item.stats.enabledNotifications.value / item.stats.enabledNotifications.total
            }
            
            let (enabledNotificationsValueLabelLayout, enabledNotificationsValueLabelApply) = makeEnabledNotificationsValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: String(format: "%.02f%%", enabledNotifications * 100.0), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (followersTitleLabelLayout, followersTitleLabelApply) = makeFollowersTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_Followers, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (viewsPerPostTitleLabelLayout, viewsPerPostTitleLabelApply) = makeViewsPerPostTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayInteractions ? item.presentationData.strings.Stats_ViewsPerPost : "", font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (sharesPerPostTitleLabelLayout, sharesPerPostTitleLabelApply) = makeSharesPerPostTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayInteractions ? item.presentationData.strings.Stats_SharesPerPost : "", font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (enabledNotificationsTitleLabelLayout, enabledNotificationsTitleLabelApply) = makeEnabledNotificationsTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_EnabledNotifications, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let followersDeltaValue = item.stats.followers.current - item.stats.followers.previous
            let followersDeltaCompact = compactNumericCountString(abs(Int(followersDeltaValue)))
            let followersDelta = followersDeltaValue > 0 ? "+\(followersDeltaCompact)" : "-\(followersDeltaCompact)"
            var followersDeltaPercentage = 0.0
            if item.stats.followers.previous > 0.0 {
                followersDeltaPercentage = abs(followersDeltaValue / item.stats.followers.previous)
            }
             
            let followersDeltaText = abs(followersDeltaPercentage) > 0.0 ? String(format: "%@ (%.02f%%)", followersDelta, followersDeltaPercentage * 100.0) : ""
            
            let (followersDeltaLabelLayout, followersDeltaLabelApply) = makeFollowersDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: followersDeltaText, font: deltaFont, textColor: followersDeltaValue > 0.0 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let viewsPerPostDeltaValue = item.stats.viewsPerPost.current - item.stats.viewsPerPost.previous
            let viewsPerPostDeltaCompact = compactNumericCountString(abs(Int(viewsPerPostDeltaValue)))
            let viewsPerPostDelta = viewsPerPostDeltaValue > 0 ? "+\(viewsPerPostDeltaCompact)" : "-\(viewsPerPostDeltaCompact)"
            var viewsPerPostDeltaPercentage = 0.0
            if item.stats.viewsPerPost.previous > 0.0 {
                viewsPerPostDeltaPercentage = abs(viewsPerPostDeltaValue / item.stats.viewsPerPost.previous)
            }
            
            let viewsPerPostDeltaText = abs(viewsPerPostDeltaPercentage) > 0.0 && displayInteractions ? String(format: "%@ (%.02f%%)", viewsPerPostDelta, viewsPerPostDeltaPercentage * 100.0) : ""
            
            let (viewsPerPostDeltaLabelLayout, viewsPerPostDeltaLabelApply) = makeViewsPerPostDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: viewsPerPostDeltaText, font: deltaFont, textColor: viewsPerPostDeltaValue > 0.0 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let sharesPerPostDeltaValue = item.stats.sharesPerPost.current - item.stats.sharesPerPost.previous
            let sharesPerPostDeltaCompact = compactNumericCountString(abs(Int(sharesPerPostDeltaValue)))
            let sharesPerPostDelta = sharesPerPostDeltaValue > 0 ? "+\(sharesPerPostDeltaCompact)" : "-\(sharesPerPostDeltaCompact)"
            var sharesPerPostDeltaPercentage = 0.0
            if item.stats.sharesPerPost.previous > 0.0 {
                sharesPerPostDeltaPercentage = abs(sharesPerPostDeltaValue / item.stats.sharesPerPost.previous)
            }
            
            let sharesPerPostDeltaText = abs(sharesPerPostDeltaPercentage) > 0.0 && displayInteractions ? String(format: "%@ (%.02f%%)", sharesPerPostDelta, sharesPerPostDeltaPercentage * 100.0) : ""
            
            let (sharesPerPostDeltaLabelLayout, sharesPerPostDeltaLabelApply) = makeSharesPerPostDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: sharesPerPostDeltaText, font: deltaFont, textColor: sharesPerPostDeltaValue > 0.0 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let horizontalSpacing: CGFloat = 4.0
            let verticalSpacing: CGFloat = 18.0
            let topInset: CGFloat = 14.0
            let sideInset: CGFloat = 16.0
            
            var height: CGFloat = topInset * 2.0
            height += enabledNotificationsValueLabelLayout.size.height + enabledNotificationsTitleLabelLayout.size.height
            
            var twoColumnLayout = true
            if max(followersValueLabelLayout.size.width + followersDeltaLabelLayout.size.width + horizontalSpacing + enabledNotificationsValueLabelLayout.size.width, viewsPerPostValueLabelLayout.size.width + viewsPerPostDeltaLabelLayout.size.width + horizontalSpacing + sharesPerPostValueLabelLayout.size.width + sharesPerPostDeltaLabelLayout.size.width) > params.width - leftInset - rightInset {
                twoColumnLayout = false
            }
            
            if twoColumnLayout {
                if !item.stats.viewsPerPost.current.isZero || !item.stats.sharesPerPost.current.isZero {
                    height += verticalSpacing
                    height += sharesPerPostValueLabelLayout.size.height + sharesPerPostTitleLabelLayout.size.height
                }
            } else {
                height += verticalSpacing
                height += enabledNotificationsValueLabelLayout.size.height + enabledNotificationsTitleLabelLayout.size.height
                if !item.stats.viewsPerPost.current.isZero {
                    height += verticalSpacing
                    height += viewsPerPostValueLabelLayout.size.height + viewsPerPostTitleLabelLayout.size.height
                }
                if !item.stats.sharesPerPost.current.isZero {
                    height += verticalSpacing
                    height += sharesPerPostValueLabelLayout.size.height + sharesPerPostTitleLabelLayout.size.height
                }
            }
            
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
                    insets = itemListNeighborsGroupedInsets(neighbors)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = followersValueLabelApply()
                    let _ = viewsPerPostValueLabelApply()
                    let _ = sharesPerPostValueLabelApply()
                    let _ = enabledNotificationsValueLabelApply()
                    
                    let _ = followersTitleLabelApply()
                    let _ = viewsPerPostTitleLabelApply()
                    let _ = sharesPerPostTitleLabelApply()
                    let _ = enabledNotificationsTitleLabelApply()
                    
                    let _ = followersDeltaLabelApply()
                    let _ = viewsPerPostDeltaLabelApply()
                    let _ = sharesPerPostDeltaLabelApply()
                    
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
                    
                    strongSelf.followersValueLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: topInset), size: followersValueLabelLayout.size)
                    strongSelf.followersTitleLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: strongSelf.followersValueLabel.frame.maxY), size: followersTitleLabelLayout.size)
                    strongSelf.followersDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.followersValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.followersValueLabel.frame.maxY - followersDeltaLabelLayout.size.height - 2.0), size: followersDeltaLabelLayout.size)
                    
                    let secondColumnX = twoColumnLayout ? max(layout.size.width / 2.0, sideInset + leftInset + max(followersValueLabelLayout.size.width + followersDeltaLabelLayout.size.width, viewsPerPostValueLabelLayout.size.width + viewsPerPostDeltaLabelLayout.size.width) + horizontalSpacing) : sideInset + leftInset
                    
                    let enabledNotificationsY = twoColumnLayout ? topInset : strongSelf.followersTitleLabel.frame.maxY + verticalSpacing
                    strongSelf.enabledNotificationsValueLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: enabledNotificationsY), size: enabledNotificationsValueLabelLayout.size)
                    strongSelf.enabledNotificationsTitleLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: strongSelf.enabledNotificationsValueLabel.frame.maxY), size: enabledNotificationsTitleLabelLayout.size)
                    
                    let viewsPerPostY = twoColumnLayout ? strongSelf.followersTitleLabel.frame.maxY + verticalSpacing : strongSelf.enabledNotificationsTitleLabel.frame.maxY + verticalSpacing
                    strongSelf.viewsPerPostValueLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: viewsPerPostY), size: viewsPerPostValueLabelLayout.size)
                    strongSelf.viewsPerPostTitleLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: strongSelf.viewsPerPostValueLabel.frame.maxY), size: viewsPerPostTitleLabelLayout.size)
                    strongSelf.viewsPerPostDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.viewsPerPostValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.viewsPerPostValueLabel.frame.maxY - viewsPerPostDeltaLabelLayout.size.height - 2.0), size: viewsPerPostDeltaLabelLayout.size)
            
                    let sharesPerPostY = twoColumnLayout ? strongSelf.enabledNotificationsTitleLabel.frame.maxY + verticalSpacing : strongSelf.viewsPerPostTitleLabel.frame.maxY + verticalSpacing
                    strongSelf.sharesPerPostValueLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: sharesPerPostY), size: sharesPerPostValueLabelLayout.size)
                    strongSelf.sharesPerPostTitleLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: strongSelf.sharesPerPostValueLabel.frame.maxY), size: sharesPerPostTitleLabelLayout.size)
                    strongSelf.sharesPerPostDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.sharesPerPostValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.sharesPerPostValueLabel.frame.maxY - sharesPerPostDeltaLabelLayout.size.height - 2.0), size: sharesPerPostDeltaLabelLayout.size)
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

