import Foundation
import UIKit
import SceneKit
import Display
import AppBundle
import LegacyComponents

final class FasterStarsView: UIView, PhoneDemoDecorationView {
    private let sceneView: SCNView
    
    private var particles: SCNNode?
    
    override init(frame: CGRect) {
        self.sceneView = SCNView(frame: CGRect(origin: .zero, size: frame.size))
        self.sceneView.backgroundColor = .clear
        if let url = getAppBundle().url(forResource: "lightspeed", withExtension: "scn") {
            self.sceneView.scene = try? SCNScene(url: url, options: nil)
        }
        self.sceneView.isUserInteractionEnabled = false
        self.sceneView.preferredFramesPerSecond = 60
        
        super.init(frame: frame)
        
        self.alpha = 0.0
        
        self.addSubview(self.sceneView)
        
        self.particles = self.sceneView.scene?.rootNode.childNode(withName: "particles", recursively: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.particles = nil
    }
    
    func setVisible(_ visible: Bool) {
        if visible, let particles = self.particles, particles.parent == nil {
            self.sceneView.scene?.rootNode.addChildNode(particles)
        }

        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
        transition.updateAlpha(layer: self.layer, alpha: visible ? 0.4 : 0.0, completion: { [weak self] finished in
            if let strongSelf = self, finished && !visible && strongSelf.particles?.parent != nil {
                strongSelf.particles?.removeFromParentNode()
            }
        })
    }
    
    private var playing = false
    func startAnimation() {
        guard !self.playing, let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "particles", recursively: false), let particles = node.particleSystems?.first else {
            return
        }
        self.playing = true
        
        let speedAnimation = POPBasicAnimation()
        speedAnimation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
            property?.readBlock = { particleSystem, values in
                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
            }
            property?.writeBlock = { particleSystem, values in
                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        speedAnimation.fromValue = 1.0 as NSNumber
        speedAnimation.toValue = 3.0 as NSNumber
        speedAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        speedAnimation.duration = 0.8
        particles.pop_add(speedAnimation, forKey: "speedFactor")
        
        let stretchAnimation = POPBasicAnimation()
        stretchAnimation.property = (POPAnimatableProperty.property(withName: "stretchFactor", initializer: { property in
            property?.readBlock = { particleSystem, values in
                values?.pointee = (particleSystem as! SCNParticleSystem).stretchFactor
            }
            property?.writeBlock = { particleSystem, values in
                (particleSystem as! SCNParticleSystem).stretchFactor = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        stretchAnimation.fromValue = 0.05 as NSNumber
        stretchAnimation.toValue = 0.3 as NSNumber
        stretchAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        stretchAnimation.duration = 0.8
        particles.pop_add(stretchAnimation, forKey: "stretchFactor")
    }
    
    func resetAnimation() {
        guard self.playing, let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "particles", recursively: false), let particles = node.particleSystems?.first else {
            return
        }
        self.playing = false
                
        let speedAnimation = POPBasicAnimation()
        speedAnimation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
            property?.readBlock = { particleSystem, values in
                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
            }
            property?.writeBlock = { particleSystem, values in
                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        speedAnimation.fromValue = 3.0 as NSNumber
        speedAnimation.toValue = 1.0 as NSNumber
        speedAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        speedAnimation.duration = 0.35
        particles.pop_add(speedAnimation, forKey: "speedFactor")
        
        let stretchAnimation = POPBasicAnimation()
        stretchAnimation.property = (POPAnimatableProperty.property(withName: "stretchFactor", initializer: { property in
            property?.readBlock = { particleSystem, values in
                values?.pointee = (particleSystem as! SCNParticleSystem).stretchFactor
            }
            property?.writeBlock = { particleSystem, values in
                (particleSystem as! SCNParticleSystem).stretchFactor = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        stretchAnimation.fromValue = 0.3 as NSNumber
        stretchAnimation.toValue = 0.05 as NSNumber
        stretchAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        stretchAnimation.duration = 0.35
        particles.pop_add(stretchAnimation, forKey: "stretchFactor")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.sceneView.frame = CGRect(origin: .zero, size: frame.size)
    }
}
