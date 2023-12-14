import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents
import AvatarNode
import AccountContext
import TelegramCore
import MergedAvatarsNode
import MultilineTextComponent
import TelegramPresentationData

private let sceneVersion: Int = 3

class GiftAvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peers: [EnginePeer]
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    init(context: AccountContext, theme: PresentationTheme, peers: [EnginePeer], isVisible: Bool, hasIdleAnimations: Bool) {
        self.context = context
        self.theme = theme
        self.peers = peers
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    static func ==(lhs: GiftAvatarComponent, rhs: GiftAvatarComponent) -> Bool {
        return lhs.peers == rhs.peers && lhs.theme === rhs.theme && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
    }
    
    final class View: UIView, SCNSceneRendererDelegate, ComponentTaggedView {
        final class Tag {
        }
        
        func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        private var _ready = Promise<Bool>()
        var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        weak var animateFrom: UIView?
        weak var containerView: UIView?
        var animationColor: UIColor?
        
        private let sceneView: SCNView
        private let avatarNode: ImageNode
        private var mergedAvatarsNode: MergedAvatarsNode?
        
        private let badgeBackground = ComponentView<Empty>()
        private let badge = ComponentView<Empty>()
        
        private var previousInteractionTimestamp: Double = 0.0
        private var timer: SwiftSignalKit.Timer?
        private var hasIdleAnimations = false
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            
            self.avatarNode = ImageNode()
            self.avatarNode.displaysAsynchronously = false
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            self.addSubview(self.avatarNode.view)
            
            self.setup()
                        
            let tapGestureRecoginzer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.addGestureRecognizer(tapGestureRecoginzer)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
        }
        
        private let hapticFeedback = HapticFeedback()
        
        private var delayTapsTill: Double?
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            self.playAppearanceAnimation(velocity: nil, mirror: false, explode: true)
        }
        
        private func setup() {
            guard let url = getAppBundle().url(forResource: "gift", withExtension: "scn"), let scene = try? SCNScene(url: url, options: nil) else {
                return
            }
            
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            let _ = self.sceneView.snapshot()
        }
        
        private var didSetReady = false
        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            if !self.didSetReady {
                self.didSetReady = true
                
                Queue.mainQueue().justDispatch {
                    self._ready.set(.single(true))
                    self.onReady()
                }
            }
        }
        
        private func onReady() {
            self.setupScaleAnimation()
            
            self.playAppearanceAnimation(explode: true)
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            self.timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                if let strongSelf = self, strongSelf.hasIdleAnimations {
                    let currentTimestamp = CACurrentMediaTime()
                    if currentTimestamp > strongSelf.previousInteractionTimestamp + 5.0 {
                        strongSelf.playAppearanceAnimation()
                    }
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
        
        private func setupScaleAnimation() {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.duration = 2.0
            animation.fromValue = 1.0
            animation.toValue = 1.15
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.autoreverses = true
            animation.repeatCount = .infinity

            self.avatarNode.view.layer.add(animation, forKey: "scale")
        }
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            self.previousInteractionTimestamp = currentTime
            self.delayTapsTill = currentTime + 0.85
            
            if explode, let node = scene.rootNode.childNode(withName: "swirl", recursively: false), let particlesLeft = scene.rootNode.childNode(withName: "particles_left", recursively: false), let particlesRight = scene.rootNode.childNode(withName: "particles_right", recursively: false), let particlesBottomLeft = scene.rootNode.childNode(withName: "particles_left_bottom", recursively: false), let particlesBottomRight = scene.rootNode.childNode(withName: "particles_right_bottom", recursively: false) {
                if let leftParticleSystem = particlesLeft.particleSystems?.first, let rightParticleSystem = particlesRight.particleSystems?.first, let leftBottomParticleSystem = particlesBottomLeft.particleSystems?.first, let rightBottomParticleSystem = particlesBottomRight.particleSystems?.first {
                    leftParticleSystem.speedFactor = 2.0
                    leftParticleSystem.particleVelocity = 1.6
                    leftParticleSystem.birthRate = 60.0
                    leftParticleSystem.particleLifeSpan = 4.0
                    
                    rightParticleSystem.speedFactor = 2.0
                    rightParticleSystem.particleVelocity = 1.6
                    rightParticleSystem.birthRate = 60.0
                    rightParticleSystem.particleLifeSpan = 4.0
                    
//                    leftBottomParticleSystem.speedFactor = 2.0
                    leftBottomParticleSystem.particleVelocity = 1.6
                    leftBottomParticleSystem.birthRate = 24.0
                    leftBottomParticleSystem.particleLifeSpan = 7.0
                    
//                    rightBottomParticleSystem.speedFactor = 2.0
                    rightBottomParticleSystem.particleVelocity = 1.6
                    rightBottomParticleSystem.birthRate = 24.0
                    rightBottomParticleSystem.particleLifeSpan = 7.0
                    
                    node.physicsField?.isActive = true
                    Queue.mainQueue().after(1.0) {
                        node.physicsField?.isActive = false
                        
                        leftParticleSystem.birthRate = 12.0
                        leftParticleSystem.particleVelocity = 1.2
                        leftParticleSystem.particleLifeSpan = 3.0
                        
                        rightParticleSystem.birthRate = 12.0
                        rightParticleSystem.particleVelocity = 1.2
                        rightParticleSystem.particleLifeSpan = 3.0
                        
                        leftBottomParticleSystem.particleVelocity = 1.2
                        leftBottomParticleSystem.birthRate = 7.0
                        leftBottomParticleSystem.particleLifeSpan = 5.0
                        
                        rightBottomParticleSystem.particleVelocity = 1.2
                        rightBottomParticleSystem.birthRate = 7.0
                        rightBottomParticleSystem.particleLifeSpan = 5.0
                        
                        let leftAnimation = POPBasicAnimation()
                        leftAnimation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
                            property?.readBlock = { particleSystem, values in
                                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
                            }
                            property?.writeBlock = { particleSystem, values in
                                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as! POPAnimatableProperty)
                        leftAnimation.fromValue = 1.2 as NSNumber
                        leftAnimation.toValue = 0.85 as NSNumber
                        leftAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        leftAnimation.duration = 0.5
                        leftParticleSystem.pop_add(leftAnimation, forKey: "speedFactor")
                        
                        let rightAnimation = POPBasicAnimation()
                        rightAnimation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
                            property?.readBlock = { particleSystem, values in
                                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
                            }
                            property?.writeBlock = { particleSystem, values in
                                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as! POPAnimatableProperty)
                        rightAnimation.fromValue = 1.2 as NSNumber
                        rightAnimation.toValue = 0.85 as NSNumber
                        rightAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        rightAnimation.duration = 0.5
                        rightParticleSystem.pop_add(rightAnimation, forKey: "speedFactor")
                    }
                }
            }
        }
        
        func update(component: GiftAvatarComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            if component.peers.count > 1 {
                let avatarSize = CGSize(width: 60.0, height: 60.0)
                
                let mergedAvatarsNode: MergedAvatarsNode
                if let current = self.mergedAvatarsNode {
                    mergedAvatarsNode = current
                } else {
                    mergedAvatarsNode = MergedAvatarsNode()
                    mergedAvatarsNode.isUserInteractionEnabled = false
                    self.addSubview(mergedAvatarsNode.view)
                    self.mergedAvatarsNode = mergedAvatarsNode
                }
                
                mergedAvatarsNode.update(context: component.context, peers: Array(component.peers.map { $0._asPeer() }.prefix(3)), synchronousLoad: false, imageSize: avatarSize.width, imageSpacing: 30.0, borderWidth: 2.0, avatarFontSize: 26.0)
                let avatarsSize = CGSize(width: avatarSize.width + 30.0 * CGFloat(min(3, component.peers.count) - 1), height: avatarSize.height)
                mergedAvatarsNode.updateLayout(size: avatarsSize)
                mergedAvatarsNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarsSize.width) / 2.0), y: 113.0 - avatarSize.height / 2.0), size: avatarsSize)
                self.avatarNode.isHidden = true
            } else {
                self.mergedAvatarsNode?.view.removeFromSuperview()
                self.mergedAvatarsNode = nil
                self.avatarNode.isHidden = false
                
                let avatarSize = CGSize(width: 100.0, height: 100.0)
                if let peer = component.peers.first {
                    self.avatarNode.setSignal(peerAvatarCompleteImage(account: component.context.account, peer: peer, size: avatarSize, font: avatarPlaceholderFont(size: 43.0), fullSize: true))
                }
                self.avatarNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0), y: 113.0 - avatarSize.height / 2.0), size: avatarSize)
            }
            
            if component.peers.count > 3 {
                let badgeTextSize = self.badge.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: "+\(component.peers.count - 3)", font: Font.with(size: 10.0, design: .round, weight: .semibold), textColor: component.theme.list.itemCheckColors.foregroundColor))
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                
                let lineWidth = 1.0 + UIScreenPixel
                let badgeSize = CGSize(width: max(17.0, badgeTextSize.width + 7.0) + lineWidth * 2.0, height: 17.0 + lineWidth * 2.0)
                let _ = self.badgeBackground.update(
                    transition: .immediate,
                    component: AnyComponent(
                        RoundedRectangle(color: component.theme.list.itemCheckColors.fillColor, cornerRadius: badgeSize.height / 2.0, stroke: lineWidth, strokeColor: component.theme.list.blocksBackgroundColor)
                    ),
                    environment: {},
                    containerSize: badgeSize
                )
                
                if let badgeTextView = self.badge.view, let badgeBackgroundView = self.badgeBackground.view {
                    if badgeBackgroundView.superview == nil {
                        self.addSubview(badgeBackgroundView)
                        self.addSubview(badgeTextView)
                    }
                    
                    let avatarsSize = CGSize(width: 120.0, height: 60.0)
                    let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width + avatarsSize.width) / 2.0) - 19.0 - lineWidth, y: 113.0 + avatarsSize.height / 2.0 - 15.0 - lineWidth), size: badgeSize)
                    badgeBackgroundView.frame = backgroundFrame
                    badgeTextView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeTextSize.width / 2.0), y: floorToScreenPixels(backgroundFrame.midY - badgeTextSize.height / 2.0) - UIScreenPixel), size: badgeTextSize)
                }
            } else {
                self.badge.view?.removeFromSuperview()
                self.badgeBackground.view?.removeFromSuperview()
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
