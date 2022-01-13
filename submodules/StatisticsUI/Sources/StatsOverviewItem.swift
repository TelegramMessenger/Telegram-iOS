import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

protocol PeerStats {
    
}

extension ChannelStats: PeerStats {
    
}

extension GroupStats: PeerStats {
    
}

class StatsOverviewItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let stats: PeerStats
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(presentationData: ItemListPresentationData, stats: PeerStats, sectionId: ItemListSectionId, style: ItemListStyle) {
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
    
    private let topLeftValueLabel: ImmediateTextNode
    private let bottomLeftValueLabel: ImmediateTextNode
    private let bottomRightValueLabel: ImmediateTextNode
    private let topRightValueLabel: ImmediateTextNode
    
    private let topLeftTitleLabel: ImmediateTextNode
    private let bottomLeftTitleLabel: ImmediateTextNode
    private let bottomRightTitleLabel: ImmediateTextNode
    private let topRightTitleLabel: ImmediateTextNode
    
    private let topLeftDeltaLabel: ImmediateTextNode
    private let bottomLeftDeltaLabel: ImmediateTextNode
    private let bottomRightDeltaLabel: ImmediateTextNode
    private let topRightDeltaLabel: ImmediateTextNode
    
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
      
        self.topLeftValueLabel = ImmediateTextNode()
        self.bottomLeftValueLabel = ImmediateTextNode()
        self.bottomRightValueLabel = ImmediateTextNode()
        self.topRightValueLabel = ImmediateTextNode()
        
        self.topLeftTitleLabel = ImmediateTextNode()
        self.bottomLeftTitleLabel = ImmediateTextNode()
        self.bottomRightTitleLabel = ImmediateTextNode()
        self.topRightTitleLabel = ImmediateTextNode()
        
        self.topLeftDeltaLabel = ImmediateTextNode()
        self.bottomLeftDeltaLabel = ImmediateTextNode()
        self.bottomRightDeltaLabel = ImmediateTextNode()
        self.topRightDeltaLabel = ImmediateTextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.topLeftValueLabel)
        self.addSubnode(self.bottomLeftValueLabel)
        self.addSubnode(self.bottomRightValueLabel)
        self.addSubnode(self.topRightValueLabel)
        
        self.addSubnode(self.topLeftTitleLabel)
        self.addSubnode(self.bottomLeftTitleLabel)
        self.addSubnode(self.bottomRightTitleLabel)
        self.addSubnode(self.topRightTitleLabel)
        
        self.addSubnode(self.topLeftDeltaLabel)
        self.addSubnode(self.bottomLeftDeltaLabel)
        self.addSubnode(self.bottomRightDeltaLabel)
        self.addSubnode(self.topRightDeltaLabel)
    }
    
    func asyncLayout() -> (_ item: StatsOverviewItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTopLeftValueLabelLayout = TextNode.asyncLayout(self.topLeftValueLabel)
        let makeTopRightValueLabelLayout = TextNode.asyncLayout(self.topRightValueLabel)
        let makeBottomLeftValueLabelLayout = TextNode.asyncLayout(self.bottomLeftValueLabel)
        let makeBottomRightValueLabelLayout = TextNode.asyncLayout(self.bottomRightValueLabel)
        
        let makeTopLeftTitleLabelLayout = TextNode.asyncLayout(self.topLeftTitleLabel)
        let makeTopRightTitleLabelLayout = TextNode.asyncLayout(self.topRightTitleLabel)
        let makeBottomLeftTitleLabelLayout = TextNode.asyncLayout(self.bottomLeftTitleLabel)
        let makeBottomRightTitleLabelLayout = TextNode.asyncLayout(self.bottomRightTitleLabel)
        
        let makeTopLeftDeltaLabelLayout = TextNode.asyncLayout(self.topLeftDeltaLabel)
        let makeTopRightDeltaLabelLayout = TextNode.asyncLayout(self.topRightDeltaLabel)
        let makeBottomLeftDeltaLabelLayout = TextNode.asyncLayout(self.bottomLeftDeltaLabel)
        let makeBottomRightDeltaLabelLayout = TextNode.asyncLayout(self.bottomRightDeltaLabel)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let horizontalSpacing: CGFloat = 4.0
            let verticalSpacing: CGFloat = 18.0
            let topInset: CGFloat = 14.0
            let sideInset: CGFloat = 16.0
            
            var height: CGFloat = topInset * 2.0
            
            let leftInset = params.leftInset
            let rightInset: CGFloat = params.rightInset
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
            let deltaFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            let topLeftValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let topRightValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let bottomLeftValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let bottomRightValueLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?

            let topLeftTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let topRightTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let bottomLeftTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let bottomRightTitleLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            
            let topLeftDeltaLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let topRightDeltaLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let bottomLeftDeltaLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            let bottomRightDeltaLabelLayoutAndApply: ((Display.TextNodeLayout, () -> Display.TextNode))?
            
            var twoColumnLayout = true
            
            func deltaText(_ value: StatsValue) -> (String, Bool, Bool) {
                let deltaValue = value.current - value.previous
                let deltaCompact = compactNumericCountString(abs(Int(deltaValue)))
                let delta = deltaValue > 0 ? "+\(deltaCompact)" : "-\(deltaCompact)"
                var deltaPercentage = 0.0
                if value.previous > 0.0 {
                    deltaPercentage = abs(deltaValue / value.previous)
                }
                
                return (abs(deltaPercentage) > 0.0 ? String(format: "%@ (%.02f%%)", delta, deltaPercentage * 100.0) : "", deltaValue > 0.0, abs(deltaValue) > 0.0)
            }
            
            if let stats = item.stats as? ChannelStats {
                let viewsPerPostDelta = deltaText(stats.viewsPerPost)
                let sharesPerPostDelta = deltaText(stats.sharesPerPost)
                
                let displayBottomRow = stats.sharesPerPost.current > 0 || viewsPerPostDelta.2 || stats.viewsPerPost.current > 0 || sharesPerPostDelta.2
                
                topLeftValueLabelLayoutAndApply = makeTopLeftValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: compactNumericCountString(Int(stats.followers.current)), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                                 
                var enabledNotifications: Double = 0.0
                if stats.enabledNotifications.total > 0 {
                    enabledNotifications = stats.enabledNotifications.value / stats.enabledNotifications.total
                }
                
                topRightValueLabelLayoutAndApply = makeTopRightValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: String(format: "%.02f%%", enabledNotifications * 100.0), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomLeftValueLabelLayoutAndApply = makeBottomLeftValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? compactNumericCountString(Int(stats.viewsPerPost.current)) : "", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomRightValueLabelLayoutAndApply = makeBottomRightValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? compactNumericCountString(Int(stats.sharesPerPost.current)) : "", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                topLeftTitleLabelLayoutAndApply = makeTopLeftTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_Followers, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                                
                topRightTitleLabelLayoutAndApply = makeTopRightTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_EnabledNotifications, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomLeftTitleLabelLayoutAndApply = makeBottomLeftTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? item.presentationData.strings.Stats_ViewsPerPost : "", font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomRightTitleLabelLayoutAndApply = makeBottomRightTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? item.presentationData.strings.Stats_SharesPerPost : "", font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                             
                let followersDelta = deltaText(stats.followers)
                topLeftDeltaLabelLayoutAndApply = makeTopLeftDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: followersDelta.0, font: deltaFont, textColor: followersDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                topRightDeltaLabelLayoutAndApply = nil
                
                bottomLeftDeltaLabelLayoutAndApply = makeBottomLeftDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: viewsPerPostDelta.0, font: deltaFont, textColor: viewsPerPostDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomRightDeltaLabelLayoutAndApply = makeBottomRightDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: sharesPerPostDelta.0, font: deltaFont, textColor: sharesPerPostDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                
                height += topRightValueLabelLayoutAndApply!.0.size.height + topRightTitleLabelLayoutAndApply!.0.size.height
                
                if max(topLeftValueLabelLayoutAndApply!.0.size.width + topLeftDeltaLabelLayoutAndApply!.0.size.width + horizontalSpacing + topRightValueLabelLayoutAndApply!.0.size.width, bottomLeftValueLabelLayoutAndApply!.0.size.width + bottomLeftDeltaLabelLayoutAndApply!.0.size.width + horizontalSpacing + bottomRightValueLabelLayoutAndApply!.0.size.width + bottomRightDeltaLabelLayoutAndApply!.0.size.width) > params.width - leftInset - rightInset {
                    twoColumnLayout = false
                }
                
                if twoColumnLayout {
                    if displayBottomRow {
                        height += verticalSpacing
                        height += bottomRightValueLabelLayoutAndApply!.0.size.height + bottomRightTitleLabelLayoutAndApply!.0.size.height
                    }
                } else {
                    height += verticalSpacing
                    height += topRightValueLabelLayoutAndApply!.0.size.height + topRightTitleLabelLayoutAndApply!.0.size.height
                    if !stats.viewsPerPost.current.isZero || viewsPerPostDelta.2 {
                        height += verticalSpacing
                        height += bottomLeftValueLabelLayoutAndApply!.0.size.height + bottomLeftTitleLabelLayoutAndApply!.0.size.height
                    }
                    if !stats.sharesPerPost.current.isZero || sharesPerPostDelta.2 {
                        height += verticalSpacing
                        height += bottomRightValueLabelLayoutAndApply!.0.size.height + bottomRightTitleLabelLayoutAndApply!.0.size.height
                    }
                }
            } else if let stats = item.stats as? GroupStats {
                let viewersDelta = deltaText(stats.viewers)
                let postersDelta = deltaText(stats.posters)
                let displayBottomRow = stats.viewers.current > 0 || viewersDelta.2 || stats.posters.current > 0 || postersDelta.2
                   
                topLeftValueLabelLayoutAndApply = makeTopLeftValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: compactNumericCountString(Int(stats.members.current)), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                topRightValueLabelLayoutAndApply = makeTopRightValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: compactNumericCountString(Int(stats.messages.current)), font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomLeftValueLabelLayoutAndApply = makeBottomLeftValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? compactNumericCountString(Int(stats.viewers.current)) : "", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomRightValueLabelLayoutAndApply = makeBottomRightValueLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? compactNumericCountString(Int(stats.posters.current)) : "", font: valueFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                topLeftTitleLabelLayoutAndApply = makeTopLeftTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_GroupMembers, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                topRightTitleLabelLayoutAndApply = makeTopRightTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_GroupMessages, font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomLeftTitleLabelLayoutAndApply = makeBottomLeftTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? item.presentationData.strings.Stats_GroupViewers : "", font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomRightTitleLabelLayoutAndApply = makeBottomRightTitleLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayBottomRow ? item.presentationData.strings.Stats_GroupPosters : "", font: titleFont, textColor: item.presentationData.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let membersDelta = deltaText(stats.members)
                topLeftDeltaLabelLayoutAndApply = makeTopLeftDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: membersDelta.0, font: deltaFont, textColor: membersDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let messagesDelta = deltaText(stats.messages)
                topRightDeltaLabelLayoutAndApply = makeTopRightDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: messagesDelta.0, font: deltaFont, textColor: messagesDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomLeftDeltaLabelLayoutAndApply = makeBottomLeftDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: viewersDelta.0, font: deltaFont, textColor: viewersDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                bottomRightDeltaLabelLayoutAndApply = makeBottomRightDeltaLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: postersDelta.0, font: deltaFont, textColor: postersDelta.1 ? item.presentationData.theme.list.freeTextSuccessColor : item.presentationData.theme.list.freeTextErrorColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                
                height += topRightValueLabelLayoutAndApply!.0.size.height + topRightTitleLabelLayoutAndApply!.0.size.height
                
                if max(topLeftValueLabelLayoutAndApply!.0.size.width + topLeftDeltaLabelLayoutAndApply!.0.size.width + horizontalSpacing + topRightValueLabelLayoutAndApply!.0.size.width, bottomLeftValueLabelLayoutAndApply!.0.size.width + bottomLeftDeltaLabelLayoutAndApply!.0.size.width + horizontalSpacing + bottomRightValueLabelLayoutAndApply!.0.size.width + bottomRightDeltaLabelLayoutAndApply!.0.size.width) > params.width - leftInset - rightInset {
                    twoColumnLayout = false
                }
                
                if twoColumnLayout {
                    if !stats.viewers.current.isZero || viewersDelta.2 || !stats.posters.current.isZero || postersDelta.2 {
                        height += verticalSpacing
                        height += bottomRightValueLabelLayoutAndApply!.0.size.height + bottomRightTitleLabelLayoutAndApply!.0.size.height
                    }
                } else {
                    height += verticalSpacing
                    height += topRightValueLabelLayoutAndApply!.0.size.height + topRightTitleLabelLayoutAndApply!.0.size.height
                    if !stats.viewers.current.isZero || viewersDelta.2 {
                        height += verticalSpacing
                        height += bottomLeftValueLabelLayoutAndApply!.0.size.height + bottomLeftTitleLabelLayoutAndApply!.0.size.height
                    }
                    if !stats.posters.current.isZero || postersDelta.2 {
                        height += verticalSpacing
                        height += bottomRightValueLabelLayoutAndApply!.0.size.height + bottomRightTitleLabelLayoutAndApply!.0.size.height
                    }
                }
            } else {
                topLeftValueLabelLayoutAndApply = nil
                topRightValueLabelLayoutAndApply = nil
                bottomLeftValueLabelLayoutAndApply = nil
                bottomRightValueLabelLayoutAndApply = nil
                topLeftTitleLabelLayoutAndApply = nil
                topRightTitleLabelLayoutAndApply = nil
                bottomLeftTitleLabelLayoutAndApply = nil
                bottomRightTitleLabelLayoutAndApply = nil
                topLeftDeltaLabelLayoutAndApply = nil
                topRightDeltaLabelLayoutAndApply = nil
                bottomLeftDeltaLabelLayoutAndApply = nil
                bottomRightDeltaLabelLayoutAndApply = nil
            }
        
            let contentSize = CGSize(width: params.width, height: height)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                                     
                    let _ = topLeftValueLabelLayoutAndApply?.1()
                    let _ = topRightValueLabelLayoutAndApply?.1()
                    let _ = bottomLeftValueLabelLayoutAndApply?.1()
                    let _ = bottomRightValueLabelLayoutAndApply?.1()
                    let _ = topLeftTitleLabelLayoutAndApply?.1()
                    let _ = topRightTitleLabelLayoutAndApply?.1()
                    let _ = bottomLeftTitleLabelLayoutAndApply?.1()
                    let _ = bottomRightTitleLabelLayoutAndApply?.1()
                    let _ = topLeftDeltaLabelLayoutAndApply?.1()
                    let _ = topRightDeltaLabelLayoutAndApply?.1()
                    let _ = bottomLeftDeltaLabelLayoutAndApply?.1()
                    let _ = bottomRightDeltaLabelLayoutAndApply?.1()
                    
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
                    
                    var secondColumnX = sideInset + leftInset
                    
                    if let topLeftValueLabelLayout = topLeftValueLabelLayoutAndApply?.0, let topLeftTitleLabelLayout = topLeftTitleLabelLayoutAndApply?.0 {
                        strongSelf.topLeftValueLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: topInset), size: topLeftValueLabelLayout.size)
                        strongSelf.topLeftTitleLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: strongSelf.topLeftValueLabel.frame.maxY), size: topLeftTitleLabelLayout.size)
                        
                        if twoColumnLayout {
                            let topWidth = topLeftValueLabelLayout.size.width + (topLeftDeltaLabelLayoutAndApply?.0.size.width ?? 0)
                            let bottomWidth = (bottomLeftValueLabelLayoutAndApply?.0.size.width ?? 0.0) + (bottomLeftDeltaLabelLayoutAndApply?.0.size.width ?? 0.0)
                            secondColumnX = max(layout.size.width / 2.0, sideInset + leftInset + max(topWidth, bottomWidth) + horizontalSpacing)
                        }
                    }
                    if let topLeftDeltaLabelLayout = topLeftDeltaLabelLayoutAndApply?.0 {
                        strongSelf.topLeftDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.topLeftValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.topLeftValueLabel.frame.maxY - topLeftDeltaLabelLayout.size.height - 2.0), size: topLeftDeltaLabelLayout.size)
                    }
                                        
                    if let topRightValueLabelLayout = topRightValueLabelLayoutAndApply?.0, let topRightTitleLabelLayout = topRightTitleLabelLayoutAndApply?.0 {
                        let topRightY = twoColumnLayout ? topInset : strongSelf.topLeftTitleLabel.frame.maxY + verticalSpacing
                        strongSelf.topRightValueLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: topRightY), size: topRightValueLabelLayout.size)
                        strongSelf.topRightTitleLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: strongSelf.topRightValueLabel.frame.maxY), size: topRightTitleLabelLayout.size)
                    }
                    if let topRightDeltaLabelLayout = topRightDeltaLabelLayoutAndApply?.0 {
                        strongSelf.topRightDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.topRightValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.topRightValueLabel.frame.maxY - topRightDeltaLabelLayout.size.height - 2.0), size: topRightDeltaLabelLayout.size)
                    }
                    
                    if let bottomLeftValueLabelLayout = bottomLeftValueLabelLayoutAndApply?.0, let bottomLeftTitleLabelLayout = bottomLeftTitleLabelLayoutAndApply?.0 {
                        let bottomLeftY = twoColumnLayout ? strongSelf.topLeftTitleLabel.frame.maxY + verticalSpacing : strongSelf.topRightTitleLabel.frame.maxY + verticalSpacing
                        strongSelf.bottomLeftValueLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: bottomLeftY), size: bottomLeftValueLabelLayout.size)
                        strongSelf.bottomLeftTitleLabel.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: strongSelf.bottomLeftValueLabel.frame.maxY), size: bottomLeftTitleLabelLayout.size)
                    }
                    if let bottomLeftDeltaLabelLayout = bottomLeftDeltaLabelLayoutAndApply?.0 {
                        strongSelf.bottomLeftDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.bottomLeftValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.bottomLeftValueLabel.frame.maxY - bottomLeftDeltaLabelLayout.size.height - 2.0), size: bottomLeftDeltaLabelLayout.size)
                    }
                    
                    if let bottomRightValueLabelLayout = bottomRightValueLabelLayoutAndApply?.0, let bottomRightTitleLabelLayout = bottomRightTitleLabelLayoutAndApply?.0 {
                        let bottomRightY = twoColumnLayout ? strongSelf.topRightTitleLabel.frame.maxY + verticalSpacing : strongSelf.bottomLeftTitleLabel.frame.maxY + verticalSpacing
                        strongSelf.bottomRightValueLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: bottomRightY), size: bottomRightValueLabelLayout.size)
                        strongSelf.bottomRightTitleLabel.frame = CGRect(origin: CGPoint(x: secondColumnX, y: strongSelf.bottomRightValueLabel.frame.maxY), size: bottomRightTitleLabelLayout.size)
                    }
                    if let bottomRightDeltaLabelLayout = bottomRightDeltaLabelLayoutAndApply?.0 {
                        strongSelf.bottomRightDeltaLabel.frame = CGRect(origin: CGPoint(x: strongSelf.bottomRightValueLabel.frame.maxX + horizontalSpacing, y: strongSelf.bottomRightValueLabel.frame.maxY - bottomRightDeltaLabelLayout.size.height - 2.0), size: bottomRightDeltaLabelLayout.size)
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

