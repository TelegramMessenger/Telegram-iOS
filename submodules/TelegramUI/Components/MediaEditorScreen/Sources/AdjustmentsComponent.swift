import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import LegacyComponents
import MediaEditor

final class AdjustmentSliderComponent: Component {
    typealias EnvironmentType = Empty
    
    let title: String
    let value: Float
    let minValue: Float
    let maxValue: Float
    let startValue: Float
    let isEnabled: Bool
    let trackColor: UIColor?
    let displayValue: Bool
    let valueUpdated: (Float) -> Void
    let isTrackingUpdated: ((Bool) -> Void)?
    
    init(
        title: String,
        value: Float,
        minValue: Float,
        maxValue: Float,
        startValue: Float,
        isEnabled: Bool,
        trackColor: UIColor?,
        displayValue: Bool,
        valueUpdated: @escaping (Float) -> Void,
        isTrackingUpdated: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.startValue = startValue
        self.isEnabled = isEnabled
        self.trackColor = trackColor
        self.displayValue = displayValue
        self.valueUpdated = valueUpdated
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    static func ==(lhs: AdjustmentSliderComponent, rhs: AdjustmentSliderComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.maxValue != rhs.maxValue {
            return false
        }
        if lhs.startValue != rhs.startValue {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.trackColor != rhs.trackColor {
            return false
        }
        if lhs.displayValue != rhs.displayValue {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private let title = ComponentView<Empty>()
        private let value = ComponentView<Empty>()
        private var sliderView: TGPhotoEditorSliderView?
        
        private var component: AdjustmentSliderComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: AdjustmentSliderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var internalIsTrackingUpdated: ((Bool) -> Void)?
            if let isTrackingUpdated = component.isTrackingUpdated {
                internalIsTrackingUpdated = { [weak self] isTracking in
                    if let self {
                        if isTracking {
                            self.sliderView?.bordered = true
                        } else {
                            Queue.mainQueue().after(0.1) {
                                self.sliderView?.bordered = false
                            }
                        }
                        isTrackingUpdated(isTracking)
                        let transition: Transition
                        if isTracking {
                            transition = .immediate
                        } else {
                            transition = .easeInOut(duration: 0.25)
                        }
                        if let titleView = self.title.view {
                            transition.setAlpha(view: titleView, alpha: isTracking ? 0.0 : 1.0)
                        }
                        if let valueView = self.value.view {
                            transition.setAlpha(view: valueView, alpha: isTracking ? 0.0 : 1.0)
                        }
                    }
                }
            }
                        
            let sliderView: TGPhotoEditorSliderView
            if let current = self.sliderView {
                sliderView = current
                sliderView.value = CGFloat(component.value)
            } else {
                sliderView = TGPhotoEditorSliderView()
                sliderView.backgroundColor = .clear
                sliderView.startColor = UIColor(rgb: 0xffffff)
                sliderView.enablePanHandling = true
                sliderView.trackCornerRadius = 1.0
                sliderView.lineSize = 2.0
                sliderView.minimumValue = CGFloat(component.minValue)
                sliderView.maximumValue = CGFloat(component.maxValue)
                sliderView.startValue = CGFloat(component.startValue)
                sliderView.value = CGFloat(component.value)
                sliderView.disablesInteractiveTransitionGestureRecognizer = true
                sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
                sliderView.layer.allowsGroupOpacity = true
                self.sliderView = sliderView
                self.addSubview(sliderView)
            }
            sliderView.interactionBegan = {
                internalIsTrackingUpdated?(true)
            }
            sliderView.interactionEnded = {
                internalIsTrackingUpdated?(false)
            }
            
            if component.isEnabled {
                sliderView.alpha = 1.3
                sliderView.trackColor = component.trackColor ?? UIColor(rgb: 0xffffff)
                sliderView.isUserInteractionEnabled = true
            } else {
                sliderView.trackColor = UIColor(rgb: 0xffffff)
                sliderView.alpha = 0.3
                sliderView.isUserInteractionEnabled = false
            }
            
            transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: 22.0, y: 7.0), size: CGSize(width: availableSize.width - 22.0 * 2.0, height: 44.0)))
            sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    Text(text: component.title, font: Font.regular(14.0), color: UIColor(rgb: 0x808080))
                ),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: 21.0, y: 0.0), size: titleSize))
            }
            
            let valueText: String
            if component.displayValue {
                if component.value > 0.005 {
                    valueText = String(format: "+%.2f", component.value)
                } else if component.value < -0.005 {
                    valueText = String(format: "%.2f", component.value)
                } else {
                    valueText = ""
                }
            } else {
                valueText = ""
            }
            
            let valueSize = self.value.update(
                transition: .immediate,
                component: AnyComponent(
                    Text(text: valueText, font: Font.with(size: 14.0, traits: .monospacedNumbers), color: UIColor(rgb: 0xf8d74a))
                ),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let valueView = self.value.view {
                if valueView.superview == nil {
                    self.addSubview(valueView)
                }
                transition.setFrame(view: valueView, frame: CGRect(origin: CGPoint(x: availableSize.width - 21.0 - valueSize.width, y: 0.0), size: valueSize))
            }
            
            return CGSize(width: availableSize.width, height: 52.0)
        }
        
        @objc private func sliderValueChanged() {
            guard let component = self.component, let sliderView = self.sliderView else {
                return
            }
            component.valueUpdated(Float(sliderView.value))
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

struct AdjustmentTool: Equatable {
    let key: EditorToolKey
    let title: String
    let value: Float
    let minValue: Float
    let maxValue: Float
    let startValue: Float
}

final class AdjustmentsComponent: Component {
    typealias EnvironmentType = Empty
    
    let tools: [AdjustmentTool]
    let valueUpdated: (EditorToolKey, Float) -> Void
    let isTrackingUpdated: (Bool) -> Void
    
    init(
        tools: [AdjustmentTool],
        valueUpdated: @escaping (EditorToolKey, Float) -> Void,
        isTrackingUpdated: @escaping (Bool) -> Void
    ) {
        self.tools = tools
        self.valueUpdated = valueUpdated
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    static func ==(lhs: AdjustmentsComponent, rhs: AdjustmentsComponent) -> Bool {
        if lhs.tools != rhs.tools {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let scrollView = UIScrollView()
        private var toolViews: [ComponentView<Empty>] = []
        
        private var component: AdjustmentsComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.scrollView.showsVerticalScrollIndicator = false
                        
            super.init(frame: frame)
                        
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: AdjustmentsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let valueUpdated = component.valueUpdated
            let isTrackingUpdated: (EditorToolKey, Bool) -> Void = { [weak self] trackingTool, isTracking in
                component.isTrackingUpdated(isTracking)
                
                if let self {
                    for i in 0 ..< component.tools.count {
                        let tool = component.tools[i]
                        if tool.key != trackingTool && i < self.toolViews.count {
                            if let view = self.toolViews[i].view {
                                let transition: Transition
                                if isTracking {
                                    transition = .immediate
                                } else {
                                    transition = .easeInOut(duration: 0.25)
                                }
                                transition.setAlpha(view: view, alpha: isTracking ? 0.0 : 1.0)
                            }
                        }
                    }
                }
            }
                        
            var sizes: [CGSize] = []
            for i in 0 ..< component.tools.count {
                let tool = component.tools[i]
                let componentView: ComponentView<Empty>
                if i >= self.toolViews.count {
                    componentView = ComponentView<Empty>()
                    self.toolViews.append(componentView)
                } else {
                    componentView = self.toolViews[i]
                }
                
                var valueIsNegative = false
                var value = tool.value
                if case .enhance = tool.key {
                    if value < 0.0 {
                        valueIsNegative = true
                    }
                    value = abs(value)
                }
                
                let size = componentView.update(
                    transition: transition,
                    component: AnyComponent(
                        AdjustmentSliderComponent(
                            title: tool.title,
                            value: value,
                            minValue: tool.minValue,
                            maxValue: tool.maxValue,
                            startValue: tool.startValue,
                            isEnabled: true,
                            trackColor: nil,
                            displayValue: true,
                            valueUpdated: { value in
                                var updatedValue = value
                                if valueIsNegative {
                                    updatedValue *= -1.0
                                }
                                valueUpdated(tool.key, updatedValue)
                            },
                            isTrackingUpdated: { isTracking in
                                isTrackingUpdated(tool.key, isTracking)
                            }
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                sizes.append(size)
            }
            
            var origin: CGPoint = CGPoint(x: 0.0, y: 11.0)
            for i in 0 ..< component.tools.count {
                let size = sizes[i]
                let componentView = self.toolViews[i]
                
                if let view = componentView.view {
                    if view.superview == nil {
                        self.scrollView.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: origin, size: size))
                }
                origin = origin.offsetBy(dx: 0.0, dy: size.height)
            }
            
            let size = CGSize(width: availableSize.width, height: 180.0)
            let contentSize = CGSize(width: availableSize.width, height: origin.y)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: size))

            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class AdjustmentsScreenComponent: Component {
    typealias EnvironmentType = Empty
    
    let toggleUneditedPreview: (Bool) -> Void
    
    init(
        toggleUneditedPreview: @escaping (Bool) -> Void
    ) {
        self.toggleUneditedPreview = toggleUneditedPreview
    }
    
    static func ==(lhs: AdjustmentsScreenComponent, rhs: AdjustmentsScreenComponent) -> Bool {
        return true
    }
        
    final class View: UIView {
        enum Field {
            case blacks
            case shadows
            case midtones
            case highlights
            case whites
        }
        
        private var component: AdjustmentsScreenComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
            longPressGestureRecognizer.minimumPressDuration = 0.05
            self.addGestureRecognizer(longPressGestureRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        @objc func handleLongPress(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            
            switch gestureRecognizer.state {
            case .began:
                component.toggleUneditedPreview(true)
            case .ended, .cancelled:
                component.toggleUneditedPreview(false)
            default:
                break
            }
        }
        
        func update(component: AdjustmentsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
