import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ComponentDisplayAdapters

final class BottomPanelComponent: Component {
    let theme: PresentationTheme
    let content: AnyComponentWithIdentity<Empty>
    let insets: UIEdgeInsets
    
    init(
        theme: PresentationTheme,
        content: AnyComponentWithIdentity<Empty>,
        insets: UIEdgeInsets
    ) {
        self.theme = theme
        self.content = content
        self.insets = insets
    }

    static func ==(lhs: BottomPanelComponent, rhs: BottomPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }

    final class View: UIView {
        private let separatorLayer: SimpleLayer
        private let backgroundView: BlurredBackgroundView
        private var content = ComponentView<Empty>()

        private var component: BottomPanelComponent?
        private weak var componentState: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)

            super.init(frame: frame)

            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separatorLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BottomPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.componentState = state
            
            let themeUpdated = previousComponent?.theme !== component.theme

            var contentHeight: CGFloat = 0.0

            contentHeight += component.insets.top
            
            var contentTransition = transition
            if let previousComponent, previousComponent.content.id != component.content.id {
                contentTransition = contentTransition.withAnimation(.none)
                self.content.view?.removeFromSuperview()
                self.content = ComponentView<Empty>()
            }
            
            let contentSize = self.content.update(
                transition: contentTransition,
                component: component.content.component,
                environment: {},
                containerSize: CGSize(width: availableSize.width - component.insets.left - component.insets.right, height: availableSize.height - component.insets.top - component.insets.bottom)
            )
            let contentFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - contentSize.width) * 0.5), y: contentHeight), size: contentSize)
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                contentTransition.setFrame(view: contentView, frame: contentFrame)
            }
            contentHeight += contentSize.height
                
            contentHeight += component.insets.bottom
            
            let size = CGSize(width: availableSize.width, height: contentHeight)
            
            if themeUpdated {
                self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
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
