import CoreGraphics
import Foundation
import RLottieCore

/// Swift facade for `LottieInstance` plus a CGImage renderer. Owns the per-animation
/// memory; release the instance and the backing rlottie buffers come with it.
public final class LottieAnimation {
    private let instance: LottieInstance

    public var dimensions: CGSize { instance.dimensions }
    public var frameCount: Int { Int(instance.frameCount) }
    public var frameRate: Int { Int(instance.frameRate) }
    public var duration: TimeInterval { Double(frameCount) / Double(max(1, frameRate)) }

    public init?(tgsFileURL url: URL) {
        guard let gzipped = try? Data(contentsOf: url),
              let json = try? decompressTgs(gzipped),
              let inst = LottieInstance(data: json, cacheKey: url.lastPathComponent) else {
            return nil
        }
        self.instance = inst
    }

    /// Renders frame `index` into a fresh CGImage sized `size × scale`. Returns nil if
    /// allocation fails. Caller is responsible for using the image promptly — backing
    /// pixels are owned by an internal `Data` retained by the CGDataProvider.
    public func renderFrame(index: Int, size: CGSize, scale: CGFloat) -> CGImage? {
        let pixelWidth = max(1, Int(size.width * scale))
        let pixelHeight = max(1, Int(size.height * scale))
        let bytesPerRow = pixelWidth * 4
        let bufferSize = bytesPerRow * pixelHeight

        var buffer = [UInt8](repeating: 0, count: bufferSize)
        buffer.withUnsafeMutableBufferPointer { ptr in
            instance.renderFrame(
                with: Int32(index),
                into: ptr.baseAddress!,
                width: Int32(pixelWidth),
                height: Int32(pixelHeight),
                bytesPerRow: Int32(bytesPerRow)
            )
        }

        let data = Data(buffer)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        // rlottie writes BGRA-premultiplied; CGBitmapInfo.byteOrder32Little + premultipliedFirst
        // lets CoreGraphics consume it without a swizzle pass.
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedFirst.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
