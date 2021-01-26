import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import SyncCore
import AccountContext
import TelegramPresentationData
import ItemListUI
import SolidRoundedButtonNode
import AnimatedAvatarSetNode

private func actionButtonImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 24.0, height: 24.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 4.0, y: 10.0), size: CGSize(width: 4.0, height: 4.0)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: CGSize(width: 4.0, height: 4.0)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 16.0, y: 10.0), size: CGSize(width: 4.0, height: 4.0)))
    })
}

public class ItemListPermanentInviteLinkItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let invite: ExportedInvitation?
    let count: Int32
    let peers: [Peer]
    let displayButton: Bool
    let displayImporters: Bool
    let buttonColor: UIColor?
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let copyAction: (() -> Void)?
    let shareAction: (() -> Void)?
    let contextAction: ((ASDisplayNode) -> Void)?
    let viewAction: (() -> Void)?
    public let tag: ItemListItemTag?
    
    public init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        invite: ExportedInvitation?,
        count: Int32,
        peers: [Peer],
        displayButton: Bool,
        displayImporters: Bool,
        buttonColor: UIColor?,
        sectionId: ItemListSectionId,
        style: ItemListStyle,
        copyAction: (() -> Void)?,
        shareAction: (() -> Void)?,
        contextAction: ((ASDisplayNode) -> Void)?,
        viewAction: (() -> Void)?,
        tag: ItemListItemTag? = nil
    ) {
        self.context = context
        self.presentationData = presentationData
        self.invite = invite
        self.count = count
        self.peers = peers
        self.displayButton = displayButton
        self.displayImporters = displayImporters
        self.buttonColor = buttonColor
        self.sectionId = sectionId
        self.style = style
        self.copyAction = copyAction
        self.shareAction = shareAction
        self.contextAction = contextAction
        self.viewAction = viewAction
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListPermanentInviteLinkItemNode()
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
            if let nodeValue = node() as? ItemListPermanentInviteLinkItemNode {
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
    
    public var selectable: Bool = false
}

public class ItemListPermanentInviteLinkItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let fieldNode: ASImageNode
    private let addressNode: TextNode
    private let fieldButtonNode: HighlightTrackingButtonNode
    private let extractedContainerNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let addressButtonNode: HighlightTrackingButtonNode
    private let addressButtonIconNode: ASImageNode
    private var shareButtonNode: SolidRoundedButtonNode?
    
    private let avatarsButtonNode: HighlightTrackingButtonNode
    private let avatarsContext: AnimatedAvatarSetContext
    private var avatarsContent: AnimatedAvatarSetContext.Content?
    private let avatarsNode: AnimatedAvatarSetNode
    private let invitedPeersNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListPermanentInviteLinkItem?
    
    override public var canBeSelected: Bool {
        return false
    }
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.fieldNode = ASImageNode()
        self.fieldNode.displaysAsynchronously = false
        self.fieldNode.displayWithoutProcessing = true
        
        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        
        self.fieldButtonNode = HighlightTrackingButtonNode()
    
        self.addressButtonNode = HighlightTrackingButtonNode()
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.isGestureEnabled = false
        self.addressButtonIconNode = ASImageNode()
        self.addressButtonIconNode.contentMode = .center
        self.addressButtonIconNode.displaysAsynchronously = false
        self.addressButtonIconNode.displayWithoutProcessing = true
        
        self.avatarsButtonNode = HighlightTrackingButtonNode()
        self.avatarsContext = AnimatedAvatarSetContext()
        self.avatarsNode = AnimatedAvatarSetNode()
        self.invitedPeersNode = TextNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.fieldNode)
        self.addSubnode(self.addressNode)
        self.addSubnode(self.fieldButtonNode)
        self.addSubnode(self.avatarsNode)
        self.addSubnode(self.invitedPeersNode)
        self.addSubnode(self.avatarsButtonNode)
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.addressButtonIconNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.addressButtonNode.addSubnode(self.containerNode)
        self.addSubnode(self.addressButtonNode)
        
        self.addSubnode(self.activateArea)
        
        self.fieldButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.addressNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.addressNode.alpha = 0.4
                } else {
                    strongSelf.addressNode.alpha = 1.0
                    strongSelf.addressNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.fieldButtonNode.addTarget(self, action: #selector(self.fieldButtonPressed), forControlEvents: .touchUpInside)
        
        self.addressButtonNode.addTarget(self, action: #selector(self.addressButtonPressed), forControlEvents: .touchUpInside)
        self.addressButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.addressButtonIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.addressButtonIconNode.alpha = 0.4
                } else {
                    strongSelf.addressButtonIconNode.alpha = 1.0
                    strongSelf.addressButtonIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.shareButtonNode?.pressed = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                item.shareAction?()
            }
        }
        self.avatarsButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.avatarsNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.invitedPeersNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.avatarsNode.alpha = 0.4
                    strongSelf.invitedPeersNode.alpha = 0.4
                } else {
                    strongSelf.avatarsNode.alpha = 1.0
                    strongSelf.invitedPeersNode.alpha = 1.0
                    strongSelf.avatarsNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.invitedPeersNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.avatarsButtonNode.addTarget(self, action: #selector(self.avatarsButtonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func fieldButtonPressed() {
        if let item = self.item {
            item.copyAction?()
        }
    }
    
    @objc private func addressButtonPressed() {
        if let item = self.item {
            item.contextAction?(self.extractedContainerNode)
        }
    }
    
    @objc private func avatarsButtonPressed() {
        if let item = self.item {
            item.viewAction?()
        }
    }
    
    public func asyncLayout() -> (_ item: ItemListPermanentInviteLinkItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        let makeInvitedPeersLayout = TextNode.asyncLayout(self.invitedPeersNode)
        
        let currentItem = self.item
        let avatarsContext = self.avatarsContext
        
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
            
            let titleColor: UIColor
            titleColor = item.presentationData.theme.list.itemInputField.primaryColor
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            let (addressLayout, addressApply) = makeAddressLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.invite.flatMap({ $0.link.replacingOccurrences(of: "https://", with: "") }) ?? "", font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 90.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let subtitle: String
            let subtitleColor: UIColor
            if item.count > 0 {
                subtitle = item.presentationData.strings.InviteLink_PeopleJoined(item.count)
                subtitleColor = item.presentationData.theme.list.itemAccentColor
            } else {
                subtitle = item.presentationData.strings.InviteLink_PeopleJoinedNone
                subtitleColor = item.presentationData.theme.list.itemSecondaryTextColor
            }
            
            let (invitedPeersLayout, invitedPeersApply) = makeInvitedPeersLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: subtitle, font: titleFont, textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let avatarsContent = avatarsContext.update(peers: item.peers, animated: false)
            
            let verticalInset: CGFloat = 16.0
            let fieldHeight: CGFloat = 52.0
            let fieldSpacing: CGFloat = 16.0
            let buttonHeight: CGFloat = 50.0
            
            var height = verticalInset * 2.0 + fieldHeight + fieldSpacing + buttonHeight + 54.0
            
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = .clear
                insets = UIEdgeInsets()
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                insets = itemListNeighborsGroupedInsets(neighbors)
            }
            
            if !item.displayImporters {
                height -= 57.0
            }
            if !item.displayButton {
                height -= 63.0
            }
            
            contentSize = CGSize(width: params.width, height: height)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.avatarsContent = avatarsContent
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
//                    strongSelf.activateArea.accessibilityLabel = item.title
//                    strongSelf.activateArea.accessibilityValue = item.label
                    strongSelf.activateArea.accessibilityTraits = []
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.fieldNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: item.presentationData.theme.list.itemInputField.backgroundColor)
                        strongSelf.addressButtonIconNode.image = actionButtonImage(color: item.presentationData.theme.list.itemInputField.controlColor)
                    }
                    
                    let _ = addressApply()
                    let _ = invitedPeersApply()
                    
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
                    
                    let fieldFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: CGSize(width: params.width - leftInset - rightInset, height: fieldHeight))
                    strongSelf.fieldNode.frame = fieldFrame
                    strongSelf.fieldButtonNode.frame = fieldFrame
                    
                    strongSelf.addressNode.frame = CGRect(origin: CGPoint(x: fieldFrame.minX + floorToScreenPixels((fieldFrame.width - addressLayout.size.width) / 2.0), y: fieldFrame.minY + floorToScreenPixels((fieldFrame.height - addressLayout.size.height) / 2.0) + 1.0), size: addressLayout.size)
                    
                    strongSelf.addressButtonNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - 38.0 - 14.0, y: verticalInset), size: CGSize(width: 52.0, height: 52.0))
                    strongSelf.extractedContainerNode.frame = strongSelf.addressButtonNode.bounds
                    strongSelf.extractedContainerNode.contentRect = strongSelf.addressButtonNode.bounds
                    strongSelf.addressButtonIconNode.frame = strongSelf.addressButtonNode.bounds
                                        
                    let shareButtonNode: SolidRoundedButtonNode
                    if let currentShareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode = currentShareButtonNode
                    } else {
                        let buttonTheme: SolidRoundedButtonTheme
                        if let buttonColor = item.buttonColor {
                            buttonTheme = SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor)
                        } else {
                            buttonTheme = SolidRoundedButtonTheme(theme: item.presentationData.theme)
                        }
                        shareButtonNode = SolidRoundedButtonNode(theme: buttonTheme, height: 50.0, cornerRadius: 10.0)
                        shareButtonNode.title = item.presentationData.strings.InviteLink_Share
                        shareButtonNode.pressed = {
                            item.shareAction?()
                        }
                        strongSelf.addSubnode(shareButtonNode)
                        strongSelf.shareButtonNode = shareButtonNode
                    }
                    
                    let buttonWidth = contentSize.width - leftInset - rightInset
                    let _ = shareButtonNode.updateLayout(width: buttonWidth, transition: .immediate)
                    shareButtonNode.frame = CGRect(x: leftInset, y: verticalInset + fieldHeight + fieldSpacing, width: buttonWidth, height: buttonHeight)
                    
                    var totalWidth = invitedPeersLayout.size.width
                    var leftOrigin: CGFloat = floorToScreenPixels((params.width - invitedPeersLayout.size.width) / 2.0)
                    let avatarSpacing: CGFloat = 21.0
                    if let avatarsContent = strongSelf.avatarsContent {
                        let avatarsSize = strongSelf.avatarsNode.update(context: item.context, content: avatarsContent, itemSize: CGSize(width: 32.0, height: 32.0), animated: true, synchronousLoad: true)
                        
                        if !avatarsSize.width.isZero {
                            totalWidth += avatarsSize.width + avatarSpacing
                        }
                        
                        let avatarsNodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - totalWidth) / 2.0), y: fieldFrame.maxY + 87.0), size: avatarsSize)
                        strongSelf.avatarsNode.frame = avatarsNodeFrame
                        if !avatarsSize.width.isZero {
                            leftOrigin = avatarsNodeFrame.maxX + avatarSpacing
                        }
                    }
                    
                    strongSelf.invitedPeersNode.frame = CGRect(origin: CGPoint(x: leftOrigin, y: fieldFrame.maxY + 92.0), size: invitedPeersLayout.size)
                    
                    strongSelf.avatarsButtonNode.frame = CGRect(x: floorToScreenPixels((params.width - totalWidth) / 2.0), y: fieldFrame.maxY + 87.0, width: totalWidth, height: 32.0)
                    strongSelf.avatarsButtonNode.isUserInteractionEnabled = !item.peers.isEmpty
                    
                    strongSelf.shareButtonNode?.isHidden = !item.displayButton
                    strongSelf.avatarsButtonNode.isHidden = !item.displayImporters
                    strongSelf.avatarsNode.isHidden = !item.displayImporters
                    strongSelf.invitedPeersNode.isHidden = !item.displayImporters
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
