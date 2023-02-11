import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData

final class BackgroundColorComponent: Component {
    let theme: PresentationTheme
    let values: [AvatarBackground]
    let selectedValue: AvatarBackground
    let customValue: AvatarBackground?
    let updateValue: (AvatarBackground) -> Void
    let openColorPicker: () -> Void
    
    init(
        theme: PresentationTheme,
        values: [AvatarBackground],
        selectedValue: AvatarBackground,
        customValue: AvatarBackground?,
        updateValue: @escaping (AvatarBackground) -> Void,
        openColorPicker: @escaping () -> Void
    ) {
        self.theme = theme
        self.values = values
        self.selectedValue = selectedValue
        self.customValue = customValue
        self.updateValue = updateValue
        self.openColorPicker = openColorPicker
    }
    
    static func ==(lhs: BackgroundColorComponent, rhs: BackgroundColorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.values != rhs.values {
            return false
        }
        if lhs.selectedValue != rhs.selectedValue {
            return false
        }
        if lhs.customValue != rhs.customValue {
            return false
        }
        return true
    }
    
    class View: UIView {
        private var views: [Int: ComponentView<Empty>] = [:]
        
        private var component: BackgroundColorComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BackgroundColorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var values: [(AvatarBackground?, Bool)] = component.values.map { ($0, false) }
            if let customValue = component.customValue {
                values.append((customValue, true))
            } else {
                values.append((nil, true))
            }
            
            let itemSize = CGSize(width: 30.0, height: 30.0)
            let sideInset: CGFloat = 12.0
            let height: CGFloat = 50.0
            let delta = floorToScreenPixels((availableSize.width - sideInset * 2.0 - CGFloat(values.count) * itemSize.width) / CGFloat(values.count - 1))
            
            for i in 0 ..< values.count {
                let view: ComponentView<Empty>
                if let current = self.views[i] {
                    view = current
                } else {
                    view = ComponentView<Empty>()
                    self.views[i] = view
                }
                
                let itemSize = view.update(
                    transition: transition,
                    component: AnyComponent(
                        BackgroundSwatchComponent(
                            theme: component.theme,
                            background: values[i].0,
                            isCustom: values[i].1,
                            isSelected: component.selectedValue == values[i].0,
                            action: {
                                if let value = values[i].0, component.selectedValue != value {
                                    component.updateValue(value)
                                } else if values[i].1 {
                                    component.openColorPicker()
                                }
                            }
                        )
                    ),
                    environment: {},
                    containerSize: itemSize
                )
                if let itemView = view.view {
                    if itemView.superview == nil {
                        self.addSubview(itemView)
                    }
                    
                    let position: CGFloat = sideInset + (delta + itemSize.width) * CGFloat(i)
                    transition.setFrame(view: itemView, frame: CGRect(origin: CGPoint(x: position, y: 10.0), size: itemSize))
                }
            }
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateAddIcon(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        
        context.move(to: CGPoint(x: 15.0, y: 9.0))
        context.addLine(to: CGPoint(x: 15.0, y: 21.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 9.0, y: 15.0))
        context.addLine(to: CGPoint(x: 21.0, y: 15.0))
        context.strokePath()
    })
}

private func generateMoreIcon() -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setFillColor(UIColor.white.cgColor)
               
        context.addEllipse(in: CGRect(x: 8.5, y: 13.5, width: 3.0, height: 3.0))
        context.fillPath()
        
        context.addEllipse(in: CGRect(x: 13.5, y: 13.5, width: 3.0, height: 3.0))
        context.fillPath()
        
        context.addEllipse(in: CGRect(x: 18.5, y: 13.5, width: 3.0, height: 3.0))
        context.fillPath()
    })
}

final class BackgroundSwatchComponent: Component {
    let theme: PresentationTheme
    let background: AvatarBackground?
    let isCustom: Bool
    let isSelected: Bool
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        background: AvatarBackground?,
        isCustom: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.background = background
        self.isCustom = isCustom
        self.isSelected = isSelected
        self.action = action
    }
    
    static func == (lhs: BackgroundSwatchComponent, rhs: BackgroundSwatchComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.background == rhs.background && lhs.isCustom == rhs.isCustom && lhs.isSelected == rhs.isSelected
    }
    
    final class View: UIButton {
        private var component: BackgroundSwatchComponent?
        
        private let maskLayer: SimpleLayer
        private let ringMaskLayer: SimpleShapeLayer
        private let circleMaskLayer: SimpleShapeLayer
        
        private let iconLayer: SimpleLayer
        
        private var currentIsHighlighted: Bool = false {
            didSet {
                if self.currentIsHighlighted != oldValue {
                    self.alpha = self.currentIsHighlighted ? 0.6 : 1.0
                }
            }
        }
                
        override init(frame: CGRect) {
            self.maskLayer = SimpleLayer()
            self.ringMaskLayer = SimpleShapeLayer()
            self.circleMaskLayer = SimpleShapeLayer()
            self.iconLayer = SimpleLayer()
          
            super.init(frame: frame)
            
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
        
        func update(component: BackgroundSwatchComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousBackground = self.component?.background
            self.component = component
            
            let contentSize = availableSize
            let bounds = CGRect(origin: .zero, size: contentSize)
  
            self.layer.allowsGroupOpacity = true
            
            if self.layer.mask == nil {
                self.layer.mask = self.maskLayer
                self.maskLayer.frame = bounds
                
                self.maskLayer.addSublayer(self.circleMaskLayer)
                self.maskLayer.addSublayer(self.ringMaskLayer)
                
                self.circleMaskLayer.frame = bounds
                if self.circleMaskLayer.path == nil {
                    self.circleMaskLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 3.0, dy: 3.0)).cgPath
                }
                
                let ringFrame = bounds
                self.ringMaskLayer.frame = CGRect(origin: .zero, size: ringFrame.size)
                self.ringMaskLayer.strokeColor = UIColor.white.cgColor
                self.ringMaskLayer.fillColor = UIColor.clear.cgColor
                self.ringMaskLayer.lineWidth = 2.0 - UIScreenPixel
                self.ringMaskLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: ringFrame.size).insetBy(dx: 1.0, dy: 1.0)).cgPath
                
                self.layer.addSublayer(self.iconLayer)
            }
            
            self.iconLayer.frame = bounds
            if component.isCustom {
                if previousBackground != component.background || self.iconLayer.contents == nil {
                    if component.background != nil {
                        self.iconLayer.contents = generateMoreIcon()?.cgImage
                    } else {
                        self.iconLayer.contents = generateAddIcon(color: component.theme.list.itemAccentColor)?.cgImage
                    }
                }
            } else {
                self.iconLayer.contents = nil
            }
            
            if component.isSelected {
                transition.setShapeLayerPath(layer: self.circleMaskLayer, path: CGPath(ellipseIn: bounds.insetBy(dx: 3.0, dy: 3.0), transform: nil))
            } else {
                transition.setShapeLayerPath(layer: self.circleMaskLayer, path: CGPath(ellipseIn: bounds, transform: nil))
            }
            
            if previousBackground != component.background {
                if let background = component.background {
                    self.layer.backgroundColor = nil
                    self.layer.contents = background.generateImage(size: availableSize).cgImage
                } else {
                    self.layer.backgroundColor = component.theme.list.itemAccentColor.withAlphaComponent(0.1).cgColor
                    self.layer.contents = nil
                }
            } else if component.background == nil {
                self.layer.backgroundColor = component.theme.list.itemAccentColor.withAlphaComponent(0.1).cgColor
                self.layer.contents = nil
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
