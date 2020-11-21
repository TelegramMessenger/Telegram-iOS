import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import PeerPresenceStatusManager
import ContextUI
import AccountContext
import LegacyComponents
import AnimationUI

public final class VoiceChatParticipantItem: ListViewItem {
    public enum ParticipantText {
        public enum TextColor {
            case generic
            case accent
            case constructive
        }
        
        case presence
        case text(String, TextColor)
        case none
    }
    
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: Peer
    let presence: PeerPresence?
    let text: ParticipantText
    let enabled: Bool
    let action: (() -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, presence: PeerPresence?, text: ParticipantText, enabled: Bool, action: (() -> Void)?, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.presence = presence
        self.text = text
        self.enabled = enabled
        self.action = action
        self.contextAction = contextAction
    }
    
    public var selectable: Bool = false
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatParticipantItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, previousItem == nil, nextItem == nil)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (node.avatarNode.ready, { _ in apply(synchronousLoads, false) })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? VoiceChatParticipantItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, previousItem == nil, nextItem == nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let avatarFont = avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0))

public class VoiceChatParticipantItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private var audioLevelView: VoiceBlobView?
    fileprivate let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let animationNode: AnimationNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (VoiceChatParticipantItem, ListViewItemLayoutParams, Bool, Bool)?
        
    override public var canBeSelected: Bool {
        if let item = self.layoutParams?.0, item.action != nil {
            return true
        } else {
            return false
        }
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.animationNode = AnimationNode(animation: "anim_voicemute", colors: [:], scale: 0.3333)
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.statusNode)
        self.offsetContainerNode.addSubnode(self.animationNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3)
                apply(false, true)
            }
        })
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let contextAction = item.contextAction else {
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
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.itemBlocksBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
           
            transition.updateSublayerTransformOffset(layer: strongSelf.animationNode.layer, offset: CGPoint(x: isExtracted ? -24.0 : 0.0, y: 0.0))
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
        
    public func asyncLayout() -> (_ item: VoiceChatParticipantItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, first, last in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let statusFontSize: CGFloat = floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0)
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let statusFont = Font.regular(statusFontSize)
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            let rightInset: CGFloat = params.rightInset
        
            let titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            let currentBoldFont: UIFont = titleFont
            
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    switch item.nameDisplayOrder {
                    case .firstLast:
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                    case .lastFirst:
                        string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                    }
                    titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: currentBoldFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: currentBoldFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: currentBoldFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: currentBoldFont, textColor: titleColor)
            }
            
            switch item.text {
            case .presence:
                if let user = item.peer as? TelegramUser, let botInfo = user.botInfo {
                    let botStatus: String
                    if botInfo.flags.contains(.hasAccessToChatHistory) {
                        botStatus = item.presentationData.strings.Bot_GroupStatusReadsHistory
                    } else {
                        botStatus = item.presentationData.strings.Bot_GroupStatusDoesNotReadHistory
                    }
                    statusAttributedString = NSAttributedString(string: botStatus, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                } else if let presence = item.presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    let (string, activity) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                    statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
                } else {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.LastSeen_Offline, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                }
            case let .text(text, textColor):
                let textColorValue: UIColor
                switch textColor {
                case .generic:
                    textColorValue = item.presentationData.theme.list.itemSecondaryTextColor
                case .accent:
                    textColorValue = item.presentationData.theme.list.itemAccentColor
                case .constructive:
                    textColorValue = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                }
                statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: textColorValue)
            case .none:
                break
            }

            let leftInset: CGFloat = 65.0 + params.leftInset
            let verticalInset: CGFloat = 8.0
            let verticalOffset: CGFloat = 0.0
            let avatarSize: CGFloat = 40.0
                              
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = UIEdgeInsets()
    
            let titleSpacing: CGFloat = statusLayout.size.height == 0.0 ? 0.0 : 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.size.height
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            var animateStatusTransition = false
            if let currentItem = currentItem {
                if case .presence = currentItem.text, case .text = item.text {
                    animateStatusTransition = true
                } else if case let .text(_, currentColor) = currentItem.text, case let .text(_, newColor) = item.text, currentColor != newColor {
                    animateStatusTransition = true
                }
            }
            
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, first, last)
                    
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
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                    
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    var combinedValueString = ""
                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
                        combinedValueString.append(statusString)
                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                    
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
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.addSubnode(currentDisabledOverlayNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                        }
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if animateStatusTransition {
                        if let snapshotView = strongSelf.statusNode.view.snapshotContentTree() {
                            strongSelf.statusNode.view.insertSubview(snapshotView, belowSubview: strongSelf.statusNode.view)

                            snapshotView.frame = strongSelf.statusNode.frame
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -7.0), duration: 0.2, removeOnCompletion: false, additive: true)
                            
                            strongSelf.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            strongSelf.statusNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 7.0), to: CGPoint(), duration: 0.2, additive: true)
                        }
                    }
                    
                    let _ = titleApply()
                    let _ = statusApply()
                                        
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }

                    strongSelf.topStripeNode.isHidden = first
                    strongSelf.bottomStripeNode.isHidden = last
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height + -separatorHeight), size: CGSize(width: layoutSize.width - leftInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + verticalOffset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: floorToScreenPixels((layout.contentSize.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize)))
                    
                    var overrideImage: AvatarNodeImageOverride?
                    if item.peer.isDeleted {
                        overrideImage = .deletedIcon
                    }
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: item.peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    if var size = strongSelf.animationNode.preferredSize() {
                        size = CGSize(width: ceil(size.width), height: ceil(size.height))
                        strongSelf.animationNode.frame = CGRect(x: params.width - size.width - 12.0, y: floor((layout.contentSize.height - size.height) / 2.0) + 1.0, width: size.width, height: size.height)
//                        animationNode.play()
                    }
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    strongSelf.updateIsHighlighted(transition: transition)
                }
            })
        }
    }
    
    var isHighlighted = false
    
    var reallyHighlighted: Bool {
        var reallyHighlighted = self.isHighlighted
        return reallyHighlighted
    }
    
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        if self.reallyHighlighted {
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
                if transition.isAnimated {
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
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
             
        self.isHighlighted = highlighted
            
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    
    override public func header() -> ListViewItemHeader? {
        return nil
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
    }
}


private class VoiceBlobView: UIView {
    private let smallBlob: BlobView
    private let mediumBlob: BlobView
    private let bigBlob: BlobView
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0
    private var presentationAudioLevel: CGFloat = 0
    
    private(set) var isAnimating = false
    
    typealias BlobRange = (min: CGFloat, max: CGFloat)
    
    init(
        frame: CGRect,
        maxLevel: CGFloat,
        smallBlobRange: BlobRange,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
        self.maxLevel = maxLevel
        
        self.smallBlob = BlobView(
            pointsCount: 8,
            minRandomness: 0.1,
            maxRandomness: 0.5,
            minSpeed: 0.2,
            maxSpeed: 0.6,
            minScale: smallBlobRange.min,
            maxScale: smallBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: true
        )
        self.mediumBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.5,
            maxSpeed: 7,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        self.bigBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.5,
            maxSpeed: 7,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        
        super.init(frame: frame)
        
        addSubview(bigBlob)
        addSubview(mediumBlob)
        addSubview(smallBlob)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.smallBlob.level = strongSelf.presentationAudioLevel
            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        smallBlob.setColor(color)
        mediumBlob.setColor(color.withAlphaComponent(0.3))
        bigBlob.setColor(color.withAlphaComponent(0.15))
    }
    
    func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        smallBlob.updateSpeedLevel(to: normalizedLevel)
        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
    }
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        mediumBlob.layer.animateScale(from: 0.5, to: 1, duration: 0.15, removeOnCompletion: false)
        bigBlob.layer.animateScale(from: 0.5, to: 1, duration: 0.15, removeOnCompletion: false)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        
        mediumBlob.layer.animateScale(from: 1.0, to: 0.5, duration: 0.15, removeOnCompletion: false)
        bigBlob.layer.animateScale(from: 1.0, to: 0.5, duration: 0.15, removeOnCompletion: false)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        if isAnimating {
            if smallBlob.frame.size != .zero {
                smallBlob.startAnimating()
                mediumBlob.startAnimating()
                bigBlob.startAnimating()
            }
        } else {
            smallBlob.stopAnimating()
            mediumBlob.stopAnimating()
            bigBlob.stopAnimating()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        smallBlob.frame = bounds
        mediumBlob.frame = bounds
        bigBlob.frame = bounds
        
        updateBlobsState()
    }
}

private class BlobView: UIView {
    
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minScale: CGFloat
    let maxScale: CGFloat
    let scaleSpeed: CGFloat
    
    var scaleLevelsToBalance = [CGFloat]()
    
    // If true ignores randomness and pointsCount
    let isCircle: Bool
    
    var level: CGFloat = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = minScale + (maxScale - minScale) * level
            shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
            CATransaction.commit()
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var scaleLevel: CGFloat = 0
    
    private var lastSpeedLevel: CGFloat = 0
    private var lastScaleLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
    
    private var transition: CGFloat = 0 {
        didSet {
            guard let currentPoints = currentPoints else { return }
            
            shapeLayer.path = UIBezierPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness).cgPath
        }
    }
    
    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }
        
        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(
                x: fromPoint.x + (toPoint.x - fromPoint.x) * transition,
                y: fromPoint.y + (toPoint.y - fromPoint.y) * transition
            )
        }
    }
    
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat,
        scaleSpeed: CGFloat,
        isCircle: Bool
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale
        self.scaleSpeed = scaleSpeed
        self.isCircle = isCircle
        
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2
        
        super.init(frame: .zero)
        
        layer.addSublayer(shapeLayer)
        
        shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        shapeLayer.fillColor = color.cgColor
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)
        
        if abs(lastSpeedLevel - newSpeedLevel) > 0.5 {
            animateToNewShape()
        }
    }
    
    func startAnimating() {
        animateToNewShape()
    }
    
    func stopAnimating() {
        fromPoints = currentPoints
        toPoints = nil
        pop_removeAnimation(forKey: "blob")
    }
    
    private func animateToNewShape() {
        guard !isCircle else { return }
        
        if pop_animation(forKey: "blob") != nil {
            fromPoints = currentPoints
            toPoints = nil
            pop_removeAnimation(forKey: "blob")
        }
        
        if fromPoints == nil {
            fromPoints = generateNextBlob(for: bounds.size)
        }
        if toPoints == nil {
            toPoints = generateNextBlob(for: bounds.size)
        }
        
        let animation = POPBasicAnimation()
        animation.property = POPAnimatableProperty.property(withName: "blob.transition", initializer: { property in
            property?.readBlock = { blobView, values in
                guard let blobView = blobView as? BlobView, let values = values else { return }
                
                values.pointee = blobView.transition
            }
            property?.writeBlock = { blobView, values in
                guard let blobView = blobView as? BlobView, let values = values else { return }
                
                blobView.transition = values.pointee
            }
        })  as? POPAnimatableProperty
        animation.completionBlock = { [weak self] animation, finished in
            if finished {
                self?.fromPoints = self?.currentPoints
                self?.toPoints = nil
                self?.animateToNewShape()
            }
        }
        animation.duration = CFTimeInterval(1 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fromValue = 0
        animation.toValue = 1
        pop_add(animation, forKey: "blob")
        
        lastSpeedLevel = speedLevel
        speedLevel = 0
    }
    
    // MARK: Helpers
    
    private func generateNextBlob(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return blob(pointsCount: pointsCount, randomness: randomness)
            .map {
                return CGPoint(
                    x: $0.x * CGFloat(size.width),
                    y: $0.y * CGFloat(size.height)
                )
            }
    }
    
    func blob(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        
        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1 / (1 + randomness / 10)
        
        let startAngle = angle * CGFloat(arc4random_uniform(100)) / CGFloat(100)
        
        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let angleRandomness: CGFloat = angle * 0.1
            let randAngle = angle + angle * ((angleRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - angleRandomness * 0.5)
            let pointX = sin(startAngle + CGFloat(i) * randAngle)
            let pointY = cos(startAngle + CGFloat(i) * randAngle)
            return CGPoint(
                x: pointX * randPointOffset,
                y: pointY * randPointOffset
            )
        }
        
        return points
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        if isCircle {
            let halfWidth = bounds.width * 0.5
            shapeLayer.path = UIBezierPath(
                roundedRect: bounds.offsetBy(dx: -halfWidth, dy: -halfWidth),
                cornerRadius: halfWidth
            ).cgPath
        }
        CATransaction.commit()
    }
}

private extension UIBezierPath {
    
    static func smoothCurve(
        through points: [CGPoint],
        length: CGFloat,
        smoothness: CGFloat
    ) -> UIBezierPath {
        var smoothPoints = [SmoothPoint]()
        for index in (0 ..< points.count) {
            let prevIndex = index - 1
            let prev = points[prevIndex >= 0 ? prevIndex : points.count + prevIndex]
            let curr = points[index]
            let next = points[(index + 1) % points.count]
            
            let angle: CGFloat = {
                let dx = next.x - prev.x
                let dy = -next.y + prev.y
                let angle = atan2(dy, dx)
                if angle < 0 {
                    return abs(angle)
                } else {
                    return 2 * .pi - angle
                }
            }()
            
            smoothPoints.append(
                SmoothPoint(
                    point: curr,
                    inAngle: angle + .pi,
                    inLength: smoothness * distance(from: curr, to: prev),
                    outAngle: angle,
                    outLength: smoothness * distance(from: curr, to: next)
                )
            )
        }
        
        let resultPath = UIBezierPath()
        resultPath.move(to: smoothPoints[0].point)
        for index in (0 ..< smoothPoints.count) {
            let curr = smoothPoints[index]
            let next = smoothPoints[(index + 1) % points.count]
            let currSmoothOut = curr.smoothOut()
            let nextSmoothIn = next.smoothIn()
            resultPath.addCurve(to: next.point, controlPoint1: currSmoothOut, controlPoint2: nextSmoothIn)
        }
        resultPath.close()
        return resultPath
    }
    
    static private func distance(from fromPoint: CGPoint, to toPoint: CGPoint) -> CGFloat {
        return sqrt((fromPoint.x - toPoint.x) * (fromPoint.x - toPoint.x) + (fromPoint.y - toPoint.y) * (fromPoint.y - toPoint.y))
    }
    
    struct SmoothPoint {
        
        let point: CGPoint
        
        let inAngle: CGFloat
        let inLength: CGFloat
        
        let outAngle: CGFloat
        let outLength: CGFloat
        
        func smoothIn() -> CGPoint {
            return smooth(angle: inAngle, length: inLength)
        }
        
        func smoothOut() -> CGPoint {
            return smooth(angle: outAngle, length: outLength)
        }
        
        private func smooth(angle: CGFloat, length: CGFloat) -> CGPoint {
            return CGPoint(
                x: point.x + length * cos(angle),
                y: point.y + length * sin(angle)
            )
        }
    }
}

