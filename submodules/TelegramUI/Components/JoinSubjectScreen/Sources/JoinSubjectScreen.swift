import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import BundleIconComponent
import Markdown
import Postbox
import TelegramCore
import AvatarNode
import TelegramStringFormatting
import AnimatedAvatarSetNode
import UndoUI
import PresentationDataUtils
import CheckComponent
import PlainButtonComponent

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
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationBarSeparator: SimpleLayer
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let closeButton = ComponentView<Empty>()
        
        private let peerAvatar = ComponentView<Empty>()
        
        private let callIconBackground = ComponentView<Empty>()
        private let callIcon = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private var subtitle: ComponentView<Empty>?
        private var descriptionText: ComponentView<Empty>?

        private var contentSeparator: SimpleLayer?
        private var previewPeersText: ComponentView<Empty>?
        private var previewPeersAvatarsNode: AnimatedAvatarSetNode?
        private var previewPeersAvatarsContext: AnimatedAvatarSetContext?
        
        private var callMicrophoneOption: ComponentView<Empty>?
        
        private let titleTransformContainer: UIView
        private let bottomPanelContainer: UIView
        private let actionButton = ComponentView<Empty>()
        private let bottomText = ComponentView<Empty>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var isFirstTimeApplyingModalFactor: Bool = true
        private var ignoreScrolling: Bool = false
        
        private var component: JoinSubjectScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        private var itemLayout: ItemLayout?
        private var topOffsetDistance: CGFloat?
        
        private var cachedCloseImage: UIImage?
        
        private var callMicrophoneIsEnabled: Bool = true

        private var isJoining: Bool = false
        private var joinDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationBarSeparator = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.titleTransformContainer = UIView()
            self.titleTransformContainer.isUserInteractionEnabled = false
            
            self.bottomPanelContainer = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.addSubview(self.navigationBarContainer)
            self.addSubview(self.titleTransformContainer)
            self.addSubview(self.bottomPanelContainer)
            
            self.navigationBarContainer.addSubview(self.navigationBackgroundView)
            self.navigationBarContainer.layer.addSublayer(self.navigationBarSeparator)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.joinDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            
            let titleCenterY: CGFloat = -itemLayout.topInset + itemLayout.containerInset + 54.0 * 0.5
            
            let titleTransformDistance: CGFloat = 20.0
            let titleY: CGFloat = max(titleCenterY, self.titleTransformContainer.center.y + topOffset + itemLayout.containerInset)
            
            transition.setSublayerTransform(view: self.titleTransformContainer, transform: CATransform3DMakeTranslation(0.0, titleY - self.titleTransformContainer.center.y, 0.0))
            
            let titleYDistance: CGFloat = titleY - titleCenterY
            let titleTransformFraction: CGFloat = 1.0 - max(0.0, min(1.0, titleYDistance / titleTransformDistance))
            let titleMinScale: CGFloat = 17.0 / 24.0
            let titleScale: CGFloat = 1.0 * (1.0 - titleTransformFraction) + titleMinScale * titleTransformFraction
            if let titleView = self.title.view {
                transition.setScale(view: titleView, scale: titleScale)
            }
            
            let navigationAlpha: CGFloat = titleTransformFraction
            transition.setAlpha(view: self.navigationBackgroundView, alpha: navigationAlpha)
            transition.setAlpha(layer: self.navigationBarSeparator, alpha: navigationAlpha)
            
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            var modalOverlayTransition = transition
            if self.isFirstTimeApplyingModalFactor {
                self.isFirstTimeApplyingModalFactor = false
                modalOverlayTransition = .spring(duration: 0.5)
            }
            if self.isUpdating {
                DispatchQueue.main.async { [weak controller] in
                    guard let controller else {
                        return
                    }
                    controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalOverlayTransition.containedViewLayoutTransition)
                }
            } else {
                controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalOverlayTransition.containedViewLayoutTransition)
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.titleTransformContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomPanelContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.titleTransformContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomPanelContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            
            if let environment = self.environment, let controller = environment.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
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
                    peer: peer._asPeer(),
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
            controller.dismiss()
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
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let component = self.component else {
                        return
                    }
                    if group.isRequest {
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        self.environment?.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationData.strings.MemberRequests_RequestToJoinSent, text: group.isGroup ? presentationData.strings.MemberRequests_RequestToJoinSentDescriptionGroup : presentationData.strings.MemberRequests_RequestToJoinSentDescriptionChannel ), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    } else {
                        if let peer {
                            self.navigateToPeer(peer: peer)
                        }
                    }
                    self.environment?.controller()?.dismiss()
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
                    self.environment?.controller()?.dismiss()
                })
            case let .groupCall(groupCall):
                component.context.joinConferenceCall(call: groupCall.info, isVideo: false, unmuteByDefault: self.callMicrophoneIsEnabled)
                
                self.environment?.controller()?.dismiss()
            }
        }
        
        func update(component: JoinSubjectScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
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
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor.cgColor
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationBarSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let closeImage: UIImage
            if let image = self.cachedCloseImage, !themeUpdated {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05), foregroundColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.4))!
                self.cachedCloseImage = closeImage
            }
            
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(image: closeImage, size: closeImage.size)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 62.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - closeButtonSize.width, y: 0.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            let clippingY: CGFloat

            let titleString: String
            let subtitleString: String?
            let descriptionTextString: String?
            let previewPeers: [EnginePeer]
            let totalMemberCount: Int
            
            switch component.mode {
            case let .group(group):
                contentHeight += 31.0

                titleString = group.title
                subtitleString = group.isPublic ? environment.strings.Invitation_PublicGroup : environment.strings.Invitation_PrivateGroup
                descriptionTextString = group.about

                previewPeers = group.members
                totalMemberCount = Int(group.memberCount)

                let peerAvatarSize = self.peerAvatar.update(
                    transition: transition,
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        peer: EnginePeer.legacyGroup(TelegramGroup(
                            id: EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(1)),
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
                let peerAvatarFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - peerAvatarSize.width) * 0.5), y: contentHeight), size: peerAvatarSize)
                if let peerAvatarView = self.peerAvatar.view {
                    if peerAvatarView.superview == nil {
                        self.scrollContentView.addSubview(peerAvatarView)
                    }
                    transition.setFrame(view: peerAvatarView, frame: peerAvatarFrame)
                }
                contentHeight += peerAvatarSize.height + 21.0
            case let .groupCall(groupCall):
                titleString = environment.strings.Invitation_GroupCall
                subtitleString = nil
                descriptionTextString = environment.strings.Invitation_GroupCall_Text

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
                let callIconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - callIconBackgroundSize.width) * 0.5), y: contentHeight), size: callIconBackgroundSize)
                if let callIconBackgroundView = self.callIconBackground.view {
                    if callIconBackgroundView.superview == nil {
                        self.scrollContentView.addSubview(callIconBackgroundView)
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
                        self.scrollContentView.addSubview(callIconView)
                    }
                    transition.setFrame(view: callIconView, frame: callIconFrame)
                }
                contentHeight += callIconBackgroundSize.height + 21.0
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.bold(24.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.titleTransformContainer.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: self.titleTransformContainer, position: titleFrame.center)
            }
            contentHeight += titleSize.height + 4.0
            
            let navigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 54.0))
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationBackgroundFrame)
            self.navigationBackgroundView.update(size: navigationBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.navigationBarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
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
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
                if let subtitleView = subtitle.view {
                    if subtitleView.superview == nil {
                        self.scrollContentView.addSubview(subtitleView)
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
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
                if let descriptionTextView = descriptionText.view {
                    if descriptionTextView.superview == nil {
                        self.scrollContentView.addSubview(descriptionTextView)
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
                    self.scrollContentView.layer.addSublayer(contentSeparator)
                }

                if themeUpdated {
                    contentSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                }
                
                contentHeight += 8.0
                transition.setFrame(layer: contentSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
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
                let previewPeersAvatarsFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - avatarsSize.width) * 0.5), y: contentHeight), size: avatarsSize)
                if previewPeersAvatarsNode.view.superview == nil {
                    self.scrollContentView.addSubview(previewPeersAvatarsNode.view)
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
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let previewPeersTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - previewPeersTextSize.width) * 0.5), y: contentHeight), size: previewPeersTextSize)
                if let previewPeersTextView = previewPeersText.view {
                    if previewPeersTextView.superview == nil {
                        self.scrollContentView.addSubview(previewPeersTextView)
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
                                    if let entry = CodableEntry(value) {
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
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let callMicrophoneOptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - callMicrophoneOptionSize.width) * 0.5), y: contentHeight), size: callMicrophoneOptionSize)
                if let callMicrophoneOptionView = callMicrophoneOption.view {
                    if callMicrophoneOptionView.superview == nil {
                        self.scrollContentView.addSubview(callMicrophoneOptionView)
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
            
            let actionButtonTitle: String
            switch component.mode {
            case .group:
                actionButtonTitle = environment.strings.Invitation_JoinGroup
            case .groupCall:
                actionButtonTitle = environment.strings.Invitation_JoinGroupCall
            }
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
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
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            
            let bottomPanelHeight = 10.0 + environment.safeInsets.bottom + actionButtonSize.height
            
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight), size: CGSize(width: availableSize.width, height: bottomPanelHeight))
            transition.setFrame(view: self.bottomPanelContainer, frame: bottomPanelFrame)
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.bottomPanelContainer.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            contentHeight += bottomPanelHeight
            
            clippingY = bottomPanelFrame.minY - 8.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - contentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset), size: CGSize(width: availableSize.width - sideInset * 2.0, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            } else {
                if !previousBounds.isEmpty, !transition.animation.isImmediate {
                    let bounds = self.scrollView.bounds
                    if bounds.maxY != previousBounds.maxY {
                        let offsetY = previousBounds.maxY - bounds.maxY
                        transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                    }
                }
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
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
    private var isDismissed: Bool = false
    
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
        
        if let componentView = self.node.hostView.componentView as? JoinSubjectScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? JoinSubjectScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
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

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.beginPath()
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
