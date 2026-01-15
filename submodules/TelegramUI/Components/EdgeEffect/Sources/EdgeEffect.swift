import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

public class EdgeEffectView: UIView {
    public enum Edge {
        case top
        case bottom
    }

    private let contentView: UIView
    private let contentMaskView: UIImageView
    private var blurView: VariableBlurView?
    
    public override init(frame: CGRect) {
        self.contentView = UIView()
        self.contentMaskView = UIImageView()
        self.contentView.mask = self.contentMaskView
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(content: UIColor, blur: Bool = false, alpha: CGFloat = 0.75, rect: CGRect, edge: Edge, edgeSize: CGFloat, transition: ComponentTransition) {
        #if DEBUG && false
        let content: UIColor = .blue
        let blur: Bool = !"".isEmpty
        self.backgroundColor = .blue
        #endif
        
        transition.setBackgroundColor(view: self.contentView, color: content)
        
        switch edge {
        case .top:
            self.contentMaskView.transform = CGAffineTransformMakeScale(1.0, -1.0)
        case .bottom:
            self.contentMaskView.transform = .identity
        }
        
        let bounds = CGRect(origin: CGPoint(), size: rect.size)
        transition.setFrame(view: self.contentView, frame: bounds)
        transition.setFrame(view: self.contentMaskView, frame: bounds)
        
        if self.contentMaskView.image?.size.height != edgeSize {
            let baseGradientAlpha: CGFloat = alpha
            let numSteps = 8
            let firstStep = 1
            let firstLocation = 0.0
            let colors: [UIColor] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return UIColor(white: 1.0, alpha: 1.0)
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    let value: CGFloat = bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                    return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                }
            }
            let locations: [CGFloat] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return 0.0
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    return (firstLocation + (1.0 - firstLocation) * step)
                }
            }
                
            if edgeSize > 0.0 {
                self.contentMaskView.image = generateGradientImage(
                    size: CGSize(width: 8.0, height: edgeSize),
                    colors: colors,
                    locations: locations
                )?.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(edgeSize))
            } else {
                self.contentMaskView.image = nil
            }
        }
        
        if blur {
            let blurView: VariableBlurView
            if let current = self.blurView {
                blurView = current
            } else {
                let gradientMaskLayer = SimpleGradientLayer()
                let baseGradientAlpha: CGFloat = 1.0
                let numSteps = 8
                let firstStep = 1
                let firstLocation = 0.8
                gradientMaskLayer.colors = (0 ..< numSteps).map { i in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0).cgColor
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 1.0, alpha: baseGradientAlpha * value).cgColor
                    }
                }
                gradientMaskLayer.locations = (0 ..< numSteps).map { i -> NSNumber in
                    if i < firstStep {
                        return 0.0 as NSNumber
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step) as NSNumber
                    }
                }
                
                blurView = VariableBlurView(gradientMask: self.contentMaskView.image ?? UIImage(), maxBlurRadius: 8.0)
                blurView.layer.mask = gradientMaskLayer
                self.insertSubview(blurView, at: 0)
                self.blurView = blurView
            }
            blurView.update(size: bounds.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: blurView, frame: bounds)
            if let maskLayer = blurView.layer.mask {
                transition.setFrame(layer: maskLayer, frame: bounds)
                maskLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            }
            blurView.transform = self.contentMaskView.transform
        } else if let blurView = self.blurView {
            self.blurView = nil
            blurView.removeFromSuperview()
        }
    }
}

public final class EdgeEffectComponent: Component {
    private let color: UIColor
    private let blur: Bool
    private let alpha: CGFloat
    private let size: CGSize
    private let edge: EdgeEffectView.Edge
    private let edgeSize: CGFloat
    
    public init(
        color: UIColor,
        blur: Bool,
        alpha: CGFloat,
        size: CGSize,
        edge: EdgeEffectView.Edge,
        edgeSize: CGFloat
    ) {
        self.color = color
        self.blur = blur
        self.alpha = alpha
        self.size = size
        self.edge = edge
        self.edgeSize = edgeSize
    }
    
    public static func == (lhs: EdgeEffectComponent, rhs: EdgeEffectComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.blur != rhs.blur {
            return false
        }
        if lhs.alpha != rhs.alpha {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.edge != rhs.edge {
            return false
        }
        if lhs.edgeSize != rhs.edgeSize {
            return false
        }
        return true
    }
    
    public final class View: EdgeEffectView {
        func update(component: EdgeEffectComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.update(content: component.color, blur: component.blur, alpha: component.alpha, rect: CGRect(origin: .zero, size: component.size), edge: component.edge, edgeSize: component.edgeSize, transition: transition)
            
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
        
        let backdropLayer = self.subviews.first?.layer
        backdropLayer?.filters = [variableBlur]
        backdropLayer?.setValue(UIScreenScale, forKey: "scale")
    }
    
    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        for layer in self.layer.sublayers ?? [] {
            transition.updateFrame(layer: layer, frame: CGRect(origin: CGPoint(), size: size))
        }
    }
}
