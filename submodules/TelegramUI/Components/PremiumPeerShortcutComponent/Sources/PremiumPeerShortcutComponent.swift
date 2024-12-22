import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import AvatarNode
import MultilineTextComponent
import EmojiTextAttachmentView
import TextFormat

public final class PremiumPeerShortcutComponent: Component {
    public enum IconPosition {
        case left
        case right
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer
    let icon: TelegramMediaFile?
    let iconPosition: IconPosition

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        peer: EnginePeer,
        icon: TelegramMediaFile? = nil,
        iconPosition: IconPosition = .right
    ) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.icon = icon
        self.iconPosition = iconPosition
    }

    public static func ==(lhs: PremiumPeerShortcutComponent, rhs: PremiumPeerShortcutComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.iconPosition != rhs.iconPosition {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView = UIView()
        private let avatarNode: AvatarNode
        private let text = ComponentView<Empty>()
        private var animationLayer: InlineStickerItemLayer?
        
        private var component: PremiumPeerShortcutComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 18.0))
            
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            self.backgroundView.layer.cornerRadius = 16.0
            
            self.addSubview(self.backgroundView)
            self.addSubnode(self.avatarNode)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: PremiumPeerShortcutComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            self.backgroundView.backgroundColor = component.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)
                        
            self.avatarNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: 30.0, height: 30.0))
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.peer.compactDisplayTitle, font: Font.medium(15.0), textColor: component.theme.list.itemPrimaryTextColor, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 50.0, height: availableSize.height)
            )
            
            let iconSize = CGSize(width: 20.0, height: 20.0)
            let iconSpacing: CGFloat = 2.0
            var size = CGSize(width: 30.0 + textSize.width + 20.0, height: 32.0)
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: component.iconPosition == .left ? 38.0 + iconSize.width + iconSpacing : 38.0, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                view.frame = textFrame
            }
            
            if let icon = component.icon {
                let animationLayer: InlineStickerItemLayer
                if let current = self.animationLayer {
                    animationLayer = current
                } else {
                    let emoji = ChatTextInputTextCustomEmojiAttribute(
                        interactivelySelectedFromPackId: nil,
                        fileId: icon.fileId.id,
                        file: icon
                    )
                    animationLayer = InlineStickerItemLayer(
                        context: .account(component.context),
                        userLocation: .other,
                        attemptSynchronousLoad: false,
                        emoji: emoji,
                        file: icon,
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        unique: true,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        pointSize: CGSize(width: 20.0, height: 20.0),
                        loopCount: 1
                    )
                    animationLayer.isVisibleForAnimations = true
                    if icon.isCustomTemplateEmoji {
                        animationLayer.dynamicColor = component.theme.actionSheet.controlAccentColor
                    }
                    self.layer.addSublayer(animationLayer)
                    self.animationLayer = animationLayer
                }
                animationLayer.frame = CGRect(origin: CGPoint(x: component.iconPosition == .left ? 38.0 : size.width - 7.0, y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
                size.width += iconSize.width + iconSpacing
            } else if let animationLayer = self.animationLayer  {
                self.animationLayer = nil
                animationLayer.removeFromSuperlayer()
            }
            
            self.backgroundView.frame = CGRect(origin: .zero, size: size)
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
