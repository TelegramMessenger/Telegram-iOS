import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import GlassBackgroundComponent
import LiquidLens
import TabSelectionRecognizer

private let buttonSize = CGSize(width: 55.0, height: 44.0)
private let tabletButtonSize = CGSize(width: 55.0, height: 44.0)

extension DrawingMode {
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .drawing:
            return strings.Paint_Draw
        case .sticker:
            return strings.Paint_Sticker
        case .text:
            return strings.Paint_Text
        }
    }
}

final class ModeComponent: Component {
    let isTablet: Bool
    let strings: PresentationStrings
    let tintColor: UIColor
    let availableModes: [DrawingMode]
    let currentMode: DrawingMode
    let updatedMode: (DrawingMode) -> Void
    let tag: AnyObject?
    
    init(
        isTablet: Bool,
        strings: PresentationStrings,
        tintColor: UIColor,
        availableModes: [DrawingMode],
        currentMode: DrawingMode,
        updatedMode: @escaping (DrawingMode) -> Void,
        tag: AnyObject?
    ) {
        self.isTablet = isTablet
        self.strings = strings
        self.tintColor = tintColor
        self.availableModes = availableModes
        self.currentMode = currentMode
        self.updatedMode = updatedMode
        self.tag = tag
    }
    
    static func ==(lhs: ModeComponent, rhs: ModeComponent) -> Bool {
        if lhs.isTablet != rhs.isTablet {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.availableModes != rhs.availableModes {
            return false
        }
        if lhs.currentMode != rhs.currentMode {
            return false
        }
        return true
    }
    
    final class View: UIView, ComponentTaggedView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private final class ScrollView: UIScrollView {
            override func touchesShouldCancel(in view: UIView) -> Bool {
                return true
            }
        }
        
        private struct LayoutData {
            var containerSize: CGSize
            var selectedFrame: CGRect
            var cornerRadius: CGFloat?
            var isTablet: Bool
        }
        
        private var component: ModeComponent?
        private var state: EmptyComponentState?
        
        final class ItemView: HighlightTrackingButton {
            init() {
                super.init(frame: .zero)
            }
            
            required init(coder: NSCoder) {
                preconditionFailure()
            }
            
            func update(isTablet: Bool, value: String, selected: Bool, tintColor: UIColor) -> CGSize {
                let title = NSMutableAttributedString(string: value, font: Font.with(size: 15.0, design: .regular, weight: .medium), textColor: UIColor(rgb: 0xffffff), paragraphAlignment: .center)
                self.setAttributedTitle(title, for: .normal)
                self.sizeToFit()
                return CGSize(width: self.titleLabel?.bounds.size.width ?? 0.0, height: buttonSize.height)
            }
        }
        
        private var backgroundView = UIView()
        private var backgroundContainer = GlassBackgroundContainerView()
        
        private var liquidLensView: LiquidLensView?
        private let scrollView = ScrollView()
        private let selectedScrollView = UIView()
        private var ignoreScrolling = false
        private var layoutData: LayoutData?
                
        private var itemViews: [AnyHashable: ItemView] = [:]
        private var selectedItemViews: [AnyHashable: ItemView] = [:]
        
        private var tabSelectionRecognizer: TabSelectionRecognizer?
        private var selectionGestureState: (startX: CGFloat, currentX: CGFloat, itemId: AnyHashable)?
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        init() {
            super.init(frame: CGRect())
            
            self.backgroundView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.09)
            self.backgroundView.layer.cornerRadius = 22.0
                        
            self.layer.allowsGroupOpacity = true
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.scrollsToTop = false
            self.scrollView.clipsToBounds = true
            self.scrollView.delegate = self
            self.scrollView.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
                guard let self else {
                    return false
                }
                return self.scrollView.contentOffset.x > .ulpOfOne
            }
            
            self.selectedScrollView.clipsToBounds = true
            self.selectedScrollView.isUserInteractionEnabled = false
            
            self.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.backgroundContainer)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        private var animatedOut = false
        func animateOutToEditor(transition: ComponentTransition) {
            self.animatedOut = true
            
            transition.setAlpha(view: self.backgroundView, alpha: 0.0)
            transition.setSublayerTransform(view: self, transform: CATransform3DMakeTranslation(0.0, -buttonSize.height, 0.0))
        }
        
        func animateInFromEditor(transition: ComponentTransition) {
            self.animatedOut = false
            
            transition.setAlpha(view: self.backgroundView, alpha: 1.0)
            transition.setSublayerTransform(view: self, transform: CATransform3DIdentity)
        }
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return self.backgroundView.frame.contains(point)
        }
        
        private func item(at point: CGPoint, in view: UIView) -> AnyHashable? {
            var closestItem: (AnyHashable, CGFloat)?
            for (id, itemView) in self.itemViews {
                let itemFrame = itemView.convert(itemView.bounds, to: view)
                if itemFrame.contains(point) {
                    return id
                } else {
                    let distance = abs(point.x - itemFrame.midX)
                    if let closestItemValue = closestItem {
                        if closestItemValue.1 > distance {
                            closestItem = (id, distance)
                        }
                    } else {
                        closestItem = (id, distance)
                    }
                }
            }
            return closestItem?.0
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateScrolling(transition: .immediate)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.tabSelectionRecognizer && otherGestureRecognizer === self.scrollView.panGestureRecognizer {
                return true
            }
            if otherGestureRecognizer === self.tabSelectionRecognizer && gestureRecognizer === self.scrollView.panGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func onTabSelectionGesture(_ recognizer: TabSelectionRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = recognizer.location(in: self)
            switch recognizer.state {
            case .began:
                if let itemId = self.item(at: location, in: self), let itemView = self.itemViews[itemId] {
                    let startX = itemView.frame.minX - 4.0
                    self.selectionGestureState = (startX, startX, itemId)
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
            case .changed:
                if var selectionGestureState = self.selectionGestureState {
                    let translation = recognizer.translation(in: self)
                    if !component.isTablet && self.scrollView.isScrollEnabled && abs(translation.x) > 6.0 && abs(translation.x) > abs(translation.y) {
                        self.selectionGestureState = nil
                        recognizer.state = .cancelled
                        self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                        return
                    }
                    selectionGestureState.currentX = selectionGestureState.startX + recognizer.translation(in: self).x
                    if let itemId = self.item(at: location, in: self) {
                        selectionGestureState.itemId = itemId
                    }
                    self.selectionGestureState = selectionGestureState
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
            case .ended, .cancelled:
                if let selectionGestureState = self.selectionGestureState {
                    self.selectionGestureState = nil
                    if case .ended = recognizer.state {
                        guard let item = component.availableModes.first(where: { AnyHashable($0.rawValue) == selectionGestureState.itemId }) else {
                            return
                        }
                        component.updatedMode(item)
                    }
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
            default:
                break
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let liquidLensView = self.liquidLensView, let layoutData = self.layoutData else {
                return
            }
            
            let contentOffsetX = layoutData.isTablet ? 0.0 : self.scrollView.bounds.minX
            var lensSelection = (origin: layoutData.selectedFrame.origin, size: layoutData.selectedFrame.size)
            if let selectionGestureState = self.selectionGestureState, !layoutData.isTablet {
                lensSelection.origin = CGPoint(x: selectionGestureState.currentX, y: 0.0)
            }
            
            if layoutData.isTablet {
                lensSelection.size.width = layoutData.containerSize.width
            } else {
                lensSelection.origin.x -= contentOffsetX
                lensSelection.origin.y = 0.0
                lensSelection.size.height = layoutData.containerSize.height
            }
            
            let maxSelectionOriginX = max(0.0, layoutData.containerSize.width - lensSelection.size.width)
            transition.setFrame(view: self.selectedScrollView, frame: CGRect(origin: .zero, size: layoutData.containerSize))
            transition.setBounds(view: self.selectedScrollView, bounds: CGRect(origin: CGPoint(x: contentOffsetX, y: 0.0), size: layoutData.containerSize))
            
            liquidLensView.update(size: layoutData.containerSize, cornerRadius: layoutData.cornerRadius, selectionOrigin: CGPoint(x: max(0.0, min(lensSelection.origin.x, maxSelectionOriginX)), y: lensSelection.origin.y), selectionSize: lensSelection.size, inset: 3.0, isDark: true, isLifted: self.selectionGestureState != nil && !layoutData.isTablet, isCollapsed: false, transition: transition)
            self.backgroundContainer.update(size: layoutData.containerSize, isDark: true, transition: .immediate)
            
            self.scrollView.isScrollEnabled = !component.isTablet && self.scrollView.contentSize.width > self.scrollView.bounds.width + .ulpOfOne
        }
                
        func update(component: ModeComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let isTablet = component.isTablet
            
            let liquidLensView: LiquidLensView
            if let current = self.liquidLensView {
                liquidLensView = current
            } else {
                liquidLensView = LiquidLensView(kind: isTablet ? .noContainer : .externalContainer)
                self.liquidLensView = liquidLensView
                self.backgroundContainer.contentView.addSubview(liquidLensView)
                liquidLensView.contentView.addSubview(self.scrollView)
                liquidLensView.selectedContentView.addSubview(self.selectedScrollView)
                
                let tabSelectionRecognizer = TabSelectionRecognizer(target: self, action: #selector(self.onTabSelectionGesture(_:)))
                tabSelectionRecognizer.delegate = self
                tabSelectionRecognizer.cancelsTouchesInView = false
                self.tabSelectionRecognizer = tabSelectionRecognizer
                liquidLensView.addGestureRecognizer(tabSelectionRecognizer)
            }
            if self.scrollView.superview == nil {
                liquidLensView.contentView.addSubview(self.scrollView)
            }
            if self.selectedScrollView.superview == nil {
                liquidLensView.selectedContentView.addSubview(self.selectedScrollView)
            }
            
            self.backgroundView.backgroundColor = component.isTablet ? .clear : UIColor(rgb: 0xffffff, alpha: 0.11)
        
            var inset: CGFloat = 23.0
            let spacing: CGFloat
            if isTablet {
                spacing = 9.0
            } else {
                if availableSize.width < 270.0 {
                    inset = 16.0
                    spacing = 20.0
                } else {
                    spacing = 30.0
                }
            }
      
            var i = 0
            var itemFrame = CGRect(origin: isTablet ? .zero : CGPoint(x: inset, y: 0.0), size: buttonSize)
            var selectedFrame = itemFrame
            
            var validKeys: Set<AnyHashable> = Set()
            for mode in component.availableModes {
                let id = mode.rawValue
                validKeys.insert(id)
                
                let itemView: ItemView
                let selectedItemView: ItemView
                if let current = self.itemViews[id], let currentSelected = self.selectedItemViews[id] {
                    itemView = current
                    selectedItemView = currentSelected
                } else {
                    itemView = ItemView()
                    itemView.isUserInteractionEnabled = false
                    self.itemViews[id] = itemView
                    
                    selectedItemView = ItemView()
                    selectedItemView.isUserInteractionEnabled = false
                    self.selectedItemViews[id] = selectedItemView
                }
                if itemView.superview !== self.scrollView {
                    self.scrollView.addSubview(itemView)
                }
                if selectedItemView.superview !== self.selectedScrollView {
                    self.selectedScrollView.addSubview(selectedItemView)
                }
               
                let itemSize = itemView.update(isTablet: component.isTablet, value: mode.title(strings: component.strings), selected: false, tintColor: component.tintColor)
                itemView.bounds = CGRect(origin: .zero, size: itemSize)
                
                let _ = selectedItemView.update(isTablet: component.isTablet, value: mode.title(strings: component.strings), selected: true, tintColor: component.tintColor)
                selectedItemView.bounds = CGRect(origin: .zero, size: itemSize)
                
                itemFrame = CGRect(origin: itemFrame.origin, size: itemSize)
                
                if mode == component.currentMode {
                    selectedFrame = itemFrame
                }
                
                if isTablet {
                    itemView.center = CGPoint(x: availableSize.width / 2.0, y: itemFrame.midY)
                    selectedItemView.center = itemView.center
                    itemFrame = itemFrame.offsetBy(dx: 0.0, dy: tabletButtonSize.height + spacing)
                } else {
                    itemView.center = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    selectedItemView.center = itemView.center
                    itemFrame = itemFrame.offsetBy(dx: itemFrame.width + spacing, dy: 0.0)
                }
                i += 1
            }
            
            var removeKeys: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validKeys.contains(id) {
                    removeKeys.append(id)
                    
                    transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                        itemView.removeFromSuperview()
                    })
                    
                    if let selectedItemView = self.selectedItemViews[id] {
                        transition.setAlpha(view: selectedItemView, alpha: 0.0, completion: { _ in
                            selectedItemView.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeKeys {
                self.itemViews.removeValue(forKey: id)
                self.selectedItemViews.removeValue(forKey: id)
            }
            
            let totalSize: CGSize
            let size: CGSize
            let contentSize: CGSize
            var cornerRadius: CGFloat?
            if isTablet {
                totalSize = CGSize(width: availableSize.width, height: tabletButtonSize.height * CGFloat(component.availableModes.count) + spacing * CGFloat(component.availableModes.count - 1))
                size = CGSize(width: availableSize.width, height: availableSize.height)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: totalSize))
                contentSize = totalSize
                cornerRadius = 20.0
            } else {
                size = CGSize(width: availableSize.width, height: buttonSize.height)
                totalSize = CGSize(width: itemFrame.minX - spacing + inset, height: buttonSize.height)
                let visibleSize = CGSize(width: min(availableSize.width, totalSize.width), height: totalSize.height)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - visibleSize.width) / 2.0), y: 0.0), size: visibleSize))
                contentSize = totalSize
            }
            
            let containerFrame = CGRect(origin: .zero, size: self.backgroundView.frame.size)
            transition.setFrame(view: self.backgroundContainer, frame: containerFrame)
            transition.setFrame(view: liquidLensView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: containerFrame.size))
            
            let scrollViewFrame = CGRect(origin: .zero, size: containerFrame.size)
            transition.setFrame(view: self.scrollView, frame: scrollViewFrame)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.isScrollEnabled = !isTablet && contentSize.width > scrollViewFrame.width + .ulpOfOne
            
            self.layoutData = LayoutData(containerSize: containerFrame.size, selectedFrame: selectedFrame.insetBy(dx: -inset, dy: 3.0), cornerRadius: cornerRadius, isTablet: isTablet)
            
            self.ignoreScrolling = true
            var scrollViewBounds = CGRect(origin: self.scrollView.bounds.origin, size: scrollViewFrame.size)
            let maxContentOffsetX = max(0.0, contentSize.width - scrollViewFrame.width)
            let shouldFocusOnSelectedItem = previousComponent?.currentMode != component.currentMode || previousComponent?.availableModes != component.availableModes || self.scrollView.bounds.size != scrollViewFrame.size
            if self.scrollView.isScrollEnabled && shouldFocusOnSelectedItem {
                let scrollLookahead = min(60.0, scrollViewBounds.width * 0.25)
                if scrollViewBounds.minX + scrollViewBounds.width - scrollLookahead < selectedFrame.maxX {
                    scrollViewBounds.origin.x = selectedFrame.maxX - scrollViewBounds.width + scrollLookahead
                }
                if scrollViewBounds.minX > selectedFrame.minX - scrollLookahead {
                    scrollViewBounds.origin.x = selectedFrame.minX - scrollLookahead
                }
            }
            scrollViewBounds.origin.x = max(0.0, min(scrollViewBounds.origin.x, maxContentOffsetX))
            transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}
