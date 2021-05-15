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

private let avatarFont = avatarPlaceholderFont(size: floor(50.0 * 16.0 / 37.0))
private let tileSize = CGSize(width: 84.0, height: 84.0)
private let backgroundCornerRadius: CGFloat = 11.0
private let videoCornerRadius: CGFloat = 23.0
private let avatarSize: CGFloat = 50.0
private let videoSize = CGSize(width: 180.0, height: 180.0)

private let accentColor: UIColor = UIColor(rgb: 0x007aff)
private let constructiveColor: UIColor = UIColor(rgb: 0x34c759)
private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

private let borderLineWidth: CGFloat = 2.0
private let borderImage = generateImage(CGSize(width: tileSize.width, height: tileSize.height), rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    context.setLineWidth(borderLineWidth)
    context.setStrokeColor(constructiveColor.cgColor)
    
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

final class VoiceChatFullscreenParticipantItem: ListViewItem {
    enum Icon {
        case none
        case microphone(Bool, UIColor)
        case invite(Bool)
        case wantsToSpeak
    }
    
    enum Color {
        case generic
        case accent
        case constructive
        case destructive
    }
    
    let presentationData: ItemListPresentationData
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: Peer
    let icon: Icon
    let color: Color
    let isLandscape: Bool
    let active: Bool
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    let getVideo: () -> GroupVideoNode?
    let action: ((ASDisplayNode?) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let getUpdatingAvatar: () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>
    
    public let selectable: Bool = true
    
    public init(presentationData: ItemListPresentationData, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, icon: Icon, color: Color, isLandscape: Bool, active: Bool, getAudioLevel: (() -> Signal<Float, NoError>)?, getVideo: @escaping () -> GroupVideoNode?, action: ((ASDisplayNode?) -> Void)?, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil, getUpdatingAvatar: @escaping () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>) {
        self.presentationData = presentationData
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.icon = icon
        self.color = color
        self.isLandscape = isLandscape
        self.active = active
        self.getAudioLevel = getAudioLevel
        self.getVideo = getVideo
        self.action = action
        self.contextAction = contextAction
        self.getUpdatingAvatar = getUpdatingAvatar
    }
        
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatFullscreenParticipantItemNode()
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
            if let nodeValue = node() as? VoiceChatFullscreenParticipantItemNode {
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

class VoiceChatFullscreenParticipantItemNode: ItemListRevealOptionsItemNode {
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    let backgroundImageNode: ASImageNode
    private let extractedBackgroundImageNode: ASImageNode
    let offsetContainerNode: ASDisplayNode
    let borderImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    private var extractedVerticalOffset: CGFloat?
        
    let avatarNode: AvatarNode
    let contentWrapperNode: ASDisplayNode
    private let titleNode: TextNode
    private var credibilityIconNode: ASImageNode?
        
    private let actionContainerNode: ASDisplayNode
    private var animationNode: VoiceChatMicrophoneNode?
    private var iconNode: ASImageNode?
    private var raiseHandNode: VoiceChatRaiseHandNode?
    private var actionButtonNode: HighlightableButtonNode
    
    private var audioLevelView: VoiceBlobView?
    private let audioLevelDisposable = MetaDisposable()
    private var didSetupAudioLevel = false
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var layoutParams: (VoiceChatFullscreenParticipantItem, ListViewItemLayoutParams, Bool, Bool)?
    private var isExtracted = false
    private var animatingExtraction = false
    private var wavesColor: UIColor?
    
    let videoContainerNode: ASDisplayNode
    private let videoFadeNode: ASImageNode
    var videoNode: GroupVideoNode?
    private let videoReadyDisposable = MetaDisposable()
    private var videoReadyDelayed = false
    private var videoReady = false
    
    private var raiseHandTimer: SwiftSignalKit.Timer?
    
    var item: VoiceChatFullscreenParticipantItem? {
        return self.layoutParams?.0
    }
    
    private var currentTitle: String?
    
    init() {
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
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: avatarSize, height: avatarSize))
        
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
    
        self.actionContainerNode = ASDisplayNode()
        self.actionButtonNode = HighlightableButtonNode()
        
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
        self.contentWrapperNode.addSubnode(self.actionContainerNode)
        self.actionContainerNode.addSubnode(self.actionButtonNode)
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.contextSourceNode.contentNode.addSubnode(self.borderImageNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
                
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
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
        
//        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
//            guard let strongSelf = self, let item = strongSelf.layoutParams?.0 else {
//                return
//            }
//
//            strongSelf.isExtracted = isExtracted
//
//            let inset: CGFloat = 12.0
////            if isExtracted {
////                strongSelf.contextSourceNode.contentNode.customHitTest = { [weak self] point in
////                    if let strongSelf = self {
////                        if let avatarListWrapperNode = strongSelf.avatarListWrapperNode, avatarListWrapperNode.frame.contains(point) {
////                            return strongSelf.avatarListNode?.view
////                        }
////                    }
////                    return nil
////                }
////            } else {
////                strongSelf.contextSourceNode.contentNode.customHitTest = nil
////            }
//
//            let extractedVerticalOffset = strongSelf.extractedVerticalOffset ?? 0.0
//            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
//                let rect: CGRect
//                if isExtracted {
//                    if extractedVerticalOffset > 0.0 {
//                        rect = CGRect(x: extractedRect.minX, y: extractedRect.minY + extractedVerticalOffset, width: extractedRect.width, height: extractedRect.height - extractedVerticalOffset)
//                    } else {
//                        rect = extractedRect
//                    }
//                } else {
//                    rect = nonExtractedRect
//                }
//
//                let springDuration: Double = isExtracted ? 0.42 : 0.3
//                let springDamping: CGFloat = isExtracted ? 104.0 : 1000.0
//
//                let itemBackgroundColor: UIColor = item.getIsExpanded() ? UIColor(rgb: 0x1c1c1e) : UIColor(rgb: 0x2c2c2e)
//
//                if !extractedVerticalOffset.isZero {
//                    let radiusTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
//                    if isExtracted {
//                        strongSelf.backgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
//                            let bounds = CGRect(origin: CGPoint(), size: size)
//                            context.clear(bounds)
//
//                            context.setFillColor(itemBackgroundColor.cgColor)
//                            context.fillEllipse(in: bounds)
//                            context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
//                        })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
//                        strongSelf.extractedBackgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
//                            let bounds = CGRect(origin: CGPoint(), size: size)
//                            context.clear(bounds)
//
//                            context.setFillColor(item.presentationData.theme.list.itemBlocksBackgroundColor.cgColor)
//                            context.fillEllipse(in: bounds)
//                            context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
//                        })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
//                        strongSelf.backgroundImageNode.cornerRadius = backgroundCornerRadius
//
//                        strongSelf.avatarNode.transform = CATransform3DIdentity
//                        var avatarInitialRect = strongSelf.avatarNode.view.convert(strongSelf.avatarNode.bounds, to: strongSelf.offsetContainerNode.supernode?.view)
//                        if strongSelf.avatarTransitionNode == nil {
//                            transition.updateCornerRadius(node: strongSelf.backgroundImageNode, cornerRadius: 0.0)
//
//                            let targetRect = CGRect(x: extractedRect.minX, y: extractedRect.minY, width: extractedRect.width, height: extractedRect.width)
//                            let initialScale = avatarInitialRect.width / targetRect.width
//                            avatarInitialRect.origin.y += backgroundCornerRadius / 2.0 * initialScale
//
//                            let avatarListWrapperNode = PinchSourceContainerNode()
//                            avatarListWrapperNode.clipsToBounds = true
//                            avatarListWrapperNode.cornerRadius = backgroundCornerRadius
//                            avatarListWrapperNode.activate = { [weak self] sourceNode in
//                                guard let strongSelf = self else {
//                                    return
//                                }
//                                strongSelf.avatarListNode?.controlsContainerNode.alpha = 0.0
//                                let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
//                                    return UIScreen.main.bounds
//                                })
//                                item.context.sharedContext.mainWindow?.presentInGlobalOverlay(pinchController)
//                            }
//                            avatarListWrapperNode.deactivated = { [weak self] in
//                                guard let strongSelf = self else {
//                                    return
//                                }
//                                strongSelf.avatarListWrapperNode?.contentNode.layer.animate(from: 0.0 as NSNumber, to: backgroundCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3, completion: { _ in
//                                })
//                            }
//                            avatarListWrapperNode.update(size: targetRect.size, transition: .immediate)
//                            avatarListWrapperNode.frame = CGRect(x: targetRect.minX, y: targetRect.minY, width: targetRect.width, height: targetRect.height + backgroundCornerRadius)
//                            avatarListWrapperNode.animatedOut = { [weak self] in
//                                guard let strongSelf = self else {
//                                    return
//                                }
//                                strongSelf.avatarListNode?.controlsContainerNode.alpha = 1.0
//                                strongSelf.avatarListNode?.controlsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
//                            }
//
//                            let transitionNode = ASImageNode()
//                            transitionNode.clipsToBounds = true
//                            transitionNode.displaysAsynchronously = false
//                            transitionNode.displayWithoutProcessing = true
//                            transitionNode.image = strongSelf.avatarNode.unroundedImage
//                            transitionNode.frame = CGRect(origin: CGPoint(), size: targetRect.size)
//                            transitionNode.cornerRadius = targetRect.width / 2.0
//                            radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: 0.0)
//
//                            strongSelf.avatarNode.isHidden = true
//                            avatarListWrapperNode.contentNode.addSubnode(transitionNode)
//
//                            strongSelf.videoContainerNode.position = CGPoint(x: avatarListWrapperNode.frame.width / 2.0, y: avatarListWrapperNode.frame.height / 2.0)
//                            strongSelf.videoContainerNode.cornerRadius = tileSize.width / 2.0
//                            strongSelf.videoContainerNode.transform = CATransform3DMakeScale(avatarListWrapperNode.frame.width / tileSize.width * 1.05, avatarListWrapperNode.frame.height / tileSize.width * 1.05, 1.0)
//                            avatarListWrapperNode.contentNode.addSubnode(strongSelf.videoContainerNode)
//
//                            strongSelf.avatarTransitionNode = transitionNode
//
//                            let avatarListContainerNode = ASDisplayNode()
//                            avatarListContainerNode.clipsToBounds = true
//                            avatarListContainerNode.frame = CGRect(origin: CGPoint(), size: targetRect.size)
//                            avatarListContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
//                            avatarListContainerNode.cornerRadius = targetRect.width / 2.0
//
//                            avatarListWrapperNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
//                            avatarListWrapperNode.layer.animateSpring(from: NSValue(cgPoint: avatarInitialRect.center), to: NSValue(cgPoint: avatarListWrapperNode.position), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, completion: { [weak self] _ in
//                                if let strongSelf = self, let avatarListNode = strongSelf.avatarListNode {
//                                    avatarListNode.currentItemNode?.addSubnode(strongSelf.videoContainerNode)
//                                }
//                            })
//
//                            radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: 0.0)
//                            radiusTransition.updateCornerRadius(node: strongSelf.videoContainerNode, cornerRadius: 0.0)
//
//                            let avatarListNode = PeerInfoAvatarListContainerNode(context: item.context)
//                            avatarListWrapperNode.contentNode.clipsToBounds = true
//                            avatarListNode.backgroundColor = .clear
//                            avatarListNode.peer = item.peer
//                            avatarListNode.firstFullSizeOnly = true
//                            avatarListNode.offsetLocation = true
//                            avatarListNode.customCenterTapAction = { [weak self] in
//                                self?.contextSourceNode.requestDismiss?()
//                            }
//                            avatarListNode.frame = CGRect(x: targetRect.width / 2.0, y: targetRect.height / 2.0, width: targetRect.width, height: targetRect.height)
//                            avatarListNode.controlsClippingNode.frame = CGRect(x: -targetRect.width / 2.0, y: -targetRect.height / 2.0, width: targetRect.width, height: targetRect.height)
//                            avatarListNode.controlsClippingOffsetNode.frame = CGRect(origin: CGPoint(x: targetRect.width / 2.0, y: targetRect.height / 2.0), size: CGSize())
//                            avatarListNode.stripContainerNode.frame = CGRect(x: 0.0, y: 13.0, width: targetRect.width, height: 2.0)
//
//                            avatarListContainerNode.addSubnode(avatarListNode)
//                            avatarListContainerNode.addSubnode(avatarListNode.controlsClippingOffsetNode)
//                            avatarListWrapperNode.contentNode.addSubnode(avatarListContainerNode)
//
//                            avatarListNode.update(size: targetRect.size, peer: item.peer, customNode: strongSelf.videoContainerNode, additionalEntry: item.getUpdatingAvatar(), isExpanded: true, transition: .immediate)
//                            strongSelf.offsetContainerNode.supernode?.addSubnode(avatarListWrapperNode)
//
//                            strongSelf.audioLevelView?.alpha = 0.0
//
//                            strongSelf.avatarListWrapperNode = avatarListWrapperNode
//                            strongSelf.avatarListContainerNode = avatarListContainerNode
//                            strongSelf.avatarListNode = avatarListNode
//                        }
//                    } else if let transitionNode = strongSelf.avatarTransitionNode, let avatarListWrapperNode = strongSelf.avatarListWrapperNode, let avatarListContainerNode = strongSelf.avatarListContainerNode {
//                        strongSelf.animatingExtraction = true
//
//                        transition.updateCornerRadius(node: strongSelf.backgroundImageNode, cornerRadius: backgroundCornerRadius)
//
//                        var avatarInitialRect = CGRect(origin: strongSelf.avatarNode.frame.origin, size: strongSelf.avatarNode.frame.size)
//                        let targetScale = avatarInitialRect.width / avatarListContainerNode.frame.width
//                        avatarInitialRect.origin.y += backgroundCornerRadius / 2.0 * targetScale
//
//                        strongSelf.avatarTransitionNode = nil
//                        strongSelf.avatarListWrapperNode = nil
//                        strongSelf.avatarListContainerNode = nil
//                        strongSelf.avatarListNode = nil
//
//                        avatarListContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak avatarListContainerNode] _ in
//                            avatarListContainerNode?.removeFromSupernode()
//                        })
//
//                        avatarListWrapperNode.contentNode.insertSubnode(strongSelf.videoContainerNode, aboveSubnode: transitionNode)
//
//                        avatarListWrapperNode.layer.animate(from: 1.0 as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
//                        avatarListWrapperNode.layer.animate(from: NSValue(cgPoint: avatarListWrapperNode.position), to: NSValue(cgPoint: avatarInitialRect.center), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionNode, weak self] _ in
//                            transitionNode?.removeFromSupernode()
//                            self?.avatarNode.isHidden = false
//
//                            self?.audioLevelView?.alpha = 1.0
//                            self?.audioLevelView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
//
//                            if let strongSelf = self {
//                                strongSelf.animatingExtraction = false
//
//                                strongSelf.offsetContainerNode.insertSubnode(strongSelf.videoContainerNode, belowSubnode: strongSelf.contentWrapperNode)
//
//                                switch item.style {
//                                    case .list:
//                                        strongSelf.videoFadeNode.alpha = 0.0
//                                        strongSelf.videoContainerNode.position = strongSelf.avatarNode.position
//                                        strongSelf.videoContainerNode.cornerRadius = tileSize.width / 2.0
//                                        strongSelf.videoContainerNode.transform = CATransform3DMakeScale(avatarSize / tileSize.width, avatarSize / tileSize.width, 1.0)
//                                    case .tile:
//                                        strongSelf.videoFadeNode.alpha = 1.0
//                                        strongSelf.videoContainerNode.position = CGPoint(x: tileSize.width / 2.0, y: tileSize.height / 2.0)
//                                        strongSelf.videoContainerNode.cornerRadius = backgroundCornerRadius
//                                        strongSelf.videoContainerNode.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
//                                }
//                            }
//                        })
//
//                        radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
//                        radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
//                        radiusTransition.updateCornerRadius(node: strongSelf.videoContainerNode, cornerRadius: tileSize.width / 2.0)
//                    }
//
//                    let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
//                    alphaTransition.updateAlpha(node: strongSelf.statusNode, alpha: isExtracted ? 0.0 : 1.0)
//                    alphaTransition.updateAlpha(node: strongSelf.expandedStatusNode, alpha: isExtracted ? 1.0 : 0.0)
//                    alphaTransition.updateAlpha(node: strongSelf.actionContainerNode, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
//
//                    let offsetInitialSublayerTransform = strongSelf.offsetContainerNode.layer.sublayerTransform
//                    strongSelf.offsetContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? -33 : 0.0, isExtracted ? extractedVerticalOffset : 0.0, 0.0)
//
//                    let actionInitialSublayerTransform = strongSelf.actionContainerNode.layer.sublayerTransform
//                    strongSelf.actionContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? 21.0 : 0.0, 0.0, 0.0)
//
//                    let initialBackgroundPosition = strongSelf.backgroundImageNode.position
//                    strongSelf.backgroundImageNode.layer.position = rect.center
//                    let initialBackgroundBounds = strongSelf.backgroundImageNode.bounds
//                    strongSelf.backgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: rect.size)
//
//                    let initialExtractedBackgroundPosition = strongSelf.extractedBackgroundImageNode.position
//                    strongSelf.extractedBackgroundImageNode.layer.position = CGPoint(x: rect.size.width / 2.0, y: rect.size.height / 2.0)
//                    let initialExtractedBackgroundBounds = strongSelf.extractedBackgroundImageNode.bounds
//                    strongSelf.extractedBackgroundImageNode.layer.bounds = strongSelf.backgroundImageNode.layer.bounds
//                    if isExtracted {
//                        strongSelf.offsetContainerNode.layer.animateSpring(from: NSValue(caTransform3D: offsetInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.offsetContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
//                        strongSelf.actionContainerNode.layer.animateSpring(from: NSValue(caTransform3D: actionInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.actionContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
//                        strongSelf.backgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: strongSelf.backgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
//                        strongSelf.backgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: strongSelf.backgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
//                        strongSelf.extractedBackgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialExtractedBackgroundPosition), to: NSValue(cgPoint: strongSelf.extractedBackgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
//                        strongSelf.extractedBackgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialExtractedBackgroundBounds), to: NSValue(cgRect: strongSelf.extractedBackgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
//                    } else {
//                        strongSelf.offsetContainerNode.layer.animate(from: NSValue(caTransform3D: offsetInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.offsetContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
//                        strongSelf.actionContainerNode.layer.animate(from: NSValue(caTransform3D: actionInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.actionContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
//                        strongSelf.backgroundImageNode.layer.animate(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: strongSelf.backgroundImageNode.position), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
//                        strongSelf.backgroundImageNode.layer.animate(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: strongSelf.backgroundImageNode.bounds), keyPath: "bounds", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
//                        strongSelf.extractedBackgroundImageNode.layer.animate(from: NSValue(cgPoint: initialExtractedBackgroundPosition), to: NSValue(cgPoint: strongSelf.extractedBackgroundImageNode.position), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
//                        strongSelf.extractedBackgroundImageNode.layer.animate(from: NSValue(cgRect: initialExtractedBackgroundBounds), to: NSValue(cgRect: strongSelf.extractedBackgroundImageNode.bounds), keyPath: "bounds", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
//                    }
//
//                    if isExtracted {
//                        strongSelf.backgroundImageNode.alpha = 1.0
//                        strongSelf.extractedBackgroundImageNode.alpha = 1.0
//                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
//                    } else {
//                        strongSelf.extractedBackgroundImageNode.alpha = 0.0
//                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
//                            if let strongSelf = self {
//                                if strongSelf.item?.style == .list {
//                                    strongSelf.backgroundImageNode.image = nil
//                                }
//                                strongSelf.extractedBackgroundImageNode.image = nil
//                                strongSelf.extractedBackgroundImageNode.layer.removeAllAnimations()
//                            }
//                        })
//                    }
//                } else {
//                    if isExtracted {
//                        strongSelf.backgroundImageNode.alpha = 0.0
//                        strongSelf.extractedBackgroundImageNode.alpha = 1.0
//                        strongSelf.backgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: itemBackgroundColor)
//                        strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: item.presentationData.theme.list.itemBlocksBackgroundColor)
//                    }
//
//                    transition.updateFrame(node: strongSelf.backgroundImageNode, frame: rect)
//                    transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: CGRect(origin: CGPoint(), size: rect.size))
//
//                    transition.updateAlpha(node: strongSelf.statusNode, alpha: isExtracted ? 0.0 : 1.0)
//                    transition.updateAlpha(node: strongSelf.expandedStatusNode, alpha: isExtracted ? 1.0 : 0.0)
//                    transition.updateAlpha(node: strongSelf.actionContainerNode, alpha: isExtracted ? 0.0 : 1.0)
//
//                    transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? inset : 0.0, y: isExtracted ? extractedVerticalOffset : 0.0))
//                    transition.updateSublayerTransformOffset(layer: strongSelf.actionContainerNode.layer, offset: CGPoint(x: isExtracted ? -24.0 : 0.0, y: 0.0))
//
//                    transition.updateAlpha(node: strongSelf.backgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
//                        if !isExtracted {
//                            self?.backgroundImageNode.image = nil
//                            self?.extractedBackgroundImageNode.image = nil
//                        }
//                    })
//                }
//            }
//        }
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
    
    func animateTransitionIn(from sourceNode: ASDisplayNode, containerNode: ASDisplayNode, animate: Bool = true) {
        guard let item = self.item else {
            return
        }
        
        let initialAnimate = animate
        if let sourceNode = sourceNode as? VoiceChatTileItemNode {
            var startContainerPosition = sourceNode.view.convert(sourceNode.bounds, to: containerNode.view).center
            var animate = initialAnimate
            if startContainerPosition.y > containerNode.frame.height - 238.0 {
                animate = false
            }
            
            if let videoNode = sourceNode.videoNode {
                if item.active {
                    self.avatarNode.alpha = 1.0
                    videoNode.alpha = 0.0
                    startContainerPosition = startContainerPosition.offsetBy(dx: 0.0, dy: 9.0)
                } else {
                    self.avatarNode.alpha = 0.0
                }
            
                sourceNode.videoNode = nil
                self.videoNode = videoNode
                self.videoContainerNode.insertSubnode(videoNode, at: 0)
 
                if animate {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    videoNode.updateLayout(size: videoSize, isLandscape: true, transition: transition)
                     
                    let scale = sourceNode.bounds.width / videoSize.width
                    self.videoContainerNode.layer.animateScale(from: sourceNode.bounds.width / videoSize.width, to: tileSize.width / videoSize.width, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    self.videoContainerNode.layer.animate(from: backgroundCornerRadius * (1.0 / scale) as NSNumber, to: videoCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    })
                    
                    self.videoFadeNode.alpha = 1.0
                    self.videoFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                } else if initialAnimate {
                    videoNode.updateLayout(size: videoSize, isLandscape: true, transition: .immediate)
                    self.videoFadeNode.alpha = 1.0
                }
            }
            
            if animate {
                let initialPosition = self.contextSourceNode.position
                let targetContainerPosition = self.contextSourceNode.view.convert(self.contextSourceNode.bounds, to: containerNode.view).center

                self.contextSourceNode.position = targetContainerPosition
                containerNode.addSubnode(self.contextSourceNode)

                self.contextSourceNode.layer.animatePosition(from: startContainerPosition, to: targetContainerPosition, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.contextSourceNode.position = initialPosition
                        strongSelf.containerNode.addSubnode(strongSelf.contextSourceNode)
                    }
                })

                if item.active {
                    self.borderImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.borderImageNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                }

                self.backgroundImageNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.backgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.contentWrapperNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.contentWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            } else if !initialAnimate {
                self.contextSourceNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.contextSourceNode.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else if let sourceNode = sourceNode as? VoiceChatParticipantItemNode, let _ = sourceNode.item {
            var startContainerPosition = sourceNode.avatarNode.view.convert(sourceNode.avatarNode.bounds, to: containerNode.view).center
            var animate = true
            if startContainerPosition.y > containerNode.frame.height - 238.0 {
                animate = false
            }
            startContainerPosition = startContainerPosition.offsetBy(dx: 0.0, dy: 9.0)

            if animate {
                sourceNode.avatarNode.alpha = 0.0

                let initialPosition = self.contextSourceNode.position
                let targetContainerPosition = self.contextSourceNode.view.convert(self.contextSourceNode.bounds, to: containerNode.view).center

                self.contextSourceNode.position = targetContainerPosition
                containerNode.addSubnode(self.contextSourceNode)

                let timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
                self.contextSourceNode.layer.animatePosition(from: startContainerPosition, to: targetContainerPosition, duration: 0.2, timingFunction: timingFunction, completion: { [weak self, weak sourceNode] _ in
                    if let strongSelf = self {
                        sourceNode?.avatarNode.alpha = 1.0
                        strongSelf.contextSourceNode.position = initialPosition
                        strongSelf.containerNode.addSubnode(strongSelf.contextSourceNode)
                    }
                })

                if item.active {
                    self.borderImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.borderImageNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, timingFunction: timingFunction)
                }
                
                self.avatarNode.layer.animateScale(from: 0.8, to: 1.0, duration: 0.2)

                self.backgroundImageNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, timingFunction: timingFunction)
                self.backgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, timingFunction: timingFunction)
                self.contentWrapperNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2, timingFunction: timingFunction)
                self.contentWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, timingFunction: timingFunction)
            }
        }
    }
        
    func asyncLayout() -> (_ item: VoiceChatFullscreenParticipantItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.layoutParams?.0
        let hasVideo = self.videoNode != nil
        
        return { item, params, first, last in
            let titleFont = Font.semibold(12.0)
            var titleAttributedString: NSAttributedString?
            
            var titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            if !hasVideo || item.active {
                switch item.color {
                    case .generic:
                        titleColor = item.presentationData.theme.list.itemPrimaryTextColor
                    case .accent:
                        titleColor = item.presentationData.theme.list.itemAccentColor
                    case .constructive:
                        titleColor = constructiveColor
                    case .destructive:
                        titleColor = destructiveColor
                }
            }
            let currentBoldFont: UIFont = titleFont
            
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
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
            
            var wavesColor = UIColor(rgb: 0x34c759)
            switch item.color {
                case .accent:
                    wavesColor = accentColor
                case .destructive:
                    wavesColor = destructiveColor
                default:
                    break
            }

            let leftInset: CGFloat = 58.0 + params.leftInset
            
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
                      
            let constrainedWidth = params.width - 24.0 - 10.0
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        
            let contentSize = tileSize
            let insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: !last ? 6.0 : 0.0, right: 0.0)
                            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
                        
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    let hadItem = strongSelf.layoutParams?.0 != nil
                    strongSelf.layoutParams = (item, params, first, last)
                    strongSelf.currentTitle = titleAttributedString?.string
                    strongSelf.wavesColor = wavesColor
                    
                    let videoNode = item.getVideo()
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
                    
                    nonExtractedRect = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.transform = CATransform3DMakeRotation(item.isLandscape ? 0.0 : CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    avatarFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - avatarSize) / 2.0), y: 7.0), size: CGSize(width: avatarSize, height: avatarSize))
                    
                    animationSize = CGSize(width: 36.0, height: 36.0)
                    animationScale = 0.66667
                    animationFrame = CGRect(x: layout.size.width - 29.0, y: 54.0, width: 24.0, height: 24.0)
                    titleFrame = CGRect(origin: CGPoint(x: 8.0, y: 63.0), size: titleLayout.size)
                                    
                    var extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                    var extractedHeight = extractedRect.height
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
                    if strongSelf.backgroundImageNode.image == nil {
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
//                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
//                        combinedValueString.append(statusString)
//                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                                        
                    let transition: ContainedViewLayoutTransition
                    if animated && hadItem {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    } else {
                        transition = .immediate
                    }
                                                            
                    let _ = titleApply()               
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                
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
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + 3.0, y: credibilityIconOffset), size: currentCredibilityIconImage.size))
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
                                    audioLevelView.alpha = strongSelf.isExtracted ? 0.0 : 1.0
                                    
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
                        if color.rgb == 0x979797 {
                            color = UIColor(rgb: 0xffffff)
                        }
                        animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: color), animated: true)
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
                    
                    let videoContainerScale = tileSize.width / videoSize.width
                    
                    if !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                        strongSelf.videoFadeNode.frame = CGRect(x: 0.0, y: videoSize.height - 75.0, width: videoSize.width, height: 75.0)
                        strongSelf.videoContainerNode.bounds = CGRect(origin: CGPoint(), size: videoSize)

                        if let videoNode = strongSelf.videoNode {
                            strongSelf.videoFadeNode.alpha = videoNode.alpha
                        } else {
                            strongSelf.videoFadeNode.alpha = 0.0
                        }
                        strongSelf.videoContainerNode.position = CGPoint(x: tileSize.width / 2.0, y: tileSize.height / 2.0)
                        strongSelf.videoContainerNode.cornerRadius = videoCornerRadius
                        strongSelf.videoContainerNode.transform = CATransform3DMakeScale(videoContainerScale, videoContainerScale, 1.0)
                    }
                    
                    strongSelf.borderImageNode.isHidden = !item.active
                    
                    let canUpdateAvatarVisibility = !strongSelf.isExtracted && !strongSelf.animatingExtraction
                    
                    if let videoNode = videoNode {
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                        if !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                            if currentItem != nil {
                                if item.active {
                                    if strongSelf.avatarNode.alpha.isZero {
                                        strongSelf.videoContainerNode.layer.animateScale(from: videoContainerScale, to: 0.001, duration: 0.2)
                                        strongSelf.avatarNode.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2)
                                        strongSelf.videoContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -9.0), duration: 0.2, additive: true)
                                    }
                                    transition.updateAlpha(node: videoNode, alpha: 0.0)
                                    transition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 0.0)
                                    transition.updateAlpha(node: strongSelf.avatarNode, alpha: 1.0)
                                } else {
                                    if !strongSelf.avatarNode.alpha.isZero {
                                        strongSelf.videoContainerNode.layer.animateScale(from: 0.001, to: videoContainerScale, duration: 0.2)
                                        strongSelf.avatarNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2)
                                        strongSelf.videoContainerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -9.0), to: CGPoint(), duration: 0.2, additive: true)
                                    }
                                    transition.updateAlpha(node: videoNode, alpha: 1.0)
                                    transition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 1.0)
                                    transition.updateAlpha(node: strongSelf.avatarNode, alpha: 0.0)
                                }
                            } else {
                                if item.active {
                                    videoNode.alpha = 0.0
                                    if canUpdateAvatarVisibility {
                                        strongSelf.avatarNode.alpha = 1.0
                                    }
                                } else if strongSelf.videoReady {
                                    videoNode.alpha = 1.0
                                    strongSelf.avatarNode.alpha = 0.0
                                }
                            }
                        }
                        
                        videoNode.updateLayout(size: videoSize, isLandscape: true, transition: .immediate)
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
                                    strongSelf.videoReady = ready
                                    if let videoNode = strongSelf.videoNode, ready {
                                        if strongSelf.videoReadyDelayed {
                                            Queue.mainQueue().after(0.15) {
                                                guard let currentItem = strongSelf.item else {
                                                    return
                                                }
                                                if currentItem.active {
                                                    if canUpdateAvatarVisibility {
                                                        strongSelf.avatarNode.alpha = 1.0
                                                    }
                                                    videoNode.alpha = 0.0
                                                } else {
                                                    strongSelf.avatarNode.alpha = 0.0
                                                    strongSelf.avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                                                    videoNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                                                    videoNode.alpha = 1.0
                                                }
                                            }
                                        } else {
                                            if item.active {
                                                if canUpdateAvatarVisibility {
                                                    strongSelf.avatarNode.alpha = 1.0
                                                }
                                                videoNode.alpha = 0.0
                                            } else {
                                                strongSelf.avatarNode.alpha = 0.0
                                                videoNode.alpha = 1.0
                                            }
                                        }
                                    }
                                }
                            }))
                        }
                    } else if canUpdateAvatarVisibility {
                        strongSelf.avatarNode.alpha = 1.0
                    }
                                        
                    strongSelf.iconNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.animationNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.raiseHandNode?.frame = CGRect(origin: CGPoint(), size: animationSize).insetBy(dx: -6.0, dy: -6.0).offsetBy(dx: -2.0, dy: 0.0)
                    
                    strongSelf.actionButtonNode.transform = CATransform3DMakeScale(animationScale, animationScale, 1.0)
//                    strongSelf.actionButtonNode.frame = animationFrame
                    transition.updateFrame(node: strongSelf.actionButtonNode, frame: animationFrame)
                                        
                    strongSelf.updateIsHighlighted(transition: transition)
                }
            })
        }
    }
    
    var isHighlighted = false
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {

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
}
