import Foundation
import UIKit
import LegacyComponents
import AccountContext

protocol DrawingEntity: AnyObject {
    var uuid: UUID { get }
    var isAnimated: Bool { get }
    var center: CGPoint { get }
    
    var lineWidth: CGFloat { get set }
    var color: DrawingColor { get set }
    
    func duplicate() -> DrawingEntity
    
    var currentEntityView: DrawingEntityView? { get }
    func makeView(context: AccountContext) -> DrawingEntityView
}

public final class DrawingEntitiesView: UIView, TGPhotoDrawingEntitiesView {
    private let context: AccountContext
    private let size: CGSize
        
    weak var selectionContainerView: DrawingSelectionContainerView?
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private(set) var selectedEntityView: DrawingEntityView?
    
    public var hasSelectionChanged: (Bool) -> Void = { _ in }
    var selectionChanged: (DrawingEntity?) -> Void = { _ in }
    var requestedMenuForEntityView: (DrawingEntityView, Bool) -> Void = { _, _ in }
    
    init(context: AccountContext, size: CGSize, entities: [DrawingEntity] = []) {
        self.context = context
        self.size = size
        
        super.init(frame: CGRect(origin: .zero, size: size))
                
        for entity in entities {
            self.add(entity)
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    var entities: [DrawingEntity] {
        var entities: [DrawingEntity] = []
        for case let view as DrawingEntityView in self.subviews {
            entities.append(view.entity)
        }
        return entities
    }
    
    private func startPosition(relativeTo entity: DrawingEntity?) -> CGPoint {
        let offsetLength = round(self.size.width * 0.1)
        let offset = CGPoint(x: offsetLength, y: offsetLength)
        if let entity = entity {
            return entity.center.offsetBy(dx: offset.x, dy: offset.y)
        } else {
            let minimalDistance: CGFloat = round(offsetLength * 0.5)
            var position = CGPoint(x: self.size.width / 2.0, y: self.size.height / 2.0) // place good here
            
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
        let width = round(self.size.width * 0.5)
        
        return CGSize(width: width, height: width)
    }
    
    func prepareNewEntity(_ entity: DrawingEntity, setup: Bool = true, relativeTo: DrawingEntity? = nil) {
        let center = self.startPosition(relativeTo: relativeTo)
        if let shape = entity as? DrawingSimpleShapeEntity {
            shape.position = center
            
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
            if setup {
                sticker.referenceDrawingSize = self.size
                sticker.scale = 1.0
            }
        } else if let bubble = entity as? DrawingBubbleEntity {
            bubble.position = center
            if setup {
                let size = self.newEntitySize()
                bubble.referenceDrawingSize = self.size
                bubble.size = CGSize(width: size.width, height: round(size.height * 0.7))
                bubble.tailPosition = CGPoint(x: 0.16, y: size.height * 0.18)
            }
        } else if let text = entity as? DrawingTextEntity {
            text.position = center
            if setup {
                text.referenceDrawingSize = self.size
                text.width = floor(self.size.width * 0.9)
                text.fontSize = 0.3
            }
        }
    }
    
    @discardableResult
    func add(_ entity: DrawingEntity) -> DrawingEntityView {
        let view = entity.makeView(context: self.context)
        view.containerView = self
        view.update()
        self.addSubview(view)
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
    
    func remove(uuid: UUID) {
        if let view = self.getView(for: uuid) {
            if self.selectedEntityView === view {
                self.selectedEntityView?.removeFromSuperview()
                self.selectedEntityView = nil
                self.selectionChanged(nil)
                self.hasSelectionChanged(false)
            }
            view.removeFromSuperview()
        }
    }
    
    func removeAll() {
        for case let view as DrawingEntityView in self.subviews {
            view.removeFromSuperview()
        }
        self.selectionChanged(nil)
        self.hasSelectionChanged(false)
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
    
    public func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer!) {
        if let selectedEntityView = self.selectedEntityView, let selectionView = selectedEntityView.selectionView {
            selectionView.handlePinch(gestureRecognizer)
        }
    }
    
    public func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer!) {
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
