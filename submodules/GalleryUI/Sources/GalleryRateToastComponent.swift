import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import MultilineTextComponent
import AnimatedTextComponent

final class GalleryRateToastComponent: Component {
    let rate: Double
    
    init(rate: Double) {
        self.rate = rate
    }
    
    static func ==(lhs: GalleryRateToastComponent, rhs: GalleryRateToastComponent) -> Bool {
        if lhs.rate != rhs.rate {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let arrows = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: GalleryRateToastComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let insets = UIEdgeInsets(top: 5.0, left: 11.0, bottom: 5.0, right: 16.0)
            let spacing: CGFloat = 5.0
            
            var rateString = String(format: "%.1f", component.rate)
            if rateString.hasSuffix(".0") {
                rateString = rateString.replacingOccurrences(of: ".0", with: "")
            }
            
            var textItems: [AnimatedTextComponent.Item] = []
            if let dotRange = rateString.range(of: ".") {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("pre"), content: .text(String(rateString[rateString.startIndex ..< dotRange.lowerBound]))))
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("dot"), content: .text(".")))
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("post"), content: .text(String(rateString[dotRange.upperBound...]))))
            } else {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("pre"), content: .text(rateString)))
            }
            textItems.append(AnimatedTextComponent.Item(id: AnyHashable("x"), content: .text("x")))
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(17.0),
                    color: .white,
                    items: textItems
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let arrowsSize = self.arrows.update(
                transition: transition,
                component: AnyComponent(GalleryRateToastAnimationComponent()),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            
            let size = CGSize(width: insets.left + insets.right + textSize.width + arrowsSize.width, height: insets.top + insets.bottom + max(textSize.height, arrowsSize.height))
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: UIColor(white: 0.0, alpha: 0.5),
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left, y: floorToScreenPixels((size.height - textSize.height) * 0.5)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            let arrowsFrame = CGRect(origin: CGPoint(x: textFrame.maxX + spacing, y: floorToScreenPixels((size.height - arrowsSize.height) * 0.5)), size: arrowsSize)
            if let arrowsView = self.arrows.view {
                if arrowsView.superview == nil {
                    self.addSubview(arrowsView)
                }
                transition.setFrame(view: arrowsView, frame: arrowsFrame)
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
