import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import AvatarNode
import CheckNode
import AppBundle
import EmojiStatusComponent
import PeerListItemComponent
import MultilineTextComponent

private let shareScreenPeerTitleFont = Font.medium(11.0)
private let shareScreenCommunityShadowImage = UIImage(bundleImageName: "Components/CommunityShadow")?.withRenderingMode(.alwaysTemplate)

final class ShareScreenPeerComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer?
    let title: String
    let avatarPeer: EnginePeer?
    let topicData: MessageHistoryThreadData?
    let communityChats: [EnginePeer]
    let isStory: Bool
    let playsStoryAnimation: Bool
    let selected: Bool
    let online: Bool
    let requirement: ShareScreenMessagingRequirement
    let action: () -> Void

    init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer?, title: String, avatarPeer: EnginePeer? = nil, topicData: MessageHistoryThreadData? = nil, communityChats: [EnginePeer] = [], isStory: Bool = false, playsStoryAnimation: Bool = false, selected: Bool, online: Bool, requirement: ShareScreenMessagingRequirement = ShareScreenMessagingRequirement(), action: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.title = title
        self.avatarPeer = avatarPeer
        self.topicData = topicData
        self.communityChats = communityChats
        self.isStory = isStory
        self.playsStoryAnimation = playsStoryAnimation
        self.selected = selected
        self.online = online
        self.requirement = requirement
        self.action = action
    }

    static func ==(lhs: ShareScreenPeerComponent, rhs: ShareScreenPeerComponent) -> Bool {
        return lhs.context === rhs.context && lhs.theme === rhs.theme && lhs.peer == rhs.peer && lhs.avatarPeer == rhs.avatarPeer && lhs.title == rhs.title && lhs.topicData == rhs.topicData && lhs.communityChats == rhs.communityChats && lhs.isStory == rhs.isStory && lhs.selected == rhs.selected && lhs.online == rhs.online && lhs.requirement == rhs.requirement
    }

    final class View: UIControl {
        private let bubbleRing = UIImageView()
        private var bubbleRingColor: UIColor?
        private let avatar = AvatarNode(font: avatarPlaceholderFont(size: 24.0))
        private let title = ComponentView<Empty>()
        private let topicIcon = ComponentView<Empty>()
        private let chatAvatars = ComponentView<Empty>()
        private let communityShadow = UIImageView()
        private let ring = UIView()
        private let online = UIView()
        private let messagingBadge = ShareScreenMessagingBadge(frame: .zero)
        private var check: CheckNode?
        private var didPlayRepostAnimation = false
        private var component: ShareScreenPeerComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.ring)
            self.addSubview(self.communityShadow)
            self.addSubview(self.avatar.view)
            self.addSubview(self.online)
            self.addSubview(self.messagingBadge)
            self.avatar.view.isUserInteractionEnabled = false
            self.ring.isUserInteractionEnabled = false
            self.online.isUserInteractionEnabled = false
            self.isAccessibilityElement = true
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func pressed() { self.component?.action() }

        func update(component: ShareScreenPeerComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let selectionChanged = self.component?.selected != component.selected
            let animateSelection = self.component != nil && !transition.animation.isImmediate
            self.component = component
            let synchronousLoad = transition.userData(PeerListItemComponent.TransitionHint.self)?.synchronousLoad ?? false
            let diameter = min(60.0, availableSize.width - 10.0)
            let frame = CGRect(x: floor((availableSize.width - diameter) * 0.5), y: 4.0, width: diameter, height: diameter)
            let isCommunity: Bool
            if case .community = component.peer { isCommunity = true } else { isCommunity = false }
            let isMonoforum = component.peer?._asPeer().isMonoForum == true
            let isForum = !isMonoforum && (component.peer?._asPeer().isForumOrMonoForum == true || isCommunity)
            self.communityShadow.isHidden = !isCommunity
            if isCommunity, let image = shareScreenCommunityShadowImage {
                if self.communityShadow.image !== image {
                    self.communityShadow.image = image
                }
                self.communityShadow.tintColor = component.theme.chatList.titleColor.withAlphaComponent(0.9)
                let shadowSize = CGSize(width: floor(diameter * image.size.width / image.size.height * 0.84), height: floor(diameter * 0.97))
                self.communityShadow.bounds = CGRect(origin: .zero, size: shadowSize)
                self.communityShadow.center = CGPoint(x: frame.midX - 12.0 + UIScreenPixel, y: frame.midY)
            }
            self.avatar.setPeer(context: component.context, theme: component.theme, peer: component.avatarPeer ?? component.peer, overrideImage: component.isStory ? .repostIcon : (component.peer?.id == component.context.account.peerId ? .savedMessagesIcon : nil), clipStyle: isMonoforum ? .bubble : (isForum ? .roundedRect : .round), synchronousLoad: synchronousLoad)
            // Match SelectablePeerNode: keep AvatarNode's layout fixed and animate
            // only its scale. Resizing the node while animating its frame shifts
            // its internal image and placeholder relative to the selection ring.
            transition.setPosition(view: self.avatar.view, position: frame.center)
            transition.setBounds(view: self.avatar.view, bounds: CGRect(origin: .zero, size: frame.size))
            self.avatar.updateSize(size: frame.size)
            if component.isStory && !self.didPlayRepostAnimation {
                self.didPlayRepostAnimation = true
                self.avatar.playRepostAnimation(animated: component.playsStoryAnimation)
            }
            transition.setFrame(view: self.ring, frame: frame)
            let selectedAvatarScale: CGFloat = 0.866666
            // Use the scaled avatar's radius plus the inset to the ring's outer
            // edge, so the two rounded rectangles have concentric corners.
            let selectedAvatarInset = diameter * (1.0 - selectedAvatarScale) * 0.5
            self.ring.layer.cornerRadius = isForum ? floor(diameter * 0.25) * selectedAvatarScale + selectedAvatarInset : diameter * 0.5
            self.ring.layer.borderWidth = isMonoforum ? 0.0 : 2.0
            if self.bubbleRing.superview == nil { self.ring.addSubview(self.bubbleRing) }
            self.bubbleRing.isHidden = !isMonoforum
            if isMonoforum {
                let color = component.theme.list.itemAccentColor
                if self.bubbleRing.image?.size != frame.size || self.bubbleRingColor != color {
                    self.bubbleRingColor = color
                    self.bubbleRing.image = generateImage(frame.size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: .zero, size: size))
                        AvatarNode.addAvatarBubblePath(context: context, rect: CGRect(origin: .zero, size: size).insetBy(dx: 1.0, dy: 1.0))
                        context.setStrokeColor(color.cgColor)
                        context.setLineWidth(2.0)
                        context.strokePath()
                    })
                }
                self.bubbleRing.frame = CGRect(origin: .zero, size: frame.size)
            }
            self.ring.layer.borderColor = component.theme.list.itemAccentColor.cgColor
            if selectionChanged {
                let scaleTransition: ComponentTransition = animateSelection ? .spring(duration: component.selected ? 0.2 : 0.4) : .immediate
                let endRasterization: ((Bool) -> Void)? = scaleTransition.animation.isImmediate ? nil : self.layer.beginRasterizedAnimation()
                scaleTransition.setScale(layer: self.avatar.layer, scale: component.selected ? selectedAvatarScale : 1.0, beginWithCurrentState: true, completion: endRasterization)
                let alphaTransition: ComponentTransition = animateSelection ? .easeInOut(duration: component.selected ? 0.15 : 0.28) : .immediate
                alphaTransition.setAlpha(view: self.ring, alpha: component.selected ? 1.0 : 0.0)
            }
            let topicData = component.selected ? component.topicData : nil
            let title = topicData?.info.title ?? component.title
            var iconSize = CGSize.zero
            if let topicData {
                let content: EmojiStatusComponent.Content
                if let fileId = topicData.info.icon {
                    content = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 18.0, height: 18.0), placeholderColor: component.theme.actionSheet.disabledActionTextColor, themeColor: component.theme.actionSheet.primaryTextColor, loopMode: .count(0))
                } else {
                    content = .topic(title: String(topicData.info.title.prefix(1)), color: topicData.info.iconColor, size: CGSize(width: 32.0, height: 32.0))
                }
                iconSize = self.topicIcon.update(transition: transition, component: AnyComponent(EmojiStatusComponent(context: component.context, animationCache: component.context.animationCache, animationRenderer: component.context.animationRenderer, content: content, isVisibleForAnimations: true, action: nil)), environment: {}, containerSize: CGSize(width: 18.0, height: 18.0))
                if let view = self.topicIcon.view {
                    if view.superview == nil { self.addSubview(view) }
                    view.isUserInteractionEnabled = false
                }
            } else {
                self.topicIcon.view?.removeFromSuperview()
            }
            if !component.communityChats.isEmpty {
                let titleWidth = ceil((title as NSString).size(withAttributes: [.font: shareScreenPeerTitleFont]).width)
                let avatarSpacing: CGFloat = component.communityChats.count > 1 ? min(10.0, max(4.0, (availableSize.width - titleWidth - 2.0 - 16.0) / CGFloat(component.communityChats.count - 1))) : 10.0
                iconSize = self.chatAvatars.update(transition: transition, component: AnyComponent(MergedAvatarsComponent(
                    context: component.context, peers: component.communityChats,
                    imageSize: 16.0, imageSpacing: avatarSpacing, borderWidth: 1.0, avatarFontSize: 8.0, synchronousLoad: synchronousLoad
                )), environment: {}, containerSize: CGSize(width: availableSize.width, height: 16.0))
                if let view = self.chatAvatars.view {
                    if view.superview == nil { self.addSubview(view) }
                    view.isUserInteractionEnabled = false
                }
            } else {
                self.chatAvatars.view?.removeFromSuperview()
            }
            let hasIcon = topicData != nil || !component.communityChats.isEmpty
            let titleColor = component.selected ? component.theme.list.itemAccentColor : component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(component.requirement.requiresPremium ? 0.4 : 1.0)
            let iconWidth = hasIcon ? iconSize.width + 2.0 : 0.0
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: title, font: shareScreenPeerTitleFont, textColor: titleColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: hasIcon ? 1 : 2
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, availableSize.width - iconWidth), height: 30.0)
            )
            let left = floorToScreenPixels((availableSize.width - titleSize.width - iconWidth) * 0.5)
            let titleFrame = CGRect(x: left + iconWidth, y: frame.maxY + 4.0, width: titleSize.width, height: titleSize.height)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.insertSubview(titleView, aboveSubview: self.avatar.view)
                }
                titleView.frame = titleFrame
            }
            if hasIcon, let view = component.communityChats.isEmpty ? self.topicIcon.view : self.chatAvatars.view {
                view.frame = CGRect(x: left, y: titleFrame.minY + floorToScreenPixels((shareScreenPeerTitleFont.lineHeight - iconSize.height) * 0.5), width: iconSize.width, height: iconSize.height)
            }
            let check: CheckNode
            if let current = self.check { check = current } else {
                check = CheckNode(theme: CheckNodeTheme(backgroundColor: component.theme.list.itemAccentColor, strokeColor: .white, borderColor: component.theme.list.plainBackgroundColor, overlayBorder: false, hasInset: false, hasShadow: false))
                self.check = check
                check.view.isUserInteractionEnabled = false
                self.addSubview(check.view)
            }
            check.theme = CheckNodeTheme(backgroundColor: component.theme.list.itemAccentColor, strokeColor: component.theme.list.itemCheckColors.foregroundColor, borderColor: component.theme.list.modalPlainBackgroundColor, overlayBorder: true, hasInset: false, hasShadow: false, filledBorder: true, borderWidth: 4.0 / 3.0, checkmarkLineWidth: 1.5, checkmarkStyle: .narrow)
            check.bounds = CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
            check.position = CGPoint(x: frame.maxX - 9.0, y: frame.maxY - 9.0)
            if selectionChanged {
                check.setSelected(component.selected, animated: animateSelection)
                let alphaTransition: ComponentTransition = animateSelection ? .easeInOut(duration: component.selected ? 0.15 : 0.28) : .immediate
                alphaTransition.setAlpha(view: check.view, alpha: component.selected ? 1.0 : 0.0)
            }
            self.online.backgroundColor = component.theme.chatList.onlineDotColor
            self.online.layer.borderWidth = 2.0
            self.online.layer.borderColor = component.theme.list.modalPlainBackgroundColor.cgColor
            self.online.layer.cornerRadius = 8.0
            self.online.frame = CGRect(x: frame.maxX - 14.0, y: frame.maxY - 14.0, width: 16.0, height: 16.0)
            self.online.isHidden = !component.online || component.selected || component.requirement.requiresPremium || component.requirement.stars != nil
            self.messagingBadge.frame = CGRect(origin: .zero, size: availableSize)
            self.messagingBadge.update(requirement: component.requirement, theme: component.theme, avatarFrame: frame, selected: component.selected, transition: transition)
            self.accessibilityLabel = title
            self.accessibilityTraits = component.selected ? [.button, .selected] : .button
            return CGSize(width: availableSize.width, height: 100.0)
        }
    }
    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
