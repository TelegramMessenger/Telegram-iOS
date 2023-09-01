import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import LegacyComponents
import TelegramCore

private let toolSize = CGSize(width: 40.0, height: 176.0)

private class ToolView: UIView, UIGestureRecognizerDelegate {
    let type: DrawingToolState.Key
    
    var isSelected = false
    var isToolFocused = false
    var isVisible = false
    private var currentSize: CGFloat?
    
    private let shadow: SimpleLayer
    private let tip: UIImageView
    private let background: SimpleLayer
    private let band: SimpleGradientLayer
    
    var pressed: (DrawingToolState.Key) -> Void = { _ in }
    var swiped: (DrawingToolState.Key, CGFloat) -> Void = { _, _ in }
    var released: () -> Void = { }
    
    init(type: DrawingToolState.Key) {
        self.type = type
        self.shadow = SimpleLayer()
        
        self.tip = UIImageView()
        self.tip.isUserInteractionEnabled = false
        
        self.background = SimpleLayer()
        
        self.band = SimpleGradientLayer()
        self.band.cornerRadius = 2.0
        self.band.type = .axial
        self.band.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.band.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.band.masksToBounds = true
        
        let backgroundImage: UIImage?
        let tipImage: UIImage?
        let shadowImage: UIImage?
        
        var tipAbove = true
        var hasBand = true
                
        switch type {
        case .pen:
            backgroundImage = UIImage(bundleImageName: "Media Editor/ToolPen")
            tipImage = UIImage(bundleImageName: "Media Editor/ToolPenTip")?.withRenderingMode(.alwaysTemplate)
            shadowImage = UIImage(bundleImageName: "Media Editor/ToolPenShadow")
        case .arrow:
            backgroundImage = UIImage(bundleImageName: "Media Editor/ToolArrow")
            tipImage = UIImage(bundleImageName: "Media Editor/ToolArrowTip")?.withRenderingMode(.alwaysTemplate)
            shadowImage = UIImage(bundleImageName: "Media Editor/ToolArrowShadow")
        case .marker:
            backgroundImage = UIImage(bundleImageName: "Media Editor/ToolMarker")
            tipImage = UIImage(bundleImageName: "Media Editor/ToolMarkerTip")?.withRenderingMode(.alwaysTemplate)
            tipAbove = false
            shadowImage = UIImage(bundleImageName: "Media Editor/ToolMarkerShadow")
        case .neon:
            backgroundImage = UIImage(bundleImageName: "Media Editor/ToolNeon")
            tipImage = UIImage(bundleImageName: "Media Editor/ToolNeonTip")?.withRenderingMode(.alwaysTemplate)
            tipAbove = false
            shadowImage = UIImage(bundleImageName: "Media Editor/ToolNeonShadow")
        case .eraser:
            backgroundImage = UIImage(bundleImageName: "Media Editor/ToolEraser")
            tipImage = nil
            hasBand = false
            shadowImage = UIImage(bundleImageName: "Media Editor/ToolEraserShadow")
        case .blur:
            backgroundImage = UIImage(bundleImageName: "Media Editor/ToolBlur")
            tipImage = UIImage(bundleImageName: "Media Editor/ToolBlurTip")
            tipAbove = false
            hasBand = false
            shadowImage = UIImage(bundleImageName: "Media Editor/ToolBlurShadow")
        }
        
        self.tip.image = tipImage
        self.background.contents = backgroundImage?.cgImage
        self.shadow.contents = shadowImage?.cgImage
        
        super.init(frame: CGRect(origin: .zero, size: toolSize))
        
        self.tip.frame = CGRect(origin: .zero, size: toolSize)
        self.shadow.frame = CGRect(origin: .zero, size: toolSize).insetBy(dx: -4.0, dy: 0.0)
        self.background.frame = CGRect(origin: .zero, size: toolSize)
        
        self.band.frame = CGRect(origin: CGPoint(x: 3.0, y: 64.0), size: CGSize(width: toolSize.width - 6.0, height: toolSize.width - 16.0))
        self.band.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        
        self.layer.addSublayer(self.shadow)
        
        if tipAbove {
            self.layer.addSublayer(self.background)
            self.addSubview(self.tip)
        } else {
            self.addSubview(self.tip)
            self.layer.addSublayer(self.background)
        }
        
        if hasBand {
            self.layer.addSublayer(self.band)
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        self.addGestureRecognizer(panGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer {
            if self.isSelected {
                return true
            } else {
                return false
            }
        }
        return self.isVisible
    }
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        self.pressed(self.type)
    }

    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let size = self.currentSize else {
            return
        }
        switch gestureRecognizer.state {
        case .changed:
            let translation = gestureRecognizer.translation(in: self)
            gestureRecognizer.setTranslation(.zero, in: self)
            
            let updatedSize = max(0.0, min(1.0, size - translation.y / 200.0))
            self.swiped(self.type, updatedSize)
        case .ended, .cancelled:
            self.released()
        default:
            break
        }
    }
    
    func animateIn(animated: Bool, delay: Double = 0.0) {
        let layout = {
            self.bounds = CGRect(origin: .zero, size: self.bounds.size)
        }
        if animated {
            UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, animations: layout)
        } else {
            layout()
        }
    }
    
    func animateOut(animated: Bool, delay: Double = 0.0, completion: @escaping () -> Void = {}) {
        let layout = {
            self.bounds = CGRect(origin: CGPoint(x: 0.0, y: -140.0), size: self.bounds.size)
        }
        if animated {
            UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, animations: layout, completion: { _ in
                completion()
            })
        } else {
            layout()
            completion()
        }
    }
    
    func update(state: DrawingToolState) {
        self.currentSize = state.size
        
        if let _ = self.tip.image {
            let color = state.color?.toUIColor()
            self.tip.tintColor = color
            
            guard let color = color else {
                return
            }
            var locations: [NSNumber] = [0.0, 1.0]
            var colors: [CGColor] = []
            switch self.type {
                case .pen, .arrow:
                    locations = [0.0, 0.15, 0.85, 1.0]
                    colors = [
                        color.withMultipliedBrightnessBy(0.7).cgColor,
                        color.cgColor,
                        color.cgColor,
                        color.withMultipliedBrightnessBy(0.7).cgColor
                    ]
                case .marker:
                    locations = [0.0, 0.15, 0.85, 1.0]
                    colors = [
                        color.withMultipliedBrightnessBy(0.7).cgColor,
                        color.cgColor,
                        color.cgColor,
                        color.withMultipliedBrightnessBy(0.7).cgColor
                    ]
                case .neon:
                    locations = [0.0, 0.15, 0.85, 1.0]
                    colors = [
                        color.withMultipliedBrightnessBy(0.7).cgColor,
                        color.cgColor,
                        color.cgColor,
                        color.withMultipliedBrightnessBy(0.7).cgColor
                    ]
                default:
                    return
            }
                 
            self.band.transform = CATransform3DMakeScale(1.0, 0.08 + 0.92 * (state.size ?? 1.0), 1.0)
            
            self.band.locations = locations
            self.band.colors = colors
        }
    }
}

final class ToolsComponent: Component {
    let state: DrawingState
    let isFocused: Bool
    let tag: AnyObject?
    let toolPressed: (DrawingToolState.Key) -> Void
    let toolResized: (DrawingToolState.Key, CGFloat) -> Void
    let sizeReleased: () -> Void
    
    init(state: DrawingState, isFocused: Bool, tag: AnyObject?, toolPressed: @escaping (DrawingToolState.Key) -> Void, toolResized: @escaping (DrawingToolState.Key, CGFloat) -> Void, sizeReleased: @escaping () -> Void) {
        self.state = state
        self.isFocused = isFocused
        self.tag = tag
        self.toolPressed = toolPressed
        self.toolResized = toolResized
        self.sizeReleased = sizeReleased
    }
    
    static func == (lhs: ToolsComponent, rhs: ToolsComponent) -> Bool {
        return lhs.state == rhs.state && lhs.isFocused == rhs.isFocused
    }
    
    public final class View: UIView, ComponentTaggedView {
        private var toolViews: [ToolView] = []
        private let maskImageView: UIImageView
        
        private var isToolFocused: Bool?
        
        private var component: ToolsComponent?
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        override init(frame: CGRect) {
            self.maskImageView = UIImageView()
            self.maskImageView.image = generateGradientImage(size: CGSize(width: 1.0, height: 120.0), colors: [UIColor.white, UIColor.white, UIColor.white.withAlphaComponent(0.0)], locations: [0.0, 0.88, 1.0], direction: .vertical)
            
            super.init(frame: frame)
            
            self.mask = self.maskImageView
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result === self {
                return nil
            }
            return result
        }
        
        func animateIn(completion: @escaping () -> Void) {
            var delay = 0.0
            for i in 0 ..< self.toolViews.count {
                let view = self.toolViews[i]
                view.animateOut(animated: false)
                view.animateIn(animated: true, delay: delay)
                delay += 0.025
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
            var delay = 0.0
            for i in 0 ..< self.toolViews.count {
                let view = self.toolViews[i]
                view.animateOut(animated: true, delay: delay, completion: i == self.toolViews.count - 1 ? completion : {})
                delay += 0.025
                
                transition.setPosition(view: view, position: CGPoint(x: view.center.x, y: toolSize.height / 2.0 - 30.0 + 34.0))
            }
        }
        
        func update(component: ToolsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            if self.toolViews.isEmpty {
                var toolViews: [ToolView] = []
                for type in DrawingToolState.Key.allCases {
                    if component.state.tools.contains(where: { $0.key == type }) {
                        let toolView = ToolView(type: type)
                        toolViews.append(toolView)
                        self.addSubview(toolView)
                    }
                }
                self.toolViews = toolViews
            }
            
            let wasFocused = self.isToolFocused
            
            self.isToolFocused = component.isFocused
            
            let toolPressed = component.toolPressed
            let toolResized = component.toolResized
            let toolSizeReleased = component.sizeReleased
            
            let spacing: CGFloat = 44.0
            let totalWidth = spacing * CGFloat(self.toolViews.count - 1)
            
            let left = (availableSize.width - totalWidth) / 2.0
            var xPositions: [CGFloat] = []
            
            var selectedIndex = 0
            let isFocused = component.isFocused
            
            for i in 0 ..< self.toolViews.count {
                xPositions.append(left + spacing * CGFloat(i))
                
                if self.toolViews[i].type == component.state.selectedTool {
                    selectedIndex = i
                }
            }
            
            if isFocused {
                let originalFocusedToolPosition = xPositions[selectedIndex]
                xPositions[selectedIndex] = availableSize.width / 2.0
                
                let delta = availableSize.width / 2.0 - originalFocusedToolPosition
                
                for i in 0 ..< xPositions.count {
                    if i != selectedIndex {
                        xPositions[i] += delta
                    }
                }
            }
            
            var offset: CGFloat = 100.0
            for i in 0 ..< self.toolViews.count {
                let view = self.toolViews[i]
                
                var scale = 0.5
                var verticalOffset: CGFloat = 30.0
                if i == selectedIndex {
                    if isFocused {
                        scale = 1.0
                        verticalOffset = 30.0
                    } else {
                        verticalOffset = 18.0
                    }
                    view.isSelected = true
                    view.isToolFocused = isFocused
                    view.isVisible = true
                } else {
                    view.isSelected = false
                    view.isToolFocused = false
                    view.isVisible = !isFocused
                }
                view.isUserInteractionEnabled = view.isVisible
                
                let layout = {
                    view.center = CGPoint(x: xPositions[i], y: toolSize.height / 2.0 - 30.0 + verticalOffset)
                    view.transform = CGAffineTransform(scaleX: scale, y: scale)
                }
                if case .curve = transition.animation {
                    UIView.animate(
                        withDuration: 0.7,
                        delay: 0.0,
                        usingSpringWithDamping: 0.6,
                        initialSpringVelocity: 0.0,
                        options: .allowUserInteraction,
                        animations: layout)
                } else {
                    layout()
                }
                
                view.update(state: component.state.toolState(for: view.type))
                
                view.pressed = { type in
                    toolPressed(type)
                }
                view.swiped = { type, size in
                    toolResized(type, size)
                }
                view.released = {
                    toolSizeReleased()
                }
                
                offset += 44.0
            }
            

            if wasFocused != nil && wasFocused != component.isFocused {
                var animated = false
                if case .curve = transition.animation {
                    animated = true
                }
                if isFocused {
                    var delay = 0.0
                    for i in (selectedIndex + 1 ..< self.toolViews.count).reversed() {
                        let view = self.toolViews[i]
                        view.animateOut(animated: animated, delay: delay)
                        delay += 0.025
                    }
                    delay = 0.0
                    for i in (0 ..< selectedIndex) {
                        let view = self.toolViews[i]
                        view.animateOut(animated: animated, delay: delay)
                        delay += 0.025
                    }
                } else {
                    var delay = 0.0
                    for i in (selectedIndex + 1 ..< self.toolViews.count) {
                        let view = self.toolViews[i]
                        view.animateIn(animated: animated, delay: delay)
                        delay += 0.025
                    }
                    delay = 0.0
                    for i in (0 ..< selectedIndex).reversed() {
                        let view = self.toolViews[i]
                        view.animateIn(animated: animated, delay: delay)
                        delay += 0.025
                    }
                }
            }

            self.maskImageView.frame = CGRect(origin: .zero, size: availableSize)
            
            if let screenTransition = transition.userData(DrawingScreenTransition.self) {
                switch screenTransition {
                case .animateIn:
                    self.animateIn(completion: {})
                case .animateOut:
                    self.animateOut(completion: {})
                }
            }
         
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ZoomOutButtonContent: CombinedComponent {
    let title: String
    let image: UIImage
  
    init(
        title: String,
        image: UIImage
    ) {
        self.title = title
        self.image = image
    }
    
    static func ==(lhs: ZoomOutButtonContent, rhs: ZoomOutButtonContent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.image !== rhs.image {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(Text.self)
        let image = Child(Image.self)
        
        return { context in
            let component = context.component
            
            let title = title.update(
                component: Text(
                    text: component.title,
                    font: Font.regular(17.0),
                    color: .white
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let image = image.update(
                component: Image(image: component.image),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: .immediate
            )
            
            let spacing: CGFloat = 2.0
            let width = title.size.width + spacing + image.size.width
            context.add(image
                .position(CGPoint(x: image.size.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            context.add(title
                .position(CGPoint(x: image.size.width + spacing + title.size.width / 2.0, y: context.availableSize.height / 2.0))
            )
                      
            return CGSize(width: width, height: context.availableSize.height)
        }
    }
}
