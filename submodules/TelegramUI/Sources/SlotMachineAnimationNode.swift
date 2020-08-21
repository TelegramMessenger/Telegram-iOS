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

enum ReelValue {
    case rolling
    case bar
    case berries
    case lemon
    case seven
    case sevenWin
}

private func leftReelAnimationItem(value: ReelValue, immediate: Bool = false) -> ManagedAnimationItem {
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

private func centerReelAnimationItem(value: ReelValue, immediate: Bool = false) -> ManagedAnimationItem {
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

private func rightReelAnimationItem(value: ReelValue, immediate: Bool = false) -> ManagedAnimationItem {
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
                            let l: ReelValue
                            let c: ReelValue
                            let r: ReelValue
                            switch value {
                                case 1:
                                    l = .seven
                                    c = .berries
                                    r = .bar
                                case 2:
                                    l = .berries
                                    c = .berries
                                    r = .bar
                                case 3:
                                    l = .seven
                                    c = .berries
                                    r = .seven
                                case 4:
                                    l = .bar
                                    c = .lemon
                                    r = .seven
                                case 5:
                                    l = .berries
                                    c = .berries
                                    r = .berries
                                case 6:
                                    l = .sevenWin
                                    c = .sevenWin
                                    r = .sevenWin
                                default:
                                    l = .sevenWin
                                    c = .sevenWin
                                    r = .sevenWin
                            }
                            if value == 6 {
                                Queue.mainQueue().after(1.5) {
                                    self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), loop: false))
                                }
                            } else {
                                self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Idle"), loop: false))
                            }
                            self.leftReelNode.trackTo(item: leftReelAnimationItem(value: l))
                            self.centerReelNode.trackTo(item: centerReelAnimationItem(value: c))
                            self.rightReelNode.trackTo(item: rightReelAnimationItem(value: r))
                            self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), frames: .still(.end), loop: false))
                        case .rolling:
                            break
                    }
                case .value:
                    switch diceState {
                        case .rolling:
                            self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Idle"), loop: false))
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
                    self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Idle"), loop: false))
                    
                    let l: ReelValue
                    let c: ReelValue
                    let r: ReelValue
                    switch value {
                        case 1:
                            l = .seven
                            c = .berries
                            r = .bar
                        case 2:
                            l = .berries
                            c = .berries
                            r = .bar
                        case 3:
                            l = .seven
                            c = .berries
                            r = .seven
                        case 4:
                            l = .bar
                            c = .lemon
                            r = .seven
                        case 5:
                            l = .berries
                            c = .berries
                            r = .berries
                        case 6:
                            l = .sevenWin
                            c = .sevenWin
                            r = .sevenWin
                        default:
                            l = .sevenWin
                            c = .sevenWin
                            r = .sevenWin
                    }
                    self.leftReelNode.trackTo(item: leftReelAnimationItem(value: l, immediate: immediate))
                    self.centerReelNode.trackTo(item: centerReelAnimationItem(value: c, immediate: immediate))
                    self.rightReelNode.trackTo(item: rightReelAnimationItem(value: r, immediate: immediate))
                    
                    let frames: ManagedAnimationFrameRange? = immediate ? .still(.end) : nil
                    self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), frames: frames, loop: false))
                case .rolling:
                    self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Idle"), loop: false))
                    self.leftReelNode.trackTo(item: leftReelAnimationItem(value: .rolling))
                    self.centerReelNode.trackTo(item: centerReelAnimationItem(value: .rolling))
                    self.rightReelNode.trackTo(item: rightReelAnimationItem(value: .rolling))
                    self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), loop: false))
            }
        }
    }
}
