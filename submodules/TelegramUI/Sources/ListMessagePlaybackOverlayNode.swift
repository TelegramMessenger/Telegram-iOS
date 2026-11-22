import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let backgroundImage = generateStretchableFilledCircleImage(radius: 4.0, color: UIColor(white: 0.0, alpha: 0.5))

final class ListMessagePlaybackOverlayNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let barNodes: [ASDisplayNode]
    
    var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                if self.isInHierarchy {
                    if self.isPlaying {
                        self.animateToPlaying()
                    } else {
                        self.animateToPaused()
                    }
                }
            }
        }
    }
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.image = backgroundImage
        
        let baseSize = CGSize(width: 48.0, height: 48.0)
        let barSize = CGSize(width: 3.0, height: 13.0)
        let barSpacing: CGFloat = 2.0
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: baseSize)
        
        let barsOrigin = CGPoint(x: floor((baseSize.width - (barSize.width * 4.0 + barSpacing * 3.0)) / 2.0), y: 23.0)
        
        var barNodes: [ASDisplayNode] = []
        for i in 0 ..< 4 {
            let barNode = ASDisplayNode()
            barNode.frame = CGRect(origin: barsOrigin.offsetBy(dx: CGFloat(i) * (barSize.width + barSpacing), dy: 0.0), size: barSize)
            barNode.isLayerBacked = true
            barNode.backgroundColor = .white
            barNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            barNode.transform = CATransform3DMakeScale(1.0, 0.2, 1.0)
            barNodes.append(barNode)
        }
        self.barNodes = barNodes
        
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.backgroundNode)
        
        for barNode in self.barNodes {
            self.addSubnode(barNode)
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        if self.isPlaying {
            self.animateToPlaying()
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        for barNode in self.barNodes {
            barNode.layer.removeAnimation(forKey: "transform.scale.y")
        }
    }
    
    private func animateToPlaying() {
        for barNode in self.barNodes {
            let randValueMul = Float(arc4random()) / Float(UInt32.max)
            let randDurationMul = Double(arc4random()) / Double(UInt32.max)
            
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.toValue = Float(0.5 + 0.5 * randValueMul) as NSNumber
            animation.autoreverses = true
            animation.duration = 0.25 + 0.25 * randDurationMul
            animation.repeatCount = Float.greatestFiniteMagnitude;
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
            
            barNode.layer.removeAnimation(forKey: "transform.scale.y")
            barNode.layer.add(animation, forKey: "transform.scale.y")
        }
    }
    
    private func animateToPaused() {
        for barNode in self.barNodes {
            if let presentationLayer = barNode.layer.presentation() {
                let animation = CABasicAnimation(keyPath: "transform.scale.y")
                animation.fromValue = (presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0
                animation.toValue = 0.2 as NSNumber
                animation.duration = 0.25
                barNode.layer.add(animation, forKey: "transform.scale.y")
            }
        }
    }
}
