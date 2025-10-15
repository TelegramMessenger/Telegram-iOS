import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AvatarNode

public final class GiftOptionItem: ListViewItem, ItemListItem {
    public enum Icon: Equatable {
        public enum Color {
            case blue
            case green
            case red
            case violet
            case premium
            case stars
        }
        
        case peer(EnginePeer)
        case image(color: Color, name: String)
    }
    
    public enum Font {
        case regular
        case bold
    }
    
    public enum SubtitleFont {
        case regular
        case small
    }
    
    public enum Label {
        case generic(String)
        case semitransparent(String)
        case boosts(Int32)
        
        var string: String {
            switch self {
            case let .generic(value), let .semitransparent(value):
                return value
            case let .boosts(value):
                return "\(value)"
            }
        }
    }
    
    let presentationData: ItemListPresentationData
    let context: AccountContext
    let icon: Icon?
    let title: String
    let titleFont: Font
    let titleBadge: String?
    let subtitle: String?
    let subtitleFont: SubtitleFont
    let subtitleActive: Bool
    let label: Label?
    let badge: String?
    let isSelected: Bool?
    let stars: Int64?
    public let sectionId: ItemListSectionId
    let action: (() -> Void)?
    
    public init(presentationData: ItemListPresentationData, context: AccountContext, icon: Icon? = nil, title: String, titleFont: Font = .regular, titleBadge: String? = nil, subtitle: String?, subtitleFont: SubtitleFont = .regular, subtitleActive: Bool = false, label: Label? = nil, badge: String? = nil, isSelected: Bool? = nil, stars: Int64? = nil, sectionId: ItemListSectionId, action: (() -> Void)?) {
        self.presentationData = presentationData
        self.icon = icon
        self.context = context
        self.title = title
        self.titleFont = titleFont
        self.titleBadge = titleBadge
        self.subtitle = subtitle
        self.subtitleFont = subtitleFont
        self.subtitleActive = subtitleActive
        self.label = label
        self.badge = badge
        self.isSelected = isSelected
        self.stars = stars
        self.sectionId = sectionId
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = GiftOptionItemNode()
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
            if let nodeValue = node() as? GiftOptionItemNode {
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
    
    public var selectable: Bool {
        return self.action != nil
    }
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

class GiftOptionItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    fileprivate var iconNode: ASImageNode?
    fileprivate var avatarNode: AvatarNode?
    private let titleNode: TextNode
    private let titleBadge = ComponentView<Empty>()
    private let statusNode: TextNode
    private var statusArrowNode: ASImageNode?
    private var starsIconNode: ASImageNode?
    
    private var labelBackgroundNode: ASImageNode?
    private let labelNode: TextNode
    private var labelIconNode: ASImageNode?
    private let badgeTextNode: TextNode
    private var badgeBackgroundNode: ASImageNode?
    
    private var layoutParams: (GiftOptionItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
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
    
    func asyncLayout() -> (_ item: GiftOptionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeBadgeLayout = TextNode.asyncLayout(self.badgeTextNode)
        let selectableControlLayout = ItemListSelectableControlNode.asyncLayout(self.selectableControlNode)
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, neighbors in
            let titleFont: UIFont
            switch item.titleFont {
            case .regular:
                titleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 17.0 / 17.0))
            case .bold:
                titleFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 17.0 / 17.0))
            }

            let statusFont: UIFont
            switch item.subtitleFont {
            case .regular:
                statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            case .small:
                statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
            }
                        
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let rightInset: CGFloat = params.rightInset
            
            let titleAttributedString = NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let statusAttributedString = NSAttributedString(string: item.subtitle ?? "", font: statusFont, textColor: item.subtitleActive ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
            let badgeAttributedString = NSAttributedString(string: item.badge ?? "", font: Font.with(size: 13.0, design: .round, weight: .semibold), textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor)
            
            let labelColor: UIColor
            let labelFont: UIFont
            if let label = item.label, case .boosts = label {
                labelColor = item.presentationData.theme.list.itemAccentColor
                labelFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            } else if let label = item.label, case .semitransparent = label {
                labelColor = item.presentationData.theme.list.itemAccentColor
                labelFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            } else {
                labelColor = item.presentationData.theme.list.itemSecondaryTextColor
                labelFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 17.0 / 17.0))
            }
            
            let labelAttributedString = NSAttributedString(string: item.label?.string ?? "", font: labelFont, textColor: labelColor)
            
            let leftInset: CGFloat = 14.0 + params.leftInset
            
            var avatarInset: CGFloat = 0.0
            if let _ = item.icon {
                avatarInset += 48.0
            }
            
            let verticalInset: CGFloat = 10.0
            var titleSpacing: CGFloat = 2.0
            if case .bold = item.titleFont {
                titleSpacing = 0.0
            }
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let separatorHeight = UIScreenPixel
            
            var selectableControlSizeAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            var editingOffset: CGFloat = 0.0
            
            if let isSelected = item.isSelected {
                let sizeAndApply = selectableControlLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, isSelected, .regular)
                selectableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
            }
                        
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: labelAttributedString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: .greatestFiniteMagnitude)))
            
            var textConstrainedWidth = params.width - leftInset - 8.0 - editingOffset - rightInset - labelLayout.size.width - avatarInset
            var subtitleConstrainedWidth = textConstrainedWidth
            if let label = item.label, case .semitransparent = label {
                textConstrainedWidth -= 54.0
                subtitleConstrainedWidth -= 30.0
            }
            if let _ = item.titleBadge {
                textConstrainedWidth -= 32.0
                subtitleConstrainedWidth -= 32.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude)))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: subtitleConstrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (badgeLayout, badgeApply) = makeBadgeLayout(TextNodeLayoutArguments(attributedString: badgeAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textConstrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
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
                    
                    let iconUpdated = currentItem?.icon != item.icon
                    
                    let iconSize = CGSize(width: 40.0, height: 40.0)
                    if let icon = item.icon {
                        let iconFrame = CGRect(origin: CGPoint(x: leftInset - 3.0 + editingOffset, y: floorToScreenPixels((layout.contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                        
                        switch icon {
                        case let .peer(peer):
                            if let iconNode = strongSelf.iconNode {
                                strongSelf.iconNode = nil
                                iconNode.removeFromSupernode()
                            }
                            
                            let avatarNode: AvatarNode
                            if let current = strongSelf.avatarNode {
                                avatarNode = current
                            } else {
                                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0)))
                                strongSelf.addSubnode(avatarNode)
                                
                                strongSelf.avatarNode = avatarNode
                            }
                            avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer)
                            avatarNode.frame = iconFrame
                        case let .image(color, name):
                            if let avatarNode = strongSelf.avatarNode {
                                strongSelf.avatarNode = nil
                                avatarNode.removeFromSupernode()
                            }
                            
                            let iconNode: ASImageNode
                            if let current = strongSelf.iconNode {
                                iconNode = current
                            } else {
                                iconNode = ASImageNode()
                                iconNode.displaysAsynchronously = false
                                strongSelf.addSubnode(iconNode)
                                
                                strongSelf.iconNode = iconNode
                            }
                            
                            let colors: [UIColor]
                            var diagonal = false
                            switch color {
                            case .blue:
                                colors = [UIColor(rgb: 0x2a9ef1), UIColor(rgb: 0x71d4fc)]
                            case .green:
                                colors = [UIColor(rgb: 0x54cb68), UIColor(rgb: 0xa0de7e)]
                            case .red:
                                colors = [UIColor(rgb: 0xff516a), UIColor(rgb: 0xff885e)]
                            case .violet:
                                colors = [UIColor(rgb: 0xd569ec), UIColor(rgb: 0xe0a2f3)]
                            case .premium:
                                colors = [
                                    UIColor(rgb: 0x6b93ff),
                                    UIColor(rgb: 0x6b93ff),
                                    UIColor(rgb: 0x8d77ff),
                                    UIColor(rgb: 0xb56eec),
                                    UIColor(rgb: 0xb56eec)
                                ]
                                diagonal = true
                            case .stars:
                                colors = [UIColor(rgb: 0xdd6f12), UIColor(rgb: 0xfec80f)]
                                diagonal = true
                            }
                            if iconNode.image == nil || iconUpdated {
                                iconNode.image = generateAvatarImage(size: iconSize, icon: generateTintedImage(image: UIImage(bundleImageName: name), color: .white), iconScale: 1.0, cornerRadius: 20.0, color: .blue, customColors: colors, diagonal: diagonal)
                            }
                            iconNode.frame = iconFrame
                        }
                    } else {
                        if let avatarNode = strongSelf.avatarNode {
                            strongSelf.avatarNode = nil
                            avatarNode.removeFromSupernode()
                        }
                        if let iconNode = strongSelf.iconNode {
                            strongSelf.iconNode = nil
                            iconNode.removeFromSupernode()
                        }
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
                    
                    var titleOffset: CGFloat = 0.0
                    if let stars = item.stars {
                        let starsIconNode: ASImageNode
                        if let current = strongSelf.starsIconNode {
                            starsIconNode = current
                        } else {
                            starsIconNode = ASImageNode()
                            starsIconNode.displaysAsynchronously = false
                            strongSelf.addSubnode(starsIconNode)
                            strongSelf.starsIconNode = starsIconNode
                            
                            starsIconNode.image = generateStarsIcon(amount: stars)
                        }
                        
                        if let icon = starsIconNode.image {
                            starsIconNode.frame = CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset, y: 10.0), size: icon.size)
                            titleOffset += icon.size.width + 3.0
                        }
                    }
                                        
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = labelApply()
                    let _ = badgeApply()
                                                            
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
                            bottomStripeInset = leftInset + editingOffset + avatarInset
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
                    
                    let titleVerticalOriginY: CGFloat
                    if statusLayout.size.height > 0.0 {
                        titleVerticalOriginY = verticalInset
                    } else {
                        titleVerticalOriginY = floorToScreenPixels((contentSize.height - titleLayout.size.height) / 2.0)
                    }
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset + titleOffset, y: titleVerticalOriginY), size: titleLayout.size)
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                    
                    var badgeOffset: CGFloat = 0.0
                    if badgeLayout.size.width > 0.0 {
                        let badgeFrame = CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset + 2.0, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: badgeLayout.size)
                        let badgeBackgroundFrame = badgeFrame.insetBy(dx: -3.0, dy: -2.0)
                        
                        let badgeBackgroundNode: ASImageNode
                        if let current = strongSelf.badgeBackgroundNode {
                            badgeBackgroundNode = current
                        } else {
                            badgeBackgroundNode = ASImageNode()
                            badgeBackgroundNode.displaysAsynchronously = false
                            badgeBackgroundNode.image = generateStretchableFilledCircleImage(radius: 5.0, color: item.presentationData.theme.list.itemCheckColors.fillColor)
                            strongSelf.badgeBackgroundNode = badgeBackgroundNode
                            
                            strongSelf.containerNode.addSubnode(badgeBackgroundNode)
                            strongSelf.containerNode.addSubnode(strongSelf.badgeTextNode)
                        }

                        transition.updateFrame(node: badgeBackgroundNode, frame: badgeBackgroundFrame)
                        transition.updateFrame(node: strongSelf.badgeTextNode, frame: badgeFrame)
                        
                        badgeOffset = badgeLayout.size.width + 10.0
                    }
                    
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset + badgeOffset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                                        
                    if let label = item.label, case .boosts = label {
                        let backgroundNode: ASImageNode
                        let iconNode: ASImageNode
                        if let currentBackground = strongSelf.labelBackgroundNode, let currentIcon = strongSelf.labelIconNode {
                            backgroundNode = currentBackground
                            iconNode = currentIcon
                        } else {
                            backgroundNode = ASImageNode()
                            backgroundNode.displaysAsynchronously = false
                            backgroundNode.image = generateStretchableFilledCircleImage(radius: 13.0, color: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.1))
                            strongSelf.containerNode.insertSubnode(backgroundNode, at: 1)
                            
                            iconNode = ASImageNode()
                            iconNode.displaysAsynchronously = false
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Premium/BoostChannel"), color: item.presentationData.theme.list.itemAccentColor)
                            strongSelf.containerNode.addSubnode(iconNode)
                            
                            strongSelf.labelBackgroundNode = backgroundNode
                            strongSelf.labelIconNode = iconNode
                        }
                        
                        if let icon = iconNode.image {
                            let labelFrame = CGRect(origin: CGPoint(x: layoutSize.width - rightInset - labelLayout.size.width - 21.0, y: floorToScreenPixels((layout.contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                            let iconFrame = CGRect(origin: CGPoint(x: labelFrame.minX - icon.size.width - 2.0, y: labelFrame.minY - 1.0), size: icon.size)
                            let totalFrame = CGRect(x: iconFrame.minX - 7.0, y: labelFrame.minY - 4.0, width: iconFrame.width + labelFrame.width + 18.0, height: 26.0)
                            transition.updateFrame(node: backgroundNode, frame: totalFrame)
                            transition.updateFrame(node: strongSelf.labelNode, frame: labelFrame)
                            transition.updateFrame(node: iconNode, frame: iconFrame)
                        }
                    } else if let label = item.label, case .semitransparent = label {
                        let backgroundNode: ASImageNode
                        if let currentBackground = strongSelf.labelBackgroundNode {
                            backgroundNode = currentBackground
                        } else {
                            backgroundNode = ASImageNode()
                            backgroundNode.displaysAsynchronously = false
                            backgroundNode.image = generateStretchableFilledCircleImage(radius: 13.0, color: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.1))
                            strongSelf.containerNode.insertSubnode(backgroundNode, at: 1)
                            
                            strongSelf.labelBackgroundNode = backgroundNode
                        }
                        
                        let labelFrame = CGRect(origin: CGPoint(x: layoutSize.width - rightInset - labelLayout.size.width - 19.0, y: floorToScreenPixels((layout.contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                        let totalFrame = CGRect(x: labelFrame.minX - 7.0, y: labelFrame.minY - 5.0, width: labelFrame.width + 14.0, height: 26.0)
                        transition.updateFrame(node: backgroundNode, frame: totalFrame)
                        transition.updateFrame(node: strongSelf.labelNode, frame: labelFrame)
                    } else {
                        transition.updateFrame(node: strongSelf.labelNode, frame: CGRect(origin: CGPoint(x: layoutSize.width - rightInset - labelLayout.size.width - 18.0, y: floorToScreenPixels((layout.contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size))
                        
                        if let labelIconNode = strongSelf.labelIconNode {
                            strongSelf.labelIconNode = nil
                            labelIconNode.removeFromSupernode()
                        }
                        if let labelBackgroundNode = strongSelf.labelBackgroundNode {
                            strongSelf.labelBackgroundNode = nil
                            labelBackgroundNode.removeFromSupernode()
                        }
                    }
                    
                    if item.subtitleActive {
                        let statusArrowNode: ASImageNode
                        if let current = strongSelf.statusArrowNode {
                            statusArrowNode = current
                        } else {
                            statusArrowNode = ASImageNode()
                            statusArrowNode.displaysAsynchronously = false
                            statusArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: item.presentationData.theme.list.itemAccentColor)
                            strongSelf.statusArrowNode = statusArrowNode
                            strongSelf.containerNode.addSubnode(statusArrowNode)
                        }
                        if let arrowSize = statusArrowNode.image?.size {
                            transition.updateFrame(node: statusArrowNode, frame: CGRect(origin: CGPoint(x: leftInset + editingOffset + avatarInset + statusLayout.size.width + 4.0, y: strongSelf.titleNode.frame.maxY + titleSpacing + 4.0), size: arrowSize))
                        }
                    } else if let statusArrowNode = strongSelf.statusArrowNode {
                        strongSelf.statusArrowNode = nil
                        statusArrowNode.removeFromSupernode()
                    }
                                        
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: strongSelf.backgroundNode.frame.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if let badge = item.titleBadge {
                        let badgeSize = strongSelf.titleBadge.update(
                            transition: .immediate,
                            component: AnyComponent(
                                BoostIconComponent(hasIcon: true, text: badge)
                            ),
                            environment: {},
                            containerSize: CGSize(width: params.width, height: 100.0)
                        )
                        if let view = strongSelf.titleBadge.view {
                            if view.superview == nil {
                                strongSelf.view.addSubview(view)
                            }
                            
                            let badgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - badgeSize.height / 2.0) - 1.0), size: badgeSize)
                            view.frame = badgeFrame
                        }
                    } else {
                        if let view = strongSelf.titleBadge.view {
                            view.removeFromSuperview()
                        }
                    }
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

private func generateStarsIcon(amount: Int64) -> UIImage {
    let stars: [Int64: Int] = [
        15: 1,
        75: 2,
        250: 3,
        500: 4,
        1000: 5,
        2500: 6,

        25: 1,
        50: 1,
        100: 2,
        150: 2,
        350: 3,
        750: 4,
        1500: 5,
        
        5000: 6,
        10000: 6,
        25000: 7,
        35000: 7
    ]
    let count = stars[amount] ?? 1
    
    let image = generateGradientTintedImage(
        image: UIImage(bundleImageName: "Peer Info/PremiumIcon"),
        colors: [
            UIColor(rgb: 0xfed219),
            UIColor(rgb: 0xf3a103),
            UIColor(rgb: 0xe78104)
        ],
        direction: .diagonal
    )!
    
    let imageSize = CGSize(width: 20.0, height: 20.0)
    let partImage = generateImage(imageSize, contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size), byTiling: false)
            context.saveGState()
            context.clip(to: CGRect(origin: .zero, size: size).insetBy(dx: -1.0, dy: -1.0).offsetBy(dx: -2.0, dy: 0.0), mask: cgImage)
            
            context.setBlendMode(.clear)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.restoreGState()
            
            context.setBlendMode(.clear)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width / 2.0, height: size.height - 4.0)))
        }
    })!
    
    let spacing: CGFloat = (3.0 - UIScreenPixel)
    let totalWidth = 20.0 + spacing * CGFloat(count - 1)
    
    return generateImage(CGSize(width: ceil(totalWidth), height: 20.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        var originX = floorToScreenPixels((size.width - totalWidth) / 2.0)
        
        let mainImage = UIImage(bundleImageName: "Premium/Stars/StarLarge")
        if let cgImage = mainImage?.cgImage, let partCGImage = partImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: originX, y: 0.0), size: imageSize).insetBy(dx: -1.5, dy: -1.5), byTiling: false)
            originX += spacing + UIScreenPixel
            
            for _ in 0 ..< count - 1 {
                context.draw(partCGImage, in: CGRect(origin: CGPoint(x: originX, y: -UIScreenPixel), size: imageSize).insetBy(dx: -1.0 + UIScreenPixel, dy: -1.0 + UIScreenPixel), byTiling: false)
                originX += spacing
            }
        }
    })!
}
