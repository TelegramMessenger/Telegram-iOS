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

private let sceneVersion: Int = 3

private func deg2rad(_ number: Float) -> Float {
    return number * .pi / 180
}

private func rad2deg(_ number: Float) -> Float {
    return number * 180.0 / .pi
}

private func generateParticlesTexture() -> UIImage {
    return UIImage()
}

private func generateFlecksTexture() -> UIImage {
    return UIImage()
}

private func generateShineTexture() -> UIImage {
    return UIImage()
}

private func generateDiffuseTexture() -> UIImage {
    return generateImage(CGSize(width: 256, height: 256), rotatedContext: { size, context in
        let colorsArray: [CGColor] = [
            UIColor(rgb: 0x0079ff).cgColor,
            UIColor(rgb: 0x6a93ff).cgColor,
            UIColor(rgb: 0x9172fe).cgColor,
            UIColor(rgb: 0xe46acd).cgColor,
        ]
        var locations: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
    })!
}

class GiftAvatarComponent: Component {
    let context: AccountContext
    let peer: EnginePeer?
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    init(context: AccountContext, peer: EnginePeer?, isVisible: Bool, hasIdleAnimations: Bool) {
        self.context = context
        self.peer = peer
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    static func ==(lhs: GiftAvatarComponent, rhs: GiftAvatarComponent) -> Bool {
        return lhs.peer == rhs.peer && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
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
            
            let panGestureRecoginzer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(panGestureRecoginzer)
            
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
        
        private var previousYaw: Float = 0.0
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            
            if #available(iOS 11.0, *) {
                node.removeAnimation(forKey: "rotate", blendOutDuration: 0.1)
                node.removeAnimation(forKey: "tapRotate", blendOutDuration: 0.1)
            } else {
                node.removeAllAnimations()
            }
            
            switch gesture.state {
                case .began:
                    self.previousYaw = 0.0
                case .changed:
                    let translation = gesture.translation(in: gesture.view)
                    let yawPan = deg2rad(Float(translation.x))
                
                    func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                        let bandedOffset = offset - bandingStart
                        let range: CGFloat = 60.0
                        let coefficient: CGFloat = 0.4
                        return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                    }
                
                    var pitchTranslation = rubberBandingOffset(offset: abs(translation.y), bandingStart: 0.0)
                    if translation.y < 0.0 {
                        pitchTranslation *= -1.0
                    }
                    let pitchPan = deg2rad(Float(pitchTranslation))
                
                    self.previousYaw = yawPan
                    node.eulerAngles = SCNVector3(pitchPan, yawPan, 0.0)
                case .ended:
                    let velocity = gesture.velocity(in: gesture.view)
                    
                    var smallAngle = false
                    if (self.previousYaw < .pi / 2 && self.previousYaw > -.pi / 2) && abs(velocity.x) < 200 {
                        smallAngle = true
                    }
                
                    self.playAppearanceAnimation(velocity: velocity.x, smallAngle: smallAngle, explode: !smallAngle && abs(velocity.x) > 600)
                    node.eulerAngles = SCNVector3(0.0, 0.0, 0.0)
                default:
                    break
            }
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
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            self.previousInteractionTimestamp = currentTime
            self.delayTapsTill = currentTime + 0.85
            
            if explode, let node = scene.rootNode.childNode(withName: "swirl", recursively: false), let particles = scene.rootNode.childNode(withName: "particles", recursively: false) {
                if let particleSystem = particles.particleSystems?.first {
                    particleSystem.particleColorVariation = SCNVector4(0.15, 0.2, 0.15, 0.3)
                    particleSystem.speedFactor = 2.0
                    particleSystem.particleVelocity = 2.2
                    particleSystem.birthRate = 4.0
                    particleSystem.particleLifeSpan = 2.0
                    
                    node.physicsField?.isActive = true
                    Queue.mainQueue().after(1.0) {
                        node.physicsField?.isActive = false
                        particles.particleSystems?.first?.birthRate = 1.2
                        particleSystem.particleVelocity = 1.0
                        particleSystem.particleLifeSpan = 4.0
                        
                        let animation = POPBasicAnimation()
                        animation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
                            property?.readBlock = { particleSystem, values in
                                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
                            }
                            property?.writeBlock = { particleSystem, values in
                                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as! POPAnimatableProperty)
                        animation.fromValue = 2.0 as NSNumber
                        animation.toValue = 1.0 as NSNumber
                        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        animation.duration = 0.5
                        particleSystem.pop_add(animation, forKey: "speedFactor")
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
            let avatarSize = CGSize(width: 100.0, height: 100.0)
            if let peer = component.peer {
                self.avatarNode.setSignal(peerAvatarCompleteImage(account: component.context.account, peer: peer, size: avatarSize, font: avatarPlaceholderFont(size: 43.0), fullSize: true))
            }
            self.avatarNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0), y: 63.0), size: avatarSize)
            
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
