import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import AvatarComponent
import MultilineTextComponent
import ButtonComponent
import GlassBarButtonComponent
import BundleIconComponent
import ListActionItemComponent
import ListSectionComponent
import AlertComponent
import PresentationDataUtils
import ItemListUI

private enum CommunityAddVisibility: Equatable {
    case visible
    case hidden

    var isVisible: Bool {
        switch self {
        case .visible:
            return true
        case .hidden:
            return false
        }
    }
}

private enum CommunityAddScreenSubject: Equatable {
    case existing(communityId: EnginePeer.Id)
    case draft(initialVisibility: Bool)
}

private func communityAddMemberCount(cachedData: EngineCachedPeerData?) -> Int32? {
    if let cachedData = cachedData as? CachedChannelData {
        return cachedData.participantsSummary.memberCount
    } else if let cachedData = cachedData as? CachedGroupData, let participants = cachedData.participants {
        return Int32(participants.participants.count)
    } else {
        return nil
    }
}

private final class CommunityAddPeerItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    let memberCount: Int32?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EnginePeer, memberCount: Int32?) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.memberCount = memberCount
    }

    static func ==(lhs: CommunityAddPeerItemComponent, rhs: CommunityAddPeerItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.memberCount != rhs.memberCount {
            return false
        }
        return true
    }

    final class View: UIView, ListSectionComponentChildView {
        var customUpdateIsHighlighted: ((Bool) -> Void)?
        var enumerateSiblings: (((UIView) -> Void) -> Void)?
        var separatorInset: CGFloat {
            return 98.0
        }

        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()

        private var component: CommunityAddPeerItemComponent?

        func update(component: CommunityAddPeerItemComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component

            let height: CGFloat = 98.0
            let avatarSize = self.avatar.update(
                transition: transition,
                component: AnyComponent(AvatarComponent(
                    context: component.context,
                    theme: component.theme,
                    peer: component.peer,
                    clipStyle: .round
                )),
                environment: {},
                containerSize: CGSize(width: 66.0, height: 66.0)
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setFrame(view: avatarView, frame: CGRect(
                    origin: CGPoint(x: 16.0, y: floorToScreenPixels((height - avatarSize.height) / 2.0)),
                    size: avatarSize
                ))
            }

            let textLeft = 16.0 + avatarSize.width + 16.0
            let textWidth = max(1.0, availableSize.width - textLeft - 16.0)

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.peer.compactDisplayTitle,
                        font: Font.semibold(18.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )

            var subtitleSize = CGSize()
            if let memberCount = component.memberCount {
                subtitleSize = self.subtitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.strings.Conversation_StatusMembers(memberCount),
                            font: Font.regular(15.0),
                            textColor: component.theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: textWidth, height: 100.0)
                )
                if let subtitleView = self.subtitle.view {
                    if subtitleView.superview == nil {
                        self.addSubview(subtitleView)
                    }
                    transition.setAlpha(view: subtitleView, alpha: 1.0)
                }
            } else if let subtitleView = self.subtitle.view {
                transition.setAlpha(view: subtitleView, alpha: 0.0)
            }

            let textHeight = titleSize.height + (subtitleSize.height.isZero ? 0.0 : 5.0 + subtitleSize.height)
            var textY = floorToScreenPixels((height - textHeight) / 2.0)

            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: textLeft, y: textY), size: titleSize))
            }
            textY += titleSize.height + 3.0

            if let subtitleView = self.subtitle.view {
                subtitleView.frame = CGRect(origin: CGPoint(x: textLeft, y: textY), size: subtitleSize)
            }

            return CGSize(width: availableSize.width, height: height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class CommunityAddContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer?
    let memberCount: Int32?
    let visibility: CommunityAddVisibility
    let isSaving: Bool
    let buttonTitle: String
    let dismiss: () -> Void
    let selectVisibility: (CommunityAddVisibility) -> Void
    let add: () -> Void

    init(
        context: AccountContext,
        peer: EnginePeer?,
        memberCount: Int32?,
        visibility: CommunityAddVisibility,
        isSaving: Bool,
        buttonTitle: String,
        dismiss: @escaping () -> Void,
        selectVisibility: @escaping (CommunityAddVisibility) -> Void,
        add: @escaping () -> Void
    ) {
        self.context = context
        self.peer = peer
        self.memberCount = memberCount
        self.visibility = visibility
        self.isSaving = isSaving
        self.buttonTitle = buttonTitle
        self.dismiss = dismiss
        self.selectVisibility = selectVisibility
        self.add = add
    }

    static func ==(lhs: CommunityAddContentComponent, rhs: CommunityAddContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.memberCount != rhs.memberCount {
            return false
        }
        if lhs.visibility != rhs.visibility {
            return false
        }
        if lhs.isSaving != rhs.isSaving {
            return false
        }
        if lhs.buttonTitle != rhs.buttonTitle {
            return false
        }
        return true
    }

    final class View: UIView {
        private let closeButton = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let peerSection = ComponentView<Empty>()
        private let visibilitySection = ComponentView<Empty>()
        private let addButton = ComponentView<Empty>()

        private func visibilityItem(
            component: CommunityAddContentComponent,
            id: String,
            title: String,
            subtitle: String,
            visibility: CommunityAddVisibility,
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: id, component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                    AnyComponentWithIdentity(id: "subtitle", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: subtitle,
                            font: Font.regular(13.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    )))
                ], alignment: .left, spacing: 4.0)),
                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0),
                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                    style: .tick,
                    isSelected: component.visibility == visibility,
                    toggle: component.isSaving ? nil : {
                        component.selectVisibility(visibility)
                    }
                )),
                accessory: nil,
                action: component.isSaving ? nil : { _ in
                    component.selectVisibility(visibility)
                },
                highlighting: component.isSaving ? .disabled : .default
            )))
        }

        func update(component: CommunityAddContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme.withModalBlocksBackground()
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            self.backgroundColor = .clear

            let sideInset: CGFloat = 16.0
            let contentWidth = max(1.0, availableSize.width - sideInset * 2.0)

            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(
                        name: "Navigation/Close",
                        tintColor: theme.chat.inputPanel.panelControlColor
                    ))),
                    action: { _ in
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: closeButtonSize))
            }

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Community_Add_Title,
                        font: Font.semibold(17.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth - 100.0, height: 44.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 16.0 + floorToScreenPixels((44.0 - titleSize.height) / 2.0)),
                    size: titleSize
                ))
            }

            var contentHeight: CGFloat = 76.0

            if let peer = component.peer {
                var transition = transition
                if self.peerSection.view == nil {
                    transition = .immediate
                }
                let peerSectionSize = self.peerSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: "peer", component: AnyComponent(CommunityAddPeerItemComponent(
                                context: component.context,
                                theme: theme,
                                strings: environment.strings,
                                peer: peer,
                                memberCount: component.memberCount
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: 1000.0)
                )
                if let peerSectionView = self.peerSection.view {
                    if peerSectionView.superview == nil {
                        self.addSubview(peerSectionView)
                    }
                    transition.setFrame(view: peerSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: peerSectionSize))
                }
                contentHeight += peerSectionSize.height + 24.0
            }

            let visibilitySectionSize = self.visibilitySection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Community_Add_VisibilityHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Community_Add_VisibilityInfo,
                            font: Font.regular(13.0),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        self.visibilityItem(
                            component: component,
                            id: "visible",
                            title: environment.strings.Community_Add_VisibilityVisible,
                            subtitle: environment.strings.Community_Add_VisibilityVisibleInfo,
                            visibility: .visible,
                            theme: theme,
                            presentationData: presentationData
                        ),
                        self.visibilityItem(
                            component: component,
                            id: "hidden",
                            title: environment.strings.Community_Add_VisibilityHidden,
                            subtitle: environment.strings.Community_Add_VisibilityHiddenInfo,
                            visibility: .hidden,
                            theme: theme,
                            presentationData: presentationData
                        )
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let visibilitySectionView = self.visibilitySection.view {
                if visibilitySectionView.superview == nil {
                    self.addSubview(visibilitySectionView)
                }
                transition.setFrame(view: visibilitySectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: visibilitySectionSize))
            }
            contentHeight += visibilitySectionSize.height + 36.0

            let buttonHeight: CGFloat = 52.0
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: buttonHeight, sideInset: 30.0)
            let addButtonSize = self.addButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: buttonHeight * 0.5
                    ),
                    content: AnyComponentWithIdentity(id: "title", component: AnyComponent(ButtonTextContentComponent(
                        text: component.buttonTitle,
                        badge: 0,
                        textColor: theme.list.itemCheckColors.foregroundColor,
                        badgeBackground: theme.list.itemCheckColors.foregroundColor,
                        badgeForeground: theme.list.itemCheckColors.fillColor
                    ))),
                    isEnabled: component.peer != nil && !component.isSaving,
                    displaysProgress: component.isSaving,
                    action: {
                        component.add()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: buttonHeight)
            )
            if let addButtonView = self.addButton.view {
                if addButtonView.superview == nil {
                    self.addSubview(addButtonView)
                }
                transition.setFrame(view: addButtonView, frame: CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: addButtonSize))
            }
            contentHeight += addButtonSize.height + buttonInsets.bottom

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class CommunityAddScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let subject: CommunityAddScreenSubject
    let peerId: EnginePeer.Id
    let requiresConfirmation: Bool
    let completed: (Bool) -> Void
    let draftCompleted: (Bool) -> Void

    init(
        context: AccountContext,
        subject: CommunityAddScreenSubject,
        peerId: EnginePeer.Id,
        requiresConfirmation: Bool,
        completed: @escaping (Bool) -> Void,
        draftCompleted: @escaping (Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.peerId = peerId
        self.requiresConfirmation = requiresConfirmation
        self.completed = completed
        self.draftCompleted = draftCompleted
    }

    static func ==(lhs: CommunityAddScreenComponent, rhs: CommunityAddScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.requiresConfirmation != rhs.requiresConfirmation {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, SheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var component: CommunityAddScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var peer: EnginePeer?
        private var cachedData: EngineCachedPeerData?
        private var visibility: CommunityAddVisibility = .visible
        private var didInitializeVisibility = false
        private var isSaving = false
        private var didRequestCachedData = false
        private var dataDisposable: Disposable?
        private let actionDisposable = MetaDisposable()

        deinit {
            self.dataDisposable?.dispose()
            self.actionDisposable.dispose()
        }

        private func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
            guard let controller = self.environment?.controller else {
                completion?()
                return
            }
            if animated {
                self.animateOut.invoke(Action { _ in
                    controller()?.dismiss(completion: completion)
                })
            } else {
                controller()?.dismiss(animated: false, completion: completion)
            }
        }

        private func ensureDataSignal(component: CommunityAddScreenComponent) {
            if self.dataDisposable != nil {
                return
            }
            self.dataDisposable = (combineLatest(
                component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId)),
                component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.CachedData(id: component.peerId))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer, cachedData in
                guard let self else {
                    return
                }
                self.peer = peer
                self.cachedData = cachedData
                self.state?.updated(transition: .spring(duration: 0.35))
            })

            if !self.didRequestCachedData {
                self.didRequestCachedData = true
                component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.peerId)
            }
        }

        private func performAdd() {
            guard let component = self.component, let peer = self.peer, !self.isSaving else {
                return
            }

            if case .draft = component.subject {
                let isVisible = self.visibility.isVisible
                self.dismiss(animated: true, completion: {
                    component.draftCompleted(isVisible)
                })
                return
            }

            if !component.requiresConfirmation {
                self.performExistingAdd()
                return
            }

            guard let environment = self.environment, let controller = environment.controller() else {
                return
            }
            let alertText: String
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                alertText = environment.strings.Community_Add_Confirm_TextChannel
            } else if case .user = peer {
                alertText = environment.strings.Community_Add_Confirm_TextBot
            } else {
                alertText = environment.strings.Community_Add_Confirm_TextGroup
            }
            controller.present(textAlertController(
                context: component.context,
                title: nil,
                text: alertText,
                actions: [
                    TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultAction, title: environment.strings.Community_Add_Confirm_Add, action: { [weak self] in
                        self?.performExistingAdd()
                    })
                ]
            ), in: .window(.root))
        }

        private func performExistingAdd() {
            guard let component = self.component, self.peer != nil, !self.isSaving, case let .existing(communityId) = component.subject else {
                return
            }

            self.isSaving = true
            self.state?.updated(transition: .immediate)

            self.actionDisposable.set((component.context.engine.peers.toggleCommunityPeerLink(
                communityId: communityId,
                peerId: component.peerId,
                action: .link(visible: self.visibility.isVisible)
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] error in
                guard let self, let environment = self.environment else {
                    return
                }
                self.isSaving = false
                if case .requestCreated = error {
                    self.dismiss(animated: true, completion: {
                        component.completed(false)
                    })
                } else if case .serverProvided = error {
                    self.state?.updated(transition: .spring(duration: 0.35))
                } else {
                    let text: String
                    switch error {
                    case .peersTooMuch:
                        text = environment.strings.Login_UnknownError
                    default:
                        text = environment.strings.Login_UnknownError
                    }
                    environment.controller()?.present(AlertScreen(
                        context: component.context,
                        title: nil,
                        text: text,
                        actions: [
                            AlertScreen.Action(title: environment.strings.Common_OK, type: .default)
                        ]
                    ), in: .window(.root))
                    
                    self.state?.updated(transition: .spring(duration: 0.35))
                }
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isSaving = false
                self.dismiss(animated: true, completion: {
                    component.completed(true)
                })
            }))
        }

        func update(component: CommunityAddScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            if !self.didInitializeVisibility {
                self.didInitializeVisibility = true
                if case let .draft(initialVisibility) = component.subject {
                    self.visibility = initialVisibility ? .visible : .hidden
                }
            }

            self.ensureDataSignal(component: component)

            let theme = environment.theme
            let isDraft: Bool
            if case .draft = component.subject {
                isDraft = true
            } else {
                isDraft = false
            }
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(CommunityAddContentComponent(
                        context: component.context,
                        peer: self.peer,
                        memberCount: communityAddMemberCount(cachedData: self.cachedData),
                        visibility: self.visibility,
                        isSaving: self.isSaving,
                        buttonTitle: isDraft ? environment.strings.Common_Done : environment.strings.Community_Add_ActionAddToCommunity,
                        dismiss: { [weak self] in
                            self?.dismiss(animated: true)
                        },
                        selectVisibility: { [weak self] visibility in
                            guard let self, !self.isSaving else {
                                return
                            }
                            if self.visibility != visibility {
                                self.visibility = visibility
                                self.state?.updated(transition: .spring(duration: 0.35))
                            }
                        },
                        add: { [weak self] in
                            self?.performAdd()
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: self.animateOut
                )),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { [weak self] animated in
                            self?.dismiss(animated: animated)
                        }
                    )
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class CommunityAddScreen: ViewControllerComponentContainer {
    public convenience init(
        context: AccountContext,
        communityId: EnginePeer.Id,
        peerId: EnginePeer.Id,
        completed: @escaping (Bool) -> Void
    ) {
        self.init(
            context: context,
            communityId: communityId,
            peerId: peerId,
            requiresConfirmation: false,
            completed: completed
        )
    }

    public init(
        context: AccountContext,
        communityId: EnginePeer.Id,
        peerId: EnginePeer.Id,
        requiresConfirmation: Bool,
        completed: @escaping (Bool) -> Void
    ) {
        super.init(
            context: context,
            component: CommunityAddScreenComponent(
                context: context,
                subject: .existing(communityId: communityId),
                peerId: peerId,
                requiresConfirmation: requiresConfirmation,
                completed: completed,
                draftCompleted: { _ in }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        initialVisibility: Bool,
        draftCompleted: @escaping (Bool) -> Void
    ) {
        super.init(
            context: context,
            component: CommunityAddScreenComponent(
                context: context,
                subject: .draft(initialVisibility: initialVisibility),
                peerId: peerId,
                requiresConfirmation: false,
                completed: { _ in },
                draftCompleted: draftCompleted
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }
}
