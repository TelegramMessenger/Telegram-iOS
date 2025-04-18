import Foundation
import UIKit
import Display
import AsyncDisplayKit
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
                
        func update(component: FlashColorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            let contentSize = CGSize(width: 30.0, height: 30.0)
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class FlashTintControlComponent: Component {
    let position: CGPoint
    let tint: CameraState.FlashTint
    let size: CGFloat
    let update: (CameraState.FlashTint?) -> Void
    let updateSize: (CGFloat) -> Void
    let dismiss: () -> Void
    
    init(
        position: CGPoint,
        tint: CameraState.FlashTint,
        size: CGFloat,
        update: @escaping (CameraState.FlashTint?) -> Void,
        updateSize: @escaping (CGFloat) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.position = position
        self.tint = tint
        self.size = size
        self.update = update
        self.updateSize = updateSize
        self.dismiss = dismiss
    }
    
    static func == (lhs: FlashTintControlComponent, rhs: FlashTintControlComponent) -> Bool {
        return lhs.position == rhs.position && lhs.tint == rhs.tint && lhs.size == rhs.size
    }
    
    final class View: UIButton {
        private var component: FlashTintControlComponent?
        
        private let dismissView = UIView()
        private let containerView = UIView()
        private let effectView: UIVisualEffectView
        private let maskLayer = CAShapeLayer()
        private let swatches = ComponentView<Empty>()
        private let sliderView: SliderView
        
        override init(frame: CGRect) {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            
            var sizeUpdateImpl: ((CGFloat) -> Void)?
            self.sliderView = SliderView(minValue: 0.0, maxValue: 1.0, value: 1.0, valueChanged: { value , _ in
                sizeUpdateImpl?(value)
            })
            
            super.init(frame: frame)
            
            self.containerView.layer.anchorPoint = CGPoint(x: 0.8, y: 0.0)
            
            self.addSubview(self.dismissView)
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.effectView)
            self.containerView.addSubview(self.sliderView)
         
            self.dismissView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissTapped)))
            
            sizeUpdateImpl = { [weak self] size in
                if let self, let component {
                    component.updateSize(size)
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func dismissTapped() {
            self.component?.dismiss()
        }
                                
        func update(component: FlashTintControlComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            
            let size = CGSize(width: 184.0, height: 92.0)
            
            self.sliderView.frame = CGRect(origin: CGPoint(x: 8.0, y: size.height - 38.0), size: CGSize(width: size.width - 16.0, height: 30.0))
            
            if isFirstTime {
                self.sliderView.value = component.size
                
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
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - swatchesSize.width) / 2.0), y: 8.0), size: swatchesSize)
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SliderView: UIView {
    private let foregroundView: UIView
    private let knobView: UIImageView
    
    let minValue: CGFloat
    let maxValue: CGFloat
    var value: CGFloat = 1.0 {
        didSet {
            self.updateValue()
        }
    }
    
    private let valueChanged: (CGFloat, Bool) -> Void
    
    private let hapticFeedback = HapticFeedback()

    init(minValue: CGFloat, maxValue: CGFloat, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.valueChanged = valueChanged
        
        self.foregroundView = UIView()
        self.foregroundView.backgroundColor = UIColor(rgb: 0x8b8b8a)
        
        self.knobView = UIImageView(image: generateFilledCircleImage(diameter: 30.0, color: .white))
        
        super.init(frame: .zero)
               
        self.backgroundColor = UIColor(rgb: 0x3e3e3e)
        self.clipsToBounds = true
        self.layer.cornerRadius = 15.0
        
        self.foregroundView.isUserInteractionEnabled = false
        self.knobView.isUserInteractionEnabled = false
        
        self.addSubview(self.foregroundView)
        self.addSubview(self.knobView)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateValue(transition: ComponentTransition = .immediate) {
        let width = self.frame.width
        
        let range = self.maxValue - self.minValue
        let value = (self.value - self.minValue) / range
        
        transition.setFrame(view: self.foregroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: 15.0 + value * (width - 30.0), height: 30.0)))
        transition.setFrame(view: self.knobView, frame: CGRect(origin: CGPoint(x: (width - 30.0) * value, y: 0.0), size: CGSize(width: 30.0, height: 30.0)))
    }
    
    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let range = self.maxValue - self.minValue
        switch gestureRecognizer.state {
            case .began:
                break
            case .changed:
                let previousValue = self.value
                
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * range
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                gestureRecognizer.setTranslation(CGPoint(), in: gestureRecognizer.view)
                
                if self.value == 1.0 && previousValue != 1.0 {
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 0.0 && previousValue != 0.0 {
                    self.hapticFeedback.impact(.soft)
                }
                if abs(previousValue - self.value) >= 0.001 {
                    self.valueChanged(self.value, false)
                }
            case .ended:
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * range
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                self.valueChanged(self.value, true)
            default:
                break
        }
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let range = self.maxValue - self.minValue
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        self.value = max(self.minValue, min(self.maxValue, self.minValue + location.x / self.bounds.width * range))
        self.valueChanged(self.value, true)
    }
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func performAction() {
    }
}

final class CameraFrontFlashOverlayController: ViewController {
    class Node: ASDisplayNode {
        init(color: UIColor) {
            super.init()
            
            self.backgroundColor = color
        }
    }
    
    private let color: UIColor
    init(color: UIColor) {
        self.color = color
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = Node(color: self.color)
        self.displayNodeDidLoad()
    }
    
    func dismissAnimated() {
        self.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
            self.dismiss()
        })
    }
}
