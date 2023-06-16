import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

public final class AvatarStoryIndicatorComponent: Component {
    public let hasUnseen: Bool
    public let isDarkTheme: Bool
    public let activeLineWidth: CGFloat
    public let inactiveLineWidth: CGFloat
    
    public init(
        hasUnseen: Bool,
        isDarkTheme: Bool,
        activeLineWidth: CGFloat,
        inactiveLineWidth: CGFloat
    ) {
        self.hasUnseen = hasUnseen
        self.isDarkTheme = isDarkTheme
        self.activeLineWidth = activeLineWidth
        self.inactiveLineWidth = inactiveLineWidth
    }
    
    public static func ==(lhs: AvatarStoryIndicatorComponent, rhs: AvatarStoryIndicatorComponent) -> Bool {
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.isDarkTheme != rhs.isDarkTheme {
            return false
        }
        if lhs.activeLineWidth != rhs.activeLineWidth {
            return false
        }
        if lhs.inactiveLineWidth != rhs.inactiveLineWidth {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let indicatorView: UIImageView
        
        private var component: AvatarStoryIndicatorComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.indicatorView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.indicatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarStoryIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let lineWidth: CGFloat
            let diameter: CGFloat
            
            if component.hasUnseen {
                lineWidth = component.activeLineWidth
            } else {
                lineWidth = component.inactiveLineWidth
            }
            let maxOuterInset = component.activeLineWidth + component.activeLineWidth
            diameter = availableSize.width + maxOuterInset * 2.0
            let imageDiameter = availableSize.width + ceilToScreenPixels(maxOuterInset) * 2.0
            
            self.indicatorView.image = generateImage(CGSize(width: imageDiameter, height: imageDiameter), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.setLineWidth(lineWidth)
                context.addEllipse(in: CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
                context.replacePathWithStrokedPath()
                context.clip()
                
                var locations: [CGFloat] = [1.0, 0.0]
                let colors: [CGColor]
                if component.hasUnseen {
                    colors = [UIColor(rgb: 0x34C76F).cgColor, UIColor(rgb: 0x3DA1FD).cgColor]
                } else {
                    if component.isDarkTheme {
                        colors = [UIColor(rgb: 0x48484A).cgColor, UIColor(rgb: 0x48484A).cgColor]
                    } else {
                        colors = [UIColor(rgb: 0xD8D8E1).cgColor, UIColor(rgb: 0xD8D8E1).cgColor]
                    }
                }
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
            transition.setFrame(view: self.indicatorView, frame: CGRect(origin: CGPoint(x: (availableSize.width - imageDiameter) * 0.5, y: (availableSize.height - imageDiameter) * 0.5), size: CGSize(width: imageDiameter, height: imageDiameter)))
            
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
