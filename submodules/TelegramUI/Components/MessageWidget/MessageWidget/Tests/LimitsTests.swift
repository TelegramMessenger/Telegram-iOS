import QuartzCore
import XCTest
@testable import MessageWidget

/// Hostile widgets through the whole pipeline (engine, validator, renderer): one message must not exhaust the
/// app's memory or hold the main thread past its wait.
class LimitsTests: MessageWidgetTestCase {
    private static var warmedUp = false

    /// The first widget a process boots pays one-time costs outside any task: in a test process launched standalone (as
    /// the Bazel runner launches it) its layout took 5.1 s against 0.04 s for the next one (measured). The limit cases
    /// time a boot, so one is booted first, whatever runs before this class.
    override func setUp() {
        super.setUp()
        if !LimitsTests.warmedUp {
            LimitsTests.warmedUp = true
            let instance = self.make("<!doctype html><p>warm</p>")
            _ = instance.layout(width: 360.0)
            instance.destroy()
        }
    }

    /// Boots `source` at 360 pt: the layout pass's wall time, and the memory the widget holds after it (live malloc
    /// bytes, both runtimes and the renderer included).
    private func measuredBoot(_ source: String) -> (instance: MessageWidgetInstance, seconds: Double, megabytes: Double) {
        let instance = self.make(source)
        let before = self.allocatedBytes()
        let start = CACurrentMediaTime()
        _ = instance.layout(width: 360.0)
        let seconds = CACurrentMediaTime() - start
        let megabytes = Double(self.allocatedBytes() - before) / 1048576.0
        return (instance, seconds, megabytes)
    }

    /// widget-sandbox's runtime limits on the widget thread's CPU clock: each boot script has a slice of its own (500 ms),
    /// and an event a slice of what the quota leaves it (at least 50 ms); a runaway is stopped past it, in upstream's words.
    func testTheBootAndOtherTasksHaveSlicesOfTheirOwn() throws {
        let boot = self.make("<!doctype html><p>x</p><script>for (;;) {}</script>")
        _ = boot.layout(width: 360.0)
        XCTAssertEqual(boot.deadReason, LimitsTests.scriptStop)
        boot.destroy()

        let event = self.make("<!doctype html><p>x</p>")
        _ = event.layout(width: 360.0)
        _ = event.evaluateForTesting("for (;;) {}")
        XCTAssertTrue(event.deadReason?.hasPrefix("CPU limit exceeded: more than ") ?? false, event.deadReason ?? "nil")
        XCTAssertTrue(event.deadReason?.contains("of continuous execution (event") ?? false, event.deadReason ?? "nil")
        event.destroy()
    }

    /// A boot script's runaway, in widget-sandbox's words.
    static let scriptStop = "CPU limit exceeded: more than 500 ms of continuous execution (script)"

    /// ~60 KB of static markup, the shape of widget-sandbox's ported chat messages (a stylesheet, rows of styled
    /// elements).
    static let heavyMarkup: String = {
        let rules = (0 ..< 200).map { ".c\($0) { color: #\(String(format: "%06x", $0 * 997)); padding: \($0 % 9)px; border-radius: 4px }" }.joined()
        let rows = (0 ..< 400).map { "<div class=\"c\($0 % 200)\" style=\"display:flex;gap:4px\"><span>row \($0)</span><b title=\"t\($0)\">bold</b><i>italic words here</i></div>" }.joined()
        return "<!doctype html><html><head><style>\(rules)</style></head><body>\(rows)</body></html>"
    }()

    /// The user, 2026-10-15, kept by the CPU limits: the parse of a widget's own markup is ours, outside every slice and
    /// window, and no widget code can run in it.
    func testTheMarkupParseIsNotTheWidgets() throws {
        let instance = self.make(LimitsTests.heavyMarkup)
        _ = instance.layout(width: 360.0)
        defer { instance.destroy() }
        XCTAssertNil(instance.deadReason)
    }

    /// The script after a heavy parse has its whole slice: one spinning 400 ms (on the wall clock as its CPU) finishes.
    func testTheScriptAfterAHeavyParseHasItsWholeSlice() throws {
        self.useWallTimeAsCpu()
        let script = "<script>\(MessageWidgetTestCase.spin(400)) window.done = true;</script>"
        let instance = self.make(LimitsTests.heavyMarkup.replacingOccurrences(of: "</body>", with: script + "</body>"))
        _ = instance.layout(width: 360.0)
        defer { instance.destroy() }
        XCTAssertNil(instance.deadReason)
        XCTAssertEqual(instance.evaluateForTesting("String(window.done)"), "true")
    }

    /// widget-sandbox v0.3.0: a counted cap passed stops the widget with upstream's reason (the conformance set's stop
    /// tests are judged by its start); markup already past one is a stop with the badge alone, never the pill, which
    /// asks the user to update the app.
    func testALimitStopIsTheWidgetsDeadReason() throws {
        let instance = self.make("<p id=p>x</p><script>setTimeout(() => document.getElementById('p').textContent = 'x'.repeat(40000), 0)</script>")
        _ = instance.layout(width: 360.0)
        defer { instance.destroy() }
        XCTAssertTrue(self.pump(until: { instance.deadReason != nil }, timeout: 10.0))
        XCTAssertEqual(instance.deadReason, "Text limit exceeded: a text value of 40000 characters (max 32768)")

        let markup = self.make("<p>" + String(repeating: "y", count: 40000) + "</p>")
        _ = markup.layout(width: 360.0)
        defer { markup.destroy() }
        XCTAssertFalse(markup.failedToStart)
        XCTAssertEqual(markup.deadReason, "Text limit exceeded: a text value of 40000 characters (max 32768)")
    }

    /// A guard on the parse's extent: the widget's scripts are outside it, so a runaway after a heavy parse is stopped at
    /// its own slice.
    func testARunawayAfterAHeavyParseIsStoppedAtItsSlice() throws {
        let instance = self.make(LimitsTests.heavyMarkup.replacingOccurrences(of: "</body>", with: "<script>for (;;) {}</script></body>"))
        _ = instance.layout(width: 360.0)
        defer { instance.destroy() }
        XCTAssertEqual(instance.deadReason, LimitsTests.scriptStop)
    }

    /// Words under the content cap are built, and the renderer's text cap (third-party/twidget VENDOR.md edit 10)
    /// bounds them: 120,000 pieces were ~330 MB.
    func testWordBombUnderTheContentCapIsBoundedByTheTextCap() throws {
        let (instance, seconds, megabytes) = self.measuredBoot("<p id=p>x</p><script>document.getElementById('p').textContent = 'a '.repeat(6e4)</script>")
        XCTAssertLessThan(megabytes, 100.0)
        XCTAssertLessThan(seconds, 2.0)
        instance.destroy()
    }

    /// `::before` content is made for every element a rule matches: 3.5 KB of markup (200 elements, a 1,000-word
    /// `content`) made 400,000 text pieces, past any size cap. The renderer's text cap bounds it too.
    func testBeforeContentAmplifierIsBoundedByTheTextCap() throws {
        let content = String(repeating: "a ", count: 1000)
        let (instance, seconds, megabytes) = self.measuredBoot("<!doctype html><style>b::before{content:\"\(content)\"}</style>" + String(repeating: "<b></b>", count: 200))
        XCTAssertLessThan(megabytes, 100.0)
        XCTAssertLessThan(seconds, 2.0)
        instance.destroy()
    }

    /// Each boot script has a slice of its own (upstream's pumpScripts): three scripts spinning 300 ms each (on the wall
    /// clock as their CPU), 900 ms in all, boot, none stopped. The boot task stops once a slice is spent (two scripts),
    /// and the third runs on a wake (the fix wave's review I-A).
    func testEachBootScriptHasASliceOfItsOwn() throws {
        self.useWallTimeAsCpu()
        let script = "<script>\(MessageWidgetTestCase.spin(300)) window.n = (window.n || 0) + 1;</script>"
        let (instance, _, _) = self.measuredBoot("<p>markup</p>" + String(repeating: script, count: 3))
        XCTAssertTrue(self.pump(until: { instance.evaluateForTesting("String(window.n)") == "3" }, timeout: 5.0))
        XCTAssertNil(instance.deadReason)
        instance.destroy()
    }

    /// Boots `loop` as a script and requires it stopped at its slice, frozen with upstream's reason. A loop of host calls
    /// or costly builtins is checked at QuickJS's interrupt, which reads the CPU clock.
    private func assertLoopIsStopped(_ loop: String, file: StaticString = #filePath, line: UInt = #line) {
        let (instance, _, _) = self.measuredBoot("<p>markup</p><script>" + loop + "</script>")
        XCTAssertEqual(instance.deadReason, LimitsTests.scriptStop, file: file, line: line)
        XCTAssertTrue(self.isFrozenWithBadge(instance), file: file, line: line)
        instance.destroy()
    }

    func testRandomFillLoopIsStoppedAtItsSlice() throws {
        // No crypto until M2: a host call that copies 64 KB each time instead, on an element never inserted (its
        // attribute sets are no operations of a batch, widget-sandbox v0.3.0's limit.batch).
        self.assertLoopIsStopped("var s = 'x'.repeat(65536); var e = document.createElement('p'); for (;;) e.setAttribute('data-x', s);")
    }

    func testLogLoopIsStoppedAtItsSlice() throws {
        self.assertLoopIsStopped("var s = 'a'.repeat(4 << 20); for (;;) console.log(s);")
    }

    func testBridgeLoopIsStoppedAtItsSlice() throws {
        self.assertLoopIsStopped("for (;;) TelegramWidget.ready();")
    }

    func testRepeatLoopIsStoppedAtItsSlice() throws {
        // 1 MB strings: 4 MB ones meet the 8 MiB heap first (widget-sandbox v0.3.0), a stop of another kind.
        self.assertLoopIsStopped("var x; for (;;) x = 'a'.repeat(1 << 20);")
    }

    func testStringifyLoopIsStoppedAtItsSlice() throws {
        self.assertLoopIsStopped("var a = []; for (var i = 0; i < 200000; i++) a.push(i); var x; for (;;) x = JSON.stringify(a);")
    }

    /// The stop cannot be caught: it ends the script where it stands, so the stop names the script, rather than letting
    /// its `catch` run and the task end later.
    func testCaughtHostCallIsStillStopped() throws {
        let (instance, _, _) = self.measuredBoot("<p>markup</p><script>var s = 'x'.repeat(65536); var d = document.createElement('p'); try { for (;;) d.setAttribute('data-x', s); } catch (e) {} TelegramWidget.ready();</script>")
        XCTAssertEqual(instance.deadReason, LimitsTests.scriptStop)
        instance.destroy()
    }

    /// The load is a task of its own (upstream's `loaded`): a script and a `load` handler spinning 400 ms each (on the
    /// wall clock as their CPU) boot.
    func testTheLoadHasASliceOfItsOwn() throws {
        self.useWallTimeAsCpu()
        let spin = MessageWidgetTestCase.spin(400)
        let (instance, _, _) = self.measuredBoot("<p>markup</p><script>\(spin) window.addEventListener('load', function () { \(spin) window.loaded = true; });</script>")
        XCTAssertNil(instance.deadReason)
        XCTAssertEqual(instance.evaluateForTesting("String(window.loaded)"), "true")
        instance.destroy()
    }

    /// The runtime's native work during a task is the task's: a loop whose cost is in the DOM (a 20 KB style attribute
    /// set again and again) is stopped at its slice.
    func testNativeDOMWorkCountsAgainstTheTask() throws {
        let instance = self.make("<!doctype html><p id=p>x</p><script>var p = document.getElementById('p'); for (;;) p.setAttribute('style', 'color:red;'.repeat(2000));</script>")
        _ = instance.layout(width: 360.0)
        XCTAssertEqual(instance.deadReason, LimitsTests.scriptStop)
        instance.destroy()
    }

    /// 20,000 elements, the renderer's node cap: bounded in memory and time whatever becomes of the widget (its script
    /// runs at most its 500 ms slice).
    func testTwentyThousandNodeDocumentIsBounded() throws {
        let (instance, seconds, megabytes) = self.measuredBoot("<script>for (var i = 0; i < 20000; i++) document.body.appendChild(document.createElement('div')).textContent = 'x'</script>")
        XCTAssertLessThan(megabytes, 200.0)
        XCTAssertLessThan(seconds, 5.0)
        instance.destroy()
    }
}
