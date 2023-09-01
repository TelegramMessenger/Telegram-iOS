import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import MediaEditor
import TelegramPresentationData

private final class TintColorComponent: Component {
    typealias EnvironmentType = Empty
    
    let color: UIColor
    let isSelected: Bool
    
    init(
        color: UIColor,
        isSelected: Bool
    ) {
        self.color = color
        self.isSelected = isSelected
    }
    
    static func ==(lhs: TintColorComponent, rhs: TintColorComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
        
    final class View: UIView {
        private var background = SimpleShapeLayer()
        private var selection = SimpleShapeLayer()
                
        private var component: TintColorComponent?
        private weak var state: EmptyComponentState?
    
        private let size = CGSize(width: 24.0, height: 24.0)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
               
            self.background.path = CGPath(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 3.0, dy: 3.0), transform: nil)
           
            let lineWidth = 1.0 + UIScreenPixel
            self.selection.lineWidth = lineWidth
            self.selection.path = CGPath(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0), transform: nil)
            
            self.layer.addSublayer(self.selection)
            self.layer.addSublayer(self.background)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: TintColorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 24.0, height: 24.0)
            let bounds = CGRect(origin: .zero, size: size)
                        
            let color: UIColor
            let selectionColor: UIColor
            if component.color == .clear {
                if component.isSelected {
                    color = UIColor(rgb: 0x000000)
                } else {
                    color = UIColor(rgb: 0x1c1f22)
                }
                selectionColor = UIColor(rgb: 0x808080)
            } else {
                color = component.color
                selectionColor = component.color
            }
            
            self.background.fillColor = color.cgColor
            self.selection.strokeColor = selectionColor.cgColor
            self.selection.fillColor = UIColor.clear.cgColor
            
            self.background.frame = bounds
            self.selection.frame = bounds
            
            self.selection.isHidden = !component.isSelected
            
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

final class TintComponent: Component {
    enum Section {
        case shadows
        case highlights
    }
    
    typealias EnvironmentType = Empty
    
    let strings: PresentationStrings
    let shadowsValue: TintValue
    let highlightsValue: TintValue
    let shadowsValueUpdated: (TintValue) -> Void
    let highlightsValueUpdated: (TintValue) -> Void
    let isTrackingUpdated: (Bool) -> Void
    
    init(
        strings: PresentationStrings,
        shadowsValue: TintValue,
        highlightsValue: TintValue,
        shadowsValueUpdated: @escaping (TintValue) -> Void,
        highlightsValueUpdated: @escaping (TintValue) -> Void,
        isTrackingUpdated: @escaping (Bool) -> Void
    ) {
        self.strings = strings
        self.shadowsValue = shadowsValue
        self.highlightsValue = highlightsValue
        self.shadowsValueUpdated = shadowsValueUpdated
        self.highlightsValueUpdated = highlightsValueUpdated
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    static func ==(lhs: TintComponent, rhs: TintComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.highlightsValue != rhs.highlightsValue {
            return false
        }
        if lhs.shadowsValue != rhs.shadowsValue {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var section: Section
        var shadowsValue: TintValue
        var highlightsValue: TintValue
        
        init(section: Section, shadowsValue: TintValue, highlightsValue: TintValue) {
            self.section = section
            self.shadowsValue = shadowsValue
            self.highlightsValue = highlightsValue
        }
    }
    
    func makeState() -> State {
        return State(section: .shadows, shadowsValue: self.shadowsValue, highlightsValue: self.highlightsValue)
    }
    
    final class View: UIView {
        private var shadowsButton = ComponentView<Empty>()
        private var highlightsButton = ComponentView<Empty>()
        private var colorViews: [ComponentView<Empty>] = []
        private var slider = ComponentView<Empty>()
        
        private var component: TintComponent?
        private weak var state: State?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: TintComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            state.shadowsValue = component.shadowsValue
            state.highlightsValue = component.highlightsValue
        
            let shadowsValueUpdated = component.shadowsValueUpdated
            let highlightsValueUpdated = component.highlightsValueUpdated
                        
            let topInset: CGFloat = 11.0
            let shadowsButtonSize = self.shadowsButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            Text(
                                text: component.strings.Story_Editor_Tint_Shadows,
                                font: Font.regular(14.0),
                                color: state.section == .shadows ? .white : UIColor(rgb: 0x808080)
                            )
                        ),
                        action: { [weak state] in
                            state?.section = .shadows
                            state?.updated()
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let shadowsButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(availableSize.width / 3.0 - shadowsButtonSize.width / 2.0), y: topInset), size: shadowsButtonSize)
            if let view = self.shadowsButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: shadowsButtonFrame)
            }
            
            let highlightsButtonSize = self.highlightsButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            Text(
                                text: component.strings.Story_Editor_Tint_Highlights,
                                font: Font.regular(14.0),
                                color: state.section == .highlights ? .white : UIColor(rgb: 0x808080)
                            )
                        ),
                        action: { [weak state] in
                            state?.section = .highlights
                            state?.updated()
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let highlightsButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(availableSize.width / 3.0 * 2.0 - highlightsButtonSize.width / 2.0), y: topInset), size: highlightsButtonSize)
            if let view = self.highlightsButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: highlightsButtonFrame)
            }
                        
            let currentColor: UIColor
            let colors: [UIColor]
            switch state.section {
            case .shadows:
                currentColor = component.shadowsValue.color
                colors = [
                    UIColor.clear,
                    UIColor(rgb: 0xff4d4d),
                    UIColor(rgb: 0xf48022),
                    UIColor(rgb: 0xffcd00),
                    UIColor(rgb: 0x81d281),
                    UIColor(rgb: 0x71c5d6),
                    UIColor(rgb: 0x0072bc),
                    UIColor(rgb: 0x662d91)
                ]
            case .highlights:
                currentColor = component.highlightsValue.color
                colors = [
                    UIColor.clear,
                    UIColor(rgb: 0xef9286),
                    UIColor(rgb: 0xeacea2),
                    UIColor(rgb: 0xf2e17c),
                    UIColor(rgb: 0xa4edae),
                    UIColor(rgb: 0x89dce5),
                    UIColor(rgb: 0x2e8bc8),
                    UIColor(rgb: 0xcd98e5)
                ]
            }
            
            var sizes: [CGSize] = []
            for i in 0 ..< colors.count {
                let color = colors[i]
                let componentView: ComponentView<Empty>
                if i >= self.colorViews.count {
                    componentView = ComponentView<Empty>()
                    self.colorViews.append(componentView)
                } else {
                    componentView = self.colorViews[i]
                }
                
                let size = componentView.update(
                    transition: transition,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                TintColorComponent(
                                    color: color,
                                    isSelected: color == currentColor
                                )
                            ),
                            action: { [weak state] in
                                if let state {
                                    switch state.section {
                                    case .shadows:
                                        shadowsValueUpdated(state.shadowsValue.withUpdatedColor(color))
                                    case .highlights:
                                        highlightsValueUpdated(state.highlightsValue.withUpdatedColor(color))
                                    }
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                sizes.append(size)
            }
            
            let isTrackingUpdated: (Bool) -> Void = { [weak self] isTracking in
                component.isTrackingUpdated(isTracking)
                
                if let self {
                    let transition: Transition
                    if isTracking {
                        transition = .immediate
                    } else {
                        transition = .easeInOut(duration: 0.25)
                    }
                    
                    let alpha: CGFloat = isTracking ? 0.0 : 1.0
                    if let view = self.shadowsButton.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                    if let view = self.highlightsButton.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                    for color in self.colorViews {
                        if let view = color.view {
                            transition.setAlpha(view: view, alpha: alpha)
                        }
                    }
                }
            }
            
            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(
                    AdjustmentSliderComponent(
                        title: "",
                        value: state.section == .shadows ? component.shadowsValue.intensity : component.highlightsValue.intensity,
                        minValue: 0.0,
                        maxValue: 1.0,
                        startValue: 0.0,
                        isEnabled: currentColor != .clear,
                        trackColor: currentColor != .clear ? currentColor : .white,
                        displayValue: false,
                        valueUpdated: { [weak state] value in
                            if let state {
                                switch state.section {
                                case .shadows:
                                    shadowsValueUpdated(state.shadowsValue.withUpdatedIntensity(value))
                                case .highlights:
                                    highlightsValueUpdated(state.highlightsValue.withUpdatedIntensity(value))
                                }
                            }
                        },
                        isTrackingUpdated: { isTracking in
                            isTrackingUpdated(isTracking)
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let colorsVerticalSpacing: CGFloat = 9.0
            let leftInset: CGFloat = 30.0
            let itemSpacing = min(33.0, floorToScreenPixels((availableSize.width - leftInset * 2.0 - sizes.first!.width * CGFloat(colors.count)) / CGFloat(colors.count - 1)))
            let finalLeftInset: CGFloat = floorToScreenPixels((availableSize.width - ((sizes.first!.width + itemSpacing) * CGFloat(colors.count) - itemSpacing)) / 2.0)
            
            var origin: CGPoint = CGPoint(x: finalLeftInset, y: topInset + highlightsButtonSize.height + colorsVerticalSpacing)
            for i in 0 ..< colors.count {
                let size = sizes[i]
                let componentView = self.colorViews[i]
                
                if let view = componentView.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: origin, size: size))
                }
                origin = origin.offsetBy(dx: size.width + itemSpacing, dy: 0.0)
            }
            
            let verticalSpacing: CGFloat = 3.0
            let sliderFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset + highlightsButtonSize.height + verticalSpacing + sizes.first!.height + verticalSpacing), size: sliderSize)
            if let view = self.slider.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: sliderFrame)
            }
            
            return CGSize(width: availableSize.width, height: topInset + highlightsButtonSize.height + colorsVerticalSpacing + sizes.first!.height + verticalSpacing + sliderSize.height)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

