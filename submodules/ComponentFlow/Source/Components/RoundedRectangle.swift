import Foundation
import UIKit
import Display

public final class RoundedRectangle: Component {
    public enum GradientDirection: Equatable {
        case horizontal
        case vertical
    }
    
    public let colors: [UIColor]
    public let cornerRadius: CGFloat?
    public let gradientDirection: GradientDirection
    public let stroke: CGFloat?
    public let strokeColor: UIColor?
    
    public convenience init(color: UIColor, cornerRadius: CGFloat?, stroke: CGFloat? = nil, strokeColor: UIColor? = nil) {
        self.init(colors: [color], cornerRadius: cornerRadius, stroke: stroke, strokeColor: strokeColor)
    }
    
    public init(colors: [UIColor], cornerRadius: CGFloat?, gradientDirection: GradientDirection = .horizontal, stroke: CGFloat? = nil, strokeColor: UIColor? = nil) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.gradientDirection = gradientDirection
        self.stroke = stroke
        self.strokeColor = strokeColor
    }

    public static func ==(lhs: RoundedRectangle, rhs: RoundedRectangle) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.gradientDirection != rhs.gradientDirection {
            return false
        }
        if lhs.stroke != rhs.stroke {
            return false
        }
        if lhs.strokeColor != rhs.strokeColor {
            return false
        }
        return true
    }
    
    public final class View: UIImageView {
        var component: RoundedRectangle?
        
        func update(component: RoundedRectangle, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if self.component != component {
                let cornerRadius = component.cornerRadius ?? min(availableSize.width, availableSize.height) * 0.5
                
                if component.colors.count == 1, let color = component.colors.first {
                    let imageSize = CGSize(width: max(component.stroke ?? 0.0, cornerRadius) * 2.0, height: max(component.stroke ?? 0.0, cornerRadius) * 2.0)
                    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                    if let context = UIGraphicsGetCurrentContext() {
                        if let strokeColor = component.strokeColor {
                            context.setFillColor(strokeColor.cgColor)
                        } else {
                            context.setFillColor(color.cgColor)
                        }
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: imageSize))
                        
                        if let stroke = component.stroke, stroke > 0.0 {
                            if let _ = component.strokeColor {
                                context.setFillColor(color.cgColor)
                            } else {
                                context.setBlendMode(.clear)
                            }
                            context.fillEllipse(in: CGRect(origin: CGPoint(), size: imageSize).insetBy(dx: stroke, dy: stroke))
                        }
                    }
                    self.image = UIGraphicsGetImageFromCurrentImageContext()?.stretchableImage(withLeftCapWidth: Int(cornerRadius), topCapHeight: Int(cornerRadius))
                    UIGraphicsEndImageContext()
                } else if component.colors.count > 1 {
                    let imageSize = availableSize
                    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                    if let context = UIGraphicsGetCurrentContext() {
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: imageSize), cornerRadius: cornerRadius).cgPath)
                        context.clip()

                        let colors = component.colors
                        let gradientColors = colors.map { $0.cgColor } as CFArray
                        let colorSpace = CGColorSpaceCreateDeviceRGB()
                        
                        var locations: [CGFloat] = []
                        let delta = 1.0 / CGFloat(colors.count - 1)
                        for i in 0 ..< colors.count {
                            locations.append(delta * CGFloat(i))
                        }
                        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: component.gradientDirection == .horizontal ? CGPoint(x: imageSize.width, y: 0.0) : CGPoint(x: 0.0, y: imageSize.height), options: CGGradientDrawingOptions())
                        
                        if let stroke = component.stroke, stroke > 0.0 {
                            context.resetClip()
                            
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: imageSize).insetBy(dx: stroke, dy: stroke), cornerRadius: cornerRadius).cgPath)
                            context.setBlendMode(.clear)
                            context.fill(CGRect(origin: .zero, size: imageSize))
                        }
                    }
                    self.image = UIGraphicsGetImageFromCurrentImageContext()?.stretchableImage(withLeftCapWidth: Int(cornerRadius), topCapHeight: Int(cornerRadius))
                    UIGraphicsEndImageContext()
                }
            }

            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

public final class FilledRoundedRectangleComponent: Component {
    public let color: UIColor
    public let cornerRadius: CGFloat
    public let smoothCorners: Bool
    
    public init(
        color: UIColor,
        cornerRadius: CGFloat,
        smoothCorners: Bool
    ) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.smoothCorners = smoothCorners
    }
    
    public static func ==(lhs: FilledRoundedRectangleComponent, rhs: FilledRoundedRectangleComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.smoothCorners != rhs.smoothCorners {
            return false
        }
        return true
    }
    
    public final class View: UIImageView {
        private var component: FilledRoundedRectangleComponent?
        
        private var currentCornerRadius: CGFloat?
        private var cornerImage: UIImage?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func applyStaticCornerRadius() {
            guard let component = self.component else {
                return
            }
            guard let cornerRadius = self.currentCornerRadius else {
                return
            }
            if cornerRadius == 0.0 {
                if let cornerImage = self.cornerImage, cornerImage.size.width == 1.0 {
                } else {
                    self.cornerImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                        context.setFillColor(UIColor.white.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5).withRenderingMode(.alwaysTemplate)
                }
            } else {
                if component.smoothCorners {
                    let size = CGSize(width: cornerRadius * 2.0 + 10.0, height: cornerRadius * 2.0 + 10.0)
                    if let cornerImage = self.cornerImage, cornerImage.size == size {
                    } else {
                        self.cornerImage = generateImage(size, rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: cornerRadius).cgPath)
                            context.setFillColor(UIColor.white.cgColor)
                            context.fillPath()
                        })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5).withRenderingMode(.alwaysTemplate)
                    }
                } else {
                    let size = CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0)
                    if let cornerImage = self.cornerImage, cornerImage.size == size {
                    } else {
                        self.cornerImage = generateStretchableFilledCircleImage(diameter: size.width, color: UIColor.white)?.withRenderingMode(.alwaysTemplate)
                    }
                }
            }
            self.image = self.cornerImage
            self.clipsToBounds = false
            self.backgroundColor = nil
            self.layer.cornerRadius = 0.0
        }
        
        func update(component: FilledRoundedRectangleComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            transition.setTintColor(view: self, color: component.color)
            
            if self.currentCornerRadius != component.cornerRadius {
                let previousCornerRadius = self.currentCornerRadius
                self.currentCornerRadius = component.cornerRadius
                if transition.animation.isImmediate {
                    self.applyStaticCornerRadius()
                } else {
                    self.image = nil
                    self.clipsToBounds = true
                    self.backgroundColor = component.color
                    if let previousCornerRadius, self.layer.animation(forKey: "cornerRadius") == nil {
                        self.layer.cornerRadius = previousCornerRadius
                    }
                    if #available(iOS 13.0, *) {
                        if component.smoothCorners {
                            self.layer.cornerCurve = .continuous
                        } else {
                            self.layer.cornerCurve = .circular
                        }
                        
                    }
                    transition.setCornerRadius(layer: self.layer, cornerRadius: component.cornerRadius, completion: { [weak self] completed in
                        guard let self, completed else {
                            return
                        }
                        self.applyStaticCornerRadius()
                    })
                }
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

open class SolidRoundedCornersContainer: UIView {
    public final class Params: Equatable {
        public let size: CGSize
        public let color: UIColor
        public let cornerRadius: CGFloat
        public let smoothCorners: Bool
        
        public init(
            size: CGSize,
            color: UIColor,
            cornerRadius: CGFloat,
            smoothCorners: Bool
        ) {
            self.size = size
            self.color = color
            self.cornerRadius = cornerRadius
            self.smoothCorners = smoothCorners
        }
        
        public static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.size != rhs.size {
                return false
            }
            if lhs.color != rhs.color {
                return false
            }
            if lhs.cornerRadius != rhs.cornerRadius {
                return false
            }
            if lhs.smoothCorners != rhs.smoothCorners {
                return false
            }
            return true
        }
    }
    
    public let cornersView: UIImageView
    
    private var params: Params?
    private var currentCornerRadius: CGFloat?
    private var cornerImage: UIImage?
    
    override public init(frame: CGRect) {
        self.cornersView = UIImageView()
        
        super.init(frame: frame)
        
        self.clipsToBounds = true
        
        self.addSubview(self.cornersView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyStaticCornerRadius() {
        guard let params = self.params else {
            return
        }
        guard let cornerRadius = self.currentCornerRadius else {
            return
        }
        if cornerRadius == 0.0 {
            if let cornerImage = self.cornerImage, cornerImage.size.width == 1.0 {
            } else {
                self.cornerImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                    context.setFillColor(UIColor.clear.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5).withRenderingMode(.alwaysTemplate)
            }
        } else {
            if params.smoothCorners {
                let size = CGSize(width: cornerRadius * 2.0 + 10.0, height: cornerRadius * 2.0 + 10.0)
                if let cornerImage = self.cornerImage, cornerImage.size == size {
                } else {
                    self.cornerImage = generateImage(size, rotatedContext: { size, context in
                        context.setFillColor(UIColor.white.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: cornerRadius).cgPath)
                        context.setFillColor(UIColor.clear.cgColor)
                        context.setBlendMode(.copy)
                        context.fillPath()
                    })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5).withRenderingMode(.alwaysTemplate)
                }
            } else {
                let size = CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0)
                if let cornerImage = self.cornerImage, cornerImage.size == size {
                } else {
                    self.cornerImage = generateStretchableFilledCircleImage(diameter: size.width, color: nil, backgroundColor: .white)?.withRenderingMode(.alwaysTemplate)
                }
            }
        }
        self.cornersView.image = self.cornerImage
        self.backgroundColor = nil
        self.layer.cornerRadius = 0.0
    }
        
    public func update(params: Params, transition: ComponentTransition) {
        if self.params == params {
            return
        }
        self.params = params
        
        transition.setTintColor(view: self.cornersView, color: params.color)
        
        if self.currentCornerRadius != params.cornerRadius {
            let previousCornerRadius = self.currentCornerRadius
            self.currentCornerRadius = params.cornerRadius
            if transition.animation.isImmediate {
                self.applyStaticCornerRadius()
            } else {
                self.cornersView.image = nil
                self.clipsToBounds = true
                if let previousCornerRadius, self.layer.animation(forKey: "cornerRadius") == nil {
                    self.layer.cornerRadius = previousCornerRadius
                }
                if #available(iOS 13.0, *) {
                    if params.smoothCorners {
                        self.layer.cornerCurve = .continuous
                    } else {
                        self.layer.cornerCurve = .circular
                    }
                    
                }
                transition.setCornerRadius(layer: self.layer, cornerRadius: params.cornerRadius, completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    self.applyStaticCornerRadius()
                })
            }
        }
    }
}
