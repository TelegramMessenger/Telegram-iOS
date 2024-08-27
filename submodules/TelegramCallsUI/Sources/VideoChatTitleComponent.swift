import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData

final class VideoChatTitleComponent: Component {
    enum Status: Equatable {
        enum Key {
            case idle
            case speaking
        }
        
        case idle(count: Int)
        case speaking(titles: [String])
        
        var key: Key {
            switch self {
            case .idle:
                return .idle
            case .speaking:
                return .speaking
            }
        }
    }

    let title: String
    let status: Status
    let strings: PresentationStrings

    init(
        title: String,
        status: Status,
        strings: PresentationStrings
    ) {
        self.title = title
        self.status = status
        self.strings = strings
    }

    static func ==(lhs: VideoChatTitleComponent, rhs: VideoChatTitleComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private var status: ComponentView<Empty>?

        private var component: VideoChatTitleComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: VideoChatTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            
            let spacing: CGFloat = 1.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            if previousComponent?.status.key != component.status.key {
                if let status = self.status {
                    self.status = nil
                    if let statusView = status.view {
                        transition.setAlpha(view: statusView, alpha: 0.0, completion: { [weak statusView] _ in
                            statusView?.removeFromSuperview()
                        })
                        transition.setPosition(view: statusView, position: statusView.center.offsetBy(dx: 0.0, dy: -10.0))
                    }
                }
            }
            
            let status: ComponentView<Empty>
            if let current = self.status {
                status = current
            } else {
                status = ComponentView()
                self.status = status
            }
            let statusComponent: AnyComponent<Empty>
            switch component.status {
            case let .idle(count):
                statusComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.VoiceChat_Panel_Members(Int32(count)), font: Font.regular(13.0), textColor: UIColor(white: 1.0, alpha: 0.5)))
                ))
            case let .speaking(titles):
                statusComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titles.joined(separator: ", "), font: Font.regular(13.0), textColor: UIColor(rgb: 0x34c759)))
                ))
            }
            
            let statusSize = status.update(
                transition: .immediate,
                component: statusComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: titleSize.height + spacing + statusSize.height)
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let statusFrame = CGRect(origin: CGPoint(x: floor((size.width - statusSize.width) * 0.5), y: titleFrame.maxY + spacing), size: statusSize)
            if let statusView = status.view {
                if statusView.superview == nil {
                    self.addSubview(statusView)
                }
                transition.setPosition(view: statusView, position: statusFrame.center)
                statusView.bounds = CGRect(origin: CGPoint(), size: statusFrame.size)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
