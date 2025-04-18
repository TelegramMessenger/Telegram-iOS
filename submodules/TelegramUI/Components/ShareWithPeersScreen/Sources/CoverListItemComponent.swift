import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import SwitchComponent

final class CoverListItemComponent: Component {
    let theme: PresentationTheme
    let title: String
    let image: UIImage?
    let hasNext: Bool
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        image: UIImage?,
        hasNext: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.image = image
        self.hasNext = hasNext
        self.action = action
    }
    
    static func ==(lhs: CoverListItemComponent, rhs: CoverListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.image !== rhs.image {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        
        private var component: CoverListItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.containerButton = HighlightTrackingButton()
                        
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        func update(component: CoverListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
                     
            self.component = component
            self.state = state
                        
            let height: CGFloat = 44.0
            let verticalInset: CGFloat = 0.0
            let leftInset: CGFloat = 16.0
            let rightInset: CGFloat = 16.0
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(Image(image: component.image, contentMode: .scaleAspectFill)),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.clipsToBounds = true
                    iconView.layer.cornerRadius = 5.0
                    self.containerButton.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset - iconSize.width, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: verticalInset), size: CGSize(width: availableSize.width, height: height - verticalInset * 2.0))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
