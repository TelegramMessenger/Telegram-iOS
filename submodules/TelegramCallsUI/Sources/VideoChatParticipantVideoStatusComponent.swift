import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import BundleIconComponent
import MultilineTextComponent

final class VideoChatParticipantVideoStatusComponent: Component {
    enum Kind {
        case ownScreenshare
        case paused
    }

    let strings: PresentationStrings
    let kind: Kind
    let isExpanded: Bool

    init(
        strings: PresentationStrings,
        kind: Kind,
        isExpanded: Bool
    ) {
        self.strings = strings
        self.kind = kind
        self.isExpanded = isExpanded
    }

    static func ==(lhs: VideoChatParticipantVideoStatusComponent, rhs: VideoChatParticipantVideoStatusComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.kind != rhs.kind {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }

    final class View: UIView {
        private var icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()

        private var component: VideoChatParticipantVideoStatusComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: VideoChatParticipantVideoStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            
            var iconTransition = transition
            if let previousComponent, previousComponent.kind != component.kind {
                self.icon.view?.removeFromSuperview()
                self.icon = ComponentView()
                iconTransition = iconTransition.withAnimation(.none)
            }
            
            let iconName: String
            let titleValue: String
            switch component.kind {
            case .ownScreenshare:
                iconName = "Call/ScreenSharePhone"
                titleValue = component.strings.VoiceChat_YouAreSharingScreen
            case .paused:
                iconName = "Call/Pause"
                titleValue = component.strings.VoiceChat_VideoPaused
            }
            
            let iconSize = self.icon.update(
                transition: iconTransition,
                component: AnyComponent(BundleIconComponent(
                    name: iconName,
                    tintColor: .white
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleValue, font: Font.semibold(14.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 8.0 * 2.0, height: 100.0)
            )
            
            let scale: CGFloat = component.isExpanded ? 1.0 : 0.825
            
            let spacing: CGFloat = 18.0
            let contentHeight: CGFloat = iconSize.height + spacing + titleSize.height
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: floor((availableSize.height - contentHeight) * 0.5)), size: iconSize)
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: iconFrame.maxY + spacing), size: titleSize)
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconTransition.setFrame(view: iconView, frame: iconFrame)
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                iconTransition.setFrame(view: titleView, frame: titleFrame)
            }
            
            iconTransition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(scale, scale, 1.0))
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
