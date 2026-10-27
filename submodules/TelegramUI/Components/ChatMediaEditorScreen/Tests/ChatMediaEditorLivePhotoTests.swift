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
}
