import Foundation
import UIKit
import Display
import SwiftSignalKit
import MediaPlayer
import TelegramPresentationData

private enum ButtonDescription: Equatable {
    enum Key: Hashable {
        case accept
        case acceptOrEnd
        case decline
        case enableCamera
        case switchCamera
        case soundOutput
        case mute
    }
    
    enum SoundOutput {
        case builtin
        case speaker
        case bluetooth
        case airpods
        case airpodsPro
        case airpodsMax
        case headphones
    }
    
    enum EndType {
        case outgoing
        case decline
        case end
    }
    
    case accept
    case end(EndType)
    case enableCamera(isActive: Bool, isEnabled: Bool, isLoading: Bool, isScreencast: Bool)
    case switchCamera(Bool)
    case soundOutput(SoundOutput)
    case mute(Bool)
    
    var key: Key {
        switch self {
        case .accept:
            return .acceptOrEnd
        case let .end(type):
            if type == .decline {
                return .decline
            } else {
                return .acceptOrEnd
            }
        case .enableCamera:
            return .enableCamera
        case .switchCamera:
            return .switchCamera
        case .soundOutput:
            return .soundOutput
        case .mute:
            return .mute
        }
    }
}

final class CallControllerButtonsView: UIView {

    private var buttonNodes: [ButtonDescription.Key: CallControllerButtonItemNode] = [:]
    
    private var mode: CallControllerButtonsMode?
    
    private var validLayout: (CGFloat, CGFloat)?
    
    var isMuted = false
    
    var acceptOrEnd: (() -> Void)?
    var decline: (() -> Void)?
    var mute: (() -> Void)?
    var speaker: (() -> Void)?
    var toggleVideo: (() -> Void)?
    var rotateCamera: (() -> Void)?
    
    init(strings: PresentationStrings) {
        super.init(frame: CGRect.zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLayout(strings: PresentationStrings, mode: CallControllerButtonsMode, constrainedWidth: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (constrainedWidth, bottomInset)
        
        self.mode = mode
        
        if let mode = self.mode {
            return self.updateButtonsLayout(strings: strings, mode: mode, width: constrainedWidth, bottomInset: bottomInset, animated: transition.isAnimated)
        } else {
            return 0.0
        }
    }
    
    private var appliedMode: CallControllerButtonsMode?
    
    func videoButtonFrame() -> CGRect? {
        return self.buttonNodes[.enableCamera]?.frame
    }
    
    private func updateButtonsLayout(strings: PresentationStrings, mode: CallControllerButtonsMode, width: CGFloat, bottomInset: CGFloat, animated: Bool) -> CGFloat {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.3, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let previousMode = self.appliedMode
        self.appliedMode = mode
        
        var animatePositionsWithDelay = false
        if let previousMode = previousMode {
            switch previousMode {
            case .incoming, .outgoingRinging:
                if case .active = mode {
                    animatePositionsWithDelay = true
                }
            default:
                break
            }
        }
        
        let minButtonSideInset: CGFloat = width > 320.0 ? 30.0 : 16.0
        let maxButtonSpacing: CGFloat = 36.0
        let buttonSize: CGFloat = 56.0
        
        struct PlacedButton {
            let button: ButtonDescription
            let frame: CGRect
        }
        
        let height: CGFloat
        
        let speakerMode: CallControllerButtonsSpeakerMode
        var videoState: CallControllerButtonsMode.VideoState
        let hasAudioRouteMenu: Bool
        switch mode {
        case .incoming(let speakerModeValue, let hasAudioRouteMenuValue, let videoStateValue), .outgoingRinging(let speakerModeValue, let hasAudioRouteMenuValue, let videoStateValue), .active(let speakerModeValue, let hasAudioRouteMenuValue, let videoStateValue):
            speakerMode = speakerModeValue
            videoState = videoStateValue
            hasAudioRouteMenu = hasAudioRouteMenuValue
        }
        
        enum MappedState {
            case incomingRinging
            case outgoingRinging
            case active
        }
        
        let mappedState: MappedState
        switch mode {
        case .incoming:
            mappedState = .incomingRinging
        case .outgoingRinging:
            mappedState = .outgoingRinging
        case let .active(_, _, videoStateValue):
            mappedState = .active
            videoState = videoStateValue
        }
        
        var buttons: [PlacedButton] = []
        switch mappedState {
        case .incomingRinging, .outgoingRinging:
            var bottomButtons: [ButtonDescription] = []
            
            let soundOutput: ButtonDescription.SoundOutput
            switch speakerMode {
                case .none, .builtin:
                    soundOutput = .builtin
                case .speaker:
                    soundOutput = .speaker
                case .headphones:
                    soundOutput = .headphones
                case let .bluetooth(type):
                    switch type {
                        case .generic:
                            soundOutput = .bluetooth
                        case .airpods:
                            soundOutput = .airpods
                        case .airpodsPro:
                            soundOutput = .airpodsPro
                        case .airpodsMax:
                            soundOutput = .airpodsMax
                }
            }
            
            if videoState.isAvailable {
                let isCameraActive: Bool
                let isScreencastActive: Bool
                let isCameraInitializing: Bool
                if videoState.hasVideo {
                    isCameraActive = videoState.isCameraActive
                    isScreencastActive = videoState.isScreencastActive
                    isCameraInitializing = videoState.isInitializingCamera
                } else {
                    isCameraActive = false
                    isScreencastActive = false
                    isCameraInitializing = videoState.isInitializingCamera
                }
                if !videoState.hasVideo {
                    bottomButtons.append(.soundOutput(soundOutput))
                    bottomButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive,
                                                       isEnabled: false,
                                                       isLoading: isCameraInitializing,
                                                       isScreencast: isScreencastActive))
                    bottomButtons.append(.mute(self.isMuted))
                } else {
                    if !isScreencastActive {
                        bottomButtons.append(.switchCamera(isCameraActive && !isCameraInitializing))
                    }
                    bottomButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive,
                                                       isEnabled: false,
                                                       isLoading: isCameraInitializing,
                                                       isScreencast: isScreencastActive))
                    if hasAudioRouteMenu {
                        bottomButtons.append(.soundOutput(soundOutput))
                    } else {
                        bottomButtons.append(.mute(self.isMuted))
                    }
                }
            } else {
                bottomButtons.append(.soundOutput(soundOutput))
                bottomButtons.append(.mute(self.isMuted))
            }
            
            if case .incomingRinging = mappedState {
                bottomButtons.append(.end(.decline))
                bottomButtons.append(.accept)
            } else {
                bottomButtons.append(.end(.outgoing))
            }
            
            let bottomButtonsContentWidth = CGFloat(bottomButtons.count) * buttonSize
            let bottomButtonsAvailableSpacingWidth = width - bottomButtonsContentWidth - minButtonSideInset * 2.0
            let bottomButtonsSpacing = min(maxButtonSpacing, bottomButtonsAvailableSpacingWidth / CGFloat(bottomButtons.count - 1))
            let bottomButtonsWidth = CGFloat(bottomButtons.count) * buttonSize + CGFloat(bottomButtons.count - 1) * bottomButtonsSpacing
            var bottomButtonsLeftOffset = floor((width - bottomButtonsWidth) / 2.0)
            for button in bottomButtons {
                let frame = CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: 0),
                                   size: CGSize(width: buttonSize, height: buttonSize))
                buttons.append(PlacedButton(button: button, frame: frame))
                bottomButtonsLeftOffset += buttonSize + bottomButtonsSpacing
            }
            
            height = buttonSize + max(bottomInset + 52.0, 66.0)
        case .active:
            if videoState.hasVideo {
                let isCameraActive: Bool
                let isScreencastActive: Bool
                let isCameraEnabled: Bool
                let isCameraInitializing: Bool
                if videoState.hasVideo {
                    isCameraActive = videoState.isCameraActive
                    isScreencastActive = videoState.isScreencastActive
                    isCameraEnabled = videoState.canChangeStatus
                    isCameraInitializing = videoState.isInitializingCamera
                } else {
                    isCameraActive = false
                    isScreencastActive = false
                    isCameraEnabled = videoState.canChangeStatus
                    isCameraInitializing = videoState.isInitializingCamera
                }
                
                var bottomButtons: [ButtonDescription] = []
                
                let soundOutput: ButtonDescription.SoundOutput
                switch speakerMode {
                    case .none, .builtin:
                        soundOutput = .builtin
                    case .speaker:
                        soundOutput = .speaker
                    case .headphones:
                        soundOutput = .headphones
                    case let .bluetooth(type):
                        switch type {
                            case .generic:
                                soundOutput = .bluetooth
                            case .airpods:
                                soundOutput = .airpods
                            case .airpodsPro:
                                soundOutput = .airpodsPro
                            case .airpodsMax:
                                soundOutput = .airpodsMax
                    }
                }

                if videoState.isCameraActive && !isScreencastActive {
                    bottomButtons.append(.switchCamera(isCameraActive && !isCameraInitializing))
                } else {
                    bottomButtons.append(.soundOutput(soundOutput))
                }
                bottomButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive, isEnabled: isCameraEnabled, isLoading: isCameraInitializing, isScreencast: isScreencastActive))
                bottomButtons.append(.mute(isMuted))
                bottomButtons.append(.end(.end))
                
                let bottomButtonsContentWidth = CGFloat(bottomButtons.count) * buttonSize
                let bottomButtonsAvailableSpacingWidth = width - bottomButtonsContentWidth - minButtonSideInset * 2.0
                let bottomButtonsSpacing = min(maxButtonSpacing, bottomButtonsAvailableSpacingWidth / CGFloat(bottomButtons.count - 1))
                let bottomButtonsWidth = CGFloat(bottomButtons.count) * buttonSize + CGFloat(bottomButtons.count - 1) * bottomButtonsSpacing
                var bottomButtonsLeftOffset = floor((width - bottomButtonsWidth) / 2.0)
                for button in bottomButtons {
                    let frame = CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: 0),
                                       size: CGSize(width: buttonSize, height: buttonSize))
                    buttons.append(PlacedButton(button: button, frame: frame))
                    bottomButtonsLeftOffset += buttonSize + bottomButtonsSpacing
                }

                height = buttonSize + max(bottomInset + 52.0, 66.0)
            } else {
                var bottomButtons: [ButtonDescription] = []
                
                let isCameraActive: Bool
                let isScreencastActive: Bool
                let isCameraEnabled: Bool
                let isCameraInitializing: Bool
                if videoState.hasVideo {
                    isCameraActive = videoState.isCameraActive
                    isScreencastActive = videoState.isScreencastActive
                    isCameraEnabled = videoState.canChangeStatus
                    isCameraInitializing = videoState.isInitializingCamera
                } else {
                    isCameraActive = false
                    isScreencastActive = false
                    isCameraEnabled = videoState.canChangeStatus
                    isCameraInitializing = videoState.isInitializingCamera
                }
                
                let soundOutput: ButtonDescription.SoundOutput
                switch speakerMode {
                    case .none, .builtin:
                        soundOutput = .builtin
                    case .speaker:
                        soundOutput = .speaker
                    case .headphones:
                        soundOutput = .bluetooth
                    case let .bluetooth(type):
                        switch type {
                            case .generic:
                                soundOutput = .bluetooth
                            case .airpods:
                                soundOutput = .airpods
                            case .airpodsPro:
                                soundOutput = .airpodsPro
                            case .airpodsMax:
                                soundOutput = .airpodsMax
                    }
                }

                bottomButtons.append(.soundOutput(soundOutput))
                bottomButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive, isEnabled: isCameraEnabled, isLoading: isCameraInitializing, isScreencast: isScreencastActive))
                bottomButtons.append(.mute(self.isMuted))
                bottomButtons.append(.end(.outgoing))
                
                let bottomButtonsContentWidth = CGFloat(bottomButtons.count) * buttonSize
                let bottomButtonsAvailableSpacingWidth = width - bottomButtonsContentWidth - minButtonSideInset * 2.0
                let bottomButtonsSpacing = min(maxButtonSpacing, bottomButtonsAvailableSpacingWidth / CGFloat(bottomButtons.count - 1))
                let bottomButtonsWidth = CGFloat(bottomButtons.count) * buttonSize + CGFloat(bottomButtons.count - 1) * bottomButtonsSpacing
                var bottomButtonsLeftOffset = floor((width - bottomButtonsWidth) / 2.0)
                for button in bottomButtons {
                    let frame = CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: 0),
                                       size: CGSize(width: buttonSize, height: buttonSize))
                    buttons.append(PlacedButton(button: button, frame: frame))
                    bottomButtonsLeftOffset += buttonSize + bottomButtonsSpacing
                }
                
                height = buttonSize + max(bottomInset + 52.0, 66.0)
            }
        }
        
        let delayIncrement = 0.015
        var validKeys: [ButtonDescription.Key] = []
        for button in buttons {
            validKeys.append(button.button.key)
            var buttonTransition = transition
            var animateButtonIn = false
            let buttonNode: CallControllerButtonItemNode
            if let current = self.buttonNodes[button.button.key] {
                buttonNode = current
            } else {
                buttonNode = CallControllerButtonItemNode(largeButtonSize: buttonSize, useNewIcons: true)
                self.buttonNodes[button.button.key] = buttonNode
                self.addSubnode(buttonNode)
                buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
                buttonTransition = .immediate
                animateButtonIn = transition.isAnimated
            }
            let buttonContent: CallControllerButtonItemNode.Content
            let buttonText: String
            var buttonAccessibilityLabel = ""
            var buttonAccessibilityValue = ""
            var buttonAccessibilityTraits: UIAccessibilityTraits = [.button]
            switch button.button {
            case .accept:
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .color(.green),
                    image: .accept
                )
                buttonText = strings.Call_Accept
                buttonAccessibilityLabel = buttonText
            case let .end(type):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .color(.red),
                    image: .end
                )
                switch type {
                case .outgoing:
                    buttonText = strings.Call_End
                case .decline:
                    buttonText = strings.Call_Decline
                case .end:
                    buttonText = strings.Call_End
                }
                if !buttonText.isEmpty {
                    buttonAccessibilityLabel = buttonText
                } else {
                    buttonAccessibilityLabel = strings.Call_End
                }
            case let .enableCamera(isActivated, isEnabled, isInitializing, isScreencastActive):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isActivated),
                    image: isScreencastActive ? .screencast : .camera,
                    isEnabled: isEnabled,
                    hasProgress: isInitializing
                )
                buttonText = strings.Call_Camera
                buttonAccessibilityLabel = buttonText
                if !isEnabled {
                    buttonAccessibilityTraits.insert(.notEnabled)
                }
                if isActivated {
                    buttonAccessibilityTraits.insert(.selected)
                }
            case let .switchCamera(isEnabled):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: false),
                    image: .flipCamera,
                    isEnabled: isEnabled
                )
                buttonText = strings.Call_Flip
                buttonAccessibilityLabel = buttonText
                if !isEnabled {
                    buttonAccessibilityTraits.insert(.notEnabled)
                }
            case let .soundOutput(value):
                let image: CallControllerButtonItemNode.Content.Image
                var isFilled = false
                var title: String = strings.Call_Speaker
                switch value {
                case .builtin:
                    image = .speaker
                case .speaker:
                    image = .speaker
                    isFilled = true
                case .bluetooth:
                    image = .bluetooth
                    title = strings.Call_Audio
                    buttonAccessibilityValue = "Bluetooth"
                case .airpods:
                    image = .airpods
                    title = strings.Call_Audio
                    buttonAccessibilityValue = "Airpods"
                case .airpodsPro:
                    image = .airpodsPro
                    title = strings.Call_Audio
                    buttonAccessibilityValue = "Airpods Pro"
                case .airpodsMax:
                    image = .airpodsMax
                    title = strings.Call_Audio
                    buttonAccessibilityValue = "Airpods Max"
                case .headphones:
                    image = .headphones
                    title = strings.Call_Audio
                    buttonAccessibilityValue = strings.Call_AudioRouteHeadphones
                }
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isFilled),
                    image: image
                )
                buttonText = title
                buttonAccessibilityLabel = buttonText
                if isFilled {
                    buttonAccessibilityTraits.insert(.selected)
                }
            case let .mute(isMuted):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isMuted),
                    image: .mute
                )
                buttonText = strings.Call_Mute
                buttonAccessibilityLabel = buttonText
                if isMuted {
                    buttonAccessibilityTraits.insert(.selected)
                }
            }
            var buttonDelay = 0.0
            if animatePositionsWithDelay {
                switch button.button.key {
                case .enableCamera:
                    buttonDelay = 0.0
                case .mute:
                    buttonDelay = delayIncrement * 1.0
                case .switchCamera:
                    buttonDelay = delayIncrement * 2.0
                case .acceptOrEnd:
                    buttonDelay = delayIncrement * 3.0
                default:
                    break
                }
            }
            buttonTransition.updateFrame(node: buttonNode, frame: button.frame, delay: buttonDelay)
            buttonNode.update(size: button.frame.size, content: buttonContent, text: buttonText, transition: buttonTransition)
            buttonNode.accessibilityLabel = buttonAccessibilityLabel
            buttonNode.accessibilityValue = buttonAccessibilityValue
            buttonNode.accessibilityTraits = buttonAccessibilityTraits
            
            if animateButtonIn {
                buttonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        var removedKeys: [ButtonDescription.Key] = []
        for (key, button) in self.buttonNodes {
            if !validKeys.contains(key) {
                removedKeys.append(key)
                if animated {
                    if case .decline = key {
                        transition.updateTransformScale(node: button, scale: 0.1)
                        transition.updateAlpha(node: button, alpha: 0.0, completion: { [weak button] _ in
                            button?.removeFromSupernode()
                        })
                    } else {
                        transition.updateAlpha(node: button, alpha: 0.0, completion: { [weak button] _ in
                            button?.removeFromSupernode()
                        })
                    }
                } else {
                    button.removeFromSupernode()
                }
            }
        }
        for key in removedKeys {
            self.buttonNodes.removeValue(forKey: key)
        }
        
        return height
    }
    
    @objc func buttonPressed(_ button: CallControllerButtonItemNode) {
        for (key, listButton) in self.buttonNodes {
            if button === listButton {
                switch key {
                case .accept:
                    self.acceptOrEnd?()
                case .acceptOrEnd:
                    self.acceptOrEnd?()
                case .decline:
                    self.decline?()
                case .enableCamera:
                    self.toggleVideo?()
                case .switchCamera:
                    self.rotateCamera?()
                case .soundOutput:
                    self.speaker?()
                case .mute:
                    self.mute?()
                }
                break
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for (_, button) in self.buttonNodes {
            if let result = button.view.hitTest(self.convert(point, to: button.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
}
