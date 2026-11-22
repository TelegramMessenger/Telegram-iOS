import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D2/D4: the core runs one task at a time and leaves what main needs in the task's snapshot.
class CoreTests: MessageWidgetTestCase {
    private func makeCore(_ source: String, scale: CGFloat = 1.0) -> MessageWidgetCore {
        let timers = MessageWidgetTimers()
        timers.fire = { [unowned self] _, body in
            self.onWorker(body)
        }
        return MessageWidgetCore(source: source, stoppedLabel: "Widget stopped", maxMessageLength: 4096, timers: timers, scale: scale)
    }

    private func task(_ core: MessageWidgetCore, _ kind: WidgetSnapshot.Kind, _ body: @escaping () -> Void) -> WidgetSnapshot {
        return self.onWorker {
            core.run(kind, body)
        }
    }

    private func boot(_ core: MessageWidgetCore) -> WidgetSnapshot {
        return self.task(core, .boot) {
            core.boot(width: 300.0, theme: .light, visible: true)
        }
    }

    /// A tile that cannot be drawn though the widget has published (its bitmap past the renderer's pixel cap here, a
    /// refused allocation on a device) keeps the last frame up, as the drawer always has, and says so in the diagnostics.
    func testATileThatCannotBeDrawnIsADiagnostic() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0'><div style='height:40px;background:#f00'></div></body>", scale: 40.0)
        defer {
            self.onWorker { core.teardown() }
        }
        _ = self.boot(core)
        let draw = self.task(core, .draw) {
            core.draw(request: 1)
        }
        XCTAssertEqual(draw.frame?.tiles.count, 0)
        XCTAssertTrue(draw.diagnostics.contains { $0.kind == "tile-draw-failed" }, "\(draw.diagnostics)")
    }

    func testABootPublishesItsSizeTilesAndState() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0;padding:0'><div style='height:200px;background:#f00'></div></body>")
        defer {
            self.onWorker { core.teardown() }
        }
        let boot = self.boot(core)
        XCTAssertEqual(boot.sequence, 1)
        XCTAssertEqual(boot.kind, .boot)
        XCTAssertEqual(boot.width, 300.0)
        XCTAssertEqual(boot.size, CGSize(width: 300.0, height: 200.0))
        XCTAssertEqual(boot.state, .live)
        // The tiles are a draw task's (the size is critical, the drawing is not).
        XCTAssertNil(boot.frame)
        XCTAssertTrue(boot.needsDraw)
        let draw = self.task(core, .draw) {
            core.draw(request: 1)
        }
        XCTAssertEqual(draw.drawRequest, 1)
        XCTAssertFalse(draw.needsDraw)
        XCTAssertEqual(Set(draw.frame.map { Array($0.tiles.keys) } ?? []), Set(WidgetFrame.grid(for: CGSize(width: 300.0, height: 200.0))))
        let idle = self.task(core, .event) {
            _ = core.evaluate("1")
        }
        XCTAssertEqual(idle.sequence, 3)
        XCTAssertFalse(idle.needsDraw, "nothing changed: nothing to draw")
        let again = self.task(core, .draw) {
            core.draw(request: 2)
        }
        XCTAssertEqual(again.frame?.tiles.count, 0, "nothing changed: no tile drawn")
    }

    func testATapsBridgeCallsLeaveWithItsOwnSnapshot() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0'><button id=b style='display:block;width:200px;height:40px' onclick=\"TelegramWidget.openLink('https://example.org/hi')\">b</button></body>")
        defer {
            self.onWorker { core.teardown() }
        }
        _ = self.boot(core)
        let tap = self.task(core, .touch) {
            core.touch(action: 0, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
            core.touch(action: 2, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        }
        XCTAssertEqual(tap.bridgeCalls, [.openLink("https://example.org/hi")])
        let click = self.task(core, .event) {
            _ = core.evaluate("document.getElementById('b').click(); 'ok'")
        }
        XCTAssertEqual(click.bridgeCalls, [], "a click outside a tap sends nothing")
        XCTAssertTrue(click.diagnostics.contains { $0.kind == "activation-blocked" })
    }

    /// A press the view retracts (action 4: it started one for the bubble's question, and a pointer's touch pressed there
    /// instead) ends for the widget as a cancel, but the double click it came between goes on.
    func testARetractedPressKeepsADoubleClick() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0'><div id=d style='height:40px'></div><script>window.log = []; for (const t of ['click', 'dblclick', 'pointercancel']) document.getElementById('d').addEventListener(t, e => log.push(t + ':' + e.detail))</script></body>")
        defer {
            self.onWorker { core.teardown() }
        }
        _ = self.boot(core)
        let point = CGPoint(x: 20.0, y: 20.0)
        var log: String?
        _ = self.task(core, .touch) {
            core.touch(action: 0, at: point, pointer: 1, primary: true, mouse: true)
            core.touch(action: 2, at: point, pointer: 1, primary: true, mouse: true)
            core.touch(action: 0, at: point, pointer: 2, primary: true)
            core.touch(action: 4, at: point, pointer: 2, primary: true)
            core.touch(action: 0, at: point, pointer: 3, primary: true, mouse: true)
            core.touch(action: 2, at: point, pointer: 3, primary: true, mouse: true)
        }
        _ = self.task(core, .event) {
            log = core.evaluate("log.join(' ')")
        }
        XCTAssertEqual(log, "click:1 pointercancel:0 click:2 dblclick:2")
    }

    /// Multitouch (design §5.1): every finger's down answers what its press is to the widget, not only the primary's.
    func testANonPrimaryDownAnswers() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0'><button id=b style='display:block;width:200px;height:40px'>b</button></body>")
        defer {
            self.onWorker { core.teardown() }
        }
        _ = self.boot(core)
        var press: MessageWidgetPress = .none
        _ = self.task(core, .touch) {
            press = core.touch(action: 0, at: CGPoint(x: 20.0, y: 20.0), pointer: 2, primary: false)
            core.touch(action: 3, at: CGPoint(x: 20.0, y: 20.0), pointer: 2, primary: false)
        }
        XCTAssertTrue(press.takesTaps)
    }

    /// SDK v1 §5.5 (v0.1.2): touch-action: none claims the press's holds for the widget (it gets contextmenu, and the
    /// bubble opens no menu); pan-y and a button do not.
    func testANoneElementClaimsHolds() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0'><div style='touch-action:none;height:40px'></div>"
            + "<div style='touch-action:pan-y;height:40px'></div><button style='display:block;width:200px;height:40px'>b</button></body>")
        defer {
            self.onWorker { core.teardown() }
        }
        _ = self.boot(core)
        let holds = [20.0, 60.0, 100.0].map { y -> Bool in
            var press: MessageWidgetPress = .none
            _ = self.task(core, .touch) {
                press = core.touch(action: 0, at: CGPoint(x: 50.0, y: y), pointer: 1, primary: true)
                core.touch(action: 3, at: CGPoint(x: 50.0, y: y), pointer: 1, primary: true)
            }
            return press.hold
        }
        XCTAssertEqual(holds, [true, false, false])
    }

    /// An iPad pointer presses as the policy's mouse: its holds and sideways drags are the widget's whatever the
    /// touch-action (a pointer has no hold menu; a vertical drag still scrolls the chat). A secondary click claims holds
    /// only where touch-action: none does (the widget's contextmenu); elsewhere it is the chat's menu.
    func testAPointerPressClaimsHoldsAndSidewaysDrags() throws {
        let core = self.makeCore("<!doctype html><body style='margin:0'><div style='height:40px'></div>"
            + "<div style='touch-action:none;height:40px'></div></body>")
        defer {
            self.onWorker { core.teardown() }
        }
        _ = self.boot(core)
        let presses = [(20.0, 0), (20.0, 2), (60.0, 2)].map { (y, button) -> MessageWidgetPress in
            var press: MessageWidgetPress = .none
            _ = self.task(core, .touch) {
                press = core.touch(action: 0, at: CGPoint(x: 50.0, y: y), pointer: 1, primary: true, mouse: true, button: button)
                core.touch(action: 3, at: CGPoint(x: 50.0, y: y), pointer: 1, primary: true, mouse: true, button: button)
            }
            return press
        }
        XCTAssertEqual(presses.map(\.claim), [[.horizontal], [.horizontal], [.horizontal]])
        XCTAssertEqual(presses.map(\.hold), [true, false, true])
    }

    /// widget-sandbox v0.1.3 (sdk-v1 §5.6): a task's snapshot carries the widget's resize anchor beside its size, top
    /// until the widget sets one.
    func testABootThatSetsBottomReportsIt() throws {
        let core = self.makeCore("<!doctype html><body><p>up</p><script>TelegramWidget.setResizeAnchor('bottom')</script></body>")
        let other = self.makeCore("<!doctype html><body><p>down</p></body>")
        defer {
            self.onWorker {
                core.teardown()
                other.teardown()
            }
        }
        XCTAssertEqual(self.boot(core).resizeAnchor, .bottom)
        XCTAssertEqual(self.boot(other).resizeAnchor, .top)
    }

    func testAStoppedWidgetIsFrozenWithItsReason() throws {
        let core = self.makeCore("<!doctype html><p>x</p><script>for (;;) {}</script>")
        defer {
            self.onWorker { core.teardown() }
        }
        let boot = self.boot(core)
        guard case let .frozen(reason) = boot.state else {
            return XCTFail("\(boot.state)")
        }
        // widget-sandbox's words: the script's own slice of the widget thread's CPU.
        XCTAssertEqual(reason, "CPU limit exceeded: more than 500 ms of continuous execution (script)")
    }

    // MARK: the CPU-clock limits (Task 5)

    /// A quota of 10 ms per second: one timer that spins 30 ms spends it, so the timer it sets is deferred to the retry
    /// time, when the core's wake runs it by itself.
    private static let throttled = MessageWidgetCpuLimits(cpuLimitMs: 500.0, cpuQuotaMs: 10.0, cpuQuotaWindowMs: 1000.0, cpuKillAfterMs: 0.0, mainThreadQuotaMs: 100.0)
    private static let throttledPage = "<!doctype html><p>x</p><script>window.log = []; setTimeout(() => { \(MessageWidgetTestCase.spin(30)) log.push('heavy'); setTimeout(() => log.push('next'), 0); }, 0);</script>"

    func testAThrottledWidgetWakesAtTheRetry() {
        self.useWallTimeAsCpu()
        let instance = self.make(CoreTests.throttledPage, cpuLimits: CoreTests.throttled)
        defer { instance.destroy() }
        _ = instance.layout(width: 360.0)
        XCTAssertTrue(self.pump(until: { instance.throttledStepsForTesting > 0 }, timeout: 5.0), "the second timer was never deferred")
        XCTAssertEqual(instance.evaluateForTesting("log.join()"), "heavy")
        XCTAssertTrue(self.pump(until: { instance.evaluateForTesting("log.join()") == "heavy,next" }, timeout: 5.0), "the retry never ran it")
        XCTAssertNil(instance.deadReason)
    }

    /// Hidden, a widget's wakes come at most once a second; a deferred task still runs at the first one after its retry.
    func testAHiddenThrottledWidgetStillWakes() {
        self.useWallTimeAsCpu()
        let instance = self.make(CoreTests.throttledPage, cpuLimits: CoreTests.throttled)
        defer { instance.destroy() }
        _ = instance.layout(width: 360.0)
        XCTAssertTrue(self.pump(until: { instance.throttledStepsForTesting > 0 }, timeout: 5.0), "the second timer was never deferred")
        instance.setVisible(false)
        XCTAssertTrue(self.pump(until: { instance.evaluateForTesting("log.join()") == "heavy,next" }, timeout: 6.0), "the retry never ran it")
        XCTAssertNil(instance.deadReason)
    }

    /// Review Focus 4: every step's CPU is taken on the thread that ran it. Thread A has spent 300 ms of its own CPU
    /// outside any step; a step on thread B, then one on A, each spinning 20 ms, record about that, never A's 300 ms nor a
    /// negative difference between two threads' clocks (clamped to 0).
    func testStepsMeasureTheirOwnThread() {
        let core = self.makeCore("<!doctype html><p>x</p><script>window.spin = ms => { const t0 = performance.now(); while (performance.now() - t0 < ms) {} };</script>")
        let a = PinnedThread(), b = PinnedThread()
        defer {
            a.run { core.teardown() }
            a.stop()
            b.stop()
        }
        _ = a.run { core.run(.boot) { core.boot(width: 300.0, theme: .light, visible: true) } }
        a.run {
            let start = CACurrentMediaTime()
            var x: UInt64 = 1
            while CACurrentMediaTime() - start < 0.3 {
                x = x &* 6364136223846793005 &+ 1442695040888963407
            }
            _ = x
        }
        for thread in [b, a] {
            let snapshot = thread.run { core.run(.event) { _ = core.evaluate("spin(20); 1") } }
            XCTAssertGreaterThan(snapshot.cpuMilliseconds, 0.0)
            XCTAssertLessThan(snapshot.cpuMilliseconds, 200.0)
        }
    }
}

/// One thread of its own, running each body it is given in turn (a step pinned to a thread, for
/// `testStepsMeasureTheirOwnThread`).
private final class PinnedThread {
    private let lock = NSCondition()
    private var bodies: [() -> Void] = []
    private var stopped = false
    private var thread: Thread?

    init() {
        let thread = Thread { [self] in
            while true {
                self.lock.lock()
                while self.bodies.isEmpty && !self.stopped {
                    self.lock.wait()
                }
                if self.bodies.isEmpty {
                    self.lock.unlock()
                    return
                }
                let body = self.bodies.removeFirst()
                self.lock.unlock()
                body()
            }
        }
        thread.stackSize = 8 << 20
        self.thread = thread
        thread.start()
    }

    /// Runs `body` on the thread and waits for it.
    func run<T>(_ body: @escaping () -> T) -> T {
        var result: T?
        let done = DispatchSemaphore(value: 0)
        self.lock.lock()
        self.bodies.append {
            result = body()
            done.signal()
        }
        self.lock.signal()
        self.lock.unlock()
        done.wait()
        return result!
    }

    func stop() {
        self.lock.lock()
        self.stopped = true
        self.lock.signal()
        self.lock.unlock()
    }
}
