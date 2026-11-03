import Foundation
import UIKit
import AppBundle
import GZip
import LottieBinding
import LottieSettings

struct RoundVideoDecorationAnimation {
    static let frameWidth = 68
    static let frameHeight = 68
    static let frameCount = 27
    static let columns = 9
    static let rows = 3
    static let width = frameWidth * columns
    static let height = frameHeight * rows
    static let bytesPerRow = width * 4
    static let byteCount = bytesPerRow * height

    let data: Data
}

struct RoundVideoDecorationImage {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let data: Data
}

struct RoundVideoDecorationResources {
    let atlas: RoundVideoDecorationAnimation
    let watermark: RoundVideoDecorationImage
}

final class RoundVideoDecorationProvider {
    static let shared = RoundVideoDecorationProvider()
    private static let isEnabled = false

    private typealias Completion = (RoundVideoDecorationResources?) -> Void

    private enum State {
        case idle
        case preparing([Completion])
        case ready(RoundVideoDecorationResources?)
    }

    private let queue = DispatchQueue(label: "Camera.RoundVideoDecoration", qos: .utility)
    private var state: State = .idle

    private init() {
    }

    func warmUp() {
        self.prepare { _ in }
    }

    func prepare(completion: @escaping (RoundVideoDecorationResources?) -> Void) {
        self.queue.async {
            guard Self.isEnabled else {
                completion(nil)
                return
            }
            switch self.state {
            case .idle:
                self.state = .preparing([completion])
                let resources = Self.makeResources()
                guard case let .preparing(completions) = self.state else {
                    return
                }
                self.state = .ready(resources)
                for completion in completions {
                    completion(resources)
                }
            case let .preparing(completions):
                self.state = .preparing(completions + [completion])
            case let .ready(resources):
                completion(resources)
            }
        }
    }

    private static func makeResources() -> RoundVideoDecorationResources? {
        guard let atlas = Self.loadOrGenerateAtlas(), let watermark = Self.loadWatermark() else {
            return nil
        }
        return RoundVideoDecorationResources(atlas: atlas, watermark: watermark)
    }

    private static func loadOrGenerateAtlas() -> RoundVideoDecorationAnimation? {
        let cacheUrl = Self.atlasCacheUrl()
        if let cacheUrl, let data = try? Data(contentsOf: cacheUrl, options: [.mappedIfSafe]) {
            if data.count == RoundVideoDecorationAnimation.byteCount {
                return RoundVideoDecorationAnimation(data: data)
            } else {
                try? FileManager.default.removeItem(at: cacheUrl)
            }
        }

        guard let path = getAppBundle().path(forResource: "PlaneLogoPlain", ofType: "tgs") else {
            return nil
        }
        // RoundVideoDecorationProvider is a process-wide singleton warmed at camera
        // startup; no account exists anywhere in its construction.
        guard let compressedData = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let data = TGGUnzipData(compressedData, 5 * 1024 * 1024),
              let animation = makeLottieInstance(data: data, fitzModifier: .none, colorReplacements: [:], cacheKey: "", settings: .noAccountFallback) else {
            return nil
        }
        guard animation.frameCount >= Int32((RoundVideoDecorationAnimation.frameCount - 1) * 2 + 1) else {
            return nil
        }

        var atlasData = Data(count: RoundVideoDecorationAnimation.byteCount)
        let frameBytesPerRow = RoundVideoDecorationAnimation.frameWidth * 4
        var frameData = Data(count: frameBytesPerRow * RoundVideoDecorationAnimation.frameHeight)
        var rendered = true
        for index in 0 ..< RoundVideoDecorationAnimation.frameCount {
            let frameRendered = frameData.withUnsafeMutableBytes { bytes -> Bool in
                guard let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return false
                }
                animation.renderFrame(
                    with: Int32(index * 2),
                    into: baseAddress,
                    width: Int32(RoundVideoDecorationAnimation.frameWidth),
                    height: Int32(RoundVideoDecorationAnimation.frameHeight),
                    bytesPerRow: Int32(frameBytesPerRow)
                )
                return true
            }
            guard frameRendered else {
                rendered = false
                break
            }

            let copied = atlasData.withUnsafeMutableBytes { atlasBytes -> Bool in
                guard let atlasBaseAddress = atlasBytes.baseAddress else {
                    return false
                }
                return frameData.withUnsafeBytes { frameBytes -> Bool in
                    guard let frameBaseAddress = frameBytes.baseAddress else {
                        return false
                    }
                    let column = index % RoundVideoDecorationAnimation.columns
                    let row = index / RoundVideoDecorationAnimation.columns
                    for frameRow in 0 ..< RoundVideoDecorationAnimation.frameHeight {
                        let destinationOffset = (row * RoundVideoDecorationAnimation.frameHeight + frameRow)
                            * RoundVideoDecorationAnimation.bytesPerRow
                            + column * frameBytesPerRow
                        atlasBaseAddress.advanced(by: destinationOffset).copyMemory(
                            from: frameBaseAddress.advanced(by: frameRow * frameBytesPerRow),
                            byteCount: frameBytesPerRow
                        )
                    }
                    return true
                }
            }
            guard copied else {
                rendered = false
                break
            }
        }
        guard rendered else {
            return nil
        }

        if let cacheUrl {
            try? FileManager.default.createDirectory(
                at: cacheUrl.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? atlasData.write(to: cacheUrl, options: [.atomic])
        }
        return RoundVideoDecorationAnimation(data: atlasData)
    }

    private static func atlasCacheUrl() -> URL? {
        guard let cachesUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesUrl
            .appendingPathComponent("Camera", isDirectory: true)
            .appendingPathComponent("PlaneLogoPlain.bgra", isDirectory: false)
    }

    private static func loadWatermark() -> RoundVideoDecorationImage? {
        guard let image = UIImage(bundleImageName: "Components/RoundVideoCorner"), let cgImage = image.cgImage else {
            return nil
        }

        let width = 100
        let height = 100
        let bytesPerRow = width * 4
        var data = Data(count: bytesPerRow * height)
        let rendered = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                  ) else {
                return false
            }
            context.clear(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
            context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
            return true
        }
        guard rendered else {
            return nil
        }
        return RoundVideoDecorationImage(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
    }
}
