import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import LegacyComponents
import AppBundle
import ImageBlur

protocol DrawingRenderLayer: CALayer {
    
}

protocol DrawingRenderView: UIView {
    
}

protocol DrawingElement: AnyObject {
    var uuid: UUID { get }
    var translation: CGPoint { get set }
    var isValid: Bool { get }
    var bounds: CGRect { get }
    
    func setupRenderView(screenSize: CGSize) -> DrawingRenderView?
    func setupRenderLayer() -> DrawingRenderLayer?
    func updatePath(_ point: DrawingPoint, state: DrawingGesturePipeline.DrawingGestureState, zoomScale: CGFloat)
    
    func draw(in: CGContext, size: CGSize)
}

private enum DrawingOperation {
    case clearAll(CGRect)
    case slice(DrawingSlice)
    case addEntity(UUID)
    case removeEntity(DrawingEntity)
}

public final class DrawingView: UIView, UIGestureRecognizerDelegate, UIPencilInteractionDelegate, TGPhotoDrawingView {
    public var zoomOut: () -> Void = {}
    
    struct NavigationState {
        let canUndo: Bool
        let canRedo: Bool
        let canClear: Bool
        let canZoomOut: Bool
        let isDrawing: Bool
    }
    
    enum Action {
        case undo
        case redo
        case clear
        case zoomOut
    }
    
    enum Tool {
        case pen
        case arrow
        case marker
        case neon
        case eraser
        case blur
    }
        
    var tool: Tool = .pen
    var toolColor: DrawingColor = DrawingColor(color: .white)
    var toolBrushSize: CGFloat = 0.25
    
    var stateUpdated: (NavigationState) -> Void = { _ in }

    var shouldBegin: (CGPoint) -> Bool = { _ in return true }
    var getFullImage: () -> UIImage? = { return nil }
    
    var requestedColorPicker: () -> Void = {}
    var requestedEraserToggle: () -> Void = {}
    var requestedToolsToggle: () -> Void = {}
    
    private var undoStack: [DrawingOperation] = []
    private var redoStack: [DrawingOperation] = []
    fileprivate var uncommitedElement: DrawingElement?
    
    private(set) var drawingImage: UIImage?
    private let renderer: UIGraphicsImageRenderer
        
    private var currentDrawingViewContainer: UIImageView
    private var currentDrawingRenderView: DrawingRenderView?
    private var currentDrawingLayer: DrawingRenderLayer?
        
    private var metalView: DrawingMetalView?

    private let brushSizePreviewLayer: SimpleShapeLayer
    
    let imageSize: CGSize
    private(set) var zoomScale: CGFloat = 1.0
    
    private var drawingGesturePipeline: DrawingGesturePipeline?
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    
    private var loadedTemplates: [UnistrokeTemplate] = []
    private var previousStrokePoint: CGPoint?
    private var strokeRecognitionTimer: SwiftSignalKit.Timer?
    
    private var isDrawing = false
    private var drawingGestureStartTimestamp: Double?
    
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
    
    private let hapticFeedback = HapticFeedback()
    
    public var screenSize: CGSize
    
    private var previousPointTimestamp: Double?
    
    private let pencilInteraction: UIInteraction?
        
    init(size: CGSize) {
        self.imageSize = size
        self.screenSize = size
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        if #available(iOS 12.0, *) {
            format.preferredRange = .standard
        }
        format.opaque = false
        self.renderer = UIGraphicsImageRenderer(size: size, format: format)
                
        self.currentDrawingViewContainer = UIImageView()
        self.currentDrawingViewContainer.frame = CGRect(origin: .zero, size: size)
        self.currentDrawingViewContainer.contentScaleFactor = 1.0
        self.currentDrawingViewContainer.backgroundColor = .clear
        self.currentDrawingViewContainer.isUserInteractionEnabled = false
        
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
        
        if #available(iOS 12.1, *) {
            let pencilInteraction = UIPencilInteraction()
            self.pencilInteraction = pencilInteraction
        } else {
            self.pencilInteraction = nil
        }
        
        super.init(frame: CGRect(origin: .zero, size: size))
    
        Queue.mainQueue().async {
            self.loadTemplates()
        }
        
        if #available(iOS 12.1, *), let pencilInteraction = self.pencilInteraction as? UIPencilInteraction {
            pencilInteraction.delegate = self
            self.addInteraction(pencilInteraction)
        }
        
        self.backgroundColor = .clear
        self.contentScaleFactor = 1.0
        self.isExclusiveTouch = true
            
        self.addSubview(self.currentDrawingViewContainer)
    
        self.layer.addSublayer(self.brushSizePreviewLayer)
        
        let drawingGesturePipeline = DrawingGesturePipeline(view: self)
        drawingGesturePipeline.gestureRecognizer?.shouldBegin = { [weak self] point in
            if let strongSelf = self {
                if !strongSelf.shouldBegin(point) {
                    return false
                }
                if strongSelf.undoStack.isEmpty && !strongSelf.hasOpaqueData && strongSelf.tool == .eraser {
                    return false
                }
                if strongSelf.tool == .blur, strongSelf.preparedBlurredImage == nil {
                    return false
                }
                if let uncommitedElement = strongSelf.uncommitedElement as? PenTool, uncommitedElement.isFinishingArrow {
                    return false
                }
                return true
            } else {
                return false
            }
        }
        drawingGesturePipeline.onDrawing = { [weak self] state, point in
            guard let strongSelf = self else {
                return
            }
            let currentTimestamp = CACurrentMediaTime()
            switch state {
            case .began:
                strongSelf.isDrawing = true
                strongSelf.previousStrokePoint = nil
                strongSelf.drawingGestureStartTimestamp = currentTimestamp
                strongSelf.previousPointTimestamp = currentTimestamp
                
                if strongSelf.uncommitedElement != nil {
                    strongSelf.finishDrawing(rect: CGRect(origin: .zero, size: strongSelf.imageSize), synchronous: true)
                }
                
                if case .marker = strongSelf.tool, let metalView = strongSelf.metalView {
                    metalView.isHidden = false
                }
                
                guard let newElement = strongSelf.setupNewElement() else {
                    return
                }
                                
                if let renderView = newElement.setupRenderView(screenSize: strongSelf.screenSize) {
                    if let currentDrawingView = strongSelf.currentDrawingRenderView {
                        strongSelf.currentDrawingRenderView = nil
                        currentDrawingView.removeFromSuperview()
                    }
                    if strongSelf.tool == .eraser {
                        strongSelf.currentDrawingViewContainer.removeFromSuperview()
                        strongSelf.currentDrawingViewContainer.backgroundColor = .white
                        
                        renderView.layer.compositingFilter = "xor"
                        
                        strongSelf.currentDrawingViewContainer.addSubview(renderView)
                        strongSelf.mask = strongSelf.currentDrawingViewContainer
                    } else if strongSelf.tool == .blur {
                        strongSelf.currentDrawingViewContainer.mask = renderView
                        strongSelf.currentDrawingViewContainer.image = strongSelf.preparedBlurredImage
                    } else {
                        strongSelf.currentDrawingViewContainer.addSubview(renderView)
                    }
                    strongSelf.currentDrawingRenderView = renderView
                }
                
                if let renderLayer = newElement.setupRenderLayer() {
                    if let currentDrawingLayer = strongSelf.currentDrawingLayer {
                        strongSelf.currentDrawingLayer = nil
                        currentDrawingLayer.removeFromSuperlayer()
                    }
                    if strongSelf.tool == .eraser {
                        strongSelf.currentDrawingViewContainer.removeFromSuperview()
                        strongSelf.currentDrawingViewContainer.backgroundColor = .white
                        
                        renderLayer.compositingFilter = "xor"
                        
                        strongSelf.currentDrawingViewContainer.layer.addSublayer(renderLayer)
                        strongSelf.mask = strongSelf.currentDrawingViewContainer
                    } else if strongSelf.tool == .blur {
                        strongSelf.currentDrawingViewContainer.layer.mask = renderLayer
                        strongSelf.currentDrawingViewContainer.image = strongSelf.preparedBlurredImage
                    } else {
                        strongSelf.currentDrawingViewContainer.layer.addSublayer(renderLayer)
                    }
                    strongSelf.currentDrawingLayer = renderLayer
                }
                newElement.updatePath(point, state: state, zoomScale: strongSelf.zoomScale)
                strongSelf.uncommitedElement = newElement
                strongSelf.updateInternalState()
            case .changed:
                if let previousPointTimestamp = strongSelf.previousPointTimestamp, currentTimestamp - previousPointTimestamp < 0.016 {
                    return
                }
                strongSelf.previousPointTimestamp = currentTimestamp
                strongSelf.uncommitedElement?.updatePath(point, state: state, zoomScale: strongSelf.zoomScale)
                
//                if case let .direct(point) = path, let lastPoint = line.points.last {
//                    if let previousStrokePoint = strongSelf.previousStrokePoint, line.points.count > 10 {
//                        let currentTimestamp = CACurrentMediaTime()
//                        if lastPoint.location.distance(to: previousStrokePoint) > 10.0 {
//                            strongSelf.previousStrokePoint = lastPoint.location
//                            
//                            strongSelf.strokeRecognitionTimer?.invalidate()
//                            strongSelf.strokeRecognitionTimer = nil
//                        }
//                            
//                        if strongSelf.strokeRecognitionTimer == nil, let startTimestamp = strongSelf.drawingGestureStartTimestamp, currentTimestamp - startTimestamp < 3.0 {
//                            strongSelf.strokeRecognitionTimer = SwiftSignalKit.Timer(timeout: 0.85, repeat: false, completion: { [weak self] in
//                                guard let strongSelf = self else {
//                                    return
//                                }
//                                if let previousStrokePoint = strongSelf.previousStrokePoint, lastPoint.location.distance(to: previousStrokePoint) <= 10.0 {
//                                    let strokeRecognizer = Unistroke(points: line.points.map { $0.location })
//                                    if let template = strokeRecognizer.match(templates: strongSelf.loadedTemplates, minThreshold: 0.5) {
//                                        let edges = line.bounds
//                                        let bounds = CGRect(origin: edges.origin, size: CGSize(width: edges.width - edges.minX, height: edges.height - edges.minY))
//                                        
//                                        var entity: DrawingEntity?
//                                        if template == "shape_rectangle" {
//                                            let shapeEntity = DrawingSimpleShapeEntity(shapeType: .rectangle, drawType: .stroke, color: strongSelf.toolColor, lineWidth: strongSelf.toolBrushSize)
//                                            shapeEntity.referenceDrawingSize = strongSelf.imageSize
//                                            shapeEntity.position = bounds.center
//                                            shapeEntity.size = CGSize(width: bounds.size.width * 1.1, height: bounds.size.height * 1.1)
//                                            entity = shapeEntity
//                                        } else if template == "shape_circle" {
//                                            let shapeEntity = DrawingSimpleShapeEntity(shapeType: .ellipse, drawType: .stroke, color: strongSelf.toolColor, lineWidth: strongSelf.toolBrushSize)
//                                            shapeEntity.referenceDrawingSize = strongSelf.imageSize
//                                            shapeEntity.position = bounds.center
//                                            shapeEntity.size = CGSize(width: bounds.size.width * 1.1, height: bounds.size.height * 1.1)
//                                            entity = shapeEntity
//                                        } else if template == "shape_star" {
//                                            let shapeEntity = DrawingSimpleShapeEntity(shapeType: .star, drawType: .stroke, color: strongSelf.toolColor, lineWidth: strongSelf.toolBrushSize)
//                                            shapeEntity.referenceDrawingSize = strongSelf.imageSize
//                                            shapeEntity.position = bounds.center
//                                            shapeEntity.size = CGSize(width: max(bounds.width, bounds.height) * 1.1, height: max(bounds.width, bounds.height) * 1.1)
//                                            entity = shapeEntity
//                                        } else if template == "shape_arrow" {
//                                            let arrowEntity = DrawingVectorEntity(type: .oneSidedArrow, color: strongSelf.toolColor, lineWidth: strongSelf.toolBrushSize)
//                                            arrowEntity.referenceDrawingSize = strongSelf.imageSize
//                                            arrowEntity.start = line.points.first?.location ?? .zero
//                                            arrowEntity.end = line.points[line.points.count - 4].location
//                                            entity = arrowEntity
//                                        }
//                                        
//                                        if let entity = entity {
//                                            strongSelf.entitiesView?.add(entity)
//                                            strongSelf.entitiesView?.selectEntity(entity)
//                                            strongSelf.cancelDrawing()
//                                            strongSelf.drawingGesturePipeline?.gestureRecognizer?.isEnabled = false
//                                            strongSelf.drawingGesturePipeline?.gestureRecognizer?.isEnabled = true
//                                        }
//                                    }
//                                }
//                                strongSelf.strokeRecognitionTimer?.invalidate()
//                                strongSelf.strokeRecognitionTimer = nil
//                            }, queue: Queue.mainQueue())
//                            strongSelf.strokeRecognitionTimer?.start()
//                        }
//                    } else {
//                        strongSelf.previousStrokePoint = lastPoint.location
//                    }
//                }
            case .ended, .cancelled:
                strongSelf.isDrawing = false
                strongSelf.strokeRecognitionTimer?.invalidate()
                strongSelf.strokeRecognitionTimer = nil
                strongSelf.uncommitedElement?.updatePath(point, state: state, zoomScale: strongSelf.zoomScale)
                
                if strongSelf.uncommitedElement?.isValid == true {
                    let bounds = strongSelf.uncommitedElement?.bounds
                    Queue.mainQueue().after(0.05) {
                        if let bounds = bounds {
                            strongSelf.finishDrawing(rect: bounds, synchronous: true)
                        }
                    }
                } else {
                    strongSelf.cancelDrawing()
                }
                strongSelf.updateInternalState()
            }
        }
        self.drawingGesturePipeline = drawingGesturePipeline
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.45
        longPressGestureRecognizer.allowableMovement = 2.0
        longPressGestureRecognizer.delegate = self
        self.addGestureRecognizer(longPressGestureRecognizer)
        self.longPressGestureRecognizer = longPressGestureRecognizer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.longPressTimer?.invalidate()
        self.strokeRecognitionTimer?.invalidate()
    }
    
    public func setup(withDrawing drawingData: Data?) {
        if let drawingData = drawingData, let image = UIImage(data: drawingData) {
            self.hasOpaqueData = true
            
            if let context = DrawingContext(size: image.size, scale: 1.0, opaque: false) {
                context.withFlippedContext { context in
                    if let cgImage = image.cgImage {
                        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
                    }
                }
                self.drawingImage = context.generateImage() ?? image
            } else {
                self.drawingImage = image
            }
            self.layer.contents = image.cgImage
            self.updateInternalState()
        }
    }
    
    var hasOpaqueData = false
    var drawingData: Data? {
        guard !self.undoStack.isEmpty || self.hasOpaqueData else {
            return nil
        }
        return self.drawingImage?.pngData()
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @available(iOS 12.1, *)
    public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch UIPencilInteraction.preferredTapAction {
        case .switchEraser:
            self.requestedEraserToggle()
        case .showColorPalette:
            self.requestedColorPicker()
        case .switchPrevious:
            self.requestedToolsToggle()
        default:
            break
        }
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
                var toolColor = self.toolColor
                var blurredImage: UIImage?
                if self.tool == .marker {
                    toolColor = toolColor.withUpdatedAlpha(toolColor.alpha * 0.7)
                } else if self.tool == .eraser {
                    toolColor = DrawingColor.clear
                } else if self.tool == .blur {
                    blurredImage = self.preparedBlurredImage
                }
                
                self.hapticFeedback.prepareImpact(.medium)
                
                let fillCircleLayer = SimpleShapeLayer()
                self.longPressTimer = SwiftSignalKit.Timer(timeout: 0.25, repeat: false, completion: { [weak self, weak fillCircleLayer] in
                    if let strongSelf = self {
                        strongSelf.cancelDrawing()
                        
                        let action = {
                            let newElement = FillTool(drawingSize: strongSelf.imageSize, color: toolColor, blur: blurredImage != nil, blurredImage: blurredImage)
                            strongSelf.uncommitedElement = newElement
                            strongSelf.finishDrawing(rect: CGRect(origin: .zero, size: strongSelf.imageSize), synchronous: true)
                        }
                        if [.eraser, .blur].contains(strongSelf.tool) {
                            UIView.transition(with: strongSelf, duration: 0.2, options: .transitionCrossDissolve) {
                                action()
                            }
                        } else {
                            action()
                        }
                                                
                        strongSelf.fillCircleLayer = nil
                        fillCircleLayer?.removeFromSuperlayer()
                        
                        strongSelf.hapticFeedback.impact(.medium)
                    }
                }, queue: Queue.mainQueue())
                self.longPressTimer?.start()
                
                if [.eraser, .blur].contains(self.tool) {
    
                } else {
                    fillCircleLayer.bounds = CGRect(origin: .zero, size: CGSize(width: 160.0, height: 160.0))
                    fillCircleLayer.position = location
                    fillCircleLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 160.0, height: 160.0))).cgPath
                    fillCircleLayer.fillColor = toolColor.toCGColor()
                    
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
    private func commit(interactive: Bool = false, synchronous: Bool = true, completion: @escaping () -> Void = {}) {
        let currentImage = self.drawingImage
        let uncommitedElement = self.uncommitedElement
        let imageSize = self.imageSize
        
        let action = {
            let updatedImage = self.renderer.image { context in
                context.cgContext.setBlendMode(.copy)
                context.cgContext.clear(CGRect(origin: .zero, size: imageSize))
                if let image = currentImage {
                    image.draw(at: .zero)
                }
                if let uncommitedElement = uncommitedElement {
                    context.cgContext.setBlendMode(.normal)
                    uncommitedElement.draw(in: context.cgContext, size: imageSize)
                }
            }
            Queue.mainQueue().async {
                self.drawingImage = updatedImage
                self.layer.contents = updatedImage.cgImage
                
                if let currentDrawingRenderView = self.currentDrawingRenderView {
                    if case .eraser = self.tool {
                        currentDrawingRenderView.removeFromSuperview()
                        self.mask = nil
                        self.insertSubview(self.currentDrawingViewContainer, at: 0)
                        self.currentDrawingViewContainer.backgroundColor = .clear
                    } else if case .blur = self.tool {
                        self.currentDrawingViewContainer.mask = nil
                        self.currentDrawingViewContainer.image = nil
                    } else {
                        if let renderView = currentDrawingRenderView as? PenTool.RenderView, renderView.isDryingUp {
                            renderView.onDryingUp = { [weak renderView] in
                                renderView?.removeFromSuperview()
                            }
                        } else {
                            currentDrawingRenderView.removeFromSuperview()
                        }
                    }
                    self.currentDrawingRenderView = nil
                }
                if let currentDrawingLayer = self.currentDrawingLayer {
                    if case .eraser = self.tool {
                        currentDrawingLayer.removeFromSuperlayer()
                        self.mask = nil
                        self.insertSubview(self.currentDrawingViewContainer, at: 0)
                        self.currentDrawingViewContainer.backgroundColor = .clear
                    } else if case .blur = self.tool {
                        self.currentDrawingViewContainer.layer.mask = nil
                        self.currentDrawingViewContainer.image = nil
                    } else {
                        currentDrawingLayer.removeFromSuperlayer()
                    }
                    self.currentDrawingLayer = nil
                }
                
                if self.tool == .marker {
                    //self.metalView?.clear()
                    self.metalView?.isHidden = true
                }
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
        
    fileprivate func cancelDrawing() {
        self.uncommitedElement = nil
        
        if let currentDrawingRenderView = self.currentDrawingRenderView {
            if case .eraser = self.tool {
                currentDrawingRenderView.removeFromSuperview()
                self.mask = nil
                self.insertSubview(self.currentDrawingViewContainer, at: 0)
                self.currentDrawingViewContainer.backgroundColor = .clear
            } else if case .blur = self.tool {
                self.currentDrawingViewContainer.mask = nil
                self.currentDrawingViewContainer.image = nil
            } else {
                currentDrawingRenderView.removeFromSuperview()
            }
            self.currentDrawingRenderView = nil
        }
        if let currentDrawingLayer = self.currentDrawingLayer {
            if self.tool == .eraser {
                currentDrawingLayer.removeFromSuperlayer()
                self.mask = nil
                self.insertSubview(self.currentDrawingViewContainer, at: 0)
                self.currentDrawingViewContainer.backgroundColor = .clear
            } else if self.tool == .blur {
                self.currentDrawingViewContainer.mask = nil
                self.currentDrawingViewContainer.image = nil
            } else {
                currentDrawingLayer.removeFromSuperlayer()
            }
            self.currentDrawingLayer = nil
        }
        if case .marker = self.tool {
            self.metalView?.isHidden = true
        }
    }
    
    private func slice(for rect: CGRect) -> DrawingSlice? {
        if let subImage = self.drawingImage?.cgImage?.cropping(to: rect) {
            return DrawingSlice(image: subImage, rect: rect)
        }
        return nil
    }
        
    fileprivate func finishDrawing(rect: CGRect, synchronous: Bool = false) {
        let complete: (Bool) -> Void = { synchronous in
            if let uncommitedElement = self.uncommitedElement, !uncommitedElement.isValid {
                self.uncommitedElement = nil
            }
            if !self.undoStack.isEmpty || self.hasOpaqueData, let slice = self.slice(for: rect) {
                self.undoStack.append(.slice(slice))
            } else {
                self.undoStack.append(.clearAll(rect))
            }
            
            self.commit(interactive: true, synchronous: synchronous)
            
            self.redoStack.removeAll()
            self.uncommitedElement = nil
            
            self.updateInternalState()
        }
        if let uncommitedElement = self.uncommitedElement as? PenTool {
            if uncommitedElement.hasArrow {
                uncommitedElement.finishArrow {
                    complete(true)
                }
            } else {
                complete(true)
            }
        } else {
            complete(synchronous)
        }
    }
    
    weak var entitiesView: DrawingEntitiesView?
    func clear() {
        self.entitiesView?.removeAll()
        
        self.uncommitedElement = nil
        self.undoStack.removeAll()
        self.redoStack.removeAll()
        self.hasOpaqueData = false
        
        let snapshotView = UIImageView(image: self.drawingImage)
        snapshotView.frame = self.bounds
        self.addSubview(snapshotView)
        
        self.drawingImage = nil
        self.layer.contents = nil
        
        Queue.mainQueue().justDispatch {
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
        
        self.updateInternalState()
        
        self.updateBlurredImage()
    }
    
    private func applySlice(_ slice: DrawingSlice) {
        let updatedImage = self.renderer.image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: imageSize))
            context.cgContext.setBlendMode(.copy)
            if let image = self.drawingImage {
                image.draw(at: .zero)
            }
            if let image = slice.image {
                context.cgContext.translateBy(x: imageSize.width / 2.0, y: imageSize.height / 2.0)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.translateBy(x: -imageSize.width / 2.0, y: -imageSize.height / 2.0)
                context.cgContext.translateBy(x: slice.rect.minX, y: imageSize.height - slice.rect.maxY)
                context.cgContext.draw(image, in: CGRect(origin: .zero, size: slice.rect.size))
            }
        }
        self.drawingImage = updatedImage
        self.layer.contents = updatedImage.cgImage
    }
    
    var canUndo: Bool {
        return !self.undoStack.isEmpty
    }
    
    private func undo() {
        guard let lastOperation = self.undoStack.last else {
            return
        }
        switch lastOperation {
        case let .clearAll(rect):
            if let slice = self.slice(for: rect) {
                self.redoStack.append(.slice(slice))
            }
            UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve) {
                self.drawingImage = nil
                self.layer.contents = nil
            }
            self.updateBlurredImage()
        case let .slice(slice):
            if let slice = self.slice(for: slice.rect) {
                self.redoStack.append(.slice(slice))
            }
            UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve) {
                self.applySlice(slice)
            }
            self.updateBlurredImage()
        case let .addEntity(uuid):
            if let entityView = self.entitiesView?.getView(for: uuid) {
                self.entitiesView?.remove(uuid: uuid, animated: true, announce: false)
                self.redoStack.append(.removeEntity(entityView.entity))
            }
        case let .removeEntity(entity):
            if let view = self.entitiesView?.add(entity, announce: false) {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                if !(entity is DrawingVectorEntity) {
                    view.layer.animateScale(from: 0.1, to: entity.scale, duration: 0.2)
                }
            }
            self.redoStack.append(.addEntity(entity.uuid))
        }
        
        self.undoStack.removeLast()

        self.updateInternalState()
    }
    
    private func redo() {
        guard let lastOperation = self.redoStack.last else {
            return
        }
        
        switch lastOperation {
            case .clearAll:
                break
            case let .slice(slice):
                if !self.undoStack.isEmpty || self.hasOpaqueData, let slice = self.slice(for: slice.rect) {
                    self.undoStack.append(.slice(slice))
                } else {
                    self.undoStack.append(.clearAll(slice.rect))
                }
                UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve) {
                    self.applySlice(slice)
                }
                self.updateBlurredImage()
            case let .addEntity(uuid):
                if let entityView = self.entitiesView?.getView(for: uuid) {
                    self.entitiesView?.remove(uuid: uuid, animated: true, announce: false)
                    self.undoStack.append(.removeEntity(entityView.entity))
                }
            case let .removeEntity(entity):
                if let view = self.entitiesView?.add(entity, announce: false) {
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    if !(entity is DrawingVectorEntity) {
                        view.layer.animateScale(from: 0.1, to: entity.scale, duration: 0.2)
                    }
                }
                self.undoStack.append(.addEntity(entity.uuid))
        }
        
        self.redoStack.removeLast()
        
        self.updateInternalState()
    }
    
    func onEntityAdded(_ entity: DrawingEntity) {
        self.redoStack.removeAll()
        self.undoStack.append(.addEntity(entity.uuid))
        
        self.updateInternalState()
    }
    
    func onEntityRemoved(_ entity: DrawingEntity) {
        self.redoStack.removeAll()
        self.undoStack.append(.removeEntity(entity))
        
        self.updateInternalState()
    }
    
    private var preparedBlurredImage: UIImage?
    
    func updateToolState(_ state: DrawingToolState) {
        let previousTool = self.tool
        switch state {
        case let .pen(brushState):
            self.tool = .pen
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
        case let .arrow(brushState):
            self.tool = .arrow
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
        case let .marker(brushState):
            self.tool = .marker
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
            
            var size = self.imageSize
            if Int(size.width) % 16 != 0 {
                size.width = ceil(size.width / 16.0) * 16.0
            }
            
            if self.metalView == nil, let metalView = DrawingMetalView(size: size) {
                metalView.transform = self.currentDrawingViewContainer.transform
                if size.width != self.imageSize.width {
                    let scaledSize = size.preciseAspectFilled(self.currentDrawingViewContainer.frame.size)
                    metalView.frame = CGRect(origin: .zero, size: scaledSize)
                } else {
                    metalView.frame = self.currentDrawingViewContainer.frame
                }
                self.insertSubview(metalView, aboveSubview: self.currentDrawingViewContainer)
                self.metalView = metalView
            }
        case let .neon(brushState):
            self.tool = .neon
            self.toolColor = brushState.color
            self.toolBrushSize = brushState.size
        case let .blur(blurState):
            self.tool = .blur
            self.toolBrushSize = blurState.size
        case let .eraser(eraserState):
            self.tool = .eraser
            self.toolBrushSize = eraserState.size
        }
        
        if self.tool != previousTool {
            self.updateBlurredImage()
        }
    }
    
    func updateBlurredImage() {
        if case .blur = self.tool {
            Queue.concurrentDefaultQueue().async {
                if let image = self.getFullImage() {
                    Queue.mainQueue().async {
                        self.preparedBlurredImage = image
                    }
                }
            }
        } else {
            self.preparedBlurredImage = nil
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
            canUndo: !self.undoStack.isEmpty,
            canRedo: !self.redoStack.isEmpty,
            canClear: !self.undoStack.isEmpty || self.hasOpaqueData || !(self.entitiesView?.entities.isEmpty ?? true),
            canZoomOut: self.zoomScale > 1.0 + .ulpOfOne,
            isDrawing: self.isDrawing
        ))
    }
    
    public func updateZoomScale(_ scale: CGFloat) {
        self.cancelDrawing()
        self.zoomScale = scale
        self.updateInternalState()
    }

    private func setupNewElement() -> DrawingElement? {
        let scale = 1.0 / self.zoomScale
        let element: DrawingElement?
        switch self.tool {
        case .pen:
            let penTool = PenTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                hasArrow: false,
                isEraser: false,
                isBlur: false,
                blurredImage: nil
            )
            element = penTool
        case .arrow:
            let penTool = PenTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                hasArrow: true,
                isEraser: false,
                isBlur: false,
                blurredImage: nil
            )
            element = penTool
        case .marker:
            let markerTool = MarkerTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale
            )
            markerTool.metalView = self.metalView
            element = markerTool
        case .neon:
            element = NeonTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale
            )
        case .blur:
            let penTool = PenTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                hasArrow: false,
                isEraser: false,
                isBlur: true,
                blurredImage: self.preparedBlurredImage
            )
            element = penTool
        case .eraser:
            let penTool = PenTool(
                drawingSize: self.imageSize,
                color: self.toolColor,
                lineWidth: self.toolBrushSize * scale,
                hasArrow: false,
                isEraser: true,
                isBlur: false,
                blurredImage: nil
            )
            element = penTool
        }
        return element
    }
    
    func setBrushSizePreview(_ size: CGFloat?) {
        let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
        if let size = size {
            let minLineWidth = max(1.0, max(self.frame.width, self.frame.height) * 0.002)
            let maxLineWidth = max(10.0, max(self.frame.width, self.frame.height) * 0.07)
            
            let minBrushSize = minLineWidth
            let maxBrushSize = maxLineWidth
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
        self.currentDrawingViewContainer.transform = transform
        self.currentDrawingViewContainer.frame = self.bounds
        
        self.drawingGesturePipeline?.transform = CGAffineTransformMakeScale(1.0 / scale, 1.0 / scale)
            
        if let metalView = self.metalView {
            var size = self.imageSize
            if Int(size.width) % 16 != 0 {
                size.width = ceil(size.width / 16.0) * 16.0
            }
            metalView.transform = transform
            if size.width != self.imageSize.width {
                let scaledSize = size.preciseAspectFilled(self.currentDrawingViewContainer.frame.size)
                metalView.frame = CGRect(origin: .zero, size: scaledSize)
            } else {
                metalView.frame = self.currentDrawingViewContainer.frame
            }
        }
        
        self.brushSizePreviewLayer.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
    }
    
    public var isEmpty: Bool {
        return self.undoStack.isEmpty && !self.hasOpaqueData
    }
    
    public var scale: CGFloat {
        return self.bounds.width / self.imageSize.width
    }
    
    public var isTracking: Bool {
        return self.uncommitedElement != nil
    }
}

private extension CGSize {
    func preciseAspectFilled(_ size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
}

private class DrawingSlice {
    private static let queue = Queue()
    
    var _image: CGImage?
    
    let uuid: UUID
    var image: CGImage? {
        if let image = self._image {
            return image
        } else if let data = try? Data(contentsOf: URL(fileURLWithPath: self.path)) {
            return UIImage(data: data)?.cgImage
        } else {
            return nil
        }
    }
    let rect: CGRect
    let path: String
    
    init(image: CGImage, rect: CGRect) {
        self.uuid = UUID()
                
        self._image = image
        self.rect = rect
        self.path = NSTemporaryDirectory() + "/drawing_\(uuid.hashValue).slice"
        
        DrawingSlice.queue.after(2.0) {
            let image = UIImage(cgImage: image)
            if let data = image.pngData() as? NSData {
                try? data.write(toFile: self.path)
                Queue.mainQueue().async {
                    self._image = nil
                }
            }
        }
    }
    
    deinit {
        try? FileManager.default.removeItem(atPath: self.path)
    }
}
