import XCTest
import UIKit
import Display

final class AllMentionSendEffectLifecycleTests: XCTestCase {
    private func onMain(_ action: () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.sync(execute: action) }
    }

    private func animationKeys(_ node: AllMentionSendEffectNode) -> [String] {
        var pending = [node.layer]
        var result: [String] = []
        while let layer = pending.popLast() {
            result.append(contentsOf: layer.animationKeys() ?? [])
            pending.append(contentsOf: layer.sublayers ?? [])
        }
        return result
    }

    func testLiveReduceMotionStopsFlightAndCannotRestartIt() {
        let finished = expectation(description: "Reduced motion finishes once")
        onMain {
            XCTAssertFalse(UIAccessibility.isReduceMotionEnabled, "Run the moving-effect checks with system Reduce Motion off")
            let node = AllMentionSendEffectNode(reduceMotion: false)
            node.updateLayout(size: CGSize(width: 620.0, height: 420.0), transition: .immediate)
            var completions = 0
            node.play { completions += 1 }
            XCTAssertTrue(self.animationKeys(node).contains("allMentionArrival"))
            XCTAssertTrue(self.animationKeys(node).contains("allMentionParticle"))
            node.updateReduceMotion(true)
            node.updateReduceMotion(false)
            XCTAssertFalse(self.animationKeys(node).contains(where: { $0.hasPrefix("allMention") }))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                XCTAssertEqual(completions, 1)
                XCTAssertTrue(self.animationKeys(node).isEmpty)
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 2.0)
    }

    func testCancellationRemovesAnimationsAndScheduledDeparture() {
        let finished = expectation(description: "No late departure or second completion")
        onMain {
            let node = AllMentionSendEffectNode(reduceMotion: false)
            node.updateLayout(size: CGSize(width: 620.0, height: 420.0), transition: .immediate)
            var completions = 0
            node.play { completions += 1 }
            node.cancel()
            node.cancel()
            XCTAssertEqual(completions, 1)
            XCTAssertTrue(self.animationKeys(node).isEmpty)
            var replayCompletions = 0
            node.play { replayCompletions += 1 }
            XCTAssertEqual(replayCompletions, 1)
            XCTAssertTrue(self.animationKeys(node).isEmpty)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                XCTAssertEqual(completions, 1)
                XCTAssertTrue(self.animationKeys(node).isEmpty)
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 3.0)
    }

    func testCancelledPendingEffectCannotStartAfterLayout() {
        onMain {
            let node = AllMentionSendEffectNode(reduceMotion: false)
            var completions = 0
            node.play { completions += 1 }
            node.cancel()
            node.updateLayout(size: CGSize(width: 620.0, height: 420.0), transition: .immediate)
            XCTAssertEqual(completions, 1)
            XCTAssertTrue(self.animationKeys(node).isEmpty)
        }
    }

    func testReducedStartStaysReducedWhenPreferenceIsDisabled() {
        let finished = expectation(description: "Reduced start finishes without flight")
        onMain {
            let node = AllMentionSendEffectNode(reduceMotion: true)
            node.updateLayout(size: CGSize(width: 620.0, height: 420.0), transition: .immediate)
            var completions = 0
            node.play { completions += 1 }
            node.updateReduceMotion(false)
            XCTAssertFalse(self.animationKeys(node).contains(where: { $0.hasPrefix("allMention") }))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                XCTAssertEqual(completions, 1)
                XCTAssertTrue(self.animationKeys(node).isEmpty)
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 2.0)
    }
}
