import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import BundleIconComponent
import GlassBarButtonComponent
import Markdown
import TelegramCore
import AvatarNode
import TelegramStringFormatting
import AnimatedAvatarSetNode
import UndoUI
import PresentationDataUtils
import CheckComponent
import PlainButtonComponent
import EmojiStatusComponent

private final class JoinSubjectSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: JoinSubjectScreenMode
    let dismiss: () -> Void

    init(
        context: AccountContext,
        mode: JoinSubjectScreenMode,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.dismiss = dismiss
    }

    static func ==(lhs: JoinSubjectSheetContentComponent, rhs: JoinSubjectSheetContentComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let closeButton = ComponentView<Empty>()

        private let peerAvatar = ComponentView<Empty>()

        private let callIconBackground = ComponentView<Empty>()
        private let callIcon = ComponentView<Empty>()

        private let title = ComponentView<Empty>()
        private let titleIcon = ComponentView<Empty>()
        private var subtitle: ComponentView<Empty>?
        private var descriptionText: ComponentView<Empty>?
        private var requestDescriptionText: ComponentView<Empty>?

        private var contentSeparator: SimpleLayer?
        private var previewPeersText: ComponentView<Empty>?
        private var previewPeersAvatarsNode: AnimatedAvatarSetNode?
        private var previewPeersAvatarsContext: AnimatedAvatarSetContext?

        private var callMicrophoneOption: ComponentView<Empty>?

        private let actionButton = ComponentView<Empty>()

        private var component: JoinSubjectSheetContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false

        private var callMicrophoneIsEnabled: Bool = true

        private var isJoining: Bool = false
        private var joinDisposable: Disposable?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.joinDisposable?.dispose()
        }

        private func navigateToPeer(peer: EnginePeer) {
            guard let component = self.component else {
                return
            }
            guard let controller = self.environment?.controller() else {
                return
            }
            guard let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            var viewControllers = navigationController.viewControllers
            guard let index = viewControllers.firstIndex(where: { $0 === controller }) else {
                return
            }

            let context = component.context

            if case .user = peer {
                if let peerInfoController = context.sharedContext.makePeerInfoController(
                    context: context,
                    updatedPresentationData: nil,
                    peer: peer,
                    mode: .generic,
                    avatarInitiallyExpanded: false,
                    fromChat: false,
                    requestsContext: nil
                ) {
                    viewControllers.insert(peerInfoController, at: index)
                }
            } else {
                let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                viewControllers.insert(chatController, at: index)
            }
            navigationController.setViewControllers(viewControllers, animated: true)
            component.dismiss()
        }

        private func performJoinAction() {
            if self.isJoining {
                return
            }
            guard let component = self.component else {
                return
            }

            switch component.mode {
            case let .group(group):
                self.joinDisposable?.dispose()

                self.isJoining = true
                if !self.isUpdating {
                    self.state?.updated(transition: .immediate)
                }

                self.joinDisposable = (component.context.engine.peers.joinChatInteractively(with: group.link)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let self, let component = self.component else {
                        return
                    }
                    switch result {
                    case let .joined(peer):
                        if group.isRequest {
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            self.environment?.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationData.strings.MemberRequests_RequestToJoinSent, text: group.isGroup ? presentationData.strings.MemberRequests_RequestToJoinSentDescriptionGroup : presentationData.strings.MemberRequests_RequestToJoinSentDescriptionChannel ), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            component.dismiss()
                        } else {
                            if let peer {
                                self.navigateToPeer(peer: peer)
                            } else {
                                component.dismiss()
                            }
                        }
                    case let .webView(webView):
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        if let navigationController = self.environment?.controller()?.navigationController as? NavigationController, var parentController = navigationController.viewControllers.last as? ViewController {
                            if let controller = navigationController.viewControllers[max(0, navigationController.viewControllers.count - 2)] as? ViewController {
                                parentController = controller
                            }
                            component.context.sharedContext.openJoinChatWebView(context: component.context, parentController: parentController, updatedPresentationData: (initial: presentationData, signal: component.context.sharedContext.presentationData), webView: webView, chatTitle: group.title)
                        }
                        component.dismiss()
                    }
                }, error: { [weak self] error in
                    guard let self, let component = self.component else {
                        return
                    }

                    self.isJoining = false
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }

                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    switch error {
                    case .tooMuchJoined:
                        if let parentNavigationController = self.environment?.controller()?.navigationController as? NavigationController {
                            let context = component.context
                            parentNavigationController.pushViewController(component.context.sharedContext.makeOldChannelsController(context: component.context, updatedPresentationData: nil, intent: .join, completed: { [weak parentNavigationController] value in
                                if value {
                                    parentNavigationController?.pushViewController(JoinSubjectScreen(context: context, mode: .group(group)))
                                }
                            }))
                        } else {
                            self.environment?.controller()?.present(textAlertController(context: component.context, title: nil, text: presentationData.strings.Join_ChannelsTooMuch, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }
                    case .tooMuchUsers:
                        self.environment?.controller()?.present(textAlertController(context: component.context, title: nil, text: presentationData.strings.Conversation_UsersTooMuchError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    case .requestSent:
                        if group.isRequest {
                            self.environment?.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationData.strings.MemberRequests_RequestToJoinSent, text: group.isGroup ? presentationData.strings.MemberRequests_RequestToJoinSentDescriptionGroup : presentationData.strings.MemberRequests_RequestToJoinSentDescriptionChannel ), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }
                    case .flood:
                        self.environment?.controller()?.present(textAlertController(context: component.context, title: nil, text: presentationData.strings.TwoStepAuth_FloodError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    case .generic:
                        break
                    }
                    component.dismiss()
                })
            case let .groupCall(groupCall):
                component.context.joinConferenceCall(call: groupCall.info, isVideo: false, unmuteByDefault: self.callMicrophoneIsEnabled)

                component.dismiss()
            }
        }

        func update(component: JoinSubjectSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme

            // iPhone Duo: one side's safe inset is the side strip; the right margin is its own and centered
            // content is centered in the band between the insets. With equal insets these are the old values.
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let rightSideInset: CGFloat = 16.0 + environment.safeInsets.right
            let bandCenterX: CGFloat = environment.safeInsets.left + (availableSize.width - environment.safeInsets.left - environment.safeInsets.right) / 2.0

            if self.component == nil {
                switch component.mode {
                case .group:
                    break
                case let .groupCall(groupCall):
                    self.callMicrophoneIsEnabled = groupCall.enableMicrophoneByDefault
                }
            }

            self.component = component
            self.state = state
            self.environment = environment

            var contentHeight: CGFloat = 0.0

            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: 16.0 + environment.safeInsets.left, y: 16.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }

            let titleString: String
            let subtitleString: String?
            let descriptionTextString: String?
            let previewPeers: [EnginePeer]
            let totalMemberCount: Int
            let verificationStatus: JoinSubjectScreenMode.Group.VerificationStatus?
            let requestDescriptionString: String?

            switch component.mode {
            case let .group(group):
                contentHeight += 31.0

                titleString = group.title
                if group.isGroup {
                    if !group.members.isEmpty {
                        subtitleString = environment.strings.Invitation_Members(group.memberCount)
                    } else {
                        subtitleString = environment.strings.Conversation_StatusMembers(group.memberCount)
                    }
                } else {
                    subtitleString = environment.strings.Conversation_StatusSubscribers(group.memberCount)
                }
                descriptionTextString = group.about
                verificationStatus = group.verificationStatus
                requestDescriptionString = group.isRequest ? (group.isGroup ? environment.strings.MemberRequests_RequestToJoinDescriptionGroup : environment.strings.MemberRequests_RequestToJoinDescriptionChannel) : nil

                previewPeers = group.members
                totalMemberCount = Int(group.memberCount)

                let avatarPeerIdValue: Int64
                if let nameColor = group.nameColor {
                    avatarPeerIdValue = Int64(nameColor.rawValue % 7)
                } else {
                    avatarPeerIdValue = 1
                }

                let peerAvatarSize = self.peerAvatar.update(
                    transition: transition,
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        peer: EnginePeer.legacyGroup(TelegramGroup(
                            id: EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(avatarPeerIdValue)),
                            title: group.title,
                            photo: group.image.flatMap { image in
                                [image]
                            } ?? [],
                            participantCount: 0,
                            role: .member,
                            membership: .Left,
                            flags: [],
                            defaultBannedRights: nil,
                            migrationReference: nil,
                            creationDate: 0,
                            version: 0
                        ))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 90.0, height: 90.0)
                )
                let peerAvatarFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - peerAvatarSize.width * 0.5), y: contentHeight), size: peerAvatarSize)
                if let peerAvatarView = self.peerAvatar.view {
                    if peerAvatarView.superview == nil {
                        self.addSubview(peerAvatarView)
                    }
                    transition.setFrame(view: peerAvatarView, frame: peerAvatarFrame)
                }
                contentHeight += peerAvatarSize.height + 21.0
            case let .groupCall(groupCall):
                titleString = environment.strings.Invitation_GroupCall
                subtitleString = nil
                descriptionTextString = environment.strings.Invitation_GroupCall_Text
                verificationStatus = nil
                requestDescriptionString = nil

                previewPeers = groupCall.members
                totalMemberCount = groupCall.totalMemberCount

                contentHeight += 31.0

                let callIconBackgroundSize = self.callIconBackground.update(
                    transition: transition,
                    component: AnyComponent(FilledRoundedRectangleComponent(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        cornerRadius: .minEdge,
                        smoothCorners: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 90.0, height: 90.0)
                )
                let callIconBackgroundFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - callIconBackgroundSize.width * 0.5), y: contentHeight), size: callIconBackgroundSize)
                if let callIconBackgroundView = self.callIconBackground.view {
                    if callIconBackgroundView.superview == nil {
                        self.addSubview(callIconBackgroundView)
                    }
                    transition.setFrame(view: callIconBackgroundView, frame: callIconBackgroundFrame)
                }

                let callIconSize = self.callIcon.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Call/CallAcceptButton",
                        tintColor: environment.theme.list.itemCheckColors.foregroundColor,
                        scaleFactor: 1.1
                    )),
                    environment: {},
                    containerSize: callIconBackgroundSize
                )
                let callIconFrame = CGRect(origin: CGPoint(x: callIconBackgroundFrame.minX + floor((callIconBackgroundFrame.width - callIconSize.width) * 0.5), y: callIconBackgroundFrame.minY + floor((callIconBackgroundFrame.height - callIconSize.height) * 0.5)), size: callIconSize)
                if let callIconView = self.callIcon.view {
                    if callIconView.superview == nil {
                        self.addSubview(callIconView)
                    }
                    transition.setFrame(view: callIconView, frame: callIconFrame)
                }
                contentHeight += callIconBackgroundSize.height + 21.0
            }

            let titleIconSpacing: CGFloat = 2.0
            var titleIconSize: CGSize?
            if let verificationStatus {
                let statusContent: EmojiStatusComponent.Content
                switch verificationStatus {
                case .fake:
                    statusContent = .text(color: environment.theme.list.itemDestructiveColor, string: environment.strings.Message_FakeAccount.uppercased())
                case .scam:
                    statusContent = .text(color: environment.theme.list.itemDestructiveColor, string: environment.strings.Message_ScamAccount.uppercased())
                case .verified:
                    statusContent = .verified(fillColor: environment.theme.list.itemCheckColors.fillColor, foregroundColor: environment.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
                }

                titleIconSize = self.titleIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: statusContent,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
            } else {
                self.titleIcon.view?.removeFromSuperview()
            }

            let titleIconWidth: CGFloat
            if let titleIconSize, titleIconSize.width > 0.0 {
                titleIconWidth = titleIconSize.width + titleIconSpacing
            } else {
                titleIconWidth = 0.0
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.bold(24.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - sideInset - rightSideInset - titleIconWidth), height: 100.0)
            )
            let titleTotalWidth = titleSize.width + titleIconWidth
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(bandCenterX - titleTotalWidth * 0.5), y: contentHeight), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let titleIconSize, titleIconSize.width > 0.0, let titleIconView = self.titleIcon.view {
                if titleIconView.superview == nil {
                    self.addSubview(titleIconView)
                }
                transition.setFrame(view: titleIconView, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + titleIconSpacing, y: contentHeight), size: titleIconSize))
            }
            contentHeight += titleSize.height + 4.0

            if let subtitleString {
                let subtitle: ComponentView<Empty>
                if let current = self.subtitle {
                    subtitle = current
                } else {
                    subtitle = ComponentView()
                    self.subtitle = subtitle
                }

                let subtitleSize = subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: subtitleString,
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemSecondaryTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                                linkAttribute: { url in
                                    return ("URL", url)
                                }
                            )
                        ),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 10000.0)
                )
                let subtitleFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - subtitleSize.width * 0.5), y: contentHeight), size: subtitleSize)
                if let subtitleView = subtitle.view {
                    if subtitleView.superview == nil {
                        self.addSubview(subtitleView)
                    }
                    transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                    subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
                }
                contentHeight += subtitleSize.height
            } else if let subtitle = self.subtitle {
                self.subtitle = nil
                subtitle.view?.removeFromSuperview()
            }

            if let descriptionTextString {
                contentHeight += 10.0
                let descriptionText: ComponentView<Empty>
                if let current = self.descriptionText {
                    descriptionText = current
                } else {
                    descriptionText = ComponentView()
                    self.descriptionText = descriptionText
                }

                let descriptionTextSize = descriptionText.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .markdown(
                            text: descriptionTextString,
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                                linkAttribute: { url in
                                    return ("URL", url)
                                }
                            )
                        ),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 10000.0)
                )
                let descriptionTextFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - descriptionTextSize.width * 0.5), y: contentHeight), size: descriptionTextSize)
                if let descriptionTextView = descriptionText.view {
                    if descriptionTextView.superview == nil {
                        self.addSubview(descriptionTextView)
                    }
                    transition.setPosition(view: descriptionTextView, position: descriptionTextFrame.center)
                    descriptionTextView.bounds = CGRect(origin: CGPoint(), size: descriptionTextFrame.size)
                }
                contentHeight += descriptionTextSize.height
            } else if let descriptionText = self.descriptionText {
                self.descriptionText = nil
                descriptionText.view?.removeFromSuperview()
            }

            if !previewPeers.isEmpty {
                contentHeight += 11.0

                let previewPeersString: String
                switch component.mode {
                case .group:
                    if previewPeers.count == 1 {
                        previewPeersString = environment.strings.Invitation_Group_AlreadyJoinedSingle(previewPeers[0].compactDisplayTitle).string
                    } else {
                        let firstPeers = previewPeers.prefix(upTo: 2)
                        let peersTextArray = firstPeers.map { "**\($0.compactDisplayTitle)**" }
                        var peersText = ""
                        if #available(iOS 13.0, *) {
                            let listFormatter = ListFormatter()
                            listFormatter.locale = localeWithStrings(environment.strings)
                            if let value = listFormatter.string(from: peersTextArray) {
                                peersText = value
                            }
                        }
                        if peersText.isEmpty {
                            for i in 0 ..< peersTextArray.count {
                                if i != 0 {
                                    peersText.append(", ")
                                }
                                peersText.append(peersTextArray[i])
                            }
                        }
                        if totalMemberCount > firstPeers.count {
                            previewPeersString = environment.strings.Invitation_Group_AlreadyJoinedMultipleWithCount(Int32(totalMemberCount - firstPeers.count)).replacingOccurrences(of: "{}", with: peersText)
                        } else {
                            previewPeersString = environment.strings.Invitation_Group_AlreadyJoinedMultiple(peersText).string
                        }
                    }
                case .groupCall:
                    if previewPeers.count == 1 {
                        previewPeersString = environment.strings.Invitation_GroupCall_AlreadyJoinedSingle(previewPeers[0].compactDisplayTitle).string
                    } else {
                        let firstPeers = previewPeers.prefix(upTo: 2)
                        let peersTextArray = firstPeers.map { "**\($0.compactDisplayTitle)**" }
                        var peersText = ""
                        if #available(iOS 13.0, *) {
                            let listFormatter = ListFormatter()
                            listFormatter.locale = localeWithStrings(environment.strings)
                            if let value = listFormatter.string(from: peersTextArray) {
                                peersText = value
                            }
                        }
                        if peersText.isEmpty {
                            for i in 0 ..< peersTextArray.count {
                                if i != 0 {
                                    peersText.append(", ")
                                }
                                peersText.append(peersTextArray[i])
                            }
                        }
                        if totalMemberCount > firstPeers.count {
                            previewPeersString = environment.strings.Invitation_GroupCall_AlreadyJoinedMultipleWithCount(Int32(totalMemberCount - firstPeers.count)).replacingOccurrences(of: "{}", with: peersText)
                        } else {
                            previewPeersString = environment.strings.Invitation_GroupCall_AlreadyJoinedMultiple(peersText).string
                        }
                    }
                }

                let contentSeparator: SimpleLayer
                if let current = self.contentSeparator {
                    contentSeparator = current
                } else {
                    contentSeparator = SimpleLayer()
                    self.contentSeparator = contentSeparator
                    self.layer.addSublayer(contentSeparator)
                }

                if themeUpdated {
                    contentSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                }

                contentHeight += 8.0
                transition.setFrame(layer: contentSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset - rightSideInset, height: UIScreenPixel)))
                contentHeight += 10.0

                let previewPeersAvatarsNode: AnimatedAvatarSetNode
                let previewPeersAvatarsContext: AnimatedAvatarSetContext
                if let current = self.previewPeersAvatarsNode, let currentContext = self.previewPeersAvatarsContext {
                    previewPeersAvatarsNode = current
                    previewPeersAvatarsContext = currentContext
                } else {
                    previewPeersAvatarsNode = AnimatedAvatarSetNode()
                    previewPeersAvatarsContext = AnimatedAvatarSetContext()
                    self.previewPeersAvatarsNode = previewPeersAvatarsNode
                    self.previewPeersAvatarsContext = previewPeersAvatarsContext
                }

                let avatarsContent = previewPeersAvatarsContext.update(peers: previewPeers.count <= 3 ? previewPeers : Array(previewPeers.prefix(upTo: 3)), animated: false)
                let avatarsSize = previewPeersAvatarsNode.update(
                    context: component.context,
                    content: avatarsContent,
                    itemSize: CGSize(width: 40.0, height: 40.0),
                    customSpacing: 24.0,
                    font: avatarPlaceholderFont(size: 18.0),
                    animated: false,
                    synchronousLoad: true
                )
                contentHeight += 8.0
                let previewPeersAvatarsFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - avatarsSize.width * 0.5), y: contentHeight), size: avatarsSize)
                if previewPeersAvatarsNode.view.superview == nil {
                    self.addSubview(previewPeersAvatarsNode.view)
                }
                transition.setFrame(view: previewPeersAvatarsNode.view, frame: previewPeersAvatarsFrame)

                contentHeight += 53.0

                let previewPeersText: ComponentView<Empty>
                if let current = self.previewPeersText {
                    previewPeersText = current
                } else {
                    previewPeersText = ComponentView()
                    self.previewPeersText = previewPeersText
                }
                let previewPeersTextSize = previewPeersText.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .markdown(
                        text: previewPeersString,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 10000.0)
                )
                let previewPeersTextFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - previewPeersTextSize.width * 0.5), y: contentHeight), size: previewPeersTextSize)
                if let previewPeersTextView = previewPeersText.view {
                    if previewPeersTextView.superview == nil {
                        self.addSubview(previewPeersTextView)
                    }
                    transition.setFrame(view: previewPeersTextView, frame: previewPeersTextFrame)
                }
                contentHeight += previewPeersTextSize.height + 23.0
            } else {
                contentHeight += 18.0

                if let contentSeparator = self.contentSeparator {
                    self.contentSeparator = nil
                    contentSeparator.removeFromSuperlayer()
                }
                if let previewPeersText = self.previewPeersText {
                    self.previewPeersText = nil
                    previewPeersText.view?.removeFromSuperview()
                }
            }

            if case .groupCall = component.mode {
                let callMicrophoneOption: ComponentView<Empty>
                var callMicrophoneOptionTransition = transition
                if let current = self.callMicrophoneOption {
                    callMicrophoneOption = current
                } else {
                    callMicrophoneOptionTransition = callMicrophoneOptionTransition.withAnimation(.none)
                    callMicrophoneOption = ComponentView()
                    self.callMicrophoneOption = callMicrophoneOption
                }

                let checkTheme = CheckComponent.Theme(
                    backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                    strokeColor: environment.theme.list.itemCheckColors.foregroundColor,
                    borderColor: environment.theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )

                let callMicrophoneOptionSize = callMicrophoneOption.update(
                    transition: callMicrophoneOptionTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                theme: checkTheme,
                                size: CGSize(width: 18.0, height: 18.0),
                                selected: self.callMicrophoneIsEnabled
                            ))),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environment.strings.Invitation_JoinGroupCall_EnableMicrophone, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor))
                            )))
                        ], spacing: 10.0)),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            self.callMicrophoneIsEnabled = !self.callMicrophoneIsEnabled
                            let callMicrophoneIsEnabled = self.callMicrophoneIsEnabled

                            if case let .groupCall(groupCall) = component.mode {
                                let context = component.context
                                let _ = (component.context.engine.calls.getGroupCallPersistentSettings(callId: groupCall.id)
                                |> deliverOnMainQueue).startStandalone(next: { value in
                                    var value: PresentationGroupCallPersistentSettings = value?.get(PresentationGroupCallPersistentSettings.self) ?? PresentationGroupCallPersistentSettings.default
                                    value.isMicrophoneEnabledByDefault = callMicrophoneIsEnabled
                                    if let entry = EngineCodableEntry(value) {
                                        context.engine.calls.setGroupCallPersistentSettings(callId: groupCall.id, value: entry)
                                    }
                                })
                            }

                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        },
                        animateAlpha: false,
                        animateScale: false
                    )),
                    environment: {
                    },
                    containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 1000.0)
                )
                let callMicrophoneOptionFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - callMicrophoneOptionSize.width * 0.5), y: contentHeight), size: callMicrophoneOptionSize)
                if let callMicrophoneOptionView = callMicrophoneOption.view {
                    if callMicrophoneOptionView.superview == nil {
                        self.addSubview(callMicrophoneOptionView)
                    }
                    callMicrophoneOptionTransition.setFrame(view: callMicrophoneOptionView, frame: callMicrophoneOptionFrame)
                }
                contentHeight += callMicrophoneOptionSize.height + 23.0
            } else {
                if let callMicrophoneOption = self.callMicrophoneOption {
                    self.callMicrophoneOption = nil
                    callMicrophoneOption.view?.removeFromSuperview()
                }
            }

            contentHeight += 10.0

            var buttonSideInset: CGFloat = 30.0
            let actionButtonTitle: String
            switch component.mode {
            case let .group(group):
                if group.isRequest {
                    actionButtonTitle = group.isGroup ? environment.strings.MemberRequests_RequestToJoinGroup : environment.strings.MemberRequests_RequestToJoinChannel
                    buttonSideInset = 16.0
                } else {
                    actionButtonTitle = group.isGroup ? environment.strings.Invitation_JoinGroup : environment.strings.Channel_JoinChannel
                }
            case .groupCall:
                actionButtonTitle = environment.strings.Invitation_JoinGroupCall
            }
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: buttonSideInset)
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: actionButtonTitle,
                            badge: 0,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: self.isJoining,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.performJoinAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            )

            let actionButtonFrame = CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }

            contentHeight += actionButtonSize.height

            if let requestDescriptionString {
                let requestDescriptionText: ComponentView<Empty>
                if let current = self.requestDescriptionText {
                    requestDescriptionText = current
                } else {
                    requestDescriptionText = ComponentView()
                    self.requestDescriptionText = requestDescriptionText
                }

                contentHeight += 14.0
                let requestDescriptionTextSize = requestDescriptionText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: requestDescriptionString,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 100.0)
                )
                let requestDescriptionTextFrame = CGRect(origin: CGPoint(x: floor(bandCenterX - requestDescriptionTextSize.width * 0.5), y: contentHeight), size: requestDescriptionTextSize)
                if let requestDescriptionTextView = requestDescriptionText.view {
                    if requestDescriptionTextView.superview == nil {
                        self.addSubview(requestDescriptionTextView)
                    }
                    transition.setFrame(view: requestDescriptionTextView, frame: requestDescriptionTextFrame)
                }
                contentHeight += requestDescriptionTextSize.height

                var bottomInset = environment.safeInsets.bottom
                if bottomInset < 5.0 {
                    bottomInset = 8.0
                }
                contentHeight += 4.0 + bottomInset
            } else if let requestDescriptionText = self.requestDescriptionText {
                self.requestDescriptionText = nil
                requestDescriptionText.view?.removeFromSuperview()

                contentHeight += buttonInsets.bottom
            } else {
                contentHeight += buttonInsets.bottom
            }

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class JoinSubjectScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: JoinSubjectScreenMode

    init(
        context: AccountContext,
        mode: JoinSubjectScreenMode
    ) {
        self.context = context
        self.mode = mode
    }

    static func ==(lhs: JoinSubjectScreenComponent, rhs: JoinSubjectScreenComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()

        private var environment: ViewControllerComponentContainer.Environment?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func dismiss() {
            guard let environment = self.environment else {
                return
            }
            self.sheetAnimateOut.invoke(Action { _ in
                if let controller = environment.controller() {
                    controller.dismiss(completion: nil)
                }
            })
        }

        func update(component: JoinSubjectScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment

            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                isDisplaying: environment.isVisible,
                isCentered: environment.presentsFloatingPanels,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    self?.dismiss()
                }
            )

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(JoinSubjectSheetContentComponent(
                        context: component.context,
                        mode: component.mode,
                        dismiss: { [weak self] in
                            self?.dismiss()
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: sheetSize))
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class JoinSubjectScreen: ViewControllerComponentContainer {
    private let context: AccountContext

    public init(
        context: AccountContext,
        mode: JoinSubjectScreenMode
    ) {
        self.context = context

        super.init(context: context, component: JoinSubjectScreenComponent(
            context: context,
            mode: mode
        ), navigationBarAppearance: .none)

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class AvatarComponent: Component {
    let context: AccountContext
    let peer: EnginePeer
    let size: CGSize?

    init(context: AccountContext, peer: EnginePeer, size: CGSize? = nil) {
        self.context = context
        self.peer = peer
        self.size = size
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    final class View: UIView {
        private var avatarNode: AvatarNode?

        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let size = component.size ?? availableSize

            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(size.width * 0.5)))
                avatarNode.displaysAsynchronously = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            avatarNode.frame = CGRect(origin: CGPoint(), size: size)
            avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true,
                displayDimensions: size
            )
            avatarNode.updateSize(size: size)

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
