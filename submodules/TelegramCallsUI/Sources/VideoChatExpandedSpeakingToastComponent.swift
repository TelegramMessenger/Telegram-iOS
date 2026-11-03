import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AvatarNode
import TelegramPresentationData
import AccountContext
import TelegramCore
import Markdown
import TextFormat

final class VideoChatExpandedSpeakingToastComponent: Component {
    let context: AccountContext
    let peer: EnginePeer
    let strings: PresentationStrings
    let theme: PresentationTheme
    let action: (EnginePeer) -> Void

    init(
        context: AccountContext,
        peer: EnginePeer,
        strings: PresentationStrings,
        theme: PresentationTheme,
        action: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.strings = strings
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: VideoChatExpandedSpeakingToastComponent, rhs: VideoChatExpandedSpeakingToastComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private var avatarNode: AvatarNode?

        private var component: VideoChatExpandedSpeakingToastComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            if let component = self.component {
                component.action(component.peer)
            }
        }
        
        func update(component: VideoChatExpandedSpeakingToastComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let avatarLeftInset: CGFloat = 3.0
            let avatarVerticalInset: CGFloat = 3.0
            let avatarSpacing: CGFloat = 12.0
            let rightInset: CGFloat = 16.0
            let avatarWidth: CGFloat = 32.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            let bodyAttributes = MarkdownAttributeSet(font: Font.regular(15.0), textColor: .white, additionalAttributes: [:])
            let boldAttributes = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: .white, additionalAttributes: [:])
            let titleText = addAttributesToStringWithRanges(component.strings.VoiceChat_ParticipantIsSpeaking(component.peer.displayTitle(strings: component.strings, displayOrder: presentationData.nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleText)
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarLeftInset - avatarWidth - avatarSpacing - rightInset, height: 100.0)
            )
            
            let size = CGSize(width: avatarLeftInset + avatarWidth + avatarSpacing + titleSize.width + rightInset, height: avatarWidth + avatarVerticalInset * 2.0)
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: UIColor(white: 0.0, alpha: 0.9),
                    cornerRadius: .value(size.height * 0.5),
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    backgroundView.isUserInteractionEnabled = false
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: avatarLeftInset + avatarWidth + avatarSpacing, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
                avatarNode.isUserInteractionEnabled = false
            }
            
            let avatarSize = CGSize(width: avatarWidth, height: avatarWidth)
            
            let clipStyle: AvatarNodeClipStyle
            if case let .channel(channel) = component.peer, channel.isForumOrMonoForum {
                clipStyle = .roundedRect
            } else {
                clipStyle = .round
            }
            
            if component.peer.smallProfileImage != nil {
                avatarNode.setPeerV2(
                    context: component.context,
                    theme: component.theme,
                    peer: component.peer,
                    authorOfMessage: nil,
                    overrideImage: nil,
                    emptyColor: nil,
                    clipStyle: .round,
                    synchronousLoad: false,
                    displayDimensions: avatarSize
                )
            } else {
                avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, clipStyle: clipStyle, synchronousLoad: false, displayDimensions: avatarSize)
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: avatarVerticalInset), size: avatarSize)
            transition.setPosition(view: avatarNode.view, position: avatarFrame.center)
            transition.setBounds(view: avatarNode.view, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            avatarNode.updateSize(size: avatarSize)
            
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
