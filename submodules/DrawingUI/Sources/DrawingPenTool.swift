import Foundation
import UIKit
import Display
import MediaEditor

private let activeWidthFactor: CGFloat = 0.7

final class PenTool: DrawingElement {
    class RenderView: UIView, DrawingRenderView {
        private weak var element: PenTool?
        private var isEraser = false
        
        private var accumulationImage: UIImage?
        private var activeView: ActiveView?
        
        private var start = 0
        private var segmentsCount = 0
        
        private var drawScale = CGSize(width: 1.0, height: 1.0)
                
        func setup(size: CGSize, screenSize: CGSize, isEraser: Bool) {
            self.isEraser = isEraser
            
            self.backgroundColor = .clear
            self.isOpaque = false
            self.contentMode = .redraw
            
            let scale = CGSize(width: 0.33, height: 0.33)
            let viewSize = CGSize(width: size.width * scale.width, height: size.height * scale.height)
            
            self.drawScale = CGSize(width: size.width / viewSize.width, height: size.height / viewSize.height)
            
            self.bounds = CGRect(origin: .zero, size: viewSize)
            self.transform = CGAffineTransform(scaleX: self.drawScale.width, y: self.drawScale.height)
            self.frame = CGRect(origin: .zero, size: size)
                        
            self.drawScale.height = self.drawScale.width
            
            let activeView = ActiveView(frame: CGRect(origin: .zero, size: self.bounds.size))
            activeView.backgroundColor = .clear
            activeView.contentMode = .redraw
            activeView.isOpaque = false
            activeView.parent = self
            self.addSubview(activeView)
            self.activeView = activeView
        }
        
        func animateArrowPaths(start: CGPoint, direction: CGFloat, length: CGFloat, lineWidth: CGFloat, completion: @escaping () -> Void) {
            let scale = min(self.drawScale.width, self.drawScale.height)
            
            let arrowStart = CGPoint(x: start.x / scale, y: start.y / scale)
            let arrowLeftPath = UIBezierPath()
            arrowLeftPath.move(to: arrowStart)
            arrowLeftPath.addLine(to: arrowStart.pointAt(distance: length / scale, angle: direction - 0.45))
            
            let arrowRightPath = UIBezierPath()
            arrowRightPath.move(to: arrowStart)
            arrowRightPath.addLine(to: arrowStart.pointAt(distance: length / scale, angle: direction + 0.45))
            
            let leftArrowShape = CAShapeLayer()
            leftArrowShape.path = arrowLeftPath.cgPath
            leftArrowShape.lineWidth = lineWidth / scale
            leftArrowShape.strokeColor = self.element?.color.toCGColor()
            leftArrowShape.lineCap = .round
            leftArrowShape.frame = self.bounds
            self.layer.addSublayer(leftArrowShape)
            
            let rightArrowShape = CAShapeLayer()
            rightArrowShape.path = arrowRightPath.cgPath
            rightArrowShape.lineWidth = lineWidth / scale
            rightArrowShape.strokeColor = self.element?.color.toCGColor()
            rightArrowShape.lineCap = .round
            rightArrowShape.frame = self.bounds
            self.layer.addSublayer(rightArrowShape)
            
            leftArrowShape.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
            rightArrowShape.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, completion: { [weak leftArrowShape, weak rightArrowShape] _ in
                completion()
                
                leftArrowShape?.removeFromSuperlayer()
                rightArrowShape?.removeFromSuperlayer()
            })
        }
    
        var onDryingUp: () -> Void = {}
        
        var isDryingUp = false {
            didSet {
                if !self.isDryingUp {
                    self.onDryingUp()
                }
            }
        }
        var dryingLayersCount: Int = 0 {
            didSet {
                if self.dryingLayersCount > 0 {
                    self.isDryingUp = true
                } else {
                    self.isDryingUp = false
                }
            }
        }
    
        fileprivate var displaySize: CGSize?
        fileprivate func draw(element: PenTool, rect: CGRect) {
            self.element = element
            
            self.alpha = element.color.alpha
            
            guard !rect.isInfinite && !rect.isEmpty && !rect.isNull else {
                return
            }
            
            var rect: CGRect? = rect

            let limit = 512
            let activeCount = self.segmentsCount - self.start
            if activeCount > limit {
                rect = nil
                let newStart = self.start + limit
                let displaySize = self.displaySize ?? CGSize(width: round(self.bounds.size.width), height: round(self.bounds.size.height))
                let image = generateImage(displaySize, contextGenerator: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    
                    if let accumulationImage = self.accumulationImage, let cgImage = accumulationImage.cgImage {
                        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                    }
                    
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    
                    context.scaleBy(x: 1.0 / self.drawScale.width, y: 1.0 / self.drawScale.height)
                    
                    context.setBlendMode(.copy)
                    element.drawSegments(in: context, from: self.start, to: newStart)
                }, opaque: false)
                self.accumulationImage = image
                self.layer.contents = image?.cgImage
                
                self.start = newStart
            }
            
            if element.hasAnimations {
                let count = CGFloat(element.segments.count - self.segmentsCount)
                if count > 0 {
                    let dryingPath = CGMutablePath()
                    var abFactor: CGFloat = activeWidthFactor * 1.35
                    let delta: CGFloat = (1.0 - abFactor) / count
                    for i in self.segmentsCount ..< element.segments.count {
                        let segmentPath = element.pathForSegment(element.segments[i], abFactor: abFactor, cdFactor: abFactor + delta)
                        dryingPath.addPath(segmentPath)
                        abFactor += delta
                    }
                    self.setupDrying(path: dryingPath)
                }
            }
            
            self.segmentsCount = element.segments.count
            
            if let rect = rect {
                self.activeView?.setNeedsDisplay(rect.insetBy(dx: -40.0, dy: -40.0).applying(CGAffineTransform(scaleX: 1.0 / self.drawScale.width, y: 1.0 / self.drawScale.height)))
            } else {
                self.activeView?.setNeedsDisplay()
            }
        }
        
        private let dryingFactor: CGFloat = 0.4
        func setupDrying(path: CGPath) {
            guard let element = self.element else {
                return
            }
            
            let dryingLayer = CAShapeLayer()
            dryingLayer.contentsScale = 1.0
            dryingLayer.fillColor = element.renderColor.cgColor
            dryingLayer.strokeColor = element.renderColor.cgColor
            dryingLayer.lineWidth = element.renderLineWidth * self.dryingFactor
            dryingLayer.path = path
            dryingLayer.animate(from: dryingLayer.lineWidth as NSNumber, to: 0.0 as NSNumber, keyPath: "lineWidth", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.4, removeOnCompletion: false, completion: { [weak dryingLayer] _ in
                dryingLayer?.removeFromSuperlayer()
                self.dryingLayersCount -= 1
            })
            dryingLayer.transform = CATransform3DMakeScale(1.0 / self.drawScale.width, 1.0 / self.drawScale.height, 1.0)
            dryingLayer.frame = self.bounds
            self.layer.addSublayer(dryingLayer)
            
            self.dryingLayersCount += 1
        }
        
        private var isActiveDrying = false
        func setupActiveSegmentsDrying() {
            guard let element = self.element else {
                return
            }
            
            if element.hasAnimations {
                let dryingPath = CGMutablePath()
                for segment in element.activeSegments {
                    let segmentPath = element.pathForSegment(segment)
                    dryingPath.addPath(segmentPath)
                }
                self.setupDrying(path: dryingPath)
                self.isActiveDrying = true
                self.setNeedsDisplay()
            }
        }
        
        class ActiveView: UIView {
            weak var parent: RenderView?
            override func draw(_ rect: CGRect) {
                guard let context = UIGraphicsGetCurrentContext(), let parent = self.parent, let element = parent.element else {
                    return
                }
                                
                parent.displaySize = rect.size
                context.scaleBy(x: 1.0 / parent.drawScale.width, y: 1.0 / parent.drawScale.height)
                element.drawSegments(in: context, from: parent.start, to: parent.segmentsCount)
                
                if element.hasAnimations {
                    element.drawActiveSegments(in: context, strokeWidth: !parent.isActiveDrying ? element.renderLineWidth * parent.dryingFactor : nil)
                } else {
                    element.drawActiveSegments(in: context, strokeWidth: nil)
                }
            }
        }
    }
        
    let uuid: UUID
    let drawingSize: CGSize
    let color: DrawingColor
    let renderLineWidth: CGFloat
    let renderMinLineWidth: CGFloat
    let renderColor: UIColor
    
    let hasArrow: Bool
    let renderArrowLength: CGFloat
    var renderArrowLineWidth: CGFloat
    
    let isEraser: Bool
    let isBlur: Bool
    
    var arrowStart: CGPoint?
    var arrowDirection: CGFloat?
    var arrowLeftPath: UIBezierPath?
    var arrowRightPath: UIBezierPath?
    
    var translation: CGPoint = .zero
        
    var blurredImage: UIImage?
    
    private weak var currentRenderView: DrawingRenderView?
    
    private var points: [Point] = Array(repeating: Point(location: .zero, width: 0.0), count: 4)
    private var pointPtr = 0
    
    private var smoothPoints: [Point] = []
    private var activeSmoothPoints: [Point] = []
    
    private var segments: [Segment] = []
    private var activeSegments: [Segment] = []
    
    private var previousActiveRect: CGRect?
    
    private var previousRenderLineWidth: CGFloat?
    
    private var segmentPaths: [Int: CGPath] = [:]
    
    private var useCubicBezier = true
    
    private let animationsEnabled: Bool
    
    var hasAnimations: Bool {
        return self.animationsEnabled && !self.isEraser && !self.isBlur
    }
        
    var isValid: Bool {
        if self.hasArrow {
            return self.arrowStart != nil && self.arrowDirection != nil
        } else {
            return self.segments.count > 0
        }
    }
    
    var bounds: CGRect {
        let segmentsBounds = boundingRect(from: 0, to: self.segments.count).insetBy(dx: -20.0, dy: -20.0)
        var combinedBounds = segmentsBounds
        if self.hasArrow, let arrowLeftPath, let arrowRightPath {
            combinedBounds = combinedBounds.union(arrowLeftPath.bounds.insetBy(dx: -renderArrowLineWidth, dy: -renderArrowLineWidth)).union(arrowRightPath.bounds.insetBy(dx: -renderArrowLineWidth, dy: -renderArrowLineWidth)).insetBy(dx: -20.0, dy: -20.0)
        }
        return normalizeDrawingRect(combinedBounds, drawingSize: self.drawingSize)
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, hasArrow: Bool, isEraser: Bool, isBlur: Bool, blurredImage: UIImage?, animationsEnabled: Bool) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = isEraser || isBlur ? DrawingColor(rgb: 0x000000) : color
        self.hasArrow = hasArrow
        self.isEraser = isEraser
        self.isBlur = isBlur
        self.blurredImage = blurredImage
        self.animationsEnabled = animationsEnabled
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.002)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.07)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        let minRenderArrowLength = max(10.0, max(drawingSize.width, drawingSize.height) * 0.02)
        
        self.renderLineWidth = lineWidth
        self.renderMinLineWidth = isEraser || isBlur ? lineWidth : minLineWidth + (lineWidth - minLineWidth) * 0.2
        self.renderArrowLength = max(minRenderArrowLength, lineWidth * 3.0)
        self.renderArrowLineWidth = max(minLineWidth * 1.8, lineWidth * 0.75)
        
        self.renderColor = color.withUpdatedAlpha(1.0).toUIColor()
    }
        
    var isFinishingArrow = false
    func finishArrow(_ completion: @escaping () -> Void) {
        if let arrowStart, let arrowDirection {
            self.isFinishingArrow = true
            (self.currentRenderView as? RenderView)?.animateArrowPaths(start: arrowStart, direction: arrowDirection, length: self.renderArrowLength, lineWidth: self.renderArrowLineWidth, completion: { [weak self] in
                self?.isFinishingArrow = false
                completion()
            })
        } else {
            completion()
        }
    }
        
    func setupRenderView(screenSize: CGSize) -> DrawingRenderView? {
        let view = RenderView()
        view.setup(size: self.drawingSize, screenSize: screenSize, isEraser: self.isEraser)
        self.currentRenderView = view
        return view
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
        
    func updatePath(_ point: DrawingPoint, state: DrawingGesturePipeline.DrawingGestureState, zoomScale: CGFloat) {
        let result = self.addPoint(point, state: state, zoomScale: zoomScale)
        let resetActiveRect = result?.0 ?? false
        let updatedRect = result?.1
        var combinedRect = updatedRect
        if let previousActiveRect = self.previousActiveRect {
            combinedRect = updatedRect?.union(previousActiveRect) ?? previousActiveRect
        }
        if resetActiveRect {
            self.previousActiveRect = updatedRect
        } else {
            self.previousActiveRect = combinedRect
        }
        
        if let currentRenderView = self.currentRenderView as? RenderView, let combinedRect {
            currentRenderView.draw(element: self, rect: combinedRect)
        }
        
        if state == .ended {
            if !self.activeSegments.isEmpty {
                (self.currentRenderView as? RenderView)?.setupActiveSegmentsDrying()
                
                self.segments.append(contentsOf: self.activeSegments)
                self.smoothPoints.append(contentsOf: self.activeSmoothPoints)
            }
            
            if self.hasArrow {
                var direction: CGFloat?
                if self.smoothPoints.count > 4 {
                    let p2 = self.smoothPoints[self.smoothPoints.count - 1].location
                    for i in 1 ..< min(self.smoothPoints.count - 2, 200) {
                        let p1 = self.smoothPoints[self.smoothPoints.count - 1 - i].location
                        if p1.distance(to: p2) > self.renderArrowLength * 0.5 {
                            direction = p2.angle(to: p1)
                            break
                        }
                    }
                }
                
                self.arrowStart = self.smoothPoints.last?.location
                self.arrowDirection = direction
                self.maybeSetupArrow()
            } else if self.segments.isEmpty {
                let radius = self.renderLineWidth / 2.0
                self.segments.append(
                    Segment(
                        a: CGPoint(x: point.x - radius, y: point.y),
                        b: CGPoint(x: point.x + radius, y: point.y),
                        c: CGPoint(x: point.x - radius, y: point.y + 0.1),
                        d: CGPoint(x: point.x + radius, y: point.y + 0.1),
                        radius1: radius,
                        radius2: radius,
                        abCenter: CGPoint(x: point.x, y: point.y),
                        cdCenter: CGPoint(x: point.x, y: point.y + 0.1),
                        perpendicular: .zero,
                        rect: CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius * 2.0, height: radius * 2.0))
                    )
                )
            }
        }
    }
    
    func maybeSetupArrow() {
        if let start = self.arrowStart, let direction = self.arrowDirection {
            let arrowLeftPath = UIBezierPath()
            arrowLeftPath.move(to: start)
            arrowLeftPath.addLine(to: start.pointAt(distance: self.renderArrowLength, angle: direction - 0.45))
            
            let arrowRightPath = UIBezierPath()
            arrowRightPath.move(to: start)
            arrowRightPath.addLine(to: start.pointAt(distance: self.renderArrowLength, angle: direction + 0.45))
            
            self.arrowLeftPath = arrowLeftPath
            self.arrowRightPath = arrowRightPath
            self.renderArrowLineWidth = self.smoothPoints.last?.width ?? self.renderArrowLineWidth
        }
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self.segments.isEmpty else {
            return
        }
        
        context.saveGState()
        
        if self.isEraser {
            context.setBlendMode(.clear)
        } else if self.isBlur {
            context.setBlendMode(.normal)
        } else {
            context.setAlpha(self.color.alpha)
            context.setBlendMode(.copy)
        }
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)
        
        if self.isBlur, let blurredImage = self.blurredImage {
            let maskContext = DrawingContext(size: size, scale: 0.5, clear: true)
            maskContext?.withFlippedContext { maskContext in
                self.drawSegments(in: maskContext, from: 0, to: self.segments.count)
            }
            if let maskImage = maskContext?.generateImage()?.cgImage, let blurredImage = blurredImage.cgImage {
                context.clip(to: CGRect(origin: .zero, size: size), mask: maskImage)
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                context.draw(blurredImage, in: CGRect(origin: .zero, size: size))
            }
            
        } else {
            self.drawSegments(in: context, from: 0, to: self.segments.count)
        }
        
        if let arrowLeftPath, let arrowRightPath {
            context.setStrokeColor(self.renderColor.cgColor)
            context.setLineWidth(self.renderArrowLineWidth)
            context.setLineCap(.round)
            
            context.addPath(arrowLeftPath.cgPath)
            context.strokePath()
            
            context.addPath(arrowRightPath.cgPath)
            context.strokePath()
        }
        
        context.restoreGState()
        
        self.segmentPaths = [:]
    }
    
    private struct Segment: Codable {
        let a: CGPoint
        let b: CGPoint
        let c: CGPoint
        let d: CGPoint
        let radius1: CGFloat
        let radius2: CGFloat
        let abCenter: CGPoint
        let cdCenter: CGPoint
        let perpendicular: CGPoint
        let rect: CGRect
                
        init(
            a: CGPoint,
            b: CGPoint,
            c: CGPoint,
            d: CGPoint,
            radius1: CGFloat,
            radius2: CGFloat,
            abCenter: CGPoint,
            cdCenter: CGPoint,
            perpendicular: CGPoint,
            rect: CGRect
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.radius1 = radius1
            self.radius2 = radius2
            self.abCenter = abCenter
            self.cdCenter = cdCenter
            self.perpendicular = perpendicular
            self.rect = rect
        }
        
        func withMultiplied(abFactor: CGFloat, cdFactor: CGFloat) -> Segment {
            let a = CGPoint(
                x: self.abCenter.x + self.perpendicular.x * self.radius1 * abFactor,
                y: self.abCenter.y + self.perpendicular.y * self.radius1 * abFactor
            )
            let b = CGPoint(
                x: self.abCenter.x - self.perpendicular.x * self.radius1 * abFactor,
                y: self.abCenter.y - self.perpendicular.y * self.radius1 * abFactor
            )
            let c = CGPoint(
                x: self.cdCenter.x + self.perpendicular.x * self.radius2 * cdFactor,
                y: self.cdCenter.y + self.perpendicular.y * self.radius2 * cdFactor
            )
            let d = CGPoint(
                x: self.cdCenter.x - self.perpendicular.x * self.radius2 * cdFactor,
                y: self.cdCenter.y - self.perpendicular.y * self.radius2 * cdFactor
            )

            return Segment(
                a: a,
                b: b,
                c: c,
                d: d,
                radius1: self.radius1 * abFactor,
                radius2: self.radius2 * cdFactor,
                abCenter: self.abCenter,
                cdCenter: self.cdCenter,
                perpendicular: self.perpendicular,
                rect: self.rect
            )
        }
    }
    
    private struct Point {
        let location: CGPoint
        let width: CGFloat
        
        init(
            location: CGPoint,
            width: CGFloat
        ) {
            self.location = location
            self.width = width
        }
    }
            
    private var currentVelocity: CGFloat?
    private func addPoint(_ point: DrawingPoint, state: DrawingGesturePipeline.DrawingGestureState, zoomScale: CGFloat) -> (Bool, CGRect)? {
        let filterDistance: CGFloat = 8.0 / zoomScale
                
        var velocity = point.velocity
        if velocity.isZero {
            velocity = 1000.0
        }
        self.currentVelocity = velocity
        
        var renderLineWidth = max(self.renderMinLineWidth, min(self.renderLineWidth - (velocity / 200.0), self.renderLineWidth))
        if let previousRenderLineWidth = self.previousRenderLineWidth {
            renderLineWidth = renderLineWidth * 0.3 + previousRenderLineWidth * 0.7
        }
        self.previousRenderLineWidth = renderLineWidth
             
        var resetActiveRect = false
        var finalizedRect: CGRect?
        if self.pointPtr == 0 {
            self.points[0] = Point(location: point.location, width: renderLineWidth)
            self.pointPtr += 1
        } else {
            let previousPoint = self.points[self.pointPtr - 1].location
            guard previousPoint.distance(to: point.location) > filterDistance else {
                return nil
            }
            
            if self.pointPtr >= 4 {
                self.points[3] = Point(
                    location: self.points[2].location.point(to: point.location, t: 0.5),
                    width: self.points[2].width
                )
                if var smoothPoints = self.currentSmoothPoints(3) {
                    if let previousSmoothPoint = self.smoothPoints.last {
                        smoothPoints.insert(previousSmoothPoint, at: 0)
                    }
                    let (segments, rect) = self.segments(fromSmoothPoints: smoothPoints)
                    self.smoothPoints.append(contentsOf: smoothPoints)
                    self.segments.append(contentsOf: segments)
                    finalizedRect = rect
                    
                    self.activeSmoothPoints.removeAll()
                    self.activeSegments.removeAll()
                    
                    resetActiveRect = true
                }
                
                self.points[0] = self.points[3]
                self.pointPtr = 1
            }
            
            let point = Point(location: point.location, width: renderLineWidth)
            self.points[self.pointPtr] = point
            self.pointPtr += 1
        }
        
        guard let smoothPoints = self.currentSmoothPoints(self.pointPtr - 1) else {
            if let finalizedRect {
                return (resetActiveRect, finalizedRect)
            } else {
                return nil
            }
        }
        
        let (segments, rect) = self.segments(fromSmoothPoints: smoothPoints)
        self.activeSmoothPoints = smoothPoints
        self.activeSegments = segments
        
        var combinedRect: CGRect?
        if let finalizedRect, let rect {
            combinedRect = finalizedRect.union(rect)
        } else {
            combinedRect = rect ?? finalizedRect
        }
        if let combinedRect {
            return (resetActiveRect, combinedRect)
        } else {
            return nil
        }
    }
    
    private func currentSmoothPoints(_ ctr: Int) -> [Point]? {
        switch ctr {
        case 0:
            return nil//return [self.points[0]]
        case 1:
            return nil//return self.smoothPoints(.line(self.points[0], self.points[1]))
        case 2:
            return self.smoothPoints(.quad(self.points[0], self.points[1], self.points[2]))
        case 3:
            return self.smoothPoints(.cubic(self.points[0], self.points[1], self.points[2], self.points[3]))
        default:
            return nil
        }
    }
        
    private enum SmootherInput {
        case line(Point, Point)
        case quad(Point, Point, Point)
        case cubic(Point, Point, Point, Point)
        
        var start: Point {
            switch self {
            case let .line(start, _), let .quad(start, _, _), let .cubic(start, _, _, _):
                return start
            }
        }
        
        var end: Point {
            switch self {
            case let .line(_, end), let .quad(_, _, end), let .cubic(_, _, _, end):
                return end
            }
        }
        
        var distance: CGFloat {
            return self.start.location.distance(to: self.end.location)
        }
    }
    private func smoothPoints(_ input: SmootherInput) -> [Point] {
        let segmentDistance: CGFloat = 6.0
        let distance = input.distance
        let numberOfSegments = min(48, max(floor(distance / segmentDistance), 24))
        
        let step = 1.0 / numberOfSegments
        
        var smoothPoints: [Point] = []
        for t in stride(from: 0, to: 1, by: step) {
            let point: Point
            switch input {
            case let .line(start, end):
                point = Point(
                    location: start.location.linearBezierPoint(to: end.location, t: t),
                    width: CGPoint(x: start.width, y: 0.0).linearBezierPoint(to: CGPoint(x: end.width, y: 0.0), t: t).x
                )
            case let .quad(start, control, end):
                let location = start.location.quadBezierPoint(to: end.location, controlPoint: control.location, t: t)
                let width = CGPoint(x: start.width, y: 0.0).quadBezierPoint(to: CGPoint(x: end.width, y: 0.0), controlPoint: CGPoint(x: (start.width + end.width) / 2.0, y: 0.0), t: t).x
                point = Point(
                    location: location,
                    width: width
                )
            case let .cubic(start, control1, control2, end):
                let location = start.location.cubicBezierPoint(to: end.location, controlPoint1: control1.location, controlPoint2: control2.location, t: t)
                let width = CGPoint(x: start.width, y: 0.0).cubicBezierPoint(to: CGPoint(x: end.width, y: 0.0), controlPoint1: CGPoint(x: (start.width + control1.width) / 2.0, y: 0.0), controlPoint2: CGPoint(x: (control2.width + end.width) / 2.0, y: 0.0), t: t).x
                point = Point(
                    location: location,
                    width: width
                )
            }
            smoothPoints.append(point)
        }
        smoothPoints.append(input.end)
        return smoothPoints
    }

    fileprivate func boundingRect(from: Int, to: Int) -> CGRect {
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = 0.0
        var maxY: CGFloat = 0.0
        
        for i in from ..< to {
            let segment = self.segments[i]
            
            if segment.rect.minX < minX {
                minX = segment.rect.minX
            }
            if segment.rect.maxX > maxX {
                maxX = segment.rect.maxX
            }
            if segment.rect.minY < minY {
                minY = segment.rect.minY
            }
            if segment.rect.maxY > maxY {
                maxY = segment.rect.maxY
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func segments(fromSmoothPoints smoothPoints: [Point]) -> ([Segment], CGRect?) {
        var segments: [Segment] = []
        var updateRect = CGRect.null
        for i in 1 ..< smoothPoints.count {
            let previousPoint = smoothPoints[i - 1].location
            let previousWidth = smoothPoints[i - 1].width
            let currentPoint = smoothPoints[i].location
            let currentWidth = smoothPoints[i].width
            let direction = CGPoint(
                x: currentPoint.x - previousPoint.x,
                y: currentPoint.y - previousPoint.y
            )
            
            guard !currentPoint.isEqual(to: previousPoint, epsilon: 0.0001) else {
                continue
            }
            
            var perpendicular = CGPoint(x: -direction.y, y: direction.x)
            let length = perpendicular.length
            if length > 0.0 {
                perpendicular = CGPoint(
                    x: perpendicular.x / length,
                    y: perpendicular.y / length
                )
            }
            
            let a = CGPoint(
                x: previousPoint.x + perpendicular.x * previousWidth / 2.0,
                y: previousPoint.y + perpendicular.y * previousWidth / 2.0
            )
            let b = CGPoint(
                x: previousPoint.x - perpendicular.x * previousWidth / 2.0,
                y: previousPoint.y - perpendicular.y * previousWidth / 2.0
            )
            let c = CGPoint(
                x: currentPoint.x + perpendicular.x * currentWidth / 2.0,
                y: currentPoint.y + perpendicular.y * currentWidth / 2.0
            )
            let d = CGPoint(
                x: currentPoint.x - perpendicular.x * currentWidth / 2.0,
                y: currentPoint.y - perpendicular.y * currentWidth / 2.0
            )
            
            let abCenter = CGPoint(
                x: (a.x + b.x) / 2.0,
                y: (a.y + b.y) / 2.0
            )
            let abRadius = CGPoint(
                x: abCenter.x - b.x,
                y: abCenter.y - b.y
            )
            let ab = CGPoint(
                x: abCenter.x - abRadius.y,
                y: abCenter.y + abRadius.x
            )
            
            let cdCenter = CGPoint(
                x: (c.x + d.x) / 2.0,
                y: (c.y + d.y) / 2.0
            )
            let cdRadius = CGPoint(
                x: cdCenter.x - c.x,
                y: cdCenter.y - c.y
            )
            let cd = CGPoint(
                x: cdCenter.x - cdRadius.y,
                y: cdCenter.y + cdRadius.x
            )
                        
            let minX = min(a.x, b.x, c.x, d.x, ab.x, cd.x)
            let minY = min(a.y, b.y, c.y, d.y, ab.y, cd.y)
            let maxX = max(a.x, b.x, c.x, d.x, ab.x, cd.x)
            let maxY = max(a.y, b.y, c.y, d.y, ab.y, cd.y)
            
            let segmentRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            updateRect = updateRect.union(segmentRect)

            let segment = Segment(
                a: a,
                b: b,
                c: c,
                d: d,
                radius1: previousWidth / 2.0,
                radius2: currentWidth / 2.0,
                abCenter: abCenter,
                cdCenter: cdCenter,
                perpendicular: perpendicular,
                rect: segmentRect
            )
            segments.append(segment)
        }
        return (segments, !updateRect.isNull ? updateRect : nil)
    }
        
    private func pathForSegment(_ segment: Segment, abFactor: CGFloat = 1.0, cdFactor: CGFloat = 1.0) -> CGPath {
        var segment = segment
        if abFactor != 1.0 || cdFactor != 1.0 {
            segment = segment.withMultiplied(abFactor: abFactor, cdFactor: cdFactor)
        }
        
        let path = CGMutablePath()
        path.move(to: segment.b)
        
        let abStartAngle = atan2(
            segment.b.y - segment.a.y,
            segment.b.x - segment.a.x
        )
        path.addArc(
            center: CGPoint(
                x: (segment.a.x + segment.b.x) / 2,
                y: (segment.a.y + segment.b.y) / 2
            ),
            radius: segment.radius1,
            startAngle: abStartAngle,
            endAngle: abStartAngle + .pi,
            clockwise: true
        )
        path.addLine(to: segment.c)
        
        let cdStartAngle = atan2(
            segment.c.y - segment.d.y,
            segment.c.x - segment.d.x
        )
        path.addArc(
            center: CGPoint(
                x: (segment.c.x + segment.d.x) / 2,
                y: (segment.c.y + segment.d.y) / 2
            ),
            radius: segment.radius2,
            startAngle: cdStartAngle,
            endAngle: cdStartAngle + .pi,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
    
    func cachedPathForSegmentIndex(_ i: Int) -> CGPath {
        var segmentPath: CGPath
        if let current = self.segmentPaths[i] {
            segmentPath = current
        } else {
            let segment = self.segments[i]
            let path = self.pathForSegment(segment)
            self.segmentPaths[i] = path
            segmentPath = path
        }
        return segmentPath
    }
    
    private func drawSegments(in context: CGContext, from: Int, to: Int) {
        context.setFillColor(self.renderColor.cgColor)
        
        for i in from ..< to {
            let segment = self.segments[i]
            
            var segmentPath: CGPath
            if let current = self.segmentPaths[i] {
                segmentPath = current
            } else {
                let path = self.pathForSegment(segment)
                self.segmentPaths[i] = path
                segmentPath = path
            }
            
            context.addPath(segmentPath)
            context.fillPath()
        }
    }
    
    private func drawActiveSegments(in context: CGContext, strokeWidth: CGFloat?) {
        context.setFillColor(self.renderColor.cgColor)
        if let strokeWidth {
            context.setStrokeColor(self.renderColor.cgColor)
            context.setLineWidth(strokeWidth)
        }
        
        var abFactor: CGFloat = activeWidthFactor
        let delta: CGFloat = (1.0 - activeWidthFactor) / CGFloat(self.activeSegments.count + 1)
        for segment in self.activeSegments {
            let path = self.pathForSegment(segment)
            context.addPath(path)
            if let _ = strokeWidth {
                context.drawPath(using: .fillStroke)
            } else {
                context.fillPath()
            }
            abFactor += delta
        }
    }
}
