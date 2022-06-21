import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle
import LegacyComponents

private func createEmitterBehavior(type: String) -> NSObject {
    let selector = ["behaviorWith", "Type:"].joined(separator: "")
    let behaviorClass = NSClassFromString(["CA", "Emitter", "Behavior"].joined(separator: "")) as! NSObject.Type
    let behaviorWithType = behaviorClass.method(for: NSSelectorFromString(selector))!
    let castedBehaviorWithType = unsafeBitCast(behaviorWithType, to:(@convention(c)(Any?, Selector, Any?) -> NSObject).self)
    return castedBehaviorWithType(behaviorClass, NSSelectorFromString(selector), type)
}

private func generateMaskImage(size originalSize: CGSize, position: CGPoint, inverse: Bool) -> UIImage? {
    var size = originalSize
    var position = position
    var scale: CGFloat = 1.0
    if max(size.width, size.height) > 640.0 {
        size = size.aspectFitted(CGSize(width: 640.0, height: 640.0))
        scale = size.width / originalSize.width
        position = CGPoint(x: position.x * scale, y: position.y * scale)
    }
    return generateImage(size, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
                
        
        let startAlpha: CGFloat = inverse ? 0.0 : 1.0
        let endAlpha: CGFloat = inverse ? 1.0 : 0.0
        
        var locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: startAlpha).cgColor, UIColor(rgb: 0xffffff, alpha: startAlpha).cgColor, UIColor(rgb: 0xffffff, alpha: endAlpha).cgColor, UIColor(rgb: 0xffffff, alpha: endAlpha).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        let center = position
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: min(10.0, min(size.width, size.height) * 0.4) * scale, options: .drawsAfterEndLocation)
    })
}

public class InvisibleInkDustNode: ASDisplayNode {
    private var currentParams: (size: CGSize, color: UIColor, textColor: UIColor, rects: [CGRect], wordRects: [CGRect])?
    private var animColor: CGColor?
    
    private weak var textNode: TextNode?
    private let textMaskNode: ASDisplayNode
    private let textSpotNode: ASImageNode
    
    private var emitterNode: ASDisplayNode
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    private let emitterMaskNode: ASDisplayNode
    private let emitterSpotNode: ASImageNode
    private let emitterMaskFillNode: ASDisplayNode
        
    public var isRevealed = false
    
    private var exploding = false
    
    public init(textNode: TextNode?) {
        self.textNode = textNode
        
        self.emitterNode = ASDisplayNode()
        self.emitterNode.isUserInteractionEnabled = false
        self.emitterNode.clipsToBounds = true
        
        self.textMaskNode = ASDisplayNode()
        self.textMaskNode.isUserInteractionEnabled = false
        self.textSpotNode = ASImageNode()
        self.textSpotNode.contentMode = .scaleToFill
        self.textSpotNode.isUserInteractionEnabled = false
        
        self.emitterMaskNode = ASDisplayNode()
        self.emitterSpotNode = ASImageNode()
        self.emitterSpotNode.contentMode = .scaleToFill
        self.emitterSpotNode.isUserInteractionEnabled = false
        
        self.emitterMaskFillNode = ASDisplayNode()
        self.emitterMaskFillNode.backgroundColor = .white
        self.emitterMaskFillNode.isUserInteractionEnabled = false
        
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
        emitter.contentsScale = 1.8
        emitter.emissionRange = .pi * 2.0
        emitter.lifetime = 1.0
        emitter.scale = 0.5
        emitter.velocityRange = 20.0
        emitter.name = "dustCell"
        emitter.alphaRange = 1.0
        emitter.setValue("point", forKey: "particleType")
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        self.emitter = emitter

        let fingerAttractor = createEmitterBehavior(type: "simpleAttractor")
        fingerAttractor.setValue("fingerAttractor", forKey: "name")
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([0.0, 0.0, 1.0, 0.0, -1.0], forKey: "values")
        alphaBehavior.setValue(true, forKey: "additive")
        
        let behaviors = [fingerAttractor, alphaBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.emitterPosition = CGPoint(x: 0, y: 0)
        emitterLayer.seed = arc4random()
        emitterLayer.emitterSize = CGSize(width: 1, height: 1)
        emitterLayer.emitterShape = CAEmitterLayerEmitterShape(rawValue: "rectangles")
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
        
        emitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        
        self.emitterLayer = emitterLayer
        
        self.emitterNode.layer.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap(_:))))
    }
    
    public func update(revealed: Bool, animated: Bool = true) {
        guard self.isRevealed != revealed, let textNode = self.textNode else {
            return
        }
        
        self.isRevealed = revealed
        
        if revealed {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .linear) : .immediate
            transition.updateAlpha(node: self, alpha: 0.0)
            transition.updateAlpha(node: textNode, alpha: 1.0)
        } else {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .linear) : .immediate
            transition.updateAlpha(node: self, alpha: 1.0)
            transition.updateAlpha(node: textNode, alpha: 0.0)
            
            if self.exploding {
                self.exploding = false
                self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            }
        }
    }
    
    @objc private func tap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let (_, _, textColor, _, _) = self.currentParams, let textNode = self.textNode, !self.isRevealed else {
            return
        }
        
        self.isRevealed = true
        self.exploding = true
        
        let position = gestureRecognizer.location(in: self.view)
        self.emitterLayer?.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        self.emitterLayer?.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
        
        let maskSize = self.emitterNode.frame.size
        Queue.concurrentDefaultQueue().async {
            let textMaskImage = generateMaskImage(size: maskSize, position: position, inverse: false)
            let emitterMaskImage = generateMaskImage(size: maskSize, position: position, inverse: true)
            
            Queue.mainQueue().async {
                self.textSpotNode.image = textMaskImage
                self.emitterSpotNode.image = emitterMaskImage
            }
        }
           
        Queue.mainQueue().after(0.1 * UIView.animationDurationFactor()) {
            textNode.alpha = 1.0
            
            textNode.view.mask = self.textMaskNode.view
            self.textSpotNode.frame = CGRect(x: 0.0, y: 0.0, width: self.emitterMaskNode.frame.width * 3.0, height: self.emitterMaskNode.frame.height * 3.0)
                
            let xFactor = (position.x / self.emitterNode.frame.width - 0.5) * 2.0
            let yFactor = (position.y / self.emitterNode.frame.height - 0.5) * 2.0
            let maxFactor = max(abs(xFactor), abs(yFactor))

            var scaleAddition = maxFactor * 4.0
            var durationAddition = -maxFactor * 0.2
            if self.emitterNode.frame.height > 0.0, self.emitterNode.frame.width / self.emitterNode.frame.height < 0.7 {
                scaleAddition *= 5.0
                durationAddition *= 2.0
            }
            
            self.textSpotNode.layer.anchorPoint = CGPoint(x: position.x / self.emitterMaskNode.frame.width, y: position.y / self.emitterMaskNode.frame.height)
            self.textSpotNode.position = position
            self.textSpotNode.layer.animateScale(from: 0.3333, to: 10.5 + scaleAddition, duration: 0.55 + durationAddition, removeOnCompletion: false, completion: { _ in
                textNode.view.mask = nil
            })
            self.textSpotNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            
            self.emitterNode.view.mask = self.emitterMaskNode.view
            self.emitterSpotNode.frame = CGRect(x: 0.0, y: 0.0, width: self.emitterMaskNode.frame.width * 3.0, height: self.emitterMaskNode.frame.height * 3.0)
            
            self.emitterSpotNode.layer.anchorPoint = CGPoint(x: position.x / self.emitterMaskNode.frame.width, y: position.y / self.emitterMaskNode.frame.height)
            self.emitterSpotNode.position = position
            self.emitterSpotNode.layer.animateScale(from: 0.3333, to: 10.5 + scaleAddition, duration: 0.55 + durationAddition, removeOnCompletion: false, completion: { [weak self] _ in
                self?.alpha = 0.0
                self?.emitterNode.view.mask = nil
                
                self?.emitter?.color = textColor.cgColor
            })
            self.emitterMaskFillNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        }
        
        Queue.mainQueue().after(0.8 * UIView.animationDurationFactor()) {
            self.exploding = false
            self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            self.textSpotNode.layer.removeAllAnimations()
            
            self.emitterSpotNode.layer.removeAllAnimations()
            self.emitterMaskFillNode.layer.removeAllAnimations()
        }
        
        var spoilersLength: Int = 0
        if let spoilers = textNode.cachedLayout?.spoilers {
            for spoiler in spoilers {
                spoilersLength += spoiler.0.length
            }
        }
        
        let timeToRead = min(45.0, ceil(max(4.0, Double(spoilersLength) * 0.04)))
        Queue.mainQueue().after(timeToRead * UIView.animationDurationFactor()) {
            if let (_, color, _, _, _) = self.currentParams {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let animation = POPBasicAnimation()
                animation.property = (POPAnimatableProperty.property(withName: "color", initializer: { property in
                    property?.readBlock = { node, values in
                        if let color = (node as! InvisibleInkDustNode).emitter?.color {
                            if let a = color.components {
                                values?[0] = a[0]
                                values?[1] = a[1]
                                values?[2] = a[2]
                                values?[3] = a[3]
                            }
                        }
                    }
                    property?.writeBlock = { node, values in
                        if let values = values, let color = CGColor(colorSpace: colorSpace, components: values) {
                            (node as! InvisibleInkDustNode).animColor = color
                            (node as! InvisibleInkDustNode).updateEmitter()
                        }
                    }
                    property?.threshold = 0.4
                }) as! POPAnimatableProperty)
                animation.fromValue = self.emitter?.color
                animation.toValue = color
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                animation.duration = 0.1
                animation.completionBlock = { [weak self] _, _ in
                    if let strongSelf = self {
                        strongSelf.animColor = nil
                        strongSelf.updateEmitter()
                    }
                }
                self.pop_add(animation, forKey: "color")
            }
            
            Queue.mainQueue().after(0.15) {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .linear)
                transition.updateAlpha(node: self, alpha: 1.0)
                transition.updateAlpha(node: textNode, alpha: 0.0, completion: { [weak self] _ in
                    self?.isRevealed = false
                })
            }
        }
    }
    
    private func updateEmitter() {
        guard let (size, color, _, _, wordRects) = self.currentParams else {
            return
        }
        
        self.emitter?.color = self.animColor ?? color.cgColor
        self.emitterLayer?.setValue(wordRects, forKey: "emitterRects")
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        
        let radius = max(size.width, size.height)
        self.emitterLayer?.setValue(max(size.width, size.height), forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        self.emitterLayer?.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        
        var square: Float = 0.0
        for rect in wordRects {
            square += Float(rect.width * rect.height)
        }
        
        Queue.mainQueue().async {
            self.emitter?.birthRate = min(100000, square * 0.35)
        }
    }
    
    public func update(size: CGSize, color: UIColor, textColor: UIColor, rects: [CGRect], wordRects: [CGRect]) {
        self.currentParams = (size, color, textColor, rects, wordRects)
                
        self.emitterNode.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterMaskNode.frame = self.emitterNode.bounds
        self.emitterMaskFillNode.frame = self.emitterNode.bounds
        self.textMaskNode.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: size)
        
        if self.isNodeLoaded {
            self.updateEmitter()
        }
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let (_, _, _, rects, _) = self.currentParams, !self.isRevealed {
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
