import Foundation
import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class SavedStickerWriteTests: XCTestCase {
    private var postbox: Postbox!
    private var directory: URL!

    override func setUpWithError() throws {
        initializeAccountManagement()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("saved-sticker-tests-" + UUID().uuidString)
        let encryption = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: try XCTUnwrap(.init(data: Data(count: 32))), salt: try XCTUnwrap(.init(data: Data(count: 16))))
        let opened = try value(openPostbox(basePath: directory.path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryption, timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970), isMainProcess: true, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: true, removeDatabaseOnError: false)
            |> filter { result in
                if case .upgrading = result { return false }
                return true
            })
        guard case let .postbox(postbox) = opened else {
            throw NSError(domain: "SavedStickerWriteTests", code: 1)
        }
        self.postbox = postbox
    }

    override func tearDownWithError() throws {
        if let postbox = postbox {
            let _ = try value(postbox.transaction { _ in })
            let _ = try value(postbox.mediaBox.storageBox.all())
            let _ = try value(postbox.mediaBox.cacheStorageBox.all())
            postbox.mediaBox.dataQueue.sync {}
        }
        postbox = nil
        Postbox.sharedQueue.sync {}
        if let directory = directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func value<T>(_ signal: Signal<T, NoError>, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let completed = expectation(description: "signal completed")
        let result = Atomic<T?>(value: nil)
        let disposable = (signal |> take(1)).start(next: { value in
            let _ = result.swap(value)
        }, completed: { completed.fulfill() })
        defer { disposable.dispose() }
        wait(for: [completed], timeout: 15)
        return try XCTUnwrap(result.with { $0 }, file: file, line: line)
    }

    private func sticker(id: Int64, cloud: Bool = true) -> TelegramMediaFile {
        let resource: TelegramMediaResource = cloud
            ? CloudDocumentMediaResource(datacenterId: 2, fileId: id, accessHash: 1, size: nil, fileReference: nil, fileName: nil)
            : LocalFileMediaResource(fileId: id)
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: [.Sticker(displayText: "", packReference: nil, maskData: nil)], alternativeRepresentations: [])
    }

    private func savedIds() throws -> [Int64] {
        return try value(postbox.transaction { transaction in
            transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers).compactMap {
                $0.contents.get(SavedStickerItem.self)?.file.fileId.id
            }
        })
    }

    func testConfirmedWriteIsPresentAfterTransactionAndRepeatMovesToFront() throws {
        let first = sticker(id: 1)
        let second = sticker(id: 2)
        XCTAssertTrue(try value(postbox.transaction { transaction in
            addSavedStickerWithResult(transaction: transaction, file: first, stringRepresentations: [])
        }))
        XCTAssertEqual(try savedIds(), [1])
        XCTAssertTrue(try value(postbox.transaction { transaction in
            addSavedStickerWithResult(transaction: transaction, file: second, stringRepresentations: [])
        }))
        XCTAssertEqual(try savedIds(), [2, 1])
        XCTAssertTrue(try value(postbox.transaction { transaction in
            addSavedStickerWithResult(transaction: transaction, file: first, stringRepresentations: [])
        }))
        XCTAssertEqual(try savedIds(), [1, 2])
    }

    func testNonCloudResourceDoesNotClaimWriteOrScheduleSynchronization() throws {
        let file = sticker(id: 1, cloud: false)
        XCTAssertFalse(try value(postbox.transaction { transaction in
            addSavedStickerWithResult(transaction: transaction, file: file, stringRepresentations: [])
        }))
        XCTAssertTrue(try savedIds().isEmpty)
        let operationCount = try value(postbox.transaction { transaction in
            var count = 0
            transaction.operationLogEnumerateEntries(peerId: PeerId(0), tag: OperationLogTags.SynchronizeSavedStickers) { _ in
                count += 1
                return true
            }
            return count
        })
        XCTAssertEqual(operationCount, 0)
    }

    func testLimitTrimsOlderStickerButDoesNotRejectWriteAndLegacyAPIStillWrites() throws {
        let first = sticker(id: 1)
        let second = sticker(id: 2)
        let _ = try value(postbox.transaction { transaction in
            addSavedSticker(transaction: transaction, file: first, stringRepresentations: [], limit: 1)
        })
        XCTAssertEqual(try savedIds(), [1])
        XCTAssertTrue(try value(postbox.transaction { transaction in
            addSavedStickerWithResult(transaction: transaction, file: second, stringRepresentations: [], limit: 1)
        }))
        XCTAssertEqual(try savedIds(), [2])
    }
}
