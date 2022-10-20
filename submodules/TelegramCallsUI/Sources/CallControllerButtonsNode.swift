import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import MediaPlayer
import TelegramPresentationData

enum CallControllerButtonsSpeakerMode: Equatable {
    enum BluetoothType: Equatable {
        case generic
        case airpods
        case airpodsPro
        case airpodsMax
    }
    
    case none
    case builtin
    case speaker
    case headphones
    case bluetooth(BluetoothType)
}

enum CallControllerButtonsMode: Equatable {
    struct VideoState: Equatable {
        var isAvailable: Bool
        var isCameraActive: Bool
        var isScreencastActive: Bool
        var canChangeStatus: Bool
        var hasVideo: Bool
        var isInitializingCamera: Bool
    }
    
    case active(speakerMode: CallControllerButtonsSpeakerMode, hasAudioRouteMenu: Bool, videoState: VideoState)
    case incoming(speakerMode: CallControllerButtonsSpeakerMode, hasAudioRouteMenu: Bool, videoState: VideoState)
    case outgoingRinging(speakerMode: CallControllerButtonsSpeakerMode, hasAudioRouteMenu: Bool, videoState: VideoState)
}

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

final class CallControllerButtonsNode: ASDisplayNode {
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
        super.init()
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
        
        let minSmallButtonSideInset: CGFloat = width > 320.0 ? 34.0 : 16.0
        let maxSmallButtonSpacing: CGFloat = 34.0
        let smallButtonSize: CGFloat = 60.0
        let topBottomSpacing: CGFloat = 84.0
        
        let maxLargeButtonSpacing: CGFloat = 115.0
        let largeButtonSize: CGFloat = 72.0
        let minLargeButtonSideInset: CGFloat = minSmallButtonSideInset - 6.0
        
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
            var topButtons: [ButtonDescription] = []
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
                topButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive, isEnabled: false, isLoading: isCameraInitializing, isScreencast: isScreencastActive))
                if !videoState.hasVideo {
                    topButtons.append(.mute(self.isMuted))
                    topButtons.append(.soundOutput(soundOutput))
                } else {
                    if hasAudioRouteMenu {
                        topButtons.append(.soundOutput(soundOutput))
                    } else {
                        topButtons.append(.mute(self.isMuted))
                    }
                    if !isScreencastActive {
                        topButtons.append(.switchCamera(isCameraActive && !isCameraInitializing))
                    }
                }
            } else {
                topButtons.append(.mute(self.isMuted))
                topButtons.append(.soundOutput(soundOutput))
            }
            
            let topButtonsContentWidth = CGFloat(topButtons.count) * largeButtonSize
            let topButtonsAvailableSpacingWidth = width - topButtonsContentWidth - minSmallButtonSideInset * 2.0
            let topButtonsSpacing = min(maxSmallButtonSpacing, topButtonsAvailableSpacingWidth / CGFloat(topButtons.count - 1))
            let topButtonsWidth = CGFloat(topButtons.count) * largeButtonSize + CGFloat(topButtons.count - 1) * topButtonsSpacing
            var topButtonsLeftOffset = floor((width - topButtonsWidth) / 2.0)
            for button in topButtons {
                buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: topButtonsLeftOffset, y: 0.0), size: CGSize(width: largeButtonSize, height: largeButtonSize))))
                topButtonsLeftOffset += largeButtonSize + topButtonsSpacing
            }
            
            if case .incomingRinging = mappedState {
                bottomButtons.append(.end(.decline))
                bottomButtons.append(.accept)
            } else {
                bottomButtons.append(.end(.outgoing))
            }
            
            let bottomButtonsContentWidth = CGFloat(bottomButtons.count) * largeButtonSize
            let bottomButtonsAvailableSpacingWidth = width - bottomButtonsContentWidth - minLargeButtonSideInset * 2.0
            let bottomButtonsSpacing = min(maxLargeButtonSpacing, bottomButtonsAvailableSpacingWidth / CGFloat(bottomButtons.count - 1))
            let bottomButtonsWidth = CGFloat(bottomButtons.count) * largeButtonSize + CGFloat(bottomButtons.count - 1) * bottomButtonsSpacing
            var bottomButtonsLeftOffset = floor((width - bottomButtonsWidth) / 2.0)
            for button in bottomButtons {
                buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: largeButtonSize + topBottomSpacing), size: CGSize(width: largeButtonSize, height: largeButtonSize))))
                bottomButtonsLeftOffset += largeButtonSize + bottomButtonsSpacing
            }
            
            height = largeButtonSize + topBottomSpacing + largeButtonSize + max(bottomInset + 32.0, 46.0)
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
                
                var topButtons: [ButtonDescription] = []
                
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
                
                topButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive, isEnabled: isCameraEnabled, isLoading: isCameraInitializing, isScreencast: isScreencastActive))
                if hasAudioRouteMenu {
                    topButtons.append(.soundOutput(soundOutput))
                } else {
                    topButtons.append(.mute(isMuted))
                }
                if !isScreencastActive {
                    topButtons.append(.switchCamera(isCameraActive && !isCameraInitializing))
                }
                topButtons.append(.end(.end))
                
                let topButtonsContentWidth = CGFloat(topButtons.count) * smallButtonSize
                let topButtonsAvailableSpacingWidth = width - topButtonsContentWidth - minSmallButtonSideInset * 2.0
                let topButtonsSpacing = min(maxSmallButtonSpacing, topButtonsAvailableSpacingWidth / CGFloat(topButtons.count - 1))
                let topButtonsWidth = CGFloat(topButtons.count) * smallButtonSize + CGFloat(topButtons.count - 1) * topButtonsSpacing
                var topButtonsLeftOffset = floor((width - topButtonsWidth) / 2.0)
                for button in topButtons {
                    buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: topButtonsLeftOffset, y: 0.0), size: CGSize(width: smallButtonSize, height: smallButtonSize))))
                    topButtonsLeftOffset += smallButtonSize + topButtonsSpacing
                }
                
                height = smallButtonSize + max(bottomInset + 19.0, 46.0)
            } else {
                var topButtons: [ButtonDescription] = []
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
                
                topButtons.append(.enableCamera(isActive: isCameraActive || isScreencastActive, isEnabled: isCameraEnabled, isLoading: isCameraInitializing, isScreencast: isScreencastActive))
                topButtons.append(.mute(self.isMuted))
                topButtons.append(.soundOutput(soundOutput))
                
                let topButtonsContentWidth = CGFloat(topButtons.count) * largeButtonSize
                let topButtonsAvailableSpacingWidth = width - topButtonsContentWidth - minSmallButtonSideInset * 2.0
                let topButtonsSpacing = min(maxSmallButtonSpacing, topButtonsAvailableSpacingWidth / CGFloat(topButtons.count - 1))
                let topButtonsWidth = CGFloat(topButtons.count) * largeButtonSize + CGFloat(topButtons.count - 1) * topButtonsSpacing
                var topButtonsLeftOffset = floor((width - topButtonsWidth) / 2.0)
                for button in topButtons {
                    buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: topButtonsLeftOffset, y: 0.0), size: CGSize(width: largeButtonSize, height: largeButtonSize))))
                    topButtonsLeftOffset += largeButtonSize + topButtonsSpacing
                }
                
                bottomButtons.append(.end(.outgoing))
                
                let bottomButtonsContentWidth = CGFloat(bottomButtons.count) * largeButtonSize
                let bottomButtonsAvailableSpacingWidth = width - bottomButtonsContentWidth - minLargeButtonSideInset * 2.0
                let bottomButtonsSpacing = min(maxLargeButtonSpacing, bottomButtonsAvailableSpacingWidth / CGFloat(bottomButtons.count - 1))
                let bottomButtonsWidth = CGFloat(bottomButtons.count) * largeButtonSize + CGFloat(bottomButtons.count - 1) * bottomButtonsSpacing
                var bottomButtonsLeftOffset = floor((width - bottomButtonsWidth) / 2.0)
                for button in bottomButtons {
                    buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: largeButtonSize + topBottomSpacing), size: CGSize(width: largeButtonSize, height: largeButtonSize))))
                    bottomButtonsLeftOffset += largeButtonSize + bottomButtonsSpacing
                }
                
                height = largeButtonSize + topBottomSpacing + largeButtonSize + max(bottomInset + 32.0, 46.0)
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
                buttonNode = CallControllerButtonItemNode()
                self.buttonNodes[button.button.key] = buttonNode
                self.addSubnode(buttonNode)
                buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
                buttonTransition = .immediate
                animateButtonIn = transition.isAnimated
            }
            let buttonContent: CallControllerButtonItemNode.Content
            let buttonText: String
            switch button.button {
            case .accept:
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .color(.green),
                    image: .accept
                )
                buttonText = strings.Call_Accept
            case let .end(type):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .color(.red),
                    image: .end
                )
                switch type {
                case .outgoing:
                    buttonText = ""
                case .decline:
                    buttonText = strings.Call_Decline
                case .end:
                    buttonText = strings.Call_End
                }
            case let .enableCamera(isActivated, isEnabled, isInitializing, isScreencastActive):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isActivated),
                    image: isScreencastActive ? .screencast : .camera,
                    isEnabled: isEnabled,
                    hasProgress: isInitializing
                )
                buttonText = strings.Call_Camera
            case let .switchCamera(isEnabled):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: false),
                    image: .flipCamera,
                    isEnabled: isEnabled
                )
                buttonText = strings.Call_Flip
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
                case .airpods:
                    image = .airpods
                    title = strings.Call_Audio
                case .airpodsPro:
                    image = .airpodsPro
                    title = strings.Call_Audio
                case .airpodsMax:
                    image = .airpodsMax
                    title = strings.Call_Audio
                case .headphones:
                    image = .headphones
                    title = strings.Call_Audio
                }
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isFilled),
                    image: image
                )
                buttonText = title
            case let .mute(isMuted):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isMuted),
                    image: .mute
                )
                buttonText = strings.Call_Mute
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
            if let result = button.view.hitTest(self.view.convert(point, to: button.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
}
