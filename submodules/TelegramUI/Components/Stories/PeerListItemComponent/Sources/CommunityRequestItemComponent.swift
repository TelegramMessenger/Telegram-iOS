import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import MultilineTextComponent
import AvatarNode
import TelegramPresentationData
import ButtonComponent
import ListSectionComponent
import BundleIconComponent

private let avatarFont = avatarPlaceholderFont(size: 22.0)
private let requesterAvatarFont = avatarPlaceholderFont(size: 8.0)

private func generateDisclosureImage() -> UIImage? {
    return generateImage(CGSize(width: 7.0, height: 12.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)

        let lineWidth: CGFloat = 2.0
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        context.move(to: CGPoint(x: lineWidth * 0.5, y: lineWidth * 0.5))
        context.addLine(to: CGPoint(x: size.width - lineWidth * 0.5, y: size.height * 0.5))
        context.addLine(to: CGPoint(x: lineWidth * 0.5, y: size.height - lineWidth * 0.5))
        context.strokePath()
    })?.withRenderingMode(.alwaysTemplate)
}

private let disclosureImage: UIImage? = generateDisclosureImage()

public final class CommunityRequestItemComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let chatPeer: EnginePeer
    public let requestedByPeer: EnginePeer?
    public let memberCount: Int32?
    public let isPrivate: Bool
    public let isVisible: Bool
    public let isEnabled: Bool
    public let declineDisplaysProgress: Bool
    public let addDisplaysProgress: Bool
    public let hasNext: Bool
    public let open: (EnginePeer) -> Void
    public let add: (EnginePeer) -> Void
    public let decline: (EnginePeer) -> Void

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        chatPeer: EnginePeer,
        requestedByPeer: EnginePeer?,
        memberCount: Int32?,
        isPrivate: Bool,
        isVisible: Bool,
        isEnabled: Bool,
        declineDisplaysProgress: Bool,
        addDisplaysProgress: Bool,
        hasNext: Bool,
        open: @escaping (EnginePeer) -> Void,
        add: @escaping (EnginePeer) -> Void,
        decline: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.chatPeer = chatPeer
        self.requestedByPeer = requestedByPeer
        self.memberCount = memberCount
        self.isPrivate = isPrivate
        self.isVisible = isVisible
        self.isEnabled = isEnabled
        self.declineDisplaysProgress = declineDisplaysProgress
        self.addDisplaysProgress = addDisplaysProgress
        self.hasNext = hasNext
        self.open = open
        self.add = add
        self.decline = decline
    }

    public static func ==(lhs: CommunityRequestItemComponent, rhs: CommunityRequestItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.chatPeer != rhs.chatPeer {
            return false
        }
        if lhs.requestedByPeer != rhs.requestedByPeer {
            return false
        }
        if lhs.memberCount != rhs.memberCount {
            return false
        }
        if lhs.isPrivate != rhs.isPrivate {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.declineDisplaysProgress != rhs.declineDisplaysProgress {
            return false
        }
        if lhs.addDisplaysProgress != rhs.addDisplaysProgress {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }

    public final class View: UIView, ListSectionComponent.ChildView {
        private let containerButton: HighlightTrackingButton
        private var avatarNode: AvatarNode?
        private var requesterAvatarNode: AvatarNode?
        private let requesterText = ComponentView<Empty>()
        private let titleText = ComponentView<Empty>()
        private var memberText: ComponentView<Empty>?
        private var privateText: ComponentView<Empty>?
        private let declineButton = ComponentView<Empty>()
        private let addButton = ComponentView<Empty>()
        private let rightIconView: UIImageView

        private var component: CommunityRequestItemComponent?

        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var enumerateSiblings: (((UIView) -> Void) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0

        override init(frame: CGRect) {
            self.containerButton = HighlightTrackingButton()
            self.containerButton.isExclusiveTouch = true

            self.rightIconView = UIImageView(image: disclosureImage)

            super.init(frame: frame)

            self.addSubview(self.containerButton)
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                self?.customUpdateIsHighlighted?(highlighted)
            }

            self.rightIconView.isUserInteractionEnabled = false
            self.containerButton.addSubview(self.rightIconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            guard let component = self.component, component.isEnabled else {
                return
            }
            component.open(component.chatPeer)
        }

        private func requesterAttributedText(component: CommunityRequestItemComponent) -> NSAttributedString {
            let requesterName: String
            if let requestedByPeer = component.requestedByPeer, !requestedByPeer.compactDisplayTitle.isEmpty {
                requesterName = requestedByPeer.compactDisplayTitle
            } else {
                requesterName = component.strings.Community_Request_UnknownRequester
            }

            let text: PresentationStrings.FormattedString
            if case let .channel(channel) = component.chatPeer, case .broadcast = channel.info {
                text = component.strings.Community_Request_RequesterSuggestsChannel(requesterName)
            } else if case .user = component.chatPeer {
                text = component.strings.Community_Request_RequesterSuggestsBot(requesterName)
            } else {
                text = component.strings.Community_Request_RequesterSuggestsGroup(requesterName)
            }

            let result = NSMutableAttributedString(
                string: text.string,
                font: Font.regular(15.0),
                textColor: component.theme.list.itemSecondaryTextColor
            )
            for range in text.ranges where range.index == 0 {
                result.addAttribute(
                    .foregroundColor,
                    value: component.theme.list.itemAccentColor,
                    range: range.range
                )
            }
            return result
        }

        func update(component: CommunityRequestItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            let themeUpdated = previousComponent?.theme !== component.theme
            self.component = component

            self.containerButton.isEnabled = component.isEnabled
            self.containerButton.alpha = component.isEnabled ? 1.0 : 0.55
            self.rightIconView.tintColor = component.theme.list.disclosureArrowColor

            let sideInset: CGFloat = 10.0
            let topInset: CGFloat = 10.0
            let bottomInset: CGFloat = 10.0
            let avatarSize: CGFloat = 40.0
            let avatarSpacing: CGFloat = 12.0
            let chevronInset: CGFloat = 16.0
            let chevronReservedWidth: CGFloat = 24.0
            let textLeft = sideInset + avatarSize + avatarSpacing
            let textRightInset = chevronInset + chevronReservedWidth
            let textWidth = max(1.0, availableSize.width - textLeft - textRightInset)

            self.separatorInset = textLeft

            var y = topInset

            let requesterSize = self.requesterText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(self.requesterAttributedText(component: component)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )
            y += requesterSize.height + 3.0

            let titleSize = self.titleText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.chatPeer.compactDisplayTitle,
                        font: Font.semibold(16.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )
            y += titleSize.height

            var memberSize: CGSize?
            if let memberCount = component.memberCount {
                let memberCountText = component.strings.Conversation_StatusMembers(memberCount)

                let memberText: ComponentView<Empty>
                if let current = self.memberText {
                    memberText = current
                } else {
                    memberText = ComponentView<Empty>()
                    self.memberText = memberText
                }
                memberSize = memberText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                BundleIconComponent(name: "Chat List/MembersIcon", tintColor: component.theme.list.itemSecondaryTextColor)
                            )),
                            AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: memberCountText,
                                        font: Font.regular(15.0),
                                        textColor: component.theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                )
                            ))
                        ], spacing: 3.0)
                    ),
                    environment: {},
                    containerSize: CGSize(width: textWidth, height: 100.0)
                )
                y += 2.0 + (memberSize?.height ?? 0.0)
            } else if let memberText = self.memberText {
                self.memberText = nil
                memberText.view?.removeFromSuperview()
            }

            var privateSize: CGSize?
            if !component.isVisible {
                let privateText: ComponentView<Empty>
                if let current = self.privateText {
                    privateText = current
                } else {
                    privateText = ComponentView<Empty>()
                    self.privateText = privateText
                }
                privateSize = privateText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                BundleIconComponent(name: "Chat List/HiddenIcon", tintColor: component.theme.list.itemSecondaryTextColor)
                            )),
                            AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: component.strings.Community_Request_PrivateStatus,
                                        font: Font.regular(15.0),
                                        textColor: component.theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                )
                            ))
                        ], spacing: 3.0)
                    ),
                    environment: {},
                    containerSize: CGSize(width: textWidth, height: 100.0)
                )
                y += 2.0 + (privateSize?.height ?? 0.0)
            } else if let privateText = self.privateText {
                self.privateText = nil
                privateText.view?.removeFromSuperview()
            }

            let buttonSpacing: CGFloat = 8.0
            let buttonHeight: CGFloat = 32.0
            let buttonsTopSpacing: CGFloat = 10.0
            let buttonsWidth = max(1.0, availableSize.width - textLeft - sideInset)
            let buttonWidth = floorToScreenPixels((buttonsWidth - buttonSpacing) / 2.0)
            let buttonsY = y + buttonsTopSpacing
            let height = max(topInset + avatarSize + bottomInset, buttonsY + buttonHeight + bottomInset)

            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height)))

            let avatarFrame = CGRect(
                origin: CGPoint(x: sideInset, y: topInset - 1.0),
                size: CGSize(width: avatarSize, height: avatarSize)
            )
            let requesterAvatarSize: CGFloat = 18.0
            let requesterAvatarFrame = CGRect(
                origin: CGPoint(
                    x: avatarFrame.maxX - requesterAvatarSize + 7.0,
                    y: avatarFrame.minY + 1.0
                ),
                size: CGSize(width: requesterAvatarSize, height: requesterAvatarSize)
            )
            let avatarCutoutRect: CGRect?
            if component.requestedByPeer != nil {
                avatarCutoutRect = CGRect(
                    origin: CGPoint(
                        x: requesterAvatarFrame.minX - avatarFrame.minX,
                        y: avatarFrame.height - (requesterAvatarFrame.maxY - avatarFrame.minY)
                    ),
                    size: requesterAvatarFrame.size
                ).insetBy(dx: -2.0 + UIScreenPixel, dy: -2.0 + UIScreenPixel)
            } else {
                avatarCutoutRect = nil
            }
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarFont)
                avatarNode.isLayerBacked = false
                avatarNode.isUserInteractionEnabled = false
                self.avatarNode = avatarNode
                self.containerButton.layer.insertSublayer(avatarNode.layer, at: 0)
            }

            if avatarNode.bounds.isEmpty {
                avatarNode.frame = avatarFrame
            } else {
                transition.setFrame(layer: avatarNode.layer, frame: avatarFrame)
            }

            let clipStyle: AvatarNodeClipStyle
            if case let .channel(channel) = component.chatPeer, channel.isForumOrMonoForum {
                clipStyle = .roundedRect
            } else {
                clipStyle = .round
            }
            avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.chatPeer,
                clipStyle: clipStyle,
                synchronousLoad: false,
                displayDimensions: CGSize(width: avatarSize, height: avatarSize),
                cutoutRect: avatarCutoutRect
            )

            if let requestedByPeer = component.requestedByPeer {
                let requesterAvatarNode: AvatarNode
                if let current = self.requesterAvatarNode {
                    requesterAvatarNode = current
                } else {
                    requesterAvatarNode = AvatarNode(font: requesterAvatarFont)
                    requesterAvatarNode.isLayerBacked = false
                    requesterAvatarNode.isUserInteractionEnabled = false
                    self.requesterAvatarNode = requesterAvatarNode
                    self.containerButton.layer.addSublayer(requesterAvatarNode.layer)
                }
                if requesterAvatarNode.bounds.isEmpty {
                    requesterAvatarNode.frame = requesterAvatarFrame
                } else {
                    transition.setFrame(layer: requesterAvatarNode.layer, frame: requesterAvatarFrame)
                }
                requesterAvatarNode.setPeer(
                    context: component.context,
                    theme: component.theme,
                    peer: requestedByPeer,
                    clipStyle: .round,
                    synchronousLoad: false,
                    displayDimensions: CGSize(width: requesterAvatarSize, height: requesterAvatarSize)
                )
            } else if let requesterAvatarNode = self.requesterAvatarNode {
                self.requesterAvatarNode = nil
                requesterAvatarNode.layer.removeFromSuperlayer()
            }

            if let requesterView = self.requesterText.view {
                if requesterView.superview == nil {
                    requesterView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(requesterView)
                }
                transition.setFrame(view: requesterView, frame: CGRect(origin: CGPoint(x: textLeft, y: topInset), size: requesterSize))
            }

            if let titleView = self.titleText.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: textLeft, y: topInset + requesterSize.height + 3.0), size: titleSize))
            }

            var nextTextY = topInset + requesterSize.height + 3.0 + titleSize.height
            if let memberView = self.memberText?.view, let memberSize {
                var transition = transition
                if memberView.superview == nil {
                    transition = .immediate
                    memberView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(memberView)
                }
                nextTextY += 3.0
                transition.setFrame(view: memberView, frame: CGRect(origin: CGPoint(x: textLeft, y: nextTextY), size: memberSize))
                nextTextY += memberSize.height
            }
            if let privateView = self.privateText?.view, let privateSize {
                var transition = transition
                if privateView.superview == nil {
                    transition = .immediate
                    privateView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(privateView)
                }
                nextTextY += 3.0
                transition.setFrame(view: privateView, frame: CGRect(origin: CGPoint(x: textLeft, y: nextTextY), size: privateSize))
            }

            let buttonsEnabled = component.isEnabled && !component.declineDisplaysProgress && !component.addDisplaysProgress

            let declineButtonSize = self.declineButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.08),
                        foreground: component.theme.list.itemPrimaryTextColor,
                        pressedColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.14),
                        cornerRadius: 16.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(ButtonTextContentComponent(
                            text: component.strings.Community_Request_Decline,
                            badge: 0,
                            textColor: component.theme.list.itemPrimaryTextColor,
                            fontSize: 15.0,
                            badgeBackground: component.theme.list.itemPrimaryTextColor,
                            badgeForeground: component.theme.list.itemBlocksBackgroundColor
                        ))
                    ),
                    fitToContentWidth: true,
                    isEnabled: buttonsEnabled,
                    displaysProgress: component.declineDisplaysProgress,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.decline(component.chatPeer)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )

            let addButtonSize = self.addButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 16.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(ButtonTextContentComponent(
                            text: component.strings.Community_Request_Add,
                            badge: 0,
                            textColor: component.theme.list.itemCheckColors.foregroundColor,
                            fontSize: 15.0,
                            badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: component.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    fitToContentWidth: true,
                    isEnabled: buttonsEnabled,
                    displaysProgress: component.addDisplaysProgress,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.add(component.chatPeer)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )

            if let declineButtonView = self.declineButton.view {
                if declineButtonView.superview == nil {
                    self.containerButton.addSubview(declineButtonView)
                }
                transition.setFrame(view: declineButtonView, frame: CGRect(
                    origin: CGPoint(x: textLeft, y: buttonsY),
                    size: declineButtonSize
                ))
            }
            if let addButtonView = self.addButton.view {
                if addButtonView.superview == nil {
                    self.containerButton.addSubview(addButtonView)
                }
                transition.setFrame(view: addButtonView, frame: CGRect(
                    origin: CGPoint(x: textLeft + declineButtonSize.width + buttonSpacing, y: buttonsY),
                    size: addButtonSize
                ))
            }

            if themeUpdated || self.rightIconView.image == nil {
                self.rightIconView.image = disclosureImage
            }
            if let image = self.rightIconView.image {
                transition.setFrame(view: self.rightIconView, frame: CGRect(
                    origin: CGPoint(
                        x: availableSize.width - chevronInset - image.size.width,
                        y: floorToScreenPixels((height - image.size.height) / 2.0)
                    ),
                    size: image.size
                ))
            }

            return CGSize(width: availableSize.width, height: height)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
