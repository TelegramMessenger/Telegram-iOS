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

private let textMaskImage: UIImage = {
    return generateImage(CGSize(width: 60.0, height: 60.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        var locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 1.0).cgColor, UIColor(rgb: 0xffffff, alpha: 1.0).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width / 2.0, options: .drawsAfterEndLocation)
    })!
}()

private let emitterMaskImage: UIImage = {
    return generateImage(CGSize(width: 120.0, height: 120.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
                
        var locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff, alpha: 1.0).cgColor, UIColor(rgb: 0xffffff, alpha: 1.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width / 10.0, options: .drawsAfterEndLocation)
    })!
}()

public class InvisibleInkDustNode: ASDisplayNode {
    private var currentParams: (size: CGSize, color: UIColor, rects: [CGRect], wordRects: [CGRect])?
    
    private weak var textNode: TextNode?
    private let textMaskNode: ASDisplayNode
    private let textSpotNode: ASImageNode
    
    private var emitterNode: ASDisplayNode
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    private let emitterMaskNode: ASDisplayNode
    private let emitterSpotNode: ASImageNode
    private let emitterMaskFillNode: ASDisplayNode
    
    public var isRevealedUpdated: (Bool) -> Void = { _ in }
    
    public var isRevealed = false
    
    public init(textNode: TextNode?) {
        self.textNode = textNode
        
        self.emitterNode = ASDisplayNode()
        self.emitterNode.clipsToBounds = true
        
        self.textMaskNode = ASDisplayNode()
        self.textSpotNode = ASImageNode()
        let img = textMaskImage
        self.textSpotNode.image = img
                
        self.emitterMaskNode = ASDisplayNode()
        self.emitterSpotNode = ASImageNode()
        let simg = emitterMaskImage
        self.emitterSpotNode.image = simg
        
        self.emitterMaskFillNode = ASDisplayNode()
        self.emitterMaskFillNode.backgroundColor = .white
        
        super.init()
        
        self.addSubnode(self.emitterNode)
        
        self.textMaskNode.addSubnode(self.textSpotNode)
        self.emitterMaskNode.addSubnode(self.emitterSpotNode)
        self.emitterMaskNode.addSubnode(self.emitterMaskFillNode)
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
        
        self.emitterNode.layer.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap(_:))))
    }
    
    public func update(revealed: Bool) {
        guard self.isRevealed != revealed, let textNode = self.textNode else {
            return
        }
        
        self.isRevealed = revealed
        
        if revealed {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
            transition.updateAlpha(node: self, alpha: 0.0)
            transition.updateAlpha(node: textNode, alpha: 1.0)
        } else {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(node: self, alpha: 1.0)
            transition.updateAlpha(node: textNode, alpha: 0.0)
        }
    }
    
    @objc private func tap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let (size, _, _, _) = self.currentParams, let textNode = self.textNode, !self.isRevealed else {
            return
        }
        
        self.isRevealed = true
        
        let position = gestureRecognizer.location(in: self.view)
        self.emitterLayer?.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        self.emitterLayer?.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
           
        Queue.mainQueue().after(0.1 * UIView.animationDurationFactor()) {
            textNode.view.mask = self.textMaskNode.view
            textNode.alpha = 1.0
                    
            let radius = max(size.width, size.height)
            self.textSpotNode.frame = CGRect(x: position.x - radius / 2.0, y: position.y - radius / 2.0, width: radius, height: radius)
                    
            self.textSpotNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            self.textSpotNode.layer.animateScale(from: 0.1, to: 3.5, duration: 0.71, removeOnCompletion: false, completion: { _ in
                textNode.view.mask = nil
            })
            
            self.emitterNode.view.mask = self.emitterMaskNode.view
            let emitterSide = radius * 5.0
            self.emitterSpotNode.frame =  CGRect(x: position.x - emitterSide / 2.0, y: position.y - emitterSide / 2.0, width: emitterSide, height: emitterSide)
            self.emitterSpotNode.layer.animateScale(from: 0.1, to: 3.0, duration: 0.71, removeOnCompletion: false, completion: { [weak self] _ in
                self?.alpha = 0.0
                self?.emitterNode.view.mask = nil
            })
            self.emitterMaskFillNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        }
        
        Queue.mainQueue().after(0.8 * UIView.animationDurationFactor()) {
            self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            self.textSpotNode.layer.removeAllAnimations()
            
            self.emitterSpotNode.layer.removeAllAnimations()
            self.emitterMaskFillNode.layer.removeAllAnimations()
        }
        
        
        let textLength = CGFloat((textNode.cachedLayout?.attributedString?.string ?? "").count)
        let timeToRead = min(45.0, ceil(max(4.0, textLength * 0.04)))
        Queue.mainQueue().after(timeToRead * UIView.animationDurationFactor()) {
            self.isRevealed = false
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
            transition.updateAlpha(node: self, alpha: 1.0)
            transition.updateAlpha(node: textNode, alpha: 0.0)
        }
    }
    
    private func updateEmitter() {
        guard let (size, color, _, wordRects) = self.currentParams else {
            return
        }
                
        self.emitter?.color = color.cgColor
        self.emitterLayer?.setValue(wordRects, forKey: "emitterRects")
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        
        let radius = max(size.width, size.height)
        self.emitterLayer?.setValue(max(size.width, size.height), forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        self.emitterLayer?.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        
        var square: Float = 0.0
        for rect in wordRects {
            square += Float(rect.width * rect.height)
        }
        
        self.emitter?.birthRate = square * 0.4
    }
    
    public func update(size: CGSize, color: UIColor, rects: [CGRect], wordRects: [CGRect]) {
        self.currentParams = (size, color, rects, wordRects)
                
        self.emitterNode.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterMaskNode.frame = self.emitterNode.bounds
        self.emitterMaskFillNode.frame = self.emitterNode.bounds
        self.textMaskNode.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: size)
        
        if self.isNodeLoaded {
            self.updateEmitter()
        }
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let (_, _, rects, _) = self.currentParams {
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
