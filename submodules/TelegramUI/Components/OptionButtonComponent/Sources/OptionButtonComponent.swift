import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

public final class OptionButtonComponent: Component {
    public struct Colors: Equatable {
        public var background: UIColor
        public var foreground: UIColor

        public init(
            background: UIColor,
            foreground: UIColor
        ) {
            self.background = background
            self.foreground = foreground
        }
    }

    public let colors: Colors
    public let icon: String
    public let action: () -> Void
    
    public init(
        colors: Colors,
        icon: String,
        action: @escaping () -> Void
    ) {
        self.colors = colors
        self.icon = icon
        self.action = action
    }
    
    public static func ==(lhs: OptionButtonComponent, rhs: OptionButtonComponent) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private var component: OptionButtonComponent?
        
        private let backgroundView: UIImageView
        private let iconView: UIImageView
        private let arrowView: UIImageView
        
        override init(frame: CGRect) {
            self.backgroundView = UIImageView()
            self.iconView = UIImageView()
            self.arrowView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
            self.addSubview(self.arrowView)
            
            self.highligthedChanged = { [weak self] highlighed in
                guard let self else {
                    return
                }
                let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                let scale: CGFloat = highlighed ? 0.8 : 1.0
                transition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(scale, scale, 1.0))
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        func update(component: OptionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            
            let size = CGSize(width: 53.0, height: 28.0)
            
            if previousComponent?.colors.background != component.colors.background {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: size.height, color: component.colors.background)
            }
            if previousComponent?.icon != component.icon {
                if previousComponent != nil, let previousImage = self.iconView.image {
                    let tempView = UIImageView(image: previousImage)
                    tempView.tintColor = component.colors.foreground
                    tempView.frame = self.iconView.frame
                    self.insertSubview(tempView, belowSubview: self.iconView)
                    
                    tempView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak tempView] _ in
                        tempView?.removeFromSuperview()
                    })
                    tempView.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    
                    self.iconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.iconView.layer.animateScale(from: 0.2, to: 1.0, duration: 0.3)
                }
                self.iconView.image = UIImage(bundleImageName: component.icon)?.withRenderingMode(.alwaysTemplate)
            }
            if previousComponent == nil {
                self.arrowView.image = UIImage(bundleImageName: "Stories/SelectorArrowDown")?.withRenderingMode(.alwaysOriginal)
            }
            if previousComponent?.colors.foreground != component.colors.foreground {
                self.iconView.tintColor = component.colors.foreground
                self.arrowView.tintColor = component.colors.foreground
            }
            
            if let iconSize = self.iconView.image?.size, let arrowSize = self.arrowView.image?.size {
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: 4.0, y: floor((size.height - iconSize.height) * 0.5)), size: iconSize))
                transition.setFrame(view: self.arrowView, frame: CGRect(origin: CGPoint(x: size.width - 8.0 - arrowSize.width, y: 1.0 + floor((size.height - arrowSize.height) * 0.5)), size: arrowSize))
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
