import Foundation
import UIKit
import SceneKit
import Display
import AppBundle

final class BadgeStarsView: UIView, PhoneDemoDecorationView {
    private let sceneView: SCNView
    
    private var leftParticles: SCNNode?
    private var rightParticles: SCNNode?
    
    override init(frame: CGRect) {
        self.sceneView = SCNView(frame: CGRect(origin: .zero, size: frame.size))
        self.sceneView.backgroundColor = .clear
        if let url = getAppBundle().url(forResource: "badge", withExtension: "scn") {
            self.sceneView.scene = try? SCNScene(url: url, options: nil)
        }
        self.sceneView.isUserInteractionEnabled = false
        self.sceneView.preferredFramesPerSecond = 60
        
        super.init(frame: frame)
        
        self.alpha = 0.0
        
        self.addSubview(self.sceneView)
        
        self.leftParticles = self.sceneView.scene?.rootNode.childNode(withName: "leftParticles", recursively: false)
        self.rightParticles = self.sceneView.scene?.rootNode.childNode(withName: "rightParticles", recursively: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setVisible(_ visible: Bool) {
        if visible, let leftParticles = self.leftParticles, let rightParticles = self.rightParticles, leftParticles.parent == nil {
            self.sceneView.scene?.rootNode.addChildNode(leftParticles)
            self.sceneView.scene?.rootNode.addChildNode(rightParticles)
        }
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
        transition.updateAlpha(layer: self.layer, alpha: visible ? 0.5 : 0.0, completion: { [weak self] finished in
            if let strongSelf = self, finished && !visible && strongSelf.leftParticles?.parent != nil {
                strongSelf.leftParticles?.removeFromParentNode()
                strongSelf.rightParticles?.removeFromParentNode()
            }
        })
    }
    
    func resetAnimation() {
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.sceneView.frame = CGRect(origin: .zero, size: frame.size)
    }
}

final class EmojiStarsView: UIView, PhoneDemoDecorationView {
    private let sceneView: SCNView
    
    private var leftParticles: SCNNode?
    private var rightParticles: SCNNode?
    
    override init(frame: CGRect) {
        self.sceneView = SCNView(frame: CGRect(origin: .zero, size: frame.size))
        self.sceneView.backgroundColor = .clear
        if let url = getAppBundle().url(forResource: "emoji", withExtension: "scn") {
            self.sceneView.scene = try? SCNScene(url: url, options: nil)
        }
        self.sceneView.isUserInteractionEnabled = false
        self.sceneView.preferredFramesPerSecond = 60
        
        super.init(frame: frame)
        
        self.alpha = 0.0
        
        self.addSubview(self.sceneView)
        
        self.leftParticles = self.sceneView.scene?.rootNode.childNode(withName: "leftParticles", recursively: false)
        self.rightParticles = self.sceneView.scene?.rootNode.childNode(withName: "rightParticles", recursively: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setVisible(_ visible: Bool) {
        if visible, let leftParticles = self.leftParticles, let rightParticles = self.rightParticles, leftParticles.parent == nil {
            self.sceneView.scene?.rootNode.addChildNode(leftParticles)
            self.sceneView.scene?.rootNode.addChildNode(rightParticles)
        }
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
        transition.updateAlpha(layer: self.layer, alpha: visible ? 0.5 : 0.0, completion: { [weak self] finished in
            if let strongSelf = self, finished && !visible && strongSelf.leftParticles?.parent != nil {
                strongSelf.leftParticles?.removeFromParentNode()
                strongSelf.rightParticles?.removeFromParentNode()
            }
        })
    }
    
    func resetAnimation() {
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.sceneView.frame = CGRect(origin: .zero, size: frame.size)
    }
}
