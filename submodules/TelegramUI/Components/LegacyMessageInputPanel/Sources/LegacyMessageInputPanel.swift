import Foundation
import UIKit
import AsyncDisplayKit
import LegacyComponents
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import LegacyComponents
import ComponentFlow
import MessageInputPanelComponent
import TelegramPresentationData
import ContextUI
import TooltipUI
import LegacyMessageInputPanelInputView
import UndoUI

public class LegacyMessageInputPanelNode: ASDisplayNode, TGCaptionPanelView {
    private let context: AccountContext
    private let chatLocation: ChatLocation
    private let isScheduledMessages: Bool
    private let present: (ViewController) -> Void
    private let presentInGlobalOverlay:  (ViewController) -> Void
    private let makeEntityInputView: () -> LegacyMessageInputPanelInputView?
    
    private let state = ComponentState()
    private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
    private let inputPanel = ComponentView<Empty>()
    
    private var currentTimeout: Int32?
    private var currentIsEditing = false
    private var currentHeight: CGFloat?
    private var currentIsVideo = false
    
    private let hapticFeedback = HapticFeedback()
    
    private var inputView: LegacyMessageInputPanelInputView?
    private var isEmojiKeyboardActive = false
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, keyboardHeight: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, metrics: LayoutMetrics)?
    
    public init(
        context: AccountContext,
        chatLocation: ChatLocation,
        isScheduledMessages: Bool,
        present: @escaping (ViewController) -> Void,
        presentInGlobalOverlay: @escaping (ViewController) -> Void,
        makeEntityInputView: @escaping () -> LegacyMessageInputPanelInputView?
    ) {
        self.context = context
        self.chatLocation = chatLocation
        self.isScheduledMessages = isScheduledMessages
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.makeEntityInputView = makeEntityInputView
        
        super.init()
        
        self.state._updated = { [weak self] transition in
            if let self {
                self.update(transition: transition.containedViewLayoutTransition)
            }
        }
    }
    
    public var sendPressed: ((NSAttributedString?) -> Void)?
    public var focusUpdated: ((Bool) -> Void)?
    public var heightUpdated: ((Bool) -> Void)?
    public var timerUpdated: ((NSNumber?) -> Void)?
    
    public func updateLayoutSize(_ size: CGSize, keyboardHeight: CGFloat, sideInset: CGFloat, animated: Bool) -> CGFloat {
        return self.updateLayout(width: size.width, leftInset: sideInset, rightInset: sideInset, bottomInset: 0.0, keyboardHeight: keyboardHeight,  additionalSideInsets: UIEdgeInsets(), maxHeight: size.height, isSecondary: false, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), isMediaInputExpanded: false)
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
        let transition = Transition.spring(duration: 0.4)
        transition.setFrame(view: view, frame: frame)
    }
    
    public func setTimeout(_ timeout: Int32, isVideo: Bool) {
        self.dismissTimeoutTooltip()
        var timeout: Int32? = timeout
        if timeout == 0 {
            timeout = nil
        }
        self.currentTimeout = timeout
        self.currentIsVideo = isVideo
    }
    
    public func dismissInput() -> Bool {
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
            if view.canDeactivateInput() {
                self.isEmojiKeyboardActive = false
                self.inputView = nil
                view.deactivateInput(force: true)
                return true
            } else {
                view.animateError()
                return false
            }
        } else {
            return true
        }
    }
    
    public func onAnimateOut() {
        self.dismissTimeoutTooltip()
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
    
    public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, keyboardHeight: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        let previousLayout = self.validLayout
        self.validLayout = (width, leftInset, rightInset, bottomInset, keyboardHeight, additionalSideInsets, maxHeight, isSecondary, metrics)
        
        var transition = transition
        if keyboardHeight.isZero, let previousKeyboardHeight = previousLayout?.keyboardHeight, previousKeyboardHeight > 0.0, !transition.isAnimated {
            transition = .animated(duration: 0.4, curve: .spring)
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = defaultDarkColorPresentationTheme
        
        var timeoutValue: String
        var timeoutSelected = false
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
        
        var maxInputPanelHeight = maxHeight
        if keyboardHeight.isZero {
            maxInputPanelHeight = 60.0
        } else {
            maxInputPanelHeight = maxHeight - keyboardHeight - 100.0
        }
        
        var resetInputContents: MessageInputPanelComponent.SendMessageInput?
        if let scheduledMessageInput = self.scheduledMessageInput {
            resetInputContents = scheduledMessageInput
            self.scheduledMessageInput = nil
        }
        
        self.inputPanel.parentState = self.state
        let inputPanelSize = self.inputPanel.update(
            transition: Transition(transition),
            component: AnyComponent(
                MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: self.context,
                    theme: theme,
                    strings: presentationData.strings,
                    style: .media,
                    placeholder: .plain(presentationData.strings.MediaPicker_AddCaption),
                    maxLength: Int(self.context.userLimits.maxCaptionLength),
                    queryTypes: [.mention],
                    alwaysDarkWhenHasText: false,
                    resetInputContents: resetInputContents,
                    nextInputMode: { [weak self] _ in
                        if self?.isEmojiKeyboardActive == true {
                            return .text
                        } else {
                            return .emoji
                        }
                    },
                    areVoiceMessagesAvailable: false,
                    presentController: self.present,
                    presentInGlobalOverlay: self.presentInGlobalOverlay,
                    sendMessageAction: { [weak self] in
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
                    attachmentAction: nil,
                    myReaction: nil,
                    likeAction: nil,
                    likeOptionsAction: nil,
                    inputModeAction: { [weak self] in
                        if let self {
                            self.toggleInputMode()
                        }
                    },
                    timeoutAction: self.chatLocation.peerId?.namespace == Namespaces.Peer.CloudUser && !self.isScheduledMessages ? { [weak self] sourceView, gesture in
                        if let self {
                            self.presentTimeoutSetup(sourceView: sourceView, gesture: gesture)
                        }
                    } : nil,
                    forwardAction: nil,
                    moreAction: nil,
                    presentVoiceMessagesUnavailableTooltip: nil,
                    presentTextLengthLimitTooltip: nil,
                    presentTextFormattingTooltip: nil,
                    paste: { _ in },
                    audioRecorder: nil,
                    videoRecordingStatus: nil,
                    isRecordingLocked: false,
                    recordedAudioPreview: nil,
                    hasRecordedVideoPreview: false,
                    wasRecordingDismissed: false,
                    timeoutValue: timeoutValue,
                    timeoutSelected: timeoutSelected,
                    displayGradient: false,
                    bottomInset: 0.0,
                    isFormattingLocked: false,
                    hideKeyboard: false,
                    customInputView: self.inputView,
                    forceIsEditing: false,
                    disabledPlaceholder: nil,
                    isChannel: false,
                    storyItem: nil,
                    chatLocation: self.chatLocation
                )
            ),
            environment: {},
            containerSize: CGSize(width: width, height: maxInputPanelHeight)
        )
        if let view = self.inputPanel.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: inputPanelSize)
            transition.updateFrame(view: view, frame: inputPanelFrame)
        }
        
        if self.currentIsEditing != self.inputPanelExternalState.isEditing {
            self.currentIsEditing = self.inputPanelExternalState.isEditing
            self.focusUpdated?(self.currentIsEditing)
        }
        
        if self.currentHeight != inputPanelSize.height {
            self.currentHeight = inputPanelSize.height
            self.heightUpdated?(transition.isAnimated)
        }
        
        return inputPanelSize.height - 8.0
    }
    
    private func toggleInputMode() {
        self.isEmojiKeyboardActive = !self.isEmojiKeyboardActive
        
        if self.isEmojiKeyboardActive {
            let inputView = self.makeEntityInputView()
            inputView?.insertText = { [weak self] text in
                if let self {
                    self.inputPanelExternalState.insertText(text)
                }
            }
            inputView?.deleteBackwards = { [weak self] in
                if let self {
                    self.inputPanelExternalState.deleteBackward()
                }
            }
            inputView?.switchToKeyboard = { [weak self] in
                if let self {
                    self.isEmojiKeyboardActive = false
                    self.inputView = nil
                    self.update(transition: .immediate)
                }
            }
            inputView?.presentController = { [weak self] c in
                if let self {
                    if !(c is UndoOverlayController) {
                        self.isEmojiKeyboardActive = false
                        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
                            view.deactivateInput(force: true)
                        }
                    }
                    self.present(c)
                }
            }
            self.inputView = inputView
            self.update(transition: .immediate)
        } else {
            self.inputView = nil
            self.update(transition: .immediate)
        }
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
        
        items.append(.action(ContextMenuActionItem(text: title, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))

        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Timer_ViewOnce, icon: { theme in
            return currentValue == viewOnceTimeout ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
        
            updateTimeout(viewOnceTimeout)
        })))
        
        let values: [Int32] = [3, 10, 30]
        
        for value in values {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Timer_Seconds(value), icon: { theme in
                return currentValue == value ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, a in
                a(.default)
                
                updateTimeout(value)
            })))
        }
            
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Timer_DoNotDelete, icon: { theme in
            return currentValue == nil ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
            
            updateTimeout(nil)
        })))
        
        let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.present(contextController)
    }
    
    private weak var tooltipController: TooltipScreen?
    
    private func dismissTimeoutTooltip() {
        if let tooltipController = self.tooltipController {
            self.tooltipController = nil
            tooltipController.dismiss()
        }
    }
    
    private func presentTimeoutTooltip(sourceView: UIView, timeout: Int32?) {
        guard let superview = self.view.superview?.superview else {
            return
        }
        self.dismissTimeoutTooltip()
        
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
        self.present(tooltipController)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let view = self.inputPanel.view, let panelResult = view.hitTest(self.view.convert(point, to: view), with: event) {
            return panelResult
        }
        return result
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    var keepInPlace: Bool {
        return true
    }

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: .top)
    }
}
