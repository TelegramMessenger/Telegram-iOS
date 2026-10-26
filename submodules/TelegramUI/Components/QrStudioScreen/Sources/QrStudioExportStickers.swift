import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import AnimationCache
import EmojiTextAttachmentView
import LottieBinding
import LottieSettings
import GZip
import AppBundle

final class QrStudioExportSticker {
    let frames: [CGImage]
    let period: Double

    init(frames: [CGImage], period: Double) {
        self.frames = frames
        self.period = period
    }

    var isAnimated: Bool {
        return self.frames.count > 1 && self.period > 0.0
    }

    func image(phase: Double, at t: Double) -> CGImage? {
        guard !self.frames.isEmpty else {
            return nil
        }
        return self.frames[QrStudioExportMotion.frameIndex(frameCount: self.frames.count, period: self.period, phase: phase, at: t)]
    }
}

func qrStudioDecodeExportPlane(pixelSide: Int) -> QrStudioExportSticker? {
    guard pixelSide > 0, let url = getAppBundle().url(forResource: "PlaneLogoPlain", withExtension: "tgs"), let data = try? Data(contentsOf: url), let unpacked = TGGUnzipData(data, 5 * 1024 * 1024), let instance = makeLottieInstance(data: unpacked, fitzModifier: .none, colorReplacements: nil, cacheKey: "", settings: .noAccountFallback), instance.frameCount > 0 else {
        return nil
    }
    let frameRate = max(1, Int(instance.frameRate))
    let step = QrStudioExportMotion.frameStep(frameDuration: 1.0 / Double(frameRate))
    let size = CGSize(width: CGFloat(pixelSide), height: CGFloat(pixelSide))
    var frames: [CGImage] = []
    var index = 0
    while index < Int(instance.frameCount) {
        guard let context = DrawingContext(size: size, scale: 1.0, opaque: false) else {
            return nil
        }
        context.withContext { c in
            c.clear(CGRect(origin: CGPoint(), size: size))
        }
        instance.renderFrame(with: Int32(index), into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(pixelSide), height: Int32(pixelSide), bytesPerRow: Int32(context.bytesPerRow))
        if let image = context.generateImage()?.cgImage, let tinted = qrStudioTinted(image, color: .white) {
            frames.append(tinted)
        }
        index += step
    }
    guard !frames.isEmpty else {
        return nil
    }
    return QrStudioExportSticker(frames: frames, period: Double(instance.frameCount) / Double(frameRate))
}

func qrStudioExportCGImage(rgba data: Data, width: Int, height: Int, bytesPerRow: Int) -> CGImage? {
    guard width > 0, height > 0, let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow) else {
        return nil
    }
    data.withUnsafeBytes { bytes -> Void in
        if let base = bytes.baseAddress {
            memcpy(context.bytes, base, min(bytes.count, height * bytesPerRow))
        }
    }
    return context.generateImage()?.cgImage
}

private let qrStudioExportDecodeQueue = Queue(name: "org.telegram.QrStudioExportDecode", qos: .userInitiated)

func qrStudioDecodeExportSticker(context: AccountContext, file: TelegramMediaFile, pixelSide: Int, tint: UIColor?, firstFrameOnly: Bool) -> Signal<QrStudioExportSticker?, NoError> {
    let size = CGSize(width: CGFloat(pixelSide), height: CGFloat(pixelSide))
    let customColor: UIColor? = (tint != nil || file.isCustomTemplateEmoji) ? .white : nil
    let fetch = animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: false, customColor: customColor)
    let queue = qrStudioExportDecodeQueue
    let item = context.animationCache.get(sourceId: file.resource.id.stringRepresentation, size: size, fetch: fetch)
    |> filter { $0.isFinal }
    |> take(1)
    |> map { result -> AnimationCacheItem? in
        return result.item
    }
    |> timeout(10.0, queue: queue, alternate: .single(nil))
    return item
    |> deliverOn(queue)
    |> map { item -> QrStudioExportSticker? in
        guard let item, item.numFrames > 0 else {
            return nil
        }
        item.reset()
        let count = firstFrameOnly ? 1 : item.numFrames
        var frames: [CGImage] = []
        var period: Double = 0.0
        var step = 1
        for index in 0 ..< count {
            guard let advance = item.advance(advance: .frames(1), requestedFormat: .rgba) else {
                break
            }
            if index == 0 {
                step = QrStudioExportMotion.frameStep(frameDuration: advance.frame.duration)
            }
            period += advance.frame.duration
            if index % step != 0 {
                continue
            }
            guard case let .rgba(data, width, height, bytesPerRow) = advance.frame.format, var image = qrStudioExportCGImage(rgba: data, width: width, height: height, bytesPerRow: bytesPerRow) else {
                continue
            }
            if let tint, let tinted = qrStudioTinted(image, color: tint) {
                image = tinted
            }
            frames.append(image)
        }
        if frames.isEmpty {
            return nil
        }
        return QrStudioExportSticker(frames: frames, period: frames.count > 1 ? period : 0.0)
    }
}
