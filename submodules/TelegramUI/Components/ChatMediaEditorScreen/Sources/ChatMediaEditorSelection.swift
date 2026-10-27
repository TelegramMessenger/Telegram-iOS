import Foundation
import UIKit
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

public func chatMediaEditorCheckButtonFrame(size: CGSize, safeInsets: UIEdgeInsets) -> CGRect {
    let topInset = safeInsets.top
    return CGRect(origin: CGPoint(x: size.width - safeInsets.right - chatMediaEditorScreenEdgeInset - (chatMediaEditorCheckButtonSize.width - chatMediaEditorCheckButtonRingInset), y: topInset + 5.0), size: chatMediaEditorCheckButtonSize)
}

public func chatMediaEditorCounterButtonFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarMinY: CGFloat, captionBaseHeight: CGFloat, hasVideoHeader: Bool) -> CGRect {
    return CGRect(origin: CGPoint(x: size.width - chatMediaEditorCounterButtonSize.width - safeInsets.right, y: toolbarMinY - captionBaseHeight - 50.0 - (hasVideoHeader ? 46.0 : 0.0)), size: chatMediaEditorCounterButtonSize)
}

public func chatMediaEditorStripFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarMinY: CGFloat, captionBaseHeight: CGFloat, hasVideoHeader: Bool, cellSize: CGSize) -> CGRect {
    let height = cellSize.height + 4.0 * 2.0
    return CGRect(x: safeInsets.left + 4.0, y: toolbarMinY - captionBaseHeight - height - 64.0 - (hasVideoHeader ? 46.0 : 0.0), width: max(0.0, size.width - safeInsets.left - 4.0 * 2.0 - safeInsets.right), height: height)
}

public func chatMediaEditorStripBackgroundWidth(frameWidth: CGFloat, count: Int, cellWidth: CGFloat) -> CGFloat {
    let count = max(1, count)
    let width = CGFloat(count) * (cellWidth + 4.0) - 4.0
    return max(0.0, min(frameWidth, width + 8.0))
}
