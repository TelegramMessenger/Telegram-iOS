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
import AudioBlob
import PeerInfoAvatarListNode

final class VoiceChatParticipantItem: ListViewItem {
    enum LayoutStyle: Equatable {
        case list
        case tile(isLandscape: Bool)
    }
    
    enum ParticipantText {
        public enum Icon {
            case volume
            case video
        }
        
        public enum TextColor {
            case generic
            case accent
            case constructive
            case destructive
        }
        
        case presence
        case text(String, Icon?, TextColor)
        case none
    }
    
    enum Icon {
        case none
        case microphone(Bool, UIColor)
        case invite(Bool)
        case wantsToSpeak
    }
    
    struct RevealOption {
        enum RevealOptionType {
            case neutral
            case warning
            case destructive
            case accent
        }
        
        var type: RevealOptionType
        var title: String
        var action: () -> Void
        
        init(type: RevealOptionType, title: String, action: @escaping () -> Void) {
            self.type = type
            self.title = title
            self.action = action
        }
    }

    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: Peer
    let ssrc: UInt32?
    let presence: PeerPresence?
    let text: ParticipantText
    let expandedText: ParticipantText?
    let icon: Icon
    let style: LayoutStyle
    let enabled: Bool
    let transparent: Bool
    let pinned: Bool
    public let selectable: Bool
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    let getVideo: () -> GroupVideoNode?
    let revealOptions: [RevealOption]
    let revealed: Bool?
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let action: ((ASDisplayNode) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let getIsExpanded: () -> Bool
    let getUpdatingAvatar: () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, ssrc: UInt32?, presence: PeerPresence?, text: ParticipantText, expandedText: ParticipantText?, icon: Icon, style: LayoutStyle, enabled: Bool, transparent: Bool, pinned: Bool, selectable: Bool, getAudioLevel: (() -> Signal<Float, NoError>)?, getVideo: @escaping () -> GroupVideoNode?, revealOptions: [RevealOption], revealed: Bool?, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, action: ((ASDisplayNode) -> Void)?, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil, getIsExpanded: @escaping () -> Bool, getUpdatingAvatar: @escaping () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.ssrc = ssrc
        self.presence = presence
        self.text = text
        self.expandedText = expandedText
        self.icon = icon
        self.style = style
        self.enabled = enabled
        self.transparent = transparent
        self.pinned = pinned
        self.selectable = selectable
        self.getAudioLevel = getAudioLevel
        self.getVideo = getVideo
        self.revealOptions = revealOptions
        self.revealed = revealed
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.action = action
        self.contextAction = contextAction
        self.getIsExpanded = getIsExpanded
        self.getUpdatingAvatar = getUpdatingAvatar
    }
        
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
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
    }
}

private let avatarFont = avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0))
private let tileSize = CGSize(width: 84.0, height: 84.0)
private let backgroundCornerRadius: CGFloat = 14.0
private let avatarSize: CGFloat = 40.0

private let accentColor: UIColor = UIColor(rgb: 0x007aff)
private let constructiveColor: UIColor = UIColor(rgb: 0x34c759)
private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

private let borderLineWidth: CGFloat = 2.0
private let borderImage = generateImage(CGSize(width: tileSize.width, height: tileSize.height), rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    context.setLineWidth(borderLineWidth)
    context.setStrokeColor(accentColor.cgColor)
    
    context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: (borderLineWidth - UIScreenPixel) / 2.0, dy: (borderLineWidth - UIScreenPixel) / 2.0), cornerRadius: backgroundCornerRadius - UIScreenPixel).cgPath)
    context.strokePath()
})

private let fadeImage = generateImage(CGSize(width: 1.0, height: 30.0), rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    let colorsArray = [UIColor(rgb: 0x000000, alpha: 0.0).cgColor, UIColor(rgb: 0x000000, alpha: 0.7).cgColor] as CFArray
    var locations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
})

private class VoiceChatParticipantStatusNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private let textNode: TextNode
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        self.textNode = TextNode()
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func update() {
        
    }
}

class VoiceChatParticipantItemNode: ItemListRevealOptionsItemNode {
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let backgroundImageNode: ASImageNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode
    private let borderImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    private var extractedVerticalOffset: CGFloat?
        
    fileprivate let avatarNode: AvatarNode
    private let pinIconNode: ASImageNode
    private let contentWrapperNode: ASDisplayNode
    private let titleNode: TextNode
    private let statusIconNode: ASImageNode
    private let statusNode: TextNode
    private let expandedStatusNode: TextNode
    private var credibilityIconNode: ASImageNode?
    
    private var avatarTransitionNode: ASImageNode?
    private var avatarListContainerNode: ASDisplayNode?
    private var avatarListWrapperNode: PinchSourceContainerNode?
    private var avatarListNode: PeerInfoAvatarListContainerNode?
    
    private let actionContainerNode: ASDisplayNode
    private var animationNode: VoiceChatMicrophoneNode?
    private var iconNode: ASImageNode?
    private var raiseHandNode: VoiceChatRaiseHandNode?
    private var actionButtonNode: HighlightableButtonNode
    
    private var audioLevelView: VoiceBlobView?
    private let audioLevelDisposable = MetaDisposable()
    private var didSetupAudioLevel = false
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (VoiceChatParticipantItem, ListViewItemLayoutParams, Bool, Bool)?
    private var isExtracted = false
    private var animatingExtraction = false
    private var wavesColor: UIColor?
    
    private let videoContainerNode: ASDisplayNode
    private let videoFadeNode: ASImageNode
    private var videoNode: GroupVideoNode?
    private let videoReadyDisposable = MetaDisposable()
    private var videoReadyDelayed = false
    
    private var raiseHandTimer: SwiftSignalKit.Timer?
    
    var item: VoiceChatParticipantItem? {
        return self.layoutParams?.0
    }
    
    private var currentTitle: String?
    
    init() {
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.backgroundImageNode = ASImageNode()
        self.backgroundImageNode.clipsToBounds = true
        self.backgroundImageNode.displaysAsynchronously = false
        self.backgroundImageNode.alpha = 0.0
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.clipsToBounds = true
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.borderImageNode = ASImageNode()
        self.borderImageNode.displaysAsynchronously = false
        self.borderImageNode.image = borderImage
        self.borderImageNode.isHidden = true
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
        
        self.pinIconNode = ASImageNode()
        self.pinIconNode.alpha = 0.65
        self.pinIconNode.displaysAsynchronously = false
        self.pinIconNode.displayWithoutProcessing = true
        self.pinIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pin"), color: UIColor(rgb: 0xffffff))
        
        self.contentWrapperNode = ASDisplayNode()
        
        self.videoContainerNode = ASDisplayNode()
        self.videoContainerNode.clipsToBounds = true
        
        self.videoFadeNode = ASImageNode()
        self.videoFadeNode.displaysAsynchronously = false
        self.videoFadeNode.displayWithoutProcessing = true
        self.videoFadeNode.contentMode = .scaleToFill
        self.videoFadeNode.image = fadeImage
        self.videoContainerNode.addSubnode(videoFadeNode)
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusIconNode = ASImageNode()
        self.statusIconNode.displaysAsynchronously = false
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.expandedStatusNode = TextNode()
        self.expandedStatusNode.isUserInteractionEnabled = false
        self.expandedStatusNode.contentMode = .left
        self.expandedStatusNode.contentsScale = UIScreen.main.scale
        self.expandedStatusNode.alpha = 0.0
        
        self.actionContainerNode = ASDisplayNode()
        self.actionButtonNode = HighlightableButtonNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.backgroundImageNode)
        self.backgroundImageNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.videoContainerNode)
        self.offsetContainerNode.addSubnode(self.contentWrapperNode)
        self.contentWrapperNode.addSubnode(self.titleNode)
        self.contentWrapperNode.addSubnode(self.statusIconNode)
        self.contentWrapperNode.addSubnode(self.statusNode)
        self.contentWrapperNode.addSubnode(self.expandedStatusNode)
        self.contentWrapperNode.addSubnode(self.actionContainerNode)
        self.actionContainerNode.addSubnode(self.actionButtonNode)
        self.offsetContainerNode.addSubnode(self.pinIconNode)
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.contextSourceNode.contentNode.addSubnode(self.borderImageNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        
        self.actionButtonNode.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3)
                apply(false, true)
            }
        })
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
                return false
            }
            if strongSelf.actionButtonNode.frame.contains(location) {
                return false
            }
            return true
        }
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
            
            strongSelf.isExtracted = isExtracted
            
            let inset: CGFloat = 12.0
            if isExtracted {
                strongSelf.contextSourceNode.contentNode.customHitTest = { [weak self] point in
                    if let strongSelf = self {
                        if let avatarListWrapperNode = strongSelf.avatarListWrapperNode, avatarListWrapperNode.frame.contains(point) {
                            return strongSelf.avatarListNode?.view
                        }
                    }
                    return nil
                }
            } else {
                strongSelf.contextSourceNode.contentNode.customHitTest = nil
            }
                       
            let extractedVerticalOffset = strongSelf.extractedVerticalOffset ?? 0.0
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect: CGRect
                if isExtracted {
                    if extractedVerticalOffset > 0.0 {
                        rect = CGRect(x: extractedRect.minX, y: extractedRect.minY + extractedVerticalOffset, width: extractedRect.width, height: extractedRect.height - extractedVerticalOffset)
                    } else {
                        rect = extractedRect
                    }
                } else {
                    rect = nonExtractedRect
                }
                
                let springDuration: Double = isExtracted ? 0.42 : 0.3
                let springDamping: CGFloat = isExtracted ? 104.0 : 1000.0
                
                let itemBackgroundColor: UIColor = item.getIsExpanded() ? UIColor(rgb: 0x1c1c1e) : UIColor(rgb: 0x2c2c2e)
                
                if !extractedVerticalOffset.isZero {
                    let radiusTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    if isExtracted {
                        strongSelf.backgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
                            let bounds = CGRect(origin: CGPoint(), size: size)
                            context.clear(bounds)
                            
                            context.setFillColor(itemBackgroundColor.cgColor)
                            context.fillEllipse(in: bounds)
                            context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
                        })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
                        strongSelf.extractedBackgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
                            let bounds = CGRect(origin: CGPoint(), size: size)
                            context.clear(bounds)
                            
                            context.setFillColor(item.presentationData.theme.list.itemBlocksBackgroundColor.cgColor)
                            context.fillEllipse(in: bounds)
                            context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
                        })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
                        strongSelf.backgroundImageNode.cornerRadius = backgroundCornerRadius
                                              
                        strongSelf.avatarNode.transform = CATransform3DIdentity
                        var avatarInitialRect = strongSelf.avatarNode.view.convert(strongSelf.avatarNode.bounds, to: strongSelf.offsetContainerNode.supernode?.view)
                        if strongSelf.avatarTransitionNode == nil {
                            transition.updateCornerRadius(node: strongSelf.backgroundImageNode, cornerRadius: 0.0)
                              
                            let targetRect = CGRect(x: extractedRect.minX, y: extractedRect.minY, width: extractedRect.width, height: extractedRect.width)
                            let initialScale = avatarInitialRect.width / targetRect.width
                            avatarInitialRect.origin.y += backgroundCornerRadius / 2.0 * initialScale
                            
                            let avatarListWrapperNode = PinchSourceContainerNode()
                            avatarListWrapperNode.clipsToBounds = true
                            avatarListWrapperNode.cornerRadius = backgroundCornerRadius
                            avatarListWrapperNode.activate = { [weak self] sourceNode in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.avatarListNode?.controlsContainerNode.alpha = 0.0
                                let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                                    return UIScreen.main.bounds
                                })
                                item.context.sharedContext.mainWindow?.presentInGlobalOverlay(pinchController)
                            }
                            avatarListWrapperNode.deactivated = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.avatarListWrapperNode?.contentNode.layer.animate(from: 0.0 as NSNumber, to: backgroundCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3, completion: { _ in
                                })
                            }
                            avatarListWrapperNode.update(size: targetRect.size, transition: .immediate)
                            avatarListWrapperNode.frame = CGRect(x: targetRect.minX, y: targetRect.minY, width: targetRect.width, height: targetRect.height + backgroundCornerRadius)
                            avatarListWrapperNode.animatedOut = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.avatarListNode?.controlsContainerNode.alpha = 1.0
                                strongSelf.avatarListNode?.controlsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                            
                            let transitionNode = ASImageNode()
                            transitionNode.clipsToBounds = true
                            transitionNode.displaysAsynchronously = false
                            transitionNode.displayWithoutProcessing = true
                            transitionNode.image = strongSelf.avatarNode.unroundedImage
                            transitionNode.frame = CGRect(origin: CGPoint(), size: targetRect.size)
                            transitionNode.cornerRadius = targetRect.width / 2.0
                            radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: 0.0)
                            
                            strongSelf.avatarNode.isHidden = true
                            avatarListWrapperNode.contentNode.addSubnode(transitionNode)
                            
                            strongSelf.videoContainerNode.position = CGPoint(x: avatarListWrapperNode.frame.width / 2.0, y: avatarListWrapperNode.frame.height / 2.0)
                            strongSelf.videoContainerNode.cornerRadius = tileSize.width / 2.0
                            strongSelf.videoContainerNode.transform = CATransform3DMakeScale(avatarListWrapperNode.frame.width / tileSize.width * 1.05, avatarListWrapperNode.frame.height / tileSize.width * 1.05, 1.0)
                            avatarListWrapperNode.contentNode.addSubnode(strongSelf.videoContainerNode)
                            
                            strongSelf.avatarTransitionNode = transitionNode
    
                            let avatarListContainerNode = ASDisplayNode()
                            avatarListContainerNode.clipsToBounds = true
                            avatarListContainerNode.frame = CGRect(origin: CGPoint(), size: targetRect.size)
                            avatarListContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            avatarListContainerNode.cornerRadius = targetRect.width / 2.0
                            
                            avatarListWrapperNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                            avatarListWrapperNode.layer.animateSpring(from: NSValue(cgPoint: avatarInitialRect.center), to: NSValue(cgPoint: avatarListWrapperNode.position), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, completion: { [weak self] _ in
                                if let strongSelf = self, let avatarListNode = strongSelf.avatarListNode {
                                    avatarListNode.currentItemNode?.addSubnode(strongSelf.videoContainerNode)
                                }
                            })
                            
                            radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: 0.0)
                            radiusTransition.updateCornerRadius(node: strongSelf.videoContainerNode, cornerRadius: 0.0)
                            
                            let avatarListNode = PeerInfoAvatarListContainerNode(context: item.context)
                            avatarListWrapperNode.contentNode.clipsToBounds = true
                            avatarListNode.backgroundColor = .clear
                            avatarListNode.peer = item.peer
                            avatarListNode.firstFullSizeOnly = true
                            avatarListNode.offsetLocation = true
                            avatarListNode.customCenterTapAction = { [weak self] in
                                self?.contextSourceNode.requestDismiss?()
                            }
                            avatarListNode.frame = CGRect(x: targetRect.width / 2.0, y: targetRect.height / 2.0, width: targetRect.width, height: targetRect.height)
                            avatarListNode.controlsClippingNode.frame = CGRect(x: -targetRect.width / 2.0, y: -targetRect.height / 2.0, width: targetRect.width, height: targetRect.height)
                            avatarListNode.controlsClippingOffsetNode.frame = CGRect(origin: CGPoint(x: targetRect.width / 2.0, y: targetRect.height / 2.0), size: CGSize())
                            avatarListNode.stripContainerNode.frame = CGRect(x: 0.0, y: 13.0, width: targetRect.width, height: 2.0)
                            
                            avatarListContainerNode.addSubnode(avatarListNode)
                            avatarListContainerNode.addSubnode(avatarListNode.controlsClippingOffsetNode)
                            avatarListWrapperNode.contentNode.addSubnode(avatarListContainerNode)
                            
                            avatarListNode.update(size: targetRect.size, peer: item.peer, customNode: strongSelf.videoContainerNode, additionalEntry: item.getUpdatingAvatar(), isExpanded: true, transition: .immediate)
                            strongSelf.offsetContainerNode.supernode?.addSubnode(avatarListWrapperNode)

                            strongSelf.audioLevelView?.alpha = 0.0
                            
                            strongSelf.avatarListWrapperNode = avatarListWrapperNode
                            strongSelf.avatarListContainerNode = avatarListContainerNode
                            strongSelf.avatarListNode = avatarListNode
                        }
                    } else if let transitionNode = strongSelf.avatarTransitionNode, let avatarListWrapperNode = strongSelf.avatarListWrapperNode, let avatarListContainerNode = strongSelf.avatarListContainerNode {
                        strongSelf.animatingExtraction = true
                        
                        transition.updateCornerRadius(node: strongSelf.backgroundImageNode, cornerRadius: backgroundCornerRadius)
                        
                        var avatarInitialRect = CGRect(origin: strongSelf.avatarNode.frame.origin, size: strongSelf.avatarNode.frame.size)
                        let targetScale = avatarInitialRect.width / avatarListContainerNode.frame.width
                        avatarInitialRect.origin.y += backgroundCornerRadius / 2.0 * targetScale
                        
                        strongSelf.avatarTransitionNode = nil
                        strongSelf.avatarListWrapperNode = nil
                        strongSelf.avatarListContainerNode = nil
                        strongSelf.avatarListNode = nil
                        
                        avatarListContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak avatarListContainerNode] _ in
                            avatarListContainerNode?.removeFromSupernode()
                        })
                        
                        avatarListWrapperNode.contentNode.insertSubnode(strongSelf.videoContainerNode, aboveSubnode: transitionNode)
                        
                        avatarListWrapperNode.layer.animate(from: 1.0 as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
                        avatarListWrapperNode.layer.animate(from: NSValue(cgPoint: avatarListWrapperNode.position), to: NSValue(cgPoint: avatarInitialRect.center), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionNode, weak self] _ in
                            transitionNode?.removeFromSupernode()
                            self?.avatarNode.isHidden = false
                            
                            self?.audioLevelView?.alpha = 1.0
                            self?.audioLevelView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            
                            if let strongSelf = self {
                                strongSelf.animatingExtraction = false
                                
                                strongSelf.offsetContainerNode.insertSubnode(strongSelf.videoContainerNode, belowSubnode: strongSelf.contentWrapperNode)
                                
                                switch item.style {
                                    case .list:
                                        strongSelf.videoFadeNode.alpha = 0.0
                                        strongSelf.videoContainerNode.position = strongSelf.avatarNode.position
                                        strongSelf.videoContainerNode.cornerRadius = tileSize.width / 2.0
                                        strongSelf.videoContainerNode.transform = CATransform3DMakeScale(avatarSize / tileSize.width, avatarSize / tileSize.width, 1.0)
                                    case .tile:
                                        strongSelf.videoFadeNode.alpha = 1.0
                                        strongSelf.videoContainerNode.position = CGPoint(x: tileSize.width / 2.0, y: tileSize.height / 2.0)
                                        strongSelf.videoContainerNode.cornerRadius = backgroundCornerRadius
                                        strongSelf.videoContainerNode.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
                                }
                            }
                        })
    
                        radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
                        radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
                        radiusTransition.updateCornerRadius(node: strongSelf.videoContainerNode, cornerRadius: tileSize.width / 2.0)
                    }
                    
                    let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    alphaTransition.updateAlpha(node: strongSelf.statusNode, alpha: isExtracted ? 0.0 : 1.0)
                    alphaTransition.updateAlpha(node: strongSelf.expandedStatusNode, alpha: isExtracted ? 1.0 : 0.0)
                    alphaTransition.updateAlpha(node: strongSelf.actionContainerNode, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
                    
                    let offsetInitialSublayerTransform = strongSelf.offsetContainerNode.layer.sublayerTransform
                    strongSelf.offsetContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? -33 : 0.0, isExtracted ? extractedVerticalOffset : 0.0, 0.0)
                    
                    let actionInitialSublayerTransform = strongSelf.actionContainerNode.layer.sublayerTransform
                    strongSelf.actionContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? 21.0 : 0.0, 0.0, 0.0)
                    
                    let initialBackgroundPosition = strongSelf.backgroundImageNode.position
                    strongSelf.backgroundImageNode.layer.position = rect.center
                    let initialBackgroundBounds = strongSelf.backgroundImageNode.bounds
                    strongSelf.backgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: rect.size)
                    
                    let initialExtractedBackgroundPosition = strongSelf.extractedBackgroundImageNode.position
                    strongSelf.extractedBackgroundImageNode.layer.position = CGPoint(x: rect.size.width / 2.0, y: rect.size.height / 2.0)
                    let initialExtractedBackgroundBounds = strongSelf.extractedBackgroundImageNode.bounds
                    strongSelf.extractedBackgroundImageNode.layer.bounds = strongSelf.backgroundImageNode.layer.bounds
                    if isExtracted {
                        strongSelf.offsetContainerNode.layer.animateSpring(from: NSValue(caTransform3D: offsetInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.offsetContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.actionContainerNode.layer.animateSpring(from: NSValue(caTransform3D: actionInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.actionContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.backgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: strongSelf.backgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.backgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: strongSelf.backgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.extractedBackgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialExtractedBackgroundPosition), to: NSValue(cgPoint: strongSelf.extractedBackgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.extractedBackgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialExtractedBackgroundBounds), to: NSValue(cgRect: strongSelf.extractedBackgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                    } else {
                        strongSelf.offsetContainerNode.layer.animate(from: NSValue(caTransform3D: offsetInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.offsetContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.actionContainerNode.layer.animate(from: NSValue(caTransform3D: actionInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.actionContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.backgroundImageNode.layer.animate(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: strongSelf.backgroundImageNode.position), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.backgroundImageNode.layer.animate(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: strongSelf.backgroundImageNode.bounds), keyPath: "bounds", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.extractedBackgroundImageNode.layer.animate(from: NSValue(cgPoint: initialExtractedBackgroundPosition), to: NSValue(cgPoint: strongSelf.extractedBackgroundImageNode.position), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.extractedBackgroundImageNode.layer.animate(from: NSValue(cgRect: initialExtractedBackgroundBounds), to: NSValue(cgRect: strongSelf.extractedBackgroundImageNode.bounds), keyPath: "bounds", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                    }

                    if isExtracted {
                        strongSelf.backgroundImageNode.alpha = 1.0
                        strongSelf.extractedBackgroundImageNode.alpha = 1.0
                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                    } else {
                        strongSelf.extractedBackgroundImageNode.alpha = 0.0
                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            if let strongSelf = self {
                                if strongSelf.item?.style == .list {
                                    strongSelf.backgroundImageNode.image = nil
                                }
                                strongSelf.extractedBackgroundImageNode.image = nil
                                strongSelf.extractedBackgroundImageNode.layer.removeAllAnimations()
                            }
                        })
                    }
                } else {
                    if isExtracted {
                        strongSelf.backgroundImageNode.alpha = 0.0
                        strongSelf.extractedBackgroundImageNode.alpha = 1.0
                        strongSelf.backgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: itemBackgroundColor)
                        strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: item.presentationData.theme.list.itemBlocksBackgroundColor)
                    }
                    
                    transition.updateFrame(node: strongSelf.backgroundImageNode, frame: rect)
                    transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: CGRect(origin: CGPoint(), size: rect.size))
                    
                    transition.updateAlpha(node: strongSelf.statusNode, alpha: isExtracted ? 0.0 : 1.0)
                    transition.updateAlpha(node: strongSelf.expandedStatusNode, alpha: isExtracted ? 1.0 : 0.0)
                    transition.updateAlpha(node: strongSelf.actionContainerNode, alpha: isExtracted ? 0.0 : 1.0)
                    
                    transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? inset : 0.0, y: isExtracted ? extractedVerticalOffset : 0.0))
                    transition.updateSublayerTransformOffset(layer: strongSelf.actionContainerNode.layer, offset: CGPoint(x: isExtracted ? -24.0 : 0.0, y: 0.0))
                    
                    transition.updateAlpha(node: strongSelf.backgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                        if !isExtracted {
                            self?.backgroundImageNode.image = nil
                            self?.extractedBackgroundImageNode.image = nil
                        }
                    })
                }
            }
        }
    }
    
    deinit {
        self.videoReadyDisposable.dispose()
        self.audioLevelDisposable.dispose()
        self.raiseHandTimer?.invalidate()
    }
    
    override func selected() {
        super.selected()
        self.layoutParams?.0.action?(self.contextSourceNode)
    }
    
    func transitionIn(from sourceNode: VoiceChatParticipantItemNode, containerNode: ASDisplayNode) {
        guard let item = self.item, let sourceItem = sourceNode.item, sourceItem.style != item.style else {
            return
        }
        
        switch sourceItem.style {
            case .list:
                var startContainerPosition = sourceNode.avatarNode.view.convert(sourceNode.avatarNode.bounds, to: containerNode.view).center
                var animate = true
                if startContainerPosition.y > containerNode.frame.height - 238.0 {
                    animate = false
                }
                                
                if let videoNode = sourceNode.videoNode {
                    if item.transparent {
                    } else {
                        if item.pinned {
                            self.avatarNode.alpha = 1.0
                            videoNode.alpha = 0.0
                        } else {
                            self.avatarNode.alpha = 0.0
                        }
                    }
                    
                    sourceNode.videoNode = nil
                    self.videoNode = videoNode
                    
                    if animate {
                        self.videoContainerNode.layer.animateScale(from: avatarSize / tileSize.width, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                    self.videoContainerNode.insertSubnode(videoNode, at: 0)
                    
                    if animate {
                        self.videoContainerNode.layer.animate(from: (tileSize.width / 2.0) as NSNumber, to: backgroundCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        })
                    }
                } else {
                    startContainerPosition = startContainerPosition.offsetBy(dx: 0.0, dy: 9.0)
                }

                if animate {
                    sourceNode.avatarNode.alpha = 0.0
                    
                    let initialPosition = self.contextSourceNode.position
                    let targetContainerPosition = self.contextSourceNode.view.convert(self.contextSourceNode.bounds, to: containerNode.view).center
                    
                    self.contextSourceNode.position = targetContainerPosition
                    containerNode.addSubnode(self.contextSourceNode)
                    
                    self.contextSourceNode.layer.animatePosition(from: startContainerPosition, to: targetContainerPosition, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak self, weak sourceNode] _ in
                        if let strongSelf = self {
                            sourceNode?.avatarNode.alpha = 1.0
                            strongSelf.contextSourceNode.position = initialPosition
                            strongSelf.containerNode.addSubnode(strongSelf.contextSourceNode)
                        }
                    })
                    
                    self.videoFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    
                    if item.pinned {
                        self.borderImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        self.borderImageNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                    
                	self.backgroundImageNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    self.backgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    self.contentWrapperNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    self.contentWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                }
            case .tile:
                let startContainerAvatarPosition = sourceNode.avatarNode.view.convert(sourceNode.avatarNode.bounds, to: containerNode.view).center
                var animate = true
                if startContainerAvatarPosition.x < -tileSize.width || startContainerAvatarPosition.x > containerNode.frame.width + tileSize.width {
                    animate = false
                }
                
                if let videoNode = sourceNode.videoNode {
                    if item.transparent {
                    } else {
                        self.avatarNode.alpha = 0.0
                    }
                    sourceNode.videoNode = nil
                    self.videoNode = videoNode
                    self.videoContainerNode.insertSubnode(videoNode, at: 0)
                    
                    videoNode.alpha = 1.0
                }
                
                if animate {
                    sourceNode.avatarNode.alpha = 0.0
                    sourceNode.videoFadeNode.alpha = 0.0
                    
                    let initialAvatarPosition = self.avatarNode.position
                    let targetContainerAvatarPosition = self.avatarNode.view.convert(self.avatarNode.bounds, to: containerNode.view).center
                    
                    let startContainerBackgroundPosition = sourceNode.backgroundImageNode.view.convert(sourceNode.backgroundImageNode.bounds, to: containerNode.view).center
                    let startContainerContentPosition = sourceNode.contentWrapperNode.view.convert(sourceNode.contentWrapperNode.bounds, to: containerNode.view).center
                    let startContainerVideoPosition = sourceNode.videoContainerNode.view.convert(sourceNode.videoContainerNode.bounds, to: containerNode.view).center
                    
                    let initialBackgroundPosition = sourceNode.backgroundImageNode.position
                    let initialContentPosition = sourceNode.contentWrapperNode.position
                    
                    sourceNode.backgroundImageNode.position = targetContainerAvatarPosition
                    sourceNode.contentWrapperNode.position = targetContainerAvatarPosition
                    containerNode.addSubnode(sourceNode.backgroundImageNode)
                    containerNode.addSubnode(sourceNode.contentWrapperNode)
                    
                    if self.videoNode != nil {
                        sourceNode.backgroundImageNode.alpha = 0.0
                    }
                    
                    sourceNode.borderImageNode.alpha = 0.0
                                        
                    sourceNode.backgroundImageNode.layer.animatePosition(from: startContainerBackgroundPosition, to: targetContainerAvatarPosition, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak sourceNode] _ in
                        if let sourceNode = sourceNode {
                            sourceNode.backgroundImageNode.alpha = 1.0
                            sourceNode.borderImageNode.alpha = 1.0
                            sourceNode.backgroundImageNode.position = initialBackgroundPosition
                            sourceNode.contextSourceNode.contentNode.insertSubnode(sourceNode.backgroundImageNode, at: 0)
                        }
                    })
                    
                    sourceNode.contentWrapperNode.layer.animatePosition(from: startContainerContentPosition, to: targetContainerAvatarPosition, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak sourceNode] _ in
                        if let sourceNode = sourceNode {
                            sourceNode.avatarNode.alpha = 1.0
                            sourceNode.videoFadeNode.alpha = 1.0
                            sourceNode.contentWrapperNode.position = initialContentPosition
                            sourceNode.offsetContainerNode.insertSubnode(sourceNode.contentWrapperNode, aboveSubnode: sourceNode.videoContainerNode)
                        }
                    })
                    
                    
                    self.avatarNode.position = targetContainerAvatarPosition
                    containerNode.addSubnode(self.avatarNode)
                    
                    self.avatarNode.layer.animatePosition(from: startContainerAvatarPosition, to: targetContainerAvatarPosition, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.avatarNode.position = initialAvatarPosition
                            strongSelf.offsetContainerNode.addSubnode(strongSelf.avatarNode)
                        }
                    })
                    
                    
                    self.videoContainerNode.position = targetContainerAvatarPosition
                    containerNode.addSubnode(self.videoContainerNode)
                    
                    self.videoContainerNode.layer.animatePosition(from: startContainerVideoPosition, to: targetContainerAvatarPosition, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.videoContainerNode.position = initialAvatarPosition
                            strongSelf.offsetContainerNode.insertSubnode(strongSelf.videoContainerNode, belowSubnode: strongSelf.contentWrapperNode)
                        }
                    })
                                        
                    self.videoContainerNode.layer.animateScale(from: 1.0, to: avatarSize / tileSize.width, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    self.videoContainerNode.layer.animate(from: backgroundCornerRadius as NSNumber, to: (tileSize.width / 2.0) as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    })
                    
                    self.videoFadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    
                    sourceNode.backgroundImageNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.35, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    sourceNode.backgroundImageNode.layer.animateAlpha(from: sourceNode.backgroundImageNode.alpha, to: 0.0, duration: 0.35, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    sourceNode.contentWrapperNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.35, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    sourceNode.contentWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                }
        }
    }
        
    func asyncLayout() -> (_ item: VoiceChatParticipantItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeExpandedStatusLayout = TextNode.asyncLayout(self.expandedStatusNode)
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        let currentItem = self.layoutParams?.0
        let currentTitle = self.currentTitle
        
        return { item, params, first, last in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
                        
            var titleFont = item.style == .list ? Font.regular(17.0) : Font.regular(12.0)
            let statusFont = Font.regular(14.0)
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var expandedStatusAttributedString: NSAttributedString?
            
            let rightInset: CGFloat = params.rightInset
        
            var titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            if item.transparent && item.style == .list {
                titleFont = Font.semibold(17.0)
                titleColor = UIColor(rgb: 0xffffff, alpha: 0.65)
            } else if case .tile = item.style {
                switch item.text {
                    case let .text(_, _, textColor):
                        switch textColor {
                            case .generic:
                                titleColor = item.presentationData.theme.list.itemPrimaryTextColor
                            case .accent:
                                titleColor = item.presentationData.theme.list.itemAccentColor
                            case .constructive:
                                titleColor = constructiveColor
                            case .destructive:
                                titleColor = destructiveColor
                        }
                    default:
                        break
                }
                
            }
            let currentBoldFont: UIFont = titleFont
            
            var updatedTitle = false
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    switch item.style {
                        case .list:
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
                        case .tile:
                            titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
                    }
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
            if let currentTitle = currentTitle, currentTitle != titleAttributedString?.string {
                updatedTitle = true
            }
            
            var wavesColor = UIColor(rgb: 0x34c759)
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
                        let (string, _) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                        statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    } else {
                        statusAttributedString = NSAttributedString(string: item.presentationData.strings.LastSeen_Offline, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    }
                case let .text(text, textIcon, textColor):
                    var textColorValue: UIColor
                    switch textColor {
                    case .generic:
                        textColorValue = item.presentationData.theme.list.itemSecondaryTextColor
                    case .accent:
                        textColorValue = item.presentationData.theme.list.itemAccentColor
                        wavesColor = textColorValue
                    case .constructive:
                        textColorValue = constructiveColor
                    case .destructive:
                        textColorValue = destructiveColor
                        wavesColor = textColorValue
                    }
                    if item.transparent && item.style == .list {
                        textColorValue = UIColor(rgb: 0xffffff, alpha: 0.65)
                    }
                    statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: textColorValue)
                case .none:
                    break
            }
            
            if let expandedText = item.expandedText, case let .text(text, _, textColor) = expandedText {
                let textColorValue: UIColor
                switch textColor {
                case .generic:
                    textColorValue = item.presentationData.theme.list.itemSecondaryTextColor
                case .accent:
                    textColorValue = item.presentationData.theme.list.itemAccentColor
                case .constructive:
                    textColorValue = constructiveColor
                case .destructive:
                    textColorValue = destructiveColor
                }
                expandedStatusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: textColorValue)
            } else {
                expandedStatusAttributedString = statusAttributedString
            }

            let leftInset: CGFloat = 58.0 + params.leftInset
            let verticalInset: CGFloat = 8.0
            let verticalOffset: CGFloat = 0.0
            
            var titleIconsWidth: CGFloat = 0.0
            var currentCredibilityIconImage: UIImage?
            var credibilityIconOffset: CGFloat = 0.0
            if item.peer.isScam {
                currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                credibilityIconOffset = 2.0
            } else if item.peer.isFake {
                currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                credibilityIconOffset = 2.0
            } else if item.peer.isVerified {
                currentCredibilityIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                credibilityIconOffset = 3.0
            }
            
            if let currentCredibilityIconImage = currentCredibilityIconImage {
                titleIconsWidth += 4.0 + currentCredibilityIconImage.size.width
            }
            
            var expandedRightInset: CGFloat = 30.0
            if item.peer.smallProfileImage != nil {
                expandedRightInset = 0.0
            }
                              
            let constrainedWidth: CGFloat
            switch item.style {
                case .list:
                    constrainedWidth = params.width - leftInset - 12.0 - rightInset - 30.0 - titleIconsWidth
                case .tile:
                    constrainedWidth = params.width - 24.0 - 10.0
            }
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset - 30.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (expandedStatusLayout, expandedStatusApply) = makeExpandedStatusLayout(TextNodeLayoutArguments(attributedString: expandedStatusAttributedString, backgroundColor: nil, maximumNumberOfLines: 6, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset - expandedRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = statusLayout.size.height == 0.0 ? 0.0 : 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.size.height
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            switch item.style {
                case .list:
                    contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
                    insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: item.transparent ? 6.0 : 0.0, right: 0.0)
                case .tile:
                    contentSize = tileSize
                    insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: !last ? 6.0 : 0.0, right: 0.0)
            }
                
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
            
            var animateStatusTransitionFromUp: Bool?
            if let currentItem = currentItem {
                if case .presence = currentItem.text, case let .text(_, _, newColor) = item.text {
                    animateStatusTransitionFromUp = newColor == .constructive
                } else if case let .text(_, _, currentColor) = currentItem.text, case let .text(_, _, newColor) = item.text, currentColor != newColor {
                    animateStatusTransitionFromUp = newColor == .constructive
                } else if case .text = currentItem.text, case .presence = item.text {
                    animateStatusTransitionFromUp = false
                }
            }
            
            let peerRevealOptions: [ItemListRevealOption]
            var mappedOptions: [ItemListRevealOption] = []
            var index: Int32 = 0
            for option in item.revealOptions {
                let color: UIColor
                let textColor: UIColor
                switch option.type {
                    case .neutral:
                        color = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.constructive.foregroundColor
                    case .warning:
                        color = item.presentationData.theme.list.itemDisclosureActions.warning.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.warning.foregroundColor
                    case .destructive:
                        color = item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor
                    case .accent:
                        color = item.presentationData.theme.list.itemDisclosureActions.accent.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.accent.foregroundColor
                }
                mappedOptions.append(ItemListRevealOption(key: index, title: option.title, icon: .none, color: color, textColor: textColor))
                index += 1
            }
            peerRevealOptions = mappedOptions
            
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, first, last)
                    strongSelf.currentTitle = titleAttributedString?.string
                    strongSelf.wavesColor = wavesColor
                    
                    let videoSize = tileSize
                    let videoNode = !item.transparent ? item.getVideo() : nil
                    if let current = strongSelf.videoNode, current !== videoNode {
                        current.removeFromSupernode()
                        strongSelf.videoReadyDisposable.set(nil)
                    }
                    
                    let videoNodeUpdated = strongSelf.videoNode !== videoNode
                    strongSelf.videoNode = videoNode
                    
                    let nonExtractedRect: CGRect
                    let avatarFrame: CGRect
                    let titleFrame: CGRect
                    let animationSize: CGSize
                    let animationFrame: CGRect
                    let animationScale: CGFloat
                    
                    switch item.style {
                        case .list:
                            nonExtractedRect = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: CGSize(width: layout.contentSize.width - 32.0, height: layout.contentSize.height))
                            avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 8.0, y: floorToScreenPixels((layout.contentSize.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
                            animationSize = CGSize(width: 36.0, height: 36.0)
                            animationScale = 1.0
                            animationFrame = CGRect(x: params.width - animationSize.width - 6.0 - params.rightInset, y: floor((layout.contentSize.height - animationSize.height) / 2.0) + 1.0, width: animationSize.width, height: animationSize.height)
                            titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset + verticalOffset), size: titleLayout.size)
                        case let .tile(isLandscape):
                            nonExtractedRect = CGRect(origin: CGPoint(), size: layout.contentSize)
                            strongSelf.containerNode.transform = CATransform3DMakeRotation(isLandscape ? 0.0 : CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                            strongSelf.statusNode.isHidden = true
                            strongSelf.expandedStatusNode.isHidden = true
                            avatarFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - avatarSize) / 2.0), y: 13.0), size: CGSize(width: avatarSize, height: avatarSize))
                            
                            let textWidth: CGFloat = 24.0 + titleLayout.size.width
                            let textOrigin: CGFloat = floor((layout.size.width - textWidth) / 2.0) - 4.0
                            animationSize = CGSize(width: 36.0, height: 36.0)
                            animationScale = 0.66667
                            animationFrame = CGRect(x: textOrigin, y: 53.0, width: 24.0, height: 24.0)
                            titleFrame = CGRect(origin: CGPoint(x: textOrigin + 24.0, y: 61.0), size: titleLayout.size)
                    }
                                    
                    var extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                    var extractedHeight = extractedRect.height + expandedStatusLayout.size.height - statusLayout.size.height
                    var extractedVerticalOffset: CGFloat = 0.0
                    if item.peer.smallProfileImage != nil || strongSelf.videoNode != nil {
                        extractedVerticalOffset = extractedRect.width
                        extractedHeight += extractedVerticalOffset
                    }

                    extractedRect.size.height = extractedHeight
                    
                    strongSelf.extractedVerticalOffset = extractedVerticalOffset
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    if strongSelf.isExtracted {
                        var extractedRect = extractedRect
                        if !extractedVerticalOffset.isZero {
                            extractedRect = CGRect(x: extractedRect.minX, y: extractedRect.minY + extractedVerticalOffset, width: extractedRect.width, height: extractedRect.height - extractedVerticalOffset)
                        }
                        strongSelf.backgroundImageNode.frame = extractedRect
                    } else {
                        strongSelf.backgroundImageNode.frame = nonExtractedRect
                    }
                    if case .tile = item.style, strongSelf.backgroundImageNode.image == nil {
                        strongSelf.backgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: UIColor(rgb: 0x1c1c1e))
                        strongSelf.backgroundImageNode.alpha = 1.0
                    }
                    strongSelf.extractedBackgroundImageNode.frame = strongSelf.backgroundImageNode.bounds
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    
                    let contentBounds = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.frame = contentBounds
                    strongSelf.contextSourceNode.frame = contentBounds
                    strongSelf.contentWrapperNode.frame = contentBounds
                    strongSelf.offsetContainerNode.frame = contentBounds
                    strongSelf.contextSourceNode.contentNode.frame = contentBounds
                    strongSelf.actionContainerNode.frame = contentBounds
                    strongSelf.borderImageNode.frame = contentBounds
                    
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                        
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    var combinedValueString = ""
                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
                        combinedValueString.append(statusString)
                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.bottomStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
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
                    
                    if updatedTitle, let snapshotView = strongSelf.titleNode.view.snapshotContentTree() {
                        strongSelf.titleNode.view.superview?.insertSubview(snapshotView, aboveSubview: strongSelf.titleNode.view)

                        if item.transparent {
                            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -20.0), duration: 0.2, removeOnCompletion: false, additive: true)
                            strongSelf.titleNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 20.0), to: CGPoint(), duration: 0.2, additive: true)
                        }

                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                        strongSelf.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    
                    if let animateStatusTransitionFromUp = animateStatusTransitionFromUp, !strongSelf.contextSourceNode.isExtractedToContextPreview {
                        let offset: CGFloat = animateStatusTransitionFromUp ? -7.0 : 7.0
                        if let snapshotView = strongSelf.statusNode.view.snapshotContentTree() {
                            strongSelf.statusNode.view.superview?.insertSubview(snapshotView, belowSubview: strongSelf.statusNode.view)

                            snapshotView.frame = strongSelf.statusNode.frame
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -offset), duration: 0.2, removeOnCompletion: false, additive: true)
                            
                            strongSelf.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            strongSelf.statusNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.2, additive: true)
                        }
                    }
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = expandedStatusApply()
                                        
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 0)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 1)
                    }

                    strongSelf.topStripeNode.isHidden = first || item.style != .list || item.transparent
                    strongSelf.bottomStripeNode.isHidden = last || item.style != .list || item.transparent
                 
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height + -separatorHeight), size: CGSize(width: layoutSize.width - leftInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                    transition.updateFrame(node: strongSelf.expandedStatusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: expandedStatusLayout.size))
                    
                    if let currentCredibilityIconImage = currentCredibilityIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.credibilityIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.offsetContainerNode.addSubnode(iconNode)
                            strongSelf.credibilityIconNode = iconNode
                        }
                        iconNode.image = currentCredibilityIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + 3.0, y: verticalInset + credibilityIconOffset), size: currentCredibilityIconImage.size))
                    } else if let credibilityIconNode = strongSelf.credibilityIconNode {
                        strongSelf.credibilityIconNode = nil
                        credibilityIconNode.removeFromSupernode()
                    }
                    
                    transition.updateFrameAsPositionAndBounds(node: strongSelf.avatarNode, frame: avatarFrame)
                    
                    let blobFrame = avatarFrame.insetBy(dx: -14.0, dy: -14.0)
                    if let getAudioLevel = item.getAudioLevel {
                        if !strongSelf.didSetupAudioLevel || currentItem?.peer.id != item.peer.id {
                            strongSelf.audioLevelView?.frame = blobFrame
                            strongSelf.didSetupAudioLevel = true
                            strongSelf.audioLevelDisposable.set((getAudioLevel()
                            |> deliverOnMainQueue).start(next: { value in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                if strongSelf.audioLevelView == nil, value > 0.0 {
                                    let audioLevelView = VoiceBlobView(
                                        frame: blobFrame,
                                        maxLevel: 1.5,
                                        smallBlobRange: (0, 0),
                                        mediumBlobRange: (0.69, 0.87),
                                        bigBlobRange: (0.71, 1.0)
                                    )
                                    
                                    let maskRect = CGRect(origin: .zero, size: blobFrame.size)
                                    let playbackMaskLayer = CAShapeLayer()
                                    playbackMaskLayer.frame = maskRect
                                    playbackMaskLayer.fillRule = .evenOdd
                                    let maskPath = UIBezierPath()
                                    maskPath.append(UIBezierPath(roundedRect: maskRect.insetBy(dx: 14, dy: 14), cornerRadius: 22))
                                    maskPath.append(UIBezierPath(rect: maskRect))
                                    playbackMaskLayer.path = maskPath.cgPath
                                    audioLevelView.layer.mask = playbackMaskLayer
                                    
                                    audioLevelView.setColor(wavesColor)
                                    audioLevelView.alpha = strongSelf.isExtracted || (strongSelf.item?.transparent == true) ? 0.0 : 1.0
                                    
                                    strongSelf.audioLevelView = audioLevelView
                                    strongSelf.offsetContainerNode.view.insertSubview(audioLevelView, at: 0)
                                }
                                
                                let level = min(1.0, max(0.0, CGFloat(value)))
                                if let audioLevelView = strongSelf.audioLevelView {
                                    audioLevelView.updateLevel(CGFloat(value))
                                    
                                    let avatarScale: CGFloat
                                    if value > 0.0 {
                                        audioLevelView.startAnimating()
                                        avatarScale = 1.03 + level * 0.13
                                        if let wavesColor = strongSelf.wavesColor {
                                            audioLevelView.setColor(wavesColor, animated: true)
                                        }
                                    } else {
                                        audioLevelView.stopAnimating(duration: 0.5)
                                        avatarScale = 1.0
                                    }
                                    
                                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                                    transition.updateTransformScale(node: strongSelf.avatarNode, scale: strongSelf.isExtracted ? 1.0 : avatarScale, beginWithCurrentState: true)
                                }
                            }))
                        }
                    } else if let audioLevelView = strongSelf.audioLevelView {
                        strongSelf.audioLevelView = nil
                        audioLevelView.removeFromSuperview()
                        
                        strongSelf.audioLevelDisposable.set(nil)
                    }
                    
                    var overrideImage: AvatarNodeImageOverride?
                    if item.peer.isDeleted {
                        overrideImage = .deletedIcon
                    }
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: item.peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad, storeUnrounded: true)
                
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    var hadMicrophoneNode = false
                    var hadRaiseHandNode = false
                    var hadIconNode = false
                    var nodeToAnimateIn: ASDisplayNode?
                    
                    if case let .microphone(muted, color) = item.icon {
                        let animationNode: VoiceChatMicrophoneNode
                        if let current = strongSelf.animationNode {
                            animationNode = current
                        } else {
                            animationNode = VoiceChatMicrophoneNode()
                            strongSelf.animationNode = animationNode
                            strongSelf.actionButtonNode.addSubnode(animationNode)
                            
                            nodeToAnimateIn = animationNode
                        }
                        var color = color
                        if item.transparent {
                            color = UIColor(rgb: 0xffffff)
                        } else if color.rgb == 0x979797 && item.style != .list {
                            color = UIColor(rgb: 0xffffff)
                        }
                        animationNode.alpha = item.transparent && item.style == .list ? 0.65 : 1.0
                        animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: false, color: color), animated: true)
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let animationNode = strongSelf.animationNode {
                        hadMicrophoneNode = true
                        strongSelf.animationNode = nil
                        animationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        animationNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak animationNode] _ in
                            animationNode?.removeFromSupernode()
                        })
                    }
                    
                    if case .wantsToSpeak = item.icon {
                        let raiseHandNode: VoiceChatRaiseHandNode
                        if let current = strongSelf.raiseHandNode {
                            raiseHandNode = current
                        } else {
                            raiseHandNode = VoiceChatRaiseHandNode(color: item.presentationData.theme.list.itemAccentColor)
                            raiseHandNode.contentMode = .center
                            strongSelf.raiseHandNode = raiseHandNode
                            strongSelf.actionButtonNode.addSubnode(raiseHandNode)
                            
                            nodeToAnimateIn = raiseHandNode
                            raiseHandNode.playRandomAnimation()
                            
                            strongSelf.raiseHandTimer = SwiftSignalKit.Timer(timeout: Double.random(in: 8.0 ... 10.5), repeat: true, completion: {
                                self?.raiseHandNode?.playRandomAnimation()
                            }, queue: Queue.mainQueue())
                            strongSelf.raiseHandTimer?.start()
                        }
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let raiseHandNode = strongSelf.raiseHandNode {
                        hadRaiseHandNode = true
                        strongSelf.raiseHandNode = nil
                        if let raiseHandTimer = strongSelf.raiseHandTimer {
                            strongSelf.raiseHandTimer = nil
                            raiseHandTimer.invalidate()
                        }
                        raiseHandNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        raiseHandNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak raiseHandNode] _ in
                            raiseHandNode?.removeFromSupernode()
                        })
                    }
                    
                    if case let .invite(invited) = item.icon {
                        let iconNode: ASImageNode
                        if let current = strongSelf.iconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.contentMode = .center
                            strongSelf.iconNode = iconNode
                            strongSelf.actionButtonNode.addSubnode(iconNode)
                            
                            nodeToAnimateIn = iconNode
                        }
                        
                        if invited {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Invited"), color: UIColor(rgb: 0x979797))
                        } else {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: item.presentationData.theme.list.itemAccentColor)
                        }
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let iconNode = strongSelf.iconNode {
                        hadIconNode = true
                        strongSelf.iconNode = nil
                        iconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        iconNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak iconNode] _ in
                            iconNode?.removeFromSupernode()
                        })
                    }
                    
                    if let node = nodeToAnimateIn, hadMicrophoneNode || hadRaiseHandNode || hadIconNode {
                        node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        node.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    }
                    
                    if !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                        strongSelf.videoFadeNode.frame = CGRect(x: 0.0, y: tileSize.height - 30.0, width: tileSize.width, height: 30.0)
                        strongSelf.videoContainerNode.bounds = CGRect(origin: CGPoint(), size: tileSize)
                        switch item.style {
                            case .list:
                                strongSelf.videoFadeNode.alpha = 0.0
                                strongSelf.videoContainerNode.position = strongSelf.avatarNode.position
                                strongSelf.videoContainerNode.cornerRadius = tileSize.width / 2.0
                                strongSelf.videoContainerNode.transform = CATransform3DMakeScale(avatarSize / tileSize.width, avatarSize / tileSize.width, 1.0)
                            case .tile:
                                strongSelf.videoFadeNode.alpha = 1.0
                                strongSelf.videoContainerNode.position = CGPoint(x: tileSize.width / 2.0, y: tileSize.height / 2.0)
                                strongSelf.videoContainerNode.cornerRadius = backgroundCornerRadius
                                strongSelf.videoContainerNode.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
                        }
                    }
                    
                    strongSelf.borderImageNode.isHidden = !item.pinned || item.style == .list
                    
                    if let videoNode = videoNode {
                        if case .tile = item.style, !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                            if currentItem != nil {
                                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                                if item.pinned {
                                    transition.updateAlpha(node: videoNode, alpha: 0.0)
                                    transition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 0.0)
                                    strongSelf.videoContainerNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2)
                                    transition.updateAlpha(node: strongSelf.avatarNode, alpha: 1.0)
                                    strongSelf.avatarNode.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2)
                                } else {
                                    transition.updateAlpha(node: videoNode, alpha: 1.0)
                                    transition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 1.0)
                                    strongSelf.videoContainerNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                                    transition.updateAlpha(node: strongSelf.avatarNode, alpha: 0.0)
                                    strongSelf.avatarNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2)
                                }
                            } else {
                                if item.pinned {
                                    videoNode.alpha = 0.0
                                    strongSelf.avatarNode.alpha = 1.0
                                } else {
                                    videoNode.alpha = 1.0
                                    strongSelf.avatarNode.alpha = 0.0
                                }
                            }
                        }
                        
                        videoNode.updateLayout(size: videoSize, isLandscape: false, transition: .immediate)
                        if !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                            if videoNode.supernode !== strongSelf.videoContainerNode {
                                videoNode.clipsToBounds = true
                                strongSelf.videoContainerNode.addSubnode(videoNode)
                            }
                            
                            videoNode.position = CGPoint(x: videoSize.width / 2.0, y: videoSize.height / 2.0)
                            videoNode.bounds = CGRect(origin: CGPoint(), size: videoSize)
                        }
                    
                        if videoNodeUpdated {
                            strongSelf.videoReadyDelayed = false
                            strongSelf.videoReadyDisposable.set((videoNode.ready
                            |> deliverOnMainQueue).start(next: { [weak self] ready in
                                if let strongSelf = self {
                                    if !ready {
                                        strongSelf.videoReadyDelayed = true
                                    }
                                    if let videoNode = strongSelf.videoNode, ready && (strongSelf.item?.transparent != true) {
                                        if strongSelf.videoReadyDelayed {
                                            Queue.mainQueue().after(0.15) {
                                                switch item.style {
                                                    case .list:
                                                        strongSelf.avatarNode.alpha = 0.0
                                                        strongSelf.avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                                                    case .tile:
                                                        if item.pinned {
                                                            strongSelf.avatarNode.alpha = 1.0
                                                            videoNode.alpha = 0.0
                                                        } else {
                                                            strongSelf.avatarNode.alpha = 0.0
                                                            strongSelf.avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                                                            videoNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                                                            videoNode.alpha = 0.0
                                                        }
                                                }
                                            }
                                        } else {
                                            if case .tile = item.style, item.pinned {
                                                strongSelf.avatarNode.alpha = 1.0
                                            } else {
                                                strongSelf.avatarNode.alpha = 0.0
                                            }
                                        }
                                    }
                                }
                            }))
                        }
                    } else {
                        strongSelf.avatarNode.alpha = 1.0
                    }
                    
                    if item.style == .list {
                        strongSelf.audioLevelView?.alpha = item.transparent ? 0.0 : 0.0
                        strongSelf.avatarNode.isHidden = item.transparent
                        strongSelf.videoContainerNode.isHidden = item.transparent
                        strongSelf.pinIconNode.isHidden = !item.transparent
                    } else {
                        strongSelf.pinIconNode.isHidden = true
                        strongSelf.videoContainerNode.isHidden = item.transparent
                        if item.transparent {
                            strongSelf.avatarNode.alpha = 1.0
                        }
                    }
                    if let image = strongSelf.pinIconNode.image {
                        strongSelf.pinIconNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 17.0), size: image.size)
                    }
                    
                    strongSelf.iconNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.animationNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.raiseHandNode?.frame = CGRect(origin: CGPoint(), size: animationSize).insetBy(dx: -6.0, dy: -6.0).offsetBy(dx: -2.0, dy: 0.0)
                    
                    strongSelf.actionButtonNode.transform = CATransform3DMakeScale(animationScale, animationScale, 1.0)
//                    strongSelf.actionButtonNode.frame = animationFrame
                    transition.updateFrame(node: strongSelf.actionButtonNode, frame: animationFrame)
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    strongSelf.updateIsHighlighted(transition: transition)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.revealed ?? false, animated: animated)
                }
            })
        }
    }
    
    var isHighlighted = false
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        guard let item = self.item else {
            return
        }
        switch item.style {
            case .list:
                if self.isHighlighted {
                    self.highlightedBackgroundNode.alpha = 1.0
                    if self.highlightedBackgroundNode.supernode == nil {
                        var anchorNode: ASDisplayNode?
                        if self.bottomStripeNode.supernode != nil {
                            anchorNode = self.bottomStripeNode
                        } else if self.topStripeNode.supernode != nil {
                            anchorNode = self.topStripeNode
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
            case .tile:
                break
//                if self.isHighlighted {
//                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
//                    transition.updateSublayerTransformScale(node: self, scale: 0.9)
//                } else {
//                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
//                    transition.updateSublayerTransformScale(node: self, scale: 1.0)
//                }
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
             
        self.isHighlighted = highlighted
            
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func header() -> ListViewItemHeader? {
        return nil
    }
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
    }
    
    @objc private func actionButtonPressed() {
        if let item = self.layoutParams?.0, let contextAction = item.contextAction {
            contextAction(self.contextSourceNode, nil)
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let _ = self.layoutParams?.0, let params = self.layoutParams?.1 {
            let leftInset: CGFloat = 65.0 + params.leftInset
                        
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = offset + leftInset - 50.0
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var statusFrame = self.statusNode.frame
            let previousStatusFrame = statusFrame
            statusFrame.origin.x = leftInset + offset
            self.statusNode.frame = statusFrame
            transition.animatePositionAdditive(node: self.statusNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.layoutParams?.0 {
            item.setPeerIdWithRevealedOptions(item.peer.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.layoutParams?.0 {
            item.setPeerIdWithRevealedOptions(nil, item.peer.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.layoutParams?.0 {
            item.revealOptions[Int(option.key)].action()
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
