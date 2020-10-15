import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SyncCore
import TelegramCore
import SwiftSignalKit
import AccountContext
import StickerResources
import ManagedAnimationNode

private struct SlotMachineValue {
    enum ReelValue {
        case rolling
        case bar
        case berries
        case lemon
        case seven
        case sevenWin
        
        var isResult: Bool {
            if case .rolling = self {
                return false
            } else {
                return true
            }
        }
    }
    
    let left: ReelValue
    let center: ReelValue
    let right: ReelValue
    
    init(rawValue: Int32?) {
        if let rawValue = rawValue, rawValue > 0 {
            let rawValue = rawValue - 1
            
            let leftRawValue = rawValue & 3
            let centerRawValue = rawValue >> 2 & 3
            let rightRawValue = rawValue >> 4
            
            func reelValue(for rawValue: Int32) -> ReelValue {
                switch rawValue {
                    case 0:
                        return .bar
                    case 1:
                        return .berries
                    case 2:
                        return .lemon
                    case 3:
                        return .seven
                    default:
                        return .rolling
                }
            }
            
            var leftReelValue = reelValue(for: leftRawValue)
            var centerReelValue = reelValue(for: centerRawValue)
            var rightReelValue = reelValue(for: rightRawValue)
            
            if leftReelValue == .seven && centerReelValue == .seven && rightReelValue == .seven {
                leftReelValue = .sevenWin
                centerReelValue = .sevenWin
                rightReelValue = .sevenWin
            }
            
            self.left = leftReelValue
            self.center = centerReelValue
            self.right = rightReelValue
        } else {
            self.left = .rolling
            self.center = .rolling
            self.right = .rolling
        }
    }
    
    var isThreeOfSame: Bool {
        return self.left == self.center && self.center == self.right && self.left.isResult
    }
    
    var is777: Bool {
        return self.left == .sevenWin && self.center == .sevenWin && self.right == .sevenWin
    }
}

private func leftReelAnimationItem(value: SlotMachineValue.ReelValue, immediate: Bool = false) -> ManagedAnimationItem {
    let frames: ManagedAnimationFrameRange? = immediate ? .still(.end) : nil
    switch value {
        case .rolling:
            return ManagedAnimationItem(source: .local("Slot_L_Spinning"), loop: true)
        case .bar:
            return ManagedAnimationItem(source: .local("Slot_L_Bar"), frames: frames, loop: false)
        case .berries:
            return ManagedAnimationItem(source: .local("Slot_L_Berries"), frames: frames, loop: false)
        case .lemon:
            return ManagedAnimationItem(source: .local("Slot_L_Lemon"), frames: frames, loop: false)
        case .seven:
            return ManagedAnimationItem(source: .local("Slot_L_7"), frames: frames, loop: false)
        case .sevenWin:
            return ManagedAnimationItem(source: .local("Slot_L_7_Win"), frames: frames, loop: false)
    }
}

private func centerReelAnimationItem(value: SlotMachineValue.ReelValue, immediate: Bool = false) -> ManagedAnimationItem {
    let frames: ManagedAnimationFrameRange? = immediate ? .still(.end) : nil
    switch value {
        case .rolling:
            return ManagedAnimationItem(source: .local("Slot_M_Spinning"), frames: frames, loop: true)
        case .bar:
            return ManagedAnimationItem(source: .local("Slot_M_Bar"), frames: frames, loop: false)
        case .berries:
            return ManagedAnimationItem(source: .local("Slot_M_Berries"), frames: frames, loop: false)
        case .lemon:
            return ManagedAnimationItem(source: .local("Slot_M_Lemon"), frames: frames, loop: false)
        case .seven:
            return ManagedAnimationItem(source: .local("Slot_M_7"), frames: frames, loop: false)
        case .sevenWin:
            return ManagedAnimationItem(source: .local("Slot_M_7_Win"), frames: frames, loop: false)
    }
}

private func rightReelAnimationItem(value: SlotMachineValue.ReelValue, immediate: Bool = false) -> ManagedAnimationItem {
    let frames: ManagedAnimationFrameRange? = immediate ? .still(.end) : nil
    switch value {
        case .rolling:
            return ManagedAnimationItem(source: .local("Slot_R_Spinning"), frames: frames, loop: true)
        case .bar:
            return ManagedAnimationItem(source: .local("Slot_R_Bar"), frames: frames, loop: false)
        case .berries:
            return ManagedAnimationItem(source: .local("Slot_R_Berries"), frames: frames, loop: false)
        case .lemon:
            return ManagedAnimationItem(source: .local("Slot_R_Lemon"), frames: frames, loop: false)
        case .seven:
            return ManagedAnimationItem(source: .local("Slot_R_7"), frames: frames, loop: false)
        case .sevenWin:
            return ManagedAnimationItem(source: .local("Slot_R_7_Win"), frames: frames, loop: false)
    }
}

final class SlotMachineAnimationNode: ASDisplayNode, GenericAnimatedStickerNode {
    private let context: AccountContext

    private let backNode: ManagedAnimationNode
    private let leftReelNode: ManagedAnimationNode
    private let centerReelNode: ManagedAnimationNode
    private let rightReelNode: ManagedAnimationNode
    private let frontNode: ManagedAnimationNode
    
    private var diceState: ManagedDiceAnimationState? = nil
    private let disposables = DisposableSet()
    
    init(context: AccountContext) {
        self.context = context
        
        let size = CGSize(width: 184.0, height: 184.0)
        self.backNode = ManagedAnimationNode(size: size)
        self.leftReelNode = ManagedAnimationNode(size: size)
        self.centerReelNode = ManagedAnimationNode(size: size)
        self.rightReelNode = ManagedAnimationNode(size: size)
        self.frontNode = ManagedAnimationNode(size: size)
        
        super.init()
        
        self.addSubnode(self.backNode)
        self.addSubnode(self.leftReelNode)
        self.addSubnode(self.centerReelNode)
        self.addSubnode(self.rightReelNode)
        self.addSubnode(self.frontNode)
    }
    
    deinit {
        self.disposables.dispose()
    }
    
    override func layout() {
        super.layout()
        
        self.backNode.frame = self.bounds
        self.leftReelNode.frame = self.bounds
        self.centerReelNode.frame = self.bounds
        self.rightReelNode.frame = self.bounds
        self.frontNode.frame = self.bounds
    }
    
    func setState(_ diceState: ManagedDiceAnimationState) {
        let previousState = self.diceState
        self.diceState = diceState
                
        if let previousState = previousState {
            switch previousState {
                case .rolling:
                    switch diceState {
                        case let .value(value, _):
                            let slotValue = SlotMachineValue(rawValue: value)
                            if slotValue.isThreeOfSame {
                                Queue.mainQueue().after(1.5) {
                                    self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), loop: false))
                                }
                            } else {
                                self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), frames: .still(.start), loop: false))
                            }
                            self.leftReelNode.trackTo(item: leftReelAnimationItem(value: slotValue.left))
                            self.centerReelNode.trackTo(item: centerReelAnimationItem(value: slotValue.center))
                            self.rightReelNode.trackTo(item: rightReelAnimationItem(value: slotValue.right))
                            self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), frames: .still(.end), loop: false))
                        case .rolling:
                            break
                    }
                case .value:
                    switch diceState {
                        case .rolling:
                            self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), frames: .still(.start), loop: false))
                            self.leftReelNode.trackTo(item: leftReelAnimationItem(value: .rolling))
                            self.centerReelNode.trackTo(item: centerReelAnimationItem(value: .rolling))
                            self.rightReelNode.trackTo(item: rightReelAnimationItem(value: .rolling))
                            self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), loop: false))
                        case .value:
                            break
                    }
            }
        } else {
            switch diceState {
                case let .value(value, immediate):
                    self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), frames: .still(.start), loop: false))
                    
                    let slotValue = SlotMachineValue(rawValue: value)
                    self.leftReelNode.trackTo(item: leftReelAnimationItem(value: slotValue.left, immediate: immediate))
                    self.centerReelNode.trackTo(item: centerReelAnimationItem(value: slotValue.center, immediate: immediate))
                    self.rightReelNode.trackTo(item: rightReelAnimationItem(value: slotValue.right, immediate: immediate))
                    
                    let frames: ManagedAnimationFrameRange? = immediate ? .still(.end) : nil
                    self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), frames: frames, loop: false))
                case .rolling:
                    self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), frames: .still(.start), loop: false))
                    self.leftReelNode.trackTo(item: leftReelAnimationItem(value: .rolling))
                    self.centerReelNode.trackTo(item: centerReelAnimationItem(value: .rolling))
                    self.rightReelNode.trackTo(item: rightReelAnimationItem(value: .rolling))
                    self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), loop: false))
            }
        }
    }
}
