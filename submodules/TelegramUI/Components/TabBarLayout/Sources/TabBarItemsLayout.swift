import Foundation
import UIKit
import Display

/// The direction a tab bar lays its items out in.
public enum TabBarAxis: Equatable {
    case horizontal
    case vertical
}

/// An item's length along the bar in every mode but horizontal regular, and a regular item's size across it.
public let tabBarItemLength: CGFloat = 56.0
/// The gap between the bar's edge and its items, at both ends and on both sides.
public let tabBarInnerInset: CGFloat = 4.0
/// A compact (icon-only) item's size across the bar.
public let tabBarCompactItemThickness: CGFloat = 40.0
/// A horizontal compact bar that would hug its items within this much of its available length takes the
/// whole length instead: a small leftover gap on each side reads as a mistake rather than a design.
private let tabBarCompactFillThreshold: CGFloat = 60.0

public struct TabBarItemsLayout: Equatable {
    /// The bar: its items plus the inner inset on every side.
    public var size: CGSize
    /// Each item's frame in the bar's coordinates, in item order.
    public var itemFrames: [CGRect]

    public init(size: CGSize, itemFrames: [CGRect]) {
        self.size = size
        self.itemFrames = itemFrames
    }
}

/// The item frames and the bar's size, one item per entry of `unboundItemWidths`.
///
/// Horizontal regular items share `availableLength` (the bar's length available along the axis, inner
/// insets included): equal lengths when every item's unconstrained width fits, else lengths weighted by
/// those widths. Every other mode gives each item `tabBarItemLength` and the bar hugs its items, except
/// that a horizontal compact bar hugging them within `tabBarCompactFillThreshold` of `availableLength`
/// (or beyond it) takes `availableLength`, its items sharing it equally. The widths are unused outside
/// horizontal regular, and `availableLength` on the vertical axis.
public func tabBarItemsLayout(axis: TabBarAxis, isCompact: Bool, unboundItemWidths: [CGFloat], availableLength: CGFloat) -> TabBarItemsLayout {
    let count = unboundItemWidths.count
    let thickness = isCompact ? tabBarCompactItemThickness : tabBarItemLength

    let lengths: [CGFloat]
    if axis == .horizontal && !isCompact && count != 0 {
        let availableItemsLength = availableLength - tabBarInnerInset * 2.0
        let equalLength = floorToScreenPixels(availableItemsLength / CGFloat(count))
        if unboundItemWidths.allSatisfy({ $0 <= equalLength }) {
            lengths = Array(repeating: equalLength, count: count)
        } else {
            let weight = availableItemsLength / unboundItemWidths.reduce(0.0, +)
            lengths = unboundItemWidths.map { floorToScreenPixels($0 * weight) }
        }
    } else if axis == .horizontal && isCompact && count != 0 && availableLength - (CGFloat(count) * tabBarItemLength + tabBarInnerInset * 2.0) < tabBarCompactFillThreshold {
        let equalLength = floorToScreenPixels((availableLength - tabBarInnerInset * 2.0) / CGFloat(count))
        lengths = Array(repeating: equalLength, count: count)
    } else {
        lengths = Array(repeating: tabBarItemLength, count: count)
    }

    var itemFrames: [CGRect] = []
    var position = tabBarInnerInset
    for length in lengths {
        switch axis {
        case .horizontal:
            itemFrames.append(CGRect(x: position, y: tabBarInnerInset, width: length, height: thickness))
        case .vertical:
            itemFrames.append(CGRect(x: tabBarInnerInset, y: position, width: thickness, height: length))
        }
        position += length
    }
    let barLength = position + tabBarInnerInset
    let barThickness = thickness + tabBarInnerInset * 2.0
    switch axis {
    case .horizontal:
        return TabBarItemsLayout(size: CGSize(width: barLength, height: barThickness), itemFrames: itemFrames)
    case .vertical:
        return TabBarItemsLayout(size: CGSize(width: barThickness, height: barLength), itemFrames: itemFrames)
    }
}

/// The bar's thickness in the system layout (UIKit's `platterMinorDimension`, iOS 27 compact metrics).
public let tabBarSystemBarThickness: CGFloat = 62.0
/// A system-layout item's size across the bar and its minimum length along it (`minimumItemPrimaryDimension`).
public let tabBarSystemItemThickness: CGFloat = 54.0

/// The item frames and the bar's size of iOS 27's portrait tab bar (`_UITabBarVisualProvider_Floating` with its
/// compact metrics, decompiled from UIKitCore and matched against UIKit's frames to 0.0001pt): one item per entry of
/// `fittedItemWidths`, each an item's content width (its title's, at the unselected font).
///
/// Up to three items (without `hasAccessory`) sit 32pt apart and the bar hugs them, at most `availableLength` long;
/// more fill `availableLength`, equally or in proportion to their widths. The frames overlap: each item reaches
/// past its content into its neighbours' gaps, and the first and last end `tabBarInnerInset` inside the bar.
/// Lengths are not rounded, as UIKit does not round them. `hasAccessory` (UIKit's hosted search or accessory
/// element) makes any count lay out like four or more.
public func tabBarSystemItemsLayout(fittedItemWidths: [CGFloat], availableLength: CGFloat, hasAccessory: Bool, scale: CGFloat = UIScreenScale) -> TabBarItemsLayout {
    let count = fittedItemWidths.count
    if count == 0 {
        return TabBarItemsLayout(size: CGSize(width: tabBarInnerInset * 2.0, height: tabBarSystemBarThickness), itemFrames: [])
    }
    let roundToScale: (CGFloat) -> CGFloat = { value in
        return floor(value * scale + 0.5) / scale
    }

    // The platter layout (sub_1c50ee7a8): the items' inset from the bar's ends, their spacing (nil: flexible)
    // and the padding added to each content width.
    let isFlexible = count > 3 || hasAccessory
    let sideInset: CGFloat = count > 4 ? 15.0 : 24.0
    let spacing: CGFloat? = isFlexible ? nil : 32.0
    let padding: CGFloat = isFlexible ? 12.0 : 0.0
    let gapCount = CGFloat(max(count - 1, 0))

    var itemLengths = fittedItemWidths.map { max(tabBarSystemItemThickness, $0 + padding) }

    // The bar's length (sub_1c50ea230, clamped in sub_1c50ef570).
    let barLength: CGFloat
    if let spacing {
        let ideal = roundToScale(sideInset * 2.0 + gapCount * spacing + CGFloat(count) * (itemLengths.max() ?? 0.0))
        barLength = min(max(ideal, 0.0), availableLength)
    } else {
        barLength = availableLength
    }

    // The items (sub_1c50eb15c).
    let initialItemsLength = barLength - sideInset * 2.0
    var totalLength = itemLengths.reduce(0.0, +)
    let clampedMaxLength = min(max(itemLengths.max() ?? 0.0, 0.0), initialItemsLength)
    let equalLength = (initialItemsLength - gapCount * (spacing ?? 2.0)) / CGFloat(count)
    let fittedLength = min(clampedMaxLength, equalLength)
    var contentInset = sideInset
    var itemsLength = initialItemsLength
    if spacing != nil {
        itemLengths = Array(repeating: fittedLength, count: count)
        totalLength = fittedLength * CGFloat(count)
    } else {
        let usesEqualLengths: Bool
        var cappedInset: CGFloat?
        if gapCount > 0.0 && (initialItemsLength - totalLength) / gapCount < 14.0 {
            usesEqualLengths = false
            cappedInset = 14.0
        } else if tabBarSystemItemThickness >= clampedMaxLength {
            usesEqualLengths = true
        } else {
            usesEqualLengths = clampedMaxLength <= equalLength
            cappedInset = 18.0
        }
        if let cappedInset {
            contentInset = min(sideInset, cappedInset)
            itemsLength = barLength - contentInset * 2.0
        }
        if usesEqualLengths {
            let length = count < 2 ? equalLength : max(fittedLength, itemsLength / CGFloat(count) - (contentInset - tabBarInnerInset))
            itemLengths = Array(repeating: length, count: count)
            totalLength = length * CGFloat(count)
        } else if totalLength < itemsLength {
            let factor = itemsLength / totalLength
            itemLengths = itemLengths.map { $0 * factor }
            totalLength = itemsLength
        }
    }
    // Overflow comes off every item evenly, even below the minimum length: UIKit's branch meant to spare the
    // items at the minimum never runs (its min() starts from 0).
    let overflow = totalLength - itemsLength + (spacing.map { gapCount * $0 } ?? 0.0)
    if overflow > 0.0 {
        let reduction = overflow / CGFloat(count)
        itemLengths = itemLengths.map { $0 - reduction }
        totalLength = itemsLength
    }
    let gap: CGFloat = gapCount > 0.0 ? (spacing ?? (itemsLength - totalLength) / gapCount) : 0.0
    // Each item reaches this far past its content on both sides (`_UITabButton.contentOutset`).
    let outset = contentInset - tabBarInnerInset

    var itemFrames: [CGRect] = []
    var position = contentInset
    for length in itemLengths {
        itemFrames.append(CGRect(x: position - outset, y: tabBarInnerInset, width: length + outset * 2.0, height: tabBarSystemItemThickness))
        position += length + gap
    }
    return TabBarItemsLayout(size: CGSize(width: barLength, height: tabBarSystemBarThickness), itemFrames: itemFrames)
}

/// The lens's selection rect in the bar's coordinates: the dragged position, else the selected item grown
/// by the inner inset along the axis, else the first item's place; always the bar's full thickness across
/// it, and clamped to the bar along it. A horizontal item narrower than its height is widened to 1.2 times
/// its height first.
public func tabBarLensSelectionFrame(axis: TabBarAxis, barSize: CGSize, selectedItemFrame: CGRect?, drag: (origin: CGFloat, itemLength: CGFloat)?) -> CGRect {
    var origin: CGFloat
    let length: CGFloat
    if let drag {
        origin = drag.origin
        length = drag.itemLength + tabBarInnerInset * 2.0
    } else if var itemFrame = selectedItemFrame {
        switch axis {
        case .horizontal:
            if itemFrame.width < itemFrame.height {
                itemFrame = itemFrame.insetBy(dx: floor((itemFrame.height * 1.2 - itemFrame.width) * -0.5), dy: 0.0)
            }
            origin = itemFrame.minX - tabBarInnerInset
            length = itemFrame.width + tabBarInnerInset * 2.0
        case .vertical:
            origin = itemFrame.minY - tabBarInnerInset
            length = itemFrame.height + tabBarInnerInset * 2.0
        }
    } else {
        origin = 0.0
        length = tabBarItemLength
    }

    switch axis {
    case .horizontal:
        origin = max(0.0, min(origin, barSize.width - length))
        return CGRect(x: origin, y: 0.0, width: length, height: barSize.height)
    case .vertical:
        origin = max(0.0, min(origin, barSize.height - length))
        return CGRect(x: 0.0, y: origin, width: barSize.width, height: length)
    }
}

/// The item under `point`, or the nearest one by distance along the axis when it is outside every item or inside
/// several (the system layout's items overlap). Nil when there are no items.
public func tabBarItemIndex(at point: CGPoint, axis: TabBarAxis, itemFrames: [CGRect]) -> Int? {
    var containing: (index: Int, distance: CGFloat)?
    var closest: (index: Int, distance: CGFloat)?
    for (index, frame) in itemFrames.enumerated() {
        let distance: CGFloat
        switch axis {
        case .horizontal:
            distance = abs(point.x - frame.midX)
        case .vertical:
            distance = abs(point.y - frame.midY)
        }
        if frame.contains(point) {
            if let containingValue = containing {
                if distance < containingValue.distance {
                    containing = (index, distance)
                }
            } else {
                containing = (index, distance)
            }
        }
        if let closestValue = closest {
            if distance < closestValue.distance {
                closest = (index, distance)
            }
        } else {
            closest = (index, distance)
        }
    }
    return containing?.index ?? closest?.index
}
