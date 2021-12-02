import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle

private func createEmitterBehavior(type: String) -> NSObject {
    let selector = ["behaviorWith", "Type:"].joined(separator: "")
    let behaviorClass = NSClassFromString(["CA", "Emitter", "Behavior"].joined(separator: "")) as! NSObject.Type
    let behaviorWithType = behaviorClass.method(for: NSSelectorFromString(selector))!
    let castedBehaviorWithType = unsafeBitCast(behaviorWithType, to:(@convention(c)(Any?, Selector, Any?) -> NSObject).self)
    return castedBehaviorWithType(behaviorClass, NSSelectorFromString(selector), type)
}

public class InvisibleInkDustNode: ASDisplayNode {
    private var currentParams: (size: CGSize, color: UIColor, rects: [CGRect])?
    
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    
    public override init() {
        super.init()
    }
    
    public var isRevealedUpdated: (Bool) -> Void = { _ in }
    
    public override func didLoad() {
        super.didLoad()
        
        let emitter = CAEmitterCell()
        emitter.contents = UIImage(bundleImageName: "Components/TextSpeckle")?.cgImage
        emitter.birthRate = 1600.0
        emitter.setValue(1.8, forKey: "contentsScale")
        emitter.emissionRange = .pi * 2.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        emitter.lifetime = 1.0
        emitter.scale = 0.5
        emitter.velocityRange = 20.0
        emitter.name = "dustCell"
        emitter.setValue("point", forKey: "particleType")
        emitter.color = UIColor.white.cgColor //?alpha
        emitter.alphaRange = 1.0
        self.emitter = emitter

        let fingerAttractor = createEmitterBehavior(type: "simpleAttractor")
        fingerAttractor.setValue("fingerAttractor", forKey: "name")
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("alphaBehavior", forKey: "name")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([1.0, 0.0], forKey: "values")
//        alphaBehavior.setValue(true, forKey: "additive")
        
        let behaviors = [fingerAttractor, alphaBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
        emitterLayer.emitterPosition = CGPoint(x: 0, y: 0)
        emitterLayer.seed = arc4random()
        emitterLayer.setValue("rectangles", forKey: "emitterShape")
        emitterLayer.emitterSize = CGSize(width: 1, height: 1)
        emitterLayer.setValue(0.0322, forKey: "updateInterval")
        
//        layer.setValue(-100, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        
        self.emitterLayer = emitterLayer
        
        self.layer.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        self.isRevealedUpdated(true)
        
        Queue.mainQueue().after(4.0) {
            self.isRevealedUpdated(false)
        }
    }
    
    private func updateEmitter() {
        guard let (size, color, rects) = self.currentParams else {
            return
        }
                
        self.emitter?.color = color.cgColor
        self.emitterLayer?.setValue(rects, forKey: "emitterRects")
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    public func update(size: CGSize, color: UIColor, rects: [CGRect]) {
        self.currentParams = (size, color, rects)
        
        if self.isNodeLoaded {
            self.updateEmitter()
        }
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let (_, _, rects) = self.currentParams {
            for rect in rects {
                if rect.contains(point) {
                    return true
                }
            }
            return false
        } else {
            return false
        }
    }
}
