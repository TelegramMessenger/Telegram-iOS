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
    let isPinned: Bool
    let backAction: () -> Void
    let pinAction: () -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isPinned: Bool,
        backAction: @escaping () -> Void,
        pinAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.isPinned = isPinned
        self.backAction = backAction
        self.pinAction = pinAction
    }

    static func ==(lhs: VideoChatExpandedControlsComponent, rhs: VideoChatExpandedControlsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isPinned != rhs.isPinned {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backButton = ComponentView<Empty>()
        private let pinStatus = ComponentView<Empty>()
        
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
            if let pinStatusView = self.pinStatus.view, let result = pinStatusView.hitTest(self.convert(point, to: pinStatusView), with: event) {
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
            
            let pinStatusSize = self.pinStatus.update(
                transition: transition,
                component: AnyComponent(VideoChatPinStatusComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isPinned: component.isPinned,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.pinAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let pinStatusFrame = CGRect(origin: CGPoint(x: availableSize.width - 0.0 - pinStatusSize.width, y: 0.0), size: pinStatusSize)
            if let pinStatusView = self.pinStatus.view {
                if pinStatusView.superview == nil {
                    self.addSubview(pinStatusView)
                }
                transition.setFrame(view: pinStatusView, frame: pinStatusFrame)
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
