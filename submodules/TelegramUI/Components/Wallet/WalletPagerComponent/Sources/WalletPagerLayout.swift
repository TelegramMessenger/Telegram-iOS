import Foundation
import CoreGraphics

struct WalletPagerLayout {
    let itemCount: Int
    let size: CGSize
    let itemSpacing: CGFloat

    var itemStride: CGFloat {
        return self.size.width + self.itemSpacing * 2.0
    }

    var isValid: Bool {
        return self.size.width > 0.0 && self.size.width.isFinite
            && self.itemStride > 0.0 && self.itemStride.isFinite
    }

    var contentSize: CGSize {
        return CGSize(width: self.itemStride * CGFloat(self.itemCount), height: self.size.height)
    }

    var scrollFrame: CGRect {
        return CGRect(x: -self.itemSpacing * 0.5, y: 0.0, width: self.itemStride, height: self.size.height)
    }

    func itemFrame(at index: Int) -> CGRect {
        return CGRect(
            x: self.itemSpacing * 0.5 + self.itemStride * CGFloat(index),
            y: 0.0,
            width: self.size.width,
            height: self.size.height
        )
    }

    func currentIndex(at offset: CGFloat) -> Int {
        guard self.itemCount > 0, self.isValid, offset.isFinite else {
            return 0
        }
        return Int(max(0.0, min(CGFloat(self.itemCount - 1), round(offset / self.itemStride))))
    }

    func preloadedIndices(at offset: CGFloat) -> Range<Int> {
        guard self.itemCount > 0, self.isValid, offset.isFinite else {
            return 0 ..< 0
        }
        let index = self.currentIndex(at: offset)
        return max(0, index - 1) ..< min(self.itemCount, index + 2)
    }

    func visibleIndices(at offset: CGFloat) -> Range<Int> {
        guard self.itemCount > 0, self.isValid, offset.isFinite else {
            return 0 ..< 0
        }
        // Only include pages that overlap the scroll view's actual viewport.
        let lower = floor((offset - self.itemSpacing * 0.5 - self.size.width) / self.itemStride) + 1.0
        let upper = ceil((offset + self.scrollFrame.width - self.itemSpacing * 0.5) / self.itemStride)
        let lowerIndex = Int(max(0.0, min(CGFloat(self.itemCount), lower)))
        let upperIndex = Int(max(0.0, min(CGFloat(self.itemCount), upper)))
        return lowerIndex ..< upperIndex
    }
}

struct WalletPagerState {
    private struct Anchor {
        let id: String
        let index: Int
        let fraction: CGFloat
    }

    private(set) var itemIds: [String] = []
    private var indexById: [String: Int] = [:]
    private(set) var layout = WalletPagerLayout(itemCount: 0, size: .zero, itemSpacing: 0.0)
    private(set) var isInitialized = false
    private var anchor: Anchor?

    func index(forId id: String) -> Int? {
        return self.indexById[id]
    }

    // Only external data/layout updates enter this path. Scrolling reads the cached layout and IDs.
    mutating func update(
        itemIds: [String],
        initialIndex: Int,
        size: CGSize,
        itemSpacing: CGFloat,
        offset: CGFloat,
        isSwiping: Bool
    ) -> CGFloat {
        if self.isInitialized, self.layout.isValid, !self.itemIds.isEmpty, offset.isFinite {
            let index = self.layout.currentIndex(at: offset)
            self.anchor = Anchor(id: self.itemIds[index], index: index, fraction: offset / self.layout.itemStride - CGFloat(index))
        }

        if self.itemIds != itemIds {
            self.itemIds = itemIds
            self.indexById.removeAll(keepingCapacity: true)
            for (index, id) in itemIds.enumerated() {
                self.indexById[id] = index
            }
        }
        self.layout = WalletPagerLayout(itemCount: itemIds.count, size: size, itemSpacing: itemSpacing)
        guard self.layout.isValid, !itemIds.isEmpty else {
            // Keep the anchor through a temporary empty list or zero-width layout.
            return 0.0
        }

        let index: Int
        let fraction: CGFloat
        if let anchor = self.anchor {
            index = self.indexById[anchor.id] ?? min(itemIds.count - 1, anchor.index)
            fraction = anchor.fraction
        } else {
            index = max(0, min(itemIds.count - 1, initialIndex))
            fraction = 0.0
        }
        self.isInitialized = true
        let targetOffset = (CGFloat(index) + fraction) * self.layout.itemStride
        let maximumOffset = max(0.0, self.layout.contentSize.width - self.layout.scrollFrame.width)
        let resolvedOffset = isSwiping ? targetOffset : max(0.0, min(maximumOffset, targetOffset))
        let resolvedIndex = self.layout.currentIndex(at: resolvedOffset)
        self.anchor = Anchor(
            id: itemIds[resolvedIndex],
            index: resolvedIndex,
            fraction: resolvedOffset / self.layout.itemStride - CGFloat(resolvedIndex)
        )
        return resolvedOffset
    }
}
