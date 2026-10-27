import Foundation
import UIKit
import Display
import ComponentFlow

final class ZoomComponent: Component {
    let availableValues: [Float]
    let value: Float
    let tag: AnyObject?
    let selected: (Float) -> Void
    
    init(
        availableValues: [Float],
        value: Float,
        tag: AnyObject?,
        selected: @escaping (Float) -> Void
    ) {
        self.availableValues = availableValues
        self.value = value
        self.tag = tag
        self.selected = selected
    }
    
    static func ==(lhs: ZoomComponent, rhs: ZoomComponent) -> Bool {
        if lhs.availableValues != rhs.availableValues {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    final class View: UIView, UIGestureRecognizerDelegate, ComponentTaggedView {
        final class ItemView: HighlightTrackingButton {
            var level: Float = 1.0
            
            init() {
                super.init(frame: .zero)
                
                self.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3)
                if #available(iOS 13.0, *) {
                    self.layer.cornerCurve = .circular
                }
                self.layer.cornerRadius = 18.5
            }
            
            required init(coder: NSCoder) {
                preconditionFailure()
            }
            
            func update(value: String, selected: Bool) {
                self.setAttributedTitle(NSAttributedString(string: value, font: Font.with(size: 13.0, design: .round, weight: .semibold), textColor: selected ? UIColor(rgb: 0xffd300) : .white, paragraphAlignment: .center), for: .normal)
            }
        }
        
        private let backgroundView: BlurredBackgroundView
        private var itemViews: [ItemView] = []
        
        private var component: ZoomComponent?
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
            self.backgroundView = BlurredBackgroundView(color: UIColor(rgb: 0x222222, alpha: 0.3))
            self.backgroundView.clipsToBounds = true
            self.backgroundView.layer.cornerRadius = 43.0 / 2.0
        
            super.init(frame: CGRect())
            
            self.layer.allowsGroupOpacity = true

            self.addSubview(self.backgroundView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func itemPressed(_ itemView: ItemView) {
            self.component?.selected(itemView.level)
        }
        
        func animateIn() {
            self.backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        func animateOut() {
            self.backgroundView.alpha = 0.0
            self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
        }

        func update(component: ZoomComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
        
            let sideInset: CGFloat = 3.0
            let spacing: CGFloat = 3.0
            let buttonSize = CGSize(width: 37.0, height: 37.0)
            let size: CGSize = CGSize(width: buttonSize.width * CGFloat(component.availableValues.count) + spacing * CGFloat(component.availableValues.count - 1) + sideInset * 2.0, height: 43.0)
            
            let selectedLevel = chatCameraSelectedZoomLevel(levels: component.availableValues, scale: component.value)
            var i = 0
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: 3.0), size: buttonSize)
            for value in component.availableValues {
                let itemView: ItemView
                if self.itemViews.count == i {
                    itemView = ItemView()
                    itemView.addTarget(self, action: #selector(self.itemPressed(_:)), for: .touchUpInside)
                    self.addSubview(itemView)
                    self.itemViews.append(itemView)
                } else {
                    itemView = self.itemViews[i]
                }
                let isSelected = value == selectedLevel
                itemView.level = value
                itemView.update(value: chatCameraZoomLabel(level: value, selected: isSelected, scale: component.value), selected: isSelected)
                itemView.bounds = CGRect(origin: .zero, size: itemFrame.size)
                itemView.center = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                if isSelected {
                    itemView.transform = CGAffineTransformIdentity
                } else {
                    itemView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                }
                
                i += 1
                itemFrame = itemFrame.offsetBy(dx: buttonSize.width + spacing, dy: 0.0)
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            self.backgroundView.update(size: size, transition: transition.containedViewLayoutTransition)
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
