import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import EmojiStatusComponent

/// A provider's icon: its custom emoji when the server sets `icon_emoji_id`, otherwise a rounded square with the
/// title's first letter.
public final class AgentProviderIconComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let provider: EngineAgentProvider
    let size: CGFloat

    public init(context: AccountContext, theme: PresentationTheme, provider: EngineAgentProvider, size: CGFloat = 30.0) {
        self.context = context
        self.theme = theme
        self.provider = provider
        self.size = size
    }

    public static func ==(lhs: AgentProviderIconComponent, rhs: AgentProviderIconComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.provider != rhs.provider {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var emoji: ComponentView<Empty>?
        private let placeholderView: UIView
        private let letterView: ImmediateTextView

        override init(frame: CGRect) {
            self.placeholderView = UIView()
            self.letterView = ImmediateTextView()

            super.init(frame: frame)

            self.placeholderView.addSubview(self.letterView)
            self.addSubview(self.placeholderView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: AgentProviderIconComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: component.size, height: component.size)

            if let iconEmojiId = component.provider.iconEmojiId {
                self.placeholderView.isHidden = true

                let emoji: ComponentView<Empty>
                if let current = self.emoji {
                    emoji = current
                } else {
                    emoji = ComponentView()
                    self.emoji = emoji
                }
                let emojiSize = emoji.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .animation(content: .customEmoji(fileId: iconEmojiId), size: size, placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.theme.list.itemAccentColor, loopMode: .count(0)),
                        isVisibleForAnimations: false,
                        action: nil
                    )),
                    environment: {},
                    containerSize: size
                )
                if let emojiView = emoji.view {
                    if emojiView.superview == nil {
                        self.addSubview(emojiView)
                    }
                    emojiView.frame = CGRect(origin: CGPoint(x: floor((size.width - emojiSize.width) * 0.5), y: floor((size.height - emojiSize.height) * 0.5)), size: emojiSize)
                }
            } else {
                if let emoji = self.emoji {
                    self.emoji = nil
                    emoji.view?.removeFromSuperview()
                }
                self.placeholderView.isHidden = false
                self.placeholderView.backgroundColor = component.theme.list.itemAccentColor
                self.placeholderView.layer.cornerRadius = floor(component.size * 0.23)
                self.placeholderView.frame = CGRect(origin: CGPoint(), size: size)

                let letter = component.provider.title.first.flatMap { String($0).uppercased() } ?? ""
                self.letterView.attributedText = NSAttributedString(string: letter, font: Font.semibold(floor(component.size * 0.5)), textColor: component.theme.list.itemCheckColors.foregroundColor)
                let letterSize = self.letterView.updateLayout(size)
                self.letterView.frame = CGRect(origin: CGPoint(x: floor((size.width - letterSize.width) * 0.5), y: floor((size.height - letterSize.height) * 0.5)), size: letterSize)
            }

            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
