import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import AccountContext
import ChatMediaSend
import ChatMediaEditorScreen

private final class FakeLiveSelectionAdapter: ChatMediaEditorSelectionAdapter {
    let selectionLimit: Int = 100
    private(set) var selected: [String]
    private let pipe = ValuePipe<Void>()

    init(selected: [String] = []) {
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
        if selected {
            if self.selected.contains(uniqueId) {
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

    var changes: Signal<Void, NoError> {
        return self.pipe.signal()
    }
}

private final class FakeLivePhotoAdapter: ChatMediaEditorLivePhotoAdapter {
    var isForceLivePhotoEnabled = false
    private(set) var modes: [String: ChatMediaSendLivePhotoMode] = [:]
    private(set) var writes: [(String, ChatMediaSendLivePhotoMode)] = []

    func livePhotoMode(for uniqueId: String) -> ChatMediaSendLivePhotoMode? {
        return self.modes[uniqueId]
    }

    func setLivePhotoMode(_ mode: ChatMediaSendLivePhotoMode, for uniqueId: String) {
        self.writes.append((uniqueId, mode))
        self.modes[uniqueId] = mode
    }
}

final class ChatMediaEditorLivePhotoTests: XCTestCase {
    private func peerId(_ namespace: EnginePeer.Id.Namespace, _ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: namespace, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    func testLivePhotoButtonGating() {
        XCTAssertTrue(chatMediaGalleryHasLivePhotoButton(peerId: self.peerId(Namespaces.Peer.CloudUser, 2)))
        XCTAssertTrue(chatMediaGalleryHasLivePhotoButton(peerId: self.peerId(Namespaces.Peer.CloudChannel, 2)))
        XCTAssertTrue(chatMediaGalleryHasLivePhotoButton(peerId: self.peerId(Namespaces.Peer.CloudGroup, 2)))
        XCTAssertFalse(chatMediaGalleryHasLivePhotoButton(peerId: self.peerId(Namespaces.Peer.SecretChat, 2)))
        XCTAssertFalse(chatMediaGalleryHasLivePhotoButton(peerId: nil))

        XCTAssertTrue(chatMediaEditorLivePhotoButtonIsVisible(hasLivePhotoButton: true, isLiveAsset: true))
        XCTAssertFalse(chatMediaEditorLivePhotoButtonIsVisible(hasLivePhotoButton: false, isLiveAsset: true))
        XCTAssertFalse(chatMediaEditorLivePhotoButtonIsVisible(hasLivePhotoButton: true, isLiveAsset: false))
    }

    func testLiveModeResolved() {
        let adapter = FakeLivePhotoAdapter()
        let model = ChatMediaEditorLivePhotoModel(adapter: adapter, selection: nil)
        XCTAssertEqual(model.mode(for: "a", isLiveAsset: true), .off)
        adapter.isForceLivePhotoEnabled = true
        XCTAssertEqual(model.mode(for: "a", isLiveAsset: true), .live)
        XCTAssertEqual(model.mode(for: "a", isLiveAsset: false), .off)
        adapter.setLivePhotoMode(.bounce, for: "a")
        XCTAssertEqual(model.mode(for: "a", isLiveAsset: true), .bounce)
        adapter.setLivePhotoMode(.off, for: "a")
        XCTAssertEqual(model.mode(for: "a", isLiveAsset: true), .off)
    }

    func testLiveModeChangeAutoSelects() {
        let adapter = FakeLivePhotoAdapter()
        let selectionAdapter = FakeLiveSelectionAdapter(selected: ["x"])
        let selection = ChatMediaEditorSelectionModel(adapter: selectionAdapter)
        let model = ChatMediaEditorLivePhotoModel(adapter: adapter, selection: selection)

        model.modeUpdated(.loop, for: "a")
        XCTAssertEqual(adapter.writes.map { $0.0 }, ["a"])
        XCTAssertEqual(adapter.writes.map { $0.1 }, [.loop])
        XCTAssertEqual(selectionAdapter.selected, ["x", "a"])

        model.modeUpdated(.off, for: "a")
        XCTAssertEqual(adapter.modes["a"], .off)
        XCTAssertEqual(selectionAdapter.selected, ["x", "a"])
    }

    func testLivePhotoButtonFrame() {
        let safeInsets = UIEdgeInsets(top: 59.0, left: 0.0, bottom: 34.0, right: 0.0)
        let size = CGSize(width: 402.0, height: 874.0)
        let buttonSize = CGSize(width: 70.0, height: 18.0)
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: size, safeInsets: safeInsets, keyboardHeight: 0.0, buttonSize: buttonSize), CGRect(x: 16.0, y: 145.0, width: 70.0, height: 18.0))
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: size, safeInsets: safeInsets, keyboardHeight: 300.0, buttonSize: buttonSize), CGRect(x: 16.0, y: -155.0, width: 70.0, height: 18.0))
        let landscape = UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0)
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: CGSize(width: 874.0, height: 402.0), safeInsets: landscape, keyboardHeight: 0.0, buttonSize: buttonSize), CGRect(x: 75.0, y: 48.0, width: 70.0, height: 18.0))
    }

    // iPhone Duo: in portrait the badge sits 18pt under the chat-name row, as in landscape on every phone (the row ends
    // at 30 there, the badge at 48): on the unfolded screen the row is on the status island's clock line, on the folded
    // one at the top. A phone keeps the fixed 145.
    func testLivePhotoButtonSitsUnderTheChatNameOnTheDuo() {
        let buttonSize = CGSize(width: 70.0, height: 18.0)
        let arrowSize = CGSize(width: 10.0, height: 12.0)
        let labelSize = CGSize(width: 80.0, height: 16.0)
        // Unfolded portrait, the island's band as the top inset.
        let unfolded = CGSize(width: 669.0, height: 951.0)
        let unfoldedInsets = UIEdgeInsets(top: 82.0, left: 0.0, bottom: 20.0, right: 0.0)
        let island = ChatMediaEditorStatusIslandRow(clockLineY: 47.0, trailingInset: 134.0)
        let unfoldedRow = chatMediaEditorRecipientLayout(size: unfolded, safeInsets: unfoldedInsets, arrowSize: arrowSize, labelSize: labelSize, statusIsland: island)
        let unfoldedRowMaxY = max(unfoldedRow.arrowFrame.maxY, unfoldedRow.labelFrame.maxY)
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: unfolded, safeInsets: unfoldedInsets, keyboardHeight: 0.0, buttonSize: buttonSize, titleRowMaxY: unfoldedRowMaxY).minY, unfoldedRowMaxY + 18.0)
        // Folded portrait: no top inset, the strip on the right.
        let folded = CGSize(width: 466.0, height: 678.0)
        let foldedInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let foldedRow = chatMediaEditorRecipientLayout(size: folded, safeInsets: foldedInsets, arrowSize: arrowSize, labelSize: labelSize)
        let foldedRowMaxY = max(foldedRow.arrowFrame.maxY, foldedRow.labelFrame.maxY)
        XCTAssertEqual(foldedRowMaxY, 30.0)
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: folded, safeInsets: foldedInsets, keyboardHeight: 0.0, buttonSize: buttonSize, titleRowMaxY: foldedRowMaxY).minY, 48.0)
        // The same 18pt as landscape's 48 under a row ending at 30.
        let landscapeRow = chatMediaEditorRecipientLayout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0), arrowSize: arrowSize, labelSize: labelSize)
        XCTAssertEqual(48.0 - max(landscapeRow.arrowFrame.maxY, landscapeRow.labelFrame.maxY), 18.0)
        // Without a row (every other device) the phone's place.
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: unfolded, safeInsets: unfoldedInsets, keyboardHeight: 0.0, buttonSize: buttonSize, titleRowMaxY: nil).minY, 145.0)
    }
}
