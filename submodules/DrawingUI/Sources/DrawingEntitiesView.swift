import Foundation
import UIKit
import Display
import LegacyComponents
import AccountContext


public protocol DrawingEntity: AnyObject {
    var uuid: UUID { get }
    var isAnimated: Bool { get }
    var center: CGPoint { get }
    
    var lineWidth: CGFloat { get set }
    var color: DrawingColor { get set }
    
    var scale: CGFloat { get set }
    
    func duplicate() -> DrawingEntity
        
    var currentEntityView: DrawingEntityView? { get }
    func makeView(context: AccountContext) -> DrawingEntityView
    
    func prepareForRender()
}

enum CodableDrawingEntity {
    case sticker(DrawingStickerEntity)
    case text(DrawingTextEntity)
    case simpleShape(DrawingSimpleShapeEntity)
    case bubble(DrawingBubbleEntity)
    case vector(DrawingVectorEntity)
    
    init?(entity: DrawingEntity) {
        if let entity = entity as? DrawingStickerEntity {
            self = .sticker(entity)
        } else if let entity = entity as? DrawingTextEntity {
            self = .text(entity)
        } else if let entity = entity as? DrawingSimpleShapeEntity {
            self = .simpleShape(entity)
        } else if let entity = entity as? DrawingBubbleEntity {
            self = .bubble(entity)
        } else if let entity = entity as? DrawingVectorEntity {
            self = .vector(entity)
        } else {
            return nil
        }
    }
    
    var entity: DrawingEntity {
        switch self {
        case let .sticker(entity):
            return entity
        case let .text(entity):
            return entity
        case let .simpleShape(entity):
            return entity
        case let .bubble(entity):
            return entity
        case let .vector(entity):
            return entity
        }
    }
}

public func decodeDrawingEntities(data: Data) -> [DrawingEntity] {
    if let codableEntities = try? JSONDecoder().decode([CodableDrawingEntity].self, from: data) {
        return codableEntities.map { $0.entity }
    }
    return []
}

extension CodableDrawingEntity: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case entity
    }

    private enum EntityType: Int, Codable {
        case sticker
        case text
        case simpleShape
        case bubble
        case vector
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EntityType.self, forKey: .type)
        switch type {
        case .sticker:
            self = .sticker(try container.decode(DrawingStickerEntity.self, forKey: .entity))
        case .text:
            self = .text(try container.decode(DrawingTextEntity.self, forKey: .entity))
        case .simpleShape:
            self = .simpleShape(try container.decode(DrawingSimpleShapeEntity.self, forKey: .entity))
        case .bubble:
            self = .bubble(try container.decode(DrawingBubbleEntity.self, forKey: .entity))
        case .vector:
            self = .vector(try container.decode(DrawingVectorEntity.self, forKey: .entity))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .sticker(payload):
            try container.encode(EntityType.sticker, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .text(payload):
            try container.encode(EntityType.text, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .simpleShape(payload):
            try container.encode(EntityType.simpleShape, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .bubble(payload):
            try container.encode(EntityType.bubble, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .vector(payload):
            try container.encode(EntityType.vector, forKey: .type)
            try container.encode(payload, forKey: .entity)
        }
    }
}

public final class DrawingEntitiesView: UIView, TGPhotoDrawingEntitiesView {
    private let context: AccountContext
    private let size: CGSize
    
    weak var drawingView: DrawingView?
    weak var selectionContainerView: DrawingSelectionContainerView?
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private(set) var selectedEntityView: DrawingEntityView?
    
    public var getEntityCenterPosition: () -> CGPoint = { return .zero }
    public var getEntityInitialRotation: () -> CGFloat = { return 0.0 }
    public var getEntityAdditionalScale: () -> CGFloat = { return 1.0 }
    
    public var hasSelectionChanged: (Bool) -> Void = { _ in }
    var selectionChanged: (DrawingEntity?) -> Void = { _ in }
    var requestedMenuForEntityView: (DrawingEntityView, Bool) -> Void = { _, _ in }
    
    var entityAdded: (DrawingEntity) -> Void = { _ in }
    var entityRemoved: (DrawingEntity) -> Void = { _ in }
    
    private let xAxisView = UIView()
    private let yAxisView = UIView()
    private let angleLayer = SimpleShapeLayer()
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, size: CGSize) {
        self.context = context
        self.size = size
                
        super.init(frame: CGRect(origin: .zero, size: size))
                
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer
        
        self.xAxisView.alpha = 0.0
        self.xAxisView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.xAxisView.isUserInteractionEnabled = false
        
        self.yAxisView.alpha = 0.0
        self.yAxisView.backgroundColor = UIColor(rgb: 0x5fc1f0)
        self.yAxisView.isUserInteractionEnabled = false
        
        self.angleLayer.strokeColor = UIColor(rgb: 0xffd70a).cgColor
        self.angleLayer.opacity = 0.0
        self.angleLayer.lineDashPattern = [12, 12] as [NSNumber]
        
        self.addSubview(self.xAxisView)
        self.addSubview(self.yAxisView)
        self.layer.addSublayer(self.angleLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
    
        let point = self.getEntityCenterPosition()
        self.xAxisView.bounds = CGRect(origin: .zero, size: CGSize(width: 6.0, height: 3000.0))
        self.xAxisView.center = point
        self.xAxisView.transform = CGAffineTransform(rotationAngle: self.getEntityInitialRotation())
        
        self.yAxisView.bounds = CGRect(origin: .zero, size: CGSize(width: 3000.0, height: 6.0))
        self.yAxisView.center = point
        self.yAxisView.transform = CGAffineTransform(rotationAngle: self.getEntityInitialRotation())
        
        let anglePath = CGMutablePath()
        anglePath.move(to: CGPoint(x: 0.0, y: 3.0))
        anglePath.addLine(to: CGPoint(x: 3000.0, y: 3.0))
        self.angleLayer.path = anglePath
        self.angleLayer.lineWidth = 6.0
        self.angleLayer.bounds = CGRect(origin: .zero, size: CGSize(width: 3000.0, height: 6.0))
    }
    
    var entities: [DrawingEntity] {
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
    
    public static func encodeEntities(_ entities: [DrawingEntity]) -> Data? {
        let entities = entities
        guard !entities.isEmpty else {
            return nil
        }
        for entity in entities {
            entity.prepareForRender()
        }
        let codableEntities = entities.compactMap({ CodableDrawingEntity(entity: $0) })
        if let data = try? JSONEncoder().encode(codableEntities) {
            return data
        } else {
            return nil
        }
    }
    
    var entitiesData: Data? {
        return DrawingEntitiesView.encodeEntities(self.entities)
    }
    
    var hasChanges: Bool {
        if let initialEntitiesData = self.initialEntitiesData {
            let entitiesData = self.entitiesData
            return entitiesData != initialEntitiesData
        } else {
            return !self.entities.isEmpty
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
    
    func prepareNewEntity(_ entity: DrawingEntity, setup: Bool = true, relativeTo: DrawingEntity? = nil) {
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
    func add(_ entity: DrawingEntity, announce: Bool = true) -> DrawingEntityView {
        let view = entity.makeView(context: self.context)
        view.containerView = self
        
        view.onSnapToXAxis = { [weak self, weak view] snappedToX in
            guard let strongSelf = self, let strongView = view else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            if snappedToX {
                strongSelf.insertSubview(strongSelf.xAxisView, belowSubview: strongView)
                if strongSelf.xAxisView.alpha < 1.0 {
                    strongSelf.hapticFeedback.impact(.light)
                }
                transition.updateAlpha(layer: strongSelf.xAxisView.layer, alpha: 1.0)
            } else {
                transition.updateAlpha(layer: strongSelf.xAxisView.layer, alpha: 0.0)
            }
        }
        view.onSnapToYAxis = { [weak self, weak view] snappedToY in
            guard let strongSelf = self, let strongView = view else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            if snappedToY {
                strongSelf.insertSubview(strongSelf.yAxisView, belowSubview: strongView)
                if strongSelf.yAxisView.alpha < 1.0 {
                    strongSelf.hapticFeedback.impact(.light)
                }
                transition.updateAlpha(layer: strongSelf.yAxisView.layer, alpha: 1.0)
            } else {
                transition.updateAlpha(layer: strongSelf.yAxisView.layer, alpha: 0.0)
            }
        }
        view.onSnapToAngle = { [weak self, weak view] snappedToAngle in
            guard let strongSelf = self, let strongView = view else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            if let snappedToAngle {
                strongSelf.layer.insertSublayer(strongSelf.angleLayer, below: strongView.layer)
                strongSelf.angleLayer.transform = CATransform3DMakeRotation(snappedToAngle, 0.0, 0.0, 1.0)
                if strongSelf.angleLayer.opacity < 1.0 {
                    strongSelf.hapticFeedback.impact(.light)
                }
                transition.updateAlpha(layer: strongSelf.angleLayer, alpha: 1.0)
            } else {
                transition.updateAlpha(layer: strongSelf.angleLayer, alpha: 0.0)
            }
        }
        view.onPositionUpdated = { [weak self] position in
            guard let strongSelf = self else {
                return
            }
            strongSelf.angleLayer.position = position
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
        
        let view = newEntity.makeView(context: self.context)
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
    
    func getView(for uuid: UUID) -> DrawingEntityView? {
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
    
    func selectEntity(_ entity: DrawingEntity?) {
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
            
            let selectionView = entityView.makeSelectionView()
            selectionView.tapped = { [weak self, weak entityView] in
                if let strongSelf = self, let entityView = entityView {
                    strongSelf.requestedMenuForEntityView(entityView, strongSelf.subviews.last === entityView)
                }
            }
            entityView.selectionView = selectionView
            self.selectionContainerView?.addSubview(selectionView)
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
    
    public func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        if let selectedEntityView = self.selectedEntityView, let selectionView = selectedEntityView.selectionView {
            selectionView.handlePinch(gestureRecognizer)
        }
    }
    
    public func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        if let selectedEntityView = self.selectedEntityView, let selectionView = selectedEntityView.selectionView {
            selectionView.handleRotate(gestureRecognizer)
        }
    }
}

public class DrawingEntityView: UIView {
    let context: AccountContext
    let entity: DrawingEntity
    var isTracking = false
    
    weak var selectionView: DrawingEntitySelectionView?
    weak var containerView: DrawingEntitiesView?
    
    var onSnapToXAxis: (Bool) -> Void = { _ in }
    var onSnapToYAxis: (Bool) -> Void = { _ in }
    var onSnapToAngle: (CGFloat?) -> Void = { _ in }
    var onPositionUpdated: (CGPoint) -> Void = { _ in }
    
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
    
    func update(animated: Bool = false) {
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
    
    func makeSelectionView() -> DrawingEntitySelectionView {
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
