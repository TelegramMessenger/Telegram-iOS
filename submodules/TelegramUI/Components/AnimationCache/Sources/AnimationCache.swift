import Foundation
import UIKit
import SwiftSignalKit

public final class AnimationCacheItemFrame {
    public enum RequestedFormat {
        case rgba
        case yuva(rowAlignment: Int)
    }

    public final class Plane {
        public let data: Data
        public let width: Int
        public let height: Int
        public let bytesPerRow: Int

        public init(data: Data, width: Int, height: Int, bytesPerRow: Int) {
            self.data = data
            self.width = width
            self.height = height
            self.bytesPerRow = bytesPerRow
        }
    }

    public enum Format {
        case rgba(data: Data, width: Int, height: Int, bytesPerRow: Int)
        case yuva(y: Plane, u: Plane, v: Plane, a: Plane)
    }

    public let format: Format
    public let duration: Double

    public init(format: Format, duration: Double) {
        self.format = format
        self.duration = duration
    }
}

public final class AnimationCacheItem {
    public enum Advance {
        case duration(Double)
        case frames(Int)
    }

    public struct AdvanceResult {
        public let frame: AnimationCacheItemFrame
        public let didLoop: Bool

        public init(frame: AnimationCacheItemFrame, didLoop: Bool) {
            self.frame = frame
            self.didLoop = didLoop
        }
    }

    public let numFrames: Int
    private let advanceImpl: (Advance, AnimationCacheItemFrame.RequestedFormat) -> AdvanceResult?
    private let resetImpl: () -> Void

    public init(numFrames: Int, advanceImpl: @escaping (Advance, AnimationCacheItemFrame.RequestedFormat) -> AdvanceResult?, resetImpl: @escaping () -> Void) {
        self.numFrames = numFrames
        self.advanceImpl = advanceImpl
        self.resetImpl = resetImpl
    }

    public func advance(advance: Advance, requestedFormat: AnimationCacheItemFrame.RequestedFormat) -> AdvanceResult? {
        return self.advanceImpl(advance, requestedFormat)
    }

    public func reset() {
        self.resetImpl()
    }
}

public struct AnimationCacheItemDrawingSurface {
    public let argb: UnsafeMutablePointer<UInt8>
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let length: Int

    public init(
        argb: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        length: Int
    ) {
        self.argb = argb
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.length = length
    }
}

public protocol AnimationCacheItemWriter: AnyObject {
    var queue: Queue { get }
    var isCancelled: Bool { get }

    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int, insertKeyframe: Bool)
    func finish()
}

public final class AnimationCacheItemResult {
    public let item: AnimationCacheItem?
    public let isFinal: Bool

    public init(item: AnimationCacheItem?, isFinal: Bool) {
        self.item = item
        self.isFinal = isFinal
    }
}

public struct AnimationCacheFetchOptions {
    public let size: CGSize
    public let writer: AnimationCacheItemWriter
    public let firstFrameOnly: Bool

    public init(
        size: CGSize,
        writer: AnimationCacheItemWriter,
        firstFrameOnly: Bool
    ) {
        self.size = size
        self.writer = writer
        self.firstFrameOnly = firstFrameOnly
    }
}

public protocol AnimationCache: AnyObject {
    func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Signal<AnimationCacheItemResult, NoError>
    func getFirstFrameSynchronously(sourceId: String, size: CGSize) -> AnimationCacheItem?
    func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable
}
