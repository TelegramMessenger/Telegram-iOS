import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import UIKitRuntimeUtils
import CoreImage
import AppBundle

private final class ContentContainer: UIView {
    private let maskContentView: UIView
    
    init(maskContentView: UIView) {
        self.maskContentView = maskContentView
        
        super.init(frame: CGRect())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result === self {
            return nil
        }
        return result
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if let subview = subview as? GlassBackgroundView.ContentView {
            self.maskContentView.addSubview(subview.tintMask)
        }
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if let subview = subview as? GlassBackgroundView.ContentView {
            subview.tintMask.removeFromSuperview()
        }
    }
}

public class GlassBackgroundView: UIView {
    public final class TransitionFlagBounce {
        public init() {
        }
    }
    
    public protocol ContentView: UIView {
        var tintMask: UIView { get }
    }
    
    open class ContentLayer: SimpleLayer {
        public var targetLayer: CALayer?
        
        override init() {
            super.init()
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public var position: CGPoint {
            get {
                return super.position
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.position = value
                }
                super.position = value
            }
        }
        
        override public var bounds: CGRect {
            get {
                return super.bounds
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.bounds = value
                }
                super.bounds = value
            }
        }
        
        override public var anchorPoint: CGPoint {
            get {
                return super.anchorPoint
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.anchorPoint = value
                }
                super.anchorPoint = value
            }
        }
        
        override public var anchorPointZ: CGFloat {
            get {
                return super.anchorPointZ
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.anchorPointZ = value
                }
                super.anchorPointZ = value
            }
        }
        
        override public var opacity: Float {
            get {
                return super.opacity
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.opacity = value
                }
                super.opacity = value
            }
        }
        
        override public var sublayerTransform: CATransform3D {
            get {
                return super.sublayerTransform
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.sublayerTransform = value
                }
                super.sublayerTransform = value
            }
        }
        
        override public var transform: CATransform3D {
            get {
                return super.transform
            } set(value) {
                if let targetLayer = self.targetLayer {
                    targetLayer.transform = value
                }
                super.transform = value
            }
        }
        
        override public func add(_ animation: CAAnimation, forKey key: String?) {
            if let targetLayer = self.targetLayer {
                targetLayer.add(animation, forKey: key)
            }
            
            super.add(animation, forKey: key)
        }
        
        override public func removeAllAnimations() {
            if let targetLayer = self.targetLayer {
                targetLayer.removeAllAnimations()
            }
            
            super.removeAllAnimations()
        }
        
        override public func removeAnimation(forKey: String) {
            if let targetLayer = self.targetLayer {
                targetLayer.removeAnimation(forKey: forKey)
            }
            
            super.removeAnimation(forKey: forKey)
        }
    }
    
    public final class ContentColorView: UIView, ContentView {
        override public static var layerClass: AnyClass {
            return ContentLayer.self
        }
        
        public let tintMask: UIView
        
        override public init(frame: CGRect) {
            self.tintMask = UIView()
            
            super.init(frame: CGRect())
            
            self.tintMask.tintColor = .black
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public final class ContentImageView: UIImageView, ContentView {
        override public static var layerClass: AnyClass {
            return ContentLayer.self
        }
        
        private let tintImageView: UIImageView
        public var tintMask: UIView {
            return self.tintImageView
        }
        
        override public var image: UIImage? {
            didSet {
                self.tintImageView.image = self.image
            }
        }
        
        override public var tintColor: UIColor? {
            didSet {
                if self.tintColor != oldValue {
                    self.setMonochromaticEffect(tintColor: self.tintColor)
                }
            }
        }
        
        override public init(frame: CGRect) {
            self.tintImageView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.tintImageView.tintColor = .black
        }
        
        override public init(image: UIImage?) {
            self.tintImageView = UIImageView()
            
            super.init(image: image)
            
            self.tintImageView.image = image
            self.tintImageView.tintColor = .black
        }
        
        override public init(image: UIImage?, highlightedImage: UIImage?) {
            self.tintImageView = UIImageView()
            
            super.init(image: image, highlightedImage: highlightedImage)
            
            self.tintImageView.image = image
            self.tintImageView.tintColor = .black
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public struct TintColor: Equatable {
        public enum Kind {
            case panel
            case custom
        }
        
        public let kind: Kind
        public let color: UIColor
        public let innerColor: UIColor?
        
        public init(kind: Kind, color: UIColor, innerColor: UIColor? = nil) {
            self.kind = kind
            self.color = color
            self.innerColor = innerColor
        }
    }
    
    private struct Params: Equatable {
        let cornerRadius: CGFloat
        let isDark: Bool
        let tintColor: TintColor
        let isInteractive: Bool
        
        init(cornerRadius: CGFloat, isDark: Bool, tintColor: TintColor, isInteractive: Bool) {
            self.cornerRadius = cornerRadius
            self.isDark = isDark
            self.tintColor = tintColor
            self.isInteractive = isInteractive
        }
    }
    
    private let backgroundNode: NavigationBackgroundNode?
    private let nativeView: UIVisualEffectView?
    private let nativeContainerView: UIVisualEffectView?
    private let nativeParamsView: EffectSettingsContainerView?
    
    private let foregroundView: UIImageView?
    private let shadowView: UIImageView?
    
    private let maskContainerView: UIView
    public let maskContentView: UIView
    private let contentContainer: ContentContainer
    
    private var innerBackgroundView: UIView?
    
    public var contentView: UIView {
        if let nativeView = self.nativeView {
            return nativeView.contentView
        } else {
            return self.contentContainer
        }
    }
    
    private var params: Params?
    
    public static var useCustomGlassImpl: Bool = false
    
    public override init(frame: CGRect) {
        if #available(iOS 26.0, *), !GlassBackgroundView.useCustomGlassImpl {
            self.backgroundNode = nil
            
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = false
            let nativeView = UIVisualEffectView(effect: glassEffect)
            //nativeView.layer.anchorPoint = CGPoint()
            self.nativeView = nativeView
            
            let glassContainerEffect = UIGlassContainerEffect()
            let nativeContainerView = UIVisualEffectView(effect: glassContainerEffect)
            self.nativeContainerView = nativeContainerView
            nativeContainerView.contentView.addSubview(nativeView)
            
            let nativeParamsView = EffectSettingsContainerView(frame: CGRect())
            self.nativeParamsView = nativeParamsView
            
            nativeParamsView.addSubview(nativeContainerView)
            
            self.foregroundView = nil
            self.shadowView = nil
        } else {
            self.backgroundNode = NavigationBackgroundNode(color: .black, enableBlur: true, customBlurRadius: 8.0)
            self.nativeView = nil
            self.nativeContainerView = nil
            self.nativeParamsView = nil
            self.foregroundView = UIImageView()
            
            self.shadowView = UIImageView()
        }
        
        self.maskContainerView = UIView()
        self.maskContainerView.backgroundColor = .white
        if let filter = CALayer.luminanceToAlpha() {
            self.maskContainerView.layer.filters = [filter]
        }
        
        self.maskContentView = UIView()
        self.maskContainerView.addSubview(self.maskContentView)
        
        self.contentContainer = ContentContainer(maskContentView: self.maskContentView)
        
        super.init(frame: frame)
        
        if let shadowView = self.shadowView {
            self.addSubview(shadowView)
        }
        if let nativeParamsView = self.nativeParamsView {
            self.addSubview(nativeParamsView)
        }
        if let backgroundNode = self.backgroundNode {
            self.addSubview(backgroundNode.view)
        }
        if let foregroundView = self.foregroundView {
            self.addSubview(foregroundView)
            foregroundView.mask = self.maskContainerView
        }
        self.addSubview(self.contentContainer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        /*if let nativeContainerView = self.nativeContainerView {
            if let result = nativeContainerView.hitTest(self.convert(point, to: nativeContainerView), with: event) {
                return result
            }
        }*/
        return nil
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, transition: ComponentTransition) {
        if let nativeContainerView = self.nativeContainerView, let nativeView = self.nativeView, nativeView.bounds.size != size {
            
            if transition.animation.isImmediate {
                nativeView.layer.cornerRadius = cornerRadius
                nativeView.frame = CGRect(origin: CGPoint(), size: size)
                nativeContainerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: max(size.height, 400.0)))
            } else {
                nativeView.layer.cornerRadius = cornerRadius
                
                let nativeFrame = CGRect(origin: CGPoint(), size: size)
                let nativeContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: max(size.height, 400.0)))
                
                if transition.userData(TransitionFlagBounce.self) != nil {
                    transition.containedViewLayoutTransition.updatePositionSpring(layer: nativeView.layer, position: nativeFrame.center)
                    transition.containedViewLayoutTransition.updateBoundsSpring(layer: nativeView.layer, bounds: CGRect(origin: CGPoint(), size: nativeFrame.size))
                    
                    transition.containedViewLayoutTransition.updatePositionSpring(layer: nativeContainerView.layer, position: nativeContainerFrame.center)
                    transition.containedViewLayoutTransition.updateBoundsSpring(layer: nativeContainerView.layer, bounds: CGRect(origin: CGPoint(), size: nativeContainerFrame.size))
                } else {
                    transition.setFrame(view: nativeView, frame: nativeFrame)
                    transition.setFrame(view: nativeContainerView, frame: nativeContainerFrame)
                }
            }
        }
        if let backgroundNode = self.backgroundNode {
            backgroundNode.updateColor(color: .clear, forceKeepBlur: tintColor.color.alpha != 1.0, transition: transition.containedViewLayoutTransition)
            backgroundNode.update(size: size, cornerRadius: cornerRadius, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        let shadowInset: CGFloat = 32.0
        
        if let innerColor = tintColor.innerColor {
            let innerBackgroundFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: 3.0, dy: 3.0)
            let innerBackgroundRadius = min(innerBackgroundFrame.width, innerBackgroundFrame.height) * 0.5
            
            let innerBackgroundView: UIView
            if let current = self.innerBackgroundView {
                innerBackgroundView = current
            } else {
                innerBackgroundView = UIView()
                self.innerBackgroundView = innerBackgroundView
                self.contentView.insertSubview(innerBackgroundView, at: 0)
                
                innerBackgroundView.frame = innerBackgroundFrame
                innerBackgroundView.layer.cornerRadius = innerBackgroundRadius
            }
            
            innerBackgroundView.backgroundColor = innerColor
            transition.setFrame(view: innerBackgroundView, frame: innerBackgroundFrame)
            transition.setCornerRadius(layer: innerBackgroundView.layer, cornerRadius: innerBackgroundRadius)
        } else if let innerBackgroundView = self.innerBackgroundView {
            self.innerBackgroundView = nil
            innerBackgroundView.removeFromSuperview()
        }
        
        let params = Params(cornerRadius: cornerRadius, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive)
        if self.params != params {
            self.params = params
            
            if let shadowView = self.shadowView {
                let shadowInnerInset: CGFloat = 0.5
                shadowView.image = generateImage(CGSize(width: shadowInset * 2.0 + cornerRadius * 2.0, height: shadowInset * 2.0 + cornerRadius * 2.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    context.setFillColor(UIColor.black.cgColor)
                    context.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: 40.0, color: UIColor(white: 0.0, alpha: 0.04).cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowInset + shadowInnerInset, y: shadowInset + shadowInnerInset), size: CGSize(width: size.width - shadowInset * 2.0 - shadowInnerInset * 2.0, height: size.height - shadowInset * 2.0 - shadowInnerInset * 2.0)))
                    
                    context.setFillColor(UIColor.clear.cgColor)
                    context.setBlendMode(.copy)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowInset + shadowInnerInset, y: shadowInset + shadowInnerInset), size: CGSize(width: size.width - shadowInset * 2.0 - shadowInnerInset * 2.0, height: size.height - shadowInset * 2.0 - shadowInnerInset * 2.0)))
                })?.stretchableImage(withLeftCapWidth: Int(shadowInset + cornerRadius), topCapHeight: Int(shadowInset + cornerRadius))
            }
            
            if let foregroundView = self.foregroundView {
                foregroundView.image = GlassBackgroundView.generateLegacyGlassImage(size: CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0), inset: shadowInset, isDark: isDark, fillColor: tintColor.color)
            } else {
                if let nativeParamsView = self.nativeParamsView, let nativeContainerView = self.nativeContainerView, let nativeView {
                    if #available(iOS 26.0, *) {
                        let glassEffect = UIGlassEffect(style: .regular)
                        switch tintColor.kind {
                        case .panel:
                            glassEffect.tintColor = nil
                        case .custom:
                            glassEffect.tintColor = tintColor.color
                        }
                        glassEffect.isInteractive = params.isInteractive
                        
                        nativeView.effect = glassEffect
                        
                        if isDark {
                            nativeParamsView.lumaMin = 0.0
                            nativeParamsView.lumaMax = 0.15
                        } else {
                            nativeParamsView.lumaMin = 0.25
                            nativeParamsView.lumaMax = 1.0
                        }
                        
                        nativeContainerView.overrideUserInterfaceStyle = isDark ? .dark : .light
                    }
                }
            }
        }
        
        transition.setFrame(view: self.maskContainerView, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width + shadowInset * 2.0, height: size.height + shadowInset * 2.0)))
        transition.setFrame(view: self.maskContentView, frame: CGRect(origin: CGPoint(x: shadowInset, y: shadowInset), size: size))
        if let foregroundView = self.foregroundView {
            transition.setFrame(view: foregroundView, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: -shadowInset, dy: -shadowInset))
        }
        if let shadowView = self.shadowView {
            transition.setFrame(view: shadowView, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: -shadowInset, dy: -shadowInset))
        }
        transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: size))
    }
}

public final class GlassBackgroundContainerView: UIView {
    private final class ContentView: UIView {
        
    }
    
    private let contentViewImpl: ContentView
    public var contentView: UIView {
        return self.contentViewImpl
    }
    
    public override init(frame: CGRect) {
        self.contentViewImpl = ContentView()
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public final class VariableBlurView: UIVisualEffectView {
    public let maxBlurRadius: CGFloat
    
    public var gradientMask: UIImage {
        didSet {
            if self.gradientMask !== oldValue {
                self.resetEffect()
            }
        }
    }
    
    public init(gradientMask: UIImage, maxBlurRadius: CGFloat = 20.0) {
        self.gradientMask = gradientMask
        self.maxBlurRadius = maxBlurRadius
        
        super.init(effect: UIBlurEffect(style: .regular))

        self.resetEffect()

        if self.subviews.indices.contains(1) {
            let tintOverlayView = subviews[1]
            tintOverlayView.alpha = 0
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.resetEffect()
        }
    }
    
    private func resetEffect() {
        let filterClassStringEncoded = "Q0FGaWx0ZXI="
        let filterClassString: String = {
            if
                let data = Data(base64Encoded: filterClassStringEncoded),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }

            return ""
        }()
        let filterWithTypeStringEncoded = "ZmlsdGVyV2l0aFR5cGU6"
        let filterWithTypeString: String = {
            if
                let data = Data(base64Encoded: filterWithTypeStringEncoded),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }

            return ""
        }()

        let filterWithTypeSelector = Selector(filterWithTypeString)

        guard let filterClass = NSClassFromString(filterClassString) as AnyObject as? NSObjectProtocol else {
            return
        }

        guard filterClass.responds(to: filterWithTypeSelector) else {
            return
        }

        let variableBlur = filterClass.perform(filterWithTypeSelector, with: "variableBlur").takeUnretainedValue()

        guard let variableBlur = variableBlur as? NSObject else {
            return
        }
        
        guard let gradientImageRef = self.gradientMask.cgImage else {
            return
        }

        variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImageRef, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")
        variableBlur.setValue(UIScreenScale, forKey: "scale")
        
        let backdropLayer = self.subviews.first?.layer
        backdropLayer?.filters = [variableBlur]
    }
}

private extension CGContext {
    func addBadgePath(in rect: CGRect) {
        saveGState()
        translateBy(x: rect.minX, y: rect.minY)
        scaleBy(x: rect.width / 78.0, y: rect.height / 78.0)
        
        // M 0 39
        move(to: CGPoint(x: 0, y: 39))
        
        // C 0 17.4609 17.4609 0 39 0
        addCurve(to: CGPoint(x: 39, y: 0),
                 control1: CGPoint(x: 0,       y: 17.4609),
                 control2: CGPoint(x: 17.4609, y: 0))
        
        // H 42
        addLine(to: CGPoint(x: 42, y: 0))
        
        // C 61.8823 0 78 16.1177 78 36
        addCurve(to: CGPoint(x: 78, y: 36),
                 control1: CGPoint(x: 61.8823, y: 0),
                 control2: CGPoint(x: 78,      y: 16.1177))
        
        // V 39
        addLine(to: CGPoint(x: 78, y: 39))
        
        // C 78 60.5391 60.5391 78 39 78
        addCurve(to: CGPoint(x: 39, y: 78),
                 control1: CGPoint(x: 78,      y: 60.5391),
                 control2: CGPoint(x: 60.5391, y: 78))
        
        // H 36
        addLine(to: CGPoint(x: 36, y: 78))
        
        // C 16.1177 78 0 61.8823 0 42
        addCurve(to: CGPoint(x: 0, y: 42),
                 control1: CGPoint(x: 16.1177, y: 78),
                 control2: CGPoint(x: 0,       y: 61.8823))
        
        // V 39 / Z
        addLine(to: CGPoint(x: 0, y: 39))
        closePath()
        
        restoreGState()
    }
}

public extension GlassBackgroundView {
    static func generateLegacyGlassImage(size: CGSize, inset: CGFloat, isDark: Bool, fillColor: UIColor) -> UIImage {
        var size = size
        if size == .zero {
            size = CGSize(width: 2.0, height: 2.0)
        }
        let innerSize = size
        size.width += inset * 2.0
        size.height += inset * 2.0
        
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let context = ctx.cgContext
            
            context.clear(CGRect(origin: CGPoint(), size: size))

            let addShadow: (CGContext, Bool, CGPoint, CGFloat, CGFloat, UIColor, CGBlendMode) -> Void = { context, isOuter, position, blur, spread, shadowColor, blendMode in
                var blur = blur
                
                if isOuter {
                    blur += abs(spread)
                    
                    context.beginTransparencyLayer(auxiliaryInfo: nil)
                    context.saveGState()
                    defer {
                        context.restoreGState()
                        context.endTransparencyLayer()
                    }

                    let spreadRect = CGRect(origin: CGPoint(x: inset, y: inset), size: innerSize).insetBy(dx: 0.25, dy: 0.25)
                    let spreadPath = UIBezierPath(
                        roundedRect: spreadRect,
                        cornerRadius: min(spreadRect.width, spreadRect.height) * 0.5
                    ).cgPath

                    context.setShadow(offset: CGSize(width: position.x, height: position.y), blur: blur, color: shadowColor.cgColor)
                    context.setFillColor(UIColor.black.withAlphaComponent(1.0).cgColor)
                    context.addPath(spreadPath)
                    context.fillPath()
                    
                    let cleanRect = CGRect(origin: CGPoint(x: inset, y: inset), size: innerSize)
                    let cleanPath = UIBezierPath(
                        roundedRect: cleanRect,
                        cornerRadius: min(cleanRect.width, cleanRect.height) * 0.5
                    ).cgPath
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    context.addPath(cleanPath)
                    context.fillPath()
                    context.setBlendMode(.normal)
                } else {
                    let image = UIGraphicsImageRenderer(size: size).image(actions: { ctx in
                        let context = ctx.cgContext
                        
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        let spreadRect = CGRect(origin: CGPoint(x: inset, y: inset), size: innerSize).insetBy(dx: -spread - 0.33, dy: -spread - 0.33)

                        context.setShadow(offset: CGSize(width: position.x, height: position.y), blur: blur, color: shadowColor.cgColor)
                        context.setFillColor(shadowColor.cgColor)
                        let enclosingRect = spreadRect.insetBy(dx: -10000.0, dy: -10000.0)
                        context.addPath(UIBezierPath(rect: enclosingRect).cgPath)
                        context.addBadgePath(in: spreadRect)
                        context.fillPath(using: .evenOdd)
                    })
                    
                    UIGraphicsPushContext(context)
                    image.draw(in: CGRect(origin: .zero, size: size), blendMode: blendMode, alpha: 1.0)
                    UIGraphicsPopContext()
                }
            }
            
            addShadow(context, true, CGPoint(), 10.0, 0.0, UIColor(white: 0.0, alpha: 0.06), .normal)
            addShadow(context, true, CGPoint(), 20.0, 0.0, UIColor(white: 0.0, alpha: 0.06), .normal)
            
            var a: CGFloat = 0.0
            var b: CGFloat = 0.0
            var s: CGFloat = 0.0
            fillColor.getHue(nil, saturation: &s, brightness: &b, alpha: &a)
            
            let innerImage: UIImage
            if size == CGSize(width: 40.0 + inset * 2.0, height: 40.0 + inset * 2.0), b >= 0.2 {
                innerImage = UIGraphicsImageRenderer(size: size).image { ctx in
                    let context = ctx.cgContext
                    
                    context.setFillColor(fillColor.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    
                    if let image = UIImage(bundleImageName: "Item List/GlassEdge40x40") {
                        let imageInset = (image.size.width - 40.0) * 0.5
                        
                        if s == 0.0 && abs(a - 0.7) < 0.1 && !isDark {
                            image.draw(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset - imageInset, dy: inset - imageInset), blendMode: .normal, alpha: 1.0)
                        } else if s <= 0.3 && !isDark {
                            image.draw(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset - imageInset, dy: inset - imageInset), blendMode: .normal, alpha: 0.7)
                        } else if b >= 0.2 {
                            let maxAlpha: CGFloat = isDark ? 0.7 : 0.8
                            image.draw(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset - imageInset, dy: inset - imageInset), blendMode: .overlay, alpha: max(0.5, min(1.0, maxAlpha * s)))
                        } else {
                            image.draw(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset - imageInset, dy: inset - imageInset), blendMode: .normal, alpha: 0.5)
                        }
                    }
                }
            } else {
                innerImage = UIGraphicsImageRenderer(size: size).image { ctx in
                    let context = ctx.cgContext
                    
                    context.setFillColor(fillColor.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset).insetBy(dx: 0.1, dy: 0.1))
                    
                    addShadow(context, true, CGPoint(x: 0.0, y: 0.0), 20.0, 0.0, UIColor(white: 0.0, alpha: 0.04), .normal)
                    addShadow(context, true, CGPoint(x: 0.0, y: 0.0), 5.0, 0.0, UIColor(white: 0.0, alpha: 0.04), .normal)
                    
                    if s <= 0.3 && !isDark {
                        addShadow(context, false, CGPoint(x: 0.0, y: 0.0), 8.0, 0.0, UIColor(white: 0.0, alpha: 0.4), .overlay)
                        
                        let edgeAlpha: CGFloat = max(0.8, min(1.0, a))
                        
                        for _ in 0 ..< 2 {
                            addShadow(context, false, CGPoint(x: -0.64, y: -0.64), 0.8, 0.0, UIColor(white: 1.0, alpha: edgeAlpha), .normal)
                            addShadow(context, false, CGPoint(x: 0.64, y: 0.64), 0.8, 0.0, UIColor(white: 1.0, alpha: edgeAlpha), .normal)
                        }
                    } else if b >= 0.2 {
                        let edgeAlpha: CGFloat = max(0.2, min(isDark ? 0.5 : 0.7, a * a * a))
                        
                        addShadow(context, false, CGPoint(x: -0.64, y: -0.64), 0.5, 0.0, UIColor(white: 1.0, alpha: edgeAlpha), .plusLighter)
                        addShadow(context, false, CGPoint(x: 0.64, y: 0.64), 0.5, 0.0, UIColor(white: 1.0, alpha: edgeAlpha), .plusLighter)
                    } else {
                        let edgeAlpha: CGFloat = max(0.4, min(isDark ? 0.5 : 0.7, a * a * a))
                        
                        addShadow(context, false, CGPoint(x: -0.64, y: -0.64), 1.2, 0.0, UIColor(white: 1.0, alpha: edgeAlpha), .normal)
                        addShadow(context, false, CGPoint(x: 0.64, y: 0.64), 1.2, 0.0, UIColor(white: 1.0, alpha: edgeAlpha), .normal)
                    }
                }
            }
            
            context.addEllipse(in: CGRect(origin: CGPoint(x: inset, y: inset), size: innerSize))
            context.clip()
            innerImage.draw(in: CGRect(origin: CGPoint(), size: size))
        }.stretchableImage(withLeftCapWidth: Int(size.width * 0.5), topCapHeight: Int(size.height * 0.5))
    }
    
    static func generateForegroundImage(size: CGSize, isDark: Bool, fillColor: UIColor) -> UIImage {
        var size = size
        if size == .zero {
            size = CGSize(width: 1.0, height: 1.0)
        }
        
        return generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let maxColor = UIColor(white: 1.0, alpha: isDark ? 0.2 : 0.9)
            let minColor = UIColor(white: 1.0, alpha: 0.0)
            
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            let lineWidth: CGFloat = isDark ? 0.33 : 0.66
            
            context.saveGState()
            
            let darkShadeColor = UIColor(white: isDark ? 1.0 : 0.0, alpha: isDark ? 0.0 : 0.035)
            let lightShadeColor = UIColor(white: isDark ? 0.0 : 1.0, alpha: isDark ? 0.0 : 0.035)
            let innerShadowBlur: CGFloat = 24.0
            
            context.resetClip()
            context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
            context.clip()
            context.addRect(CGRect(origin: CGPoint(), size: size).insetBy(dx: -100.0, dy: -100.0))
            context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.black.cgColor)
            context.setShadow(offset: CGSize(width: 10.0, height: -10.0), blur: innerShadowBlur, color: darkShadeColor.cgColor)
            context.fillPath(using: .evenOdd)
            
            context.resetClip()
            context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
            context.clip()
            context.addRect(CGRect(origin: CGPoint(), size: size).insetBy(dx: -100.0, dy: -100.0))
            context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.black.cgColor)
            context.setShadow(offset: CGSize(width: -10.0, height: 10.0), blur: innerShadowBlur, color: lightShadeColor.cgColor)
            context.fillPath(using: .evenOdd)
            
            context.restoreGState()
            
            context.setLineWidth(lineWidth)
            
            context.addRect(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height)))
            context.clip()
            context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
            context.replacePathWithStrokedPath()
            context.clip()
            
            do {
                var locations: [CGFloat] = [0.0, 0.5, 0.5 + 0.2, 1.0 - 0.1, 1.0]
                let colors: [CGColor] = [maxColor.cgColor, maxColor.cgColor, minColor.cgColor, minColor.cgColor, maxColor.cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            }
            
            context.resetClip()
            context.addRect(CGRect(origin: CGPoint(x: size.width - size.width * 0.5, y: 0.0), size: CGSize(width: size.width * 0.5, height: size.height)))
            context.clip()
            context.addEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
            context.replacePathWithStrokedPath()
            context.clip()
            
            do {
                var locations: [CGFloat] = [0.0, 0.1, 0.5 - 0.2, 0.5, 1.0]
                let colors: [CGColor] = [maxColor.cgColor, minColor.cgColor, minColor.cgColor, maxColor.cgColor, maxColor.cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            }
        })!.stretchableImage(withLeftCapWidth: Int(size.width * 0.5), topCapHeight: Int(size.height * 0.5))
    }
}

public final class GlassBackgroundComponent: Component {
    private let size: CGSize
    private let cornerRadius: CGFloat
    private let isDark: Bool
    private let tintColor: GlassBackgroundView.TintColor
    
    public init(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: GlassBackgroundView.TintColor) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.isDark = isDark
        self.tintColor = tintColor
    }
    
    public static func == (lhs: GlassBackgroundComponent, rhs: GlassBackgroundComponent) -> Bool {
        if lhs.size != rhs.size {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.isDark != rhs.isDark {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return true
    }
    
    public final class View: GlassBackgroundView {
        func update(component: GlassBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.update(size: component.size, cornerRadius: component.cornerRadius, isDark: component.isDark, tintColor: component.tintColor, transition: transition)
            
            return component.size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
