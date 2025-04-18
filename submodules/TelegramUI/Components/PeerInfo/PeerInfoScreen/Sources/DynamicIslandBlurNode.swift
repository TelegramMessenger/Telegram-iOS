import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import AnimationUI
import Display

final class DynamicIslandMaskNode: ASDisplayNode {
    var animationNode: AnimationNode?
    
    var isForum = false {
        didSet {
            if self.isForum != oldValue {
                self.animationNode?.removeFromSupernode()
                let animationNode = AnimationNode(animation: "ForumAvatarMask")
                self.addSubnode(animationNode)
                self.animationNode = animationNode
            }
        }
    }
    
    override init() {
        let animationNode = AnimationNode(animation: "UserAvatarMask")
        self.animationNode = animationNode
        
        super.init()
        
        self.addSubnode(animationNode)
    }
    
    func update(_ value: CGFloat) {
        self.animationNode?.setProgress(value)
    }
    
    var animating = false
    
    override func layout() {
        self.animationNode?.frame = self.bounds
    }
}

final class DynamicIslandBlurNode: ASDisplayNode {
    private var effectView: UIVisualEffectView?
    private let fadeNode = ASDisplayNode()
    let gradientNode = ASImageNode()

    private var hierarchyTrackingNode: HierarchyTrackingNode?
    
    deinit {
        self.animator?.stopAnimation(true)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let hierarchyTrackingNode = HierarchyTrackingNode({ [weak self] value in
            if !value {
                self?.animator?.stopAnimation(true)
                self?.animator = nil
            }
        })
        self.hierarchyTrackingNode = hierarchyTrackingNode
        self.addSubnode(hierarchyTrackingNode)
        
        self.fadeNode.backgroundColor = .black
        self.fadeNode.alpha = 0.0
        
        self.gradientNode.displaysAsynchronously = false
        let gradientImage = generateImage(CGSize(width: 100.0, height: 100.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            
            var locations: [CGFloat] = [0.0, 0.87, 1.0]
            let colors: [CGColor] = [UIColor(rgb: 0x000000, alpha: 0.0).cgColor, UIColor(rgb: 0x000000, alpha: 0.0).cgColor, UIColor(rgb: 0x000000, alpha: 1.0).cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            let endRadius: CGFloat = 90.0
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0 + 38.0)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: endRadius, options: .drawsAfterEndLocation)
        })
        self.gradientNode.image = gradientImage
        
        let effectView = UIVisualEffectView(effect: nil)
        self.effectView = effectView
        self.view.insertSubview(effectView, at: 0)
        
        self.addSubnode(self.gradientNode)
        self.addSubnode(self.fadeNode)
    }
    
    private var animator: UIViewPropertyAnimator?
    
    func prepare() -> Bool {
        guard self.animator == nil else {
            return false
        }
        let animator =  UIViewPropertyAnimator(duration: 1.0, curve: .linear)
        self.animator = animator
        self.effectView?.effect = nil
        animator.addAnimations { [weak self] in
            self?.effectView?.effect = UIBlurEffect(style: .dark)
        }
        return true
    }
    
    func update(_ value: CGFloat) {
        let fadeAlpha = min(1.0, max(0.0, -0.25 + value * 1.55))
        if value > 0.0 {
            var value = value
            let updated = self.prepare()
            if value > 0.99 && updated {
                value = 0.99
            }
            self.animator?.fractionComplete = max(0.0, -0.1 + value * 1.1)
        } else {
            self.animator?.stopAnimation(true)
            self.animator = nil
            self.effectView?.effect = nil
        }
        self.fadeNode.alpha = fadeAlpha
    }
    
    override func layout() {
        super.layout()
        
        self.effectView?.frame = self.bounds
        self.fadeNode.frame = self.bounds
        
        let gradientSize = CGSize(width: 100.0, height: 100.0)
        self.gradientNode.frame = CGRect(origin: CGPoint(x: (self.bounds.width - gradientSize.width) / 2.0, y: 0.0), size: gradientSize)
    }
}
