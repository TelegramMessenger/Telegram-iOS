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
import TelegramPresentationData

private let sceneVersion: Int = 5

private func deg2rad(_ number: Float) -> Float {
    return number * .pi / 180
}

private func rad2deg(_ number: Float) -> Float {
    return number * 180.0 / .pi
}

public final class PremiumDiamondComponent: Component {
    let theme: PresentationTheme
    
    public init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    public static func ==(lhs: PremiumDiamondComponent, rhs: PremiumDiamondComponent) -> Bool {
        return lhs.theme === rhs.theme
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
                
        private let sceneView: SCNView
        
        private let diamondLayer: DiamondLayer
        
        private var timer: SwiftSignalKit.Timer?
                
        private var component: PremiumDiamondComponent?
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            self.sceneView.isJitteringEnabled = true
            
            self.diamondLayer = DiamondLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            
            self.layer.addSublayer(self.diamondLayer)
            
            self.setup()
            
            let panGestureRecoginzer = UIPanGestureRecognizer(target: self.diamondLayer, action: #selector(self.diamondLayer.handlePan(_:)))
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
                
        private func setup() {
            guard let scene = loadCompressedScene(name: "gift2", version: sceneVersion) else {
                return
            }
            
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            let names: [String] = [
                "particles_left",
                "particles_right",
                "particles_left_bottom",
                "particles_right_bottom",
                "particles_center"
            ]
            
            let particleColor = UIColor(rgb: 0x428df4) //0x3b9bff)
            for name in names {
                if let node = scene.rootNode.childNode(withName: name, recursively: false), let particleSystem = node.particleSystems?.first {
                    particleSystem.particleIntensity = min(1.0, 2.0 * particleSystem.particleIntensity)
                    particleSystem.particleIntensityVariation = 0.05
                    particleSystem.particleColor = particleColor
                    particleSystem.particleColorVariation = SCNVector4Make(0.0, 0.0, 0.1, 0.0)
                                      
                    if let propertyControllers = particleSystem.propertyControllers, let sizeController = propertyControllers[.size], let colorController = propertyControllers[.color] {
                        let animation = CAKeyframeAnimation()
                        if let existing = colorController.animation as? CAKeyframeAnimation {
                            animation.keyTimes = existing.keyTimes
                            animation.values = existing.values?.compactMap { ($0 as? UIColor)?.alpha } ?? []
                        } else {
                            animation.values = [ 0.0, 1.0, 1.0, 0.0 ]
                        }
                        let opacityController = SCNParticlePropertyController(animation: animation)
                        particleSystem.propertyControllers = [
                            .size: sizeController,
                            .opacity: opacityController
                        ]
                    }
                }
            }
            
            //let _ = self.sceneView.snapshot()
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
            self.setupScaleAnimation()
            
            self.playAppearanceAnimation(mirror: true, explode: true)
        }
        
        private func setupScaleAnimation() {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.duration = 2.0
            animation.fromValue = 0.9
            animation.toValue = 1.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.autoreverses = true
            animation.repeatCount = .infinity

            self.diamondLayer.add(animation, forKey: "scale")
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
                
                self.diamondLayer.playAppearanceAnimation(velocity:nil, smallAngle: false, explode: true)
            }
        }
        
        func update(component: PremiumDiamondComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.sceneView.backgroundColor = component.theme.list.blocksBackgroundColor
            
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
        
            self.diamondLayer.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.height, height: availableSize.height))
            self.diamondLayer.position = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0 - 8.0)
                        
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
