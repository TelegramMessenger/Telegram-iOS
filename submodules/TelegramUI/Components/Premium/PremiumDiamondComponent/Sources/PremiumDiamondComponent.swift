import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents
import PremiumStarComponent

private let sceneVersion: Int = 5

private func deg2rad(_ number: Float) -> Float {
    return number * .pi / 180
}

private func rad2deg(_ number: Float) -> Float {
    return number * 180.0 / .pi
}

public final class PremiumDiamondComponent: Component {
    public init() {
    }
    
    public static func ==(lhs: PremiumDiamondComponent, rhs: PremiumDiamondComponent) -> Bool {
        return true
    }
    
    public final class View: UIView, SCNSceneRendererDelegate, ComponentTaggedView {
        public final class Tag {
            public init() {
                
            }
        }
        
        public func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        private var _ready = Promise<Bool>()
        public var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        weak var animateFrom: UIView?
        weak var containerView: UIView?
        
        private let sceneView: SCNView
                
        private var timer: SwiftSignalKit.Timer?
                
        private var component: PremiumDiamondComponent?
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            self.sceneView.isJitteringEnabled = true
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            
            self.setup()
            
            let panGestureRecoginzer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(panGestureRecoginzer)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
        }
                
        private var previousYaw: Float = 0.0
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            let keys = [
                "rotate",
                "tapRotate",
                "continuousRotation"
            ]

            for key in keys {
                node.removeAnimation(forKey: key)
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
                    // Maintain the initial tilt while adding pan gestures
                    let initialTiltX: Float = deg2rad(-15.0)
                    let initialTiltZ: Float = deg2rad(5.0)
                    node.eulerAngles = SCNVector3(initialTiltX + pitchPan, yawPan, initialTiltZ)
                case .ended:
                    let velocity = gesture.velocity(in: gesture.view)
                    
                    var smallAngle = false
                    if (self.previousYaw < .pi / 2 && self.previousYaw > -.pi / 2) && abs(velocity.x) < 200 {
                        smallAngle = true
                    }
                
                    self.playAppearanceAnimation(velocity: velocity.x, smallAngle: smallAngle, explode: !smallAngle && abs(velocity.x) > 600)
                default:
                    break
            }
        }
        
        private func setup() {
            guard let scene = loadCompressedScene(name: "diamond", version: sceneVersion) else {
                return
            }
            
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            let _ = self.sceneView.snapshot()
        }
        
        private var didSetReady = false
        public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            if !self.didSetReady {
                self.didSetReady = true
                
                Queue.mainQueue().justDispatch {
                    self._ready.set(.single(true))
                    self.onReady()
                }
            }
        }
        
        private func onReady() {
            self.playAppearanceAnimation(mirror: true, explode: true)
        }
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene else {
                return
            }
                        
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
                    
                    leftBottomParticleSystem.particleVelocity = 1.6
                    leftBottomParticleSystem.birthRate = 24.0
                    leftBottomParticleSystem.particleLifeSpan = 7.0
                    
                    rightBottomParticleSystem.particleVelocity = 1.6
                    rightBottomParticleSystem.birthRate = 24.0
                    rightBottomParticleSystem.particleLifeSpan = 7.0
                    
                    node.physicsField?.isActive = true
                    Queue.mainQueue().after(1.0) {
                        node.physicsField?.isActive = false
                        
                        leftParticleSystem.birthRate = 15.0
                        leftParticleSystem.particleVelocity = 1.0
                        leftParticleSystem.particleLifeSpan = 3.0
                        
                        rightParticleSystem.birthRate = 15.0
                        rightParticleSystem.particleVelocity = 1.0
                        rightParticleSystem.particleLifeSpan = 3.0
                        
                        leftBottomParticleSystem.particleVelocity = 1.0
                        leftBottomParticleSystem.birthRate = 10.0
                        leftBottomParticleSystem.particleLifeSpan = 5.0
                        
                        rightBottomParticleSystem.particleVelocity = 1.0
                        rightBottomParticleSystem.birthRate = 10.0
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
            
//            var from = node.presentation.eulerAngles
//            if abs(from.y - .pi * 2.0) < 0.001 {
//                from.y = 0.0
//            }
//            node.removeAnimation(forKey: "tapRotate")
//            
//            var toValue: Float = smallAngle ? 0.0 : .pi * 2.0
//            if let velocity = velocity, !smallAngle && abs(velocity) > 200 && velocity < 0.0 {
//                toValue *= -1
//            }
//            if mirror {
//                toValue *= -1
//            }
//            
//            
//            let to = SCNVector3(x: from.x, y: toValue, z: from.z)
//            let distance = rad2deg(to.y - from.y)
//            
//            guard !distance.isZero else {
//                Queue.mainQueue().after(0.1) { [weak self] in
//                    self?.setupContinuousRotation()
//                }
//                return
//            }
//            
//            let springAnimation = CASpringAnimation(keyPath: "eulerAngles")
//            springAnimation.fromValue = NSValue(scnVector3: from)
//            springAnimation.toValue = NSValue(scnVector3: to)
//            springAnimation.mass = 1.0
//            springAnimation.stiffness = 21.0
//            springAnimation.damping = 5.8
//            springAnimation.duration = springAnimation.settlingDuration * 0.75
//            springAnimation.initialVelocity = velocity.flatMap { abs($0 / CGFloat(distance)) } ?? 1.7
//            springAnimation.completion = { [weak self] finished in
//                if finished {
//                    self?.setupContinuousRotation()
//                }
//            }
//            node.addAnimation(springAnimation, forKey: "rotate")
        }
        
        func update(component: PremiumDiamondComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
                        
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
