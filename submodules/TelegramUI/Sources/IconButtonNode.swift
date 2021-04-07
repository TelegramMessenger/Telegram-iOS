import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let circleDiameter: CGFloat = 80.0

final class IconButtonNode: HighlightTrackingButtonNode {
    private let iconNode: ASImageNode
    private var circleNode: ASImageNode?
    
    var icon: UIImage? {
        didSet {
            self.iconNode.image = self.icon
            
            self.setNeedsLayout()
        }
    }
    
    var circleColor: UIColor? {
        didSet {
            if let color = self.circleColor {
                let circleNode: ASImageNode
                if let current = self.circleNode {
                    circleNode = current
                } else {
                    circleNode = ASImageNode()
                    circleNode.alpha = 0.0
                    circleNode.displaysAsynchronously = false
                    circleNode.displayWithoutProcessing = true
                    circleNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: circleDiameter, height: circleDiameter))
                    circleNode.position = CGPoint(x: self.frame.width / 2.0, y: self.frame.height / 2.0)
                    self.insertSubnode(circleNode, at: 0)
                    self.circleNode = circleNode
                }
                circleNode.image = generateFilledCircleImage(diameter: circleDiameter, color: color)
            } else if let current = self.circleNode {
                self.circleNode = nil
                current.removeFromSupernode()
            }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            self.alpha = self.isEnabled ? 1.0 : 0.4
        }
    }
    
    var isPressing = false {
        didSet {
            if self.isPressing != oldValue && !self.isPressing {
                self.highligthedChanged(false)
            }
        }
    }
    
    init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init(pointerStyle: .circle)
        
        self.addSubnode(self.iconNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .linear)
                    transition.updateSublayerTransformScale(node: strongSelf, scale: 0.8)
                    if let circleNode = strongSelf.circleNode {
                        transition.updateAlpha(node: circleNode, alpha: 1.0)
                    }
                } else if !strongSelf.isPressing {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .linear)
                    transition.updateSublayerTransformScale(node: strongSelf, scale: 1.0)
                    if let circleNode = strongSelf.circleNode {
                        transition.updateAlpha(node: circleNode, alpha: 0.0)
                    }
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        self.circleNode?.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
