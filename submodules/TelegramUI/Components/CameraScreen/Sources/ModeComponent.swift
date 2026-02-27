import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import GlassBackgroundComponent
import LiquidLens
import TabSelectionRecognizer

extension CameraState.CameraMode {
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .photo:
            return strings.Story_Camera_Photo
        case .video:
            return strings.Story_Camera_Video
        case .live:
            return strings.Story_Camera_Live
        }
    }
}

private let buttonSize = CGSize(width: 55.0, height: 48.0)
private let tabletButtonSize = CGSize(width: 55.0, height: 44.0)

final class ModeComponent: Component {
    let isTablet: Bool
    let strings: PresentationStrings
    let tintColor: UIColor
    let availableModes: [CameraState.CameraMode]
    let currentMode: CameraState.CameraMode
    let updatedMode: (CameraState.CameraMode) -> Void
    let tag: AnyObject?
    
    init(
        isTablet: Bool,
        strings: PresentationStrings,
        tintColor: UIColor,
        availableModes: [CameraState.CameraMode],
        currentMode: CameraState.CameraMode,
        updatedMode: @escaping (CameraState.CameraMode) -> Void,
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
    
    final class View: UIView, ComponentTaggedView {
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
                let accentColor: UIColor
                let normalColor: UIColor
                if tintColor.rgb == 0xffffff {
                    accentColor = UIColor(rgb: 0xffd300)
                    normalColor = .white
                } else {
                    accentColor = tintColor
                    normalColor = tintColor.withAlphaComponent(0.5)
                }
                
                let title = NSMutableAttributedString(string: value.uppercased(), font: Font.with(size: 14.0, design: .regular, weight: .medium), textColor: selected ? accentColor : normalColor, paragraphAlignment: .center)
                title.addAttribute(.kern, value: -0.5 as NSNumber, range: NSMakeRange(0, title.length))
                self.setAttributedTitle(title, for: .normal)
                self.sizeToFit()
                
                return CGSize(width: self.titleLabel?.bounds.size.width ?? 0.0, height: isTablet ? tabletButtonSize.height : buttonSize.height)
            }
        }
        
        private var backgroundView = UIView()
        private var backgroundContainer = GlassBackgroundContainerView()
        
        private var liquidLensView: LiquidLensView?
                
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
            
            self.backgroundView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.11)
            self.backgroundView.layer.cornerRadius = 24.0
                        
            self.layer.allowsGroupOpacity = true
            
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
        
        private func item(at point: CGPoint) -> AnyHashable? {
            var closestItem: (AnyHashable, CGFloat)?
            for (id, itemView) in self.itemViews {
                if itemView.frame.contains(point) {
                    return id
                } else {
                    let distance = abs(point.x - itemView.center.x)
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
        
        @objc private func onTabSelectionGesture(_ recognizer: TabSelectionRecognizer) {
            guard let component = self.component, let liquidLensView = self.liquidLensView else {
                return
            }
            let location = recognizer.location(in: liquidLensView.contentView)
            switch recognizer.state {
            case .began:
                if let itemId = self.item(at: location), let itemView = self.itemViews[itemId] {
                    let startX = itemView.frame.minX - 4.0
                    self.selectionGestureState = (startX, startX, itemId)
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
            case .changed:
                if var selectionGestureState = self.selectionGestureState {
                    selectionGestureState.currentX = selectionGestureState.startX + recognizer.translation(in: self).x
                    if let itemId = self.item(at: location) {
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
                
        func update(component: ModeComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
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
                
                let tabSelectionRecognizer = TabSelectionRecognizer(target: self, action: #selector(self.onTabSelectionGesture(_:)))
                self.tabSelectionRecognizer = tabSelectionRecognizer
                liquidLensView.addGestureRecognizer(tabSelectionRecognizer)
            }
            
            self.backgroundView.backgroundColor = component.isTablet ? .clear : UIColor(rgb: 0xffffff, alpha: 0.11)
        
            let inset: CGFloat = 23.0
            let spacing: CGFloat = isTablet ? 9.0 : 40.0
      
            var i = 0
            var itemFrame = CGRect(origin: isTablet ? .zero : CGPoint(x: inset, y: 0.0), size: buttonSize)
            var selectedFrame = itemFrame
            
            var validKeys: Set<AnyHashable> = Set()
            for mode in component.availableModes.reversed() {
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
                    liquidLensView.contentView.addSubview(itemView)
                    
                    selectedItemView = ItemView()
                    selectedItemView.isUserInteractionEnabled = false
                    self.selectedItemViews[id] = selectedItemView
                    liquidLensView.selectedContentView.addSubview(selectedItemView)
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
                }
            }
            for id in removeKeys {
                self.itemViews.removeValue(forKey: id)
            }
            
            let totalSize: CGSize
            let size: CGSize
            var cornerRadius: CGFloat?
            if isTablet {
                totalSize = CGSize(width: availableSize.width, height: tabletButtonSize.height * CGFloat(component.availableModes.count) + spacing * CGFloat(component.availableModes.count - 1))
                size = CGSize(width: availableSize.width, height: availableSize.height)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: totalSize))
                cornerRadius = 20.0
            } else {
                size = CGSize(width: availableSize.width, height: buttonSize.height)
                totalSize = CGSize(width: itemFrame.minX - spacing + inset, height: buttonSize.height)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - totalSize.width) / 2.0), y: 0.0), size: totalSize))
            }
            
            let containerFrame = CGRect(origin: .zero, size: self.backgroundView.frame.size)
            transition.setFrame(view: self.backgroundContainer, frame: containerFrame)
            
            let selectionFrame = selectedFrame.insetBy(dx: -23.0, dy: 3.0)
            var lensSelection: (origin: CGPoint, size: CGSize)
            if let selectionGestureState = self.selectionGestureState, !isTablet {
                lensSelection = (CGPoint(x: selectionGestureState.currentX, y: 0.0), selectionFrame.size)
            } else {
                lensSelection = (CGPoint(x: selectionFrame.minX, y: selectionFrame.minY), selectionFrame.size)
            }
            
            if isTablet {
                lensSelection.size.width = size.width
            } else {
                lensSelection.size.height = containerFrame.size.height
                lensSelection.origin.y = 0.0
            }
            
            transition.setFrame(view: liquidLensView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: containerFrame.size))
            liquidLensView.update(size: containerFrame.size, cornerRadius: cornerRadius, selectionOrigin: CGPoint(x: max(0.0, min(lensSelection.origin.x, containerFrame.size.width - lensSelection.size.width)), y: lensSelection.origin.y), selectionSize: lensSelection.size, inset: 3.0, isDark: true, isLifted: self.selectionGestureState != nil && !isTablet, isCollapsed: false, transition: transition)
            self.backgroundContainer.update(size: containerFrame.size, isDark: true, transition: .immediate)
            
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

final class HintLabelComponent: Component {
    let text: String
    let tintColor: UIColor
    
    init(
        text: String,
        tintColor: UIColor
    ) {
        self.text = text
        self.tintColor = tintColor
    }
    
    static func ==(lhs: HintLabelComponent, rhs: HintLabelComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var component: HintLabelComponent?
        private var componentView = ComponentView<Empty>()
        
        init() {
            super.init(frame: CGRect())
        }
        
        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
            
        func update(component: HintLabelComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            if let previousText = previousComponent?.text, !previousText.isEmpty && previousText != component.text {
                if let componentView = self.componentView.view, let snapshotView = componentView.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = componentView.frame
                    self.addSubview(snapshotView)
                    snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
                
                self.componentView.view?.removeFromSuperview()
                self.componentView = ComponentView<Empty>()
            }
            
            let textSize = self.componentView.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.text.uppercased(), font: Font.with(size: 14.0, design: .camera, weight: .semibold), textColor: component.tintColor)),
                        horizontalAlignment: .center
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.componentView.view {
                if view.superview == nil {
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.addSubview(view)
                }
                
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0), y: 0.0), size: textSize)
            }
                        
            return CGSize(width: availableSize.width, height: textSize.height)
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
