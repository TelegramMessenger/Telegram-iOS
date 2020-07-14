import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import MediaPlayer
import TelegramPresentationData

enum CallControllerButtonsSpeakerMode {
    case none
    case builtin
    case speaker
    case headphones
    case bluetooth
}

enum CallControllerButtonsMode: Equatable {
    enum VideoState: Equatable {
        case notAvailable
        case possible
        case outgoingRequested
        case incomingRequested
        case active
    }
    
    case active(speakerMode: CallControllerButtonsSpeakerMode, videoState: VideoState)
    case incoming(speakerMode: CallControllerButtonsSpeakerMode, videoState: VideoState)
    case outgoingRinging(speakerMode: CallControllerButtonsSpeakerMode, videoState: VideoState)
}

private enum ButtonDescription: Equatable {
    enum Key: Hashable {
        case accept
        case end
        case enableCamera
        case switchCamera
        case soundOutput
        case mute
    }
    
    enum SoundOutput {
        case builtin
        case speaker
        case bluetooth
    }
    
    enum EndType {
        case outgoing
        case decline
        case end
    }
    
    case accept
    case end(EndType)
    case enableCamera(Bool)
    case switchCamera
    case soundOutput(SoundOutput)
    case mute(Bool)
    
    var key: Key {
        switch self {
        case .accept:
            return .accept
        case .end:
            return .end
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
    var isCameraPaused = false
    
    var accept: (() -> Void)?
    var mute: (() -> Void)?
    var end: (() -> Void)?
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
        
        let minSmallButtonSideInset: CGFloat = 34.0
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
        switch mode {
        case .incoming(let speakerModeValue, let videoStateValue), .outgoingRinging(let speakerModeValue, let videoStateValue), .active(let speakerModeValue, let videoStateValue):
            speakerMode = speakerModeValue
            videoState = videoStateValue
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
        case let .active(_, videoStateValue):
            switch videoStateValue {
            case .incomingRequested:
                mappedState = .incomingRinging
                videoState = .outgoingRequested
            case .outgoingRequested:
                mappedState = .outgoingRinging
                videoState = .outgoingRequested
            case .active, .possible, .notAvailable:
                mappedState = .active
            }
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
                soundOutput = .bluetooth
            case .bluetooth:
                soundOutput = .bluetooth
            }
            
            switch videoState {
            case .active, .possible, .incomingRequested, .outgoingRequested:
                let isCameraActive: Bool
                if case .possible = videoState {
                    isCameraActive = false
                } else {
                    isCameraActive = !self.isCameraPaused
                }
                topButtons.append(.enableCamera(isCameraActive))
                topButtons.append(.mute(self.isMuted))
                if case .possible = videoState {
                    topButtons.append(.soundOutput(soundOutput))
                } else {
                    topButtons.append(.switchCamera)
                }
            case .notAvailable:
                topButtons.append(.mute(self.isMuted))
                topButtons.append(.soundOutput(soundOutput))
            }
            
            let topButtonsContentWidth = CGFloat(topButtons.count) * smallButtonSize
            let topButtonsAvailableSpacingWidth = width - topButtonsContentWidth - minSmallButtonSideInset * 2.0
            let topButtonsSpacing = min(maxSmallButtonSpacing, topButtonsAvailableSpacingWidth / CGFloat(topButtons.count - 1))
            let topButtonsWidth = CGFloat(topButtons.count) * smallButtonSize + CGFloat(topButtons.count - 1) * topButtonsSpacing
            var topButtonsLeftOffset = floor((width - topButtonsWidth) / 2.0)
            for button in topButtons {
                buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: topButtonsLeftOffset, y: 0.0), size: CGSize(width: smallButtonSize, height: smallButtonSize))))
                topButtonsLeftOffset += smallButtonSize + topButtonsSpacing
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
                buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: smallButtonSize + topBottomSpacing), size: CGSize(width: largeButtonSize, height: largeButtonSize))))
                bottomButtonsLeftOffset += largeButtonSize + bottomButtonsSpacing
            }
            
            height = smallButtonSize + topBottomSpacing + largeButtonSize + max(bottomInset + 32.0, 46.0)
        case .active:
            switch videoState {
            case .active, .incomingRequested, .outgoingRequested:
                let isCameraActive: Bool
                if case .possible = videoState {
                    isCameraActive = false
                } else {
                    isCameraActive = !self.isCameraPaused
                }
                
                var topButtons: [ButtonDescription] = []
                
                let soundOutput: ButtonDescription.SoundOutput
                switch speakerMode {
                case .none, .builtin:
                    soundOutput = .builtin
                case .speaker:
                    soundOutput = .speaker
                case .headphones:
                    soundOutput = .builtin
                case .bluetooth:
                    soundOutput = .bluetooth
                }
                
                topButtons.append(.enableCamera(isCameraActive))
                topButtons.append(.mute(isMuted))
                topButtons.append(.switchCamera)
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
            case .notAvailable, .possible:
                var topButtons: [ButtonDescription] = []
                var bottomButtons: [ButtonDescription] = []
                
                let soundOutput: ButtonDescription.SoundOutput
                switch speakerMode {
                case .none, .builtin:
                    soundOutput = .builtin
                case .speaker:
                    soundOutput = .speaker
                case .headphones:
                    soundOutput = .bluetooth
                case .bluetooth:
                    soundOutput = .bluetooth
                }
                
                topButtons.append(.enableCamera(false))
                topButtons.append(.mute(self.isMuted))
                topButtons.append(.soundOutput(soundOutput))
                
                let topButtonsContentWidth = CGFloat(topButtons.count) * smallButtonSize
                let topButtonsAvailableSpacingWidth = width - topButtonsContentWidth - minSmallButtonSideInset * 2.0
                let topButtonsSpacing = min(maxSmallButtonSpacing, topButtonsAvailableSpacingWidth / CGFloat(topButtons.count - 1))
                let topButtonsWidth = CGFloat(topButtons.count) * smallButtonSize + CGFloat(topButtons.count - 1) * topButtonsSpacing
                var topButtonsLeftOffset = floor((width - topButtonsWidth) / 2.0)
                for button in topButtons {
                    buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: topButtonsLeftOffset, y: 0.0), size: CGSize(width: smallButtonSize, height: smallButtonSize))))
                    topButtonsLeftOffset += smallButtonSize + topButtonsSpacing
                }
                
                bottomButtons.append(.end(.outgoing))
                
                let bottomButtonsContentWidth = CGFloat(bottomButtons.count) * largeButtonSize
                let bottomButtonsAvailableSpacingWidth = width - bottomButtonsContentWidth - minLargeButtonSideInset * 2.0
                let bottomButtonsSpacing = min(maxLargeButtonSpacing, bottomButtonsAvailableSpacingWidth / CGFloat(bottomButtons.count - 1))
                let bottomButtonsWidth = CGFloat(bottomButtons.count) * largeButtonSize + CGFloat(bottomButtons.count - 1) * bottomButtonsSpacing
                var bottomButtonsLeftOffset = floor((width - bottomButtonsWidth) / 2.0)
                for button in bottomButtons {
                    buttons.append(PlacedButton(button: button, frame: CGRect(origin: CGPoint(x: bottomButtonsLeftOffset, y: smallButtonSize + topBottomSpacing), size: CGSize(width: largeButtonSize, height: largeButtonSize))))
                    bottomButtonsLeftOffset += largeButtonSize + bottomButtonsSpacing
                }
                
                height = smallButtonSize + topBottomSpacing + largeButtonSize + max(bottomInset + 32.0, 46.0)
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
            case let .enableCamera(isEnabled):
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isEnabled),
                    image: .camera
                )
                buttonText = strings.Call_Camera
            case .switchCamera:
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: false),
                    image: .flipCamera
                )
                buttonText = strings.Call_Flip
            case let .soundOutput(value):
                let image: CallControllerButtonItemNode.Content.Image
                var isFilled = false
                switch value {
                case .builtin:
                    image = .speaker
                case .speaker:
                    image = .speaker
                    isFilled = true
                case .bluetooth:
                    image = .bluetooth
                }
                buttonContent = CallControllerButtonItemNode.Content(
                    appearance: .blurred(isFilled: isFilled),
                    image: image
                )
                buttonText = strings.Call_Speaker
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
                case .end:
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
                    if case .accept = key {
                        if let endButton = self.buttonNodes[.end] {
                            transition.updateFrame(node: button, frame: endButton.frame)
                            if let content = button.currentContent {
                                button.update(size: endButton.frame.size, content: content, text: button.currentText, transition: transition)
                            }
                            transition.updateTransformScale(node: button, scale: 0.1)
                            transition.updateAlpha(node: button, alpha: 0.0, completion: { [weak button] _ in
                                button?.removeFromSupernode()
                            })
                        }
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
                    self.accept?()
                case .end:
                    self.end?()
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
