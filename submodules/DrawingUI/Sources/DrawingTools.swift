import Foundation
import UIKit
import Display

final class MarkerTool: DrawingElement, Codable {
    let uuid: UUID
    
    let drawingSize: CGSize
    let color: DrawingColor
    
    let renderLineWidth: CGFloat
    
    var translation = CGPoint()
    
    var points: [CGPoint] = []
    
    weak var metalView: DrawingMetalView?
    
    var isValid: Bool {
        return !self.points.isEmpty
    }
        
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = color
        
        let minLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.01)
        let maxLineWidth = max(20.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderLineWidth = lineWidth
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case drawingSize
        case color
        case renderLineWidth
        case points
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.drawingSize = try container.decode(CGSize.self, forKey: .drawingSize)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.renderLineWidth = try container.decode(CGFloat.self, forKey: .renderLineWidth)
        self.points = try container.decode([CGPoint].self, forKey: .points)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.drawingSize, forKey: .drawingSize)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.renderLineWidth, forKey: .renderLineWidth)
        try container.encode(self.points, forKey: .points)
    }
    
    func setupRenderView(screenSize: CGSize) -> DrawingRenderView? {
        return nil
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    private var didSetup = false
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .location(point) = path else {
            return
        }
             
        self.points.append(point.location)
        
        self.didSetup = true
        self.metalView?.updated(point, state: state, brush: .marker, color: self.color, size: self.renderLineWidth)
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard !self.points.isEmpty else {
            return
        }
        context.saveGState()
        
        context.translateBy(x: self.translation.x, y: self.translation.y)
        
        let didSetup = self.didSetup
        if didSetup {
            self.didSetup = false
        } else {
            self.metalView?.setup(self.points, brush: .marker, color: self.color, size: self.renderLineWidth)
        }
        self.metalView?.drawInContext(context)
        if !didSetup {
            self.metalView?.clear()
        }
        
        context.restoreGState()
    }
}
    
final class NeonTool: DrawingElement, Codable {
    class RenderLayer: SimpleLayer, DrawingRenderLayer {
        var lineWidth: CGFloat = 0.0
        
        let shadowLayer = SimpleShapeLayer()
        let borderLayer = SimpleShapeLayer()
        let fillLayer = SimpleShapeLayer()
        
        func setup(size: CGSize, color: DrawingColor, lineWidth: CGFloat, strokeWidth: CGFloat, shadowRadius: CGFloat) {
            self.contentsScale = 1.0
            self.lineWidth = lineWidth
                        
            let bounds = CGRect(origin: .zero, size: size)
            self.frame = bounds
            
            self.shadowLayer.frame = bounds
            self.shadowLayer.backgroundColor = UIColor.clear.cgColor
            self.shadowLayer.contentsScale = 1.0
            self.shadowLayer.lineWidth = strokeWidth * 0.5
            self.shadowLayer.lineCap = .round
            self.shadowLayer.lineJoin = .round
            self.shadowLayer.fillColor = UIColor.white.cgColor
            self.shadowLayer.strokeColor = UIColor.white.cgColor
            self.shadowLayer.shadowColor = color.toCGColor()
            self.shadowLayer.shadowRadius = shadowRadius
            self.shadowLayer.shadowOpacity = 1.0
            self.shadowLayer.shadowOffset = .zero

            self.borderLayer.frame = bounds
            self.borderLayer.contentsScale = 1.0
            self.borderLayer.lineWidth = strokeWidth
            self.borderLayer.lineCap = .round
            self.borderLayer.lineJoin = .round
            self.borderLayer.fillColor = UIColor.clear.cgColor
            self.borderLayer.strokeColor = UIColor.white.mixedWith(color.toUIColor(), alpha: 0.25).cgColor
            
            self.fillLayer.frame = bounds
            self.fillLayer.contentsScale = 1.0
            self.fillLayer.fillColor = UIColor.white.cgColor
            
            self.addSublayer(self.shadowLayer)
            self.addSublayer(self.borderLayer)
            self.addSublayer(self.fillLayer)
        }
        
        func updatePath(_ path: CGPath) {
            self.shadowLayer.path = path
            self.borderLayer.path = path
            self.fillLayer.path = path
        }
    }
    
    let uuid: UUID
    
    let drawingSize: CGSize
    let color: DrawingColor
        
    var renderPath: CGPath?
    let renderStrokeWidth: CGFloat
    let renderShadowRadius: CGFloat
    let renderLineWidth: CGFloat
    
    var translation = CGPoint()
    
    private var currentRenderLayer: DrawingRenderLayer?
    
    var isValid: Bool {
        return self.renderPath != nil
    }
        
    required init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = color
        
        let strokeWidth = min(drawingSize.width, drawingSize.height) * 0.008
        let shadowRadius = min(drawingSize.width, drawingSize.height) * 0.03
        
        let minLineWidth = max(1.0, max(drawingSize.width, drawingSize.height) * 0.003)
        let maxLineWidth = max(10.0, max(drawingSize.width, drawingSize.height) * 0.09)
        let lineWidth = minLineWidth + (maxLineWidth - minLineWidth) * lineWidth
        
        self.renderStrokeWidth = strokeWidth
        self.renderShadowRadius = shadowRadius
        self.renderLineWidth = lineWidth
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case drawingSize
        case color
        case renderStrokeWidth
        case renderShadowRadius
        case renderLineWidth
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.drawingSize = try container.decode(CGSize.self, forKey: .drawingSize)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.renderStrokeWidth = try container.decode(CGFloat.self, forKey: .renderStrokeWidth)
        self.renderShadowRadius = try container.decode(CGFloat.self, forKey: .renderShadowRadius)
        self.renderLineWidth = try container.decode(CGFloat.self, forKey: .renderLineWidth)
//        self.points = try container.decode([CGPoint].self, forKey: .points)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.drawingSize, forKey: .drawingSize)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.renderStrokeWidth, forKey: .renderStrokeWidth)
        try container.encode(self.renderShadowRadius, forKey: .renderShadowRadius)
        try container.encode(self.renderLineWidth, forKey: .renderLineWidth)
//        try container.encode(self.points, forKey: .points)
    }
    
    func setupRenderView(screenSize: CGSize) -> DrawingRenderView? {
        return nil
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        let layer = RenderLayer()
        layer.setup(size: self.drawingSize, color: self.color, lineWidth: self.renderLineWidth, strokeWidth: self.renderStrokeWidth, shadowRadius: self.renderShadowRadius)
        self.currentRenderLayer = layer
        return layer
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
        guard case let .smoothCurve(bezierPath) = path else {
            return
        }
        
        let cgPath = bezierPath.path.cgPath.copy(strokingWithWidth: self.renderLineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
        self.renderPath = cgPath
        
        if let currentRenderLayer = self.currentRenderLayer as? RenderLayer {
            currentRenderLayer.updatePath(cgPath)
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

        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(self.renderStrokeWidth * 0.5)
        context.setShadow(offset: .zero, blur: self.renderShadowRadius * 1.9, color: self.color.toCGColor())
        context.drawPath(using: .fillStroke)

        context.addPath(path)
        context.setShadow(offset: .zero, blur: 0.0, color: UIColor.clear.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(self.renderStrokeWidth)
        context.setStrokeColor(UIColor.white.mixedWith(self.color.toUIColor(), alpha: 0.25).cgColor)
        context.strokePath()

        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)

        context.fillPath()
        
        context.restoreGState()
    }
}

final class FillTool: DrawingElement, Codable {
    let uuid: UUID

    let drawingSize: CGSize
    let color: DrawingColor
    let isBlur: Bool
    var blurredImage: UIImage?
    
    var translation = CGPoint()
    
    var isValid: Bool {
        return true
    }
    
    required init(drawingSize: CGSize, color: DrawingColor, blur: Bool, blurredImage: UIImage?) {
        self.uuid = UUID()
        self.drawingSize = drawingSize
        self.color = color
        self.isBlur = blur
        self.blurredImage = blurredImage
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case drawingSize
        case color
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.drawingSize = try container.decode(CGSize.self, forKey: .drawingSize)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.isBlur = false
//        self.points = try container.decode([CGPoint].self, forKey: .points)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.drawingSize, forKey: .drawingSize)
        try container.encode(self.color, forKey: .color)
//        try container.encode(self.points, forKey: .points)
    }
    
    func setupRenderView(screenSize: CGSize) -> DrawingRenderView? {
        return nil
    }
    
    func setupRenderLayer() -> DrawingRenderLayer? {
        return nil
    }
    
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState) {
    }

    func draw(in context: CGContext, size: CGSize) {
        context.setShouldAntialias(false)

        context.setBlendMode(.copy)
        
        if self.isBlur {
            if let blurredImage = self.blurredImage?.cgImage {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                context.draw(blurredImage, in: CGRect(origin: .zero, size: size))
            }
        } else {
            context.setFillColor(self.color.toCGColor())
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        context.setBlendMode(.normal)
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return false
    }
    
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool {
        return false
    }
}
