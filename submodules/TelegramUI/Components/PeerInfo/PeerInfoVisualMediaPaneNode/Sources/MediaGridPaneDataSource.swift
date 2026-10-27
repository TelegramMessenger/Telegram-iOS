import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import DirectMediaImageCache
import MediaGrid

private final class MediaGridPaneImageRequest: MediaGridImageRequest {
    private let disposable: Disposable

    init(disposable: Disposable) {
        self.disposable = disposable
    }

    func cancel() {
        self.disposable.dispose()
    }
}

func mediaGridPaneSelectedMedia(_ message: EngineMessage) -> EngineMedia? {
    for media in message._asMessage().effectiveMedia {
        if let image = media as? TelegramMediaImage {
            return .image(image)
        } else if let file = media as? TelegramMediaFile {
            if let cover = file.videoCover {
                return .image(cover)
            } else {
                return .file(file)
            }
        }
    }
    return nil
}

final class MediaGridPaneDataSource: MediaGridDataSource {
    private struct HoleEntry {
        var index: Int
        var messageId: EngineMessage.Id
    }

    private static let thumbnailCacheLimit = 4000
    private static let thumbnailBatchLimit = 400

    private let directMediaImageCache: DirectMediaImageCache

    private(set) var count: Int = 0
    private(set) var isPlaceholderCount = false
    private(set) var isLoading = true
    private var messages: [Int: EngineMessage] = [:]
    private var indexById: [EngineMessage.Id: Int] = [:]
    private var holeEntries: [HoleEntry] = []
    private var anchors: [(index: Int, timestamp: Int32)] = []
    private var thumbnails: [EngineMessage.Id: MediaGridThumbnail] = [:]
    private var pendingThumbnails = Set<EngineMessage.Id>()
    private var missingThumbnails = Set<EngineMessage.Id>()

    var onThumbnailsReady: ((IndexSet) -> Void)?

    init(directMediaImageCache: DirectMediaImageCache) {
        self.directMediaImageCache = directMediaImageCache
    }

    func update(state: SparseMessageList.State) -> MediaGridChanges? {
        var newCount = state.totalCount
        var isPlaceholderCount = false
        var newMessages: [Int: EngineMessage] = [:]
        var newIndexById: [EngineMessage.Id: Int] = [:]
        var newHoles: [HoleEntry] = []
        var newAnchors: [(index: Int, timestamp: Int32)] = []
        if state.items.isEmpty && state.isLoading && state.totalCount == 0 {
            newCount = 100
            isPlaceholderCount = true
        } else {
            for item in state.items {
                switch item.content {
                case let .message(message, isLocal):
                    let engineMessage = EngineMessage(message)
                    newMessages[item.index] = engineMessage
                    newIndexById[message.id] = item.index
                    newAnchors.append((item.index, message.timestamp))
                    if !isLocal {
                        newHoles.append(HoleEntry(index: item.index, messageId: message.id))
                    }
                case let .placeholder(id, timestamp):
                    newHoles.append(HoleEntry(index: item.index, messageId: id))
                    newAnchors.append((item.index, timestamp))
                }
            }
        }
        newAnchors.sort(by: { $0.index < $1.index })

        let oldCount = self.count
        var changed = IndexSet()
        for index in 0 ..< min(oldCount, newCount) {
            let previous = self.messages[index]
            let current = newMessages[index]
            if previous?.stableId != current?.stableId || previous?.stableVersion != current?.stableVersion {
                changed.insert(index)
            }
        }
        var inserted = IndexSet()
        var removed = IndexSet()
        if newCount > oldCount {
            inserted.insert(integersIn: oldCount ..< newCount)
        } else if newCount < oldCount {
            removed.insert(integersIn: newCount ..< oldCount)
        }

        self.count = newCount
        self.isPlaceholderCount = isPlaceholderCount
        self.isLoading = state.isLoading
        self.messages = newMessages
        self.indexById = newIndexById
        self.holeEntries = newHoles
        self.anchors = newAnchors

        let changes = MediaGridChanges(removed: removed, inserted: inserted, changed: changed)
        return changes.isEmpty ? nil : changes
    }

    func reset() {
        self.count = 0
        self.isPlaceholderCount = false
        self.isLoading = true
        self.messages = [:]
        self.indexById = [:]
        self.holeEntries = []
        self.anchors = []
    }

    var loadedMessages: [EngineMessage] {
        return self.messages.keys.sorted().compactMap { self.messages[$0] }
    }

    var hasLoadedMessages: Bool {
        return !self.messages.isEmpty
    }

    func message(at index: Int) -> EngineMessage? {
        return self.messages[index]
    }

    func index(of id: EngineMessage.Id) -> Int? {
        return self.indexById[id]
    }

    func holes() -> [MediaGridPaneHole] {
        return self.holeEntries.map { MediaGridPaneHole(anchorIndex: $0.index) }
    }

    func holeAnchorMessageId(at anchorIndex: Int) -> EngineMessage.Id? {
        return self.holeEntries.first(where: { $0.index == anchorIndex })?.messageId
    }

    func timestamp(at index: Int) -> Int32? {
        if let message = self.messages[index] {
            return message.timestamp
        }
        return mediaGridPaneDateIndex(at: index, anchors: self.anchors)
    }

    func date(at index: Int) -> Date? {
        return self.timestamp(at: index).flatMap { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    func aspectRatioReader() -> MediaGridAspectRatioReader {
        return { _ in
            return 1.0
        }
    }

    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        guard let message = self.messages[index], let media = mediaGridPaneSelectedMedia(message) else {
            return nil
        }
        let width = mediaGridPanePreviewWidth(cellPointWidth: pixelSize.width / UIScreenScale)
        guard let result = self.directMediaImageCache.getImage(message: message._asMessage(), media: media._asMedia(), width: width, possibleWidths: mediaGridPanePreviewWidths, synchronous: false), let loadSignal = result.loadSignal else {
            return nil
        }
        var lastImage: UIImage?
        let disposable = (loadSignal
        |> deliverOnMainQueue).start(next: { image in
            guard let image else {
                return
            }
            lastImage = image
            completion(image, true)
        }, completed: {
            if let lastImage {
                completion(lastImage, false)
            }
        })
        return MediaGridPaneImageRequest(disposable: disposable)
    }

    func startCaching(indices: [Int], pixelSize: CGSize) {
    }

    func stopCaching(indices: [Int], pixelSize: CGSize) {
    }

    func thumbnail(at index: Int) -> MediaGridThumbnail? {
        guard let message = self.messages[index] else {
            return nil
        }
        return self.thumbnails[message.id]
    }

    func prepareThumbnails(ranges: [Range<Int>]) {
        var batch: [(EngineMessage.Id, EngineMedia)] = []
        outer: for range in ranges {
            for index in range {
                guard let message = self.messages[index] else {
                    continue
                }
                if self.thumbnails[message.id] != nil || self.pendingThumbnails.contains(message.id) || self.missingThumbnails.contains(message.id) {
                    continue
                }
                guard let media = mediaGridPaneSelectedMedia(message) else {
                    continue
                }
                self.pendingThumbnails.insert(message.id)
                batch.append((message.id, media))
                if batch.count >= MediaGridPaneDataSource.thumbnailBatchLimit {
                    break outer
                }
            }
        }
        if batch.isEmpty {
            return
        }
        let cache = self.directMediaImageCache
        Queue.concurrentDefaultQueue().async { [weak self] in
            var decoded: [(EngineMessage.Id, CGImage?)] = []
            for (id, media) in batch {
                decoded.append((id, cache.blurredImmediateThumbnail(media: media._asMedia())?.cgImage))
            }
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                if self.thumbnails.count + decoded.count > MediaGridPaneDataSource.thumbnailCacheLimit {
                    self.thumbnails.removeAll()
                }
                var indices = IndexSet()
                for (id, image) in decoded {
                    self.pendingThumbnails.remove(id)
                    guard let image else {
                        self.missingThumbnails.insert(id)
                        continue
                    }
                    self.thumbnails[id] = MediaGridThumbnail(image: image, contentsRect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
                    if let index = self.indexById[id] {
                        indices.insert(index)
                    }
                }
                if !indices.isEmpty {
                    self.onThumbnailsReady?(indices)
                }
            }
        }
    }
}
