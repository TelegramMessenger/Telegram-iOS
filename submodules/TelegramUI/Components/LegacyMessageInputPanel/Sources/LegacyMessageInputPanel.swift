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

public class LegacyMessageInputPanelNode: ASDisplayNode, TGCaptionPanelView {
    private let context: AccountContext
    private let chatLocation: ChatLocation
    private let present: (ViewController) -> Void
    private let presentInGlobalOverlay:  (ViewController) -> Void
        
    private let state = ComponentState()
    private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
    private let inputPanel = ComponentView<Empty>()
    
    private var currentTimeout: Int32?
    private var currentIsEditing = false
    private var currentHeight: CGFloat?
    
    private let hapticFeedback = HapticFeedback()
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, keyboardHeight: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, metrics: LayoutMetrics)?
    
    public init(
        context: AccountContext,
        chatLocation: ChatLocation,
        present: @escaping (ViewController) -> Void,
        presentInGlobalOverlay: @escaping (ViewController) -> Void
    ) {
        self.context = context
        self.chatLocation = chatLocation
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
        
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
    
    public func setCaption(_ caption: NSAttributedString?) {
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
            view.setSendMessageInput(value: .text(caption ?? NSAttributedString()), updateState: true)
        }
    }
    
    public func animate(_ view: UIView, frame: CGRect) {
        let transition = Transition.spring(duration: 0.4)
        transition.setFrame(view: view, frame: frame)
    }
    
    public func setTimeout(_ timeout: Int32) {
        var timeout: Int32? = timeout
        if timeout == 0 {
            timeout = nil
        }
        self.currentTimeout = timeout
    }
    
    public func dismissInput() {
        if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
            view.deactivateInput()
        }
    }
    
    public func onAnimateOut() {
        self.tooltipController?.dismiss()
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
                    maxLength: 1024,
                    queryTypes: [.mention],
                    alwaysDarkWhenHasText: false,
                    resetInputContents: nil,
                    nextInputMode: { _ in
                        return .emoji
                    },
                    areVoiceMessagesAvailable: false,
                    presentController: self.present,
                    presentInGlobalOverlay: self.presentInGlobalOverlay,
                    sendMessageAction: { [weak self] in
                        if let self {
                            self.sendPressed?(self.caption())
                            self.dismissInput()
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
                    inputModeAction: nil,
                    timeoutAction: { [weak self] sourceView in
                        if let self {
                            self.presentTimeoutSetup(sourceView: sourceView)
                        }
                    },
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
    
    private func presentTimeoutSetup(sourceView: UIView) {
        self.hapticFeedback.impact(.light)
        
        var items: [ContextMenuItem] = []

        let updateTimeout: (Int32?) -> Void = { [weak self] timeout in
            if let self {
                self.currentTimeout = timeout
                self.timerUpdated?(timeout as? NSNumber)
                self.update(transition: .immediate)
                self.presentTimeoutTooltip(sourceView: sourceView, timeout: timeout)
            }
        }
                
        let currentValue = self.currentTimeout
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme)
        let title = "Choose how long the media will be kept after opening."
        let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
        
        items.append(.action(ContextMenuActionItem(text: title, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))

        items.append(.action(ContextMenuActionItem(text: "View Once", icon: { theme in
            return currentValue == viewOnceTimeout ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
        
            updateTimeout(viewOnceTimeout)
        })))
        
        items.append(.action(ContextMenuActionItem(text: "3 Seconds", icon: { theme in
            return currentValue == 3 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
            
            updateTimeout(3)
        })))
        
        items.append(.action(ContextMenuActionItem(text: "10 Seconds", icon: { theme in
            return currentValue == 10 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
            
            updateTimeout(10)
        })))
        
        items.append(.action(ContextMenuActionItem(text: "30 Seconds", icon: { theme in
            return currentValue == 30 ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
            
            updateTimeout(30)
        })))
    
        items.append(.action(ContextMenuActionItem(text: "Do Not Delete", icon: { theme in
            return currentValue == nil ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, a in
            a(.default)
            
            updateTimeout(nil)
        })))
        
        let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.present(contextController)
    }
    
    private weak var tooltipController: TooltipScreen?
    private func presentTimeoutTooltip(sourceView: UIView, timeout: Int32?) {
        guard let superview = self.view.superview?.superview else {
            return
        }
        if let tooltipController = self.tooltipController {
            self.tooltipController = nil
            tooltipController.dismiss()
        }
        
        let parentFrame = superview.convert(superview.bounds, to: nil)
        let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
        let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 2.0), size: CGSize())
        
        let text: String
        let iconName: String
        if timeout == viewOnceTimeout {
            text = "Photo set to view once."
            iconName = "anim_autoremove_on"
        } else if let timeout {
            text = "Photo will be deleted in \(timeout) seconds after opening."
            iconName = "anim_autoremove_on"
        } else {
            text = "Photo will be kept in chat."
            iconName = "anim_autoremove_off"
        }
        
        let tooltipController = TooltipScreen(
            account: self.context.account,
            sharedContext: self.context.sharedContext,
            text: .plain(text: text),
            balancedTextLayout: true,
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
