import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer

public final class TitleActivityIndicatorComponent: Component {
    let color: UIColor
    
    public init(
        color: UIColor
    ) {
        self.color = color
    }
    
    public static func ==(lhs: TitleActivityIndicatorComponent, rhs: TitleActivityIndicatorComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let shapeLayer: SimpleShapeLayer
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
        private var component: TitleActivityIndicatorComponent?
        private var animator: ConstantDisplayLinkAnimator?
        private var animationPhase: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            self.shapeLayer = SimpleShapeLayer()
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.refreshAnimation()
            }
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.refreshAnimation()
            }
            
            self.layer.addSublayer(self.shapeLayer)
            
            self.shapeLayer.lineCap = .round
            self.shapeLayer.lineWidth = 1.5
            self.shapeLayer.fillColor = nil
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
        }
        
        private func refreshAnimation() {
            if self.hierarchyTrackingLayer.isInHierarchy {
                if self.animator == nil {
                    let animationStartTime = CACurrentMediaTime()
                    self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                        guard let self else {
                            return
                        }
                        let duration: Double = 0.5
                        self.animationPhase = (CACurrentMediaTime() - animationStartTime).truncatingRemainder(dividingBy: duration) / duration
                        self.updateAnimation()
                    })
                    self.animator?.isPaused = false
                }
            } else {
                if let animator = self.animator {
                    self.animator = nil
                    animator.invalidate()
                }
            }
        }
        
        private func updateAnimation() {
            let size = self.shapeLayer.bounds
            let path = CGMutablePath()
            
            let radius = size.height * 0.5
            
            enum Segment {
                case line(start: CGPoint, end: CGPoint)
                case halfCircle(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat)
                
                func length(radius: CGFloat) -> CGFloat {
                    switch self {
                    case let .line(start, end):
                        return abs(start.x - end.x)
                    case let .halfCircle(_, radius, startAngle, endAngle):
                        return (endAngle - startAngle) * radius
                    }
                }
                
                func addPath(into path: CGMutablePath, fromFraction: CGFloat, toFraction: CGFloat) {
                    switch self {
                    case let .line(start, end):
                        if fromFraction != 0.0 {
                            path.move(to: CGPoint(
                                x: start.x * (1.0 - fromFraction) + end.x * fromFraction,
                                y: start.y * (1.0 - fromFraction) + end.y * fromFraction
                            ))
                        }
                        path.addLine(to: CGPoint(
                            x: start.x * (1.0 - toFraction) + end.x * toFraction,
                            y: start.y * (1.0 - toFraction) + end.y * toFraction
                        ))
                    case let .halfCircle(center, radius, startAngle, endAngle):
                        path.addArc(center: center, radius: radius, startAngle: startAngle + fromFraction * (endAngle - startAngle), endAngle: startAngle + toFraction * (endAngle - startAngle), clockwise: false)
                    }
                }
            }
            
            let segments: [Segment] = [
                .halfCircle(center: CGPoint(x: size.width - radius, y: radius), radius: radius, startAngle: -CGFloat.pi * 0.5, endAngle: CGFloat.pi * 0.5),
                .line(start: CGPoint(x: size.width - radius, y: size.height), end: CGPoint(x: radius, y: size.height)),
                .halfCircle(center: CGPoint(x: radius, y: radius), radius: radius, startAngle: CGFloat.pi * 0.5, endAngle: CGFloat.pi * 1.5),
                .line(start: CGPoint(x: radius, y: 0.0), end: CGPoint(x: size.width - radius, y: 0.0)),
            ]
            
            var totalLength: CGFloat = 0.0
            for segment in segments {
                totalLength += segment.length(radius: radius)
            }
            
            let startOffset: CGFloat = self.animationPhase
            let endOffset: CGFloat = startOffset + 0.8
            
            var startLength = startOffset * totalLength
            
            var startSegment: (Int, CGFloat)?
            while startSegment == nil {
                for i in 0 ..< segments.count {
                    let segment = segments[i]
                    let segmentLength = segment.length(radius: radius)
                    if segmentLength <= startLength {
                        startLength -= segmentLength
                    } else {
                        let subOffset = startLength
                        startSegment = (i, subOffset)
                        break
                    }
                }
            }
            
            var isFirst = true
            var pathLength = (endOffset - startOffset) * totalLength
            
            if let (startIndex, startOffset) = startSegment {
                var index = startIndex
                while pathLength > 0.0 {
                    let segment = segments[index]
                    let segmentOffset: CGFloat = isFirst ? startOffset : 0.0
                    let segmentLength = segment.length(radius: radius)
                    
                    let segmentSubLength = segmentLength - segmentOffset
                    if segmentSubLength > 0.0 {
                        //remainingLength <= segmentRemainingLength -> take remainingLength
                        //remainingLength > segmentRemainingLength -> take segmentRemainingLength
                        
                        let pathPart: CGFloat
                        if pathLength <= segmentSubLength {
                            pathPart = pathLength
                        } else {
                            pathPart = segmentSubLength
                        }
                        pathLength -= pathPart
                        
                        segment.addPath(into: path, fromFraction: segmentOffset / segmentLength, toFraction: (segmentOffset + pathPart) / segmentLength)
                    }
                    
                    index = (index + 1) % segments.count
                    isFirst = false
                }
            }
            
            /*for segment in segments {
                segment.addPath(into: path, fromFraction: 0.0, toFraction: 1.0)
            }*/
            
            if let currentPath = self.shapeLayer.path {
                if currentPath != path {
                    self.shapeLayer.path = path
                }
            } else {
                self.shapeLayer.path = path
            }
        }
        
        func update(component: TitleActivityIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            let _ = isFirstTime
            
            transition.setFrame(layer: self.shapeLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setShapeLayerPath(layer: self.shapeLayer, path: UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: availableSize), cornerRadius: availableSize.height * 0.5).cgPath)
            
            self.shapeLayer.strokeColor = component.color.cgColor
            
            self.refreshAnimation()
            self.updateAnimation()
            
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
