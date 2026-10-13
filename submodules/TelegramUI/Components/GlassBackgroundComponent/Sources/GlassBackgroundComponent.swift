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
            if let gestureRecognizers = self.gestureRecognizers, !gestureRecognizers.isEmpty {
                return result
            }
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
        public enum CustomStyle {
            case `default`
            case clear
        }
        
        public enum Kind: Equatable {
            case panel
            case clear
            case custom(style: CustomStyle, color: UIColor)
        }
        
        public let kind: Kind
        public let innerColor: UIColor?
        public let innerInset: CGFloat
        
        public init(kind: Kind, innerColor: UIColor? = nil, innerInset: CGFloat = 3.0) {
            self.kind = kind
            self.innerColor = innerColor
            self.innerInset = innerInset
        }
    }
    
    public struct CornerRadii: Equatable {
        public let topLeft: CGFloat
        public let topRight: CGFloat
        public let bottomLeft: CGFloat
        public let bottomRight: CGFloat

        public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomLeft = bottomLeft
            self.bottomRight = bottomRight
        }

        public init(radius: CGFloat) {
            self.init(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
        }

        fileprivate func insetBy(_ value: CGFloat) -> CornerRadii {
            return CornerRadii(
                topLeft: max(0.0, self.topLeft - value),
                topRight: max(0.0, self.topRight - value),
                bottomLeft: max(0.0, self.bottomLeft - value),
                bottomRight: max(0.0, self.bottomRight - value)
            )
        }

        fileprivate var maximum: CGFloat {
            return max(max(self.topLeft, self.topRight), max(self.bottomLeft, self.bottomRight))
        }
    }

    public enum Shape: Equatable {
        case roundedRect(cornerRadius: CGFloat)
        case customRoundedRect(cornerRadii: CornerRadii)

        fileprivate func cornerRadii(for size: CGSize) -> CornerRadii {
            switch self {
            case let .roundedRect(cornerRadius):
                return GlassBackgroundView.clampedCornerRadii(size: size, cornerRadii: CornerRadii(radius: cornerRadius))
            case let .customRoundedRect(cornerRadii):
                return GlassBackgroundView.clampedCornerRadii(size: size, cornerRadii: cornerRadii)
            }
        }

        func maximumCornerRadius(for size: CGSize) -> CGFloat {
            return self.cornerRadii(for: size).maximum
        }
    }

    static func clampedCornerRadii(size: CGSize, cornerRadii: CornerRadii) -> CornerRadii {
        let size = CGSize(width: max(0.0, size.width), height: max(0.0, size.height))
        var cornerRadii = CornerRadii(
            topLeft: max(0.0, cornerRadii.topLeft),
            topRight: max(0.0, cornerRadii.topRight),
            bottomLeft: max(0.0, cornerRadii.bottomLeft),
            bottomRight: max(0.0, cornerRadii.bottomRight)
        )

        func scaleFor(edgeLength: CGFloat, _ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
            let sum = lhs + rhs
            if sum <= edgeLength || sum.isZero {
                return 1.0
            }
            return edgeLength / sum
        }

        let scale = min(
            1.0,
            scaleFor(edgeLength: size.width, cornerRadii.topLeft, cornerRadii.topRight),
            scaleFor(edgeLength: size.width, cornerRadii.bottomLeft, cornerRadii.bottomRight),
            scaleFor(edgeLength: size.height, cornerRadii.topLeft, cornerRadii.bottomLeft),
            scaleFor(edgeLength: size.height, cornerRadii.topRight, cornerRadii.bottomRight)
        )

        if scale < 1.0 {
            cornerRadii = CornerRadii(
                topLeft: cornerRadii.topLeft * scale,
                topRight: cornerRadii.topRight * scale,
                bottomLeft: cornerRadii.bottomLeft * scale,
                bottomRight: cornerRadii.bottomRight * scale
            )
        }

        return cornerRadii
    }

    static func generateRoundedRectPath(rect: CGRect, cornerRadii: CornerRadii) -> CGPath {
        let cornerRadii = self.clampedCornerRadii(size: rect.size, cornerRadii: cornerRadii)
        let path = CGMutablePath()

        func addCorner(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {
            if radius > CGFloat.ulpOfOne {
                path.addArc(tangent1End: tangent1End, tangent2End: tangent2End, radius: radius)
            } else {
                path.addLine(to: tangent1End)
                path.addLine(to: tangent2End)
            }
        }

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadii.topLeft))
        addCorner(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + cornerRadii.topLeft, y: rect.minY),
            radius: cornerRadii.topLeft
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadii.topRight, y: rect.minY))
        addCorner(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + cornerRadii.topRight),
            radius: cornerRadii.topRight
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadii.bottomRight))
        addCorner(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - cornerRadii.bottomRight, y: rect.maxY),
            radius: cornerRadii.bottomRight
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadii.bottomLeft, y: rect.maxY))
        addCorner(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY - cornerRadii.bottomLeft),
            radius: cornerRadii.bottomLeft
        )
        path.closeSubpath()

        return path
    }

    static func generateRoundedRectPath(size: CGSize, cornerRadii: CornerRadii) -> CGPath {
        return self.generateRoundedRectPath(rect: CGRect(origin: CGPoint(), size: size), cornerRadii: cornerRadii)
    }
    
    private final class ClippingShapeContext {
        let view: UIView
        private var maskLayer: CAShapeLayer?
        
        private(set) var shape: Shape?
        
        init(view: UIView) {
            self.view = view
        }
        
        func update(shape: Shape, size: CGSize, transition: ComponentTransition) {
            self.shape = shape
            
            switch shape {
            case let .roundedRect(cornerRadius):
                self.maskLayer = nil
                self.view.layer.mask = nil
                transition.setCornerRadius(layer: self.view.layer, cornerRadius: cornerRadius)
            case let .customRoundedRect(cornerRadii):
                transition.setCornerRadius(layer: self.view.layer, cornerRadius: 0.0)
                if #available(iOS 26.0, *) {
                    transition.animateView {
                        self.view.cornerConfiguration = .corners(
                            topLeftRadius: .fixed(cornerRadii.topLeft),
                            topRightRadius: .fixed(cornerRadii.topRight),
                            bottomLeftRadius: .fixed(cornerRadii.bottomLeft),
                            bottomRightRadius: .fixed(cornerRadii.bottomRight)
                        )
                    }
                } else {
                    let maskLayer: CAShapeLayer
                    if let current = self.maskLayer {
                        maskLayer = current
                    } else {
                        maskLayer = CAShapeLayer()
                        maskLayer.fillColor = UIColor.black.cgColor
                        self.maskLayer = maskLayer
                        self.view.layer.mask = maskLayer
                    }
                    transition.setFrame(layer: maskLayer, frame: CGRect(origin: CGPoint(), size: size))
                    transition.setShapeLayerPath(layer: maskLayer, path: GlassBackgroundView.generateRoundedRectPath(size: size, cornerRadii: cornerRadii))
                }
            }
        }
    }
    
    public struct Params: Equatable {
        public let shape: Shape
        public let isDark: Bool
        public let tintColor: TintColor
        public let isInteractive: Bool
        public let isVisible: Bool
        
        init(shape: Shape, isDark: Bool, tintColor: TintColor, isInteractive: Bool, isVisible: Bool) {
            self.shape = shape
            self.isDark = isDark
            self.tintColor = tintColor
            self.isInteractive = isInteractive
            self.isVisible = isVisible
        }
    }
    
    private let legacyView: LegacyGlassView?
    private let legacyHighlightContainerView: UIView?
    private let legacyHighlightClippingContext: ClippingShapeContext?
    private var glassHighlightRecognizer: GlassHighlightGestureRecognizer?
    
    private let nativeView: UIVisualEffectView?
    private let nativeViewClippingContext: ClippingShapeContext?
    private let nativeParamsView: EffectSettingsContainerView?
    
    private let foregroundView: UIImageView?
    private let shadowView: UIImageView?
    
    private let maskContainerView: UIView
    public let maskContentView: UIView
    private let contentContainer: ContentContainer
    
    private var innerBackgroundView: UIView?
    
    /// UIKit's liquid morph must target the effect view itself so the backdrop
    /// participates in the shape transition along with its content.
    public var transitionView: UIView {
        return self.nativeView ?? self
    }

    public var contentView: UIView {
        if let nativeView = self.nativeView {
            return nativeView.contentView
        } else {
            return self.contentContainer
        }
    }
    
    public private(set) var params: Params?
        
    public static var useCustomGlassImpl: Bool = false
    
    public override init(frame: CGRect) {
        if #available(iOS 26.0, *), !GlassBackgroundView.useCustomGlassImpl {
            self.legacyView = nil
            self.legacyHighlightContainerView = nil
            self.legacyHighlightClippingContext = nil
            
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = false
            let nativeView = UIVisualEffectView(effect: glassEffect)
            self.nativeViewClippingContext = ClippingShapeContext(view: nativeView)
            self.nativeView = nativeView
            
            let nativeParamsView = EffectSettingsContainerView(frame: CGRect())
            self.nativeParamsView = nativeParamsView
            
            nativeParamsView.addSubview(nativeView)
            
            self.foregroundView = nil
            self.shadowView = nil
        } else {
            self.legacyView = LegacyGlassView(frame: CGRect())
            let legacyHighlightContainerView = UIView()
            legacyHighlightContainerView.isUserInteractionEnabled = false
            legacyHighlightContainerView.clipsToBounds = true
            self.legacyHighlightContainerView = legacyHighlightContainerView
            self.legacyHighlightClippingContext = ClippingShapeContext(view: legacyHighlightContainerView)
            self.nativeView = nil
            self.nativeViewClippingContext = nil
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
        if let legacyView = self.legacyView {
            self.addSubview(legacyView)
            let glassHighlightRecognizer = GlassHighlightGestureRecognizer(target: self, action: #selector(self.onHighlightGesture(_:)))
            glassHighlightRecognizer.highlightContainerView = self.legacyHighlightContainerView
            self.glassHighlightRecognizer = glassHighlightRecognizer
            self.addGestureRecognizer(glassHighlightRecognizer)
            glassHighlightRecognizer.isEnabled = false
        }
        if let foregroundView = self.foregroundView {
            self.addSubview(foregroundView)
            foregroundView.mask = self.maskContainerView
        }
        self.addSubview(self.contentContainer)
        if let legacyHighlightContainerView = self.legacyHighlightContainerView {
            self.addSubview(legacyHighlightContainerView)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func onHighlightGesture(_ recognizer: GlassHighlightGestureRecognizer) {
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isUserInteractionEnabled {
            return nil
        }
        if self.isHidden {
            return nil
        }
        if self.alpha == 0.0 {
            return nil
        }
        if let nativeView = self.nativeView {
            if let result = nativeView.hitTest(self.convert(point, to: nativeView), with: event) {
                return result
            }
        } else {
            if let result = self.contentContainer.hitTest(self.convert(point, to: self.contentContainer), with: event) {
                return result
            }
        }
        return nil
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        let shape: Shape = .roundedRect(cornerRadius: cornerRadius)
        self.update(size: size, shape: shape, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible, transition: transition)
    }

    public func update(size: CGSize, cornerRadii: CornerRadii, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        let shape: Shape = .customRoundedRect(cornerRadii: cornerRadii)
        self.update(size: size, shape: shape, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible, transition: transition)
    }

    func update(size: CGSize, shape: Shape, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        
        if let glassHighlightRecognizer = self.glassHighlightRecognizer {
            glassHighlightRecognizer.isEnabled = isInteractive
        }
        
        if let nativeView = self.nativeView, let nativeViewClippingContext = self.nativeViewClippingContext, (nativeView.bounds.size != size || nativeViewClippingContext.shape != shape || (nativeView.overrideUserInterfaceStyle == .dark) != isDark) {
            nativeViewClippingContext.update(shape: shape, size: size, transition: transition)
            if transition.animation.isImmediate {
                nativeView.frame = CGRect(origin: CGPoint(), size: size)
            } else {
                let nativeFrame = CGRect(origin: CGPoint(), size: size)
                transition.animateView {
                    nativeView.frame = nativeFrame
                }
            }
            nativeView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        if let legacyView = self.legacyView {
            let style: LegacyGlassView.Style
            switch tintColor.kind {
            case .panel:
                style = .normal
            case .clear:
                style = .clear
            case let .custom(styleValue, _):
                switch styleValue {
                case .clear:
                    style = .clear
                case .default:
                    style = .normal
                }
            }
            legacyView.update(size: size, shape: shape, style: style, transition: transition)
            transition.setFrame(view: legacyView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setAlpha(view: legacyView, alpha: isVisible ? 1.0 : 0.0)
            
            transition.setPosition(view: self.contentView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
            transition.setBounds(view: self.contentView, bounds: CGRect(origin: CGPoint(), size: size))
        }
        if let legacyHighlightContainerView = self.legacyHighlightContainerView {
            transition.setFrame(view: legacyHighlightContainerView, frame: CGRect(origin: CGPoint(), size: size))
            self.legacyHighlightClippingContext?.update(shape: shape, size: size, transition: transition)
        }
        
        let shadowInset: CGFloat = 32.0
        
        if let innerColor = tintColor.innerColor {
            let innerBackgroundFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: tintColor.innerInset, dy: tintColor.innerInset)
            let innerBackgroundRadius = min(innerBackgroundFrame.width, innerBackgroundFrame.height) * 0.5
            
            let innerBackgroundView: UIView
            var innerBackgroundTransition = transition
            var animateIn = false
            if let current = self.innerBackgroundView {
                innerBackgroundView = current
            } else {
                innerBackgroundView = UIView()
                innerBackgroundTransition = innerBackgroundTransition.withAnimation(.none)
                self.innerBackgroundView = innerBackgroundView
                self.contentView.insertSubview(innerBackgroundView, at: 0)
                
                innerBackgroundView.frame = innerBackgroundFrame
                innerBackgroundView.layer.cornerRadius = innerBackgroundRadius
                animateIn = true
            }
            
            innerBackgroundView.backgroundColor = innerColor
            innerBackgroundTransition.setFrame(view: innerBackgroundView, frame: innerBackgroundFrame)
            innerBackgroundTransition.setCornerRadius(layer: innerBackgroundView.layer, cornerRadius: innerBackgroundRadius)
            
            if animateIn {
                transition.animateAlpha(view: innerBackgroundView, from: 0.0, to: 1.0)
                transition.animateScale(view: innerBackgroundView, from: 0.001, to: 1.0)
            }
        } else if let innerBackgroundView = self.innerBackgroundView {
            self.innerBackgroundView = nil
            
            transition.setAlpha(view: innerBackgroundView, alpha: 0.0, completion: { [weak innerBackgroundView] _ in
                innerBackgroundView?.removeFromSuperview()
            })
            transition.setScale(view: innerBackgroundView, scale: 0.001)
            
            innerBackgroundView.removeFromSuperview()
        }
        
        let params = Params(shape: shape, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible)
        if self.params != params {
            self.params = params
            
            if let shadowView = self.shadowView {
                switch shape {
                case let .roundedRect(cornerRadius):
                    shadowView.image = Self.generateLegacyShadowImage(cornerRadius: cornerRadius, shadowInset: shadowInset)
                case let .customRoundedRect(cornerRadii):
                    shadowView.image = Self.generateLegacyShadowImage(cornerRadii: GlassBackgroundView.clampedCornerRadii(size: size, cornerRadii: cornerRadii), shadowInset: shadowInset)
                }
                transition.setAlpha(view: shadowView, alpha: isVisible ? 1.0 : 0.0)
            }
            
            if let foregroundView = self.foregroundView {
                let fillColor: UIColor
                let borderWidthFactor: CGFloat
                switch tintColor.kind {
                case .panel:
                    borderWidthFactor = 1.0
                    if isDark {
                        fillColor = UIColor(white: 1.0, alpha: 1.0).mixedWith(.black, alpha: 1.0 - 0.11).withAlphaComponent(0.85)
                    } else {
                        fillColor = UIColor(white: 1.0, alpha: 0.7)
                    }
                case .clear:
                    borderWidthFactor = 2.0
                    fillColor = UIColor(white: 1.0, alpha: 0.0)
                case let .custom(style, color):
                    fillColor = color
                    switch style {
                    case .clear:
                        borderWidthFactor = 2.0
                    case .default:
                        borderWidthFactor = 1.0
                    }
                }
                switch shape {
                case let .roundedRect(cornerRadius):
                    foregroundView.image = GlassBackgroundView.generateLegacyGlassImage(size: CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0), inset: shadowInset, borderWidthFactor: borderWidthFactor, isDark: isDark, fillColor: fillColor)
                case let .customRoundedRect(cornerRadii):
                    foregroundView.image = GlassBackgroundView.generateLegacyGlassImage(cornerRadii: GlassBackgroundView.clampedCornerRadii(size: size, cornerRadii: cornerRadii), inset: shadowInset, borderWidthFactor: borderWidthFactor, isDark: isDark, fillColor: fillColor)
                }
                #if DEBUG
                //foregroundView.image = nil
                #endif
                transition.setAlpha(view: foregroundView, alpha: isVisible ? 1.0 : 0.0)
            } else {
                if let nativeParamsView = self.nativeParamsView, let nativeView = self.nativeView {
                    if #available(iOS 26.0, *) {
                        var glassEffect: UIGlassEffect?
                        
                        if isVisible {
                            let glassEffectValue: UIGlassEffect
                            switch tintColor.kind {
                            case .panel:
                                if isDark {
                                    glassEffectValue = UIGlassEffect(style: .regular)
                                    glassEffectValue.tintColor = UIColor(white: 1.0, alpha: 0.025)
                                } else {
                                    glassEffectValue = UIGlassEffect(style: .regular)
                                    glassEffectValue.tintColor = UIColor(white: 1.0, alpha: 0.1)
                                }
                            case let .custom(style, color):
                                switch style {
                                case .default:
                                    glassEffectValue = UIGlassEffect(style: .regular)
                                    glassEffectValue.tintColor = color
                                case .clear:
                                    glassEffectValue = UIGlassEffect(style: .clear)
                                    glassEffectValue.tintColor = color
                                }
                            case .clear:
                                glassEffectValue = UIGlassEffect(style: .clear)
                                if isDark {
                                    glassEffectValue.tintColor = UIColor(white: 0.0, alpha: 0.28)
                                } else {
                                    glassEffectValue.tintColor = nil
                                }
                            }
                            glassEffectValue.isInteractive = isInteractive
                            glassEffect = glassEffectValue
                        }
                        
                        if glassEffect == nil {
                            if nativeView.effect is UIGlassEffect {
                                if #available(iOS 26.1, *) {
                                    if transition.animation.isImmediate {
                                        nativeView.effect = nil
                                    } else {
                                        transition.animateView {
                                            nativeView.effect = nil
                                        }
                                    }
                                } else {
                                    if transition.animation.isImmediate {
                                        nativeView.effect = UIVisualEffect()
                                    } else {
                                        transition.animateView {
                                            nativeView.effect = UIVisualEffect()
                                        }
                                    }
                                }
                            }
                        } else {
                            if transition.animation.isImmediate {
                                nativeView.effect = glassEffect
                            } else {
                                if let glassEffect, let currentEffect = nativeView.effect as? UIGlassEffect, currentEffect.tintColor == glassEffect.tintColor, currentEffect.isInteractive == glassEffect.isInteractive {
                                } else {
                                    transition.animateView {
                                        nativeView.effect = glassEffect
                                    }
                                }
                            }
                        }
                        
                        if isDark {
                            nativeParamsView.lumaMin = 0.0
                            nativeParamsView.lumaMax = 0.15
                        } else {
                            nativeParamsView.lumaMin = 0.8
                            nativeParamsView.lumaMax = 0.801
                        }
                    }
                }
            }
        }
        
        if let nativeParamsView = self.nativeParamsView {
            transition.setFrame(view: nativeParamsView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
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
    
    override public func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
    }
}

public final class GlassBackgroundContainerView: UIView {
    private final class ContentView: UIView {
    }
    
    private let legacyView: ContentView?
    private let nativeParamsView: EffectSettingsContainerView?
    private let nativeView: UIVisualEffectView?
    
    public var contentView: UIView {
        if let nativeView = self.nativeView {
            return nativeView.contentView
        } else {
            return self.legacyView!
        }
    }
    
    public init(spacing: CGFloat = 7.0) {
        if #available(iOS 26.0, *), !GlassBackgroundView.useCustomGlassImpl {
            let effect = UIGlassContainerEffect()
            effect.spacing = spacing
            let nativeView = UIVisualEffectView(effect: effect)
            self.nativeView = nativeView
            
            let nativeParamsView = EffectSettingsContainerView(frame: CGRect())
            self.nativeParamsView = nativeParamsView
            nativeParamsView.addSubview(nativeView)
            
            self.legacyView = nil
        } else {
            self.nativeView = nil
            self.nativeParamsView = nil
            self.legacyView = ContentView()
        }
        
        super.init(frame: CGRect())
        
        if let nativeParamsView = self.nativeParamsView {
            self.addSubview(nativeParamsView)
        } else if let legacyView = self.legacyView {
            self.addSubview(legacyView)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if subview !== self.nativeParamsView && subview !== self.legacyView {
            assertionFailure()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero {
            return nil
        }
        if self.isHidden {
            return nil
        }
        if !self.isUserInteractionEnabled {
            return nil
        }
        for view in self.contentView.subviews.reversed() {
            if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                
                #if DEBUG
                func findMatrix(layer: CALayer) -> AnyObject? {
                    for filter in layer.filters ?? [] {
                        if "\(filter)".contains("vibrantColorMatrix") {
                            return filter as AnyObject
                        }
                    }
                    
                    for sublayer in layer.sublayers ?? [] {
                        if let result = findMatrix(layer: sublayer) {
                            return result
                        }
                    }
                    return nil
                }
                
                /*if let filter = findMatrix(layer: self.layer) as? NSObject {
                    var matrix: [Float32] = .init(repeating: 0, count: 20)
                    let matrixValues = filter.value(forKey: "inputColorMatrix") as! NSValue
                    matrixValues.getValue(&matrix, size: 4 * 20)
                    assert(true)
                }*/
                #endif
                
                return result
            }
        }
        
        guard let result = self.contentView.hitTest(point, with: event) else {
            return nil
        }
        
        if result === self.contentView {
            return nil
        }
        
        return result
    }
    
    public func update(size: CGSize, isDark: Bool, transition: ComponentTransition) {
        if let nativeParamsView = self.nativeParamsView, let nativeView = self.nativeView {
            nativeView.overrideUserInterfaceStyle = isDark ? .dark : .light
            
            if isDark {
                nativeParamsView.lumaMin = 0.0
                nativeParamsView.lumaMax = 0.15
            } else {
                nativeParamsView.lumaMin = 0.8
                nativeParamsView.lumaMax = 0.801
            }
            if let nativeParamsView = self.nativeParamsView {
                transition.setFrame(view: nativeParamsView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            }
            
            transition.animateView {
                nativeView.frame = CGRect(origin: CGPoint(), size: size)
            }
        } else if let legacyView = self.legacyView {
            transition.setFrame(view: legacyView, frame: CGRect(origin: CGPoint(), size: size))
        }
    }
    
    override public func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
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

private struct LegacyResizableImageMetrics {
    let imageSize: CGSize
    let innerRect: CGRect
    let leftCapWidth: Int
    let topCapHeight: Int
}

private func legacyResizableImageMetrics(cornerRadii: GlassBackgroundView.CornerRadii, inset: CGFloat) -> LegacyResizableImageMetrics {
    let leftRadius = ceil(max(cornerRadii.topLeft, cornerRadii.bottomLeft))
    let rightRadius = ceil(max(cornerRadii.topRight, cornerRadii.bottomRight))
    let topRadius = ceil(max(cornerRadii.topLeft, cornerRadii.topRight))
    let bottomRadius = ceil(max(cornerRadii.bottomLeft, cornerRadii.bottomRight))

    let innerSize = CGSize(
        width: max(1.0, leftRadius + rightRadius + 1.0),
        height: max(1.0, topRadius + bottomRadius + 1.0)
    )
    let imageSize = CGSize(width: innerSize.width + inset * 2.0, height: innerSize.height + inset * 2.0)

    return LegacyResizableImageMetrics(
        imageSize: imageSize,
        innerRect: CGRect(origin: CGPoint(x: inset, y: inset), size: innerSize),
        leftCapWidth: Int(ceil(inset + leftRadius)),
        topCapHeight: Int(ceil(inset + topRadius))
    )
}

public extension GlassBackgroundView {
    static func generateLegacyShadowImage(cornerRadius: CGFloat, shadowInset: CGFloat = 32.0, shadowIntensity: CGFloat = 0.04, shadowBlur: CGFloat = 40.0) -> UIImage? {
        let shadowInnerInset: CGFloat = 0.5
        let diameter = max(1.0, cornerRadius * 2.0)
        let size = CGSize(width: shadowInset * 2.0 + diameter, height: shadowInset * 2.0 + diameter)
        
        return generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let shadowRect = CGRect(
                origin: CGPoint(x: shadowInset + shadowInnerInset, y: shadowInset + shadowInnerInset),
                size: CGSize(
                    width: size.width - shadowInset * 2.0 - shadowInnerInset * 2.0,
                    height: size.height - shadowInset * 2.0 - shadowInnerInset * 2.0
                )
            )
            
            context.setFillColor(UIColor.black.cgColor)
            context.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: shadowBlur, color: UIColor(white: 0.0, alpha: shadowIntensity).cgColor)
            context.fillEllipse(in: shadowRect)
            
            context.setFillColor(UIColor.clear.cgColor)
            context.setBlendMode(.copy)
            context.fillEllipse(in: shadowRect)
        })?.stretchableImage(
            withLeftCapWidth: Int(shadowInset + cornerRadius),
            topCapHeight: Int(shadowInset + cornerRadius)
        )
    }

    static func generateLegacyShadowImage(cornerRadii: CornerRadii, shadowInset: CGFloat = 32.0, shadowIntensity: CGFloat = 0.04, shadowBlur: CGFloat = 40.0) -> UIImage? {
        let shadowInnerInset: CGFloat = 0.5
        let metrics = legacyResizableImageMetrics(cornerRadii: cornerRadii, inset: shadowInset)

        return generateImage(metrics.imageSize, rotatedContext: { _, context in
            context.clear(CGRect(origin: CGPoint(), size: metrics.imageSize))

            let shadowRect = metrics.innerRect.insetBy(dx: shadowInnerInset, dy: shadowInnerInset)
            let shadowPath = GlassBackgroundView.generateRoundedRectPath(rect: shadowRect, cornerRadii: cornerRadii)

            context.setFillColor(UIColor.black.cgColor)
            context.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: shadowBlur, color: UIColor(white: 0.0, alpha: shadowIntensity).cgColor)
            context.addPath(shadowPath)
            context.fillPath()

            context.setFillColor(UIColor.clear.cgColor)
            context.setBlendMode(.copy)
            context.addPath(shadowPath)
            context.fillPath()
        })?.stretchableImage(
            withLeftCapWidth: metrics.leftCapWidth,
            topCapHeight: metrics.topCapHeight
        )
    }
    
    static func generateLegacyGlassImage(size: CGSize, inset: CGFloat, borderWidthFactor: CGFloat = 1.0, isDark: Bool, fillColor: UIColor) -> UIImage {
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
            
            addShadow(context, true, CGPoint(), 30.0, 0.0, UIColor(white: 0.0, alpha: 0.045), .normal)
            addShadow(context, true, CGPoint(), 20.0, 0.0, UIColor(white: 0.0, alpha: 0.01), .normal)
            
            var a: CGFloat = 0.0
            var b: CGFloat = 0.0
            var s: CGFloat = 0.0
            fillColor.getHue(nil, saturation: &s, brightness: &b, alpha: &a)
            
            let innerImage: UIImage
            /*if size == CGSize(width: 40.0 + inset * 2.0, height: 40.0 + inset * 2.0), b >= 0.2 {
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
            }*/
            
            innerImage = UIGraphicsImageRenderer(size: size).image { ctx in
                let context = ctx.cgContext
                
                context.setFillColor(fillColor.cgColor)
                var ellipseRect = CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset)
                context.fillEllipse(in: ellipseRect)
                
                let lineWidth: CGFloat = (isDark ? 0.8 : 0.8) * borderWidthFactor
                let strokeColor: UIColor
                let blendMode: CGBlendMode
                let baseAlpha: CGFloat = isDark ? 0.3 : 0.6
                
                if s == 0.0 && abs(a - 0.7) < 0.1 && !isDark {
                    blendMode = .normal
                    strokeColor = UIColor(white: 1.0, alpha: baseAlpha)
                } else if s <= 0.3 && !isDark {
                    blendMode = .normal
                    strokeColor = UIColor(white: 1.0, alpha: 0.7 * baseAlpha)
                } else if b >= 0.2 {
                    let maxAlpha: CGFloat = isDark ? 0.7 : 0.8
                    blendMode = .overlay
                    strokeColor = UIColor(white: 1.0, alpha: max(0.5, min(1.0, maxAlpha * s)) * baseAlpha)
                } else {
                    blendMode = .normal
                    strokeColor = UIColor(white: 1.0, alpha: 0.5 * baseAlpha)
                }
                
                context.setStrokeColor(strokeColor.cgColor)
                ellipseRect = CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset)
                context.addEllipse(in: ellipseRect)
                context.clip()
                
                ellipseRect = CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5)
                
                context.setBlendMode(blendMode)
                
                let radius = ellipseRect.height * 0.5
                let smallerRadius = radius - lineWidth * 1.33
                context.move(to: CGPoint(x: ellipseRect.minX, y: ellipseRect.minY + radius))
                // Top-left corner (regular radius)
                context.addArc(tangent1End: CGPoint(x: ellipseRect.minX, y: ellipseRect.minY), tangent2End: CGPoint(x: ellipseRect.minX + radius, y: ellipseRect.minY), radius: radius)
                context.addLine(to: CGPoint(x: ellipseRect.maxX - smallerRadius, y: ellipseRect.minY))
                // Top-right corner (smaller radius)
                context.addArc(tangent1End: CGPoint(x: ellipseRect.maxX, y: ellipseRect.minY), tangent2End: CGPoint(x: ellipseRect.maxX, y: ellipseRect.minY + smallerRadius), radius: smallerRadius)
                context.addLine(to: CGPoint(x: ellipseRect.maxX, y: ellipseRect.maxY - radius))
                // Bottom-right corner (regular radius)
                context.addArc(tangent1End: CGPoint(x: ellipseRect.maxX, y: ellipseRect.maxY), tangent2End: CGPoint(x: ellipseRect.maxX - radius, y: ellipseRect.maxY), radius: radius)
                context.addLine(to: CGPoint(x: ellipseRect.minX + smallerRadius, y: ellipseRect.maxY))
                // Bottom-left corner (smaller radius)
                context.addArc(tangent1End: CGPoint(x: ellipseRect.minX, y: ellipseRect.maxY), tangent2End: CGPoint(x: ellipseRect.minX, y: ellipseRect.maxY - smallerRadius), radius: smallerRadius)
                context.closePath()
                context.strokePath()
                
                context.resetClip()
                context.setBlendMode(.normal)
            }
            innerImage.draw(in: CGRect(origin: CGPoint(), size: size))
        }.stretchableImage(withLeftCapWidth: Int(size.width * 0.5), topCapHeight: Int(size.height * 0.5))
    }
    
    static func generateLegacyGlassImage(cornerRadii: CornerRadii, inset: CGFloat, borderWidthFactor: CGFloat = 1.0, isDark: Bool, fillColor: UIColor) -> UIImage {
        let metrics = legacyResizableImageMetrics(cornerRadii: cornerRadii, inset: inset)
        let size = metrics.imageSize
        let innerRect = metrics.innerRect

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

                    let spreadRect = innerRect.insetBy(dx: 0.25, dy: 0.25)
                    let spreadPath = GlassBackgroundView.generateRoundedRectPath(rect: spreadRect, cornerRadii: cornerRadii)

                    context.setShadow(offset: CGSize(width: position.x, height: position.y), blur: blur, color: shadowColor.cgColor)
                    context.setFillColor(UIColor.black.withAlphaComponent(1.0).cgColor)
                    context.addPath(spreadPath)
                    context.fillPath()

                    let cleanPath = GlassBackgroundView.generateRoundedRectPath(rect: innerRect, cornerRadii: cornerRadii)
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    context.addPath(cleanPath)
                    context.fillPath()
                    context.setBlendMode(.normal)
                } else {
                    let image = UIGraphicsImageRenderer(size: size).image(actions: { ctx in
                        let context = ctx.cgContext
                        let spreadRect = innerRect.insetBy(dx: -spread - 0.33, dy: -spread - 0.33)

                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setShadow(offset: CGSize(width: position.x, height: position.y), blur: blur, color: shadowColor.cgColor)
                        context.setFillColor(shadowColor.cgColor)
                        context.addPath(UIBezierPath(rect: spreadRect.insetBy(dx: -10000.0, dy: -10000.0)).cgPath)
                        context.addPath(GlassBackgroundView.generateRoundedRectPath(rect: spreadRect, cornerRadii: cornerRadii))
                        context.fillPath(using: .evenOdd)
                    })

                    UIGraphicsPushContext(context)
                    image.draw(in: CGRect(origin: .zero, size: size), blendMode: blendMode, alpha: 1.0)
                    UIGraphicsPopContext()
                }
            }

            addShadow(context, true, CGPoint(), 30.0, 0.0, UIColor(white: 0.0, alpha: 0.045), .normal)
            addShadow(context, true, CGPoint(), 20.0, 0.0, UIColor(white: 0.0, alpha: 0.01), .normal)

            var a: CGFloat = 0.0
            var b: CGFloat = 0.0
            var s: CGFloat = 0.0
            fillColor.getHue(nil, saturation: &s, brightness: &b, alpha: &a)

            context.setFillColor(fillColor.cgColor)
            context.addPath(GlassBackgroundView.generateRoundedRectPath(rect: innerRect, cornerRadii: cornerRadii))
            context.fillPath()

            let lineWidth: CGFloat = (isDark ? 0.8 : 0.8) * borderWidthFactor
            let strokeColor: UIColor
            let blendMode: CGBlendMode
            let baseAlpha: CGFloat = isDark ? 0.3 : 0.6

            if s == 0.0 && abs(a - 0.7) < 0.1 && !isDark {
                blendMode = .normal
                strokeColor = UIColor(white: 1.0, alpha: baseAlpha)
            } else if s <= 0.3 && !isDark {
                blendMode = .normal
                strokeColor = UIColor(white: 1.0, alpha: 0.7 * baseAlpha)
            } else if b >= 0.2 {
                let maxAlpha: CGFloat = isDark ? 0.7 : 0.8
                blendMode = .overlay
                strokeColor = UIColor(white: 1.0, alpha: max(0.5, min(1.0, maxAlpha * s)) * baseAlpha)
            } else {
                blendMode = .normal
                strokeColor = UIColor(white: 1.0, alpha: 0.5 * baseAlpha)
            }

            context.addPath(GlassBackgroundView.generateRoundedRectPath(rect: innerRect, cornerRadii: cornerRadii))
            context.clip()
            context.setBlendMode(blendMode)
            context.setLineWidth(lineWidth)
            context.setStrokeColor(strokeColor.cgColor)
            context.addPath(GlassBackgroundView.generateRoundedRectPath(rect: innerRect.insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), cornerRadii: cornerRadii.insetBy(lineWidth * 0.5)))
            context.strokePath()
            context.resetClip()
            context.setBlendMode(.normal)
        }.stretchableImage(withLeftCapWidth: metrics.leftCapWidth, topCapHeight: metrics.topCapHeight)
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
    private let shape: GlassBackgroundView.Shape
    private let isDark: Bool
    private let tintColor: GlassBackgroundView.TintColor
    private let isInteractive: Bool
    private let isVisible: Bool
    
    public init(
        size: CGSize,
        cornerRadius: CGFloat,
        isDark: Bool,
        tintColor: GlassBackgroundView.TintColor,
        isInteractive: Bool = false,
        isVisible: Bool = true
    ) {
        self.size = size
        self.shape = .roundedRect(cornerRadius: cornerRadius)
        self.isDark = isDark
        self.tintColor = tintColor
        self.isInteractive = isInteractive
        self.isVisible = isVisible
    }

    public init(
        size: CGSize,
        cornerRadii: GlassBackgroundView.CornerRadii,
        isDark: Bool,
        tintColor: GlassBackgroundView.TintColor,
        isInteractive: Bool = false,
        isVisible: Bool = true
    ) {
        self.size = size
        self.shape = .customRoundedRect(cornerRadii: cornerRadii)
        self.isDark = isDark
        self.tintColor = tintColor
        self.isInteractive = isInteractive
        self.isVisible = isVisible
    }
    
    public static func == (lhs: GlassBackgroundComponent, rhs: GlassBackgroundComponent) -> Bool {
        if lhs.size != rhs.size {
            return false
        }
        if lhs.shape != rhs.shape {
            return false
        }
        if lhs.isDark != rhs.isDark {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.isInteractive != rhs.isInteractive {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        return true
    }
    
    public final class View: GlassBackgroundView {
        func update(component: GlassBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.update(size: component.size, shape: component.shape, isDark: component.isDark, tintColor: component.tintColor, isInteractive: component.isInteractive, isVisible: component.isVisible, transition: transition)
            
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

public final class GlassContextExtractableContainer: UIView, ContextExtractableContainer {
    /// Target the native effect itself so UIKit includes the source backdrop in a morph.
    public var transitionView: UIView {
        return self.glassView.transitionView
    }

    private struct NormalParams {
        let size: CGSize
        let cornerRadius: CGFloat
        let isDark: Bool
        let tintColor: GlassBackgroundView.TintColor
        let isInteractive: Bool
        let isVisible: Bool
        
        init(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: GlassBackgroundView.TintColor, isInteractive: Bool, isVisible: Bool) {
            self.size = size
            self.cornerRadius = cornerRadius
            self.isDark = isDark
            self.tintColor = tintColor
            self.isInteractive = isInteractive
            self.isVisible = isVisible
        }
    }
    
    public let extractableContentView: UIView
    public let normalContentView: UIView
    
    public var contentView: UIView {
        return self.normalContentView
    }
    
    public var normalState: NormalState {
        guard let normalParams = self.normalParams else {
            return NormalState(
                size: CGSize(),
                cornerRadius: 0.0
            )
        }
        return NormalState(
            size: normalParams.size,
            cornerRadius: normalParams.cornerRadius
        )
    }
    
    private let glassView: GlassBackgroundView
    
    private var state: State = .normal
    private var normalParams: NormalParams?
    
    override public init(frame: CGRect) {
        self.extractableContentView = UIView()
        self.glassView = GlassBackgroundView()
        self.normalContentView = SparseContainerView()
        
        super.init(frame: frame)
        
        self.glassView.contentView.addSubview(self.normalContentView)
        self.extractableContentView.addSubview(self.glassView)
        self.addSubview(self.extractableContentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isUserInteractionEnabled {
            return nil
        }
        if self.isHidden {
            return nil
        }
        if self.alpha == 0.0 {
            return nil
        }
        switch self.state {
        case .normal:
            if let result = self.normalContentView.hitTest(self.convert(point, to: self.normalContentView), with: event) {
                return result
            }
        case .extracted:
            break
        }
        
        return nil
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: GlassBackgroundView.TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        let normalParams = NormalParams(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible)
        self.normalParams = normalParams
        
        if case .normal = self.state {
            self.applyState(previousState: self.state, transition: .transition(transition.containedViewLayoutTransition), completion: nil)
        }
    }
    
    public func updateState(state: State, transition: Transition, completion: ((Bool) -> Void)?) {
        let previousState = self.state
        self.state = state
        self.applyState(previousState: previousState, transition: transition, completion: completion)
    }
    
    private func applyState(previousState: State?, transition: Transition, completion: ((Bool) -> Void)?) {
        guard let normalParams = self.normalParams else {
            completion?(true)
            return
        }
        
        let mappedTransition: ComponentTransition
        switch transition {
        case let .transition(transition):
            mappedTransition = ComponentTransition(transition)
        case let .spring(duration, stiffness, damping):
            mappedTransition = ComponentTransition(animation: .curve(duration: duration, curve: .bounce(stiffness: stiffness, damping: damping)))
        }
        
        switch self.state {
        case .normal:
            mappedTransition.setAlpha(view: self.normalContentView, alpha: 1.0)
            mappedTransition.setFrame(view: self.extractableContentView, frame: CGRect(origin: CGPoint(), size: normalParams.size))
            mappedTransition.setFrame(view: self.normalContentView, frame: CGRect(origin: CGPoint(), size: normalParams.size), completion: { completed in
                completion?(completed)
            })
            
            self.glassView.update(
                size: normalParams.size,
                cornerRadius: normalParams.cornerRadius,
                isDark: normalParams.isDark,
                tintColor: normalParams.tintColor,
                isInteractive: normalParams.isInteractive,
                isVisible: normalParams.isVisible,
                transition: mappedTransition,
            )
        case let .extracted(size, cornerRadius, extractionState):
            switch extractionState {
            case .animatedOut:
                mappedTransition.setAlpha(view: self.normalContentView, alpha: 1.0, completion: { completed in
                    completion?(completed)
                })
                
                self.glassView.update(
                    size: normalParams.size,
                    cornerRadius: normalParams.cornerRadius,
                    isDark: normalParams.isDark,
                    tintColor: normalParams.tintColor,
                    isInteractive: normalParams.isInteractive,
                    isVisible: normalParams.isVisible,
                    transition: mappedTransition
                )
            case .animatedIn:
                mappedTransition.setAlpha(view: self.normalContentView, alpha: 0.0, completion: { completed in
                    completion?(completed)
                })
                
                if case let .curve(duration, curve) = mappedTransition.animation, case .spring = curve, let previousState, case let .extracted(_, previousCornerRadius, previousExtractedState) = previousState, case .animatedOut = previousExtractedState {
                    self.glassView.update(
                        size: size,
                        cornerRadius: previousCornerRadius,
                        isDark: normalParams.isDark,
                        tintColor: normalParams.tintColor,
                        isInteractive: normalParams.isInteractive,
                        isVisible: normalParams.isVisible,
                        transition: mappedTransition
                    )
                    let firstPartDuration: Double = 0.35
                    self.glassView.update(
                        size: size,
                        cornerRadius: min(size.width, size.height) * 0.5,
                        isDark: normalParams.isDark,
                        tintColor: normalParams.tintColor,
                        isInteractive: normalParams.isInteractive,
                        isVisible: normalParams.isVisible,
                        transition: .easeInOut(duration: duration * firstPartDuration)
                    )
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + UIView.animationDurationFactor() * duration * firstPartDuration, execute: { [weak self] in
                        guard let self, let normalParams = self.normalParams else {
                            return
                        }
                        guard case let .extracted(newSize, newCornerRadius, newExtractionState) = self.state, newSize == size, newCornerRadius == cornerRadius, newExtractionState == extractionState else {
                            return
                        }
                        self.glassView.update(
                            size: size,
                            cornerRadius: cornerRadius,
                            isDark: normalParams.isDark,
                            tintColor: normalParams.tintColor,
                            isInteractive: normalParams.isInteractive,
                            isVisible: normalParams.isVisible,
                            transition: .spring(duration: duration * (1.0 - firstPartDuration))
                        )
                    })
                } else {
                    self.glassView.update(
                        size: size,
                        cornerRadius: cornerRadius,
                        isDark: normalParams.isDark,
                        tintColor: normalParams.tintColor,
                        isInteractive: normalParams.isInteractive,
                        isVisible: normalParams.isVisible,
                        transition: mappedTransition
                    )
                }
            }
        }
    }
}
