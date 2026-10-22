import UIKit
import XCTest
@testable import MessageWidget

/// The core on WidgetRuntime (M1d plan, Task 8): what a widget's snapshots carry, the tap's bridge permission, the
/// frozen widget, the theme and the hidden widget's wakes.
final class NativeCoreTests: MessageWidgetTestCase {
    private static let page = "<!doctype html><html><head><style>body{margin:0}</style></head><body>"

    private func number(_ instance: MessageWidgetInstance, _ code: String) -> Int {
        return Int(instance.evaluateForTesting(code) ?? "") ?? -1
    }

    func testBootSnapshotHasSizeAndTiles() {
        let (instance, view) = self.booted(NativeCoreTests.page + "<div style=\"width:200px;height:80px;background:#ff0000\"></div></body></html>", width: 300.0)
        // The width laid out at, and the box's height: the page's `body{margin:0}` wins over the host's 8 px margin.
        XCTAssertEqual(instance.layout(width: 300.0), CGSize(width: 300.0, height: 80.0))
        XCTAssertEqual(Set(instance.currentFrame.tiles.keys), Set(WidgetFrame.grid(for: CGSize(width: 300.0, height: 80.0))))
        let pixel = self.pixel(self.render(view), 100, 40)
        XCTAssertEqual(pixel.r, 255)
        XCTAssertEqual(pixel.g, 0)
        XCTAssertEqual(pixel.b, 0)
    }

    func testTapRunsAClickAndPermitsOpenLink() {
        let (instance, _) = self.booted(NativeCoreTests.page + "<button id=\"b\" style=\"display:block;width:200px;height:100px\">Open</button><script>"
            + "document.getElementById('b').addEventListener('click', () => { document.getElementById('b').textContent = 'clicked';"
            + " TelegramWidget.openLink('https://telegram.org/'); TelegramWidget.openLink('https://telegram.org/again'); });"
            + "</script></body></html>")
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { call in
            calls.append(call)
        }
        instance.touch(action: 0, at: CGPoint(x: 100.0, y: 50.0), pointer: 0, primary: true)
        instance.touch(action: 2, at: CGPoint(x: 100.0, y: 50.0), pointer: 0, primary: true)
        self.pump(0.05)
        XCTAssertEqual(instance.evaluateForTesting("document.getElementById('b').textContent"), "clicked")
        // One openLink per tap: the second is refused.
        XCTAssertEqual(calls, [.openLink("https://telegram.org/")])
        XCTAssertTrue(instance.diagnostics.contains { $0.kind == "activation-blocked" })
    }

    /// Review Focus 5: a timer's openLink is refused, a timer that is due while a tap is handled included.
    func testBridgeCallsOutsideATapAreRefused() {
        let (instance, _) = self.booted(NativeCoreTests.page + "<div style=\"height:100px\"></div><script>"
            + "setTimeout(() => TelegramWidget.openLink('https://telegram.org/timeout'), 20);"
            + "setInterval(() => TelegramWidget.openLink('https://telegram.org/interval'), 1);"
            + "</script></body></html>")
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { call in
            calls.append(call)
        }
        for _ in 0 ..< 5 {
            self.pump(0.01)
            instance.touch(action: 0, at: CGPoint(x: 50.0, y: 50.0), pointer: 0, primary: true)
            instance.touch(action: 2, at: CGPoint(x: 50.0, y: 50.0), pointer: 0, primary: true)
        }
        self.pump(0.1)
        XCTAssertEqual(calls, [])
        XCTAssertTrue(instance.diagnostics.contains { $0.kind == "activation-blocked" && $0.detail.contains("openLink") })
    }

    func testFrozenWidgetKeepsHeightAndShowsTheBadge() {
        let (instance, view) = self.booted(NativeCoreTests.page + "<div style=\"height:100px;background:#ff0000\"></div>"
            + "<script>setTimeout(() => { for (;;) {} }, 20);</script></body></html>", width: 300.0)
        let before = instance.layout(width: 300.0)
        XCTAssertEqual(before.height, 100.0)
        XCTAssertTrue(self.pump(until: { instance.deadReason != nil }))
        XCTAssertTrue(instance.deadReason?.contains("Work limit exceeded") ?? false, instance.deadReason ?? "nil")
        XCTAssertEqual(instance.layout(width: 300.0), before)
        let image = self.render(view)
        // The badge's left padding, inside its rounded end, over the red box (the page has no margin):
        // rgba(60,60,60,.75) over rgb(255,0,0). Bottom LEFT, because a captionless widget's bubble draws its date pill
        // at the bottom right, over the widget (the V1 final review's I2).
        let badge = self.pixel(image, 8, Int(before.height) - 15)
        XCTAssertEqual(Double(badge.r), 109.0, accuracy: 4.0)
        XCTAssertEqual(Double(badge.g), 45.0, accuracy: 4.0)
        XCTAssertEqual(Double(badge.b), 45.0, accuracy: 4.0)
        // Where the date pill goes, the last frame shows.
        XCTAssertEqual(self.pixel(image, Int(before.width) - 8, Int(before.height) - 15).r, 255)
        // The content keeps its last frame.
        XCTAssertEqual(self.pixel(image, 20, 20).r, 255)
        // Touches are ignored.
        let touches = instance.queuedForTesting[.touch]?.waited ?? 0
        instance.touch(action: 0, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        XCTAssertEqual(instance.queuedForTesting[.touch]?.waited ?? 0, touches)
        // A new width keeps the frozen tree, clipped to it, at the latched height.
        XCTAssertEqual(instance.layout(width: 150.0), CGSize(width: 150.0, height: before.height))
    }

    /// A bubble with a fixed height shorter than its widget's content clips the widget there, and a stopped widget's
    /// badge must stay inside the clip (the V1 final review's I2: it was drawn at the bottom of the up-to-600 pt
    /// document, below the clip). The bubble's height is the document's maximum, so the document ends at the clip.
    func testAFixedHeightCapsTheDocumentAndKeepsTheBadgeInside() {
        let instance = self.make(NativeCoreTests.page + "<div style=\"height:400px;background:#ff0000\"></div>"
            + "<script>setTimeout(() => { for (;;) {} }, 20);</script></body></html>", scale: 1.0)
        instance.maximumHeight = 120.0
        let size = instance.layout(width: 300.0)
        XCTAssertEqual(size, CGSize(width: 300.0, height: 120.0))
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        self.settle(instance)
        XCTAssertTrue(self.pump(until: { instance.deadReason != nil }))
        let image = self.render(view)
        let badge = self.pixel(image, 8, 120 - 15)
        XCTAssertEqual(Double(badge.r), 109.0, accuracy: 4.0)
        XCTAssertEqual(Double(badge.g), 45.0, accuracy: 4.0)
    }

    func testThemeFlipRebuilds() {
        let (instance, view) = self.booted(NativeCoreTests.page.replacingOccurrences(of: "body{margin:0}", with: "body{margin:0;background:#ffffff} @media (prefers-color-scheme: dark) { body { background: #000000 } }")
            + "<div id=\"t\" style=\"height:60px\">light</div><script>"
            + "TelegramWidget.onTheme(theme => { document.getElementById('t').textContent = theme; });"
            + "</script></body></html>")
        // Right of the text (the UA layer's font draws "light" over the top-left corner).
        XCTAssertEqual(self.pixel(self.render(view), 150, 40).r, 255)
        instance.setTheme(.dark)
        XCTAssertEqual(self.pixel(self.render(view), 150, 40).r, 0)
        // The onTheme callbacks are a task of their own: it runs without anything else waking the widget.
        XCTAssertTrue(self.pump(until: { instance.evaluateForTesting("document.getElementById('t').textContent") == "dark" }, timeout: 2.0))
    }

    /// SDK v1 §2.4 (v0.1.1): a text-token change alone is a theme change, and the widget's layout follows it: a widget
    /// with no CSS of its own is the padding token above and below its lines, each the font size times the line height
    /// (rounded up to a point; the reference set is 8 + 3 × 20.25 + 8).
    func testATextTokenChangeRelaysOut() {
        let (instance, _) = self.booted("<!doctype html><p>x<br>x<br>x</p>", width: 300.0)
        XCTAssertEqual(instance.layout(width: 300.0).height, 77.0)
        instance.setTheme(MessageWidgetInstance.Theme(colorScheme: .light, text: MessageWidgetInstance.Theme.TextTokens(fontSize: 30.0, lineHeight: 1.3, padding: "6px 11px")))
        XCTAssertEqual(instance.evaluateForTesting("getComputedStyle(document.documentElement).fontSize"), "30px")
        XCTAssertEqual(instance.layout(width: 300.0).height, 129.0)
    }

    /// v0.1.1 plan, Task 6 (R4; sdk-v1 §2.4: a background set on the root or the body paints the whole bubble): below a
    /// document shorter than its view (the 50 pt minimum, a fixed height) the view paints the canvas colour, the body's
    /// here; a widget with no background leaves it transparent, so the bubble shows.
    func testTheCanvasColourFillsTheViewBelowTheDocument() {
        let (instance, view) = self.booted(NativeCoreTests.page.replacingOccurrences(of: "body{margin:0}", with: "body{margin:0;background:#00ff00}") + "<div style=\"height:30px\"></div></body></html>", width: 300.0)
        XCTAssertEqual(instance.layout(width: 300.0).height, 50.0)
        view.frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 120.0)
        view.layoutIfNeeded()
        let image = self.render(view)
        for y in [10, 40, 100] {
            let pixel = self.pixel(image, 150, y)
            XCTAssertEqual([pixel.r, pixel.g, pixel.b], [0, 255, 0], "y \(y)")
        }
        let (plain, plainView) = self.booted(NativeCoreTests.page + "<div style=\"height:30px\"></div></body></html>", width: 300.0)
        XCTAssertEqual(plain.layout(width: 300.0).height, 50.0)
        plainView.frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 120.0)
        plainView.layoutIfNeeded()
        let pixel = self.pixel(self.render(plainView), 150, 100)
        XCTAssertEqual([pixel.r, pixel.g, pixel.b], [255, 255, 255])
    }

    /// No seam where the tree's painting ends and the canvas layer begins: the painter rounds boxes to whole CSS px, so
    /// below a fractional document height every device pixel row is the canvas colour (a band of the bubble's showed).
    func testTheCanvasHasNoSeamUnderAFractionalDocument() {
        let (instance, view) = self.booted(NativeCoreTests.page.replacingOccurrences(of: "body{margin:0}", with: "body{margin:0;background:#00ff00}") + "<div style=\"height:70.6px\"></div></body></html>", scale: 3.0, width: 300.0)
        let height = instance.layout(width: 300.0).height
        view.frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: height + 40.0)
        view.layoutIfNeeded()
        let image = self.render(view, scale: 3.0)
        var seam: [Int] = []
        for y in 0 ..< Int((height + 40.0) * 3.0) {
            let pixel = self.devicePixel(image, 450, y)
            if [pixel.r, pixel.g, pixel.b] != [0, 255, 0] {
                seam.append(y)
            }
        }
        XCTAssertEqual(seam, [])
    }

    func testHiddenWidgetWakesAtMostOncePerSecond() {
        let (instance, _) = self.booted(NativeCoreTests.page + "<div>n</div><script>window.n = 0; setInterval(() => { window.n++; }, 10);</script></body></html>")
        self.pump(0.2)
        XCTAssertGreaterThan(self.number(instance, "String(window.n)"), 3)
        instance.setVisible(false)
        self.pump(0.05)
        let count = self.number(instance, "String(window.n)")
        let wakes = instance.appliedForTesting[.wake] ?? 0
        self.pump(2.5)
        let hidden = self.number(instance, "String(window.n)") - count
        XCTAssertGreaterThanOrEqual(hidden, 1)
        XCTAssertLessThanOrEqual(hidden, 3)
        XCTAssertLessThanOrEqual((instance.appliedForTesting[.wake] ?? 0) - wakes, 3)
        // Visible again, the interval runs at its own pace.
        instance.setVisible(true)
        let shown = self.number(instance, "String(window.n)")
        self.pump(0.3)
        XCTAssertGreaterThan(self.number(instance, "String(window.n)") - shown, 5)
    }

    /// Task 8 review I1: a widget that keeps a task runnable (an unhandledrejection handler that rejects again, each
    /// pass ~4M units) is not run 256 times in one core task: a drain stops once it has spent a task's budget, and the
    /// rest runs on later wakes, so the widget's queue never holds a pool thread for long.
    func testADrainStopsAtOneTaskBudget() {
        let (instance, _) = self.booted(NativeCoreTests.page + "<p id=n>0</p><script>window.n = 0;"
            + "window.addEventListener('unhandledrejection', e => { e.preventDefault(); var s = 0;"
            + " for (var i = 0; i < 2000000; i++) s = (s + i) | 0; window.n++; Promise.reject(1); });"
            + "setTimeout(() => Promise.reject(1), 10);</script></body></html>")
        XCTAssertTrue(self.pump(until: { instance.largestTaskWorkForTesting > 0 }, timeout: 20.0))
        self.pump(0.3)
        XCTAssertNil(instance.deadReason)
        XCTAssertLessThan(instance.largestTaskWorkForTesting, 2 * MessageWidgetCore.taskWorkUnits)
        XCTAssertGreaterThan(self.number(instance, "String(window.n)"), 7)
        instance.destroy()
    }

    /// Task 8 review I2: a width or theme change rebuilds on a budget of its own, not on what the previous step left.
    func testAWidthChangeAfterAHeavyStepHasItsOwnBudget() {
        MessageWidgetCore.budgetsForTesting = (parse: MessageWidgetCore.parseWorkUnits, boot: MessageWidgetCore.bootWorkUnits, task: 2_000_000)
        defer {
            MessageWidgetCore.budgetsForTesting = nil
        }
        // The timer leaves ~60,000 of its 2,000,000 units; rebuilding the heavy markup takes ~700,000.
        let source = LimitsTests.heavyMarkup.replacingOccurrences(of: "</body>", with: "<script>setTimeout(() => { var s = 0;"
            + " for (var i = 0; i < 970000; i++) s = (s + i) | 0; TelegramWidget.ready(); }, 10);</script></body>")
        let instance = self.make(source)
        _ = instance.layout(width: 360.0)
        // Observed without running anything in the widget (an evaluation would be a step with a budget of its own).
        XCTAssertTrue(self.pump(until: { instance.diagnostics.contains { $0.kind == "bridge-ignored" && $0.detail == "ready" } }, timeout: 10.0))
        XCTAssertNil(instance.deadReason)
        _ = instance.layout(width: 300.0)
        XCTAssertNil(instance.deadReason, instance.deadReason ?? "")
        instance.setTheme(.dark)
        XCTAssertNil(instance.deadReason, instance.deadReason ?? "")
        instance.destroy()
    }

    /// The user, 2026-10-19: drawing may be async; only the widget's size is critical. The waited boot reports the size
    /// and draws nothing; one `.draw` task, never waited for, lands the tiles after it.
    func testTheSizeIsCriticalAndTheTilesAreDrawnAfterIt() {
        let instance = self.make(NativeCoreTests.page + "<div style=\"width:200px;height:80px;background:#ff0000\"></div></body></html>")
        XCTAssertEqual(instance.layout(width: 300.0), CGSize(width: 300.0, height: 80.0))
        XCTAssertTrue(instance.currentFrame.tiles.isEmpty)
        XCTAssertTrue(instance.isDrawPendingForTesting)
        XCTAssertEqual(instance.queuedForTesting[.draw]?.waited ?? 0, 0)
        XCTAssertEqual(instance.queuedForTesting[.draw]?.unwaited, 1)
        self.settle(instance)
        XCTAssertEqual(Set(instance.currentFrame.tiles.keys), Set(WidgetFrame.grid(for: CGSize(width: 300.0, height: 80.0))))
        // A task that changes nothing visible queues no draw.
        _ = instance.evaluateForTesting("1")
        XCTAssertFalse(instance.isDrawPendingForTesting)
        XCTAssertEqual(instance.queuedForTesting[.draw]?.unwaited, 1)
        instance.destroy()
    }
}
