import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
import MultiAnimationRenderer
import SubcodecObjC
import SubcodecAnimationCacheImpl
import Accelerate

private let maxSlotsLimit: Int = 882

private func roundUp(_ numToRound: Int, multiple: Int) -> Int {
    if multiple == 0 { return numToRound }
    let remainder = numToRound % multiple
    if remainder == 0 { return numToRound }
    return numToRound + multiple - remainder
}

private final class SpriteContext {
    let mbsPath: String
    let region: SCSpriteRegion
    let targets = Bag<Weak<MultiAnimationRenderTarget>>()
    let metadata: MbsMetadata

    var currentFrameIndex: Int = 0
    var remainingDuration: Double = 0.0

    var isPlaying: Bool {
        for target in self.targets.copyItems() {
            if let target = target.value, target.shouldBeAnimating {
                return true
            }
        }
        return false
    }

    init(mbsPath: String, region: SCSpriteRegion, metadata: MbsMetadata) {
        self.mbsPath = mbsPath
        self.region = region
        self.metadata = metadata
        if !metadata.frameDurations.isEmpty {
            self.remainingDuration = metadata.frameDurations[0]
        }
    }
}

private final class SurfaceGroup {
    let spriteWidth: Int
    let spriteHeight: Int

    private(set) var surface: SCMuxSurface?
    private(set) var decoder: SCVideoToolboxDecoder?
    private(set) var spriteContexts: [Int: SpriteContext] = [:]
    private var currentMaxSlots: Int = 64
    private var accumulatedNalData = Data()
    private var lastDecodedFrame: SCDecodedFrame?

    init(spriteWidth: Int, spriteHeight: Int) {
        self.spriteWidth = spriteWidth
        self.spriteHeight = spriteHeight
    }

    func ensureInitialized() -> Bool {
        if self.surface != nil {
            return true
        }
        let sink: (Data) -> Void = { [weak self] data in
            self?.accumulatedNalData.append(data)
        }
        guard let surface = try? SCMuxSurface.create(
            withSpriteWidth: Int32(self.spriteWidth),
            spriteHeight: Int32(self.spriteHeight),
            maxSlots: Int32(self.currentMaxSlots),
            qp: 26,
            sink: sink
        ) else {
            return false
        }
        self.surface = surface

        guard let decoder = try? SCVideoToolboxDecoder.createDecoder() else {
            return false
        }
        self.decoder = decoder

        return true
    }

    func addSprite(mbsPath: String, metadata: MbsMetadata) -> SpriteContext? {
        guard self.ensureInitialized(), let surface = self.surface else {
            return nil
        }

        guard let region = try? surface.addSprite(atPath: mbsPath) else {
            if !self.tryGrow() {
                return nil
            }
            guard let region = try? surface.addSprite(atPath: mbsPath) else {
                return nil
            }
            let context = SpriteContext(mbsPath: mbsPath, region: region, metadata: metadata)
            self.spriteContexts[Int(region.slot)] = context
            return context
        }

        let context = SpriteContext(mbsPath: mbsPath, region: region, metadata: metadata)
        self.spriteContexts[Int(region.slot)] = context
        return context
    }

    func removeSprite(slot: Int) {
        self.surface?.removeSprite(atSlot: Int32(slot))
        self.spriteContexts.removeValue(forKey: slot)
    }

    private func tryGrow() -> Bool {
        guard let surface = self.surface, let decoder = self.decoder else {
            return false
        }

        let newMaxSlots: Int
        if self.currentMaxSlots * 2 <= maxSlotsLimit {
            newMaxSlots = self.currentMaxSlots * 2
        } else if self.currentMaxSlots < maxSlotsLimit {
            newMaxSlots = maxSlotsLimit
        } else {
            return false
        }

        if self.lastDecodedFrame == nil {
            self.accumulatedNalData = Data()
            guard let _ = try? surface.advanceFrame(sink: { [weak self] data in
                self?.accumulatedNalData.append(data)
            }) else {
                return false
            }
            if !self.accumulatedNalData.isEmpty {
                if let frames = try? decoder.decodeStream(self.accumulatedNalData) {
                    self.lastDecodedFrame = frames.last
                }
            }
        }

        guard let decodedFrame = self.lastDecodedFrame else {
            return false
        }

        self.accumulatedNalData = Data()
        let yData = decodedFrame.y
        let cbData = decodedFrame.cb
        let crData = decodedFrame.cr
        let decodedWidth = Int(decodedFrame.width)
        let decodedHeight = Int(decodedFrame.height)
        let chromaWidth = decodedWidth / 2

        guard let resizeResult = try? surface.resize(
            toMaxSlots: Int32(newMaxSlots),
            yPlane: yData,
            cbPlane: cbData,
            crPlane: crData,
            decodedWidth: Int32(decodedWidth),
            decodedHeight: Int32(decodedHeight),
            strideY: Int32(decodedWidth),
            strideCb: Int32(chromaWidth),
            strideCr: Int32(chromaWidth),
            withSink: { [weak self] data in
                self?.accumulatedNalData.append(data)
            }
        ) else {
            return false
        }

        if !self.accumulatedNalData.isEmpty {
            if let frames = try? decoder.decodeStream(self.accumulatedNalData) {
                self.lastDecodedFrame = frames.last
            }
        }

        var updatedContexts: [Int: SpriteContext] = [:]
        for newRegion in resizeResult.regions {
            let newSlot = Int(newRegion.slot)
            for (_, context) in self.spriteContexts {
                if updatedContexts.values.contains(where: { $0 === context }) {
                    continue
                }
                let updated = SpriteContext(mbsPath: context.mbsPath, region: newRegion, metadata: context.metadata)
                updated.currentFrameIndex = context.currentFrameIndex
                updated.remainingDuration = context.remainingDuration
                for target in context.targets.copyItems() {
                    if let target = target.value {
                        let _ = updated.targets.add(Weak(target))
                    }
                }
                updatedContexts[newSlot] = updated
                break
            }
        }

        self.spriteContexts = updatedContexts
        self.currentMaxSlots = newMaxSlots
        self.accumulatedNalData = Data()
        return true
    }

    func tick(advanceTimestamp: Double) {
        guard let surface = self.surface, let decoder = self.decoder else {
            return
        }

        var anyAdvanced = false
        for (slot, context) in self.spriteContexts {
            guard context.isPlaying else {
                continue
            }
            if advanceTimestamp > 0.0 {
                context.remainingDuration -= advanceTimestamp
                if context.remainingDuration <= 0.0 {
                    surface.advanceSprite(atSlot: Int32(slot))
                    context.currentFrameIndex += 1
                    if context.currentFrameIndex >= context.metadata.frameCount {
                        context.currentFrameIndex = 0
                    }
                    if context.currentFrameIndex < context.metadata.frameDurations.count {
                        context.remainingDuration = context.metadata.frameDurations[context.currentFrameIndex]
                    }
                    anyAdvanced = true
                }
            } else {
                surface.advanceSprite(atSlot: Int32(slot))
                anyAdvanced = true
            }
        }

        if !anyAdvanced {
            return
        }

        self.accumulatedNalData = Data()
        guard let _ = try? surface.emitFrameIfNeeded(sink: { [weak self] data in
            self?.accumulatedNalData.append(data)
        }) else {
            return
        }

        guard !self.accumulatedNalData.isEmpty else {
            return
        }

        guard let frames = try? decoder.decodeStream(self.accumulatedNalData) else {
            return
        }
        guard let decodedFrame = frames.last else {
            return
        }

        self.lastDecodedFrame = decodedFrame

        for (_, context) in self.spriteContexts {
            let region = context.region
            let colorRect = region.colorRect
            let alphaRect = region.alphaRect

            let frameWidth = Int(colorRect.width)
            let frameHeight = Int(colorRect.height)
            guard frameWidth > 0 && frameHeight > 0 else {
                continue
            }

            let cgImage = extractCGImage(
                decodedFrame: decodedFrame,
                colorRect: colorRect,
                alphaRect: alphaRect,
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )

            let didLoop = context.currentFrameIndex == 0 && context.metadata.frameCount > 1

            for targetRef in context.targets.copyItems() {
                if let target = targetRef.value {
                    if let cgImage = cgImage {
                        target.transitionToContents(cgImage, didLoop: didLoop)
                    }
                }
            }
        }
    }

    var isEmpty: Bool {
        return self.spriteContexts.isEmpty
    }

    var hasPlayingSprites: Bool {
        for (_, context) in self.spriteContexts {
            if context.isPlaying {
                return true
            }
        }
        return false
    }
}

private func extractCGImage(
    decodedFrame: SCDecodedFrame,
    colorRect: CGRect,
    alphaRect: CGRect,
    frameWidth: Int,
    frameHeight: Int
) -> CGImage? {
    let decodedWidth = Int(decodedFrame.width)
    let chromaWidth = decodedWidth / 2

    let bytesPerRow = frameWidth * 4
    let bufferSize = frameHeight * bytesPerRow
    guard let buffer = malloc(bufferSize) else {
        return nil
    }
    let outPtr = buffer.assumingMemoryBound(to: UInt8.self)

    let colorX = Int(colorRect.origin.x)
    let colorY = Int(colorRect.origin.y)
    let alphaX = Int(alphaRect.origin.x)
    let alphaY = Int(alphaRect.origin.y)

    decodedFrame.y.withUnsafeBytes { yBuf in
        decodedFrame.cb.withUnsafeBytes { cbBuf in
            decodedFrame.cr.withUnsafeBytes { crBuf in
                let yPtr = yBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let cbPtr = cbBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let crPtr = crBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)

                for row in 0 ..< frameHeight {
                    for col in 0 ..< frameWidth {
                        let srcY = yPtr[(colorY + row) * decodedWidth + (colorX + col)]
                        let srcCb = cbPtr[((colorY + row) / 2) * chromaWidth + ((colorX + col) / 2)]
                        let srcCr = crPtr[((colorY + row) / 2) * chromaWidth + ((colorX + col) / 2)]
                        let srcA = yPtr[(alphaY + row) * decodedWidth + (alphaX + col)]

                        let yVal = Int(srcY) - 16
                        let cbVal = Int(srcCb) - 128
                        let crVal = Int(srcCr) - 128

                        var r = (298 * yVal + 459 * crVal + 128) >> 8
                        var g = (298 * yVal - 55 * cbVal - 136 * crVal + 128) >> 8
                        var b = (298 * yVal + 541 * cbVal + 128) >> 8

                        r = max(0, min(255, r))
                        g = max(0, min(255, g))
                        b = max(0, min(255, b))

                        let a = Int(srcA)
                        let pr = (r * a + 127) / 255
                        let pg = (g * a + 127) / 255
                        let pb = (b * a + 127) / 255

                        let outOffset = (row * frameWidth + col) * 4
                        outPtr[outOffset + 0] = UInt8(pb)
                        outPtr[outOffset + 1] = UInt8(pg)
                        outPtr[outOffset + 2] = UInt8(pr)
                        outPtr[outOffset + 3] = UInt8(a)
                    }
                }
            }
        }
    }

    guard let dataProvider = CGDataProvider(dataInfo: nil, data: buffer, size: bufferSize, releaseData: { _, data, _ in
        free(UnsafeMutableRawPointer(mutating: data))
    }) else {
        free(buffer)
        return nil
    }

    return CGImage(
        width: frameWidth,
        height: frameHeight,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
        provider: dataProvider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}

public final class SubcodecMultiAnimationRendererImpl: MultiAnimationRenderer {
    private struct SizeKey: Hashable {
        let width: Int
        let height: Int
    }

    private var surfaceGroups: [SizeKey: SurfaceGroup] = [:]
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
        guard let subcodecCache = cache as? SubcodecAnimationCacheImpl else {
            return EmptyDisposable
        }

        let spriteWidth = roundUp(Int(size.width), multiple: 16)
        let spriteHeight = roundUp(Int(size.height), multiple: 16)
        let sizeKey = SizeKey(width: spriteWidth, height: spriteHeight)

        let fetchDisposable = MetaDisposable()

        fetchDisposable.set(subcodecCache.fetchIfNeeded(sourceId: itemId, size: size, fetch: fetch, completion: { [weak self, weak target] mbsPath in
            Queue.mainQueue().async {
                guard let strongSelf = self, let target = target, let mbsPath = mbsPath else {
                    return
                }

                guard let metadata = subcodecCache.loadMetadata(sourceId: itemId, size: size) else {
                    return
                }

                let surfaceGroup: SurfaceGroup
                if let existing = strongSelf.surfaceGroups[sizeKey] {
                    surfaceGroup = existing
                } else {
                    surfaceGroup = SurfaceGroup(spriteWidth: spriteWidth, spriteHeight: spriteHeight)
                    strongSelf.surfaceGroups[sizeKey] = surfaceGroup
                }

                guard let spriteContext = surfaceGroup.addSprite(mbsPath: mbsPath, metadata: metadata) else {
                    return
                }

                let targetIndex = spriteContext.targets.add(Weak(target))
                target.numFrames = metadata.frameCount

                let slot = Int(spriteContext.region.slot)

                let deinitIndex = target.deinitCallbacks.add { [weak self, weak surfaceGroup] in
                    Queue.mainQueue().async {
                        guard let strongSelf = self, let surfaceGroup = surfaceGroup else {
                            return
                        }
                        spriteContext.targets.remove(targetIndex)
                        if spriteContext.targets.isEmpty {
                            surfaceGroup.removeSprite(slot: slot)
                            if surfaceGroup.isEmpty {
                                strongSelf.surfaceGroups.removeValue(forKey: sizeKey)
                            }
                            strongSelf.updateIsPlaying()
                        }
                    }
                }

                let updateStateIndex = target.updateStateCallbacks.add { [weak self] in
                    self?.updateIsPlaying()
                }

                fetchDisposable.set(ActionDisposable { [weak self, weak surfaceGroup, weak target] in
                    guard let strongSelf = self, let surfaceGroup = surfaceGroup else {
                        return
                    }
                    if let target = target {
                        target.deinitCallbacks.remove(deinitIndex)
                        target.updateStateCallbacks.remove(updateStateIndex)
                    }
                    spriteContext.targets.remove(targetIndex)
                    if spriteContext.targets.isEmpty {
                        surfaceGroup.removeSprite(slot: slot)
                        if surfaceGroup.isEmpty {
                            strongSelf.surfaceGroups.removeValue(forKey: sizeKey)
                        }
                        strongSelf.updateIsPlaying()
                    }
                })

                strongSelf.updateIsPlaying()
            }
        }))

        return ActionDisposable {
            fetchDisposable.dispose()
        }.strict()
    }

    public func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool {
        if let item = cache.getFirstFrameSynchronously(sourceId: itemId, size: size) {
            guard let frame = item.advance(advance: .frames(1), requestedFormat: .rgba) else {
                return false
            }
            switch frame.frame.format {
            case let .rgba(data, width, height, bytesPerRow):
                guard let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow) else {
                    return false
                }
                data.withUnsafeBytes { bytes -> Void in
                    memcpy(context.bytes, bytes.baseAddress!, height * bytesPerRow)
                }
                guard let image = context.generateImage() else {
                    return false
                }
                target.contents = image.cgImage
                target.numFrames = item.numFrames
                return true
            default:
                return false
            }
        }
        return false
    }

    public func loadFirstFrame(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (Bool, Bool) -> Void) -> Disposable {
        return cache.getFirstFrame(queue: .mainQueue(), sourceId: itemId, size: size, fetch: fetch, completion: { [weak target] result in
            guard let item = result.item else {
                Queue.mainQueue().async {
                    completion(false, result.isFinal)
                }
                return
            }

            let loaded: Bool
            if let frame = item.advance(advance: .frames(1), requestedFormat: .rgba) {
                switch frame.frame.format {
                case let .rgba(data, width, height, bytesPerRow):
                    Queue.mainQueue().async {
                        guard let target = target else {
                            completion(false, true)
                            return
                        }
                        target.numFrames = item.numFrames
                        if let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow) {
                            data.withUnsafeBytes { bytes -> Void in
                                memcpy(context.bytes, bytes.baseAddress!, height * bytesPerRow)
                            }
                            if let image = context.generateImage() {
                                target.contents = image.cgImage
                                completion(true, true)
                                return
                            }
                        }
                        completion(false, true)
                    }
                    return
                default:
                    loaded = false
                }
            } else {
                loaded = false
            }

            Queue.mainQueue().async {
                completion(loaded, true)
            }
        }).strict()
    }

    public func loadFirstFrameAsImage(cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (CGImage?) -> Void) -> Disposable {
        return cache.getFirstFrame(queue: .mainQueue(), sourceId: itemId, size: size, fetch: fetch, completion: { result in
            guard let item = result.item else {
                Queue.mainQueue().async {
                    completion(nil)
                }
                return
            }

            if let frame = item.advance(advance: .frames(1), requestedFormat: .rgba) {
                switch frame.frame.format {
                case let .rgba(data, width, height, bytesPerRow):
                    Queue.mainQueue().async {
                        if let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow) {
                            data.withUnsafeBytes { bytes -> Void in
                                memcpy(context.bytes, bytes.baseAddress!, height * bytesPerRow)
                            }
                            completion(context.generateImage()?.cgImage)
                        } else {
                            completion(nil)
                        }
                    }
                    return
                default:
                    break
                }
            }

            Queue.mainQueue().async {
                completion(nil)
            }
        }).strict()
    }

    public func setFrameIndex(itemId: String, size: CGSize, frameIndex: Int, placeholder: UIImage) {
    }

    private func updateIsPlaying() {
        var isPlaying = false
        for (_, group) in self.surfaceGroups {
            if group.hasPlayingSprites {
                isPlaying = true
                break
            }
        }
        self.isPlaying = isPlaying
    }

    private func animationTick(frameInterval: Double) {
        for (_, group) in self.surfaceGroups {
            if group.hasPlayingSprites {
                group.tick(advanceTimestamp: frameInterval)
            }
        }
    }
}
