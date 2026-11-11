import XCTest
import SwiftSignalKit
@testable import ChatControllerInteraction

final class ChatIsOpeningMediaTests: XCTestCase {
    private let queue = Queue()
    private let unannouncedTimeout: Double = 0.2
    private let announcedTimeout: Double = 1.0
    // Checks are made well clear of either deadline, so a busy test runner oversleeping does not flip them.
    private let margin: Double = 0.3

    private final class Recorder {
        private let lock = NSLock()
        private var storage: [Bool] = []

        var values: [Bool] {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.storage
        }

        func append(_ value: Bool) {
            self.lock.lock()
            self.storage.append(value)
            self.lock.unlock()
        }
    }

    private func record(_ blockInteraction: Promise<Bool>) -> (Recorder, Disposable) {
        let recorder = Recorder()
        let disposable = chatIsOpeningMedia(blockInteraction: blockInteraction.get(), unannouncedTimeout: self.unannouncedTimeout, announcedTimeout: self.announcedTimeout, queue: self.queue).start(next: { value in
            recorder.append(value)
        })
        return (recorder, disposable)
    }

    private func wait(_ seconds: Double) {
        let expectation = self.expectation(description: "wait")
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: seconds + 2.0)
    }

    // An open that says nothing (a file, a voice message, a link) blocks repeated taps briefly, as before.
    func testAnOpenThatNeverReportsIsReleasedAfterTheShortTimeout() {
        let blockInteraction = Promise<Bool>()
        let (recorder, disposable) = self.record(blockInteraction)
        defer { disposable.dispose() }

        XCTAssertEqual(recorder.values, [true])
        self.wait(self.unannouncedTimeout + self.margin)
        XCTAssertEqual(recorder.values, [true, false])
    }

    // A gallery reports that it is opening and stays blocked past the short timeout until it reports it is on screen.
    func testAGalleryOnItsWayStaysBlockedUntilItIsOnScreen() {
        let blockInteraction = Promise<Bool>()
        let (recorder, disposable) = self.record(blockInteraction)
        defer { disposable.dispose() }

        blockInteraction.set(.single(true))
        self.wait(self.unannouncedTimeout + self.margin)
        XCTAssertEqual(recorder.values, [true, true])

        blockInteraction.set(.single(false))
        XCTAssertEqual(recorder.values, [true, true, false])

        self.wait(self.announcedTimeout + self.margin)
        XCTAssertEqual(recorder.values, [true, true, false])
    }

    // A gallery that reports it is opening but never that it arrived does not leave the chat's media blocked.
    func testAGalleryThatNeverArrivesIsReleasedAfterTheLongTimeout() {
        let blockInteraction = Promise<Bool>()
        let (recorder, disposable) = self.record(blockInteraction)
        defer { disposable.dispose() }

        blockInteraction.set(.single(true))
        self.wait(self.unannouncedTimeout + self.margin)
        XCTAssertEqual(recorder.values, [true, true])

        self.wait(self.announcedTimeout - self.unannouncedTimeout)
        XCTAssertEqual(recorder.values, [true, true, false])
    }
}
