import XCTest
@testable import CoreListDemo

final class TraceAssertionsTests: XCTestCase {
    private func frame(_ time: TimeInterval, container y: CGFloat = 0, items: [(Int, CGFloat, CGFloat)]) -> Frame {
        var map: [Int: ItemSnapshot] = [:]
        for (idx, screenY, h) in items {
            map[idx] = ItemSnapshot(modelFrame: CGRect(x: 0, y: 0, width: 390, height: h),
                                    resolvedScreenY: screenY,
                                    structuralScreenY: screenY,
                                    height: h,
                                    visualHeight: h,
                                    alpha: 1.0)
        }
        return Frame(time: time, containerOriginY: y, boundsOriginY: 0, containerTranslationY: 0, snapshotOriginY: nil, snapItems: [], items: map)
    }

    func testAssertContiguousEveryFrame_passes() {
        let trace: Trace = [
            frame(0, items: [(0, 0, 50), (1, 50, 50), (2, 100, 50)]),
            frame(0.1, items: [(0, -10, 50), (1, 40, 50), (2, 90, 50)]),
        ]
        trace.assertContiguousEveryFrame()
    }

    func testAssertNoVisibleJump_passes() {
        let trace: Trace = [
            frame(0, items: [(0, 0, 50)]),
            frame(0.016, items: [(0, -5, 50)]),
            frame(0.032, items: [(0, -10, 50)]),
        ]
        trace.assertNoVisibleJump(maxPerFrameDeltaY: 10)
    }

    func testAssertEndsAt_passes() {
        let trace: Trace = [
            frame(0, items: [(0, 0, 50)]),
            frame(0.5, items: [(0, -50, 50)]),
        ]
        trace.assertEndsAt(clockTime: 0.5, tolerance: 0.01)
    }

    func testAssertItemSettlesAt_passes() {
        let trace: Trace = [
            frame(0, items: [(5, 200, 50)]),
            frame(0.3, items: [(5, 100, 50)]),
        ]
        trace.assertItem(5, settlesAt: 100, tolerance: 0.5)
    }

    func testItemSnapshot_carriesAlpha() {
        let snapshot = ItemSnapshot(modelFrame: .zero,
                                    resolvedScreenY: 100,
                                    structuralScreenY: 100,
                                    height: 50,
                                    visualHeight: 50,
                                    alpha: 0.5)
        XCTAssertEqual(snapshot.alpha, 0.5, accuracy: 0.001)
    }
}
