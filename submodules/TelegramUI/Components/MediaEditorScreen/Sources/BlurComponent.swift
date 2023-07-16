import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import MediaEditor
import TelegramPresentationData

private final class BlurModeComponent: Component {
    typealias EnvironmentType = Empty
    
    let title: String
    let icon: UIImage?
    let isSelected: Bool
    
    init(
        title: String,
        icon: UIImage?,
        isSelected: Bool
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
    }
    
    static func ==(lhs: BlurModeComponent, rhs: BlurModeComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.icon !== rhs.icon {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
                
        private var component: BlurModeComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
               
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: BlurModeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
                        
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(
                    Image(
                        image: component.icon,
                        tintColor: component.isSelected ? UIColor(rgb: 0xf8d74a) : .white,
                        size: CGSize(width: 30.0, height: 30.0)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(
                        text: component.title,
                        font: Font.regular(14.0),
                        color: component.isSelected ? UIColor(rgb: 0xf8d74a) : UIColor(rgb: 0x808080)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let spacing: CGFloat = 3.0
            let size = CGSize(width: 66.0, height: iconSize.height + spacing + titleSize.height)
            
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: 0.0), size: iconSize)
            if let view = self.icon.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: iconFrame)
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: iconSize.height + spacing), size: titleSize)
            if let view = self.title.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: titleFrame)
            }
            
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

final class BlurComponent: Component {
    typealias EnvironmentType = Empty
    
    let strings: PresentationStrings
    let value: BlurValue
    let hasPortrait: Bool
    let valueUpdated: (BlurValue) -> Void
    let isTrackingUpdated: (Bool) -> Void
    
    init(
        strings: PresentationStrings,
        value: BlurValue,
        hasPortrait: Bool,
        valueUpdated: @escaping (BlurValue) -> Void,
        isTrackingUpdated: @escaping (Bool) -> Void
    ) {
        self.strings = strings
        self.value = value
        self.hasPortrait = hasPortrait
        self.valueUpdated = valueUpdated
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    static func ==(lhs: BlurComponent, rhs: BlurComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.hasPortrait != rhs.hasPortrait {
            return false
        }
        return true
    }
    
    func makeState() -> State {
        return State(value: self.value)
    }
    
    final class State: ComponentState {
        var value: BlurValue
        
        init(value: BlurValue) {
            self.value = value
        }
    }
    
    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let offButton = ComponentView<Empty>()
        private let radialButton = ComponentView<Empty>()
        private let linearButton = ComponentView<Empty>()
        private let portraitButton = ComponentView<Empty>()
        
        private let slider = ComponentView<Empty>()
        
        private var component: BlurComponent?
        private weak var state: State?
        
        private let offImage = UIImage(bundleImageName: "Media Editor/BlurOff")
        private let radialImage = UIImage(bundleImageName: "Media Editor/BlurRadial")
        private let linearImage = UIImage(bundleImageName: "Media Editor/BlurLinear")
        private let portraitImage = UIImage(bundleImageName: "Media Editor/BlurPortrait")
                
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: BlurComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            state.value = component.value
            
            let valueUpdated = component.valueUpdated
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(
                        text: component.strings.Story_Editor_Blur_Title,
                        font: Font.regular(14.0),
                        color: UIColor(rgb: 0x808080)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 11.0), size: titleSize)
            if let view = self.title.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: titleFrame)
            }
            
            let offButtonSize = self.offButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            BlurModeComponent(
                                title: component.strings.Story_Editor_Blur_Off,
                                icon: self.offImage,
                                isSelected: state.value.mode == .off
                            )
                        ),
                        action: { [weak state] in
                            if let state {
                                valueUpdated(state.value.withUpdatedMode(.off))
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let _ = self.radialButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            BlurModeComponent(
                                title: component.strings.Story_Editor_Blur_Radial,
                                icon: self.radialImage,
                                isSelected: state.value.mode == .radial
                            )
                        ),
                        action: { [weak state] in
                            if let state {
                                valueUpdated(state.value.withUpdatedMode(.radial))
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let _ = self.linearButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            BlurModeComponent(
                                title: component.strings.Story_Editor_Blur_Linear,
                                icon: self.linearImage,
                                isSelected: state.value.mode == .linear
                            )
                        ),
                        action: { [weak state] in
                            if let state {
                                valueUpdated(state.value.withUpdatedMode(.linear))
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let _ = self.portraitButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            BlurModeComponent(
                                title: component.strings.Story_Editor_Blur_Portrait,
                                icon: self.portraitImage,
                                isSelected: state.value.mode == .portrait
                            )
                        ),
                        action: { [weak state] in
                            if let state {
                                valueUpdated(state.value.withUpdatedMode(.portrait))
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
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
                    if let view = self.title.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                    if let view = self.offButton.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                    if let view = self.radialButton.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                    if let view = self.linearButton.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                    if let view = self.portraitButton.view {
                        transition.setAlpha(view: view, alpha: alpha)
                    }
                }
            }

            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(
                    AdjustmentSliderComponent(
                        title: "",
                        value: state.value.intensity,
                        minValue: 0.0,
                        maxValue: 1.0,
                        startValue: 0.0,
                        isEnabled: state.value.mode != .off,
                        trackColor: nil,
                        displayValue: false,
                        valueUpdated: { [weak state] value in
                            if let state {
                                valueUpdated(state.value.withUpdatedIntensity(value))
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
            
            var buttons = [self.offButton, self.radialButton, self.linearButton]
            if component.hasPortrait {
                buttons.append(self.portraitButton)
            }
            
            let topInset: CGFloat = 34.0
            let horizontalSpacing: CGFloat = 24.0
            let width: CGFloat = CGFloat(buttons.count) * offButtonSize.width + (CGFloat(buttons.count - 1) * horizontalSpacing)
            let commonX = floorToScreenPixels((availableSize.width - width) / 2.0)
            var offsetX: CGFloat = commonX
            for button in buttons {
                if let view = button.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: offsetX, y: topInset), size: offButtonSize))
                }
                offsetX += offButtonSize.width + horizontalSpacing
            }
            
            let verticalSpacing: CGFloat = -5.0
            let sliderFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset + offButtonSize.height + verticalSpacing), size: sliderSize)
            if let view = self.slider.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: sliderFrame)
            }
            
            return CGSize(width: availableSize.width, height: topInset + offButtonSize.height + verticalSpacing + sliderSize.height + 6.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private let blurInsetProximity: CGFloat = 20.0
private let blurMinimumFalloff: Float = 0.1
private let blurMinimumDifference: Float = 0.02
private let blurViewCenterInset: CGFloat = 30.0
private let blurViewRadiusInset: CGFloat = 30.0

final class BlurScreenComponent: Component {
    typealias EnvironmentType = Empty
    
    let value: BlurValue
    let valueUpdated: (BlurValue) -> Void
    let isTrackingUpdated: (Bool) -> Void
    
    init(
        value: BlurValue,
        valueUpdated: @escaping (BlurValue) -> Void,
        isTrackingUpdated: @escaping (Bool) -> Void
        
    ) {
        self.value = value
        self.valueUpdated = valueUpdated
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    static func ==(lhs: BlurScreenComponent, rhs: BlurScreenComponent) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        enum Control {
            case center
            case innerRadius
            case outerRadius
            case rotation
            case wholeArea
        }
        private var component: BlurScreenComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .clear
            self.contentMode = .redraw
            self.isOpaque = false
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            panGestureRecognizer.delegate = self
            self.addGestureRecognizer(panGestureRecognizer)
            
            let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch(_:)))
            pinchGestureRecognizer.delegate = self
            self.addGestureRecognizer(pinchGestureRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        private var activeControl: Control?
        private var startCenterPoint: CGPoint?
        private var startDistance: CGFloat?
        private var startRadius: CGFloat?
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            let centerPoint = CGPoint(
                x: component.value.position.x * self.frame.width,
                y: component.value.position.y * self.frame.height
            )
            let delta = CGPoint(x: location.x - centerPoint.x, y: location.y - centerPoint.y)
            let shorterSide = min(self.frame.width, self.frame.height)
            let innerRadius = shorterSide * CGFloat(component.value.falloff)
            let outerRadius = shorterSide * CGFloat(component.value.size)
            
            switch gestureRecognizer.state {
            case .began:
                switch component.value.mode {
                case .radial:
                    component.isTrackingUpdated(true)
                    let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
                    
                    let close = abs(outerRadius - innerRadius) < blurInsetProximity
                    let innerRadiusOuterInset = close ? 0 : blurViewRadiusInset
                    let outerRadiusInnerInset = close ? 0 : blurViewRadiusInset
                    
                    if distance < blurViewCenterInset {
                        self.activeControl = .center
                        self.startCenterPoint = centerPoint
                    }
                    else if distance > innerRadius - blurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset {
                        self.activeControl = .innerRadius
                        self.startDistance = distance
                        self.startRadius = innerRadius
                    } else if distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + blurViewRadiusInset {
                        self.activeControl = .outerRadius
                        self.startDistance = distance
                        self.startRadius = outerRadius
                    }
                case .linear:
                    component.isTrackingUpdated(true)
                    let radialDistance = sqrt(delta.x * delta.x + delta.y * delta.y)
                    let distance = abs(delta.x * cos(CGFloat(component.value.rotation) + .pi / 2.0) + delta.y * sin(CGFloat(component.value.rotation) + .pi / 2.0))
                    
                    let close = abs(outerRadius - innerRadius) < blurInsetProximity
                    let innerRadiusOuterInset = close ? 0 : blurViewRadiusInset
                    let outerRadiusInnerInset = close ? 0 : blurViewRadiusInset
                    
                    if radialDistance < blurViewCenterInset {
                        self.activeControl = .center
                        self.startCenterPoint = centerPoint
                    } else if distance > innerRadius - blurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset {
                        self.activeControl = .innerRadius
                        self.startDistance = distance
                        self.startRadius = innerRadius
                    } else if distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + blurViewRadiusInset {
                        self.activeControl = .outerRadius;
                        self.startDistance = distance
                        self.startRadius = outerRadius
                    } else if distance <= innerRadius - blurViewRadiusInset || distance >= outerRadius + blurViewRadiusInset {
                        self.activeControl = .rotation
                    }
                default:
                    break
                }
            case .changed:
                switch component.value.mode {
                case .radial:
                    guard let activeControl = self.activeControl else {
                        return
                    }
                    let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
                    
                    switch activeControl {
                    case .center:
                        guard let startCenterPoint = self.startCenterPoint else {
                            return
                        }
                        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
                        let centerPoint = CGPoint(
                            x: max(0.0, min(self.frame.width, startCenterPoint.x + translation.x)),
                            y: max(0.0, min(self.frame.height, startCenterPoint.y + translation.y))
                        )
                        let position = CGPoint(
                            x: centerPoint.x / self.frame.width,
                            y: centerPoint.y / self.frame.height
                        )
                        component.valueUpdated(component.value.withUpdatedPosition(position))
                    case .innerRadius:
                        guard let startDistance = self.startDistance, let startRadius = self.startRadius else {
                            return
                        }
                        let delta = distance - startDistance
                        let falloff = min(max(blurMinimumFalloff, Float((startRadius + delta) / shorterSide)), component.value.size - blurMinimumDifference)
                        component.valueUpdated(component.value.withUpdatedFalloff(falloff))
                    case .outerRadius:
                        guard let startDistance = self.startDistance, let startRadius = self.startRadius else {
                            return
                        }
                        let delta = distance - startDistance
                        let size = max(component.value.falloff + blurMinimumDifference, Float((startRadius + delta) / shorterSide))
                        component.valueUpdated(component.value.withUpdatedSize(size))
                    default:
                        break
                    }
                case .linear:
                    guard let activeControl = self.activeControl else {
                        return
                    }
                    let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
                    
                    switch activeControl {
                    case .center:
                        guard let startCenterPoint = self.startCenterPoint else {
                            return
                        }
                        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
                        let centerPoint = CGPoint(
                            x: max(0.0, min(self.frame.width, startCenterPoint.x + translation.x)),
                            y: max(0.0, min(self.frame.height, startCenterPoint.y + translation.y))
                        )
                        let position = CGPoint(
                            x: centerPoint.x / self.frame.width,
                            y: centerPoint.y / self.frame.height
                        )
                        component.valueUpdated(component.value.withUpdatedPosition(position))
                    case .innerRadius:
                        guard let startDistance = self.startDistance, let startRadius = self.startRadius else {
                            return
                        }
                        let delta = distance - startDistance
                        let falloff = min(max(blurMinimumFalloff, Float((startRadius + delta) / shorterSide)), component.value.size - blurMinimumDifference)
                        component.valueUpdated(component.value.withUpdatedFalloff(falloff))
                    case .outerRadius:
                        guard let startDistance = self.startDistance, let startRadius = self.startRadius else {
                            return
                        }
                        let delta = distance - startDistance
                        let size = max(component.value.falloff + blurMinimumDifference, Float((startRadius + delta) / shorterSide))
                        component.valueUpdated(component.value.withUpdatedSize(size))
                    case .rotation:
                        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
                        var clockwise = false
                        let right = location.x > centerPoint.x
                        let bottom = location.y > centerPoint.y
                        
                        if !right && !bottom {
                            if abs(translation.y) > abs(translation.x) {
                                if translation.y < 0.0 {
                                    clockwise = true
                                }
                            } else {
                                if translation.x > 0.0 {
                                    clockwise = true
                                }
                            }
                        } else if right && !bottom {
                            if abs(translation.y) > abs(translation.x) {
                                if translation.y > 0.0 {
                                    clockwise = true
                                }
                            } else
                            {
                                if translation.x > 0.0 {
                                    clockwise = true
                                }
                            }
                        } else if right && bottom {
                            if abs(translation.y) > abs(translation.x) {
                                if translation.y > 0 {
                                    clockwise = true
                                }
                            } else {
                                if translation.x < 0 {
                                    clockwise = true
                                }
                            }
                        } else {
                            if abs(translation.y) > abs(translation.x) {
                                if translation.y < 0 {
                                    clockwise = true
                                }
                            } else {
                                if translation.x < 0 {
                                    clockwise = true
                                }
                            }
                        }
                        
                        let delta = sqrt(translation.x * translation.x + translation.y * translation.y)
                        
                        let angleInDegress = radiansToDegrees(radians: CGFloat(component.value.rotation))
                        let updatedAngle = angleInDegress + delta * (clockwise ? 1.0 : -1.0) / .pi / 1.15
                        component.valueUpdated(component.value.withUpdatedRotation(Float(degreesToRadians(degrees: updatedAngle))))
                        
                        gestureRecognizer.setTranslation(.zero, in: gestureRecognizer.view)
                    default:
                        break
                    }
                default:
                    break
                }
            default:
                component.isTrackingUpdated(false)
                self.activeControl = nil
                self.startCenterPoint = nil
                self.startDistance = nil
                self.startRadius = nil
            }
        }
        
        @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            switch gestureRecognizer.state {
            case .began:
                component.isTrackingUpdated(true)
                self.activeControl = .wholeArea
            case .changed:
                let scale = Float(gestureRecognizer.scale)
                
                let size = max(component.value.falloff + blurMinimumDifference, component.value.size * scale)
                let falloff = max(blurMinimumFalloff, component.value.falloff * scale)
                component.valueUpdated(component.value.withUpdatedSize(size).withUpdatedFalloff(falloff))
                                
                gestureRecognizer.scale = 1.0
            default:
                component.isTrackingUpdated(false)
                self.activeControl = nil
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let component = self.component else {
                return false
            }
            
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            let centerPoint = CGPoint(
                x: component.value.position.x * self.frame.width,
                y: component.value.position.y * self.frame.height
            )
            let delta = CGPoint(x: location.x - centerPoint.x, y: location.y - centerPoint.y)
            let innerRadius = min(self.frame.width, self.frame.height) * CGFloat(component.value.falloff)
            let outerRadius = min(self.frame.width, self.frame.height) * CGFloat(component.value.size)
            
            switch component.value.mode {
            case .radial:
                let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
                
                let close = abs(outerRadius - innerRadius) < blurInsetProximity
                let innerRadiusOuterInset = close ? 0.0 : blurViewRadiusInset
                let outerRadiusInnerInset = close ? 0.0 : blurViewRadiusInset
                                
                if distance < blurViewCenterInset && gestureRecognizer is UIPanGestureRecognizer {
                    return true
                } else if distance > innerRadius - blurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset {
                    return true
                } else if distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + blurViewRadiusInset {
                    return true
                }
            case .linear:
                let radialDistance = sqrt(delta.x * delta.x + delta.y * delta.y)
                let distance = abs(delta.x * cos(CGFloat(component.value.rotation) + .pi / 2.0) + delta.y * sin(CGFloat(component.value.rotation) + .pi / 2.0))
                
                let close = abs(outerRadius - innerRadius) < blurInsetProximity
                let innerRadiusOuterInset = close ? 0.0 : blurViewRadiusInset
                let outerRadiusInnerInset = close ? 0.0 : blurViewRadiusInset
                
                if radialDistance < blurViewCenterInset && gestureRecognizer is UIPanGestureRecognizer {
                    return true
                } else if distance > innerRadius - blurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset {
                    return true
                } else if distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + blurViewRadiusInset {
                    return true
                } else if distance <= innerRadius - blurViewRadiusInset || distance >= outerRadius + blurViewRadiusInset {
                    return true
                }
            default:
                break
            }
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func update(component: BlurScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            self.setNeedsDisplay()
            
            return availableSize
        }
        
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext(), let component = self.component else {
                return
            }
            guard ![.off, .portrait].contains(component.value.mode) else {
                return
            }
            
            let centerPoint = CGPoint(
                x: component.value.position.x * rect.size.width,
                y: component.value.position.y * rect.size.height
            )
            let innerRadius = min(rect.size.width, rect.size.height) * CGFloat(component.value.falloff)
            let outerRadius = min(rect.size.width, rect.size.height) * CGFloat(component.value.size)
            
            context.setFillColor(UIColor.white.cgColor)
            context.setShadow(offset: .zero, blur: 2.5, color: UIColor(rgb: 0x000000, alpha: 0.3).cgColor)
            
            let knobSize = CGSize(width: 16.0, height: 16.0)
            switch component.value.mode {
            case .radial:
                var radSpace = degreesToRadians(degrees: 6.15)
                var radLen = degreesToRadians(degrees: 10.2)
                for i in 0 ..< 22 {
                    let cgPath = CGMutablePath()
                    cgPath.addArc(
                        center: centerPoint,
                        radius: innerRadius,
                        startAngle: CGFloat(i) * (radSpace + radLen),
                        endAngle: CGFloat(i) * (radSpace + radLen) + radLen,
                        clockwise: false
                    )
                    let strokedArc = cgPath.copy(strokingWithWidth: 1.5, lineCap: .butt, lineJoin: .miter, miterLimit: 10.0)
                    context.addPath(strokedArc)
                }
                
                radSpace = degreesToRadians(degrees: 2.02)
                radLen = degreesToRadians(degrees: 3.6)
                for i in 0 ..< 64 {
                    let cgPath = CGMutablePath()
                    cgPath.addArc(
                        center: centerPoint,
                        radius: outerRadius,
                        startAngle: CGFloat(i) * (radSpace + radLen),
                        endAngle: CGFloat(i) * (radSpace + radLen) + radLen,
                        clockwise: false
                    )
                    let strokedArc = cgPath.copy(strokingWithWidth: 1.5, lineCap: .butt, lineJoin: .miter, miterLimit: 10.0)
                    context.addPath(strokedArc)
                }
                context.fillPath()

                context.fillEllipse(in: CGRect(origin: CGPoint(x: centerPoint.x - knobSize.width / 2.0, y: centerPoint.y - knobSize.height / 2.0), size: knobSize))
            case .linear:
                context.translateBy(x: centerPoint.x, y: centerPoint.y)
                context.rotate(by: CGFloat(component.value.rotation))
                
                let space: CGFloat = 6.0
                var length: CGFloat = 12.0
                let thickness: CGFloat = 1.5
                
                for i in 0 ..< 30 {
                    context.addRect(CGRect(x: CGFloat(i) * (length + space), y: -innerRadius, width: length, height: thickness))
                    context.addRect(CGRect(x: CGFloat(-i) * (length + space) - space - length, y: -innerRadius, width: length, height: thickness))
                    
                    context.addRect(CGRect(x: CGFloat(i) * (length + space), y: innerRadius, width: length, height: thickness))
                    context.addRect(CGRect(x: CGFloat(-i) * (length + space) - space - length, y: innerRadius, width: length, height: thickness))
                }
                
                length = 6.0
                
                for i in 0 ..< 64 {
                    context.addRect(CGRect(x: CGFloat(i) * (length + space), y: -outerRadius, width: length, height: thickness))
                    context.addRect(CGRect(x: CGFloat(-i) * (length + space) - space - length, y: -outerRadius, width: length, height: thickness))
                    
                    context.addRect(CGRect(x: CGFloat(i) * (length + space), y: outerRadius, width: length, height: thickness))
                    context.addRect(CGRect(x: CGFloat(-i) * (length + space) - space - length, y: outerRadius, width: length, height: thickness))
                }
                
                context.fillPath()
                
                context.fillEllipse(in: CGRect(origin: CGPoint(x: -knobSize.width / 2.0, y: -knobSize.height / 2.0), size: knobSize))
            default:
                break
            }
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func degreesToRadians(degrees: CGFloat) -> CGFloat {
    return degrees * .pi / 180.0
}

private func radiansToDegrees(radians: CGFloat) -> CGFloat {
    return radians * 180.0 / .pi
}
