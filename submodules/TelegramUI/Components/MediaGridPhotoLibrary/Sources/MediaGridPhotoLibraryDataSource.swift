import UIKit
import Photos
import MediaGrid

public final class MediaGridPhotoLibraryDataSource: NSObject, MediaGridDataSource, PHPhotoLibraryChangeObserver {
    struct ImageKey: Hashable {
        var identifier: String
        var width: Int
        var height: Int
        var revision: Int

        var cacheKey: NSString {
            return "\(self.identifier)|\(self.width)x\(self.height)|\(self.revision)" as NSString
        }
    }

    struct PrefetchKey: Hashable {
        var index: Int
        var width: Int
        var height: Int
    }

    struct Load {
        var asset: PHAsset
        var targetSize: CGSize
    }

    typealias Scheduler = ImageLoadScheduler<ImageKey, PrefetchKey, Load>

    static let preparePageLimit = 32
    static let unknownPage: Int32 = -2

    public private(set) var fetchResult: PHFetchResult<PHAsset>
    public let reversed: Bool
    private(set) var catalog = ThumbnailCatalog.empty
    private var catalogGeneration = 0
    public let store: MediaGridThumbnailStore
    public let filler: MediaGridPhotoLibraryFiller?
    public var onThumbnailsChanged: ((IndexSet) -> Void)?
    public var onLog: ((String) -> Void)?
    private(set) var fillStartTime: CFTimeInterval?
    public private(set) var fillDuration: CFTimeInterval?
    private var preparedRanges: [Range<Int>] = []
    private var pageCache: [Int32] = []
    private var launchSnapshot: ThumbnailLaunchSnapshot?
    private let snapshotURL: URL?
    private var snapshotSaveGeneration = 0
    private(set) var planInstallCount = 0
    private var isSharpNetworkIdle = true
    private var backgroundObserver: NSObjectProtocol?
    private var revisions: [String: Int] = [:]
    private var revisionBase = 0
    public var onChange: ((MediaGridChanges?) -> Void)?
    private let manager = PHImageManager.default()
    private let cache = NSCache<NSString, UIImage>()
    private let scheduler = Scheduler(localLimit: 12, localPrefetchLimit: 6, networkLimit: 4)
    public let launchKeeper: MediaGridLaunchCacheKeeper?
    let launchMatch: MediaGridLaunchMatch?
    private let launchFetchResult: PHFetchResult<PHAsset>
    private(set) var isLaunchInstalled = false

    static let snapshotHead = 2048

    public init(fetchResult: PHFetchResult<PHAsset>, reversed: Bool, store: MediaGridThumbnailStore, launch: MediaGridLaunchMatch?, filler: MediaGridPhotoLibraryFiller? = nil, snapshotURL: URL? = nil) {
        self.launchMatch = launch
        self.launchKeeper = launch.map { MediaGridLaunchCacheKeeper(cache: $0.cache) }
        self.launchFetchResult = fetchResult
        self.fetchResult = fetchResult
        self.reversed = reversed
        self.observedFetchResult = fetchResult
        self.snapshotURL = snapshotURL
        self.store = store
        self.filler = filler
        super.init()
        self.store.onThumbnailsChanged = { [weak self] ids in
            self?.thumbnailsChanged(ids)
        }
        self.store.hookOwner = self
        if let filler {
            filler.source.fetchResult = fetchResult
            filler.source.reversed = reversed
            filler.filler.onProgress = { [weak self] in
                self?.fillProgressed()
            }
            filler.sharpNetworkIdle = { [weak self] in
                return self?.isSharpNetworkIdle ?? false
            }
        }
        self.scheduler.networkLaneDidChange = { [weak self] in
            guard let self else {
                return
            }
            let isIdle = self.scheduler.isNetworkLaneIdle
            if isIdle != self.isSharpNetworkIdle {
                self.isSharpNetworkIdle = isIdle
                self.filler?.filler.networkConditionsChanged()
            }
        }
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.saveLaunchSnapshot()
            self?.launchKeeper?.refreshIfResting()
        })
        self.cache.totalCostLimit = 80 * 1024 * 1024
        self.scheduler.startJob = { [weak self] job in
            self?.start(job)
        }
        self.scheduler.cancelJob = { [weak self] job in
            if let token = job.token {
                self?.manager.cancelImageRequest(token)
            }
        }
        self.scheduler.resolvePrefetch = { [weak self] key in
            guard let self, let asset = self.asset(at: key.index) else {
                return nil
            }
            let size = self.targetSize(at: key.index, pixelSize: CGSize(width: key.width, height: key.height))
            return (self.key(for: asset, size: size), Load(asset: asset, targetSize: size))
        }
        self.scheduler.isCached = { [weak self] key in
            return self?.cache.object(forKey: key.cacheKey) != nil
        }
        self.startLaunchMatch()
        self.startCatalog(fetchResult)
        PHPhotoLibrary.shared().register(self)
    }

    private func startLaunchMatch() {
        guard let match = self.launchMatch else {
            self.isLaunchInstalled = true
            return
        }
        match.notifyResult(queue: .main) { [weak self] result in
            guard let self, self.installLaunch(result), let keeper = self.launchKeeper else {
                return
            }
            let indices = IndexSet(keeper.images.keys)
            if !indices.isEmpty {
                self.onThumbnailsChanged?(indices)
            }
        }
        match.notifyHead(queue: .main) { [weak self] head in
            self?.launchHeadArrived(head)
        }
    }

    static func fetchIndex(_ index: Int, count: Int, reversed: Bool) -> Int {
        return reversed ? count - 1 - index : index
    }

    static func launchMatch(cache: MediaGridLaunchCache, fetchResult: PHFetchResult<PHAsset>, reversed: Bool) -> MediaGridLaunchMatch {
        return MediaGridLaunchMatch(cache: cache, readHead: {
            return MediaGridPhotoLibraryDataSource.head(of: fetchResult, count: cache.capacity, reversed: reversed)
        })
    }

    static func head(of fetchResult: PHFetchResult<PHAsset>, count: Int, reversed: Bool) -> [MediaGridLaunchCache.Key] {
        let total = fetchResult.count
        var head: [MediaGridLaunchCache.Key] = []
        for index in 0 ..< min(count, total) {
            let asset = fetchResult.object(at: MediaGridPhotoLibraryDataSource.fetchIndex(index, count: total, reversed: reversed))
            head.append(MediaGridLaunchCache.Key(id: asset.localIdentifier, version: MediaGridPhotoLibraryDataSource.version(of: asset)))
        }
        return head
    }

    @discardableResult
    private func installLaunch(_ result: MediaGridLaunchMatch.Result) -> Bool {
        guard !self.isLaunchInstalled, let keeper = self.launchKeeper else {
            return false
        }
        self.isLaunchInstalled = true
        if self.launchFetchResult === self.fetchResult {
            keeper.install(head: result.head ?? [], images: result.images)
        } else {
            keeper.install(head: [], images: [:])
            keeper.setHead(self.catalogHead())
        }
        self.onLog?(String(format: "LAUNCH installed matched=%d/%d stored=%d load=%.1fms decode=%.1fms", keeper.images.count, result.head?.count ?? 0, keeper.cache.storedKeys.count, result.duration * 1000.0, keeper.cache.loadDuration * 1000.0))
        return true
    }

    private func launchHeadArrived(_ head: [MediaGridLaunchCache.Key]) {
        guard self.isLaunchInstalled, self.launchFetchResult === self.fetchResult, let keeper = self.launchKeeper, keeper.head.isEmpty else {
            return
        }
        keeper.setHead(head)
    }

    private func catalogHead() -> [MediaGridLaunchCache.Key] {
        let count = min(self.catalog.count, self.launchKeeper?.capacity ?? 0)
        return (0 ..< count).map { MediaGridLaunchCache.Key(id: self.catalog.ids[$0], version: self.catalog.versions[$0]) }
    }

    public func waitForLaunchImages(timeout: TimeInterval) {
        guard !self.isLaunchInstalled else {
            return
        }
        let start = CACurrentMediaTime()
        let result = self.launchMatch?.wait(timeout: timeout)
        let waited = CACurrentMediaTime() - start
        let ready = result != nil
        if let result {
            self.installLaunch(result)
        }
        self.onLog?(String(format: "LAUNCH wait=%.2fms ready=%d matched=%d", waited * 1000.0, ready ? 1 : 0, self.launchKeeper?.images.count ?? 0))
    }

    public func launchImage(at index: Int) -> MediaGridLaunchImage? {
        return self.launchKeeper?.images[index]
    }

    private func startCatalog(_ fetchResult: PHFetchResult<PHAsset>) {
        let store = self.store
        let filler = self.filler?.filler
        let snapshotURL = self.snapshotURL
        let reversed = self.reversed
        self.changeQueue.async { [weak self] in
            if let snapshotURL, let data = try? Data(contentsOf: snapshotURL), let snapshot = ThumbnailLaunchSnapshot.decode(data), snapshot.count == fetchResult.count {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.fetchResult === fetchResult, self.catalogGeneration == 0, self.catalog.count == 0 else {
                        return
                    }
                    self.onLog?(String(format: "THUMBS snapshot ids=%d", snapshot.indices.count))
                    self.installLaunchSnapshot(snapshot)
                }
            }
            let start = CACurrentMediaTime()
            let catalog = MediaGridPhotoLibraryDataSource.makeCatalog(fetchResult, reversed: reversed, prefix: MediaGridPhotoLibraryDataSource.initialCatalogPrefix, onPrefix: { prefix in
                let duration = CACurrentMediaTime() - start
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.fetchResult === fetchResult, self.catalogGeneration == 0 else {
                        return
                    }
                    self.onLog?(String(format: "THUMBS catalog prefix=%d build=%.1fms", prefix.count, duration * 1000.0))
                    self.installCatalog(prefix, generation: 0)
                }
            })
            let duration = CACurrentMediaTime() - start
            guard let self else {
                return
            }
            self.observedCatalogGeneration += 1
            let generation = self.observedCatalogGeneration
            self.observedCatalog = catalog
            DispatchQueue.main.async { [weak self] in
                guard let self, self.fetchResult === fetchResult else {
                    return
                }
                self.onLog?(String(format: "THUMBS catalog count=%d build=%.1fms", catalog.count, duration * 1000.0))
                self.installCatalog(catalog, generation: generation)
            }
            store.load { [weak self] in
                self?.changeQueue.async { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isStoreLoaded = true
                    let catalog = self.observedCatalog
                    let generation = self.observedCatalogGeneration
                    guard let filler else {
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.catalogGeneration == generation else {
                                return
                            }
                            self.resetPageCache()
                            self.prepareStore()
                        }
                        return
                    }
                    let start = CACurrentMediaTime()
                    let plan = filler.makePlan(for: catalog)
                    let planDuration = CACurrentMediaTime() - start
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.catalogGeneration == generation else {
                            return
                        }
                        self.onLog?(String(format: "THUMBS plan count=%d filled=%d unavailable=%d orphans=%d build=%.1fms", catalog.count, plan.filled, plan.unavailable, plan.orphans.count, planDuration * 1000.0))
                        self.installPlan(plan)
                        self.resetPageCache()
                        self.prepareStore()
                    }
                }
            }
        }
    }

    func installLaunchSnapshot(_ snapshot: ThumbnailLaunchSnapshot) {
        self.launchSnapshot = snapshot
        self.store.load { [weak self] in
            guard let self, self.launchSnapshot != nil else {
                return
            }
            self.prepareStore()
        }
        self.onThumbnailsChanged?(snapshot.indices)
    }

    func debugId(at index: Int) -> String? {
        return self.id(at: index)
    }

    func installCatalog(_ catalog: ThumbnailCatalog, generation: Int) {
        let previousCount = self.catalog.count
        var changed = IndexSet(integersIn: min(previousCount, catalog.count) ..< catalog.count)
        if let snapshot = self.launchSnapshot {
            for segment in snapshot.segments {
                for (offset, id) in segment.ids.enumerated() {
                    let index = segment.start + offset
                    if index >= previousCount && index < catalog.count && catalog.ids[index] == id {
                        changed.remove(index)
                    }
                }
            }
            if generation != 0 {
                self.launchSnapshot = nil
            }
        }
        self.catalog = catalog
        self.catalogGeneration = generation
        if self.isLaunchInstalled, catalog.count > 0, generation != 0 || catalog.count >= (self.launchKeeper?.capacity ?? 0) {
            self.launchKeeper?.setHead(self.catalogHead())
        }
        self.resetPageCache()
        self.prepareStore()
        if !changed.isEmpty {
            self.onThumbnailsChanged?(changed)
        }
    }

    static let snapshotSettleDelay: Double = 1.0

    private func scheduleLaunchSnapshotSave() {
        guard self.snapshotURL != nil else {
            return
        }
        self.snapshotSaveGeneration += 1
        let generation = self.snapshotSaveGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + MediaGridPhotoLibraryDataSource.snapshotSettleDelay) { [weak self] in
            guard let self, self.snapshotSaveGeneration == generation else {
                return
            }
            self.saveLaunchSnapshot()
        }
    }

    private func saveLaunchSnapshot() {
        guard let url = self.snapshotURL, self.catalog.count == self.fetchResult.count, self.catalog.count > 0 else {
            return
        }
        var ranges: [Range<Int>] = []
        if let viewport = self.preparedRanges.first {
            ranges.append(max(0, viewport.lowerBound - viewport.count) ..< viewport.upperBound + viewport.count)
        }
        let snapshot = ThumbnailLaunchSnapshot.make(catalog: self.catalog, head: MediaGridPhotoLibraryDataSource.snapshotHead, ranges: ranges)
        DispatchQueue.global(qos: .utility).async {
            try? snapshot.encode().write(to: url, options: .atomic)
        }
    }

    static func version(of asset: PHAsset) -> String {
        guard let date = asset.modificationDate else {
            return "0"
        }
        return String(Int64((date.timeIntervalSince1970 * 1000.0).rounded()))
    }

    static let initialCatalogPrefix = 4096

    static func makeCatalog(_ fetchResult: PHFetchResult<PHAsset>, reversed: Bool, prefix: Int = 0, onPrefix: ((ThumbnailCatalog) -> Void)? = nil) -> ThumbnailCatalog {
        var ids: [String] = []
        var versions: [String] = []
        ids.reserveCapacity(fetchResult.count)
        versions.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects(options: reversed ? .reverse : []) { asset, _, _ in
            ids.append(asset.localIdentifier)
            versions.append(MediaGridPhotoLibraryDataSource.version(of: asset))
            if ids.count == prefix, prefix < fetchResult.count {
                onPrefix?(ThumbnailCatalog(ids: ids, versions: versions))
            }
        }
        return ThumbnailCatalog(ids: ids, versions: versions)
    }

    private func installPlan(_ plan: ThumbnailFillPlan, removed: [String] = [], urgent: [String] = []) {
        guard let filler = self.filler?.filler else {
            return
        }
        self.planInstallCount += 1
        if self.fillStartTime == nil {
            self.fillStartTime = CACurrentMediaTime()
        }
        filler.install(plan, removed: removed, urgent: urgent)
    }

    private func fillProgressed() {
        if let filler = self.filler?.filler, filler.isComplete, self.fillDuration == nil, let start = self.fillStartTime {
            let duration = CACurrentMediaTime() - start
            self.fillDuration = duration
            self.onLog?(String(format: "THUMBS fill complete filled=%d unavailable=%d total=%d time=%.2fs", filler.filledCount, filler.unavailableCount, self.catalog.count, duration))
        }
    }

    private func thumbnailsChanged(_ ids: Set<String>) {
        self.filler?.filler.storeChanged(ids: ids)
        var indices = IndexSet()
        let hasCache = self.pageCache.count == self.catalog.count
        for id in ids {
            if let index = self.catalog.indexById[id] {
                indices.insert(index)
                if hasCache {
                    self.pageCache[index] = MediaGridPhotoLibraryDataSource.unknownPage
                }
            }
        }
        if let snapshot = self.launchSnapshot {
            for segment in snapshot.segments where segment.start + segment.ids.count > self.catalog.count {
                for (offset, id) in segment.ids.enumerated() where segment.start + offset >= self.catalog.count && ids.contains(id) {
                    indices.insert(segment.start + offset)
                }
            }
        }
        if !indices.isEmpty {
            self.onThumbnailsChanged?(indices)
        }
    }

    private func id(at index: Int) -> String? {
        if index < self.catalog.count {
            return self.catalog.id(at: index)
        }
        return self.launchSnapshot?.id(at: index)
    }

    public var catalogCount: Int {
        return self.catalog.count
    }

    public func hasStoredThumbnail(at index: Int) -> Bool {
        guard let id = self.id(at: index) else {
            return false
        }
        return self.store.version(for: id) != nil
    }

    public func thumbnail(at index: Int) -> MediaGridThumbnail? {
        guard let id = self.id(at: index) else {
            return nil
        }
        return self.store.thumbnail(for: id)
    }

    public func prepareThumbnails(ranges: [Range<Int>]) {
        self.preparedRanges = ranges
        self.launchKeeper?.viewportChanged(lowerBound: ranges.first?.lowerBound ?? 0)
        self.filler?.filler.setPriority(ranges: ranges)
        self.prepareStore()
        self.scheduleLaunchSnapshotSave()
    }

    private func resetPageCache() {
        self.pageCache = [Int32](repeating: MediaGridPhotoLibraryDataSource.unknownPage, count: self.catalog.count)
    }

    private func prepareStore() {
        let catalog = self.catalog
        if self.pageCache.count != catalog.count {
            self.resetPageCache()
        }
        var cache = self.pageCache
        self.pageCache = []
        let store = self.store
        var ids: [String] = []
        var seen = Set<Int32>()
        var last: Int32 = MediaGridPhotoLibraryDataSource.unknownPage
        let snapshot = self.launchSnapshot
        let upper = max(catalog.count, snapshot?.count ?? 0)
        outer: for range in self.preparedRanges {
            let clamped = range.clamped(to: 0 ..< upper)
            for index in clamped {
                var page: Int32
                let id: String
                if index < catalog.count {
                    id = catalog.ids[index]
                    page = cache[index]
                    if page == MediaGridPhotoLibraryDataSource.unknownPage {
                        page = store.page(for: id).map { Int32($0) } ?? -1
                        cache[index] = page
                    }
                } else if let snapshotId = snapshot?.id(at: index) {
                    id = snapshotId
                    page = store.page(for: id).map { Int32($0) } ?? -1
                } else {
                    continue
                }
                if page < 0 || page == last {
                    continue
                }
                last = page
                if seen.insert(page).inserted {
                    ids.append(id)
                    if ids.count >= MediaGridPhotoLibraryDataSource.preparePageLimit {
                        break outer
                    }
                }
            }
        }
        self.pageCache = cache
        store.prepare(ids: ids)
    }

    deinit {
        if self.store.hookOwner == nil {
            self.store.onThumbnailsChanged = nil
        }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    struct LibraryUpdate {
        var previous: PHFetchResult<PHAsset>
        var fetchResult: PHFetchResult<PHAsset>
        var changes: MediaGridChanges?
        var invalidatesAll: Bool
        var changedIdentifiers: [String]
        var removedIdentifiers: [String]
        var insertedIdentifiers: [String] = []
        var changedVersions: [String: String] = [:]
        var isAvailabilityOnly = false
        var availabilityIdentifiers: [String] = []
        var catalog = ThumbnailCatalog.empty
        var catalogGeneration = 0
        var plan: ThumbnailFillPlan?
    }

    private let changeQueue = DispatchQueue(label: "org.telegram.MediaGridPhotoLibrary.libraryChanges")
    private var observedFetchResult: PHFetchResult<PHAsset>
    private var observedCatalog = ThumbnailCatalog.empty
    private var observedCatalogGeneration = 0
    private var isStoreLoaded = false

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        self.changeQueue.sync {
            guard var update = MediaGridPhotoLibraryDataSource.update(for: changeInstance, previous: self.observedFetchResult, reversed: self.reversed) else {
                return
            }
            if let changes = update.changes, !changes.changed.isEmpty, self.observedCatalog.count == update.previous.count {
                let filtered = MediaGridPhotoLibraryDataSource.droppingUnversionedChanges(changes, changedIdentifiers: update.changedIdentifiers, newVersions: update.changedVersions, previous: self.observedCatalog)
                let kept = Set(filtered.changedIdentifiers)
                update.availabilityIdentifiers = update.changedIdentifiers.filter { !kept.contains($0) }
                update.changes = filtered.changes
                update.changedIdentifiers = filtered.changedIdentifiers
                update.isAvailabilityOnly = filtered.changes.isEmpty
            }
            if update.isAvailabilityOnly {
                update.catalog = self.observedCatalog
                update.catalogGeneration = self.observedCatalogGeneration
                self.observedFetchResult = update.fetchResult
                DispatchQueue.main.async { [weak self] in
                    self?.apply(update)
                }
                return
            }
            update.catalog = MediaGridPhotoLibraryDataSource.catalog(for: update, previous: self.observedCatalog, reversed: self.reversed)
            self.observedCatalogGeneration += 1
            update.catalogGeneration = self.observedCatalogGeneration
            self.observedCatalog = update.catalog
            if self.isStoreLoaded, let filler = self.filler?.filler {
                update.plan = filler.makePlan(for: update.catalog)
            }
            self.observedFetchResult = update.fetchResult
            DispatchQueue.main.async { [weak self] in
                self?.apply(update)
            }
        }
    }

    static func update(for change: PHChange, previous: PHFetchResult<PHAsset>, reversed: Bool) -> LibraryUpdate? {
        guard let details = change.changeDetails(for: previous) else {
            return nil
        }
        let fetchResult = details.fetchResultAfterChanges
        var update = LibraryUpdate(previous: previous, fetchResult: fetchResult, changes: nil, invalidatesAll: !details.hasIncrementalChanges, changedIdentifiers: [], removedIdentifiers: [])
        guard details.hasIncrementalChanges else {
            return update
        }
        update.changedIdentifiers = details.changedObjects.map { $0.localIdentifier }
        update.removedIdentifiers = details.removedObjects.map { $0.localIdentifier }
        update.insertedIdentifiers = details.insertedObjects.map { $0.localIdentifier }
        for asset in details.changedObjects {
            update.changedVersions[asset.localIdentifier] = MediaGridPhotoLibraryDataSource.version(of: asset)
        }
        if !details.hasMoves {
            update.changes = MediaGridPhotoLibraryDataSource.gridChanges(removed: details.removedIndexes ?? IndexSet(), inserted: details.insertedIndexes ?? IndexSet(), changed: details.changedIndexes ?? IndexSet(), oldCount: previous.count, newCount: fetchResult.count, reversed: reversed)
        }
        return update
    }

    static func droppingUnversionedChanges(_ changes: MediaGridChanges, changedIdentifiers: [String], newVersions: [String: String], previous: ThumbnailCatalog) -> (changes: MediaGridChanges, changedIdentifiers: [String]) {
        var result = changes
        var kept: [String] = []
        for id in changedIdentifiers {
            guard let oldIndex = previous.indexById[id], let version = newVersions[id], previous.versions[oldIndex] == version, let newIndex = changes.newIndex(forOld: oldIndex) else {
                kept.append(id)
                continue
            }
            result.changed.remove(newIndex)
        }
        return (result, kept)
    }

    static func catalog(for update: LibraryUpdate, previous: ThumbnailCatalog, reversed: Bool) -> ThumbnailCatalog {
        let fetchResult = update.fetchResult
        let count = fetchResult.count
        guard let changes = update.changes, previous.count == update.previous.count, changes.isValid(oldCount: previous.count, newCount: count) else {
            return MediaGridPhotoLibraryDataSource.makeCatalog(fetchResult, reversed: reversed)
        }
        return previous.applying(changes, newCount: count, entry: { index in
            let asset = fetchResult.object(at: MediaGridPhotoLibraryDataSource.fetchIndex(index, count: count, reversed: reversed))
            return (asset.localIdentifier, MediaGridPhotoLibraryDataSource.version(of: asset))
        })
    }

    private func swapFetchResult(_ update: LibraryUpdate) {
        self.fetchResult = update.fetchResult
        self.filler?.source.fetchResult = update.fetchResult
        self.catalog = update.catalog
        self.catalogGeneration = update.catalogGeneration
        self.launchSnapshot = nil
        if self.isLaunchInstalled {
            self.launchKeeper?.setHead(self.catalogHead())
        }
        if let plan = update.plan {
            self.installPlan(plan, removed: update.removedIdentifiers, urgent: update.insertedIdentifiers + update.changedIdentifiers)
        } else if !update.removedIdentifiers.isEmpty {
            self.store.remove(ids: update.removedIdentifiers)
            self.filler?.filler.registry.remove(ids: update.removedIdentifiers)
        }
        if !update.availabilityIdentifiers.isEmpty {
            self.filler?.filler.retryNow(ids: update.availabilityIdentifiers)
        }
        self.resetPageCache()
        self.prepareStore()
    }

    func apply(_ update: LibraryUpdate) {
        let isConsecutive = update.previous === self.fetchResult
        if update.invalidatesAll || !isConsecutive {
            self.revisionBase += 1
        }
        for identifier in update.changedIdentifiers {
            self.revisions[identifier, default: 0] += 1
        }
        for identifier in update.removedIdentifiers {
            self.revisions.removeValue(forKey: identifier)
        }
        if isConsecutive && update.isAvailabilityOnly {
            self.fetchResult = update.fetchResult
            self.filler?.source.fetchResult = update.fetchResult
            self.filler?.filler.retryNow(ids: update.availabilityIdentifiers)
            return
        }
        guard isConsecutive, let changes = update.changes else {
            self.scheduler.remapPrefetching({ _ in nil }, update: {
                self.swapFetchResult(update)
            })
            self.onChange?(nil)
            return
        }
        self.scheduler.remapPrefetching({ key in
            guard let index = changes.newIndex(forOld: key.index), !changes.changed.contains(index) else {
                return nil
            }
            return PrefetchKey(index: index, width: key.width, height: key.height)
        }, update: {
            self.swapFetchResult(update)
        })
        self.onChange?(changes)
    }

    static func gridChanges(removed: IndexSet, inserted: IndexSet, changed: IndexSet, oldCount: Int, newCount: Int, reversed: Bool) -> MediaGridChanges {
        guard reversed else {
            return MediaGridChanges(removed: removed, inserted: inserted, changed: changed)
        }
        let reverse: (IndexSet, Int) -> IndexSet = { indices, count in
            var result = IndexSet()
            for range in indices.rangeView {
                result.insert(integersIn: (count - range.upperBound) ..< (count - range.lowerBound))
            }
            return result
        }
        return MediaGridChanges(removed: reverse(removed, oldCount), inserted: reverse(inserted, newCount), changed: reverse(changed, newCount))
    }

    public var count: Int {
        return self.fetchResult.count
    }

    public func asset(at index: Int) -> PHAsset? {
        let count = self.fetchResult.count
        guard index >= 0, index < count else {
            return nil
        }
        return self.fetchResult.object(at: MediaGridPhotoLibraryDataSource.fetchIndex(index, count: count, reversed: self.reversed))
    }

    public func date(at index: Int) -> Date? {
        return self.asset(at: index)?.creationDate
    }

    public func aspectRatioReader() -> MediaGridAspectRatioReader {
        let fetchResult = self.fetchResult
        let reversed = self.reversed
        return { index in
            let count = fetchResult.count
            guard index >= 0, index < count else {
                return 1.0
            }
            let asset = fetchResult.object(at: MediaGridPhotoLibraryDataSource.fetchIndex(index, count: count, reversed: reversed))
            guard asset.pixelWidth > 0, asset.pixelHeight > 0 else {
                return 1.0
            }
            return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        }
    }

    func imageRevision(for identifier: String) -> Int {
        return self.revisionBase + (self.revisions[identifier] ?? 0)
    }

    private func key(for asset: PHAsset, size: CGSize) -> ImageKey {
        let identifier = asset.localIdentifier
        return ImageKey(identifier: identifier, width: Int(size.width), height: Int(size.height), revision: self.imageRevision(for: identifier))
    }

    public func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> MediaGridImageRequest? {
        guard let asset = self.asset(at: index) else {
            completion(nil, false)
            return nil
        }
        let targetSize = self.targetSize(at: index, pixelSize: pixelSize)
        let key = self.key(for: asset, size: targetSize)
        if let image = self.cache.object(forKey: key.cacheKey) {
            completion(image, false)
            return nil
        }
        return self.scheduler.request(key: key, payload: Load(asset: asset, targetSize: targetSize), completion: completion)
    }

    private func targetSize(at index: Int, pixelSize: CGSize) -> CGSize {
        return self.launchKeeper?.targetSize(at: index, pixelSize: pixelSize) ?? pixelSize
    }

    public func performBatch(_ updates: () -> Void) {
        self.scheduler.batch(updates)
    }

    public func startCaching(indices: [Int], pixelSize: CGSize) {
        self.scheduler.startPrefetching(self.prefetchKeys(indices: indices, pixelSize: pixelSize))
    }

    public func stopCaching(indices: [Int], pixelSize: CGSize) {
        self.scheduler.stopPrefetching(self.prefetchKeys(indices: indices, pixelSize: pixelSize))
    }

    private func prefetchKeys(indices: [Int], pixelSize: CGSize) -> [PrefetchKey] {
        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)
        return indices.map { PrefetchKey(index: $0, width: width, height: height) }
    }

    private func start(_ job: Scheduler.Job) {
        let attempt = job.attempt
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = job.usesNetwork
        let token = self.manager.requestImage(for: job.payload.asset, targetSize: job.payload.targetSize, contentMode: .aspectFill, options: options, resultHandler: { [weak self, weak job] image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            let handle: (UIImage?) -> Void = { image in
                guard let self, let job else {
                    return
                }
                self.handle(job, attempt: attempt, image: image, isDegraded: isDegraded, isCancelled: isCancelled, isInCloud: isInCloud)
            }
            if let image, !isDegraded, Thread.isMainThread, let job, job.hasConsumers(running: attempt), MediaGridPhotoLibraryDataSource.needsPreparation(image) {
                MediaGridPhotoLibraryDataSource.enqueuePreparation(image, job: job, attempt: attempt, queue: MediaGridPhotoLibraryDataSource.preparationQueue, prepare: MediaGridPhotoLibraryDataSource.prepare, deliver: handle)
            } else if Thread.isMainThread {
                handle(image)
            } else {
                DispatchQueue.main.async {
                    handle(image)
                }
            }
        })
        if job.state == .running && job.attempt == attempt {
            job.token = token
        }
    }

    static let harvestQueue = DispatchQueue(label: "org.telegram.MediaGridPhotoLibrary.thumbnailHarvest", qos: .utility)

    private func harvest(_ image: UIImage, id: String) {
        guard let filler = self.filler?.filler, let version = filler.harvestVersion(for: id) else {
            return
        }
        MediaGridPhotoLibraryDataSource.harvestQueue.async { [weak self] in
            guard let small = ThumbnailDownscaler.image(from: image) else {
                return
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.harvests += 1
                filler.harvest(id: id, version: version, image: small)
            }
        }
    }

    public private(set) var harvests = 0

    static let preparationQueue = DispatchQueue(label: "org.telegram.MediaGridPhotoLibrary.imagePreparation", qos: .userInitiated)
    static let preparationMinPixels = 512 * 512

    static func enqueuePreparation<K, P, L>(_ image: UIImage, job: ImageLoadScheduler<K, P, L>.Job, attempt: Int, queue: DispatchQueue, prepare: @escaping (UIImage) -> UIImage, deliver: @escaping (UIImage) -> Void) {
        queue.async { [weak job] in
            let prepared = job?.hasConsumers(running: attempt) == true ? prepare(image) : image
            DispatchQueue.main.async {
                deliver(prepared)
            }
        }
    }

    static func needsPreparation(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }
        return cgImage.width * cgImage.height >= MediaGridPhotoLibraryDataSource.preparationMinPixels
    }

    static func prepare(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        format.preferredRange = .automatic
        let size = CGSize(width: round(image.size.width * image.scale), height: round(image.size.height * image.scale))
        guard size.width > 0.0, size.height > 0.0 else {
            return image
        }
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let renderedImage = rendered.cgImage else {
            return image
        }
        return UIImage(cgImage: renderedImage, scale: image.scale, orientation: .up)
    }

    private func handle(_ job: Scheduler.Job, attempt: Int, image: UIImage?, isDegraded: Bool, isCancelled: Bool, isInCloud: Bool) {
        if isCancelled {
            self.scheduler.cancelledExternally(job, attempt: attempt)
            return
        }
        if isDegraded {
            if let image {
                self.scheduler.deliverDegraded(job, attempt: attempt, image: image)
            }
            return
        }
        if image == nil && isInCloud && self.scheduler.moveToNetwork(job, attempt: attempt) {
            return
        }
        if let image, let cgImage = image.cgImage, job.state == .running, job.attempt == attempt {
            self.cache.setObject(image, forKey: job.key.cacheKey, cost: cgImage.bytesPerRow * cgImage.height)
            self.harvest(image, id: job.key.identifier)
            if job.key.revision == self.imageRevision(for: job.key.identifier) {
                self.launchKeeper?.delivered(id: job.key.identifier, image: cgImage)
            }
        }
        self.scheduler.finish(job, attempt: attempt, image: image)
    }
}
