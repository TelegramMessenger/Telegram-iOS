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
import PeerInfoAvatarListNode
import ContextUI

private let backgroundCornerRadius: CGFloat = 14.0

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

    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode

    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    private var extractedVerticalOffset: CGFloat?
    
    fileprivate let avatarNode: AvatarNode
    private let contentWrapperNode: ASDisplayNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let expandedSubtitleNode: TextNode
    private let dateNode: TextNode
    private let measureAddNode: TextNode
    private let addButton: SolidRoundedButtonNode
    private let dismissButton: HighlightableButtonNode
    
    private var avatarTransitionNode: ASImageNode?
    private var avatarListContainerNode: ASDisplayNode?
    private var avatarListWrapperNode: PinchSourceContainerNode?
    private var avatarListNode: PeerInfoAvatarListContainerNode?
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var layoutParams: (ItemListInviteRequestItem, ListViewItemLayoutParams, ItemListNeighbors, Bool, Bool)?
    
    public var tag: ItemListItemTag?
    
    private var isExtracted = false
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
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
        
        self.expandedSubtitleNode = TextNode()
        self.expandedSubtitleNode.alpha = 0.0
        self.expandedSubtitleNode.isUserInteractionEnabled = false
        self.expandedSubtitleNode.contentMode = .left
        self.expandedSubtitleNode.contentsScale = UIScreen.main.scale
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.contentMode = .left
        self.dateNode.contentsScale = UIScreen.main.scale
        
        self.measureAddNode = TextNode()
        
        self.addButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), fontSize: 15.0, height: 32.0, cornerRadius: 16.0)
        self.dismissButton = HighlightableButtonNode()
            
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.contentWrapperNode = ASDisplayNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        
        self.offsetContainerNode.addSubnode(self.contentWrapperNode)
        self.contentWrapperNode.addSubnode(self.avatarNode)
        self.contentWrapperNode.addSubnode(self.titleNode)
        self.contentWrapperNode.addSubnode(self.subtitleNode)
        self.contentWrapperNode.addSubnode(self.expandedSubtitleNode)
        self.contentWrapperNode.addSubnode(self.dateNode)
        self.contentWrapperNode.addSubnode(self.addButton)
        self.contentWrapperNode.addSubnode(self.dismissButton)
        
        self.addButton.pressed = { [weak self] in
            if let (item, _, _, _, _) = self?.layoutParams {
                item.addAction?()
            }
        }
        self.dismissButton.addTarget(self, action: #selector(self.dismissPressed), forControlEvents: .touchUpInside)
        
        self.containerNode.shouldBegin = { [weak self] point in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0 else {
                return false
            }
            if item.importer == nil || strongSelf.addButton.frame.contains(point) || strongSelf.dismissButton.frame.contains(point)  {
                return false
            }
            return true
        }
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let _ = item.importer, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture)
        }

        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let peer = item.importer?.peer.peer else {
                return
            }
            
            strongSelf.isExtracted = isExtracted
            
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
                        rect = CGRect(x: extractedRect.minX - 16.0, y: extractedRect.minY + extractedVerticalOffset, width: extractedRect.width, height: extractedRect.height - extractedVerticalOffset)
                    } else {
                        rect = extractedRect
                    }
                } else {
                    rect = nonExtractedRect
                }
                
                let springDuration: Double = isExtracted ? 0.42 : 0.3
                let springDamping: CGFloat = isExtracted ? 124.0 : 1000.0
                
                let itemBackgroundColor: UIColor
                switch item.style {
                    case .plain:
                        itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    case .blocks:
                        itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                }
                                
                if !extractedVerticalOffset.isZero {
                    let radiusTransition = ContainedViewLayoutTransition.animated(duration: 0.15, curve: .easeInOut)
                    if isExtracted {
                        strongSelf.extractedBackgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
                            let bounds = CGRect(origin: CGPoint(), size: size)
                            context.clear(bounds)
                            
                            context.setFillColor(itemBackgroundColor.cgColor)
                            context.fillEllipse(in: bounds)
                            context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
                        })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
                                              
                        strongSelf.avatarNode.transform = CATransform3DIdentity
                        var avatarInitialRect = strongSelf.avatarNode.view.convert(strongSelf.avatarNode.bounds, to: strongSelf.offsetContainerNode.supernode?.view)
                        if strongSelf.avatarTransitionNode == nil {
                            let targetRect = CGRect(x: extractedRect.minX - 16.0, y: extractedRect.minY, width: extractedRect.width, height: extractedRect.width)
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
                            avatarListNode.peer = peer
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
                            
                            avatarListNode.update(size: targetRect.size, peer: peer, customNode: nil, additionalEntry: .single(nil), isExpanded: true, transition: .immediate)
                            strongSelf.offsetContainerNode.supernode?.addSubnode(avatarListWrapperNode)
                            
                            strongSelf.avatarListWrapperNode = avatarListWrapperNode
                            strongSelf.avatarListContainerNode = avatarListContainerNode
                            strongSelf.avatarListNode = avatarListNode
                        }
                    } else if let transitionNode = strongSelf.avatarTransitionNode, let avatarListWrapperNode = strongSelf.avatarListWrapperNode, let avatarListContainerNode = strongSelf.avatarListContainerNode {
                        
                        var avatarInitialRect = CGRect(origin: strongSelf.avatarNode.frame.origin, size: strongSelf.avatarNode.frame.size)
                        let targetScale = avatarInitialRect.width / avatarListContainerNode.frame.width
                        avatarInitialRect.origin.y += backgroundCornerRadius / 2.0 * targetScale
                        
                        strongSelf.avatarTransitionNode = nil
                        strongSelf.avatarListWrapperNode = nil
                        strongSelf.avatarListContainerNode = nil
                        strongSelf.avatarListNode = nil
                        
                        avatarListContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak avatarListContainerNode, weak avatarListWrapperNode] _ in
                            avatarListContainerNode?.removeFromSupernode()
                            avatarListWrapperNode?.removeFromSupernode()
                        })
                                                
                        avatarListWrapperNode.layer.animate(from: 1.0 as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
                        avatarListWrapperNode.layer.animate(from: NSValue(cgPoint: avatarListWrapperNode.position), to: NSValue(cgPoint: avatarInitialRect.center), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak transitionNode, weak self] _ in
                            transitionNode?.removeFromSupernode()
                            self?.avatarNode.isHidden = false
                        })
    
                        radiusTransition.updateCornerRadius(node: avatarListContainerNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
                        radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: avatarListContainerNode.frame.width / 2.0)
                    }
                    
                    let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    alphaTransition.updateAlpha(node: strongSelf.subtitleNode, alpha: isExtracted ? 0.0 : 1.0)
                    alphaTransition.updateAlpha(node: strongSelf.expandedSubtitleNode, alpha: isExtracted ? 1.0 : 0.0)
                    alphaTransition.updateAlpha(node: strongSelf.dateNode, alpha: isExtracted ? 0.0 : 1.0)
                    alphaTransition.updateAlpha(node: strongSelf.addButton, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
                    alphaTransition.updateAlpha(node: strongSelf.dismissButton, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
                    
                    var sublayerOffset: CGFloat = -64.0
                    if item.style == .plain {
                        sublayerOffset += 16.0
                    }
                    
                    let offsetInitialSublayerTransform = strongSelf.offsetContainerNode.layer.sublayerTransform
                    strongSelf.offsetContainerNode.layer.sublayerTransform = CATransform3DMakeTranslation(isExtracted ? sublayerOffset : 0.0, isExtracted ? extractedVerticalOffset : 0.0, 0.0)
                    
                    let initialExtractedBackgroundPosition = strongSelf.extractedBackgroundImageNode.position
                    strongSelf.extractedBackgroundImageNode.layer.position = rect.center
                    let initialExtractedBackgroundBounds = strongSelf.extractedBackgroundImageNode.bounds
                    strongSelf.extractedBackgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: rect.size)
                    if isExtracted {
                        strongSelf.offsetContainerNode.layer.animateSpring(from: NSValue(caTransform3D: offsetInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.offsetContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.extractedBackgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialExtractedBackgroundPosition), to: NSValue(cgPoint: strongSelf.extractedBackgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
                        strongSelf.extractedBackgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialExtractedBackgroundBounds), to: NSValue(cgRect: strongSelf.extractedBackgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                    } else {
                        strongSelf.offsetContainerNode.layer.animate(from: NSValue(caTransform3D: offsetInitialSublayerTransform), to: NSValue(caTransform3D: strongSelf.offsetContainerNode.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.extractedBackgroundImageNode.layer.animate(from: NSValue(cgPoint: initialExtractedBackgroundPosition), to: NSValue(cgPoint: strongSelf.extractedBackgroundImageNode.position), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        strongSelf.extractedBackgroundImageNode.layer.animate(from: NSValue(cgRect: initialExtractedBackgroundBounds), to: NSValue(cgRect: strongSelf.extractedBackgroundImageNode.bounds), keyPath: "bounds", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                    }

                    if isExtracted {
                        strongSelf.extractedBackgroundImageNode.alpha = 1.0
                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                    } else {
                        strongSelf.extractedBackgroundImageNode.alpha = 0.0
                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            if let strongSelf = self {
                                strongSelf.extractedBackgroundImageNode.image = nil
                                strongSelf.extractedBackgroundImageNode.layer.removeAllAnimations()
                            }
                        })
                    }
                } else {
                    if isExtracted {
                        strongSelf.extractedBackgroundImageNode.alpha = 1.0
                        strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: item.presentationData.theme.list.itemBlocksBackgroundColor)
                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                    } else {
                        strongSelf.extractedBackgroundImageNode.alpha = 0.0
                        strongSelf.extractedBackgroundImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            if let strongSelf = self {
                                strongSelf.extractedBackgroundImageNode.image = nil
                                strongSelf.extractedBackgroundImageNode.layer.removeAllAnimations()
                            }
                        })
                    }
                    
                    transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: CGRect(origin: CGPoint(), size: rect.size))
                    
                    transition.updateAlpha(node: strongSelf.subtitleNode, alpha: isExtracted ? 0.0 : 1.0)
                    transition.updateAlpha(node: strongSelf.expandedSubtitleNode, alpha: isExtracted ? 1.0 : 0.0)
                    transition.updateAlpha(node: strongSelf.dateNode, alpha: isExtracted ? 0.0 : 1.0)
                    
                    transition.updateAlpha(node: strongSelf.addButton, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
                    transition.updateAlpha(node: strongSelf.dismissButton, alpha: isExtracted ? 0.0 : 1.0, delay: isExtracted ? 0.0 : 0.1)
                    
                    var sublayerOffset: CGFloat = -16.0
                    if item.style == .plain {
                        sublayerOffset += 16.0
                    }
                    
                    transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? sublayerOffset : 0.0, y: 0.0))
                }
            }
        }
    }
    
    public func asyncLayout() -> (_ item: ItemListInviteRequestItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors, _ firstWithHeader: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeExpandedSubtitleLayout = TextNode.asyncLayout(self.expandedSubtitleNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        let makeMeasureAddLayout = TextNode.asyncLayout(self.measureAddNode)
        
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
            var expandedSubtitleText: String
            var dateText: String
          
            if let importer = item.importer, let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                titleText = peer.displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder)
                subtitleText = importer.about ?? ""
                expandedSubtitleText = importer.about ?? " "
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: importer.date, relativeTo: timestamp, dateTimeFormat: item.dateTimeFormat)
            } else {
                titleText = " "
                subtitleText = " "
                expandedSubtitleText = " "
                dateText = " "
            }
            
            let titleAttributedString = NSAttributedString(string: titleText, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let subtitleAttributedString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            let expnadedSubtitleAttributedString = NSAttributedString(string: expandedSubtitleText, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            let dateAttributedString = NSAttributedString(string: dateText, font: subtitleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 62.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let verticalInset: CGFloat = 9.0
           
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 44.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var expandedMaxWidth = params.width - leftInset - rightInset
            if item.style == .plain {
                expandedMaxWidth -= 32.0
            }
            let (expandedSubtitleLayout, expandedSubtitleApply) = makeExpandedSubtitleLayout(TextNodeLayoutArguments(attributedString: expnadedSubtitleAttributedString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: expandedMaxWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let addButtonTitle = item.isGroup ? item.presentationData.strings.MemberRequests_AddToGroup : item.presentationData.strings.MemberRequests_AddToChannel
            
            let (measureAddLayout, _) = makeMeasureAddLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: addButtonTitle, font: Font.semibold(15.0), textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
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
                    insets.top = 0.0
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
                    strongSelf.contentWrapperNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                    
                    var nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height))
                    if case .blocks = item.style {
                        nonExtractedRect = nonExtractedRect.inset(by: UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset))
                    }
                    var extractedRect: CGRect
                    if case .blocks = item.style {
                        extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: params.leftInset, dy: 0.0)
                    } else {
                        extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: params.leftInset + 16.0, dy: 0.0)
                    }
                    var extractedHeight = extractedRect.height + expandedSubtitleLayout.size.height - subtitleLayout.size.height
                    var extractedVerticalOffset: CGFloat = 0.0
                    if item.importer?.peer.peer?.smallProfileImage != nil {
                        extractedRect.size.width = min(extractedRect.width, params.availableHeight - 20.0)
                        extractedVerticalOffset = extractedRect.width
                        extractedHeight += extractedVerticalOffset
                    } else {
                        nonExtractedRect.size.width += 16.0
                        extractedHeight = max(108.0, extractedHeight)
                    }
                    
                    extractedRect.size.height = extractedHeight - 46.0
                    
                    strongSelf.extractedVerticalOffset = extractedVerticalOffset
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
                    let _ = expandedSubtitleApply()
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
                    
                    let avatarSize: CGSize = CGSize(width: 40.0, height: 40.0)
                    let avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 9.0, y: verticalInset + 2.0), size: avatarSize)
                    strongSelf.avatarNode.frame = avatarFrame
                    
                    if let importer = item.importer, let peer = importer.peer.peer.flatMap({ EnginePeer($0) }) {
                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: nil, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: false, storeUnrounded: true)
                    }
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.subtitleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: subtitleLayout.size))
                    transition.updateFrame(node: strongSelf.expandedSubtitleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: expandedSubtitleLayout.size))
                    transition.updateFrame(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: params.width - rightInset - dateLayout.size.width, y: verticalInset + 2.0), size: dateLayout.size))
                                        
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.addButton.title = addButtonTitle
                    if let _ = updatedTheme {
                        strongSelf.addButton.updateTheme(SolidRoundedButtonTheme(theme: item.presentationData.theme))
                    }
                    strongSelf.dismissButton.setTitle(item.presentationData.strings.MemberRequests_Dismiss, with: Font.bold(15.0), with: item.presentationData.theme.list.itemAccentColor, for: .normal)
                    
                    let addWidth = measureAddLayout.size.width + 24.0
                    let addHeight = strongSelf.addButton.updateLayout(width: addWidth, transition: .immediate)
                    let addButtonFrame = CGRect(x: leftInset, y: contentSize.height - addHeight - 12.0, width: addWidth, height: addHeight)
                    strongSelf.addButton.frame = addButtonFrame
                    
                    let dismissSize = strongSelf.dismissButton.measure(layout.size)
                    strongSelf.dismissButton.frame = CGRect(origin: CGPoint(x: leftInset + addWidth + 24.0, y: verticalInset + contentSize.height - addHeight - 14.0), size: dismissSize)
                    
                    if item.importer == nil {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            if strongSelf.bottomStripeNode.supernode != nil {
                                strongSelf.bottomStripeNode.removeFromSupernode()
                                strongSelf.addSubnode(strongSelf.bottomStripeNode)
                                strongSelf.insertSubnode(shimmerNode, belowSubnode: strongSelf.bottomStripeNode)
                            } else {
                                strongSelf.addSubnode(shimmerNode)
                            }
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }
                        
                        var shapes: [ShimmerEffectNode.Shape] = []
                        
                        let titleLineWidth: CGFloat = 120.0
                        let subtitleLineWidth: CGFloat = 180.0
                        let dateLineWidth: CGFloat = 35.0
                        let lineDiameter: CGFloat = 10.0
                        
                        let iconFrame = strongSelf.avatarNode.frame
                        shapes.append(.circle(iconFrame))
                        
                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                        
                        let subtitleFrame = strongSelf.subtitleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: subtitleFrame.minX, y: subtitleFrame.minY + floor((subtitleFrame.height - lineDiameter) / 2.0)), width: subtitleLineWidth, diameter: lineDiameter))
                        
                        let dateFrame = strongSelf.dateNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: dateFrame.maxX - dateLineWidth, y: dateFrame.minY + floor((dateFrame.height - lineDiameter) / 2.0)), width: dateLineWidth, diameter: lineDiameter))

                        let addFrame = strongSelf.addButton.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: addFrame.minX, y: addFrame.minY + floor((addFrame.height - addFrame.height) / 2.0)), width: addFrame.width, diameter: addFrame.height))
                        
                        let dismissFrame = strongSelf.dismissButton.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: dismissFrame.minX, y: dismissFrame.minY + floor((dismissFrame.height - lineDiameter) / 2.0)), width: 60.0, diameter: lineDiameter))
                        
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
