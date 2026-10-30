import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D6: taps wait and carry their permission; timer ticks and frames wait unless the widget is hidden
/// or demoted; one frame task at a time; the newest visibility replaces one still queued.
class EventTests: MessageWidgetTestCase {
    /// A cap that ends a held task's wait at once in test time (planning ruling 8).
    private let capped = MessageWidgetWaitPolicy(cap: 0.05)
    private static let ticker = "<!doctype html><p id=n>0</p><script>window.n = 0; setInterval(function () { document.getElementById('n').textContent = String(++window.n) }, 20)</script>"
    /// 20 ms of the widget thread's CPU under `useWallTimeAsCpu()`: past the demotion threshold (10 ms), far inside the
    /// slice and the quota.
    private static let heavyLoop = MessageWidgetTestCase.spin(20)

    private func frameTasks(_ instance: MessageWidgetInstance) -> Int {
        let frames = instance.queuedForTesting[.frame]
        return (frames?.waited ?? 0) + (frames?.unwaited ?? 0)
    }

    /// Fails first: every tick was waited for.
    /// The system's Reduce Motion reaches the widget as prefers-reduced-motion: set before the widget boots, its first
    /// layout's; changed later, its media queries follow.
    func testReduceMotionReachesTheWidget() {
        let instance = self.make("<!doctype html><p>x</p>")
        instance.setReducedMotion(true)
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(instance.evaluateForTesting("String(matchMedia('(prefers-reduced-motion: reduce)').matches)"), "true")
        instance.setReducedMotion(false)
        XCTAssertEqual(instance.evaluateForTesting("String(matchMedia('(prefers-reduced-motion: reduce)').matches)"), "false")
        instance.destroy()
    }

    func testAHiddenWidgetsTimersAreNotWaitedFor() {
        let instance = self.make(EventTests.ticker)
        _ = instance.layout(width: 360.0)
        // The core's timers fire as its wakes (MessageWidgetCore.scheduleWake): one `.wake` task per due deadline.
        XCTAssertTrue(self.pump(until: { (instance.queuedForTesting[.wake]?.waited ?? 0) >= 3 }))
        XCTAssertEqual(instance.queuedForTesting[.wake]?.unwaited ?? 0, 0, "visible: every tick is waited for")
        instance.setVisible(false)
        let waited = instance.queuedForTesting[.wake]?.waited ?? 0
        self.pump(2.5)
        let hidden = instance.queuedForTesting
        XCTAssertEqual(hidden[.wake]?.waited ?? 0, waited, "hidden: no tick is waited for")
        XCTAssertGreaterThan(hidden[.wake]?.unwaited ?? 0, 0, "the 1 Hz ticks still run")
        instance.destroy()
    }

    /// Fails first (it does not build: there is no demotion yet). A background drain past 10 ms of the widget thread's
    /// CPU demotes (the CPU-clock limits design; a million units before).
    func testABackgroundDrainPast10msDemotes() {
        self.useWallTimeAsCpu()
        let instance = self.make("<!doctype html><p>x</p><script>setInterval(function () { \(EventTests.heavyLoop) }, 20)</script>")
        _ = instance.layout(width: 360.0)
        XCTAssertFalse(instance.demoted)
        XCTAssertTrue(self.pump(until: { (instance.queuedForTesting[.wake]?.unwaited ?? 0) >= 2 }))
        XCTAssertTrue(instance.demoted)
        XCTAssertEqual(instance.queuedForTesting[.wake]?.waited, 1, "the tick that crossed the threshold was the last one waited for")
        XCTAssertNil(instance.deadReason, "demoted, not stopped")
        instance.destroy()
    }

    /// Fails first (it does not build). Boots and taps are what the user waits for: they never demote.
    func testABootOrATapPast10msDoesNotDemote() {
        self.useWallTimeAsCpu()
        let loop = EventTests.heavyLoop
        let instance = self.make("<!doctype html><body style='margin:0'><button id=b style='display:block;width:200px;height:40px' onclick='\(loop)'>b</button><script>\(loop)</script></body>")
        _ = instance.layout(width: 360.0)
        XCTAssertGreaterThan(instance.largestTaskCpuMillisecondsForTesting(.boot), MessageWidgetInstance.demotionCpuMilliseconds)
        instance.touch(action: 0, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        instance.touch(action: 2, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        XCTAssertGreaterThan(instance.largestTaskCpuMillisecondsForTesting(.touch), MessageWidgetInstance.demotionCpuMilliseconds)
        XCTAssertFalse(instance.demoted)
        instance.destroy()
    }

    /// Fails first: a second frame task was queued behind the one still running. The shim asks the host for a frame
    /// only while it holds no callback (`requestAnimationFrame` in widget-sandbox's globals.ts), so the click cancels
    /// the boot's pending callback before asking again: that is what lets a request reach main while a frame is in
    /// flight.
    func testNoFrameTaskIsQueuedWhileOneIsInFlight() {
        let instance = self.make("<!doctype html><body style='margin:0'><button id=b style='display:block;width:200px;height:40px' onclick='cancelAnimationFrame(window.pending); requestAnimationFrame(function () {})'>b</button><script>window.pending = requestAnimationFrame(function () {})</script></body>", policy: self.capped)
        _ = self.bootFully(instance, width: 360.0)
        instance.touch(action: 0, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        let tap = instance.gateNextTaskForTesting()
        // Held: its click asks for a frame.
        instance.touch(action: 2, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        let frame = instance.gateNextTaskForTesting()
        // The boot's request: a frame task, held behind the tap.
        instance.deliverFrameForTesting()
        XCTAssertEqual(self.frameTasks(instance), 1)
        tap.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.touch] == 2 }))
        // The tap asked for a frame while the first is still running: this tick queues nothing.
        instance.deliverFrameForTesting()
        XCTAssertEqual(self.frameTasks(instance), 1)
        frame.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.frame] == 1 }))
        instance.deliverFrameForTesting()
        XCTAssertEqual(self.frameTasks(instance), 2)
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.frame] == 2 }))
        instance.destroy()
    }

    /// Pin. Break: drop the restore in `HostState::PressScope`'s destructor (the press stays active after its events)
    /// and this fails (the timer's call is sent).
    func testATimerDoesNotCarryTheTapsPermission() {
        let instance = self.make("<!doctype html><body style='margin:0'><button id=b style='display:block;width:200px;height:40px' onclick=\"setTimeout(function () { TelegramWidget.openLink('https://example.org/later') }, 0)\">b</button></body>")
        _ = instance.layout(width: 360.0)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = {
            calls.append($0)
        }
        instance.touch(action: 0, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        instance.touch(action: 2, at: CGPoint(x: 20.0, y: 20.0), pointer: 0, primary: true)
        // The timer runs after the up's task, in the same core task or a wake: refused either way.
        XCTAssertTrue(self.pump(until: { instance.diagnostics.contains { $0.kind == "activation-blocked" && $0.detail.contains("openLink") } }))
        self.pump(0.05)
        XCTAssertEqual(calls, [])
        XCTAssertEqual(instance.queuedForTesting[.touch]?.waited, 2, "taps are always waited for")
        instance.destroy()
    }

    /// Pin. Break: drop `key: "visibility"` in `updateVisibility` and this fails (three tasks applied).
    func testAWaitingVisibilityTaskIsReplacedByTheNewest() {
        let instance = self.make(VisibilityTests.frameCounter, policy: self.capped)
        _ = self.bootFully(instance, width: 360.0)
        let gate = instance.gateNextTaskForTesting()
        // Held: what follows waits behind it.
        instance.touch(action: 0, at: CGPoint(x: 10.0, y: 10.0), pointer: 0, primary: true)
        instance.setVisible(false)
        instance.setVisible(true)
        instance.setVisible(false)
        XCTAssertEqual(instance.queuedForTesting[.visibility]?.unwaited, 3, "never waited for")
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.visibility] == 1 }))
        self.pump(0.1)
        XCTAssertEqual(instance.appliedForTesting[.visibility], 1, "three changes, one task: the newest")
        XCTAssertEqual(instance.evaluateForTesting("String(document.hidden)"), "true")
        instance.destroy()
    }

    /// Review Focus 1. Pin. Break: delete `guard !self.destroyed else { return false }` in `perform` and this fails.
    func testATimerFiringAfterDestroyRunsNothing() {
        let instance = self.make("<!doctype html><p id=p>x</p><script>setTimeout(function () { document.getElementById('p').textContent = 'fired' }, 300)</script>", policy: self.capped)
        _ = self.bootFully(instance, width: 360.0)
        let gate = instance.gateNextTaskForTesting()
        // Held, so the teardown (which cancels the timer) cannot run before the timer fires on main.
        instance.touch(action: 0, at: CGPoint(x: 10.0, y: 10.0), pointer: 0, primary: true)
        instance.destroy()
        self.pump(0.6)
        XCTAssertNil(instance.queuedForTesting[.timer], "the fire found the widget destroyed")
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { instance.isIdleForTesting }), "the teardown ran after the held task")
        XCTAssertNil(instance.appliedForTesting[.timer])
    }
}
