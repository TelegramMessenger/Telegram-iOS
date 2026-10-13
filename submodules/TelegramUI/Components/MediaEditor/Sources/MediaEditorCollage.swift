import Foundation
import UIKit
import AVFoundation
import Photos
import ImageIO
import Display
import TelegramCore
import SwiftSignalKit

public final class MediaEditorCollage {
    public enum Source {
        case image(UIImage, assetIdentifier: String?)
        case imageFile(String)
        case videoFile(String)
        case videoAsset(PHAsset)

        public var isVideo: Bool {
            switch self {
            case .videoFile, .videoAsset:
                return true
            case .image, .imageFile:
                return false
            }
        }
    }

    public struct Item {
        public let id: Int64
        public let source: Source
        public let dimensions: CGSize
        public let duration: Double
        public let frame: CGRect
        public let contentScale: CGFloat
        public let contentOffset: CGPoint
        public let videoTrimRange: Range<Double>?
        public let videoOffset: Double?
        public let videoVolume: CGFloat?

        public init(id: Int64, source: Source, dimensions: CGSize, duration: Double, frame: CGRect, contentScale: CGFloat, contentOffset: CGPoint, videoTrimRange: Range<Double>? = nil, videoOffset: Double? = nil, videoVolume: CGFloat? = nil) {
            self.id = id
            self.source = source
            self.dimensions = dimensions
            self.duration = duration
            self.frame = frame
            self.contentScale = contentScale
            self.contentOffset = contentOffset
            self.videoTrimRange = videoTrimRange
            self.videoOffset = videoOffset
            self.videoVolume = videoVolume
        }

        public func withSource(_ source: Source) -> Item {
            return Item(id: self.id, source: source, dimensions: self.dimensions, duration: self.duration, frame: self.frame, contentScale: self.contentScale, contentOffset: self.contentOffset, videoTrimRange: self.videoTrimRange, videoOffset: self.videoOffset, videoVolume: self.videoVolume)
        }
    }

    public let rows: [Int]
    public let items: [Item]
    public let mainItemId: Int64?
    public let hasSavedSettings: Bool
    public let fileLease: MediaEditorDraftFileLease?
    public let size = CGSize(width: 1080.0, height: 1920.0)

    public init(rows: [Int], items: [Item], mainItemId: Int64? = nil, hasSavedSettings: Bool = false, fileLease: MediaEditorDraftFileLease? = nil) {
        self.rows = rows
        self.items = items
        if let mainItemId, items.contains(where: { $0.id == mainItemId && $0.source.isVideo }) {
            self.mainItemId = mainItemId
        } else {
            self.mainItemId = items.filter { $0.source.isVideo }.reduce(nil as Item?) { current, item in
                if let current, current.duration >= item.duration {
                    return current
                }
                return item
            }?.id
        }
        self.hasSavedSettings = hasSavedSettings
        self.fileLease = fileLease
    }

    public var isVideo: Bool {
        return self.mainItemId != nil
    }

    public func prepareVideoSources() -> Signal<Bool, NoError> {
        let signals: [Signal<Bool, NoError>] = self.items.compactMap { item in
            switch item.source {
            case let .videoFile(path):
                return Signal { subscriber in
                    Queue.concurrentDefaultQueue().async {
                        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                        subscriber.putNext(asset.isPlayable && !asset.tracks(withMediaType: .video).isEmpty)
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            case let .videoAsset(asset):
                return Signal { subscriber in
                    let options = PHVideoRequestOptions()
                    options.version = .current
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    let requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                        Queue.concurrentDefaultQueue().async {
                            subscriber.putNext(asset.map { $0.isPlayable && !$0.tracks(withMediaType: .video).isEmpty } ?? false)
                            subscriber.putCompletion()
                        }
                    }
                    return ActionDisposable {
                        PHImageManager.default().cancelImageRequest(requestId)
                    }
                }
            case .image, .imageFile:
                return nil
            }
        }
        if signals.isEmpty {
            return .single(true)
        }
        return combineLatest(signals) |> map { $0.allSatisfy { $0 } }
    }

    public func image() -> UIImage? {
        guard !self.isVideo else {
            return nil
        }
        var images: [UIImage] = []
        for item in self.items {
            switch item.source {
            case let .image(image, _):
                images.append(image)
            case let .imageFile(path):
                guard let image = mediaEditorCollageImage(path: path) else {
                    return nil
                }
                images.append(image)
            default:
                return nil
            }
        }
        return generateImage(self.size, contextGenerator: { size, context in
            for (item, image) in zip(self.items, images) {
                let frame = CGRect(x: item.frame.minX, y: size.height - item.frame.maxY, width: item.frame.width, height: item.frame.height)
                let drawingSize = image.size.aspectFilled(frame.size)
                let center = frame.center.offsetBy(dx: item.contentOffset.x * frame.width, dy: item.contentOffset.y * frame.height)
                let imageFrame = CGSize(width: drawingSize.width * item.contentScale, height: drawingSize.height * item.contentScale).centered(around: center)
                context.saveGState()
                context.clip(to: frame)
                if let cgImage = image.cgImage {
                    context.draw(cgImage, in: imageFrame)
                }
                context.restoreGState()
            }
        }, opaque: true, scale: 1.0)
    }

    public func snapshot(values: MediaEditorValues) -> MediaEditorCollage {
        guard self.isVideo, values.collage.count == self.items.count else {
            return self
        }
        let items = zip(self.items, values.collage).map { item, value in
            Item(id: item.id, source: item.source, dimensions: item.dimensions, duration: item.duration, frame: value.frame, contentScale: value.contentScale, contentOffset: value.contentOffset, videoTrimRange: value.content == .main ? values.videoTrimRange : value.videoTrimRange, videoOffset: value.videoOffset, videoVolume: value.content == .main ? values.videoVolume : value.videoVolume)
        }
        return MediaEditorCollage(rows: self.rows, items: items, mainItemId: self.mainItemId, hasSavedSettings: true, fileLease: self.fileLease)
    }

    public func videoValues() -> [MediaEditorValues.VideoCollageItem] {
        guard self.isVideo else {
            return []
        }
        return self.items.map { item in
            let content: MediaEditorValues.VideoCollageItem.Content
            if item.id == self.mainItemId {
                content = .main
            } else {
                switch item.source {
                case let .imageFile(path):
                    content = .imageFile(path: URL(fileURLWithPath: path).deletingLastPathComponent().path + "/render-\(item.id).jpg")
                case let .videoFile(path):
                    content = .videoFile(path: path)
                case let .videoAsset(asset):
                    content = .asset(localIdentifier: asset.localIdentifier, isVideo: true)
                case .image:
                    preconditionFailure("Unsaved collage images do not have persistent render resources")
                }
            }
            return MediaEditorValues.VideoCollageItem(content: content, frame: item.frame, contentScale: item.contentScale, contentOffset: item.contentOffset, videoTrimRange: item.videoTrimRange, videoOffset: item.videoOffset, videoVolume: item.videoVolume)
        }
    }

    public func valuesForStorage(_ values: MediaEditorValues, additionalVideoPath: String?, audioPath: String?) -> MediaEditorValues {
        // The manifest owns the sources and per-cell settings. Do not persist temporary render paths.
        var values = values.withUpdatedCollage([])
        if let additionalVideoPath {
            values = values.withUpdatedAdditionalVideo(path: additionalVideoPath, isDual: values.additionalVideoIsDual, mirroringChanges: values.additionalVideoMirroringChanges, positionChanges: values.additionalVideoPositionChanges)
        }
        if let audioPath, let audio = values.audioTrack {
            values = values.withUpdatedAudioTrack(MediaAudioTrack(path: audioPath, artist: audio.artist, title: audio.title, duration: audio.duration, file: audio.file))
        }
        return values
    }

    public func valuesForEditor(_ values: MediaEditorValues, resetVideoTimeline: Bool = false) -> MediaEditorValues {
        var values = values.withUpdatedCollage(self.videoValues())
        if let path = values.additionalVideoPath, !path.hasPrefix("/") {
            values = values.withUpdatedAdditionalVideo(path: fullDraftPath(peerId: values.peerId, path: path), isDual: values.additionalVideoIsDual, mirroringChanges: values.additionalVideoMirroringChanges, positionChanges: values.additionalVideoPositionChanges)
        }
        if let main = self.items.first(where: { $0.id == self.mainItemId }) {
            values = values.withUpdatedVideoVolume(main.videoVolume)
            let trimRange = resetVideoTimeline ? (main.videoTrimRange ?? 0.0 ..< min(main.duration, 60.0)) : values.videoTrimRange
            if let trimRange {
                var upper = min(main.duration, trimRange.upperBound)
                let lower = max(0.0, min(trimRange.lowerBound, max(0.0, upper - 0.1)))
                if resetVideoTimeline {
                    upper = min(upper, lower + 60.0)
                }
                values = values.withUpdatedVideoTrimRange(lower ..< max(lower, upper))
            }
            if let cover = values.coverImageTimestamp {
                values = values.withUpdatedCoverImageTimestamp(min(values.videoTrimRange?.upperBound ?? main.duration, max(values.videoTrimRange?.lowerBound ?? 0.0, cover)))
            }
        } else if resetVideoTimeline {
            values = values.withUpdatedVideoTrimRange(0.0 ..< 5.0).withUpdatedCoverImageTimestamp(nil)
        }
        return values
    }

    public static func rows(for count: Int) -> [Int] {
        switch count {
        case 1: return [1]
        case 2: return [1, 1]
        case 3: return [2, 1]
        case 4: return [2, 2]
        case 5: return [1, 2, 2]
        default: return [2, 2, 2]
        }
    }

    public func removingItems(_ ids: Set<Int64>) -> MediaEditorCollage {
        let remaining = self.items.filter { !ids.contains($0.id) }
        guard !ids.isEmpty, !remaining.isEmpty else {
            return self
        }
        let rows = MediaEditorCollage.rows(for: remaining.count)
        let rowHeight = self.size.height / CGFloat(rows.count)
        var updatedItems: [Item] = []
        var index = 0
        for (row, columns) in rows.enumerated() {
            let columnWidth = self.size.width / CGFloat(columns)
            for column in 0 ..< columns {
                let item = remaining[index]
                let frame = CGRect(x: CGFloat(column) * columnWidth, y: CGFloat(row) * rowHeight, width: columnWidth, height: rowHeight)
                let oldSize = item.dimensions.aspectFilled(item.frame.size)
                let newSize = item.dimensions.aspectFilled(frame.size)
                let scale = min(3.5, max(1.0, item.contentScale))
                let center = CGPoint(
                    x: 0.5 - item.contentOffset.x * item.frame.width / (oldSize.width * scale),
                    y: 0.5 + item.contentOffset.y * item.frame.height / (oldSize.height * scale)
                )
                let contentSize = CGSize(width: newSize.width * scale, height: newSize.height * scale)
                let scrollOffset = CGPoint(
                    x: min(max(0.0, contentSize.width - frame.width), max(0.0, center.x * contentSize.width - frame.width / 2.0)),
                    y: min(max(0.0, contentSize.height - frame.height), max(0.0, center.y * contentSize.height - frame.height / 2.0))
                )
                let offset = CGPoint(
                    x: -(scrollOffset.x - (contentSize.width - frame.width) / 2.0) / frame.width,
                    y: (scrollOffset.y - (contentSize.height - frame.height) / 2.0) / frame.height
                )
                updatedItems.append(Item(id: item.id, source: item.source, dimensions: item.dimensions, duration: item.duration, frame: frame, contentScale: scale, contentOffset: offset, videoTrimRange: item.videoTrimRange, videoOffset: item.videoOffset, videoVolume: item.videoVolume))
                index += 1
            }
        }
        return MediaEditorCollage(rows: rows, items: updatedItems, mainItemId: self.mainItemId, hasSavedSettings: self.hasSavedSettings, fileLease: self.fileLease)
    }
}

public func mediaEditorCollageImage(path: String) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1920
    ] as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: image)
}

public struct MediaEditorCollageDraft: Codable {
    public struct Item: Codable {
        public enum Kind: String, Codable {
            case image
            case videoFile
            case videoAsset
        }
        public let id: Int64
        public let kind: Kind
        public let resource: String
        public let dimensions: CGSize
        public let duration: Double
        public let frame: CGRect
        public let contentScale: CGFloat
        public let contentOffset: CGPoint
        public let videoTrimRange: Range<Double>?
        public let videoOffset: Double?
        public let videoVolume: CGFloat?

        init(item: MediaEditorCollage.Item, kind: Kind, resource: String, dimensions: CGSize? = nil) {
            self.id = item.id
            self.kind = kind
            self.resource = resource
            self.dimensions = dimensions ?? item.dimensions
            self.duration = item.duration
            self.frame = item.frame
            self.contentScale = item.contentScale
            self.contentOffset = item.contentOffset
            self.videoTrimRange = item.videoTrimRange
            self.videoOffset = item.videoOffset
            self.videoVolume = item.videoVolume
        }
    }

    public let version: Int32
    public let directory: String
    public let size: CGSize
    public let rows: [Int32]
    public let items: [Item]
    public let mainItemId: Int64?

    init(directory: String, collage: MediaEditorCollage, items: [Item]) {
        self.version = 1
        self.directory = directory
        self.size = collage.size
        self.rows = collage.rows.map { Int32($0) }
        self.items = items
        self.mainItemId = collage.mainItemId
    }

    public enum ResolveError: Error {
        case unsupported
        case access
        case unreadable
    }

    public struct Resolved {
        public let collage: MediaEditorCollage?
        public let missingCount: Int
    }

    public func resolve(engine: TelegramEngine) throws -> Resolved {
        let directoryComponents = self.directory.split(separator: "/", omittingEmptySubsequences: false)
        guard self.version == 1, self.size == CGSize(width: 1080.0, height: 1920.0), (1 ... 6).contains(self.items.count), (1 ... 6).contains(self.rows.count), self.rows.allSatisfy({ (1 ... 6).contains($0) }), self.rows.reduce(0, +) == Int32(self.items.count), Set(self.items.map(\.id)).count == self.items.count, directoryComponents.count == 2, directoryComponents[0] == "collages", UUID(uuidString: String(directoryComponents[1])) != nil else {
            throw ResolveError.unsupported
        }
        let directory = fullDraftPath(peerId: engine.account.peerId, path: self.directory)
        let lease = MediaEditorDraftFileLease(path: directory)
        var items: [MediaEditorCollage.Item] = []
        var missing = Set<Int64>()
        let needsRenderImages = self.items.contains { $0.kind != .image }
        for item in self.items {
            guard item.dimensions.width.isFinite, item.dimensions.height.isFinite, item.dimensions.width > 0.0, item.dimensions.height > 0.0, item.frame.width.isFinite, item.frame.height.isFinite, item.frame.width > 0.0, item.frame.height > 0.0, item.frame.minX.isFinite, item.frame.minY.isFinite, (1.0 ... 3.5).contains(item.contentScale), item.contentOffset.x.isFinite, item.contentOffset.y.isFinite, item.duration.isFinite, item.kind == .image ? item.duration >= 0.0 : item.duration > 0.0 else {
                throw ResolveError.unsupported
            }
            let source: MediaEditorCollage.Source
            var duration = item.duration
            switch item.kind {
            case .image, .videoFile:
                guard !item.resource.isEmpty, !item.resource.contains("/"), !item.resource.contains("..") else {
                    throw ResolveError.unsupported
                }
                let path = directory + "/" + item.resource
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: path)
                    guard attributes[.type] as? FileAttributeType == .typeRegular, FileManager.default.isReadableFile(atPath: path) else {
                        throw ResolveError.unreadable
                    }
                } catch {
                    let error = error as NSError
                    guard error.domain == NSCocoaErrorDomain, error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError else {
                        throw ResolveError.unreadable
                    }
                    missing.insert(item.id)
                }
                if item.kind == .image {
                    if !missing.contains(item.id) {
                        guard CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) != nil else {
                            throw ResolveError.unreadable
                        }
                        let renderPath = directory + "/render-\(item.id).jpg"
                        if needsRenderImages, UIImage(contentsOfFile: renderPath) == nil {
                            guard let image = mediaEditorCollageImage(path: path), let data = image.jpegData(compressionQuality: 0.95) else {
                                throw ResolveError.unreadable
                            }
                            do {
                                try data.write(to: URL(fileURLWithPath: renderPath), options: .atomic)
                            } catch {
                                throw ResolveError.unreadable
                            }
                        }
                    }
                    source = .imageFile(path)
                } else {
                    source = .videoFile(path)
                }
            case .videoAsset:
                let options = PHFetchOptions()
                options.includeHiddenAssets = true
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [item.resource], options: options)
                if let asset = assets.firstObject {
                    guard asset.mediaType == .video, asset.duration.isFinite, asset.duration > 0.0 else {
                        throw ResolveError.unreadable
                    }
                    duration = asset.duration
                    source = .videoAsset(asset)
                } else {
                    let status: PHAuthorizationStatus
                    if #available(iOS 14.0, *) {
                        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    } else {
                        status = PHPhotoLibrary.authorizationStatus()
                    }
                    guard status == .authorized else {
                        throw ResolveError.access
                    }
                    missing.insert(item.id)
                    // This placeholder is removed before the collage reaches the editor.
                    source = .videoFile("")
                }
            }
            var trimRange = item.videoTrimRange
            if let range = trimRange, item.kind != .image {
                let upper = min(duration, range.upperBound)
                let lower = max(0.0, min(range.lowerBound, max(0.0, upper - 0.1)))
                trimRange = lower ..< max(lower, upper)
            }
            items.append(MediaEditorCollage.Item(id: item.id, source: source, dimensions: item.dimensions, duration: duration, frame: item.frame, contentScale: item.contentScale, contentOffset: item.contentOffset, videoTrimRange: trimRange, videoOffset: item.videoOffset, videoVolume: item.videoVolume))
        }
        if missing.count == items.count {
            return Resolved(collage: nil, missingCount: missing.count)
        }
        let collage = MediaEditorCollage(rows: self.rows.map { Int($0) }, items: items, mainItemId: self.mainItemId, hasSavedSettings: true, fileLease: lease)
        return Resolved(collage: collage.removingItems(missing), missingCount: missing.count)
    }
}

public final class MediaEditorDraftFileLease {
    private static let lock = NSLock()
    private static var counts: [String: Int] = [:]
    private static var pendingDeletion = Set<String>()
    private let path: String

    public init(path: String) {
        self.path = path
        Self.lock.lock()
        Self.counts[path, default: 0] += 1
        Self.lock.unlock()
    }

    deinit {
        Self.lock.lock()
        let count = (Self.counts[self.path] ?? 1) - 1
        if count == 0 {
            Self.counts.removeValue(forKey: self.path)
            if Self.pendingDeletion.remove(self.path) != nil {
                try? FileManager.default.removeItem(atPath: self.path)
            }
        } else {
            Self.counts[self.path] = count
        }
        Self.lock.unlock()
    }

    public static func delete(path: String) {
        Self.lock.lock()
        if Self.counts[path] != nil {
            Self.pendingDeletion.insert(path)
        } else {
            try? FileManager.default.removeItem(atPath: path)
        }
        Self.lock.unlock()
    }

    public static func isInUse(path: String) -> Bool {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return Self.counts[path] != nil
    }
}
