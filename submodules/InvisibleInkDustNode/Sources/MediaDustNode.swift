import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle
import LegacyComponents

public class MediaDustNode: ASDisplayNode {
    private var currentParams: (size: CGSize, color: UIColor)?
    private var animColor: CGColor?
        
    private var emitterNode: ASDisplayNode
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
        
    public override init() {
        self.emitterNode = ASDisplayNode()
        self.emitterNode.isUserInteractionEnabled = false
        self.emitterNode.clipsToBounds = true
                
        super.init()
        
        self.addSubnode(self.emitterNode)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let emitter = CAEmitterCell()
        emitter.color = UIColor(rgb: 0xffffff, alpha: 0.0).cgColor
        emitter.contents = UIImage(bundleImageName: "Components/TextSpeckle")?.cgImage
        emitter.contentsScale = 1.8
        emitter.emissionRange = .pi * 2.0
        emitter.lifetime = 8.0
        emitter.scale = 0.5
        emitter.velocityRange = 0.0
        emitter.name = "dustCell"
        emitter.alphaRange = 1.0
        emitter.setValue("point", forKey: "particleType")
        emitter.setValue(1.0, forKey: "mass")
        emitter.setValue(0.01, forKey: "massRange")
        self.emitter = emitter
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1], forKey: "values")
        alphaBehavior.setValue(true, forKey: "additive")
        
        let scaleBehavior = createEmitterBehavior(type: "valueOverLife")
        scaleBehavior.setValue("scale", forKey: "keyPath")
        scaleBehavior.setValue([0.0, 0.5], forKey: "values")
        scaleBehavior.setValue([0.0, 0.05], forKey: "locations")
                
        let behaviors = [alphaBehavior, scaleBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.seed = arc4random()
        emitterLayer.emitterShape = .rectangle
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
                
        self.emitterLayer = emitterLayer
        
        self.emitterNode.layer.addSublayer(emitterLayer)
        
        self.updateEmitter()
    }
        
    private func updateEmitter() {
        guard let (size, _) = self.currentParams else {
            return
        }
        
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.emitterSize = size
        self.emitterLayer?.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        let square = Float(size.width * size.height)
        Queue.mainQueue().async {
            self.emitter?.birthRate = min(100000.0, square * 0.016)
        }
    }
    
    public func update(size: CGSize, color: UIColor) {
        self.currentParams = (size, color)
                
        self.emitterNode.frame = CGRect(origin: CGPoint(), size: size)
        
        if self.isNodeLoaded {
            self.updateEmitter()
        }
    }
}
