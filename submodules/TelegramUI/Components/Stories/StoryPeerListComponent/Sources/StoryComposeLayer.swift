import Foundation
import Display
import Metal
import MetalKit
import MetalEngine
import ComponentFlow
import TelegramPresentationData


private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }
    
    let mainBundle = Bundle(for: StoryBlobLayer.self)
    guard let path = mainBundle.path(forResource: "StoryPeerListBundle", ofType: "bundle") else {
        return nil
    }
    guard let bundle = Bundle(path: path) else {
        return nil
    }
    guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }
    
    metalLibraryValue = library
    return library
}

private final class PropertyAnimation<T: Interpolatable> {
    let from: T
    let to: T
    let animation: ComponentTransition.Animation
    let startTimestamp: Double
    private let interpolator: (Interpolatable, Interpolatable, CGFloat) -> Interpolatable
    
    init(fromValue: T, toValue: T, animation: ComponentTransition.Animation, startTimestamp: Double) {
        self.from = fromValue
        self.to = toValue
        self.animation = animation
        self.startTimestamp = startTimestamp
        self.interpolator = T.interpolator()
    }
    
    func valueAt(_ t: CGFloat) -> Interpolatable {
        if t <= 0.0 {
            return self.from
        } else if t >= 1.0 {
            return self.to
        } else {
            return self.interpolator(self.from, self.to, t)
        }
    }
}

private final class AnimatableProperty<T: Interpolatable> {
    var presentationValue: T
    var value: T
    private var animation: PropertyAnimation<T>?
    
    init(value: T) {
        self.value = value
        self.presentationValue = value
    }
    
    func update(value: T, transition: ComponentTransition = .immediate) {
        let currentTimestamp = CACurrentMediaTime()
        if case .none = transition.animation {
            if let animation = self.animation, case let .curve(duration, curve) = animation.animation {
                self.value = value
                let elapsed = duration - (currentTimestamp - animation.startTimestamp)
                if let presentationValue = self.presentationValue as? CGFloat, let newValue = value as? CGFloat, abs(presentationValue - newValue) > 0.56 {
                    self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: .curve(duration: elapsed * 0.8, curve: curve), startTimestamp: currentTimestamp)
                } else {
                    self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: .curve(duration: elapsed, curve: curve), startTimestamp: currentTimestamp)
                }
            } else {
                self.value = value
                self.presentationValue = value
                self.animation = nil
            }
        } else {
            self.value = value
            self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: transition.animation, startTimestamp: currentTimestamp)
        }
    }
    
    func tick(timestamp: Double) -> Bool {
        guard let animation = self.animation, case let .curve(duration, curve) = animation.animation else {
            return false
        }
        
        let timeFromStart = timestamp - animation.startTimestamp
        var t = max(0.0, timeFromStart / duration)
        switch curve {
        case .linear:
            break
        case .easeInOut:
            t = listViewAnimationCurveEaseInOut(t)
        case .spring:
            t = lookupSpringValue(t)
        case let .custom(x1, y1, x2, y2):
            t = bezierPoint(CGFloat(x1), CGFloat(y1), CGFloat(x2), CGFloat(y2), t)
        }
        self.presentationValue = animation.valueAt(t) as! T
    
        if timeFromStart <= duration {
            return true
        }
        self.animation = nil
        return false
    }
}

private func lookupSpringValue(_ t: CGFloat) -> CGFloat {
    let table: [(CGFloat, CGFloat)] = [
        (0.0, 0.0),
        (0.0625, 0.1123005598783493),
        (0.125, 0.31598418951034546),
        (0.1875, 0.5103585720062256),
        (0.25, 0.6650152802467346),
        (0.3125, 0.777747631072998),
        (0.375, 0.8557760119438171),
        (0.4375, 0.9079672694206238),
        (0.5, 0.942038357257843),
        (0.5625, 0.9638798832893372),
        (0.625, 0.9776856303215027),
        (0.6875, 0.9863143563270569),
        (0.75, 0.991658091545105),
        (0.8125, 0.9949421286582947),
        (0.875, 0.9969474077224731),
        (0.9375, 0.9981651306152344),
        (1.0, 1.0)
    ]
    
    for i in 0 ..< table.count - 2 {
        let lhs = table[i]
        let rhs = table[i + 1]
        
        if t >= lhs.0 && t <= rhs.0 {
            let fraction = (t - lhs.0) / (rhs.0 - lhs.0)
            let value = lhs.1 + fraction * (rhs.1 - lhs.1)
            return value
        }
    }
    return 1.0
}

final class StoryBlobLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?
    
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "cameraBlobVertex"),
                  let fragmentFunction = library.makeFunction(name: "cameraBlobFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    private var primarySize = AnimatableProperty<CGFloat>(value: 1.0)
    private var primaryHoleSize = AnimatableProperty<CGFloat>(value: 0.0)
    private var primaryOffsetX = AnimatableProperty<CGFloat>(value: 45.0)
    private var primaryOffsetY = AnimatableProperty<CGFloat>(value: 0.0)
    
    private var secondarySize = AnimatableProperty<CGFloat>(value: 0.85)
    private var secondaryOffsetX = AnimatableProperty<CGFloat>(value: 45.0)
    private var secondaryOffsetY = AnimatableProperty<CGFloat>(value: 0.0)
    
    private var displayLinkSubscription: SharedDisplayLinkDriver.Link?
    private var hasActiveAnimations: Bool = false
    
    override init() {
        super.init()
        
        self.isOpaque = false
                
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                guard let self else {
                    return
                }
                self.updateAnimations()
                if self.hasActiveAnimations {
                    self.setNeedsUpdate()
                }
            }
        }
        
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = nil
        }
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        
        if let layer = layer as? StoryBlobLayer {
            self.primarySize = layer.primarySize
            self.primaryHoleSize = layer.primaryHoleSize
            self.primaryOffsetX = layer.primaryOffsetX
            self.primaryOffsetY = layer.primaryOffsetY
            self.secondarySize = layer.secondarySize
            self.secondaryOffsetX = layer.secondaryOffsetX
            self.secondaryOffsetY = layer.secondaryOffsetY
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updatePrimarySize(_ size: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.height > 0.0 else {
            return
        }
        let mappedSize = size / self.bounds.height
        self.primarySize.update(value: mappedSize, transition: transition)
        
        self.setNeedsUpdate()
    }
    
    func updatePrimaryHoleSize(_ size: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.height > 0.0 else {
            return
        }
        let mappedSize = size / self.bounds.height
        self.primaryHoleSize.update(value: mappedSize, transition: transition)
        
        self.setNeedsUpdate()
    }
    
    func updatePrimaryOffsetX(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.bounds.height * 2.0
        self.primaryOffsetX.update(value: mappedOffset, transition: transition)
        
        self.setNeedsUpdate()
    }
        
    func updatePrimaryOffsetY(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.width > 0.0 else {
            return
        }
        let mappedOffset = offset / self.bounds.width * 2.0
        self.primaryOffsetY.update(value: mappedOffset, transition: transition)
        
        self.setNeedsUpdate()
    }
    
    func updateSecondarySize(_ size: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.height > 0.0 else {
            return
        }
        let mappedSize = size / self.bounds.height
        self.secondarySize.update(value: mappedSize, transition: transition)
        
        self.setNeedsUpdate()
    }
    
    func updateSecondaryOffsetX(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.bounds.height * 2.0
        self.secondaryOffsetX.update(value: mappedOffset, transition: transition)
        
        self.setNeedsUpdate()
    }
    
    func updateSecondaryOffsetY(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.bounds.width > 0.0 else {
            return
        }
        let mappedOffset = offset / self.bounds.width * 2.0
        self.secondaryOffsetY.update(value: mappedOffset, transition: transition)
        
        self.setNeedsUpdate()
    }
    
    private func updateAnimations() {
        let properties = [
            self.primarySize,
            self.primaryHoleSize,
            self.primaryOffsetX,
            self.primaryOffsetY,
            self.secondarySize,
            self.secondaryOffsetX,
            self.secondaryOffsetY,
        ]
        
        let timestamp = CACurrentMediaTime()
        var hasAnimations = false
        for property in properties {
            if property.tick(timestamp: timestamp) {
                hasAnimations = true
            }
        }
        self.hasActiveAnimations = hasAnimations
    }
    
    func update(context: MetalEngineSubjectContext) {
        if self.bounds.isEmpty {
            return
        }
        
        let drawableSize = CGSize(width: self.bounds.width * UIScreen.main.scale, height: self.bounds.height * UIScreen.main.scale)
        
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: Int(drawableSize.width), height: Int(drawableSize.height))), state: RenderState.self, layer: self, commands: { encoder, placement in
            let effectiveRect = placement.effectiveRect
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)

            var primaryParameters = simd_float2(
                Float(self.primarySize.presentationValue),
                Float(self.primaryHoleSize.presentationValue)
            )
            encoder.setFragmentBytes(&primaryParameters, length: MemoryLayout<simd_float2>.size, index: 0)

            var primaryOffset = simd_float2(
                Float(self.primaryOffsetX.presentationValue),
                Float(self.primaryOffsetY.presentationValue)
            )
            encoder.setFragmentBytes(&primaryOffset, length: MemoryLayout<simd_float2>.size, index: 1)
            
            var secondaryParameters = simd_float2(
                Float(self.secondarySize.presentationValue),
                Float(0)
            )
            encoder.setFragmentBytes(&secondaryParameters, length: MemoryLayout<simd_float2>.size, index: 2)
            
            var secondaryOffset = simd_float2(
                Float(self.secondaryOffsetX.presentationValue),
                Float(self.secondaryOffsetY.presentationValue)
            )
            encoder.setFragmentBytes(&secondaryOffset, length: MemoryLayout<simd_float2>.size, index: 3)
            
            var resolution = simd_float2(
                Float(drawableSize.width),
                Float(drawableSize.height)
            )
            encoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_float2>.size, index: 4)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        })
    }
}

final class StoryComposeLayer: CALayer {
    private let theme: PresentationTheme?
    private let strings: PresentationStrings?
    
    private let blobLayer = SimpleLayer()
    private let maskLayer = StoryBlobLayer()
    private let backgroundLayer = SimpleGradientLayer()
    private let foregroundLayer = SimpleGradientLayer()
    private let iconLayer = SimpleLayer()
    private let labelLayer = SimpleLayer()
        
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        super.init()
        
        self.addSublayer(self.blobLayer)
        
        self.blobLayer.mask = self.maskLayer
        self.blobLayer.masksToBounds = true
    
        self.backgroundLayer.type = .axial
        self.backgroundLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.backgroundLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.blobLayer.addSublayer(self.backgroundLayer)
        
        self.foregroundLayer.type = .axial
        self.foregroundLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.foregroundLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.blobLayer.addSublayer(self.foregroundLayer)
        
        self.iconLayer.contents = generateAddIcon(color: theme.list.itemCheckColors.foregroundColor)?.cgImage
        self.iconLayer.opacity = 0.0
        self.blobLayer.addSublayer(self.iconLayer)
        
        if let image = generateAddLabel(strings: strings, color: theme.list.itemPrimaryTextColor) {
            self.labelLayer.contents = image.cgImage
            self.labelLayer.bounds = CGRect(origin: .zero, size: image.size)
            self.addSublayer(self.labelLayer)
            self.labelLayer.opacity = 0.0
        }
        
        if let blurEffect = CALayer.blur() {
            self.iconLayer.filters = [blurEffect]
            blurEffect.setValue(8.0 as NSNumber, forKey: "inputRadius")
            self.labelLayer.filters = [blurEffect]
            blurEffect.setValue(8.0 as NSNumber, forKey: "inputRadius")
        }
    }
    
    override init(layer: Any) {
        if let layer = layer as? StoryComposeLayer {
            self.theme = layer.theme
            self.strings = layer.strings
        } else {
            self.theme = nil
            self.strings = nil
        }
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateOffset(_ offset: CGFloat, baseSize: CGFloat, colors: [CGColor], transition: ComponentTransition = .immediate) {
        self.backgroundLayer.colors = colors
        self.foregroundLayer.locations = [0.0, 0.68, 1.0]
      
        if let theme = self.theme {
            let fillColor = theme.list.itemCheckColors.fillColor
            self.foregroundLayer.colors = [
                fillColor.cgColor,
                fillColor.withAlphaComponent(0.0).cgColor,
                fillColor.withAlphaComponent(0.0).cgColor
            ]
        }
        
        var holeSize = baseSize > 52.0 ? 58.0 : -60.0
        var primaryBaseScale = 1.0
        var secondaryBaseScale = 0.68
        if holeSize < 0.0 {
            if offset > 48.0 {
                holeSize -= min(14.0, (max(0.0, (offset - 48.0)) / 20.0) * 14.0)
            }
            primaryBaseScale = 0.96 + min(1.0, max(0.0, (offset - 20.0)) / 10.0) * 0.04
            secondaryBaseScale = 0.62
        }
        
        var secondaryScale = secondaryBaseScale
        if offset < 20.0 {
            secondaryScale += (offset / 20.0) * 0.2
        } else {
            secondaryScale = min(1.0, max(secondaryBaseScale + 0.2, offset / 75.0))
        }
        
        self.maskLayer.updatePrimaryOffsetX(85.0, transition: transition)
        self.maskLayer.updatePrimarySize(baseSize * primaryBaseScale, transition: transition)
        self.maskLayer.updateSecondaryOffsetX(85.0 - offset, transition: transition)
        self.maskLayer.updatePrimaryHoleSize(holeSize, transition: transition)
        self.maskLayer.updateSecondarySize(55.0 * secondaryScale, transition: transition)
        
        if holeSize < 0.0 {
            transition.setAlpha(layer: self.blobLayer, alpha: min(1.0, max(0.0, offset / 10.0)))
        }
        
        let layerX = self.bounds.width - offset + 5.0
        transition.setPosition(layer: self.iconLayer, position: CGPoint(x: layerX, y: self.bounds.height / 2.0))
        transition.setPosition(layer: self.labelLayer, position: CGPoint(x: layerX, y: self.bounds.height + 13.0 - UIScreenPixel))

        let iconOffset = max(0.0, offset - 35.0)
        let alpha = max(0.0, min(1.0, iconOffset / 15.0))
        let blurRadius = 8.0 - min(8.0, (iconOffset / 20.0) * 8.0)
       
        for layer in [self.iconLayer, self.labelLayer] {
            layer.setValue(blurRadius as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            transition.setAlpha(layer: layer, alpha: alpha)
        }
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        self.blobLayer.frame = self.bounds
        self.maskLayer.frame = self.bounds
        self.backgroundLayer.frame = self.bounds
        self.foregroundLayer.frame = self.bounds
        self.iconLayer.bounds = CGRect(origin: .zero, size: CGSize(width: 30.0, height: 30.0))
    }
}

private func generateAddIcon(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(3.0)
        context.setLineCap(.round)
        
        context.move(to: CGPoint(x: 15.0, y: 5.5))
        context.addLine(to: CGPoint(x: 15.0, y: 24.5))
        context.strokePath()
        
        context.move(to: CGPoint(x: 5.5, y: 15.0))
        context.addLine(to: CGPoint(x: 24.5, y: 15.0))
        context.strokePath()
    })
}


private func generateAddLabel(strings: PresentationStrings,  color: UIColor) -> UIImage? {
    let titleString = NSAttributedString(string: strings.StoryFeed_AddStory, font: Font.regular(11.0), textColor: color, paragraphAlignment: .center)
    var textRect = titleString.boundingRect(with: CGSize(width: 200.0, height: 20.0), options: .usesLineFragmentOrigin, context: nil)
    textRect.size.width = ceil(textRect.size.width)
    textRect.size.height = ceil(textRect.size.height)
    
    return generateImage(textRect.size, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
    
        UIGraphicsPushContext(context)
        titleString.draw(in: textRect)
        UIGraphicsPopContext()
    })
}
