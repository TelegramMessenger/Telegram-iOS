import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ShimmerEffect

public final class ShimmeringLinkNode: ASDisplayNode {
    private let shimmerEffectNode: ShimmerEffectForegroundNode
    private let borderShimmerEffectNode: ShimmerEffectForegroundNode
    
    private let maskNode: ASImageNode
    private let borderMaskNode: ASImageNode
    
    private(set) var rects: [CGRect] = []
    public var color: UIColor {
        didSet {
            self.backgroundColor = color
        }
    }
    private let isSkeleton: Bool
    
    public var innerRadius: CGFloat = 4.0
    public var outerRadius: CGFloat = 4.0
    public var inset: CGFloat = 2.0
    
    public init(color: UIColor, isSkeleton: Bool = false) {
        self.color = color
        self.isSkeleton = isSkeleton
        
        self.shimmerEffectNode = ShimmerEffectForegroundNode()
        self.borderShimmerEffectNode = ShimmerEffectForegroundNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isLayerBacked = true
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
    
    override public func didLoad() {
        super.didLoad()
        
        if self.isSkeleton {
            self.shimmerEffectNode.removeFromSupernode()
            self.addSubnode(self.maskNode)
        } else {
            self.shimmerEffectNode.layer.mask = self.maskNode.layer
            self.borderShimmerEffectNode.layer.mask = self.borderMaskNode.layer
        }
    }
    
    public func updateRects(_ rects: [CGRect], color: UIColor? = nil) {
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
        if self.isSkeleton {
            let (offset, image) = generateSkeletonRectsImage(color: self.color, rects: self.rects)
            if let image = image {
                self.maskNode.frame = CGRect(origin: offset, size: image.size)
                self.maskNode.image = image
            }
        } else {
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
    }
    
    public func updateLayout(_ size: CGSize) {
        self.shimmerEffectNode.frame = CGRect(origin: .zero, size: size)
        self.borderShimmerEffectNode.frame = CGRect(origin: .zero, size: size)
        
        self.shimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: size), within: size)
        self.borderShimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: size), within: size)
        
        self.shimmerEffectNode.update(backgroundColor: .clear, foregroundColor: self.color.withMultipliedAlpha(1.75), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
        self.borderShimmerEffectNode.update(backgroundColor: .clear, foregroundColor: self.color.withMultipliedAlpha(2.0), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
    }
}

private func generateSkeletonRectsImage(color: UIColor, rects: [CGRect]) -> (CGPoint, UIImage?) {
    if rects.isEmpty {
        return (CGPoint(), nil)
    }
    
    var topLeft = rects[0].origin
    var bottomRight = CGPoint(x: rects[0].maxX, y: rects[0].maxY)
    for i in 1 ..< rects.count {
        topLeft.x = min(topLeft.x, rects[i].origin.x)
        topLeft.y = min(topLeft.y, rects[i].origin.y)
        bottomRight.x = max(bottomRight.x, rects[i].maxX)
        bottomRight.y = max(bottomRight.y, rects[i].maxY)
    }
    
    let drawingInset: CGFloat = 0.0
    
    topLeft.x -= drawingInset
    topLeft.y -= drawingInset
    bottomRight.x += drawingInset * 2.0
    bottomRight.y += drawingInset * 2.0
    
    return (topLeft, generateImage(CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setFillColor(color.cgColor)
        for rect in rects {
            context.addPath(UIBezierPath(roundedRect: rect.offsetBy(dx: -topLeft.x, dy: -topLeft.y), cornerRadius: rect.height * 0.5).cgPath)
        }
        context.fillPath()
    }))
}
