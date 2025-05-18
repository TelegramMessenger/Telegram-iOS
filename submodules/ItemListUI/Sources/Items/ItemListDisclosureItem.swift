import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ShimmerEffect
import AvatarNode
import TelegramCore
import AccountContext
import TextNodeWithEntities
import ListItemComponentAdaptor

private let avatarFont = avatarPlaceholderFont(size: 16.0)

public enum ItemListDisclosureItemTitleColor {
    case primary
    case accent
}

public enum ItemListDisclosureItemTitleFont {
    case regular
    case bold
}

public enum ItemListDisclosureStyle {
    case arrow
    case optionArrows
    case none
}

public enum ItemListDisclosureLabelStyle {
    case text
    case detailText
    case coloredText(UIColor)
    case textWithIcon(UIImage)
    case multilineDetailText
    case badge(UIColor)
    case color(UIColor)
    case semitransparentBadge(UIColor)
    case image(image: UIImage, size: CGSize)
}

public enum ItemListDisclosureItemDetailLabelColor {
    case generic
    case constructive
    case destructive
}

public class ItemListDisclosureItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    let presentationData: ItemListPresentationData
    let icon: UIImage?
    let context: AccountContext?
    let iconPeer: EnginePeer?
    let title: String
    let attributedTitle: NSAttributedString?
    let titleColor: ItemListDisclosureItemTitleColor
    let titleFont: ItemListDisclosureItemTitleFont
    let titleIcon: UIImage?
    let titleBadge: String?
    let enabled: Bool
    let label: String
    let attributedLabel: NSAttributedString?
    let labelStyle: ItemListDisclosureLabelStyle
    let additionalDetailLabel: String?
    let additionalDetailLabelColor: ItemListDisclosureItemDetailLabelColor
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let disclosureStyle: ItemListDisclosureStyle
    let noInsets: Bool
    let action: (() -> Void)?
    let clearHighlightAutomatically: Bool
    public let tag: ItemListItemTag?
    public let shimmeringIndex: Int?
    
    public init(presentationData: ItemListPresentationData, icon: UIImage? = nil, context: AccountContext? = nil, iconPeer: EnginePeer? = nil, title: String, attributedTitle: NSAttributedString? = nil, enabled: Bool = true, titleColor: ItemListDisclosureItemTitleColor = .primary, titleFont: ItemListDisclosureItemTitleFont = .regular, titleIcon: UIImage? = nil, titleBadge: String? = nil, label: String, attributedLabel: NSAttributedString? = nil, labelStyle: ItemListDisclosureLabelStyle = .text, additionalDetailLabel: String? = nil, additionalDetailLabelColor: ItemListDisclosureItemDetailLabelColor = .generic, sectionId: ItemListSectionId, style: ItemListStyle, disclosureStyle: ItemListDisclosureStyle = .arrow, noInsets: Bool = false, action: (() -> Void)?, clearHighlightAutomatically: Bool = true, tag: ItemListItemTag? = nil, shimmeringIndex: Int? = nil) {
        self.presentationData = presentationData
        self.icon = icon
        self.context = context
        self.iconPeer = iconPeer
        self.title = title
        self.attributedTitle = attributedTitle
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.titleIcon = titleIcon
        self.titleBadge = titleBadge
        self.enabled = enabled
        self.labelStyle = labelStyle
        self.label = label
        self.attributedLabel = attributedLabel
        self.additionalDetailLabel = additionalDetailLabel
        self.additionalDetailLabelColor = additionalDetailLabelColor
        self.sectionId = sectionId
        self.style = style
        self.disclosureStyle = disclosureStyle
        self.noInsets = noInsets
        self.action = action
        self.clearHighlightAutomatically = clearHighlightAutomatically
        self.tag = tag
        self.shimmeringIndex = shimmeringIndex
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListDisclosureItemNode()
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
            if let nodeValue = node() as? ItemListDisclosureItemNode {
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
        if self.clearHighlightAutomatically {
            listView.clearHighlightAnimated(true)
        }
        if self.enabled {
            self.action?()
        }
    }
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: ItemListDisclosureItem, rhs: ItemListDisclosureItem) -> Bool {
        if lhs.presentationData != rhs.presentationData {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        
        return true
    }
}

private let badgeFont = Font.regular(15.0)
private let boldBadgeFont = Font.semibold(14.0)

public class ItemListDisclosureItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    var avatarNode: AvatarNode?
    let iconNode: ASImageNode
    let titleNode: TextNodeWithEntities
    let titleIconNode: ASImageNode
    public let labelNode: TextNode
    var additionalDetailLabelNode: TextNode?
    let arrowNode: ASImageNode
    let labelBadgeNode: ASImageNode
    let labelImageNode: ASImageNode
    
    var titleBadgeNode: ASImageNode?
    var titleBadgeTextNode: TextNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListDisclosureItem?
    
    override public var canBeSelected: Bool {
        if let item = self.item, let _ = item.action {
            return true
        } else {
            return false
        }
    }
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }

    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
        self.titleNode = TextNodeWithEntities()
        self.titleNode.textNode.isUserInteractionEnabled = false
        
        self.titleIconNode = ASImageNode()
        self.titleIconNode.displayWithoutProcessing = true
        self.titleIconNode.displaysAsynchronously = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isLayerBacked = true
        
        self.labelBadgeNode = ASImageNode()
        self.labelImageNode = ASImageNode()
        self.labelBadgeNode.displayWithoutProcessing = true
        self.labelBadgeNode.displaysAsynchronously = false
        self.labelBadgeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode.textNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.arrowNode)
        
        self.addSubnode(self.activateArea)
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    public func updateHasContextMenu(hasContextMenu: Bool) {
        let transition: ContainedViewLayoutTransition
        if hasContextMenu {
            transition = .immediate
        } else {
            transition = .animated(duration: 0.3, curve: .easeInOut)
        }
        transition.updateAlpha(node: self.labelNode, alpha: hasContextMenu ? 0.5 : 1.0)
        transition.updateAlpha(node: self.arrowNode, alpha: hasContextMenu ? 0.5 : 1.0)
    }
    
    public func asyncLayout() -> (_ item: ItemListDisclosureItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode.textNode)
        let makeTitleWithEntitiesLayout = TextNodeWithEntities.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeAdditionalDetailLabelLayout = TextNode.asyncLayout(self.additionalDetailLabelNode)
        
        let makeTitleBadgeTextNodeLayout = TextNode.asyncLayout(self.titleBadgeTextNode)
        
        let currentItem = self.item
        
        let currentHasBadge = self.labelBadgeNode.image != nil
        
        return { item, params, neighbors in
            var rightInset: CGFloat
            switch item.disclosureStyle {
            case .none:
                rightInset = 16.0 + params.rightInset
            case .arrow:
                rightInset = 34.0 + params.rightInset
            case .optionArrows:
                rightInset = 34.0 + params.rightInset
            }
            
            var updateArrowImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            var updatedLabelBadgeImage: UIImage?
            var updatedLabelImage: UIImage?
            
            var badgeDiameter: CGFloat = 20.0
            var badgeColor: UIColor?
            var badgeColorUpdated = false
            if case let .badge(color) = item.labelStyle {
                if item.label.count > 0 {
                    badgeColor = color
                }
            } else if case let .semitransparentBadge(color) = item.labelStyle {
                badgeDiameter = 24.0
                badgeColor = color.withAlphaComponent(0.1)
                
                badgeColorUpdated = true
                if let currentItem = currentItem, case let .semitransparentBadge(previousColor) = currentItem.labelStyle, color.isEqual(previousColor) {
                    badgeColorUpdated = false
                }
            }
            if case let .color(color) = item.labelStyle {
                var updatedColor = true
                if let currentItem = currentItem, case let .color(previousColor) = currentItem.labelStyle, color.isEqual(previousColor) {
                    updatedColor = false
                }
                if updatedColor {
                    updatedLabelImage = generateFilledCircleImage(diameter: 17.0, color: color)
                }
            }
            if case let .textWithIcon(image) = item.labelStyle {
                updatedLabelImage = generateTintedImage(image: image, color: item.presentationData.theme.list.itemSecondaryTextColor)
            } else if case let .image(image, _) = item.labelStyle {
                updatedLabelImage = image
            }
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                switch item.disclosureStyle {
                case .none, .arrow:
                    updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                case .optionArrows:
                    updateArrowImage = PresentationResourcesItemList.disclosureOptionArrowsImage(item.presentationData.theme)
                }
                if let badgeColor = badgeColor {
                    updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
                }
            } else if let badgeColor = badgeColor, !currentHasBadge || badgeColorUpdated {
                updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
            }
            
            var updateIcon = false
            if currentItem?.icon != item.icon {
                updateIcon = true
            }
            
            let contentSize: CGSize
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            var leftInset = 16.0 + params.leftInset
            if item.icon != nil {
                leftInset += item.noInsets ? 49.0 : 43.0
            } else if item.iconPeer != nil {
                leftInset += 46.0
            }
            
            var additionalTextRightInset: CGFloat = 0.0
            switch item.labelStyle {
            case .badge, .semitransparentBadge:
                additionalTextRightInset += 44.0
            default:
                break
            }
            
            let titleColor: UIColor
            if item.enabled {
                titleColor = item.titleColor == .accent ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemPrimaryTextColor
            } else {
                titleColor = item.presentationData.theme.list.itemDisabledTextColor
            }
            
            let titleFont: UIFont
            let defaultLabelFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            switch item.titleFont {
            case .regular:
                titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            case .bold:
                titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            }
            
            var maxTitleWidth: CGFloat = params.width - params.rightInset - 20.0 - leftInset - additionalTextRightInset
            if item.iconPeer != nil {
                maxTitleWidth -= 12.0
            }
            
            var titleBadgeTextNodeLayout: (TextNodeLayout, () -> TextNode)?
            if let titleBadge = item.titleBadge {
                let titleBadgeTextNodeLayoutValue = makeTitleBadgeTextNodeLayout(TextNodeLayoutArguments(attributedString: item.attributedTitle ?? NSAttributedString(string: titleBadge, font: Font.medium(11.0), textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                titleBadgeTextNodeLayout = titleBadgeTextNodeLayoutValue
                maxTitleWidth -= 5.0 + titleBadgeTextNodeLayoutValue.0.size.width
            }
            
            let titleArguments = TextNodeLayoutArguments(attributedString: item.attributedTitle ?? NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: item.attributedTitle != nil ? 0 : 1, truncationType: .end, constrainedSize: CGSize(width: maxTitleWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets())
            let (titleLayoutAndApply) = item.context == nil ? makeTitleLayout(titleArguments) : nil
            let (titleWithEntitiesLayoutAndApply) = item.context != nil ? makeTitleWithEntitiesLayout(titleArguments) : nil
            
            let titleLayout: TextNodeLayout = (titleWithEntitiesLayoutAndApply?.0 ?? titleLayoutAndApply?.0)!
            
            let detailFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            let labelFont: UIFont
            let labelBadgeColor: UIColor
            var labelConstrain: CGFloat = params.width - params.rightInset - leftInset - 40.0 - titleLayout.size.width - 10.0
            if item.iconPeer != nil {
                labelConstrain -= 6.0
            }
            
            switch item.labelStyle {
            case .badge:
                labelBadgeColor = item.presentationData.theme.list.itemCheckColors.foregroundColor
                labelFont = badgeFont
            case let .semitransparentBadge(color):
                labelBadgeColor = color
                labelFont = boldBadgeFont
            case .detailText, .multilineDetailText:
                labelBadgeColor = item.presentationData.theme.list.itemSecondaryTextColor
                labelFont = detailFont
                labelConstrain = params.width - params.rightInset - 40.0 - leftInset
            case let .coloredText(color):
                labelBadgeColor = color
                labelFont = defaultLabelFont
            default:
                labelBadgeColor = item.presentationData.theme.list.itemSecondaryTextColor
                labelFont = defaultLabelFont
            }
            var multilineLabel = false
            if case .multilineDetailText = item.labelStyle {
                multilineLabel = true
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: item.attributedLabel ?? NSAttributedString(string: item.label, font: labelFont, textColor: labelBadgeColor), backgroundColor: nil, maximumNumberOfLines: multilineLabel ? 0 : 1, truncationType: .end, constrainedSize: CGSize(width: labelConstrain, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var additionalDetailLabelInfo: (TextNodeLayout, () -> TextNode)?
            if let additionalDetailLabel = item.additionalDetailLabel {
                var detailRightInset: CGFloat = 20.0 + params.rightInset + additionalTextRightInset
                if labelLayout.size.width != 0 {
                    detailRightInset += labelLayout.size.width + 7.0
                }
                let additionalDetailColor: UIColor
                switch item.additionalDetailLabelColor {
                case .generic:
                    additionalDetailColor = item.presentationData.theme.list.itemSecondaryTextColor
                case .constructive:
                    additionalDetailColor = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                case .destructive:
                    additionalDetailColor = item.presentationData.theme.list.itemDestructiveColor
                }
                additionalDetailLabelInfo = makeAdditionalDetailLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: additionalDetailLabel, font: detailFont, textColor: additionalDetailColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - detailRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            }
            
            let verticalInset: CGFloat
            if item.iconPeer != nil {
                verticalInset = 6.0
            } else {
                verticalInset = 11.0
            }
            
            let titleSpacing: CGFloat = 1.0
            
            var height: CGFloat
            switch item.labelStyle {
            case .detailText:
                height = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + labelLayout.size.height
            case .multilineDetailText:
                height = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + labelLayout.size.height
            default:
                height = verticalInset * 2.0 + titleLayout.size.height
            }
            if let additionalDetailLabelInfo = additionalDetailLabelInfo {
                height += titleSpacing + additionalDetailLabelInfo.0.size.height
            }
            if item.iconPeer != nil {
                height = max(height, 40.0 + verticalInset * 2.0)
            }
            
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsPlainInsets(neighbors)
                if item.noInsets {
                    insets.top = 0.0
                    insets.bottom = 0.0
                }
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
                    if item.enabled {
                        strongSelf.activateArea.accessibilityTraits = [.button]
                    } else {
                        strongSelf.activateArea.accessibilityTraits = [.button, .notEnabled]
                    }
                    
                    if let icon = item.icon {
                        if strongSelf.iconNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconNode)
                        }
                        if updateIcon {
                            strongSelf.iconNode.image = icon
                        }
                        let iconY: CGFloat
                        if case .multilineDetailText = item.labelStyle {
                            iconY = 14.0
                        } else {
                            iconY = floor((layout.contentSize.height - icon.size.height) / 2.0)
                        }
                        strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - icon.size.width) / 2.0), y: iconY), size: icon.size)
                    } else if strongSelf.iconNode.supernode != nil {
                        strongSelf.iconNode.image = nil
                        strongSelf.iconNode.removeFromSupernode()
                    }
                    
                    if let context = item.context, let iconPeer = item.iconPeer {
                        let avatarNode: AvatarNode
                        if let current = strongSelf.avatarNode {
                            avatarNode = current
                        } else {
                            avatarNode = AvatarNode(font: avatarFont)
                            strongSelf.avatarNode = avatarNode
                            strongSelf.addSubnode(avatarNode)
                        }
                        let avatarSize: CGFloat = 40.0
                        avatarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - avatarSize) / 2.0), y: floor((height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
                        var clipStyle: AvatarNodeClipStyle = .round
                        if case let .channel(channel) = iconPeer, channel.isForumOrMonoForum {
                            clipStyle = .roundedRect
                        }
                        var overrideImage: AvatarNodeImageOverride?
                        if iconPeer.id == context.account.peerId {
                            overrideImage = .savedMessagesIcon
                        }
                        avatarNode.setPeer(context: context, theme: item.presentationData.theme, peer: iconPeer, overrideImage: overrideImage, clipStyle: clipStyle)
                    } else if let avatarNode = strongSelf.avatarNode {
                        strongSelf.avatarNode = nil
                        avatarNode.removeFromSupernode()
                    }
                    
                    if let updateArrowImage = updateArrowImage {
                        strongSelf.arrowNode.image = updateArrowImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                                        
                    if let titleWithEntitiesApply = titleWithEntitiesLayoutAndApply?.1, let context = item.context {
                        let _ = titleWithEntitiesApply(
                            TextNodeWithEntities.Arguments(
                                context: context,
                                cache: context.animationCache,
                                renderer: context.animationRenderer,
                                placeholderColor: item.presentationData.theme.chat.inputPanel.inputTextColor.withAlphaComponent(0.12),
                                attemptSynchronous: false
                            )
                        )
                    } else if let titleApply = titleLayoutAndApply?.1 {
                        let _ = titleApply()
                    }
                    
                    let _ = labelApply()
                    
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
                    
                    var centralContentHeight: CGFloat = titleLayout.size.height
                    switch item.labelStyle {
                    case .detailText, .multilineDetailText:
                        centralContentHeight += titleSpacing
                        centralContentHeight += labelLayout.size.height
                    default:
                        break
                    }
                    if let additionalDetailLabelInfo {
                        centralContentHeight += titleSpacing
                        centralContentHeight += additionalDetailLabelInfo.0.size.height
                    }
                    
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - centralContentHeight) / 2.0)), size: titleLayout.size)
                    strongSelf.titleNode.textNode.frame = titleFrame
                    
                    if let updateBadgeImage = updatedLabelBadgeImage {
                        if strongSelf.labelBadgeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.labelBadgeNode, belowSubnode: strongSelf.labelNode)
                        }
                        strongSelf.labelBadgeNode.image = updateBadgeImage
                    }
                    if badgeColor == nil && strongSelf.labelBadgeNode.supernode != nil {
                        strongSelf.labelBadgeNode.image = nil
                        strongSelf.labelBadgeNode.removeFromSupernode()
                    }
                    
                    var badgeWidth = max(badgeDiameter, labelLayout.size.width + 10.0)
                    if case .semitransparentBadge = item.labelStyle {
                        badgeWidth += 2.0
                    }
                    let badgeFrame = CGRect(origin: CGPoint(x: params.width - rightInset - badgeWidth, y: floor((contentSize.height - badgeDiameter) / 2.0)), size: CGSize(width: badgeWidth, height: badgeDiameter))
                    strongSelf.labelBadgeNode.frame = badgeFrame
                    
                    let labelFrame: CGRect
                    switch item.labelStyle {
                    case .badge:
                        labelFrame = CGRect(origin: CGPoint(x: params.width - rightInset - badgeWidth + (badgeWidth - labelLayout.size.width) / 2.0, y: badgeFrame.minY + 1.0), size: labelLayout.size)
                    case .semitransparentBadge:
                        labelFrame = CGRect(origin: CGPoint(x: params.width - rightInset - badgeWidth + (badgeWidth - labelLayout.size.width) / 2.0, y: badgeFrame.minY + 1.0 - UIScreenPixel + floorToScreenPixels((badgeDiameter - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                    case .detailText, .multilineDetailText:
                        labelFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: labelLayout.size)
                    default:
                        labelFrame = CGRect(origin: CGPoint(x: params.width - rightInset - labelLayout.size.width, y: floor((height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                    }
                    strongSelf.labelNode.frame = labelFrame
                    
                    if let additionalDetailLabelInfo = additionalDetailLabelInfo {
                        let additionalDetailLabelNode = additionalDetailLabelInfo.1()
                        
                        if strongSelf.additionalDetailLabelNode !== additionalDetailLabelNode {
                            strongSelf.additionalDetailLabelNode?.removeFromSupernode()
                            strongSelf.additionalDetailLabelNode = additionalDetailLabelNode
                            strongSelf.addSubnode(additionalDetailLabelNode)
                        }
                        
                        additionalDetailLabelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: additionalDetailLabelInfo.0.size)
                    } else if let additionalDetailLabelNode = strongSelf.additionalDetailLabelNode {
                        strongSelf.additionalDetailLabelNode = nil
                        additionalDetailLabelNode.removeFromSupernode()
                    }
                    
                    if let (badgeTextLayout, badgeTextApply) = titleBadgeTextNodeLayout {
                        let titleBadgeNode: ASImageNode
                        if let current = strongSelf.titleBadgeNode {
                            titleBadgeNode = current
                        } else {
                            titleBadgeNode = ASImageNode()
                            strongSelf.titleBadgeNode = titleBadgeNode
                            strongSelf.addSubnode(titleBadgeNode)
                            
                            titleBadgeNode.image = generateFilledRoundedRectImage(size: CGSize(width: 16.0, height: 16.0), cornerRadius: 5.0, color: item.presentationData.theme.list.itemCheckColors.fillColor)?.stretchableImage(withLeftCapWidth: 6, topCapHeight: 6)
                        }
                        
                        let titleBadgeTextNode = badgeTextApply()
                        if titleBadgeTextNode.supernode == nil {
                            strongSelf.addSubnode(titleBadgeTextNode)
                        }
                        let badgeSideInset: CGFloat = 5.0
                        let badgeVerticalInset: CGFloat = 2.0
                        let badgeSize = CGSize(width: badgeTextLayout.size.width + badgeSideInset * 2.0, height: badgeTextLayout.size.height + badgeVerticalInset * 2.0)
                        let titleBadgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 5.0, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - badgeSize.height) * 0.5)), size: badgeSize)
                        let titleBadgeTextFrame = CGRect(origin: CGPoint(x: titleBadgeFrame.minX + badgeSideInset, y: titleBadgeFrame.minY + badgeVerticalInset), size: badgeTextLayout.size)
                        
                        titleBadgeNode.frame = titleBadgeFrame
                        titleBadgeTextNode.frame = titleBadgeTextFrame
                    } else {
                        if let titleBadgeTextNode = strongSelf.titleBadgeTextNode {
                            strongSelf.titleBadgeTextNode = nil
                            titleBadgeTextNode.removeFromSupernode()
                        }
                        if let titleBadgeNode = strongSelf.titleBadgeNode {
                            strongSelf.titleBadgeNode = nil
                            titleBadgeNode.removeFromSupernode()
                        }
                    }
                    
                    if let titleIcon = item.titleIcon {
                        if strongSelf.titleIconNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.titleIconNode)
                        }
                        
                        strongSelf.titleIconNode.image = titleIcon
                        strongSelf.titleIconNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + 5.0, y: floor((layout.contentSize.height - titleIcon.size.height) / 2.0) - 1.0), size: titleIcon.size)
                    } else {
                        if strongSelf.titleIconNode.supernode != nil {
                            strongSelf.titleIconNode.removeFromSupernode()
                        }
                    }
 
                    if case .textWithIcon = item.labelStyle {
                        if let updatedLabelImage = updatedLabelImage {
                            strongSelf.labelImageNode.image = updatedLabelImage
                        }
                        if strongSelf.labelImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.labelImageNode)
                        }
                        
                        if let size = strongSelf.labelImageNode.image?.size {
                            strongSelf.labelImageNode.frame = CGRect(origin: CGPoint(x: labelFrame.minX - size.width - 5.0, y: floor((layout.contentSize.height - size.height) / 2.0) - 1.0), size: size)
                        }
                    } else if case let .image(_, size) = item.labelStyle {
                        if let updatedLabelImage = updatedLabelImage {
                            strongSelf.labelImageNode.image = updatedLabelImage
                        }
                        if strongSelf.labelImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.labelImageNode)
                        }
                        
                        strongSelf.labelImageNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - size.width - 30.0, y: floor((layout.contentSize.height - size.height) / 2.0)), size: size)
                    } else if case .color = item.labelStyle {
                        if let updatedLabelImage = updatedLabelImage {
                            strongSelf.labelImageNode.image = updatedLabelImage
                        }
                        if strongSelf.labelImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.labelImageNode)
                        }
                        if let image = strongSelf.labelImageNode.image {
                            strongSelf.labelImageNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 50.0, y: floor((layout.contentSize.height - image.size.height) / 2.0)), size: image.size)
                        }
                    } else if strongSelf.labelImageNode.supernode != nil {
                        strongSelf.labelImageNode.removeFromSupernode()
                        strongSelf.labelImageNode.image = nil
                    }
                    
                    if let arrowImage = strongSelf.arrowNode.image {
                        let arrowRightOffset: CGFloat
                        switch item.disclosureStyle {
                        case .optionArrows:
                            arrowRightOffset = 18.0
                        case .none, .arrow:
                            arrowRightOffset = 7.0
                        }
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - arrowRightOffset - arrowImage.size.width, y: floorToScreenPixels((height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
                    }
                    
                    switch item.disclosureStyle {
                    case .none:
                        strongSelf.arrowNode.isHidden = true
                    case .arrow, .optionArrows:
                        strongSelf.arrowNode.isHidden = false
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: height + UIScreenPixel))

                    if let shimmeringIndex = item.shimmeringIndex {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.insertSubnode(shimmerNode, aboveSubnode: strongSelf.backgroundNode)
                            } else {
                                strongSelf.addSubnode(shimmerNode)
                            }
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }

                        var shapes: [ShimmerEffectNode.Shape] = []

                        let titleLineWidth: CGFloat = (shimmeringIndex % 2 == 0) ? 120.0 : 80.0
                        let lineDiameter: CGFloat = 8.0

                        let titleFrame = strongSelf.titleNode.textNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))

                        shimmerNode.update(backgroundColor: item.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: contentSize)
                    } else if let shimmerNode = strongSelf.placeholderNode {
                        strongSelf.placeholderNode = nil
                        shimmerNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && (self.item?.enabled ?? false) {
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
