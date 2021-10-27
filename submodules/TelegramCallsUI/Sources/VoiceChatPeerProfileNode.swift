import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import ContextUI
import AccountContext
import LegacyComponents
import PeerInfoAvatarListNode

private let backgroundCornerRadius: CGFloat = 14.0

final class VoiceChatPeerProfileNode: ASDisplayNode {
    private let context: AccountContext
    private let size: CGSize
    private var peer: Peer
    private var text: VoiceChatParticipantItem.ParticipantText
    private let customNode: ASDisplayNode?
    private let additionalEntry: Signal<(TelegramMediaImageRepresentation, Float)?, NoError>
    
    private let backgroundImageNode: ASImageNode
    private let avatarListContainerNode: ASDisplayNode
    let avatarListWrapperNode: PinchSourceContainerNode
    let avatarListNode: PeerInfoAvatarListContainerNode
    private var videoFadeNode: ASImageNode
    private let infoNode: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let statusNode: VoiceChatParticipantStatusNode
    
    private var appeared = false
    
    init(context: AccountContext, size: CGSize, sourceSize: CGSize, peer: Peer, text: VoiceChatParticipantItem.ParticipantText, customNode: ASDisplayNode? = nil, additionalEntry: Signal<(TelegramMediaImageRepresentation, Float)?, NoError>, requestDismiss: (() -> Void)?) {
        self.context = context
        self.size = size
        self.peer = peer
        self.text = text
        self.customNode = customNode
        self.additionalEntry = additionalEntry
        
        self.backgroundImageNode = ASImageNode()
        self.backgroundImageNode.clipsToBounds = true
        self.backgroundImageNode.displaysAsynchronously = false
        self.backgroundImageNode.displayWithoutProcessing = true
        
        self.videoFadeNode = ASImageNode()
        self.videoFadeNode.displaysAsynchronously = false
        self.videoFadeNode.contentMode = .scaleToFill
        
        self.avatarListContainerNode = ASDisplayNode()
        self.avatarListContainerNode.clipsToBounds = true
        
        self.avatarListWrapperNode = PinchSourceContainerNode()
        self.avatarListWrapperNode.clipsToBounds = true
        self.avatarListWrapperNode.cornerRadius = backgroundCornerRadius
       
        self.avatarListNode = PeerInfoAvatarListContainerNode(context: context)
        self.avatarListNode.backgroundColor = .clear
        self.avatarListNode.peer = peer
        self.avatarListNode.firstFullSizeOnly = true
        self.avatarListNode.offsetLocation = true
        self.avatarListNode.customCenterTapAction = {
            requestDismiss?()
        }
        
        self.infoNode = ASDisplayNode()
        self.infoNode.clipsToBounds = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = VoiceChatParticipantStatusNode()
        self.statusNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundImageNode)
        self.addSubnode(self.infoNode)
        self.addSubnode(self.videoFadeNode)
        self.addSubnode(self.avatarListWrapperNode)
        self.infoNode.addSubnode(self.titleNode)
        self.infoNode.addSubnode(self.statusNode)
        
        self.avatarListContainerNode.addSubnode(self.avatarListNode)
        self.avatarListContainerNode.addSubnode(self.avatarListNode.controlsClippingOffsetNode)
        self.avatarListWrapperNode.contentNode.addSubnode(self.avatarListContainerNode)
        
        self.avatarListWrapperNode.activate = { [weak self] sourceNode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.avatarListNode.controlsContainerNode.alpha = 0.0
            let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                return UIScreen.main.bounds
            })
            context.sharedContext.mainWindow?.presentInGlobalOverlay(pinchController)
        }
        self.avatarListWrapperNode.deactivated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.avatarListWrapperNode.contentNode.layer.animate(from: 0.0 as NSNumber, to: backgroundCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3, completion: { _ in
            })
        }
        self.avatarListWrapperNode.animatedOut = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.avatarListNode.controlsContainerNode.alpha = 1.0
            strongSelf.avatarListNode.controlsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        }
        
        self.updateInfo(size: size, sourceSize: sourceSize, animate: false)
    }
    
    func updateInfo(size: CGSize, sourceSize: CGSize, animate: Bool) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        let titleFont = Font.regular(17.0)
        let titleColor = UIColor.white
        var titleAttributedString: NSAttributedString?
        if let user = self.peer as? TelegramUser {
            if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                let string = NSMutableAttributedString()
                switch presentationData.nameDisplayOrder {
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
                titleAttributedString = NSAttributedString(string: presentationData.strings.User_DeletedAccount, font: titleFont, textColor: titleColor)
            }
        } else if let group = peer as? TelegramGroup {
            titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: titleColor)
        } else if let channel = peer as? TelegramChannel {
            titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: titleColor)
        }
        self.titleNode.attributedText = titleAttributedString
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: self.size.width - 24.0, height: size.height))
        
        let makeStatusLayout = self.statusNode.asyncLayout()
        let (statusLayout, statusApply) = makeStatusLayout(CGSize(width: self.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude), self.text, true)
        let _ = statusApply()
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: titleSize)
        self.statusNode.frame = CGRect(origin: CGPoint(x: 14.0, y: titleSize.height + 3.0), size: statusLayout)
        
        let totalHeight = titleSize.height + statusLayout.height + 3.0 + 8.0
        let infoFrame = CGRect(x: 0.0, y: size.height - totalHeight, width: sourceSize.width, height: totalHeight)

        if animate {
            let springDuration: Double = !self.appeared ? 0.42 : 0.3
            let springDamping: CGFloat = !self.appeared ? 124.0 : 1000.0
            
            let initialInfoPosition = self.infoNode.position
            self.infoNode.layer.position = infoFrame.center
            let initialInfoBounds = self.infoNode.bounds
            self.infoNode.layer.bounds = CGRect(origin: CGPoint(), size: infoFrame.size)
            
            self.infoNode.layer.animateSpring(from: NSValue(cgPoint: initialInfoPosition), to: NSValue(cgPoint: self.infoNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
            self.infoNode.layer.animateSpring(from: NSValue(cgRect: initialInfoBounds), to: NSValue(cgRect: self.infoNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
        } else {
            self.infoNode.frame = infoFrame
        }
    }
    
    func animateIn(from sourceNode: ASDisplayNode, targetRect: CGRect, transition: ContainedViewLayoutTransition) {
        let radiusTransition = ContainedViewLayoutTransition.animated(duration: 0.15, curve: .easeInOut)
        let springDuration: Double = 0.42
        let springDamping: CGFloat = 124.0
        
        if let sourceNode = sourceNode as? VoiceChatTileItemNode {
            let sourceRect = sourceNode.bounds
            self.backgroundImageNode.frame = sourceNode.bounds
            self.updateInfo(size: sourceNode.bounds.size, sourceSize: sourceNode.bounds.size, animate: false)
            self.updateInfo(size: targetRect.size, sourceSize: targetRect.size, animate: true)
                        
            self.backgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.clear(bounds)
                
                context.setFillColor(UIColor(rgb: 0x1c1c1e).cgColor)
                context.fillEllipse(in: bounds)
                context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
            })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
            self.backgroundImageNode.cornerRadius = backgroundCornerRadius
                                  
            transition.updateCornerRadius(node: self.backgroundImageNode, cornerRadius: 0.0)
              
            let initialRect = sourceRect
            let initialScale: CGFloat = sourceRect.width / targetRect.width
            
            let targetSize = CGSize(width: targetRect.size.width, height: targetRect.size.width)
            self.avatarListWrapperNode.update(size: targetSize, transition: .immediate)
            self.avatarListWrapperNode.frame = CGRect(x: targetRect.minX, y: targetRect.minY, width: targetRect.width, height: targetRect.width + backgroundCornerRadius)
            
            self.avatarListContainerNode.frame = CGRect(origin: CGPoint(), size: targetSize)
            self.avatarListContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.avatarListContainerNode.cornerRadius = targetRect.width / 2.0
            
            var appearanceTransition = transition
            if transition.isAnimated {
                appearanceTransition = .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0))
            }
            
            if let videoNode = sourceNode.videoNode {
                videoNode.updateLayout(size: targetSize, layoutMode: .fillOrFitToSquare, transition: appearanceTransition)
                appearanceTransition.updateFrame(node: videoNode, frame: CGRect(origin: CGPoint(), size: targetSize))
                appearanceTransition.updateFrame(node: sourceNode.videoContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: targetSize.width, height: targetSize.height + backgroundCornerRadius)))
                sourceNode.videoContainerNode.cornerRadius = backgroundCornerRadius
            }
            self.insertSubnode(sourceNode.videoContainerNode, belowSubnode: self.avatarListWrapperNode)
            
            if let snapshotView = sourceNode.infoNode.view.snapshotView(afterScreenUpdates: false) {
                self.videoFadeNode.image = tileFadeImage
                self.videoFadeNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
                self.videoFadeNode.frame = CGRect(x: 0.0, y: sourceRect.height - sourceNode.fadeNode.frame.height, width: sourceRect.width, height: sourceNode.fadeNode.frame.height)
                
                self.insertSubnode(self.videoFadeNode, aboveSubnode: sourceNode.videoContainerNode)
                self.view.insertSubview(snapshotView, aboveSubview: sourceNode.videoContainerNode.view)
                snapshotView.frame = sourceRect
                appearanceTransition.updateFrame(view: snapshotView, frame: CGRect(origin: CGPoint(x: 0.0, y: targetSize.height - snapshotView.frame.size.height), size: snapshotView.frame.size))
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
                appearanceTransition.updateFrame(node: self.videoFadeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: targetSize.height - self.videoFadeNode.frame.size.height), size: CGSize(width: targetSize.width, height: self.videoFadeNode.frame.height)))
                self.videoFadeNode.alpha = 0.0
                self.videoFadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
            
            self.avatarListWrapperNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            self.avatarListWrapperNode.layer.animateSpring(from: NSValue(cgPoint: initialRect.center), to: NSValue(cgPoint: self.avatarListWrapperNode.position), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.avatarListNode.updateCustomItemsOnlySynchronously = false
                    strongSelf.avatarListNode.currentItemNode?.addSubnode(sourceNode.videoContainerNode)
                }
            })
            
            radiusTransition.updateCornerRadius(node: self.avatarListContainerNode, cornerRadius: 0.0)
            
            self.avatarListWrapperNode.contentNode.clipsToBounds = true

            self.avatarListNode.frame = CGRect(x: targetRect.width / 2.0, y: targetRect.width / 2.0, width: targetRect.width, height: targetRect.width)
            self.avatarListNode.controlsClippingNode.frame = CGRect(x: -targetRect.width / 2.0, y: -targetRect.width / 2.0, width: targetRect.width, height: targetRect.width)
            self.avatarListNode.controlsClippingOffsetNode.frame = CGRect(origin: CGPoint(x: targetRect.width / 2.0, y: targetRect.width / 2.0), size: CGSize())
            self.avatarListNode.stripContainerNode.frame = CGRect(x: 0.0, y: 13.0, width: targetRect.width, height: 2.0)
            self.avatarListNode.topShadowNode.frame = CGRect(x: 0.0, y: 0.0, width: targetRect.width, height: 44.0)
            
            self.avatarListNode.updateCustomItemsOnlySynchronously = true
            self.avatarListNode.update(size: targetSize, peer: self.peer, customNode: self.customNode, additionalEntry: self.additionalEntry, isExpanded: true, transition: .immediate)
            
            let backgroundTargetRect = CGRect(x: 0.0, y: targetSize.height - backgroundCornerRadius * 2.0, width: targetRect.width, height: targetRect.height - targetSize.height + backgroundCornerRadius * 2.0)
            let initialBackgroundPosition = self.backgroundImageNode.position
            self.backgroundImageNode.layer.position = backgroundTargetRect.center
            let initialBackgroundBounds = self.backgroundImageNode.bounds
            self.backgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: backgroundTargetRect.size)
            
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: self.backgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: self.backgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
        } else if let sourceNode = sourceNode as? VoiceChatFullscreenParticipantItemNode {
            let sourceRect = sourceNode.bounds
            self.backgroundImageNode.frame = sourceNode.bounds
            self.updateInfo(size: sourceNode.bounds.size, sourceSize: sourceNode.bounds.size, animate: false)
            self.updateInfo(size: targetRect.size, sourceSize: targetRect.size, animate: true)
            
            self.backgroundImageNode.image = generateImage(CGSize(width: backgroundCornerRadius * 2.0, height: backgroundCornerRadius * 2.0), rotatedContext: { (size, context) in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.clear(bounds)
                
                context.setFillColor(UIColor(rgb: 0x1c1c1e).cgColor)
                context.fillEllipse(in: bounds)
                context.fill(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height / 2.0))
            })?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius), topCapHeight: Int(backgroundCornerRadius))
            self.backgroundImageNode.cornerRadius = backgroundCornerRadius
                                  
            transition.updateCornerRadius(node: self.backgroundImageNode, cornerRadius: 0.0)
              
            let initialRect: CGRect
            let hasVideo: Bool
            if let videoNode = sourceNode.videoNode, videoNode.supernode == sourceNode.videoContainerNode, !videoNode.alpha.isZero {
                initialRect = sourceRect
                hasVideo = true
            } else {
                initialRect = sourceNode.avatarNode.frame
                hasVideo = false
            }
            let initialScale = initialRect.width / targetRect.width
            
            let targetSize = CGSize(width: targetRect.size.width, height: targetRect.size.width)
            self.avatarListWrapperNode.update(size: targetSize, transition: .immediate)
            self.avatarListWrapperNode.frame = CGRect(x: targetRect.minX, y: targetRect.minY, width: targetRect.width, height: targetRect.width + backgroundCornerRadius)
            
            self.avatarListContainerNode.frame = CGRect(origin: CGPoint(), size: targetSize)
            self.avatarListContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.avatarListContainerNode.cornerRadius = targetRect.width / 2.0
            
            var appearanceTransition = transition
            if transition.isAnimated {
                appearanceTransition = .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0))
            }
            
            if let videoNode = sourceNode.videoNode, hasVideo {
                videoNode.updateLayout(size: targetSize, layoutMode: .fillOrFitToSquare, transition: appearanceTransition)
                appearanceTransition.updateFrame(node: videoNode, frame: CGRect(origin: CGPoint(), size: targetSize))
                appearanceTransition.updateFrame(node: sourceNode.videoFadeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: targetSize.height - fadeHeight), size: CGSize(width: targetSize.width, height: fadeHeight)))
                appearanceTransition.updateTransformScale(node: sourceNode.videoContainerNode, scale: 1.0)
                appearanceTransition.updateFrame(node: sourceNode.videoContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: targetSize.width, height: targetSize.height + backgroundCornerRadius)))
                sourceNode.videoContainerNode.cornerRadius = backgroundCornerRadius
                appearanceTransition.updateAlpha(node: sourceNode.videoFadeNode, alpha: 0.0)
            } else {
                let transitionNode = ASImageNode()
                transitionNode.clipsToBounds = true
                transitionNode.displaysAsynchronously = false
                transitionNode.displayWithoutProcessing = true
                transitionNode.image = sourceNode.avatarNode.unroundedImage
                transitionNode.frame = CGRect(origin: CGPoint(), size: targetSize)
                transitionNode.cornerRadius = targetRect.width / 2.0
                radiusTransition.updateCornerRadius(node: transitionNode, cornerRadius: 0.0)
                
                sourceNode.avatarNode.isHidden = true
                self.avatarListWrapperNode.contentNode.insertSubnode(transitionNode, at: 0)
            }
            self.insertSubnode(sourceNode.videoContainerNode, belowSubnode: self.avatarListWrapperNode)
            
            self.avatarListWrapperNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            self.avatarListWrapperNode.layer.animateSpring(from: NSValue(cgPoint: initialRect.center), to: NSValue(cgPoint: self.avatarListWrapperNode.position), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.avatarListNode.updateCustomItemsOnlySynchronously = false
                    strongSelf.avatarListNode.currentItemNode?.addSubnode(sourceNode.videoContainerNode)
                }
            })
            
            radiusTransition.updateCornerRadius(node: self.avatarListContainerNode, cornerRadius: 0.0)
            
            self.avatarListWrapperNode.contentNode.clipsToBounds = true

            self.avatarListNode.frame = CGRect(x: targetRect.width / 2.0, y: targetRect.width / 2.0, width: targetRect.width, height: targetRect.width)
            self.avatarListNode.controlsClippingNode.frame = CGRect(x: -targetRect.width / 2.0, y: -targetRect.width / 2.0, width: targetRect.width, height: targetRect.width)
            self.avatarListNode.controlsClippingOffsetNode.frame = CGRect(origin: CGPoint(x: targetRect.width / 2.0, y: targetRect.width / 2.0), size: CGSize())
            self.avatarListNode.stripContainerNode.frame = CGRect(x: 0.0, y: 13.0, width: targetRect.width, height: 2.0)
            self.avatarListNode.topShadowNode.frame = CGRect(x: 0.0, y: 0.0, width: targetRect.width, height: 44.0)
            
            self.avatarListNode.updateCustomItemsOnlySynchronously = true
            self.avatarListNode.update(size: targetSize, peer: self.peer, customNode: self.customNode, additionalEntry: self.additionalEntry, isExpanded: true, transition: .immediate)
            
            let backgroundTargetRect = CGRect(x: 0.0, y: targetSize.height - backgroundCornerRadius * 2.0, width: targetRect.width, height: targetRect.height - targetSize.height + backgroundCornerRadius * 2.0)
            let initialBackgroundPosition = self.backgroundImageNode.position
            self.backgroundImageNode.layer.position = backgroundTargetRect.center
            let initialBackgroundBounds = self.backgroundImageNode.bounds
            self.backgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: backgroundTargetRect.size)
            
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: self.backgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: self.backgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
        }
        self.appeared = true
    }
    
    func animateOut(to targetNode: ASDisplayNode, targetRect: CGRect, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        let radiusTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        let springDuration: Double = 0.3
        let springDamping: CGFloat = 1000.0
        if let targetNode = targetNode as? VoiceChatTileItemNode {
            let initialSize = self.bounds
            self.updateInfo(size: targetRect.size, sourceSize: targetRect.size, animate: true)
            
            transition.updateCornerRadius(node: self.backgroundImageNode, cornerRadius: backgroundCornerRadius)
            
            let targetScale = targetRect.width / avatarListContainerNode.frame.width
                        
            self.insertSubnode(targetNode.videoContainerNode, belowSubnode: self.avatarListWrapperNode)
            self.insertSubnode(self.videoFadeNode, aboveSubnode: targetNode.videoContainerNode)
            self.avatarListWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            self.avatarListWrapperNode.layer.animate(from: 1.0 as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
            self.avatarListWrapperNode.layer.animate(from: NSValue(cgPoint: self.avatarListWrapperNode.position), to: NSValue(cgPoint: targetRect.center), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak targetNode] _ in
                if let targetNode = targetNode {
                    targetNode.contentNode.insertSubnode(targetNode.videoContainerNode, aboveSubnode: targetNode.backgroundNode)
                }
                completion()
                self?.removeFromSupernode()
            })
            
            radiusTransition.updateCornerRadius(node: self.avatarListContainerNode, cornerRadius: backgroundCornerRadius)
            
            if let snapshotView = targetNode.infoNode.view.snapshotView(afterScreenUpdates: true) {
                self.view.insertSubview(snapshotView, aboveSubview: targetNode.videoContainerNode.view)
                let snapshotFrame = snapshotView.frame
                snapshotView.frame = CGRect(origin: CGPoint(x: 0.0, y: initialSize.width - snapshotView.frame.size.height), size: snapshotView.frame.size)
                transition.updateFrame(view: snapshotView, frame: snapshotFrame)
                snapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                transition.updateFrame(node: self.videoFadeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: targetRect.height - self.videoFadeNode.frame.size.height), size: CGSize(width: targetRect.width, height: self.videoFadeNode.frame.height)))
                self.videoFadeNode.alpha = 1.0
                self.videoFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            
            if let videoNode = targetNode.videoNode {
                videoNode.updateLayout(size: targetRect.size, layoutMode: .fillOrFitToSquare, transition: transition)
                transition.updateFrame(node: videoNode, frame: targetRect)
                transition.updateFrame(node: targetNode.videoContainerNode, frame: targetRect)
            }
            
            let backgroundTargetRect = targetRect
            let initialBackgroundPosition = self.backgroundImageNode.position
            self.backgroundImageNode.layer.position = backgroundTargetRect.center
            let initialBackgroundBounds = self.backgroundImageNode.bounds
            self.backgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: backgroundTargetRect.size)
            
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: self.backgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: self.backgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            
            self.avatarListNode.stripContainerNode.alpha = 0.0
            self.avatarListNode.stripContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            
            self.avatarListNode.topShadowNode.alpha = 0.0
            self.avatarListNode.topShadowNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            
            self.infoNode.alpha = 0.0
            self.infoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        } else if let targetNode = targetNode as? VoiceChatFullscreenParticipantItemNode {
            let backgroundTargetRect = targetRect
            
            self.updateInfo(size: targetRect.size, sourceSize: targetRect.size, animate: true)
            
            targetNode.avatarNode.isHidden = false
            
            transition.updateCornerRadius(node: self.backgroundImageNode, cornerRadius: backgroundCornerRadius)
            
            var targetRect = targetRect
            let hasVideo: Bool
            if let videoNode = targetNode.videoNode, !videoNode.alpha.isZero {
                hasVideo = true
            } else {
                targetRect = targetNode.avatarNode.frame
                hasVideo = false
            }
            let targetScale = targetRect.width / self.avatarListContainerNode.frame.width
                        
            self.insertSubnode(targetNode.videoContainerNode, belowSubnode: self.avatarListWrapperNode)
            self.insertSubnode(self.videoFadeNode, aboveSubnode: targetNode.videoContainerNode)
            self.avatarListWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            self.avatarListWrapperNode.layer.animate(from: 1.0 as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
            self.avatarListWrapperNode.layer.animate(from: NSValue(cgPoint: self.avatarListWrapperNode.position), to: NSValue(cgPoint: targetRect.center), keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak targetNode] _ in
                if let targetNode = targetNode {
                    targetNode.offsetContainerNode.insertSubnode(targetNode.videoContainerNode, at: 0)
                }
                completion()
                self?.removeFromSupernode()
            })
            
            radiusTransition.updateCornerRadius(node: self.avatarListContainerNode, cornerRadius: backgroundCornerRadius)
            
            if hasVideo, let videoNode = targetNode.videoNode {
                videoNode.updateLayout(size: CGSize(width: 180.0, height: 180.0), layoutMode: .fillOrFitToSquare, transition: transition)
                transition.updateFrame(node: videoNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: 180.0, height: 180.0)))
                transition.updateTransformScale(node: targetNode.videoContainerNode, scale: 84.0 / 180.0)
                transition.updateFrameAsPositionAndBounds(node: targetNode.videoContainerNode, frame: CGRect(x: 0.0, y: 0.0, width: 180.0, height: 180.0))
                transition.updatePosition(node: targetNode.videoContainerNode, position: CGPoint(x: 42.0, y: 42.0))
                transition.updateFrame(node: targetNode.videoFadeNode, frame: CGRect(x: 0.0, y: 180.0 - fadeHeight, width: 180.0, height: fadeHeight))
                transition.updateAlpha(node: targetNode.videoFadeNode, alpha: 1.0)
            }
            
            let initialBackgroundPosition = self.backgroundImageNode.position
            self.backgroundImageNode.layer.position = backgroundTargetRect.center
            let initialBackgroundBounds = self.backgroundImageNode.bounds
            self.backgroundImageNode.layer.bounds = CGRect(origin: CGPoint(), size: backgroundTargetRect.size)
            
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgPoint: initialBackgroundPosition), to: NSValue(cgPoint: self.backgroundImageNode.position), keyPath: "position", duration: springDuration, delay: 0.0, initialVelocity: 0.0, damping: springDamping)
            self.backgroundImageNode.layer.animateSpring(from: NSValue(cgRect: initialBackgroundBounds), to: NSValue(cgRect: self.backgroundImageNode.bounds), keyPath: "bounds", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            
            self.avatarListNode.stripContainerNode.alpha = 0.0
            self.avatarListNode.stripContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
           
            self.avatarListNode.topShadowNode.alpha = 0.0
            self.avatarListNode.topShadowNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            
            self.infoNode.alpha = 0.0
            self.infoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        }
    }
}
