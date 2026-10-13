import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import TextFieldComponent
import TextFormat
import ChatEntityKeyboardInputNode
import ChatPresentationInterfaceState
import MessageInputPanelComponent
import GlassBackgroundComponent
import GlassBarButtonComponent
import ListItemComponentAdaptor
import CheckNode
import UndoUI

private final class GiftMessagePublicToggleComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let wallpaper: TelegramWallpaper
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        wallpaper: TelegramWallpaper,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.wallpaper = wallpaper
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    static func ==(lhs: GiftMessagePublicToggleComponent, rhs: GiftMessagePublicToggleComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let backgroundNode: NavigationBackgroundNode
        private let checkNode: CheckNode
        private let textNode: ImmediateTextNode

        private var component: GiftMessagePublicToggleComponent?

        override init(frame: CGRect) {
            self.backgroundNode = NavigationBackgroundNode(color: .clear)
            self.checkNode = CheckNode(theme: CheckNodeTheme(
                backgroundColor: .white,
                strokeColor: .clear,
                borderColor: .white,
                overlayBorder: false,
                hasInset: false,
                hasShadow: false,
                borderWidth: 1.5
            ))
            self.textNode = ImmediateTextNode()

            super.init(frame: frame)

            self.isExclusiveTouch = true
            self.backgroundNode.view.isUserInteractionEnabled = false
            self.checkNode.isUserInteractionEnabled = false
            self.textNode.isUserInteractionEnabled = false
            self.textNode.displaysAsynchronously = false

            self.addSubview(self.backgroundNode.view)
            self.addSubview(self.checkNode.view)
            self.addSubview(self.textNode.view)

            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                let transition: ComponentTransition = highlighted ? .immediate : .easeInOut(duration: 0.2)
                transition.setAlpha(view: self, alpha: highlighted ? 0.7 : 1.0)
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        @objc private func pressed() {
            self.component?.action()
        }

        func update(component: GiftMessagePublicToggleComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component

            let foregroundColor = UIColor.white
            self.checkNode.theme = CheckNodeTheme(
                backgroundColor: foregroundColor,
                strokeColor: .clear,
                borderColor: foregroundColor,
                overlayBorder: false,
                hasInset: false,
                hasShadow: false,
                borderWidth: 1.5
            )
            if previousComponent?.isSelected != component.isSelected {
                self.checkNode.setSelected(component.isSelected, animated: previousComponent != nil && !transition.animation.isImmediate)
            }

            self.textNode.attributedText = NSAttributedString(
                string: component.title,
                font: Font.medium(13.0),
                textColor: foregroundColor
            )
            let textSize = self.textNode.updateLayout(CGSize(width: max(0.0, availableSize.width - 48.0), height: 30.0))
            let size = CGSize(width: ceil(textSize.width) + 48.0, height: 30.0)

            let backgroundColor = selectDateFillStaticColor(theme: component.theme, wallpaper: component.wallpaper)
            let enableBlur = component.context.sharedContext.energyUsageSettings.fullTranslucency && dateFillNeedsBlur(theme: component.theme, wallpaper: component.wallpaper)
            self.backgroundNode.updateColor(
                color: backgroundColor,
                enableBlur: enableBlur,
                transition: transition.containedViewLayoutTransition
            )
            self.backgroundNode.update(
                size: size,
                cornerRadius: size.height * 0.5,
                transition: transition.containedViewLayoutTransition
            )
            transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: .zero, size: size))

            let padding: CGFloat = 6.0
            let spacing: CGFloat = 9.0
            let checkSize = CGSize(width: 18.0, height: 18.0)
            transition.setFrame(
                view: self.checkNode.view,
                frame: CGRect(origin: CGPoint(x: padding, y: padding), size: checkSize)
            )
            let textOriginX = max(
                padding + checkSize.width + spacing,
                padding + checkSize.width + floor((size.width - padding - checkSize.width - textSize.width) * 0.5) - 2.0
            )
            transition.setFrame(
                view: self.textNode.view,
                frame: CGRect(
                    origin: CGPoint(x: textOriginX, y: floorToScreenPixels((size.height - textSize.height) * 0.5)),
                    size: textSize
                )
            )

            self.accessibilityLabel = component.title
            self.accessibilityValue = component.isSelected ? "1" : "0"
            self.accessibilityTraits = component.isSelected ? [.button, .selected] : [.button]

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

private final class GiftMessageScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let gift: StarGift.UniqueGift
    let dismissOnCompletion: Bool
    let completion: (GiftMessageScreen.Result) -> Void

    init(
        context: AccountContext,
        peer: EnginePeer,
        gift: StarGift.UniqueGift,
        dismissOnCompletion: Bool,
        completion: @escaping (GiftMessageScreen.Result) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.gift = gift
        self.dismissOnCompletion = dismissOnCompletion
        self.completion = completion
    }

    static func ==(lhs: GiftMessageScreenComponent, rhs: GiftMessageScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.peer == rhs.peer && lhs.gift == rhs.gift && lhs.dismissOnCompletion == rhs.dismissOnCompletion
    }

    final class View: UIView {
        private let dimView = UIView()
        private let containerView = UIView()
        private let closeButton = ComponentView<Empty>()
        private let preview = ComponentView<Empty>()
        private let publicToggle = ComponentView<Empty>()
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        private let inputPanelBackground = GlassBackgroundContainerView()

        private var component: GiftMessageScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating = false
        private var isCommitted = false
        private var makePublic = false

        private var accountPeer: EnginePeer?
        private var accountPeerDisposable: Disposable?

        private var currentInputMode: MessageInputPanelComponent.InputMode = .text
        private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
        private var inputMediaNodeDataDisposable: Disposable?
        private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
        private var inputMediaNode: ChatEntityKeyboardInputNode?
        private var isInputMediaNodeAnimatingOut = false
        private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        private var previousInputHeight: CGFloat?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissPressed)))
            self.addSubview(self.dimView)

            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 38.0
            self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.addSubview(self.containerView)

        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        deinit {
            self.accountPeerDisposable?.dispose()
            self.inputMediaNodeDataDisposable?.dispose()
        }

        @objc private func dismissPressed() {
            self.environment?.controller()?.dismiss()
        }

        @objc private func publicTogglePressed() {
            self.makePublic = !self.makePublic
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }

        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.containerView.layer.animatePosition(
                from: CGPoint(x: 0.0, y: self.bounds.height),
                to: CGPoint(),
                duration: 0.5,
                timingFunction: kCAMediaTimingFunctionSpring,
                additive: true
            )
        }

        func animateOut(completion: @escaping () -> Void) {
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.containerView.layer.animatePosition(
                from: CGPoint(),
                to: CGPoint(x: 0.0, y: self.bounds.height),
                duration: 0.3,
                timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue,
                removeOnCompletion: false,
                additive: true,
                completion: { _ in completion() }
            )
        }

        private func setup(component: GiftMessageScreenComponent) {
            self.accountPeerDisposable = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                self.accountPeer = peer
                self.state?.updated()
            })

            self.inputMediaNodeDataPromise.set(
                ChatEntityKeyboardInputNode.inputData(
                    context: component.context,
                    chatPeerId: nil,
                    areCustomEmojiEnabled: true,
                    hasTrending: false,
                    hasSearch: true,
                    hasStickers: false,
                    hasGifs: false,
                    hideBackground: true,
                    maskEdge: .clip,
                    forceHasPremium: true,
                    sendGif: nil
                )
            )
            self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                self?.inputMediaNodeData = value
            })

            self.inputMediaInteraction = ChatEntityKeyboardInputNode.Interaction(
                sendSticker: { _, _, _, _, _, _, _, _, _ in false },
                sendEmoji: { _, _, _ in },
                sendGif: { _, _, _, _, _ in false },
                sendBotContextResultAsGif: { _, _, _, _, _, _ in false },
                editGif: { _, _ in },
                updateChoosingSticker: { _ in },
                switchToTextInput: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.currentInputMode = .text
                    self.activateInput()
                },
                dismissTextInput: {},
                insertText: { [weak self] text in
                    self?.inputPanelExternalState.insertText(text)
                },
                backwardsDeleteText: { [weak self] in
                    self?.inputPanelExternalState.deleteBackward()
                },
                openStickerEditor: {},
                presentController: { [weak self] controller, arguments in
                    self?.environment?.controller()?.present(controller, in: .window(.root), with: arguments)
                },
                presentGlobalOverlayController: { [weak self] controller, arguments in
                    self?.environment?.controller()?.presentInGlobalOverlay(controller, with: arguments)
                },
                getNavigationController: { [weak self] in
                    return self?.environment?.controller()?.navigationController as? NavigationController
                },
                requestLayout: { [weak self] transition in
                    guard let self, !self.isUpdating else {
                        return
                    }
                    self.state?.updated(transition: ComponentTransition(transition))
                }
            )
        }

        private func currentText(applyAutocorrection: Bool) -> NSAttributedString {
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View,
                  case let .text(text) = inputPanelView.getSendMessageInput(applyAutocorrection: applyAutocorrection) else {
                return NSAttributedString()
            }
            return text
        }

        private func commit() {
            guard !self.isCommitted, let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, !inputPanelView.canDeactivateInput() {
                return
            }
            self.isCommitted = true

            let inputText = self.currentText(applyAutocorrection: true)
            let result: GiftMessageScreen.Result
            if inputText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result = GiftMessageScreen.Result(hideName: !self.makePublic, text: nil, entities: nil)
            } else {
                let entities = generateChatInputTextEntities(inputText)
                result = GiftMessageScreen.Result(
                    hideName: !self.makePublic,
                    text: inputText.string,
                    entities: entities.isEmpty ? nil : entities
                )
            }

            if component.dismissOnCompletion {
                controller.dismiss(completion: {
                    component.completion(result)
                })
            } else {
                if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View {
                    inputPanelView.deactivateInput(force: true)
                }
                self.isCommitted = false
                component.completion(result)
            }
        }

        private func activateInput() {
            self.currentInputMode = .text
            if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, !inputPanelView.isActive {
                inputPanelView.activateInput()
            } else {
                self.state?.updated(transition: .immediate)
            }
        }

        private func updateInputMediaNode(
            component: GiftMessageScreenComponent,
            availableSize: CGSize,
            bottomInset: CGFloat,
            metrics: LayoutMetrics,
            deviceMetrics: DeviceMetrics,
            transition: ComponentTransition
        ) -> CGFloat {
            guard case .emoji = self.currentInputMode, let inputData = self.inputMediaNodeData else {
                if let inputMediaNode = self.inputMediaNode {
                    self.inputMediaNode = nil
                    self.isInputMediaNodeAnimatingOut = true
                    var targetFrame = inputMediaNode.frame
                    targetFrame.origin.y = availableSize.height
                    let removalTransition: ComponentTransition = transition.animation.isImmediate ? .easeInOut(duration: 0.3) : transition
                    removalTransition.setFrame(view: inputMediaNode.view, frame: targetFrame, completion: { [weak self, weak inputMediaNode] _ in
                        inputMediaNode?.view.removeFromSuperview()
                        guard let self else {
                            return
                        }
                        self.isInputMediaNodeAnimatingOut = false
                        self.state?.updated(transition: .immediate)
                    })
                }
                return 0.0
            }

            let inputMediaNode: ChatEntityKeyboardInputNode
            var animateIn = false
            if let current = self.inputMediaNode {
                inputMediaNode = current
            } else {
                animateIn = true
                inputMediaNode = ChatEntityKeyboardInputNode(
                    context: component.context,
                    currentInputData: inputData,
                    updatedInputData: self.inputMediaNodeDataPromise.get(),
                    defaultToEmojiTab: true,
                    opaqueTopPanelBackground: false,
                    useOpaqueTheme: false,
                    interaction: self.inputMediaInteraction,
                    chatPeerId: nil,
                    stateContext: self.inputMediaNodeStateContext,
                    forceHasPremium: true
                )
                inputMediaNode.clipsToBounds = true
                inputMediaNode.externalTopPanelContainerImpl = nil
                inputMediaNode.useExternalSearchContainer = true
                self.addSubview(inputMediaNode.view)
                self.inputMediaNode = inputMediaNode
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let interfaceState = ChatPresentationInterfaceState(
                chatWallpaper: .builtin(WallpaperSettings()),
                theme: presentationData.theme,
                preferredGlassType: .default,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                limitsConfiguration: component.context.currentLimitsConfiguration.with { $0 },
                fontSize: presentationData.chatFontSize,
                bubbleCorners: presentationData.chatBubbleCorners,
                accountPeerId: component.context.account.peerId,
                mode: .standard(.default),
                chatLocation: .peer(id: component.context.account.peerId),
                subject: nil,
                greetingData: nil,
                pendingUnpinnedAllMessages: false,
                activeGroupCallInfo: nil,
                hasActiveGroupCall: false,
                threadData: nil,
                isGeneralThreadClosed: nil,
                replyMessage: nil,
                accountPeerColor: nil,
                businessIntro: nil
            )
            let heightAndOverflow = inputMediaNode.updateLayout(
                width: availableSize.width,
                leftInset: 0.0,
                rightInset: 0.0,
                bottomInset: bottomInset + 8.0,
                standardInputHeight: deviceMetrics.standardInputHeight(inLandscape: false),
                inputHeight: 0.0,
                maximumHeight: availableSize.height,
                inputPanelHeight: 0.0,
                transition: .immediate,
                interfaceState: interfaceState,
                layoutMetrics: metrics,
                deviceMetrics: deviceMetrics,
                isVisible: true,
                isExpanded: false
            )
            let height = heightAndOverflow.0
            let inputMediaNodeFrame = CGRect(x: 0.0, y: availableSize.height - height, width: availableSize.width, height: height)
            if animateIn {
                var initialFrame = inputMediaNodeFrame
                initialFrame.origin.y = availableSize.height
                ComponentTransition.immediate.setFrame(view: inputMediaNode.view, frame: initialFrame)
            }
            transition.setFrame(view: inputMediaNode.view, frame: inputMediaNodeFrame)
            return height
        }

        func update(
            component: GiftMessageScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<ViewControllerComponentContainer.Environment>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            if self.component == nil {
                self.setup(component: component)
            }
            self.component = component
            self.state = state
            self.environment = environment

            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            self.containerView.backgroundColor = environment.theme.list.blocksBackgroundColor
            transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))

            let fillingWidth: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingWidth = min(availableSize.width, 414.0)
            } else {
                fillingWidth = min(availableSize.width, availableSize.height)
            }
            let containerInset = environment.statusBarHeight + 10.0
            let containerFrame = CGRect(
                x: floor((availableSize.width - fillingWidth) * 0.5),
                y: containerInset,
                width: fillingWidth,
                height: availableSize.height - containerInset
            )
            transition.setFrame(view: self.containerView, frame: containerFrame)

            let inputMediaHeight = self.updateInputMediaNode(
                component: component,
                availableSize: availableSize,
                bottomInset: environment.safeInsets.bottom,
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                transition: transition
            )
            let inputHeight: CGFloat
            if self.inputMediaNode != nil {
                inputHeight = inputMediaHeight
            } else if self.isInputMediaNodeAnimatingOut && environment.inputHeight.isZero && self.inputPanelExternalState.isEditing, let previousInputHeight = self.previousInputHeight {
                inputHeight = previousInputHeight
            } else {
                inputHeight = environment.inputHeight
            }
            self.previousInputHeight = inputHeight

            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(
                        name: "Navigation/Close",
                        tintColor: environment.theme.chat.inputPanel.panelControlColor
                    ))),
                    action: { [weak self] _ in self?.dismissPressed() }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.containerView.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: CGRect(x: 16.0, y: 16.0, width: closeButtonSize.width, height: closeButtonSize.height))
            }

            let nextInputMode: MessageInputPanelComponent.InputMode = self.currentInputMode == .text ? .emoji : .text
            let maxLength = GiftConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 }).maxCaptionLength
            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .gift,
                    placeholder: .plain(environment.strings.Gift_Message_InputPlaceholder),
                    sendPaidMessageStars: nil,
                    maxLength: Int(maxLength),
                    queryTypes: [],
                    alwaysDarkWhenHasText: false,
                    useGrayBackground: false,
                    displayGiftSendButton: true,
                    returnKeyType: .default,
                    returnKeyAction: { [weak self] in
                        guard let self, let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                            return
                        }
                        inputPanelView.deactivateInput(force: true)
                    },
                    resetInputContents: nil,
                    nextInputMode: { _ in nextInputMode },
                    areVoiceMessagesAvailable: false,
                    presentController: { [weak self] controller in
                        self?.environment?.controller()?.present(controller, in: .window(.root))
                    },
                    presentInGlobalOverlay: { [weak self] controller in
                        self?.environment?.controller()?.presentInGlobalOverlay(controller)
                    },
                    sendMessageAction: { [weak self] _ in self?.commit() },
                    sendMessageOptionsAction: nil,
                    sendStickerAction: { _ in },
                    setMediaRecordingActive: nil,
                    lockMediaRecording: {},
                    stopAndPreviewMediaRecording: {},
                    discardMediaRecordingPreview: nil,
                    attachmentAction: nil,
                    myReaction: nil,
                    likeAction: nil,
                    likeOptionsAction: nil,
                    inputModeAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.currentInputMode == .text {
                            self.currentInputMode = .emoji
                            self.state?.updated(transition: .spring(duration: 0.4))
                        } else {
                            self.activateInput()
                        }
                    },
                    timeoutAction: nil,
                    forwardAction: nil,
                    paidMessageAction: nil,
                    moreAction: nil,
                    presentCaptionPositionTooltip: nil,
                    presentVoiceMessagesUnavailableTooltip: nil,
                    presentTextLengthLimitTooltip: {},
                    presentTextFormattingTooltip: {},
                    paste: { _ in },
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
                    hideKeyboard: self.currentInputMode == .emoji,
                    customInputView: nil,
                    forceIsEditing: self.currentInputMode == .emoji,
                    disabledPlaceholder: nil,
                    header: nil,
                    isChannel: false,
                    storyItem: nil,
                    chatLocation: nil
                )),
                environment: {},
                containerSize: CGSize(width: fillingWidth - 32.0, height: 160.0)
            )
            let effectiveBottomInset = inputHeight + (inputHeight.isZero ? environment.safeInsets.bottom : 0.0)
            let inputPanelFrame = CGRect(
                x: 16.0,
                y: containerFrame.height - effectiveBottomInset - inputPanelSize.height - 8.0,
                width: inputPanelSize.width,
                height: inputPanelSize.height
            )
            let inputBackgroundFrame = CGRect(x: inputPanelFrame.minX, y: inputPanelFrame.minY - 20.0, width: inputPanelFrame.width, height: inputPanelFrame.height + 40.0)
            self.inputPanelBackground.update(size: inputBackgroundFrame.size, isDark: environment.theme.overallDarkAppearance, transition: transition)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.containerView.addSubview(self.inputPanelBackground)
                    self.inputPanelBackground.contentView.addSubview(inputPanelView)
                }
                transition.setFrame(view: self.inputPanelBackground, frame: inputBackgroundFrame)
                transition.setFrame(view: inputPanelView, frame: CGRect(x: 0.0, y: 20.0, width: inputPanelFrame.width, height: inputPanelFrame.height))
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let publicToggleSize = self.publicToggle.update(
                transition: transition,
                component: AnyComponent(GiftMessagePublicToggleComponent(
                    context: component.context,
                    theme: environment.theme,
                    wallpaper: presentationData.chatWallpaper,
                    title: environment.strings.Gift_Message_MakePublic,
                    isSelected: self.makePublic,
                    action: { [weak self] in
                        self?.publicTogglePressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: fillingWidth - 64.0, height: 30.0)
            )
            let publicToggleFrame = CGRect(
                x: floor((fillingWidth - publicToggleSize.width) * 0.5),
                y: inputPanelFrame.minY - publicToggleSize.height - 9.0,
                width: publicToggleSize.width,
                height: publicToggleSize.height
            )
            if let publicToggleView = self.publicToggle.view {
                if publicToggleView.superview == nil {
                    self.containerView.addSubview(publicToggleView)
                }
                transition.setFrame(view: publicToggleView, frame: publicToggleFrame)
            }

            if let accountPeer = self.accountPeer {
                let inputText = self.currentText(applyAutocorrection: false)
                let hasPreviewText = !inputText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                var peers: [EnginePeer] = [accountPeer]
                if component.peer.id != accountPeer.id {
                    peers.append(component.peer)
                }
                let listItemParams = ListViewItemLayoutParams(
                    width: fillingWidth,
                    leftInset: 0.0,
                    rightInset: 0.0,
                    availableHeight: 10000.0,
                    isStandalone: true
                )
                let previewHeight = max(370.0, publicToggleFrame.minY)
                let previewSize = self.preview.update(
                    transition: transition,
                    component: AnyComponent(ListItemComponentAdaptor(
                        itemGenerator: ChatGiftPreviewItem(
                            context: component.context,
                            theme: environment.theme,
                            componentTheme: environment.theme,
                            strings: environment.strings,
                            sectionId: 0,
                            fontSize: presentationData.chatFontSize,
                            chatBubbleCorners: presentationData.chatBubbleCorners,
                            wallpaper: presentationData.chatWallpaper,
                            dateTimeFormat: environment.dateTimeFormat,
                            nameDisplayOrder: presentationData.nameDisplayOrder,
                            peers: peers,
                            subject: .uniqueGift(gift: component.gift, nameHidden: !self.makePublic),
                            chatPeerId: component.peer.id == accountPeer.id ? nil : component.peer.id,
                            text: hasPreviewText ? inputText.string : "",
                            entities: hasPreviewText ? generateChatInputTextEntities(inputText) : [],
                            upgradeStars: nil,
                            chargeStars: nil,
                            bottomInset: max(0.0, containerFrame.height - previewHeight),
                            contentHeight: previewHeight,
                            maximumBubbleBottom: publicToggleFrame.minY - 16.0,
                            action: { [weak self] in self?.commit() }
                        ),
                        params: listItemParams
                    )),
                    environment: {},
                    containerSize: CGSize(width: fillingWidth, height: containerFrame.height)
                )
                if let previewView = self.preview.view {
                    if previewView.superview == nil {
                        self.containerView.insertSubview(previewView, at: 0)
                    }
                    transition.setFrame(view: previewView, frame: CGRect(origin: .zero, size: previewSize))
                }
            }

            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 66.0, left: 0.0, bottom: 0.0, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false,
                    presentedInFormSheet: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<ViewControllerComponentContainer.Environment>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class GiftMessageScreen: ViewControllerComponentContainer {
    public struct Result {
        public let hideName: Bool
        public let text: String?
        public let entities: [MessageTextEntity]?

        public init(hideName: Bool, text: String?, entities: [MessageTextEntity]?) {
            self.hideName = hideName
            self.text = text
            self.entities = entities
        }
    }

    private let accountContext: AccountContext
    private let peer: EnginePeer
    private let gift: StarGift.UniqueGift

    private var didPlayAppearAnimation = false
    private var didPresentMessageHint = false
    private var isDismissed = false

    public init(
        context: AccountContext,
        peer: EnginePeer,
        gift: StarGift.UniqueGift,
        dismissOnCompletion: Bool = true,
        completion: @escaping (Result) -> Void
    ) {
        self.accountContext = context
        self.peer = peer
        self.gift = gift

        super.init(
            context: context,
            component: GiftMessageScreenComponent(context: context, peer: peer, gift: gift, dismissOnCompletion: dismissOnCompletion, completion: completion),
            navigationBarAppearance: .none,
            theme: .default
        )
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder: NSCoder) {
        preconditionFailure()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.disablesInteractiveModalDismiss = true
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            if let componentView = self.node.hostView.componentView as? GiftMessageScreenComponent.View {
                componentView.alpha = 0.0
                Queue.mainQueue().after(0.01, {
                    componentView.alpha = 1.0
                    componentView.animateIn()
                })
            }
        }
        if self.peer.id != self.accountContext.account.peerId && !self.didPresentMessageHint {
            self.didPresentMessageHint = true
            Queue.mainQueue().after(0.3, { [weak self] in
                guard let self, !self.isDismissed else {
                    return
                }
                self.presentMessageHint()
            })
        }
    }

    private func presentMessageHint() {
        let presentationData = self.accountContext.sharedContext.currentPresentationData.with { $0 }
        let peerTitle = self.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        let giftTitle = "\(self.gift.title) #\(formatCollectibleNumber(self.gift.number, dateTimeFormat: presentationData.dateTimeFormat))"
        let controller = UndoOverlayController(
            presentationData: presentationData,
            content: .invitedToVoiceChat(
                context: self.accountContext,
                peer: self.peer,
                title: presentationData.strings.Gift_Message_ToastTitle,
                text: presentationData.strings.Gift_Message_ToastText(peerTitle, giftTitle).string,
                action: nil,
                duration: 5.0
            ),
            elevatedLayout: false,
            position: .top,
            action: { _ in return false }
        )
        self.present(controller, in: .current)
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        guard !self.isDismissed else {
            return
        }
        self.isDismissed = true
        if let componentView = self.node.hostView.componentView as? GiftMessageScreenComponent.View {
            componentView.animateOut(completion: { [weak self] in
                completion?()
                self?.dismiss(animated: false)
            })
        } else {
            completion?()
            self.dismiss(animated: false)
        }
        self.dismissAllTooltips()
    }
}
