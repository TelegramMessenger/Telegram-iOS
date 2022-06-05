import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache

public protocol MultiAnimationRenderer: AnyObject {
    func add(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable) -> Disposable
    func loadFirstFrameSynchronously(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String) -> Bool
}

open class MultiAnimationRenderTarget: SimpleLayer {
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
}

private func convertFrameToImage(frame: AnimationCacheItemFrame) -> UIImage? {
    switch frame.format {
    case let .rgba(width, height, bytesPerRow):
        let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow)
        let range = frame.range
        frame.data.withUnsafeBytes { bytes -> Void in
            memcpy(context.bytes, bytes.baseAddress!.advanced(by: range.lowerBound), min(context.length, range.upperBound - range.lowerBound))
        }
        return context.generateImage()
    }
}

private final class FrameGroup {
    let image: UIImage
    let size: CGSize
    let frameRange: Range<Int>
    let count: Int
    let skip: Int
    
    init?(item: AnimationCacheItem, baseFrameIndex: Int, count: Int, skip: Int) {
        if count == 0 {
            return nil
        }
        
        assert(count % skip == 0)
        
        let actualCount = count / skip
        
        guard let firstFrame = item.getFrame(index: baseFrameIndex % item.numFrames) else {
            return nil
        }
        
        switch firstFrame.format {
        case let .rgba(width, height, bytesPerRow):
            let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height * actualCount)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow)
            for i in stride(from: baseFrameIndex, to: baseFrameIndex + count, by: skip) {
                let frame: AnimationCacheItemFrame
                if i == baseFrameIndex {
                    frame = firstFrame
                } else {
                    if let nextFrame = item.getFrame(index: i % item.numFrames) {
                        frame = nextFrame
                    } else {
                        return nil
                    }
                }
                
                let localFrameIndex = (i - baseFrameIndex) / skip
                
                frame.data.withUnsafeBytes { bytes -> Void in
                    memcpy(context.bytes.advanced(by: localFrameIndex * height * bytesPerRow), bytes.baseAddress!.advanced(by: frame.range.lowerBound), height * bytesPerRow)
                }
            }
            
            guard let image = context.generateImage() else {
                return nil
            }
            
            self.image = image
            self.size = CGSize(width: CGFloat(width), height: CGFloat(height))
            self.frameRange = baseFrameIndex ..< (baseFrameIndex + count)
            self.count = count
            self.skip = skip
        }
    }
    
    func contentsRect(index: Int) -> CGRect? {
        if !self.frameRange.contains(index) {
            return nil
        }
        let actualCount = self.count / self.skip
        let localIndex = (index - self.frameRange.lowerBound) / self.skip
        
        let itemHeight = 1.0 / CGFloat(actualCount)
        return CGRect(origin: CGPoint(x: 0.0, y: CGFloat(localIndex) * itemHeight), size: CGSize(width: 1.0, height: itemHeight))
    }
}

private final class LoadFrameGroupTask {
    let task: () -> () -> Void
    
    init(task: @escaping () -> () -> Void) {
        self.task = task
    }
}

private final class ItemAnimationContext {
    static let queue = Queue(name: "ItemAnimationContext", qos: .default)
    
    private let cache: AnimationCache
    private let stateUpdated: () -> Void
    
    private var disposable: Disposable?
    private var displayLink: ConstantDisplayLinkAnimator?
    private var frameIndex: Int = 0
    private var item: AnimationCacheItem?
    
    private var currentFrameGroup: FrameGroup?
    private var isLoadingFrameGroup: Bool = false
    
    private(set) var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                self.stateUpdated()
            }
        }
    }
    
    let targets = Bag<Weak<MultiAnimationRenderTarget>>()
    
    init(cache: AnimationCache, itemId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable, stateUpdated: @escaping () -> Void) {
        self.cache = cache
        self.stateUpdated = stateUpdated
        
        self.disposable = cache.get(sourceId: itemId, fetch: fetch).start(next: { [weak self] item in
            Queue.mainQueue().async {
                guard let strongSelf = self, let item = item else {
                    return
                }
                strongSelf.item = item
                strongSelf.updateIsPlaying()
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
            
            return LoadFrameGroupTask(task: { [weak self] in
                let possibleCounts: [Int] = [10, 12, 14, 16, 18, 20]
                let countIndex = Int.random(in: 0 ..< possibleCounts.count)
                let currentFrameGroup = FrameGroup(item: item, baseFrameIndex: currentFrame, count: possibleCounts[countIndex], skip: 2)
                
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
            self.frameIndex += 2
        }
        
        if let currentFrameGroup = self.currentFrameGroup, let contentsRect = currentFrameGroup.contentsRect(index: currentFrame) {
            for target in self.targets.copyItems() {
                target.value?.contentsRect = contentsRect
            }
        }
        
        return nil
    }
}

public final class MultiAnimationRendererImpl: MultiAnimationRenderer {
    private final class GroupContext {
        private let stateUpdated: () -> Void
        
        private var itemContexts: [String: ItemAnimationContext] = [:]
        
        private(set) var isPlaying: Bool = false {
            didSet {
                if self.isPlaying != oldValue {
                    self.stateUpdated()
                }
            }
        }
        
        init(stateUpdated: @escaping () -> Void) {
            self.stateUpdated = stateUpdated
        }
        
        func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable) -> Disposable {
            let itemContext: ItemAnimationContext
            if let current = self.itemContexts[itemId] {
                itemContext = current
            } else {
                itemContext = ItemAnimationContext(cache: cache, itemId: itemId, fetch: fetch, stateUpdated: { [weak self] in
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
        
        func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String) -> Bool {
            if let item = cache.getSynchronously(sourceId: itemId) {
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
                        self.displayLink?.frameInterval = 2
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
    }
    
    public func add(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, fetch: @escaping (AnimationCacheItemWriter) -> Disposable) -> Disposable {
        let groupContext: GroupContext
        if let current = self.groupContexts[groupId] {
            groupContext = current
        } else {
            groupContext = GroupContext(stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContexts[groupId] = groupContext
        }
        
        let disposable = groupContext.add(target: target, cache: cache, itemId: itemId, fetch: fetch)
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
    
    public func loadFirstFrameSynchronously(groupId: String, target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String) -> Bool {
        let groupContext: GroupContext
        if let current = self.groupContexts[groupId] {
            groupContext = current
        } else {
            groupContext = GroupContext(stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContexts[groupId] = groupContext
        }
        
        return groupContext.loadFirstFrameSynchronously(target: target, cache: cache, itemId: itemId)
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
