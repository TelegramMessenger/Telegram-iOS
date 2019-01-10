import UIKit
import Accelerate

extension CGImage {
    var area: Int {
        return width * height
    }
    
    private var size: CGSize {
        return CGSize(width: width, height: height)
    }
    
    private var bytes: Int {
        return bytesPerRow * height
    }
    
    private func imageBuffer(from data: UnsafeMutableRawPointer!) -> vImage_Buffer {
        return vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
    }
    
    func blurred(with boxSize: UInt32, iterations: Int, blendColor: UIColor?, blendMode: CGBlendMode) -> CGImage? {
        guard let providerData = dataProvider?.data else {
            return nil
        }
        
        let inData = malloc(bytes)
        var inBuffer = imageBuffer(from: inData)
        
        let outData = malloc(bytes)
        var outBuffer = imageBuffer(from: outData)
        
        let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize))
        let tempData = malloc(tempSize)
        
        defer {
            free(inData)
            free(outData)
            free(tempData)
        }
        
        let source = CFDataGetBytePtr(providerData)
        memcpy(inBuffer.data, source, bytes)
        
        for _ in 0..<iterations {
            vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempData, 0, 0, boxSize, boxSize, nil, vImage_Flags(kvImageEdgeExtend))
            
            let temp = inBuffer.data
            inBuffer.data = outBuffer.data
            outBuffer.data = temp
        }
        
        let context = colorSpace.flatMap {
            CGContext(data: inBuffer.data, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: $0, bitmapInfo: bitmapInfo.rawValue)
        }
        
        return context?.makeImage(with: blendColor, blendMode: blendMode, size: size)
    }
}


public extension UIImage {
    func blurred(radius: CGFloat, iterations: Int, ratio: CGFloat, blendColor color: UIColor?, blendMode mode: CGBlendMode) -> UIImage? {
        guard let cgImage = cgImage else {
            return nil
        }
        
        if cgImage.area <= 0 || radius <= 0 {
            return self
        }
        
        var boxSize = UInt32(radius * scale * ratio)
        if boxSize % 2 == 0 {
            boxSize += 1
        }
        
        return cgImage.blurred(with: boxSize, iterations: iterations, blendColor: color, blendMode: mode).map {
            UIImage(cgImage: $0, scale: scale, orientation: imageOrientation)
        }
    }
}

extension CGContext {
    static func imageContext(rect: CGRect, opaque: Bool) -> CGContext? {
        UIGraphicsBeginImageContextWithOptions(rect.size, opaque, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.translateBy(x: -rect.origin.x, y: -rect.origin.y)
        context.interpolationQuality = .default
        
        return context
    }
    
    func makeImage(with blendColor: UIColor?, blendMode: CGBlendMode, size: CGSize) -> CGImage? {
        if let color = blendColor {
            setFillColor(color.cgColor)
            setBlendMode(blendMode)
            fill(CGRect(origin: .zero, size: size))
        }
        
        return makeImage()
    }
}

private extension CGRect {
    func rectangle(_ s: CGSize) -> CGRect {
        let x = origin.x / s.width
        let y = origin.y / s.height
        let width = size.width / s.width
        let height = size.height / s.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

class BlurLayer: CALayer {
    private static let blurRadiusKey = "blurRadius"
    private static let blurLayoutKey = "blurLayout"
    @NSManaged var blurRadius: CGFloat
    @NSManaged private var blurLayout: CGFloat
    
    private var fromBlurRadius: CGFloat?
    var presentationRadius: CGFloat {
        if let radius = fromBlurRadius {
            if let layer = presentation() {
                return layer.blurRadius
            } else {
                return radius
            }
        } else {
            return blurRadius
        }
    }
    
    override class func needsDisplay(forKey key: String) -> Bool {
        if key == blurRadiusKey || key == blurLayoutKey {
            return true
        }
        return super.needsDisplay(forKey: key)
    }
    
    open override func action(forKey event: String) -> CAAction? {
        if event == BlurLayer.blurRadiusKey {
            fromBlurRadius = nil
            
            if let action = super.action(forKey: "opacity") as? CABasicAnimation {
                fromBlurRadius = (presentation() ?? self).blurRadius
                
                action.keyPath = event
                action.fromValue = fromBlurRadius
                return action
            }
        }
        
        if event == BlurLayer.blurLayoutKey, let action = super.action(forKey: "opacity") as? CABasicAnimation {
            action.keyPath = event
            action.fromValue = 0
            action.toValue = 1
            return action
        }
        
        return super.action(forKey: event)
    }
}

extension BlurLayer {
    func draw(_ image: UIImage, fixes isFixes: Bool, baseLayer: CALayer?) {
        contents = image.cgImage
        contentsScale = image.scale
        
        if isFixes, let blurLayer = presentation() {
            contentsRect = blurLayer.convert(blurLayer.bounds, to: baseLayer).rectangle(image.size)
        }
    }
    
    func refresh() {
        fromBlurRadius = nil
    }
    
    func animate() {
        UIView.performWithoutAnimation {
            blurLayout = 0
        }
        blurLayout = 1
    }
    
    func render(in context: CGContext, for layer: CALayer) {
        layer.render(in: context)
    }
}

open class DynamicBlurView: UIView {
    open override class var layerClass : AnyClass {
        return BlurLayer.self
    }

    private var staticImage: UIImage?
    private var displayLink: CADisplayLink?
    private var blurLayer: BlurLayer {
        return layer as! BlurLayer
    }
    private let mainQueue = DispatchQueue.main
    private let globalQueue: DispatchQueue = {
        if #available (iOS 8.0, *) {
            return .global(qos: .userInteractive)
        } else {
            return .global(priority: .high)
        }
    }()
    private var renderingTarget: UIView? {
        if isDeepRendering {
            return window
        } else {
            return superview
        }
    }


    open var drawsAsynchronously: Bool = false
    open var blurRadius: CGFloat {
        set { blurLayer.blurRadius = newValue }
        get { return blurLayer.blurRadius }
    }
    /// Blend color.
    open var blendColor: UIColor?
	/// Blend mode.
    open var blendMode: CGBlendMode = .plusLighter
    /// Default is 3.
    open var iterations: Int = 3
    /// If the view want to render beyond the layer, should be true.
    open var isDeepRendering: Bool = false
    /// When none of tracking mode, it can change the radius of blur with the ratio. Should set from 0 to 1.
    open var blurRatio: CGFloat = 1 {
        didSet {
            if let image = staticImage, oldValue != blurRatio {
                draw(image, blurRadius: blurRadius, fixes: false, baseLayer: renderingTarget?.layer)
            }
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        isUserInteractionEnabled = false
    }

    open override func didMoveToWindow() {
        super.didMoveToWindow()

        if let view = renderingTarget, window != nil {
            staticImage = snapshotImage(for: view.layer, conversion: !isDeepRendering)
        }
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if superview == nil {
            displayLink?.invalidate()
            displayLink = nil
        } else {
            linkForDisplay()
        }
    }

    private func async(on queue: DispatchQueue, actions: @escaping () -> Void) {
        queue.async(execute: actions)
    }

    private func sync(on queue: DispatchQueue, actions: () -> Void) {
        queue.sync(execute: actions)
    }

    private func draw(_ image: UIImage, blurRadius radius: CGFloat, fixes isFixes: Bool, baseLayer: CALayer?) {
        async(on: globalQueue) { [weak self] in
            if let me = self, let blurredImage = image.blurred(radius: radius, iterations: me.iterations, ratio: me.blurRatio, blendColor: me.blendColor, blendMode: me.blendMode) {
                me.sync(on: me.mainQueue) {
                    me.blurLayer.draw(blurredImage, fixes: isFixes, baseLayer: baseLayer)
                }
            }
        }
    }

    private func blurLayerRect(to layer: CALayer, conversion: Bool) -> CGRect {
        if conversion {
            let presentationLayer = blurLayer.presentation() ?? blurLayer
            return presentationLayer.convert(presentationLayer.bounds, to: layer)
        } else {
            return layer.bounds
        }
    }

    private func snapshotImage(for layer: CALayer, conversion: Bool) -> UIImage? {
        let rect = blurLayerRect(to: layer, conversion: conversion)
        guard let context = CGContext.imageContext(rect: rect, opaque: isOpaque) else {
            return nil
        }

        blurLayer.render(in: context, for: layer)

        defer {
            UIGraphicsEndImageContext()
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

extension DynamicBlurView {
    open override func display(_ layer: CALayer) {
        let blurRadius = blurLayer.presentationRadius
        let isFixes = isDeepRendering && staticImage != nil
        if let view = renderingTarget, let image = staticImage ?? snapshotImage(for: view.layer, conversion: !isFixes) {
            draw(image, blurRadius: blurRadius, fixes: isFixes, baseLayer: view.layer)
        }
    }
}

extension DynamicBlurView {
    private func linkForDisplay() {
        displayLink?.invalidate()
        displayLink = UIScreen.main.displayLink(withTarget: self, selector: #selector(DynamicBlurView.displayDidRefresh(_:)))
        displayLink?.add(to: .main, forMode: RunLoop.Mode(rawValue: ""))
    }

    @objc private func displayDidRefresh(_ displayLink: CADisplayLink) {
        display(layer)
    }
}
