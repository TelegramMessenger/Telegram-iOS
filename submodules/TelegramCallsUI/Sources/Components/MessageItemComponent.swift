import Foundation
import Display
import UIKit
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AvatarNode
import GlassBackgroundComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import AccountContext
import TextFormat
import TelegramPresentationData
import ReactionSelectionNode
import BundleIconComponent
import LottieComponent
import Markdown

private let glassColor = UIColor(rgb: 0x25272e, alpha: 0.72)

final class MessageItemComponent: Component {
    public enum Icon: Equatable {
        case peer(EnginePeer)
        case icon(String)
        case animation(String)
    }
    
    private let context: AccountContext
    private let icon: Icon
    private let isNotification: Bool
    private let text: String
    private let entities: [MessageTextEntity]
    private let availableReactions: [ReactionItem]?
    private let openPeer: ((EnginePeer) -> Void)?
    
    init(
        context: AccountContext,
        icon: Icon,
        isNotification: Bool,
        text: String,
        entities: [MessageTextEntity],
        availableReactions: [ReactionItem]?,
        openPeer: ((EnginePeer) -> Void)?
    ) {
        self.context = context
        self.icon = icon
        self.isNotification = isNotification
        self.text = text
        self.entities = entities
        self.availableReactions = availableReactions
        self.openPeer = openPeer
    }
    
    static func == (lhs: MessageItemComponent, rhs: MessageItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if (lhs.availableReactions ?? []).isEmpty != (rhs.availableReactions ?? []).isEmpty {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let container: UIView
        private let background: GlassBackgroundView
        private let avatarNode: AvatarNode
        private let icon: ComponentView<Empty>
        private let text: ComponentView<Empty>
        weak var standaloneReactionAnimation: StandaloneReactionAnimation?
        
        private var cachedEntities: [MessageTextEntity]?
        private var entityFiles: [MediaId: TelegramMediaFile] = [:]
        
        private var component: MessageItemComponent?
        
        override init(frame: CGRect) {
            self.container = UIView()
            self.container.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            self.background = GlassBackgroundView()
            
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 12.0))
            self.avatarNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -8.0)
            
            self.icon = ComponentView()
            self.text = ComponentView()
            
            super.init(frame: frame)
                        
            self.addSubview(self.container)
            self.container.addSubview(self.background)
            self.container.addSubview(self.avatarNode.view)
            
            self.avatarNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.avatarTapped)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func avatarTapped() {
            guard let component = self.component, case let .peer(peer) = component.icon else {
                return
            }
            component.openPeer?(peer)
        }
        
        func animateFrom(globalFrame: CGRect, cornerRadius: CGFloat, textSnapshotView: UIView, transition: ComponentTransition) {
            guard let superview = self.superview?.superview?.superview else {
                return
            }
            
            let originalCenter = self.container.center
            let originalTransform = self.container.transform
            
            let superviewCenter = self.convert(self.container.center, to: superview)
            self.container.center = superviewCenter
            self.container.transform = .identity
            superview.addSubview(self.container)
            
            let hasRTL = (self.text.view as? MultilineTextWithEntitiesComponent.View)?.hasRTL ?? false
            let direction: CGFloat = hasRTL ? -1.0 : 1.0
            let initialSize = self.background.frame.size
            
            self.container.addSubview(textSnapshotView)
            transition.setAlpha(view: textSnapshotView, alpha: 0.0, completion: { _ in
                textSnapshotView.removeFromSuperview()
            })
            
            let additionalOffset = hasRTL ? globalFrame.size.width - initialSize.width : 0.0
            transition.setPosition(view: textSnapshotView, position: CGPoint(x: textSnapshotView.center.x + 71.0 * direction - additionalOffset, y: textSnapshotView.center.y))
            
            self.background.update(size: globalFrame.size, cornerRadius: cornerRadius, isDark: true, tintColor: .init(kind: .custom, color: glassColor), transition: .immediate)
            self.background.update(size: initialSize, cornerRadius: 18.0, isDark: true, tintColor: .init(kind: .custom, color: glassColor), transition: transition)
            
            let deltaX = (globalFrame.width - self.container.frame.width) / 2.0
            let deltaY = (globalFrame.height - self.container.frame.height) / 2.0
            let fromFrame = superview.convert(globalFrame, from: nil).offsetBy(dx: -deltaX, dy: -deltaY)
            
            self.container.center = fromFrame.center
            transition.setPosition(view: self.container, position: superviewCenter, completion: { _ in
                self.container.center = originalCenter
                self.container.transform = originalTransform
                self.insertSubview(self.container, at: 0)
            })
            
            if let textView = self.text.view {
                transition.animatePosition(view: textView, from: CGPoint(x: -71.0 * direction, y: 0.0), to: .zero, additive: true)
                transition.animateAlpha(view: textView, from: 0.0, to: 1.0)
            }
            transition.animateAlpha(view: self.avatarNode.view, from: 0.0, to: 1.0)
            transition.animateScale(view: self.avatarNode.view, from: 0.01, to: 1.0)
        }
                
        func update(component: MessageItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            var transition = transition
            if isFirstTime {
                transition = .immediate
            }
            self.component = component
            
            let theme = defaultDarkPresentationTheme
                        
            let textFont = Font.regular(14.0)
            let boldTextFont = Font.semibold(14.0)
            let italicFont = Font.italic(14.0)
            let boldItalicTextFont = Font.semiboldItalic(14.0)
            let monospaceFont = Font.monospace(14.0)
            let textColor: UIColor = .white
            let linkColor: UIColor = UIColor(rgb: 0x59b6fa)
                        
            let minimalHeight: CGFloat = component.isNotification ? 50.0 : 36.0
            let cornerRadius = minimalHeight * 0.5
            let avatarInset: CGFloat = component.isNotification ? 10.0 : 4.0
            let avatarSize = CGSize(width: component.isNotification ? 30.0 : 28.0, height: component.isNotification ? 30.0 : 28.0)
            let avatarSpacing: CGFloat = 10.0
            let iconSpacing: CGFloat = 10.0
            let rightInset: CGFloat = component.isNotification ? 15.0 : 13.0
                        
            var peerName = ""
            if !component.isNotification, case let .peer(peer) = component.icon {
                peerName = peer.compactDisplayTitle
                if peerName.count > 40 {
                    peerName = "\(peerName.prefix(40))…"
                }
            }
            
            let text = component.text
            var entities = component.entities
            
            if let cachedEntities = self.cachedEntities {
                entities = cachedEntities
            } else if let availableReactions = component.availableReactions, text.count == 1 {
                let emoji = component.text.strippedEmoji
                var reactionItem: ReactionItem?
                for item in availableReactions {
                    if case .builtin(emoji) = item.reaction.rawValue {
                        reactionItem = item
                        break
                    }
                }
                if case .builtin = reactionItem?.reaction.rawValue, let item = component.context.animatedEmojiStickersValue[emoji]?.first {
                    self.entityFiles[item.file.fileId] = item.file._parse()
                    entities.insert(MessageTextEntity(range: 0 ..< (text as NSString).length, type: .CustomEmoji(stickerPack: nil, fileId: item.file.fileId.id)), at: 0)
                    self.cachedEntities = entities
                }
            } else {
                entities = entities.filter { entity in
                    switch entity.type {
                    case .Bold, .Italic, .Strikethrough, .Underline, .Spoiler:
                        return true
                    case .CustomEmoji:
                        if case let .peer(peer) = component.icon, peer.isPremium {
                            return true
                        }
                        return false
                    default:
                        return false
                    }
                }
                self.cachedEntities = entities
            }
                        
            let attributedText: NSAttributedString
            if component.isNotification {
                attributedText = parseMarkdownIntoAttributedString(
                    text,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                        bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                        link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                        linkAttribute: { _ in return nil }
                    )
                )
            } else {
                let textWithAppliedEntities = stringWithAppliedEntities(text, entities: entities, baseColor: textColor, linkColor: linkColor, baseFont: textFont, linkFont: textFont, boldFont: boldTextFont, italicFont: italicFont, boldItalicFont: boldItalicTextFont, fixedFont: monospaceFont, blockQuoteFont: textFont, message: nil, entityFiles: self.entityFiles).mutableCopy() as! NSMutableAttributedString
                if !peerName.isEmpty {
                    textWithAppliedEntities.insert(NSAttributedString(string: "\u{2066}\(peerName)\u{2069} ", font: boldTextFont, textColor: textColor), at: 0)
                }
                attributedText = textWithAppliedEntities
            }
            
            let spacing: CGFloat
            switch component.icon {
            case .peer:
                spacing = avatarSpacing
            case .icon:
                spacing = iconSpacing
            case .animation:
                spacing = iconSpacing
            }
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: UIColor(rgb: 0xffffff, alpha: 0.3),
                    text: .plain(attributedText),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    spoilerColor: .white,
                    handleSpoilers: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarInset - avatarSize.width - spacing - rightInset, height: .greatestFiniteMagnitude)
            )
            
            let hasRTL = (self.text.view as? MultilineTextWithEntitiesComponent.View)?.hasRTL ?? false
            
            let size = CGSize(
                width: avatarInset + avatarSize.width + spacing + textSize.width + rightInset,
                height: max(minimalHeight, textSize.height + 15.0)
            )
            
            switch component.icon {
            case let .peer(peer):
                if peer.smallProfileImage != nil {
                    self.avatarNode.setPeerV2(
                        context: component.context,
                        theme: theme,
                        peer: peer,
                        authorOfMessage: nil,
                        overrideImage: nil,
                        emptyColor: nil,
                        clipStyle: .round,
                        synchronousLoad: true,
                        displayDimensions: avatarSize
                    )
                } else {
                    self.avatarNode.setPeer(
                        context: component.context,
                        theme: theme,
                        peer: peer,
                        clipStyle: .round,
                        synchronousLoad: true,
                        displayDimensions: avatarSize
                    )
                }
                let avatarFrame = CGRect(origin: CGPoint(x: avatarInset, y: avatarInset), size: avatarSize)
                if self.avatarNode.bounds.isEmpty {
                    self.avatarNode.frame = mappedFrame(avatarFrame, containerSize: size, hasRTL: hasRTL)
                } else {
                    transition.setFrame(view: self.avatarNode.view, frame: mappedFrame(avatarFrame, containerSize: size, hasRTL: hasRTL))
                }
                self.avatarNode.isHidden = false
            case let .icon(iconName):
                let iconSize = self.icon.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(name: iconName, tintColor: .white)),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let iconFrame = CGRect(
                    origin: CGPoint(
                        x: avatarInset,
                        y: floorToScreenPixels((size.height - iconSize.height) / 2.0)
                    ),
                    size: iconSize
                )
                if let iconView = self.icon.view {
                    if iconView.superview == nil {
                        self.container.addSubview(iconView)
                    }
                    transition.setFrame(view: iconView, frame: mappedFrame(iconFrame, containerSize: size, hasRTL: hasRTL))
                }
                self.avatarNode.isHidden = true
            case let .animation(animationName):
                let iconSize = self.icon.update(
                    transition: transition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: animationName
                        ),
                        placeholderColor: nil,
                        startingPosition: .end,
                        size: CGSize(width: 40.0, height: 40.0),
                        loop: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 40.0, height: 40.0)
                )
                let iconFrame = CGRect(
                    origin: CGPoint(
                        x: avatarInset - 3.0,
                        y: floorToScreenPixels((size.height - iconSize.height) / 2.0)
                    ),
                    size: iconSize
                )
                if let iconView = self.icon.view as? LottieComponent.View {
                    if iconView.superview == nil {
                        self.container.addSubview(iconView)
                        iconView.playOnce()
                    }
                    transition.setFrame(view: iconView, frame: mappedFrame(iconFrame, containerSize: size, hasRTL: hasRTL))
                }
                self.avatarNode.isHidden = true
            }
            
            func mappedFrame(_ frame: CGRect, containerSize: CGSize, hasRTL: Bool) -> CGRect {
                return CGRect(
                    origin: CGPoint(x: hasRTL ? containerSize.width - frame.minX - frame.width : frame.minX, y: frame.origin.y),
                    size: frame.size
                )
            }
            
            let textFrame = CGRect(
                origin: CGPoint(
                    x: avatarInset + avatarSize.width + spacing,
                    y: floorToScreenPixels((size.height - textSize.height) / 2.0)
                ),
                size: textSize
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.container.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: mappedFrame(textFrame, containerSize: size, hasRTL: hasRTL))
            }
            
            transition.setFrame(view: self.container, frame: CGRect(origin: CGPoint(), size: size))

            self.background.update(size: size, cornerRadius: cornerRadius, isDark: true, tintColor: .init(kind: .custom, color: glassColor), transition: transition)
            transition.setFrame(view: self.background, frame: CGRect(origin: CGPoint(), size: size))
            
            if isFirstTime, let availableReactions = component.availableReactions, let textView = self.text.view {
                var reactionItem: ReactionItem?
                for item in availableReactions {
                    if case .builtin(component.text.strippedEmoji) = item.reaction.rawValue {
                        reactionItem = item
                        break
                    }
                }
                
                if let reactionItem {
                    Queue.mainQueue().justDispatch {
                        guard let listView = self.superview else {
                            return
                        }
                        
                        let emojiTargetView = UIView(frame: CGRect(origin: CGPoint(x: textView.frame.width - 32.0, y: -17.0), size: CGSize(width: 44.0, height: 44.0)))
                        emojiTargetView.isUserInteractionEnabled = false
                        textView.addSubview(emojiTargetView)
                        
                        let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: nil, useDirectRendering: false)
                        self.container.addSubview(standaloneReactionAnimation.view)
                        
                        if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                            self.standaloneReactionAnimation = nil
                            standaloneReactionAnimation.view.removeFromSuperview()
                        }
                        self.standaloneReactionAnimation = standaloneReactionAnimation
                        
                        standaloneReactionAnimation.frame = listView.bounds
                        standaloneReactionAnimation.animateReactionSelection(
                            context: component.context,
                            theme: theme,
                            animationCache: component.context.animationCache,
                            reaction: reactionItem,
                            avatarPeers: [],
                            playHaptic: false,
                            isLarge: false,
                            hideCenterAnimation: true,
                            targetView: emojiTargetView,
                            addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
                                guard let self else {
                                    return
                                }
                                
                                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                                    self.standaloneReactionAnimation = nil
                                    standaloneReactionAnimation.view.removeFromSuperview()
                                }
                                self.standaloneReactionAnimation = standaloneReactionAnimation
                                
                                standaloneReactionAnimation.frame = self.bounds
                                listView.addSubview(standaloneReactionAnimation.view)
                            },
                            completion: { [weak standaloneReactionAnimation] in
                                standaloneReactionAnimation?.view.removeFromSuperview()
                            }
                        )
                    }
                }
            }
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
