import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import MediaPlayer
import TelegramPresentationData

enum LegacyCallControllerButtonsSpeakerMode {
    case none
    case builtin
    case speaker
    case headphones
    case bluetooth
}

enum LegacyCallControllerButtonsMode: Equatable {
    case active(speakerMode: LegacyCallControllerButtonsSpeakerMode)
    case incoming
}

final class LegacyCallControllerButtonsNode: ASDisplayNode {
    private let acceptButton: LegacyCallControllerButtonNode
    private let declineButton: LegacyCallControllerButtonNode
    
    private let muteButton: LegacyCallControllerButtonNode
    private let endButton: LegacyCallControllerButtonNode
    private let speakerButton: LegacyCallControllerButtonNode
    private let swichCameraButton: LegacyCallControllerButtonNode
    
    private var mode: LegacyCallControllerButtonsMode?
    
    private var validLayout: CGFloat?
    
    var isMuted = false {
        didSet {
            self.muteButton.isSelected = self.isMuted
        }
    }
    
    var accept: (() -> Void)?
    var mute: (() -> Void)?
    var end: (() -> Void)?
    var speaker: (() -> Void)?
    var toggleVideo: (() -> Void)?
    var rotateCamera: (() -> Void)?
    
    init(strings: PresentationStrings) {
        self.acceptButton = LegacyCallControllerButtonNode(type: .accept, label: strings.Call_Accept)
        self.acceptButton.alpha = 0.0
        self.declineButton = LegacyCallControllerButtonNode(type: .end, label: strings.Call_Decline)
        self.declineButton.alpha = 0.0
        
        self.muteButton = LegacyCallControllerButtonNode(type: .mute, label: nil)
        self.muteButton.alpha = 0.0
        self.endButton = LegacyCallControllerButtonNode(type: .end, label: nil)
        self.endButton.alpha = 0.0
        self.speakerButton = LegacyCallControllerButtonNode(type: .speaker, label: nil)
        self.speakerButton.alpha = 0.0
        self.swichCameraButton = LegacyCallControllerButtonNode(type: .switchCamera, label: nil)
        self.swichCameraButton.alpha = 0.0
        
        super.init()
        
        self.addSubnode(self.acceptButton)
        self.addSubnode(self.declineButton)
        self.addSubnode(self.muteButton)
        self.addSubnode(self.endButton)
        self.addSubnode(self.speakerButton)
        self.addSubnode(self.swichCameraButton)
        
        self.acceptButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        self.declineButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        self.muteButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        self.endButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        self.speakerButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        self.swichCameraButton.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousLayout = self.validLayout
        self.validLayout = constrainedWidth
        
        if let mode = self.mode, previousLayout != self.validLayout {
            self.updateButtonsLayout(mode: mode, width: constrainedWidth, animated: false)
        }
    }
    
    func updateMode(_ mode: LegacyCallControllerButtonsMode) {
        if self.mode != mode {
            let previousMode = self.mode
            self.mode = mode
            if let validLayout = self.validLayout {
                self.updateButtonsLayout(mode: mode, width: validLayout, animated: previousMode != nil)
            }
        }
    }
    
    private func updateButtonsLayout(mode: LegacyCallControllerButtonsMode, width: CGFloat, animated: Bool) {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.3, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let threeButtonSpacing: CGFloat = 28.0
        let twoButtonSpacing: CGFloat = 105.0
        let buttonSize = CGSize(width: 75.0, height: 75.0)
    
        let threeButtonsWidth = 3.0 * buttonSize.width + 2.0 * threeButtonSpacing
        let twoButtonsWidth = 2.0 * buttonSize.width + 1.0 * twoButtonSpacing
        
        var origin = CGPoint(x: floor((width - threeButtonsWidth) / 2.0), y: 0.0)
        
        for button in [self.muteButton, self.endButton, self.speakerButton] {
            transition.updateFrame(node: button, frame: CGRect(origin: origin, size: buttonSize))
            if button === self.speakerButton {
                transition.updateFrame(node: self.swichCameraButton, frame: CGRect(origin: origin, size: buttonSize))
            }
            
            origin.x += buttonSize.width + threeButtonSpacing
        }
        
        origin = CGPoint(x: floor((width - twoButtonsWidth) / 2.0), y: 0.0)
        for button in [self.declineButton, self.acceptButton] {
            transition.updateFrame(node: button, frame: CGRect(origin: origin, size: buttonSize))
            origin.x += buttonSize.width + twoButtonSpacing
        }
        
        switch mode {
            case .incoming:
                for button in [self.declineButton, self.acceptButton] {
                    button.alpha = 1.0
                }
                for button in [self.muteButton, self.endButton, self.speakerButton, self.swichCameraButton] {
                    button.alpha = 0.0
                }
            case let .active(speakerMode):
                for button in [self.muteButton] {
                    if animated && button.alpha.isZero {
                        button.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    button.alpha = 1.0
                }
                
                for button in [self.swichCameraButton] {
                    if animated && !button.alpha.isZero {
                        button.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    }
                    button.alpha = 0.0
                }
                for button in [self.speakerButton] {
                    if animated && button.alpha.isZero {
                        button.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    button.alpha = 1.0
                }
                
                var animatingAcceptButton = false
                if self.endButton.alpha.isZero {
                    if animated {
                        if !self.acceptButton.alpha.isZero {
                            animatingAcceptButton = true
                            self.endButton.layer.animatePosition(from: self.acceptButton.position, to: self.endButton.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                            self.acceptButton.animateRollTransition()
                            self.endButton.layer.animate(from: (CGFloat.pi * 5 / 4) as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.rotation.z", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.3)
                            self.acceptButton.layer.animatePosition(from: self.acceptButton.position, to: self.endButton.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.acceptButton.alpha = 0.0
                                    strongSelf.acceptButton.layer.removeAnimation(forKey: "position")
                                    strongSelf.acceptButton.layer.removeAnimation(forKey: "transform.rotation.z")
                                }
                            })
                        }
                        self.endButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    self.endButton.alpha = 1.0
                }
                
                if !self.declineButton.alpha.isZero {
                    if animated {
                        self.declineButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                    self.declineButton.alpha = 0.0
                }
                
                if self.acceptButton.alpha.isZero && !animatingAcceptButton {
                    self.acceptButton.alpha = 0.0
                }
            
                self.speakerButton.isSelected = speakerMode == .speaker
                self.speakerButton.isHidden = speakerMode == .none
                let speakerButtonType: LegacyCallControllerButtonType
                switch speakerMode {
                    case .none, .builtin, .speaker:
                        speakerButtonType = .speaker
                    case .headphones:
                        speakerButtonType = .bluetooth
                    case .bluetooth:
                        speakerButtonType = .bluetooth
                }
                self.speakerButton.updateType(speakerButtonType)
        }
    }
    
    @objc func buttonPressed(_ button: LegacyCallControllerButtonNode) {
        if button === self.muteButton {
            self.mute?()
        } else if button === self.endButton || button === self.declineButton {
            self.end?()
        } else if button === self.speakerButton {
            self.speaker?()
        } else if button === self.acceptButton {
            self.accept?()
        } else if button === self.swichCameraButton {
            self.rotateCamera?()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let buttons = [
            self.acceptButton,
            self.declineButton,
            self.muteButton,
            self.endButton,
            self.speakerButton,
            self.swichCameraButton
        ]
        for button in buttons {
            if button.isHidden || button.alpha.isZero {
                continue
            }
            if let result = button.view.hitTest(self.view.convert(point, to: button.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
}
