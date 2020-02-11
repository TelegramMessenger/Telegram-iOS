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
import Charts

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
            var updatedGraph: ChannelStatsGraph?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let valueFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            let deltaFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            let (followersValueLabelLayout, followersValueLabelApply) = makeFollowersValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "221K", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (viewsPerPostValueLabelLayout, viewsPerPostValueLabelApply) = makeViewsPerPostValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "120K", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (sharesPerPostValueLabelLayout, sharesPerPostValueLabelApply) = makeSharesPerPostValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "350", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
             let (enabledNotificationsValueLabelLayout, enabledNotificationsValueLabelApply) = makeEnabledNotificationsValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "22.77%", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            
            let (followersTitleLabelLayout, followersTitleLabelApply) = makeFollowersTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Followers", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (viewsPerPostTitleLabelLayout, viewsPerPostTitleLabelApply) = makeViewsPerPostTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Views Per Post", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (sharesPerPostTitleLabelLayout, sharesPerPostTitleLabelApply) = makeSharesPerPostTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Shares Per Post", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (enabledNotificationsTitleLabelLayout, enabledNotificationsTitleLabelApply) = makeEnabledNotificationsTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Enabled Notifications", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (followersDeltaLabelLayout, followersDeltaLabelApply) = makeFollowersDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "+474 (0.21%)", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (viewsPerPostDeltaLabelLayout, viewsPerPostDeltaLabelApply) = makeViewsPerPostDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "-14K (10.68%)", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (sharesPerPostDeltaLabelLayout, sharesPerPostDeltaLabelApply) = makeSharesPerPostDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "-134 (27.68%)", font: valueFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    contentSize = CGSize(width: params.width, height: 120.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    contentSize = CGSize(width: params.width, height: 120.0)
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
                    
                    strongSelf.followersValueLabel.frame = CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: followersValueLabelLayout.size)
                    
                    strongSelf.viewsPerPostValueLabel.frame = CGRect(origin: CGPoint(x: leftInset, y: 44.0), size: viewsPerPostValueLabelLayout.size)
                    
                    strongSelf.sharesPerPostValueLabel.frame = CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: 44.0), size: sharesPerPostValueLabelLayout.size)
                    
                    strongSelf.enabledNotificationsValueLabel.frame = CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: 7.0), size: enabledNotificationsValueLabelLayout.size)
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

