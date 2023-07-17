import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData

extension CameraMode {
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .photo:
            return strings.Story_Camera_Photo
        case .video:
            return strings.Story_Camera_Video
        }
    }
}

private let buttonSize = CGSize(width: 55.0, height: 44.0)

final class ModeComponent: Component {
    let isTablet: Bool
    let strings: PresentationStrings
    let availableModes: [CameraMode]
    let currentMode: CameraMode
    let updatedMode: (CameraMode) -> Void
    let tag: AnyObject?
    
    init(
        isTablet: Bool,
        strings: PresentationStrings,
        availableModes: [CameraMode],
        currentMode: CameraMode,
        updatedMode: @escaping (CameraMode) -> Void,
        tag: AnyObject?
    ) {
        self.isTablet = isTablet
        self.strings = strings
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
        
        final class ItemView: HighlightTrackingButton {
            var pressed: () -> Void = {
                
            }
            
            init() {
                super.init(frame: .zero)
                
                self.isExclusiveTouch = true
                
                self.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            }
            
            required init(coder: NSCoder) {
                preconditionFailure()
            }
            
            @objc func buttonPressed() {
                self.pressed()
            }
            
            func update(value: String, selected: Bool) {
                self.setAttributedTitle(NSAttributedString(string: value.uppercased(), font: Font.with(size: 14.0, design: .camera, weight: .semibold), textColor: selected ? UIColor(rgb: 0xf8d74a) : .white, paragraphAlignment: .center), for: .normal)
            }
        }
        
        private var containerView = UIView()
        private var itemViews: [ItemView] = []
        
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
            
            self.layer.allowsGroupOpacity = true
            
            self.addSubview(self.containerView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        private var animatedOut = false
        func animateOutToEditor(transition: Transition) {
            self.animatedOut = true
            
            transition.setAlpha(view: self.containerView, alpha: 0.0)
            transition.setSublayerTransform(view: self.containerView, transform: CATransform3DMakeTranslation(0.0, -buttonSize.height, 0.0))
        }
        
        func animateInFromEditor(transition: Transition) {
            self.animatedOut = false
            
            transition.setAlpha(view: self.containerView, alpha: 1.0)
            transition.setSublayerTransform(view: self.containerView, transform: CATransform3DIdentity)
        }
                
        func update(component: ModeComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
        
            let isTablet = component.isTablet
            let updatedMode = component.updatedMode
        
            let spacing: CGFloat = isTablet ? 9.0 : 14.0
      
            var i = 0
            var itemFrame = CGRect(origin: .zero, size: buttonSize)
            var selectedCenter = itemFrame.minX
            
            for mode in component.availableModes {
                let itemView: ItemView
                if self.itemViews.count == i {
                    itemView = ItemView()
                    self.containerView.addSubview(itemView)
                    self.itemViews.append(itemView)
                } else {
                    itemView = self.itemViews[i]
                }
                itemView.pressed = {
                    updatedMode(mode)
                }
               
                itemView.update(value: mode.title(strings: component.strings), selected: mode == component.currentMode)
                itemView.bounds = CGRect(origin: .zero, size: itemFrame.size)
                
                if isTablet {
                    itemView.center = CGPoint(x: availableSize.width / 2.0, y: itemFrame.midY)
                    if mode == component.currentMode {
                        selectedCenter = itemFrame.midY
                    }
                    itemFrame = itemFrame.offsetBy(dx: 0.0, dy: buttonSize.height + spacing)
                } else {
                    itemView.center = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    if mode == component.currentMode {
                        selectedCenter = itemFrame.midX
                    }
                    itemFrame = itemFrame.offsetBy(dx: buttonSize.width + spacing, dy: 0.0)
                }
                                
                i += 1
            }
            
            let totalSize: CGSize
            let size: CGSize
            if isTablet {
                totalSize = CGSize(width: availableSize.width, height: buttonSize.height * CGFloat(component.availableModes.count) + spacing * CGFloat(component.availableModes.count - 1))
                size = CGSize(width: availableSize.width, height: availableSize.height)
                transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height / 2.0 - selectedCenter), size: totalSize))
            } else {
                size = CGSize(width: availableSize.width, height: buttonSize.height)
                totalSize = CGSize(width: buttonSize.width * CGFloat(component.availableModes.count) + spacing * CGFloat(component.availableModes.count - 1), height: buttonSize.height)
                transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: availableSize.width / 2.0 - selectedCenter, y: 0.0), size: totalSize))
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class HintLabelComponent: Component {
    let text: String
    
    init(
        text: String
    ) {
        self.text = text
    }
    
    static func ==(lhs: HintLabelComponent, rhs: HintLabelComponent) -> Bool {
        if lhs.text != rhs.text {
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
            
        func update(component: HintLabelComponent, availableSize: CGSize, transition: Transition) -> CGSize {
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
                        text: .plain(NSAttributedString(string: component.text.uppercased(), font: Font.with(size: 14.0, design: .camera, weight: .semibold), textColor: .white)),
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
