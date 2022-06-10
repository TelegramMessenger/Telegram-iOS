import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import StickerResources
import ManagedAnimationNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle

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

public enum ManagedSlotMachineAnimationState: Equatable {
    case rolling
    case value(Int32, Bool)
}

public final class SlotMachineAnimationNode: ASDisplayNode {
    private let backNode: ManagedAnimationNode
    private let leftReelNode: DiceAnimatedStickerNode
    private let centerReelNode: DiceAnimatedStickerNode
    private let rightReelNode: DiceAnimatedStickerNode
    private let frontNode: ManagedAnimationNode
    
    private var diceState: ManagedSlotMachineAnimationState? = nil
    private let disposables = DisposableSet()
        
    private let animationSize: CGSize
    
    public var success: ((Bool) -> Void)?
    
    public init(account: Account, size: CGSize = CGSize(width: 184.0, height: 184.0)) {
        self.animationSize = size
        self.backNode = ManagedAnimationNode(size: self.animationSize)
        let reelSize = CGSize(width: 384.0, height: 384.0)
        self.leftReelNode = DiceAnimatedStickerNode(account: account, size: reelSize)
        self.centerReelNode = DiceAnimatedStickerNode(account: account,size: reelSize)
        self.rightReelNode = DiceAnimatedStickerNode(account: account,size: reelSize)
        self.frontNode = ManagedAnimationNode(size: self.animationSize)
        
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
    
    public override func layout() {
        super.layout()
        
        self.backNode.frame = self.bounds
        self.leftReelNode.frame = self.bounds
        self.centerReelNode.frame = self.bounds
        self.rightReelNode.frame = self.bounds
        self.frontNode.frame = self.bounds
    }
    
    public func setState(_ diceState: ManagedSlotMachineAnimationState) {
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
                                    self.success?(!slotValue.is777)
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
            self.backNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Back_Win"), frames: .still(.start), loop: false))
            
            switch diceState {
                case let .value(value, immediate):
                    let slotValue = SlotMachineValue(rawValue: value)
                    self.leftReelNode.trackTo(item: leftReelAnimationItem(value: slotValue.left, immediate: immediate))
                    self.centerReelNode.trackTo(item: centerReelAnimationItem(value: slotValue.center, immediate: immediate))
                    self.rightReelNode.trackTo(item: rightReelAnimationItem(value: slotValue.right, immediate: immediate))
                    
                    let frames: ManagedAnimationFrameRange? = immediate ? .still(.end) : nil
                    self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), frames: frames, loop: false))
                case .rolling:
                    self.leftReelNode.trackTo(item: leftReelAnimationItem(value: .rolling))
                    self.centerReelNode.trackTo(item: centerReelAnimationItem(value: .rolling))
                    self.rightReelNode.trackTo(item: rightReelAnimationItem(value: .rolling))
                    self.frontNode.trackTo(item: ManagedAnimationItem(source: .local("Slot_Front_Pull"), loop: false))
            }
        }
    }
    
    public func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
    }
}

class DiceAnimatedStickerNode: ASDisplayNode {
    private let account: Account
    public let intrinsicSize: CGSize
    
    private let animationNode: AnimatedStickerNode
    
    public var state: ManagedAnimationState?
    public var trackStack: [ManagedAnimationItem] = []
    public var didTryAdvancingState = false
    
    init(account: Account, size: CGSize) {
        self.account = account
        self.intrinsicSize = size
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.autoplay = true
        
        super.init()
        
        self.addSubnode(self.animationNode)
        
        self.animationNode.completed = { [weak self] willStop in
            guard let strongSelf = self, !strongSelf.didTryAdvancingState, let state = strongSelf.state else {
                return
            }
            
            if state.item.loop && strongSelf.trackStack.isEmpty {
                
            } else {
                strongSelf.didTryAdvancingState = true
                strongSelf.advanceState()
            }
        }
    }
    
    var initialized = false
    override func didLoad() {
        super.didLoad()
        
        self.initialized = true
        self.advanceState()
    }
    
    
    private func advanceState() {
        guard !self.trackStack.isEmpty else {
            return
        }
        
        let item = self.trackStack.removeFirst()
        
        if let state = self.state, state.item.source == item.source {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: state)
        } else {
            self.state = ManagedAnimationState(displaySize: self.intrinsicSize, item: item, current: nil)
        }
        
        var source: AnimatedStickerNodeSource?
        switch item.source {
            case let .local(animationName):
                source = AnimatedStickerNodeLocalFileSource(name: animationName)
            case let .resource(account, resource):
                source = AnimatedStickerResourceSource(account: account, resource: resource._asResource())
        }
        
        let playbackMode: AnimatedStickerPlaybackMode
        if item.loop {
            playbackMode = .loop
        } else if let frames = item.frames, case let .still(position) = frames {
            playbackMode = .still(position == .start ? .start : .end)
        } else {
            playbackMode = .once
        }
        
        if let source = source {
            self.animationNode.setup(source: source, width: Int(self.intrinsicSize.width), height: Int(self.intrinsicSize.height), playbackMode: playbackMode, mode: .direct(cachePathPrefix: nil))
        }
        
        self.didTryAdvancingState = false
    }
    
    func trackTo(item: ManagedAnimationItem) {
        if let currentItem = self.state?.item {
            if currentItem.source == item.source && currentItem.frames == item.frames && currentItem.loop == item.loop {
                return
            }
        }
        self.trackStack.append(item)
        self.didTryAdvancingState = false
        
        if !self.animationNode.isPlaying && self.initialized {
            self.advanceState()
        }
    }
    
    override func layout() {
        super.layout()
        
        self.animationNode.updateLayout(size: self.bounds.size)
        self.animationNode.frame = self.bounds
    }
    
    public func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
    }
}
