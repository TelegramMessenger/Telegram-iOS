import UIKit
import XCTest
@testable import MessageWidget

/// Text selection (sdk-v1 §5.10): while its bubble is lifted into the context menu, a widget exports what it lets the
/// reader select after every publish, keeps running, takes no input and is waited for by nobody.
final class SelectionExportTests: MessageWidgetTestCase {
    private static let sentence = "You can select this sentence, this bold word too, and copy it."
    private static let selection = "<!doctype html><html><head><style>body{margin:0} .sel{user-select:text}</style></head><body>"
        + "<div class=sel>You can select this sentence, <b>this bold word</b> too, and copy it.</div>"
        + "<div>This sentence cannot be selected.</div>"
        + "<button id=b style=\"display:block;width:200px;height:60px\">b</button>"
        + "<script>window.clicks = 0; document.getElementById('b').addEventListener('click', () => { window.clicks++; });</script>"
        + "</body></html>"

    private func applied(_ instance: MessageWidgetInstance, _ kind: WidgetSnapshot.Kind) -> Int {
        return instance.appliedForTesting[kind] ?? 0
    }

    func testExtractingExportsTheSelectableText() {
        let (instance, view) = self.booted(SelectionExportTests.selection)
        withExtendedLifetime(instance) {
            var changes = 0
            view.onSelectableTextChange = {
                changes += 1
            }
            view.setExtracted(true)
            XCTAssertTrue(self.pump(until: { view.selectableText != nil }))
            XCTAssertEqual(view.selectableText?.text as String?, SelectionExportTests.sentence)
            XCTAssertTrue(self.pump(until: { changes > 0 }))
        }
    }

    func testAWidgetWithNothingSelectableExportsNone() {
        let (instance, view) = self.booted("<!doctype html><p>x</p>")
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            XCTAssertTrue(self.pump(until: { self.applied(instance, .selection) > 0 }))
            XCTAssertNil(view.selectableText)
        }
    }

    func testEveryPublishReExportsWhileExtracted() {
        let (instance, view) = self.booted("<!doctype html><p style=\"user-select:text\">n <span id=c>0</span></p><script>"
            + "let n = 0; setInterval(() => { document.getElementById('c').textContent = String(++n); }, 50);</script>")
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            XCTAssertTrue(self.pump(until: { view.selectableText != nil }))
            let first = view.selectableText?.text as String?
            XCTAssertTrue(self.pump(until: { (view.selectableText?.text as String?).map { $0 != first } ?? false }))
            view.setExtracted(false)
            XCTAssertNil(view.selectableText)
            let queued = instance.queuedForTesting[.selection]?.unwaited ?? 0
            self.pump(0.3)
            XCTAssertEqual(instance.queuedForTesting[.selection]?.unwaited ?? 0, queued)
            XCTAssertNil(view.selectableText)
        }
    }

    func testLongExtractionDoesNotDemote() {
        let (instance, view) = self.booted("<!doctype html><p style=\"user-select:text\" id=p>moving</p><script>"
            + "let x = 0; const step = () => { document.getElementById('p').style.marginLeft = (x++ % 40) + 'px'; "
            + "requestAnimationFrame(step); }; requestAnimationFrame(step);</script>")
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            let framesWaited = instance.queuedForTesting[.frame]?.waited ?? 0
            let deadline = Date(timeIntervalSinceNow: 2.0)
            while Date() < deadline {
                instance.deliverFrameForTesting()
                self.pump(0.016)
            }
            XCTAssertGreaterThan(self.applied(instance, .selection), 5)
            XCTAssertEqual(instance.queuedForTesting[.frame]?.waited ?? 0, framesWaited)
            XCTAssertGreaterThan(instance.queuedForTesting[.frame]?.unwaited ?? 0, 0)
            XCTAssertFalse(instance.demoted)
            XCTAssertNil(instance.deadReason)
        }
    }

    /// The widget's timers fire through main as its wake (no frames run them inside a frame task).
    func testAnExtractedWidgetWaitsForNothing() {
        let (instance, view) = self.booted("<!doctype html><p style=\"user-select:text\" id=p>0</p><script>let n = 0; "
            + "setInterval(() => { document.getElementById('p').textContent = String(++n); }, 30);</script>")
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            let waited = instance.queuedForTesting[.wake]?.waited ?? 0
            let unwaited = instance.queuedForTesting[.wake]?.unwaited ?? 0
            self.pump(0.6)
            XCTAssertEqual(instance.queuedForTesting[.wake]?.waited ?? 0, waited)
            XCTAssertGreaterThan(instance.queuedForTesting[.wake]?.unwaited ?? 0, unwaited)
            view.setExtracted(false)
            self.pump(0.3)
            XCTAssertGreaterThan(instance.queuedForTesting[.wake]?.waited ?? 0, waited)
        }
    }

    func testAnExtractedWidgetTakesNoTouches() {
        let (instance, view) = self.booted(SelectionExportTests.selection)
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            XCTAssertFalse(view.isUserInteractionEnabled)
            view.handleTouch(phase: .began, at: CGPoint(x: 100.0, y: 70.0))
            view.handleTouch(phase: .ended, at: CGPoint(x: 100.0, y: 70.0))
            self.pump(0.05)
            XCTAssertEqual(instance.evaluateForTesting("String(window.clicks)"), "0")
            view.setExtracted(false)
            XCTAssertTrue(view.isUserInteractionEnabled)
            view.handleTouch(phase: .began, at: CGPoint(x: 100.0, y: 70.0))
            view.handleTouch(phase: .ended, at: CGPoint(x: 100.0, y: 70.0))
            self.pump(0.05)
            XCTAssertEqual(instance.evaluateForTesting("String(window.clicks)"), "1")
        }
    }

    func testAStopClearsTheSelectableText() {
        let (instance, view) = self.booted("<!doctype html><p style=\"user-select:text\">kept</p><script>"
            + "setTimeout(() => { for (;;) {} }, 300);</script>")
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            XCTAssertTrue(self.pump(until: { view.selectableText != nil }))
            XCTAssertTrue(self.pump(until: { instance.deadReason != nil }))
            XCTAssertTrue(self.pump(until: { view.selectableText == nil }))
        }
    }

    /// Review Focus 4 (the data half): a boundary named by its Text node is gone once script replaces that node.
    func testASelectionWhoseNodeIsReplacedIsDropped() {
        let (instance, view) = self.booted("<!doctype html><p id=p style=\"user-select:text\">ab</p><script>"
            + "setTimeout(() => { document.getElementById('p').textContent = 'ab'; }, 300);</script>")
        withExtendedLifetime(instance) {
            view.setExtracted(true)
            XCTAssertTrue(self.pump(until: { view.selectableText != nil }))
            guard let first = view.selectableText, let position = first.position(at: 1) else {
                return XCTFail("no selectable text")
            }
            XCTAssertEqual(first.index(of: position), 1)
            XCTAssertTrue(self.pump(until: { view.selectableText.map { $0 != first } ?? false }))
            XCTAssertEqual(view.selectableText?.text as String?, "ab")
            XCTAssertNil(view.selectableText?.index(of: position))
        }
    }
}
