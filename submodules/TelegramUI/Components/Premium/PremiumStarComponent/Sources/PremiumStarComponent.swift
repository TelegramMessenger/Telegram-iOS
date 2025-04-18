import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents
import TelegramPresentationData

private let sceneVersion: Int = 7

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

private func generateDiffuseTexture(colors: [UIColor]) -> UIImage {
    return generateImage(CGSize(width: 256, height: 256), rotatedContext: { size, context in
        let colorsArray: [CGColor] = colors.map { $0.cgColor }
        var locations: [CGFloat] = []
        for i in 0 ..< colors.count {
            let t = CGFloat(i) / CGFloat(colors.count - 1)
            locations.append(t)
        }
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
    })!
}

public func loadCompressedScene(name: String, version: Int) -> SCNScene? {
    let resourceUrl: URL
    if let url = getAppBundle().url(forResource: name, withExtension: "scn") {
        resourceUrl = url
    } else {
        let fileName = "\(name)_\(version).scn"
        let tmpUrl = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
        if !FileManager.default.fileExists(atPath: tmpUrl.path) {
            guard let url = getAppBundle().url(forResource: name, withExtension: ""),
                  let compressedData = try? Data(contentsOf: url),
                  let decompressedData = TGGUnzipData(compressedData, 8 * 1024 * 1024) else {
                return nil
            }
            try? decompressedData.write(to: tmpUrl)
        }
        resourceUrl = tmpUrl
    }
    
    guard let scene = try? SCNScene(url: resourceUrl, options: nil) else {
        return nil
    }
    return scene
}

public final class PremiumStarComponent: Component {
    let theme: PresentationTheme
    let isIntro: Bool
    let isVisible: Bool
    let hasIdleAnimations: Bool
    let colors: [UIColor]?
    let particleColor: UIColor?
    let backgroundColor: UIColor?
    
    public init(
        theme: PresentationTheme,
        isIntro: Bool,
        isVisible: Bool,
        hasIdleAnimations: Bool,
        colors: [UIColor]? = nil,
        particleColor: UIColor? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self.theme = theme
        self.isIntro = isIntro
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
        self.colors = colors
        self.particleColor = particleColor
        self.backgroundColor = backgroundColor
    }
    
    public static func ==(lhs: PremiumStarComponent, rhs: PremiumStarComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.isIntro == rhs.isIntro && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations && lhs.colors == rhs.colors && lhs.particleColor == rhs.particleColor && lhs.backgroundColor == rhs.backgroundColor
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
        
        private var component: PremiumStarComponent?
        
        private var _ready = Promise<Bool>()
        public var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        public weak var animateFrom: UIView?
        public weak var containerView: UIView?
        public var animationColor: UIColor?
        
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
        
        private func updateColors(animated: Bool = false) {
            guard let component = self.component, let colors = component.colors, let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            if animated {
                UIView.animate(withDuration: 0.25, animations: {
                    node.geometry?.materials.first?.diffuse.contents = generateDiffuseTexture(colors: colors)
                })
            } else {
                node.geometry?.materials.first?.diffuse.contents = generateDiffuseTexture(colors: colors)
            }
            
            let names: [String] = [
                "particles_left",
                "particles_right",
                "particles_left_bottom",
                "particles_right_bottom",
                "particles_center"
            ]
            
            let starNames: [String] = [
                "coins_left",
                "coins_right"
            ]
            
            if let particleColor = component.particleColor {
                for name in starNames {
                    if let node = scene.rootNode.childNode(withName: name, recursively: false), let particleSystem = node.particleSystems?.first {
                        if animated {
                            particleSystem.warmupDuration = 0.0
                        }
                        particleSystem.particleIntensity = 1.0
                        particleSystem.particleIntensityVariation = 0.05
                        particleSystem.particleColor = particleColor
                        particleSystem.particleColorVariation = SCNVector4Make(0.07, 0.0, 0.1, 0.0)
                        node.isHidden = false
                        
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
            } else {
                if animated {
                    for name in starNames {
                        if let node = scene.rootNode.childNode(withName: name, recursively: false) {
                            node.isHidden = true
                        }
                    }
                }
            }
            
            for name in names {
                if let node = scene.rootNode.childNode(withName: name, recursively: false), let particleSystem = node.particleSystems?.first {
                    if let particleColor = component.particleColor {
                        particleSystem.particleIntensity = min(1.0, 2.0 * particleSystem.particleIntensity)
                        particleSystem.particleIntensityVariation = 0.05
                        particleSystem.particleColor = particleColor
                        particleSystem.particleColorVariation = SCNVector4Make(0.1, 0.0, 0.12, 0.0)
                    } else {
                        particleSystem.particleColorVariation = SCNVector4Make(0.12, 0.03, 0.035, 0.0)
                        if animated {
                            particleSystem.particleColor = UIColor(rgb: 0xaa69ea)
                        }
                    }
                                            
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
        }
        
        private var didSetup = false
        private func setup() {
            guard !self.didSetup, let scene = loadCompressedScene(name: "star2", version: sceneVersion) else {
                return
            }
            
            self.didSetup = true
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            self.updateColors()
            
            if self.animateFrom != nil {
                let _ = self.sceneView.snapshot()
            } else {
                self.didSetReady = true
                self._ready.set(.single(true))
                self.onReady()
            }
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
        
        private func playAppearanceAnimation(
            velocity: CGFloat? = nil,
            smallAngle: Bool = false,
            mirror: Bool = false,
            explode: Bool = false,
            force: Bool = false
        ) {
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
        
            var from = node.presentation.eulerAngles
            if abs(from.y) - .pi * 2.0 < 0.05 {
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
        
        func update(component: PremiumStarComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            self.setup()
            
            if let previousComponent, component.colors != previousComponent.colors {
                self.updateColors(animated: true)
                self.playAppearanceAnimation(velocity: nil, mirror: component.colors?.contains(UIColor(rgb: 0xe57d02)) == true, explode: true, force: true)
            }
            
            if let backgroundColor = component.backgroundColor {
                self.sceneView.backgroundColor = backgroundColor
            } else {
                self.sceneView.backgroundColor = .clear
            }
            
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect(), isIntro: self.isIntro)
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

public final class StandalonePremiumStarComponent: Component {
    let theme: PresentationTheme
    let colors: [UIColor]?
    
    public init(
        theme: PresentationTheme,
        colors: [UIColor]? = nil
    ) {
        self.theme = theme
        self.colors = colors
    }
    
    public static func ==(lhs: StandalonePremiumStarComponent, rhs: StandalonePremiumStarComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.colors == rhs.colors
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
        
        private var component: StandalonePremiumStarComponent?
        
        private var _ready = Promise<Bool>()
        public var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        private let sceneView: SCNView
                
        private var timer: SwiftSignalKit.Timer?
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            self.sceneView.isJitteringEnabled = true
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
        }
        
        private var didSetup = false
        private func setup() {
            guard !self.didSetup, let scene = loadCompressedScene(name: "star2", version: sceneVersion) else {
                return
            }
            
            self.didSetup = true
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            if let component = self.component, let node = scene.rootNode.childNode(withName: "star", recursively: false), let colors =
                component.colors {
                node.geometry?.materials.first?.diffuse.contents = generateDiffuseTexture(colors: colors)
            }
            
            for node in scene.rootNode.childNodes {
                if let name = node.name, name.hasPrefix("particles") {
                    node.isHidden = true
                }
            }
            
            self.didSetReady = true
            self._ready.set(.single(true))
            self.onReady()
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
            //self.setupScaleAnimation()
            //self.setupGradientAnimation()
            
            self.playAppearanceAnimation(mirror: true)
        }
        
        private func setupScaleAnimation() {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }

            let fromScale: Float = 0.1
            let toScale: Float = 0.092
            
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
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
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
            
            let animation = CABasicAnimation(keyPath: "eulerAngles")
            animation.fromValue = NSValue(scnVector3: from)
            animation.toValue = NSValue(scnVector3: to)
            animation.duration = 0.4 * UIView.animationDurationFactor()
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.completion = { [weak node] finished in
                if finished {
                    node?.eulerAngles = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
                }
            }
            node.addAnimation(animation, forKey: "rotate")
        }
        
        func update(component: StandalonePremiumStarComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.setup()
            
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
