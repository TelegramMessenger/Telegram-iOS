import Foundation
import CoreGraphics
import SwiftSignalKit
import LottieBinding
import GZip
import AppBundle
import NewsFeedSupport

/// `news_drop.tgs` as alpha masks at 84 px (the 28 pt box at 3x); the drop picks one by time and colours it with the
/// theme's accent (spec §2.4). The file is the tab bar's `TabNews` motion stretched 13× (its 40 frames over 520 of a
/// 9 s, 60 fps file). The pull drives the pop by the finger, and the original's 34 pop frames gave a slow pull one
/// image per several points of travel, so the icon stepped; the stretched file has a frame for every fraction of a
/// point. Times stay the original's (`NewsRefreshMetrics.popFrames`, `stickerFramesPerSecond`, `loopDuration`): the pop
/// keeps every third stretched frame, the loop's tail, played by the clock, every second real-time frame.
public final class NewsStickerFrames {
    private static let pixelSize = 84
    /// How many frames of the file one frame of the original motion spans.
    private static let stretch = 13
    private static let popStep = 3
    private static let tailFramesPerSecond = 30.0
    private static var shared: NewsStickerFrames?
    private static var pending: [(NewsStickerFrames?) -> Void] = []

    private let popImages: [CGImage]
    private let tailImages: [CGImage]

    private init(popImages: [CGImage], tailImages: [CGImage]) {
        self.popImages = popImages
        self.tailImages = tailImages
    }

    /// Calls back on the main queue; renders at most once per process.
    public static func load(completion: @escaping (NewsStickerFrames?) -> Void) {
        if let shared = self.shared {
            completion(shared)
            return
        }
        self.pending.append(completion)
        guard self.pending.count == 1 else {
            return
        }
        Queue.concurrentDefaultQueue().async {
            let frames = self.render()
            Queue.mainQueue().async {
                self.shared = frames
                let callbacks = self.pending
                self.pending = []
                for callback in callbacks {
                    callback(frames)
                }
            }
        }
    }

    private static func render() -> NewsStickerFrames? {
        guard let path = getAppBundle().path(forResource: "news_drop", ofType: "tgs"), let packed = try? Data(contentsOf: URL(fileURLWithPath: path)), let data = TGGUnzipData(packed, 1024 * 1024), let instance = makeLottieInstance(data: data, fitzModifier: .none, colorReplacements: nil) else {
            return nil
        }
        let size = self.pixelSize
        let bytesPerRow = size * 4
        func render(frame: Int) -> CGImage? {
            let index = min(Int32(frame), max(0, instance.frameCount - 1))
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * size)
            defer {
                buffer.deallocate()
            }
            buffer.initialize(repeating: 0, count: bytesPerRow * size)
            instance.renderFrame(with: index, into: buffer, width: Int32(size), height: Int32(size), bytesPerRow: Int32(bytesPerRow))
            guard let context = CGContext(data: buffer, width: size, height: size, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
                return nil
            }
            return context.makeImage()
        }
        let metrics = NewsRefreshMetrics.self
        var popImages: [CGImage] = []
        var frame = 0
        while frame <= Int(metrics.popFrames) * self.stretch {
            guard let image = render(frame: frame) else {
                return nil
            }
            popImages.append(image)
            frame += self.popStep
        }
        var tailImages: [CGImage] = []
        var time = metrics.popFrames / metrics.stickerFramesPerSecond
        while time < metrics.loopDuration {
            guard let image = render(frame: Int(time * metrics.stickerFramesPerSecond) * self.stretch) else {
                return nil
            }
            tailImages.append(image)
            time += 1.0 / self.tailFramesPerSecond
        }
        return NewsStickerFrames(popImages: popImages, tailImages: tailImages)
    }

    /// The frame `time` seconds into the original motion: one of the pop's while it lasts, then the tail's by real
    /// time (clamped).
    public func image(at time: Double) -> CGImage? {
        let metrics = NewsRefreshMetrics.self
        let popDuration = metrics.popFrames / metrics.stickerFramesPerSecond
        if time < popDuration || self.tailImages.isEmpty {
            guard !self.popImages.isEmpty else {
                return nil
            }
            let index = Int(max(0.0, time) * metrics.stickerFramesPerSecond * Double(NewsStickerFrames.stretch)) / NewsStickerFrames.popStep
            return self.popImages[min(self.popImages.count - 1, index)]
        }
        let index = Int((time - popDuration) * NewsStickerFrames.tailFramesPerSecond)
        return self.tailImages[max(0, min(self.tailImages.count - 1, index))]
    }
}
