import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import EmojiTextAttachmentView
import TextFormat
import AccountContext
import TelegramStringFormatting

protocol Stats {
    
}

extension ChannelStats: Stats {
    
}

extension GroupStats: Stats {
    
}

extension ChannelBoostStatus: Stats {
    
}

extension MessageStats: Stats {
    
}

extension StoryStats: Stats {
    
}

extension RevenueStats: Stats {
    
}

extension StarsRevenueStats: Stats {
    
}

class StatsOverviewItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let isGroup: Bool
    let stats: Stats?
    let additionalStats: Stats?
    let storyViews: EngineStoryItem.Views?
    let publicShares: Int32?
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(context: AccountContext, presentationData: ItemListPresentationData, isGroup: Bool, stats: Stats?, additionalStats: Stats? = nil, storyViews: EngineStoryItem.Views? = nil, publicShares: Int32? = nil, sectionId: ItemListSectionId, style: ItemListStyle) {
        self.context = context
        self.presentationData = presentationData
        self.isGroup = isGroup
        self.stats = stats
        self.additionalStats = additionalStats
        self.storyViews = storyViews
        self.publicShares = publicShares
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

private final class ValueItemNode: ASDisplayNode {
    enum Mode {
        case generic
        case ton
        case stars
    }
    
    enum DeltaColor {
        case generic
        case positive
        case negative
    }
    
    private let valueNode: TextNode
    private let titleNode: TextNode
    private let deltaNode: TextNode
    private var iconNode: ASImageNode?
    
    var currentIconName: String?
    var currentTheme: PresentationTheme?
    var pressed: (() -> Void)?
      
    override init() {
        self.valueNode = TextNode()
        self.titleNode = TextNode()
        self.deltaNode = TextNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.valueNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.deltaNode)
    }
            
    static func asyncLayout(_ current: ValueItemNode?) -> (_ context: AccountContext, _ width: CGFloat, _ presentationData: ItemListPresentationData, _ value: String, _ title: String, _ delta: (String, DeltaColor)?, _ mode: Mode) -> (CGSize, () -> ValueItemNode) {
        
        let maybeMakeValueLayout = (current?.valueNode).flatMap(TextNode.asyncLayout)
        let maybeMakeTitleLayout = (current?.titleNode).flatMap(TextNode.asyncLayout)
        let maybeMakeDeltaLayout = (current?.deltaNode).flatMap(TextNode.asyncLayout)
        
        return { context, width, presentationData, value, title, delta, mode in
            let targetNode: ValueItemNode
            if let current = current {
                targetNode = current
            } else {
                targetNode = ValueItemNode()
            }
            
            let makeValueLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeValueLayout {
                makeValueLayout = maybeMakeValueLayout
            } else {
                makeValueLayout = TextNode.asyncLayout(targetNode.valueNode)
            }
            
            let makeTitleLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeTitleLayout {
                makeTitleLayout = maybeMakeTitleLayout
            } else {
                makeTitleLayout = TextNode.asyncLayout(targetNode.titleNode)
            }
            
            let makeDeltaLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeDeltaLayout {
                makeDeltaLayout = maybeMakeDeltaLayout
            } else {
                makeDeltaLayout = TextNode.asyncLayout(targetNode.deltaNode)
            }
                        
            let fontSize = presentationData.fontSize.itemListBaseFontSize
            let valueFont = Font.semibold(fontSize)
            let smallValueFont = Font.semibold(fontSize / 17.0 * 13.0)
            let titleFont = Font.regular(presentationData.fontSize.itemListBaseHeaderFontSize)
            let deltaFont = Font.regular(presentationData.fontSize.itemListBaseHeaderFontSize)
        
            let valueColor = presentationData.theme.list.itemPrimaryTextColor
            let titleColor = presentationData.theme.list.sectionHeaderTextColor
            
            let deltaColor: UIColor
            if let (_, color) = delta {
                switch color {
                case .generic:
                    deltaColor = titleColor
                case .positive:
                    deltaColor = presentationData.theme.list.freeTextSuccessColor
                case .negative:
                    deltaColor = presentationData.theme.list.freeTextErrorColor
                }
            } else {
                deltaColor = presentationData.theme.list.freeTextErrorColor
            }
            
            let constrainedSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            
            let valueString: NSAttributedString
            if case .ton = mode {
                valueString = tonAmountAttributedString(value, integralFont: valueFont, fractionalFont: smallValueFont, color: valueColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            } else {
                valueString = NSAttributedString(string: value, font: valueFont, textColor: valueColor)
            }
            
            let (valueLayout, valueApply) = makeValueLayout(TextNodeLayoutArguments(attributedString: valueString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (deltaLayout, deltaApply) = makeDeltaLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: delta?.0 ?? "", font: deltaFont, textColor: deltaColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var valueOffset: CGFloat = 0.0
            let iconName: String?
            var iconTinted = false
            switch mode {
            case .ton:
                iconName = "Ads/TonMedium"
                iconTinted = true
                valueOffset = 17.0
            case .stars:
                iconName = "Premium/Stars/StarMedium"
                valueOffset = 21.0
            default:
                iconName = nil
            }
            
            let horizontalSpacing: CGFloat = 4.0
            let size = CGSize(
                width: max(valueOffset + valueLayout.size.width + horizontalSpacing + deltaLayout.size.width, titleLayout.size.width),
                height: valueLayout.size.height + titleLayout.size.height
            )
            return (size, {
                var themeUpdated = false
                if targetNode.currentTheme !== presentationData.theme {
                    themeUpdated = true
                }
                targetNode.currentTheme = presentationData.theme
                
                let _ = valueApply()
                let _ = titleApply()
                let _ = deltaApply()
                  
                var iconNameUpdated = false
                if targetNode.currentIconName != iconName {
                    targetNode.currentIconName = iconName
                    iconNameUpdated = true
                }
                
                if let iconName {
                    let iconNode: ASImageNode
                    if let current = targetNode.iconNode {
                        iconNode = current
                    } else {
                        iconNode = ASImageNode()
                        iconNode.displaysAsynchronously = false
                        targetNode.iconNode = iconNode
                        targetNode.addSubnode(iconNode)
                    }
                    
                    if themeUpdated || iconNameUpdated {
                        if iconTinted {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: iconName), color: presentationData.theme.list.itemAccentColor)
                        } else {
                            iconNode.image = UIImage(bundleImageName: iconName)
                        }
                    }
                    
                    if let icon = iconNode.image {
                        let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((valueLayout.size.height - icon.size.height) / 2.0) - 1.0), size: icon.size)
                        iconNode.frame = iconFrame
                    }
                } else if let iconNode = targetNode.iconNode {
                    iconNode.removeFromSupernode()
                    targetNode.iconNode = nil
                }
               
                let valueFrame = CGRect(origin: CGPoint(x: valueOffset, y: 0.0), size: valueLayout.size)
                let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: valueFrame.maxY), size: titleLayout.size)
                let deltaFrame = CGRect(origin: CGPoint(x: valueFrame.maxX + horizontalSpacing, y: valueFrame.maxY - deltaLayout.size.height - 2.0 - UIScreenPixel), size: deltaLayout.size)
                
                targetNode.valueNode.frame = valueFrame
                targetNode.titleNode.frame = titleFrame
                targetNode.deltaNode.frame = deltaFrame
                
                return targetNode
            })
        }
    }
}


class StatsOverviewItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let topLeftItem: ValueItemNode
    private let topRightItem: ValueItemNode
    private let middle1LeftItem: ValueItemNode
    private let middle1RightItem: ValueItemNode
    private let middle2LeftItem: ValueItemNode
    private let middle2RightItem: ValueItemNode
    private let bottomLeftItem: ValueItemNode
    private let bottomRightItem: ValueItemNode
    
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
      
        self.topLeftItem = ValueItemNode()
        self.topRightItem = ValueItemNode()
        self.middle1LeftItem = ValueItemNode()
        self.middle1RightItem = ValueItemNode()
        self.middle2LeftItem = ValueItemNode()
        self.middle2RightItem = ValueItemNode()
        self.bottomLeftItem = ValueItemNode()
        self.bottomRightItem = ValueItemNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.topLeftItem)
        self.addSubnode(self.topRightItem)
        self.addSubnode(self.middle1LeftItem)
        self.addSubnode(self.middle1RightItem)
        self.addSubnode(self.middle2LeftItem)
        self.addSubnode(self.middle2RightItem)
        self.addSubnode(self.bottomLeftItem)
        self.addSubnode(self.bottomRightItem)
    }
    
    func asyncLayout() -> (_ item: StatsOverviewItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTopLeftItemLayout = ValueItemNode.asyncLayout(self.topLeftItem)
        let makeTopRightItemLayout = ValueItemNode.asyncLayout(self.topRightItem)
        let makeMiddle1LeftItemLayout = ValueItemNode.asyncLayout(self.middle1LeftItem)
        let makeMiddle1RightItemLayout = ValueItemNode.asyncLayout(self.middle1RightItem)
        let makeMiddle2LeftItemLayout = ValueItemNode.asyncLayout(self.middle2LeftItem)
        let makeMiddle2RightItemLayout = ValueItemNode.asyncLayout(self.middle2RightItem)
        let makeBottomLeftItemLayout = ValueItemNode.asyncLayout(self.bottomLeftItem)
        let makeBottomRightItemLayout = ValueItemNode.asyncLayout(self.bottomRightItem)
        
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
            
            var twoColumnLayout = "".isEmpty // Silence the warning
            var useMinLeftColumnWidth = false
            
            var topLeftItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var topRightItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var middle1LeftItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var middle1RightItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var middle2LeftItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var middle2RightItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var bottomLeftItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            var bottomRightItemLayoutAndApply: (CGSize, () -> ValueItemNode)?
            
            func deltaText(_ value: StatsValue) -> (text: String, positive: Bool, hasValue: Bool) {
                let deltaValue = value.current - value.previous
                let deltaCompact = compactNumericCountString(abs(Int(deltaValue)))
                let delta = deltaValue > 0 ? "+\(deltaCompact)" : "-\(deltaCompact)"
                var deltaPercentage = 0.0
                if value.previous > 0.0 {
                    deltaPercentage = abs(deltaValue / value.previous)
                }
                
                return (abs(deltaPercentage) > 0.0 ? String(format: "%@ (%.02f%%)", delta, deltaPercentage * 100.0) : "", deltaValue > 0.0, abs(deltaValue) > 0.0)
            }
            
            if let stats = item.stats as? MessageStats {
                topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(stats.views),
                    item.presentationData.strings.Stats_Message_Views,
                    nil,
                    .generic
                )
                
                topRightItemLayoutAndApply = makeTopRightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    item.publicShares.flatMap { compactNumericCountString(Int($0)) } ?? "–",
                    item.presentationData.strings.Stats_Message_PublicShares,
                    nil,
                    .generic
                )
                
                middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(stats.reactions),
                    item.presentationData.strings.Stats_Message_Reactions,
                    nil,
                    .generic
                )
                
                middle1RightItemLayoutAndApply = makeMiddle1RightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    item.publicShares.flatMap { "≈\( compactNumericCountString(max(0, stats.forwards - Int($0))))" } ?? "–",
                    item.presentationData.strings.Stats_Message_PrivateShares,
                    nil,
                    .generic
                )
                
                height += topRightItemLayoutAndApply!.0.height * 2.0 + verticalSpacing
            } else if let _ = item.stats as? StoryStats, let views = item.storyViews {
                topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(views.seenCount),
                    item.presentationData.strings.Stats_Message_Views,
                    nil,
                    .generic
                )
                
                topRightItemLayoutAndApply = makeTopRightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    item.publicShares.flatMap { compactNumericCountString(Int($0)) } ?? "–",
                    item.presentationData.strings.Stats_Message_PublicShares,
                    nil,
                    .generic
                )
                
                middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(views.reactedCount),
                    item.presentationData.strings.Stats_Message_Reactions,
                    nil,
                    .generic
                )
                
                middle1RightItemLayoutAndApply = makeMiddle1RightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    item.publicShares.flatMap { "≈\( compactNumericCountString(max(0, views.forwardCount - Int($0))))" } ?? "–",
                    item.presentationData.strings.Stats_Message_PrivateShares,
                    nil,
                    .generic
                )
                
                height += topRightItemLayoutAndApply!.0.height * 2.0 + verticalSpacing
            } else if let stats = item.stats as? ChannelBoostStatus {
                topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    "\(stats.level)",
                    item.presentationData.strings.Stats_Boosts_Level,
                    nil,
                    .generic
                )
                
                var premiumSubscribers: Double = 0.0
                if let premiumAudience = stats.premiumAudience, premiumAudience.total > 0 {
                    premiumSubscribers = premiumAudience.value / premiumAudience.total
                }
                
                topRightItemLayoutAndApply = makeTopRightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    "≈\(Int(stats.premiumAudience?.value ?? 0))",
                    item.isGroup ? item.presentationData.strings.Stats_Boosts_PremiumMembers : item.presentationData.strings.Stats_Boosts_PremiumSubscribers,
                    (String(format: "%.02f%%", premiumSubscribers * 100.0), .generic),
                    .generic
                )
                
                middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    "\(stats.boosts)",
                    item.presentationData.strings.Stats_Boosts_ExistingBoosts,
                    nil,
                    .generic
                )
                
                let boostsLeft: Int32
                if let nextLevelBoosts = stats.nextLevelBoosts {
                    boostsLeft = Int32(nextLevelBoosts - stats.boosts)
                } else {
                    boostsLeft = 0
                }
                middle1RightItemLayoutAndApply = makeMiddle1RightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    "\(boostsLeft)",
                    item.presentationData.strings.Stats_Boosts_BoostsToLevelUp,
                    nil,
                    .generic
                )
                
                if twoColumnLayout {
                    height += topRightItemLayoutAndApply!.0.height * 2.0 + verticalSpacing
                } else {
                    height += topLeftItemLayoutAndApply!.0.height * 4.0 + verticalSpacing * 3.0
                }
            } else if let stats = item.stats as? ChannelStats {
                let viewsPerPostDelta = deltaText(stats.viewsPerPost)
                let sharesPerPostDelta = deltaText(stats.sharesPerPost)
                let reactionsPerPostDelta = deltaText(stats.reactionsPerPost)

                let viewsPerStoryDelta = deltaText(stats.viewsPerStory)
                let sharesPerStoryDelta = deltaText(stats.sharesPerStory)
                let reactionsPerStoryDelta = deltaText(stats.reactionsPerStory)
                
                let followersDelta = deltaText(stats.followers)
                topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(Int(stats.followers.current)),
                    item.presentationData.strings.Stats_Followers,
                    (followersDelta.text, followersDelta.positive ? .positive : .negative),
                    .generic
                )
                
                var enabledNotifications: Double = 0.0
                if stats.enabledNotifications.total > 0 {
                    enabledNotifications = stats.enabledNotifications.value / stats.enabledNotifications.total
                }
                topRightItemLayoutAndApply = makeTopRightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    String(format: "%.02f%%", enabledNotifications * 100.0),
                    item.presentationData.strings.Stats_EnabledNotifications,
                    nil,
                    .generic
                )
                
                let hasMessages = stats.viewsPerPost.current > 0 || viewsPerPostDelta.hasValue
                let hasStories = stats.viewsPerStory.current > 0 || viewsPerStoryDelta.hasValue
                
                var items: [Int: (String, String, (String, ValueItemNode.DeltaColor)?)] = [:]
                if hasMessages {
                    items[0] = (
                        compactNumericCountString(Int(stats.viewsPerPost.current)),
                        item.presentationData.strings.Stats_ViewsPerPost,
                        (viewsPerPostDelta.text, viewsPerPostDelta.positive ? .positive : .negative)
                    )
                }
                if hasMessages {
                    let index = hasStories ? 2 : 1
                    items[index] = (
                        compactNumericCountString(Int(stats.sharesPerPost.current)),
                        item.presentationData.strings.Stats_SharesPerPost,
                        (sharesPerPostDelta.text, sharesPerPostDelta.positive ? .positive : .negative)
                    )
                }
                if stats.reactionsPerPost.current > 0 || reactionsPerPostDelta.hasValue {
                    let index = hasStories ? 4 : 2
                    items[index] = (
                        compactNumericCountString(Int(stats.reactionsPerPost.current)),
                        item.presentationData.strings.Stats_ReactionsPerPost,
                        (reactionsPerPostDelta.text, reactionsPerPostDelta.positive ? .positive : .negative)
                    )
                }
                if hasStories {
                    let index = items[0] == nil ? 0 : 1
                    items[index] = (
                        compactNumericCountString(Int(stats.viewsPerStory.current)),
                        item.presentationData.strings.Stats_ViewsPerStory,
                        (viewsPerStoryDelta.text, viewsPerStoryDelta.positive ? .positive : .negative)
                    )
                    let sharesIndex = items[1] == nil ? 1 : 3
                    items[sharesIndex] = (
                        compactNumericCountString(Int(stats.sharesPerStory.current)),
                        item.presentationData.strings.Stats_SharesPerStory,
                        (sharesPerStoryDelta.text, sharesPerStoryDelta.positive ? .positive : .negative)
                    )
                    let reactionsIndex = items[3] == nil ? 2 : 5
                    items[reactionsIndex] = (
                        compactNumericCountString(Int(stats.reactionsPerStory.current)),
                        item.presentationData.strings.Stats_ReactionsPerStory,
                        (reactionsPerStoryDelta.text, reactionsPerStoryDelta.positive ? .positive : .negative)
                    )
                }
                
                if let (value, title, delta) = items[0] {
                    middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        value,
                        title,
                        delta,
                        .generic
                    )
                }
                if let (value, title, delta) = items[1] {
                    middle1RightItemLayoutAndApply = makeMiddle1RightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        value,
                        title,
                        delta,
                        .generic
                    )
                }
                if let (value, title, delta) = items[2] {
                    middle2LeftItemLayoutAndApply = makeMiddle2LeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        value,
                        title,
                        delta,
                        .generic
                    )
                }
                if let (value, title, delta) = items[3] {
                    middle2RightItemLayoutAndApply = makeMiddle2RightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        value,
                        title,
                        delta,
                        .generic
                    )
                }
                if let (value, title, delta) = items[4] {
                    bottomLeftItemLayoutAndApply = makeBottomLeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        value,
                        title,
                        delta,
                        .generic
                    )
                }
                if let (value, title, delta) = items[5] {
                    bottomRightItemLayoutAndApply = makeBottomRightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        value,
                        title,
                        delta,
                        .generic
                    )
                }

                let valuesCount = CGFloat(2 + items.count)
                if twoColumnLayout {
                    let rowsCount = ceil(valuesCount / 2.0)
                    height += topLeftItemLayoutAndApply!.0.height * rowsCount + (verticalSpacing * (rowsCount - 1.0))
                } else {
                    height += topLeftItemLayoutAndApply!.0.height * valuesCount + (verticalSpacing * (valuesCount - 1.0))
                }
            } else if let stats = item.stats as? GroupStats {
                let viewersDelta = deltaText(stats.viewers)
                let postersDelta = deltaText(stats.posters)
                let displayBottomRow = stats.viewers.current > 0 || viewersDelta.2 || stats.posters.current > 0 || postersDelta.2

                let membersDelta = deltaText(stats.members)
                topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(Int(stats.members.current)),
                    item.presentationData.strings.Stats_GroupMembers,
                    (membersDelta.text, membersDelta.positive ? .positive : .negative),
                    .generic
                )
                
                let messagesDelta = deltaText(stats.messages)
                topRightItemLayoutAndApply = makeTopRightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    compactNumericCountString(Int(stats.messages.current)),
                    item.presentationData.strings.Stats_GroupMessages,
                    (messagesDelta.text, messagesDelta.positive ? .positive : .negative),
                    .generic
                )
                
                if displayBottomRow {
                    middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        compactNumericCountString(Int(stats.viewers.current)),
                        item.presentationData.strings.Stats_GroupViewers,
                        (viewersDelta.text, viewersDelta.positive ? .positive : .negative),
                        .generic
                    )
                    
                    middle1RightItemLayoutAndApply = makeMiddle1RightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        compactNumericCountString(Int(stats.posters.current)),
                        item.presentationData.strings.Stats_GroupPosters,
                        (postersDelta.text, postersDelta.positive ? .positive : .negative),
                        .generic
                    )
                }
                
                if twoColumnLayout || !displayBottomRow {
                    height += topRightItemLayoutAndApply!.0.height * 2.0 + verticalSpacing
                } else {
                    height += topLeftItemLayoutAndApply!.0.height * 4.0 + verticalSpacing * 3.0
                }
            } else if let stats = item.stats as? RevenueStats {
                if let additionalStats = item.additionalStats as? StarsRevenueStats, additionalStats.balances.overallRevenue > StarsAmount.zero {
                    twoColumnLayout = true
                    useMinLeftColumnWidth = true
                    
                    topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatTonAmountText(stats.balances.availableBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                        item.presentationData.strings.Monetization_StarsProceeds_Available,
                        (stats.balances.availableBalance == 0 ? "" : "≈\(formatTonUsdValue(stats.balances.availableBalance, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .ton
                    )
                    
                    middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatTonAmountText(stats.balances.currentBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                        item.presentationData.strings.Monetization_StarsProceeds_Current,
                        (stats.balances.currentBalance == 0 ? "" : "≈\(formatTonUsdValue(stats.balances.currentBalance, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .ton
                    )
                    
                    middle2LeftItemLayoutAndApply = makeMiddle2LeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatTonAmountText(stats.balances.overallRevenue, dateTimeFormat: item.presentationData.dateTimeFormat),
                        item.presentationData.strings.Monetization_StarsProceeds_Total,
                        (stats.balances.overallRevenue == 0 ? "" : "≈\(formatTonUsdValue(stats.balances.overallRevenue, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .ton
                    )
                    
                    topRightItemLayoutAndApply = makeTopRightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatStarsAmountText(additionalStats.balances.availableBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                        " ",
                        (additionalStats.balances.availableBalance == StarsAmount.zero ? "" : "≈\(formatTonUsdValue(additionalStats.balances.availableBalance.value, divide: false, rate: additionalStats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .stars
                    )
                    
                    middle1RightItemLayoutAndApply = makeMiddle1RightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatStarsAmountText(additionalStats.balances.currentBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                        " ",
                        (additionalStats.balances.currentBalance == StarsAmount.zero ? "" : "≈\(formatTonUsdValue(additionalStats.balances.currentBalance.value, divide: false, rate: additionalStats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .stars
                    )
                    
                    middle2RightItemLayoutAndApply = makeMiddle2RightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatStarsAmountText(additionalStats.balances.overallRevenue, dateTimeFormat: item.presentationData.dateTimeFormat),
                        " ",
                        (additionalStats.balances.overallRevenue == StarsAmount.zero ? "" : "≈\(formatTonUsdValue(additionalStats.balances.overallRevenue.value, divide: false, rate: additionalStats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .stars
                    )
                    
                    height += topLeftItemLayoutAndApply!.0.height * 3.0 + verticalSpacing * 2.0
                } else {
                    twoColumnLayout = false
                    
                    topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatTonAmountText(stats.balances.availableBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                        item.presentationData.strings.Monetization_Overview_Available,
                        (stats.balances.availableBalance == 0 ? "" : "≈\(formatTonUsdValue(stats.balances.availableBalance, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .ton
                    )
                    
                    topRightItemLayoutAndApply = makeTopRightItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatTonAmountText(stats.balances.currentBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                        item.presentationData.strings.Monetization_Overview_Current,
                        (stats.balances.currentBalance == 0 ? "" : "≈\(formatTonUsdValue(stats.balances.currentBalance, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .ton
                    )
                    
                    middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                        item.context,
                        params.width,
                        item.presentationData,
                        formatTonAmountText(stats.balances.overallRevenue, dateTimeFormat: item.presentationData.dateTimeFormat),
                        item.presentationData.strings.Monetization_Overview_Total,
                        (stats.balances.overallRevenue == 0 ? "" : "≈\(formatTonUsdValue(stats.balances.overallRevenue, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                        .ton
                    )
                    
                    height += topLeftItemLayoutAndApply!.0.height * 3.0 + verticalSpacing * 2.0
                }
            } else if let stats = item.stats as? StarsRevenueStats {
                twoColumnLayout = false
                
                topLeftItemLayoutAndApply = makeTopLeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    formatStarsAmountText(stats.balances.availableBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                    item.presentationData.strings.Monetization_StarsProceeds_Available,
                    (stats.balances.availableBalance == StarsAmount.zero ? "" : "≈\(formatTonUsdValue(stats.balances.availableBalance.value, divide: false, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                    .stars
                )
                
                topRightItemLayoutAndApply = makeTopRightItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    formatStarsAmountText(stats.balances.currentBalance, dateTimeFormat: item.presentationData.dateTimeFormat),
                    item.presentationData.strings.Monetization_StarsProceeds_Current,
                    (stats.balances.currentBalance == StarsAmount.zero ? "" : "≈\(formatTonUsdValue(stats.balances.currentBalance.value, divide: false, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                    .stars
                )
                
                middle1LeftItemLayoutAndApply = makeMiddle1LeftItemLayout(
                    item.context,
                    params.width,
                    item.presentationData,
                    formatStarsAmountText(stats.balances.overallRevenue, dateTimeFormat: item.presentationData.dateTimeFormat),
                    item.presentationData.strings.Monetization_StarsProceeds_Total,
                    (stats.balances.overallRevenue == StarsAmount.zero ? "" : "≈\(formatTonUsdValue(stats.balances.overallRevenue.value, divide: false, rate: stats.usdRate, dateTimeFormat: item.presentationData.dateTimeFormat))", .generic),
                    .stars
                )
                
                height += topLeftItemLayoutAndApply!.0.height * 3.0 + verticalSpacing * 2.0
            }
        
            let contentSize = CGSize(width: params.width, height: height)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                                     
                    let _ = topLeftItemLayoutAndApply?.1()
                    let _ = topRightItemLayoutAndApply?.1()
                    let _ = middle1LeftItemLayoutAndApply?.1()
                    let _ = middle1RightItemLayoutAndApply?.1()
                    let _ = middle2LeftItemLayoutAndApply?.1()
                    let _ = middle2RightItemLayoutAndApply?.1()
                    let _ = bottomLeftItemLayoutAndApply?.1()
                    let _ = bottomRightItemLayoutAndApply?.1()
                    
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
                    
                    let firstColumnX = sideInset + leftInset
                    var secondColumnX = firstColumnX
                    
                    if twoColumnLayout {
                        var maxLeftWidth: CGFloat = 0.0
                        if let topLeftItemLayout = topLeftItemLayoutAndApply?.0 {
                            maxLeftWidth = max(maxLeftWidth, topLeftItemLayout.width)
                        }
                        if let middle1LeftItemLayout = middle1LeftItemLayoutAndApply?.0 {
                            maxLeftWidth = max(maxLeftWidth, middle1LeftItemLayout.width)
                        }
                        if let middle2LeftItemLayout = middle2LeftItemLayoutAndApply?.0 {
                            maxLeftWidth = max(maxLeftWidth, middle2LeftItemLayout.width)
                        }
                        if let bottomLeftItemLayout = bottomLeftItemLayoutAndApply?.0 {
                            maxLeftWidth = max(maxLeftWidth, bottomLeftItemLayout.width)
                        }
                        if useMinLeftColumnWidth {
                            secondColumnX = min(layout.size.width / 2.0, firstColumnX + maxLeftWidth + horizontalSpacing * 3.0)
                        } else {
                            secondColumnX = max(layout.size.width / 2.0, firstColumnX + maxLeftWidth + horizontalSpacing)
                        }
                    }
                                        
                    if let topLeftItemLayout = topLeftItemLayoutAndApply?.0 {
                        strongSelf.topLeftItem.frame = CGRect(origin: CGPoint(x: firstColumnX, y: topInset), size: topLeftItemLayout)
                    }
                    
                    if let topRightItemLayout = topRightItemLayoutAndApply?.0 {
                        let originY = twoColumnLayout ? topInset : strongSelf.topLeftItem.frame.maxY + verticalSpacing
                        strongSelf.topRightItem.frame = CGRect(origin: CGPoint(x: secondColumnX, y: originY), size: topRightItemLayout)
                    }
                    
                    if let middle1LeftItemLayout = middle1LeftItemLayoutAndApply?.0 {
                        let originY = (twoColumnLayout ? strongSelf.topLeftItem.frame.maxY : strongSelf.topRightItem.frame.maxY) + verticalSpacing
                        strongSelf.middle1LeftItem.frame = CGRect(origin: CGPoint(x: firstColumnX, y: originY), size: middle1LeftItemLayout)
                    }
                    
                    if let middle1RightItemLayout = middle1RightItemLayoutAndApply?.0 {
                        let originY = (twoColumnLayout ? strongSelf.topRightItem.frame.maxY : strongSelf.middle1LeftItem.frame.maxY) + verticalSpacing
                        strongSelf.middle1RightItem.frame = CGRect(origin: CGPoint(x: secondColumnX, y: originY), size: middle1RightItemLayout)
                    }
                    
                    if let middle2LeftItemLayout = middle2LeftItemLayoutAndApply?.0 {
                        let originY = (twoColumnLayout ? strongSelf.middle1LeftItem.frame.maxY : strongSelf.middle1RightItem.frame.maxY) + verticalSpacing
                        strongSelf.middle2LeftItem.frame = CGRect(origin: CGPoint(x: firstColumnX, y: originY), size: middle2LeftItemLayout)
                    }
                    
                    if let middle2RightItemLayout = middle2RightItemLayoutAndApply?.0 {
                        let originY = (twoColumnLayout ? strongSelf.middle1RightItem.frame.maxY : strongSelf.middle2LeftItem.frame.maxY) + verticalSpacing
                        strongSelf.middle2RightItem.frame = CGRect(origin: CGPoint(x: secondColumnX, y: originY), size: middle2RightItemLayout)
                    }
                    
                    if let bottomLeftItemLayout = bottomLeftItemLayoutAndApply?.0 {
                        let originY = (twoColumnLayout ? strongSelf.middle2LeftItem.frame.maxY : strongSelf.middle2RightItem.frame.maxY) + verticalSpacing
                        strongSelf.bottomLeftItem.frame = CGRect(origin: CGPoint(x: firstColumnX, y: originY), size: bottomLeftItemLayout)
                    }
                    
                    if let bottomRightItemLayout = bottomRightItemLayoutAndApply?.0 {
                        let originY = (twoColumnLayout ? strongSelf.middle2RightItem.frame.maxY : strongSelf.bottomLeftItem.frame.maxY) + verticalSpacing
                        strongSelf.bottomRightItem.frame = CGRect(origin: CGPoint(x: secondColumnX, y: originY), size: bottomRightItemLayout)
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

