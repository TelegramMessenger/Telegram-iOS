import Foundation
import UIKit
import SceneKit
import Display
import AppBundle
import SwiftSignalKit

final class SwirlStarsView: UIView, PhoneDemoDecorationView {
    private let sceneView: SCNView
    
    private var particles: SCNNode?
    
    override init(frame: CGRect) {
        self.sceneView = SCNView(frame: CGRect(origin: .zero, size: frame.size))
        self.sceneView.backgroundColor = .clear
        if let url = getAppBundle().url(forResource: "swirl", withExtension: "scn") {
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
        self.setupAnimations()
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
        transition.updateAlpha(layer: self.layer, alpha: visible ? 0.6 : 0.0, completion: { [weak self] finished in
            if let strongSelf = self, finished && !visible && strongSelf.particles?.parent != nil {
                strongSelf.particles?.removeFromParentNode()
                
                if let node = strongSelf.sceneView.scene?.rootNode.childNode(withName: "star", recursively: false) {
                    node.removeAllAnimations()
                }
            }
        })
    }
    
    func setupAnimations() {
        guard let node = self.sceneView.scene?.rootNode.childNode(withName: "star", recursively: false), node.animationKeys.isEmpty else {
            return
        }
        
        let initial = node.eulerAngles
        let target = SCNVector3(x: node.eulerAngles.x + .pi * 2.0, y: node.eulerAngles.y, z: node.eulerAngles.z)
        
        let animation = CABasicAnimation(keyPath: "eulerAngles")
        animation.fromValue = NSValue(scnVector3: initial)
        animation.toValue = NSValue(scnVector3: target)
        animation.duration = 1.5
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.repeatCount = .infinity
        node.addAnimation(animation, forKey: "rotation")
    }
    
    func resetAnimation() {
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.sceneView.frame = CGRect(origin: .zero, size: frame.size)
    }
}
