import Foundation
import CoreGraphics
import ImageIO
import UIKit

public final class MediaGridThumbnailStore {
    private struct IndexEntry {
        var slot: Int
        var version: String
        var contentsRect: CGRect
    }

    private struct SlotGeometry {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    private struct Placement: Equatable {
        let slot: Int
        let rect: CGRect
    }

    private struct PageImage {
        let image: CGImage
        let generation: Int
    }

    private enum PendingOperation {
        case write(CGImage, String, String)
        case remove([String])
    }

    private struct LoadedState {
        var index: [String: IndexEntry] = [:]
        var placements: [String: Placement] = [:]
        var slotOwners: [Int: String] = [:]
        var freeSlots: [Int] = []
        var nextSlot = 0
        var pageFiles: [Int: UInt64] = [:]
    }

    static let indexFileName = "index.bin"
    static let pageQuality: CGFloat = 0.8

    private let directory: URL?
    private let slotPixelSize: Int
    private let pageSide: Int
    private let decodedPageBudget: Int
    private let slotsPerPage: Int
    private let pagePixelSize: Int
    let writerContextLimit: Int
    let pageImageCapacity: Int
    private let maxConcurrentDecodes = 3

    private let lock = NSLock()
    private var index: [String: IndexEntry] = [:]
    private var freeSlots: [Int] = []
    private var nextSlot = 0
    private var isLoaded: Bool
    private var isLoadStarted = false
    private var loadCompletions: [() -> Void] = []
    private var pendingOperations: [PendingOperation] = []
    private var isIndexDirty = false
    private var pageGenerations: [Int: Int] = [:]
    private var diskGenerations: [Int: Int] = [:]
    private var pageFiles: [Int: UInt64] = [:]
    private var flushDelay: Double = 2.0

    private let queue = DispatchQueue(label: "org.telegram.MediaGridThumbnailStore")
    private var contexts: [Int: CGContext] = [:]
    private var contextUses: [Int: Int] = [:]
    private var contextTick = 0
    private var snapshotGenerations: [Int: Int] = [:]
    private var stashedImages: [Int: PageImage] = [:]
    private var dirtyPages = Set<Int>()
    private var pendingPlacements: [String: Placement] = [:]
    private var pendingRemovals = Set<String>()
    private var isPublishScheduled = false
    private var isDiskFlushScheduled = false
    private var lastFlushTime: Double = -1.0
    private let minimumPublishInterval: Double = 1.0 / 60.0

    private let ioQueue = DispatchQueue(label: "org.telegram.MediaGridThumbnailStore.io", qos: .utility)
    private var nextStamp: UInt64 = 1
    private var supersededFiles: [URL] = []

    private let decodeQueue = DispatchQueue(label: "org.telegram.MediaGridThumbnailStore.decode", qos: .userInitiated, attributes: .concurrent)

    private var placements: [String: Placement] = [:]
    private var slotOwners: [Int: String] = [:]
    private var pageImages: [Int: PageImage] = [:]
    private var pageUses: [Int: Int] = [:]
    private var useTick = 0
    private var decodeStack: [Int] = []
    private var decodesInFlight = Set<Int>()
    private var isPrepareTurnOpen = false
    private var visibleIds = Set<String>()
    private var observers: [NSObjectProtocol] = []

    public var onThumbnailsChanged: ((Set<String>) -> Void)?
    var didDecodePage: ((Int, Bool) -> Void)?

    public init(directory: URL?, slotPixelSize: Int = 48, pageSide: Int = 16, decodedPageBudget: Int = 32) {
        self.directory = directory
        self.slotPixelSize = slotPixelSize
        self.pageSide = pageSide
        self.decodedPageBudget = decodedPageBudget
        self.slotsPerPage = pageSide * pageSide
        self.pagePixelSize = pageSide * slotPixelSize
        self.writerContextLimit = min(4, max(1, decodedPageBudget / 4))
        self.pageImageCapacity = max(1, decodedPageBudget - self.writerContextLimit)
        self.isLoaded = directory == nil

        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil, using: { [weak self] _ in
            MediaGridThumbnailStore.onMain {
                self?.handleMemoryWarning()
            }
        }))
        self.observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            MediaGridThumbnailStore.onMain {
                self?.handleBackground()
            }
        }))
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var diskFlushDelay: Double {
        get {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.flushDelay
        }
        set {
            self.lock.lock()
            self.flushDelay = newValue
            self.lock.unlock()
        }
    }

    public var decodedPageCount: Int {
        dispatchPrecondition(condition: .onQueue(.main))
        return self.pageImages.count
    }

    func writerContextCount() -> Int {
        return self.queue.sync {
            self.contexts.count
        }
    }

    public func version(for id: String) -> String? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.index[id]?.version
    }

    public func thumbnail(for id: String) -> MediaGridThumbnail? {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        guard let placement = self.placements[id] else {
            return nil
        }
        let page = placement.slot / self.slotsPerPage
        guard let image = self.pageImages[page]?.image else {
            return nil
        }
        self.touch(page: page)
        return MediaGridThumbnail(image: image, contentsRect: placement.rect)
    }

    public func write(_ image: CGImage, id: String, version: String) {
        guard image.width > 0, image.height > 0 else {
            return
        }
        self.lock.lock()
        if !self.isLoaded {
            self.pendingOperations.append(.write(image, id, version))
            self.lock.unlock()
            return
        }
        let slot: Int
        if let entry = self.index[id] {
            slot = entry.slot
        } else if !self.freeSlots.isEmpty {
            slot = self.freeSlots.removeFirst()
        } else {
            slot = self.nextSlot
            self.nextSlot += 1
        }
        let geometry = self.geometry(slot: slot, imageWidth: image.width, imageHeight: image.height)
        let contentsRect = self.unitRect(x: geometry.x, y: geometry.y, width: geometry.width, height: geometry.height)
        self.index[id] = IndexEntry(slot: slot, version: version, contentsRect: contentsRect)
        self.isIndexDirty = true
        self.queue.async {
            self.draw(image, id: id, slot: slot, geometry: geometry, contentsRect: contentsRect)
        }
        self.lock.unlock()
    }

    public func remove(ids: [String]) {
        var removed: [(String, Int)] = []
        self.lock.lock()
        if !self.isLoaded {
            self.pendingOperations.append(.remove(ids))
            self.lock.unlock()
            return
        }
        for id in ids {
            guard let entry = self.index.removeValue(forKey: id) else {
                continue
            }
            removed.append((id, entry.slot))
            self.freeSlot(entry.slot)
        }
        if !removed.isEmpty {
            self.isIndexDirty = true
            self.queue.async {
                for (id, slot) in removed {
                    self.clear(id: id, slot: slot)
                }
            }
        }
        self.lock.unlock()
        if removed.isEmpty {
            return
        }
        MediaGridThumbnailStore.onMain {
            for (id, slot) in removed {
                if self.placements[id]?.slot == slot {
                    self.placements.removeValue(forKey: id)
                }
                if self.slotOwners[slot] == id {
                    self.slotOwners.removeValue(forKey: slot)
                }
            }
        }
    }

    public func load(completion: @escaping () -> Void) {
        self.lock.lock()
        if self.isLoaded {
            self.lock.unlock()
            DispatchQueue.main.async(execute: completion)
            return
        }
        self.loadCompletions.append(completion)
        let start = !self.isLoadStarted
        self.isLoadStarted = true
        self.lock.unlock()
        guard start, let directory = self.directory else {
            return
        }
        self.ioQueue.async {
            let state = self.readState(directory: directory)
            DispatchQueue.main.async {
                self.apply(state)
            }
        }
    }

    public func prepare(ids: [String]) {
        dispatchPrecondition(condition: .onQueue(.main))
        if !self.isPrepareTurnOpen {
            self.isPrepareTurnOpen = true
            self.decodeStack.removeAll()
            DispatchQueue.main.async {
                self.isPrepareTurnOpen = false
            }
        }
        var seen = Set<Int>()
        var wanted: [Int] = []
        for id in ids {
            guard let placement = self.placements[id] else {
                continue
            }
            let page = placement.slot / self.slotsPerPage
            guard seen.insert(page).inserted else {
                continue
            }
            if self.pageImages[page] != nil {
                self.touch(page: page)
            } else if !self.decodesInFlight.contains(page) {
                wanted.append(page)
            }
        }
        if wanted.count > self.pageImageCapacity {
            wanted.removeLast(wanted.count - self.pageImageCapacity)
        }
        let wantedSet = Set(wanted)
        self.decodeStack.removeAll { wantedSet.contains($0) }
        self.decodeStack.append(contentsOf: wanted.reversed())
        self.startDecodes()
    }

    public func flush(completion: (() -> Void)?) {
        self.requestDiskFlush {
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    public func trimToVisible(ids: Set<String>) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.visibleIds = ids
        self.trim()
    }

    static func encodePage(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: MediaGridThumbnailStore.pageQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    static func decodePage(_ data: Data) -> CGImage? {
        guard !data.isEmpty, let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func touch(page: Int) {
        self.useTick += 1
        self.pageUses[page] = self.useTick
    }

    private func freeSlot(_ slot: Int) {
        let insertion = self.freeSlots.firstIndex(where: { $0 > slot }) ?? self.freeSlots.count
        self.freeSlots.insert(slot, at: insertion)
    }

    private func unitRect(x: Int, y: Int, width: Int, height: Int) -> CGRect {
        let unit = 1.0 / CGFloat(max(1, self.pagePixelSize))
        return CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: CGFloat(width) * unit, height: CGFloat(height) * unit)
    }

    private func geometry(slot: Int, imageWidth: Int, imageHeight: Int) -> SlotGeometry {
        let size = self.slotPixelSize
        let aspect = min(2.0, max(0.5, CGFloat(imageWidth) / CGFloat(imageHeight)))
        let width = aspect >= 1.0 ? size : max(1, Int((CGFloat(size) * aspect).rounded()))
        let height = aspect >= 1.0 ? max(1, Int((CGFloat(size) / aspect).rounded())) : size
        let origin = self.slotOrigin(slot)
        return SlotGeometry(x: origin.x + (size - width) / 2, y: origin.y + (size - height) / 2, width: width, height: height)
    }

    private func slotOrigin(_ slot: Int) -> (x: Int, y: Int) {
        let local = slot % self.slotsPerPage
        return ((local % self.pageSide) * self.slotPixelSize, (local / self.pageSide) * self.slotPixelSize)
    }

    private func flippedRect(x: Int, y: Int, width: Int, height: Int) -> CGRect {
        return CGRect(x: x, y: self.pagePixelSize - y - height, width: width, height: height)
    }

    private func pageURL(directory: URL, page: Int, stamp: UInt64) -> URL {
        return directory.appendingPathComponent("\(page)-\(stamp).jpg")
    }

    private func isFlushed(page: Int) -> Bool {
        return (self.pageGenerations[page] ?? 0) == (self.diskGenerations[page] ?? 0)
    }

    private func idsInPage(_ page: Int) -> [String] {
        let range = page * self.slotsPerPage ..< (page + 1) * self.slotsPerPage
        return self.index.compactMap { range.contains($0.value.slot) ? $0.key : nil }
    }

    private func readState(directory: URL) -> LoadedState {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var state = LoadedState()
        let indexURL = directory.appendingPathComponent(MediaGridThumbnailStore.indexFileName)
        var file: MediaGridThumbnailIndexFile?
        if let data = try? Data(contentsOf: indexURL, options: .mappedIfSafe) {
            file = MediaGridThumbnailIndexFile.decode(data, slotPixelSize: self.slotPixelSize, pageSide: self.pageSide)
        }
        if let file {
            state.pageFiles = file.pages
            self.nextStamp = file.nextStamp
            state.index.reserveCapacity(file.entries.count)
            state.placements.reserveCapacity(file.entries.count)
            state.slotOwners.reserveCapacity(file.entries.count)
            var maxSlot = -1
            for entry in file.entries where file.pages[entry.slot / self.slotsPerPage] != nil {
                let rect = self.unitRect(x: entry.x, y: entry.y, width: entry.width, height: entry.height)
                state.index[entry.id] = IndexEntry(slot: entry.slot, version: entry.version, contentsRect: rect)
                state.placements[entry.id] = Placement(slot: entry.slot, rect: rect)
                state.slotOwners[entry.slot] = entry.id
                maxSlot = max(maxSlot, entry.slot)
            }
            state.nextSlot = maxSlot + 1
            if state.slotOwners.count < state.nextSlot {
                state.freeSlots.reserveCapacity(state.nextSlot - state.slotOwners.count)
                for slot in 0 ..< state.nextSlot where state.slotOwners[slot] == nil {
                    state.freeSlots.append(slot)
                }
            }
        } else {
            self.nextStamp = 1
            try? fileManager.removeItem(at: indexURL)
        }
        let referenced = Set(state.pageFiles.map { "\($0.key)-\($0.value).jpg" })
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name != MediaGridThumbnailStore.indexFileName && !referenced.contains(name) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
        return state
    }

    private func apply(_ state: LoadedState) {
        self.lock.lock()
        self.index = state.index
        self.freeSlots = state.freeSlots
        self.nextSlot = state.nextSlot
        self.pageFiles = state.pageFiles
        self.isLoaded = true
        let operations = self.pendingOperations
        self.pendingOperations = []
        let completions = self.loadCompletions
        self.loadCompletions = []
        self.lock.unlock()
        self.placements = state.placements
        self.slotOwners = state.slotOwners
        for operation in operations {
            switch operation {
            case let .write(image, id, version):
                self.write(image, id: id, version: version)
            case let .remove(ids):
                self.remove(ids: ids)
            }
        }
        for completion in completions {
            completion()
        }
    }

    private func handleMemoryWarning() {
        self.trim()
    }

    private func handleBackground() {
        self.flush {
            self.trim()
        }
    }

    private func trim() {
        var keep = Set<Int>()
        for id in self.visibleIds {
            if let placement = self.placements[id] {
                keep.insert(placement.slot / self.slotsPerPage)
            }
        }
        self.decodeStack.removeAll { !keep.contains($0) }
        if self.directory != nil {
            self.lock.lock()
            let victims = self.pageImages.keys.filter { !keep.contains($0) && self.isFlushed(page: $0) }
            self.lock.unlock()
            for page in victims {
                self.pageImages.removeValue(forKey: page)
                self.pageUses.removeValue(forKey: page)
            }
        }
        self.queue.async {
            self.dropCleanContexts()
        }
    }

    private func install(page: Int, image: PageImage) -> Bool {
        if let current = self.pageImages[page], current.generation > image.generation {
            return false
        }
        let isNew = self.pageImages[page] == nil
        self.pageImages[page] = image
        self.touch(page: page)
        self.evictPageImages(protecting: page)
        return isNew
    }

    private func evictPageImages(protecting page: Int) {
        guard self.directory != nil, self.pageImages.count > self.pageImageCapacity else {
            return
        }
        self.lock.lock()
        var candidates = self.pageImages.keys.filter { $0 != page && self.isFlushed(page: $0) }
        self.lock.unlock()
        candidates.sort { (self.pageUses[$0] ?? 0) < (self.pageUses[$1] ?? 0) }
        for victim in candidates {
            if self.pageImages.count <= self.pageImageCapacity {
                break
            }
            self.pageImages.removeValue(forKey: victim)
            self.pageUses.removeValue(forKey: victim)
        }
    }

    private func owners(page: Int) -> Set<String> {
        var ids = Set<String>()
        let base = page * self.slotsPerPage
        for slot in base ..< base + self.slotsPerPage {
            if let id = self.slotOwners[slot], self.placements[id]?.slot == slot {
                ids.insert(id)
            }
        }
        return ids
    }

    private func startDecodes() {
        while self.decodesInFlight.count < self.maxConcurrentDecodes, let page = self.decodeStack.popLast() {
            if self.pageImages[page] != nil || self.decodesInFlight.contains(page) {
                continue
            }
            self.decodesInFlight.insert(page)
            self.decodeQueue.async {
                self.decode(page: page)
            }
        }
    }

    private func decode(page: Int) {
        self.didDecodePage?(page, Thread.isMainThread)
        while true {
            self.lock.lock()
            let flushed = self.isFlushed(page: page)
            let generation = self.diskGenerations[page] ?? 0
            let stamp = self.pageFiles[page]
            self.lock.unlock()
            if !flushed {
                self.queue.async {
                    self.republish(page: page)
                }
                self.finishDecode(page: page, image: nil, lost: [])
                return
            }
            guard let directory = self.directory else {
                self.finishDecode(page: page, image: nil, lost: [])
                return
            }
            var image: CGImage?
            var url: URL?
            if let stamp {
                url = self.pageURL(directory: directory, page: page, stamp: stamp)
                if let data = try? Data(contentsOf: url!), let decoded = MediaGridThumbnailStore.decodePage(data), decoded.width == self.pagePixelSize, decoded.height == self.pagePixelSize {
                    image = decoded
                }
            }
            if let image {
                self.finishDecode(page: page, image: PageImage(image: image, generation: generation), lost: [])
                return
            }
            self.lock.lock()
            if self.pageFiles[page] != stamp {
                self.lock.unlock()
                continue
            }
            var lost: [String] = []
            if self.isFlushed(page: page) {
                self.pageFiles.removeValue(forKey: page)
                lost = self.idsInPage(page)
            }
            self.lock.unlock()
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            self.finishDecode(page: page, image: nil, lost: lost)
            return
        }
    }

    private func finishDecode(page: Int, image: PageImage?, lost: [String]) {
        DispatchQueue.main.async {
            self.decodesInFlight.remove(page)
            if let image, self.install(page: page, image: image) {
                let ids = self.owners(page: page)
                if !ids.isEmpty {
                    self.onThumbnailsChanged?(ids)
                }
            }
            if !lost.isEmpty {
                self.remove(ids: lost)
            }
            self.startDecodes()
        }
    }

    private func bumpGeneration(page: Int) {
        self.lock.lock()
        self.pageGenerations[page, default: 0] += 1
        self.lock.unlock()
    }

    private func generation(page: Int) -> Int {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.pageGenerations[page] ?? 0
    }

    private func isContextClean(page: Int) -> Bool {
        return self.generation(page: page) == (self.snapshotGenerations[page] ?? 0)
    }

    private func context(page: Int) -> CGContext? {
        if let context = self.contexts[page] {
            self.contextTick += 1
            self.contextUses[page] = self.contextTick
            return context
        }
        let side = self.pagePixelSize
        guard side > 0, let space = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        self.evictContexts(excluding: page)
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: side, height: side))
        if let directory = self.directory {
            self.ioQueue.sync {}
            self.lock.lock()
            let stamp = self.pageFiles[page]
            self.lock.unlock()
            if let stamp {
                let url = self.pageURL(directory: directory, page: page, stamp: stamp)
                if let data = try? Data(contentsOf: url), let image = MediaGridThumbnailStore.decodePage(data), image.width == side, image.height == side {
                    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
                } else {
                    self.lock.lock()
                    self.pageFiles.removeValue(forKey: page)
                    let lost = self.idsInPage(page)
                    self.lock.unlock()
                    try? FileManager.default.removeItem(at: url)
                    self.remove(ids: lost)
                }
            }
        }
        self.contexts[page] = context
        self.contextTick += 1
        self.contextUses[page] = self.contextTick
        return context
    }

    private func evictContexts(excluding page: Int) {
        guard self.directory != nil else {
            return
        }
        while self.contexts.count >= self.writerContextLimit {
            guard let victim = self.contexts.keys.filter({ $0 != page }).min(by: { (self.contextUses[$0] ?? 0) < (self.contextUses[$1] ?? 0) }) else {
                return
            }
            if !self.isContextClean(page: victim) {
                self.snapshotToDisk(pages: [victim])
            }
            self.dropContext(page: victim)
        }
    }

    private func dropContext(page: Int) {
        guard let context = self.contexts.removeValue(forKey: page) else {
            return
        }
        self.contextUses.removeValue(forKey: page)
        if self.dirtyPages.contains(page), let image = context.makeImage() {
            self.stashedImages[page] = PageImage(image: image, generation: self.generation(page: page))
        }
    }

    private func dropCleanContexts() {
        guard self.directory != nil else {
            return
        }
        for page in Array(self.contexts.keys) where self.isContextClean(page: page) {
            self.dropContext(page: page)
        }
    }

    private func republish(page: Int) {
        guard self.context(page: page) != nil else {
            return
        }
        self.dirtyPages.insert(page)
        self.schedulePublish()
    }

    private func draw(_ image: CGImage, id: String, slot: Int, geometry: SlotGeometry, contentsRect: CGRect) {
        let page = slot / self.slotsPerPage
        guard let context = self.context(page: page) else {
            self.lock.lock()
            if self.index[id]?.slot == slot {
                self.index.removeValue(forKey: id)
                self.freeSlot(slot)
            }
            self.lock.unlock()
            return
        }
        let size = self.slotPixelSize
        let origin = self.slotOrigin(slot)
        context.clear(self.flippedRect(x: origin.x, y: origin.y, width: size, height: size))
        let target = self.flippedRect(x: geometry.x, y: geometry.y, width: geometry.width, height: geometry.height)
        let scale = max(target.width / CGFloat(image.width), target.height / CGFloat(image.height))
        let drawn = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.saveGState()
        context.clip(to: target)
        context.draw(image, in: CGRect(x: target.midX - drawn.width / 2.0, y: target.midY - drawn.height / 2.0, width: drawn.width, height: drawn.height))
        context.restoreGState()
        self.bumpGeneration(page: page)
        self.pendingPlacements[id] = Placement(slot: slot, rect: contentsRect)
        self.dirtyPages.insert(page)
        self.schedulePublish()
        self.scheduleDiskFlush()
    }

    private func clear(id: String, slot: Int) {
        let page = slot / self.slotsPerPage
        if self.pendingPlacements[id]?.slot == slot {
            self.pendingPlacements.removeValue(forKey: id)
        }
        self.pendingRemovals.insert(id)
        if let context = self.contexts[page] {
            let origin = self.slotOrigin(slot)
            context.clear(self.flippedRect(x: origin.x, y: origin.y, width: self.slotPixelSize, height: self.slotPixelSize))
            self.bumpGeneration(page: page)
            self.dirtyPages.insert(page)
        }
        self.schedulePublish()
        self.scheduleDiskFlush()
    }

    private func schedulePublish() {
        if self.isPublishScheduled {
            return
        }
        self.isPublishScheduled = true
        let delay = max(0.0, self.lastFlushTime + self.minimumPublishInterval - CFAbsoluteTimeGetCurrent())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.queue.async {
                self.publishPending()
            }
        }
    }

    private func publishPending() {
        var images: [Int: PageImage] = [:]
        for page in self.dirtyPages {
            if let context = self.contexts[page], let image = context.makeImage() {
                images[page] = PageImage(image: image, generation: self.generation(page: page))
            } else if let stashed = self.stashedImages[page] {
                images[page] = stashed
            }
        }
        let changes = self.pendingPlacements
        let removals = self.pendingRemovals
        self.dirtyPages.removeAll()
        self.stashedImages.removeAll()
        self.pendingPlacements.removeAll()
        self.pendingRemovals.removeAll()
        self.isPublishScheduled = false
        self.lastFlushTime = CFAbsoluteTimeGetCurrent()
        DispatchQueue.main.async {
            self.publish(images: images, changes: changes, removals: removals)
        }
    }

    private func publish(images: [Int: PageImage], changes: [String: Placement], removals: Set<String>) {
        dispatchPrecondition(condition: .onQueue(.main))
        var changed = removals
        var newPages: [Int] = []
        for (page, image) in images {
            if self.install(page: page, image: image) {
                newPages.append(page)
            }
        }
        self.lock.lock()
        for (id, placement) in changes where self.index[id]?.slot == placement.slot {
            self.placements[id] = placement
            self.slotOwners[placement.slot] = id
            changed.insert(id)
        }
        self.lock.unlock()
        for page in newPages where self.pageImages[page] != nil {
            changed.formUnion(self.owners(page: page))
        }
        if !changed.isEmpty {
            self.onThumbnailsChanged?(changed)
        }
    }

    private func scheduleDiskFlush() {
        guard self.directory != nil, !self.isDiskFlushScheduled else {
            return
        }
        self.isDiskFlushScheduled = true
        self.queue.asyncAfter(deadline: .now() + self.diskFlushDelay) {
            self.requestDiskFlush(completion: nil)
        }
    }

    private func requestDiskFlush(completion: (() -> Void)?) {
        guard let directory = self.directory else {
            completion?()
            return
        }
        self.lock.lock()
        guard self.isLoaded else {
            self.lock.unlock()
            completion?()
            return
        }
        let snapshot = self.index
        let isIndexDirty = self.isIndexDirty
        self.isIndexDirty = false
        self.queue.async {
            self.performDiskFlush(directory: directory, snapshot: snapshot, isIndexDirty: isIndexDirty, completion: completion)
        }
        self.lock.unlock()
    }

    private func performDiskFlush(directory: URL, snapshot: [String: IndexEntry], isIndexDirty: Bool, completion: (() -> Void)?) {
        self.isDiskFlushScheduled = false
        let pages = self.contexts.keys.filter { !self.isContextClean(page: $0) }
        self.snapshotToDisk(pages: pages)
        let writeIndex = isIndexDirty || !pages.isEmpty
        self.ioQueue.async {
            if writeIndex {
                self.writeIndex(directory: directory, snapshot: snapshot)
            }
            completion?()
        }
    }

    private func snapshotToDisk(pages: [Int]) {
        guard let directory = self.directory else {
            return
        }
        for page in pages {
            guard let image = self.contexts[page]?.makeImage() else {
                continue
            }
            let generation = self.generation(page: page)
            self.snapshotGenerations[page] = generation
            self.ioQueue.async {
                self.writePage(directory: directory, page: page, image: image, generation: generation)
            }
        }
    }

    private func writePage(directory: URL, page: Int, image: CGImage, generation: Int) {
        guard let data = MediaGridThumbnailStore.encodePage(image) else {
            return
        }
        let stamp = self.nextStamp
        self.nextStamp += 1
        do {
            try data.write(to: self.pageURL(directory: directory, page: page, stamp: stamp), options: .atomic)
        } catch {
            return
        }
        self.lock.lock()
        let previous = self.pageFiles[page]
        self.pageFiles[page] = stamp
        if generation > (self.diskGenerations[page] ?? 0) {
            self.diskGenerations[page] = generation
        }
        self.isIndexDirty = true
        self.lock.unlock()
        if let previous {
            self.supersededFiles.append(self.pageURL(directory: directory, page: page, stamp: previous))
        }
    }

    private func writeIndex(directory: URL, snapshot: [String: IndexEntry]) {
        self.lock.lock()
        let pages = self.pageFiles
        self.lock.unlock()
        var entries: [MediaGridThumbnailIndexFile.Entry] = []
        entries.reserveCapacity(snapshot.count)
        let side = CGFloat(self.pagePixelSize)
        for (id, entry) in snapshot where pages[entry.slot / self.slotsPerPage] != nil {
            let rect = entry.contentsRect
            entries.append(MediaGridThumbnailIndexFile.Entry(id: id, version: entry.version, slot: entry.slot, x: Int((rect.minX * side).rounded()), y: Int((rect.minY * side).rounded()), width: Int((rect.width * side).rounded()), height: Int((rect.height * side).rounded())))
        }
        let file = MediaGridThumbnailIndexFile(slotPixelSize: self.slotPixelSize, pageSide: self.pageSide, nextStamp: self.nextStamp, pages: pages, entries: entries)
        do {
            try file.encoded().write(to: directory.appendingPathComponent(MediaGridThumbnailStore.indexFileName), options: .atomic)
        } catch {
            return
        }
        for url in self.supersededFiles {
            try? FileManager.default.removeItem(at: url)
        }
        self.supersededFiles.removeAll()
    }
}
