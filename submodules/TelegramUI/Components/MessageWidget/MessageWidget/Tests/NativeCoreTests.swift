import UIKit
import XCTest
@testable import MessageWidget

/// The core on WidgetRuntime (M1d plan, Task 8): what a widget's snapshots carry, the tap's bridge permission, the
/// frozen widget, the theme and the hidden widget's wakes.
final class NativeCoreTests: MessageWidgetTestCase {
    private static let page = "<!doctype html><html><head><style>body{margin:0}</style></head><body>"
    /// The product's slice with both windows lifted, so a boot's slice of JS defers nothing after it.
    private static let lifted = MessageWidgetCpuLimits(cpuLimitMs: 500.0, cpuQuotaMs: 1_000_000.0, cpuQuotaWindowMs: 1000.0, cpuKillAfterMs: 0.0, mainThreadQuotaMs: 1_000_000.0)

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
        // widget-sandbox's words: the timer's slice is what the JS quota left it (the boot spent a little).
        XCTAssertTrue(instance.deadReason?.hasPrefix("CPU limit exceeded: more than ") ?? false, instance.deadReason ?? "nil")
        XCTAssertTrue(instance.deadReason?.contains("of continuous execution (timer") ?? false, instance.deadReason ?? "nil")
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

    /// widget-sandbox v0.1.2: timers a hidden widget sets run in the order of their delays, as a browser's throttled
    /// background tab runs them, though the hidden widget fires its due timers only at its 1 Hz wake.
    func testAHiddenWidgetsTimersRunInTheOrderOfTheirDelays() {
        let (instance, _) = self.booted(NativeCoreTests.page + "<div>t</div><script>window.order = [];"
            + " window.schedule = () => { for (const ms of [20, 10, 0]) setTimeout(() => window.order.push(ms), ms); return 'ok'; };"
            + "</script></body></html>")
        instance.setVisible(false)
        self.pump(0.05)
        XCTAssertEqual(instance.evaluateForTesting("window.schedule()"), "ok")
        self.pump(2.5)
        XCTAssertEqual(instance.evaluateForTesting("window.order.join(',')"), "0,10,20")
    }

    /// Task 8 review I1, on the CPU limits: a widget that keeps a task runnable (an unhandledrejection handler that
    /// rejects again, each pass spinning 40 ms of a timer's kind) holds no pool thread for long: past the JS quota
    /// (300 ms a second) its passes are deferred, each drain ends there, and the rest runs on later wakes.
    func testAWidgetThatKeepsATaskRunnableIsThrottled() {
        self.useWallTimeAsCpu()
        let (instance, _) = self.booted(NativeCoreTests.page + "<p id=n>0</p><script>window.n = 0;"
            + "window.addEventListener('unhandledrejection', e => { e.preventDefault(); \(MessageWidgetTestCase.spin(40))"
            + " window.n++; Promise.reject(1); });"
            + "setTimeout(() => Promise.reject(1), 10);</script></body></html>")
        XCTAssertTrue(self.pump(until: { instance.throttledStepsForTesting > 0 }, timeout: 10.0), "never throttled")
        let first = self.number(instance, "String(window.n)")
        XCTAssertLessThanOrEqual(first, 16, "at most two windows' worth of the quota before the first deferral was seen")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") > first }, timeout: 5.0), "the deferred passes never ran")
        XCTAssertNil(instance.deadReason)
        instance.destroy()
    }

    /// The final review's I1: the same chain rooted in a boot script, so every pass is a boot follow-up, a kind the JS
    /// quota never defers, holds no pool thread for long either: a core task's drain ends once its steps have spent one
    /// slice of CPU (500 ms), and the rest runs on later wakes. Without that, one drain ran 256 passes (10 s here).
    func testABootRootedChainHoldsNoThreadForLong() {
        self.useWallTimeAsCpu()
        let (instance, _) = self.booted(NativeCoreTests.page + "<p id=n>0</p><script>window.n = 0;"
            + "window.addEventListener('unhandledrejection', e => { e.preventDefault(); \(MessageWidgetTestCase.spin(40))"
            + " window.n++; Promise.reject(1); });"
            + "Promise.reject(1);</script></body></html>")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") > 40 }, timeout: 30.0), "the chain stalled")
        for kind: WidgetSnapshot.Kind in [.boot, .wake, .timer, .event] {
            let cpu = instance.largestTaskCpuMillisecondsForTesting(kind)
            XCTAssertLessThan(cpu, 1500.0, "a \(kind) task held its thread for \(cpu) ms")
        }
        XCTAssertNil(instance.deadReason)
        instance.destroy()
    }

    /// The task that stops a widget after its first publish is measured too: the stop drops the session, so its CPU is read
    /// before that (the attack scan's largest tasks, the snapshot's demotion input).
    func testTheTaskThatStopsAWidgetRecordsItsCpu() {
        self.useWallTimeAsCpu()
        let instance = self.make(NativeCoreTests.page + "<script>for (;;) {}</script></body></html>")
        _ = instance.layout(width: 360.0)
        XCTAssertTrue(self.pump(until: { instance.deadReason != nil }, timeout: 10.0), "the spin was never stopped")
        let cpu = instance.largestTaskCpuMillisecondsForTesting(.boot)
        XCTAssertGreaterThanOrEqual(cpu, 450.0, "the stopping boot task recorded \(cpu) ms")
        instance.destroy()
    }

    /// The fix wave's review I-A: the boot's own loop is bounded the same way. A chain that doubles at every boot script
    /// (each toBlob callback asks for two more, and a boot link runs only after what the one before it queued) ran 2^10
    /// passes inside the boot task before its load.
    func testABootChainThatDoublesHoldsNoThreadForLong() {
        self.useWallTimeAsCpu()
        let empties = String(repeating: "<script></script>", count: 10)
        let (instance, _) = self.booted(NativeCoreTests.page + "<script>window.n = 0; const c = document.createElement('canvas');"
            + "function f() { \(MessageWidgetTestCase.spin(5)) window.n++; c.toBlob(f); c.toBlob(f); } f();</script>" + empties
            + "</body></html>")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") > 300 }, timeout: 30.0), "the chain stalled")
        for kind: WidgetSnapshot.Kind in [.boot, .wake] {
            let cpu = instance.largestTaskCpuMillisecondsForTesting(kind)
            XCTAssertLessThan(cpu, 1500.0, "a \(kind) task held its thread for \(cpu) ms")
        }
        instance.destroy()
    }

    /// The fix waves' review I-B: a press whose down task cannot run within the touch's bounded drains (more than a
    /// slice of runnable steps before it, about 2.5 s here) is unanswered, as when main's wait ends first: never the
    /// claim of the press before it, and the touch holds its thread no longer than its drains' slices. The down is the
    /// widget's later, in its turn.
    func testAPressBehindABacklogIsUnanswered() {
        self.useWallTimeAsCpu()
        let instance = self.make(NativeCoreTests.page + "<div style=\"width:300px;height:100px;touch-action:none\"></div>"
            + "<script>window.downs = 0; addEventListener('pointerdown', () => window.downs++); const c = document.createElement('canvas');"
            + "for (let i = 0; i < 20; i++) c.toBlob(() => { \(MessageWidgetTestCase.spin(150)) });</script></body></html>")
        let size = instance.layout(width: 360.0)
        instance.view.frame = CGRect(origin: .zero, size: size)
        // Main's run loop has not run since the boot, so no wake has: the boot task's slice ran 3 or 4 of the callbacks,
        // and the rest (2.5 s) are ahead of the down, past the touch's two drains (a slice each).
        let press = instance.touch(action: 0, at: CGPoint(x: 150.0, y: 50.0), pointer: 0, primary: true)
        XCTAssertEqual(press, .unanswered)
        let cpu = instance.largestTaskCpuMillisecondsForTesting(.touch)
        XCTAssertLessThan(cpu, 1500.0, "a touch task held its thread for \(cpu) ms")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.downs)") == 1 }, timeout: 10.0), "the down never ran")
        instance.touch(action: 3, at: CGPoint(x: 150.0, y: 50.0), pointer: 0, primary: true)
        instance.destroy()
    }

    /// The fix waves' review: a boot past one slice of CPU finishes on wakes, which are the boot's work, not the widget's
    /// timers: they never demote it (three scripts spinning 250 ms each, 250 ms inside the two slices' exemption).
    func testABootThatFinishesOnWakesIsNotDemoted() {
        self.useWallTimeAsCpu()
        let script = "<script>\(MessageWidgetTestCase.spin(250)) window.n = (window.n || 0) + 1;</script>"
        let instance = self.make(NativeCoreTests.page + String(repeating: script, count: 3) + "</body></html>")
        _ = instance.layout(width: 360.0)
        XCTAssertEqual(self.number(instance, "String(window.n)"), 2, "the boot task did not stop at its slice")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") == 3 }, timeout: 5.0))
        XCTAssertFalse(instance.demoted)
        instance.destroy()
    }

    /// The parse's async scripts are the boot's too (a link each, as its other scripts): one that runs on a wake past
    /// the boot task's slice does not demote the widget.
    func testABootsAsyncScriptsOnWakesAreNotDemoted() {
        self.useWallTimeAsCpu()
        let classic = "<script>\(MessageWidgetTestCase.spin(250)) window.n = (window.n || 0) + 1;</script>"
        let module = "<script type=module async>\(MessageWidgetTestCase.spin(250)) window.n = (window.n || 0) + 1;</script>"
        let instance = self.make(NativeCoreTests.page + classic + module + module + "</body></html>")
        _ = instance.layout(width: 360.0)
        XCTAssertEqual(self.number(instance, "String(window.n)"), 2, "the boot task did not stop at its slice")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") == 3 }, timeout: 5.0))
        XCTAssertFalse(instance.demoted)
        instance.destroy()
    }

    /// Demotion exempts a wake's boot links by their CPU, not the wake: a wake that runs the boot's last script and 30 ms
    /// of a timer beside it is demoted. The windows are lifted, or the boot's slice of JS would defer the timer to a wake
    /// of its own.
    func testAWakesWorkBesideTheBootsLinksDemotes() {
        self.useWallTimeAsCpu()
        let instance = self.make(NativeCoreTests.page + "<script>\(MessageWidgetTestCase.spin(300))</script>"
            + "<script>\(MessageWidgetTestCase.spin(300)) setTimeout(() => { \(MessageWidgetTestCase.spin(30)) window.timer = 1; }, 0);</script>"
            + "<script>\(MessageWidgetTestCase.spin(50)) window.last = 1;</script></body></html>", cpuLimits: NativeCoreTests.lifted)
        _ = instance.layout(width: 360.0)
        XCTAssertEqual(instance.evaluateForTesting("String(window.last)"), "undefined", "the boot task did not stop at its slice")
        XCTAssertTrue(self.pump(until: { instance.evaluateForTesting("String(window.last + window.timer)") == "2" }, timeout: 5.0))
        XCTAssertTrue(instance.demoted)
        instance.destroy()
    }

    /// Only the boot's links are exempt, never a frame while the boot is incomplete: a 30 ms frame between its links
    /// demotes. The windows are lifted, or the boot's slice of JS would defer the frame past the load.
    func testAHeavyFrameDuringTheBootDemotes() {
        self.useWallTimeAsCpu()
        let script = "<script>\(MessageWidgetTestCase.spin(250)) window.n = (window.n || 0) + 1;</script>"
        let instance = self.make(NativeCoreTests.page + "<script>requestAnimationFrame(() => { \(MessageWidgetTestCase.spin(30))"
            + " window.frameState = document.readyState; });</script>" + String(repeating: script, count: 3) + "</body></html>", cpuLimits: NativeCoreTests.lifted)
        let size = instance.layout(width: 360.0)
        instance.view.frame = CGRect(origin: .zero, size: size)
        XCTAssertEqual(self.number(instance, "String(window.n)"), 2, "the boot task did not stop at its slice")
        // Queued before main's run loop runs the wake that finishes the boot.
        self.deliverFrame(instance)
        XCTAssertEqual(instance.evaluateForTesting("window.frameState"), "loading")
        XCTAssertTrue(instance.demoted)
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") == 3 }, timeout: 5.0))
        instance.destroy()
    }

    /// The plan's Review Focus 2, through the core: frames that spend the JS quota are deferred (main is asked for no
    /// frames meanwhile), and the core's wake at the retry releases them, so main's display-link frames resume.
    func testAThrottledAnimationResumesThroughTheCore() {
        self.useWallTimeAsCpu()
        let (instance, _) = self.booted(NativeCoreTests.page + "<div>t</div><script>window.n = 0;"
            + "function f() { \(MessageWidgetTestCase.spin(40)) window.n++; requestAnimationFrame(f); } requestAnimationFrame(f);"
            + "</script></body></html>")
        func tick(until condition: () -> Bool, timeout: TimeInterval) -> Bool {
            let deadline = Date(timeIntervalSinceNow: timeout)
            while !condition() {
                if Date() >= deadline {
                    return false
                }
                self.deliverFrame(instance)
                self.pump(0.016)
            }
            return true
        }
        XCTAssertTrue(tick(until: { instance.throttledStepsForTesting > 0 }, timeout: 5.0), "never throttled")
        let throttledAt = self.number(instance, "String(window.n)")
        XCTAssertLessThanOrEqual(throttledAt, 16)
        XCTAssertTrue(tick(until: { self.number(instance, "String(window.n)") >= throttledAt + 3 }, timeout: 5.0), "the frames never resumed")
        XCTAssertNil(instance.deadReason)
        instance.destroy()
    }

    /// The third fix-wave review: only the boot's own links (its scripts and its load) are exempt from demotion, never
    /// what else a task runs while the document is incomplete. A chain that keeps the load from ever running (it
    /// doubles at every boot script) is demoted, as are its frames, so main stops waiting for them.
    func testABootChainThatKeepsTheLoadAwayIsDemoted() {
        self.useWallTimeAsCpu()
        let empties = String(repeating: "<script></script>", count: 10)
        let (instance, _) = self.booted(NativeCoreTests.page + "<script>window.n = 0; const c = document.createElement('canvas');"
            + "function f() { \(MessageWidgetTestCase.spin(5)) window.n++; c.toBlob(f); c.toBlob(f); } f();</script>" + empties
            + "</body></html>")
        XCTAssertTrue(self.pump(until: { instance.demoted }, timeout: 10.0), "never demoted")
        instance.destroy()
    }

    /// The fourth fix-wave review: the boot's own steps are exempt for its first two slices of CPU only, so a run of
    /// heavy parser scripts (each a boot link, 2.4 s in all here) cannot keep main waiting for its wakes for as long as
    /// the scripts last: past the exemption the widget is demoted.
    func testARunOfHeavyBootScriptsIsDemotedPastTheExemption() {
        self.useWallTimeAsCpu()
        let script = "<script>\(MessageWidgetTestCase.spin(300)) window.n = (window.n || 0) + 1;</script>"
        let (instance, _) = self.booted(NativeCoreTests.page + String(repeating: script, count: 8) + "</body></html>")
        XCTAssertTrue(self.pump(until: { self.number(instance, "String(window.n)") == 8 }, timeout: 10.0))
        XCTAssertTrue(instance.demoted)
        instance.destroy()
    }

    /// The fix waves' review: a press whose own pointerdown handler stops the widget (past its slice) is the bubble's: no
    /// claim, no hold from a widget that is now a picture.
    func testAPressThatStopsTheWidgetIsTheBubbles() {
        self.useWallTimeAsCpu()
        let (instance, _) = self.booted(NativeCoreTests.page + "<div id=d style=\"width:300px;height:100px;touch-action:none\"></div>"
            + "<script>document.getElementById('d').addEventListener('pointerdown', () => { \(MessageWidgetTestCase.spin(700)) });</script>"
            + "</body></html>")
        let press = instance.touch(action: 0, at: CGPoint(x: 150.0, y: 50.0), pointer: 0, primary: true)
        XCTAssertNotNil(instance.deadReason)
        XCTAssertEqual(press, .none)
        instance.destroy()
    }

    /// Task 8 review I2: a width or theme change after a heavy step is a step of its own, on a slice of its own.
    func testAWidthChangeAfterAHeavyStepHasItsOwnSlice() {
        self.useWallTimeAsCpu()
        let source = LimitsTests.heavyMarkup.replacingOccurrences(of: "</body>", with: "<script>setTimeout(() => { \(MessageWidgetTestCase.spin(200))"
            + " TelegramWidget.ready(); }, 10);</script></body>")
        let instance = self.make(source)
        _ = instance.layout(width: 360.0)
        // Observed without running anything in the widget (an evaluation would be a step with a slice of its own).
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
