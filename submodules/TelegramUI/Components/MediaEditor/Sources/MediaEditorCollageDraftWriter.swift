import Foundation
import UIKit
import Photos
import ImageIO
import SwiftSignalKit
import TelegramCore
import Postbox

public enum MediaEditorCollageDraftSaveError: Error, Equatable {
    case cancelled
    case mediaUnavailable
    case storage
}

public final class MediaEditorCollageDraftSaveOperation {
    private enum State {
        case preparing
        case committing
        case finished
        case cancelled
    }

    private let queue = Queue()
    private let lock = NSLock()
    private var state: State = .preparing
    private var imageRequestId: PHImageRequestID?
    private let collage: MediaEditorCollage
    private let preview: UIImage
    private let baseImagePath: String?
    private let makeDraft: (String, MediaEditorCollageDraft, String?, String?) -> MediaEditorDraft
    private let additionalVideoPath: String?
    private let audioPath: String?
    private let store: (MediaEditorDraft) -> Signal<Never, NoError>
    private let completion: (Result<MediaEditorDraft, MediaEditorCollageDraftSaveError>) -> Void
    private let directory: String
    private let stagingPath: String
    private let finalPath: String
    private var stagingLease: MediaEditorDraftFileLease?
    private var finalLease: MediaEditorDraftFileLease?
    private var importedItems: [MediaEditorCollageDraft.Item] = []
    private var storeDisposable: Disposable?

    public init(engine: TelegramEngine, collage: MediaEditorCollage, preview: UIImage, baseImagePath: String?, additionalVideoPath: String?, audioPath: String?, makeDraft: @escaping (String, MediaEditorCollageDraft, String?, String?) -> MediaEditorDraft, store: @escaping (MediaEditorDraft) -> Signal<Never, NoError>, completion: @escaping (Result<MediaEditorDraft, MediaEditorCollageDraftSaveError>) -> Void) {
        self.collage = collage
        self.preview = preview
        self.baseImagePath = baseImagePath
        self.makeDraft = makeDraft
        self.additionalVideoPath = additionalVideoPath
        self.audioPath = audioPath.map { fullDraftPath(peerId: engine.account.peerId, path: $0) }
        self.store = store
        self.completion = completion
        let id = UUID().uuidString
        self.directory = "collages/\(id)"
        self.stagingPath = fullDraftPath(peerId: engine.account.peerId, path: "collages/.pending-\(id)")
        self.finalPath = fullDraftPath(peerId: engine.account.peerId, path: self.directory)
        self.stagingLease = MediaEditorDraftFileLease(path: self.stagingPath)
        self.finalLease = MediaEditorDraftFileLease(path: self.finalPath)
        self.queue.async {
            do {
                try FileManager.default.createDirectory(atPath: self.stagingPath, withIntermediateDirectories: true)
                self.importNext()
            } catch {
                self.finish(.failure(.storage))
            }
        }
    }

    @discardableResult public func cancel() -> Bool {
        self.lock.lock()
        guard self.state == .preparing else {
            self.lock.unlock()
            return false
        }
        self.state = .cancelled
        let requestId = self.imageRequestId
        self.lock.unlock()
        if let requestId {
            PHImageManager.default().cancelImageRequest(requestId)
        }
        self.queue.async {
            self.finish(.failure(.cancelled))
        }
        return true
    }

    private var isPreparing: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.state == .preparing
    }

    private func importNext() {
        guard self.isPreparing else {
            return
        }
        guard self.importedItems.count < self.collage.items.count else {
            self.commit()
            return
        }
        let item = self.collage.items[self.importedItems.count]
        switch item.source {
        case let .image(image, assetIdentifier):
            if let assetIdentifier {
                let fetchOptions = PHFetchOptions()
                fetchOptions.includeHiddenAssets = true
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: fetchOptions).firstObject else {
                    self.finish(.failure(.mediaUnavailable))
                    return
                }
                let options = PHImageRequestOptions()
                options.version = .current
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                let received: (Data?) -> Void = { data in
                    self.queue.async {
                        guard self.isPreparing else {
                            return
                        }
                        guard let data, UIImage(data: data) != nil else {
                            self.finish(.failure(.mediaUnavailable))
                            return
                        }
                        self.writeImage(data, item: item)
                    }
                }
                let requestId: PHImageRequestID
                if #available(iOS 13.0, *) {
                    requestId = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                        guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else {
                            return
                        }
                        received(data)
                    }
                } else {
                    requestId = PHImageManager.default().requestImageData(for: asset, options: options) { data, _, _, info in
                        guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else {
                            return
                        }
                        received(data)
                    }
                }
                self.lock.lock()
                self.imageRequestId = requestId
                let wasCancelled = self.state == .cancelled
                self.lock.unlock()
                if wasCancelled {
                    PHImageManager.default().cancelImageRequest(requestId)
                }
            } else if let data = image.pngData() {
                self.writeImage(data, item: item)
            } else {
                self.finish(.failure(.storage))
            }
        case let .imageFile(path):
            self.copyFile(path, name: "photo-\(item.id).image", kind: .image, item: item)
        case let .videoFile(path):
            let pathExtension = URL(fileURLWithPath: path).pathExtension
            self.copyFile(path, name: "video-\(item.id).\(pathExtension.isEmpty ? "mp4" : pathExtension)", kind: .videoFile, item: item)
        case let .videoAsset(asset):
            let fetchOptions = PHFetchOptions()
            fetchOptions.includeHiddenAssets = true
            guard PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: fetchOptions).firstObject != nil else {
                self.finish(.failure(.mediaUnavailable))
                return
            }
            self.importedItems.append(MediaEditorCollageDraft.Item(item: item, kind: .videoAsset, resource: asset.localIdentifier))
            self.importNext()
        }
    }

    private func writeImage(_ data: Data, item: MediaEditorCollage.Item) {
        let name = "photo-\(item.id).image"
        do {
            try data.write(to: URL(fileURLWithPath: self.stagingPath + "/" + name), options: .atomic)
            if self.collage.isVideo {
                try self.writeRenderImage(name: name, item: item)
            }
            self.importedItems.append(MediaEditorCollageDraft.Item(item: item, kind: .image, resource: name, dimensions: self.imageDimensions(name: name)))
            self.importNext()
        } catch {
            self.finish(.failure(.storage))
        }
    }

    private func copyFile(_ path: String, name: String, kind: MediaEditorCollageDraft.Item.Kind, item: MediaEditorCollage.Item) {
        do {
            try FileManager.default.copyItem(atPath: path, toPath: self.stagingPath + "/" + name)
            if kind == .image, self.collage.isVideo {
                let renderName = "render-\(item.id).jpg"
                let renderPath = URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(renderName).path
                if FileManager.default.fileExists(atPath: renderPath) {
                    try FileManager.default.copyItem(atPath: renderPath, toPath: self.stagingPath + "/" + renderName)
                } else {
                    try self.writeRenderImage(name: name, item: item)
                }
            }
            self.importedItems.append(MediaEditorCollageDraft.Item(item: item, kind: kind, resource: name, dimensions: kind == .image ? self.imageDimensions(name: name) : nil))
            self.importNext()
        } catch {
            self.finish(.failure(FileManager.default.fileExists(atPath: path) ? .storage : .mediaUnavailable))
        }
    }

    private func writeRenderImage(name: String, item: MediaEditorCollage.Item) throws {
        guard let image = mediaEditorCollageImage(path: self.stagingPath + "/" + name), let data = image.jpegData(compressionQuality: 0.95) else {
            throw MediaEditorCollageDraftSaveError.storage
        }
        try data.write(to: URL(fileURLWithPath: self.stagingPath + "/render-\(item.id).jpg"), options: .atomic)
    }

    private func imageDimensions(name: String) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: self.stagingPath + "/" + name) as CFURL, nil), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any], let width = properties[kCGImagePropertyPixelWidth] as? NSNumber, let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if (5 ... 8).contains(orientation) {
            return CGSize(width: CGFloat(height.doubleValue), height: CGFloat(width.doubleValue))
        }
        return CGSize(width: CGFloat(width.doubleValue), height: CGFloat(height.doubleValue))
    }

    private func commit() {
        do {
            guard let data = self.preview.jpegData(compressionQuality: 0.87) else {
                self.finish(.failure(.storage))
                return
            }
            try data.write(to: URL(fileURLWithPath: self.stagingPath + "/preview.jpg"), options: .atomic)
            let baseName: String
            if !self.collage.isVideo {
                baseName = "base.jpg"
                if let baseImagePath = self.baseImagePath, FileManager.default.fileExists(atPath: baseImagePath) {
                    try FileManager.default.copyItem(atPath: baseImagePath, toPath: self.stagingPath + "/" + baseName)
                } else {
                    let items = zip(self.collage.items, self.importedItems).map { item, saved in
                        item.withSource(.imageFile(self.stagingPath + "/" + saved.resource))
                    }
                    guard let image = MediaEditorCollage(rows: self.collage.rows, items: items).image(), let data = image.jpegData(compressionQuality: 0.95) else {
                        self.finish(.failure(.storage))
                        return
                    }
                    try data.write(to: URL(fileURLWithPath: self.stagingPath + "/" + baseName), options: .atomic)
                }
            } else {
                baseName = "preview.jpg"
            }
            let collage = MediaEditorCollageDraft(directory: self.directory, collage: self.collage, items: self.importedItems)
            let additionalVideoPath = try self.copyAuxiliaryFile(self.additionalVideoPath, name: "additional-video")
            let audioPath = try self.copyAuxiliaryFile(self.audioPath, name: "audio")
            let draft = self.makeDraft(self.directory + "/" + baseName, collage, additionalVideoPath, audioPath)
            // Validate with the same codec used by the draft list and story source cache.
            let metadata = try AdaptedPostboxEncoder().encode(draft)
            _ = try AdaptedPostboxDecoder().decode(MediaEditorDraft.self, from: metadata)
            self.lock.lock()
            guard self.state == .preparing else {
                self.lock.unlock()
                return
            }
            self.state = .committing
            self.lock.unlock()
            try FileManager.default.moveItem(atPath: self.stagingPath, toPath: self.finalPath)
            self.storeDisposable = self.store(draft).start(completed: {
                self.queue.async {
                    self.finish(.success(draft))
                }
            })
        } catch {
            self.finish(.failure(.storage))
        }
    }

    private func copyAuxiliaryFile(_ path: String?, name: String) throws -> String? {
        guard let path else {
            return nil
        }
        let pathExtension = URL(fileURLWithPath: path).pathExtension
        let name = name + (pathExtension.isEmpty ? "" : "." + pathExtension)
        try FileManager.default.copyItem(atPath: path, toPath: self.stagingPath + "/" + name)
        return self.directory + "/" + name
    }

    private func finish(_ result: Result<MediaEditorDraft, MediaEditorCollageDraftSaveError>) {
        self.lock.lock()
        guard self.state != .finished else {
            self.lock.unlock()
            return
        }
        let result: Result<MediaEditorDraft, MediaEditorCollageDraftSaveError> = self.state == .cancelled ? .failure(.cancelled) : result
        self.state = .finished
        self.lock.unlock()
        self.storeDisposable = nil
        if case .failure = result {
            MediaEditorDraftFileLease.delete(path: self.stagingPath)
            MediaEditorDraftFileLease.delete(path: self.finalPath)
        }
        self.stagingLease = nil
        self.finalLease = nil
        Queue.mainQueue().async {
            self.completion(result)
        }
    }
}
