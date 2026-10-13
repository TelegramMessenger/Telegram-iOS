import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `write(2)` may write fewer bytes than asked (disk full, file-size limit). The context
/// must record only what actually landed on disk, must not link the partial file as the
/// complete file, and must fail the fetch so the caller can retry.
final class MediaBoxFileContextV2ShortWriteTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var manager: MediaBoxFileManager!

    private var fullPath: String { return self.basePath + "/resource" }
    private var partialPath: String { return self.basePath + "/resource_partial" }
    private var metaPath: String { return self.basePath + "/resource_partial.meta" }

    private var context: MediaBoxFileContextV2Impl!

    private var previousLimit = rlimit()
    private var previousSignalHandler: sig_t?

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "MediaBoxFileContextV2ShortWriteTests")
        self.basePath = NSTemporaryDirectory() + "MediaBoxFileContextV2ShortWriteTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.manager = MediaBoxFileManager(queue: self.queue)
        self.queue.sync {
            self.context = MediaBoxFileContextV2Impl(
                queue: self.queue,
                manager: self.manager,
                storageBox: nil,
                resourceId: "resource".data(using: .utf8)!,
                path: self.fullPath,
                partialPath: self.partialPath,
                metaPath: self.metaPath
            )
        }
        XCTAssertNotNil(self.context)
        getrlimit(RLIMIT_FSIZE, &self.previousLimit)
    }

    override func tearDown() {
        setrlimit(RLIMIT_FSIZE, &self.previousLimit)
        if let previousSignalHandler = self.previousSignalHandler {
            signal(SIGXFSZ, previousSignalHandler)
        }
        // The context's file handles are released on its queue, as the file manager requires.
        self.queue.sync {
            self.context = nil
        }
        self.manager = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    /// Caps the size any file this process writes may reach, so a large write returns
    /// short. SIGXFSZ, which the kernel raises alongside EFBIG, is ignored for the test.
    private func limitFileSize(to bytes: rlim_t) {
        self.previousSignalHandler = signal(SIGXFSZ, SIG_IGN)
        var limit = self.previousLimit
        limit.rlim_cur = bytes
        XCTAssertEqual(setrlimit(RLIMIT_FSIZE, &limit), 0, "setrlimit failed: \(String(cString: strerror(errno)))")
    }

    func testShortWriteIsNotRecordedAndFailsTheFetch() {
        // Large enough that the meta file and test-runner logs stay well under the cap,
        // while the payload cannot fit.
        let cap: Int = 4 * 1024 * 1024
        let payload = Data(repeating: 0x5C, count: 2 * cap)
        self.limitFileSize(to: rlim_t(cap))
        defer {
            setrlimit(RLIMIT_FSIZE, &self.previousLimit)
        }

        let finished = self.expectation(description: "fetch finished")
        var failed = false
        self.queue.sync {
            let _ = self.context.fetched(range: 0 ..< Int64(payload.count), priority: .default, fetch: { _ in
                return Signal { subscriber in
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: payload, range: 0 ..< Int64(payload.count), complete: true))
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
            }, error: { _ in
                failed = true
                finished.fulfill()
            }, completed: {
                XCTFail("a short write must not complete the fetch")
                finished.fulfill()
            })
        }
        self.wait(for: [finished], timeout: 5.0)
        self.queue.sync {}
        setrlimit(RLIMIT_FSIZE, &self.previousLimit)

        XCTAssertTrue(failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.fullPath), "a file with missing bytes must not be linked as complete")

        var recorded: MediaBoxFileMap?
        self.queue.sync {
            recorded = try? MediaBoxFileMap.read(manager: self.manager, path: self.metaPath)
        }
        XCTAssertEqual(recorded?.sum ?? 0, 0, "the map must not claim bytes that were not written")
    }
}
