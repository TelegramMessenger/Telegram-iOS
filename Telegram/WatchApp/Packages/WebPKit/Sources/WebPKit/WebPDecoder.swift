import CoreGraphics
import Foundation
import WebPCore

/// Decodes WebP image data via the vendored libwebp. Returns a `CGImage` in RGBA8888.
/// Caller does not need to manage the libwebp allocation — we copy into a `Data`
/// retained by the `CGDataProvider`.
public enum WebPDecoder {
    public static func decode(data: Data) -> CGImage? {
        guard !data.isEmpty else { return nil }
        var outPtr: UnsafeMutablePointer<UInt8>? = nil
        var width: Int32 = 0
        var height: Int32 = 0
        let ok = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int32 in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return webp_kit_decode_rgba(base, raw.count, &outPtr, &width, &height)
        }
        guard ok == 1, let outPtr, width > 0, height > 0 else { return nil }
        defer { webp_kit_free(outPtr) }

        let pixelCount = Int(width) * Int(height) * 4
        let buffer = Data(bytes: outPtr, count: pixelCount)
        guard let provider = CGDataProvider(data: buffer as CFData) else { return nil }

        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.last.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue)
        return CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    public static func decode(url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data: data)
    }
}
