import Foundation
import UIKit
import SwiftSignalKit
import Display
import SoftwareVideo

/*public protocol MultiVideoRenderer: AnyObject {
    func add(groupId: String, target: MultiVideoRenderTarget, itemId: String, size: CGSize, source: @escaping (@escaping (String) -> Void) -> Disposable) -> Disposable
}

open class MultiVideoRenderTarget: SimpleLayer {
    fileprivate let deinitCallbacks = Bag<() -> Void>()
    fileprivate let updateStateCallbacks = Bag<() -> Void>()
    
    public final var shouldBeAnimating: Bool = false {
        didSet {
            if self.shouldBeAnimating != oldValue {
                for f in self.updateStateCallbacks.copyItems() {
                    f()
                }
            }
        }
    }
    
    deinit {
        for f in self.deinitCallbacks.copyItems() {
            f()
        }
    }
    
    open func updateDisplayPlaceholder(displayPlaceholder: Bool) {
    }
}

private final class ItemVideoContext {
    static let queue = Queue(name: "ItemVideoContext", qos: .default)
    
    private let stateUpdated: () -> Void
    
    private var disposable: Disposable?
    private var displayLink: ConstantDisplayLinkAnimator?
    private var frameManager: SoftwareVideoLayerFrameManager?
    
    private(set) var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                self.stateUpdated()
            }
        }
    }
    
    let targets = Bag<Weak<MultiVideoRenderTarget>>()
    
    init(itemId: String, source: @escaping (@escaping (String) -> Void) -> Disposable, stateUpdated: @escaping () -> Void) {
        self.stateUpdated = stateUpdated
        
        self.disposable = source({ [weak self] in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                //strongSelf.frameManager = SoftwareVideoLayerFrameManager(account: <#T##Account#>, fileReference: <#T##FileMediaReference#>, layerHolder: <#T##SampleBufferLayer#>)
                strongSelf.updateIsPlaying()
                
                if result.item == nil {
                    for target in strongSelf.targets.copyItems() {
                        if let target = target.value {
                            target.updateDisplayPlaceholder(displayPlaceholder: true)
                        }
                    }
                }
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
        self.displayLink?.invalidate()
    }
    
    func updateAddedTarget(target: MultiAnimationRenderTarget) {
        if let item = self.item, let currentFrameGroup = self.currentFrameGroup {
            let currentFrame = self.frameIndex % item.numFrames
            
            if let contentsRect = currentFrameGroup.contentsRect(index: currentFrame) {
                target.updateDisplayPlaceholder(displayPlaceholder: false)
                target.contents = currentFrameGroup.image.cgImage
                target.contentsRect = contentsRect
            }
        }
        
        self.updateIsPlaying()
    }
    
    func updateIsPlaying() {
        var isPlaying = true
        if self.item == nil {
            isPlaying = false
        }
        
        var shouldBeAnimating = false
        for target in self.targets.copyItems() {
            if let target = target.value {
                if target.shouldBeAnimating {
                    shouldBeAnimating = true
                    break
                }
            }
        }
        if !shouldBeAnimating {
            isPlaying = false
        }
        
        self.isPlaying = isPlaying
    }
    
    func animationTick() -> LoadFrameGroupTask? {
        return self.update(advanceFrame: true)
    }
    
    private func update(advanceFrame: Bool) -> LoadFrameGroupTask? {
        guard let item = self.item else {
            return nil
        }
        
        let currentFrame = self.frameIndex % item.numFrames
        
        if let currentFrameGroup = self.currentFrameGroup, currentFrameGroup.frameRange.contains(currentFrame) {
        } else if !self.isLoadingFrameGroup {
            self.currentFrameGroup = nil
            self.isLoadingFrameGroup = true
            let frameSkip = self.frameSkip
            
            return LoadFrameGroupTask(task: { [weak self] in
                let possibleCounts: [Int] = [10, 12, 14, 16, 18, 20]
                let countIndex = Int.random(in: 0 ..< possibleCounts.count)
                let currentFrameGroup = FrameGroup(item: item, baseFrameIndex: currentFrame, count: possibleCounts[countIndex], skip: frameSkip)
                
                return {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.isLoadingFrameGroup = false
                    
                    if let currentFrameGroup = currentFrameGroup {
                        strongSelf.currentFrameGroup = currentFrameGroup
                        for target in strongSelf.targets.copyItems() {
                            target.value?.contents = currentFrameGroup.image.cgImage
                        }
                        
                        let _ = strongSelf.update(advanceFrame: false)
                    }
                }
            })
        }
        
        if advanceFrame {
            self.frameIndex += self.frameSkip
        }
        
        if let currentFrameGroup = self.currentFrameGroup, let contentsRect = currentFrameGroup.contentsRect(index: currentFrame) {
            for target in self.targets.copyItems() {
                if let target = target.value {
                    target.updateDisplayPlaceholder(displayPlaceholder: false)
                    target.contentsRect = contentsRect
                }
            }
        }
        
        return nil
    }
}

public final class MultiAnimationRendererImpl: MultiAnimationRenderer {
    private final class GroupContext {
        private var frameSkip: Int
        private let stateUpdated: () -> Void
        
        private var itemContexts: [String: ItemAnimationContext] = [:]
        
        private(set) var isPlaying: Bool = false {
            didSet {
                if self.isPlaying != oldValue {
                    self.stateUpdated()
                }
            }
        }
        
        init(frameSkip: Int, stateUpdated: @escaping () -> Void) {
            self.frameSkip = frameSkip
            self.stateUpdated = stateUpdated
        }
        
        func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable) -> Disposable {
            let itemContext: ItemAnimationContext
            if let current = self.itemContexts[itemId] {
                itemContext = current
            } else {
                itemContext = ItemAnimationContext(cache: cache, itemId: itemId, size: size, frameSkip: self.frameSkip, fetch: fetch, stateUpdated: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateIsPlaying()
                })
                self.itemContexts[itemId] = itemContext
            }
            
            let index = itemContext.targets.add(Weak(target))
            itemContext.updateAddedTarget(target: target)
            
            let deinitIndex = target.deinitCallbacks.add { [weak self, weak itemContext] in
                Queue.mainQueue().async {
                    guard let strongSelf = self, let itemContext = itemContext, strongSelf.itemContexts[itemId] === itemContext else {
                        return
                    }
                    itemContext.targets.remove(index)
                    if itemContext.targets.isEmpty {
                        strongSelf.itemContexts.removeValue(forKey: itemId)
                    }
                }
            }
            
            let updateStateIndex = target.updateStateCallbacks.add { [weak itemContext] in
                guard let itemContext = itemContext else {
                    return
                }
                itemContext.updateIsPlaying()
            }
            
            return ActionDisposable { [weak self, weak itemContext, weak target] in
                guard let strongSelf = self, let itemContext = itemContext, strongSelf.itemContexts[itemId] === itemContext else {
                    return
                }
                if let target = target {
                    target.deinitCallbacks.remove(deinitIndex)
                    target.updateStateCallbacks.remove(updateStateIndex)
                }
                itemContext.targets.remove(index)
                if itemContext.targets.isEmpty {
                    strongSelf.itemContexts.removeValue(forKey: itemId)
                }
            }
        }
        
        func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool {
            if let item = cache.getSynchronously(sourceId: itemId, size: size) {
                guard let frameGroup = FrameGroup(item: item, baseFrameIndex: 0, count: 1, skip: 1) else {
                    return false
                }
                
                target.contents = frameGroup.image.cgImage
                
                return true
            } else {
                return false
            }
        }
        
        private func updateIsPlaying() {
            var isPlaying = false
            for (_, itemContext) in self.itemContexts {
                if itemContext.isPlaying {
                    isPlaying = true
                    break
                }
            }
            
            self.isPlaying = isPlaying
        }
        
        func animationTick() -> [LoadFrameGroupTask] {
            var tasks: [LoadFrameGroupTask] = []
            for (_, itemContext) in self.itemContexts {
                if itemContext.isPlaying {
                    if let task = itemContext.animationTick() {
                        tasks.append(task)
                    }
                }
            }
            
            return tasks
        }
    }
    
    private var groupContexts: [String: GroupContext] = [:]
    private var frameSkip: Int
    private var displayLink: ConstantDisplayLinkAnimator?
    
    private(set) var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                if self.isPlaying {
                    if self.displayLink == nil {
                        self.displayLink = ConstantDisplayLinkAnimator { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.animationTick()
                        }
                        self.displayLink?.frameInterval = self.frameSkip
                        self.displayLink?.isPaused = false
                    }
                } else {
                    if let displayLink = self.displayLink {
                        self.displayLink = nil
                        displayLink.invalidate()
                    }
                }
            }
        }
    }
    
    public init() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled && ProcessInfo.processInfo.activeProcessorCount > 2 {
            self.frameSkip = 1
        } else {
            self.frameSkip = 2
        }
    }
    
    public func add(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: @escaping (CGSize, AnimationCacheItemWriter) -> Disposable) -> Disposable {
        let groupContext: GroupContext
        if let current = self.groupContexts[groupId] {
            groupContext = current
        } else {
            groupContext = GroupContext(frameSkip: self.frameSkip, stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContexts[groupId] = groupContext
        }
        
        let disposable = groupContext.add(target: target, cache: cache, itemId: itemId, size: size, fetch: fetch)
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
    
    public func loadFirstFrameSynchronously(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool {
        let groupContext: GroupContext
        if let current = self.groupContexts[groupId] {
            groupContext = current
        } else {
            groupContext = GroupContext(frameSkip: self.frameSkip, stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContexts[groupId] = groupContext
        }
        
        return groupContext.loadFirstFrameSynchronously(target: target, cache: cache, itemId: itemId, size: size)
    }
    
    private func updateIsPlaying() {
        var isPlaying = false
        for (_, groupContext) in self.groupContexts {
            if groupContext.isPlaying {
                isPlaying = true
                break
            }
        }
        
        self.isPlaying = isPlaying
    }
    
    private func animationTick() {
        var tasks: [LoadFrameGroupTask] = []
        for (_, groupContext) in self.groupContexts {
            if groupContext.isPlaying {
                tasks.append(contentsOf: groupContext.animationTick())
            }
        }
        
        if !tasks.isEmpty {
            ItemAnimationContext.queue.async {
                var completions: [() -> Void] = []
                for task in tasks {
                    let complete = task.task()
                    completions.append(complete)
                }
                
                if !completions.isEmpty {
                    Queue.mainQueue().async {
                        for completion in completions {
                            completion()
                        }
                    }
                }
            }
        }
    }
}
*/
