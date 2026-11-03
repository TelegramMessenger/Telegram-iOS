import Foundation
import CoreGraphics
import SwiftSignalKit
import LottieBinding
import LottieSettings
import GZip
import AppBundle

/// `news_drop.tgs` as alpha masks: every second frame of the 60 fps file (90 at 30 fps), at 84 px (the 28 pt box at
/// 3x). The drop picks one by time and colours it with the theme's accent (spec §2.4).
public final class NewsStickerFrames {
    private static let pixelSize = 84
    private static var shared: NewsStickerFrames?
    private static var pending: [(NewsStickerFrames?) -> Void] = []

    private let images: [CGImage]

    private init(images: [CGImage]) {
        self.images = images
    }

    /// Calls back on the main queue; renders at most once per process.
    public static func load(settings: LottieRenderingSettings, completion: @escaping (NewsStickerFrames?) -> Void) {
        if let shared = self.shared {
            completion(shared)
            return
        }
        self.pending.append(completion)
        guard self.pending.count == 1 else {
            return
        }
        Queue.concurrentDefaultQueue().async {
            let frames = self.render(settings: settings)
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

    private static func render(settings: LottieRenderingSettings) -> NewsStickerFrames? {
        guard let path = getAppBundle().path(forResource: "news_drop", ofType: "tgs"), let packed = try? Data(contentsOf: URL(fileURLWithPath: path)), let data = TGGUnzipData(packed, 1024 * 1024), let instance = makeLottieInstance(data: data, fitzModifier: .none, colorReplacements: nil, cacheKey: "news_drop", settings: settings) else {
            return nil
        }
        let size = self.pixelSize
        let bytesPerRow = size * 4
        var images: [CGImage] = []
        for i in 0 ..< 90 {
            let index = min(Int32(i * 2), max(0, instance.frameCount - 1))
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * size)
            buffer.initialize(repeating: 0, count: bytesPerRow * size)
            instance.renderFrame(with: index, into: buffer, width: Int32(size), height: Int32(size), bytesPerRow: Int32(bytesPerRow))
            guard let context = CGContext(data: buffer, width: size, height: size, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), let image = context.makeImage() else {
                buffer.deallocate()
                return nil
            }
            buffer.deallocate()
            images.append(image)
        }
        return NewsStickerFrames(images: images)
    }

    /// The frame `time` seconds into the file (`Int(time · 30)`, clamped).
    public func image(at time: Double) -> CGImage? {
        guard !self.images.isEmpty else {
            return nil
        }
        return self.images[max(0, min(self.images.count - 1, Int(time * 30.0)))]
    }
}
