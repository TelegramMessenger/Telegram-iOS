import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents

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

class PremiumStarComponent: Component {
    let isIntro: Bool
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    init(isIntro: Bool, isVisible: Bool, hasIdleAnimations: Bool) {
        self.isIntro = isIntro
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    static func ==(lhs: PremiumStarComponent, rhs: PremiumStarComponent) -> Bool {
        return lhs.isIntro == rhs.isIntro && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
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
                
        private var previousInteractionTimestamp: Double = 0.0
        private var timer: SwiftSignalKit.Timer?
        private var hasIdleAnimations = false
        
        private let isIntro: Bool
        
        init(frame: CGRect, isIntro: Bool) {
            self.isIntro = isIntro
            
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
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            self.previousInteractionTimestamp = currentTime
            if let delayTapsTill = self.delayTapsTill, currentTime < delayTapsTill {
                return
            }
            
            var left: Bool?
            var top: Bool?
            if let view = gesture.view {
                let point = gesture.location(in: view)
                let horizontalDistanceFromCenter = abs(point.x - view.frame.size.width / 2.0)
                if horizontalDistanceFromCenter > 60.0 {
                    return
                }
                let verticalDistanceFromCenter = abs(point.y - view.frame.size.height / 2.0)
                if horizontalDistanceFromCenter > 20.0 {
                    left = point.x < view.frame.width / 2.0
                }
                if verticalDistanceFromCenter > 20.0 {
                    top = point.y < view.frame.height / 2.0
                }
            }
            
            if node.animationKeys.contains("tapRotate"), let left = left {
                self.playAppearanceAnimation(velocity: nil, mirror: left, explode: true)
                
                self.hapticFeedback.impact(.medium)
                return
            }
            
            let initial = node.eulerAngles
            var yaw: CGFloat = 0.0
            var pitch: CGFloat = 0.0
            if let left = left {
                yaw = left ? -0.6 : 0.6
            }
            if let top = top {
                pitch = top ? -0.3 : 0.3
            }
            let target = SCNVector3(pitch, yaw, 0.0)
                        
            let animation = CABasicAnimation(keyPath: "eulerAngles")
            animation.fromValue = NSValue(scnVector3: initial)
            animation.toValue = NSValue(scnVector3: target)
            animation.duration = 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            node.addAnimation(animation, forKey: "tapRotate")
            
            node.eulerAngles = target
            
            Queue.mainQueue().after(0.25) {
                node.eulerAngles = initial
                let springAnimation = CASpringAnimation(keyPath: "eulerAngles")
                springAnimation.fromValue = NSValue(scnVector3: target)
                springAnimation.toValue = NSValue(scnVector3: SCNVector3(x: 0.0, y: 0.0, z: 0.0))
                springAnimation.mass = 1.0
                springAnimation.stiffness = 21.0
                springAnimation.damping = 5.8
                springAnimation.duration = springAnimation.settlingDuration * 0.8
                node.addAnimation(springAnimation, forKey: "tapRotate")
            }
            
            self.hapticFeedback.tap()
        }
        
        private var previousYaw: Float = 0.0
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            
            let keys = [
                "rotate",
                "tapRotate"
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
            let resourceUrl: URL
            if let url = getAppBundle().url(forResource: "star", withExtension: "scn") {
                resourceUrl = url
            } else {
                let fileName = "star_\(sceneVersion).scn"
                let tmpUrl = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
                if !FileManager.default.fileExists(atPath: tmpUrl.path) {
                    guard let url = getAppBundle().url(forResource: "star", withExtension: ""),
                          let compressedData = try? Data(contentsOf: url),
                          let decompressedData = TGGUnzipData(compressedData, 8 * 1024 * 1024) else {
                        return
                    }
                    try? decompressedData.write(to: tmpUrl)
                }
                resourceUrl = tmpUrl
            }
            
            guard let scene = try? SCNScene(url: resourceUrl, options: nil) else {
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
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false), let animateFrom = self.animateFrom, var containerView = self.containerView else {
                return
            }
                        
            containerView = containerView.subviews[2].subviews[1]
            
            if let animationColor = self.animationColor {
                let newNode = node.clone()
                newNode.geometry = node.geometry?.copy() as? SCNGeometry
                
                let colorMaterial = SCNMaterial()
                colorMaterial.diffuse.contents = animationColor
                colorMaterial.lightingModel = SCNMaterial.LightingModel.blinn
                newNode.geometry?.materials = [colorMaterial]
                node.addChildNode(newNode)
                
                newNode.scale = SCNVector3(1.03, 1.03, 1.03)
                newNode.geometry?.materials.first?.diffuse.contents = animationColor
                   
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.beginTime = CACurrentMediaTime() + 0.1
                animation.duration = 0.7
                animation.fromValue = 1.0
                animation.toValue = 0.0
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
                animation.completion = { [weak newNode] _ in
                    newNode?.removeFromParentNode()
                }
                newNode.addAnimation(animation, forKey: "opacity")
            }
            
            let initialPosition = self.sceneView.center
            let targetPosition = self.sceneView.superview!.convert(self.sceneView.center, to: containerView)
            let sourcePosition = animateFrom.superview!.convert(animateFrom.center, to: containerView).offsetBy(dx: 0.0, dy: -20.0)
            
            containerView.addSubview(self.sceneView)
            self.sceneView.center = targetPosition
            
            animateFrom.alpha = 0.0
            self.sceneView.layer.animateScale(from: 0.05, to: 0.5, duration: 1.0, timingFunction: kCAMediaTimingFunctionSpring)
            self.sceneView.layer.animatePosition(from: sourcePosition, to: targetPosition, duration: 1.0, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                self.addSubview(self.sceneView)
                self.sceneView.center = initialPosition
            })
            
            Queue.mainQueue().after(0.4, {
                animateFrom.alpha = 1.0
            })
            
            self.animateFrom = nil
            self.containerView = nil
        }
        
        private func onReady() {
            self.setupScaleAnimation()
            self.setupGradientAnimation()
            self.setupShineAnimation()
            
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
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }

            let fromScale: Float = self.isIntro ? 0.1 : 0.08
            let toScale: Float = self.isIntro ? 0.115 : 0.092
            
            let animation = CABasicAnimation(keyPath: "scale")
            animation.duration = 2.0
            animation.fromValue = NSValue(scnVector3: SCNVector3(x: fromScale, y: fromScale, z: fromScale))
            animation.toValue = NSValue(scnVector3: SCNVector3(x: toScale, y: toScale, z: toScale))
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.autoreverses = true
            animation.repeatCount = .infinity

            node.addAnimation(animation, forKey: "scale")
        }
        
        private func setupGradientAnimation() {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            guard let initial = node.geometry?.materials.first?.diffuse.contentsTransform else {
                return
            }
            
            let animation = CABasicAnimation(keyPath: "contentsTransform")
            animation.duration = 4.5
            animation.fromValue = NSValue(scnMatrix4: initial)
            animation.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -0.35, 0.35, 0))
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            
            node.geometry?.materials.first?.diffuse.addAnimation(animation, forKey: "gradient")
        }
        
        private func setupShineAnimation() {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            guard let initial = node.geometry?.materials.first?.emission.contentsTransform else {
                return
            }
            
            let animation = CABasicAnimation(keyPath: "contentsTransform")
            animation.fillMode = .forwards
            animation.fromValue = NSValue(scnMatrix4: initial)
            animation.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -1.6, 0.0, 0.0))
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.beginTime = 1.1
            animation.duration = 0.9
            
            let group = CAAnimationGroup()
            group.animations = [animation]
            group.beginTime = 1.0
            group.duration = 4.0
            group.repeatCount = .infinity
            
            node.geometry?.materials.first?.emission.addAnimation(group, forKey: "shimmer")
        }
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
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
                    
                    leftBottomParticleSystem.particleVelocity = 1.6
                    leftBottomParticleSystem.birthRate = 24.0
                    leftBottomParticleSystem.particleLifeSpan = 7.0
                    
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
        
            var from = node.presentation.eulerAngles
            if abs(from.y - .pi * 2.0) < 0.001 {
                from.y = 0.0
            }
            node.removeAnimation(forKey: "tapRotate")
            
            var toValue: Float = smallAngle ? 0.0 : .pi * 2.0
            if let velocity = velocity, !smallAngle && abs(velocity) > 200 && velocity < 0.0 {
                toValue *= -1
            }
            if mirror {
                toValue *= -1
            }
            let to = SCNVector3(x: 0.0, y: toValue, z: 0.0)
            let distance = rad2deg(to.y - from.y)
            
            guard !distance.isZero else {
                return
            }
            
            let springAnimation = CASpringAnimation(keyPath: "eulerAngles")
            springAnimation.fromValue = NSValue(scnVector3: from)
            springAnimation.toValue = NSValue(scnVector3: to)
            springAnimation.mass = 1.0
            springAnimation.stiffness = 21.0
            springAnimation.damping = 5.8
            springAnimation.duration = springAnimation.settlingDuration * 0.75
            springAnimation.initialVelocity = velocity.flatMap { abs($0 / CGFloat(distance)) } ?? 1.7
            springAnimation.completion = { [weak node] finished in
                if finished {
                    node?.eulerAngles = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
                }
            }
            node.addAnimation(springAnimation, forKey: "rotate")
        }
        
        func update(component: PremiumStarComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect(), isIntro: self.isIntro)
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
