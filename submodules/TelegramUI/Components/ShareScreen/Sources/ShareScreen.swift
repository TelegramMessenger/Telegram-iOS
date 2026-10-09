import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import SwiftSignalKit
import Postbox
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import ButtonComponent
import AccountContext
import PresentationDataUtils
import TelegramStringFormatting
import UndoUI
import PresentationDataUtils
import GlassBackgroundComponent
import GlassBarButtonComponent
import PlainButtonComponent
import ResizableSheetComponent
import EdgeEffect
import ShareController
import MessageInputPanelComponent
import MultilineTextComponent
import MergedAvatarsNode

private final class SheetContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let subject: ShareControllerSubject
    let externalShare: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    let contentHeight: CGFloat
    let groupPeers: [EnginePeer]
    let interactionUpdated: (SharePeersSheetContentView.InteractionState) -> Void
    let trackedScrollViewUpdated: (UIScrollView?) -> Void
    let dismiss: () -> Void

    init(
        context: AccountContext,
        subject: ShareControllerSubject,
        externalShare: Bool,
        theme: PresentationTheme,
        strings: PresentationStrings,
        contentHeight: CGFloat,
        groupPeers: [EnginePeer],
        interactionUpdated: @escaping (SharePeersSheetContentView.InteractionState) -> Void,
        trackedScrollViewUpdated: @escaping (UIScrollView?) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.externalShare = externalShare
        self.theme = theme
        self.strings = strings
        self.contentHeight = contentHeight
        self.groupPeers = groupPeers
        self.interactionUpdated = interactionUpdated
        self.trackedScrollViewUpdated = trackedScrollViewUpdated
        self.dismiss = dismiss
    }

    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.groupPeers != rhs.groupPeers {
            return false
        }
        return true
    }

    final class View: UIView {
        private var isUpdating = false

        private var peersContentView: SharePeersSheetContentView?
        private let search = ComponentView<Empty>()

        private var component: SheetContent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.disablesInteractiveKeyboardGestureRecognizer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {

        }

        func update(component: SheetContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            self.state = state

            let peersContentView: SharePeersSheetContentView
            if let current = self.peersContentView {
                peersContentView = current
            } else {
                peersContentView = SharePeersSheetContentView(
                    context: component.context,
                    subject: component.subject,
                    externalShare: component.externalShare
                )
                self.peersContentView = peersContentView
                self.addSubview(peersContentView)
            }
            self.component = component
            peersContentView.interactionUpdated = component.interactionUpdated
            peersContentView.trackedScrollViewUpdated = component.trackedScrollViewUpdated

            let contentSize = CGSize(width: availableSize.width, height: component.contentHeight)
            transition.setFrame(view: peersContentView, frame: CGRect(origin: .zero, size: contentSize))
            peersContentView.update(
                availableSize: contentSize,
                theme: component.theme,
                strings: component.strings,
                transition: themeUpdated ? .immediate : transition.containedViewLayoutTransition
            )

            let searchSize = self.search.update(
                transition: transition,
                component: AnyComponent(
                    SearchInputPanelComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        metrics: environment.metrics,
                        safeInsets: .zero,
                        groupPeers: component.groupPeers,
                        updated: { _ in },
                        cancel: {}
                    )
                ),
                environment: {
                },
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            let searchFrame = CGRect(origin: CGPoint(x: 0.0, y: 76.0), size: searchSize)
            if let searchView = self.search.view {
                if searchView.superview == nil {
                    self.addSubview(searchView)
                }
                transition.setFrame(view: searchView, frame: searchFrame)
            }

            return contentSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ShareScreenSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    private let context: AccountContext
    private let subject: ShareControllerSubject
    private let externalShare: Bool

    init(
        context: AccountContext,
        subject: ShareControllerSubject,
        externalShare: Bool
    ) {
        self.context = context
        self.subject = subject
        self.externalShare = externalShare
    }

    static func ==(lhs: ShareScreenSheetComponent, rhs: ShareScreenSheetComponent) -> Bool {
        return true
    }

    final class State: ComponentState {
        var foundPeers: [(peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool)] = []
        var selectedPeerIds = Set<EnginePeer.Id>()
        var selectedPeers: [EngineRenderedPeer] = []
        var selectedTopics: [EnginePeer.Id: (Int64, MessageHistoryThreadData?)] = [:]

        func updateInteractionState(_ interactionState: SharePeersSheetContentView.InteractionState) {
            self.foundPeers = interactionState.foundPeers
            self.selectedPeerIds = interactionState.selectedPeerIds
            self.selectedPeers = interactionState.selectedPeers
            self.selectedTopics = interactionState.selectedTopics
            self.updated(transition: .spring(duration: 0.4).withUserData(MultilineTextComponent.CrossfadeTransition()))
        }
    }

    func makeState() -> State {
        return State()
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<()>>()
        private let sheetExternalState = ResizableSheetComponent<EnvironmentType>.ExternalState()

        private var isUpdating = false

        private var component: ShareScreenSheetComponent?
        private(set) weak var state: State?
        private var environment: EnvironmentType?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {

        }

        private func subtitleText(component: ShareScreenSheetComponent, state: State, strings: PresentationStrings) -> String {
            guard !state.selectedPeers.isEmpty else {
                return strings.ShareMenu_SelectChats
            }
            let nameDisplayOrder = component.context.sharedContext.currentPresentationData.with { $0.nameDisplayOrder }
            let selectedTitles = state.selectedPeers.compactMap { peer -> String? in
                if peer.peerId == component.context.account.peerId {
                    return strings.DialogList_SavedMessages
                } else {
                    return peer.chatMainPeer?.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                }
            }
            if selectedTitles.isEmpty {
                return strings.ShareMenu_SelectChats
            } else {
                return selectedTitles.joined(separator: ", ")
            }
        }

        func update(component: ShareScreenSheetComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.state = state

            let controller = environment.controller

            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    self.animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }

            let theme = environment.theme.withModalBlocksBackground()

            var titleItems: [AnyComponentWithIdentity<Empty>] = []
            titleItems.append(AnyComponentWithIdentity(id: "title", component: AnyComponent(
                Text(text: environment.strings.ShareMenu_ShareTo, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor)
            )))

            titleItems.append(AnyComponentWithIdentity(id: "subtitle", component: AnyComponent(
                MultilineTextComponent(text: .plain(
                    NSAttributedString(string: self.subtitleText(component: component, state: state, strings: environment.strings), font: Font.regular(12.0), textColor: theme.list.itemSecondaryTextColor)
                ))
            )))

            var groupPeers: [EnginePeer] = []
            for peer in state.selectedPeers {
                if let peer = peer.peer, case .user = peer {
                    groupPeers.append(peer)
                }
            }

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(
                    ResizableSheetComponent<EnvironmentType>(
                        content: AnyComponent<EnvironmentType>(SheetContent(
                            context: component.context,
                            subject: component.subject,
                            externalShare: component.externalShare,
                            theme: theme,
                            strings: environment.strings,
                            contentHeight: max(0.0, availableSize.height - environment.statusBarHeight - 10.0),
                            groupPeers: groupPeers,
                            interactionUpdated: { [weak state] interactionState in
                                state?.updateInteractionState(interactionState)
                            },
                            trackedScrollViewUpdated: { [weak self] scrollView in
                                self?.sheetExternalState.setTrackedScrollView(scrollView)
                            },
                            dismiss: {
                                dismiss(true)
                            }
                        )),
                        titleItem: AnyComponent(
                            VStack(titleItems, spacing: 0.0)
                        ),
                        leftItem: AnyComponent(
                            GlassBarButtonComponent(
                                size: CGSize(width: 44.0, height: 44.0),
                                backgroundColor: nil,
                                isDark: theme.overallDarkAppearance,
                                state: .glass,
                                component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                    BundleIconComponent(
                                        name: "Navigation/Close",
                                        tintColor: theme.chat.inputPanel.panelControlColor
                                    )
                                )),
                                action: { _ in
                                    dismiss(true)
                                }
                            )
                        ),
                        rightItem: AnyComponent(
                            GlassBarButtonComponent(
                                size: CGSize(width: 44.0, height: 44.0),
                                backgroundColor: nil,
                                isDark: theme.overallDarkAppearance,
                                state: .glass,
                                component: AnyComponentWithIdentity(id: "share", component: AnyComponent(
                                    BundleIconComponent(
                                        name: "Navigation/Share",
                                        tintColor: theme.chat.inputPanel.panelControlColor
                                    )
                                )),
                                action: { _ in
                                    dismiss(true)
                                }
                            )
                        ),
                        bottomItem: AnyComponent(
                            BottomPanelComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                actionTitle: "Copy Link",
                                actionBadge: state.selectedPeerIds.isEmpty ? nil : state.selectedPeerIds.count,
                                action: {

                                }
                            )
                        ),
                        backgroundColor: .color(theme.list.modalPlainBackgroundColor),
                        defaultHeight: 540.0,
                        externalState: self.sheetExternalState,
                        animateOut: self.animateOut
                    )
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        screenSize: availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
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
        return View()
    }

    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ShareScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let subject: ShareControllerSubject

    public init(
        context: AccountContext,
        subject: ShareControllerSubject,
        externalShare: Bool
    ) {
        self.context = context
        self.subject = subject

        super.init(
            context: context,
            component: ShareScreenSheetComponent(
                context: context,
                subject: subject,
                externalShare: externalShare
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class BottomPanelComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let actionTitle: String?
    let actionBadge: Int?
    let action: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        actionTitle: String?,
        actionBadge: Int?,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.actionBadge = actionBadge
        self.action = action
    }

    static func ==(lhs: BottomPanelComponent, rhs: BottomPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        if lhs.actionBadge != rhs.actionBadge {
            return false
        }
        return true
    }

    final class View: UIView {
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()

        private let actionButton = ComponentView<Empty>()

        private var component: BottomPanelComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: BottomPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            var contentHeight: CGFloat = 0.0

            let inputPanelInset: CGFloat = 19.0

            let mainActionIsVisible = (component.actionBadge ?? 0) > 0

            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    style: .gift,
                    placeholder: .plain("Add a caption..."),
                    sendPaidMessageStars: nil,
                    maxLength: 1024,
                    queryTypes: [],
                    alwaysDarkWhenHasText: false,
                    useGrayBackground: false,
                    resetInputContents: nil,
                    nextInputMode: { _ in return .emoji },
                    areVoiceMessagesAvailable: false,
                    presentController: { c in
                    },
                    presentInGlobalOverlay: { c in
                    },
                    sendMessageAction: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        let _ = self
                        //self.deactivateInput()
                    },
                    sendMessageOptionsAction: nil,
                    sendStickerAction: { _ in },
                    setMediaRecordingActive: nil,
                    lockMediaRecording: {
                    },
                    stopAndPreviewMediaRecording: {
                    },
                    discardMediaRecordingPreview: nil,
                    attachmentAction: nil,
                    myReaction: nil,
                    likeAction: nil,
                    likeOptionsAction: nil,
                    inputModeAction: { [weak self] in
                        if let self {
                            let _ = self
//                            switch self.currentInputMode {
//                            case .text:
//                                self.currentInputMode = .emoji
//                            case .emoji:
//                                self.currentInputMode = .text
//                            default:
//                                self.currentInputMode = .emoji
//                            }
//                            if self.currentInputMode == .text {
//                                self.activateInput()
//                            } else {
//                                self.state?.updated(transition: .immediate)
//                            }
                        }
                    },
                    timeoutAction: nil,
                    forwardAction: nil,
                    paidMessageAction: nil,
                    moreAction: nil,
                    presentCaptionPositionTooltip: nil,
                    presentVoiceMessagesUnavailableTooltip: nil,
                    presentTextLengthLimitTooltip: {
                    },
                    presentTextFormattingTooltip: {
                    },
                    paste: { _ in
                    },
                    audioRecorder: nil,
                    videoRecordingStatus: nil,
                    isRecordingLocked: false,
                    hasRecordedVideo: false,
                    recordedAudioPreview: nil,
                    hasRecordedVideoPreview: false,
                    wasRecordingDismissed: false,
                    timeoutValue: nil,
                    timeoutSelected: false,
                    displayGradient: false,
                    bottomInset: 0.0,
                    isFormattingLocked: false,
                    hideKeyboard: false, //self.currentInputMode == .emoji,
                    customInputView: nil,
                    forceIsEditing: false, //self.currentInputMode == .emoji,
                    disabledPlaceholder: nil,
                    header: nil,
                    isChannel: false,
                    storyItem: nil,
                    chatLocation: nil
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width + inputPanelInset * 2.0, height: 160.0)
            )
            let inputPanelFrame = CGRect(origin: CGPoint(x: -inputPanelInset, y: 0.0), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setPosition(view: inputPanelView, position: inputPanelFrame.center)
                transition.setBounds(view: inputPanelView, bounds: CGRect(origin: .zero, size: inputPanelFrame.size))
                transition.setBlur(layer: inputPanelView.layer, radius: mainActionIsVisible ? 0.0 : 10.0)
                //transition.setScale(view: inputPanelView, scale: mainActionIsVisible ? 1.0 : 0.7)
            }
            if mainActionIsVisible {
                contentHeight += inputPanelSize.height
                contentHeight += 8.0
            }

            let buttonTitle: AnyComponentWithIdentity<Empty>
            if let actionBadge = component.actionBadge, actionBadge > 0 {
                buttonTitle = AnyComponentWithIdentity(id: "send", component: AnyComponent(ButtonTextContentComponent(
                    text: "Send",
                    badge: actionBadge,
                    textColor: component.theme.list.itemCheckColors.foregroundColor,
                    badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                    badgeForeground: component.theme.list.itemCheckColors.fillColor
                )))
            } else {
                buttonTitle = AnyComponentWithIdentity(id: component.actionTitle ?? "", component: AnyComponent(Text(
                    text: component.actionTitle ?? "",
                    font: Font.semibold(17.0),
                    color: component.theme.list.itemCheckColors.foregroundColor
                )))
            }

            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: buttonTitle,
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: availableSize.height)
            )
            let actionButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }

            contentHeight += actionButtonSize.height

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SearchInputPanelComponent: Component {
    public final class ResetText: Equatable {
        public let value: String

        public init(value: String) {
            self.value = value
        }

        public static func ==(lhs: ResetText, rhs: ResetText) -> Bool {
            return lhs === rhs
        }
    }

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let metrics: LayoutMetrics
    let safeInsets: UIEdgeInsets
    let placeholder: String?
    let groupPeers: [EnginePeer]
    let resetText: ResetText?
    let updated: ((String) -> Void)
    let cancel: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        metrics: LayoutMetrics,
        safeInsets: UIEdgeInsets,
        placeholder: String? = nil,
        groupPeers: [EnginePeer] = [],
        resetText: ResetText? = nil,
        updated: @escaping ((String) -> Void),
        cancel: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.metrics = metrics
        self.safeInsets = safeInsets
        self.placeholder = placeholder
        self.groupPeers = groupPeers
        self.resetText = resetText
        self.updated = updated
        self.cancel = cancel
    }

    public static func ==(lhs: SearchInputPanelComponent, rhs: SearchInputPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.groupPeers != rhs.groupPeers {
            return false
        }
        if lhs.resetText != rhs.resetText {
            return false
        }
        return true
    }

    private final class TextField: UITextField {
        var sideInset: CGFloat = 0.0

        override func textRect(forBounds bounds: CGRect) -> CGRect {
            return CGRect(origin: CGPoint(x: self.sideInset, y: 0.0), size: CGSize(width: bounds.width - self.sideInset * 2.0, height: bounds.height))
        }

        override func editingRect(forBounds bounds: CGRect) -> CGRect {
            return CGRect(origin: CGPoint(x: self.sideInset, y: 0.0), size: CGSize(width: bounds.width - self.sideInset * 2.0, height: bounds.height))
        }
    }

    public final class View: UIView, UITextFieldDelegate {
        private let containerView: GlassBackgroundContainerView
        private let fieldBackgroundView: GlassBackgroundView

        private let icon = ComponentView<Empty>()
        private var placeholder = ComponentView<Empty>()

        private let textField: TextField
        private let clearButton = ComponentView<Empty>()

        private let rightButton = ComponentView<Empty>()

        private var component: SearchInputPanelComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false

        public var currentText: String {
            return self.textField.text ?? ""
        }

        override init(frame: CGRect) {
            self.containerView = GlassBackgroundContainerView()
            self.fieldBackgroundView = GlassBackgroundView()
            self.textField = TextField()

            super.init(frame: frame)

            self.addSubview(self.containerView)
            self.containerView.contentView.addSubview(self.fieldBackgroundView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func textDidChange() {
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
            self.component?.updated(self.currentText)
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if !self.currentText.isEmpty {
                self.textField.resignFirstResponder()
            }

            return true
        }

        public func setText(text: String, updateState: Bool) {
            self.textField.text = text
            if updateState {
                self.state?.updated(transition: .immediate, isLocal: true)
                self.component?.updated(self.currentText)
            } else {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
        }

        public func activateInput() {
            self.textField.becomeFirstResponder()
        }

        public func deactivateInput() -> Bool {
            self.textField.resignFirstResponder()

            return self.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func update(component: SearchInputPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let previousComponent = self.component
            self.component = component
            self.state = state

            if self.textField.superview == nil {
                self.addSubview(self.textField)

                self.textField.accessibilityTraits = .searchField
                self.textField.autocorrectionType = .no
                self.textField.autocapitalizationType = .sentences
                self.textField.enablesReturnKeyAutomatically = true
                self.textField.returnKeyType = .search
                self.textField.delegate = self
                self.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
            }

            let themeUpdated = component.theme !== previousComponent?.theme

            if themeUpdated {
                self.textField.font = Font.regular(17.0)
                self.textField.textColor = component.theme.list.itemPrimaryTextColor
                self.textField.keyboardAppearance = component.theme.overallDarkAppearance ? .dark : .light
            }

            let backgroundColor = component.theme.list.plainBackgroundColor.withMultipliedAlpha(0.75)

            let edgeInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
            let fieldHeight: CGFloat = 44.0
            let buttonSpacing: CGFloat = 10.0

            var rightButtonWidth: CGFloat = 44.0
            let rightButtonContent: AnyComponentWithIdentity<Empty>
            if self.textField.isFirstResponder {
                rightButtonContent = AnyComponentWithIdentity(id: "close", component: AnyComponent(
                    BundleIconComponent(
                        name: "Navigation/Close",
                        tintColor: component.theme.chat.inputPanel.panelControlColor
                    )
                ))
            } else if component.groupPeers.count > 1 {
                rightButtonContent = AnyComponentWithIdentity(id: "createGroupAvatars", component: AnyComponent(
                    HStack([
                        AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                            BundleIconComponent(
                                name: "Navigation/CreateGroup",
                                tintColor: component.theme.chat.inputPanel.panelControlColor,
                                maxSize: CGSize(width: 22.0, height: 22.0)
                            )
                        )),
                        AnyComponentWithIdentity(id: "avatars", component: AnyComponent(
                            MergedAvatarsComponent(
                                context: component.context,
                                peers: component.groupPeers,
                                imageSize: 24.0,
                                imageSpacing: 15.0,
                                borderWidth: 2.0 - UIScreenPixel,
                                avatarFontSize: 10.0
                            )
                        ))
                    ], spacing: 3.0)
                ))
                rightButtonWidth = 24.0 + CGFloat(min(3, component.groupPeers.count) - 1) * 14.0 + 44.0
            } else {
                rightButtonContent = AnyComponentWithIdentity(id: "createGroup", component: AnyComponent(
                    BundleIconComponent(
                        name: "Navigation/CreateGroup",
                        tintColor: component.theme.chat.inputPanel.panelControlColor
                    )
                ))
            }


            let rightButtonSize = CGSize(width: rightButtonWidth, height: 44.0)
            let _ = self.rightButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: rightButtonSize,
                    backgroundColor: backgroundColor,
                    isDark: component.theme.overallDarkAppearance,
                    state: .glass,
                    component: rightButtonContent,
                    action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = self.deactivateInput()
                        component.cancel()
                    }
                )),
                environment: {},
                containerSize: rightButtonSize
            )

            let cancelButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - edgeInsets.right - rightButtonSize.width, y: edgeInsets.top), size: rightButtonSize)
            let fieldFrame = CGRect(origin: CGPoint(x: edgeInsets.left, y: edgeInsets.top), size: CGSize(width: max(0.0, cancelButtonFrame.minX - buttonSpacing - edgeInsets.left), height: fieldHeight))

            self.fieldBackgroundView.update(size: fieldFrame.size, cornerRadius: fieldFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            transition.setFrame(view: self.fieldBackgroundView, frame: fieldFrame)

            let fieldSideInset: CGFloat = 41.0
            self.textField.sideInset = fieldSideInset
            let fieldContentWidth = max(0.0, fieldFrame.width - fieldSideInset * 2.0 - 30.0)

            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(name: "Components/Search Bar/Loupe", tintColor: component.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: fieldContentWidth, height: 100.0)
            )

            let iconFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + 11.0, y: fieldFrame.minY + floor((fieldFrame.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.layer.anchorPoint = CGPoint()
                    iconView.isUserInteractionEnabled = false
                    self.insertSubview(iconView, belowSubview: self.textField)
                }
                transition.setPosition(view: iconView, position: iconFrame.origin)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }

            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.placeholder ?? component.strings.Common_Search, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.6)))
                )),
                environment: {},
                containerSize: CGSize(width: fieldContentWidth, height: 100.0)
            )

            let placeholderFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + fieldSideInset, y: fieldFrame.minY + floor((fieldFrame.height - placeholderSize.height) * 0.5)), size: placeholderSize)
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.layer.anchorPoint = CGPoint()
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, belowSubview: self.textField)
                }
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)

                placeholderView.isHidden = !self.currentText.isEmpty
            }

            transition.setFrame(view: self.textField, frame: fieldFrame)

            let clearButtonSize = self.clearButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Components/Search Bar/Clear",
                        tintColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.4)
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 44.0, height: 44.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.setText(text: "", updateState: true)
                    },
                    animateAlpha: false,
                    animateScale: true
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            if let clearButtonView = self.clearButton.view {
                if clearButtonView.superview == nil {
                    self.addSubview(clearButtonView)
                }
                transition.setFrame(view: clearButtonView, frame: CGRect(origin: CGPoint(x: fieldFrame.maxX - clearButtonSize.width, y: fieldFrame.minY + floor((fieldFrame.height - clearButtonSize.height) * 0.5)), size: clearButtonSize))
                clearButtonView.isHidden = self.currentText.isEmpty
            }

            if let cancelButtonView = self.rightButton.view {
                if cancelButtonView.superview == nil {
                    self.containerView.contentView.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }

            let size = CGSize(width: availableSize.width, height: edgeInsets.top + fieldHeight + edgeInsets.bottom)

            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: size))
            self.containerView.update(size: size, isDark: component.theme.overallDarkAppearance, transition: transition)

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

private final class MergedAvatarsComponent: Component {
    let context: AccountContext
    let peers: [EnginePeer]
    let imageSize: CGFloat
    let imageSpacing: CGFloat
    let borderWidth: CGFloat
    let avatarFontSize: CGFloat
    let synchronousLoad: Bool
    let pressed: (() -> Void)?

    init(
        context: AccountContext,
        peers: [EnginePeer],
        imageSize: CGFloat = MergedAvatarsNode.defaultMergedImageSize,
        imageSpacing: CGFloat = MergedAvatarsNode.defaultMergedImageSpacing,
        borderWidth: CGFloat = MergedAvatarsNode.defaultBorderWidth,
        avatarFontSize: CGFloat = MergedAvatarsNode.defaultAvatarFontSize,
        synchronousLoad: Bool = false,
        pressed: (() -> Void)? = nil
    ) {
        self.context = context
        self.peers = peers
        self.imageSize = imageSize
        self.imageSpacing = imageSpacing
        self.borderWidth = borderWidth
        self.avatarFontSize = avatarFontSize
        self.synchronousLoad = synchronousLoad
        self.pressed = pressed
    }

    static func ==(lhs: MergedAvatarsComponent, rhs: MergedAvatarsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.imageSize != rhs.imageSize {
            return false
        }
        if lhs.imageSpacing != rhs.imageSpacing {
            return false
        }
        if lhs.borderWidth != rhs.borderWidth {
            return false
        }
        if lhs.avatarFontSize != rhs.avatarFontSize {
            return false
        }
        if lhs.synchronousLoad != rhs.synchronousLoad {
            return false
        }
        return true
    }

    final class View: UIView {
        private let mergedAvatarsNode: MergedAvatarsNode

        private var component: MergedAvatarsComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            self.mergedAvatarsNode = MergedAvatarsNode()

            super.init(frame: frame)

            self.addSubnode(self.mergedAvatarsNode)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: MergedAvatarsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let visiblePeers = Array(component.peers.prefix(3)).map { $0._asPeer() }
            let size = CGSize(
                width: visiblePeers.isEmpty ? 0.0 : component.imageSize + component.imageSpacing * CGFloat(max(0, visiblePeers.count - 1)),
                height: visiblePeers.isEmpty ? 0.0 : component.imageSize
            )

            self.mergedAvatarsNode.pressed = component.pressed
            self.mergedAvatarsNode.isUserInteractionEnabled = component.pressed != nil
            self.mergedAvatarsNode.isHidden = visiblePeers.isEmpty

            if !visiblePeers.isEmpty {
                self.mergedAvatarsNode.update(
                    context: component.context,
                    peers: visiblePeers,
                    synchronousLoad: component.synchronousLoad,
                    imageSize: component.imageSize,
                    imageSpacing: component.imageSpacing,
                    borderWidth: component.borderWidth,
                    avatarFontSize: component.avatarFontSize
                )
                self.mergedAvatarsNode.updateLayout(size: size)
            }

            transition.setFrame(view: self.mergedAvatarsNode.view, frame: CGRect(origin: .zero, size: size))
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
