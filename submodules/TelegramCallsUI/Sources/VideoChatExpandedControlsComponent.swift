import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import BackButtonComponent

final class VideoChatExpandedControlsComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let backAction: () -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        backAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.backAction = backAction
    }

    static func ==(lhs: VideoChatExpandedControlsComponent, rhs: VideoChatExpandedControlsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backButton = ComponentView<Empty>()
        
        private var component: VideoChatExpandedControlsComponent?
        private var isUpdating: Bool = false
        
        private var ignoreScrolling: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let backButtonView = self.backButton.view, let result = backButtonView.hitTest(self.convert(point, to: backButtonView), with: event) {
                return result
            }
            return nil
        }
        
        func update(component: VideoChatExpandedControlsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let backButtonSize = self.backButton.update(
                transition: transition,
                component: AnyComponent(BackButtonComponent(
                    title: component.strings.Common_Back,
                    color: .white,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.backAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width * 0.5, height: 100.0)
            )
            let backButtonFrame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: backButtonSize)
            if let backButtonView = self.backButton.view {
                if backButtonView.superview == nil {
                    self.addSubview(backButtonView)
                }
                transition.setFrame(view: backButtonView, frame: backButtonFrame)
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
