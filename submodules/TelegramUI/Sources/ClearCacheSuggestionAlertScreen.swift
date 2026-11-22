import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import AlertHeaderComponent
import AvatarNode

func clearCacheSuggestionAlertScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
    peer: EnginePeer,
    openStorage: @escaping () -> Void
) -> AlertScreen {
    let presentationDataSignal = Signal<PresentationData, NoError>.single(updatedPresentationData.initial)
    |> then(updatedPresentationData.signal)

    return AlertScreen(
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        contentSignal: presentationDataSignal |> map { presentationData in
            return [
                AnyComponentWithIdentity(
                    id: "header",
                    component: AnyComponent(
                        AlertHeaderComponent(component: AnyComponentWithIdentity(
                            id: "avatar",
                            component: AnyComponent(ClearCacheSuggestionAvatarComponent(
                                context: context,
                                theme: presentationData.theme,
                                peer: peer
                            ))
                        ))
                    )
                ),
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AlertTitleComponent(title: presentationData.strings.Conversation_Moderate_Delete))
                ),
                AnyComponentWithIdentity(
                    id: "text",
                    component: AnyComponent(AlertTextComponent(content: .plain(presentationData.strings.ClearCache_FreeSpaceDescription)))
                )
            ]
        },
        actionsSignal: presentationDataSignal |> map { presentationData in
            return [
                AlertScreen.Action(title: presentationData.strings.ClearCache_FreeSpace, type: .default, action: openStorage),
                AlertScreen.Action(title: presentationData.strings.Common_Cancel, type: .generic)
            ]
        },
        updatedPresentationData: updatedPresentationData
    )
}

private final class ClearCacheSuggestionAvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer

    init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer) {
        self.context = context
        self.theme = theme
        self.peer = peer
    }

    static func ==(lhs: ClearCacheSuggestionAvatarComponent, rhs: ClearCacheSuggestionAvatarComponent) -> Bool {
        return lhs.context === rhs.context && lhs.theme === rhs.theme && lhs.peer == rhs.peer
    }

    final class View: UIView {
        private let avatarNode: AvatarNode

        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 34.0))
            self.avatarNode.isAccessibilityElement = false

            super.init(frame: frame)

            self.addSubnode(self.avatarNode)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: ClearCacheSuggestionAvatarComponent) -> CGSize {
            let size = CGSize(width: 80.0, height: 80.0)
            var clipStyle: AvatarNodeClipStyle = .round
            if case let .channel(channel) = component.peer, channel.isMonoForum {
                clipStyle = .bubble
            }

            let overrideImage: AvatarNodeImageOverride?
            if component.peer.id == component.context.account.peerId {
                overrideImage = .savedMessagesIcon
            } else if component.peer.id.isReplies {
                overrideImage = .repliesIcon
            } else if component.peer.id.isAnonymousSavedMessages {
                overrideImage = .anonymousSavedMessagesIcon(isColored: true)
            } else if component.peer.isDeleted {
                overrideImage = .deletedIcon
            } else {
                overrideImage = nil
            }

            self.avatarNode.frame = CGRect(origin: .zero, size: size)
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                overrideImage: overrideImage,
                clipStyle: clipStyle,
                synchronousLoad: true,
                displayDimensions: size
            )
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self)
    }
}
