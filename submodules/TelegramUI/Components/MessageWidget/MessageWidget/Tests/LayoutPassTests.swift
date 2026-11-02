import QuartzCore
import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D5: the layout pass waits for a boot or a new width within the turn's cap; until it
/// finishes it answers the placeholder or the previous size, and the bubble lays out again when it lands.
class LayoutPassTests: MessageWidgetTestCase {
    /// A cap that ends a gated task's wait at once in test time. Only tests whose task is held use a cap (planning
    /// ruling 8).
    private let capped = MessageWidgetWaitPolicy(cap: 0.05)
    private static let tall = "<!doctype html><body style='margin:0;padding:0'><div style='height:300px;background:#f00'></div></body>"
    private static let paragraph = "<!doctype html><body style='margin:0'><p style='margin:0;font:16px/20px sans-serif'>\(String(repeating: "word ", count: 80))</p></body>"

    /// The oracle `testAThemeChangeDuringABootAppliesAfterIt` reads: the widget's scripts see the theme the host set.
    /// Passes on arrival. If it fails, that test needs another observable, not another expectation.
    func testTheWidgetsScriptsSeeTheTheme() {
        let instance = self.make("<!doctype html><p>x</p>", theme: .light)
        _ = instance.layout(width: 300.0)
        // TelegramWidget.theme (matchMedia comes with M2).
        let query = "TelegramWidget.theme"
        XCTAssertEqual(instance.evaluateForTesting(query), "light")
        instance.setTheme(.dark)
        XCTAssertEqual(instance.evaluateForTesting(query), "dark")
        instance.destroy()
    }

    /// Fails first: the snapshot of the abandoned width laid the bubble out too, at a width nobody asks for any more.
    func testASnapshotForAWidthSinceReplacedDoesNotRelayOut() {
        let instance = self.make(LayoutPassTests.paragraph, policy: self.capped)
        _ = self.bootFully(instance, width: 300.0)
        var changes = 0
        instance.onLayoutChange = {
            changes += 1
        }
        let gate = instance.gateNextTaskForTesting()
        // Held at 200; then 360 is asked for and queued behind it (the turn's cap is spent: no wait).
        _ = instance.layout(width: 200.0)
        _ = instance.layout(width: 360.0)
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.layout] == 2 }))
        self.pump(0.1)
        XCTAssertEqual(changes, 1, "only the width still asked for lays the bubble out")
        XCTAssertEqual(instance.layout(width: 360.0).width, 360.0)
        XCTAssertEqual(instance.queuedForTesting[.layout]?.waited, 2, "and that relayout queued nothing")
        instance.destroy()
    }

    /// Final review I1. A bubble wider than its widget (a forward, reply or author header) lays the widget out at the
    /// width it offers, then fills it to its own; every later pass asks for both again. Each pass queued two width
    /// tasks, and a fill that missed its wait landed late with another size, laid the bubble out again, and so on
    /// without end. A filled widget keeps its width while the same width is offered.
    func testAFilledWidgetKeepsItsWidthOnLaterPasses() {
        let instance = self.make(LayoutPassTests.paragraph, policy: self.capped)
        _ = self.bootFully(instance, width: 340.0)
        var changes = 0
        instance.onLayoutChange = {
            changes += 1
        }
        let gate = instance.gateNextTaskForTesting()
        // Held: it misses its wait and lands late.
        _ = instance.fill(width: 300.0)
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { changes == 1 }), "the fill's late size lays the bubble out once")
        self.pump(0.1)
        let widthTasks = instance.queuedForTesting[.layout]?.waited ?? 0
        // The relayout that follows, and every pass after it: the offered width, then the fill.
        for _ in 0 ..< 3 {
            _ = instance.layout(width: 340.0)
            _ = instance.fill(width: 300.0)
            self.pump(0.1)
        }
        XCTAssertEqual(instance.queuedForTesting[.layout]?.waited ?? 0, widthTasks, "no width task: the widget keeps the width it was filled to")
        XCTAssertEqual(changes, 1, "and no further relayout")
        XCTAssertEqual(instance.layout(width: 340.0), instance.fill(width: 300.0))
        instance.destroy()
    }

    /// Pin. A different width offered after a fill (a rotation) lays the widget out again. Break: drop the
    /// `abs(width - self.offeredWidth) <= 0.5` condition in `layout` (a filled widget keeps its width whatever is
    /// offered) and this fails.
    func testANewOfferedWidthAfterAFillIsLaidOutAgain() {
        let instance = self.make(LayoutPassTests.paragraph)
        let offered = instance.layout(width: 340.0)
        let filled = instance.fill(width: 300.0)
        XCTAssertEqual(filled.width, 300.0)
        XCTAssertGreaterThan(filled.height, offered.height)
        XCTAssertEqual(instance.layout(width: 400.0).width, 400.0)
        XCTAssertEqual(instance.queuedForTesting[.layout]?.waited, 2)
        instance.destroy()
    }

    /// Fails first: the answer before any snapshot was the renderer's minimum height.
    func testABootThatMissesItsWaitIsThePlaceholderThenRelaysOut() {
        let instance = self.make(LayoutPassTests.tall, policy: self.capped)
        var changes = 0
        instance.onLayoutChange = {
            changes += 1
        }
        let gate = instance.gateNextTaskForTesting()
        XCTAssertEqual(instance.layout(width: 300.0), CGSize(width: 300.0, height: MessageWidgetInstance.placeholderHeight))
        XCTAssertEqual(instance.layoutVersion, 0)
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { changes == 1 }), "the boot's snapshot asks for a relayout")
        XCTAssertEqual(instance.layoutVersion, 1)
        XCTAssertEqual(instance.layout(width: 300.0), CGSize(width: 300.0, height: 300.0))
        XCTAssertEqual(instance.queuedForTesting[.boot]?.waited, 1)
        XCTAssertNil(instance.queuedForTesting[.layout], "the relayout found the boot's snapshot at its width")
        instance.destroy()
    }

    /// Review Focus 4. Fails first on the placeholder. A ported chat message's parse takes longer than a 1 ms cap: main's
    /// wait ends at the cap (the only bound since the CPU-clock limits), and the widget goes on to boot.
    func testAHeavyParseEndsTheWaitAtTheCap() {
        let instance = self.make(LimitsTests.heavyMarkup, policy: MessageWidgetWaitPolicy(cap: 0.001))
        XCTAssertEqual(instance.layout(width: 360.0), CGSize(width: 360.0, height: MessageWidgetInstance.placeholderHeight))
        XCTAssertNil(instance.appliedForTesting[.boot])
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.boot] == 1 }, timeout: 60.0))
        XCTAssertNil(instance.deadReason)
        XCTAssertFalse(instance.failedToStart)
        XCTAssertGreaterThan(instance.layout(width: 360.0).height, MessageWidgetInstance.placeholderHeight)
        instance.destroy()
    }

    /// Fails first: a start failure applied after its wait moved nothing, so the block stayed a placeholder.
    func testALateStartFailureDrawsAsCodeOnTheRelayout() {
        self.failUnstartableSources()
        let pool = self.pool!, turn = self.turn!, capped = self.capped
        var gate: MessageWidgetInstance.TaskGate?
        let registry = MessageWidgetRegistry(factory: { source, theme, label, max, _, _, _, _, _ in
            let instance = MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max, pool: pool, waitPolicy: capped, turn: turn, scale: 1.0)
            gate = instance?.gateNextTaskForTesting()
            return instance
        })
        var changes = 0
        registry.onLayoutChange = {
            changes += 1
        }
        let source = self.unstartableSource("<!doctype html><p>x</p>")
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertEqual(registry.size(path: [0], source: source, width: 300.0), CGSize(width: 300.0, height: MessageWidgetInstance.placeholderHeight))
        registry.endPass()
        gate?.release.signal()
        XCTAssertTrue(self.pump(until: { changes == 1 }), "the late failure asks for a relayout")
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: source, width: 300.0), "drawn as code on the relayout")
        registry.endPass()
        XCTAssertTrue(registry.layoutVersions.isEmpty)
    }

    /// Pin. Break: in `layout`, `} else if abs(width - self.requestedWidth) > 0.5 {` → `} else {` (a width task on
    /// every call) and this fails.
    func testAWidgetWithASnapshotAtTheWidthQueuesNothing() {
        let instance = self.make(LayoutPassTests.tall)
        let size = instance.layout(width: 300.0)
        XCTAssertEqual(instance.layout(width: 300.0), size)
        XCTAssertEqual(instance.layout(width: 300.4), size)
        XCTAssertNil(instance.queuedForTesting[.layout], "no task: the snapshot is at this width")
        instance.destroy()
    }

    /// Pin. Break: in `apply`, `if changed && !self.inLayoutCall` → `if changed && false` and this fails (no relayout).
    func testANewWidthKeepsThePreviousSizeUntilItsTaskIsDone() {
        let instance = self.make(LayoutPassTests.paragraph, policy: self.capped)
        let wide = self.bootFully(instance, width: 360.0)
        var changes = 0
        instance.onLayoutChange = {
            changes += 1
        }
        let gate = instance.gateNextTaskForTesting()
        XCTAssertEqual(instance.layout(width: 200.0), CGSize(width: 200.0, height: wide.height), "the previous size, no wider than offered")
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { changes == 1 }))
        XCTAssertGreaterThan(instance.layout(width: 200.0).height, wide.height)
        XCTAssertEqual(instance.queuedForTesting[.layout]?.waited, 1, "the relayout at 200 found the snapshot at 200")
        instance.destroy()
    }

    /// Review Focus 2. Pin. Break: in `setTheme`, return while no snapshot has a size yet (`guard self.reportedSize !=
    /// nil`) and this fails: the theme is lost.
    func testAThemeChangeDuringABootAppliesAfterIt() {
        let instance = self.make("<!doctype html><p>x</p>", theme: .light, policy: self.capped)
        let gate = instance.gateNextTaskForTesting()
        _ = instance.layout(width: 300.0)
        // Queued behind the held boot; the turn's cap is spent, so it is not waited for.
        instance.setTheme(.dark)
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.theme] == 1 }))
        XCTAssertEqual(instance.appliedForTesting[.boot], 1)
        XCTAssertEqual(instance.evaluateForTesting("TelegramWidget.theme"), "dark")
        instance.destroy()
    }

    /// Review Focus 3. Pin. Break: move `if self.destroyed { return }` in `apply` below the size handling and this fails.
    func testALateBootForADestroyedWidgetIsIgnored() {
        let instance = self.make(LayoutPassTests.tall, policy: self.capped)
        var changes = 0
        instance.onLayoutChange = {
            changes += 1
        }
        let gate = instance.gateNextTaskForTesting()
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(gate.started.wait(timeout: .now() + 5.0), .success)
        instance.destroy()
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.boot] == 1 }), "the late snapshot reached main")
        self.pump(0.1)
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(instance.layoutVersion, 0)
        XCTAssertTrue(self.pump(until: { instance.isIdleForTesting }), "the teardown ran after the boot")
    }
}
