import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import MediaEditor
import MediaAssetsContext
import CheckNode
import TelegramPresentationData

final class SelectionPanelComponent: Component {
    let previewContainerView: PortalSourceView
    let frame: CGRect
    let items: [MediaEditorScreenImpl.EditingItem]
    let selectedItemId: String
    let itemTapped: (String?) -> Void
    let itemSelectionToggled: (String) -> Void
    let itemReordered: (String, String) -> Void
    
    init(
        previewContainerView: PortalSourceView,
        frame: CGRect,
        items: [MediaEditorScreenImpl.EditingItem],
        selectedItemId: String,
        itemTapped: @escaping (String?) -> Void,
        itemSelectionToggled: @escaping (String) -> Void,
        itemReordered: @escaping (String, String) -> Void
    ) {
        self.previewContainerView = previewContainerView
        self.frame = frame
        self.items = items
        self.selectedItemId = selectedItemId
        self.itemTapped = itemTapped
        self.itemSelectionToggled = itemSelectionToggled
        self.itemReordered = itemReordered
    }
    
    static func ==(lhs: SelectionPanelComponent, rhs: SelectionPanelComponent) -> Bool {
        return lhs.frame == rhs.frame && lhs.items == rhs.items && lhs.selectedItemId == rhs.selectedItemId
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        final class ItemView: UIView {
            private let backgroundNode: ASImageNode
            private let imageNode: ImageNode
            private let checkNode: InteractiveCheckNode
            private var selectionLayer: SimpleShapeLayer?
            
            var toggleSelection: () -> Void = {}
            
            override init(frame: CGRect) {
                self.backgroundNode = ASImageNode()
                self.backgroundNode.displaysAsynchronously = false
                
                self.imageNode = ImageNode()
                self.imageNode.contentMode = .scaleAspectFill
                
                self.checkNode = InteractiveCheckNode(theme: CheckNodeTheme(theme: defaultDarkColorPresentationTheme, style: .overlay))
                            
                super.init(frame: frame)

                self.clipsToBounds = true
                self.layer.cornerRadius = 6.0
                
                self.addSubview(self.backgroundNode.view)
                self.addSubview(self.imageNode.view)
                self.addSubview(self.checkNode.view)
                
                self.checkNode.valueChanged = { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.toggleSelection()
                }
            }
            
            required init?(coder aDecoder: NSCoder) {
                preconditionFailure()
            }
                   
            fileprivate var item: MediaEditorScreenImpl.EditingItem?
            func update(item: MediaEditorScreenImpl.EditingItem, number: Int, isSelected: Bool, isEnabled: Bool, size: CGSize, portalView: PortalView?, transition: ComponentTransition) {
                let previousItem = self.item
                self.item = item
                
                if previousItem?.identifier != item.identifier || previousItem?.version != item.version {
                    let imageSignal: Signal<UIImage?, NoError>
                    if let thumbnail = item.thumbnail {
                        imageSignal = .single(thumbnail)
                        self.imageNode.contentMode = .scaleAspectFill
                    } else {
                        switch item.source {
                        case let .image(image, _):
                            imageSignal = .single(image)
                        case let .video(_, image, _, _):
                            imageSignal = .single(image)
                        case let .asset(asset):
                            imageSignal = assetImage(asset: asset, targetSize:CGSize(width: 128.0 * UIScreenScale, height: 128.0 * UIScreenScale), exact: false, synchronous: true)
                        }
                        self.imageNode.contentUpdated = { [weak self] image in
                            if let self {
                                if self.backgroundNode.image == nil {
                                    if let image, image.size.width > image.size.height {
                                        self.imageNode.contentMode = .scaleAspectFit
                                        Queue.concurrentDefaultQueue().async {
                                            let colors = mediaEditorGetGradientColors(from: image)
                                            let gradientImage = mediaEditorGenerateGradientImage(size: CGSize(width: 3.0, height: 128.0), colors: colors.array)
                                            Queue.mainQueue().async {
                                                self.backgroundNode.image = gradientImage
                                            }
                                        }
                                    } else {
                                        self.imageNode.contentMode = .scaleAspectFill
                                    }
                                }
                            }
                        }
                    }
                    self.imageNode.setSignal(imageSignal)
                }
                
                let backgroundSize = CGSize(width: size.width, height: floorToScreenPixels(size.width / 9.0 * 16.0))
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
                
                self.imageNode.frame = CGRect(origin: .zero, size: size)
                
                //self.checkNode.content = .counter(number)
                self.checkNode.setSelected(isEnabled, animated: previousItem != nil)
                
                let checkSize = CGSize(width: 29.0, height: 29.0)
                self.checkNode.frame = CGRect(origin: CGPoint(x: size.width - checkSize.width - 4.0, y: 4.0), size: checkSize)
                
                if isSelected, let portalView {
                    portalView.view.frame = CGRect(origin: .zero, size: size)
                    self.insertSubview(portalView.view, aboveSubview: self.imageNode.view)
                }
                
                let lineWidth: CGFloat = 2.0 - UIScreenPixel
                let selectionFrame = CGRect(origin: .zero, size: size)
                if isSelected {
                    let selectionLayer: SimpleShapeLayer
                    if let current = self.selectionLayer {
                        selectionLayer = current
                    } else {
                        selectionLayer = SimpleShapeLayer()
                        self.selectionLayer = selectionLayer
                        self.layer.addSublayer(selectionLayer)
                        
                        selectionLayer.fillColor = UIColor.clear.cgColor
                        selectionLayer.strokeColor = UIColor.white.cgColor
                        selectionLayer.lineWidth = lineWidth
                        selectionLayer.frame = selectionFrame
                        selectionLayer.path = CGPath(roundedRect: CGRect(origin: .zero, size: selectionFrame.size).insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0), cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
                    }
                    
                } else if let selectionLayer = self.selectionLayer {
                    self.selectionLayer = nil
                    selectionLayer.removeFromSuperlayer()
                }
            }
        }
        
        private let backgroundView: BlurredBackgroundView
        private let backgroundMaskView: UIView
        private let backgroundMaskPanelView: UIView
        
        private let scrollView: UIScrollView
        private var itemViews: [AnyHashable: ItemView] = [:]
        private var portalView: PortalView?
        
        private var reorderRecognizer: ReorderGestureRecognizer?
        private var reorderingItem: (id: AnyHashable, initialPosition: CGPoint, position: CGPoint, snapshotView: UIView)?
        
        private var tapRecognizer: UITapGestureRecognizer?
        
        private var component: SelectionPanelComponent?
        private var state: EmptyComponentState?
                    
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: UIColor(white: 0.2, alpha: 0.45), enableBlur: true)
            self.backgroundMaskView = UIView(frame: .zero)
            
            self.backgroundMaskPanelView = UIView(frame: .zero)
            self.backgroundMaskPanelView.backgroundColor = UIColor.white
            self.backgroundMaskPanelView.clipsToBounds = true
            self.backgroundMaskPanelView.layer.cornerRadius = 10.0
            
            self.scrollView = UIScrollView(frame: .zero)
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.layer.cornerRadius = 10.0
            
            super.init(frame: frame)
            
            self.backgroundView.mask = self.backgroundMaskView
            
            let reorderRecognizer = ReorderGestureRecognizer(
                shouldBegin: { [weak self] point in
                    guard let self, let item = self.item(at: point) else {
                        return (allowed: false, requiresLongPress: false, item: nil)
                    }
                    
                    return (allowed: true, requiresLongPress: true, item: item)
                },
                willBegin: { point in
                },
                began: { [weak self] item in
                    guard let self else {
                        return
                    }
                    self.setReorderingItem(item: item)
                },
                ended: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.setReorderingItem(item: nil)
                },
                moved: { [weak self] distance in
                    guard let self else {
                        return
                    }
                    self.moveReorderingItem(distance: distance)
                },
                isActiveUpdated: { _ in
                }
            )
            reorderRecognizer.delegate = self
            self.reorderRecognizer = reorderRecognizer
            self.addGestureRecognizer(reorderRecognizer)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
            self.tapRecognizer = tapRecognizer
            self.addGestureRecognizer(tapRecognizer)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.scrollView)
            
            self.backgroundMaskView.addSubview(self.backgroundMaskPanelView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
        }
        
        @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            self.reorderRecognizer?.isEnabled = false
            self.reorderRecognizer?.isEnabled = true
            
            let location = gestureRecognizer.location(in: self)
            if let itemView = self.item(at: location), let item = itemView.item, item.identifier != component.selectedItemId {
                component.itemTapped(item.identifier)
            } else {
                component.itemTapped(nil)
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is UITapGestureRecognizer {
                return true
            }
            if otherGestureRecognizer is UIPanGestureRecognizer {
                if gestureRecognizer === self.reorderRecognizer, ![.began, .changed].contains(gestureRecognizer.state) {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                    return true
                } else {
                    return false
                }
            }
            return false
        }
        
        func item(at point: CGPoint) -> ItemView? {
            let point = self.convert(point, to: self.scrollView)
            for (_, itemView) in self.itemViews {
                if itemView.frame.contains(point) {
                    return itemView
                }
            }
            return nil
        }
        
        func setReorderingItem(item: ItemView?) {
            self.tapRecognizer?.isEnabled = false
            self.tapRecognizer?.isEnabled = true
            
            var mappedItem: (AnyHashable, ItemView)?
            if let item {
                for (id, visibleItem) in self.itemViews {
                    if visibleItem === item {
                        mappedItem = (id, visibleItem)
                        break
                    }
                }
            }
            
            if self.reorderingItem?.id != mappedItem?.0 {
                let transition: ComponentTransition = .spring(duration: 0.4)
                if let (id, itemView) = mappedItem, let snapshotView = itemView.snapshotView(afterScreenUpdates: false) {
                    itemView.isHidden = true
                    
                    let position = self.scrollView.convert(itemView.center, to: self)
                    snapshotView.center = position
                    transition.setScale(view: snapshotView, scale: 0.9)
                    self.addSubview(snapshotView)
                    
                    self.reorderingItem = (id, position, position, snapshotView)
                } else {
                    if let (id, _, _, snapshotView) = self.reorderingItem {
                        if let itemView = self.itemViews[id] {
                            if let innerSnapshotView = snapshotView.snapshotView(afterScreenUpdates: false) {
                                innerSnapshotView.center = self.convert(snapshotView.center, to: self.scrollView)
                                innerSnapshotView.transform = CGAffineTransformMakeScale(0.9, 0.9)
                                self.scrollView.addSubview(innerSnapshotView)
                                
                                transition.setPosition(view: innerSnapshotView, position: itemView.center, completion: { [weak innerSnapshotView] _ in
                                    innerSnapshotView?.removeFromSuperview()
                                    itemView.isHidden = false
                                })
                                transition.setScale(view: innerSnapshotView, scale: 1.0)
                            }
                            
                            transition.setPosition(view: snapshotView, position: self.scrollView.convert(itemView.center, to: self), completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            transition.setScale(view: snapshotView, scale: 1.0)
                            transition.setAlpha(view: snapshotView, alpha: 0.0)
                        }
                    }
                    self.reorderingItem = nil
                }
                self.state?.updated(transition: transition)
            }
        }
        
        func moveReorderingItem(distance: CGPoint) {
            guard let component = self.component else {
                return
            }
            if let (id, initialPosition, _, snapshotView) = self.reorderingItem {
                let targetPosition = CGPoint(x: initialPosition.x + distance.x, y: initialPosition.y + distance.y)
                self.reorderingItem = (id, initialPosition, targetPosition, snapshotView)
                snapshotView.center = targetPosition
                
                let mappedPosition = self.convert(targetPosition, to: self.scrollView)
                
                if let visibleReorderingItem = self.itemViews[id], let fromId = self.itemViews[id]?.item?.identifier {
                    for (_, visibleItem) in self.itemViews {
                        if visibleItem === visibleReorderingItem {
                            continue
                        }
                        if visibleItem.frame.contains(mappedPosition), let toId = visibleItem.item?.identifier {
                            component.itemReordered(fromId, toId)
                            break
                        }
                    }
                }
            }
        }
        
        func animateIn(from buttonView: SelectionPanelButtonContentComponent.View) {
            guard let component = self.component else {
                return
            }
            
            self.scrollView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            
            let buttonFrame = buttonView.convert(buttonView.bounds, to: self)
            let fromPoint = CGPoint(x: buttonFrame.center.x - self.scrollView.center.x, y: buttonFrame.center.y - self.scrollView.center.y)
            
            self.scrollView.layer.animatePosition(from: fromPoint, to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            self.scrollView.layer.animateBounds(from: CGRect(origin: CGPoint(x: buttonFrame.minX - self.scrollView.frame.minX, y: buttonFrame.minY - self.scrollView.frame.minY), size: buttonFrame.size), to: self.scrollView.bounds, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                        
            self.backgroundMaskPanelView.layer.animatePosition(from: fromPoint, to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundMaskPanelView.layer.animate(from: NSNumber(value: Float(16.5)), to: NSNumber(value: Float(self.backgroundMaskPanelView.layer.cornerRadius)), keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
            self.backgroundMaskPanelView.layer.animateBounds(from: CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0)), to: self.backgroundMaskPanelView.bounds, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            
            let mainCircleDelay: Double = 0.02
            let backgroundWidth = self.backgroundMaskPanelView.frame.width
            for item in component.items {
                guard let itemView = self.itemViews[item.identifier] else {
                    continue
                }
                
                let distance = abs(itemView.frame.center.x - backgroundWidth)
                let distanceNorm = distance / backgroundWidth
                let adjustedDistanceNorm = distanceNorm
                let itemDelay = mainCircleDelay + adjustedDistanceNorm * 0.14
                
                itemView.isHidden = true
                Queue.mainQueue().after(itemDelay * UIView.animationDurationFactor()) { [weak itemView] in
                    guard let itemView else {
                        return
                    }
                    itemView.isHidden = false
                    itemView.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                }
            }
        }
        
        func animateOut(to buttonView: SelectionPanelButtonContentComponent.View, completion: @escaping () -> Void) {
            guard let component = self.component else {
                completion()
                return
            }
            
            self.scrollView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            
            let buttonFrame = buttonView.convert(buttonView.bounds, to: self)
            let scrollButtonFrame = buttonView.convert(buttonView.bounds, to: self.scrollView)
            let toPoint = CGPoint(x: buttonFrame.center.x - self.scrollView.center.x, y: buttonFrame.center.y - self.scrollView.center.y)
            
            self.scrollView.layer.animatePosition(from: .zero, to: toPoint, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            self.scrollView.layer.animateBounds(from: self.scrollView.bounds, to: CGRect(origin: CGPoint(x: (buttonFrame.minX - self.scrollView.frame.minX) / 2.0, y: (buttonFrame.minY - self.scrollView.frame.minY) / 2.0), size: buttonFrame.size), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            
            self.backgroundMaskPanelView.layer.animatePosition(from: .zero, to: toPoint, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            self.backgroundMaskPanelView.layer.animate(from: NSNumber(value: Float(self.backgroundMaskPanelView.layer.cornerRadius)), to: NSNumber(value: Float(16.5)), keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4, removeOnCompletion: false)
            self.backgroundMaskPanelView.layer.animateBounds(from: self.backgroundMaskPanelView.bounds, to: CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0)), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { finished in
                if finished {
                    completion()
                    self.backgroundMaskPanelView.layer.removeAllAnimations()
                    for (_, itemView) in self.itemViews {
                        itemView.layer.removeAllAnimations()
                    }
                }
            })
            
            let mainCircleDelay: Double = 0.0
            let backgroundWidth = self.backgroundMaskPanelView.frame.width
            
            for item in component.items {
                guard let itemView = self.itemViews[item.identifier] else {
                    continue
                }
                let distance = abs(itemView.frame.center.x - backgroundWidth)
                let distanceNorm = distance / backgroundWidth
                let adjustedDistanceNorm = distanceNorm
                
                let itemDelay = mainCircleDelay + adjustedDistanceNorm * 0.05
                
                Queue.mainQueue().after(itemDelay * UIView.animationDurationFactor()) { [weak itemView] in
                    guard let itemView else {
                        return
                    }
                    
                    itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
                itemView.layer.animatePosition(from: itemView.center, to: scrollButtonFrame.center, duration: 0.4)
            }
        }
        
        func update(component: SelectionPanelComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            if self.portalView == nil {
                if let portalView = PortalView(matchPosition: false) {
                    portalView.view.layer.rasterizationScale = UIScreenScale
                    
                    let scale = 95.0 / component.previewContainerView.frame.width
                    portalView.view.transform = CGAffineTransformMakeScale(scale, scale)
                    
                    component.previewContainerView.addPortal(view: portalView)
                    self.portalView = portalView
                }
            }
                        
            var validIds = Set<AnyHashable>()
                      
            let itemSize = CGSize(width: 95.0, height: 112.0)
            let spacing: CGFloat = 4.0
            
            var itemFrame: CGRect = CGRect(origin: CGPoint(x: spacing, y: spacing), size: itemSize)
           
            var index = 1
            for item in component.items {
                let id = item.identifier
                validIds.insert(id)
                            
                var itemTransition = transition
                let itemView: ItemView
                if let current = self.itemViews[id] {
                    itemView = current
                } else {
                    itemView = ItemView(frame: itemFrame)
                    self.scrollView.addSubview(itemView)
                    self.itemViews[id] = itemView
                    
                    itemTransition = .immediate
                }
                itemView.toggleSelection = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.itemSelectionToggled(id)
                }
                itemView.update(item: item, number: index, isSelected: item.identifier == component.selectedItemId, isEnabled: item.isEnabled, size: itemFrame.size, portalView: self.portalView, transition: itemTransition)
 
                itemTransition.setBounds(view: itemView, bounds: CGRect(origin: .zero, size: itemFrame.size))
                itemTransition.setPosition(view: itemView, position: itemFrame.center)
                
                itemFrame.origin.x += itemSize.width + spacing
                index += 1
            }
                        
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    transition.setAlpha(view: itemView, alpha: 0.0, completion: { [weak itemView] _ in
                        itemView?.removeFromSuperview()
                    })
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            let contentSize = CGSize(width: itemFrame.minX, height: itemSize.height + spacing * 2.0)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            let backgroundSize = CGSize(width: min(availableSize.width - 24.0, contentSize.width), height: contentSize.height)
            self.backgroundView.frame = CGRect(origin: .zero, size: availableSize)
            self.backgroundView.update(size: availableSize, transition: .immediate)
            
            let contentFrame = CGRect(origin: CGPoint(x: availableSize.width - 12.0 - backgroundSize.width, y: component.frame.minY), size: backgroundSize)
            self.backgroundMaskPanelView.frame = contentFrame
            self.scrollView.frame = contentFrame
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}

private final class ReorderGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: SelectionPanelComponent.View.ItemView?)
    private let willBegin: (CGPoint) -> Void
    private let began: (SelectionPanelComponent.View.ItemView) -> Void
    private let ended: () -> Void
    private let moved: (CGPoint) -> Void
    private let isActiveUpdated: (Bool) -> Void
    
    private var initialLocation: CGPoint?
    private var longTapTimer: SwiftSignalKit.Timer?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var itemView: SelectionPanelComponent.View.ItemView?
    
    public init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: SelectionPanelComponent.View.ItemView?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (SelectionPanelComponent.View.ItemView) -> Void, ended: @escaping () -> Void, moved: @escaping (CGPoint) -> Void, isActiveUpdated: @escaping (Bool) -> Void) {
        self.shouldBegin = shouldBegin
        self.willBegin = willBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        self.isActiveUpdated = isActiveUpdated
        
        super.init(target: nil, action: nil)
    }
    
    deinit {
        self.longTapTimer?.invalidate()
        self.longPressTimer?.invalidate()
    }
    
    private func startLongTapTimer() {
        self.longTapTimer?.invalidate()
        let longTapTimer = SwiftSignalKit.Timer(timeout: 0.25, repeat: false, completion: { [weak self] in
            self?.longTapTimerFired()
        }, queue: Queue.mainQueue())
        self.longTapTimer = longTapTimer
        longTapTimer.start()
    }
    
    private func stopLongTapTimer() {
        self.itemView = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = SwiftSignalKit.Timer(timeout: 0.6, repeat: false, completion: { [weak self] in
            self?.longPressTimerFired()
        }, queue: Queue.mainQueue())
        self.longPressTimer = longPressTimer
        longPressTimer.start()
    }
    
    private func stopLongPressTimer() {
        self.itemView = nil
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
    }
    
    override public func reset() {
        super.reset()
        
        self.itemView = nil
        self.stopLongTapTimer()
        self.stopLongPressTimer()
        self.initialLocation = nil
        
        self.isActiveUpdated(false)
    }
    
    private func longTapTimerFired() {
        guard let location = self.initialLocation else {
            return
        }
        
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        
        self.willBegin(location)
    }
    
    private func longPressTimerFired() {
        guard let _ = self.initialLocation else {
            return
        }
        
        self.isActiveUpdated(true)
        self.state = .began
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        if let itemView = self.itemView {
            self.began(itemView)
        }
        self.isActiveUpdated(true)
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.isActiveUpdated(false)
            self.state = .failed
            self.ended()
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view) {
                let (allowed, requiresLongPress, itemView) = self.shouldBegin(location)
                if allowed {
                    self.isActiveUpdated(true)
                    
                    self.itemView = itemView
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongTapTimer()
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let itemView = self.itemView {
                            self.began(itemView)
                        }
                    }
                } else {
                    self.isActiveUpdated(false)
                    self.state = .failed
                }
            } else {
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.isActiveUpdated(false)
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.isActiveUpdated(false)
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            let offset = CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y)
            self.moved(offset)
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            let dY = touchLocation.y - initialTapLocation.y
            
            if dX * dX + dY * dY > 3.0 * 3.0 {
                self.stopLongTapTimer()
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
}
