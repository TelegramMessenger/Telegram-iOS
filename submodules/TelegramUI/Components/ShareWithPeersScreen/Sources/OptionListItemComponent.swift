import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import SwitchComponent

final class OptionListItemComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool, isTinted: Bool)
    }
    
    let theme: PresentationTheme
    let title: String
    let hasNext: Bool
    let selected: Bool
    let selectionChanged: (Bool) -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        hasNext: Bool,
        selected: Bool,
        selectionChanged: @escaping (Bool) -> Void
    ) {
        self.theme = theme
        self.title = title
        self.hasNext = hasNext
        self.selected = selected
        self.selectionChanged = selectionChanged
    }
    
    static func ==(lhs: OptionListItemComponent, rhs: OptionListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.selected != rhs.selected {
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
        private let switchComponent = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        
        private var component: OptionListItemComponent?
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
//            guard let component = self.component else {
//                return
//            }
//            if case .editing(true, _) = component.selectionState {
//                component.secondaryAction()
//            } else {
//                component.action()
//            }
        }
        
        func update(component: OptionListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
                     
            self.component = component
            self.state = state
                        
            let height: CGFloat = 44.0
            let verticalInset: CGFloat = 0.0
            let leftInset: CGFloat = 16.0
            let rightInset: CGFloat = 16.0
            
            let switchSize = self.switchComponent.update(
                transition: .immediate,
                component: AnyComponent(SwitchComponent(
                    tintColor: nil,
                    value: component.selected,
                    valueUpdated: { selected in
                        component.selectionChanged(selected)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
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
            if let switchView = self.switchComponent.view {
                if switchView.superview == nil {
                    self.containerButton.addSubview(switchView)
                }
                transition.setFrame(view: switchView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset - switchSize.width, y: floorToScreenPixels((height - switchSize.height) / 2.0)), size: switchSize))
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
