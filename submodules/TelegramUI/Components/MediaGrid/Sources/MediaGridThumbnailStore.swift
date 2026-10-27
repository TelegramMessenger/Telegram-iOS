import Foundation
import CoreGraphics

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

    private let directory: URL?
    private let slotPixelSize: Int
    private let pageSide: Int
    private let decodedPageBudget: Int
    private let slotsPerPage: Int
    private let pagePixelSize: Int

    private let lock = NSLock()
    private var index: [String: IndexEntry] = [:]
    private var freeSlots: [Int] = []
    private var nextSlot = 0

    private let queue = DispatchQueue(label: "org.telegram.MediaGridThumbnailStore")
    private var contexts: [Int: CGContext] = [:]
    private var dirtyPages = Set<Int>()
    private var pendingPlacements: [String: Placement] = [:]
    private var pendingRemovals = Set<String>()
    private var isPublishScheduled = false
    private var lastFlushTime: Double = -1.0
    private let minimumPublishInterval: Double = 1.0 / 60.0

    private var placements: [String: Placement] = [:]
    private var pageImages: [Int: CGImage] = [:]

    public var onThumbnailsChanged: ((Set<String>) -> Void)?

    public init(directory: URL?, slotPixelSize: Int = 48, pageSide: Int = 16, decodedPageBudget: Int = 32) {
        self.directory = directory
        self.slotPixelSize = slotPixelSize
        self.pageSide = pageSide
        self.decodedPageBudget = decodedPageBudget
        self.slotsPerPage = pageSide * pageSide
        self.pagePixelSize = pageSide * slotPixelSize
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
        guard let placement = self.placements[id], let image = self.pageImages[placement.slot / self.slotsPerPage] else {
            return nil
        }
        return MediaGridThumbnail(image: image, contentsRect: placement.rect)
    }

    public func write(_ image: CGImage, id: String, version: String) {
        guard image.width > 0, image.height > 0 else {
            return
        }
        self.lock.lock()
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
        let unit = 1.0 / CGFloat(max(1, self.pagePixelSize))
        let contentsRect = CGRect(x: CGFloat(geometry.x) * unit, y: CGFloat(geometry.y) * unit, width: CGFloat(geometry.width) * unit, height: CGFloat(geometry.height) * unit)
        self.index[id] = IndexEntry(slot: slot, version: version, contentsRect: contentsRect)
        self.queue.async {
            self.draw(image, id: id, slot: slot, geometry: geometry, contentsRect: contentsRect)
        }
        self.lock.unlock()
    }

    public func remove(ids: [String]) {
        var removed: [(String, Int)] = []
        self.lock.lock()
        for id in ids {
            guard let entry = self.index.removeValue(forKey: id) else {
                continue
            }
            removed.append((id, entry.slot))
            self.freeSlot(entry.slot)
        }
        if !removed.isEmpty {
            self.queue.async {
                for (id, slot) in removed {
                    self.clear(id: id, slot: slot)
                }
            }
        }
        self.lock.unlock()
        let drop = {
            for (id, _) in removed {
                self.placements.removeValue(forKey: id)
            }
        }
        if Thread.isMainThread {
            drop()
        } else {
            DispatchQueue.main.async(execute: drop)
        }
    }

    private func freeSlot(_ slot: Int) {
        let insertion = self.freeSlots.firstIndex(where: { $0 > slot }) ?? self.freeSlots.count
        self.freeSlots.insert(slot, at: insertion)
    }

    private func geometry(slot: Int, imageWidth: Int, imageHeight: Int) -> SlotGeometry {
        let size = self.slotPixelSize
        let aspect = min(2.0, max(0.5, CGFloat(imageWidth) / CGFloat(imageHeight)))
        let width = aspect >= 1.0 ? size : max(1, Int((CGFloat(size) * aspect).rounded()))
        let height = aspect >= 1.0 ? max(1, Int((CGFloat(size) / aspect).rounded())) : size
        let origin = self.slotOrigin(slot)
        return SlotGeometry(x: origin.x + (size - width) / 2, y: origin.y + (size - height) / 2, width: width, height: height)
    }

    private func context(page: Int) -> CGContext? {
        if let context = self.contexts[page] {
            return context
        }
        let side = self.pagePixelSize
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: side, height: side))
        self.contexts[page] = context
        return context
    }

    private func slotOrigin(_ slot: Int) -> (x: Int, y: Int) {
        let local = slot % self.slotsPerPage
        return ((local % self.pageSide) * self.slotPixelSize, (local / self.pageSide) * self.slotPixelSize)
    }

    private func flippedRect(x: Int, y: Int, width: Int, height: Int) -> CGRect {
        return CGRect(x: x, y: self.pagePixelSize - y - height, width: width, height: height)
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
        self.pendingPlacements[id] = Placement(slot: slot, rect: contentsRect)
        self.dirtyPages.insert(page)
        self.schedulePublish()
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
            self.dirtyPages.insert(page)
        }
        self.schedulePublish()
    }

    private func schedulePublish() {
        if self.isPublishScheduled {
            return
        }
        self.isPublishScheduled = true
        let delay = max(0.0, self.lastFlushTime + self.minimumPublishInterval - CFAbsoluteTimeGetCurrent())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.queue.async {
                self.flush()
            }
        }
    }

    private func flush() {
        var images: [Int: CGImage] = [:]
        for page in self.dirtyPages {
            if let image = self.contexts[page]?.makeImage() {
                images[page] = image
            }
        }
        let changes = self.pendingPlacements
        let removals = self.pendingRemovals
        self.dirtyPages.removeAll()
        self.pendingPlacements.removeAll()
        self.pendingRemovals.removeAll()
        self.isPublishScheduled = false
        self.lastFlushTime = CFAbsoluteTimeGetCurrent()
        DispatchQueue.main.async {
            self.publish(images: images, changes: changes, removals: removals)
        }
    }

    private func publish(images: [Int: CGImage], changes: [String: Placement], removals: Set<String>) {
        dispatchPrecondition(condition: .onQueue(.main))
        for (page, image) in images {
            self.pageImages[page] = image
        }
        var changed = removals
        self.lock.lock()
        for (id, placement) in changes where self.index[id]?.slot == placement.slot {
            self.placements[id] = placement
            changed.insert(id)
        }
        self.lock.unlock()
        if !changed.isEmpty {
            self.onThumbnailsChanged?(changed)
        }
    }
}
