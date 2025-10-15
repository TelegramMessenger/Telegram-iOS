import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ManagedAnimationNode

public enum VoiceChatActionButtonIconAnimationState: Equatable {
    case empty
    case start
    case subscribe
    case unsubscribe
    case unmute
    case mute
    case hand
}

public final class VoiceChatActionButtonIconNode: ManagedAnimationNode {
    private let isColored: Bool
    private var iconState: VoiceChatActionButtonIconAnimationState = .mute
    
    public init(isColored: Bool) {
        self.isColored = isColored
        super.init(size: CGSize(width: 100.0, height: 100.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceUnmute"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.1))
    }
    
    public func enqueueState(_ state: VoiceChatActionButtonIconAnimationState) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        if state != .empty {
            self.alpha = 1.0
        }
        switch previousState {
            case .empty:
                switch state {
                    case .start:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceStart"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    default:
                        break
                }
            case .subscribe:
                switch state {
                    case .unsubscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminder")))
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminderToMute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminderToRaiseHand")))
                    default:
                        break
                }
            case .unsubscribe:
                switch state {
                    case .subscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminder")))
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminderToMute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminderToRaiseHand")))
                    default:
                        break
                }
            case .start:
                switch state {
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceStart")))
                    default:
                        break
                }
            case .unmute:
                switch state {
                    case .mute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceMute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceUnmuteToRaiseHand")))
                    default:
                        break
                }
            case .mute:
                switch state {
                    case .start:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceStart"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    case .unmute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceUnmute")))
                    case .hand:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceMuteToRaiseHand")))
                    case .subscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceSetReminderToRaiseHand"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    case .unsubscribe:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceCancelReminderToRaiseHand"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.001))
                    case .empty:
                        self.alpha = 0.0
                    default:
                        break
                }
            case .hand:
                switch state {
                    case .mute, .unmute:
                        self.trackTo(item: ManagedAnimationItem(source: .local("VoiceRaiseHandToMute")))
                    default:
                        break
                }
        }
    }
    
    public func playRandomAnimation() {
        if case .hand = self.iconState {
            if let next = self.trackStack.first, case let .local(name) = next.source, name.hasPrefix("VoiceHand_") {
                return
            }
            
            var useTiredAnimation = false
            var useAngryAnimation = false
            let val = Float.random(in: 0.0..<1.0)
            if val <= 0.01 {
                useTiredAnimation = true
            } else if val <= 0.05 {
                useAngryAnimation = true
            }
            
            let normalAnimations = ["VoiceHand_1", "VoiceHand_2", "VoiceHand_3", "VoiceHand_4", "VoiceHand_7", "VoiceHand_8"]
            let tiredAnimations = ["VoiceHand_5", "VoiceHand_6"]
            let angryAnimations = ["VoiceHand_9", "VoiceHand_10"]
            let animations: [String]
            if useTiredAnimation {
                animations = tiredAnimations
            } else if useAngryAnimation {
                animations = angryAnimations
            } else {
                animations = normalAnimations
            }
            if let animationName = animations.randomElement() {
                self.trackTo(item: ManagedAnimationItem(source: .local(animationName)))
            }
        }
    }
}
