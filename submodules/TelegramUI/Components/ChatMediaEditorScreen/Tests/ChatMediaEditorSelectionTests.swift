import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import MediaEditor
import ChatMediaEditorScreen
import Display

private final class FakeSelectionAdapter: ChatMediaEditorSelectionAdapter {
    let selectionLimit: Int
    private(set) var selected: [String]
    private(set) var senders: [AnyObject?] = []
    private let pipe = ValuePipe<Void>()

    init(selectionLimit: Int = 100, selected: [String] = []) {
        self.selectionLimit = selectionLimit
        self.selected = selected
    }

    func isSelected(_ uniqueId: String) -> Bool {
        return self.selected.contains(uniqueId)
    }

    func index(of uniqueId: String) -> Int? {
        return self.selected.firstIndex(of: uniqueId)
    }

    func selectedIds() -> [String] {
        return self.selected
    }

    func setSelected(_ uniqueId: String, _ selected: Bool, sender: AnyObject?) -> Bool {
        self.senders.append(sender)
        if selected {
            if self.selected.contains(uniqueId) || self.selected.count >= self.selectionLimit {
                return false
            }
            self.selected.append(uniqueId)
        } else {
            guard let index = self.selected.firstIndex(of: uniqueId) else {
                return false
            }
            self.selected.remove(at: index)
        }
        self.pipe.putNext(Void())
        return true
    }

    func reorder(_ ids: [String]) {
        self.selected = ids
        self.pipe.putNext(Void())
    }

    var changes: Signal<Void, NoError> {
        return self.pipe.signal()
    }
}

final class ChatMediaEditorSelectionTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func defaultValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: self.peerId, originalDimensions: PixelDimensions(width: 1200, height: 800), qualityPreset: .compressedVeryHigh)
    }

    func testCheckShowsOneBasedIndex() {
        let adapter = FakeSelectionAdapter(selected: ["a", "b"])
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(model.checkState(for: "a"), ChatMediaEditorCheckState(isSelected: true, number: 1))
        XCTAssertEqual(model.checkState(for: "b"), ChatMediaEditorCheckState(isSelected: true, number: 2))
        XCTAssertEqual(model.checkState(for: "c"), ChatMediaEditorCheckState(isSelected: false, number: nil))

        XCTAssertTrue(model.toggle("c", sender: nil))
        XCTAssertEqual(model.checkState(for: "c"), ChatMediaEditorCheckState(isSelected: true, number: 3))
        XCTAssertFalse(model.toggle("a", sender: nil))
        XCTAssertEqual(model.checkState(for: "b"), ChatMediaEditorCheckState(isSelected: true, number: 1))
        XCTAssertEqual(model.checkState(for: "c"), ChatMediaEditorCheckState(isSelected: true, number: 2))

        var updates = 0
        model.selectionUpdated = {
            updates += 1
        }
        adapter.reorder(["c", "b"])
        XCTAssertEqual(updates, 1)
        XCTAssertEqual(model.checkState(for: "c"), ChatMediaEditorCheckState(isSelected: true, number: 1))
    }

    func testNoCheckWhenLimitOne() {
        let adapter = FakeSelectionAdapter(selectionLimit: 1, selected: ["a"])
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        XCTAssertFalse(model.isEnabled)
        XCTAssertFalse(model.isCounterVisible)
        XCTAssertFalse(model.toggle("b", sender: nil))
        XCTAssertEqual(adapter.selected, ["a"])
        XCTAssertTrue(adapter.senders.isEmpty)

        let size = CGSize(width: 402.0, height: 874.0)
        let safeInsets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let checkFrame = chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets)
        XCTAssertEqual(checkFrame, CGRect(x: 402.0 - 52.0, y: 62.0 + 5.0, width: 39.0, height: 39.0))
        XCTAssertEqual(chatMediaEditorCheckButtonFrame(size: size, safeInsets: UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0)).minY, 25.0)
    }

    // iPhone Duo's unfolded screen in portrait (669x951): the 134x82 status island stands at the top right, its band the
    // top safe inset. The check sits on the island's clock line (centre 47), left of the island, not below its band.
    func testCheckSitsOnTheStatusIslandsClockLine() {
        let size = CGSize(width: 669.0, height: 951.0)
        let safeInsets = UIEdgeInsets(top: 82.0, left: 0.0, bottom: 20.0, right: 0.0)
        let island = ChatMediaEditorStatusIslandRow(clockLineY: 47.0, trailingInset: 134.0)
        let check = chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets, statusIsland: island)
        XCTAssertEqual(check.midY, 47.0)
        XCTAssertEqual(check.maxX, chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets).maxX - 134.0)
        XCTAssertLessThanOrEqual(check.maxX, size.width - 134.0)
        // Without an island (every other device) the frame is the one it always was.
        XCTAssertEqual(chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets, statusIsland: nil), chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets))
    }

    func testCheckAndCounterRingsKeepTheEdgeInset() {
        let size = CGSize(width: 402.0, height: 874.0)
        for safeInsets in [UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)] {
            let edge = size.width - safeInsets.right
            let check = chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets)
            let checkRingMaxX = check.maxX - 4.0 + 5.0 / 6.0
            XCTAssertEqual(edge - checkRingMaxX, chatMediaEditorScreenEdgeInset, accuracy: 0.25)
            let counter = chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: .none, toolbarMinY: 791.0, captionBaseHeight: 52.0, hasVideoHeader: false)
            let counterRingMaxX = counter.minX + chatMediaEditorCounterCircleFrame.maxX + 0.75
            XCTAssertEqual(edge - counterRingMaxX, chatMediaEditorScreenEdgeInset, accuracy: 0.25)
        }
    }

    func testCounterVisibleFromOne() {
        let adapter = FakeSelectionAdapter()
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        XCTAssertEqual(model.selectedCount, 0)
        XCTAssertFalse(model.isCounterVisible)
        XCTAssertTrue(model.toggle("a", sender: nil))
        XCTAssertEqual(model.selectedCount, 1)
        XCTAssertTrue(model.isCounterVisible)

        model.setStripOpen(true)
        XCTAssertTrue(model.isStripOpen)
        XCTAssertFalse(model.toggle("a", sender: nil))
        XCTAssertEqual(model.selectedCount, 0)
        XCTAssertFalse(model.isCounterVisible)
        XCTAssertFalse(model.isStripOpen)

        let size = CGSize(width: 402.0, height: 874.0)
        let safeInsets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let toolbarMinY = size.height - safeInsets.bottom - 49.0
        XCTAssertEqual(chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: .none, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: false), CGRect(x: 402.0 - 64.0, y: 874.0 - 49.0 - 52.0 - 50.0 - 34.0, width: 64.0, height: 38.0))
        XCTAssertEqual(chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: .none, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: true).minY, 874.0 - 49.0 - 52.0 - 50.0 - 34.0 - 50.0)
        let cellSize = CGSize(width: 128.0, height: 128.0)
        XCTAssertEqual(chatMediaEditorStripFrame(size: size, safeInsets: safeInsets, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: false, cellSize: cellSize), CGRect(x: 4.0, y: 874.0 - 49.0 - 52.0 - 136.0 - 64.0 - 34.0, width: 402.0 - 8.0, height: 136.0))
        XCTAssertEqual(chatMediaEditorStripFrame(size: size, safeInsets: safeInsets, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: true, cellSize: cellSize).minY, 874.0 - 49.0 - 52.0 - 136.0 - 64.0 - 34.0 - 46.0)
        XCTAssertEqual(chatMediaEditorStripBackgroundWidth(frameWidth: 394.0, count: 1, cellWidth: 128.0), 136.0)
        XCTAssertEqual(chatMediaEditorStripBackgroundWidth(frameWidth: 394.0, count: 2, cellWidth: 128.0), 268.0)
        XCTAssertEqual(chatMediaEditorStripBackgroundWidth(frameWidth: 394.0, count: 5, cellWidth: 128.0), 394.0)
    }

    func testStripRemovalRules() {
        let adapter = FakeSelectionAdapter()
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        var updates: [ChatMediaEditorStripUpdate] = []
        model.stripUpdated = { update in
            updates.append(update)
        }
        let mainCheck = NSObject()
        XCTAssertTrue(model.toggle("a", sender: mainCheck))
        XCTAssertTrue(model.toggle("b", sender: mainCheck))
        XCTAssertTrue(model.toggle("c", sender: mainCheck))
        XCTAssertEqual(model.stripItems, ["a", "b", "c"])
        XCTAssertEqual(updates.last, ChatMediaEditorStripUpdate(inserted: [2], removed: []))
        XCTAssertTrue(adapter.senders.allSatisfy { $0 === mainCheck })

        XCTAssertFalse(model.toggle("b", sender: mainCheck))
        XCTAssertEqual(model.stripItems, ["a", "c"])
        XCTAssertEqual(updates.last, ChatMediaEditorStripUpdate(inserted: [], removed: [1]))

        XCTAssertFalse(model.toggleFromStrip("c"))
        XCTAssertEqual(model.stripItems, ["a", "c"])
        XCTAssertFalse(adapter.isSelected("c"))
        XCTAssertEqual(model.checkState(for: "c"), ChatMediaEditorCheckState(isSelected: false, number: nil))
        XCTAssertEqual(model.selectedCount, 1)
        XCTAssertTrue(adapter.senders.last! === model)

        XCTAssertTrue(model.toggleFromStrip("c"))
        XCTAssertEqual(model.stripItems, ["a", "c"])
        XCTAssertEqual(adapter.selected, ["a", "c"])

        XCTAssertFalse(model.toggleFromStrip("c"))
        XCTAssertTrue(model.toggle("c", sender: mainCheck))
        XCTAssertEqual(model.stripItems, ["a", "c"])

        let _ = adapter.setSelected("a", false, sender: nil)
        XCTAssertEqual(model.stripItems, ["c"])

        let keeping = ChatMediaEditorSelectionModel(adapter: FakeSelectionAdapter(selected: ["x", "y"]), keepsDeselectedItems: true)
        XCTAssertEqual(keeping.stripItems, ["x", "y"])
        XCTAssertFalse(keeping.toggle("x", sender: mainCheck))
        XCTAssertEqual(keeping.stripItems, ["x", "y"])
    }

    func testEditCommitAutoSelects() {
        let adapter = FakeSelectionAdapter()
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        let before = self.defaultValues()
        let rotated = before.withUpdatedCropRect(cropRect: CGRect(x: 0.0, y: 0.0, width: 600.0, height: 800.0), rotation: 0.0, mirroring: false)

        XCTAssertFalse(chatMediaEditorCommitShouldAutoSelect(before: before, after: before, baselineQualityPreset: nil))
        XCTAssertTrue(chatMediaEditorCommitShouldAutoSelect(before: before, after: rotated, baselineQualityPreset: nil))
        XCTAssertFalse(chatMediaEditorCommitShouldAutoSelect(before: rotated, after: rotated, baselineQualityPreset: nil))

        model.editCommitted("a", before: before, after: before, baselineQualityPreset: nil)
        XCTAssertFalse(adapter.isSelected("a"))
        model.editCommitted("a", before: before, after: rotated, baselineQualityPreset: nil)
        XCTAssertTrue(adapter.isSelected("a"))
        XCTAssertNil(adapter.senders.last!)
        model.editCommitted("a", before: rotated, after: rotated.withUpdatedCropRect(cropRect: CGRect(x: 0.0, y: 0.0, width: 500.0, height: 800.0), rotation: 0.0, mirroring: false), baselineQualityPreset: nil)
        XCTAssertEqual(adapter.selected, ["a"])
    }

    func testNonEmptyCaptionAutoSelects() {
        let adapter = FakeSelectionAdapter()
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        model.captionCommitted(NSAttributedString(), for: "a")
        XCTAssertFalse(adapter.isSelected("a"))
        model.captionCommitted(NSAttributedString(string: "Hello"), for: "a")
        XCTAssertTrue(adapter.isSelected("a"))
        XCTAssertEqual(model.stripItems, ["a"])
        model.captionCommitted(NSAttributedString(string: "Again"), for: "a")
        XCTAssertEqual(adapter.selected, ["a"])
    }

    func testLimitRefusalRevertsCheck() {
        let adapter = FakeSelectionAdapter(selectionLimit: 2, selected: ["a", "b"])
        let model = ChatMediaEditorSelectionModel(adapter: adapter)
        var updates: [ChatMediaEditorStripUpdate] = []
        model.stripUpdated = { update in
            updates.append(update)
        }
        XCTAssertFalse(model.toggle("c", sender: nil))
        XCTAssertEqual(model.checkState(for: "c"), ChatMediaEditorCheckState(isSelected: false, number: nil))
        XCTAssertEqual(model.selectedCount, 2)
        XCTAssertEqual(model.stripItems, ["a", "b"])
        XCTAssertTrue(updates.isEmpty)

        model.captionCommitted(NSAttributedString(string: "Caption"), for: "c")
        XCTAssertFalse(adapter.isSelected("c"))
        XCTAssertEqual(model.stripItems, ["a", "b"])
    }

    func testSelectionHapticFiresOnlyOnAnActualToggle() {
        XCTAssertTrue(chatMediaEditorSelectionToggleHaptic(wasSelected: false, isSelected: true))
        XCTAssertTrue(chatMediaEditorSelectionToggleHaptic(wasSelected: true, isSelected: false))
        XCTAssertFalse(chatMediaEditorSelectionToggleHaptic(wasSelected: false, isSelected: false))
        XCTAssertFalse(chatMediaEditorSelectionToggleHaptic(wasSelected: true, isSelected: true))
    }

    func testLandscapeCheckButtonFrame() {
        let size = CGSize(width: 874.0, height: 402.0)
        let insets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        XCTAssertEqual(chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets, toolbarSide: .left), CGRect(x: 760.0, y: 5.0, width: 39.0, height: 39.0))
        XCTAssertEqual(chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets, toolbarSide: .right), CGRect(x: 75.0, y: 5.0, width: 39.0, height: 39.0))
    }

    func testLandscapeCounterButtonFrame() {
        let size = CGSize(width: 874.0, height: 402.0)
        let insets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        XCTAssertEqual(chatMediaEditorCounterButtonFrame(size: size, safeInsets: insets, reservedCorners: .none, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: false, toolbarSide: .left), CGRect(x: 112.0, y: 8.0, width: 64.0, height: 38.0))
        XCTAssertEqual(chatMediaEditorCounterButtonFrame(size: size, safeInsets: insets, reservedCorners: .none, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: true, toolbarSide: .left), CGRect(x: 112.0, y: 8.0, width: 64.0, height: 38.0))
        XCTAssertEqual(chatMediaEditorCounterButtonFrame(size: size, safeInsets: insets, reservedCorners: .none, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: true, toolbarSide: .right), CGRect(x: 698.0, y: 8.0, width: 64.0, height: 38.0))
    }

    func testLandscapeStripFrame() {
        let size = CGSize(width: 874.0, height: 402.0)
        let insets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        let cellSize = CGSize(width: 128.0, height: 128.0)
        XCTAssertEqual(chatMediaEditorStripFrame(size: size, safeInsets: insets, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: false, cellSize: cellSize, toolbarSide: .left), CGRect(x: 177.0, y: 4.0, width: 136.0, height: 374.0))
        XCTAssertEqual(chatMediaEditorStripFrame(size: size, safeInsets: insets, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: true, cellSize: cellSize, toolbarSide: .left), CGRect(x: 177.0, y: 4.0, width: 136.0, height: 310.0))
        XCTAssertEqual(chatMediaEditorStripFrame(size: size, safeInsets: insets, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: true, cellSize: cellSize, toolbarSide: .right), CGRect(x: 561.0, y: 4.0, width: 136.0, height: 310.0))
    }

    func testStripBackgroundGrowsFromTopWhenVertical() {
        let cellSize = CGSize(width: 128.0, height: 128.0)
        let horizontalSize = CGSize(width: 394.0, height: 136.0)
        XCTAssertEqual(chatMediaEditorStripBackgroundFrame(size: horizontalSize, count: 1, cellSize: cellSize, isVertical: false), CGRect(x: 258.0, y: 0.0, width: 136.0, height: 136.0))
        XCTAssertEqual(chatMediaEditorStripMaskFrame(size: horizontalSize, count: 1, cellSize: cellSize, isVertical: false), CGRect(x: 258.0, y: 4.0, width: 136.0, height: 128.0))
        let verticalSize = CGSize(width: 136.0, height: 310.0)
        XCTAssertEqual(chatMediaEditorStripBackgroundFrame(size: verticalSize, count: 1, cellSize: cellSize, isVertical: true), CGRect(x: 0.0, y: 0.0, width: 136.0, height: 136.0))
        XCTAssertEqual(chatMediaEditorStripBackgroundFrame(size: verticalSize, count: 2, cellSize: cellSize, isVertical: true), CGRect(x: 0.0, y: 0.0, width: 136.0, height: 268.0))
        XCTAssertEqual(chatMediaEditorStripBackgroundFrame(size: verticalSize, count: 5, cellSize: cellSize, isVertical: true), CGRect(x: 0.0, y: 0.0, width: 136.0, height: 310.0))
        XCTAssertEqual(chatMediaEditorStripMaskFrame(size: verticalSize, count: 2, cellSize: cellSize, isVertical: true), CGRect(x: 4.0, y: 0.0, width: 128.0, height: 268.0))
    }

    func testStripHiddenCenterSlidesTowardColumn() {
        XCTAssertEqual(chatMediaEditorStripHiddenCenter(size: CGSize(width: 394.0, height: 136.0), toolbarSide: nil), CGPoint(x: 197.0, y: 68.0 + 136.0 / 3.0))
        XCTAssertEqual(chatMediaEditorStripHiddenCenter(size: CGSize(width: 136.0, height: 310.0), toolbarSide: .left), CGPoint(x: 68.0 - 136.0 / 3.0, y: 155.0))
        XCTAssertEqual(chatMediaEditorStripHiddenCenter(size: CGSize(width: 136.0, height: 310.0), toolbarSide: .right), CGPoint(x: 68.0 + 136.0 / 3.0, y: 155.0))
    }
}
