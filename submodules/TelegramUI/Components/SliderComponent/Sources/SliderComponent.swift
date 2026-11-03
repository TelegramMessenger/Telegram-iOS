import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import LegacyComponents
import ComponentFlow

public final class SliderComponent: Component {
    public final class Discrete: Equatable {
        public let valueCount: Int
        public let value: Int
        public let minValue: Int?
        public let markPositions: Bool
        public let valueUpdated: (Int) -> Void
        
        public init(valueCount: Int, value: Int, minValue: Int? = nil, markPositions: Bool, valueUpdated: @escaping (Int) -> Void) {
            self.valueCount = valueCount
            self.value = value
            self.minValue = minValue
            self.markPositions = markPositions
            self.valueUpdated = valueUpdated
        }
        
        public static func ==(lhs: Discrete, rhs: Discrete) -> Bool {
            if lhs.valueCount != rhs.valueCount {
                return false
            }
            if lhs.value != rhs.value {
                return false
            }
            if lhs.minValue != rhs.minValue {
                return false
            }
            if lhs.markPositions != rhs.markPositions {
                return false
            }
            return true
        }
    }
    
    public final class Continuous: Equatable {
        public let value: CGFloat
        public let minValue: CGFloat?
        public let range: ClosedRange<CGFloat>
        public let startValue: CGFloat
        public let valueUpdated: (CGFloat) -> Void
        
        public init(
            value: CGFloat,
            minValue: CGFloat? = nil,
            range: ClosedRange<CGFloat> = 0.0 ... 1.0,
            startValue: CGFloat = 0.0,
            valueUpdated: @escaping (CGFloat) -> Void
        ) {
            self.value = value
            self.minValue = minValue
            self.range = range
            self.startValue = startValue
            self.valueUpdated = valueUpdated
        }
        
        public static func ==(lhs: Continuous, rhs: Continuous) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.minValue != rhs.minValue {
                return false
            }
            if lhs.range != rhs.range {
                return false
            }
            if lhs.startValue != rhs.startValue {
                return false
            }
            return true
        }
    }
    
    public enum Content: Equatable {
        case discrete(Discrete)
        case continuous(Continuous)
    }
    
    public let content: Content
    public let useNative: Bool
    public let trackBackgroundColor: UIColor
    public let trackForegroundColor: UIColor
    public let minTrackForegroundColor: UIColor?
    public let knobSize: CGFloat?
    public let knobColor: UIColor?
    public let isEnabled: Bool
    public let trackHeight: CGFloat?
    public let displaysBorderOnTracking: Bool
    public let useLegacyKnob: Bool
    public let isTrackingUpdated: ((Bool) -> Void)?
    
    public init(
        content: Content,
        useNative: Bool = false,
        trackBackgroundColor: UIColor,
        trackForegroundColor: UIColor,
        minTrackForegroundColor: UIColor? = nil,
        knobSize: CGFloat? = nil,
        knobColor: UIColor? = nil,
        isEnabled: Bool = true,
        trackHeight: CGFloat? = nil,
        displaysBorderOnTracking: Bool = false,
        useLegacyKnob: Bool = false,
        isTrackingUpdated: ((Bool) -> Void)? = nil
    ) {
        self.content = content
        self.useNative = useNative
        self.trackBackgroundColor = trackBackgroundColor
        self.trackForegroundColor = trackForegroundColor
        self.minTrackForegroundColor = minTrackForegroundColor
        self.knobSize = knobSize
        self.knobColor = knobColor
        self.isEnabled = isEnabled
        self.trackHeight = trackHeight
        self.displaysBorderOnTracking = displaysBorderOnTracking
        self.useLegacyKnob = useLegacyKnob
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    public static func ==(lhs: SliderComponent, rhs: SliderComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.trackBackgroundColor != rhs.trackBackgroundColor {
            return false
        }
        if lhs.trackForegroundColor != rhs.trackForegroundColor {
            return false
        }
        if lhs.minTrackForegroundColor != rhs.minTrackForegroundColor {
            return false
        }
        if lhs.knobSize != rhs.knobSize {
            return false
        }
        if lhs.knobColor != rhs.knobColor {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.trackHeight != rhs.trackHeight {
            return false
        }
        if lhs.displaysBorderOnTracking != rhs.displaysBorderOnTracking {
            return false
        }
        if lhs.useLegacyKnob != rhs.useLegacyKnob {
            return false
        }
        return true
    }
    
    final class SliderView: UISlider {
        
    }
    
    public final class View: UIView {
        private var nativeSliderView: SliderView?
        private let nativeTrackBackgroundView = UIView()
        private let nativeTrackForegroundView = UIView()
        private var sliderView: TGPhotoEditorSliderView?
        
        private var component: SliderComponent?
        private weak var state: EmptyComponentState?
        
        public var hitTestTarget: UIView? {
            return self.sliderView
        }
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private static let legacyKnobImage: UIImage = generateImage(CGSize(width: 21.0, height: 21.0), rotatedContext: { _, context in
            context.setShadow(offset: CGSize(width: 0.0, height: 0.5), blur: 1.5, color: UIColor(white: 0.0, alpha: 0.5).cgColor)
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: 2.0, y: 2.0, width: 17.0, height: 17.0))
        })!
                
        public func cancelGestures() {
            if let sliderView = self.sliderView, let gestureRecognizers = sliderView.gestureRecognizers {
                for gestureRecognizer in gestureRecognizers {
                    if gestureRecognizer.isEnabled {
                        gestureRecognizer.isEnabled = false
                        gestureRecognizer.isEnabled = true
                    }
                }
            }
        }
        
        func update(component: SliderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            if #available(iOS 26.0, *), component.useNative {
                if let sliderView = self.sliderView {
                    self.sliderView = nil
                    sliderView.removeFromSuperview()
                }

                let sliderView: SliderView
                if let current = self.nativeSliderView {
                    sliderView = current
                } else {
                    sliderView = SliderView()
                    sliderView.disablesInteractiveTransitionGestureRecognizer = true
                    sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
                    sliderView.layer.allowsGroupOpacity = true
                    
                    self.addSubview(self.nativeTrackBackgroundView)
                    self.addSubview(self.nativeTrackForegroundView)
                    self.addSubview(sliderView)
                    self.nativeSliderView = sliderView
                    
                    switch component.content {
                    case let .continuous(continuous):
                        sliderView.minimumValue = Float(continuous.minValue ?? continuous.range.lowerBound)
                        sliderView.maximumValue = Float(continuous.range.upperBound)
                    case let .discrete(discrete):
                        sliderView.minimumValue = 0.0
                        sliderView.maximumValue = Float(discrete.valueCount - 1)
                        sliderView.trackConfiguration = .init(numberOfTicks: discrete.valueCount)
                    }
                }
                switch component.content {
                case let .continuous(continuous):
                    sliderView.minimumValue = Float(continuous.minValue ?? continuous.range.lowerBound)
                    sliderView.maximumValue = Float(continuous.range.upperBound)
                    sliderView.value = Float(continuous.value)
                case let .discrete(discrete):
                    sliderView.minimumValue = 0.0
                    sliderView.maximumValue = Float(discrete.valueCount - 1)
                    sliderView.value = Float(discrete.value)
                }

                let useCenteredNativeTrack: Bool
                if case let .continuous(continuous) = component.content, continuous.range.lowerBound < continuous.startValue && continuous.startValue < continuous.range.upperBound {
                    useCenteredNativeTrack = true
                } else {
                    useCenteredNativeTrack = false
                }

                if useCenteredNativeTrack {
                    sliderView.minimumTrackTintColor = UIColor.clear
                    sliderView.maximumTrackTintColor = UIColor.clear

                    let trackHeight = component.trackHeight ?? 4.0
                    let trackFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - trackHeight) * 0.5)), size: CGSize(width: availableSize.width, height: trackHeight))
                    self.nativeTrackBackgroundView.backgroundColor = component.trackBackgroundColor
                    self.nativeTrackBackgroundView.layer.cornerRadius = trackHeight * 0.5
                    self.nativeTrackBackgroundView.alpha = component.isEnabled ? 1.0 : 0.3
                    transition.setFrame(view: self.nativeTrackBackgroundView, frame: trackFrame)

                    if case let .continuous(continuous) = component.content {
                        let rangeDistance = max(continuous.range.upperBound - continuous.range.lowerBound, CGFloat.ulpOfOne)
                        let startPosition = min(max((continuous.startValue - continuous.range.lowerBound) / rangeDistance, 0.0), 1.0) * trackFrame.width
                        let valuePosition = min(max((continuous.value - continuous.range.lowerBound) / rangeDistance, 0.0), 1.0) * trackFrame.width
                        let foregroundFrame = CGRect(
                            origin: CGPoint(x: trackFrame.minX + min(startPosition, valuePosition), y: trackFrame.minY),
                            size: CGSize(width: abs(valuePosition - startPosition), height: trackFrame.height)
                        )
                        self.nativeTrackForegroundView.backgroundColor = component.trackForegroundColor
                        self.nativeTrackForegroundView.layer.cornerRadius = trackHeight * 0.5
                        self.nativeTrackForegroundView.alpha = component.isEnabled ? 1.0 : 0.3
                        transition.setFrame(view: self.nativeTrackForegroundView, frame: foregroundFrame)
                    }
                } else {
                    sliderView.minimumTrackTintColor = component.trackForegroundColor
                    sliderView.maximumTrackTintColor = component.trackBackgroundColor
                    self.nativeTrackBackgroundView.frame = CGRect()
                    self.nativeTrackForegroundView.frame = CGRect()
                }
                sliderView.isEnabled = component.isEnabled
                sliderView.alpha = component.isEnabled ? 1.0 : 0.3
                
                transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: 44.0)))
            } else {
                self.nativeTrackBackgroundView.frame = CGRect()
                self.nativeTrackForegroundView.frame = CGRect()
                if let nativeSliderView = self.nativeSliderView {
                    self.nativeSliderView = nil
                    nativeSliderView.removeFromSuperview()
                }

                var internalIsTrackingUpdated: ((Bool) -> Void)?
                if let isTrackingUpdated = component.isTrackingUpdated {
                    internalIsTrackingUpdated = { [weak self] isTracking in
                        if let self {
                            if component.displaysBorderOnTracking {
                                if isTracking {
                                    self.sliderView?.bordered = true
                                } else {
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: { [weak self] in
                                        self?.sliderView?.bordered = false
                                    })
                                }
                            }
                        }
                        isTrackingUpdated(isTracking)
                    }
                }
                
                let sliderView: TGPhotoEditorSliderView
                if let current = self.sliderView {
                    sliderView = current
                } else {
                    sliderView = TGPhotoEditorSliderView()
                    sliderView.enablePanHandling = true
                    sliderView.dotSize = 5.0
                    sliderView.disablesInteractiveTransitionGestureRecognizer = true
                    
                    switch component.content {
                    case let .discrete(discrete):
                        sliderView.positionsCount = discrete.valueCount
                        sliderView.useLinesForPositions = true
                        sliderView.markPositions = discrete.markPositions
                    case .continuous:
                        break
                    }
                    
                    sliderView.backgroundColor = nil
                    sliderView.isOpaque = false
                    
                    sliderView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
                    sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
                    
                    
                    sliderView.disablesInteractiveTransitionGestureRecognizer = true
                    sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
                    sliderView.layer.allowsGroupOpacity = true
                    self.sliderView = sliderView
                    self.addSubview(sliderView)
                }
                if let trackHeight = component.trackHeight {
                    sliderView.lineSize = trackHeight
                } else if let knobSize = component.knobSize {
                    sliderView.lineSize = knobSize + 4.0
                } else {
                    sliderView.lineSize = 4.0
                }
                sliderView.trackCornerRadius = sliderView.lineSize * 0.5
                sliderView.backColor = component.trackBackgroundColor
                sliderView.startColor = component.useLegacyKnob ? UIColor(rgb: 0xffffff) : component.trackBackgroundColor
                sliderView.trackColor = component.trackForegroundColor
                sliderView.isUserInteractionEnabled = component.isEnabled
                sliderView.alpha = component.isEnabled ? (component.useLegacyKnob ? 1.3 : 1.0) : 0.3
                if let knobSize = component.knobSize {
                    sliderView.knobImage = generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setShadow(offset: CGSize(width: 0.0, height: -3.0), blur: 12.0, color: UIColor(white: 0.0, alpha: 0.25).cgColor)
                        if let knobColor = component.knobColor {
                            context.setFillColor(knobColor.cgColor)
                        } else {
                            context.setFillColor(UIColor.white.cgColor)
                        }
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: floor((size.width - knobSize) * 0.5), y: floor((size.width - knobSize) * 0.5)), size: CGSize(width: knobSize, height: knobSize)))
                    })
                } else if component.useLegacyKnob {
                    sliderView.knobImage = View.legacyKnobImage
                } else {
                    sliderView.knobImage = generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setShadow(offset: CGSize(width: 0.0, height: -3.0), blur: 12.0, color: UIColor(white: 0.0, alpha: 0.25).cgColor)
                        context.setFillColor(UIColor.white.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 28.0, height: 28.0)))
                    })
                }
                sliderView.lowerBoundTrackColor = component.minTrackForegroundColor
                switch component.content {
                case let .discrete(discrete):
                    sliderView.minimumValue = 0.0
                    sliderView.maximumValue = CGFloat(discrete.valueCount - 1)
                    sliderView.startValue = 0.0
                    sliderView.positionsCount = discrete.valueCount
                    sliderView.useLinesForPositions = true
                    sliderView.markPositions = discrete.markPositions
                    if let minValue = discrete.minValue {
                        sliderView.lowerBoundValue = CGFloat(minValue)
                    } else {
                        sliderView.lowerBoundValue = 0.0
                    }
                    sliderView.value = CGFloat(discrete.value)
                case let .continuous(continuous):
                    sliderView.minimumValue = continuous.range.lowerBound
                    sliderView.maximumValue = continuous.range.upperBound
                    sliderView.startValue = continuous.startValue
                    sliderView.positionsCount = 0
                    if let minValue = continuous.minValue {
                        sliderView.lowerBoundValue = minValue
                    } else {
                        sliderView.lowerBoundValue = 0.0
                    }
                    sliderView.value = continuous.value
                }
                sliderView.interactionBegan = {
                    internalIsTrackingUpdated?(true)
                }
                sliderView.interactionEnded = {
                    internalIsTrackingUpdated?(false)
                }
                
                transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: 44.0)))
                sliderView.hitTestEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            }
            
            return size
        }
        
        @objc private func sliderValueChanged() {
            guard let component = self.component else {
                return
            }
            let floatValue: CGFloat
            if let sliderView = self.sliderView {
                floatValue = sliderView.value
            } else if let nativeSliderView = self.nativeSliderView {
                floatValue = CGFloat(nativeSliderView.value)
            } else {
                return
            }
            switch component.content {
            case let .discrete(discrete):
                discrete.valueUpdated(Int(floatValue))
            case let .continuous(continuous):
                continuous.valueUpdated(floatValue)
            }
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
