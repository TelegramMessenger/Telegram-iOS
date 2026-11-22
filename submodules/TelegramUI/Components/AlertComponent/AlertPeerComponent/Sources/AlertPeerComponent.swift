import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import AlertComponent
import AvatarComponent
import MultilineTextComponent

private final class AlertPeerStopBadgeComponent: Component {
    static func ==(lhs: AlertPeerStopBadgeComponent, rhs: AlertPeerStopBadgeComponent) -> Bool {
        return true
    }

    final class View: UIImageView {
        private static let image: UIImage? = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            context.setFillColor(UIColor(rgb: 0xff3b30).cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))

            let barHeight: CGFloat = 2.0 - UIScreenPixel
            let barFrame = CGRect(
                x: floorToScreenPixels((size.width - 10.0) * 0.5),
                y: floorToScreenPixels((size.height - barHeight) * 0.5),
                width: 10.0,
                height: barHeight
            )
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(UIBezierPath(roundedRect: barFrame, cornerRadius: barHeight * 0.5).cgPath)
            context.fillPath()
        })

        func update(component: AlertPeerStopBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.image = View.image
            return CGSize(width: 16.0, height: 16.0)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class AlertPeerComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment

    private let context: AccountContext
    private let peer: EnginePeer
    private let memberCount: Int32?

    public init(
        context: AccountContext,
        peer: EnginePeer,
        memberCount: Int32?
    ) {
        self.context = context
        self.peer = peer
        self.memberCount = memberCount
    }

    public static func ==(lhs: AlertPeerComponent, rhs: AlertPeerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.memberCount != rhs.memberCount {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()

        private var component: AlertPeerComponent?
        private weak var state: EmptyComponentState?
        
        private func isPrivateGroup(_ peer: EnginePeer) -> Bool {
            switch peer {
            case .legacyGroup(_):
                return true
            case let .channel(channel):
                if case .group = channel.info {
                    if let addressName = peer.addressName, !addressName.isEmpty {
                        return false
                    }
                    if peer.usernames.contains(where: { $0.flags.contains(.isActive) && !$0.username.isEmpty }) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            default:
                return false
            }
        }

        func update(component: AlertPeerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environment = environment[AlertComponentEnvironment.self]

            let avatarSize = CGSize(width: 40.0, height: 40.0)
            let verticalInset: CGFloat = 4.0
            let textSpacing: CGFloat = 12.0
            let textLeft = -6.0 + avatarSize.width + textSpacing
            let textWidth = max(1.0, availableSize.width - textLeft)

            let avatarSizeValue = self.avatar.update(
                transition: transition,
                component: AnyComponent(AvatarComponent(
                    context: component.context,
                    theme: environment.theme,
                    peer: component.peer,
                    icon: AnyComponent(AlertPeerStopBadgeComponent())
                )),
                environment: {},
                containerSize: avatarSize
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setFrame(view: avatarView, frame: CGRect(origin: CGPoint(x: -6.0, y: verticalInset), size: avatarSizeValue))
            }

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.peer.compactDisplayTitle,
                        font: Font.semibold(16.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )

            let memberCountText: String
            if let memberCount = component.memberCount {
                if memberCount == 1 {
                    memberCountText = "1 member"
                } else {
                    memberCountText = "\(memberCount) members"
                }
            } else if self.isPrivateGroup(component.peer) {
                memberCountText = "private group"
            } else {
                memberCountText = "0 members"
            }
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: memberCountText,
                        font: Font.regular(14.0),
                        textColor: environment.theme.actionSheet.secondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )

            let textHeight = titleSize.height + 2.0 + subtitleSize.height
            let textY = verticalInset + floorToScreenPixels((avatarSize.height - textHeight) * 0.5)

            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: textLeft, y: textY), size: titleSize))
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: CGRect(origin: CGPoint(x: textLeft, y: textY + titleSize.height + 2.0), size: subtitleSize))
            }

            return CGSize(width: availableSize.width, height: avatarSize.height + verticalInset * 2.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
