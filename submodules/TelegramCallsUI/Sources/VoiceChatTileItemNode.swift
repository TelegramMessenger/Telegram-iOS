import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramPresentationData

private let backgroundCornerRadius: CGFloat = 11.0
private let constructiveColor: UIColor = UIColor(rgb: 0x34c759)
private let borderLineWidth: CGFloat = 2.0
private let borderImage = generateImage(CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    context.setLineWidth(borderLineWidth)
    context.setStrokeColor(constructiveColor.cgColor)
    
    context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: (borderLineWidth - UIScreenPixel) / 2.0, dy: (borderLineWidth - UIScreenPixel) / 2.0), cornerRadius: backgroundCornerRadius - UIScreenPixel).cgPath)
    context.strokePath()
})

private let fadeHeight: CGFloat = 50.0

final class VoiceChatTileItem: Equatable {
    enum Icon: Equatable {
        case none
        case microphone(Bool)
        case presentation
    }
    
    let peer: Peer
    let videoEndpointId: String
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    let icon: Icon
    let text: VoiceChatParticipantItem.ParticipantText
    let speaking: Bool
    let action: () -> Void
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let getVideo: () -> GroupVideoNode?
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    
    var id: String {
        return self.videoEndpointId
    }
    
    init(peer: Peer, videoEndpointId: String, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, speaking: Bool, icon: Icon, text: VoiceChatParticipantItem.ParticipantText, action:  @escaping () -> Void, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?, getVideo: @escaping () -> GroupVideoNode?, getAudioLevel: (() -> Signal<Float, NoError>)?) {
        self.peer = peer
        self.videoEndpointId = videoEndpointId
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.icon = icon
        self.text = text
        self.speaking = speaking
        self.action = action
        self.contextAction = contextAction
        self.getVideo = getVideo
        self.getAudioLevel = getAudioLevel
    }
    
    static func == (lhs: VoiceChatTileItem, rhs: VoiceChatTileItem) -> Bool {
        if !arePeersEqual(lhs.peer, rhs.peer) {
            return false
        }
        if lhs.videoEndpointId != rhs.videoEndpointId {
            return false
        }
        if lhs.speaking != rhs.speaking {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
}

private var fadeImage: UIImage? = {
    return generateImage(CGSize(width: 1.0, height: fadeHeight), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let colorsArray = [UIColor(rgb: 0x000000, alpha: 0.0).cgColor, UIColor(rgb: 0x000000, alpha: 0.7).cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })
}()

final class VoiceChatTileItemNode: ASDisplayNode {
    private let context: AccountContext
  
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    let contentNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    var videoContainerNode: ASDisplayNode
    var videoNode: GroupVideoNode?
    let infoNode: ASDisplayNode
    let fadeNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private var animationNode: VoiceChatMicrophoneNode?
    private var highlightNode: ASImageNode
    private let statusNode: VoiceChatParticipantStatusNode
    
    private var profileNode: VoiceChatPeerProfileNode?
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private var validLayout: (CGSize, CGFloat)?
    var item: VoiceChatTileItem?
    private var isExtracted = false
    
    private let audioLevelDisposable = MetaDisposable()
    
    init(context: AccountContext) {
        self.context = context
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.contentNode = ASDisplayNode()
        self.contentNode.clipsToBounds = true
        self.contentNode.cornerRadius = 11.0
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = panelBackgroundColor
        
        self.videoContainerNode = ASDisplayNode()
        self.videoContainerNode.clipsToBounds = true
        
        self.infoNode = ASDisplayNode()
        
        self.fadeNode = ASImageNode()
        self.fadeNode.displaysAsynchronously = false
        self.fadeNode.displayWithoutProcessing = true
        self.fadeNode.contentMode = .scaleToFill
        self.fadeNode.image = fadeImage
        
        self.titleNode = ImmediateTextNode()
        self.statusNode = VoiceChatParticipantStatusNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.highlightNode = ASImageNode()
        self.highlightNode.contentMode = .scaleToFill
        self.highlightNode.image = borderImage?.stretchableImage(withLeftCapWidth: 12, topCapHeight: 12)
        self.highlightNode.alpha = 0.0
        
        super.init()
        
        self.clipsToBounds = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.backgroundNode)
        self.contentNode.addSubnode(self.videoContainerNode)
        self.contentNode.addSubnode(self.fadeNode)
        self.contentNode.addSubnode(self.infoNode)
        self.infoNode.addSubnode(self.titleNode)
        self.infoNode.addSubnode(self.iconNode)
        self.contentNode.addSubnode(self.highlightNode)
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let _ = self else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture)
        }
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let _ = strongSelf.item else {
                return
            }
            strongSelf.updateIsExtracted(isExtracted, transition: transition)
        }
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        self.item?.action()
    }
    
    private func updateIsExtracted(_ isExtracted: Bool, transition: ContainedViewLayoutTransition) {
        guard self.isExtracted != isExtracted, let extractedRect = self.extractedRect, let nonExtractedRect = self.nonExtractedRect, let item = self.item else {
            return
        }
        self.isExtracted = isExtracted
        
        if isExtracted {
            let profileNode = VoiceChatPeerProfileNode(context: self.context, size: extractedRect.size, peer: item.peer, text: item.text, customNode: self.videoContainerNode, additionalEntry: .single(nil), requestDismiss: { [weak self] in
                self?.contextSourceNode.requestDismiss?()
            })
            profileNode.frame = CGRect(origin: CGPoint(), size: extractedRect.size)
            self.profileNode = profileNode
            self.contextSourceNode.contentNode.addSubnode(profileNode)

            profileNode.animateIn(from: self, targetRect: extractedRect, transition: transition)
            
            self.contextSourceNode.contentNode.customHitTest = { [weak self] point in
                if let strongSelf = self, let profileNode = strongSelf.profileNode {
                    if profileNode.avatarListWrapperNode.frame.contains(point) {
                        return profileNode.avatarListNode.view
                    }
                }
                return nil
            }
        } else if let profileNode = self.profileNode {
            self.profileNode = nil
            profileNode.animateOut(to: self, targetRect: nonExtractedRect, transition: transition)
            
            self.contextSourceNode.contentNode.customHitTest = nil
        }
    }
    
    func update(size: CGSize, availableWidth: CGFloat, item: VoiceChatTileItem, transition: ContainedViewLayoutTransition) {
        guard self.validLayout?.0 != size || self.validLayout?.1 != availableWidth || self.item != item else {
            return
        }
        
        self.validLayout = (size, availableWidth)
        
        var itemTransition = transition
        if self.item != item {
            let previousItem = self.item
            self.item = item
            
            if false, let getAudioLevel = item.getAudioLevel {
                self.audioLevelDisposable.set((getAudioLevel()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                    if value > 0.4 {
                        transition.updateAlpha(node: strongSelf.highlightNode, alpha: 1.0)
                    } else {
                        transition.updateAlpha(node: strongSelf.highlightNode, alpha: 0.0)
                    }
                }))
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            if item.speaking {
                transition.updateAlpha(node: self.highlightNode, alpha: 1.0)
            } else {
                transition.updateAlpha(node: self.highlightNode, alpha: 0.0)
            }
            
            if previousItem?.videoEndpointId != item.videoEndpointId || self.videoNode == nil {
                if let current = self.videoNode {
                    self.videoNode = nil
                    current.removeFromSupernode()
                }
                
                if let videoNode = item.getVideo() {
                    itemTransition = .immediate
                    self.videoNode = videoNode
                    self.videoContainerNode.addSubnode(videoNode)
                }
            }
            
            let titleFont = Font.semibold(13.0)
            let titleColor = UIColor.white
            var titleAttributedString: NSAttributedString?
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
                    titleAttributedString = NSAttributedString(string: item.strings.User_DeletedAccount, font: titleFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: titleColor)
            }
            self.titleNode.attributedText = titleAttributedString
            
            if case let .microphone(muted) = item.icon {
                let animationNode: VoiceChatMicrophoneNode
                if let current = self.animationNode {
                    animationNode = current
                } else {
                    animationNode = VoiceChatMicrophoneNode()
                    self.animationNode = animationNode
                    self.infoNode.addSubnode(animationNode)
                }
                animationNode.alpha = 1.0
                animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: UIColor.white), animated: true)
            } else if let animationNode = self.animationNode {
                self.animationNode = nil
                animationNode.removeFromSupernode()
            }
        }
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.contentNode.frame = bounds
        self.containerNode.frame = bounds
        self.contextSourceNode.frame = bounds
        self.contextSourceNode.contentNode.frame = bounds
        
        let extractedWidth = availableWidth
        let makeStatusLayout = self.statusNode.asyncLayout()
        let (statusLayout, _) = makeStatusLayout(CGSize(width: availableWidth - 30.0, height: CGFloat.greatestFiniteMagnitude), item.text, true)
                
        let extractedRect = CGRect(x: 0.0, y: 0.0, width: extractedWidth, height: extractedWidth + statusLayout.height + 39.0)
        let nonExtractedRect = bounds
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        self.contextSourceNode.contentRect = extractedRect
        
        if self.videoContainerNode.supernode === self.contentNode {
            if let videoNode = self.videoNode {
                transition.updateFrame(node: videoNode, frame: bounds)
                videoNode.updateLayout(size: size, isLandscape: true, transition: itemTransition)
            }
            transition.updateFrame(node: self.videoContainerNode, frame: bounds)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: bounds)
        transition.updateFrame(node: self.highlightNode, frame: bounds)
        transition.updateFrame(node: self.infoNode, frame: bounds)
        transition.updateFrame(node: self.fadeNode, frame: CGRect(x: 0.0, y: size.height - fadeHeight, width: size.width, height: fadeHeight))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 50.0, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 30.0, y: size.height - titleSize.height - 8.0), size: titleSize)
        
        if let animationNode = self.animationNode {
            let animationSize = CGSize(width: 36.0, height: 36.0)
            animationNode.bounds = CGRect(origin: CGPoint(), size: animationSize)
            animationNode.transform = CATransform3DMakeScale(0.66667, 0.66667, 1.0)
            transition.updatePosition(node: animationNode, position: CGPoint(x: 16.0, y: size.height - 15.0))
        }
    }
    
    func animateTransitionIn(from sourceNode: ASDisplayNode, containerNode: ASDisplayNode, transition: ContainedViewLayoutTransition, animate: Bool = true) {
        guard let _ = self.item else {
            return
        }
        var duration: Double = 0.2
        var timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue
        if case let .animated(transitionDuration, curve) = transition {
            duration = transitionDuration + 0.05
            timingFunction = curve.timingFunction
        }
        
        if let sourceNode = sourceNode as? VoiceChatFullscreenParticipantItemNode, let _ = sourceNode.item {
            let initialAnimate = animate
        
            var startContainerPosition = sourceNode.view.convert(sourceNode.bounds, to: containerNode.view).center
            var animate = initialAnimate
//            if startContainerPosition.y > containerNode.frame.height - 238.0 {
//                animate = false
//            }
            
            if let videoNode = sourceNode.videoNode {
                sourceNode.videoNode = nil
                videoNode.alpha = 1.0
                self.videoNode = videoNode
                self.videoContainerNode.addSubnode(videoNode)
 
                if animate {
//                    self.videoContainerNode.layer.animateScale(from: sourceNode.bounds.width / videoSize.width, to: tileSize.width / videoSize.width, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
//                    self.videoContainerNode.layer.animate(from: (tileSize.width / 2.0) as NSNumber, to: videoCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { _ in
//                    })
                }
            }
                        
            if animate {
                sourceNode.isHidden = true
                Queue.mainQueue().after(0.4) {
                    sourceNode.isHidden = false
                }
                
                let initialPosition = self.contextSourceNode.position
                let targetContainerPosition = self.contextSourceNode.view.convert(self.contextSourceNode.bounds, to: containerNode.view).center

                self.contextSourceNode.position = targetContainerPosition
                containerNode.addSubnode(self.contextSourceNode)

                self.contextSourceNode.layer.animateScale(from: 0.467, to: 1.0, duration: duration, timingFunction: timingFunction)
                self.contextSourceNode.layer.animatePosition(from: startContainerPosition, to: targetContainerPosition, duration: duration, timingFunction: timingFunction, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.contextSourceNode.position = initialPosition
                        strongSelf.containerNode.addSubnode(strongSelf.contextSourceNode)
                    }
                })
                
                self.videoNode?.updateLayout(size: self.bounds.size, isLandscape: true, transition: transition)
                self.videoNode?.frame = self.bounds
            } else if !initialAnimate {
                self.videoNode?.updateLayout(size: self.bounds.size, isLandscape: true, transition: .immediate)
                self.videoNode?.frame = self.bounds
                
                sourceNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak sourceNode] _ in
                    sourceNode?.layer.removeAllAnimations()
                })
                sourceNode.layer.animateScale(from: 1.0, to: 0.0, duration: duration, timingFunction: timingFunction)
            }
            
            self.fadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
}

private class VoiceChatTileHighlightNode: ASDisplayNode {
    
}
