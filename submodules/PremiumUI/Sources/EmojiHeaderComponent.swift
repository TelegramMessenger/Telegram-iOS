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
import AnimationCache
import MultiAnimationRenderer
import EmojiStatusComponent

private let sceneVersion: Int = 3

class EmojiHeaderComponent: Component {
    let context: AccountContext
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    let placeholderColor: UIColor
    let fileId: Int64
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        placeholderColor: UIColor,
        fileId: Int64,
        isVisible: Bool,
        hasIdleAnimations: Bool
    ) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.placeholderColor = placeholderColor
        self.fileId = fileId
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    static func ==(lhs: EmojiHeaderComponent, rhs: EmojiHeaderComponent) -> Bool {
        return lhs.placeholderColor == rhs.placeholderColor && lhs.fileId == rhs.fileId && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
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
        let statusView: ComponentHostView<Empty>
        
        private var previousInteractionTimestamp: Double = 0.0
        private var timer: SwiftSignalKit.Timer?
        private var hasIdleAnimations = false
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
                        
            self.statusView = ComponentHostView<Empty>()
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            self.addSubview(self.statusView)
            
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
        
        private func maybeAnimateIn() {
            guard let animateFrom = self.animateFrom, var containerView = self.containerView else {
                return
            }
                        
            containerView = containerView.subviews[2].subviews[1]
            
            let initialPosition = self.statusView.center
            let targetPosition = self.statusView.superview!.convert(self.statusView.center, to: containerView)
            let sourcePosition = animateFrom.superview!.convert(animateFrom.center, to: containerView).offsetBy(dx: 0.0, dy: -20.0)
            
            containerView.addSubview(self.statusView)
            self.statusView.center = targetPosition
            
            animateFrom.alpha = 0.0
            self.statusView.layer.animateScale(from: 0.05, to: 1.0, duration: 0.8, timingFunction: kCAMediaTimingFunctionSpring)
            self.statusView.layer.animatePosition(from: sourcePosition, to: targetPosition, duration: 0.8, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                self.addSubview(self.statusView)
                self.statusView.center = initialPosition
            })
            
            Queue.mainQueue().after(0.4, {
                animateFrom.alpha = 1.0
            })
            
            self.animateFrom = nil
            self.containerView = nil
        }
        
        private func onReady() {
            self.setupScaleAnimation()
            
            self.maybeAnimateIn()
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
//            let animation = CABasicAnimation(keyPath: "transform.scale")
//            animation.duration = 2.0
//            animation.fromValue = 1.0
//            animation.toValue = 1.15
//            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//            animation.autoreverses = true
//            animation.repeatCount = .infinity
//
//            self.avatarNode.view.layer.add(animation, forKey: "scale")
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
        
        func update(component: EmojiHeaderComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            let size = self.statusView.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: component.context,
                    animationCache: component.animationCache,
                    animationRenderer: component.animationRenderer,
                    content: .animation(
                        content: .customEmoji(fileId: component.fileId),
                        size: CGSize(width: 100.0, height: 100.0),
                        placeholderColor: component.placeholderColor
                    ),
                    action: nil,
                    longTapAction: nil
                )),
                environment: {},
                containerSize: CGSize(width: 96.0, height: 96.0)
            )
            self.statusView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - size.width) / 2.0), y: 63.0), size: size)

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
