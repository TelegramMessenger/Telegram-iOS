import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer
import TelegramPresentationData

public final class AvatarStoryIndicatorComponent: Component {
    public struct Colors: Equatable {
        public var unseenColors: [UIColor]
        public var unseenCloseFriendsColors: [UIColor]
        public var seenColors: [UIColor]
        
        public init(
            unseenColors: [UIColor],
            unseenCloseFriendsColors: [UIColor],
            seenColors: [UIColor]
        ) {
            self.unseenColors = unseenColors
            self.unseenCloseFriendsColors = unseenCloseFriendsColors
            self.seenColors = seenColors
        }
        
        public init(theme: PresentationTheme) {
            self.unseenColors = [theme.chatList.storyUnseenColors.topColor, theme.chatList.storyUnseenColors.bottomColor]
            self.unseenCloseFriendsColors = [theme.chatList.storyUnseenPrivateColors.topColor, theme.chatList.storyUnseenPrivateColors.bottomColor]
            self.seenColors = [theme.chatList.storySeenColors.topColor, theme.chatList.storySeenColors.bottomColor]
        }
    }
    
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
    public let colors: Colors
    public let activeLineWidth: CGFloat
    public let inactiveLineWidth: CGFloat
    public let counters: Counters?
    public let displayProgress: Bool
    
    public init(
        hasUnseen: Bool,
        hasUnseenCloseFriendsItems: Bool,
        colors: Colors,
        activeLineWidth: CGFloat,
        inactiveLineWidth: CGFloat,
        counters: Counters?,
        displayProgress: Bool = false
    ) {
        self.hasUnseen = hasUnseen
        self.hasUnseenCloseFriendsItems = hasUnseenCloseFriendsItems
        self.colors = colors
        self.activeLineWidth = activeLineWidth
        self.inactiveLineWidth = inactiveLineWidth
        self.counters = counters
        self.displayProgress = displayProgress
    }
    
    public static func ==(lhs: AvatarStoryIndicatorComponent, rhs: AvatarStoryIndicatorComponent) -> Bool {
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.hasUnseenCloseFriendsItems != rhs.hasUnseenCloseFriendsItems {
            return false
        }
        if lhs.colors != rhs.colors {
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
        if lhs.displayProgress != rhs.displayProgress {
            return false
        }
        return true
    }
    
    private final class ProgressLayer: HierarchyTrackingLayer {
        enum Value: Equatable {
            case indefinite
            case progress(Float)
        }
        
        private struct Params: Equatable {
            var size: CGSize
            var lineWidth: CGFloat
            var value: Value
        }
        private var currentParams: Params?
        
        private let uploadProgressLayer = SimpleShapeLayer()
        
        private let indefiniteDashLayer = SimpleShapeLayer()
        private let indefiniteReplicatorLayer = CAReplicatorLayer()
        
        override init() {
            super.init()
            
            self.uploadProgressLayer.fillColor = nil
            self.uploadProgressLayer.strokeColor = UIColor.white.cgColor
            self.uploadProgressLayer.lineCap = .round
            
            self.indefiniteDashLayer.fillColor = nil
            self.indefiniteDashLayer.strokeColor = UIColor.white.cgColor
            self.indefiniteDashLayer.lineCap = .round
            self.indefiniteDashLayer.lineJoin = .round
            self.indefiniteDashLayer.strokeEnd = 0.0333
            
            let count = 1.0 / self.indefiniteDashLayer.strokeEnd
            let angle = (2.0 * Double.pi) / Double(count)
            self.indefiniteReplicatorLayer.addSublayer(self.indefiniteDashLayer)
            self.indefiniteReplicatorLayer.instanceCount = Int(count)
            self.indefiniteReplicatorLayer.instanceTransform = CATransform3DMakeRotation(CGFloat(angle), 0.0, 0.0, 1.0)
            self.indefiniteReplicatorLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
            self.indefiniteReplicatorLayer.instanceDelay = 0.025
            
            self.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.updateAnimations(transition: .immediate)
            }
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func reset() {
            self.currentParams = nil
            self.indefiniteDashLayer.path = nil
            self.uploadProgressLayer.path = nil
        }
        
        func updateAnimations(transition: Transition) {
            guard let params = self.currentParams else {
                return
            }
            
            switch params.value {
            case let .progress(progress):
                if self.indefiniteReplicatorLayer.superlayer != nil {
                    self.indefiniteReplicatorLayer.removeFromSuperlayer()
                }
                if self.uploadProgressLayer.superlayer == nil {
                    self.addSublayer(self.uploadProgressLayer)
                }
                transition.setShapeLayerStrokeEnd(layer: self.uploadProgressLayer, strokeEnd: CGFloat(progress))
                if self.uploadProgressLayer.animation(forKey: "rotation") == nil {
                    let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    rotationAnimation.duration = 2.0
                    rotationAnimation.fromValue = NSNumber(value: Float(0.0))
                    rotationAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
                    rotationAnimation.repeatCount = Float.infinity
                    rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                    self.uploadProgressLayer.add(rotationAnimation, forKey: "rotation")
                }
            case .indefinite:
                if self.uploadProgressLayer.superlayer == nil {
                    self.uploadProgressLayer.removeFromSuperlayer()
                }
                if self.indefiniteReplicatorLayer.superlayer == nil {
                    self.addSublayer(self.indefiniteReplicatorLayer)
                }
                if self.indefiniteReplicatorLayer.animation(forKey: "rotation") == nil {
                    let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                    rotationAnimation.duration = 4.0
                    rotationAnimation.fromValue = NSNumber(value: -.pi / 2.0)
                    rotationAnimation.toValue = NSNumber(value: -.pi / 2.0 + Double.pi * 2.0)
                    rotationAnimation.repeatCount = Float.infinity
                    rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                    self.indefiniteReplicatorLayer.add(rotationAnimation, forKey: "rotation")
                }
                if self.indefiniteDashLayer.animation(forKey: "dash") == nil {
                    let dashAnimation = CAKeyframeAnimation(keyPath: "strokeStart")
                    dashAnimation.keyTimes = [0.0, 0.45, 0.55, 1.0]
                    dashAnimation.values = [
                        self.indefiniteDashLayer.strokeStart,
                        self.indefiniteDashLayer.strokeEnd,
                        self.indefiniteDashLayer.strokeEnd,
                        self.indefiniteDashLayer.strokeStart,
                    ]
                    dashAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
                    dashAnimation.duration = 2.5
                    dashAnimation.repeatCount = .infinity
                    self.indefiniteDashLayer.add(dashAnimation, forKey: "dash")
                }
            }
        }
        
        func update(size: CGSize, radius: CGFloat, lineWidth: CGFloat, value: Value, transition: Transition) {
            let params = Params(
                size: size,
                lineWidth: lineWidth,
                value: value
            )
            if self.currentParams == params {
                return
            }
            self.currentParams = params
            
            self.indefiniteDashLayer.lineWidth = lineWidth
            self.uploadProgressLayer.lineWidth = lineWidth
            
            let bounds = CGRect(origin: .zero, size: size)
            if self.uploadProgressLayer.path == nil {
                let path = CGMutablePath()
                path.addEllipse(in: CGRect(origin: CGPoint(x: (size.width - radius * 2.0) * 0.5, y: (size.height - radius * 2.0) * 0.5), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
                self.uploadProgressLayer.path = path
                self.uploadProgressLayer.frame = bounds
            }
            
            if self.indefiniteDashLayer.path == nil {
                let path = CGMutablePath()
                path.addEllipse(in: CGRect(origin: CGPoint(x: (size.width - radius * 2.0) * 0.5, y: (size.height - radius * 2.0) * 0.5), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
                self.indefiniteDashLayer.path = path
                self.indefiniteReplicatorLayer.frame = bounds
                self.indefiniteDashLayer.frame = bounds
            }
            
            self.updateAnimations(transition: transition)
        }
    }
    
    public final class View: UIView {
        private let indicatorView: UIImageView
        private var progressLayer: ProgressLayer?
        private var colorLayer: SimpleGradientLayer?
        
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
            
            let diameter: CGFloat
            
            let maxOuterInset = component.activeLineWidth * 2.0
            diameter = availableSize.width + maxOuterInset * 2.0
            let imageDiameter = ceil(availableSize.width + maxOuterInset * 2.0)
            
            let activeColors: [CGColor]
            let inactiveColors: [CGColor]
            
            if component.hasUnseenCloseFriendsItems {
                activeColors = component.colors.unseenCloseFriendsColors.map(\.cgColor)
            } else {
                activeColors = component.colors.unseenColors.map(\.cgColor)
            }
            
            inactiveColors = component.colors.seenColors.map(\.cgColor)
            
            let radius = (diameter - component.activeLineWidth) * 0.5
            
            self.indicatorView.image = generateImage(CGSize(width: imageDiameter, height: imageDiameter), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.setLineCap(.round)
                
                var locations: [CGFloat] = [0.0, 1.0]
                
                if let counters = component.counters, counters.totalCount > 1 {
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    let spacing: CGFloat = component.activeLineWidth * 2.0
                    let angularSpacing: CGFloat = spacing / radius
                    let circleLength = CGFloat.pi * 2.0 * radius
                    let segmentLength = (circleLength - spacing * CGFloat(counters.totalCount)) / CGFloat(counters.totalCount)
                    let segmentAngle = segmentLength / radius
                    
                    for pass in 0 ..< 2 {
                        context.resetClip()
                        
                        if pass == 0 {
                            context.setLineWidth(component.inactiveLineWidth)
                        } else {
                            context.setLineWidth(component.activeLineWidth)
                        }
                        
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
                    let lineWidth: CGFloat = component.hasUnseen ? component.activeLineWidth : component.inactiveLineWidth
                    context.setLineWidth(lineWidth)
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
            let indicatorFrame = CGRect(origin: CGPoint(x: (availableSize.width - imageDiameter) * 0.5, y: (availableSize.height - imageDiameter) * 0.5), size: CGSize(width: imageDiameter, height: imageDiameter))
            transition.setFrame(view: self.indicatorView, frame: indicatorFrame)
            
            let progressTransition = Transition(animation: .curve(duration: 0.3, curve: .easeInOut))
            if component.displayProgress {
                let colorLayer: SimpleGradientLayer
                if let current = self.colorLayer {
                    colorLayer = current
                } else {
                    colorLayer = SimpleGradientLayer()
                    self.colorLayer = colorLayer
                    self.layer.addSublayer(colorLayer)
                    colorLayer.opacity = 0.0
                }
                
                progressTransition.setAlpha(view: self.indicatorView, alpha: 0.0)
                progressTransition.setAlpha(layer: colorLayer, alpha: 1.0)
                
                let colors: [CGColor] = activeColors
                /*if component.hasUnseen {
                    colors = activeColors
                } else {
                    colors = inactiveColors
                }*/
                
                let lineWidth: CGFloat = component.hasUnseen ? component.activeLineWidth : component.inactiveLineWidth
                
                colorLayer.colors = colors
                colorLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                colorLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
                
                let progressLayer: ProgressLayer
                if let current = self.progressLayer {
                    progressLayer = current
                } else {
                    progressLayer = ProgressLayer()
                    self.progressLayer = progressLayer
                    colorLayer.mask = progressLayer
                }
                
                colorLayer.frame = indicatorFrame
                progressLayer.frame = CGRect(origin: CGPoint(), size: indicatorFrame.size)
                progressLayer.update(size: indicatorFrame.size, radius: radius, lineWidth: lineWidth, value: .indefinite, transition: .immediate)
            } else {
                progressTransition.setAlpha(view: self.indicatorView, alpha: 1.0)
                
                self.progressLayer = nil
                if let colorLayer = self.colorLayer {
                    self.colorLayer = nil
                    
                    progressTransition.setAlpha(layer: colorLayer, alpha: 0.0, completion: { [weak colorLayer] _ in
                        colorLayer?.removeFromSuperlayer()
                    })
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
