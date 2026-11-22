import Foundation
import UIKit
import ImageIO
import SwiftSignalKit
import TelegramCore

private let cameraBatchQueue = Queue(name: "CameraBatchQueue", qos: .userInitiated)

public final class CameraBatch {
    public struct Item {
        public let uniqueId: String
        public let content: Content
        public let thumbnail: UIImage?
    }

    public enum Content {
        case image(path: String, dimensions: PixelDimensions)
        case video(path: String, dimensions: PixelDimensions, duration: Double, mirror: Bool, cover: UIImage?)

        var path: String {
            switch self {
            case let .image(path, _):
                return path
            case let .video(path, _, _, _, _):
                return path
            }
        }
    }

    private var list: CameraBatchList<Item>
    private let listeners = Bag<() -> Void>()

    public init(maxCount: Int, isSingleShot: Bool) {
        self.list = CameraBatchList(maxCount: maxCount, isSingleShot: isSingleShot)
    }

    deinit {
        for entry in self.list.entries {
            CameraBatch.deleteFiles(of: entry.payload)
        }
    }

    public var isSingleShot: Bool {
        return self.list.isSingleShot
    }

    public var items: [Item] {
        return self.list.entries.map { $0.payload }
    }

    public var count: Int {
        return self.list.count
    }

    public var pendingCount: Int {
        return self.list.pendingCount
    }

    public var hasContent: Bool {
        return self.list.hasContent
    }

    public var isClosed: Bool {
        return self.list.isClosed
    }

    public var acceptsCapture: Bool {
        return self.list.acceptsCapture
    }

    public func addListener(_ f: @escaping () -> Void) -> Disposable {
        let index = self.listeners.add(f)
        return ActionDisposable { [weak self] in
            Queue.mainQueue().async {
                self?.listeners.remove(index)
            }
        }
    }

    func beginPending() {
        self.list.beginPending()
    }

    func endPending() {
        self.list.endPending()
    }

    public func close() {
        let items = self.list.close()
        for item in items {
            CameraBatch.deleteFiles(of: item)
        }
        if !items.isEmpty {
            self.notify()
        }
    }

    @discardableResult
    public func append(_ item: Item) -> CameraBatchAppendResult {
        let result = self.list.append(id: item.uniqueId, payload: item)
        if case .refused = result {
            CameraBatch.deleteFiles(of: item)
        } else {
            self.notify()
        }
        return result
    }

    public func remove(id: String) {
        if let item = self.list.remove(id: id) {
            CameraBatch.deleteFiles(of: item)
            self.notify()
        }
    }

    public func detach(id: String) -> Item? {
        guard let item = self.list.remove(id: id) else {
            return nil
        }
        self.notify()
        return item
    }

    public func discardAll() {
        self.close()
    }

    public func detachAll() -> [Item] {
        let items = self.list.removeAll()
        if !items.isEmpty {
            self.notify()
        }
        return items
    }

    private func notify() {
        for f in self.listeners.copyItems() {
            f()
        }
    }

    private static func deleteFiles(of item: Item) {
        CameraBatch.deleteFile(path: item.content.path)
    }

    private static func deleteFile(path: String) {
        cameraBatchQueue.async {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private static func deliverOnMain(item: Item?, path: String?, cancelled: Atomic<Bool>, subscriber: Subscriber<Item?, NoError>) {
        Queue.mainQueue().async {
            if cancelled.with({ $0 }) {
                if let path {
                    CameraBatch.deleteFile(path: path)
                }
                return
            }
            subscriber.putNext(item)
            subscriber.putCompletion()
        }
    }

    private static func makeTemporaryPath(uniqueId: String, fileExtension: String) -> String {
        return NSTemporaryDirectory() + "camera-batch-\(uniqueId).\(fileExtension)"
    }

    static func photoItem(image: UIImage, thumbnailPixelSide: CGFloat) -> Signal<Item?, NoError> {
        return Signal { subscriber in
            let cancelled = Atomic<Bool>(value: false)
            cameraBatchQueue.async {
                if cancelled.with({ $0 }) {
                    return
                }
                let uniqueId = UUID().uuidString
                let path = CameraBatch.makeTemporaryPath(uniqueId: uniqueId, fileExtension: "jpg")
                guard let data = image.jpegData(compressionQuality: 0.93), (try? data.write(to: URL(fileURLWithPath: path), options: .atomic)) != nil else {
                    CameraBatch.deliverOnMain(item: nil, path: nil, cancelled: cancelled, subscriber: subscriber)
                    return
                }
                let dimensions = PixelDimensions(width: Int32(round(image.size.width * image.scale)), height: Int32(round(image.size.height * image.scale)))
                let thumbnail = CameraBatch.fileThumbnail(path: path, pixelSide: thumbnailPixelSide)
                CameraBatch.deliverOnMain(item: Item(uniqueId: uniqueId, content: .image(path: path, dimensions: dimensions), thumbnail: thumbnail), path: path, cancelled: cancelled, subscriber: subscriber)
            }
            return ActionDisposable {
                let _ = cancelled.swap(true)
            }
        }
    }

    static func videoItem(path: String, dimensions: PixelDimensions, duration: Double, mirror: Bool, cover: UIImage?, thumbnailPixelSide: CGFloat) -> Signal<Item?, NoError> {
        return Signal { subscriber in
            let cancelled = Atomic<Bool>(value: false)
            cameraBatchQueue.async {
                if cancelled.with({ $0 }) {
                    CameraBatch.deleteFile(path: path)
                    return
                }
                let thumbnail = cover.flatMap { CameraBatch.scaledThumbnail(image: $0, pixelSide: thumbnailPixelSide) }
                CameraBatch.deliverOnMain(item: Item(uniqueId: UUID().uuidString, content: .video(path: path, dimensions: dimensions, duration: duration, mirror: mirror, cover: thumbnail), thumbnail: thumbnail), path: path, cancelled: cancelled, subscriber: subscriber)
            }
            return ActionDisposable {
                let _ = cancelled.swap(true)
            }
        }
    }

    private static func fileThumbnail(path: String, pixelSide: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(pixelSide)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func scaledThumbnail(image: UIImage, pixelSide: CGFloat) -> UIImage? {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard pixelSize.width > 0.0, pixelSize.height > 0.0 else {
            return nil
        }
        let ratio = min(1.0, pixelSide / max(pixelSize.width, pixelSize.height))
        let targetSize = CGSize(width: max(1.0, floor(pixelSize.width * ratio)), height: max(1.0, floor(pixelSize.height * ratio)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
