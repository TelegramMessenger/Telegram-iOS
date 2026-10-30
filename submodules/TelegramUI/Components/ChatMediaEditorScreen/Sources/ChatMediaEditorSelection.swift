import Foundation
import UIKit
import Display
import SwiftSignalKit
import MediaEditor
import ChatMediaSend

public protocol ChatMediaEditorSelectionAdapter: AnyObject {
    var selectionLimit: Int { get }
    func isSelected(_ uniqueId: String) -> Bool
    func index(of uniqueId: String) -> Int?
    func selectedIds() -> [String]
    func setSelected(_ uniqueId: String, _ selected: Bool, sender: AnyObject?) -> Bool
    var changes: Signal<Void, NoError> { get }
}

public struct ChatMediaEditorCheckState: Equatable {
    public var isSelected: Bool
    public var number: Int?

    public init(isSelected: Bool, number: Int?) {
        self.isSelected = isSelected
        self.number = number
    }
}

public struct ChatMediaEditorStripUpdate: Equatable {
    public var inserted: [Int]
    public var removed: [Int]

    public init(inserted: [Int], removed: [Int]) {
        self.inserted = inserted
        self.removed = removed
    }
}

public func chatMediaEditorCommitShouldAutoSelect(before: MediaEditorValues, after: MediaEditorValues, baselineQualityPreset: MediaQualityPreset?) -> Bool {
    return (before != after || before.qualityPreset != after.qualityPreset) && chatMediaEditorValuesAreEdited(after, baselineQualityPreset: baselineQualityPreset)
}

public final class ChatMediaEditorSelectionModel {
    public let adapter: ChatMediaEditorSelectionAdapter
    public let keepsDeselectedItems: Bool
    public private(set) var stripItems: [String]
    public private(set) var isStripOpen = false
    public var stripUpdated: ((ChatMediaEditorStripUpdate) -> Void)?
    public var selectionUpdated: (() -> Void)?

    private var selectedSnapshot: Set<String>
    private var selectedOrderSnapshot: [String]
    private var stripKeptIds = Set<String>()
    private var changesDisposable: Disposable?

    public init(adapter: ChatMediaEditorSelectionAdapter, keepsDeselectedItems: Bool = false) {
        self.adapter = adapter
        self.keepsDeselectedItems = keepsDeselectedItems
        let selectedIds = adapter.selectedIds()
        self.stripItems = selectedIds
        self.selectedSnapshot = Set(selectedIds)
        self.selectedOrderSnapshot = selectedIds
        self.changesDisposable = adapter.changes.startStrict(next: { [weak self] _ in
            self?.sync()
        })
    }

    deinit {
        self.changesDisposable?.dispose()
    }

    public var isEnabled: Bool {
        return self.adapter.selectionLimit != 1
    }

    public var selectedCount: Int {
        return self.adapter.selectedIds().count
    }

    public var isCounterVisible: Bool {
        return self.isEnabled && self.selectedCount >= 1
    }

    public func checkState(for uniqueId: String) -> ChatMediaEditorCheckState {
        guard self.adapter.isSelected(uniqueId) else {
            return ChatMediaEditorCheckState(isSelected: false, number: nil)
        }
        return ChatMediaEditorCheckState(isSelected: true, number: self.adapter.index(of: uniqueId).flatMap { $0 + 1 })
    }

    @discardableResult
    public func toggle(_ uniqueId: String, sender: AnyObject?) -> Bool {
        guard self.isEnabled else {
            return self.adapter.isSelected(uniqueId)
        }
        let _ = self.adapter.setSelected(uniqueId, !self.adapter.isSelected(uniqueId), sender: sender)
        self.sync()
        return self.adapter.isSelected(uniqueId)
    }

    @discardableResult
    public func toggleFromStrip(_ uniqueId: String) -> Bool {
        guard self.isEnabled else {
            return self.adapter.isSelected(uniqueId)
        }
        self.stripKeptIds.insert(uniqueId)
        let _ = self.adapter.setSelected(uniqueId, !self.adapter.isSelected(uniqueId), sender: self)
        self.sync()
        self.stripKeptIds.remove(uniqueId)
        return self.adapter.isSelected(uniqueId)
    }

    public func autoSelect(_ uniqueId: String) {
        guard !self.adapter.isSelected(uniqueId) else {
            return
        }
        let _ = self.adapter.setSelected(uniqueId, true, sender: nil)
        self.sync()
    }

    public func editCommitted(_ uniqueId: String, before: MediaEditorValues, after: MediaEditorValues, baselineQualityPreset: MediaQualityPreset?) {
        if chatMediaEditorCommitShouldAutoSelect(before: before, after: after, baselineQualityPreset: baselineQualityPreset) {
            self.autoSelect(uniqueId)
        }
    }

    public func captionCommitted(_ caption: NSAttributedString, for uniqueId: String) {
        if caption.length > 0 {
            self.autoSelect(uniqueId)
        }
    }

    public func setStripOpen(_ isOpen: Bool) {
        self.isStripOpen = isOpen && self.isCounterVisible
    }

    public func sync() {
        let selectedIds = self.adapter.selectedIds()
        let selected = Set(selectedIds)
        let previous = self.selectedSnapshot
        self.selectedSnapshot = selected
        let previousOrder = self.selectedOrderSnapshot
        self.selectedOrderSnapshot = selectedIds

        var removed: [Int] = []
        if !self.keepsDeselectedItems {
            for (index, uniqueId) in self.stripItems.enumerated().reversed() {
                if !selected.contains(uniqueId) && previous.contains(uniqueId) && !self.stripKeptIds.contains(uniqueId) {
                    removed.append(index)
                }
            }
            for index in removed {
                self.stripItems.remove(at: index)
            }
            removed.reverse()
        }
        var inserted: [Int] = []
        for uniqueId in selectedIds where !self.stripItems.contains(uniqueId) {
            self.stripItems.append(uniqueId)
            inserted.append(self.stripItems.count - 1)
        }
        if !self.isCounterVisible {
            self.isStripOpen = false
        }
        if !inserted.isEmpty || !removed.isEmpty {
            self.stripUpdated?(ChatMediaEditorStripUpdate(inserted: inserted, removed: removed))
        }
        if selectedIds != previousOrder {
            self.selectionUpdated?()
        }
    }
}

public let chatMediaEditorScreenEdgeInset: CGFloat = 16.0
public func chatMediaEditorSelectionToggleHaptic(wasSelected: Bool, isSelected: Bool) -> Bool {
    return wasSelected != isSelected
}

public let chatMediaEditorCheckButtonSize = CGSize(width: 39.0, height: 39.0)
public let chatMediaEditorCheckButtonRingInset: CGFloat = 3.0
public let chatMediaEditorCounterButtonSize = CGSize(width: 64.0, height: 38.0)
public let chatMediaEditorCounterCircleFrame = CGRect(x: 16.0, y: 1.0, width: 31.0, height: 31.0)

/// iPhone Duo's unfolded screen in portrait: the status island at the top right. The editor's top row sits on the
/// island's clock line, centred `clockLineY` from the top, its trailing control `trailingInset` further left, as the story
/// editor's does (rule 4 in docs/iphone-duo-layout.md); below the island it stood under the island's whole band.
public struct ChatMediaEditorStatusIslandRow: Equatable {
    public var clockLineY: CGFloat
    public var trailingInset: CGFloat

    public init(clockLineY: CGFloat, trailingInset: CGFloat) {
        self.clockLineY = clockLineY
        self.trailingInset = trailingInset
    }
}

/// The status island beside the editor's top row, or nil: every other device and posture.
public func chatMediaEditorStatusIslandRow(layout: ContainerViewLayout) -> ChatMediaEditorStatusIslandRow? {
    guard layout.topBarStatusIsland != nil else {
        return nil
    }
    return ChatMediaEditorStatusIslandRow(clockLineY: (layout.navigationBarStatusBarHeight ?? 0.0) + 31.0, trailingInset: layout.navigationBarTrailingButtonsInset)
}

public func chatMediaEditorCheckButtonFrame(size: CGSize, safeInsets: UIEdgeInsets, statusIsland: ChatMediaEditorStatusIslandRow? = nil, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    let topInset = safeInsets.top
    if let toolbarSide {
        let notchEdge = chatMediaEditorLandscapeNotchEdge(size: size, safeInsets: safeInsets, side: toolbarSide)
        let x: CGFloat
        switch toolbarSide {
        case .left:
            x = notchEdge - chatMediaEditorScreenEdgeInset - (chatMediaEditorCheckButtonSize.width - chatMediaEditorCheckButtonRingInset)
        case .right:
            x = notchEdge + chatMediaEditorScreenEdgeInset - chatMediaEditorCheckButtonRingInset
        }
        return CGRect(origin: CGPoint(x: x, y: topInset + 5.0), size: chatMediaEditorCheckButtonSize)
    }
    var frame = CGRect(origin: CGPoint(x: size.width - safeInsets.right - chatMediaEditorScreenEdgeInset - (chatMediaEditorCheckButtonSize.width - chatMediaEditorCheckButtonRingInset), y: topInset + 5.0), size: chatMediaEditorCheckButtonSize)
    if let statusIsland {
        frame.origin.x -= statusIsland.trailingInset
        frame.origin.y = statusIsland.clockLineY - frame.height / 2.0
    }
    return frame
}

/// The counter and the camera button beside it sit at the bottom: they span the side strip, keeping clear only of a
/// corner block that reaches the bottom edge (`bottomEdgeSideInsets`). Equal to `safeInsets` on every other device.
func chatMediaEditorBottomRowSafeInsets(_ safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners) -> UIEdgeInsets {
    let sideInsets = bottomEdgeSideInsets(safeInsets: safeInsets, reservedCorners: reservedCorners)
    var result = safeInsets
    result.left = sideInsets.left
    result.right = sideInsets.right
    return result
}

func chatMediaEditorLandscapeHeaderInset(hasVideoHeader: Bool) -> CGFloat {
    return hasVideoHeader ? chatMediaEditorVideoScrubberPanelHeight : 0.0
}

public func chatMediaEditorCounterButtonFrame(size: CGSize, safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners, toolbarMinY: CGFloat, captionBaseHeight: CGFloat, hasVideoHeader: Bool, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    if let toolbarSide {
        let innerEdge = chatMediaEditorLandscapeInnerEdge(size: size, safeInsets: safeInsets, side: toolbarSide)
        let x: CGFloat
        switch toolbarSide {
        case .left:
            x = innerEdge + 1.0
        case .right:
            x = innerEdge - 1.0 - chatMediaEditorCounterButtonSize.width
        }
        return CGRect(origin: CGPoint(x: x, y: chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets, toolbarSide: toolbarSide).midY - chatMediaEditorCounterCircleFrame.midY), size: chatMediaEditorCounterButtonSize)
    }
    let safeInsets = chatMediaEditorBottomRowSafeInsets(safeInsets, reservedCorners: reservedCorners)
    return CGRect(origin: CGPoint(x: size.width - chatMediaEditorCounterButtonSize.width - safeInsets.right, y: toolbarMinY - captionBaseHeight - 50.0 - (hasVideoHeader ? 50.0 : 0.0)), size: chatMediaEditorCounterButtonSize)
}

let chatMediaEditorLandscapeStripInnerOffset: CGFloat = 66.0

public func chatMediaEditorStripFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarMinY: CGFloat, captionBaseHeight: CGFloat, hasVideoHeader: Bool, cellSize: CGSize, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    if let toolbarSide {
        let innerEdge = chatMediaEditorLandscapeInnerEdge(size: size, safeInsets: safeInsets, side: toolbarSide)
        let headerInset = chatMediaEditorLandscapeHeaderInset(hasVideoHeader: hasVideoHeader)
        let width = cellSize.width + 4.0 * 2.0
        let x: CGFloat
        switch toolbarSide {
        case .left:
            x = innerEdge + chatMediaEditorLandscapeStripInnerOffset
        case .right:
            x = innerEdge - chatMediaEditorLandscapeStripInnerOffset - width
        }
        return CGRect(x: x, y: safeInsets.top + 4.0, width: width, height: max(0.0, size.height - safeInsets.top - safeInsets.bottom - 4.0 * 2.0 - headerInset))
    }
    let height = cellSize.height + 4.0 * 2.0
    return CGRect(x: safeInsets.left + 4.0, y: toolbarMinY - captionBaseHeight - height - 64.0 - (hasVideoHeader ? 46.0 : 0.0), width: max(0.0, size.width - safeInsets.left - 4.0 * 2.0 - safeInsets.right), height: height)
}

public func chatMediaEditorStripBackgroundWidth(frameWidth: CGFloat, count: Int, cellWidth: CGFloat) -> CGFloat {
    let count = max(1, count)
    let width = CGFloat(count) * (cellWidth + 4.0) - 4.0
    return max(0.0, min(frameWidth, width + 8.0))
}

public func chatMediaEditorStripBackgroundFrame(size: CGSize, count: Int, cellSize: CGSize, isVertical: Bool) -> CGRect {
    if isVertical {
        let height = chatMediaEditorStripBackgroundWidth(frameWidth: size.height, count: count, cellWidth: cellSize.height)
        return CGRect(x: 0.0, y: 0.0, width: size.width, height: height)
    }
    let width = chatMediaEditorStripBackgroundWidth(frameWidth: size.width, count: count, cellWidth: cellSize.width)
    return CGRect(x: size.width - width, y: 0.0, width: width, height: size.height)
}

public func chatMediaEditorStripMaskFrame(size: CGSize, count: Int, cellSize: CGSize, isVertical: Bool) -> CGRect {
    let backgroundFrame = chatMediaEditorStripBackgroundFrame(size: size, count: count, cellSize: cellSize, isVertical: isVertical)
    if isVertical {
        return CGRect(x: 4.0, y: backgroundFrame.minY, width: max(0.0, backgroundFrame.width - 8.0), height: backgroundFrame.height)
    }
    return CGRect(x: backgroundFrame.minX, y: 4.0, width: backgroundFrame.width, height: max(0.0, backgroundFrame.height - 8.0))
}

public func chatMediaEditorStripHiddenCenter(size: CGSize, toolbarSide: ChatMediaEditorToolbarSide?) -> CGPoint {
    switch toolbarSide {
    case .none:
        return CGPoint(x: size.width / 2.0, y: size.height / 2.0 + size.height / 3.0)
    case .left:
        return CGPoint(x: size.width / 2.0 - size.width / 3.0, y: size.height / 2.0)
    case .right:
        return CGPoint(x: size.width / 2.0 + size.width / 3.0, y: size.height / 2.0)
    }
}
