import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import LegacyComponents
import AppBundle
import ImageBlur

protocol DrawingElement: AnyObject {
    var uuid: UUID { get }
    var bounds: CGRect { get }
    var points: [Polyline.Point] { get }

    var translation: CGPoint { get set }
    
    var renderLineWidth: CGFloat { get }
    
    func containsPoint(_ point: CGPoint) -> Bool
    func hasPointsInsidePath(_ path: UIBezierPath) -> Bool
    
    init(drawingSize: CGSize, color: DrawingColor, lineWidth: CGFloat, arrow: Bool)
    
    func setupRenderLayer() -> DrawingRenderLayer?
    func updatePath(_ path: DrawingGesturePipeline.DrawingResult, state: DrawingGesturePipeline.DrawingGestureState)
    
    func draw(in: CGContext, size: CGSize)
}

enum DrawingCommand {
    enum DrawingElementTransform {
        case move(offset: CGPoint)
    }
    
    case addStroke(DrawingElement)
    case updateStrokes([UUID], DrawingElementTransform)
    case removeStroke(DrawingElement)
    case addEntity(DrawingEntity)
    case updateEntity(UUID, DrawingEntity)
    case removeEntity(DrawingEntity)
    case updateEntityZOrder(UUID, Int32)
}

public final class DrawingView: UIView, UIGestureRecognizerDelegate, TGPhotoDrawingView {
    public var zoomOut: () -> Void = {}
    
    struct NavigationState {
        let canUndo: Bool
        let canRedo: Bool
        let canClear: Bool
        let canZoomOut: Bool
    }
    
    enum Action {
        case undo
        case redo
        case clear
        case zoomOut
    }
    
    enum Tool {
        case pen
        case marker
        case neon
        case pencil
        case eraser
        case lasso
        case objectRemover
        case blur
    }
        
    var tool: Tool = .pen
    var toolColor: DrawingColor = DrawingColor(color: .white)
    var toolBrushSize: CGFloat = 0.25
    var toolHasArrow: Bool = false
    
    var stateUpdated: (NavigationState) -> Void = { _ in }

    var shouldBegin: (CGPoint) -> Bool = { _ in return true }
    var requestMenu: ([UUID], CGRect) -> Void = { _, _ in }
    var getFullImage: (Bool) -> UIImage? = { _ in return nil }
    
    private var elements: [DrawingElement] = []
    private var redoElements: [DrawingElement] = []
    fileprivate var uncommitedElement: DrawingElement?
    
    private(set) var drawingImage: UIImage?
    private let renderer: UIGraphicsImageRenderer
        
    private var currentDrawingView: UIView
    private var currentDrawingLayer: DrawingRenderLayer?
    
    private var pannedSelectionView: UIView
    
    var lassoView: DrawingLassoView
    private var metalView: DrawingMetalView

    private let brushSizePreviewLayer: SimpleShapeLayer
    
    let imageSize: CGSize
    private var zoomScale: CGFloat = 1.0
    
    private var drawingGesturePipeline: DrawingGesturePipeline?
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    
    private var loadedTemplates: [UnistrokeTemplate] = []
    private var previousStrokePoint: CGPoint?
    private var strokeRecognitionTimer: SwiftSignalKit.Timer?
    
    private func loadTemplates() {
        func load(_ name: String) {
            if let url = getAppBundle().url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any],
               let points = json["points"] as? [Any]
            {
                var strokePoints: [CGPoint] = []
                for point in points {
                    let x = (point as! [Any]).first as! Double
                    let y = (point as! [Any]).last as! Double
                    strokePoints.append(CGPoint(x: x, y: y))
                }
                let template = UnistrokeTemplate(name: name, points: strokePoints)
                self.loadedTemplates.append(template)
            }
        }
        
        load("shape_rectangle")
        load("shape_circle")
        load("shape_star")
        load("shape_arrow")
    }
    
    public init(size: CGSize) {
        self.imageSize = size
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        self.renderer = UIGraphicsImageRenderer(size: size, format: format)
                
        self.currentDrawingView = UIView()
        self.currentDrawingView.frame = CGRect(origin: .zero, size: size)
        self.currentDrawingView.contentScaleFactor = 1.0
        self.currentDrawingView.backgroundColor = .clear
        self.currentDrawingView.isUserInteractionEnabled = false
        
        self.pannedSelectionView = UIView()
        self.pannedSelectionView.frame = CGRect(origin: .zero, size: size)
        self.pannedSelectionView.contentScaleFactor = 1.0
        self.pannedSelectionView.backgroundColor = .clear
        self.pannedSelectionView.isUserInteractionEnabled = false
        
        self.lassoView = DrawingLassoView(size: size)
        self.lassoView.isHidden = true
                
        self.metalView = DrawingMetalView(size: size)!
        self.metalView.isHidden = true
        
        self.brushSizePreviewLayer = SimpleShapeLayer()
        self.brushSizePreviewLayer.bounds = CGRect(origin: .zero, size: CGSize(width: 100.0, height: 100.0))
        self.brushSizePreviewLayer.strokeColor = UIColor(rgb: 0x919191).cgColor
        self.brushSizePreviewLayer.fillColor = UIColor.white.cgColor
        self.brushSizePreviewLayer.path = CGPath(ellipseIn: CGRect(origin: .zero, size: CGSize(width: 100.0, height: 100.0)), transform: nil)
        self.brushSizePreviewLayer.opacity = 0.0
        self.brushSizePreviewLayer.shadowColor = UIColor.black.cgColor
        self.brushSizePreviewLayer.shadowOpacity = 0.5
        self.brushSizePreviewLayer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        self.brushSizePreviewLayer.shadowRadius = 20.0
        
        super.init(frame: CGRect(origin: .zero, size: size))
    
        Queue.mainQueue().async {
            self.loadTemplates()
        }
        
        self.backgroundColor = .clear
        self.contentScaleFactor = 1.0
            
        self.addSubview(self.currentDrawingView)
        self.addSubview(self.metalView)
        self.lassoView.addSubview(self.pannedSelectionView)
        self.addSubview(self.lassoView)
        self.layer.addSublayer(self.brushSizePreviewLayer)
        
        let drawingGesturePipeline = DrawingGesturePipeline(view: self)
        drawingGesturePipeline.gestureRecognizer?.shouldBegin = { [weak self] point in
            if let strongSelf = self {
                if !strongSelf.shouldBegin(point) {
                    return false
                }
                if !strongSelf.lassoView.isHidden && strongSelf.lassoView.point(inside: strongSelf.convert(point, to: strongSelf.lassoView), with: nil) {
                    return false
                }
                return true
            } else {
                return false
            }
        }
        drawingGesturePipeline.onDrawing = { [weak self] state, path in
            guard let strongSelf = self else {
                return
            }
            if case .objectRemover = strongSelf.tool {
                if case let .location(point) = path {
                    var elementsToRemove: [DrawingElement] = []
                    for element in strongSelf.elements {
                        if element.containsPoint(point.location) {
                            elementsToRemove.append(element)
                        }
                    }
                    
                    for element in elementsToRemove {
                        strongSelf.removeElement(element)
                    }
                }
            } else if case .lasso = strongSelf.tool {
                if case let .smoothCurve(bezierPath) = path {
                    let scale = strongSelf.bounds.width / strongSelf.imageSize.width
                    
                    switch state {
                    case .began:
                        strongSelf.lassoView.setup(scale: scale)
                        strongSelf.lassoView.updatePath(bezierPath)
                    case .changed:
                        strongSelf.lassoView.updatePath(bezierPath)
                    case .ended:
                        let closedPath = bezierPath.closedCopy()
                        
                        var selectedElements: [DrawingElement] = []
                        var selectedPoints: [CGPoint] = []
                        var maxLineWidth: CGFloat = 0.0
                        for element in strongSelf.elements {
                            if element.hasPointsInsidePath(closedPath.path) {
                                maxLineWidth = max(maxLineWidth, element.renderLineWidth)
                                selectedElements.append(element)
                                selectedPoints.append(contentsOf: element.points.map { $0.location })
                            }
                        }
                        
                        if selectedPoints.count > 0 {
                            strongSelf.lassoView.apply(scale: scale, points: selectedPoints, selectedElements: selectedElements.map { $0.uuid }, expand: maxLineWidth)
                        } else {
                            strongSelf.lassoView.reset()
                        }
                    case .cancelled:
                        strongSelf.lassoView.reset()
                    }
                }
            } else {
                switch state {
                case .began:
                    strongSelf.previousStrokePoint = nil
                    
                    if strongSelf.uncommitedElement != nil {
                        strongSelf.finishDrawing()
                    }
                    
                    guard let newElement = strongSelf.prepareNewElement() else {
                        return
                    }
                    
                    if newElement is MarkerTool || newElement is PencilTool {
                        self?.metalView.isHidden = false
                    }
                    
                    if let renderLayer = newElement.setupRenderLayer() {
                        strongSelf.currentDrawingView.layer.addSublayer(renderLayer)
                        strongSelf.currentDrawingLayer = renderLayer
                    }
                    newElement.updatePath(path, state: state)
                    strongSelf.uncommitedElement = newElement
                case .changed:
                    strongSelf.uncommitedElement?.updatePath(path, state: state)
                    
                    if case let .polyline(line) = path, let lastPoint = line.points.last {
                        if let previousStrokePoint = strongSelf.previousStrokePoint, line.points.count > 10 {
                            if lastPoint.location.distance(to: previousStrokePoint) > 10.0 {
                                strongSelf.previousStrokePoint = lastPoint.location
                                
                                strongSelf.strokeRecognitionTimer?.invalidate()
                                strongSelf.strokeRecognitionTimer = nil
                            }
                                
                            if strongSelf.strokeRecognitionTimer == nil {
                                strongSelf.strokeRecognitionTimer = SwiftSignalKit.Timer(timeout: 0.85, repeat: false, completion: { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if let previousStrokePoint = strongSelf.previousStrokePoint, lastPoint.location.distance(to: previousStrokePoint) <= 10.0 {
                                        let strokeRecognizer = Unistroke(points: line.points.map { $0.location })
                                        if let template = strokeRecognizer.match(templates: strongSelf.loadedTemplates, minThreshold: 0.5) {
                                            
                                            let edges = line.bounds
                                            let bounds = CGRect(origin: edges.origin, size: CGSize(width: edges.width - edges.minX, height: edges.height - edges.minY))
                                            
                                            var entity: DrawingEntity?
                                            if template == "shape_rectangle" {
                                                let shapeEntity = DrawingSimpleShapeEntity(shapeType: .rectangle, drawType: .stroke, color: strongSelf.toolColor, lineWidth: 0.25)
                                                shapeEntity.referenceDrawingSize = strongSelf.imageSize
                                                shapeEntity.position = bounds.center
                                                shapeEntity.size = bounds.size
                                                entity = shapeEntity
                                            } else if template == "shape_circle" {
                                                let shapeEntity = DrawingSimpleShapeEntity(shapeType: .ellipse, drawType: .stroke, color: strongSelf.toolColor, lineWidth: 0.25)
                                                shapeEntity.referenceDrawingSize = strongSelf.imageSize
                                                shapeEntity.position = bounds.center
                                                shapeEntity.size = bounds.size
                                                entity = shapeEntity
                                            } else if template == "shape_star" {
                                                let shapeEntity = DrawingSimpleShapeEntity(shapeType: .star, drawType: .stroke, color: strongSelf.toolColor, lineWidth: 0.25)
                                                shapeEntity.referenceDrawingSize = strongSelf.imageSize
                                                shapeEntity.position = bounds.center
                                                shapeEntity.size = CGSize(width: max(bounds.width, bounds.height), height: max(bounds.width, bounds.height))
                                                entity = shapeEntity
                                            } else if template == "shape_arrow" {
                                                let arrowEntity = DrawingVectorEntity(type: .oneSidedArrow, color: strongSelf.toolColor, lineWidth: 0.2)
                                                arrowEntity.referenceDrawingSize = strongSelf.imageSize
                                                arrowEntity.start = line.points.first?.location ?? .zero
                                                arrowEntity.end = line.points[line.points.count - 4].location
                                                entity = arrowEntity
                                            }
                                            
                                            if let entity = entity {
                                                strongSelf.entitiesView?.add(entity)
                                                strongSelf.cancelDrawing()
                                                strongSelf.drawingGesturePipeline?.gestureRecognizer?.isEnabled = false
                                                strongSelf.drawingGesturePipeline?.gestureRecognizer?.isEnabled = true
                                            }
                                        }
                                    }
                                    strongSelf.strokeRecognitionTimer?.invalidate()
                                    strongSelf.strokeRecognitionTimer = nil
                                }, queue: Queue.mainQueue())
                                strongSelf.strokeRecognitionTimer?.start()
                            }
                        } else {
                            strongSelf.previousStrokePoint = lastPoint.location
                        }
                    }
                    
                case .ended:
                    strongSelf.strokeRecognitionTimer?.invalidate()
                    strongSelf.strokeRecognitionTimer = nil
                    strongSelf.uncommitedElement?.updatePath(path, state: state)
                    Queue.mainQueue().after(0.05) {
                        strongSelf.finishDrawing()
                    }
                case .cancelled:
                    strongSelf.strokeRecognitionTimer?.invalidate()
                    strongSelf.strokeRecognitionTimer = nil
                    strongSelf.cancelDrawing()
                }
            }
        }
        self.drawingGesturePipeline = drawingGesturePipeline
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.45
        longPressGestureRecognizer.allowableMovement = 2.0
        longPressGestureRecognizer.delegate = self
        self.addGestureRecognizer(longPressGestureRecognizer)
        self.longPressGestureRecognizer = longPressGestureRecognizer
        
        self.lassoView.requestMenu = { [weak self] elements, rect in
            if let strongSelf = self {
                strongSelf.requestMenu(elements, rect)
            }
        }
        
        self.lassoView.panBegan = { [weak self] elements in
            if let strongSelf = self {
                strongSelf.skipDrawing = Set(elements)
                strongSelf.commit(reset: true)
                strongSelf.updateSelectionContent()
            }
        }
        
        self.lassoView.panChanged = { [weak self] elements, offset in
            if let strongSelf = self {
                let offset = CGPoint(x: offset.x * -1.0, y: offset.y * -1.0)
                strongSelf.lassoView.bounds = CGRect(origin: offset, size: strongSelf.lassoView.bounds.size)
            }
        }
        
        self.lassoView.panEnded = { [weak self] elements, offset in
            if let strongSelf = self {
                let elementsSet = Set(elements)
                for element in strongSelf.elements {
                    if elementsSet.contains(element.uuid) {
                        element.translation = element.translation.offsetBy(offset)
                    }
                }
                strongSelf.skipDrawing = Set()
                strongSelf.commit(reset: true, completion: {
                    strongSelf.pannedSelectionView.layer.contents = nil
                    
                    strongSelf.lassoView.bounds = CGRect(origin: .zero, size: strongSelf.lassoView.bounds.size)
                    strongSelf.lassoView.translate(offset)
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.longPressTimer?.invalidate()
        self.strokeRecognitionTimer?.invalidate()
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.longPressGestureRecognizer, !self.lassoView.isHidden {
            return false
        }
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    private var longPressTimer: SwiftSignalKit.Timer?
    private var fillCircleLayer: CALayer?
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let location = gestureRecognizer.location(in: self)
        switch gestureRecognizer.state {
        case .began:
            self.longPressTimer?.invalidate()
            self.longPressTimer = nil
            
            if self.longPressTimer == nil {
                self.longPressTimer = SwiftSignalKit.Timer(timeout: 0.25, repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.cancelDrawing()
                        
                        let newElement = FillTool(drawingSize: strongSelf.imageSize, color: strongSelf.toolColor, lineWidth: 0.0, arrow: false)
                        strongSelf.uncommitedElement = newElement
                        strongSelf.finishDrawing()
                    }
                }, queue: Queue.mainQueue())
                self.longPressTimer?.start()
                
                let fillCircleLayer = SimpleShapeLayer()
                fillCircleLayer.bounds = CGRect(origin: .zero, size: CGSize(width: 160.0, height: 160.0))
                fillCircleLayer.position = location
                fillCircleLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 160.0, height: 160.0))).cgPath
                fillCircleLayer.fillColor = self.toolColor.toCGColor()
                self.layer.addSublayer(fillCircleLayer)
                self.fillCircleLayer = fillCircleLayer
                
                fillCircleLayer.animateScale(from: 0.01, to: 12.0, duration: 0.35, removeOnCompletion: false, completion: { [weak self] _ in
                    if let strongSelf = self {
                        if let fillCircleLayer = strongSelf.fillCircleLayer {
                            strongSelf.fillCircleLayer = nil
                            fillCircleLayer.removeFromSuperlayer()
                        }
                    }
                })
            }
        case .ended, .cancelled:
            self.longPressTimer?.invalidate()
            self.longPressTimer = nil
            if let fillCircleLayer = self.fillCircleLayer {
                self.fillCircleLayer = nil
                fillCircleLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak fillCircleLayer] _ in
                    fillCircleLayer?.removeFromSuperlayer()
                })
            }
        default:
            break
        }
    }
        
    private let queue = Queue()
    private var skipDrawing = Set<UUID>()
    private func commit(reset: Bool = false, interactive: Bool = false, synchronous: Bool = false, completion: @escaping () -> Void = {}) {
        let currentImage = self.drawingImage
        let uncommitedElement = self.uncommitedElement
        let imageSize = self.imageSize
        let skipDrawing = self.skipDrawing
        
        let action = {
            let updatedImage = self.renderer.image { context in
                if !reset {
                    context.cgContext.clear(CGRect(origin: .zero, size: imageSize))
                    if let image = currentImage {
                        image.draw(at: .zero)
                    }
                    if let uncommitedElement = uncommitedElement {
                        uncommitedElement.draw(in: context.cgContext, size: imageSize)
                    }
                } else {
                    context.cgContext.clear(CGRect(origin: .zero, size: imageSize))
                    for element in self.elements {
                        if !skipDrawing.contains(element.uuid) {
                            element.draw(in: context.cgContext, size: imageSize)
                        }
                    }
                }
            }
            Queue.mainQueue().async {
                self.drawingImage = updatedImage
                self.layer.contents = updatedImage.cgImage
                
                if let currentDrawingLayer = self.currentDrawingLayer {
                    self.currentDrawingLayer = nil
                    currentDrawingLayer.removeFromSuperlayer()
                }
                
                self.metalView.clear()
                self.metalView.isHidden = true
                
                completion()
            }
        }
        if synchronous {
            action()
        } else {
            self.queue.async {
                action()
            }
        }
    }
    
    private func updateSelectionContent() {
        let selectionImage = self.renderer.image { context in
            for element in self.elements {
                if self.skipDrawing.contains(element.uuid) {
                    element.draw(in: context.cgContext, size: self.imageSize)
                }
            }
        }
        self.pannedSelectionView.layer.contents = selectionImage.cgImage
    }
    
    fileprivate func cancelDrawing() {
        self.uncommitedElement = nil
        
        if let currentDrawingLayer = self.currentDrawingLayer {
            self.currentDrawingLayer = nil
            currentDrawingLayer.removeFromSuperlayer()
        }
    }
        
    fileprivate func finishDrawing() {
        let complete: (Bool) -> Void = { synchronous in
            self.commit(interactive: true, synchronous: synchronous)
            
            self.redoElements.removeAll()
            if let uncommitedElement = self.uncommitedElement {
                self.elements.append(uncommitedElement)
                self.uncommitedElement = nil
            }
            
            self.updateInternalState()
        }
        if let uncommitedElement = self.uncommitedElement as? PenTool, uncommitedElement.arrow {
            uncommitedElement.finishArrow({
                complete(true)
            })
        } else {
            complete(false)
        }
    }
    
    weak var entitiesView: DrawingEntitiesView?
    func clear() {
        self.entitiesView?.removeAll()
        
        self.uncommitedElement = nil
        self.elements.removeAll()
        self.redoElements.removeAll()
        self.drawingImage = nil
        self.commit(reset: true)
        
        self.updateInternalState()
        
        self.lassoView.reset()
    }
    
    private func undo() {
        guard let lastElement = self.elements.last else {
            return
        }
        self.uncommitedElement = nil
        self.redoElements.append(lastElement)
        self.elements.removeLast()
        self.commit(reset: true)
        
        self.updateInternalState()
    }
    
    private func redo() {
        guard let lastElement = self.redoElements.last else {
            return
        }
        self.uncommitedElement = nil
        self.elements.append(lastElement)
        self.redoElements.removeLast()
        self.uncommitedElement = lastElement
        self.commit(reset: false)
        self.uncommitedElement = nil
        
        self.updateInternalState()
    }
    
    private var preparredEraserImage: UIImage?
    
    func updateToolState(_ state: DrawingToolState) {
        switch state {
        case let .pen(brushState):
            self.drawingGesturePipeline?.mode = .location
            self.tool = .pen
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
            self.toolHasArrow = brushState.mode == .arrow
        case let .marker(brushState):
            self.drawingGesturePipeline?.mode = .location
            self.tool = .marker
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
            self.toolHasArrow = brushState.mode == .arrow
        case let .neon(brushState):
            self.drawingGesturePipeline?.mode = .smoothCurve
            self.tool = .neon
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
            self.toolHasArrow = brushState.mode == .arrow
        case let .pencil(brushState):
            self.drawingGesturePipeline?.mode = .location
            self.tool = .pencil
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
            self.toolHasArrow = brushState.mode == .arrow
        case .lasso:
            self.drawingGesturePipeline?.mode = .smoothCurve
            self.tool = .lasso
        case let .eraser(eraserState):
            switch eraserState.mode {
            case .bitmap:
                self.tool = .eraser
                self.drawingGesturePipeline?.mode = .smoothCurve
            case .vector:
                self.tool = .objectRemover
                self.drawingGesturePipeline?.mode = .location
            case .blur:
                self.tool = .blur
                self.drawingGesturePipeline?.mode = .smoothCurve
            }
            self.toolBrushSize = eraserState.size
        }
        
        if [.eraser, .blur].contains(self.tool) {
            Queue.concurrentDefaultQueue().async {
                if let image = self.getFullImage(self.tool == .blur) {
                    if case .eraser = self.tool {
                        Queue.mainQueue().async {
                            self.preparredEraserImage = image
                        }
                    } else {
//                        let format = UIGraphicsImageRendererFormat()
//                        format.scale = 1.0
//                        let size = image.size.fitted(CGSize(width: 256, height: 256))
//                        let renderer = UIGraphicsImageRenderer(size: size, format: format)
//                        let scaledImage = renderer.image { _ in
//                            image.draw(in: CGRect(origin: .zero, size: size))
//                        }
                        
                        let blurredImage = blurredImage(image, radius: 60.0)
                        Queue.mainQueue().async {
                            self.preparredEraserImage = blurredImage
                        }
                    }
                }
            }
        } else {
            self.preparredEraserImage = nil
        }
        
    }
    
    func performAction(_ action: Action) {
        switch action {
        case .undo:
            self.undo()
        case .redo:
            self.redo()
        case .clear:
            self.clear()
        case .zoomOut:
            self.zoomOut()
        }
    }

    private func updateInternalState() {
        self.stateUpdated(NavigationState(
            canUndo: !self.elements.isEmpty,
            canRedo: !self.redoElements.isEmpty,
            canClear: !self.elements.isEmpty,
            canZoomOut: self.zoomScale > 1.0 + .ulpOfOne
        ))
    }
    
    public func updateZoomScale(_ scale: CGFloat) {
        self.zoomScale = scale
        self.updateInternalState()
    }

    private func prepareNewElement() -> DrawingElement? {
        let scale = 1.0 / self.zoomScale
        let element: DrawingElement?
        switch self.tool {
        case .pen:
            let penTool = PenTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                arrow: self.toolHasArrow
            )
            element = penTool
        case .marker:
            let markerTool = MarkerTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                arrow: self.toolHasArrow
            )
            markerTool.metalView = self.metalView
            element = markerTool
        case .neon:
            element = NeonTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                arrow: self.toolHasArrow
            )
        case .pencil:
            let pencilTool = PencilTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                arrow: self.toolHasArrow
            )
            pencilTool.metalView = self.metalView
            element = pencilTool
        case .blur:
            let blurTool = BlurTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                arrow: false)
            blurTool.getFullImage = { [weak self] in
                return self?.preparredEraserImage
            }
            element = blurTool
        case .eraser:
            let eraserTool = EraserTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                arrow: false)
            eraserTool.getFullImage = { [weak self] in
                return self?.preparredEraserImage
            }
            element = eraserTool
        default:
            element = nil
        }
        return element
    }
    
    func removeElement(_ element: DrawingElement) {
        self.elements.removeAll(where: { $0 === element })
        self.commit(reset: true)
    }
    
    func removeElements(_ elements: [UUID]) {
        self.elements.removeAll(where: { elements.contains($0.uuid) })
        self.commit(reset: true)
        
        self.lassoView.reset()
    }
    
    func setBrushSizePreview(_ size: CGFloat?) {
        let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
        if let size = size {
            let minBrushSize = 2.0
            let maxBrushSize = 28.0
            let brushSize = minBrushSize + (maxBrushSize - minBrushSize) * size
            
            self.brushSizePreviewLayer.transform = CATransform3DMakeScale(brushSize / 100.0, brushSize / 100.0, 1.0)
            transition.setAlpha(layer: self.brushSizePreviewLayer, alpha: 1.0)
        } else {
            transition.setAlpha(layer: self.brushSizePreviewLayer, alpha: 0.0)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let scale = self.scale
        let transform = CGAffineTransformMakeScale(scale, scale)
        self.currentDrawingView.transform = transform
        self.currentDrawingView.frame = self.bounds
        
        self.drawingGesturePipeline?.transform = CGAffineTransformMakeScale(1.0 / scale, 1.0 / scale)
    
        self.lassoView.transform = transform
        self.lassoView.frame = self.bounds
        
        self.metalView.transform = transform
        self.metalView.frame = self.bounds
                        
        self.brushSizePreviewLayer.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
    }
    
    public var isEmpty: Bool {
        return self.elements.isEmpty
    }
    
    public var scale: CGFloat {
        return self.bounds.width / self.imageSize.width
    }
    
    public var isTracking: Bool {
        return self.uncommitedElement != nil
    }
}

class DrawingLassoView: UIView {
    private var lassoBlackLayer: SimpleShapeLayer
    private var lassoWhiteLayer: SimpleShapeLayer
    
    var requestMenu: ([UUID], CGRect) -> Void = { _, _ in }
    
    var panBegan: ([UUID]) -> Void = { _ in }
    var panChanged: ([UUID], CGPoint) -> Void = { _, _ in }
    var panEnded:  ([UUID], CGPoint) -> Void = { _, _ in }
    
    private var currentScale: CGFloat = 1.0
    private var currentPoints: [CGPoint] = []
    private var selectedElements: [UUID] = []
    private var currentExpand: CGFloat = 0.0
    
    init(size: CGSize) {
        self.lassoBlackLayer = SimpleShapeLayer()
        self.lassoBlackLayer.frame = CGRect(origin: .zero, size: size)
        
        self.lassoWhiteLayer = SimpleShapeLayer()
        self.lassoWhiteLayer.frame = CGRect(origin: .zero, size: size)
        
        super.init(frame: CGRect(origin: .zero, size: size))
        
        self.layer.addSublayer(self.lassoBlackLayer)
        self.layer.addSublayer(self.lassoWhiteLayer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tapGestureRecognizer.numberOfTouchesRequired = 1
        self.addGestureRecognizer(tapGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        self.addGestureRecognizer(panGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(scale: CGFloat) {
        self.isHidden = false
        
        let dash: CGFloat = 5.0 / scale
        
        self.lassoBlackLayer.opacity = 0.5
        self.lassoBlackLayer.fillColor = UIColor.clear.cgColor
        self.lassoBlackLayer.strokeColor = UIColor.black.cgColor
        self.lassoBlackLayer.lineWidth = 2.0 / scale
        self.lassoBlackLayer.lineJoin = .round
        self.lassoBlackLayer.lineCap = .round
        self.lassoBlackLayer.lineDashPattern = [dash as NSNumber, dash * 2.5 as NSNumber]
        
        let blackAnimation = CABasicAnimation(keyPath: "lineDashPhase")
        blackAnimation.fromValue = dash * 3.5
        blackAnimation.toValue = 0
        blackAnimation.duration = 0.45
        blackAnimation.repeatCount = .infinity
        self.lassoBlackLayer.add(blackAnimation, forKey: "lineDashPhase")
        
        self.lassoWhiteLayer.opacity = 0.5
        self.lassoWhiteLayer.fillColor = UIColor.clear.cgColor
        self.lassoWhiteLayer.strokeColor = UIColor.white.cgColor
        self.lassoWhiteLayer.lineWidth = 2.0 / scale
        self.lassoWhiteLayer.lineJoin = .round
        self.lassoWhiteLayer.lineCap = .round
        self.lassoWhiteLayer.lineDashPattern = [dash as NSNumber, dash * 2.5 as NSNumber]
        
        let whiteAnimation = CABasicAnimation(keyPath: "lineDashPhase")
        whiteAnimation.fromValue = dash * 3.5 + dash * 1.75
        whiteAnimation.toValue = dash * 1.75
        whiteAnimation.duration = 0.45
        whiteAnimation.repeatCount = .infinity
        self.lassoWhiteLayer.add(whiteAnimation, forKey: "lineDashPhase")
    }
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let path = self.lassoBlackLayer.path else {
            return
        }
        self.requestMenu(self.selectedElements, path.boundingBox)
    }
    
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            self.panBegan(self.selectedElements)
        case .changed:
            self.panChanged(self.selectedElements, translation)
        case .ended:
            self.panEnded(self.selectedElements, translation)
        default:
            break
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let path = self.lassoBlackLayer.path {
            return path.contains(point)
        } else {
            return false
        }
    }
    
    func updatePath(_ bezierPath: BezierPath) {
        self.lassoBlackLayer.path = bezierPath.path.cgPath
        self.lassoWhiteLayer.path = bezierPath.path.cgPath
    }
    
    func translate(_ offset: CGPoint) {
        let updatedPoints = self.currentPoints.map { $0.offsetBy(offset) }
        
        self.apply(scale: self.currentScale, points: updatedPoints, selectedElements: self.selectedElements, expand: self.currentExpand)
    }
    
    func apply(scale: CGFloat, points: [CGPoint], selectedElements: [UUID], expand: CGFloat) {
        self.currentScale = scale
        self.currentPoints = points
        self.selectedElements = selectedElements
        self.currentExpand = expand
        
        let dash: CGFloat = 5.0 / scale
        
        let hullPath = concaveHullPath(points: points)
        let expandedPath = expandPath(hullPath, width: expand)
        self.lassoBlackLayer.path = expandedPath
        self.lassoWhiteLayer.path = expandedPath
        
        self.lassoBlackLayer.removeAllAnimations()
        self.lassoWhiteLayer.removeAllAnimations()
        
        let blackAnimation = CABasicAnimation(keyPath: "lineDashPhase")
        blackAnimation.fromValue = 0
        blackAnimation.toValue = dash * 3.5
        blackAnimation.duration = 0.45
        blackAnimation.repeatCount = .infinity
        self.lassoBlackLayer.add(blackAnimation, forKey: "lineDashPhase")
        
        self.lassoWhiteLayer.fillColor = UIColor.clear.cgColor
        self.lassoWhiteLayer.strokeColor = UIColor.white.cgColor
        self.lassoWhiteLayer.lineWidth = 2.0 / scale
        self.lassoWhiteLayer.lineJoin = .round
        self.lassoWhiteLayer.lineCap = .round
        self.lassoWhiteLayer.lineDashPattern = [dash as NSNumber, dash * 2.5 as NSNumber]
        
        let whiteAnimation = CABasicAnimation(keyPath: "lineDashPhase")
        whiteAnimation.fromValue = dash * 1.75
        whiteAnimation.toValue = dash * 3.5 + dash * 1.75
        whiteAnimation.duration = 0.45
        whiteAnimation.repeatCount = .infinity
        self.lassoWhiteLayer.add(whiteAnimation, forKey: "lineDashPhase")
    }
    
    func reset() {
        self.bounds = CGRect(origin: .zero, size: self.bounds.size)
        
        self.selectedElements = []
        
        self.isHidden = true
        self.lassoBlackLayer.path = nil
        self.lassoWhiteLayer.path = nil
        self.lassoBlackLayer.removeAllAnimations()
        self.lassoWhiteLayer.removeAllAnimations()
    }
}
