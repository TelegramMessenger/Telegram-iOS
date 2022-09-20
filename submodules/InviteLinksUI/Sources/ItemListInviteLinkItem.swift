import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import ShimmerEffect
import TelegramCore

func invitationAvailability(_ invite: ExportedInvitation) -> CGFloat {
    if case let .link(_, _, _, _, isRevoked, _, date, startDate, expireDate, usageLimit, count, _) = invite {
        if isRevoked {
            return 0.0
        }
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        var availability: CGFloat = 1.0
        if let expireDate = expireDate {
            let startDate = startDate ?? date
            let fraction = CGFloat(expireDate - currentTime) / CGFloat(expireDate - startDate)
            availability = min(fraction, availability)
        }
        if let usageLimit = usageLimit, let count = count {
            let fraction = 1.0 - (CGFloat(count) / CGFloat(usageLimit))
            availability = min(fraction, availability)
        }
        return max(0.0, min(1.0, availability))
    } else {
        return 1.0
    }
}

private enum ItemBackgroundColor: Equatable {
    case blue
    case green
    case yellow
    case red
    case gray
    
    var colors: (top: UIColor, bottom: UIColor, text: UIColor) {
        switch self {
            case .blue:
                return (UIColor(rgb: 0x00b5f7), UIColor(rgb: 0x00b2f6), UIColor(rgb: 0xa7f4ff))
            case .green:
                return (UIColor(rgb: 0x4aca62), UIColor(rgb: 0x43c85c), UIColor(rgb: 0xc5ffe6))
            case .yellow:
                return (UIColor(rgb: 0xf8a953), UIColor(rgb: 0xf7a64e), UIColor(rgb: 0xfeffd7))
            case .red:
                return (UIColor(rgb: 0xf2656a), UIColor(rgb: 0xf25f65), UIColor(rgb: 0xffd3de))
            case .gray:
                return (UIColor(rgb: 0xa8b2bb), UIColor(rgb: 0xa2abb4), UIColor(rgb: 0xe3e6e8))
        }
    }
}

public class ItemListInviteLinkItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let invite: ExportedInvitation?
    let share: Bool
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let tapAction: ((ExportedInvitation) -> Void)?
    let contextAction: ((ExportedInvitation, ASDisplayNode, ContextGesture?) -> Void)?
    public let tag: ItemListItemTag?
    
    public init(
        presentationData: ItemListPresentationData,
        invite: ExportedInvitation?,
        share: Bool,
        sectionId: ItemListSectionId,
        style: ItemListStyle,
        tapAction: ((ExportedInvitation) -> Void)?,
        contextAction: ((ExportedInvitation, ASDisplayNode, ContextGesture?) -> Void)?,
        tag: ItemListItemTag? = nil
    ) {
        self.presentationData = presentationData
        self.invite = invite
        self.share = share
        self.sectionId = sectionId
        self.style = style
        self.tapAction = tapAction
        self.contextAction = contextAction
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            var firstWithHeader = false
            var last = false
            if self.style == .plain {
                if previousItem == nil {
                    firstWithHeader = true
                }
                if nextItem == nil {
                    last = true
                }
            }
            let node = ItemListInviteLinkItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), firstWithHeader, last)
            
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
            if let nodeValue = node() as? ItemListInviteLinkItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    var firstWithHeader = false
                    var last = false
                    if self.style == .plain {
                        if previousItem == nil {
                            firstWithHeader = true
                        }
                        if nextItem == nil {
                            last = true
                        }
                    }
                    
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), firstWithHeader, last)
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
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        if let invite = self.invite {
            self.tapAction?(invite)
        }
    }
}

public class ItemListInviteLinkItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let extractedBackgroundImageNode: ASImageNode

    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let offsetContainerNode: ASDisplayNode
    
    private let iconBackgroundNode: ASDisplayNode
    private let iconNode: ASImageNode
    private var timerNode: TimerNode?
    
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var currentColor: ItemBackgroundColor?
    private var layoutParams: (ItemListInviteLinkItem, ListViewItemLayoutParams, ItemListNeighbors, Bool, Bool)?
    
    public var tag: ItemListItemTag?
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        self.maskNode = ASImageNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.iconBackgroundNode = ASDisplayNode()
        self.iconBackgroundNode.setLayerBlock { () -> CALayer in
            return CAShapeLayer()
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.contentMode = .center
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
    
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.contentMode = .left
        self.subtitleNode.contentsScale = UIScreen.main.scale
            
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        
        self.offsetContainerNode.addSubnode(self.iconBackgroundNode)
        self.offsetContainerNode.addSubnode(self.iconNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.subtitleNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let invite = item.invite, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(invite, strongSelf.contextSourceNode, gesture)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0 else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    public override func didLoad() {
        super.didLoad()
        
        if let shapeLayer = self.iconBackgroundNode.layer as? CAShapeLayer {
            shapeLayer.path = UIBezierPath(ovalIn: CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)).cgPath
        }
    }
    
    public func asyncLayout() -> (_ item: ItemListInviteLinkItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors, _ firstWithHeader: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        let currentItem = self.layoutParams?.0
                
        return { item, params, neighbors, firstWithHeader, last in
            var updatedTheme: PresentationTheme?
        
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let availability = item.invite.flatMap { invitationAvailability($0) } ?? 0.0
            
            let color: ItemBackgroundColor
            let nextColor: ItemBackgroundColor
            let transitionFraction: CGFloat
            if let invite = item.invite, case let .link(_, _, _, _, isRevoked, _, _, _, expireDate, usageLimit, _, _) = invite {
                if isRevoked {
                    color = .gray
                    nextColor = .gray
                    transitionFraction = 0.0
                } else if expireDate == nil && usageLimit == nil {
                    color = .blue
                    nextColor = .blue
                    transitionFraction = 0.0
                } else if availability >= 0.5 {
                    color = .green
                    nextColor = .yellow
                    transitionFraction = (availability - 0.5) / 0.5
                } else if availability > 0.0 {
                    color = .yellow
                    nextColor = .red
                    transitionFraction = availability / 0.5
                } else {
                    color = .red
                    nextColor = .red
                    transitionFraction = 0.0
                }
            } else {
                color = .gray
                nextColor = .gray
                transitionFraction = 0.0
            }
            
            let topColor = color.colors.top
            let nextTopColor = nextColor.colors.top
            let iconColor: UIColor
            if let _ = item.invite {
                if case .blue = color {
                    iconColor = item.presentationData.theme.list.itemAccentColor
                } else {
                    iconColor = nextTopColor.mixedWith(topColor, alpha: transitionFraction)
                }
            } else {
                iconColor = item.presentationData.theme.list.mediaPlaceholderColor
            }
            
            let inviteLink = item.invite?.link?.replacingOccurrences(of: "https://", with: "") ?? ""
            var titleText = inviteLink
            var subtitleText: String = ""
            var timerValue: TimerNode.Value?
            
            
            if let invite = item.invite, case let  .link(_, title, _, _, _, _, date, startDate, expireDate, usageLimit, count, requestedCount) = invite {
                if let title = title, !title.isEmpty {
                    titleText = title
                }
                
                let count = count ?? 0
                let requestedCount = requestedCount ?? 0
                
                if count > 0 {
                    subtitleText = item.presentationData.strings.InviteLink_PeopleJoinedShort(count)
                } else {
                    if let usageLimit = usageLimit, count == 0 && !availability.isZero {
                        subtitleText = item.presentationData.strings.InviteLink_PeopleCanJoin(usageLimit)
                    } else {
                        if availability.isZero {
                            subtitleText = item.presentationData.strings.InviteLink_PeopleJoinedShortNoneExpired
                        } else if requestedCount == 0 {
                            subtitleText = item.presentationData.strings.InviteLink_PeopleJoinedShortNone
                        }
                    }
                }
                
                if requestedCount > 0 {
                    if !subtitleText.isEmpty {
                        subtitleText += ", "
                    }
                    subtitleText += item.presentationData.strings.MemberRequests_PeopleRequestedShort(requestedCount)
                }
                
                if invite.isRevoked {
                    if !subtitleText.isEmpty {
                        subtitleText += " • "
                    }
                    subtitleText += item.presentationData.strings.InviteLink_Revoked
                } else {
                    var isExpired = false
                    if let expireDate = expireDate, currentTime >= expireDate {
                        isExpired = true
                    }
                    var isFull = false
                    
                    if let usageLimit = usageLimit {
                        if !isExpired {
                            let remaining = usageLimit - count
                            if remaining > 0 && remaining != usageLimit {
                                subtitleText += ", "
                                subtitleText += item.presentationData.strings.InviteLink_PeopleRemaining(remaining)
                                
                                let fraction = CGFloat(remaining) / CGFloat(usageLimit)
                                if abs(fraction - availability) < 0.0001 {
                                    timerValue = .fraction(fraction)
                                }
                            } else if remaining == 0 {
                                isFull = true
                                if !subtitleText.isEmpty {
                                    subtitleText += " • "
                                }
                                subtitleText += item.presentationData.strings.InviteLink_UsageLimitReached
                            }
                        }
                    }
                    if let expireDate = expireDate, !isFull {
                        if !isExpired {
                            if !subtitleText.isEmpty {
                                subtitleText += " • "
                            }
                            let elapsedTime = expireDate - currentTime
                            if elapsedTime >= 86400 {
                                subtitleText += item.presentationData.strings.InviteLink_ExpiresIn(scheduledTimeIntervalString(strings: item.presentationData.strings, value: elapsedTime)).string
                            } else {
                                subtitleText += item.presentationData.strings.InviteLink_ExpiresIn(textForTimeout(value: elapsedTime)).string
                            }
                            if timerValue == nil {
                                timerValue = .timestamp(creation: startDate ?? date, deadline: expireDate)
                            }
                        } else {
                            if !subtitleText.isEmpty {
                                subtitleText += " • "
                            }
                            subtitleText += item.presentationData.strings.InviteLink_Expired
                        }
                    }
                }
            } else {
                titleText = " "
                subtitleText = " "
            }
            
            let titleAttributedString = NSAttributedString(string: titleText, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let subtitleAttributedString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let verticalInset: CGFloat = subtitleAttributedString.string.isEmpty ? 14.0 : 8.0
           
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + subtitleLayout.size.height
            
            var insets: UIEdgeInsets
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    insets = itemListNeighborsPlainInsets(neighbors)
                    insets.top = firstWithHeader ? 29.0 : 0.0
                    insets.bottom = 0.0
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors, firstWithHeader, last)
                                        
                    strongSelf.accessibilityLabel = titleAttributedString.string
                    strongSelf.accessibilityValue = subtitleAttributedString.string
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                    
                    let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width - 16.0, height: layout.contentSize.height))
                    let extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    if strongSelf.contextSourceNode.isExtractedToContextPreview {
                        strongSelf.extractedBackgroundImageNode.frame = extractedRect
                    } else {
                        strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                    }
                    strongSelf.contextSourceNode.contentRect = extractedRect
                     
                    if let layer = strongSelf.iconBackgroundNode.layer as? CAShapeLayer {
                        layer.fillColor = iconColor.cgColor
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: item.presentationData.theme.list.itemCheckColors.foregroundColor)
                    }
                                        
                    let transition = ContainedViewLayoutTransition.immediate
                                        
                    let _ = titleApply()
                    let _ = subtitleApply()
                    
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
                            
                            let stripeInset: CGFloat
                            if case .none = neighbors.bottom {
                                stripeInset = 0.0
                            } else {
                                stripeInset = leftInset
                            }
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: stripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - stripeInset, height: separatorHeight))
                            strongSelf.bottomStripeNode.isHidden = last
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
                    
                    let iconSize: CGSize = CGSize(width: 40.0, height: 40.0)
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + 12.0, y: floorToScreenPixels((layout.contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                    strongSelf.iconBackgroundNode.bounds = CGRect(origin: CGPoint(), size: iconSize)
                    strongSelf.iconBackgroundNode.position = iconFrame.center
                    strongSelf.iconNode.frame = iconFrame
                    
                    transition.updateTransformScale(node: strongSelf.iconBackgroundNode, scale: timerValue != nil ? 0.875 : 1.0)
                    
                    if let timerValue = timerValue {
                        let timerNode: TimerNode
                        if let current = strongSelf.timerNode {
                            timerNode = current
                        } else {
                            timerNode = TimerNode()
                            timerNode.isUserInteractionEnabled = false
                            strongSelf.timerNode = timerNode
                            strongSelf.offsetContainerNode.addSubnode(timerNode)
                        }
                        timerNode.update(color: iconColor, value: timerValue)
                    } else if let timerNode = strongSelf.timerNode {
                        strongSelf.timerNode = nil
                        timerNode.removeFromSupernode()
                    }
                    
                    strongSelf.timerNode?.frame = iconFrame.insetBy(dx: -5.0, dy: -5.0)
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.subtitleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size))
                                        
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    if item.invite == nil {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            strongSelf.addSubnode(shimmerNode)
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }
                        
                        var shapes: [ShimmerEffectNode.Shape] = []
                        
                        let titleLineWidth: CGFloat = 180.0
                        let subtitleLineWidth: CGFloat = 60.0
                        let lineDiameter: CGFloat = 10.0
                        
                        let iconFrame = strongSelf.iconBackgroundNode.frame
                        shapes.append(.circle(iconFrame))
                        
                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                        
                        let subtitleFrame = strongSelf.subtitleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: subtitleFrame.minX, y: subtitleFrame.minY + floor((subtitleFrame.height - lineDiameter) / 2.0)), width: subtitleLineWidth, diameter: lineDiameter))
                        
                        shimmerNode.update(backgroundColor: item.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: layout.contentSize)
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
}

private struct ContentParticle {
    var position: CGPoint
    var direction: CGPoint
    var velocity: CGFloat
    var alpha: CGFloat
    var lifetime: Double
    var beginTime: Double
    
    init(position: CGPoint, direction: CGPoint, velocity: CGFloat, alpha: CGFloat, lifetime: Double, beginTime: Double) {
        self.position = position
        self.direction = direction
        self.velocity = velocity
        self.alpha = alpha
        self.lifetime = lifetime
        self.beginTime = beginTime
    }
}

private final class TimerNode: ASDisplayNode {
    enum Value: Equatable {
        case timestamp(creation: Int32, deadline: Int32)
        case fraction(CGFloat)
    }
    private struct Params: Equatable {
        var color: UIColor
        var value: Value
    }
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var inHierarchyValue: Bool = false
    
    private var animator: ConstantDisplayLinkAnimator?
    private let contentNode: ASDisplayNode
    private var particles: [ContentParticle] = []
    
    private var currentParams: Params?
    
    var reachedTimeout: (() -> Void)?
    
    override init() {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.contentNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
        
        updateInHierarchy = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inHierarchyValue = value
            strongSelf.animator?.isPaused = value
        }
    }
    
    deinit {
        self.animator?.invalidate()
    }
    
    func update(color: UIColor, value: Value) {
        let params = Params(
            color: color,
            value: value
        )
        self.currentParams = params
        
        self.updateValues()
    }
    
    private func updateValues() {
        guard let params = self.currentParams else {
            return
        }

        let color = params.color

        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        var fraction: CGFloat
        switch params.value {
            case let .fraction(value):
                fraction = value
            case let .timestamp(creation, deadline):
                fraction = CGFloat(deadline - currentTimestamp) / CGFloat(deadline - creation)
        }
        fraction = max(0.0001, 1.0 - max(0.0, min(1.0, fraction)))
      
        let image: UIImage?
        
        let diameter: CGFloat = 42.0
        let inset: CGFloat = 8.0
        let lineWidth: CGFloat = 2.0

        let timestamp = CACurrentMediaTime()
        
        let center = CGPoint(x: (diameter + inset) / 2.0, y: (diameter + inset) / 2.0)
        let radius: CGFloat = (diameter - lineWidth / 2.0) / 2.0
        
        let startAngle: CGFloat = -CGFloat.pi / 2.0
        let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * fraction
        
        let sparks = fraction > 0.05 && fraction != 1.0
        if sparks {
            let v = CGPoint(x: sin(endAngle), y: -cos(endAngle))
            let c = CGPoint(x: -v.y * radius + center.x, y: v.x * radius + center.y)
            
            let dt: CGFloat = 1.0 / 60.0
            var removeIndices: [Int] = []
            for i in 0 ..< self.particles.count {
                let currentTime = timestamp - self.particles[i].beginTime
                if currentTime > self.particles[i].lifetime {
                    removeIndices.append(i)
                } else {
                    let input: CGFloat = CGFloat(currentTime / self.particles[i].lifetime)
                    let decelerated: CGFloat = (1.0 - (1.0 - input) * (1.0 - input))
                    self.particles[i].alpha = 1.0 - decelerated
                    
                    var p = self.particles[i].position
                    let d = self.particles[i].direction
                    let v = self.particles[i].velocity
                    p = CGPoint(x: p.x + d.x * v * dt, y: p.y + d.y * v * dt)
                    self.particles[i].position = p
                }
            }
            
            for i in removeIndices.reversed() {
                self.particles.remove(at: i)
            }
            
            let newParticleCount = 1
            for _ in 0 ..< newParticleCount {
                let degrees: CGFloat = CGFloat(arc4random_uniform(140)) - 40.0
                let angle: CGFloat = degrees * CGFloat.pi / 180.0
                
                let direction = CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
                let velocity = (20.0 + (CGFloat(arc4random()) / CGFloat(UINT32_MAX)) * 4.0) * 0.3
                
                let lifetime = Double(0.4 + CGFloat(arc4random_uniform(100)) * 0.01)
                
                let particle = ContentParticle(position: c, direction: direction, velocity: velocity, alpha: 1.0, lifetime: lifetime, beginTime: timestamp)
                self.particles.append(particle)
            }
        }
        
        image = generateImage(CGSize(width: diameter + inset, height: diameter + inset), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            context.addPath(path)
            context.strokePath()
            
            if sparks {
                for particle in self.particles {
                    let size: CGFloat = 2.0
                    context.setAlpha(particle.alpha)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
                }
            }
        })
        
        self.contentNode.contents = image?.cgImage
        if let image = image {
            self.contentNode.frame = CGRect(origin: CGPoint(), size: image.size)
        }
             
        if fraction <= .ulpOfOne {
            self.animator?.invalidate()
            self.animator = nil
        } else {
            if self.animator == nil {
                let animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateValues()
                })
                self.animator = animator
                animator.isPaused = self.inHierarchyValue
            }
        }
    }
}
