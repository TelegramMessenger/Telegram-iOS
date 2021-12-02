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
    
    private weak var textNode: TextNode?
    
    private let maskNode: ASDisplayNode
    private let spotNode: ASImageNode
    
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
        
    public var isRevealedUpdated: (Bool) -> Void = { _ in }
    
    public init(textNode: TextNode) {
        self.textNode = textNode
        
        self.maskNode = ASDisplayNode()
        self.spotNode = ASImageNode()
        self.spotNode.image = UIImage(bundleImageName: "Components/TextSpot")
                
        super.init()
        
        self.maskNode.addSubnode(self.spotNode)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let emitter = CAEmitterCell()
        emitter.contents = UIImage(bundleImageName: "Components/TextSpeckle")?.cgImage
        emitter.setValue(1.8, forKey: "contentsScale")
        emitter.emissionRange = .pi * 2.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        emitter.lifetime = 1.0
        emitter.scale = 0.5
        emitter.velocityRange = 20.0
        emitter.name = "dustCell"
        emitter.setValue("point", forKey: "particleType")
        emitter.color = UIColor.white.withAlphaComponent(0.0).cgColor
        emitter.alphaRange = 1.0
        self.emitter = emitter

        let fingerAttractor = createEmitterBehavior(type: "simpleAttractor")
        fingerAttractor.setValue("fingerAttractor", forKey: "name")
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("alphaBehavior", forKey: "name")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([0.0, 0.0, 1.0, 0.0, -1.0], forKey: "values")
        alphaBehavior.setValue(true, forKey: "additive")
        
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
        
        emitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        
        self.emitterLayer = emitterLayer
        
        self.layer.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap(_:))))
    }
    
    private var revealed = false
    @objc private func tap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let (size, _, _) = self.currentParams, !self.revealed else {
            return
        }
        
        self.revealed = true
        
        let position = gestureRecognizer.location(in: self.view)
        self.emitterLayer?.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        self.emitterLayer?.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
        
        self.textNode?.view.mask = self.maskNode.view
        self.textNode?.alpha = 1.0
        
        let radius = max(size.width, size.height)
        self.spotNode.frame = CGRect(x: position.x - radius / 2.0, y: position.y - radius / 2.0, width: radius, height: radius)
        
        self.spotNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.spotNode.layer.animateScale(from: 0.0, to: 3.5, duration: 0.61, removeOnCompletion: false, completion: { [weak self] _ in
            self?.textNode?.view.mask = nil
        })
                
        Queue.mainQueue().after(0.2) {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(node: self, alpha: 0.0)
                        
            self.isRevealedUpdated(true)
        }
        
        Queue.mainQueue().after(0.7) {
            self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            self.spotNode.layer.removeAllAnimations()
        }
        
        Queue.mainQueue().after(4.0) {
            self.revealed = false
            self.isRevealedUpdated(false)
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(node: self, alpha: 1.0)
            if let textNode = self.textNode {
                transition.updateAlpha(node: textNode, alpha: 0.0)
            }
        }
    }
    
    private func updateEmitter() {
        guard let (size, color, rects) = self.currentParams else {
            return
        }
                
        self.emitter?.color = color.cgColor
        self.emitterLayer?.setValue(rects, forKey: "emitterRects")
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        
        let radius = max(size.width, size.height)
        self.emitterLayer?.setValue(max(size.width, size.height), forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        self.emitterLayer?.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        
        var square: Float = 0.0
        for rect in rects {
            square += Float(rect.width * rect.height)
        }
        
        self.emitter?.birthRate = square * 0.3
    }
    
    public func update(size: CGSize, color: UIColor, rects: [CGRect]) {
        self.currentParams = (size, color, rects)
                
        self.maskNode.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: size)
        
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
