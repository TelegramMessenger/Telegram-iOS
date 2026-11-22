import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import LocalMediaResources
@testable import MediaEditor
@testable import ChatMediaSend

private let capturedTestTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-captured-tests", processType: "tests", launchSpecificId: 1)
}()

private func writeCapturedTestFile(name: String, data: Data) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory() + "captured-test-\(name)-\(UInt32.random(in: 0 ... UInt32.max))")
    try? data.write(to: url)
    return url
}

private func capturedTestJpeg(size: CGSize) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.blue.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    return image.jpegData(compressionQuality: 0.9)!
}

private final class CapturedTestRenderer: ChatMediaSendRendering {
    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        return .single(.result(nil))
    }
}

final class ChatMediaSendCapturedTests: XCTestCase {
    func testSaveCapturedRule() {
        XCTAssertTrue(chatMediaSendSavesCapturedOriginal(saveCapturedMedia: true, isSecretChat: false, timer: nil))
        XCTAssertTrue(chatMediaSendSavesCapturedOriginal(saveCapturedMedia: true, isSecretChat: false, timer: 0))
        XCTAssertFalse(chatMediaSendSavesCapturedOriginal(saveCapturedMedia: true, isSecretChat: true, timer: nil))
        XCTAssertFalse(chatMediaSendSavesCapturedOriginal(saveCapturedMedia: false, isSecretChat: false, timer: nil))
        XCTAssertFalse(chatMediaSendSavesCapturedOriginal(saveCapturedMedia: true, isSecretChat: false, timer: 10))
        XCTAssertFalse(chatMediaSendSavesCapturedOriginal(saveCapturedMedia: true, isSecretChat: false, timer: viewOnceTimeout))

        let photo = writeCapturedTestFile(name: "photo.jpg", data: capturedTestJpeg(size: CGSize(width: 8.0, height: 6.0)))
        let video = writeCapturedTestFile(name: "video.mp4", data: Data([0, 1, 2, 3]))
        defer {
            try? FileManager.default.removeItem(at: photo)
            try? FileManager.default.removeItem(at: video)
        }
        let originals: [ChatMediaSendCapturedOriginal] = [.photo(photo), .video(video)]

        var deniedSaves: [ChatMediaSendCapturedOriginal] = []
        var deniedCompleted = false
        chatMediaSendSaveCapturedOriginals(originals, isAuthorized: { false }, save: { original, completion in
            deniedSaves.append(original)
            completion()
        }, completion: {
            deniedCompleted = true
        })
        XCTAssertTrue(deniedSaves.isEmpty)
        XCTAssertTrue(deniedCompleted)

        var saves: [ChatMediaSendCapturedOriginal] = []
        var completed = false
        chatMediaSendSaveCapturedOriginals(originals, isAuthorized: { true }, save: { original, completion in
            saves.append(original)
            completion()
        }, completion: {
            completed = true
        })
        XCTAssertEqual(saves, originals)
        XCTAssertTrue(completed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photo.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: video.path))

        var emptyCompleted = false
        chatMediaSendSaveCapturedOriginals([], isAuthorized: { true }, save: { _, completion in
            completion()
        }, completion: {
            emptyCompleted = true
        })
        XCTAssertTrue(emptyCompleted)
    }

    func testCapturedPhotoFileBuildsScaledImage() {
        let _ = capturedTestTempBoxInitialized
        let url = writeCapturedTestFile(name: "shot.jpg", data: capturedTestJpeg(size: CGSize(width: 2000.0, height: 1500.0)))
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let item = ChatMediaSendItem(uniqueId: "shot", source: .imageFile(path: url.path, dimensions: PixelDimensions(width: 2000, height: 1500)), options: ChatMediaSendItemOptions())
        XCTAssertFalse(chatMediaSendItemNeedsRender(item))
        XCTAssertFalse(chatMediaSendItemIsCameraRollCandidate(item))

        var outcome: ChatMediaSendOutcome?
        let expectation = self.expectation(description: "outcome")
        let disposable = chatMediaSendMessages(items: [item], global: ChatMediaSendGlobalOptions(grouping: true), renderer: CapturedTestRenderer(), makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()

        XCTAssertEqual(outcome?.droppedUniqueIds, [])
        XCTAssertEqual(outcome?.messages.count, 1)
        guard let message = outcome?.messages.first, case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message.message, let image = mediaReference?.media as? TelegramMediaImage else {
            XCTFail()
            return
        }
        XCTAssertEqual(image.representations.last?.dimensions, PixelDimensions(width: 1280, height: 960))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        var edited = item
        edited.values = chatMediaEditorValues(peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)), originalDimensions: PixelDimensions(width: 2000, height: 1500), qualityPreset: .compressedVeryHigh)
        XCTAssertTrue(chatMediaSendItemNeedsRender(edited))
    }
}
