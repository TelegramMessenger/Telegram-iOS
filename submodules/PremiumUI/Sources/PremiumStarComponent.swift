import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle

private let sceneVersion: Int = 1

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
    let isVisible: Bool
    
    init(isVisible: Bool) {
        self.isVisible = isVisible
    }
    
    static func ==(lhs: PremiumStarComponent, rhs: PremiumStarComponent) -> Bool {
        return lhs.isVisible == rhs.isVisible
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
        
        private let sceneView: SCNView
                
        private var previousInteractionTimestamp: Double = 0.0
        private var timer: SwiftSignalKit.Timer?
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: frame)
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            
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
        
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            
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
                    let pitchPan = deg2rad(Float(translation.y))
                
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
            guard let url = getAppBundle().url(forResource: "star", withExtension: ""),
                  let compressedData = try? Data(contentsOf: url),
                  let decompressedData = TGGUnzipData(compressedData, 8 * 1024 * 1024) else {
                return
            }
            let fileName = "star_\(sceneVersion).scn"
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
            if !FileManager.default.fileExists(atPath: tmpURL.path) {
                try? decompressedData.write(to: tmpURL)
            }
            
            guard let scene = try? SCNScene(url: tmpURL, options: nil) else {
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
                
                self._ready.set(.single(true))
                self.onReady()
            }
        }
        
        private func onReady() {
            self.setupGradientAnimation()
            self.setupShineAnimation()
            
            self.playAppearanceAnimation(explode: true)
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            self.timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                if let strongSelf = self {
                    let currentTimestamp = CACurrentMediaTime()
                    if currentTimestamp > strongSelf.previousInteractionTimestamp + 5.0 {
                        strongSelf.playAppearanceAnimation()
                    }
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
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
            animation.beginTime = 0.6
            animation.duration = 0.9
            
            let group = CAAnimationGroup()
            group.animations = [animation]
            group.beginTime = 1.0
            group.duration = 3.0
            group.repeatCount = .infinity
            
            node.geometry?.materials.first?.emission.addAnimation(group, forKey: "shimmer")
        }
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            
            if explode, let node = scene.rootNode.childNode(withName: "swirl", recursively: false), let particles = scene.rootNode.childNode(withName: "particles", recursively: false) {
                let particleSystem = particles.particleSystems?.first
                particleSystem?.particleColorVariation = SCNVector4(0.15, 0.2, 0.35, 0.3)
                particleSystem?.particleVelocity = 2.2
                particleSystem?.birthRate = 4.5
                particleSystem?.particleLifeSpan = 2.0
                
                node.physicsField?.isActive = true
                Queue.mainQueue().after(1.0) {
                    node.physicsField?.isActive = false
                    particles.particleSystems?.first?.birthRate = 1.2
                    particleSystem?.particleVelocity = 1.0
                    particleSystem?.particleLifeSpan = 4.0
                }
            }
        
            let from = node.presentation.eulerAngles
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
            
            node.addAnimation(springAnimation, forKey: "rotate")
        }
        
        func update(component: PremiumStarComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            
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
