import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramCore

/// A real account store for the intents extension's tests, opened the way the extension
/// opens one (same seed configuration, encryption parameters, temporary mode) and closed
/// without racing its own queues.
final class TestPostbox {
    let basePath: String
    private(set) var postbox: Postbox!

    /// The extension installs a shared logger before anything else; code under test logs
    /// through it, and without one the logger traps. Installed once, writing nowhere.
    private static let installSilentLogger: Void = {
        let logger = Logger(rootPath: NSTemporaryDirectory(), basePath: NSTemporaryDirectory())
        logger.logToFile = false
        logger.logToConsole = false
        Logger.setSharedLogger(logger)
    }()

    init(name: String) throws {
        let _ = TestPostbox.installSilentLogger
        // The extension registers TelegramCore's stored types before it opens the account;
        // without this the seeded peers do not decode and every chat renders as absent.
        initializeAccountManagement()
        self.basePath = NSTemporaryDirectory() + name + "-" + UUID().uuidString
        let encryptionParameters = ValueBoxEncryptionParameters(
            forceEncryptionIfNoSet: false,
            key: ValueBoxEncryptionParameters.Key(data: Data(count: 32))!,
            salt: ValueBoxEncryptionParameters.Salt(data: Data(count: 16))!
        )
        let opened = DispatchSemaphore(value: 0)
        var postbox: Postbox?
        let disposable = openPostbox(
            basePath: self.basePath,
            seedConfiguration: telegramPostboxSeedConfiguration,
            encryptionParameters: encryptionParameters,
            timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970),
            isMainProcess: true,
            isTemporary: true,
            isReadOnly: false,
            useCopy: false,
            useCaches: false,
            removeDatabaseOnError: true
        ).start(next: { result in
            if case let .postbox(value) = result {
                postbox = value
                opened.signal()
            }
        })
        XCTAssertEqual(opened.wait(timeout: .now() + 30.0), .success, "postbox did not open")
        disposable.dispose()
        self.postbox = try XCTUnwrap(postbox)
    }

    /// The media box opens its storage database lazily on its own queue; deleting the
    /// directory while that open is in flight trips an assertion inside SQLite setup (and
    /// the next store to open then finds a half-deleted folder). A round trip through that
    /// queue makes sure the open has finished before anything is removed.
    func close() {
        let storageReady = DispatchSemaphore(value: 0)
        let disposable = self.postbox.mediaBox.storageBox.totalSize().start(next: { _ in
            storageReady.signal()
        })
        let _ = storageReady.wait(timeout: .now() + 10.0)
        disposable.dispose()
        self.transaction { _ in }
        self.postbox = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
    }

    /// Runs `f` as a transaction and waits for it to commit.
    @discardableResult
    func transaction<T>(_ f: @escaping (Transaction) -> T, file: StaticString = #file, line: UInt = #line) -> T? {
        let done = DispatchSemaphore(value: 0)
        var result: T?
        let disposable = self.postbox.transaction(f).start(next: { value in
            result = value
        }, completed: {
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 30.0), .success, "transaction did not finish", file: file, line: line)
        disposable.dispose()
        return result
    }

    /// The first value of `signal`, waited for.
    func first<T>(_ signal: Signal<T, NoError>, file: StaticString = #file, line: UInt = #line) -> T? {
        let done = DispatchSemaphore(value: 0)
        var result: T?
        let disposable = (signal |> take(1)).start(next: { value in
            result = value
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 30.0), .success, "signal did not emit", file: file, line: line)
        disposable.dispose()
        return result
    }
}
