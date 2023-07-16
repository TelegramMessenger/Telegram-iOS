import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import ChatTextInputMediaRecordingButton
import AccountContext
import TelegramPresentationData
import ChatPresentationInterfaceState
import MoreHeaderButton
import ContextUI

private extension MessageInputActionButtonComponent.Mode {
    var iconName: String? {
        switch self {
        case .delete:
            return "Chat/Context Menu/Delete"
        case .attach:
            return "Chat/Input/Text/IconAttachment"
        case .forward:
            return "Chat/Input/Text/IconForwardSend"
        default:
            return nil
        }
    }
}

public final class MessageInputActionButtonComponent: Component {
    public enum Mode {
        case none
        case send
        case apply
        case voiceInput
        case videoInput
        case unavailableVoiceInput
        case delete
        case attach
        case forward
        case more
    }
    
    public enum Action {
        case down
        case up
    }

    public let mode: Mode
    public let action: (Mode, Action, Bool) -> Void
    public let longPressAction: ((UIView, ContextGesture?) -> Void)?
    public let switchMediaInputMode: () -> Void
    public let updateMediaCancelFraction: (CGFloat) -> Void
    public let lockMediaRecording: () -> Void
    public let stopAndPreviewMediaRecording: () -> Void
    public let moreAction: (UIView, ContextGesture?) -> Void
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let presentController: (ViewController) -> Void
    public let audioRecorder: ManagedAudioRecorder?
    public let videoRecordingStatus: InstantVideoControllerRecordingStatus?
    
    public init(
        mode: Mode,
        action: @escaping (Mode, Action, Bool) -> Void,
        longPressAction: ((UIView, ContextGesture?) -> Void)?,
        switchMediaInputMode: @escaping () -> Void,
        updateMediaCancelFraction: @escaping (CGFloat) -> Void,
        lockMediaRecording: @escaping () -> Void,
        stopAndPreviewMediaRecording: @escaping () -> Void,
        moreAction: @escaping (UIView, ContextGesture?) -> Void,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        presentController: @escaping (ViewController) -> Void,
        audioRecorder: ManagedAudioRecorder?,
        videoRecordingStatus: InstantVideoControllerRecordingStatus?
    ) {
        self.mode = mode
        self.action = action
        self.longPressAction = longPressAction
        self.switchMediaInputMode = switchMediaInputMode
        self.updateMediaCancelFraction = updateMediaCancelFraction
        self.lockMediaRecording = lockMediaRecording
        self.stopAndPreviewMediaRecording = stopAndPreviewMediaRecording
        self.moreAction = moreAction
        self.context = context
        self.theme = theme
        self.strings = strings
        self.presentController = presentController
        self.audioRecorder = audioRecorder
        self.videoRecordingStatus = videoRecordingStatus
    }
    
    public static func ==(lhs: MessageInputActionButtonComponent, rhs: MessageInputActionButtonComponent) -> Bool {
        if lhs.mode != rhs.mode {
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
        if lhs.audioRecorder !== rhs.audioRecorder {
            return false
        }
        if lhs.videoRecordingStatus !== rhs.videoRecordingStatus {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var micButton: ChatTextInputMediaRecordingButton?
        
        public let button: HighlightTrackingButtonNode
        public let referenceNode: ContextReferenceContentNode
        public let containerNode: ContextControllerSourceNode
        private let sendIconView: UIImageView
        
        private var moreButton: MoreHeaderButton?
        
        private var component: MessageInputActionButtonComponent?
        private weak var componentState: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.sendIconView = UIImageView()
            
            self.button = HighlightTrackingButtonNode()
            self.referenceNode = ContextReferenceContentNode()
            self.containerNode = ContextControllerSourceNode()
            
            super.init(frame: frame)
                             
            self.addSubview(self.button.view)
            self.containerNode.addSubnode(self.referenceNode)
            self.referenceNode.view.addSubview(self.sendIconView)
            self.button.addSubnode(self.containerNode)

            self.containerNode.shouldBegin = { [weak self] location in
                guard let self, let component = self.component, let _ = component.longPressAction else {
                    return false
                }
                return true
            }
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component, let longPressAction = component.longPressAction else {
                    return
                }
                longPressAction(self, gesture)
            }
            
            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                
                let scale: CGFloat = highlighted ? 0.6 : 1.0
                
                let transition = Transition(animation: .curve(duration: highlighted ? 0.5 : 0.3, curve: .spring))
                transition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(scale, scale, 1.0))
            }
            
            self.button.addTarget(self, action: #selector(self.touchDown), forControlEvents: .touchDown)
            self.button.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
//            but.addTarget(self, action: #selector(self.touchDown), for: .touchDown)
//            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func touchDown() {
            guard let component = self.component else {
                return
            }
            component.action(component.mode, .down, false)
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(component.mode, .up, false)
        }
                
//        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
//            let result = super.hitTest(point, with: event)
//            return result
//        }
        
        func update(component: MessageInputActionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.componentState = state
            
            let themeUpdated = previousComponent?.theme !== component.theme
            
            self.containerNode.isUserInteractionEnabled = component.longPressAction != nil
            
            if self.micButton == nil {
                let micButton = ChatTextInputMediaRecordingButton(
                    context: component.context,
                    theme: defaultDarkPresentationTheme,
                    useDarkTheme: true,
                    strings: component.strings,
                    presentController: component.presentController
                )
                self.micButton = micButton
                micButton.statusBarHost = component.context.sharedContext.mainWindow?.statusBarHost
                self.addSubview(micButton)
                
                micButton.disablesInteractiveKeyboardGestureRecognizer = true
                
                micButton.beginRecording = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    switch component.mode {
                    case .voiceInput, .videoInput:
                        component.action(component.mode, .down, false)
                    default:
                        break
                    }
                }
                micButton.stopRecording = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.stopAndPreviewMediaRecording()
                }
                micButton.endRecording = { [weak self] sendMedia in
                    guard let self, let component = self.component else {
                        return
                    }
                    switch component.mode {
                    case .voiceInput, .videoInput:
                        component.action(component.mode, .up, sendMedia)
                    default:
                        break
                    }
                }
                micButton.updateLocked = { [weak self] _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.lockMediaRecording()
                }
                micButton.switchMode = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    if case .unavailableVoiceInput = component.mode {
                        component.action(component.mode, .up, false)
                    } else {
                        component.switchMediaInputMode()
                    }
                }
                micButton.updateCancelTranslation = { [weak self] in
                    guard let self, let micButton = self.micButton, let component = self.component else {
                        return
                    }
                    component.updateMediaCancelFraction(micButton.cancelTranslation)
                }
            }
            
            if case .more = component.mode, self.moreButton == nil {
                let moreButton = MoreHeaderButton(color: .white)
                self.moreButton = moreButton
                self.addSubnode(moreButton)
                
                moreButton.isUserInteractionEnabled = true
                moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: .white)))
                moreButton.onPressed = { [weak self] in
                    guard let self, let component = self.component, let moreButton = self.moreButton else {
                        return
                    }
                    moreButton.play()
                    component.moreAction(moreButton.view, nil)
                }
                moreButton.contextAction = { [weak self] sourceNode, gesture in
                    guard let self, let component = self.component, let moreButton = self.moreButton else {
                        return
                    }
                    moreButton.play()
                    component.moreAction(moreButton.view, gesture)
                }
                self.moreButton = moreButton
                self.addSubnode(moreButton)
            }
            
            var sendAlpha: CGFloat = 0.0
            var microphoneAlpha: CGFloat = 0.0
            var moreAlpha: CGFloat = 0.0
            switch component.mode {
            case .none:
                break
            case .send, .apply, .attach, .delete, .forward:
                sendAlpha = 1.0
            case .more:
                moreAlpha = 1.0
            case .videoInput, .voiceInput:
                microphoneAlpha = 1.0
            case .unavailableVoiceInput:
                microphoneAlpha = 0.4
            }
            
            if self.sendIconView.image == nil || previousComponent?.mode.iconName != component.mode.iconName {
                if let iconName = component.mode.iconName {
                    self.sendIconView.image = generateTintedImage(image: UIImage(bundleImageName: iconName), color: .white)
                } else if case .apply = component.mode {
                    self.sendIconView.image = generateImage(CGSize(width: 33.0, height: 33.0), contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(UIColor.white.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                        
                        if let image = UIImage(bundleImageName: "Media Editor/Apply"), let cgImage = image.cgImage {
                            context.setBlendMode(.copy)
                            context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.35).cgColor)
                            context.clip(to: CGRect(origin: CGPoint(x: -4.0 + UIScreenPixel, y: -3.0 - UIScreenPixel), size: CGSize(width: 40.0, height: 40.0)), mask: cgImage)
                            context.fill(CGRect(origin: .zero, size: size))
                        }
                    })
                } else if case .none = component.mode {
                    self.sendIconView.image = nil
                } else {
                    if !transition.animation.isImmediate {
                        if let snapshotView = self.sendIconView.snapshotView(afterScreenUpdates: false) {
                            snapshotView.frame = self.sendIconView.frame
                            self.addSubview(snapshotView)
                            
                            transition.setAlpha(view: snapshotView, alpha: 0.0, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            transition.setScale(view: snapshotView, scale: 0.01)
                            
                            self.sendIconView.alpha = 0.0
                            transition.animateAlpha(view: self.sendIconView, from: 0.0, to: sendAlpha)
                            transition.animateScale(view: self.sendIconView, from: 0.01, to: 1.0)
                        }
                    }
                    self.sendIconView.image = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(UIColor.white.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                        context.setBlendMode(.copy)
                        context.setStrokeColor(UIColor.clear.cgColor)
                        context.setLineWidth(2.0)
                        context.setLineCap(.round)
                        context.setLineJoin(.round)
                        
                        context.translateBy(x: 5.45, y: 4.0)
                        
                        context.saveGState()
                        context.translateBy(x: 4.0, y: 4.0)
                        let _ = try? drawSvgPath(context, path: "M1,7 L7,1 L13,7 S ")
                        context.restoreGState()
                        
                        context.saveGState()
                        context.translateBy(x: 10.0, y: 4.0)
                        let _ = try? drawSvgPath(context, path: "M1,16 V1 S ")
                        context.restoreGState()
                    })
                }
            }
            
            transition.setFrame(view: self.button.view, frame: CGRect(origin: .zero, size: availableSize))
            transition.setFrame(view: self.containerNode.view, frame: CGRect(origin: .zero, size: availableSize))
            transition.setFrame(view: self.referenceNode.view, frame: CGRect(origin: .zero, size: availableSize))
            
            transition.setAlpha(view: self.sendIconView, alpha: sendAlpha)
            transition.setScale(view: self.sendIconView, scale: sendAlpha == 0.0 ? 0.01 : 1.0)
            
            if let image = self.sendIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - image.size.width) * 0.5), y: floorToScreenPixels((availableSize.height - image.size.height) * 0.5)), size: image.size)
                transition.setPosition(view: self.sendIconView, position: iconFrame.center)
                transition.setBounds(view: self.sendIconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            }
            
            if let moreButton = self.moreButton {
                let buttonSize = CGSize(width: 32.0, height: 44.0)
                moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: .white)))
                let moreFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - buttonSize.height) * 0.5)), size: buttonSize)
                transition.setPosition(view: moreButton.view, position: moreFrame.center)
                transition.setBounds(view: moreButton.view, bounds: CGRect(origin: CGPoint(), size: moreFrame.size))
                
                transition.setAlpha(view: moreButton.view, alpha: moreAlpha)
                transition.setScale(view: moreButton.view, scale: moreAlpha == 0.0 ? 0.01 : 1.0)
            }
            
            if let micButton = self.micButton {
                if themeUpdated {
                    micButton.updateTheme(theme: defaultDarkPresentationTheme)
                }
                
                let micButtonFrame = CGRect(origin: CGPoint(), size: availableSize)
                let shouldLayoutMicButton = micButton.bounds.size != micButtonFrame.size
                transition.setPosition(layer: micButton.layer, position: micButtonFrame.center)
                transition.setBounds(layer: micButton.layer, bounds: CGRect(origin: CGPoint(), size: micButtonFrame.size))
                if shouldLayoutMicButton {
                    micButton.layoutItems()
                }
                
                if previousComponent?.mode != component.mode {
                    switch component.mode {
                    case .none, .send, .apply, .voiceInput, .attach, .delete, .forward, .unavailableVoiceInput, .more:
                        micButton.updateMode(mode: .audio, animated: !transition.animation.isImmediate)
                    case .videoInput:
                        micButton.updateMode(mode: .video, animated: !transition.animation.isImmediate)
                    }
                }
                
                DispatchQueue.main.async { [weak self, weak micButton] in
                    guard let self, let component = self.component, let micButton else {
                        return
                    }
                    micButton.audioRecorder = component.audioRecorder
                    micButton.videoRecordingStatus = component.videoRecordingStatus
                }
                
                transition.setAlpha(view: micButton, alpha: microphoneAlpha)
                transition.setScale(view: micButton, scale: microphoneAlpha == 0.0 ? 0.01 : 1.0)
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
