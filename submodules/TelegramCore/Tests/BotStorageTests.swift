import Foundation
import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

/// A Mini App's DeviceStorage writes report back only when their signal finishes: `device_storage_key_saved` and
/// `device_storage_cleared` are sent on completion, `device_storage_failed` on error.
final class BotStorageTests: XCTestCase {
    private enum Outcome: Equatable {
        case completed
        case failed(BotStorageError)
    }

    private let botId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1001))
    private var postbox: Postbox!
    private var directory: URL!

    override func setUpWithError() throws {
        initializeAccountManagement()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("bot-storage-tests-" + UUID().uuidString)
        let encryption = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: try XCTUnwrap(.init(data: Data(count: 32))), salt: try XCTUnwrap(.init(data: Data(count: 16))))
        let opened = try value(openPostbox(basePath: directory.path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryption, timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970), isMainProcess: true, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: true, removeDatabaseOnError: false)
            |> filter { result in
                if case .upgrading = result { return false }
                return true
            })
        guard case let .postbox(postbox) = opened else {
            throw NSError(domain: "BotStorageTests", code: 1)
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

    private func outcome(_ signal: Signal<Never, BotStorageError>) -> Outcome? {
        let finished = expectation(description: "storage update finished")
        let result = Atomic<Outcome?>(value: nil)
        let disposable = signal.start(error: { error in
            let _ = result.swap(.failed(error))
            finished.fulfill()
        }, completed: {
            let _ = result.swap(.completed)
            finished.fulfill()
        })
        defer { disposable.dispose() }
        wait(for: [finished], timeout: 5)
        return result.with { $0 }
    }

    private func storedData() throws -> [String: String]? {
        let botId = self.botId
        return try value(postbox.transaction { transaction in
            transaction.getPreferencesEntry(key: PreferencesKeys.botStorageState(peerId: botId))?.get(TelegramBotStorageState.self)?.data
        })
    }

    func testSavingAndRemovingAKeyComplete() throws {
        XCTAssertEqual(outcome(_internal_setBotStorageValue(postbox: postbox, peerId: botId, key: "theme", value: "dark")), .completed)
        XCTAssertEqual(try storedData(), ["theme": "dark"])

        XCTAssertEqual(outcome(_internal_setBotStorageValue(postbox: postbox, peerId: botId, key: "theme", value: nil)), .completed)
        XCTAssertEqual(try storedData(), [:])
    }

    func testClearingCompletes() throws {
        XCTAssertEqual(outcome(_internal_setBotStorageValue(postbox: postbox, peerId: botId, key: "theme", value: "dark")), .completed)

        XCTAssertEqual(outcome(_internal_clearBotStorage(postbox: postbox, peerId: botId)), .completed)
        XCTAssertEqual(try storedData(), [:])
    }

    func testAValueOverTheQuotaFailsAndKeepsTheStoredOnes() throws {
        XCTAssertEqual(outcome(_internal_setBotStorageValue(postbox: postbox, peerId: botId, key: "theme", value: "dark")), .completed)

        let oversized = String(repeating: "a", count: 5 * 1024 * 1024 + 1)
        XCTAssertEqual(outcome(_internal_setBotStorageValue(postbox: postbox, peerId: botId, key: "blob", value: oversized)), .failed(.quotaExceeded))
        XCTAssertEqual(try storedData(), ["theme": "dark"])
    }
}
