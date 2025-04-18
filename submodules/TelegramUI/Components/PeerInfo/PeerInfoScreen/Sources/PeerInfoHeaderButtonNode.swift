import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import AnimationUI
import Display
import TelegramPresentationData
import ComponentFlow
import LottieComponent

enum PeerInfoHeaderButtonKey: Hashable {
    case message
    case discussion
    case call
    case videoCall
    case voiceChat
    case mute
    case more
    case addMember
    case search
    case leave
    case stop
    case addContact
}

enum PeerInfoHeaderButtonIcon {
    case message
    case call
    case videoCall
    case voiceChat
    case mute
    case unmute
    case more
    case addMember
    case search
    case leave
    case stop
}

final class PeerInfoHeaderButtonNode: HighlightableButtonNode {
    let key: PeerInfoHeaderButtonKey
    private let action: (PeerInfoHeaderButtonNode, ContextGesture?) -> Void
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    //private let backgroundNode: NavigationBackgroundNode
    private let contentNode: ASDisplayNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    private var animatedIcon: ComponentView<Empty>?
    
    private var theme: PresentationTheme?
    private var icon: PeerInfoHeaderButtonIcon?
    private var isActive: Bool?
    
    let backgroundContainerView: UIView
    let backgroundView: UIView
    
    init(key: PeerInfoHeaderButtonKey, action: @escaping (PeerInfoHeaderButtonNode, ContextGesture?) -> Void) {
        self.key = key
        self.action = action
        
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.backgroundContainerView = UIView()
        self.backgroundView = UIView()
        self.backgroundView.backgroundColor = .white
        self.backgroundContainerView.addSubview(self.backgroundView)
        
        /*self.backgroundNode = NavigationBackgroundNode(color: UIColor(white: 1.0, alpha: 0.2), enableBlur: true, enableSaturation: false)
        self.backgroundNode.isUserInteractionEnabled = false*/
        
        self.contentNode = ASDisplayNode()
        self.contentNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.accessibilityTraits = .button
        
        self.containerNode.addSubnode(self.referenceNode)
        //self.referenceNode.addSubnode(self.backgroundNode)
        self.referenceNode.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.iconNode)
        self.addSubnode(self.containerNode)
        self.contentNode.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.containerNode.activated = { [weak self] gesture, _ in
            if let strongSelf = self {
                strongSelf.action(strongSelf, gesture)
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        switch self.icon {
        case .voiceChat, .more, .leave:
            if let animatedIconView = self.animatedIcon?.view as? LottieComponent.View {
                animatedIconView.playOnce()
            }
        default:
            break
        }
        self.action(self, nil)
    }
    
    func update(size: CGSize, text: String, icon: PeerInfoHeaderButtonIcon, isActive: Bool, presentationData: PresentationData, backgroundColor: UIColor, foregroundColor: UIColor, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousIcon = self.icon
        let themeUpdated = self.theme != presentationData.theme
        let iconUpdated = self.icon != icon
        let isActiveUpdated = self.isActive != isActive
        self.isActive = isActive
        
        let iconSize = CGSize(width: 40.0, height: 40.0)
        
        if themeUpdated || iconUpdated {
            self.theme = presentationData.theme
            self.icon = icon
            
            var isGestureEnabled = false
            if [.mute, .voiceChat, .more].contains(icon) {
                isGestureEnabled = true
            }
            self.containerNode.isGestureEnabled = isGestureEnabled
            
            let iconColor = UIColor.white
            self.iconNode.image = generateImage(iconSize, contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setBlendMode(.normal)
                context.setFillColor(iconColor.cgColor)
                let imageName: String?
                switch icon {
                case .message:
                    imageName = "Peer Info/ButtonMessage"
                case .call:
                    imageName = "Peer Info/ButtonCall"
                case .videoCall:
                    imageName = "Peer Info/ButtonVideo"
                case .voiceChat:
                    imageName = nil
                case .mute:
                    imageName = nil
                case .unmute:
                    imageName = nil
                case .more:
                    imageName = nil
                case .addMember:
                    imageName = "Peer Info/ButtonAddMember"
                case .search:
                    imageName = "Peer Info/ButtonSearch"
                case .leave:
                    imageName = nil
                case .stop:
                    imageName = "Peer Info/ButtonStop"
                }
                if let imageName = imageName, let image = generateTintedImage(image: UIImage(bundleImageName: imageName), color: .white) {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.fill(imageRect)
                }
            })
        }
        
        let animationName: String?
        var playOnce = false
        var seekToEnd = false
        switch icon {
        case .voiceChat:
            animationName = "anim_profilevc"
        case .mute:
            animationName = "anim_profileunmute"
            if previousIcon == .unmute {
                playOnce = true
            } else {
                seekToEnd = true
            }
        case .unmute:
            animationName = "anim_profilemute"
            if previousIcon == .mute {
                playOnce = true
            } else {
                seekToEnd = true
            }
        case .more:
            animationName = "anim_profilemore"
        case .leave:
            animationName = "anim_profileleave"
        default:
            animationName = nil
        }
        
        if let animationName = animationName {
            let animatedIcon: ComponentView<Empty>
            if let current = self.animatedIcon {
                animatedIcon = current
            } else {
                animatedIcon = ComponentView()
                self.animatedIcon = animatedIcon
            }
            let _ = animatedIcon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: animationName),
                    color: foregroundColor,
                    startingPosition: seekToEnd ? .end : .begin
                )),
                environment: {},
                containerSize: iconSize
            )
        } else if let animatedIcon = self.animatedIcon {
            self.animatedIcon = nil
            animatedIcon.view?.removeFromSuperview()
        }
        
        if let animatedIconView = self.animatedIcon?.view as? LottieComponent.View {
            if animatedIconView.superview == nil {
                self.contentNode.view.addSubview(animatedIconView)
            }
            if playOnce {
                animatedIconView.playOnce()
            }
        }
        
        transition.updateTintColor(layer: self.iconNode.layer, color: foregroundColor)
        transition.updateTintColor(layer: self.titleNode.layer, color: foregroundColor)
        transition.updateTintColor(layer: self.textNode.layer, color: foregroundColor)
        
        if isActiveUpdated {
            let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.iconNode, alpha: isActive ? 1.0 : 0.3)
            if let animatedIconView = self.animatedIcon?.view {
                alphaTransition.updateAlpha(layer: animatedIconView.layer, alpha: isActive ? 1.0 : 0.3)
            }
            alphaTransition.updateAlpha(node: self.textNode, alpha: isActive ? 1.0 : 0.3)
        }
        
        self.textNode.attributedText = NSAttributedString(string: text.lowercased(), font: Font.regular(11.0), textColor: .white)
        self.accessibilityLabel = text
        let titleSize = self.textNode.updateLayout(CGSize(width: 120.0, height: .greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height * 0.5 * (1.0 - fraction)), size: size))
        transition.updateAlpha(node: self.contentNode, alpha: fraction)
        
        let backgroundY: CGFloat = size.height * (1.0 - fraction)
        let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: backgroundY), size: CGSize(width: size.width, height: max(0.0, size.height - backgroundY)))
        //transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(view: self.backgroundView, frame: backgroundFrame)
        
        transition.updateSublayerTransformScale(node: self.contentNode, scale: 1.0 * fraction + 0.001 * (1.0 - fraction))
        
        transition.updateCornerRadius(layer: self.backgroundView.layer, cornerRadius: min(11.0, backgroundFrame.height * 0.5))
        //self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: min(11.0, backgroundFrame.height * 0.5), transition: transition)
        //self.backgroundNode.updateColor(color: backgroundColor, transition: transition)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: 1.0), size: iconSize))
        if let animatedIconView = self.animatedIcon?.view {
            transition.updateFrame(view: animatedIconView, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: 1.0), size: iconSize))
        }
        transition.updateFrameAdditiveToCenter(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 9.0), size: titleSize))
        
        self.referenceNode.frame = self.containerNode.bounds
    }
}
