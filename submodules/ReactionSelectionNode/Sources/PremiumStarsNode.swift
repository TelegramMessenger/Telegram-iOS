import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AppBundle

private let starsCount = 9
public final class PremiumStarsNode: ASDisplayNode {
    private let starNodes: [ASImageNode]
    private var timer: SwiftSignalKit.Timer?
    
    public override init() {
        let image = UIImage(bundleImageName: "Premium/ReactionsStar")
        var starNodes: [ASImageNode] = []
        for _ in 0 ..< starsCount {
            let node = ASImageNode()
            node.isLayerBacked = true
            node.alpha = 0.0
            node.image = image
            node.displaysAsynchronously = false
            starNodes.append(node)
        }
        self.starNodes = starNodes
        
        super.init()
        
        for node in starNodes {
            self.addSubnode(node)
        }
        
        Queue.mainQueue().async {
            self.setup(firstTime: true)
            
            self.timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                self?.setup()
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func setup(firstTime: Bool = false) {
        let size: CGSize
        if self.frame.width > 0.0 {
            size = self.frame.size
        } else {
            size = CGSize(width: 32.0, height: 32.0)
        }
        let starSize = CGSize(width: 6.0, height: 8.0)
        
        for node in self.starNodes {
            if node.layer.animation(forKey: "transform.scale") == nil && node.layer.animation(forKey: "opacity") == nil {
                let x = CGFloat.random(in: 0 ..< size.width)
                let y = CGFloat.random(in: 0 ..< size.width)
                
                let randomTargetScale = CGFloat.random(in: 0.8 ..< 1.0)
                node.bounds = CGRect(origin: .zero, size: starSize)
                node.position = CGPoint(x: x, y: y)
                
                node.alpha = 1.0
                
                let duration =  CGFloat.random(in: 0.4 ..< 0.65)
                let delay = firstTime ? CGFloat.random(in: 0.0 ..< 0.25) : 0.0
                node.layer.animateScale(from: 0.001, to: randomTargetScale, duration: duration, delay: delay, removeOnCompletion: false, completion: { [weak self, weak node] _ in
                    let duration =  CGFloat.random(in: 0.3 ..< 0.35)
                    node?.alpha = 0.0
                    node?.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak self, weak node] _ in
                        node?.layer.removeAllAnimations()
                        self?.setup()
                    })
                })
            }
        }
    }
}
