import Foundation
import CoreGraphics

public final class MediaGridThumbnailStore {
    private struct IndexEntry {
        var slot: Int
        var version: String
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
    private var isPublishScheduled = false

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
        guard let placement = self.placements[id], let image = self.pageImages[placement.slot / self.slotsPerPage] else {
            return nil
        }
        return MediaGridThumbnail(image: image, contentsRect: placement.rect)
    }

    public func write(_ image: CGImage, id: String, version: String) {
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
        self.index[id] = IndexEntry(slot: slot, version: version)
        self.queue.async {
            self.draw(image, id: id, slot: slot)
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
            let insertion = self.freeSlots.firstIndex(where: { $0 > entry.slot }) ?? self.freeSlots.count
            self.freeSlots.insert(entry.slot, at: insertion)
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

    private func draw(_ image: CGImage, id: String, slot: Int) {
        let page = slot / self.slotsPerPage
        guard let context = self.context(page: page), image.width > 0, image.height > 0 else {
            return
        }
        let size = self.slotPixelSize
        let aspect = min(2.0, max(0.5, CGFloat(image.width) / CGFloat(image.height)))
        let width = aspect >= 1.0 ? size : max(1, Int((CGFloat(size) * aspect).rounded()))
        let height = aspect >= 1.0 ? max(1, Int((CGFloat(size) / aspect).rounded())) : size
        let origin = self.slotOrigin(slot)
        let x = origin.x + (size - width) / 2
        let y = origin.y + (size - height) / 2
        context.clear(self.flippedRect(x: origin.x, y: origin.y, width: size, height: size))
        let target = self.flippedRect(x: x, y: y, width: width, height: height)
        let scale = max(target.width / CGFloat(image.width), target.height / CGFloat(image.height))
        let drawn = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.saveGState()
        context.clip(to: target)
        context.draw(image, in: CGRect(x: target.midX - drawn.width / 2.0, y: target.midY - drawn.height / 2.0, width: drawn.width, height: drawn.height))
        context.restoreGState()
        let unit = 1.0 / CGFloat(self.pagePixelSize)
        self.pendingPlacements[id] = Placement(slot: slot, rect: CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: CGFloat(width) * unit, height: CGFloat(height) * unit))
        self.markDirty(page: page)
    }

    private func clear(id: String, slot: Int) {
        let page = slot / self.slotsPerPage
        if self.pendingPlacements[id]?.slot == slot {
            self.pendingPlacements.removeValue(forKey: id)
        }
        guard let context = self.contexts[page] else {
            return
        }
        let origin = self.slotOrigin(slot)
        context.clear(self.flippedRect(x: origin.x, y: origin.y, width: self.slotPixelSize, height: self.slotPixelSize))
        self.markDirty(page: page)
    }

    private func markDirty(page: Int) {
        self.dirtyPages.insert(page)
        if self.isPublishScheduled {
            return
        }
        self.isPublishScheduled = true
        DispatchQueue.main.async {
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
        self.dirtyPages.removeAll()
        self.pendingPlacements.removeAll()
        self.isPublishScheduled = false
        DispatchQueue.main.async {
            self.publish(images: images, changes: changes)
        }
    }

    private func publish(images: [Int: CGImage], changes: [String: Placement]) {
        for (page, image) in images {
            self.pageImages[page] = image
        }
        var changed = Set<String>()
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
