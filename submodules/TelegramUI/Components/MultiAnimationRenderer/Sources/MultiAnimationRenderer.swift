import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
import Accelerate

public protocol MultiAnimationRenderer: AnyObject {
    func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, unique: Bool, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Disposable
    func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool
    func loadFirstFrame(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (Bool, Bool) -> Void) -> Disposable
    func setFrameIndex(itemId: String, size: CGSize, frameIndex: Int, placeholder: UIImage)
}

private var nextRenderTargetId: Int64 = 1

open class MultiAnimationRenderTarget: SimpleLayer {
    public let id: Int64
    
    let deinitCallbacks = Bag<() -> Void>()
    let updateStateCallbacks = Bag<() -> Void>()
    
    public final var shouldBeAnimating: Bool = false {
        didSet {
            if self.shouldBeAnimating != oldValue {
                for f in self.updateStateCallbacks.copyItems() {
                    f()
                }
            }
        }
    }
    
    public var blurredRepresentationBackgroundColor: UIColor?
    public var blurredRepresentationTarget: CALayer? {
        didSet {
            if self.blurredRepresentationTarget !== oldValue {
                for f in self.updateStateCallbacks.copyItems() {
                    f()
                }
            }
        }
    }
    
    public override init() {
        assert(Thread.isMainThread)
        
        self.id = nextRenderTargetId
        nextRenderTargetId += 1
        
        super.init()
    }
    
    public override init(layer: Any) {
        guard let layer = layer as? MultiAnimationRenderTarget else {
            preconditionFailure()
        }
        
        self.id = layer.id
        
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        for f in self.deinitCallbacks.copyItems() {
            f()
        }
    }
    
    open func updateDisplayPlaceholder(displayPlaceholder: Bool) {
    }
    
    open func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
    }
}

private final class LoadFrameGroupTask {
    let task: () -> () -> Void
    let queueAffinity: Int
    
    init(task: @escaping () -> () -> Void, queueAffinity: Int) {
        self.task = task
        self.queueAffinity = queueAffinity
    }
}

private final class ItemAnimationContext {
    fileprivate final class Frame {
        let frame: AnimationCacheItemFrame
        let duration: Double
        let image: UIImage
        let badgeImage: UIImage?
        let size: CGSize
        
        var remainingDuration: Double
        
        private var blurredRepresentationValue: UIImage?
        
        init?(frame: AnimationCacheItemFrame) {
            self.frame = frame
            self.duration = frame.duration
            self.remainingDuration = frame.duration
            
            switch frame.format {
            case let .rgba(data, width, height, bytesPerRow):
                let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow)
                    
                data.withUnsafeBytes { bytes -> Void in
                    memcpy(context.bytes, bytes.baseAddress!, height * bytesPerRow)
                }
                
                guard let image = context.generateImage() else {
                    return nil
                }
                
                self.image = image
                self.size = CGSize(width: CGFloat(width), height: CGFloat(height))
                self.badgeImage = nil
            default:
                return nil
            }
        }
        
        func blurredRepresentation(color: UIColor?) -> UIImage? {
            if let blurredRepresentationValue = self.blurredRepresentationValue {
                return blurredRepresentationValue
            }
            
            switch frame.format {
            case let .rgba(data, width, height, bytesPerRow):
                let blurredWidth = 12
                let blurredHeight = 12
                let context = DrawingContext(size: CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight)), scale: 1.0, opaque: true, bytesPerRow: bytesPerRow)
                
                let size = CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight))
                
                data.withUnsafeBytes { bytes -> Void in
                    if let dataProvider = CGDataProvider(dataInfo: nil, data: bytes.baseAddress!, size: bytes.count, releaseData: { _, _, _ in }) {
                        let image = CGImage(
                            width: width,
                            height: height,
                            bitsPerComponent: 8,
                            bitsPerPixel: 32,
                            bytesPerRow: bytesPerRow,
                            space: DeviceGraphicsContextSettings.shared.colorSpace,
                            bitmapInfo: DeviceGraphicsContextSettings.shared.transparentBitmapInfo,
                            provider: dataProvider,
                            decode: nil,
                            shouldInterpolate: true,
                            intent: .defaultIntent
                        )
                        if let image = image {
                            context.withFlippedContext { c in
                                c.setFillColor((color ?? .white).cgColor)
                                c.fill(CGRect(origin: CGPoint(), size: size))
                                c.draw(image, in: CGRect(origin: CGPoint(x: -size.width / 2.0, y: -size.height / 2.0), size: CGSize(width: size.width * 1.8, height: size.height * 1.8)))
                            }
                        }
                    }
                    
                    var destinationBuffer = vImage_Buffer()
                    destinationBuffer.width = UInt(blurredWidth)
                    destinationBuffer.height = UInt(blurredHeight)
                    destinationBuffer.data = context.bytes
                    destinationBuffer.rowBytes = context.bytesPerRow
                    
                    vImageBoxConvolve_ARGB8888(&destinationBuffer,
                                               &destinationBuffer,
                                               nil,
                                               0, 0,
                                               UInt32(15),
                                               UInt32(15),
                                               nil,
                                               vImage_Flags(kvImageTruncateKernel))
                    
                    let divisor: Int32 = 0x1000

                    let rwgt: CGFloat = 0.3086
                    let gwgt: CGFloat = 0.6094
                    let bwgt: CGFloat = 0.0820

                    let adjustSaturation: CGFloat = 1.7

                    let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
                    let b = (1.0 - adjustSaturation) * rwgt
                    let c = (1.0 - adjustSaturation) * rwgt
                    let d = (1.0 - adjustSaturation) * gwgt
                    let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
                    let f = (1.0 - adjustSaturation) * gwgt
                    let g = (1.0 - adjustSaturation) * bwgt
                    let h = (1.0 - adjustSaturation) * bwgt
                    let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

                    let satMatrix: [CGFloat] = [
                        a, b, c, 0,
                        d, e, f, 0,
                        g, h, i, 0,
                        0, 0, 0, 1
                    ]

                    var matrix: [Int16] = satMatrix.map { value in
                        return Int16(value * CGFloat(divisor))
                    }

                    vImageMatrixMultiply_ARGB8888(&destinationBuffer, &destinationBuffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
                    
                    context.withFlippedContext { c in
                        c.setFillColor((color ?? .white).withMultipliedAlpha(0.6).cgColor)
                        c.fill(CGRect(origin: CGPoint(), size: size))
                    }
                }
                
                self.blurredRepresentationValue = context.generateImage()
                return self.blurredRepresentationValue
            default:
                return nil
            }
        }
    }
    
    static let queue0 = Queue(name: "ItemAnimationContext-0", qos: .default)
    static let queue1 = Queue(name: "ItemAnimationContext-1", qos: .default)
    
    private let cache: AnimationCache
    let queueAffinity: Int
    private let stateUpdated: () -> Void
    
    private var disposable: Disposable?
    private var displayLink: ConstantDisplayLinkAnimator?
    private var item: Atomic<AnimationCacheItem>?
    private var itemPlaceholderAndFrameIndex: (UIImage, Int)?
    
    private var currentFrame: Frame?
    private var loadingFrameTaskId: Int?
    private var nextLoadingFrameTaskId: Int = 0
    
    private(set) var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                self.stateUpdated()
            }
        }
    }
    
    let targets = Bag<Weak<MultiAnimationRenderTarget>>()
    
    init(cache: AnimationCache, queueAffinity: Int, itemId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable, stateUpdated: @escaping () -> Void) {
        self.cache = cache
        self.queueAffinity = queueAffinity
        self.stateUpdated = stateUpdated
        
        self.disposable = cache.get(sourceId: itemId, size: size, fetch: fetch).start(next: { [weak self] result in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let item = result.item {
                    strongSelf.item = Atomic(value: item)
                }
                if let (placeholder, index) = strongSelf.itemPlaceholderAndFrameIndex {
                    strongSelf.itemPlaceholderAndFrameIndex = nil
                    strongSelf.setFrameIndex(index: index, placeholder: placeholder)
                }
                strongSelf.updateIsPlaying()
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
        self.displayLink?.invalidate()
    }
    
    func setFrameIndex(index: Int, placeholder: UIImage) {
        if let item = self.item {
            let nextFrame = item.with { item -> AnimationCacheItemFrame? in
                item.reset()
                for i in 0 ... index {
                    let result = item.advance(advance: .frames(1), requestedFormat: .rgba)
                    if i == index {
                        return result?.frame
                    }
                }
                return nil
            }
            
            self.loadingFrameTaskId = nil
            
            if let nextFrame = nextFrame, let currentFrame = Frame(frame: nextFrame) {
                self.currentFrame = currentFrame
                
                for target in self.targets.copyItems() {
                    if let target = target.value {
                        target.transitionToContents(currentFrame.image.cgImage!, didLoop: false)
                        
                        if let blurredRepresentationTarget = target.blurredRepresentationTarget {
                            blurredRepresentationTarget.contents = currentFrame.blurredRepresentation(color: target.blurredRepresentationBackgroundColor)?.cgImage
                        }
                    }
                }
            }
        } else {
            for target in self.targets.copyItems() {
                if let target = target.value {
                    target.transitionToContents(placeholder.cgImage!, didLoop: false)
                }
            }
            
            self.itemPlaceholderAndFrameIndex = (placeholder, index)
        }
    }
    
    func updateAddedTarget(target: MultiAnimationRenderTarget) {
        if let currentFrame = self.currentFrame {
            if let cgImage = currentFrame.image.cgImage {
                target.transitionToContents(cgImage, didLoop: false)
                
                if let blurredRepresentationTarget = target.blurredRepresentationTarget {
                    blurredRepresentationTarget.contents = currentFrame.blurredRepresentation(color: target.blurredRepresentationBackgroundColor)?.cgImage
                }
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
    
    func animationTick(advanceTimestamp: Double) -> LoadFrameGroupTask? {
        return self.update(advanceTimestamp: advanceTimestamp)
    }
    
    private func update(advanceTimestamp: Double) -> LoadFrameGroupTask? {
        guard let item = self.item else {
            return nil
        }
        
        var frameAdvance: AnimationCacheItem.Advance?
        if self.loadingFrameTaskId == nil {
            if let currentFrame = self.currentFrame, advanceTimestamp > 0.0 {
                let divisionFactor = advanceTimestamp / currentFrame.remainingDuration
                let wholeFactor = round(divisionFactor)
                if abs(wholeFactor - divisionFactor) < 0.005 {
                    currentFrame.remainingDuration = 0.0
                    frameAdvance = .frames(Int(wholeFactor))
                } else {
                    currentFrame.remainingDuration -= advanceTimestamp
                    if currentFrame.remainingDuration <= 0.0 {
                        frameAdvance = .duration(currentFrame.duration + max(0.0, -currentFrame.remainingDuration))
                    }
                }
            } else if self.currentFrame == nil {
                frameAdvance = .frames(1)
            }
        }
        
        if let frameAdvance = frameAdvance, self.loadingFrameTaskId == nil {
            let taskId = self.nextLoadingFrameTaskId
            self.nextLoadingFrameTaskId += 1
            
            self.loadingFrameTaskId = taskId
            
            return LoadFrameGroupTask(task: { [weak self] in
                let currentFrame: (frame: Frame, didLoop: Bool)?
                do {
                    if let (frame, didLoop) = try item.tryWith({ item -> (AnimationCacheItemFrame, Bool)? in
                        if let result = item.advance(advance: frameAdvance, requestedFormat: .rgba) {
                            return (result.frame, result.didLoop)
                        } else {
                            return nil
                        }
                    }), let mappedFrame = Frame(frame: frame) {
                        currentFrame = (mappedFrame, didLoop)
                    } else {
                        currentFrame = nil
                    }
                } catch {
                    assertionFailure()
                    currentFrame = nil
                }
                
                return {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if strongSelf.loadingFrameTaskId != taskId {
                        return
                    }
                    
                    strongSelf.loadingFrameTaskId = nil
                    
                    if let currentFrame = currentFrame {
                        strongSelf.currentFrame = currentFrame.frame
                        for target in strongSelf.targets.copyItems() {
                            if let target = target.value {
                                target.transitionToContents(currentFrame.frame.image.cgImage!, didLoop: currentFrame.didLoop)
                                
                                if let blurredRepresentationTarget = target.blurredRepresentationTarget {
                                    blurredRepresentationTarget.contents = currentFrame.frame.blurredRepresentation(color: target.blurredRepresentationBackgroundColor)?.cgImage
                                }
                            }
                        }
                    }
                }
            }, queueAffinity: self.queueAffinity)
        }
        
        if let _ = self.currentFrame {
            for target in self.targets.copyItems() {
                if let target = target.value {
                    target.updateDisplayPlaceholder(displayPlaceholder: false)
                }
            }
        }
        
        return nil
    }
}

public final class MultiAnimationRendererImpl: MultiAnimationRenderer {
    private final class GroupContext {
        private let firstFrameQueue: Queue
        private let stateUpdated: () -> Void
        
        private struct ItemKey: Hashable {
            var id: String
            var width: Int
            var height: Int
            var uniqueId: Int
        }
        
        private var itemContexts: [ItemKey: ItemAnimationContext] = [:]
        private var nextQueueAffinity: Int = 0
        private var nextUniqueId: Int = 1
        
        private(set) var isPlaying: Bool = false {
            didSet {
                if self.isPlaying != oldValue {
                    self.stateUpdated()
                }
            }
        }
        
        init(firstFrameQueue: Queue, stateUpdated: @escaping () -> Void) {
            self.firstFrameQueue = firstFrameQueue
            self.stateUpdated = stateUpdated
        }
        
        func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, unique: Bool, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Disposable {
            var uniqueId = 0
            if unique {
                uniqueId = self.nextUniqueId
                self.nextUniqueId += 1
            }
            
            let itemKey = ItemKey(id: itemId, width: Int(size.width), height: Int(size.height), uniqueId: uniqueId)
            let itemContext: ItemAnimationContext
            if let current = self.itemContexts[itemKey] {
                itemContext = current
            } else {
                let queueAffinity = self.nextQueueAffinity
                self.nextQueueAffinity += 1
                itemContext = ItemAnimationContext(cache: cache, queueAffinity: queueAffinity, itemId: itemId, size: size, fetch: fetch, stateUpdated: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateIsPlaying()
                })
                self.itemContexts[itemKey] = itemContext
            }
            
            let index = itemContext.targets.add(Weak(target))
            itemContext.updateAddedTarget(target: target)
            
            let deinitIndex = target.deinitCallbacks.add { [weak self, weak itemContext] in
                Queue.mainQueue().async {
                    guard let strongSelf = self, let itemContext = itemContext, strongSelf.itemContexts[itemKey] === itemContext else {
                        return
                    }
                    itemContext.targets.remove(index)
                    if itemContext.targets.isEmpty {
                        strongSelf.itemContexts.removeValue(forKey: itemKey)
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
                guard let strongSelf = self, let itemContext = itemContext, strongSelf.itemContexts[itemKey] === itemContext else {
                    return
                }
                if let target = target {
                    target.deinitCallbacks.remove(deinitIndex)
                    target.updateStateCallbacks.remove(updateStateIndex)
                }
                itemContext.targets.remove(index)
                if itemContext.targets.isEmpty {
                    strongSelf.itemContexts.removeValue(forKey: itemKey)
                }
            }
        }
        
        func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool {
            if let item = cache.getFirstFrameSynchronously(sourceId: itemId, size: size) {
                guard let frame = item.advance(advance: .frames(1), requestedFormat: .rgba) else {
                    return false
                }
                guard let loadedFrame = ItemAnimationContext.Frame(frame: frame.frame) else {
                    return false
                }
                
                target.contents = loadedFrame.image.cgImage
                
                if let blurredRepresentationTarget = target.blurredRepresentationTarget {
                    blurredRepresentationTarget.contents = loadedFrame.blurredRepresentation(color: target.blurredRepresentationBackgroundColor)?.cgImage
                }
                
                return true
            } else {
                return false
            }
        }
        
        func loadFirstFrame(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (Bool, Bool) -> Void) -> Disposable {
            var hadIntermediateUpdate = false
            return cache.getFirstFrame(queue: self.firstFrameQueue, sourceId: itemId, size: size, fetch: fetch, completion: { [weak target] item in
                guard let item = item.item else {
                    let isFinal = item.isFinal
                    hadIntermediateUpdate = true
                    Queue.mainQueue().async {
                        completion(false, isFinal)
                    }
                    return
                }
                
                let loadedFrame: ItemAnimationContext.Frame?
                if let frame = item.advance(advance: .frames(1), requestedFormat: .rgba) {
                    loadedFrame = ItemAnimationContext.Frame(frame: frame.frame)
                } else {
                    loadedFrame = nil
                }
                
                Queue.mainQueue().async {
                    guard let target = target else {
                        completion(false, true)
                        return
                    }
                    if let loadedFrame = loadedFrame {
                        if let cgImage = loadedFrame.image.cgImage {
                            if hadIntermediateUpdate {
                                target.transitionToContents(cgImage, didLoop: false)
                            } else {
                                target.contents = cgImage
                            }
                        }
                        
                        if let blurredRepresentationTarget = target.blurredRepresentationTarget {
                            blurredRepresentationTarget.contents = loadedFrame.blurredRepresentation(color: target.blurredRepresentationBackgroundColor)?.cgImage
                        }
                        
                        completion(true, true)
                    } else {
                        completion(false, true)
                    }
                }
            })
        }
        
        func setFrameIndex(itemId: String, size: CGSize, frameIndex: Int, placeholder: UIImage) {
            if let itemContext = self.itemContexts[ItemKey(id: itemId, width: Int(size.width), height: Int(size.height), uniqueId: 0)] {
                itemContext.setFrameIndex(index: frameIndex, placeholder: placeholder)
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
        
        func animationTick(advanceTimestamp: Double) -> [LoadFrameGroupTask] {
            var tasks: [LoadFrameGroupTask] = []
            for (_, itemContext) in self.itemContexts {
                if itemContext.isPlaying {
                    if let task = itemContext.animationTick(advanceTimestamp: advanceTimestamp) {
                        tasks.append(task)
                    }
                }
            }
            
            return tasks
        }
    }
    
    public static let firstFrameQueue = Queue(name: "MultiAnimationRenderer-FirstFrame", qos: .userInteractive)
    
    private var groupContext: GroupContext?
    private var frameSkip: Int
    private var displayTimer: Foundation.Timer?
    
    private(set) var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                if self.isPlaying {
                    if self.displayTimer == nil {
                        final class TimerTarget: NSObject {
                            private let f: () -> Void
                            
                            init(_ f: @escaping () -> Void) {
                                self.f = f
                            }
                            
                            @objc func timerEvent() {
                                self.f()
                            }
                        }
                        let frameInterval = Double(self.frameSkip) / 60.0
                        let displayTimer = Foundation.Timer(timeInterval: frameInterval, target: TimerTarget { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.animationTick(frameInterval: frameInterval)
                        }, selector: #selector(TimerTarget.timerEvent), userInfo: nil, repeats: true)
                        self.displayTimer = displayTimer
                        RunLoop.main.add(displayTimer, forMode: .common)
                    }
                } else {
                    if let displayTimer = self.displayTimer {
                        self.displayTimer = nil
                        displayTimer.invalidate()
                    }
                }
            }
        }
    }
    
    public init() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled && ProcessInfo.processInfo.processorCount > 2 {
            self.frameSkip = 1
        } else {
            self.frameSkip = 2
        }
    }
    
    public func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, unique: Bool, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Disposable {
        let groupContext: GroupContext
        if let current = self.groupContext {
            groupContext = current
        } else {
            groupContext = GroupContext(firstFrameQueue: MultiAnimationRendererImpl.firstFrameQueue, stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContext = groupContext
        }
        
        let disposable = groupContext.add(target: target, cache: cache, itemId: itemId, unique: unique, size: size, fetch: fetch)
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
    
    public func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool {
        let groupContext: GroupContext
        if let current = self.groupContext {
            groupContext = current
        } else {
            groupContext = GroupContext(firstFrameQueue: MultiAnimationRendererImpl.firstFrameQueue, stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContext = groupContext
        }
        
        return groupContext.loadFirstFrameSynchronously(target: target, cache: cache, itemId: itemId, size: size)
    }
    
    public func loadFirstFrame(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (Bool, Bool) -> Void) -> Disposable {
        let groupContext: GroupContext
        if let current = self.groupContext {
            groupContext = current
        } else {
            groupContext = GroupContext(firstFrameQueue: MultiAnimationRendererImpl.firstFrameQueue, stateUpdated: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIsPlaying()
            })
            self.groupContext = groupContext
        }
        
        return groupContext.loadFirstFrame(target: target, cache: cache, itemId: itemId, size: size, fetch: fetch, completion: completion)
    }
    
    public func setFrameIndex(itemId: String, size: CGSize, frameIndex: Int, placeholder: UIImage) {
        if let groupContext = self.groupContext {
            groupContext.setFrameIndex(itemId: itemId, size: size, frameIndex: frameIndex, placeholder: placeholder)
        }
    }
    
    private func updateIsPlaying() {
        var isPlaying = false
        if let groupContext = self.groupContext {
            if groupContext.isPlaying {
                isPlaying = true
            }
        }
        
        self.isPlaying = isPlaying
    }
    
    private func animationTick(frameInterval: Double) {
        let secondsPerFrame = frameInterval
        
        var tasks: [LoadFrameGroupTask] = []
        if let groupContext = self.groupContext {
            if groupContext.isPlaying {
                tasks.append(contentsOf: groupContext.animationTick(advanceTimestamp: secondsPerFrame))
            }
        }
        
        if !tasks.isEmpty {
            let tasks0 = tasks.filter { $0.queueAffinity % 2 == 0 }
            let tasks1 = tasks.filter { $0.queueAffinity % 2 == 1 }
            let allTasks = [tasks0, tasks1]
            
            let taskCompletions = Atomic<[Int: [() -> Void]]>(value: [:])
            let queues: [Queue] = [ItemAnimationContext.queue0, ItemAnimationContext.queue1]
            
            for i in 0 ..< 2 {
                let partTasks = allTasks[i]
                let id = i
                queues[i].async {
                    var completions: [() -> Void] = []
                    for task in partTasks {
                        let complete = task.task()
                        completions.append(complete)
                    }
                    
                    var complete = false
                    let _ = taskCompletions.modify { current in
                        var current = current
                        current[id] = completions
                        if current.count == 2 {
                            complete = true
                        }
                        return current
                    }
                    
                    if complete {
                        Queue.mainQueue().async {
                            let allCompletions = taskCompletions.with { $0 }
                            for (_, fs) in allCompletions {
                                for f in fs {
                                    f()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
