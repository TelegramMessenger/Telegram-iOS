import Foundation
import UIKit
import Display
import ComponentFlow

extension CameraMode {
    var title: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        }
    }
}

final class ModeComponent: Component {
    let availableModes: [CameraMode]
    let currentMode: CameraMode
    let updatedMode: (CameraMode) -> Void
    
    init(
        availableModes: [CameraMode],
        currentMode: CameraMode,
        updatedMode: @escaping (CameraMode) -> Void
    ) {
        self.availableModes = availableModes
        self.currentMode = currentMode
        self.updatedMode = updatedMode
    }
    
    static func ==(lhs: ModeComponent, rhs: ModeComponent) -> Bool {
        if lhs.availableModes != rhs.availableModes {
            return false
        }
        if lhs.currentMode != rhs.currentMode {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var component: ModeComponent?
        
        final class ItemView: HighlightTrackingButton {
            var pressed: () -> Void = {
                
            }
            
            init() {
                super.init(frame: .zero)
                
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
        
        init() {
            super.init(frame: CGRect())
            
            self.layer.allowsGroupOpacity = true
            
            self.addSubview(self.containerView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
                
        func update(component: ModeComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            let updatedMode = component.updatedMode
            
            let spacing: CGFloat = 14.0
            let buttonSize = CGSize(width: 55.0, height: 44.0)
      
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
               
                itemView.update(value: mode.title, selected: mode == component.currentMode)
                itemView.bounds = CGRect(origin: .zero, size: itemFrame.size)
                itemView.center = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                
                if mode == component.currentMode {
                    selectedCenter = itemFrame.midX
                }
                
                i += 1
                itemFrame = itemFrame.offsetBy(dx: buttonSize.width + spacing, dy: 0.0)
            }
            
            let totalSize = CGSize(width: buttonSize.width * CGFloat(component.availableModes.count) + spacing * CGFloat(component.availableModes.count - 1), height: buttonSize.height)
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: availableSize.width / 2.0 - selectedCenter, y: 0.0), size: totalSize))
            
            return CGSize(width: availableSize.width, height: buttonSize.height)
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
