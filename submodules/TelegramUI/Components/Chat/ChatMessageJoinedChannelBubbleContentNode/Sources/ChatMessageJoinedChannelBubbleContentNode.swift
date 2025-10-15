import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import UrlEscaping
import TelegramStringFormatting
import WallpaperBackgroundNode
import ReactionSelectionNode
import ChatControllerInteraction
import ShimmerEffect
import Markdown
import ChatMessageBubbleContentNode
import ChatMessagePollBubbleContentNode
import ChatMessageItemCommon
import RoundedRectWithTailPath
import AvatarNode
import MultilineTextComponent
import BundleIconComponent
import ChatMessageBackground
import ContextUI
import UndoUI
import MergedAvatarsNode

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, accountPeerId: EnginePeer.Id) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: false, forForumOverview: false)
}

private func generateCloseButtonImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
                
        context.setAlpha(color.alpha)
        context.setBlendMode(.copy)
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(color.withAlphaComponent(1.0).cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

public class ChatMessageJoinedChannelBubbleContentNode: ChatMessageBubbleContentNode {
    private let labelNode: TextNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private let backgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let panelNode: ASDisplayNode
    private let panelBackgroundNode: MessageBackgroundNode
    private let titleNode: TextNode
    private let closeButtonNode: HighlightTrackingButtonNode
    private let closeIconNode: ASImageNode
    private let panelListView = ComponentView<Empty>()
    
    private var cachedMaskBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?
                    
    private var currentMaskSize: CGSize?
    private var panelMaskLayer: CAShapeLayer?
    
    private var isExpanded: Bool?
    
    required public init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.backgroundMaskNode = ASImageNode()
        
        self.panelNode = ASDisplayNode()
        self.panelBackgroundNode = MessageBackgroundNode()

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.closeButtonNode = HighlightTrackingButtonNode()
        
        self.closeIconNode = ASImageNode()
        self.closeIconNode.displaysAsynchronously = false
        self.closeIconNode.isUserInteractionEnabled = false
        
        super.init()

        self.addSubnode(self.labelNode)
        
        self.panelNode.anchorPoint = CGPoint(x: 0.5, y: -0.1)
        
        self.addSubnode(self.panelNode)
        self.panelNode.addSubnode(self.panelBackgroundNode)
        self.panelNode.addSubnode(self.titleNode)
        
        self.panelNode.addSubnode(self.closeIconNode)
        self.panelNode.addSubnode(self.closeButtonNode)
        
        self.closeButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.closeIconNode.layer.removeAnimation(forKey: "opacity")
                self.closeIconNode.alpha = 0.4
            } else {
                self.closeIconNode.alpha = 1.0
                self.closeIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.closeButtonNode.addTarget(self, action: #selector(self.closeButtonPressed), forControlEvents: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.panelMaskLayer = CAShapeLayer()
    }
    
    @objc private func pressed() {
        guard let item = self.item else {
            return
        }
        if let recommendedChannels = item.associatedData.recommendedChannels {
            let _ = item.context.engine.peers.toggleRecommendedChannelsHidden(peerId: item.message.id.peerId, hidden: !recommendedChannels.isHidden).startStandalone()
        } else {
            let _ = item.context.engine.peers.requestRecommendedChannels(peerId: item.message.id.peerId).startStandalone()
        }
    }
    
    @objc private func closeButtonPressed() {
        guard let item = self.item else {
            return
        }
        let _ = item.context.engine.peers.toggleRecommendedChannelsHidden(peerId: item.message.id.peerId, hidden: true).startStandalone()
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)

        let cachedMaskBackgroundImage = self.cachedMaskBackgroundImage

        return { item, layoutConstants, _, _, constrainedSize, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            let unboundWidth: CGFloat = constrainedSize.width - 10.0 * 2.0
            return (contentProperties, nil, unboundWidth, { constrainedSize, position in
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, message: EngineMessage(item.message), accountPeerId: item.context.account.peerId)
            
                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_SimilarChannels, font: Font.semibold(15.0), textColor: item.presentationData.theme.theme.chat.message.incoming.primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                                
                var labelRects = labelLayout.linesRects()
                if labelRects.count > 1 {
                    let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                    for i in 0 ..< sortedIndices.count {
                        let index = sortedIndices[i]
                        for j in -1 ... 1 {
                            if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                                if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                                    labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                                    labelRects[index].size.width = labelRects[index + j].size.width
                                }
                            }
                        }
                    }
                }
                for i in 0 ..< labelRects.count {
                    labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
                    labelRects[i].size.height = 20.0
                    labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
                }

                let backgroundMaskImage: (CGPoint, UIImage)?
                var backgroundMaskUpdated = false
                if let (currentOffset, currentImage, currentRects) = cachedMaskBackgroundImage, currentRects == labelRects {
                    backgroundMaskImage = (currentOffset, currentImage)
                } else {
                    backgroundMaskImage = LinkHighlightingNode.generateImage(color: .black, inset: 0.0, innerRadius: 10.0, outerRadius: 10.0, rects: labelRects, useModernPathCalculation: false)
                    backgroundMaskUpdated = true
                }
                
                let isExpanded: Bool
                if let recommendedChannels = item.associatedData.recommendedChannels, !recommendedChannels.channels.isEmpty && !recommendedChannels.isHidden {
                    isExpanded = true
                } else {
                    isExpanded = false
                }
            
                let spacing: CGFloat = 17.0
                let margin: CGFloat = 4.0
                var contentSize = CGSize(width: constrainedSize.width, height: labelLayout.size.height)
                if isExpanded {
                    contentSize.height += spacing + 140.0 + margin
                } else {
                    contentSize.height += margin
                }
                
                return (contentSize.width, { boundingWidth in
                    return (contentSize, { [weak self] animation, synchronousLoads, info in
                        if let strongSelf = self {
                            let themeUpdated = strongSelf.item?.presentationData.theme !== item.presentationData.theme
                            strongSelf.item = item
                            strongSelf.isExpanded = isExpanded
                            
                            if !item.controllerInteraction.recommendedChannelsOpenUp {
                                info?.setInvertOffsetDirection()
                            }
                                                        
                            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: labelLayout.size.height + spacing - 14.0), size: CGSize(width: constrainedSize.width, height: 140.0))
                            
                            strongSelf.panelNode.position = CGPoint(x: panelFrame.midX, y: panelFrame.minY)
                            strongSelf.panelNode.bounds = CGRect(origin: .zero, size: panelFrame.size)
                            
                            let panelInnerSize = CGSize(width: panelFrame.width + 8.0, height: panelFrame.height + 10.0)
                            if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode {
                                let graphics = PresentationResourcesChat.principalGraphics(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                                strongSelf.panelBackgroundNode.update(size: panelInnerSize, theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, graphics: graphics, wallpaperBackgroundNode: backgroundNode, transition: .immediate)
                            }
                            strongSelf.panelBackgroundNode.frame = CGRect(origin: CGPoint(x: -7.0, y: -8.0), size: panelInnerSize)

                            if strongSelf.panelBackgroundNode.layer.mask == nil {
                                strongSelf.panelBackgroundNode.layer.mask = strongSelf.panelMaskLayer
                            }
                            strongSelf.panelMaskLayer?.frame = CGRect(origin: .zero, size: panelInnerSize)
                            if strongSelf.panelMaskLayer?.path == nil {
                                let path = generateRoundedRectWithTailPath(rectSize: CGSize(width: panelFrame.width, height: panelFrame.height), cornerRadius: 16.0, tailSize: CGSize(width: 16.0, height: 6.0), tailRadius: 2.0, tailPosition: 0.5, transformTail: false)
                                path.apply(CGAffineTransform(translationX: 7.0, y: 2.0))
                                strongSelf.panelMaskLayer?.path = path.cgPath
                            }
                            
                            if themeUpdated {
                                strongSelf.closeIconNode.image = generateCloseButtonImage(color: item.presentationData.theme.theme.chat.message.incoming.secondaryTextColor)
                            }
                                                                                                                
                            let _ = labelApply()
                            let _ = titleApply()
                            
                            let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentSize.width - labelLayout.size.width) / 2.0), y: 2.0), size: labelLayout.size)
                            strongSelf.labelNode.frame = labelFrame
                            
                            let titleFrame = CGRect(origin: CGPoint(x: 16.0, y: 11.0), size: titleLayout.size)
                            strongSelf.titleNode.frame = titleFrame
                            
                            if let icon = strongSelf.closeIconNode.image {
                                let closeFrame = CGRect(origin: CGPoint(x: panelFrame.width - 5.0 - icon.size.width, y: 5.0), size: icon.size)
                                strongSelf.closeIconNode.frame = closeFrame
                                strongSelf.closeButtonNode.frame = closeFrame.insetBy(dx: -4.0, dy: -4.0)
                            }
                            
                            if isExpanded {
                                animation.animator.updateAlpha(layer: strongSelf.panelNode.layer, alpha: 1.0, completion: nil)
                                animation.animator.updateScale(layer: strongSelf.panelNode.layer, scale: 1.0, completion: nil)
                            } else {
                                animation.animator.updateAlpha(layer: strongSelf.panelNode.layer, alpha: 0.0, completion: nil)
                                animation.animator.updateScale(layer: strongSelf.panelNode.layer, scale: 0.1, completion: nil)
                            }
                            
                            let baseBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                            if let (offset, image) = backgroundMaskImage {
                                if strongSelf.backgroundNode == nil {
                                    if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                        strongSelf.backgroundNode = backgroundNode
                                        strongSelf.insertSubnode(backgroundNode, at: 0)
                                        
                                        backgroundNode.view.addGestureRecognizer(UITapGestureRecognizer(target: strongSelf, action: #selector(strongSelf.pressed)))
                                    }
                                }

                                if backgroundMaskUpdated, let backgroundNode = strongSelf.backgroundNode {
                                    if labelRects.count == 1 {
                                        backgroundNode.clipsToBounds = true
                                        backgroundNode.cornerRadius = labelRects[0].height / 2.0
                                        backgroundNode.view.mask = nil
                                    } else {
                                        backgroundNode.clipsToBounds = false
                                        backgroundNode.cornerRadius = 0.0
                                        backgroundNode.view.mask = strongSelf.backgroundMaskNode.view
                                    }
                                }

                                if let backgroundNode = strongSelf.backgroundNode {
                                    backgroundNode.frame = CGRect(origin: CGPoint(x: baseBackgroundFrame.minX + offset.x, y: baseBackgroundFrame.minY + offset.y), size: image.size)
                                }
                                strongSelf.backgroundMaskNode.image = image
                                strongSelf.backgroundMaskNode.frame = CGRect(origin: CGPoint(), size: image.size)

                                strongSelf.cachedMaskBackgroundImage = (offset, image, labelRects)
                            }
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
                            }
                            
                            strongSelf.updateList()
                        }
                    })
                })
            })
        }
    }
    
    private func updateList() {
        guard let item = self.item, let recommendedChannels = item.associatedData.recommendedChannels else {
            return
        }
        let listSize = self.panelListView.update(
            transition: .immediate,
            component: AnyComponent(
                ChannelListPanelComponent(
                    context: item.context,
                    theme: item.presentationData.theme.theme,
                    strings: item.presentationData.strings,
                    peers: recommendedChannels,
                    action: { peer in
                        if let peer {
                            var jsonString: String = "{"
                            jsonString += "\"ref_channel_id\": \"\(item.message.id.peerId.id._internalGetInt64Value())\","
                            jsonString += "\"open_channel_id\": \"\(peer.id.id._internalGetInt64Value())\""
                            jsonString += "}"
                            
                            if let data = jsonString.data(using: .utf8), let json = JSON(data: data) {
                                addAppLogEvent(postbox: item.context.account.postbox, type: "channels.open_recommended_channel", data: json)
                            }
                            item.controllerInteraction.openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                        } else {
                            let context = item.context
                            let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
                            let controller = UndoOverlayController(
                                presentationData: presentationData,
                                content: .premiumPaywall(title: nil, text: item.presentationData.strings.Chat_ChannelRecommendation_PremiumTooltip, customUndoText: nil, timeout: nil, linkAction: nil),
                                elevatedLayout: false,
                                action: { [weak self] action in
                                    if case .info = action {
                                        if let self, let item = self.item {
                                            let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: false, dismissed: nil)
                                            item.controllerInteraction.navigationController()?.pushViewController(controller)
                                        }
                                    }
                                    return true
                                }
                            )
                            item.controllerInteraction.presentControllerInCurrent(controller, nil)
                            HapticFeedback().impact(.light)
                        }
                    },
                    openMore: { [weak self] in
                        guard let item = self?.item else {
                            return
                        }
                        let _ = (item.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: item.message.id.peerId))
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                            if let peer = peer {
                                self?.item?.controllerInteraction.openPeer(peer, .info(ChatControllerInteractionNavigateToPeer.InfoParams(switchToRecommendedChannels: true)), nil, .default)
                            }
                        })
                    },
                    contextAction: { [weak self] peer, sourceView, gesture in
                        if let item = self?.item {
                            item.controllerInteraction.openRecommendedChannelContextMenu(peer, sourceView, gesture)
                        }
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: self.panelNode.frame.width, height: 100.0)
        )
        if let view = self.panelListView.view {
            if view.superview == nil {
                self.panelNode.view.addSubview(view)
            }
            view.frame = CGRect(origin: CGPoint(x: 0.0, y: 42.0), size: listSize)
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
        
        var panelBackgroundFrame = panelBackgroundNode.frame
        panelBackgroundFrame.origin.x += self.panelNode.frame.minX + rect.minX
        panelBackgroundFrame.origin.y += self.panelNode.frame.minY + rect.minY
        self.panelBackgroundNode.updateAbsoluteRect(panelBackgroundFrame, within: containerSize)
    }

    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }

    override public func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
    }
    
    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [(CGRect, CGRect)]?
            let textNodeFrame = self.labelNode.frame
            if let point = point {
                if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.labelNode.lineAndAttributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
        
            if let rects = rects {
                var mappedRects: [CGRect] = []
                for i in 0 ..< rects.count {
                    let lineRect = rects[i].0
                    var itemRect = rects[i].1
                    itemRect.origin.x = floor((textNodeFrame.size.width - lineRect.width) / 2.0) + itemRect.origin.x
                    mappedRects.append(itemRect)
                }
                
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                    linkHighlightingNode = LinkHighlightingNode(color: serviceColor.linkHighlight)
                    linkHighlightingNode.inset = 2.5
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.labelNode)
                }
                linkHighlightingNode.frame = self.labelNode.frame.offsetBy(dx: 0.0, dy: 1.5)
                linkHighlightingNode.updateRects(mappedRects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.labelNode.frame
        if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)), gesture == .tap {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.labelNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            }
        }
        
        if let backgroundNode = self.backgroundNode, backgroundNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        
        if self.panelNode.frame.contains(point) {
            let panelPoint = self.view.convert(point, to: self.panelNode.view)
            if self.closeButtonNode.frame.contains(panelPoint) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
        }
        
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}

private class MessageBackgroundNode: ASDisplayNode {
    private let backgroundWallpaperNode: ChatMessageBubbleBackdrop
    private let backgroundNode: ChatMessageBackground
    
    override init() {
        self.backgroundWallpaperNode = ChatMessageBubbleBackdrop()
        self.backgroundNode = ChatMessageBackground()
        self.backgroundNode.backdropNode = self.backgroundWallpaperNode

        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.backgroundWallpaperNode)
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    
    func update(size: CGSize, theme: PresentationTheme, wallpaper: TelegramWallpaper, graphics: PrincipalThemeEssentialGraphics, wallpaperBackgroundNode: WallpaperBackgroundNode, transition: ContainedViewLayoutTransition) {
        self.backgroundNode.setType(type: .incoming(.Extracted), highlighted: false, graphics: graphics, maskMode: false, hasWallpaper: wallpaper.hasWallpaper, transition: transition, backgroundNode: wallpaperBackgroundNode)
        self.backgroundWallpaperNode.setType(type: .incoming(.Extracted), theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), essentialGraphics: graphics, maskMode: false, backgroundNode: wallpaperBackgroundNode)
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.updateLayout(size: backgroundFrame.size, transition: transition)
        self.backgroundWallpaperNode.updateFrame(backgroundFrame, transition: transition)
        
        if let (rect, size) = self.absoluteRect {
            self.updateAbsoluteRect(rect, within: size)
        }
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        var backgroundWallpaperFrame = self.backgroundWallpaperNode.frame
        backgroundWallpaperFrame.origin.x += rect.minX
        backgroundWallpaperFrame.origin.y += rect.minY
        self.backgroundWallpaperNode.update(rect: backgroundWallpaperFrame, within: containerSize)
    }
}

private let itemSize = CGSize(width: 84.0, height: 90.0)

private final class ChannelItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peers: [EnginePeer]
    let isLocked: Bool
    let title: String
    let subtitle: String
    let action: (EnginePeer?) -> Void
    let openMore: () -> Void
    let contextAction: ((EnginePeer, UIView, ContextGesture?) -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peers: [EnginePeer],
        isLocked: Bool,
        title: String,
        subtitle: String,
        action: @escaping (EnginePeer?) -> Void,
        openMore: @escaping () -> Void,
        contextAction: ((EnginePeer, UIView, ContextGesture?) -> Void)?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peers = peers
        self.isLocked = isLocked
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.openMore = openMore
        self.contextAction = contextAction
    }
    
    static func ==(lhs: ChannelItemComponent, rhs: ChannelItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.isLocked != rhs.isLocked {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let contextContainer: ContextControllerSourceView
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private let circlesView: UIImageView
        
        private let avatarNode: AvatarNode
        private var mergedAvatarsNode: MergedAvatarsNode?
        private let avatarBadge: AvatarBadgeView
        private let subtitleIcon = ComponentView<Empty>()
                        
        private var component: ChannelItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.contextContainer = ContextControllerSourceView()
            
            self.circlesView = UIImageView()
            
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            self.avatarNode.isUserInteractionEnabled = false
            
            self.avatarBadge = AvatarBadgeView(frame: CGRect())
            
            self.containerButton = HighlightTrackingButton()
            
            super.init(frame: frame)
            
            self.addSubview(self.contextContainer)
            
            self.contextContainer.addSubview(self.containerButton)
            
            self.contextContainer.addSubnode(self.avatarNode)
            self.contextContainer.addSubview(self.avatarBadge)
            
            self.avatarNode.badgeView = self.avatarBadge
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.contextContainer.animateScale = false
            self.contextContainer.activated = { [weak self] gesture, point in
                if let self, let component = self.component, let peer = component.peers.first {
                    component.contextAction?(peer, self.contextContainer, gesture)
                }
            }
            
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let topScale: CGFloat = (self.bounds.width - 6.0) / self.bounds.width
                    
                    if highlighted {
                        self.contextContainer.layer.removeAnimation(forKey: "sublayerTransform")
                        let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                        transition.setScale(layer: self.contextContainer.layer, scale: topScale)
                    } else {
                        let transition = ComponentTransition(animation: .none)
                        transition.setScale(layer: self.contextContainer.layer, scale: 1.0)
                        
                        self.contextContainer.layer.animateScale(from: topScale, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component, let peer = component.peers.first else {
                return
            }
            if !component.isLocked {
                if component.peers.count > 1 {
                    component.openMore()
                } else {
                    component.action(peer)
                }
            } else {
                component.action(nil)
            }
        }
        
        func update(component: ChannelItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let themeUpdated = previousComponent?.theme !== component.theme
                                
            self.contextContainer.isGestureEnabled = true
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(11.0), textColor: component.isLocked || component.peers.count > 1 ? component.theme.chat.message.incoming.secondaryTextColor : component.theme.chat.message.incoming.primaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2
                )),
                environment: {},
                containerSize: CGSize(width: itemSize.width - 9.0, height: 100.0)
            )
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.subtitle, font: Font.with(size: 9.0, design: .round, weight: .bold), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: itemSize.width - 6.0, height: 100.0)
            )
            
            var subtitleIconSize: CGSize
            if component.peers.count == 1 {
                subtitleIconSize = self.subtitleIcon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(name: component.isLocked ? "Chat List/StatusLockIcon" : "Chat/Message/Subscriber", tintColor: .white)),
                    environment: {},
                    containerSize: CGSize(width: itemSize.width - 6.0, height: 100.0)
                )
                if component.isLocked {
                    subtitleIconSize = subtitleIconSize.fitted(CGSize(width: 8.0, height: 8.0))
                }
            } else {
                subtitleIconSize = .zero
            }
            
            let avatarSize = CGSize(width: 60.0, height: 60.0)
            var avatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((itemSize.width - avatarSize.width) / 2.0), y: 0.0), size: avatarSize)
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((itemSize.width - titleSize.width) / 2.0), y: avatarFrame.maxY + 4.0), size: titleSize)
            
            let subtitleSpacing: CGFloat = 1.0 + UIScreenPixel
            let subtitleTotalWidth = subtitleIconSize.width + subtitleSize.width + subtitleSpacing
            
            let subtitleOriginX = floorToScreenPixels((itemSize.width - subtitleTotalWidth) / 2.0) + 1.0 - UIScreenPixel
            var iconOriginX = subtitleOriginX
            var textOriginX = subtitleOriginX
            if subtitleIconSize.width > 0.0 {
                textOriginX += subtitleIconSize.width + subtitleSpacing
            }
            if component.isLocked {
                textOriginX = subtitleOriginX
                iconOriginX = subtitleOriginX + subtitleSize.width + subtitleSpacing
            }
            
            let subtitleIconFrame = CGRect(origin: CGPoint(x: iconOriginX, y: avatarFrame.maxY - subtitleSize.height + 1.0 - UIScreenPixel), size: subtitleIconSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: textOriginX, y: avatarFrame.maxY - subtitleSize.height - UIScreenPixel), size: subtitleSize)
            
            var avatarHorizontalOffset: CGFloat = 0.0
            if component.isLocked {
                avatarHorizontalOffset = -10.0
            }
            avatarFrame = avatarFrame.offsetBy(dx: avatarHorizontalOffset, dy: 0.0)
            self.avatarNode.frame = avatarFrame
            if let peer = component.peers.first {
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer)
            }
            
            if component.peers.count > 1 {
                let mergedAvatarsNode: MergedAvatarsNode
                if let current = self.mergedAvatarsNode {
                    mergedAvatarsNode = current
                } else {
                    mergedAvatarsNode = MergedAvatarsNode()
                    mergedAvatarsNode.isUserInteractionEnabled = false
                    self.contextContainer.insertSubview(mergedAvatarsNode.view, aboveSubview: self.avatarNode.view)
                    self.mergedAvatarsNode = mergedAvatarsNode
                }
                
                mergedAvatarsNode.update(context: component.context, peers: component.peers.map { $0._asPeer() }, synchronousLoad: false, imageSize: 60.0, imageSpacing: 10.0, borderWidth: 2.0, avatarFontSize: 26.0)
                let avatarsSize = CGSize(width: avatarSize.width + 20.0, height: avatarSize.height)
                mergedAvatarsNode.updateLayout(size: avatarsSize)
                mergedAvatarsNode.frame = CGRect(origin: CGPoint(x: avatarFrame.midX - avatarsSize.width / 2.0, y: avatarFrame.minY), size: avatarsSize)
                self.avatarNode.isHidden = true
            } else {
                self.mergedAvatarsNode?.view.removeFromSuperview()
                self.mergedAvatarsNode = nil
                self.avatarNode.isHidden = false
            }
            
            if component.isLocked {
                if self.circlesView.superview == nil {
                    self.contextContainer.insertSubview(self.circlesView, belowSubview: self.avatarNode.view)
                }
                self.circlesView.isHidden = false
                
                if self.circlesView.image == nil || themeUpdated {
                    let image = generateImage(CGSize(width: 50.0, height: avatarSize.height), rotatedContext: { size, context in
                        context.clear(CGRect(origin: .zero, size: size))
                        
                        let color = component.theme.chat.message.incoming.secondaryTextColor.withMultipliedAlpha(0.35)
                        
                        context.saveGState()
                        
                        let rect1 = CGRect(origin: CGPoint(x: size.width - avatarSize.width, y: 0.0), size: avatarSize)
                        context.addEllipse(in: rect1)
                        context.clip()
                        
                        context.setFillColor(color.cgColor)
                        context.fill(rect1)
                        
                        context.restoreGState()
                        
                        context.setBlendMode(.clear)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - avatarSize.width - 12.0, y: -2.0), size: CGSize(width: avatarSize.width + 4.0, height: avatarSize.height + 4.0)))
                        
                        context.setBlendMode(.normal)
                        
                        context.saveGState()
                        
                        let rect2 = CGRect(origin: CGPoint(x: size.width - avatarSize.width - 10.0, y: 0.0), size: avatarSize)
                        context.addEllipse(in: rect2)
                        context.clip()
                        
                        context.setFillColor(color.cgColor)
                        context.fill(rect2)
                        
                        context.restoreGState()
                        
                        context.setBlendMode(.clear)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - avatarSize.width - 22.0, y: -2.0), size: CGSize(width: avatarSize.width + 4.0, height: avatarSize.height + 4.0)))
                    })
                    self.circlesView.image = image
                }
                self.circlesView.frame = CGRect(origin: CGPoint(x: avatarFrame.midX, y: 0.0), size: CGSize(width: 50.0, height: 60.0))
            } else {
                if self.circlesView.superview != nil {
                    self.circlesView.removeFromSuperview()
                }
            }
                
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.contextContainer.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    subtitleView.isUserInteractionEnabled = false
                    self.contextContainer.addSubview(subtitleView)
                }
                subtitleView.frame = subtitleFrame
            }
            if let subtitleIconView = self.subtitleIcon.view {
                if subtitleIconView.superview == nil {
                    subtitleIconView.isUserInteractionEnabled = false
                    self.contextContainer.addSubview(subtitleIconView)
                }
                subtitleIconView.frame = subtitleIconFrame
            }
            
            let strokeWidth: CGFloat = 1.0 + UIScreenPixel
            let avatarBadgeSize = CGSize(width: subtitleSize.width + subtitleIconSize.width + 10.0, height: 15.0)
            self.avatarBadge.update(size: avatarBadgeSize, text: "", hasTimeoutIcon: false, useSolidColor: true, strokeColor: component.theme.chat.message.incoming.bubble.withoutWallpaper.fill.first!)

            let avatarBadgeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((itemSize.width - avatarBadgeSize.width) / 2.0), y: avatarFrame.minY + avatarFrame.height - avatarBadgeSize.height + 2.0), size: avatarBadgeSize).insetBy(dx: -strokeWidth, dy: -strokeWidth)
            self.avatarBadge.frame = avatarBadgeFrame
    
            let bounds = CGRect(origin: .zero, size: itemSize)
            self.contextContainer.frame = bounds
            self.containerButton.frame = bounds
            
            return itemSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private let channelsLimit: Int32 = 10

final class ChannelListPanelComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peers: RecommendedChannels
    let action: (EnginePeer?) -> Void
    let openMore: () -> Void
    let contextAction: (EnginePeer, UIView, ContextGesture?) -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peers: RecommendedChannels,
        action: @escaping (EnginePeer?) -> Void,
        openMore: @escaping () -> Void,
        contextAction: @escaping (EnginePeer, UIView, ContextGesture?) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peers = peers
        self.action = action
        self.openMore = openMore
        self.contextAction = contextAction
    }
    
    static func ==(lhs: ChannelListPanelComponent, rhs: ChannelListPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        let containerInsets: UIEdgeInsets
        let containerHeight: CGFloat
        let itemWidth: CGFloat
        let itemCount: Int
        
        let contentWidth: CGFloat
        
        init(
            containerInsets: UIEdgeInsets,
            containerHeight: CGFloat,
            itemWidth: CGFloat,
            itemCount: Int
        ) {
            self.containerInsets = containerInsets
            self.containerHeight = containerHeight
            self.itemWidth = itemWidth
            self.itemCount = itemCount
            
            self.contentWidth = containerInsets.left + containerInsets.right + CGFloat(itemCount) * itemWidth
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -self.containerInsets.top)
            var minVisibleRow = Int(floor((offsetRect.minX) / (self.itemWidth)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxX) / (self.itemWidth)))
            
            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = maxVisibleRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: self.containerInsets.left + CGFloat(index) * self.itemWidth, y: 0.0), size: CGSize(width: self.itemWidth, height: self.containerHeight))
        }
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private let measureItem = ComponentView<Empty>()
        private var visibleItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        
        private var component: ChannelListPanelComponent?
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollViewImpl()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
            
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: -100.0, dy: 0.0)
            
            let hasMore = component.peers.count > channelsLimit
            
            var validIds = Set<EnginePeer.Id>()
            if let visibleItems = itemLayout.visibleItems(for: visibleBounds) {
                let upperBound = min(Int(channelsLimit), visibleItems.upperBound)
                
                for index in visibleItems.lowerBound ..< upperBound {
                    if index >= component.peers.channels.count {
                        continue
                    }
                    let item = component.peers.channels[index]
                    let id = item.peer.id
                    validIds.insert(id)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    if let current = self.visibleItems[id] {
                        itemView = current
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentView()
                        self.visibleItems[id] = itemView
                    }
                    
                    let title: String
                    let subtitle: String
                    var isLocked = false
                    var isLast = false
                    if index == upperBound - 1 && hasMore {
                        if !component.context.isPremium {
                            isLocked = true
                        }
                        title =  component.strings.Chat_SimilarChannels_MoreChannels
                        subtitle = "+\(component.peers.count - channelsLimit)"
                        isLast = true
                    } else {
                        title = item.peer.compactDisplayTitle
                        subtitle = countString(Int64(item.subscribers))
                    }
                    
                    var peers: [EnginePeer] = [item.peer]
                    if isLast && !isLocked {
                        for i in index + 1 ..< index + 3 {
                            if i < component.peers.channels.count {
                                peers.append(component.peers.channels[i].peer)
                            }
                        }
                    }
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(ChannelItemComponent(
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            peers: peers,
                            isLocked: isLocked,
                            title: title,
                            subtitle: subtitle,
                            action: component.action,
                            openMore: component.openMore,
                            contextAction: !isLocked && peers.count == 1 ? component.contextAction : nil
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.itemWidth, height: itemLayout.containerHeight)
                    )
                    let itemFrame = itemLayout.itemFrame(for: index)
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.scrollView.addSubview(itemComponentView)
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removeIds: [EnginePeer.Id] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func update(component: ChannelListPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
                        
            let itemLayout = ItemLayout(
                containerInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                containerHeight: availableSize.height,
                itemWidth: itemSize.width,
                itemCount: min(Int(channelsLimit), component.peers.channels.count)
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            var scrollBounds = self.scrollView.bounds
            scrollBounds.size = availableSize
            transition.setBounds(view: self.scrollView, bounds: scrollBounds)
            let contentSize = CGSize(width: itemLayout.contentWidth, height: availableSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            if !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
