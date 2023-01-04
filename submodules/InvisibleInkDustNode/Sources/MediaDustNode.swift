import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle
import LegacyComponents

public class MediaDustLayer: CALayer {
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    
    private var size: CGSize?
    
    override public init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupEmitterLayerIfNeeded() {
        guard self.emitterLayer == nil else {
            return
        }
        
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
        self.addSublayer(emitterLayer)
                
        self.emitterLayer = emitterLayer
    }
    
    private func updateEmitter() {
        guard let size = self.size else {
            return
        }
        
        self.setupEmitterLayerIfNeeded()
        
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.emitterSize = size
        self.emitterLayer?.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        let square = Float(size.width * size.height)
        Queue.mainQueue().async {
            self.emitter?.birthRate = min(100000.0, square * 0.02)
        }
    }
    
    public func updateLayout(size: CGSize) {
        self.size = size
        
        self.updateEmitter()
    }
}

public class MediaDustNode: ASDisplayNode {
    private var currentParams: (size: CGSize, color: UIColor)?
    private var animColor: CGColor?
        
    private var emitterNode: ASDisplayNode
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    
    private let emitterMaskNode: ASDisplayNode
    private let emitterSpotNode: ASImageNode
    private let emitterMaskFillNode: ASDisplayNode
    
    public var isRevealed = false
    private var isExploding = false
    
    public var revealed: () -> Void = {}
    public var tapped: () -> Void = {}
    
    public override init() {
        self.emitterNode = ASDisplayNode()
        self.emitterNode.isUserInteractionEnabled = false
        self.emitterNode.clipsToBounds = true
        
        self.emitterMaskNode = ASDisplayNode()
        self.emitterSpotNode = ASImageNode()
        self.emitterSpotNode.contentMode = .scaleToFill
        self.emitterSpotNode.isUserInteractionEnabled = false
        
        self.emitterMaskFillNode = ASDisplayNode()
        self.emitterMaskFillNode.backgroundColor = .white
        self.emitterMaskFillNode.isUserInteractionEnabled = false
                
        super.init()
        
        self.addSubnode(self.emitterNode)
        
        self.emitterMaskNode.addSubnode(self.emitterSpotNode)
        self.emitterMaskNode.addSubnode(self.emitterMaskFillNode)
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
        
        let randomAttractor0 = createEmitterBehavior(type: "simpleAttractor")
        randomAttractor0.setValue("randomAttractor0", forKey: "name")
        randomAttractor0.setValue(20, forKey: "falloff")
        randomAttractor0.setValue(35, forKey: "radius")
        randomAttractor0.setValue(5, forKey: "stiffness")
        randomAttractor0.setValue(NSValue(cgPoint: .zero), forKey: "position")
        
        let randomAttractor1 = createEmitterBehavior(type: "simpleAttractor")
        randomAttractor1.setValue("randomAttractor1", forKey: "name")
        randomAttractor1.setValue(20, forKey: "falloff")
        randomAttractor1.setValue(35, forKey: "radius")
        randomAttractor1.setValue(5, forKey: "stiffness")
        randomAttractor1.setValue(NSValue(cgPoint: .zero), forKey: "position")
        
        let fingerAttractor = createEmitterBehavior(type: "simpleAttractor")
        fingerAttractor.setValue("fingerAttractor", forKey: "name")
        
        let behaviors = [randomAttractor0, randomAttractor1, fingerAttractor, alphaBehavior, scaleBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.seed = arc4random()
        emitterLayer.emitterShape = .rectangle
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
        
        emitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        
        self.emitterLayer = emitterLayer
        
        self.emitterNode.layer.addSublayer(emitterLayer)
        
        self.updateEmitter()
        
        self.setupRandomAnimations()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap(_:))))
    }
    
    @objc private func tap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard !self.isRevealed else {
            return
        }
        
        self.tapped()
        
        self.isRevealed = true
        self.isExploding = true
        
        let position = gestureRecognizer.location(in: self.view)
        self.emitterLayer?.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        self.emitterLayer?.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
        
        let maskSize = self.emitterNode.frame.size
        Queue.concurrentDefaultQueue().async {
            let emitterMaskImage = generateMaskImage(size: maskSize, position: position, inverse: true)
            
            Queue.mainQueue().async {
                self.emitterSpotNode.image = emitterMaskImage
            }
        }
           
        Queue.mainQueue().after(0.1 * UIView.animationDurationFactor()) {
            let xFactor = (position.x / self.emitterNode.frame.width - 0.5) * 2.0
            let yFactor = (position.y / self.emitterNode.frame.height - 0.5) * 2.0
            let maxFactor = max(abs(xFactor), abs(yFactor))

            let scaleAddition = maxFactor * 4.0
            let durationAddition = -maxFactor * 0.2
            
            self.supernode?.view.mask = self.emitterMaskNode.view
            self.emitterSpotNode.frame = CGRect(x: 0.0, y: 0.0, width: self.emitterMaskNode.frame.width * 3.0, height: self.emitterMaskNode.frame.height * 3.0)
            
            self.emitterSpotNode.layer.anchorPoint = CGPoint(x: position.x / self.emitterMaskNode.frame.width, y: position.y / self.emitterMaskNode.frame.height)
            self.emitterSpotNode.position = position
            self.emitterSpotNode.layer.animateScale(from: 0.3333, to: 10.5 + scaleAddition, duration: 0.45 + durationAddition, removeOnCompletion: false, completion: { [weak self] _ in
                self?.revealed()
                self?.alpha = 0.0
                self?.supernode?.view.mask = nil
                
            })
            self.emitterMaskFillNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        Queue.mainQueue().after(0.8 * UIView.animationDurationFactor()) {
            self.isExploding = false
            self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            
            self.emitterSpotNode.layer.removeAllAnimations()
            self.emitterMaskFillNode.layer.removeAllAnimations()
        }
    }
        
    private var didSetupAnimations = false
    private func setupRandomAnimations() {
        guard self.frame.width > 0.0, self.emitterLayer != nil, !self.didSetupAnimations else {
            return
        }
        self.didSetupAnimations = true
        
        let falloffAnimation1 = CABasicAnimation(keyPath: "emitterBehaviors.randomAttractor0.falloff")
        falloffAnimation1.beginTime = 0.0
        falloffAnimation1.fillMode = .both
        falloffAnimation1.isRemovedOnCompletion = false
        falloffAnimation1.autoreverses = true
        falloffAnimation1.repeatCount = .infinity
        falloffAnimation1.duration = 2.0
        falloffAnimation1.fromValue = -20.0 as NSNumber
        falloffAnimation1.toValue = 60.0 as NSNumber
        falloffAnimation1.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.emitterLayer?.add(falloffAnimation1, forKey: "emitterBehaviors.randomAttractor0.falloff")
        
        let positionAnimation1 = CAKeyframeAnimation(keyPath: "emitterBehaviors.randomAttractor0.position")
        positionAnimation1.beginTime = 0.0
        positionAnimation1.fillMode = .both
        positionAnimation1.isRemovedOnCompletion = false
        positionAnimation1.autoreverses = true
        positionAnimation1.repeatCount = .infinity
        positionAnimation1.duration = 3.0
        positionAnimation1.calculationMode = .discrete
        
        let xInset1: CGFloat = self.frame.width * 0.2
        let yInset1: CGFloat = self.frame.height * 0.2
        var positionValues1: [CGPoint] = []
        for _ in 0 ..< 35 {
            positionValues1.append(CGPoint(x: CGFloat.random(in: xInset1 ..< self.frame.width - xInset1), y: CGFloat.random(in: yInset1 ..< self.frame.height - yInset1)))
        }
        positionAnimation1.values = positionValues1
        
        self.emitterLayer?.add(positionAnimation1, forKey: "emitterBehaviors.randomAttractor0.position")
        
        let falloffAnimation2 = CABasicAnimation(keyPath: "emitterBehaviors.randomAttractor1.falloff")
        falloffAnimation2.beginTime = 0.0
        falloffAnimation2.fillMode = .both
        falloffAnimation2.isRemovedOnCompletion = false
        falloffAnimation2.autoreverses = true
        falloffAnimation2.repeatCount = .infinity
        falloffAnimation2.duration = 2.0
        falloffAnimation2.fromValue = -20.0 as NSNumber
        falloffAnimation2.toValue = 60.0 as NSNumber
        falloffAnimation2.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.emitterLayer?.add(falloffAnimation2, forKey: "emitterBehaviors.randomAttractor1.falloff")
                
        let positionAnimation2 = CAKeyframeAnimation(keyPath: "emitterBehaviors.randomAttractor1.position")
        positionAnimation2.beginTime = 0.0
        positionAnimation2.fillMode = .both
        positionAnimation2.isRemovedOnCompletion = false
        positionAnimation2.autoreverses = true
        positionAnimation2.repeatCount = .infinity
        positionAnimation2.duration = 3.0
        positionAnimation2.calculationMode = .discrete
        
        let xInset2: CGFloat = self.frame.width * 0.1
        let yInset2: CGFloat = self.frame.height * 0.1
        var positionValues2: [CGPoint] = []
        for _ in 0 ..< 35 {
            positionValues2.append(CGPoint(x: CGFloat.random(in: xInset2 ..< self.frame.width - xInset2), y: CGFloat.random(in: yInset2 ..< self.frame.height - yInset2)))
        }
        positionAnimation2.values = positionValues2
        
        self.emitterLayer?.add(positionAnimation2, forKey: "emitterBehaviors.randomAttractor1.position")
    }
    
    private func updateEmitter() {
        guard let (size, _) = self.currentParams else {
            return
        }
        
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.emitterSize = size
        self.emitterLayer?.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        let radius = max(size.width, size.height)
        self.emitterLayer?.setValue(max(size.width, size.height), forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        self.emitterLayer?.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        
        let square = Float(size.width * size.height)
        Queue.mainQueue().async {
            self.emitter?.birthRate = min(100000.0, square * 0.02)
        }
    }
        
    public func update(size: CGSize, color: UIColor, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, color)
        
        let bounds = CGRect(origin: .zero, size: size)
        transition.updateFrame(node: self.emitterNode, frame: bounds)
        
        self.emitterMaskNode.frame = bounds
        self.emitterMaskFillNode.frame = bounds
        
        if self.isNodeLoaded {
            self.updateEmitter()
            self.setupRandomAnimations()
        }
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if !self.isRevealed {
            return super.point(inside: point, with: event)
        } else {
            return false
        }
    }
}
