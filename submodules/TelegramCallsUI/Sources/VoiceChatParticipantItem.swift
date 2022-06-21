import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import ContextUI
import AccountContext
import LegacyComponents
import AudioBlob
import PeerInfoAvatarListNode

final class VoiceChatParticipantItem: ListViewItem {
    enum ParticipantText: Equatable {
        struct TextIcon: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public init() {
                self.rawValue = 0
            }
            
            public static let volume = TextIcon(rawValue: 1 << 0)
            public static let video = TextIcon(rawValue: 1 << 1)
            public static let screen = TextIcon(rawValue: 1 << 2)
        }
        
        enum TextColor {
            case generic
            case accent
            case constructive
            case destructive
        }
        
        case text(String, TextIcon, TextColor)
        case none
    }
    
    enum Icon {
        case none
        case microphone(Bool, UIColor)
        case invite(Bool)
        case wantsToSpeak
    }
    
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: Peer
    let text: ParticipantText
    let expandedText: ParticipantText?
    let icon: Icon
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    let action: ((ASDisplayNode?) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let getIsExpanded: () -> Bool
    let getUpdatingAvatar: () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>
    
    public let selectable: Bool = true
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, text: ParticipantText, expandedText: ParticipantText?, icon: Icon, getAudioLevel: (() -> Signal<Float, NoError>)?, action: ((ASDisplayNode?) -> Void)?, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil, getIsExpanded: @escaping () -> Bool, getUpdatingAvatar: @escaping () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.text = text
        self.expandedText = expandedText
        self.icon = icon
        self.getAudioLevel = getAudioLevel
        self.action = action
        self.contextAction = contextAction
        self.getIsExpanded = getIsExpanded
        self.getUpdatingAvatar = getUpdatingAvatar
    }
        
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatParticipantItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, previousItem == nil || previousItem is VoiceChatTilesGridItem, nextItem == nil)
            
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
                    let (layout, apply) = makeLayout(self, params, previousItem == nil || previousItem is VoiceChatTilesGridItem, nextItem == nil)
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

class VoiceChatParticipantStatusNode: ASDisplayNode {
    private var iconNodes: [ASImageNode]
    private let textNode: TextNode
    
    private var currentParams: (CGSize, VoiceChatParticipantItem.ParticipantText)?
    
    override init() {
        self.iconNodes = []
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (_ size: CGSize, _ text: VoiceChatParticipantItem.ParticipantText, _ expanded: Bool) -> (CGSize, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { size, text, expanded in
            let statusFont = Font.regular(14.0)
            
            var attributedString: NSAttributedString?
            var color: UIColor = .white
            var hasVolume = false
            var hasVideo = false
            var hasScreen = false
            switch text {
                case let .text(text, textIcon, textColor):
                    hasVolume = textIcon.contains(.volume)
                    hasVideo = textIcon.contains(.video)
                    hasScreen = textIcon.contains(.screen)
                    
                    var textColorValue: UIColor
                    switch textColor {
                    case .generic:
                        textColorValue = UIColor(rgb: 0x98989e)
                    case .accent:
                        textColorValue = accentColor
                    case .constructive:
                        textColorValue = constructiveColor
                    case .destructive:
                        textColorValue = destructiveColor
                    }
                    color = textColorValue
                    attributedString = NSAttributedString(string: text, font: statusFont, textColor: textColorValue)
                default:
                    break
            }
                        
            let iconSize = CGSize(width: 16.0, height: 16.0)
            let spacing: CGFloat = 3.0
            
            var icons: [UIImage] = []
            if hasVolume, let image = generateTintedImage(image: UIImage(bundleImageName: "Call/StatusVolume"), color: color) {
                icons.append(image)
            }
            if hasVideo, let image = generateTintedImage(image: UIImage(bundleImageName: "Call/StatusVideo"), color: color) {
                icons.append(image)
            }
            if hasScreen, let image = generateTintedImage(image: UIImage(bundleImageName: "Call/StatusScreen"), color: color) {
                icons.append(image)
            }
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: expanded ? 4 : 1, truncationType: .end, constrainedSize: CGSize(width: size.width - (iconSize.width + spacing) * CGFloat(icons.count), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            var contentSize = textLayout.size
            contentSize.width += (iconSize.width + spacing) * CGFloat(icons.count)
            
            return (contentSize, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.currentParams = (size, text)
                
                for i in 0 ..< icons.count {
                    let iconNode: ASImageNode
                    if strongSelf.iconNodes.count >= i + 1 {
                        iconNode = strongSelf.iconNodes[i]
                    } else {
                        iconNode = ASImageNode()
                        strongSelf.addSubnode(iconNode)
                        strongSelf.iconNodes.append(iconNode)
                    }
                    iconNode.frame = CGRect(origin: CGPoint(x: (iconSize.width + spacing) * CGFloat(i), y: 1.0), size: iconSize)
                    
                    iconNode.image = icons[i]
                }
                if strongSelf.iconNodes.count > icons.count {
                    for i in icons.count ..< strongSelf.iconNodes.count {
                        strongSelf.iconNodes[i].image = nil
                    }
                }
                
                
                let _ = textApply()
                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: (iconSize.width + spacing) * CGFloat(icons.count), y: 0.0), size: textLayout.size)
            })
        }
    }
}

class VoiceChatParticipantItemNode: ItemListRevealOptionsItemNode {
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightContainerNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let backgroundImageNode: ASImageNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    private var extractedVerticalOffset: CGFloat?
        
    let avatarNode: AvatarNode
    private let contentWrapperNode: ASDisplayNode
    private let titleNode: TextNode
    private let statusNode: VoiceChatParticipantStatusNode
    private let expandedStatusNode: VoiceChatParticipantStatusNode
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
    
    var audioLevelView: VoiceBlobView?
    private let audioLevelDisposable = MetaDisposable()
    private var didSetupAudioLevel = false
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var layoutParams: (VoiceChatParticipantItem, ListViewItemLayoutParams, Bool, Bool)?
    private var isExtracted = false
    private var animatingExtraction = false
    private var wavesColor: UIColor?
        
    private var raiseHandTimer: SwiftSignalKit.Timer?
    private var silenceTimer: SwiftSignalKit.Timer?
    
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

        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
        
        self.contentWrapperNode = ASDisplayNode()
   
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = VoiceChatParticipantStatusNode()
        self.statusNode.isUserInteractionEnabled = false
        
        self.expandedStatusNode = VoiceChatParticipantStatusNode()
        self.expandedStatusNode.isUserInteractionEnabled = false
        self.expandedStatusNode.alpha = 0.0
        
        self.actionContainerNode = ASDisplayNode()
        self.actionButtonNode = HighlightableButtonNode()
        
        self.highlightContainerNode = ASDisplayNode()
        self.highlightContainerNode.clipsToBounds = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.highlightContainerNode.addSubnode(self.highlightedBackgroundNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.backgroundImageNode)
        self.backgroundImageNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.contentWrapperNode)
        self.contentWrapperNode.addSubnode(self.titleNode)
        self.contentWrapperNode.addSubnode(self.statusNode)
        self.contentWrapperNode.addSubnode(self.expandedStatusNode)
        self.contentWrapperNode.addSubnode(self.actionContainerNode)
        self.actionContainerNode.addSubnode(self.actionButtonNode)
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        
        self.actionButtonNode.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
                
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
            
            let inset: CGFloat = 0.0
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
                let springDamping: CGFloat = isExtracted ? 124.0 : 1000.0
                
                let itemBackgroundColor: UIColor = item.getIsExpanded() ? UIColor(rgb: 0x1c1c1e) : UIColor(rgb: 0x2c2c2e)
                
                if !extractedVerticalOffset.isZero {
                    let radiusTransition = ContainedViewLayoutTransition.animated(duration: 0.15, curve: .easeInOut)
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
                            
                            strongSelf.avatarTransitionNode = transitionNode
    
                            let avatarListContainerNode = ASDisplayNode()
                            avatarListContainerNode.clipsToBounds = true
                            avatarListContainerNode.frame = CGRect(origin: CGPoint(), size: targetRect.size)
                            avatarListContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            avatarListContainerNode.cornerRadius = targetRect.width / 2.0
                            
                            avatarListWrapperNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                            avatarListWrapperNode.layer.animateSpring(from: NSValue(cgPoint: avatarInitialRect.center), to: NSValue(cgPoint: avatarListWrapperNode.position), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                            
                            radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: 0.0)
                            
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
                            avatarListNode.topShadowNode.frame = CGRect(x: 0.0, y: 0.0, width: targetRect.width, height: 44.0)
                            
                            avatarListContainerNode.addSubnode(avatarListNode)
                            avatarListContainerNode.addSubnode(avatarListNode.controlsClippingOffsetNode)
                            avatarListWrapperNode.contentNode.addSubnode(avatarListContainerNode)
                            
                            avatarListNode.update(size: targetRect.size, peer: item.peer, customNode: nil, additionalEntry: item.getUpdatingAvatar(), isExpanded: true, transition: .immediate)
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
                                                
                        avatarListWrapperNode.layer.animate(from: 1.0 as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
                        avatarListWrapperNode.layer.animate(from: NSValue(cgPoint: avatarListWrapperNode.position), to: NSValue(cgPoint: avatarInitialRect.center), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionNode, weak self] _ in
                            transitionNode?.removeFromSupernode()
                            self?.avatarNode.isHidden = false
                            
                            self?.audioLevelView?.alpha = 1.0
                            self?.audioLevelView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            
                            if let strongSelf = self {
                                strongSelf.animatingExtraction = false
                            }
                        })
    
                        radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
                        radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
                    }
                    
                    let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    alphaTransition.updateAlpha(node: strongSelf.statusNode, alpha: isExtracted ? 0.0 : 1.0)
                    alphaTransition.updateAlpha(node: strongSelf.expandedStatusNode, alpha: isExtracted ? 1.0 : 0.0)
                    alphaTransition.updateAlpha(node: strongSelf.actionContainerNode, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
                    
                    let offsetInitialSublayerTransform = strongSelf.offsetContainerNode.layer.sublayerTransform
                    strongSelf.offsetContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? -43 : 0.0, isExtracted ? extractedVerticalOffset : 0.0, 0.0)
                    
                    let actionInitialSublayerTransform = strongSelf.actionContainerNode.layer.sublayerTransform
                    strongSelf.actionContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? 43.0 : 0.0, 0.0, 0.0)
                    
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
                                strongSelf.backgroundImageNode.image = nil
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
                    transition.updateSublayerTransformOffset(layer: strongSelf.actionContainerNode.layer, offset: CGPoint(x: isExtracted ? -inset * 2.0 : 0.0, y: 0.0))
                    
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
        self.audioLevelDisposable.dispose()
        self.raiseHandTimer?.invalidate()
        self.silenceTimer?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.highlightContainerNode.layer.cornerCurve = .continuous
        }
    }
    
    override func selected() {
        super.selected()
        self.layoutParams?.0.action?(self.contextSourceNode)
    }
    
    func animateTransitionIn(from sourceNode: ASDisplayNode, containerNode: ASDisplayNode, transition: ContainedViewLayoutTransition) {
        guard let _ = self.item, let sourceNode = sourceNode as? VoiceChatFullscreenParticipantItemNode, let _ = sourceNode.item else {
            return
        }
        var duration: Double = 0.2
        var timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue
        if case let .animated(transitionDuration, curve) = transition {
            duration = transitionDuration + 0.08
            timingFunction = curve.timingFunction
        }
        
        let startContainerAvatarPosition = sourceNode.avatarNode.view.convert(sourceNode.avatarNode.bounds, to: containerNode.view).center
        var animate = true
        if containerNode.frame.width > containerNode.frame.height {
            if startContainerAvatarPosition.y < -tileSize.height * 2.0 || startContainerAvatarPosition.y > containerNode.frame.height + tileSize.height * 2.0 {
                animate = false
            }
        } else {
            if startContainerAvatarPosition.x < -tileSize.width * 4.0 || startContainerAvatarPosition.x > containerNode.frame.width + tileSize.width * 4.0 {
                animate = false
            }
        }
        if animate {
            sourceNode.avatarNode.alpha = 0.0
            sourceNode.audioLevelView?.alpha = 0.0
            
            let initialAvatarPosition = self.avatarNode.position
            let initialBackgroundPosition = sourceNode.backgroundImageNode.position
            let initialContentPosition = sourceNode.contentWrapperNode.position
            
            let startContainerBackgroundPosition = sourceNode.backgroundImageNode.view.convert(sourceNode.backgroundImageNode.bounds, to: containerNode.view).center
            let startContainerContentPosition = sourceNode.contentWrapperNode.view.convert(sourceNode.contentWrapperNode.bounds, to: containerNode.view).center

            let targetContainerAvatarPosition = self.avatarNode.view.convert(self.avatarNode.bounds, to: containerNode.view).center

            sourceNode.backgroundImageNode.position = targetContainerAvatarPosition
            sourceNode.contentWrapperNode.position = targetContainerAvatarPosition
            containerNode.addSubnode(sourceNode.backgroundImageNode)
            containerNode.addSubnode(sourceNode.contentWrapperNode)

            sourceNode.highlightNode.alpha = 0.0
            
            sourceNode.backgroundImageNode.layer.animatePosition(from: startContainerBackgroundPosition, to: targetContainerAvatarPosition, duration: duration, timingFunction: timingFunction, completion: { [weak sourceNode] _ in
                if let sourceNode = sourceNode {
                    Queue.mainQueue().after(0.1, {
                        sourceNode.backgroundImageNode.layer.removeAllAnimations()
                        sourceNode.contentWrapperNode.layer.removeAllAnimations()
                    })
                    sourceNode.backgroundImageNode.alpha = 1.0
                    sourceNode.highlightNode.alpha = 1.0
                    sourceNode.backgroundImageNode.position = initialBackgroundPosition
                    sourceNode.contextSourceNode.contentNode.insertSubnode(sourceNode.backgroundImageNode, at: 0)
                }
            })

            sourceNode.contentWrapperNode.layer.animatePosition(from: startContainerContentPosition, to: targetContainerAvatarPosition, duration: duration, timingFunction: timingFunction, completion: { [weak sourceNode] _ in
                if let sourceNode = sourceNode {
                    sourceNode.avatarNode.alpha = 1.0
                    sourceNode.audioLevelView?.alpha = 1.0
                    sourceNode.contentWrapperNode.position = initialContentPosition
                    sourceNode.offsetContainerNode.insertSubnode(sourceNode.contentWrapperNode, aboveSubnode: sourceNode.videoContainerNode)
                }
            })

            if let audioLevelView = self.audioLevelView {
                audioLevelView.center = targetContainerAvatarPosition
                containerNode.view.addSubview(audioLevelView)
                
                audioLevelView.layer.animateScale(from: 1.25, to: 1.0, duration: duration, timingFunction: timingFunction)
                audioLevelView.layer.animatePosition(from: startContainerAvatarPosition, to: targetContainerAvatarPosition, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
            }
            self.avatarNode.position = targetContainerAvatarPosition
            containerNode.addSubnode(self.avatarNode)
            
            self.avatarNode.layer.animateScale(from: 1.25, to: 1.0, duration: duration, timingFunction: timingFunction)
            self.avatarNode.layer.animatePosition(from: startContainerAvatarPosition, to: targetContainerAvatarPosition, duration: duration, timingFunction: timingFunction, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.avatarNode.position = initialAvatarPosition
                    strongSelf.offsetContainerNode.addSubnode(strongSelf.avatarNode)
                    if let audioLevelView = strongSelf.audioLevelView {
                        audioLevelView.layer.removeAllAnimations()
                        audioLevelView.center = initialAvatarPosition
                        strongSelf.offsetContainerNode.view.insertSubview(audioLevelView, at: 0)
                    }
                }
            })

            sourceNode.backgroundImageNode.layer.animateScale(from: 1.0, to: 0.001, duration: duration, timingFunction: timingFunction)
            sourceNode.backgroundImageNode.layer.animateAlpha(from: sourceNode.backgroundImageNode.alpha, to: 0.0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
            sourceNode.contentWrapperNode.layer.animateScale(from: 1.0, to: 0.001, duration: duration, timingFunction: timingFunction)
            sourceNode.contentWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        }
    }
        
    func asyncLayout() -> (_ item: VoiceChatParticipantItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = self.statusNode.asyncLayout()
        let makeExpandedStatusLayout = self.expandedStatusNode.asyncLayout()
        
        let currentItem = self.layoutParams?.0
        let currentTitle = self.currentTitle
        
        return { item, params, first, last in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
                        
            let titleFont = Font.regular(17.0)
            var titleAttributedString: NSAttributedString?
            let titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            
            let rightInset: CGFloat = params.rightInset
            
            var updatedTitle = false
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        switch item.nameDisplayOrder {
                            case .firstLast:
                                string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: lastName, font: titleFont, textColor: titleColor))
                            case .lastFirst:
                                string.append(NSAttributedString(string: lastName, font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        }
                        titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: titleFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: titleColor)
            }
            if let currentTitle = currentTitle, currentTitle != titleAttributedString?.string {
                updatedTitle = true
            }
            
            var wavesColor = UIColor(rgb: 0x34c759)
            if case let .text(_, _, textColor) = item.text {
                switch textColor {
                    case .accent:
                        wavesColor = accentColor
                    case .destructive:
                        wavesColor = destructiveColor
                    default:
                        break
                }
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
                              
            let constrainedWidth = params.width - leftInset - 12.0 - rightInset - 30.0 - titleIconsWidth
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let expandedWidth = min(params.width - leftInset - rightInset, params.availableHeight - 30.0)
            let (statusLayout, statusApply) = makeStatusLayout(CGSize(width: params.width - leftInset - 8.0 - rightInset - 30.0, height: CGFloat.greatestFiniteMagnitude), item.text, false)
            let (expandedStatusLayout, expandedStatusApply) = makeExpandedStatusLayout(CGSize(width: expandedWidth - 8.0 - expandedRightInset, height: CGFloat.greatestFiniteMagnitude), item.expandedText ?? item.text, params.availableHeight > params.width)
            
            let titleSpacing: CGFloat = statusLayout.height == 0.0 ? 0.0 : 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.height
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let insets = UIEdgeInsets()
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            var animateStatusTransitionFromUp: Bool?
            if let currentItem = currentItem {
                if case let .text(_, _, currentColor) = currentItem.text, case let .text(_, _, newColor) = item.text, currentColor != newColor {
                    animateStatusTransitionFromUp = newColor == .constructive
                }
            }
                        
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    let hadItem = strongSelf.layoutParams?.0 != nil
                    strongSelf.layoutParams = (item, params, first, last)
                    strongSelf.currentTitle = titleAttributedString?.string
                    strongSelf.wavesColor = wavesColor
                                    
                    let nonExtractedRect: CGRect
                    let avatarFrame: CGRect
                    let titleFrame: CGRect
                    let animationSize: CGSize
                    let animationFrame: CGRect
                    let animationScale: CGFloat
                    
                    nonExtractedRect = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: CGSize(width: layout.contentSize.width - 32.0, height: layout.contentSize.height))
                    avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 8.0, y: floorToScreenPixels((layout.contentSize.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
                    animationSize = CGSize(width: 36.0, height: 36.0)
                    animationScale = 1.0
                    animationFrame = CGRect(x: params.width - animationSize.width - 6.0 - params.rightInset, y: floor((layout.contentSize.height - animationSize.height) / 2.0) + 1.0, width: animationSize.width, height: animationSize.height)
                    titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset + verticalOffset), size: titleLayout.size)
                                       
                    var extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: params.leftInset, dy: 0.0)
                    var extractedHeight = extractedRect.height + expandedStatusLayout.height - statusLayout.height
                    var extractedVerticalOffset: CGFloat = 0.0
                    if item.peer.smallProfileImage != nil {
                        extractedRect.size.width = min(extractedRect.width, params.availableHeight - 20.0)
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
                    strongSelf.extractedBackgroundImageNode.frame = strongSelf.backgroundImageNode.bounds
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    
                    let contentBounds = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.frame = contentBounds
                    strongSelf.contextSourceNode.frame = contentBounds
                    strongSelf.contentWrapperNode.frame = contentBounds
                    strongSelf.offsetContainerNode.frame = contentBounds
                    strongSelf.contextSourceNode.contentNode.frame = contentBounds
                    strongSelf.actionContainerNode.frame = contentBounds
                    
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                        
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    let combinedValueString = ""
//                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
//                        combinedValueString.append(statusString)
//                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.bottomStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                                        
                    let transition: ContainedViewLayoutTransition
                    if animated && hadItem {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    } else {
                        transition = .immediate
                    }
                    
                    if updatedTitle, let snapshotView = strongSelf.titleNode.view.snapshotContentTree() {
                        strongSelf.titleNode.view.superview?.insertSubview(snapshotView, aboveSubview: strongSelf.titleNode.view)

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

                    strongSelf.topStripeNode.isHidden = first
                    strongSelf.bottomStripeNode.isHidden = last
                 
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height + -separatorHeight), size: CGSize(width: layoutSize.width - leftInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout))
                    transition.updateFrame(node: strongSelf.expandedStatusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: expandedStatusLayout))
                    
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
                                    audioLevelView.alpha = strongSelf.isExtracted ? 0.0 : 1.0
                                    
                                    strongSelf.audioLevelView = audioLevelView
                                    strongSelf.offsetContainerNode.view.insertSubview(audioLevelView, at: 0)
                                }
                                
                                let level = min(1.0, max(0.0, CGFloat(value)))
                                if let audioLevelView = strongSelf.audioLevelView {
                                    audioLevelView.updateLevel(CGFloat(value))
                                    
                                    let avatarScale: CGFloat
                                    if value > 0.02 {
                                        audioLevelView.startAnimating()
                                        avatarScale = 1.03 + level * 0.13
                                        if let wavesColor = strongSelf.wavesColor {
                                            audioLevelView.setColor(wavesColor, animated: true)
                                        }
                                        
                                        if let silenceTimer = strongSelf.silenceTimer {
                                            silenceTimer.invalidate()
                                            strongSelf.silenceTimer = nil
                                        }
                                    } else {
                                        avatarScale = 1.0
                                        if strongSelf.silenceTimer == nil {
                                            let silenceTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                                                self?.audioLevelView?.stopAnimating(duration: 0.75)
                                                self?.silenceTimer = nil
                                            }, queue: Queue.mainQueue())
                                            strongSelf.silenceTimer = silenceTimer
                                            silenceTimer.start()
                                        }
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
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(item.peer), overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad, storeUnrounded: true)
                
                    strongSelf.highlightContainerNode.frame = CGRect(origin: CGPoint(x: params.leftInset, y: -UIScreenPixel), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel + 11.0))
                    
                    strongSelf.highlightContainerNode.cornerRadius = first ? 11.0 : 0.0
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
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
                        animationNode.alpha = 1.0
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
                    
                    strongSelf.avatarNode.isHidden = strongSelf.isExtracted
                    
                    strongSelf.iconNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.animationNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.raiseHandNode?.frame = CGRect(origin: CGPoint(), size: animationSize).insetBy(dx: -6.0, dy: -6.0).offsetBy(dx: -2.0, dy: 0.0)
                    
                    strongSelf.actionButtonNode.transform = CATransform3DMakeScale(animationScale, animationScale, 1.0)
                    transition.updateFrame(node: strongSelf.actionButtonNode, frame: animationFrame)

                    strongSelf.updateIsHighlighted(transition: transition)
                }
            })
        }
    }
    
    var isHighlighted = false
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        if self.isHighlighted {
            self.highlightContainerNode.alpha = 1.0
            if self.highlightContainerNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightContainerNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightContainerNode)
                }
            }
        } else {
            if self.highlightContainerNode.supernode != nil {
                if transition.isAnimated {
                    self.highlightContainerNode.layer.animateAlpha(from: self.highlightContainerNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightContainerNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightContainerNode.alpha = 0.0
                } else {
                    self.highlightContainerNode.removeFromSupernode()
                }
            }
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
    
    override func headers() -> [ListViewItemHeader]? {
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
}
