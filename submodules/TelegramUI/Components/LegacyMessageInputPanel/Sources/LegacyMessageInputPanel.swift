import Foundation
import UIKit
import AsyncDisplayKit
import LegacyComponents
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import ComponentFlow
import MessageInputPanelComponent
import TelegramPresentationData
import ContextUI
import TooltipUI
import UndoUI
import TelegramNotices
import TextFormat
import TelegramUIPreferences
import Pasteboard
import ChatRichTextEditorComposer
import ChatEntityKeyboardInputNode
import ChatPresentationInterfaceState

public class LegacyMessageInputPanelNode: ASDisplayNode, TGCaptionPanelView {
    private let context: AccountContext
    private let chatLocation: ChatLocation
    private let isScheduledMessages: Bool
    private let isFile: Bool
    private let hasTimer: Bool
    private let customEmojiAvailable: Bool
    private let pushViewController: (ViewController) -> Void
    private let present: (ViewController) -> Void
    private let presentInGlobalOverlay: (ViewController) -> Void
    private let getNavigationController: () -> NavigationController?

    private let state = ComponentState()
    private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
    private let inputPanel = ComponentView<Empty>()

    private var currentTimeout: Int32?
    private var currentIsEditing = false
    private var currentHeight: CGFloat?
    private var currentIsVideo = false
    private var currentIsCaptionAbove = false
    private var currentInputMode: MessageInputPanelComponent.InputMode = .text
    private var currentAdditionalInputHeight: CGFloat = 0.0
    private var currentSafeAreaInset: UIEdgeInsets = .zero
    private var currentContainerBottomInset: CGFloat = 0.0
    private var usesContainerLayout = false

    private let hapticFeedback = HapticFeedback()

    private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
    private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
    private var inputMediaNodeDataDisposable: Disposable?
    private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
    private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
    private var inputMediaNode: ChatEntityKeyboardInputNode?

    public var sendPressed: ((NSAttributedString?) -> Void)?
    public var focusUpdated: ((Bool) -> Void)?
    public var heightUpdated: ((Bool) -> Void)?
    public var timerUpdated: ((NSNumber?) -> Void)?
    public var captionIsAboveUpdated: ((Bool) -> Void)?

    public var additionalInputHeight: CGFloat {
        return self.currentAdditionalInputHeight
    }

    private weak var undoController: UndoOverlayController?
    private weak var tooltipController: TooltipScreen?

    private var isAIEnabled: Bool = false

    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, keyboardHeight: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, metrics: LayoutMetrics)?

    public init(
        context: AccountContext,
        chatLocation: ChatLocation,
        isScheduledMessages: Bool,
        isFile: Bool,
        hasTimer: Bool,
        customEmojiAvailable: Bool,
        pushViewController: @escaping (ViewController) -> Void,
        present: @escaping (ViewController) -> Void,
        presentInGlobalOverlay: @escaping (ViewController) -> Void,
        getNavigationController: @escaping () -> NavigationController?
    ) {
        self.context = context
        self.chatLocation = chatLocation
        self.isScheduledMessages = isScheduledMessages
        self.isFile = isFile
        self.hasTimer = hasTimer
        self.customEmojiAvailable = customEmojiAvailable
        self.pushViewController = pushViewController
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.getNavigationController = getNavigationController

        super.init()

        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ios_disable_ai_attach"] as? Double, value == 1.0 {
        } else if let peerId = chatLocation.peerId, peerId.namespace != Namespaces.Peer.SecretChat {
            self.isAIEnabled = true
        }

        self.inputMediaNodeDataPromise.set(
            ChatEntityKeyboardInputNode.inputData(
                context: context,
                chatPeerId: nil,
                areCustomEmojiEnabled: customEmojiAvailable,
                hasTrending: false,
                hasStickers: false,
                hasGifs: false,
                maskEdge: .clip,
                sendGif: nil
            )
        )
        self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            self.inputMediaNodeData = value
            if case .emoji = self.currentInputMode {
                self.update(transition: .immediate)
            }
        })

        self.inputMediaInteraction = ChatEntityKeyboardInputNode.Interaction(
            sendSticker: { _, _, _, _, _, _, _, _, _ in
                return false
            },
            sendEmoji: { _, _, _ in
            },
            sendGif: { _, _, _, _, _ in
                return false
            },
            sendBotContextResultAsGif: { _, _, _, _, _, _ in
                return false
            },
            editGif: { _, _ in
            },
            updateChoosingSticker: { _ in
            },
            switchToTextInput: { [weak self] in
                self?.activateInput()
            },
            dismissTextInput: {
            },
            insertText: { [weak self] text in
                self?.inputPanelExternalState.insertText(text)
            },
            backwardsDeleteText: { [weak self] in
                self?.inputPanelExternalState.deleteBackward()
            },
            openStickerEditor: {
            },
            presentController: { [weak self] controller, _ in
                guard let self else {
                    return
                }
                self.prepareForPresentedController(controller)
                self.present(controller)
            },
            presentGlobalOverlayController: { [weak self] controller, _ in
                guard let self else {
                    return
                }
                self.prepareForPresentedController(controller)
                self.presentInGlobalOverlay(controller)
            },
            getNavigationController: getNavigationController,
            requestLayout: { [weak self] transition in
                self?.update(transition: transition)
            }
        )
        self.inputMediaInteraction?.forceTheme = defaultDarkColorPresentationTheme

        self.state._updated = { [weak self] transition, _ in
            if let self {
                self.update(transition: transition.containedViewLayoutTransition)
            }
        }
    }

    deinit {
        self.inputMediaNodeDataDisposable?.dispose()
    }

    public func updateLayoutSize(_ size: CGSize, keyboardHeight: CGFloat, sideInset: CGFloat, animated: Bool) -> CGFloat {
        self.currentSafeAreaInset = .zero
        self.currentContainerBottomInset = 0.0
        self.usesContainerLayout = false
        return self.updateLayout(width: size.width, leftInset: sideInset, rightInset: sideInset, bottomInset: 0.0, keyboardHeight: keyboardHeight, additionalSideInsets: UIEdgeInsets(), maxHeight: size.height, isSecondary: false, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), isMediaInputExpanded: false)
    }

    @objc(updateContainerLayoutSize:safeAreaInset:bottomInset:keyboardHeight:animated:)
    public func updateContainerLayoutSize(_ size: CGSize, safeAreaInset: UIEdgeInsets, bottomInset: CGFloat, keyboardHeight: CGFloat, animated: Bool) -> CGFloat {
        self.currentSafeAreaInset = safeAreaInset
        self.currentContainerBottomInset = bottomInset
        self.usesContainerLayout = true
        return self.updateLayout(width: size.width, leftInset: 0.0, rightInset: 0.0, bottomInset: 0.0, keyboardHeight: keyboardHeight, additionalSideInsets: UIEdgeInsets(), maxHeight: size.height, isSecondary: false, transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), isMediaInputExpanded: false)
    }

    public func caption() -> NSAttributedString {
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View, case let .text(caption) = view.getSendMessageInput() {
            return caption
        } else {
            return NSAttributedString()
        }
    }

    private var scheduledMessageInput: MessageInputPanelComponent.SendMessageInput?
    public func setCaption(_ caption: NSAttributedString?) {
        let sendMessageInput = MessageInputPanelComponent.SendMessageInput.text(caption ?? NSAttributedString())
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
            view.setSendMessageInput(value: sendMessageInput, updateState: true)
        } else {
            self.scheduledMessageInput = sendMessageInput
        }
    }

    public func animate(_ view: UIView, frame: CGRect) {
        let transition = ComponentTransition.spring(duration: 0.4)
        transition.setFrame(view: view, frame: frame)
    }

    public func setTimeout(_ timeout: Int32, isVideo: Bool, isCaptionAbove: Bool) {
        self.dismissAllTooltips()
        var timeout: Int32? = timeout
        if timeout == 0 {
            timeout = nil
        }
        self.currentTimeout = timeout
        self.currentIsVideo = isVideo
        self.currentIsCaptionAbove = isCaptionAbove
    }

    public func activateInput() {
        let transition: ContainedViewLayoutTransition
        if self.currentInputMode != .text {
            transition = .animated(duration: 0.4, curve: .spring)
        } else {
            transition = .immediate
        }
        self.currentInputMode = .text
        self.update(transition: transition)
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
            view.activateInput()
        }
    }

    public func dismissInput() -> Bool {
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
            if view.canDeactivateInput() {
                let inputModeTransition: ContainedViewLayoutTransition
                if self.currentInputMode != .text {
                    self.currentInputMode = .text
                    inputModeTransition = .animated(duration: 0.4, curve: .spring)
                } else {
                    inputModeTransition = .immediate
                }
                if view.isActive {
                    view.deactivateInput(force: true)
                }
                if !inputModeTransition.isAnimated {
                    return true
                }
                self.update(transition: inputModeTransition)
                return true
            } else {
                view.animateError()
                return false
            }
        } else {
            if self.currentInputMode != .text {
                self.currentInputMode = .text
                self.update(transition: .animated(duration: 0.4, curve: .spring))
            }
            return true
        }
    }

    public func onAnimateOut() {
        self.dismissAllTooltips()
    }

    public func baseHeight() -> CGFloat {
        return 52.0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func update(transition: ContainedViewLayoutTransition) {
        if let (width, leftInset, rightInset, bottomInset, keyboardHeight, additionalSideInsets, maxHeight, isSecondary, metrics) = self.validLayout {
            let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, keyboardHeight: keyboardHeight, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: transition, metrics: metrics, isMediaInputExpanded: false)
        }
    }

    public func updateLayout(
        width: CGFloat,
        leftInset: CGFloat,
        rightInset: CGFloat,
        bottomInset: CGFloat,
        keyboardHeight: CGFloat,
        additionalSideInsets: UIEdgeInsets,
        maxHeight: CGFloat,
        isSecondary: Bool,
        transition: ContainedViewLayoutTransition,
        metrics: LayoutMetrics,
        isMediaInputExpanded: Bool
    ) -> CGFloat {
        let previousLayout = self.validLayout
        self.validLayout = (width, leftInset, rightInset, bottomInset, keyboardHeight, additionalSideInsets, maxHeight, isSecondary, metrics)

        var transition = transition
        if keyboardHeight.isZero, let previousKeyboardHeight = previousLayout?.keyboardHeight, previousKeyboardHeight > 0.0, !transition.isAnimated {
            transition = .animated(duration: 0.4, curve: .spring)
        }

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = defaultDarkColorPresentationTheme
        let isLandscape = width > maxHeight
        let deviceMetrics = DeviceMetrics(screenSize: CGSize(width: width, height: maxHeight), scale: UIScreen.main.scale, statusBarHeight: 0.0, onScreenNavigationHeight: nil)
        let standardInputHeight = deviceMetrics.standardInputHeight(inLandscape: isLandscape)
        let keyboardWasHidden = self.inputPanelExternalState.isKeyboardHidden

        var timeoutValue: String?
        var timeoutSelected = false
        if self.isFile {
            timeoutValue = nil
        } else {
            if let timeout = self.currentTimeout {
                if timeout == viewOnceTimeout {
                    timeoutValue = "1"
                } else {
                    timeoutValue = "\(timeout)"
                }
                timeoutSelected = true
            } else {
                timeoutValue = "1"
            }
        }

        let reservedKeyboardHeight: CGFloat
        if case .emoji = self.currentInputMode {
            reservedKeyboardHeight = max(keyboardHeight, standardInputHeight)
        } else if self.inputPanelExternalState.isEditing && keyboardHeight.isZero && keyboardWasHidden {
            reservedKeyboardHeight = standardInputHeight
        } else {
            reservedKeyboardHeight = keyboardHeight
        }

        let maxInputPanelHeight: CGFloat
        if keyboardHeight.isZero, case .text = self.currentInputMode, !keyboardWasHidden {
            maxInputPanelHeight = 60.0
        } else {
            maxInputPanelHeight = max(60.0, maxHeight - reservedKeyboardHeight - 100.0)
        }

        var resetInputContents: MessageInputPanelComponent.SendMessageInput?
        if let scheduledMessageInput = self.scheduledMessageInput {
            resetInputContents = scheduledMessageInput
            self.scheduledMessageInput = nil
        }

        var hasTimer = self.hasTimer && self.chatLocation.peerId?.namespace == Namespaces.Peer.CloudUser && !self.isScheduledMessages
        if self.chatLocation.peerId?.isRepliesOrSavedMessages(accountPeerId: self.context.account.peerId) == true {
            hasTimer = false
        }

        self.inputPanel.parentState = self.state
        let inputPanelSize = self.inputPanel.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(
                MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: self.context,
                    theme: theme,
                    strings: presentationData.strings,
                    style: .media,
                    placeholder: .plain(presentationData.strings.MediaPicker_AddCaption),
                    sendPaidMessageStars: nil,
                    maxLength: Int(self.context.userLimits.maxCaptionLength),
                    queryTypes: [.mention, .hashtag],
                    alwaysDarkWhenHasText: false,
                    resetInputContents: resetInputContents,
                    nextInputMode: { [weak self] _ in
                        guard let self else {
                            return .emoji
                        }
                        switch self.currentInputMode {
                        case .text:
                            return .emoji
                        case .emoji:
                            return .text
                        default:
                            return .emoji
                        }
                    },
                    areVoiceMessagesAvailable: false,
                    presentController: self.present,
                    presentInGlobalOverlay: self.presentInGlobalOverlay,
                    sendMessageAction: { [weak self] _ in
                        if let self {
                            self.sendPressed?(self.caption())
                            let _ = self.dismissInput()
                        }
                    },
                    sendMessageOptionsAction: nil,
                    sendStickerAction: { _ in },
                    setMediaRecordingActive: nil,
                    lockMediaRecording: nil,
                    stopAndPreviewMediaRecording: nil,
                    discardMediaRecordingPreview: nil,
                    attachmentAction: { [weak self] in
                        self?.toggleIsCaptionAbove()
                    },
                    attachmentButtonMode: self.currentIsCaptionAbove ? .captionDown : .captionUp,
                    myReaction: nil,
                    likeAction: nil,
                    likeOptionsAction: nil,
                    inputModeAction: { [weak self] in
                        self?.toggleInputMode()
                    },
                    timeoutAction: hasTimer ? { [weak self] sourceView, gesture in
                        self?.presentTimeoutSetup(sourceView: sourceView, gesture: gesture)
                    } : nil,
                    forwardAction: nil,
                    paidMessageAction: nil,
                    moreAction: nil,
                    presentCaptionPositionTooltip: { [weak self] sourceView in
                        self?.presentCaptionPositionTooltip(sourceView: sourceView)
                    },
                    presentVoiceMessagesUnavailableTooltip: nil,
                    presentTextLengthLimitTooltip: nil,
                    presentTextFormattingTooltip: nil,
                    paste: { _ in },
                    audioRecorder: nil,
                    videoRecordingStatus: nil,
                    isRecordingLocked: false,
                    hasRecordedVideo: false,
                    recordedAudioPreview: nil,
                    hasRecordedVideoPreview: false,
                    wasRecordingDismissed: false,
                    timeoutValue: timeoutValue,
                    timeoutSelected: timeoutSelected,
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
                    chatLocation: self.chatLocation,
                    aiCompose: self.isAIEnabled ? { [weak self] in
                        self?.openAICompose()
                    } : nil
                )
            ),
            environment: {},
            containerSize: CGSize(width: width, height: maxInputPanelHeight)
        )
        let inputPanelHeight = inputPanelSize.height - 8.0
        var totalHeight = inputPanelHeight
        var inputMediaHeight: CGFloat = 0.0
        self.currentAdditionalInputHeight = 0.0
        var inputMediaNodeForLayout: ChatEntityKeyboardInputNode?
        var isNewInputMediaNode = false
        var retainedInputHeight = keyboardHeight
        var shouldRetainHiddenInputHeight = false

        if case .emoji = self.currentInputMode, let inputData = self.inputMediaNodeData {
            let inputMediaNode: ChatEntityKeyboardInputNode
            if let current = self.inputMediaNode {
                inputMediaNode = current
            } else {
                isNewInputMediaNode = true
                inputMediaNode = ChatEntityKeyboardInputNode(
                    context: self.context,
                    currentInputData: inputData,
                    updatedInputData: self.inputMediaNodeDataPromise.get(),
                    defaultToEmojiTab: true,
                    opaqueTopPanelBackground: false,
                    useOpaqueTheme: false,
                    interaction: self.inputMediaInteraction,
                    chatPeerId: nil,
                    stateContext: self.inputMediaNodeStateContext
                )
                inputMediaNode.clipsToBounds = true
                inputMediaNode.externalTopPanelContainerImpl = nil
                inputMediaNode.useExternalSearchContainer = true
                self.inputMediaNode = inputMediaNode
            }

            if inputMediaNode.view.superview == nil {
                if let inputPanelView = self.inputPanel.view {
                    self.view.insertSubview(inputMediaNode.view, belowSubview: inputPanelView)
                } else {
                    self.view.addSubview(inputMediaNode.view)
                }
            }
            inputMediaNodeForLayout = inputMediaNode

            let inputPresentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let presentationInterfaceState = ChatPresentationInterfaceState(
                chatWallpaper: .builtin(WallpaperSettings()),
                theme: inputPresentationData.theme,
                preferredGlassType: .default,
                strings: inputPresentationData.strings,
                dateTimeFormat: inputPresentationData.dateTimeFormat,
                nameDisplayOrder: inputPresentationData.nameDisplayOrder,
                limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 },
                fontSize: inputPresentationData.chatFontSize,
                bubbleCorners: inputPresentationData.chatBubbleCorners,
                accountPeerId: self.context.account.peerId,
                mode: .standard(.default),
                chatLocation: .peer(id: self.context.account.peerId),
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
                width: width,
                leftInset: 0.0,
                rightInset: 0.0,
                bottomInset: 0.0,
                standardInputHeight: standardInputHeight,
                inputHeight: 0.0,
                maximumHeight: maxHeight,
                inputPanelHeight: 0.0,
                transition: .immediate,
                interfaceState: presentationInterfaceState,
                layoutMetrics: metrics,
                deviceMetrics: deviceMetrics,
                isVisible: true,
                isExpanded: false
            )
            inputMediaHeight = heightAndOverflow.0
            self.currentAdditionalInputHeight = inputMediaHeight
            totalHeight += inputMediaHeight
        } else if let inputMediaNode = self.inputMediaNode {
            self.inputMediaNode = nil

            if transition.isAnimated {
                var dismissingInputHeight = keyboardHeight
                if self.inputPanelExternalState.isEditing && (dismissingInputHeight.isZero && keyboardWasHidden) {
                    dismissingInputHeight = max(dismissingInputHeight, standardInputHeight)
                }
                let targetOriginY: CGFloat
                if self.usesContainerLayout {
                    if dismissingInputHeight > 0.0 {
                        targetOriginY = maxHeight - dismissingInputHeight
                    } else {
                        targetOriginY = maxHeight
                    }
                } else {
                    if dismissingInputHeight > 0.0 {
                        targetOriginY = inputPanelHeight
                    } else {
                        targetOriginY = inputPanelHeight + inputMediaNode.frame.height
                    }
                }
                let targetFrame = CGRect(
                    origin: CGPoint(x: inputMediaNode.frame.minX, y: targetOriginY),
                    size: inputMediaNode.frame.size
                )
                transition.updateFrame(view: inputMediaNode.view, frame: targetFrame)
                inputMediaNode.view.layer.animateAlpha(from: inputMediaNode.view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak inputMediaNode] _ in
                    inputMediaNode?.view.removeFromSuperview()
                })
            } else {
                inputMediaNode.view.removeFromSuperview()
            }
        }

        if self.inputPanelExternalState.isEditing {
            if case .emoji = self.currentInputMode {
                retainedInputHeight = max(retainedInputHeight, standardInputHeight)
                shouldRetainHiddenInputHeight = true
            } else if retainedInputHeight.isZero && keyboardWasHidden {
                retainedInputHeight = max(retainedInputHeight, standardInputHeight)
                shouldRetainHiddenInputHeight = true
            }
        }
        if self.currentAdditionalInputHeight.isZero && retainedInputHeight > 0.0 && shouldRetainHiddenInputHeight {
            self.currentAdditionalInputHeight = retainedInputHeight
            totalHeight += retainedInputHeight
        }

        let isLandscapePhone = width > maxHeight && UIDevice.current.userInterfaceIdiom != .pad
        let collapsedCaptionTopInset = self.currentSafeAreaInset.top + 48.0
        let expandedCaptionTopInset = self.currentSafeAreaInset.top + 8.0

        var inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: inputPanelSize)
        var inputMediaFrame = CGRect(origin: CGPoint(x: 0.0, y: inputPanelHeight), size: CGSize(width: width, height: inputMediaHeight))

        if self.usesContainerLayout {
            if isLandscapePhone {
                inputPanelFrame.origin.y = maxHeight + 16.0 - 8.0
                inputMediaFrame.origin.y = maxHeight + 16.0
            } else if case .emoji = self.currentInputMode {
                inputMediaFrame.origin.y = maxHeight - inputMediaHeight
                if self.currentIsCaptionAbove {
                    inputPanelFrame.origin.y = expandedCaptionTopInset - 8.0
                } else {
                    inputPanelFrame.origin.y = inputMediaFrame.minY - inputPanelHeight - 8.0
                }
            } else {
                if self.currentIsCaptionAbove {
                    inputPanelFrame.origin.y = (retainedInputHeight > 0.0 ? expandedCaptionTopInset : collapsedCaptionTopInset) - 8.0
                } else {
                    let bottomOffset = max(self.currentContainerBottomInset, retainedInputHeight)
                    inputPanelFrame.origin.y = maxHeight - inputPanelHeight - bottomOffset - 8.0
                }
                inputMediaFrame.origin.y = maxHeight
            }
        }

        if let view = self.inputPanel.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            transition.updateFrame(view: view, frame: inputPanelFrame)
        }

        if let inputMediaNode = inputMediaNodeForLayout {
            if isNewInputMediaNode && transition.isAnimated {
                inputMediaNode.view.frame = inputMediaFrame.offsetBy(dx: 0.0, dy: inputMediaHeight)
                inputMediaNode.view.alpha = 0.0
                inputMediaNode.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            inputMediaNode.view.alpha = 1.0
            transition.updateFrame(view: inputMediaNode.view, frame: inputMediaFrame)
        }

        if self.currentIsEditing != self.inputPanelExternalState.isEditing {
            self.currentIsEditing = self.inputPanelExternalState.isEditing
            self.focusUpdated?(self.currentIsEditing)
        }

        if self.currentHeight != totalHeight {
            self.currentHeight = totalHeight
            self.heightUpdated?(transition.isAnimated)
        }

        return totalHeight
    }

    private func prepareForPresentedController(_ controller: ViewController) {
        if controller is UndoOverlayController {
            return
        }
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View, view.isActive {
            view.deactivateInput(force: true)
        }
        if self.currentInputMode != .text {
            self.currentInputMode = .text
            self.update(transition: .immediate)
        }
    }

    private func openAICompose() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let effectiveInputText: NSAttributedString = self.caption()
            if effectiveInputText.length == 0 {
                return
            }

            let inputText = trimChatInputText(effectiveInputText)
            var entities: [MessageTextEntity] = []
            if inputText.length != 0 {
                entities = generateTextEntities(inputText.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(inputText, maxAnimatedEmojisInText: 0))
            }

            self.pushViewController(await self.context.sharedContext.makeTextProcessingScreen(
                context: self.context,
                theme: defaultDarkColorPresentationTheme,
                mode: .edit(
                    saveRestoreStateId: self.chatLocation.peerId,
                    completion: { [weak self] text in
                        guard let self else {
                            return
                        }
                        // Captions are plain text with entities; the API only returns a rich result for rich input.
                        guard case let .plain(text, entities) = text else {
                            return
                        }
                        self.setCaption(chatInputStateStringWithAppliedEntities(text, entities: entities))
                    },
                    send: nil,
                    sendContextActions: nil
                ),
                inputText: .plain(text: inputText.string, entities: entities),
                copyResult: { text in
                    storeComposedRichMessageInPasteboard(text)
                },
                translateChat: nil
            ))
        }
    }

    private func toggleInputMode() {
        switch self.currentInputMode {
        case .text:
            self.currentInputMode = .emoji
            self.update(transition: .animated(duration: 0.4, curve: .spring))
            if let view = self.inputPanel.view as? MessageInputPanelComponent.View, !view.isActive {
                view.activateInput()
            }
        case .emoji:
            self.activateInput()
        default:
            self.currentInputMode = .emoji
            self.update(transition: .animated(duration: 0.4, curve: .spring))
        }
    }

    private func toggleIsCaptionAbove() {
        self.currentIsCaptionAbove = !self.currentIsCaptionAbove
        self.captionIsAboveUpdated?(self.currentIsCaptionAbove)
        self.update(transition: .animated(duration: 0.3, curve: .spring))

        self.dismissAllTooltips()

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        let title = self.currentIsCaptionAbove ? presentationData.strings.MediaPicker_InvertCaption_Updated_Up_Title : presentationData.strings.MediaPicker_InvertCaption_Updated_Down_Title
        let text = self.currentIsCaptionAbove ? presentationData.strings.MediaPicker_InvertCaption_Updated_Up_Text : presentationData.strings.MediaPicker_InvertCaption_Updated_Down_Text
        let animationName = self.currentIsCaptionAbove ? "message_preview_sort_above" : "message_preview_sort_below"

        let controller = UndoOverlayController(
            presentationData: presentationData,
            content: .universal(animation: animationName, scale: 1.0, colors: ["__allcolors__": UIColor.white], title: title, text: text, customUndoText: nil, timeout: 2.0),
            elevatedLayout: false,
            position: self.currentIsCaptionAbove ? .bottom : .top,
            action: { _ in return false }
        )
        self.present(controller)
        self.undoController = controller
    }

    private func presentTimeoutSetup(sourceView: UIView, gesture: ContextGesture?) {
        self.hapticFeedback.impact(.light)

        var items: [ContextMenuItem] = []

        let updateTimeout: (Int32?) -> Void = { [weak self] timeout in
            if let self {
                let previousTimeout = self.currentTimeout
                self.currentTimeout = timeout
                self.timerUpdated?(timeout as? NSNumber)
                self.update(transition: .immediate)
                if previousTimeout != timeout {
                    self.presentTimeoutTooltip(sourceView: sourceView, timeout: timeout)
                }
            }
        }

        let currentValue = self.currentTimeout
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        let title = presentationData.strings.MediaPicker_Timer_Description
        let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil

        items.append(.action(ContextMenuActionItem(text: title, textLayout: .multiline, textFont: .small, icon: { _ in nil }, action: emptyAction)))

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Timer_ViewOnce, icon: { theme in
            return currentValue == viewOnceTimeout ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
        }, action: { _, action in
            action(.default)

            updateTimeout(viewOnceTimeout)
        })))

        let values: [Int32] = [3, 10, 30]

        for value in values {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Timer_Seconds(value), icon: { theme in
                return currentValue == value ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, action in
                action(.default)

                updateTimeout(value)
            })))
        }

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Timer_DoNotDelete, icon: { theme in
            return currentValue == nil ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
        }, action: { _, action in
            action(.default)

            updateTimeout(nil)
        })))

        let contextController = makeContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(sourceView: sourceView, position: self.currentIsCaptionAbove ? .bottom : .top)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }

    private func dismissAllTooltips() {
        if let undoController = self.undoController {
            self.undoController = nil
            undoController.dismissWithCommitAction()
        }
        if let tooltipController = self.tooltipController {
            self.tooltipController = nil
            tooltipController.dismiss()
        }
    }

    private func presentTimeoutTooltip(sourceView: UIView, timeout: Int32?) {
        guard let superview = self.view.superview?.superview else {
            return
        }
        self.dismissAllTooltips()

        let parentFrame = superview.convert(superview.bounds, to: nil)
        let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
        let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 2.0), size: CGSize())

        let isVideo = self.currentIsVideo
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let text: String
        let iconName: String
        if timeout == viewOnceTimeout {
            text = isVideo ? presentationData.strings.MediaPicker_Timer_Video_ViewOnceTooltip : presentationData.strings.MediaPicker_Timer_Photo_ViewOnceTooltip
            iconName = "anim_autoremove_on"
        } else if let timeout {
            text = isVideo ? presentationData.strings.MediaPicker_Timer_Video_TimerTooltip("\(timeout)").string : presentationData.strings.MediaPicker_Timer_Photo_TimerTooltip("\(timeout)").string
            iconName = "anim_autoremove_on"
        } else {
            text = isVideo ? presentationData.strings.MediaPicker_Timer_Video_KeepTooltip : presentationData.strings.MediaPicker_Timer_Photo_KeepTooltip
            iconName = "anim_autoremove_off"
        }

        let tooltipController = TooltipScreen(
            account: self.context.account,
            sharedContext: self.context.sharedContext,
            text: .plain(text: text),
            balancedTextLayout: false,
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            arrowStyle: .small,
            icon: .animation(name: iconName, delay: 0.1, tintColor: nil),
            location: .point(location, .bottom),
            displayDuration: .default,
            inset: 8.0,
            shouldDismissOnTouch: { _, _ in
                return .ignore
            }
        )
        self.tooltipController = tooltipController
        self.presentInGlobalOverlay(tooltipController)
    }

    private func presentCaptionPositionTooltip(sourceView: UIView) {
        guard let superview = self.view.superview?.superview else {
            return
        }
        self.dismissAllTooltips()

        let _ = (ApplicationSpecificNotice.getCaptionAboveMediaTooltip(accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] count in
            guard let self else {
                return
            }
            if count > 2 {
                return
            }

            let parentFrame = superview.convert(superview.bounds, to: nil)
            let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX + 2.0, y: absoluteFrame.minY + 6.0), size: CGSize())

            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

            let tooltipController = TooltipScreen(
                account: self.context.account,
                sharedContext: self.context.sharedContext,
                text: .plain(text: presentationData.strings.MediaPicker_InvertCaptionTooltip),
                balancedTextLayout: false,
                style: .customBlur(UIColor(rgb: 0x18181a), 4.0),
                arrowStyle: .small,
                icon: nil,
                location: .point(location, .bottom),
                displayDuration: .default,
                inset: 4.0,
                cornerRadius: 10.0,
                shouldDismissOnTouch: { _, _ in
                    return .ignore
                }
            )
            self.tooltipController = tooltipController
            self.presentInGlobalOverlay(tooltipController)

            let _ = ApplicationSpecificNotice.incrementCaptionAboveMediaTooltip(accountManager: self.context.sharedContext.accountManager).start()
        })
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = self.inputPanel.view, let panelResult = view.hitTest(self.view.convert(point, to: view), with: event) {
            return panelResult
        }
        if let inputMediaNode = self.inputMediaNode, let inputMediaResult = inputMediaNode.view.hitTest(self.view.convert(point, to: inputMediaNode.view), with: event) {
            return inputMediaResult
        }
        let result = super.hitTest(point, with: event)
        if result === self.view {
            return nil
        }
        return result
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    var keepInPlace: Bool {
        return true
    }

    let position: ContextControllerReferenceViewInfo.ActionsPosition

    init(sourceView: UIView, position: ContextControllerReferenceViewInfo.ActionsPosition) {
        self.sourceView = sourceView
        self.position = position
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: self.position)
    }
}
