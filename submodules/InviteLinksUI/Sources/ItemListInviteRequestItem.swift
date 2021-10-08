import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import ShimmerEffect
import LocalizedPeerData
import AvatarNode
import AccountContext
import SolidRoundedButtonNode

public class ItemListInviteRequestItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let importer: PeerInvitationImportersState.Importer?
    let isGroup: Bool
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let tapAction: (() -> Void)?
    let addAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    public let tag: ItemListItemTag?
    
    public init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        importer: PeerInvitationImportersState.Importer?,
        isGroup: Bool,
        sectionId: ItemListSectionId,
        style: ItemListStyle,
        tapAction: (() -> Void)?,
        addAction: (() -> Void)?,
        dismissAction: (() -> Void)?,
        contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?,
        tag: ItemListItemTag? = nil
    ) {
        self.context = context
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.importer = importer
        self.isGroup = isGroup
        self.sectionId = sectionId
        self.style = style
        self.tapAction = tapAction
        self.addAction = addAction
        self.dismissAction = dismissAction
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
            let node = ItemListInviteRequestItemNode()
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
            if let nodeValue = node() as? ItemListInviteRequestItemNode {
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
        self.tapAction?()
    }
}

private let avatarFont = avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0))

public class ItemListInviteRequestItemNode: ListViewItemNode, ItemListItemNode {
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
    
    fileprivate let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let dateNode: TextNode
    private let addButton: SolidRoundedButtonNode
    private let dismissButton: HighlightableButtonNode
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var layoutParams: (ItemListInviteRequestItem, ListViewItemLayoutParams, ItemListNeighbors, Bool, Bool)?
    
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
    
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
    
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.contentMode = .left
        self.subtitleNode.contentsScale = UIScreen.main.scale
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.contentMode = .left
        self.dateNode.contentsScale = UIScreen.main.scale
        
        self.addButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
        self.dismissButton = HighlightableButtonNode()
            
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.subtitleNode)
        self.offsetContainerNode.addSubnode(self.dateNode)
        self.offsetContainerNode.addSubnode(self.addButton)
        self.offsetContainerNode.addSubnode(self.dismissButton)
        
        self.addButton.pressed = { [weak self] in
            if let (item, _, _, _, _) = self?.layoutParams {
                item.addAction?()
            }
        }
        self.dismissButton.addTarget(self, action: #selector(self.dismissPressed), forControlEvents: .touchUpInside)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let _ = item.importer, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture)
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
    
    public func asyncLayout() -> (_ item: ItemListInviteRequestItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors, _ firstWithHeader: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        
        let currentItem = self.layoutParams?.0
                
        return { item, params, neighbors, firstWithHeader, last in
            var updatedTheme: PresentationTheme?
        
            let titleFont = Font.semibold(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
                        
            var titleText: String
            var subtitleText: String
            var dateText: String
          
            if let importer = item.importer, let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                titleText = peer.displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder)
                subtitleText = importer.about ?? ""
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: importer.date, relativeTo: timestamp, dateTimeFormat: item.dateTimeFormat)
            } else {
                titleText = " "
                subtitleText = " "
                dateText = " "
            }
            
            let titleAttributedString = NSAttributedString(string: titleText, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let subtitleAttributedString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            let dateAttributedString = NSAttributedString(string: dateText, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 62.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let verticalInset: CGFloat = 9.0
           
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            var rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + 41.0
            if !subtitleLayout.size.height.isZero {
                rawHeight += subtitleLayout.size.height + 5.0
            }
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
                    insets = itemListNeighborsGroupedInsets(neighbors)
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
                     
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                                        
                    let transition = ContainedViewLayoutTransition.immediate
                                        
                    let _ = titleApply()
                    let _ = subtitleApply()
                    let _ = dateApply()
                    
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
                    
                    let avatarSize: CGSize = CGSize(width: 40.0, height: 40.0)
                    let avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 9.0, y: verticalInset + 2.0), size: avatarSize)
                    strongSelf.avatarNode.frame = avatarFrame
                    
                    if let importer = item.importer, let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: nil, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: false)
                    }
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.subtitleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size))
                    transition.updateFrame(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: params.width - rightInset - dateLayout.size.width, y: verticalInset + 2.0), size: dateLayout.size))
                                        
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.addButton.title = item.isGroup ? item.presentationData.strings.MemberRequests_AddToGroup : item.presentationData.strings.MemberRequests_AddToChannel
                    if let _ = updatedTheme {
                        strongSelf.addButton.updateTheme(SolidRoundedButtonTheme(theme: item.presentationData.theme))
                    }
                    strongSelf.dismissButton.setTitle(item.presentationData.strings.MemberRequests_Dismiss, with: Font.bold(15.0), with: item.presentationData.theme.list.itemAccentColor, for: .normal)
                    
                    let addHeight = strongSelf.addButton.updateLayout(width: 138.0, transition: .immediate)
                    strongSelf.addButton.frame = CGRect(x: leftInset, y: contentSize.height - addHeight - 12.0, width: 138.0, height: addHeight)
                    
                    let dismissSize = strongSelf.dismissButton.measure(layout.size)
                    strongSelf.dismissButton.frame = CGRect(origin: CGPoint(x: leftInset + 138.0 + 24.0, y: verticalInset + contentSize.height - addHeight - 14.0), size: dismissSize)
                    
                    if item.importer == nil {
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
                        
                        let iconFrame = strongSelf.avatarNode.frame
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
    
    @objc private func dismissPressed() {
        if let (item, _, _, _, _) = self.layoutParams {
            item.dismissAction?()
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
