import Foundation
import UIKit
import Display
import LegacyComponents
import AccountContext
import MediaEditor

public func decodeDrawingEntities(data: Data) -> [DrawingEntity] {
    if let codableEntities = try? JSONDecoder().decode([CodableDrawingEntity].self, from: data) {
        return codableEntities.map { $0.entity }
    }
    return []
}

private func makeEntityView(context: AccountContext, entity: DrawingEntity) -> DrawingEntityView? {
    if let entity = entity as? DrawingBubbleEntity {
        return DrawingBubbleEntityView(context: context, entity: entity)
    } else if let entity = entity as? DrawingSimpleShapeEntity {
        return DrawingSimpleShapeEntityView(context: context, entity: entity)
    } else if let entity = entity as? DrawingStickerEntity {
        return DrawingStickerEntityView(context: context, entity: entity)
    } else if let entity = entity as? DrawingTextEntity {
        return DrawingTextEntityView(context: context, entity: entity)
    } else if let entity = entity as? DrawingVectorEntity {
        return DrawingVectorEntityView(context: context, entity: entity)
    } else if let entity = entity as? DrawingMediaEntity {
        return DrawingMediaEntityView(context: context, entity: entity)
    } else {
        return nil
    }
}

private func prepareForRendering(entityView: DrawingEntityView) {
    if let entityView = entityView as? DrawingBubbleEntityView {
        entityView.entity.renderImage = entityView.getRenderImage()
    }
    if let entityView = entityView as? DrawingSimpleShapeEntityView {
        entityView.entity.renderImage = entityView.getRenderImage()
    }
    if let entityView = entityView as? DrawingTextEntityView {
        entityView.entity.renderImage = entityView.getRenderImage()
        entityView.entity.renderSubEntities = entityView.getRenderSubEntities()
    }
    if let entityView = entityView as? DrawingVectorEntityView {
        entityView.entity.renderImage = entityView.getRenderImage()
    }
}

public final class DrawingEntitiesView: UIView, TGPhotoDrawingEntitiesView {
    private let context: AccountContext
    private let size: CGSize
    
    weak var drawingView: DrawingView?
    public weak var selectionContainerView: DrawingSelectionContainerView?
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    public private(set) var selectedEntityView: DrawingEntityView?
    
    public var getEntityEdgePositions: () -> UIEdgeInsets? = { return nil }
    public var getEntityCenterPosition: () -> CGPoint = { return .zero }
    public var getEntityInitialRotation: () -> CGFloat = { return 0.0 }
    public var getEntityAdditionalScale: () -> CGFloat = { return 1.0 }
    
    public var hasSelectionChanged: (Bool) -> Void = { _ in }
    var selectionChanged: (DrawingEntity?) -> Void = { _ in }
    var requestedMenuForEntityView: (DrawingEntityView, Bool) -> Void = { _, _ in }
    
    var entityAdded: (DrawingEntity) -> Void = { _ in }
    var entityRemoved: (DrawingEntity) -> Void = { _ in }
        
    private let topEdgeView = UIView()
    private let leftEdgeView = UIView()
    private let rightEdgeView = UIView()
    private let bottomEdgeView = UIView()
    private let xAxisView = UIView()
    private let yAxisView = UIView()
    private let angleLayer = SimpleShapeLayer()
    
    public var onInteractionUpdated: (Bool) -> Void = { _ in }
    public var edgePreviewUpdated: (Bool) -> Void = { _ in }
    
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, size: CGSize) {
        self.context = context
        self.size = size
                
        super.init(frame: CGRect(origin: .zero, size: size))
                
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer
        
        self.topEdgeView.alpha = 0.0
        self.topEdgeView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.topEdgeView.isUserInteractionEnabled = false
        
        self.leftEdgeView.alpha = 0.0
        self.leftEdgeView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.leftEdgeView.isUserInteractionEnabled = false
        
        self.rightEdgeView.alpha = 0.0
        self.rightEdgeView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.rightEdgeView.isUserInteractionEnabled = false
        
        self.bottomEdgeView.alpha = 0.0
        self.bottomEdgeView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.bottomEdgeView.isUserInteractionEnabled = false
        
        self.xAxisView.alpha = 0.0
        self.xAxisView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.xAxisView.isUserInteractionEnabled = false
        
        self.yAxisView.alpha = 0.0
        self.yAxisView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.yAxisView.isUserInteractionEnabled = false
        
        self.angleLayer.strokeColor = UIColor(rgb: 0xffd70a).cgColor
        self.angleLayer.opacity = 0.0
        self.angleLayer.lineDashPattern = [12, 12] as [NSNumber]
        
        self.addSubview(self.topEdgeView)
        self.addSubview(self.leftEdgeView)
        self.addSubview(self.rightEdgeView)
        self.addSubview(self.bottomEdgeView)
        
        self.addSubview(self.xAxisView)
        self.addSubview(self.yAxisView)
        self.layer.addSublayer(self.angleLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
    
        let referenceSize = self.convert(CGRect(origin: .zero, size: CGSize(width: 1.0 + UIScreenPixel, height: 1.0)), from: nil)
        let width = ceil(referenceSize.width)
        
        if let edges = self.getEntityEdgePositions() {
            self.topEdgeView.bounds = CGRect(origin: .zero, size: CGSize(width: 3000.0, height: width))
            self.topEdgeView.center = CGPoint(x: self.bounds.width / 2.0, y: edges.top)
            
            self.bottomEdgeView.bounds = CGRect(origin: .zero, size: CGSize(width: 3000.0, height: width))
            self.bottomEdgeView.center = CGPoint(x: self.bounds.width / 2.0, y: edges.bottom)
            
            self.leftEdgeView.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: 3000.0))
            self.leftEdgeView.center = CGPoint(x: edges.left, y: self.bounds.height / 2.0)
            
            self.rightEdgeView.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: 3000.0))
            self.rightEdgeView.center = CGPoint(x: edges.right, y: self.bounds.height / 2.0)
        }
        
        let point = self.getEntityCenterPosition()
        self.xAxisView.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: 3000.0))
        self.xAxisView.center = point
        self.xAxisView.transform = CGAffineTransform(rotationAngle: self.getEntityInitialRotation())
        
        self.yAxisView.bounds = CGRect(origin: .zero, size: CGSize(width: 3000.0, height: width))
        self.yAxisView.center = point
        self.yAxisView.transform = CGAffineTransform(rotationAngle: self.getEntityInitialRotation())
        
        let anglePath = CGMutablePath()
        anglePath.move(to: CGPoint(x: 0.0, y: width / 2.0))
        anglePath.addLine(to: CGPoint(x: 3000.0, y: width / 2.0))
        self.angleLayer.path = anglePath
        self.angleLayer.lineWidth = width
        self.angleLayer.bounds = CGRect(origin: .zero, size: CGSize(width: 3000.0, height: width))
    }
    
    public var entities: [DrawingEntity] {
        var entities: [DrawingEntity] = []
        for case let view as DrawingEntityView in self.subviews {
            entities.append(view.entity)
        }
        return entities
    }
    
    private var initialEntitiesData: Data?
    public func setup(withEntitiesData entitiesData: Data?) {
        self.clear()
        
        self.initialEntitiesData = entitiesData
        
        if let entitiesData = entitiesData, let codableEntities = try? JSONDecoder().decode([CodableDrawingEntity].self, from: entitiesData) {
            let entities = codableEntities.map { $0.entity }
            for entity in entities {
                self.add(entity, announce: false)
            }
        }
    }
    
    public static func encodeEntities(_ entities: [DrawingEntity], entitiesView: DrawingEntitiesView? = nil) -> [CodableDrawingEntity] {
        let entities = entities
        guard !entities.isEmpty else {
            return []
        }
        if let entitiesView {
            for entity in entities {
                if let entityView = entitiesView.getView(for: entity.uuid) {
                    prepareForRendering(entityView: entityView)
                }
            }
        }
        return entities.compactMap({ CodableDrawingEntity(entity: $0) })
    }
    
    public static func encodeEntitiesData(_ entities: [DrawingEntity], entitiesView: DrawingEntitiesView? = nil) -> Data? {
        let codableEntities = encodeEntities(entities, entitiesView: entitiesView)
        if let data = try? JSONEncoder().encode(codableEntities) {
            return data
        } else {
            return nil
        }
    }
    
    var entitiesData: Data? {
        return DrawingEntitiesView.encodeEntitiesData(self.entities, entitiesView: self)
    }
    
    var hasChanges: Bool {
        if let initialEntitiesData = self.initialEntitiesData {
            let entitiesData = self.entitiesData
            return entitiesData != initialEntitiesData
        } else {
            let filteredEntities = self.entities.filter { !$0.isMedia }
            return !filteredEntities.isEmpty
        }
    }
    
    private func startPosition(relativeTo entity: DrawingEntity?) -> CGPoint {
        let offsetLength = round(self.size.width * 0.1)
        let offset = CGPoint(x: offsetLength, y: offsetLength)
        if let entity = entity {
            return entity.center.offsetBy(dx: offset.x, dy: offset.y)
        } else {
            let minimalDistance: CGFloat = round(offsetLength * 0.5)
            var position = self.getEntityCenterPosition()
            
            while true {
                var occupied = false
                for case let view as DrawingEntityView in self.subviews {
                    if view.entity.isMedia {
                        continue
                    }
                    let location = view.entity.center
                    let distance = sqrt(pow(location.x - position.x, 2) + pow(location.y - position.y, 2))
                    if distance < minimalDistance {
                        occupied = true
                    }
                }
                if !occupied {
                    break
                } else {
                    position = position.offsetBy(dx: offset.x, dy: offset.y)
                }
            }
            return position
        }
    }
    
    private func newEntitySize() -> CGSize {
        let zoomScale = 1.0 / (self.drawingView?.zoomScale ?? 1.0)
        let width = round(self.size.width * 0.5) * zoomScale
        return CGSize(width: width, height: width)
    }
    
    public func prepareNewEntity(_ entity: DrawingEntity, setup: Bool = true, relativeTo: DrawingEntity? = nil) {
        let center = self.startPosition(relativeTo: relativeTo)
        let rotation = self.getEntityInitialRotation()
        let zoomScale = 1.0 / (self.drawingView?.zoomScale ?? 1.0)
        
        if let shape = entity as? DrawingSimpleShapeEntity {
            shape.position = center
            shape.rotation = rotation
            
            if setup {
                let size = self.newEntitySize()
                shape.referenceDrawingSize = self.size
                if shape.shapeType == .star {
                    shape.size = size
                } else {
                    shape.size = CGSize(width: size.width, height: round(size.height * 0.75))
                }
            }
        } else if let vector = entity as? DrawingVectorEntity {
            if setup {
                vector.drawingSize = self.size
                vector.referenceDrawingSize = self.size
                vector.start = CGPoint(x: center.x * 0.5, y: center.y)
                vector.mid = (0.5, 0.0)
                vector.end = CGPoint(x: center.x * 1.5, y: center.y)
                vector.type = .oneSidedArrow
            }
        } else if let sticker = entity as? DrawingStickerEntity {
            sticker.position = center
            sticker.rotation = rotation
            if setup {
                sticker.referenceDrawingSize = self.size
                sticker.scale = zoomScale
            }
        } else if let bubble = entity as? DrawingBubbleEntity {
            bubble.position = center
            bubble.rotation = rotation
            if setup {
                let size = self.newEntitySize()
                bubble.referenceDrawingSize = self.size
                bubble.size = CGSize(width: size.width, height: round(size.height * 0.7))
                bubble.tailPosition = CGPoint(x: 0.16, y: size.height * 0.18)
            }
        } else if let text = entity as? DrawingTextEntity {
            text.position = center
            text.rotation = rotation
            if setup {
                text.referenceDrawingSize = self.size
                text.width = floor(self.size.width * 0.9)
                text.fontSize = 0.3
                text.scale = zoomScale
            }
        }
    }
    
    @discardableResult
    public func add(_ entity: DrawingEntity, announce: Bool = true) -> DrawingEntityView {
        guard let view = makeEntityView(context: self.context, entity: entity) else {
            fatalError()
        }
        view.containerView = self
        
        func processSnap(snapped: Bool, snapView: UIView) {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            if snapped {
                self.insertSubview(snapView, belowSubview: view)
                if snapView.alpha < 1.0 {
                    self.hapticFeedback.impact(.light)
                }
                transition.updateAlpha(layer: snapView.layer, alpha: 1.0)
            } else {
                transition.updateAlpha(layer: snapView.layer, alpha: 0.0)
            }
        }
        
        view.onSnapUpdated = { [weak self, weak view] type, snapped in
            guard let self else {
                return
            }
            switch type {
            case .centerX:
                processSnap(snapped: snapped, snapView: self.xAxisView)
            case .centerY:
                processSnap(snapped: snapped, snapView: self.yAxisView)
            case .top:
                processSnap(snapped: snapped, snapView: self.topEdgeView)
                self.edgePreviewUpdated(snapped)
            case .left:
                processSnap(snapped: snapped, snapView: self.leftEdgeView)
                self.edgePreviewUpdated(snapped)
            case .right:
                processSnap(snapped: snapped, snapView: self.rightEdgeView)
                self.edgePreviewUpdated(snapped)
            case .bottom:
                processSnap(snapped: snapped, snapView: self.bottomEdgeView)
                self.edgePreviewUpdated(snapped)
            case let .rotation(angle):
                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                if let angle, let view {
                    self.layer.insertSublayer(self.angleLayer, below: view.layer)
                    self.angleLayer.transform = CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0)
                    if self.angleLayer.opacity < 1.0 {
                        self.hapticFeedback.impact(.light)
                    }
                    transition.updateAlpha(layer: self.angleLayer, alpha: 1.0)
                } else {
                    transition.updateAlpha(layer: self.angleLayer, alpha: 0.0)
                }
            }
        }
        view.onPositionUpdated = { [weak self] position in
            if let self {
                self.angleLayer.position = position
            }
        }
        view.onInteractionUpdated = { [weak self] interacting in
            if let self {
                self.onInteractionUpdated(interacting)
            }
        }
        
        view.update()
        self.addSubview(view)
        
        if announce {
            self.entityAdded(entity)
        }
        return view
    }
    
    func duplicate(_ entity: DrawingEntity) -> DrawingEntity {
        let newEntity = entity.duplicate()
        self.prepareNewEntity(newEntity, setup: false, relativeTo: entity)
        
        guard let view = makeEntityView(context: self.context, entity: entity) else {
            fatalError()
        }
        view.containerView = self
        view.update()
        self.addSubview(view)
        return newEntity
    }
    
    func remove(uuid: UUID, animated: Bool = false, announce: Bool = true) {
        if let view = self.getView(for: uuid) {
            if self.selectedEntityView === view {
                self.selectedEntityView = nil
                self.selectionChanged(nil)
                self.hasSelectionChanged(false)
            }
            if animated {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
                if !(view.entity is DrawingVectorEntity) {
                    view.layer.animateScale(from: view.entity.scale, to: 0.1, duration: 0.2, removeOnCompletion: false)
                }
                if let selectionView = view.selectionView {
                    selectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak selectionView] _ in
                        selectionView?.removeFromSuperview()
                    })
                    if !(view.entity is DrawingVectorEntity) {
                        selectionView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                    }
                }
            } else {
                view.removeFromSuperview()
            }
            
            if announce {
                self.entityRemoved(view.entity)
            }
        }
    }
    
    func removeAll() {
        self.clear(animated: true)
        self.selectionChanged(nil)
        self.hasSelectionChanged(false)
    }
    
    private func clear(animated: Bool = false) {
        if animated {
            for case let view as DrawingEntityView in self.subviews {
                if view.entity.isMedia {
                    continue
                }
                if let selectionView = view.selectionView {
                    selectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak selectionView] _ in
                        selectionView?.removeFromSuperview()
                    })
                }
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
                if !(view.entity is DrawingVectorEntity) {
                    view.layer.animateScale(from: 0.0, to: -0.99, duration: 0.2, removeOnCompletion: false, additive: true)
                }
            }
            
        } else {
            for case let view as DrawingEntityView in self.subviews {
                if view.entity.isMedia {
                    continue
                }
                view.selectionView?.removeFromSuperview()
                view.removeFromSuperview()
            }
        }
    }
    
    func bringToFront(uuid: UUID) {
        if let view = self.getView(for: uuid) {
            self.bringSubviewToFront(view)
        }
    }
    
    public func getView(for uuid: UUID) -> DrawingEntityView? {
        for case let view as DrawingEntityView in self.subviews {
            if view.entity.uuid == uuid {
                return view
            }
        }
        return nil
    }
    
    public func play() {
        for case let view as DrawingEntityView in self.subviews {
            view.play()
        }
    }
    
    public func pause() {
        for case let view as DrawingEntityView in self.subviews {
            view.pause()
        }
    }
    
    public func seek(to timestamp: Double) {
        for case let view as DrawingEntityView in self.subviews {
            view.seek(to: timestamp)
        }
    }
    
    public func resetToStart() {
        for case let view as DrawingEntityView in self.subviews {
            view.resetToStart()
        }
    }
    
    public func updateVisibility(_ visibility: Bool) {
        for case let view as DrawingEntityView in self.subviews {
            view.updateVisibility(visibility)
        }
    }
    
    @objc private func handleTap(_ gestureRecognzier: UITapGestureRecognizer) {
        let location = gestureRecognzier.location(in: self)
        
        var intersectedViews: [DrawingEntityView] = []
        for case let view as DrawingEntityView in self.subviews {
            if view.precisePoint(inside: self.convert(location, to: view)) {
                intersectedViews.append(view)
            }
        }
        
        if let entityView = intersectedViews.last {
            self.selectEntity(entityView.entity)
        }
    }
    
    public func selectEntity(_ entity: DrawingEntity?) {
        if entity?.isMedia == true {
            return
        }
        if entity !== self.selectedEntityView?.entity {
            if let selectedEntityView = self.selectedEntityView {
                if let textEntityView = selectedEntityView as? DrawingTextEntityView, textEntityView.isEditing {
                    if entity == nil {
                        textEntityView.endEditing()
                    } else {
                        return
                    }
                }
                
                self.selectedEntityView = nil
                if let selectionView = selectedEntityView.selectionView {
                    selectedEntityView.selectionView = nil
                    selectionView.removeFromSuperview()
                }
            }
        }
        
        if let entity = entity, let entityView = self.getView(for: entity.uuid) {
            self.selectedEntityView = entityView
            
            if let selectionView = entityView.makeSelectionView() {
                selectionView.tapped = { [weak self, weak entityView] in
                    if let strongSelf = self, let entityView = entityView {
                        strongSelf.requestedMenuForEntityView(entityView, strongSelf.subviews.last === entityView)
                    }
                }
                entityView.selectionView = selectionView
                self.selectionContainerView?.addSubview(selectionView)
            }
            entityView.update()
        }
        
        self.selectionChanged(self.selectedEntityView?.entity)
        self.hasSelectionChanged(self.selectedEntityView != nil)
    }
    
    var isTrackingAnyEntity: Bool {
        for case let view as DrawingEntityView in self.subviews {
            if view.isTracking {
                return true
            }
        }
        return false
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return super.point(inside: point, with: event)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        }
        if let result = result as? DrawingEntityView, !result.precisePoint(inside: self.convert(point, to: result)) {
            return nil
        }
        return result
    }
    
    public func clearSelection() {
        self.selectEntity(nil)
    }
    
    public func onZoom() {
        self.selectedEntityView?.updateSelectionView()
    }
    
    public var hasSelection: Bool {
        return self.selectedEntityView != nil
    }
    
    public func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        if !self.hasSelection, let mediaEntityView = self.subviews.first(where: { $0 is DrawingEntityMediaView }) as? DrawingEntityMediaView {
            mediaEntityView.handlePan(gestureRecognizer)
        }
    }
    
    public func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        if !self.hasSelection, let mediaEntityView = self.subviews.first(where: { $0 is DrawingEntityMediaView }) as? DrawingEntityMediaView {
            mediaEntityView.handlePinch(gestureRecognizer)
        } else if let selectedEntityView = self.selectedEntityView, let selectionView = selectedEntityView.selectionView {
            selectionView.handlePinch(gestureRecognizer)
        }
    }
    
    public func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        if !self.hasSelection, let mediaEntityView = self.subviews.first(where: { $0 is DrawingEntityMediaView }) as? DrawingEntityMediaView {
            mediaEntityView.handleRotate(gestureRecognizer)
        } else if let selectedEntityView = self.selectedEntityView, let selectionView = selectedEntityView.selectionView {
            selectionView.handleRotate(gestureRecognizer)
        }
    }
}

protocol DrawingEntityMediaView: DrawingEntityView {
    func handlePan(_ gestureRecognizer: UIPanGestureRecognizer)
    func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer)
    func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer)
}

public class DrawingEntityView: UIView {
    let context: AccountContext
    public let entity: DrawingEntity
    var isTracking = false
    
    public weak var selectionView: DrawingEntitySelectionView?
    weak var containerView: DrawingEntitiesView?
    
    var onSnapUpdated: (DrawingEntitySnapTool.SnapType, Bool) -> Void = { _, _ in }
    var onPositionUpdated: (CGPoint) -> Void = { _ in }
    var onInteractionUpdated: (Bool) -> Void = { _ in }
    
    init(context: AccountContext, entity: DrawingEntity) {
        self.context = context
        self.entity = entity
        
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let selectionView = self.selectionView {
            selectionView.removeFromSuperview()
        }
    }
    
    var selectionBounds: CGRect {
        return self.bounds
    }
    
    func play() {
        
    }
    
    func pause() {
        
    }
    
    func seek(to timestamp: Double) {
        
    }
    
    func resetToStart() {
        
    }
    
    func updateVisibility(_ visibility: Bool) {
        
    }
    
    public func update(animated: Bool = false) {
        self.updateSelectionView()
    }
    
    func updateSelectionView() {
        guard let selectionView = self.selectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
        
        selectionView.transform = .identity
        let bounds = self.selectionBounds
        let center = bounds.center
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        selectionView.center = self.convert(center, to: selectionView.superview)
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: bounds.width * scale + selectionView.selectionInset * 2.0, height: bounds.height * scale + selectionView.selectionInset * 2.0))
        
        self.popIdentityTransformForMeasurement()
    }
    
    private var realTransform: CGAffineTransform?
    func pushIdentityTransformForMeasurement() {
        guard self.realTransform == nil else {
            return
        }
        self.realTransform = self.transform
        self.transform = .identity
    }
    
    func popIdentityTransformForMeasurement() {
        guard let realTransform = self.realTransform else {
            return
        }
        self.transform = realTransform
        self.realTransform = nil
    }
    
    public func precisePoint(inside point: CGPoint) -> Bool {
        return self.point(inside: point, with: nil)
    }
    
    func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        return DrawingEntitySelectionView()
    }
}

let entitySelectionViewHandleSize = CGSize(width: 44.0, height: 44.0)
public class DrawingEntitySelectionView: UIView {
    weak var entityView: DrawingEntityView?
    
    var tapped: () -> Void = { }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        self.tapped()
    }
    
    @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
    }
    
    @objc func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
    }
    
    var selectionInset: CGFloat {
        return 0.0
    }
}

public class DrawingSelectionContainerView: UIView {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        }
        return result
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let result = super.point(inside: point, with: event)
        if !result {
            for subview in self.subviews {
                let subpoint = self.convert(point, to: subview)
                if subview.point(inside: subpoint, with: event) {
                    return true
                }
            }
        }
        return result
    }
}
