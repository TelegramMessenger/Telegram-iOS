import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

public final class AvatarStoryIndicatorComponent: Component {
    public struct Counters: Equatable {
        public var totalCount: Int
        public var unseenCount: Int
        
        public init(totalCount: Int, unseenCount: Int) {
            self.totalCount = totalCount
            self.unseenCount = unseenCount
        }
    }
    
    public let hasUnseen: Bool
    public let hasUnseenCloseFriendsItems: Bool
    public let theme: PresentationTheme
    public let activeLineWidth: CGFloat
    public let inactiveLineWidth: CGFloat
    public let counters: Counters?
    
    public init(
        hasUnseen: Bool,
        hasUnseenCloseFriendsItems: Bool,
        theme: PresentationTheme,
        activeLineWidth: CGFloat,
        inactiveLineWidth: CGFloat,
        counters: Counters?
    ) {
        self.hasUnseen = hasUnseen
        self.hasUnseenCloseFriendsItems = hasUnseenCloseFriendsItems
        self.theme = theme
        self.activeLineWidth = activeLineWidth
        self.inactiveLineWidth = inactiveLineWidth
        self.counters = counters
    }
    
    public static func ==(lhs: AvatarStoryIndicatorComponent, rhs: AvatarStoryIndicatorComponent) -> Bool {
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.hasUnseenCloseFriendsItems != rhs.hasUnseenCloseFriendsItems {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.activeLineWidth != rhs.activeLineWidth {
            return false
        }
        if lhs.inactiveLineWidth != rhs.inactiveLineWidth {
            return false
        }
        if lhs.counters != rhs.counters {
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
                
                let activeColors: [CGColor]
                let inactiveColors: [CGColor]
                
                if component.hasUnseenCloseFriendsItems {
                    activeColors = [
                        UIColor(rgb: 0x7CD636).cgColor,
                        UIColor(rgb: 0x26B470).cgColor
                    ]
                } else {
                    activeColors = [
                        UIColor(rgb: 0x34C76F).cgColor,
                        UIColor(rgb: 0x3DA1FD).cgColor
                    ]
                }
                
                if component.theme.overallDarkAppearance {
                    inactiveColors = [component.theme.rootController.tabBar.textColor.cgColor, component.theme.rootController.tabBar.textColor.cgColor]
                } else {
                    inactiveColors = [UIColor(rgb: 0xD8D8E1).cgColor, UIColor(rgb: 0xD8D8E1).cgColor]
                }
                
                var locations: [CGFloat] = [0.0, 1.0]
                
                context.setLineWidth(lineWidth)
                
                if let counters = component.counters, counters.totalCount > 1 {
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    let radius = (diameter - lineWidth) * 0.5
                    let spacing: CGFloat = 2.0
                    let angularSpacing: CGFloat = spacing / radius
                    let circleLength = CGFloat.pi * 2.0 * radius
                    let segmentLength = (circleLength - spacing * CGFloat(counters.totalCount)) / CGFloat(counters.totalCount)
                    let segmentAngle = segmentLength / radius
                    
                    for pass in 0 ..< 2 {
                        context.resetClip()
                        
                        let startIndex: Int
                        let endIndex: Int
                        if pass == 0 {
                            startIndex = 0
                            endIndex = counters.totalCount - counters.unseenCount
                        } else {
                            startIndex = counters.totalCount - counters.unseenCount
                            endIndex = counters.totalCount
                        }
                        if startIndex < endIndex {
                            for i in startIndex ..< endIndex {
                                let startAngle = CGFloat(i) * (angularSpacing + segmentAngle) - CGFloat.pi * 0.5 + angularSpacing * 0.5
                                context.move(to: CGPoint(x: center.x + cos(startAngle) * radius, y: center.y + sin(startAngle) * radius))
                                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + segmentAngle, clockwise: false)
                            }
                            
                            context.replacePathWithStrokedPath()
                            context.clip()
                            
                            let colors: [CGColor]
                            if pass == 1 {
                                colors = activeColors
                            } else {
                                colors = inactiveColors
                            }
                            
                            let colorSpace = CGColorSpaceCreateDeviceRGB()
                            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                            
                            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                        }
                    }
                } else {
                    context.addEllipse(in: CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
                    
                    context.replacePathWithStrokedPath()
                    context.clip()
                    
                    let colors: [CGColor]
                    if component.hasUnseen {
                        colors = activeColors
                    } else {
                        colors = inactiveColors
                    }
                    
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                    
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                }
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
