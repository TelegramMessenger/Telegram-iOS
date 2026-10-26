import Foundation
import UIKit
import Photos
import AVFoundation
import SwiftSignalKit
import TelegramCore
import LegacyComponents

public struct ChatMediaSendConvertedGif: Equatable {
    public var path: String
    public var dimensions: PixelDimensions
    public var duration: Double

    public init(path: String, dimensions: PixelDimensions, duration: Double) {
        self.path = path
        self.dimensions = dimensions
        self.duration = duration
    }
}

public protocol ChatMediaSendGifConverting {
    func convertGif(identifier: String) -> Signal<ChatMediaSendConvertedGif?, NoError>
}

public let chatMediaSendGifUniformTypeIdentifier = "com.compuserve.gif"

public func chatMediaSendAssetIsGif(_ asset: PHAsset) -> Bool {
    return asset.value(forKey: "uniformTypeIdentifier") as? String == chatMediaSendGifUniformTypeIdentifier
}

func chatMediaSendDataIsGif(_ data: Data) -> Bool {
    guard data.count >= 5 else {
        return false
    }
    let header = data.prefix(5)
    return header == Data("GIF87".utf8) || header == Data("GIF89".utf8)
}

public func chatMediaSendConvertedGifPath(identifier: String) -> String {
    let provider: LegacyComponentsGlobalsProvider? = LegacyComponentsGlobals.provider()
    let basePath = provider?.dataStoragePath() ?? NSTemporaryDirectory()
    let directory = (basePath as NSString).appendingPathComponent("convertedGifs")
    let _ = try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    let name = TGStringUtils.md5(identifier) ?? "\(identifier.hashValue)"
    return (directory as NSString).appendingPathComponent("\(name).mp4")
}

public func chatMediaSendConvertedGifFromFile(path: String) -> ChatMediaSendConvertedGif? {
    guard FileManager.default.fileExists(atPath: path) else {
        return nil
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
        return nil
    }
    let size = track.naturalSize.applying(track.preferredTransform)
    let width = Int32(abs(size.width).rounded())
    let height = Int32(abs(size.height).rounded())
    let duration = asset.duration.seconds
    guard width > 0, height > 0, duration.isFinite, duration > 0.0 else {
        return nil
    }
    return ChatMediaSendConvertedGif(path: path, dimensions: PixelDimensions(width: width, height: height), duration: duration)
}

func chatMediaSendMoveConvertedGif(from path: String, to outputPath: String) -> Bool {
    let fileManager = FileManager.default
    let _ = try? fileManager.removeItem(atPath: outputPath)
    do {
        try fileManager.moveItem(atPath: path, toPath: outputPath)
        return true
    } catch {
        let _ = try? fileManager.removeItem(atPath: path)
        return false
    }
}

public func chatMediaSendConvertGifData(_ data: Data, outputPath: String) -> Signal<ChatMediaSendConvertedGif?, NoError> {
    guard chatMediaSendDataIsGif(data) else {
        return .single(nil)
    }
    return Signal { subscriber in
        let delivered = Atomic<Bool>(value: false)
        let deliver: (ChatMediaSendConvertedGif?) -> Void = { result in
            if !delivered.swap(true) {
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
        }
        let disposable = TGGifConverter.convertGif(toMp4: data).start(next: { next in
            guard let result = next as? NSDictionary, let path = result["path"] as? String else {
                deliver(nil)
                return
            }
            if path != outputPath {
                guard chatMediaSendMoveConvertedGif(from: path, to: outputPath) else {
                    deliver(nil)
                    return
                }
            }
            var dimensions: PixelDimensions?
            if let value = result["dimensions"] as? NSValue {
                let size = value.cgSizeValue
                let width = Int32(size.width.rounded())
                let height = Int32(size.height.rounded())
                if width > 0, height > 0 {
                    dimensions = PixelDimensions(width: width, height: height)
                }
            }
            let duration = (result["duration"] as? NSNumber)?.doubleValue ?? 0.0
            if let dimensions, duration.isFinite, duration > 0.0 {
                deliver(ChatMediaSendConvertedGif(path: outputPath, dimensions: dimensions, duration: duration))
            } else {
                deliver(chatMediaSendConvertedGifFromFile(path: outputPath))
            }
        }, error: { _ in
            deliver(nil)
        }, completed: {
            deliver(nil)
        })
        return ActionDisposable {
            disposable?.dispose()
        }
    }
}

private func chatMediaSendAssetImageData(identifier: String) -> Signal<Data?, NoError> {
    return Signal { subscriber in
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        let requestId = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options, resultHandler: { data, _, _, _ in
            subscriber.putNext(data)
            subscriber.putCompletion()
        })
        return ActionDisposable {
            PHImageManager.default().cancelImageRequest(requestId)
        }
    }
}

public final class ChatMediaSendGifConverter: ChatMediaSendGifConverting {
    public static let shared = ChatMediaSendGifConverter()

    private let results = Atomic<[String: ChatMediaSendConvertedGif]>(value: [:])
    private let pending = Atomic<[String: Promise<ChatMediaSendConvertedGif?>]>(value: [:])
    private let conversion: (String) -> Signal<ChatMediaSendConvertedGif?, NoError>

    public convenience init() {
        self.init(conversion: chatMediaSendDefaultGifConversion)
    }

    init(conversion: @escaping (String) -> Signal<ChatMediaSendConvertedGif?, NoError>) {
        self.conversion = conversion
    }

    public func cachedGif(identifier: String) -> ChatMediaSendConvertedGif? {
        if let result = self.results.with({ $0[identifier] }) {
            if FileManager.default.fileExists(atPath: result.path) {
                return result
            }
            let _ = self.results.modify { current in
                var current = current
                current.removeValue(forKey: identifier)
                return current
            }
        }
        return nil
    }

    public func convertGif(identifier: String) -> Signal<ChatMediaSendConvertedGif?, NoError> {
        if let cached = self.cachedGif(identifier: identifier) {
            return .single(cached)
        }
        var created: Promise<ChatMediaSendConvertedGif?>?
        let promise = self.pending.modify { current -> [String: Promise<ChatMediaSendConvertedGif?>] in
            if current[identifier] != nil {
                return current
            }
            var current = current
            let promise = Promise<ChatMediaSendConvertedGif?>()
            created = promise
            current[identifier] = promise
            return current
        }[identifier]!
        if let created {
            let results = self.results
            let pending = self.pending
            let conversion: Signal<ChatMediaSendConvertedGif?, NoError> = (self.conversion(identifier)
            |> then(.single(nil))
            |> take(1))
            |> runOn(Queue.concurrentDefaultQueue())
            |> map { result -> ChatMediaSendConvertedGif? in
                if let result {
                    let _ = results.modify { current in
                        var current = current
                        current[identifier] = result
                        return current
                    }
                }
                let _ = pending.modify { current in
                    var current = current
                    current.removeValue(forKey: identifier)
                    return current
                }
                return result
            }
            created.set(conversion)
        }
        return promise.get()
        |> take(1)
    }
}

private func chatMediaSendDefaultGifConversion(identifier: String) -> Signal<ChatMediaSendConvertedGif?, NoError> {
    let outputPath = chatMediaSendConvertedGifPath(identifier: identifier)
    return Signal<ChatMediaSendConvertedGif?, NoError> { subscriber in
        if let existing = chatMediaSendConvertedGifFromFile(path: outputPath) {
            subscriber.putNext(existing)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        return (chatMediaSendAssetImageData(identifier: identifier)
        |> chatMediaSendDeliverOnBackground
        |> mapToSignal { data -> Signal<ChatMediaSendConvertedGif?, NoError> in
            guard let data else {
                return .single(nil)
            }
            return chatMediaSendConvertGifData(data, outputPath: outputPath)
        }).start(next: { value in
            subscriber.putNext(value)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}
