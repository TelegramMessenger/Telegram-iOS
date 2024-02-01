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
import TelegramCore
import MultilineTextComponent
import TelegramPresentationData

private let sceneVersion: Int = 3

public final class BoostHeaderBackgroundComponent: Component {
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    public init(isVisible: Bool, hasIdleAnimations: Bool) {
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    public static func ==(lhs: BoostHeaderBackgroundComponent, rhs: BoostHeaderBackgroundComponent) -> Bool {
        return lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
    }
    
    public final class View: UIView, SCNSceneRendererDelegate {
        private var _ready = Promise<Bool>()
        var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
                
        private let sceneView: SCNView
        
        private var previousInteractionTimestamp: Double = 0.0
        private var hasIdleAnimations = false
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            
            self.setup()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
                
        private func setup() {
            guard let url = getAppBundle().url(forResource: "boost", withExtension: "scn"), let scene = try? SCNScene(url: url, options: nil) else {
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
            self.playAppearanceAnimation(explode: true)
        }
        

        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            self.previousInteractionTimestamp = currentTime
            
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
        
        func update(component: BoostHeaderBackgroundComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
