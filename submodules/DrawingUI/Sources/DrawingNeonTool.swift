import Foundation
import UIKit
import Display

final class NeonTool: DrawingElement {
    class RenderView: UIView, DrawingRenderView {
        private weak var element: NeonTool?
        private var drawScale = CGSize(width: 1.0, height: 1.0)
        
        let shadowLayer = SimpleShapeLayer()
        let borderLayer = SimpleShapeLayer()
        let fillLayer = SimpleShapeLayer()
        
        func setup(element: NeonTool, size: CGSize, screenSize: CGSize) {
            self.element = element
            
            self.backgroundColor = .clear
            self.isOpaque = false
            self.contentScaleFactor = 1.0
                        
            let shadowRadius = element.renderShadowRadius
            let strokeWidth = element.renderStrokeWidth
            var shadowColor = element.color.toUIColor()
            var fillColor: UIColor = .white
            if shadowColor.lightness < 0.01 {
                fillColor = shadowColor
                shadowColor = UIColor(rgb: 0x440881)
            }
                        
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
            
            self.shadowLayer.frame = bounds
            self.shadowLayer.contentsScale = 1.0
            self.shadowLayer.backgroundColor = UIColor.clear.cgColor
            self.shadowLayer.lineWidth = strokeWidth * 0.5
            self.shadowLayer.lineCap = .round
            self.shadowLayer.lineJoin = .round
            self.shadowLayer.fillColor = fillColor.cgColor
            self.shadowLayer.strokeColor = fillColor.cgColor
            self.shadowLayer.shadowColor = shadowColor.cgColor
            self.shadowLayer.shadowRadius = shadowRadius
            self.shadowLayer.shadowOpacity = 1.0
            self.shadowLayer.shadowOffset = .zero

            self.borderLayer.frame = bounds
            self.borderLayer.contentsScale = 1.0
            self.borderLayer.lineWidth = strokeWidth
            self.borderLayer.lineCap = .round
            self.borderLayer.lineJoin = .round
            self.borderLayer.fillColor = UIColor.clear.cgColor
            self.borderLayer.strokeColor = fillColor.mixedWith(shadowColor, alpha: 0.25).cgColor
            
            self.fillLayer.frame = bounds
            self.fillLayer.contentsScale = 1.0
            self.fillLayer.fillColor = fillColor.cgColor
            
            self.layer.addSublayer(self.shadowLayer)
            self.layer.addSublayer(self.borderLayer)
            self.layer.addSublayer(self.fillLayer)
        }
        
        fileprivate func updatePath(_ path: CGPath) {
            self.shadowLayer.path = path
            self.borderLayer.path = path
            self.fillLayer.path = path
        }
    }
        
    let uuid: UUID
    let drawingSize: CGSize
    let color: DrawingColor
    let renderStrokeWidth: CGFloat
    let renderShadowRadius: CGFloat
    let renderLineWidth: CGFloat
    let renderColor: UIColor
    
    private var pathStarted = false
    private let path = UIBezierPath()
    private var activePath: UIBezierPath?
    private var addedPaths = 0
    
    fileprivate var renderPath: CGPath?
    
    var translation: CGPoint = .zero
        
    private weak var currentRenderView: DrawingRenderView?
        
    var isValid: Bool {
        return self.renderPath != nil
    }
    
    var bounds: CGRect {
        if let renderPath = self.renderPath {
            return normalizeDrawingRect(renderPath.boundingBoxOfPath.insetBy(dx: -self.renderShadowRadius - 30.0, dy: -self.renderShadowRadius - 30.0), drawingSize: self.drawingSize)
        } else {
            return .zero
        }
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = color
        
        let strokeWidth = min(drawingSize.width, drawingSize.height) * 0.01
        let shadowRadius = min(drawingSize.width, drawingSize.height) * 0.03
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.002)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.07)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderStrokeWidth = strokeWidth
        self.renderShadowRadius = shadowRadius
        self.renderLineWidth = lineWidth
        
        self.renderColor = color.withUpdatedAlpha(1.0).toUIColor()
    }

    func setupRenderView(screenSize: CGSize) -> DrawingRenderView? {
        let view = RenderView()
        view.setup(element: self, size: self.drawingSize, screenSize: screenSize)
        self.currentRenderView = view
        return view
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    func updatePath(_ point: DrawingPoint, state: DrawingGesturePipeline.DrawingGestureState, zoomScale: CGFloat) {
        guard self.addPoint(point, state: state, zoomScale: zoomScale) || state == .ended else {
            return
        }

        if let currentRenderView = self.currentRenderView as? RenderView {
            let path = self.path.cgPath.mutableCopy()
            if let activePath {
                path?.addPath(activePath.cgPath)
            }
            if let renderPath = path?.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0) {   
                self.renderPath = renderPath
                currentRenderView.updatePath(renderPath)
            }
        }
        
        if state == .ended {
            if let activePath = self.activePath {
                self.path.append(activePath)
                self.renderPath = self.path.cgPath.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
            } else if self.addedPaths == 0, let point = self.points.first {
                self.renderPath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: point.x - self.renderLineWidth / 2.0, y: point.y - self.renderLineWidth / 2.0), size: CGSize(width: self.renderLineWidth, height: self.renderLineWidth)), transform: nil)
            }
        }
    }
        
    func draw(in context: CGContext, size: CGSize) {
        guard let path = self.renderPath else {
            return
        }
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        context.setShouldAntialias(true)

        context.setBlendMode(.normal)
        
        var shadowColor = self.color.toUIColor()
        var fillColor: UIColor = .white
        if shadowColor.lightness < 0.01 {
            fillColor = shadowColor
            shadowColor = UIColor(rgb: 0x440881)
        }

        context.addPath(path)
        context.setLineCap(.round)
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(fillColor.cgColor)
        context.setLineWidth(self.renderStrokeWidth * 0.5)
        context.setShadow(offset: .zero, blur: self.renderShadowRadius * 1.9, color: shadowColor.cgColor)
        context.drawPath(using: .fillStroke)

        context.addPath(path)
        context.setShadow(offset: .zero, blur: 0.0, color: UIColor.clear.cgColor)
        context.setLineWidth(self.renderStrokeWidth)
        context.setStrokeColor(fillColor.mixedWith(shadowColor, alpha: 0.25).cgColor)
        context.strokePath()

        context.addPath(path)
        context.setFillColor(fillColor.cgColor)

        context.fillPath()
        
        context.restoreGState()
    }
        
    private var points: [CGPoint] = Array(repeating: .zero, count: 4)
    private var pointPtr = 0
    
    private func addPoint(_ point: DrawingPoint, state: DrawingGesturePipeline.DrawingGestureState, zoomScale: CGFloat) -> Bool {
        let filterDistance: CGFloat = 10.0 / zoomScale
                             
        if self.pointPtr == 0 {
            self.points[0] = point.location
            self.pointPtr += 1
        } else {
            let previousPoint = self.points[self.pointPtr - 1]
            guard previousPoint.distance(to: point.location) > filterDistance else {
                return false
            }
            
            if self.pointPtr >= 4 {
                self.points[3] = self.points[2].point(to: point.location, t: 0.5)
                
                if let bezierPath = self.currentBezierPath(3) {
                    self.path.append(bezierPath)
                    self.addedPaths += 1
                    self.activePath = nil
                }
               
                self.points[0] = self.points[3]
                self.pointPtr = 1
            }
            
            self.points[self.pointPtr] = point.location
            self.pointPtr += 1
        }
        
        guard let bezierPath = self.currentBezierPath(self.pointPtr - 1) else {
            return false
        }
       
        self.activePath = bezierPath
                
        return true
    }
    
    private func currentBezierPath(_ ctr: Int) -> UIBezierPath? {
        switch ctr {
        case 0:
            return nil
        case 1:
            let path = UIBezierPath()
            path.move(to: self.points[0])
            path.addLine(to: self.points[1])
            return path
        case 2:
            let path = UIBezierPath()
            path.move(to: self.points[0])
            path.addQuadCurve(to: self.points[2], controlPoint: self.points[1])
            return path
        case 3:
            let path = UIBezierPath()
            path.move(to: self.points[0])
            path.addCurve(to: self.points[3], controlPoint1: self.points[1], controlPoint2: self.points[2])
            return path
        default:
            return nil
        }
    }
}

