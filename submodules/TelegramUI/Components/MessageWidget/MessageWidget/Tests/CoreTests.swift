import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D2/D4: the core runs one task at a time and leaves what main needs in the task's snapshot.
class CoreTests: MessageWidgetTestCase {
    private func makeCore(_ source: String) -> MessageWidgetCore {
        let timers = MessageWidgetTimers()
        timers.fire = { [unowned self] _, body in
            self.onWorker(body)
        }
        return MessageWidgetCore(source: source, stoppedLabel: "Widget stopped", maxMessageLength: 4096, timers: timers, scale: 1.0)
    }

    private func task(_ core: MessageWidgetCore, _ kind: WidgetSnapshot.Kind, _ body: @escaping () -> Void) -> WidgetSnapshot {
        return self.onWorker {
            core.run(kind, meter: WorkMeter(threshold: .max), body)
        }
    }

    private func boot(_ core: MessageWidgetCore) -> WidgetSnapshot {
        return self.task(core, .boot) {
            core.boot(width: 300.0, theme: .light, visible: true, budgets: nil)
        }
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
        XCTAssertGreaterThan(boot.units, 0)
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
        XCTAssertTrue(reason.contains("Work limit"), reason)
        XCTAssertGreaterThan(boot.units, MessageWidgetCore.bootWorkUnits)
    }

    /// Spec D7 ruling: the parse is not charged to the widget, but main waits on it, so the task's meter counts it.
    func testTheTasksUnitsCountTheUnchargedParse() throws {
        let core = self.makeCore(LimitsTests.heavyMarkup)
        defer {
            self.onWorker { core.teardown() }
        }
        let boot = self.boot(core)
        XCTAssertEqual(boot.state, .live)
        let parse = self.onWorker { core.parseWork }
        XCTAssertGreaterThan(parse, 100_000)
        XCTAssertGreaterThanOrEqual(boot.units, parse)
    }
}
