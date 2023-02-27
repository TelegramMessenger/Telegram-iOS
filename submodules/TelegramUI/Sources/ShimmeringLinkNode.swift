import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ShimmerEffect

final class ShimmeringLinkNode: ASDisplayNode {
    private let shimmerEffectNode: ShimmerEffectForegroundNode
    private let borderShimmerEffectNode: ShimmerEffectForegroundNode
    
    private let maskNode: ASImageNode
    private let borderMaskNode: ASImageNode
    
    private(set) var rects: [CGRect] = []
    var color: UIColor {
        didSet {
            self.backgroundColor = color
        }
    }
    
    var innerRadius: CGFloat = 4.0
    var outerRadius: CGFloat = 4.0
    var inset: CGFloat = 2.0
    
    init(color: UIColor) {
        self.color = color
        
        self.shimmerEffectNode = ShimmerEffectForegroundNode()
        self.borderShimmerEffectNode = ShimmerEffectForegroundNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        
        self.borderMaskNode = ASImageNode()
        self.borderMaskNode.displaysAsynchronously = false
        self.borderMaskNode.displayWithoutProcessing = true
        
        super.init()
        
        self.isLayerBacked = true
        
        self.shimmerEffectNode.backgroundColor = color.withAlphaComponent(color.alpha * 0.6)
        
        self.addSubnode(self.shimmerEffectNode)
        //self.addSubnode(self.borderShimmerEffectNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.shimmerEffectNode.layer.mask = self.maskNode.layer
        self.borderShimmerEffectNode.layer.mask = self.borderMaskNode.layer
    }
    
    func updateRects(_ rects: [CGRect], color: UIColor? = nil) {
        var updated = false
        if self.rects != rects {
            updated = true
            self.rects = rects
        }
        
        if let color, !color.isEqual(self.color) {
            updated = true
            self.color = color
        }
        
        if updated {
            self.updateMasks()
        }
    }
    
    private func updateMasks() {
        let (offset, image) = generateRectsImage(color: .white, rects: self.rects, inset: self.inset, outerRadius: self.outerRadius, innerRadius: self.innerRadius, useModernPathCalculation: true)
        
        let (borderOffset, borderImage) = generateRectsImage(color: .white, rects: self.rects.map { $0.insetBy(dx: 0.0, dy: 0.0) }, inset: self.inset, outerRadius: self.outerRadius, innerRadius: self.innerRadius, stroke: true, useModernPathCalculation: true)
        
        if let image = image {
            self.maskNode.frame = CGRect(origin: offset, size: image.size)
            self.maskNode.image = image
        }
        
        if let borderImage = borderImage {
            self.borderMaskNode.frame = CGRect(origin: borderOffset, size: borderImage.size)
            self.borderMaskNode.image = borderImage
        }
    }
    
    func updateLayout(_ size: CGSize) {
        self.shimmerEffectNode.frame = CGRect(origin: .zero, size: size)
        self.borderShimmerEffectNode.frame = CGRect(origin: .zero, size: size)
        
        self.shimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: size), within: size)
        self.borderShimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: size), within: size)
        
        self.shimmerEffectNode.update(backgroundColor: .clear, foregroundColor: self.color.withAlphaComponent(min(1.0, self.color.alpha * 1.2)), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
        self.borderShimmerEffectNode.update(backgroundColor: .clear, foregroundColor: self.color.withAlphaComponent(min(1.0, self.color.alpha * 1.5)), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
    }
}
