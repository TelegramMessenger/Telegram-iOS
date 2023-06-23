import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AppBundle
import TextFieldComponent
import BundleIconComponent
import AccountContext
import TelegramPresentationData
import ChatPresentationInterfaceState
import LottieComponent
import ChatContextQuery
import TextFormat

public final class MessageInputPanelComponent: Component {
    public enum Style {
        case story
        case editor
    }
    
    public enum InputMode: Hashable {
        case text
        case stickers
        case emoji
    }
    
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var hasText: Bool = false
        public fileprivate(set) var isKeyboardHidden: Bool = false
        
        public fileprivate(set) var insertText: (NSAttributedString) -> Void = { _ in }
        public fileprivate(set) var deleteBackward: () -> Void = { }
        
        public init() {
        }
    }
    
    public let externalState: ExternalState
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let style: Style
    public let placeholder: String
    public let alwaysDarkWhenHasText: Bool
    public let nextInputMode: (Bool) -> InputMode?
    public let areVoiceMessagesAvailable: Bool
    public let presentController: (ViewController) -> Void
    public let sendMessageAction: () -> Void
    public let setMediaRecordingActive: ((Bool, Bool, Bool) -> Void)?
    public let lockMediaRecording: (() -> Void)?
    public let stopAndPreviewMediaRecording: (() -> Void)?
    public let discardMediaRecordingPreview: (() -> Void)?
    public let attachmentAction: (() -> Void)?
    public let inputModeAction: (() -> Void)?
    public let timeoutAction: ((UIView) -> Void)?
    public let forwardAction: (() -> Void)?
    public let moreAction: ((UIView, ContextGesture?) -> Void)?
    public let presentVoiceMessagesUnavailableTooltip: ((UIView) -> Void)?
    public let audioRecorder: ManagedAudioRecorder?
    public let videoRecordingStatus: InstantVideoControllerRecordingStatus?
    public let isRecordingLocked: Bool
    public let recordedAudioPreview: ChatRecordedMediaPreview?
    public let wasRecordingDismissed: Bool
    public let timeoutValue: String?
    public let timeoutSelected: Bool
    public let displayGradient: Bool
    public let bottomInset: CGFloat
    public let hideKeyboard: Bool
    public let disabledPlaceholder: String?
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        style: Style,
        placeholder: String,
        alwaysDarkWhenHasText: Bool,
        nextInputMode: @escaping (Bool) -> InputMode?,
        areVoiceMessagesAvailable: Bool,
        presentController: @escaping (ViewController) -> Void,
        sendMessageAction: @escaping () -> Void,
        setMediaRecordingActive: ((Bool, Bool, Bool) -> Void)?,
        lockMediaRecording: (() -> Void)?,
        stopAndPreviewMediaRecording: (() -> Void)?,
        discardMediaRecordingPreview: (() -> Void)?,
        attachmentAction: (() -> Void)?,
        inputModeAction: (() -> Void)?,
        timeoutAction: ((UIView) -> Void)?,
        forwardAction: (() -> Void)?,
        moreAction: ((UIView, ContextGesture?) -> Void)?,
        presentVoiceMessagesUnavailableTooltip: ((UIView) -> Void)?,
        audioRecorder: ManagedAudioRecorder?,
        videoRecordingStatus: InstantVideoControllerRecordingStatus?,
        isRecordingLocked: Bool,
        recordedAudioPreview: ChatRecordedMediaPreview?,
        wasRecordingDismissed: Bool,
        timeoutValue: String?,
        timeoutSelected: Bool,
        displayGradient: Bool,
        bottomInset: CGFloat,
        hideKeyboard: Bool,
        disabledPlaceholder: String?
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.style = style
        self.nextInputMode = nextInputMode
        self.placeholder = placeholder
        self.alwaysDarkWhenHasText = alwaysDarkWhenHasText
        self.areVoiceMessagesAvailable = areVoiceMessagesAvailable
        self.presentController = presentController
        self.sendMessageAction = sendMessageAction
        self.setMediaRecordingActive = setMediaRecordingActive
        self.lockMediaRecording = lockMediaRecording
        self.stopAndPreviewMediaRecording = stopAndPreviewMediaRecording
        self.discardMediaRecordingPreview = discardMediaRecordingPreview
        self.attachmentAction = attachmentAction
        self.inputModeAction = inputModeAction
        self.timeoutAction = timeoutAction
        self.forwardAction = forwardAction
        self.moreAction = moreAction
        self.presentVoiceMessagesUnavailableTooltip = presentVoiceMessagesUnavailableTooltip
        self.audioRecorder = audioRecorder
        self.videoRecordingStatus = videoRecordingStatus
        self.isRecordingLocked = isRecordingLocked
        self.wasRecordingDismissed = wasRecordingDismissed
        self.recordedAudioPreview = recordedAudioPreview
        self.timeoutValue = timeoutValue
        self.timeoutSelected = timeoutSelected
        self.displayGradient = displayGradient
        self.bottomInset = bottomInset
        self.hideKeyboard = hideKeyboard
        self.disabledPlaceholder = disabledPlaceholder
    }
    
    public static func ==(lhs: MessageInputPanelComponent, rhs: MessageInputPanelComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.alwaysDarkWhenHasText != rhs.alwaysDarkWhenHasText {
            return false
        }
        if lhs.areVoiceMessagesAvailable != rhs.areVoiceMessagesAvailable {
            return false
        }
        if lhs.audioRecorder !== rhs.audioRecorder {
            return false
        }
        if lhs.videoRecordingStatus !== rhs.videoRecordingStatus {
            return false
        }
        if lhs.isRecordingLocked != rhs.isRecordingLocked {
            return false
        }
        if lhs.wasRecordingDismissed != rhs.wasRecordingDismissed {
            return false
        }
        if lhs.recordedAudioPreview !== rhs.recordedAudioPreview {
            return false
        }
        if lhs.timeoutValue != rhs.timeoutValue {
            return false
        }
        if lhs.timeoutSelected != rhs.timeoutSelected {
            return false
        }
        if lhs.displayGradient != rhs.displayGradient {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if (lhs.forwardAction == nil) != (rhs.forwardAction == nil) {
            return false
        }
        if (lhs.moreAction == nil) != (rhs.moreAction == nil) {
            return false
        }
        if lhs.hideKeyboard != rhs.hideKeyboard {
            return false
        }
        if lhs.disabledPlaceholder != rhs.disabledPlaceholder {
            return false
        }
        return true
    }
    
    public enum SendMessageInput {
        case text(NSAttributedString)
    }
    
    public final class View: UIView {
        private let fieldBackgroundView: BlurredBackgroundView
        private let vibrancyEffectView: UIVisualEffectView
        private let gradientView: UIImageView
        private let bottomGradientView: UIView
        
        private let placeholder = ComponentView<Empty>()
        private let vibrancyPlaceholder = ComponentView<Empty>()
        
        private var disabledPlaceholder: ComponentView<Empty>?
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()
        
        private let attachmentButton = ComponentView<Empty>()
        private var deleteMediaPreviewButton: ComponentView<Empty>?
        private let inputActionButton = ComponentView<Empty>()
        private let stickerButton = ComponentView<Empty>()
        private let reactionButton = ComponentView<Empty>()
        private let timeoutButton = ComponentView<Empty>()
        
        private var mediaRecordingVibrancyContainer: UIView
        private var mediaRecordingPanel: ComponentView<Empty>?
        private weak var dismissingMediaRecordingPanel: UIView?
        
        private var mediaPreviewPanel: ComponentView<Empty>?
        
        private var currentMediaInputIsVoice: Bool = true
        private var mediaCancelFraction: CGFloat = 0.0
        
        private var contextQueryStates: [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)] = [:]
        private var contextQueryResults: [ChatPresentationInputQueryKind: ChatPresentationInputQueryResult] = [:]
        
        private var contextQueryResultPanel: ComponentView<Empty>?
        private var contextQueryResultPanelExternalState: ContextResultPanelComponent.ExternalState?
        
        private var currentInputMode: InputMode?
        
        private var component: MessageInputPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.fieldBackgroundView = BlurredBackgroundView(color: UIColor(white: 0.0, alpha: 0.5), enableBlur: true)
            
            let style: UIBlurEffect.Style = .dark
            let blurEffect = UIBlurEffect(style: style)
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
            self.vibrancyEffectView = vibrancyEffectView
            
            self.mediaRecordingVibrancyContainer = UIView()
            self.vibrancyEffectView.contentView.addSubview(self.mediaRecordingVibrancyContainer)
            
            self.gradientView = UIImageView()
            self.bottomGradientView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.bottomGradientView)
            self.addSubview(self.gradientView)
            self.fieldBackgroundView.addSubview(self.vibrancyEffectView)
            self.addSubview(self.fieldBackgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func getSendMessageInput() -> SendMessageInput {
            guard let textFieldView = self.textField.view as? TextFieldComponent.View else {
                return .text(NSAttributedString())
            }
            
            return .text(textFieldView.getAttributedText())
        }
        
        public func getAttachmentButtonView() -> UIView? {
            guard let attachmentButtonView = self.attachmentButton.view else {
                return nil
            }
            return attachmentButtonView
        }
        
        public func clearSendMessageInput() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.setAttributedText(NSAttributedString())
            }
        }
        
        public func activateInput() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.activateInput()
            }
        }
        
        public func updateContextQueries() {
            guard let component = self.component, let textFieldView = self.textField.view as? TextFieldComponent.View else {
                return
            }
            let context = component.context
            let inputState = textFieldView.getInputState()
            
            let contextQueryUpdates = contextQueryResultState(context: context, inputState: inputState, currentQueryStates: &self.contextQueryStates)

            for (kind, update) in contextQueryUpdates {
                switch update {
                case .remove:
                    if let (_, disposable) = self.contextQueryStates[kind] {
                        disposable.dispose()
                        self.contextQueryStates.removeValue(forKey: kind)
                        self.contextQueryResults[kind] = nil
                    }
                case let .update(query, signal):
                    let currentQueryAndDisposable = self.contextQueryStates[kind]
                    currentQueryAndDisposable?.1.dispose()

                    var inScope = true
                    var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                    self.contextQueryStates[kind] = (query, (signal
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let self {
                            if Thread.isMainThread && inScope {
                                inScope = false
                                inScopeResult = result
                            } else {
                                self.contextQueryResults[kind] = result(self.contextQueryResults[kind])
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    }))
                    inScope = false
                    if let inScopeResult = inScopeResult {
                        self.contextQueryResults[kind] = inScopeResult(self.contextQueryResults[kind])
                    }
                }
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            
            if result == nil, let contextQueryResultPanel = self.contextQueryResultPanel?.view, let panelResult = contextQueryResultPanel.hitTest(self.convert(point, to: contextQueryResultPanel), with: event), panelResult !== contextQueryResultPanel {
                return panelResult
            }
             
            return result
        }
        
        func update(component: MessageInputPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            var insets = UIEdgeInsets(top: 14.0, left: 7.0, bottom: 6.0, right: 41.0)
            
            if let _ = component.attachmentAction {
                insets.left = 41.0
            }
            if let _ = component.setMediaRecordingActive {
                insets.right = 41.0
            }
            
            let mediaInsets = UIEdgeInsets(top: insets.top, left: 7.0, bottom: insets.bottom, right: insets.right)
            
            let baseFieldHeight: CGFloat = 40.0
            

            self.component = component
            self.state = state

            let hasMediaRecording = component.audioRecorder != nil || component.videoRecordingStatus != nil
            let hasMediaEditing = component.recordedAudioPreview != nil
            
            let topGradientHeight: CGFloat = 32.0
            if self.gradientView.image == nil {
                let baseAlpha: CGFloat = 0.7
                
                self.gradientView.image = generateImage(CGSize(width: insets.left + insets.right + baseFieldHeight, height: topGradientHeight + insets.top + baseFieldHeight + insets.bottom), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    var locations: [CGFloat] = []
                    var colors: [CGColor] = []
                    let numStops = 10
                    for i in 0 ..< numStops {
                        let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                        locations.append((1.0 - step))
                        let alphaStep: CGFloat = pow(step, 1.5)
                        colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                    }
                    
                    if let gradient = CGGradient(colorsSpace: context.colorSpace, colors: colors as CFArray, locations: &locations) {
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: 0.0, y: 0.0), options: CGGradientDrawingOptions())
                    }
                    
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: insets.left, y: topGradientHeight + insets.top), size: CGSize(width: baseFieldHeight, height: baseFieldHeight)).insetBy(dx: 3.0, dy: 3.0))
                })?.resizableImage(withCapInsets: UIEdgeInsets(top: topGradientHeight + insets.top + baseFieldHeight * 0.5, left: insets.left + baseFieldHeight * 0.5, bottom: insets.bottom + baseFieldHeight * 0.5, right: insets.right + baseFieldHeight * 0.5))
                
                self.bottomGradientView.backgroundColor = UIColor.black.withAlphaComponent(baseAlpha)
            }
            
            let availableTextFieldSize = CGSize(width: availableSize.width - insets.left - insets.right, height: availableSize.height - insets.top - insets.bottom)
            
            self.textField.parentState = state
            let textFieldSize = self.textField.update(
                transition: .immediate,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    strings: component.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: UIColor(rgb: 0xffffff),
                    insets: UIEdgeInsets(top: 9.0, left: 8.0, bottom: 10.0, right: 48.0),
                    hideKeyboard: component.hideKeyboard,
                    present: { c in
                        component.presentController(c)
                    }
                )),
                environment: {},
                containerSize: availableTextFieldSize
            )
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.placeholder,
                    font: Font.regular(17.0),
                    color: UIColor(rgb: 0xffffff, alpha: 0.3)
                )),
                environment: {},
                containerSize: availableTextFieldSize
            )
            
            let _ = self.vibrancyPlaceholder.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.placeholder,
                    font: Font.regular(17.0),
                    color: .white
                )),
                environment: {},
                containerSize: availableTextFieldSize
            )
            if !self.textFieldExternalState.isEditing && component.setMediaRecordingActive == nil {
                insets.right = insets.left
            }
            
            let fieldFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: availableSize.width - insets.left - insets.right, height: textFieldSize.height))
            
            let fieldBackgroundFrame: CGRect
            if hasMediaRecording {
                fieldBackgroundFrame = CGRect(origin: CGPoint(x: mediaInsets.left, y: insets.top), size: CGSize(width: availableSize.width - mediaInsets.left - mediaInsets.right, height: textFieldSize.height))
            } else {
                fieldBackgroundFrame = fieldFrame
            }
            
            transition.setFrame(view: self.vibrancyEffectView, frame: CGRect(origin: CGPoint(), size: fieldBackgroundFrame.size))
            
            transition.setFrame(view: self.fieldBackgroundView, frame: fieldBackgroundFrame)
            self.fieldBackgroundView.update(size: fieldBackgroundFrame.size, cornerRadius: baseFieldHeight * 0.5, transition: transition.containedViewLayoutTransition)
            
            let gradientFrame = CGRect(origin: CGPoint(x: fieldBackgroundFrame.minX - fieldFrame.minX, y: -topGradientHeight), size: CGSize(width: availableSize.width - (fieldBackgroundFrame.minX - fieldFrame.minX), height: topGradientHeight + fieldBackgroundFrame.maxY + insets.bottom))
            transition.setFrame(view: self.gradientView, frame: gradientFrame)
            transition.setFrame(view: self.bottomGradientView, frame: CGRect(origin: CGPoint(x: 0.0, y: gradientFrame.maxY), size: CGSize(width: availableSize.width, height: component.bottomInset)))
            transition.setAlpha(view: self.gradientView, alpha: component.displayGradient ? 1.0 : 0.0)
            transition.setAlpha(view: self.bottomGradientView, alpha: component.displayGradient ? 1.0 : 0.0)

            let placeholderOriginX: CGFloat
            if self.textFieldExternalState.isEditing || component.style == .story {
                placeholderOriginX = 16.0
            } else {
                placeholderOriginX = floorToScreenPixels((availableSize.width - placeholderSize.width) / 2.0)
            }
            let placeholderFrame = CGRect(origin: CGPoint(x: placeholderOriginX, y: floor((fieldBackgroundFrame.height - placeholderSize.height) * 0.5)), size: placeholderSize)
            if let placeholderView = self.placeholder.view, let vibrancyPlaceholderView = self.vibrancyPlaceholder.view {
                if vibrancyPlaceholderView.superview == nil {
                    vibrancyPlaceholderView.layer.anchorPoint = CGPoint()
                    self.vibrancyEffectView.contentView.addSubview(vibrancyPlaceholderView)
                }
                transition.setPosition(view: vibrancyPlaceholderView, position: placeholderFrame.origin)
                vibrancyPlaceholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                if placeholderView.superview == nil {
                    placeholderView.isUserInteractionEnabled = false
                    placeholderView.layer.anchorPoint = CGPoint()
                    self.fieldBackgroundView.addSubview(placeholderView)
                }
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                transition.setAlpha(view: placeholderView, alpha: (hasMediaRecording || hasMediaEditing || component.disabledPlaceholder != nil) ? 0.0 : 1.0)
                transition.setAlpha(view: vibrancyPlaceholderView, alpha: (hasMediaRecording || hasMediaEditing || component.disabledPlaceholder != nil) ? 0.0 : 1.0)
            }
            
            transition.setAlpha(view: self.fieldBackgroundView, alpha: component.disabledPlaceholder != nil ? 0.0 : 1.0)
            
            let size = CGSize(width: availableSize.width, height: textFieldSize.height + insets.top + insets.bottom)
            
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.addSubview(textFieldView)
                }
                transition.setFrame(view: textFieldView, frame: CGRect(origin: CGPoint(x: fieldBackgroundFrame.minX, y: fieldBackgroundFrame.maxY - textFieldSize.height), size: textFieldSize))
                transition.setAlpha(view: textFieldView, alpha: (hasMediaRecording || hasMediaEditing || component.disabledPlaceholder != nil) ? 0.0 : 1.0)
            }
            
            if let disabledPlaceholderText = component.disabledPlaceholder {
                let disabledPlaceholder: ComponentView<Empty>
                var disabledPlaceholderTransition = transition
                if let current = self.disabledPlaceholder {
                    disabledPlaceholder = current
                } else {
                    disabledPlaceholderTransition = .immediate
                    disabledPlaceholder = ComponentView()
                    self.disabledPlaceholder = disabledPlaceholder
                }
                let disabledPlaceholderSize = disabledPlaceholder.update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: disabledPlaceholderText, font: Font.regular(17.0), color: UIColor(rgb: 0xffffff, alpha: 0.3))),
                    environment: {},
                    containerSize: CGSize(width: fieldBackgroundFrame.width - 8.0 * 2.0, height: 100.0)
                )
                let disabledPlaceholderFrame = CGRect(origin: CGPoint(x: fieldBackgroundFrame.minX + floor((fieldBackgroundFrame.width - disabledPlaceholderSize.width) * 0.5), y: fieldBackgroundFrame.minY + floor((fieldBackgroundFrame.height - disabledPlaceholderSize.height) * 0.5)), size: disabledPlaceholderSize)
                if let disabledPlaceholderView = disabledPlaceholder.view {
                    if disabledPlaceholderView.superview == nil {
                        self.addSubview(disabledPlaceholderView)
                    }
                    disabledPlaceholderTransition.setPosition(view: disabledPlaceholderView, position: disabledPlaceholderFrame.center)
                    disabledPlaceholderView.bounds = CGRect(origin: CGPoint(), size: disabledPlaceholderFrame.size)
                }
            } else {
                if let disabledPlaceholder = self.disabledPlaceholder {
                    self.disabledPlaceholder = nil
                    disabledPlaceholder.view?.removeFromSuperview()
                }
            }
            
            if component.attachmentAction != nil {
                let attachmentButtonMode: MessageInputActionButtonComponent.Mode
                if !self.textFieldExternalState.isEditing && component.moreAction != nil {
                    attachmentButtonMode = .more
                } else {
                    attachmentButtonMode = .attach
                }
                
                let attachmentButtonSize = self.attachmentButton.update(
                    transition: transition,
                    component: AnyComponent(MessageInputActionButtonComponent(
                        mode: attachmentButtonMode,
                        action: { [weak self] mode, action, sendAction in
                            guard let self, let component = self.component, case .up = action else {
                                return
                            }
                            
                            switch mode {
                            case .delete:
                                break
                            case .attach:
                                component.attachmentAction?()
                            default:
                                break
                            }
                        },
                        switchMediaInputMode: {
                        },
                        updateMediaCancelFraction: { _ in
                        },
                        lockMediaRecording: {
                        },
                        stopAndPreviewMediaRecording: {
                        },
                        moreAction: { [weak self] view, gesture in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.moreAction?(view, gesture)
                        },
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        presentController: component.presentController,
                        audioRecorder: nil,
                        videoRecordingStatus: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 33.0, height: baseFieldHeight)
                )
                if let attachmentButtonView = self.attachmentButton.view {
                    if attachmentButtonView.superview == nil {
                        self.addSubview(attachmentButtonView)
                    }
                    let attachmentButtonFrame = CGRect(origin: CGPoint(x: floor((insets.left - attachmentButtonSize.width) * 0.5) + (fieldBackgroundFrame.minX - fieldFrame.minX), y: size.height - insets.bottom - baseFieldHeight + floor((baseFieldHeight - attachmentButtonSize.height) * 0.5)), size: attachmentButtonSize)
                    transition.setPosition(view: attachmentButtonView, position: attachmentButtonFrame.center)
                    transition.setBounds(view: attachmentButtonView, bounds: CGRect(origin: CGPoint(), size: attachmentButtonFrame.size))
                    transition.setAlpha(view: attachmentButtonView, alpha: (hasMediaRecording || hasMediaEditing) ? 0.0 : 1.0)
                    transition.setScale(view: attachmentButtonView, scale: hasMediaEditing ? 0.001 : 1.0)
                }
            }
            
            if hasMediaEditing {
                let deleteMediaPreviewButton: ComponentView<Empty>
                var deleteMediaPreviewButtonTransition = transition
                if let current = self.deleteMediaPreviewButton {
                    deleteMediaPreviewButton = current
                } else {
                    if !transition.animation.isImmediate {
                        deleteMediaPreviewButtonTransition = .immediate
                    }
                    deleteMediaPreviewButton = ComponentView()
                    self.deleteMediaPreviewButton = deleteMediaPreviewButton
                }
                let buttonSize = CGSize(width: 40.0, height: 40.0)
                let deleteMediaPreviewButtonFrame = CGRect(origin: CGPoint(x: 1.0 + (fieldBackgroundFrame.minX - fieldFrame.minX), y: 3.0 + floor((size.height - buttonSize.height) * 0.5)), size: CGSize(width: buttonSize.width, height: buttonSize.height))
                let _ = deleteMediaPreviewButton.update(
                    transition: deleteMediaPreviewButtonTransition,
                    component: AnyComponent(Button(
                        content: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "BinBlue"),
                            color: .white,
                            startingPosition: .begin
                        )),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.discardMediaRecordingPreview?()
                        }
                    ).minSize(buttonSize)),
                    environment: {},
                    containerSize: buttonSize
                )
                if let deleteMediaPreviewButtonView = deleteMediaPreviewButton.view {
                    if deleteMediaPreviewButtonView.superview == nil {
                        self.addSubview(deleteMediaPreviewButtonView)
                        transition.animateAlpha(view: deleteMediaPreviewButtonView, from: 0.0, to: 1.0)
                        transition.animatePosition(view: deleteMediaPreviewButtonView, from: CGPoint(x: mediaInsets.left - insets.left, y: 0.0), to: CGPoint(), additive: true)
                    }
                    deleteMediaPreviewButtonTransition.setFrame(view: deleteMediaPreviewButtonView, frame: deleteMediaPreviewButtonFrame)
                }
            } else if let deleteMediaPreviewButton = self.deleteMediaPreviewButton {
                self.deleteMediaPreviewButton = nil
                if let deleteMediaPreviewButtonView = deleteMediaPreviewButton.view {
                    if component.wasRecordingDismissed, let deleteMediaPreviewButtonView = deleteMediaPreviewButtonView as? Button.View, let animationView = deleteMediaPreviewButtonView.content as? LottieComponent.View {
                        if let attachmentButtonView = self.attachmentButton.view {
                            attachmentButtonView.isHidden = true
                        }
                        animationView.playOnce(completion: { [weak self, weak deleteMediaPreviewButtonView] in
                            guard let self, let deleteMediaPreviewButtonView else {
                                return
                            }
                            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setAlpha(view: deleteMediaPreviewButtonView, alpha: 0.0, completion: { [weak deleteMediaPreviewButtonView] _ in
                                deleteMediaPreviewButtonView?.removeFromSuperview()
                            })
                            transition.setScale(view: deleteMediaPreviewButtonView, scale: 0.001)
                            
                            if let attachmentButtonView = self.attachmentButton.view {
                                attachmentButtonView.isHidden = false
                                
                                transition.animateAlpha(view: attachmentButtonView, from: 0.0, to: attachmentButtonView.alpha)
                                transition.animateScale(view: attachmentButtonView, from: 0.001, to: 1.0)
                            }
                        })
                    } else {
                        transition.setAlpha(view: deleteMediaPreviewButtonView, alpha: 0.0, completion: { [weak deleteMediaPreviewButtonView] _ in
                            deleteMediaPreviewButtonView?.removeFromSuperview()
                        })
                        transition.setScale(view: deleteMediaPreviewButtonView, scale: 0.001)
                    }
                }
            }
            
            let inputActionButtonMode: MessageInputActionButtonComponent.Mode
            if case .editor = component.style {
                inputActionButtonMode = self.textFieldExternalState.isEditing ? .apply : .none
            } else {
                if hasMediaEditing {
                    inputActionButtonMode = .send
                } else {
                    if self.textFieldExternalState.hasText {
                        inputActionButtonMode = .send
                    } else if !self.textFieldExternalState.isEditing && component.forwardAction != nil {
                        inputActionButtonMode = .forward
                    } else {
                        if component.areVoiceMessagesAvailable {
                            inputActionButtonMode = self.currentMediaInputIsVoice ? .voiceInput : .videoInput
                        } else {
                            inputActionButtonMode = .unavailableVoiceInput
                        }
                    }
                }
            }
            let inputActionButtonSize = self.inputActionButton.update(
                transition: transition,
                component: AnyComponent(MessageInputActionButtonComponent(
                    mode: inputActionButtonMode,
                    action: { [weak self] mode, action, sendAction in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        switch mode {
                        case .none:
                            break
                        case .send:
                            if case .up = action {
                                if component.recordedAudioPreview != nil {
                                    component.sendMessageAction()
                                } else if case let .text(string) = self.getSendMessageInput(), string.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                } else {
                                    component.sendMessageAction()
                                }
                            }
                        case .apply:
                            if case .up = action {
                                component.sendMessageAction()
                            }
                        case .voiceInput, .videoInput:
                            component.setMediaRecordingActive?(action == .down, mode == .videoInput, sendAction)
                        case .forward:
                            if case .up = action {
                                component.forwardAction?()
                            }
                        case .unavailableVoiceInput:
                            if let view = self.inputActionButton.view {
                                component.presentVoiceMessagesUnavailableTooltip?(view)
                            }
                        default:
                            break
                        }
                    },
                    switchMediaInputMode: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        self.currentMediaInputIsVoice = !self.currentMediaInputIsVoice
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                    },
                    updateMediaCancelFraction: { [weak self] mediaCancelFraction in
                        guard let self else {
                            return
                        }
                        if self.mediaCancelFraction != mediaCancelFraction {
                            self.mediaCancelFraction = mediaCancelFraction
                            self.state?.updated(transition: .immediate)
                        }
                    },
                    lockMediaRecording: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.lockMediaRecording?()
                    },
                    stopAndPreviewMediaRecording: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.stopAndPreviewMediaRecording?()
                    },
                    moreAction: { _, _ in },
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    presentController: component.presentController,
                    audioRecorder: component.audioRecorder,
                    videoRecordingStatus: component.videoRecordingStatus
                )),
                environment: {},
                containerSize: CGSize(width: 33.0, height: 33.0)
            )
            if let inputActionButtonView = self.inputActionButton.view {
                if inputActionButtonView.superview == nil {
                    self.addSubview(inputActionButtonView)
                }
                let inputActionButtonOriginX: CGFloat
                if component.setMediaRecordingActive != nil || self.textFieldExternalState.isEditing {
                    inputActionButtonOriginX = size.width - insets.right + floorToScreenPixels((insets.right - inputActionButtonSize.width) * 0.5)
                } else {
                    inputActionButtonOriginX = size.width
                }
                transition.setFrame(view: inputActionButtonView, frame: CGRect(origin: CGPoint(x: inputActionButtonOriginX, y: size.height - insets.bottom - baseFieldHeight + floorToScreenPixels((baseFieldHeight - inputActionButtonSize.height) * 0.5)), size: inputActionButtonSize))
            }
        
            var fieldIconNextX = fieldBackgroundFrame.maxX - 4.0
            
            var inputModeVisible = false
            if component.style == .story || self.textFieldExternalState.isEditing {
                inputModeVisible = true
            }
            
            let animationName: String
            var animationPlay = false
            
            let previousInputMode = self.currentInputMode
            let inputMode = component.nextInputMode(self.textFieldExternalState.hasText)
            self.currentInputMode = inputMode
            
            if let inputMode {
                self.currentInputMode = inputMode
                switch inputMode {
                case .text:
                    if let previousInputMode {
                        if case .stickers = previousInputMode {
                            animationName = "input_anim_stickerToKey"
                            animationPlay = true
                        } else if case .emoji = previousInputMode {
                            animationName = "input_anim_smileToKey"
                            animationPlay = true
                        } else {
                            animationName = "input_anim_stickerToKey"
                        }
                    } else {
                        animationName = "input_anim_stickerToKey"
                    }
                case .stickers:
                    if let previousInputMode {
                        if case .text = previousInputMode {
                            animationName = "input_anim_keyToSticker"
                            animationPlay = true
                        } else if case .emoji = previousInputMode {
                            animationName = "input_anim_smileToSticker"
                            animationPlay = true
                        } else {
                            animationName = "input_anim_keyToSticker"
                        }
                    } else {
                        animationName = "input_anim_keyToSticker"
                    }
                case .emoji:
                    if let previousInputMode {
                        if case .text = previousInputMode {
                            animationName = "input_anim_keyToSmile"
                            animationPlay = true
                        } else if case .stickers = previousInputMode {
                            animationName = "input_anim_stickerToSmile"
                            animationPlay = true
                        } else {
                            animationName = "input_anim_keyToSmile"
                        }
                    } else {
                        animationName = "input_anim_keyToSmile"
                    }
                }
            } else {
                animationName = ""
            }
            
            let stickerButtonSize = self.stickerButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: animationName),
                        color: .white
                    )),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.component?.inputModeAction?()
                    }
                ).minSize(CGSize(width: 32.0, height: 32.0))),
                environment: {},
                containerSize: CGSize(width: 32.0, height: 32.0)
            )
            if let stickerButtonView = self.stickerButton.view as? Button.View {
                if stickerButtonView.superview == nil {
                    self.addSubview(stickerButtonView)
                }
                let stickerIconFrame = CGRect(origin: CGPoint(x: fieldIconNextX - stickerButtonSize.width, y: fieldFrame.maxY - 4.0 - stickerButtonSize.height), size: stickerButtonSize)
                transition.setPosition(view: stickerButtonView, position: stickerIconFrame.center)
                transition.setBounds(view: stickerButtonView, bounds: CGRect(origin: CGPoint(), size: stickerIconFrame.size))
                
                transition.setAlpha(view: stickerButtonView, alpha: (hasMediaRecording || hasMediaEditing || !inputModeVisible || component.disabledPlaceholder != nil) ? 0.0 : 1.0)
                transition.setScale(view: stickerButtonView, scale: (hasMediaRecording || hasMediaEditing || !inputModeVisible) ? 0.1 : 1.0)
                
                if inputModeVisible {
                    fieldIconNextX -= stickerButtonSize.width + 2.0
                    
                    if let animationView = stickerButtonView.content as? LottieComponent.View {
                        if animationPlay {
                            animationView.playOnce()
                        }
                    }
                }
            }
            
            if let timeoutAction = component.timeoutAction, let timeoutValue = component.timeoutValue {
                func generateIcon(value: String) -> UIImage? {
                    let image = UIImage(bundleImageName: "Media Editor/Timeout")!
                    let valueString = NSAttributedString(string: value, font: Font.with(size: value.count == 1 ? 12.0 : 10.0, design: .round, weight: .semibold), textColor: .white, paragraphAlignment: .center)
                   
                    return generateImage(image.size, contextGenerator: { size, context in
                        let bounds = CGRect(origin: CGPoint(), size: size)
                        context.clear(bounds)
                        
                        if let cgImage = image.cgImage {
                            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                        }
                        
                        var offset: CGPoint = CGPoint(x: 0.0, y: -3.0 - UIScreenPixel)
                        if value == "∞" {
                            offset.x += UIScreenPixel
                            offset.y += 1.0 - UIScreenPixel
                        }
                        
                        let valuePath = CGMutablePath()
                        valuePath.addRect(bounds.offsetBy(dx: offset.x, dy: offset.y))
                        let valueFramesetter = CTFramesetterCreateWithAttributedString(valueString as CFAttributedString)
                        let valyeFrame = CTFramesetterCreateFrame(valueFramesetter, CFRangeMake(0, valueString.length), valuePath, nil)
                        CTFrameDraw(valyeFrame, context)
                    })?.withRenderingMode(.alwaysTemplate)
                }
                
                let icon = generateIcon(value: timeoutValue)
                let timeoutButtonSize = self.timeoutButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(Image(image: icon, tintColor: component.timeoutSelected ? UIColor(rgb: 0xf8d74a) : UIColor(white: 1.0, alpha: 1.0), size: CGSize(width: 20.0, height: 20.0))),
                        action: { [weak self] in
                            guard let self, let timeoutButtonView = self.timeoutButton.view else {
                                return
                            }
                            timeoutAction(timeoutButtonView)
                        }
                    ).minSize(CGSize(width: 32.0, height: 32.0))),
                    environment: {},
                    containerSize: CGSize(width: 32.0, height: 32.0)
                )
                if let timeoutButtonView = self.timeoutButton.view {
                    if timeoutButtonView.superview == nil {
                        self.addSubview(timeoutButtonView)
                    }
                    let originX = fieldBackgroundFrame.maxX - 4.0
                    let timeoutIconFrame = CGRect(origin: CGPoint(x: originX - timeoutButtonSize.width, y: fieldFrame.maxY - 4.0 - timeoutButtonSize.height), size: timeoutButtonSize)
                    transition.setPosition(view: timeoutButtonView, position: timeoutIconFrame.center)
                    transition.setBounds(view: timeoutButtonView, bounds: CGRect(origin: CGPoint(), size: timeoutIconFrame.size))
                    
                    transition.setAlpha(view: timeoutButtonView, alpha: self.textFieldExternalState.isEditing ? 0.0 : 1.0)
                    transition.setScale(view: timeoutButtonView, scale: self.textFieldExternalState.isEditing ? 0.1 : 1.0)
                }
            }
            
            var fieldBackgroundIsDark = false
            if self.textFieldExternalState.hasText && component.alwaysDarkWhenHasText {
                fieldBackgroundIsDark = true
            } else if self.textFieldExternalState.isEditing || component.style == .editor {
                fieldBackgroundIsDark = true
            }
            self.fieldBackgroundView.updateColor(color: fieldBackgroundIsDark ? UIColor(white: 0.0, alpha: 0.5) : UIColor(white: 1.0, alpha: 0.09), transition: transition.containedViewLayoutTransition)
            if let placeholder = self.placeholder.view, let vibrancyPlaceholderView = self.vibrancyPlaceholder.view {
                placeholder.isHidden = self.textFieldExternalState.hasText
                vibrancyPlaceholderView.isHidden = placeholder.isHidden
            }
            
            component.externalState.isEditing = self.textFieldExternalState.isEditing
            component.externalState.hasText = self.textFieldExternalState.hasText
            component.externalState.insertText = { [weak self] text in
                if let self, let view = self.textField.view as? TextFieldComponent.View {
                    view.insertText(text)
                }
            }
            component.externalState.deleteBackward = { [weak self] in
                if let self, let view = self.textField.view as? TextFieldComponent.View {
                    view.deleteBackward()
                }
            }
            component.externalState.isKeyboardHidden = component.hideKeyboard
            
            if hasMediaRecording {
                if let dismissingMediaRecordingPanel = self.dismissingMediaRecordingPanel {
                    self.dismissingMediaRecordingPanel = nil
                    transition.setAlpha(view: dismissingMediaRecordingPanel, alpha: 0.0, completion: { [weak dismissingMediaRecordingPanel] _ in
                        dismissingMediaRecordingPanel?.removeFromSuperview()
                    })
                }
                
                let mediaRecordingPanel: ComponentView<Empty>
                var mediaRecordingPanelTransition = transition
                if let current = self.mediaRecordingPanel {
                    mediaRecordingPanel = current
                } else {
                    mediaRecordingPanelTransition = .immediate
                    mediaRecordingPanel = ComponentView()
                    self.mediaRecordingPanel = mediaRecordingPanel
                }
                
                let _ = mediaRecordingPanel.update(
                    transition: mediaRecordingPanelTransition,
                    component: AnyComponent(MediaRecordingPanelComponent(
                        theme: component.theme,
                        strings: component.strings,
                        audioRecorder: component.audioRecorder,
                        videoRecordingStatus: component.videoRecordingStatus,
                        isRecordingLocked: component.isRecordingLocked,
                        cancelFraction: self.mediaCancelFraction,
                        inputInsets: insets,
                        insets: mediaInsets,
                        cancelAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setMediaRecordingActive?(false, false, false)
                        }
                    )),
                    environment: {},
                    containerSize: size
                )
                if let mediaRecordingPanelView = mediaRecordingPanel.view as? MediaRecordingPanelComponent.View {
                    var animateIn = false
                    if mediaRecordingPanelView.superview == nil {
                        animateIn = true
                        self.insertSubview(mediaRecordingPanelView, aboveSubview: self.fieldBackgroundView)
                        
                        self.mediaRecordingVibrancyContainer.addSubview(mediaRecordingPanelView.vibrancyContainer)
                    }
                    mediaRecordingPanelTransition.setFrame(view: mediaRecordingPanelView, frame: CGRect(origin: CGPoint(), size: size))
                    mediaRecordingPanelTransition.setFrame(view: self.mediaRecordingVibrancyContainer, frame: CGRect(origin: CGPoint(x: -fieldBackgroundFrame.minX, y: -fieldBackgroundFrame.minY), size: size))
                    
                    if animateIn && !transition.animation.isImmediate {
                        mediaRecordingPanelView.animateIn()
                    }
                }
            } else {
                if let mediaRecordingPanel = self.mediaRecordingPanel {
                    self.mediaRecordingPanel = nil
                    
                    if let dismissingMediaRecordingPanel = self.dismissingMediaRecordingPanel {
                        self.dismissingMediaRecordingPanel = nil
                        transition.setAlpha(view: dismissingMediaRecordingPanel, alpha: 0.0, completion: { [weak dismissingMediaRecordingPanel] _ in
                            dismissingMediaRecordingPanel?.removeFromSuperview()
                        })
                    }
                    
                    self.dismissingMediaRecordingPanel = mediaRecordingPanel.view
                    
                    if let mediaRecordingPanelView = mediaRecordingPanel.view as? MediaRecordingPanelComponent.View {
                        let wasRecordingDismissed = component.wasRecordingDismissed
                        if wasRecordingDismissed, let attachmentButtonView = self.attachmentButton.view {
                            attachmentButtonView.isHidden = true
                        }
                        mediaRecordingPanelView.animateOut(transition: transition, dismissRecording: wasRecordingDismissed, completion: { [weak self, weak mediaRecordingPanelView] in
                            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                            
                            if let mediaRecordingPanelView = mediaRecordingPanelView {
                                transition.setAlpha(view: mediaRecordingPanelView, alpha: 0.0, completion: { [weak mediaRecordingPanelView] _ in
                                    mediaRecordingPanelView?.removeFromSuperview()
                                })
                            }
                            
                            guard let self else {
                                return
                            }
                            if wasRecordingDismissed, self.mediaRecordingPanel == nil, let attachmentButtonView = self.attachmentButton.view {
                                attachmentButtonView.isHidden = false
                                
                                transition.animateAlpha(view: attachmentButtonView, from: 0.0, to: attachmentButtonView.alpha)
                                transition.animateScale(view: attachmentButtonView, from: 0.001, to: 1.0)
                            }
                        })
                    }
                }
            }
            
            if let recordedAudioPreview = component.recordedAudioPreview {
                let mediaPreviewPanel: ComponentView<Empty>
                var mediaPreviewPanelTransition = transition
                if let current = self.mediaPreviewPanel {
                    mediaPreviewPanel = current
                } else {
                    mediaPreviewPanelTransition = .immediate
                    mediaPreviewPanel = ComponentView()
                    self.mediaPreviewPanel = mediaPreviewPanel
                }
                
                let _ = mediaPreviewPanel.update(
                    transition: mediaPreviewPanelTransition,
                    component: AnyComponent(MediaPreviewPanelComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        mediaPreview: recordedAudioPreview,
                        insets: insets
                    )),
                    environment: {},
                    containerSize: size
                )
                if let mediaPreviewPanelView = mediaPreviewPanel.view as? MediaPreviewPanelComponent.View {
                    var animateIn = false
                    if mediaPreviewPanelView.superview == nil {
                        animateIn = true
                        self.insertSubview(mediaPreviewPanelView, aboveSubview: self.fieldBackgroundView)
                        
                        self.mediaRecordingVibrancyContainer.addSubview(mediaPreviewPanelView.vibrancyContainer)
                    }
                    mediaPreviewPanelTransition.setFrame(view: mediaPreviewPanelView, frame: CGRect(origin: CGPoint(), size: size))
                    mediaPreviewPanelTransition.setFrame(view: self.mediaRecordingVibrancyContainer, frame: CGRect(origin: CGPoint(x: -fieldBackgroundFrame.minX, y: -fieldBackgroundFrame.minY), size: size))
                    
                    if animateIn && !transition.animation.isImmediate {
                        mediaPreviewPanelView.animateIn()
                    }
                }
            } else {
                if let mediaPreviewPanel = self.mediaPreviewPanel {
                    self.mediaPreviewPanel = nil
                    
                    if let mediaPreviewPanelView = mediaPreviewPanel.view as? MediaPreviewPanelComponent.View {
                        mediaPreviewPanelView.animateOut(transition: transition, completion: { [weak mediaPreviewPanelView] in
                            mediaPreviewPanelView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            self.updateContextQueries()
            
            if let result = self.contextQueryResults[.mention], result.count > 0 && self.textFieldExternalState.isEditing {
                let availablePanelHeight: CGFloat = 413.0
                
                var animateIn = false
                let panel: ComponentView<Empty>
                let externalState: ContextResultPanelComponent.ExternalState
                var transition = transition
                if let current = self.contextQueryResultPanel, let currentState = self.contextQueryResultPanelExternalState {
                    panel = current
                    externalState = currentState
                } else {
                    panel = ComponentView<Empty>()
                    externalState = ContextResultPanelComponent.ExternalState()
                    self.contextQueryResultPanel = panel
                    self.contextQueryResultPanelExternalState = externalState
                    animateIn = true
                    transition = .immediate
                }
                let panelLeftInset: CGFloat = max(insets.left, 7.0)
                let panelRightInset: CGFloat = max(insets.right, 41.0)
                let panelSize = panel.update(
                    transition: transition,
                    component: AnyComponent(ContextResultPanelComponent(
                        externalState: externalState,
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        results: result,
                        action: { [weak self] action in
                            if let self, case let .mention(peer) = action, let textView = self.textField.view as? TextFieldComponent.View {
                                let inputState = textView.getInputState()
                                
                                var mentionQueryRange: NSRange?
                                inner: for (range, type, _) in textInputStateContextQueryRangeAndType(inputState: inputState) {
                                    if type == [.mention] {
                                        mentionQueryRange = range
                                        break inner
                                    }
                                }
                                
                                if let range = mentionQueryRange {
                                    let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                                    if let addressName = peer.addressName, !addressName.isEmpty {
                                        let replacementText = addressName + " "
                                        inputText.replaceCharacters(in: range, with: replacementText)
                                        
                                        let selectionPosition = range.lowerBound + (replacementText as NSString).length
                                        textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                                    } else if !peer.compactDisplayTitle.isEmpty {
                                        let replacementText = NSMutableAttributedString()
                                        replacementText.append(NSAttributedString(string: peer.compactDisplayTitle, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
                                        replacementText.append(NSAttributedString(string: " "))
                                        
                                        let updatedRange = NSRange(location: range.location - 1, length: range.length + 1)
                                        inputText.replaceCharacters(in: updatedRange, with: replacementText)
                                        
                                        let selectionPosition = updatedRange.lowerBound + replacementText.length
                                        textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                                    }
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - panelLeftInset - panelRightInset, height: availablePanelHeight)
                )
                
                let panelFrame = CGRect(origin: CGPoint(x: insets.left, y: -panelSize.height + 33.0), size: panelSize)
                if let panelView = panel.view as? ContextResultPanelComponent.View {
                    if panelView.superview == nil {
                        self.insertSubview(panelView, at: 0)
                    }
                    transition.setFrame(view: panelView, frame: panelFrame)
                    
                    if animateIn {
                        panelView.animateIn(transition: .spring(duration: 0.4))
                    }
                }
                
            } else if let contextQueryResultPanel = self.contextQueryResultPanel?.view as? ContextResultPanelComponent.View {
                self.contextQueryResultPanel = nil
                contextQueryResultPanel.animateOut(transition: .spring(duration: 0.4), completion: { [weak contextQueryResultPanel] in
                    contextQueryResultPanel?.removeFromSuperview()
                })
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
