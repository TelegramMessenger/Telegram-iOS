import Foundation
import UIKit
import AsyncDisplayKit
import Display
import UIKitRuntimeUtils
import ComponentFlow

open class RasterizedCompositionLayer: CALayer {
    private final class SublayerReference {
        weak var layer: CALayer?
        
        init(layer: CALayer) {
            self.layer = layer
        }
    }
    
    private var sublayerReferences: [SublayerReference] = []
    
    public var onUpdatedIsAnimating: (() -> Void)?
    public var onContentsUpdated: (() -> Void)?
    
    override public var position: CGPoint {
        didSet {
            if self.position != oldValue {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var bounds: CGRect {
        didSet {
            if self.bounds != oldValue {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var transform: CATransform3D {
        didSet {
            if !CATransform3DEqualToTransform(self.transform, oldValue) {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var opacity: Float {
        didSet {
            if self.opacity != oldValue {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var isHidden: Bool {
        didSet {
            if self.isHidden != oldValue {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var backgroundColor: CGColor? {
        didSet {
            if let lhs = self.backgroundColor, let rhs = oldValue {
                if lhs != rhs {
                    self.onContentsUpdated?()
                }
            } else if (self.backgroundColor == nil) != (oldValue == nil) {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var cornerRadius: CGFloat {
        didSet {
            if self.cornerRadius != oldValue {
                self.onContentsUpdated?()
            }
        }
    }
    
    override public var masksToBounds: Bool {
        didSet {
            if self.masksToBounds != oldValue {
                self.onContentsUpdated?()
            }
        }
    }
    
    public var hasAnimationsInTree: Bool {
        if let animationKeys = self.animationKeys(), !animationKeys.isEmpty {
            return true
        }
        if let sublayers = self.sublayers {
            for sublayer in sublayers {
                if let sublayer = sublayer as? RasterizedCompositionLayer {
                    if sublayer.hasAnimationsInTree {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    override public init() {
        super.init()
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func onLayerAdded(layer: CALayer) {
        if !self.sublayerReferences.contains(where: { $0.layer === layer }) {
            self.sublayerReferences.append(SublayerReference(layer: layer))
        }
        if let layer = layer as? RasterizedCompositionLayer {
            layer.onUpdatedIsAnimating = { [weak self] in
                self?.onUpdatedIsAnimating?()
            }
            layer.onContentsUpdated = { [weak self] in
                self?.onContentsUpdated?()
            }
        } else {
            assertionFailure()
        }
        
        self.onUpdatedIsAnimating?()
        self.onContentsUpdated?()
    }
    
    private func cleanupSublayerReferences() {
        for i in (0 ..< self.sublayerReferences.count).reversed() {
            if let layer = sublayerReferences[i].layer {
                if layer.superlayer !== self {
                    sublayerReferences.remove(at: i)
                }
            } else {
                sublayerReferences.remove(at: i)
            }
        }
    }
    
    override public func addSublayer(_ layer: CALayer) {
        super.addSublayer(layer)
        
        self.onLayerAdded(layer: layer)
    }
    
    override public func insertSublayer(_ layer: CALayer, at idx: UInt32) {
        super.insertSublayer(layer, at: idx)
        
        self.onLayerAdded(layer: layer)
    }

    override public func insertSublayer(_ layer: CALayer, below sibling: CALayer?) {
        super.insertSublayer(layer, below: sibling)
        
        self.onLayerAdded(layer: layer)
    }

    override public func insertSublayer(_ layer: CALayer, above sibling: CALayer?) {
        super.insertSublayer(layer, above: sibling)
        
        self.onLayerAdded(layer: layer)
    }

    override public func replaceSublayer(_ oldLayer: CALayer, with newLayer: CALayer) {
        super.replaceSublayer(oldLayer, with: newLayer)
        
        self.onLayerAdded(layer: newLayer)
    }
    
    override public func add(_ anim: CAAnimation, forKey key: String?) {
        let anim = anim.copy() as! CAAnimation
        let completion = anim.completion
        anim.completion = { [weak self] flag in
            completion?(flag)
            
            guard let self else {
                return
            }
            self.onUpdatedIsAnimating?()
        }
        
        super.add(anim, forKey: key)
    }
    
    override public func removeAllAnimations() {
        super.removeAllAnimations()
        
        self.onUpdatedIsAnimating?()
    }
    
    override public func removeAnimation(forKey key: String) {
        super.removeAnimation(forKey: key)
        
        if let animationKeys = self.animationKeys(), !animationKeys.isEmpty {
        } else {
            self.onUpdatedIsAnimating?()
        }
    }
}

public final class RasterizedCompositionImageLayer: RasterizedCompositionLayer {
    public var image: UIImage? {
        didSet {
            if self.image !== oldValue {
                if let image = self.image {
                    let capInsets = image.capInsets
                    if capInsets.left.isZero && capInsets.top.isZero && capInsets.right.isZero && capInsets.bottom.isZero {
                        self.contentsScale = image.scale
                        self.contents = image.cgImage
                    } else {
                        ASDisplayNodeSetResizableContents(self, image)
                    }
                } else {
                    self.contents = nil
                }
                self.onContentsUpdated?()
            }
        }
    }
}

private func calculateSublayerBounds(layer: CALayer) -> CGRect {
    var result: CGRect
    if layer.contents != nil {
        result = layer.bounds
    } else {
        result = CGRect()
    }
    
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let sublayerBounds = sublayer.convert(sublayer.bounds, to: layer)
            if result.isEmpty {
                result = sublayerBounds
            } else {
                result = result.union(sublayerBounds)
            }
        }
    }
    
    return result
}

public final class RasterizedCompositionMonochromeLayer: SimpleLayer {
    public let contentsLayer = RasterizedCompositionLayer()
    public let maskedLayer = SimpleLayer()
    public let rasterizedLayer = SimpleLayer()
    
    private var isContentsUpdateScheduled: Bool = false
    private var isRasterizationModeUpdateScheduled: Bool = false
    
    override public init() {
        super.init()
        
        self.maskedLayer.opacity = 0.0
        self.addSublayer(self.maskedLayer)
        
        self.maskedLayer.mask = self.contentsLayer
        self.maskedLayer.rasterizationScale = UIScreenScale
        
        self.contentsLayer.backgroundColor = UIColor.black.cgColor
        if let filter = makeLuminanceToAlphaFilter() {
            self.contentsLayer.filters = [filter]
        }
        self.contentsLayer.rasterizationScale = UIScreenScale
        
        self.addSublayer(self.rasterizedLayer)
        
        self.contentsLayer.onContentsUpdated = { [weak self] in
            guard let self else {
                return
            }
            if !self.contentsLayer.hasAnimationsInTree {
                self.scheduleContentsUpdate()
            }
        }
        
        self.contentsLayer.onUpdatedIsAnimating = { [weak self] in
            guard let self else {
                return
            }
            self.scheduleUpdateRasterizationMode()
        }
        
        self.isContentsUpdateScheduled = true
        self.isRasterizationModeUpdateScheduled = true
        self.setNeedsLayout()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    private func scheduleContentsUpdate() {
        self.isContentsUpdateScheduled = true
        self.setNeedsLayout()
    }
    
    private func scheduleUpdateRasterizationMode() {
        self.isRasterizationModeUpdateScheduled = true
        self.setNeedsLayout()
    }
    
    override public func layoutSublayers() {
        super.layoutSublayers()
        
        if self.isRasterizationModeUpdateScheduled {
            self.isRasterizationModeUpdateScheduled = false
            self.updateRasterizationMode()
        }
        if self.isContentsUpdateScheduled {
            self.isContentsUpdateScheduled = false
            if !self.contentsLayer.hasAnimationsInTree {
                self.updateContents()
            }
        }
    }
    
    private func updateContents() {
        var contentBounds = calculateSublayerBounds(layer: self.contentsLayer)
        contentBounds.size.width = ceil(contentBounds.width)
        contentBounds.size.height = ceil(contentBounds.height)
        self.rasterizedLayer.frame = contentBounds
        let contentsImage = generateImage(contentBounds.size, rotatedContext: { size, context in
            UIGraphicsPushContext(context)
            defer {
                UIGraphicsPopContext()
            }
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.translateBy(x: -contentBounds.minX, y: -contentBounds.minY)
            
            self.contentsLayer.render(in: context)
        })
        
        if let contentsImage {
            if let context = DrawingContext(size: contentsImage.size, scale: 0.0, opaque: false, clear: true), let alphaContext = DrawingContext(size: contentsImage.size, scale: 0.0, opaque: false, clear: true) {
                context.withContext { c in
                    UIGraphicsPushContext(c)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    c.clear(CGRect(origin: CGPoint(), size: context.size))
                    contentsImage.draw(in: CGRect(origin: CGPoint(), size: context.size), blendMode: .normal, alpha: 1.0)
                }
                alphaContext.withContext { c in
                    UIGraphicsPushContext(c)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    c.clear(CGRect(origin: CGPoint(), size: context.size))
                    contentsImage.draw(in: CGRect(origin: CGPoint(), size: context.size), blendMode: .normal, alpha: 1.0)
                }
                context.blt(alphaContext, at: CGPoint(), mode: .AlphaFromColor)
                
                self.rasterizedLayer.contents = context.generateImage()?.cgImage
            }
        } else {
            self.rasterizedLayer.contents = nil
        }
    }
    
    private func updateRasterizationMode() {
        self.maskedLayer.opacity = self.contentsLayer.hasAnimationsInTree ? 1.0 : 0.0
        if self.rasterizedLayer.isHidden != (self.maskedLayer.opacity != 0.0) {
            self.rasterizedLayer.isHidden = self.maskedLayer.opacity != 0.0
            if !self.rasterizedLayer.isHidden {
                self.updateContents()
            }
        }
    }
}
