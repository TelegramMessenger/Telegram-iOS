import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import BundleIconComponent
import ButtonComponent
import AccountContext
import PresentationDataUtils
import GlassBackgroundComponent
import GlassBarButtonComponent
import PlainButtonComponent
import MessageInputPanelComponent
import MultilineTextComponent
import MergedAvatarsNode
import HorizontalTabsComponent
import ObjectiveC
import CheckNode

private var shareScreenFadeVisibleKey: UInt8 = 0

func shareScreenSetFadeVisible(_ view: UIView, isVisible: Bool, blurRadius: CGFloat = 0.0, transition: ComponentTransition) {
    let previous = (objc_getAssociatedObject(view, &shareScreenFadeVisibleKey) as? NSNumber)?.boolValue
    guard previous != isVisible else { return }
    objc_setAssociatedObject(view, &shareScreenFadeVisibleKey, NSNumber(value: isVisible), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    let fromAlpha = CGFloat(view.layer.presentation()?.opacity ?? view.layer.opacity)
    view.layer.removeAnimation(forKey: "opacity")
    let animationTransition: ComponentTransition = previous == nil ? .immediate : transition
    if blurRadius > 0.0 {
        animationTransition.setBlur(layer: view.layer, radius: isVisible ? 0.0 : blurRadius)
    }
    guard case let .curve(duration, curve) = animationTransition.animation else {
        view.alpha = isVisible ? 1.0 : 0.0
        return
    }
    view.alpha = 1.0
    view.layer.animate(from: fromAlpha as NSNumber, to: (isVisible ? 1.0 : 0.0) as NSNumber, keyPath: "opacity", duration: duration, delay: 0.0, curve: curve, removeOnCompletion: isVisible, additive: false, completion: isVisible ? nil : { [weak view] _ in
        guard let view, (objc_getAssociatedObject(view, &shareScreenFadeVisibleKey) as? NSNumber)?.boolValue == false else { return }
        view.alpha = 0.0
        view.layer.removeAnimation(forKey: "opacity")
    })
}

final class ShareScreenPanelState {
    var initialCaption = NSAttributedString(string: "")
    var height: CGFloat = 0.0
    var heightUpdated: (() -> Void)?
    var caption: () -> NSAttributedString = { NSAttributedString(string: "") }
}

final class BottomPanelComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let actionTitle: String?
    let actionBadge: Int?
    let action: () -> Void
    let actionOptions: ((UIView) -> Void)?
    let panelState: ShareScreenPanelState
    let hiddenActionOffset: CGFloat
    let showsActionButton: Bool
    let inlineSendButton: Bool
    let sheetSideInset: CGFloat
    let metrics: LayoutMetrics
    let deviceMetrics: DeviceMetrics
    let isSending: Bool
    let showsProgress: Bool
    let present: (ViewController) -> Void
    let accessory: AnyComponentWithIdentity<Empty>?

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        actionTitle: String?,
        actionBadge: Int?,
        panelState: ShareScreenPanelState,
        showsActionButton: Bool,
        hiddenActionOffset: CGFloat,
        inlineSendButton: Bool,
        sheetSideInset: CGFloat,
        metrics: LayoutMetrics,
        deviceMetrics: DeviceMetrics,
        isSending: Bool,
        showsProgress: Bool = true,
        present: @escaping (ViewController) -> Void,
        accessory: AnyComponentWithIdentity<Empty>? = nil,
        actionOptions: ((UIView) -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.actionBadge = actionBadge
        self.action = action
        self.actionOptions = actionOptions
        self.panelState = panelState
        self.showsActionButton = showsActionButton
        self.hiddenActionOffset = hiddenActionOffset
        self.inlineSendButton = inlineSendButton
        self.sheetSideInset = sheetSideInset
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        self.isSending = isSending
        self.showsProgress = showsProgress
        self.present = present
        self.accessory = accessory
    }

    static func ==(lhs: BottomPanelComponent, rhs: BottomPanelComponent) -> Bool {
        if lhs.panelState !== rhs.panelState || lhs.inlineSendButton != rhs.inlineSendButton || lhs.sheetSideInset != rhs.sheetSideInset || lhs.showsActionButton != rhs.showsActionButton || lhs.hiddenActionOffset != rhs.hiddenActionOffset || lhs.isSending != rhs.isSending || lhs.showsProgress != rhs.showsProgress || lhs.metrics != rhs.metrics || lhs.deviceMetrics != rhs.deviceMetrics { return false }
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
        if lhs.accessory != rhs.accessory {
            return false
        }
        return true
    }

    final class View: UIView {
        private var accessory: ComponentView<Empty>?
        private var accessoryId: AnyHashable?
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()

        private let actionButton = ComponentView<Empty>()
        private let inlineBadge = UIView()
        private let inlineBadgeText = ComponentView<Empty>()
        private var inlineBadgeValue = ""
        private var emojiInput: ShareScreenEmojiInputView?
        private var isEmoji = false

        private func send() {
            if let input = self.inputPanel.view as? MessageInputPanelComponent.View, !input.canDeactivateInput() {
                input.animateError()
                return
            }
            self.component?.action()
        }

        private func toggleEmoji() {
            guard let component = self.component else { return }
            self.isEmoji = !self.isEmoji
            if self.isEmoji && self.emojiInput == nil {
                self.emojiInput = ShareScreenEmojiInputView(context: component.context, metrics: component.metrics, deviceMetrics: component.deviceMetrics, insertText: { [weak self] text in self?.inputPanelExternalState.insertText(text) }, deleteBackward: { [weak self] in self?.inputPanelExternalState.deleteBackward() }, switchToText: { [weak self] in self?.toggleEmoji() })
            }
            self.state?.updated(transition: .immediate)
            (self.inputPanel.view as? MessageInputPanelComponent.View)?.activateInput()
        }

        @objc private func actionLongPressed(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let component = self.component, !component.isSending, component.actionBadge != nil, let view = recognizer.view else { return }
            component.actionOptions?(view)
        }

        private var visibilityGeneration = 0
        private var isHidingPanel = false
        private var lastVisibleHeight: CGFloat = 0.0
        private var lastButtonTitle: AnyComponentWithIdentity<Empty>?
        private var component: BottomPanelComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: BottomPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                self.inputPanelExternalState.initialText = component.panelState.initialCaption
            }
            let previousInputIsVisible = self.component.map { ($0.actionBadge ?? 0) > 0 }
            self.component = component
            self.state = state
            let hasSelection = (component.actionBadge ?? 0) > 0
            if previousInputIsVisible != hasSelection { self.visibilityGeneration += 1 }
            if hasSelection || component.actionTitle != nil {
                self.isHidingPanel = false
            } else if previousInputIsVisible == true {
                self.isHidingPanel = true
                let generation = self.visibilityGeneration
                Queue.mainQueue().after(0.2) { [weak self] in
                    guard let self, self.visibilityGeneration == generation, self.isHidingPanel, let component = self.component, (component.actionBadge ?? 0) == 0, component.actionTitle == nil else { return }
                    self.isHidingPanel = false
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                }
            }
            component.panelState.caption = { [weak self] in
                guard let self, let view = self.inputPanel.view as? MessageInputPanelComponent.View else { return NSAttributedString(string: "") }
                switch view.getSendMessageInput() { case let .text(text): return text }
            }

            var contentHeight: CGFloat = 0.0

            if let accessory = component.accessory {
                let accessoryView: ComponentView<Empty>
                if let current = self.accessory, self.accessoryId == accessory.id {
                    accessoryView = current
                } else {
                    self.accessory?.view?.removeFromSuperview()
                    accessoryView = ComponentView<Empty>()
                    self.accessory = accessoryView
                    self.accessoryId = accessory.id
                }
                let accessorySize = accessoryView.update(transition: transition, component: accessory.component, environment: {}, containerSize: CGSize(width: availableSize.width, height: 44.0))
                if let view = accessoryView.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - accessorySize.width) * 0.5), y: 0.0), size: accessorySize))
                    shareScreenSetFadeVisible(view, isVisible: component.showsActionButton, blurRadius: 8.0, transition: transition)
                    view.isUserInteractionEnabled = component.showsActionButton
                }
                if component.showsActionButton {
                    contentHeight += accessorySize.height + 8.0
                }
            } else if let accessory = self.accessory {
                accessory.view?.removeFromSuperview()
                self.accessory = nil
                self.accessoryId = nil
            }
            let accessoryOffset = contentHeight

            let inputPanelInset: CGFloat = component.sheetSideInset - 8.0

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
                    placeholder: .plain(component.strings.ShareScreen_Caption),
                    sendPaidMessageStars: nil,
                    maxLength: 1024,
                    queryTypes: [],
                    alwaysDarkWhenHasText: false,
                    useGrayBackground: false,
                    displayGiftSendButton: component.inlineSendButton,
                    resetInputContents: nil,
                    nextInputMode: { [weak self] _ in return self?.isEmoji == true ? .text : .emoji },
                    areVoiceMessagesAvailable: false,
                    presentController: component.present,
                    presentInGlobalOverlay: component.present,
                    sendMessageAction: { [weak self] _ in self?.send() },
                    sendMessageOptionsAction: component.actionOptions == nil ? nil : { [weak self] view, _ in
                        guard let self, let component = self.component, !component.isSending, (component.actionBadge ?? 0) > 0 else { return }
                        component.actionOptions?(view)
                    },
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
                    inputModeAction: { [weak self] in self?.toggleEmoji() },
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
                    hideKeyboard: false,
                    customInputView: self.isEmoji ? self.emojiInput : nil,
                    // Visibility is animated by the enclosing panel, including its editing controls.
                    forceIsEditing: true,
                    disabledPlaceholder: nil,
                    header: nil,
                    isChannel: false,
                    storyItem: nil,
                    chatLocation: nil
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width + inputPanelInset * 2.0, height: 160.0)
            )
            let panelSlidesOut = !mainActionIsVisible && component.actionTitle == nil
            let slideTransition: ComponentTransition = previousInputIsVisible != nil && previousInputIsVisible != mainActionIsVisible && transition.animation.isImmediate ? .spring(duration: 0.4) : transition
            let slideOffset: CGFloat = panelSlidesOut ? component.hiddenActionOffset : 0.0
            let inputPanelFrame = CGRect(origin: CGPoint(x: -inputPanelInset, y: accessoryOffset), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    shareScreenSetFadeVisible(inputPanelView, isVisible: mainActionIsVisible, transition: .immediate)
                    self.addSubview(inputPanelView)
                }
                let visibilityTransition: ComponentTransition
                if let previousInputIsVisible, previousInputIsVisible != mainActionIsVisible {
                    visibilityTransition = .easeInOut(duration: 0.2)
                } else {
                    visibilityTransition = transition
                }
                shareScreenSetFadeVisible(inputPanelView, isVisible: mainActionIsVisible || panelSlidesOut, transition: visibilityTransition)
                inputPanelView.accessibilityElementsHidden = !mainActionIsVisible
                if slideTransition.animation.isImmediate || previousInputIsVisible == mainActionIsVisible {
                    transition.setPosition(view: inputPanelView, position: inputPanelFrame.center.offsetBy(dx: 0.0, dy: slideOffset))
                } else {
                    slideTransition.setPosition(view: inputPanelView, position: inputPanelFrame.center.offsetBy(dx: 0.0, dy: slideOffset))
                }
                transition.setBounds(view: inputPanelView, bounds: CGRect(origin: .zero, size: inputPanelFrame.size))
                let inputIsEnabled = mainActionIsVisible && !component.isSending
                if !inputIsEnabled {
                    // Both resigning first responder and disabling interaction can
                    // synchronously update the text field's component state.
                    Queue.mainQueue().justDispatch { [weak self] in
                        guard let self, let component = self.component, (component.actionBadge ?? 0) == 0 || component.isSending else {
                            return
                        }
                        (self.inputPanel.view as? MessageInputPanelComponent.View)?.deactivateInput(force: true)
                        // Deactivation can trigger another layout; use its latest state.
                        if let component = self.component {
                            let isVisible = (component.actionBadge ?? 0) > 0
                            self.inputPanel.view?.isUserInteractionEnabled = isVisible && !component.isSending
                        }
                    }
                } else {
                    inputPanelView.isUserInteractionEnabled = inputIsEnabled
                }
            }
            if mainActionIsVisible || self.isHidingPanel {
                contentHeight += inputPanelSize.height
                if component.showsActionButton { contentHeight += 8.0 }
            }

            let buttonIsVisible = mainActionIsVisible || component.actionTitle != nil
            let buttonTitle: AnyComponentWithIdentity<Empty>
            if !buttonIsVisible, let previousTitle = self.lastButtonTitle {
                buttonTitle = previousTitle
            } else if let actionBadge = component.actionBadge, actionBadge > 0 {
                buttonTitle = AnyComponentWithIdentity(id: "send", component: AnyComponent(ButtonTextContentComponent(
                    text: component.strings.ShareMenu_Send,
                    badge: actionBadge,
                    textColor: component.theme.list.itemCheckColors.foregroundColor,
                    badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                    badgeForeground: component.theme.list.itemCheckColors.fillColor,
                    combinedAlignment: true
                )))
            } else {
                buttonTitle = AnyComponentWithIdentity(id: component.actionTitle ?? "", component: AnyComponent(Text(
                    text: component.actionTitle ?? "",
                    font: Font.semibold(17.0),
                    color: component.theme.list.itemCheckColors.foregroundColor
                )))
            }

            if buttonIsVisible { self.lastButtonTitle = buttonTitle }
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
                    isEnabled: !component.isSending,
                    displaysProgress: component.isSending && component.showsProgress,
                    action: { [weak self] in
                        self?.send()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 50.0)
            )
            let actionButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if component.actionOptions != nil && actionButtonView.gestureRecognizers?.contains(where: { $0 is UILongPressGestureRecognizer }) != true {
                    actionButtonView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.actionLongPressed(_:))))
                }
                if actionButtonView.superview == nil {
                    actionButtonView.layer.rasterizationScale = UIScreenScale
                    actionButtonView.layer.shouldRasterize = true
                    self.addSubview(actionButtonView)
                }
                let buttonFrame = actionButtonFrame.offsetBy(dx: 0.0, dy: component.showsActionButton && !panelSlidesOut ? 0.0 : component.hiddenActionOffset)
                if previousInputIsVisible != nil && previousInputIsVisible != mainActionIsVisible && component.showsActionButton {
                    slideTransition.setFrame(view: actionButtonView, frame: buttonFrame)
                } else {
                    transition.setFrame(view: actionButtonView, frame: buttonFrame)
                }
                actionButtonView.isUserInteractionEnabled = component.showsActionButton && buttonIsVisible
                actionButtonView.accessibilityElementsHidden = !component.showsActionButton || !buttonIsVisible
                actionButtonView.isAccessibilityElement = component.showsActionButton && buttonIsVisible
                actionButtonView.accessibilityTraits = .button
                actionButtonView.accessibilityLabel = mainActionIsVisible ? component.strings.ShareMenu_Send : component.actionTitle
                actionButtonView.accessibilityValue = component.actionBadge.map(String.init)
                let visibilityTransition: ComponentTransition = previousInputIsVisible != nil && previousInputIsVisible != mainActionIsVisible ? .easeInOut(duration: 0.2) : transition
                visibilityTransition.setAlpha(view: actionButtonView, alpha: buttonIsVisible || panelSlidesOut ? 1.0 : 0.0)
            }

            let inlineBadgeIsVisible = component.inlineSendButton
            if let sendButtonView = (self.inputPanel.view as? MessageInputPanelComponent.View)?.inputActionButtonView {
                if self.inlineBadge.superview !== sendButtonView {
                    self.inlineBadge.alpha = 0.0
                    sendButtonView.addSubview(self.inlineBadge)
                }
                if let actionBadge = component.actionBadge {
                    self.inlineBadgeValue = "\(actionBadge)"
                }
                let badgeTextSize = self.inlineBadgeText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: self.inlineBadgeValue, font: Font.with(size: 11.0, weight: .semibold, traits: .monospacedNumbers), textColor: component.theme.list.itemCheckColors.foregroundColor)),
                        horizontalAlignment: .center
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 18.0)
                )
                self.inlineBadge.backgroundColor = component.theme.list.itemCheckColors.fillColor
                self.inlineBadge.layer.cornerRadius = 9.0
                self.inlineBadge.clipsToBounds = true
                self.inlineBadge.layer.borderWidth = 1.5
                self.inlineBadge.layer.borderColor = component.theme.list.modalPlainBackgroundColor.cgColor
                self.inlineBadge.isUserInteractionEnabled = false
                let badgeWidth = max(18.0, badgeTextSize.width + 8.0)
                self.inlineBadge.bounds = CGRect(origin: .zero, size: CGSize(width: badgeWidth, height: 18.0))
                if let textView = self.inlineBadgeText.view {
                    if textView.superview !== self.inlineBadge {
                        textView.isUserInteractionEnabled = false
                        self.inlineBadge.addSubview(textView)
                    }
                    textView.frame = CGRect(x: floorToScreenPixels((badgeWidth - badgeTextSize.width) * 0.5), y: floorToScreenPixels((18.0 - badgeTextSize.height) * 0.5), width: badgeTextSize.width, height: badgeTextSize.height)
                }
                self.inlineBadge.center = CGPoint(x: 1.0, y: 10.0)
                let badgeTransition: ComponentTransition = previousInputIsVisible != nil && previousInputIsVisible != mainActionIsVisible ? .easeInOut(duration: 0.2) : transition
                badgeTransition.setAlpha(view: self.inlineBadge, alpha: inlineBadgeIsVisible ? 1.0 : 0.0)
            }
            contentHeight += component.showsActionButton && (mainActionIsVisible || component.actionTitle != nil) ? actionButtonSize.height : 0.0

            if mainActionIsVisible {
                self.lastVisibleHeight = contentHeight
            } else if self.isHidingPanel {
                contentHeight = max(contentHeight, self.lastVisibleHeight)
            }

            if abs(component.panelState.height - contentHeight) > 0.5 {
                component.panelState.height = contentHeight
                // Notify the parent after this component update has finished. Queue.async
                // executes immediately when already on the main queue.
                Queue.mainQueue().justDispatch { [weak panelState = component.panelState] in panelState?.heightUpdated?() }
            }
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

final class SearchInputPanelComponent: Component {
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
    let isVisible: Bool
    let isSearching: Bool
    let tabs: [HorizontalTabsComponent.Tab]
    let selectedTab: Int32
    let activated: () -> Void
    let createGroup: () -> Void
    let groupTooltip: (UIView) -> Void
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
        isVisible: Bool,
        isSearching: Bool,
        tabs: [HorizontalTabsComponent.Tab] = [],
        selectedTab: Int32 = 0,
        activated: @escaping () -> Void,
        createGroup: @escaping () -> Void,
        groupTooltip: @escaping (UIView) -> Void,
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
        self.isVisible = isVisible
        self.isSearching = isSearching
        self.tabs = tabs
        self.selectedTab = selectedTab
        self.activated = activated
        self.createGroup = createGroup
        self.groupTooltip = groupTooltip
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
        if lhs.isVisible != rhs.isVisible { return false }
        if lhs.isSearching != rhs.isSearching { return false }
        if lhs.tabs != rhs.tabs || lhs.selectedTab != rhs.selectedTab { return false }
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
        private var containerView: GlassBackgroundContainerView
        private var fieldBackgroundView: GlassBackgroundView
        private var tabsBackground: GlassBackgroundView?
        private var tabsContainer: GlassBackgroundContainerView?
        private var tabs = ComponentView<Empty>()

        private var pagerSelectedTab: Int32?

        func updateTabSwitchFraction(_ fraction: CGFloat, selectedTab: Int32?, isDragging: Bool, transition: ComponentTransition = .immediate) {
            self.pagerSelectedTab = selectedTab
            if let component = self.component, let view = self.tabs.view {
                let _ = self.tabs.update(transition: transition, component: AnyComponent(HorizontalTabsComponent(
                    context: component.context, theme: component.theme, tabs: component.tabs,
                    selectedTab: AnyHashable(selectedTab ?? component.selectedTab), isEditing: false
                )), environment: {}, containerSize: view.bounds.size)
            }
            (self.tabs.view as? HorizontalTabsComponent.View)?.updateTabSwitchFraction(fraction: fraction, isDragging: isDragging, transition: transition)
        }

        private let icon = ComponentView<Empty>()
        private var placeholder = ComponentView<Empty>()

        private let textField: TextField
        private let clearButton = ComponentView<Empty>()

        private var cancelSearchButton = ComponentView<Empty>()
        private var createGroupButton = ComponentView<Empty>()
        private var displayedGroupTooltip = false

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

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            self.component?.activated()
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
            self.isUserInteractionEnabled = component.isVisible
            self.accessibilityElementsHidden = !component.isVisible

            let rebuildGlass = previousComponent?.isVisible == false && component.isVisible
            if rebuildGlass {
                // A native glass group can retain shadow contributions after
                // its effects are hidden and restored. Retire the entire group,
                // including button effects and the tabs' lifted overlay.
                self.containerView.removeFromSuperview()
                self.containerView = GlassBackgroundContainerView()
                self.fieldBackgroundView = GlassBackgroundView()
                self.tabsBackground = nil
                self.tabsContainer?.removeFromSuperview()
                self.tabsContainer = nil
                self.tabs = ComponentView<Empty>()
                self.cancelSearchButton = ComponentView<Empty>()
                self.createGroupButton = ComponentView<Empty>()
                self.insertSubview(self.containerView, at: 0)
                self.containerView.contentView.addSubview(self.fieldBackgroundView)
            }
            let glassTransition: ComponentTransition = rebuildGlass ? .immediate : transition

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

            if previousComponent?.isSearching == true && !component.isSearching && !(self.textField.text ?? "").isEmpty {
                self.textField.text = ""
            }

            let themeUpdated = component.theme !== previousComponent?.theme

            if themeUpdated {
                self.textField.accessibilityLabel = component.strings.Common_Search
                self.textField.font = Font.regular(17.0)
                self.textField.textColor = component.theme.list.itemPrimaryTextColor
                self.textField.keyboardAppearance = component.theme.overallDarkAppearance ? .dark : .light
            }

            let backgroundColor = component.theme.list.plainBackgroundColor.withMultipliedAlpha(0.75)

            let edgeInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
            let fieldHeight: CGFloat = 44.0
            let buttonSpacing: CGFloat = 10.0
            let showsTabs = component.isSearching && !component.tabs.isEmpty
            let size = CGSize(width: availableSize.width, height: showsTabs ? 100.0 : edgeInsets.top + fieldHeight + edgeInsets.bottom)
            glassTransition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: size))
            self.containerView.update(size: size, isDark: component.theme.overallDarkAppearance, transition: glassTransition)

            var rightButtonWidth: CGFloat = 44.0
            let rightButtonContent: AnyComponentWithIdentity<Empty>
            if component.groupPeers.count > 1 {
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


            let activeButtonWidth: CGFloat = component.isSearching ? 44.0 : rightButtonWidth
            let cancelButtonFrame = CGRect(x: availableSize.width - edgeInsets.right - activeButtonWidth, y: edgeInsets.top, width: activeButtonWidth, height: 44.0)
            for isCancel in [false, true] {
                let button = isCancel ? self.cancelSearchButton : self.createGroupButton
                let buttonSize = CGSize(width: isCancel ? 44.0 : rightButtonWidth, height: 44.0)
                let isVisible = component.isVisible && component.isSearching == isCancel
                let isShown = component.isSearching == isCancel
                let content = isCancel ? AnyComponentWithIdentity(id: "close", component: AnyComponent(
                    BundleIconComponent(name: "Navigation/Close", tintColor: component.theme.chat.inputPanel.panelControlColor)
                )) : rightButtonContent
                let buttonTransition: ComponentTransition = button.view == nil ? .immediate : transition
                let _ = button.update(
                    transition: buttonTransition,
                    component: AnyComponent(GlassBarButtonComponent(
                        size: buttonSize,
                        backgroundColor: backgroundColor,
                        isDark: component.theme.overallDarkAppearance,
                        state: .glass,
                        isVisible: component.isVisible,
                        component: content,
                        action: { [weak self] _ in
                            guard let self, let component = self.component, component.isVisible, component.isSearching == isCancel else { return }
                            if isCancel {
                                let _ = self.deactivateInput()
                                self.setText(text: "", updateState: false)
                                component.cancel()
                            } else {
                                component.createGroup()
                            }
                        }
                    )),
                    environment: {},
                    containerSize: buttonSize
                )
                if let view = button.view {
                    if view.superview == nil { self.containerView.contentView.addSubview(view) }
                    shareScreenSetFadeVisible(view, isVisible: isShown, blurRadius: 8.0, transition: buttonTransition)
                    buttonTransition.setFrame(view: view, frame: CGRect(x: availableSize.width - edgeInsets.right - buttonSize.width, y: edgeInsets.top, width: buttonSize.width, height: buttonSize.height))
                    view.isUserInteractionEnabled = isVisible
                    view.isAccessibilityElement = isVisible
                    view.accessibilityElementsHidden = !isVisible
                    view.accessibilityTraits = .button
                    view.accessibilityLabel = isCancel ? component.strings.Common_Close : component.strings.ShareScreen_CreateGroupTooltip
                }
            }

            let fieldFrame = CGRect(origin: CGPoint(x: edgeInsets.left, y: edgeInsets.top), size: CGSize(width: max(0.0, cancelButtonFrame.minX - buttonSpacing - edgeInsets.left), height: fieldHeight))

            self.fieldBackgroundView.update(size: fieldFrame.size, cornerRadius: fieldFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, isVisible: component.isVisible, transition: glassTransition)
            glassTransition.setFrame(view: self.fieldBackgroundView, frame: fieldFrame)

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

            if component.isVisible && !component.isSearching && component.groupPeers.count > 1 && !self.displayedGroupTooltip {
                self.displayedGroupTooltip = true
                Queue.mainQueue().justDispatch { [weak self] in
                    guard let self, let component = self.component, component.isVisible, !component.isSearching, let view = self.createGroupButton.view, view.window != nil else { return }
                    component.groupTooltip(view)
                }
            }

            if showsTabs {
                let tabsBackground: GlassBackgroundView
                var backgroundTransition = transition
                if let current = self.tabsBackground {
                    tabsBackground = current
                } else {
                    // Reusing a detached native glass effect retains its old
                    // shadow contribution when it rejoins the effect group.
                    tabsBackground = GlassBackgroundView()
                    self.tabsBackground = tabsBackground
                    let tabsContainer = GlassBackgroundContainerView()
                    self.tabsContainer = tabsContainer
                    self.insertSubview(tabsContainer, aboveSubview: self.containerView)
                    tabsContainer.contentView.addSubview(tabsBackground)
                    backgroundTransition = .immediate
                    shareScreenSetFadeVisible(tabsContainer, isVisible: false, transition: .immediate)
                }
                if let tabsContainer = self.tabsContainer {
                    tabsContainer.frame = CGRect(origin: .zero, size: size)
                    tabsContainer.update(size: size, isDark: component.theme.overallDarkAppearance, transition: .immediate)
                    shareScreenSetFadeVisible(tabsContainer, isVisible: component.isVisible, blurRadius: 8.0, transition: transition)
                }
                let tabsTransition: ComponentTransition = previousComponent?.isSearching == true && previousComponent?.selectedTab != component.selectedTab ? .spring(duration: 0.35) : transition
                let tabsSize = self.tabs.update(transition: tabsTransition, component: AnyComponent(HorizontalTabsComponent(
                    context: component.context, theme: component.theme, tabs: component.tabs,
                    selectedTab: AnyHashable(self.pagerSelectedTab ?? component.selectedTab), isEditing: false
                )), environment: {}, containerSize: CGSize(width: availableSize.width - 32.0, height: 40.0))
                backgroundTransition.setFrame(view: tabsBackground, frame: CGRect(x: 16.0, y: 56.0, width: tabsSize.width, height: tabsSize.height))
                tabsBackground.update(size: tabsSize, cornerRadius: 20.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, isVisible: true, transition: backgroundTransition)
                if let view = self.tabs.view {
                    if view.superview !== tabsBackground.contentView {
                        tabsBackground.contentView.addSubview(view)
                        (view as? HorizontalTabsComponent.View)?.setOverlayContainerView(overlayContainerView: self.tabsContainer?.contentView ?? self.containerView.contentView)
                    }
                    view.frame = CGRect(origin: .zero, size: tabsSize)
                }
                tabsBackground.isUserInteractionEnabled = component.isVisible
                tabsBackground.accessibilityElementsHidden = !component.isVisible
            } else if let tabsBackground = self.tabsBackground {
                self.tabsBackground = nil
                tabsBackground.isUserInteractionEnabled = false
                tabsBackground.accessibilityElementsHidden = true
                if let tabsContainer = self.tabsContainer {
                    self.tabsContainer = nil
                    tabsContainer.isUserInteractionEnabled = false
                    shareScreenSetFadeVisible(tabsContainer, isVisible: false, blurRadius: 8.0, transition: transition)
                    transition.attachAnimation(view: tabsContainer, id: "remove", completion: { [weak tabsContainer] _ in
                        tabsContainer?.removeFromSuperview()
                    })
                }
            }

            if rebuildGlass {
                transition.animateAlpha(view: self.containerView, from: 0.0, to: 1.0)
            }
            for view in [self.textField, self.icon.view, self.placeholder.view, self.clearButton.view].compactMap({ $0 }) {
                transition.setAlpha(view: view, alpha: component.isVisible ? 1.0 : 0.0)
            }
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

final class MergedAvatarsComponent: Component {
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

            let visiblePeers = Array(component.peers.prefix(3))
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

final class ShareScreenBarButtonComponent: Component {
    let theme: PresentationTheme
    let title: String
    let icon: String
    let isVisible: Bool
    let action: () -> Void

    init(theme: PresentationTheme, title: String, icon: String, isVisible: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.icon = icon
        self.isVisible = isVisible
        self.action = action
    }

    static func ==(lhs: ShareScreenBarButtonComponent, rhs: ShareScreenBarButtonComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title && lhs.icon == rhs.icon && lhs.isVisible == rhs.isVisible
    }

    final class View: UIView {
        private let button = ComponentView<Empty>()
        func update(component: ShareScreenBarButtonComponent, transition: ComponentTransition) -> CGSize {
            self.isUserInteractionEnabled = component.isVisible
            self.accessibilityElementsHidden = !component.isVisible
            let size = CGSize(width: 44.0, height: 44.0)
            let _ = self.button.update(transition: transition, component: AnyComponent(GlassBarButtonComponent(size: size, backgroundColor: nil, isDark: component.theme.overallDarkAppearance, state: .glass, isVisible: true, component: AnyComponentWithIdentity(id: component.icon, component: AnyComponent(BundleIconComponent(name: component.icon, tintColor: component.theme.list.itemPrimaryTextColor))), action: { _ in component.action() })), environment: {}, containerSize: size)
            if let view = self.button.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(origin: .zero, size: size))
                shareScreenSetFadeVisible(view, isVisible: component.isVisible, blurRadius: 8.0, transition: transition)
                view.isAccessibilityElement = true
                view.accessibilityLabel = component.title
                view.accessibilityTraits = .button
            }
            return size
        }
    }
    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, transition: transition)
    }
}

final class ShareScreenFadeComponent: Component {
    let content: AnyComponent<Empty>
    let isVisible: Bool

    init(content: AnyComponent<Empty>, isVisible: Bool) {
        self.content = content
        self.isVisible = isVisible
    }

    static func ==(lhs: ShareScreenFadeComponent, rhs: ShareScreenFadeComponent) -> Bool {
        return lhs.content == rhs.content && lhs.isVisible == rhs.isVisible
    }

    final class View: UIView {
        private let content = ComponentView<Empty>()

        func update(component: ShareScreenFadeComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.isUserInteractionEnabled = component.isVisible
            self.accessibilityElementsHidden = !component.isVisible
            let size = self.content.update(transition: transition, component: component.content, environment: {}, containerSize: availableSize)
            if let view = self.content.view {
                if view.superview == nil { self.addSubview(view) }
                transition.setFrame(view: view, frame: CGRect(origin: .zero, size: size))
                shareScreenSetFadeVisible(view, isVisible: component.isVisible, blurRadius: 8.0, transition: transition)
            }
            return size
        }
    }

    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class ShareScreenCheckOptionComponent: Component {
    let theme: PresentationTheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(theme: PresentationTheme, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    static func ==(lhs: ShareScreenCheckOptionComponent, rhs: ShareScreenCheckOptionComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title && lhs.isSelected == rhs.isSelected
    }

    final class View: UIControl {
        private var checkNode: CheckNode?
        private let titleLabel = ComponentView<Empty>()
        private var component: ShareScreenCheckOptionComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.component?.action()
        }

        func update(component: ShareScreenCheckOptionComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previous = self.component
            self.component = component
            let checkTheme = CheckNodeTheme(backgroundColor: component.theme.list.itemCheckColors.fillColor, strokeColor: component.theme.list.itemCheckColors.foregroundColor, borderColor: component.theme.list.itemCheckColors.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false)
            let checkNode: CheckNode
            if let current = self.checkNode {
                checkNode = current
                if previous?.theme !== component.theme {
                    checkNode.theme = checkTheme
                }
            } else {
                checkNode = CheckNode(theme: checkTheme, content: .check(isRectangle: false))
                checkNode.isUserInteractionEnabled = false
                self.checkNode = checkNode
                self.addSubview(checkNode.view)
            }
            let checkSize: CGFloat = 18.0
            let spacing: CGFloat = 8.0
            let titleSize = self.titleLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor)),
                    truncationType: .end
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, availableSize.width - checkSize - spacing), height: 100.0)
            )
            let size = CGSize(width: min(availableSize.width, checkSize + spacing + titleSize.width), height: 36.0)
            checkNode.frame = CGRect(x: 0.0, y: floor((size.height - checkSize) * 0.5), width: checkSize, height: checkSize)
            checkNode.setSelected(component.isSelected, animated: previous != nil && !transition.animation.isImmediate)
            if let titleView = self.titleLabel.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = CGRect(x: checkSize + spacing, y: floor((size.height - titleSize.height) * 0.5), width: titleSize.width, height: titleSize.height)
            }
            self.accessibilityLabel = component.title
            self.accessibilityValue = component.isSelected ? "1" : "0"
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
