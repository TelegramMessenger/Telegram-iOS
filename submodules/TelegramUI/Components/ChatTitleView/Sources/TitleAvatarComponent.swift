import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import AvatarNode

/// A peer's small avatar before a chat's title (`ChatTitleLeadingIcon.peer`).
final class TitleAvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer
    let imageOverride: AvatarNodeImageOverride?

    init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer, imageOverride: AvatarNodeImageOverride?) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.imageOverride = imageOverride
    }

    static func ==(lhs: TitleAvatarComponent, rhs: TitleAvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.imageOverride != rhs.imageOverride {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode

        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 9.0))
            super.init(frame: frame)
            self.addSubview(self.avatarNode.view)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: TitleAvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let size = availableSize
            var clipStyle: AvatarNodeClipStyle = .round
            if case let .channel(channel) = component.peer, channel.isForum {
                clipStyle = .roundedRect
            }
            self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, overrideImage: component.imageOverride, emptyColor: component.theme.list.mediaPlaceholderColor, clipStyle: clipStyle, displayDimensions: size)
            self.avatarNode.frame = CGRect(origin: CGPoint(), size: size)
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
