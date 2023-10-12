import Foundation
import UIKit
import Display
import ComponentFlow
import RoundedRectWithTailPath

private final class FlashColorComponent: Component {
    let tint: CameraState.FlashTint?
    let isSelected: Bool
    let action: () -> Void
    
    init(
        tint: CameraState.FlashTint?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }
    
    static func == (lhs: FlashColorComponent, rhs: FlashColorComponent) -> Bool {
        return lhs.tint == rhs.tint && lhs.isSelected == rhs.isSelected
    }
    
    final class View: UIButton {
        private var component: FlashColorComponent?
        
        private var contentView: UIView
        
        private let circleLayer: SimpleShapeLayer
        private var ringLayer: CALayer?
        private var iconLayer: CALayer?
        
        private var currentIsHighlighted: Bool = false {
            didSet {
                if self.currentIsHighlighted != oldValue {
                    self.contentView.alpha = self.currentIsHighlighted ? 0.6 : 1.0
                }
            }
        }
                
        override init(frame: CGRect) {
            self.contentView = UIView(frame: CGRect(origin: .zero, size: frame.size))
            self.contentView.isUserInteractionEnabled = false
            self.circleLayer = SimpleShapeLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
            self.contentView.layer.addSublayer(self.circleLayer)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        @objc private func pressed() {
            self.component?.action()
        }
        
        override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.currentIsHighlighted = true
            
            return super.beginTracking(touch, with: event)
        }
                        
        override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            self.currentIsHighlighted = false
        
            super.endTracking(touch, with: event)
        }
        
        override public func cancelTracking(with event: UIEvent?) {
            self.currentIsHighlighted = false
        
            super.cancelTracking(with: event)
        }
                
        func update(component: FlashColorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            let contentSize = CGSize(width: 24.0, height: 24.0)
            self.contentView.frame = CGRect(origin: .zero, size: contentSize)
            
            let bounds = CGRect(origin: .zero, size: contentSize)
            self.layer.allowsGroupOpacity = true
            self.contentView.layer.allowsGroupOpacity = true
            
            self.circleLayer.frame = bounds
            if self.ringLayer == nil {
                let ringLayer = SimpleLayer()
                ringLayer.backgroundColor = UIColor.clear.cgColor
                ringLayer.cornerRadius = contentSize.width / 2.0
                ringLayer.borderWidth = 1.0 + UIScreenPixel
                ringLayer.frame = CGRect(origin: .zero, size: contentSize)
                self.contentView.layer.insertSublayer(ringLayer, at: 0)
                self.ringLayer = ringLayer
            }

            if component.isSelected {
                transition.setShapeLayerPath(layer: self.circleLayer, path: CGPath(ellipseIn: bounds.insetBy(dx: 3.0 - UIScreenPixel, dy: 3.0 - UIScreenPixel), transform: nil))
            } else {
                transition.setShapeLayerPath(layer: self.circleLayer, path: CGPath(ellipseIn: bounds, transform: nil))
            }
            
            if let color = component.tint?.color {
                self.circleLayer.fillColor = color.cgColor
                self.ringLayer?.borderColor = color.cgColor
            } else {
                if self.iconLayer == nil {
                    let iconLayer = SimpleLayer()
                    iconLayer.contents = UIImage(bundleImageName: "Camera/FlashOffIcon")?.cgImage
                    iconLayer.contentsGravity = .resizeAspect
                    iconLayer.frame = bounds.insetBy(dx: -4.0, dy: -4.0)
                    self.contentView.layer.addSublayer(iconLayer)
                    self.iconLayer = iconLayer
                }
                
                self.circleLayer.fillColor = UIColor(rgb: 0xffffff, alpha: 0.1).cgColor
                self.ringLayer?.borderColor = UIColor.clear.cgColor
            }
            
            return contentSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class FlashTintControlComponent: Component {
    let position: CGPoint
    let tint: CameraState.FlashTint
    let update: (CameraState.FlashTint?) -> Void
    let dismiss: () -> Void
    
    init(
        position: CGPoint,
        tint: CameraState.FlashTint,
        update: @escaping (CameraState.FlashTint?) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.position = position
        self.tint = tint
        self.update = update
        self.dismiss = dismiss
    }
    
    static func == (lhs: FlashTintControlComponent, rhs: FlashTintControlComponent) -> Bool {
        return lhs.position == rhs.position && lhs.tint == rhs.tint
    }
    
    final class View: UIButton {
        private var component: FlashTintControlComponent?
        
        private let dismissView = UIView()
        private let containerView = UIView()
        private let effectView: UIVisualEffectView
        private let maskLayer = CAShapeLayer()
        private let swatches = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            
            super.init(frame: frame)
            
            self.containerView.layer.anchorPoint = CGPoint(x: 0.8, y: 0.0)
            
            self.addSubview(self.dismissView)
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.effectView)
         
            self.dismissView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissTapped)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func dismissTapped() {
            self.component?.dismiss()
        }
                                
        func update(component: FlashTintControlComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            
            let size = CGSize(width: 160.0, height: 40.0)
            if isFirstTime {
                self.maskLayer.path = generateRoundedRectWithTailPath(rectSize: size, cornerRadius: 10.0, tailSize: CGSize(width: 18, height: 7.0), tailRadius: 1.0, tailPosition: 0.8, transformTail: false).cgPath
                self.maskLayer.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height + 7.0))
                self.effectView.layer.mask = self.maskLayer
            }
            
            let swatchesSize = self.swatches.update(
                transition: transition,
                component: AnyComponent(
                    HStack(
                        [
                            AnyComponentWithIdentity(
                                id: "off",
                                component: AnyComponent(
                                    FlashColorComponent(
                                        tint: nil,
                                        isSelected: false,
                                        action: {
                                            component.update(nil)
                                            component.dismiss()
                                        }
                                    )
                                )
                            ),
                            AnyComponentWithIdentity(
                                id: "white",
                                component: AnyComponent(
                                    FlashColorComponent(
                                        tint: .white,
                                        isSelected: component.tint == .white,
                                        action: {
                                            component.update(.white)
                                        }
                                    )
                                )
                            ),
                            AnyComponentWithIdentity(
                                id: "yellow",
                                component: AnyComponent(
                                    FlashColorComponent(
                                        tint: .yellow,
                                        isSelected: component.tint == .yellow,
                                        action: {
                                            component.update(.yellow)
                                        }
                                    )
                                )
                            ),
                            AnyComponentWithIdentity(
                                id: "blue",
                                component: AnyComponent(
                                    FlashColorComponent(
                                        tint: .blue,
                                        isSelected: component.tint == .blue,
                                        action: {
                                            component.update(.blue)
                                        }
                                    )
                                )
                            )
                        ],
                        spacing: 16.0
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.swatches.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - swatchesSize.width) / 2.0), y: floorToScreenPixels((size.height - swatchesSize.height) / 2.0)), size: swatchesSize)
            }
            
            self.dismissView.frame = CGRect(origin: .zero, size: availableSize)
            
            self.containerView.bounds = CGRect(origin: .zero, size: size)
            self.containerView.center = component.position
            
            self.effectView.frame = CGRect(origin: CGPoint(x: 0.0, y: -7.0), size: CGSize(width: size.width, height: size.height + 7.0))
            
            if isFirstTime {
                self.containerView.layer.animateScale(from: 0.0, to: 1.0, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring)
                self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            
            return availableSize
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.containerView.frame.contains(point) {
                return self.dismissView
            }
            return super.hitTest(point, with: event)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
