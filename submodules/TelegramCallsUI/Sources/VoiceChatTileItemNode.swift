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
    let icon: Icon
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    let speaking: Bool
    let action: () -> Void
    let getVideo: () -> GroupVideoNode?
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    
    var id: String {
        return self.videoEndpointId
    }
    
    init(peer: Peer, videoEndpointId: String, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, speaking: Bool, icon: Icon, action:  @escaping () -> Void, getVideo: @escaping () -> GroupVideoNode?, getAudioLevel: (() -> Signal<Float, NoError>)?) {
        self.peer = peer
        self.videoEndpointId = videoEndpointId
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.icon = icon
        self.speaking = speaking
        self.action = action
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
    private let backgroundNode: ASDisplayNode
    var videoNode: GroupVideoNode?
    private let fadeNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private var animationNode: VoiceChatMicrophoneNode?
    private var highlightNode: ASImageNode
    
    private var validLayout: CGSize?
    var item: VoiceChatTileItem?
    
    private let audioLevelDisposable = MetaDisposable()
    
    init(context: AccountContext) {
        self.context = context
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
                
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = panelBackgroundColor
        
        self.fadeNode = ASImageNode()
        self.fadeNode.displaysAsynchronously = false
        self.fadeNode.displayWithoutProcessing = true
        self.fadeNode.contentMode = .scaleToFill
        self.fadeNode.image = fadeImage
        
        self.titleNode = ImmediateTextNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.highlightNode = ASImageNode()
        self.highlightNode.contentMode = .scaleToFill
        self.highlightNode.image = borderImage?.stretchableImage(withLeftCapWidth: 12, topCapHeight: 12)
        self.highlightNode.alpha = 0.0
        
        super.init()
        
        self.clipsToBounds = true
        
        self.contextSourceNode.contentNode.clipsToBounds = true
        self.contextSourceNode.contentNode.cornerRadius = 11.0
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.backgroundNode)
        self.contextSourceNode.contentNode.addSubnode(self.fadeNode)
        self.contextSourceNode.contentNode.addSubnode(self.titleNode)
        self.contextSourceNode.contentNode.addSubnode(self.iconNode)
        self.contextSourceNode.contentNode.addSubnode(self.highlightNode)
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
    
    func update(size: CGSize, item: VoiceChatTileItem, transition: ContainedViewLayoutTransition) {
        guard self.validLayout != size || self.item != item else {
            return
        }
        
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
                    self.contextSourceNode.contentNode.insertSubnode(videoNode, at: 1)
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
                    self.contextSourceNode.contentNode.addSubnode(animationNode)
                }
                animationNode.alpha = 1.0
                animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: UIColor.white), animated: true)
            } else if let animationNode = self.animationNode {
                self.animationNode = nil
                animationNode.removeFromSupernode()
            }
        }
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.containerNode.frame = bounds
        self.contextSourceNode.frame = bounds
        self.contextSourceNode.contentNode.frame = bounds
        
        if let videoNode = self.videoNode {
            transition.updateFrame(node: videoNode, frame: bounds)
            videoNode.updateLayout(size: size, isLandscape: true, transition: itemTransition)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: bounds)
        transition.updateFrame(node: self.highlightNode, frame: bounds)
        transition.updateFrame(node: self.fadeNode, frame: CGRect(x: 0.0, y: size.height - fadeHeight, width: size.width, height: fadeHeight))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 50.0, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 11.0, y: size.height - titleSize.height - 8.0), size: titleSize)
        
        if let animationNode = self.animationNode {
            let animationSize = CGSize(width: 36.0, height: 36.0)
            animationNode.bounds = CGRect(origin: CGPoint(), size: animationSize)
            animationNode.transform = CATransform3DMakeScale(0.66667, 0.66667, 1.0)
            transition.updatePosition(node: animationNode, position: CGPoint(x: size.width - 19.0, y: size.height - 15.0))
        }
    }
    
    func animateTransitionIn(from sourceNode: ASDisplayNode, containerNode: ASDisplayNode, animate: Bool = true) {
        guard let _ = self.item else {
            return
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
                self.contextSourceNode.contentNode.insertSubnode(videoNode, at: 1)
 
                if animate {
//                    self.videoContainerNode.layer.animateScale(from: sourceNode.bounds.width / videoSize.width, to: tileSize.width / videoSize.width, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
//                    self.videoContainerNode.layer.animate(from: (tileSize.width / 2.0) as NSNumber, to: videoCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { _ in
//                    })
                }
            }
            
            sourceNode.isHidden = true
            Queue.mainQueue().after(0.25) {
                sourceNode.isHidden = false
            }
            
            if animate {
                let initialPosition = self.contextSourceNode.position
                let targetContainerPosition = self.contextSourceNode.view.convert(self.contextSourceNode.bounds, to: containerNode.view).center

                self.contextSourceNode.position = targetContainerPosition
                containerNode.addSubnode(self.contextSourceNode)

                self.contextSourceNode.layer.animateScale(from: 0.467, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                self.contextSourceNode.layer.animatePosition(from: startContainerPosition, to: targetContainerPosition, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.contextSourceNode.position = initialPosition
                        strongSelf.containerNode.addSubnode(strongSelf.contextSourceNode)
                    }
                })
                
                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                self.videoNode?.updateLayout(size: self.bounds.size, isLandscape: true, transition: transition)
                self.videoNode?.frame = self.bounds
            } else if !initialAnimate {
                self.videoNode?.updateLayout(size: self.bounds.size, isLandscape: true, transition: .immediate)
                self.videoNode?.frame = self.bounds
            }
            
            self.fadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
}

private class VoiceChatTileHighlightNode: ASDisplayNode {
    
}
