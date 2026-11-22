import QuartzCore
import UIKit
import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D2/D7: a widget stuck in a task holds one pool thread and the other serves every other widget; two
/// widgets run at once, each drawing its own pixels.
class ConcurrencyTests: MessageWidgetTestCase {
    /// Pin. Break: make the test pool one thread (`MessageWidgetPool(threadCount: 1)` in `TestSupport.setUp`) and this
    /// fails at "the other thread served it".
    func testAStuckWidgetHoldsOneThreadAndTheOtherServes() {
        let stuck = self.make("<!doctype html><p>stuck</p>", policy: MessageWidgetWaitPolicy(cap: 0.05))
        let gate = stuck.gateNextTaskForTesting()
        defer {
            gate.release.signal()
        }
        let start = CACurrentMediaTime()
        XCTAssertEqual(stuck.layout(width: 300.0), CGSize(width: 300.0, height: MessageWidgetInstance.placeholderHeight))
        XCTAssertLessThan(CACurrentMediaTime() - start, 1.0, "main's wait ended at the cap")
        XCTAssertEqual(gate.started.wait(timeout: .now() + 5.0), .success)
        let other = self.make(self.fixture("02-split-bill"), policy: MessageWidgetWaitPolicy(cap: 5.0))
        let size = other.layout(width: 360.0)
        guard other.appliedForTesting[.boot] == 1 else {
            return XCTFail("the other thread served it: the second widget's boot did not finish within 5 s")
        }
        XCTAssertGreaterThan(size.height, 60.0)
        XCTAssertEqual(other.evaluateForTesting("document.getElementById('plus').click(); document.getElementById('n').textContent"), "5")
        other.destroy()
        // Destroying the stuck widget returns at once; its teardown waits for the task it is in.
        stuck.destroy()
        XCTAssertFalse(stuck.isIdleForTesting)
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { stuck.isIdleForTesting }))
    }

    /// Review Focus 5. Pin. Break: as above (one thread), and this fails at "both boots are running at once". The two
    /// renderers share process-wide caches (CSSFont's, litehtml's string table, the image and raster stores), all
    /// lock-guarded: each widget must still draw only its own colour.
    func testTwoWidgetsRunAtOnceOnTwoThreads() {
        func page(_ color: String) -> String {
            let rows = String(repeating: "<div style='height:4px;background:\(color)'></div>", count: 200)
            return "<!doctype html><body style='margin:0;padding:0'>\(rows)<script>for (var i = 0; i < 50; i++) { var d = document.createElement('div'); d.setAttribute('style', 'height:2px;background:\(color)'); document.body.appendChild(d); }</script></body>"
        }
        let noWait = MessageWidgetWaitPolicy(cap: 0.0)
        let red = self.make(page("rgb(255,0,0)"), policy: noWait)
        let blue = self.make(page("rgb(0,0,255)"), policy: noWait)
        let redGate = red.gateNextTaskForTesting()
        let blueGate = blue.gateNextTaskForTesting()
        _ = red.layout(width: 200.0)
        _ = blue.layout(width: 200.0)
        XCTAssertEqual(redGate.started.wait(timeout: .now() + 5.0), .success)
        XCTAssertEqual(blueGate.started.wait(timeout: .now() + 5.0), .success, "both boots are running at once, one per thread")
        // Released together: the two parse, run their scripts and render side by side.
        redGate.release.signal()
        blueGate.release.signal()
        XCTAssertTrue(self.pump(until: { red.appliedForTesting[.boot] == 1 && blue.appliedForTesting[.boot] == 1 }))
        for (instance, expected) in [(red, (r: 255, g: 0, b: 0)), (blue, (r: 0, g: 0, b: 255))] {
            let size = instance.layout(width: 200.0)
            XCTAssertEqual(size, CGSize(width: 200.0, height: 600.0))
            let view = instance.view
            view.frame = CGRect(origin: .zero, size: size)
            view.update()
            let image = self.render(view)
            // The column is ~900 px tall and the widget is clipped at 600.
            for y in stride(from: 1, to: Int(size.height), by: 97) {
                let p = self.pixel(image, 100, y)
                XCTAssertTrue(abs(p.r - expected.r) <= 3 && abs(p.g - expected.g) <= 3 && abs(p.b - expected.b) <= 3, "\(expected) at y \(y): \(p)")
            }
            instance.destroy()
        }
    }
}
