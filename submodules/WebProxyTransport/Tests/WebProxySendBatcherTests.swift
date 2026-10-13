import XCTest
@testable import WebProxyTransport

final class WebProxySendBatcherTests: XCTestCase {
    private func frames(_ sizes: [Int]) -> [Data] {
        return sizes.map { Data(count: $0) }
    }

    func testEmptyQueueBatchesNothing() {
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: [], isFirstMessage: false, maximumFrames: 4096, maximumBytes: 2048), 0)
    }

    /// The relay's session-create body must be the lone HELLO frame; it caps that
    /// request at 64 bytes, so the first message can never carry a batch.
    func testFirstMessageIsAlwaysAlone() {
        let pending = self.frames([16, 16, 16])
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: pending, isFirstMessage: true, maximumFrames: 4096, maximumBytes: 2048), 1)
    }

    func testSubsequentMessagesCoalesce() {
        let pending = self.frames([16, 16, 16])
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: pending, isFirstMessage: false, maximumFrames: 4096, maximumBytes: 2048), 3)
    }

    func testStopsAtTheByteBudget() {
        let pending = self.frames([600, 600, 600, 600])
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: pending, isFirstMessage: false, maximumFrames: 4096, maximumBytes: 2048), 3)
    }

    func testStopsAtTheFrameBudget() {
        let pending = self.frames([1, 1, 1, 1, 1])
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: pending, isFirstMessage: false, maximumFrames: 2, maximumBytes: 2048), 2)
    }

    /// A single frame larger than the batch budget still has to go, or the queue wedges.
    func testAnOversizedLeadingFrameIsSentAlone() {
        let pending = self.frames([5000, 8])
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: pending, isFirstMessage: false, maximumFrames: 4096, maximumBytes: 2048), 1)
    }

    func testNeverExceedsTheQueue() {
        let pending = self.frames([8, 8])
        XCTAssertEqual(WebProxySendBatcher.batchCount(pending: pending, isFirstMessage: false, maximumFrames: 4096, maximumBytes: 1 << 20), 2)
    }

    func testDefaultsMatchTheProtocolLimits() {
        // 4096 frames is the bridge's hard cap: splitFrames throws past it.
        XCTAssertEqual(WebProxyProtocol.maximumBatchFrames, 4096)
        let pending = self.frames(Array(repeating: 8, count: 5000))
        XCTAssertEqual(
            WebProxySendBatcher.batchCount(
                pending: pending,
                isFirstMessage: false,
                maximumFrames: WebProxyProtocol.maximumBatchFrames,
                maximumBytes: WebProxyProtocol.defaultBatchSize
            ),
            4096
        )
    }
}
