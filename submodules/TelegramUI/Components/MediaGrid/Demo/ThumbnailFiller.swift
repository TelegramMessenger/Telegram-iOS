import Foundation
import CoreGraphics
import UIKit
import Photos
import MediaGrid

struct ThumbnailCatalog {
    let ids: [String]
    let versions: [String]
    let indexById: [String: Int]

    static let empty = ThumbnailCatalog(ids: [], versions: [])

    init(ids: [String], versions: [String]) {
        self.ids = ids
        self.versions = versions
        var indexById: [String: Int] = [:]
        indexById.reserveCapacity(ids.count)
        for (index, id) in ids.enumerated() {
            indexById[id] = index
        }
        self.indexById = indexById
    }

    var count: Int {
        return self.ids.count
    }

    func id(at index: Int) -> String? {
        guard index >= 0, index < self.ids.count else {
            return nil
        }
        return self.ids[index]
    }

    static func build(count: Int, entry: (Int) -> (id: String, version: String)) -> ThumbnailCatalog {
        var ids: [String] = []
        var versions: [String] = []
        ids.reserveCapacity(count)
        versions.reserveCapacity(count)
        for index in 0 ..< count {
            let item = entry(index)
            ids.append(item.id)
            versions.append(item.version)
        }
        return ThumbnailCatalog(ids: ids, versions: versions)
    }

    func applying(_ changes: MediaGridChanges, newCount: Int, entry: (Int) -> (id: String, version: String)) -> ThumbnailCatalog {
        var ids: [String] = []
        var versions: [String] = []
        ids.reserveCapacity(newCount)
        versions.reserveCapacity(newCount)
        var old = 0
        for index in 0 ..< newCount {
            if changes.inserted.contains(index) {
                let item = entry(index)
                ids.append(item.id)
                versions.append(item.version)
                continue
            }
            while changes.removed.contains(old) {
                old += 1
            }
            if changes.changed.contains(index) || old >= self.ids.count {
                let item = entry(index)
                ids.append(item.id)
                versions.append(item.version)
            } else {
                ids.append(self.ids[old])
                versions.append(self.versions[old])
            }
            old += 1
        }
        return ThumbnailCatalog(ids: ids, versions: versions)
    }
}

enum ThumbnailFillState: UInt8 {
    case missing = 0
    case filled = 1
    case unavailable = 2
    case inFlight = 3
}

struct ThumbnailFillPlan {
    var catalog: ThumbnailCatalog
    var states: [ThumbnailFillState]
    var filled: Int
    var unavailable: Int

    static func make(catalog: ThumbnailCatalog, isFilled: (String, String) -> Bool, isUnavailable: (String, String) -> Bool) -> ThumbnailFillPlan {
        var states: [ThumbnailFillState] = []
        states.reserveCapacity(catalog.count)
        var filled = 0
        var unavailable = 0
        for index in 0 ..< catalog.count {
            let id = catalog.ids[index]
            let version = catalog.versions[index]
            if isFilled(id, version) {
                states.append(.filled)
                filled += 1
            } else if isUnavailable(id, version) {
                states.append(.unavailable)
                unavailable += 1
            } else {
                states.append(.missing)
            }
        }
        return ThumbnailFillPlan(catalog: catalog, states: states, filled: filled, unavailable: unavailable)
    }
}

enum ThumbnailImageResult {
    case image(CGImage)
    case unavailable
}

protocol ThumbnailImageSource: AnyObject {
    func requestThumbnail(index: Int, id: String, completion: @escaping (ThumbnailImageResult) -> Void)
}

final class UnavailableThumbnailRegistry {
    private let lock = NSLock()
    private var entries: [String: String]
    private let url: URL?
    private var isSaveScheduled = false
    private let queue = DispatchQueue(label: "org.telegram.MediaGridDemo.unavailableThumbnails", qos: .utility)

    init(url: URL?) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url), let entries = try? PropertyListDecoder().decode([String: String].self, from: data) {
            self.entries = entries
        } else {
            self.entries = [:]
        }
    }

    func contains(id: String, version: String) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.entries[id] == version
    }

    var count: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.entries.count
    }

    func insert(id: String, version: String) {
        self.lock.lock()
        self.entries[id] = version
        self.lock.unlock()
        self.scheduleSave()
    }

    func remove(ids: [String]) {
        self.lock.lock()
        for id in ids {
            self.entries.removeValue(forKey: id)
        }
        self.lock.unlock()
        self.scheduleSave()
    }

    private func scheduleSave() {
        guard let url = self.url else {
            return
        }
        self.lock.lock()
        let isScheduled = self.isSaveScheduled
        self.isSaveScheduled = true
        self.lock.unlock()
        if isScheduled {
            return
        }
        self.queue.asyncAfter(deadline: .now() + 2.0) {
            self.lock.lock()
            let entries = self.entries
            self.isSaveScheduled = false
            self.lock.unlock()
            if let data = try? PropertyListEncoder().encode(entries) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

final class ThumbnailFiller {
    static let idleLimit = 16
    static let fastLimit = 4

    private let store: MediaGridThumbnailStore
    private let source: ThumbnailImageSource
    let registry: UnavailableThumbnailRegistry

    private(set) var catalog = ThumbnailCatalog.empty
    private(set) var states: [ThumbnailFillState] = []
    private(set) var filledCount = 0
    private(set) var unavailableCount = 0
    private(set) var missingCount = 0
    private(set) var hasPlan = false
    private(set) var isComplete = false
    private var inFlight: [String: String] = [:]
    private var urgent: [String] = []
    private var urgentPosition = 0
    private var ranges: [Range<Int>] = []
    private var rangeIndex = 0
    private var rangePosition = 0
    private var center = 0
    private var outwardStep = 0
    private var outwardRadius = 0
    private var gridPosition = 0
    var onProgress: (() -> Void)?

    var isMovingFast = false {
        didSet {
            if self.isMovingFast != oldValue {
                self.pump()
            }
        }
    }

    var isPaused = false {
        didSet {
            if self.isPaused != oldValue {
                self.pump()
            }
        }
    }

    var inFlightCount: Int {
        return self.inFlight.count
    }

    var limit: Int {
        return self.isMovingFast ? ThumbnailFiller.fastLimit : ThumbnailFiller.idleLimit
    }

    init(store: MediaGridThumbnailStore, source: ThumbnailImageSource, registry: UnavailableThumbnailRegistry) {
        self.store = store
        self.source = source
        self.registry = registry
    }

    func makePlan(for catalog: ThumbnailCatalog) -> ThumbnailFillPlan {
        let store = self.store
        let registry = self.registry
        return ThumbnailFillPlan.make(catalog: catalog, isFilled: { id, version in
            return store.version(for: id) == version
        }, isUnavailable: { id, version in
            return registry.contains(id: id, version: version)
        })
    }

    func install(_ plan: ThumbnailFillPlan, removed: [String] = [], urgent: [String] = []) {
        if !removed.isEmpty {
            self.store.remove(ids: removed)
            self.registry.remove(ids: removed)
        }
        self.catalog = plan.catalog
        self.states = plan.states
        self.filledCount = plan.filled
        self.unavailableCount = plan.unavailable
        self.missingCount = plan.catalog.count - plan.filled - plan.unavailable
        for id in self.inFlight.keys {
            if let index = plan.catalog.indexById[id] {
                self.setState(.inFlight, at: index)
            }
        }
        self.urgent = Array(self.urgent[self.urgentPosition...]) + urgent
        self.urgentPosition = 0
        self.rangeIndex = 0
        self.rangePosition = 0
        self.outwardStep = 0
        self.gridPosition = 0
        self.hasPlan = true
        self.isComplete = false
        self.pump()
        self.onProgress?()
    }

    func setPriority(ranges: [Range<Int>]) {
        guard ranges != self.ranges else {
            return
        }
        self.ranges = ranges
        self.rangeIndex = 0
        self.rangePosition = 0
        if let first = ranges.first {
            let center = (first.lowerBound + first.upperBound) / 2
            if center != self.center {
                self.center = center
                self.outwardStep = 0
            }
            self.outwardRadius = max(512, first.count * 4)
        }
        self.pump()
    }

    private func setState(_ state: ThumbnailFillState, at index: Int) {
        let previous = self.states[index]
        if previous == state {
            return
        }
        switch previous {
        case .filled:
            self.filledCount -= 1
        case .unavailable:
            self.unavailableCount -= 1
        case .missing:
            self.missingCount -= 1
        case .inFlight:
            break
        }
        switch state {
        case .filled:
            self.filledCount += 1
        case .unavailable:
            self.unavailableCount += 1
        case .missing:
            self.missingCount += 1
        case .inFlight:
            break
        }
        self.states[index] = state
    }

    private func isMissing(_ index: Int) -> Bool {
        return index >= 0 && index < self.states.count && self.states[index] == .missing
    }

    private func nextCandidate() -> Int? {
        if self.missingCount == 0 {
            self.urgent.removeAll()
            self.urgentPosition = 0
            return nil
        }
        while self.urgentPosition < self.urgent.count {
            let id = self.urgent[self.urgentPosition]
            self.urgentPosition += 1
            if let index = self.catalog.indexById[id], self.isMissing(index) {
                return index
            }
        }
        if self.urgentPosition > 0 {
            self.urgent.removeAll()
            self.urgentPosition = 0
        }
        while self.rangeIndex < self.ranges.count {
            let range = self.ranges[self.rangeIndex]
            while range.lowerBound + self.rangePosition < range.upperBound {
                let index = range.lowerBound + self.rangePosition
                self.rangePosition += 1
                if self.isMissing(index) {
                    return index
                }
            }
            self.rangeIndex += 1
            self.rangePosition = 0
        }
        let count = self.states.count
        if !self.ranges.isEmpty {
            while self.outwardStep <= 2 * self.outwardRadius {
                let step = self.outwardStep
                self.outwardStep += 1
                let index = step % 2 == 0 ? self.center + step / 2 : self.center - (step + 1) / 2
                if self.isMissing(index) {
                    return index
                }
            }
        }
        while self.gridPosition < count {
            let index = self.gridPosition
            self.gridPosition += 1
            if self.isMissing(index) {
                return index
            }
        }
        return nil
    }

    func pump() {
        guard self.hasPlan, !self.isPaused else {
            return
        }
        var exhausted = false
        while self.inFlight.count < self.limit {
            guard let index = self.nextCandidate() else {
                exhausted = true
                break
            }
            let id = self.catalog.ids[index]
            let version = self.catalog.versions[index]
            if self.store.version(for: id) == version {
                self.setState(.filled, at: index)
                continue
            }
            if self.registry.contains(id: id, version: version) {
                self.setState(.unavailable, at: index)
                continue
            }
            if self.inFlight[id] != nil {
                self.setState(.inFlight, at: index)
                continue
            }
            self.inFlight[id] = version
            self.setState(.inFlight, at: index)
            self.source.requestThumbnail(index: index, id: id, completion: { [weak self] result in
                self?.complete(id: id, version: version, result: result)
            })
        }
        if exhausted && self.inFlight.isEmpty && !self.isComplete {
            self.isComplete = true
            self.onProgress?()
        }
    }

    private func complete(id: String, version: String, result: ThumbnailImageResult) {
        self.inFlight.removeValue(forKey: id)
        if let index = self.catalog.indexById[id] {
            let isCurrent = self.catalog.versions[index] == version
            switch result {
            case let .image(image):
                if isCurrent {
                    self.store.write(image, id: id, version: version)
                    self.setState(.filled, at: index)
                } else {
                    self.setState(.missing, at: index)
                    self.restartScan()
                }
            case .unavailable:
                self.registry.insert(id: id, version: version)
                if isCurrent {
                    self.setState(.unavailable, at: index)
                } else {
                    self.setState(.missing, at: index)
                    self.restartScan()
                }
            }
        }
        self.pump()
        self.onProgress?()
    }

    private func restartScan() {
        self.rangeIndex = 0
        self.rangePosition = 0
        self.outwardStep = 0
        self.gridPosition = 0
        self.isComplete = false
    }
}

final class PhotoKitThumbnailSource: ThumbnailImageSource {
    static let targetSize = CGSize(width: 96.0, height: 96.0)
    static let fastFormatFallbackLimit = 32

    var fetchResult: PHFetchResult<PHAsset>
    private let manager = PHImageManager.default()
    private let queue = DispatchQueue(label: "org.telegram.MediaGridDemo.thumbnailRequests", qos: .utility)
    private var usesFastFormat = true
    private var fastFormatSuccesses = 0
    private var fastFormatFailures = 0

    init(fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
    }

    func requestThumbnail(index: Int, id: String, completion: @escaping (ThumbnailImageResult) -> Void) {
        let fetchResult = self.fetchResult
        self.queue.async {
            let count = fetchResult.count
            var asset: PHAsset?
            if index >= 0, index < count {
                let candidate = fetchResult.object(at: count - 1 - index)
                if candidate.localIdentifier == id {
                    asset = candidate
                }
            }
            if asset == nil {
                asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
            }
            guard let asset else {
                DispatchQueue.main.async {
                    completion(.unavailable)
                }
                return
            }
            self.request(asset, fastFormat: self.usesFastFormat, completion: completion)
        }
    }

    private func request(_ asset: PHAsset, fastFormat: Bool, completion: @escaping (ThumbnailImageResult) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = fastFormat ? .fastFormat : .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        self.manager.requestImage(for: asset, targetSize: PhotoKitThumbnailSource.targetSize, contentMode: .aspectFit, options: options, resultHandler: { image, info in
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            let hasError = info?[PHImageErrorKey] != nil
            self.queue.async {
                if let image, let cgImage = PhotoKitThumbnailSource.upright(image) {
                    if fastFormat {
                        self.fastFormatSuccesses += 1
                    }
                    DispatchQueue.main.async {
                        completion(.image(cgImage))
                    }
                    return
                }
                if fastFormat && !isInCloud && hasError {
                    self.fastFormatFailures += 1
                    if self.usesFastFormat && self.fastFormatSuccesses == 0 && self.fastFormatFailures >= PhotoKitThumbnailSource.fastFormatFallbackLimit {
                        self.usesFastFormat = false
                        print("THUMBS fastFormat unavailable after \(self.fastFormatFailures) failures, using highQualityFormat")
                        fflush(stdout)
                    }
                    self.request(asset, fastFormat: false, completion: completion)
                    return
                }
                DispatchQueue.main.async {
                    completion(.unavailable)
                }
            }
        })
    }

    static func upright(_ image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        if image.imageOrientation == .up {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let size = CGSize(width: round(image.size.width * image.scale), height: round(image.size.height * image.scale))
        guard size.width > 0.0, size.height > 0.0 else {
            return nil
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
