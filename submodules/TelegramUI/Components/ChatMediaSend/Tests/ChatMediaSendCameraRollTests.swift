import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import LocalMediaResources
@testable import MediaEditor
@testable import ChatMediaSend

private let cameraRollTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private let cameraRollTestTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-camera-roll-tests", processType: "tests", launchSpecificId: 1)
}()

private final class CameraRollTestRenderer: ChatMediaSendRendering {
    private let lock = NSLock()
    private var _renders: [String: Bool] = [:]

    var renders: [String: Bool] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self._renders
    }

    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        self.lock.lock()
        self._renders[item.uniqueId] = forceHd
        self.lock.unlock()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64.0, height: 48.0), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 64.0, height: 48.0))
        }
        return .single(.result(image))
    }
}

private final class CameraRollTestLivePreparer: ChatMediaSendLivePhotoPreparing {
    private let lock = NSLock()
    private var _stillRequests: [String: Bool] = [:]

    var stillRequests: [String: Bool] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self._stillRequests
    }

    func prepareLivePhoto(item: ChatMediaSendItem, renderer: ChatMediaSendRendering) -> Signal<ChatMediaSendPreparedLivePhoto?, NoError> {
        self.lock.lock()
        self._stillRequests[item.uniqueId] = item.rendersCameraRollStill
        self.lock.unlock()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80.0, height: 60.0), format: format).image { context in
            UIColor.purple.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 80.0, height: 60.0))
        }
        return .single(ChatMediaSendPreparedLivePhoto(video: ChatMediaSendLivePhotoVideo(path: "/tmp/live-\(item.uniqueId).mp4", dimensions: PixelDimensions(width: 1920, height: 1440), duration: 2.0), image: image))
    }
}

private final class CameraRollTestStalledRenderer: ChatMediaSendRendering {
    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        if item.uniqueId == "stalled" {
            return .never()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return .single(.result(UIGraphicsImageRenderer(size: CGSize(width: 32.0, height: 32.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        }))
    }
}

private func cameraRollTestTempFiles() -> Set<String> {
    let directory = NSTemporaryDirectory()
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
    return Set(names.filter { $0.hasPrefix("camera-roll-") }.map { (directory as NSString).appendingPathComponent($0) })
}

final class ChatMediaSendCameraRollTests: XCTestCase {
    private let photoSize = CGSize(width: 4032.0, height: 3024.0)

    override func setUp() {
        super.setUp()
        let _ = cameraRollTestTempBoxInitialized
    }

    private func plainValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: cameraRollTestPeerId, originalDimensions: PixelDimensions(self.photoSize), qualityPreset: .compressedVeryHigh)
    }

    private func toolValues() -> MediaEditorValues {
        return self.plainValues().withUpdatedToolValues([.brightness: Float(0.4)])
    }

    private func stickerFile(_ id: Int64, animated: Bool) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: LocalFileMediaResource(fileId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: animated ? "application/x-tgsticker" : "image/webp", size: nil, attributes: [.FileName(fileName: "sticker.tgs")], alternativeRepresentations: [])
    }

    private func stickerValues(animated: Bool) -> MediaEditorValues {
        let entity = DrawingStickerEntity(content: .file(.standalone(media: self.stickerFile(9, animated: animated)), .sticker))
        return self.plainValues().withUpdatedEntities([.sticker(entity)])
    }

    private func croppedValues() -> MediaEditorValues {
        return self.plainValues().withUpdatedCrop(rect: CGRect(x: 10.0, y: 10.0, width: 2000.0, height: 2000.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
    }

    private func photoItem(_ id: String, values: MediaEditorValues?, timer: Int32? = nil) -> ChatMediaSendItem {
        return ChatMediaSendItem(uniqueId: id, source: .libraryAsset(identifier: id, pixelSize: self.photoSize, isVideo: false, duration: 0.0), values: values, stickers: values.flatMap { chatMediaSendCollectStickers(entities: $0.entities) } ?? [], options: ChatMediaSendItemOptions(timer: timer))
    }

    private func send(_ items: [ChatMediaSendItem], save: Bool, renderer: CameraRollTestRenderer) throws -> ChatMediaSendOutcome {
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: false, saveEditedPhotosToCameraRoll: save), renderer: renderer, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        return try XCTUnwrap(outcome)
    }

    func testSaveEditedPhotosRule() throws {
        XCTAssertTrue(chatMediaSendSavesEditedPhotos(saveEditedPhotos: true, isSecretChat: false, isPasteboard: false))
        XCTAssertFalse(chatMediaSendSavesEditedPhotos(saveEditedPhotos: false, isSecretChat: false, isPasteboard: false))
        XCTAssertFalse(chatMediaSendSavesEditedPhotos(saveEditedPhotos: true, isSecretChat: true, isPasteboard: false))
        XCTAssertFalse(chatMediaSendSavesEditedPhotos(saveEditedPhotos: true, isSecretChat: false, isPasteboard: true))

        XCTAssertTrue(chatMediaSendItemIsCameraRollCandidate(self.photoItem("tools", values: self.toolValues())))
        XCTAssertTrue(chatMediaSendItemIsCameraRollCandidate(self.photoItem("sticker", values: self.stickerValues(animated: false))))
        XCTAssertFalse(chatMediaSendItemIsCameraRollCandidate(self.photoItem("crop", values: self.croppedValues())))
        XCTAssertFalse(chatMediaSendItemIsCameraRollCandidate(self.photoItem("plain", values: nil)))
        XCTAssertFalse(chatMediaSendItemIsCameraRollCandidate(self.photoItem("animated", values: self.stickerValues(animated: true))))
        let video = ChatMediaSendItem(uniqueId: "video", source: .libraryAsset(identifier: "video", pixelSize: self.photoSize, isVideo: true, duration: 3.0), values: self.toolValues(), options: ChatMediaSendItemOptions())
        XCTAssertFalse(chatMediaSendItemIsCameraRollCandidate(video))
        let live = ChatMediaSendItem(uniqueId: "live", source: .livePhoto(identifier: "live", pixelSize: self.photoSize, mode: .live), values: self.toolValues(), options: ChatMediaSendItemOptions(isLivePhoto: true))
        XCTAssertTrue(chatMediaSendItemIsCameraRollCandidate(live))
        let liveCrop = ChatMediaSendItem(uniqueId: "live-crop", source: .livePhoto(identifier: "live-crop", pixelSize: self.photoSize, mode: .loop), values: self.croppedValues(), options: ChatMediaSendItemOptions(livePhotoLoopOrBounce: true))
        XCTAssertFalse(chatMediaSendItemIsCameraRollCandidate(liveCrop))
        let pasted = ChatMediaSendItem(uniqueId: "pasted", source: .image(UIImage()), values: self.toolValues(), options: ChatMediaSendItemOptions())
        XCTAssertTrue(chatMediaSendItemIsCameraRollCandidate(pasted))

        XCTAssertTrue(ChatMediaSendPlannedItem(index: 0, caption: nil, groupingKey: nil, timer: 10, spoiler: false, price: nil).isExcludedFromCameraRoll)
        XCTAssertFalse(ChatMediaSendPlannedItem(index: 0, caption: nil, groupingKey: nil, timer: nil, spoiler: false, price: nil).isExcludedFromCameraRoll)

        let items = [
            self.photoItem("tools", values: self.toolValues()),
            self.photoItem("timer", values: self.toolValues(), timer: 10),
            self.photoItem("crop", values: self.croppedValues()),
            self.photoItem("plain", values: nil),
            self.photoItem("sticker", values: self.stickerValues(animated: false))
        ]
        let renderer = CameraRollTestRenderer()
        let outcome = try self.send(items, save: true, renderer: renderer)
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["tools", "timer", "crop", "plain", "sticker"])
        XCTAssertEqual(outcome.cameraRollImagePaths.count, 2)
        for path in outcome.cameraRollImagePaths {
            let image = try XCTUnwrap(UIImage(contentsOfFile: path))
            XCTAssertEqual(image.size, CGSize(width: 64.0, height: 48.0))
        }
        XCTAssertEqual(renderer.renders, ["tools": true, "timer": false, "crop": false, "sticker": true])

        let saved = Atomic<[String]>(value: [])
        let done = self.expectation(description: "saved")
        chatMediaSendSaveToCameraRoll(paths: outcome.cameraRollImagePaths, isAuthorized: { true }, save: { url, completion in
            let _ = saved.modify { $0 + [url.path] }
            DispatchQueue.global().async {
                completion()
            }
        }, completion: {
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(saved.with { $0 }, outcome.cameraRollImagePaths)
        for path in outcome.cameraRollImagePaths {
            XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        }

        let offRenderer = CameraRollTestRenderer()
        let offOutcome = try self.send(items, save: false, renderer: offRenderer)
        XCTAssertTrue(offOutcome.cameraRollImagePaths.isEmpty)
        XCTAssertEqual(offRenderer.renders, ["tools": false, "timer": false, "crop": false, "sticker": false])
    }

    private func liveItem(_ id: String, mode: ChatMediaSendLivePhotoMode, values: MediaEditorValues?, timer: Int32? = nil) -> ChatMediaSendItem {
        return ChatMediaSendItem(uniqueId: id, source: .livePhoto(identifier: id, pixelSize: self.photoSize, mode: mode), values: values, options: ChatMediaSendItemOptions(timer: timer, livePhotoLoopOrBounce: mode.isLoopOrBounce, isLivePhoto: mode == .live))
    }

    func testEditedLivePhotosSavedInEveryMode() throws {
        initializeAccountManagement()
        let items = [
            self.liveItem("live", mode: .live, values: self.toolValues()),
            self.liveItem("loop", mode: .loop, values: self.toolValues()),
            self.liveItem("bounce", mode: .bounce, values: self.stickerValues(animated: false)),
            self.liveItem("timer", mode: .live, values: self.toolValues(), timer: 10),
            self.liveItem("crop", mode: .live, values: self.croppedValues()),
            self.liveItem("plain", mode: .live, values: nil)
        ]
        let preparer = CameraRollTestLivePreparer()
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: false, saveEditedPhotosToCameraRoll: true), renderer: CameraRollTestRenderer(), livePhotoPreparer: preparer, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(result.droppedUniqueIds, [])
        XCTAssertEqual(preparer.stillRequests, ["live": true, "loop": true, "bounce": true, "timer": false, "crop": false, "plain": false])
        XCTAssertEqual(result.cameraRollImagePaths.count, 3)
        for path in result.cameraRollImagePaths {
            let image = try XCTUnwrap(UIImage(contentsOfFile: path))
            XCTAssertEqual(image.size, CGSize(width: 80.0, height: 60.0))
        }
        chatMediaSendDiscardCameraRollImages(result.cameraRollImagePaths)

        let offPreparer = CameraRollTestLivePreparer()
        let offExpectation = self.expectation(description: "off")
        var offOutcome: ChatMediaSendOutcome?
        let offDisposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: false), renderer: CameraRollTestRenderer(), livePhotoPreparer: offPreparer, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                offOutcome = value
                offExpectation.fulfill()
            }
        })
        self.wait(for: [offExpectation], timeout: 10.0)
        offDisposable.dispose()
        XCTAssertEqual(offOutcome?.cameraRollImagePaths, [])
        XCTAssertTrue(offPreparer.stillRequests.values.allSatisfy { !$0 })
    }

    func testLivePhotoPreparerRendersFullSizeStillForCameraRoll() {
        for flag in [true, false] {
            var item = self.liveItem("missing-live-asset", mode: .live, values: self.toolValues())
            item.rendersCameraRollStill = flag
            let renderer = CameraRollTestRenderer()
            let expectation = self.expectation(description: "prepared")
            let disposable = ChatMediaSendLivePhotoPreparer.shared.prepareLivePhoto(item: item, renderer: renderer).start(next: { _ in
                expectation.fulfill()
            })
            self.wait(for: [expectation], timeout: 10.0)
            disposable.dispose()
            XCTAssertEqual(renderer.renders, ["missing-live-asset": flag])
        }
    }

    func testSaveSkippedWithoutFullAccess() throws {
        let path = NSTemporaryDirectory() + "chat-media-send-camera-roll-auth-\(UInt64.random(in: 0 ... UInt64.max)).jpg"
        try Data([1]).write(to: URL(fileURLWithPath: path))
        var saved = false
        let done = self.expectation(description: "done")
        chatMediaSendSaveToCameraRoll(paths: [path], isAuthorized: { false }, save: { _, completion in
            saved = true
            completion()
        }, completion: {
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertFalse(saved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testPhotoLibraryAccessRequestedOnlyWhenUndeterminedAndSaving() {
        let table: [(access: ChatMediaSendPhotoLibraryAccess, hasMediaToSave: Bool, requests: Bool)] = [
            (.notDetermined, true, true),
            (.notDetermined, false, false),
            (.authorized, true, false),
            (.limited, true, false),
            (.denied, true, false)
        ]
        for row in table {
            var requested = false
            var completed = 0
            chatMediaSendPreparePhotoLibraryAccess(hasMediaToSave: row.hasMediaToSave, access: { row.access }, request: { done in
                requested = true
                done()
            }, completion: {
                completed += 1
            })
            XCTAssertEqual(requested, row.requests)
            XCTAssertEqual(completed, 1)
        }
    }

    func testCancelledSendDiscardsCameraRollFiles() throws {
        let before = cameraRollTestTempFiles()
        let items = [
            self.photoItem("written", values: self.toolValues()),
            self.photoItem("stalled", values: self.toolValues())
        ]
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: false, saveEditedPhotosToCameraRoll: true), renderer: CameraRollTestStalledRenderer(), makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { _ in
        })
        let deadline = Date().addingTimeInterval(5.0)
        var written: Set<String> = []
        while written.isEmpty && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            written = cameraRollTestTempFiles().subtracting(before)
        }
        XCTAssertEqual(written.count, 1)
        disposable.dispose()
        for path in written {
            XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        }
    }

    func testDiscardCameraRollImagesRemovesFiles() throws {
        let path = NSTemporaryDirectory() + "chat-media-send-camera-roll-\(UInt64.random(in: 0 ... UInt64.max)).jpg"
        try Data([1]).write(to: URL(fileURLWithPath: path))
        chatMediaSendDiscardCameraRollImages([path])
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
}
