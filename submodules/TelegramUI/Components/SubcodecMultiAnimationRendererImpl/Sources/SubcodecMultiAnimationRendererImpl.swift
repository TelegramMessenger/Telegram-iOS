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
        let sink: (NSData) -> Void = { [weak self] data in
            self?.accumulatedNalData.append(data as Data)
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
            guard let _ = try? surface.advanceFrame(withSink: { [weak self] data in
                self?.accumulatedNalData.append(data as Data)
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
                self?.accumulatedNalData.append(data as Data)
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
        guard let _ = try? surface.emitFrameIfNeeded(withSink: { [weak self] data in
            self?.accumulatedNalData.append(data as Data)
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
