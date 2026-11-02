import XCTest
@testable import MessageWidget

/// SDK v1 §5.7 (V2b plan, Task 5): a stopped widget is built again the next time its bubble is shown; after 2 stops in a
/// row it stays stopped until the app restarts (the policy is in memory) or the message gets new HTML (a new source).
class RestartPolicyTests: MessageWidgetTestCase {
    /// Loops forever in a task when its stored `loop` is "1", so its CPU slice stops it; runs quietly otherwise.
    private let source = "<!doctype html><p>x</p><script>if (localStorage.getItem('loop') === '1') setTimeout(() => { for (;;) {} }, 0)</script>"

    private func makeRegistry(_ policy: MessageWidgetRestartPolicy) -> MessageWidgetRegistry {
        let pool = self.pool!, turn = self.turn!
        return MessageWidgetRegistry(factory: { source, theme, label, max, locale, storage, _, _, startsStopped in
            MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max, locale: locale, storage: storage, startsStopped: startsStopped, pool: pool, waitPolicy: .unbounded, turn: turn, scale: 1.0)
        }, restartPolicy: policy)
    }

    /// One bubble's life: the widget shown, run until it stops when it loops, then the bubble goes.
    private func show(_ policy: MessageWidgetRestartPolicy, source: String? = nil, loops: Bool) -> MessageWidgetInstance? {
        let source = source ?? self.source
        let registry = self.makeRegistry(policy)
        registry.storage = MessageWidgetStorage(local: [.init(key: "loop", value: loops ? "1" : "0")], session: [])
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [], source: source, width: 300.0)
        registry.endPass()
        let instance = (registry.view(path: [], source: source) as? MessageWidgetView)?.instance
        if loops || instance?.startedStopped == true {
            XCTAssertTrue(self.pump(until: { instance?.deadReason != nil }, timeout: 10.0))
        } else {
            self.pump(0.2)
        }
        registry.destroyAll()
        return instance
    }

    func testASecondStopInARowKeepsTheWidgetStopped() {
        let policy = MessageWidgetRestartPolicy()
        let first = self.show(policy, loops: true)
        XCTAssertEqual(first?.startedStopped, false)
        XCTAssertNotNil(first?.deadReason)
        let second = self.show(policy, loops: true)
        XCTAssertEqual(second?.startedStopped, false)
        XCTAssertNotNil(second?.deadReason)
        let third = self.show(policy, loops: false)
        XCTAssertEqual(third?.startedStopped, true)
        XCTAssertNotNil(third?.deadReason)
    }

    func testARunWithoutAStopResetsTheCount() {
        let policy = MessageWidgetRestartPolicy()
        _ = self.show(policy, loops: true)
        let quiet = self.show(policy, loops: false)
        XCTAssertNil(quiet?.deadReason)
        _ = self.show(policy, loops: true)
        let fourth = self.show(policy, loops: true)
        XCTAssertEqual(fourth?.startedStopped, false)
    }

    func testANewSourceBootsAgain() {
        let policy = MessageWidgetRestartPolicy()
        _ = self.show(policy, loops: true)
        _ = self.show(policy, loops: true)
        XCTAssertEqual(self.show(policy, loops: true)?.startedStopped, true)
        let edited = self.show(policy, source: self.source + "<p>edited</p>", loops: false)
        XCTAssertEqual(edited?.startedStopped, false)
        XCTAssertNil(edited?.deadReason)
    }

    /// Review Focus 5: a stop counts once, however many passes see the stopped widget.
    func testAStopCountsOnceAcrossPasses() {
        let policy = MessageWidgetRestartPolicy()
        let registry = self.makeRegistry(policy)
        registry.storage = MessageWidgetStorage(local: [.init(key: "loop", value: "1")], session: [])
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [], source: self.source, width: 300.0)
        registry.endPass()
        let instance = (registry.view(path: [], source: self.source) as? MessageWidgetView)?.instance
        XCTAssertTrue(self.pump(until: { instance?.deadReason != nil }, timeout: 10.0))
        for _ in 0 ..< 5 {
            registry.beginPass(ownerId: 1, theme: .light)
            _ = registry.size(path: [], source: self.source, width: 300.0)
            registry.endPass()
        }
        registry.destroyAll()
        XCTAssertEqual(policy.stopsInARow(MessageWidgetRestartPolicy.Key(owner: AnyHashable(1), source: self.source)), 1)
    }
}
