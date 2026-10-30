import MessageWidgetRendering
import XCTest
@testable import MessageWidget

class InstanceTests: MessageWidgetTestCase {
    /// Taps the element matched by `selector` (a real down + up through the renderer's hit test).
    func tap(_ instance: MessageWidgetInstance, _ selector: String) {
        guard let rect = self.borderBox(instance, selector) else {
            XCTFail("no rect for \(selector)")
            return
        }
        let p = CGPoint(x: rect.midX, y: rect.midY)
        instance.touch(action: 0, at: p, pointer: 0, primary: true)
        instance.touch(action: 2, at: p, pointer: 0, primary: true)
    }

    func testASandboxWidgetKeepsTheWholeWidthAsInABrowser() throws {
        // A page written for a browser viewport: its body fills the width, however narrow its content (an HTML message,
        // by contrast, is as wide as its content).
        let instance = self.make("<!doctype html><div style='width:120px;height:40px;background:#f00'></div>")
        XCTAssertEqual(instance.layout(width: 360.0).width, 360.0)
        instance.destroy()
    }

    func testExamplesBootToAHeight() throws {
        for name in ["01-weather-card", "02-split-bill", "03-faq-accordion", "04-poll", "05-countdown"] {
            let instance = self.make(self.fixture(name))
            let size = instance.layout(width: 360.0)
            XCTAssertEqual(size.width, 360.0)
            XCTAssertGreaterThan(size.height, 60.0, name)
            XCTAssertLessThanOrEqual(size.height, 600.0, name)
            XCTAssertNil(instance.deadReason, name)
            XCTAssertNil(instance.lastError, name)
            instance.destroy()
        }
    }

    func testTapChangesTextNotHeight() throws {
        let instance = self.make(self.fixture("02-split-bill"))
        let before = instance.layout(width: 360.0)
        var notified = 0
        instance.onLayoutChange = { notified += 1 }
        self.tap(instance, "#plus")
        XCTAssertEqual(instance.evaluateForTesting("document.getElementById('n').textContent"), "5")
        self.pump(0.1)
        XCTAssertEqual(instance.layout(width: 360.0).height, before.height)
        XCTAssertEqual(notified, 0)
        XCTAssertEqual(instance.layoutVersion, 0)
    }

    /// widget-sandbox v0.1.3: the instance keeps the anchor of the latest snapshot it applied, 'bottom' from the boot and
    /// 'top' from a later timer.
    func testTheInstanceKeepsTheLatestAnchor() throws {
        let instance = self.make("<!doctype html><body><p>a</p><script>TelegramWidget.setResizeAnchor('bottom');"
            + " setTimeout(() => TelegramWidget.setResizeAnchor('top'), 200);</script></body>")
        _ = instance.layout(width: 360.0)
        XCTAssertEqual(instance.resizeAnchor, .bottom)
        self.pump(0.6)
        XCTAssertEqual(instance.resizeAnchor, .top)
    }

    func testTapThatGrowsTheWidgetBumpsTheVersion() throws {
        let instance = self.make(self.fixture("03-faq-accordion"))
        let before = instance.layout(width: 360.0)
        let changed = self.expectation(description: "layout change")
        instance.onLayoutChange = { changed.fulfill() }
        self.tap(instance, ".q")
        self.wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(instance.layoutVersion, 1)
        XCTAssertGreaterThan(instance.layout(width: 360.0).height, before.height)
    }

    /// A press restyles `:active`, which relayouts in the renderer. Nothing listens for the press, so no
    /// JS task runs and `finishTask` never sees the new height: the touch itself must report it, after
    /// the call, once. The release's click does run a task, which must not report it a second time.
    func testPressThatChangesTheHeightBumpsTheVersion() throws {
        let instance = self.make("<!doctype html><style>body{margin:0;padding:0}#b{height:60px;background:#f00}#b:active{height:120px}</style><div id=b></div>")
        XCTAssertEqual(instance.layout(width: 360.0).height, 60.0)
        var notified = 0
        instance.onLayoutChange = { notified += 1 }
        let point = CGPoint(x: 20.0, y: 20.0)
        instance.touch(action: 0, at: point, pointer: 0, primary: true)
        XCTAssertEqual(instance.layoutVersion, 1)
        XCTAssertEqual(notified, 0, "the host was called back from inside the touch")
        XCTAssertEqual(instance.layout(width: 360.0).height, 120.0)
        self.pump(0.1)
        XCTAssertEqual(notified, 1)
        instance.touch(action: 2, at: point, pointer: 0, primary: true)
        XCTAssertEqual(instance.layoutVersion, 2)
        XCTAssertEqual(instance.layout(width: 360.0).height, 60.0)
        self.pump(0.1)
        XCTAssertEqual(notified, 2)
    }

    /// SDK v1 §2.5: a link call needs a press, one call per press.
    func testOpenLinkOnlyFromATapAndOncePerTap() throws {
        let instance = self.make("<!doctype html><body style='margin:0'><button id=go style='display:block;width:200px;height:40px' onclick=\"TelegramWidget.openLink('https://example.org/a'); TelegramWidget.openLink('https://example.org/b')\">go</button></body>")
        _ = instance.layout(width: 360.0)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.evaluateForTesting("TelegramWidget.openLink('https://example.org/spam'); 'ok'")
        self.pump(0.1)
        XCTAssertTrue(calls.isEmpty, "a script without a tap opened a link")
        XCTAssertTrue(instance.diagnostics.contains { $0.kind == "activation-blocked" })
        self.tap(instance, "#go")
        self.pump(0.1)
        XCTAssertEqual(calls, [.openLink("https://example.org/a")])
    }

    /// SDK v1 §2.6: haptics need no tap; the runtime's bucket lets 5 of a burst through, and the host gets each one.
    func testHapticsReachTheHost() throws {
        let instance = self.make("<!doctype html><p>h</p>")
        _ = instance.layout(width: 360.0)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.evaluateForTesting("const H = TelegramWidget.HapticFeedback; H.impactOccurred('soft').notificationOccurred('warning').selectionChanged(); for (let i = 0; i < 10; i++) H.selectionChanged(); 'ok'")
        self.pump(0.1)
        XCTAssertEqual(calls, [.haptic(kind: "impact", value: "soft"), .haptic(kind: "notification", value: "warning"), .haptic(kind: "selection", value: nil), .haptic(kind: "selection", value: nil), .haptic(kind: "selection", value: nil)])
        XCTAssertTrue(instance.diagnostics.contains { $0.kind == "haptic-limit" })
    }

    /// SDK v1 §3.1 (V2b plan, Task 4): the client's stored areas are in the widget at its first read.
    func testThePreloadReachesTheWidget() throws {
        let storage = MessageWidgetStorage(local: [.init(key: "k", value: "v")], session: [.init(key: "s", value: "1")])
        let instance = self.make("<!doctype html><p>s</p>", storage: storage)
        _ = instance.layout(width: 360.0)
        XCTAssertEqual(instance.evaluateForTesting("localStorage.getItem('k') + ':' + sessionStorage.getItem('s')"), "v:1")
    }

    /// §3.2: each area a task changed reaches the host once, at the task's end, `local` first, entries in insertion order.
    func testCommitsReachTheHostInOrder() throws {
        let instance = self.make("<!doctype html><p>c</p>")
        _ = instance.layout(width: 360.0)
        var commits: [MessageWidgetInstance.StorageCommit] = []
        instance.onStorageCommit = { commits.append($0) }
        _ = instance.evaluateForTesting("setTimeout(() => { sessionStorage.setItem('s', 'x'); localStorage.setItem('b', '2'); localStorage.setItem('a', '1'); }, 0); 'ok'")
        XCTAssertTrue(self.pump(until: { commits.count >= 2 }, timeout: 5.0))
        XCTAssertEqual(commits, [
            MessageWidgetInstance.StorageCommit(area: .local, entries: [.init(key: "b", value: "2"), .init(key: "a", value: "1")]),
            MessageWidgetInstance.StorageCommit(area: .session, entries: [.init(key: "s", value: "x")])
        ])
    }

    /// Review Focus 5: the writes of the task that stopped the widget are never committed.
    func testAStoppedWidgetCommitsNothingMore() throws {
        let instance = self.make("<!doctype html><p>x</p>")
        _ = instance.layout(width: 360.0)
        var commits: [MessageWidgetInstance.StorageCommit] = []
        instance.onStorageCommit = { commits.append($0) }
        _ = instance.evaluateForTesting("setTimeout(() => { localStorage.setItem('k', 'v'); for (;;) {} }, 0); 'ok'")
        XCTAssertTrue(self.pump(until: { instance.deadReason != nil }, timeout: 10.0))
        self.pump(0.2)
        XCTAssertEqual(commits, [])
    }

    /// Final review I1: the task running when the bubble destroys and releases its widget still delivers its commit —
    /// an area the widget reached is kept, even though the task's presentation is dropped (spec D5).
    func testTheCommitOfTheTaskRunningAtDestroyStillReachesTheHost() throws {
        // A capped wait: the gated timer task is waited for while the widget is visible.
        var instance: MessageWidgetInstance? = self.make("<!doctype html><p>d</p>", policy: MessageWidgetWaitPolicy(cap: 0.05))
        _ = instance?.layout(width: 360.0)
        var commits: [MessageWidgetInstance.StorageCommit] = []
        instance?.onStorageCommit = { commits.append($0) }
        _ = instance?.evaluateForTesting("setTimeout(() => { localStorage.setItem('k', 'v'); }, 300); 'ok'")
        // The next task is the timer's, not a draw of the boot or the evaluation.
        XCTAssertTrue(self.pump(until: { instance?.isDrawPendingForTesting == false }, timeout: 5.0))
        guard let gate = instance?.gateNextTaskForTesting() else {
            return XCTFail()
        }
        XCTAssertTrue(self.pump(until: { gate.started.wait(timeout: .now()) == .success }, timeout: 5.0))
        instance?.destroy()
        weak var released = instance
        instance = nil
        XCTAssertNil(released)
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { !commits.isEmpty }, timeout: 2.0))
        XCTAssertEqual(commits, [MessageWidgetInstance.StorageCommit(area: .local, entries: [.init(key: "k", value: "v")])])
    }

    /// A disabled button takes no click, as in browsers: a tap on it reaches no handler.
    func testDisabledButtonTakesNoClick() throws {
        let instance = self.make("<!doctype html><body style='margin:0'><button id=go disabled style='display:block;width:200px;height:40px' onclick=\"TelegramWidget.openLink('https://example.org/a'); this.disabled = true\">go</button></body>")
        _ = instance.layout(width: 360.0)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        self.tap(instance, "#go")
        self.pump(0.1)
        XCTAssertNil(instance.lastError)
        XCTAssertTrue(calls.isEmpty)
        _ = instance.evaluateForTesting("document.getElementById('go').disabled = false; 'ok'")
        self.tap(instance, "#go")
        self.tap(instance, "#go")
        self.tap(instance, "#go")
        self.pump(0.1)
        XCTAssertEqual(calls, [.openLink("https://example.org/a")])
        XCTAssertNil(instance.lastError)
    }

    /// SDK v1 §2.5: a URL past 256 characters is a TypeError in the widget, and the host never sees it.
    func testOpenLinkThrowsOnAnOverlongURL() throws {
        let instance = self.make("<button id=long style='display:block;height:40px'>long</button><button id=short style='display:block;height:40px'>short</button><script>document.getElementById('long').onclick = function () { TelegramWidget.openLink('https://example.com/' + 'a'.repeat(5000)) }; document.getElementById('short').onclick = function () { TelegramWidget.openLink('https://example.com/a') }</script>")
        _ = instance.layout(width: 360.0)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        self.tap(instance, "#long")
        self.tap(instance, "#short")
        self.pump(0.1)
        XCTAssertEqual(calls, [.openLink("https://example.com/a")])
        XCTAssertTrue(instance.diagnostics.contains { $0.kind == "uncaught-exception" && $0.detail.contains("TypeError") }, "\(instance.diagnostics)")
    }

    func testHangFreezesTheWidget() throws {
        let instance = self.make(self.fixture("10-sandbox-probe"))
        _ = instance.layout(width: 360.0)
        self.tap(instance, "#hang")
        XCTAssertNotNil(instance.deadReason)
        // widget-sandbox's words: the tap's event task ran past its slice (what the quota left it, at least 50 ms).
        XCTAssertTrue(instance.deadReason?.hasPrefix("CPU limit exceeded: more than ") ?? false, instance.deadReason ?? "nil")
        XCTAssertTrue(instance.deadReason?.contains("of continuous execution (event") ?? false, instance.deadReason ?? "nil")
        // The badge is drawn over the last frame now, not built into the document.
        XCTAssertEqual(instance.onCoreForTesting { $0.renderer?.frozenLabel } ?? nil, "Widget stopped")
    }

    func testBootErrorKeepsMinimumHeight() throws {
        let instance = self.make("<script>throw new Error('boom')</script>")
        XCTAssertEqual(instance.layout(width: 360.0).height, 50.0)
        XCTAssertTrue(instance.lastError?.contains("boom") ?? false, "\(instance.lastError ?? "nil")")
        XCTAssertNil(instance.deadReason)
    }

    /// A width change reflows without the widget's JS. (Telling the JS — innerWidth, a resize event — comes with the
    /// viewport in M2.)
    func testWidthChangeReflowsWithoutJS() throws {
        let instance = self.make(self.fixture("01-weather-card"))
        let wide = instance.layout(width: 360.0)
        let narrow = instance.layout(width: 200.0)
        XCTAssertGreaterThanOrEqual(narrow.height, wide.height)
    }

    /// Spec 2026-10-15 D1: every source runs in the sandbox — no doctype, static markup (once an HTML message).
    func testASourceWithoutADoctypeRunsInTheSandbox() throws {
        let instance = self.make("<div class=\"card\" style=\"padding:8px\">static card</div>")
        let size = instance.layout(width: 360.0)
        XCTAssertFalse(instance.failedToStart)
        XCTAssertGreaterThan(size.height, 0.0)
        XCTAssertEqual(instance.evaluateForTesting("document.querySelector('.card').textContent"), "static card")
        instance.destroy()
    }

    /// A message written for the removed HTML-message format (a `render()` script) boots in the sandbox without an
    /// error: nothing calls `render()`, and its static markup is what shows.
    func testARenderScriptBootsWithoutError() throws {
        let instance = self.make("<b>fallback</b><script>let n = 0; function render() { return '<b>' + n + '</b>'; }</script>")
        _ = instance.layout(width: 360.0)
        self.pump(0.1)
        XCTAssertNil(instance.deadReason)
        XCTAssertNil(instance.lastError)
        XCTAssertEqual(instance.evaluateForTesting("typeof render"), "function")
        XCTAssertTrue(self.renderedHTML(instance).contains("fallback"))
        instance.destroy()
    }

    /// A card with a fixed width keeps the whole offered width, as every sandbox widget does.
    func testANarrowCardKeepsTheWholeWidth() throws {
        let instance = self.make("<div style=\"width:200px;height:40px;background:#f00\">x</div>")
        XCTAssertEqual(instance.layout(width: 360.0).width, 360.0)
        instance.destroy()
    }

    /// Pages with an image URL in markup and set from script through the DOM. Profile 1 gives the renderer the 48 px
    /// placeholder in its place (V4 plan, Task 6), as it drops a remote CSS url() declaration
    /// (`attacks/css-background-url.html`, Task 3b), so neither reaches the container.
    static let urlPages = ["attacks/markup-img-src.html", "attacks/api-setattribute-src.html"]

    /// The boundary (spec §3): over every page of widget-sandbox's attack corpus (its URLs point at
    /// `http://127.0.0.1:9999/hit/…`), nothing is requested. A recording URLProtocol sees every request the process's
    /// URL loading system makes; WidgetRuntime has no loader of its own (`WidgetRuntimeNoIOScanTests`), and its container
    /// refuses every URL but `data:` that reaches it, counting each. Each page gets three animation frames, so the
    /// rAF-driven attacks run past boot, and is drawn, so the draw-time sites are reached too. The URL pages' URLs never
    /// reach the container: profile 1 renders the placeholder in their place. No task of any page holds its thread past
    /// two slices of CPU (the record's "Our DOM and renderer are native code").
    func testAttackCorpusRequestsNothing() throws {
        URLProtocol.registerClass(RecordingURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(RecordingURLProtocol.self)
        }
        RecordingURLProtocol.reset()
        let pages = WidgetCorpus.files(in: "attacks")
        XCTAssertEqual(pages.count, 113)
        var rafBurnFrames: String?
        var rafBurnReason: String?
        var layoutLoopReason: String?
        var largest: [(path: String, kind: WidgetSnapshot.Kind, cpu: Double)] = []
        let kinds: [WidgetSnapshot.Kind] = [.boot, .layout, .theme, .touch, .timer, .wake, .frame, .visibility, .event, .state, .draw, .selection]
        for page in pages {
            let (instance, view) = self.booted(page.source)
            for _ in 0 ..< 3 {
                self.deliverFrame(instance)
            }
            if page.path == "attacks/cpu-raf-burn.html" {
                rafBurnFrames = instance.evaluateForTesting("document.getElementById('frames').textContent")
                rafBurnReason = instance.deadReason
            }
            if page.path == "attacks/layout-query-loop.html" {
                layoutLoopReason = instance.deadReason
            }
            self.pump(0.2)
            view.update()
            let refused = self.networkRefusals(instance)
            XCTAssertGreaterThanOrEqual(refused, 0, "\(page.path) has no runtime")
            if InstanceTests.urlPages.contains(page.path) {
                XCTAssertEqual(refused, 0, "\(page.path): a planted URL reached the container")
            }
            if let top = kinds.map({ (kind: $0, cpu: instance.largestTaskCpuMillisecondsForTesting($0)) }).max(by: { $0.cpu < $1.cpu }) {
                largest.append((page.path, top.kind, top.cpu))
            }
            instance.destroy()
        }
        // No page runs a native path (our DOM, our renderer: nothing interrupts them) on and on: the CPU of each task's
        // runtime steps stays within two slices, the most a task may take by design (a runaway fails here, not a native
        // path a few hundred ms long); the largest are the pages the 500 ms slice stops (measured 2026-10-30: timer-flood's
        // boot 546 ms, fallback-at-boot's 500 ms, layout-query-loop's 107 ms, every other page under 60 ms).
        largest.sort { $0.cpu > $1.cpu }
        for row in largest.prefix(5) {
            print("attack scan: \(String(format: "%.1f", row.cpu)) ms, a \(row.kind) task of \(row.path)")
        }
        for row in largest where row.cpu >= 1000.0 {
            XCTFail("\(row.path): a \(row.kind) task held its thread for \(row.cpu) ms")
        }
        // A frame spinning 30 ms on performance.now() is well inside its slice (500 ms) and, three of them, the JS quota
        // (300 ms a second): it runs, as upstream's does, and would be throttled past the quota rather than stopped.
        XCTAssertEqual(rafBurnFrames, "3")
        XCTAssertNil(rafBurnReason)
        // A boot script forcing a layout per iteration (a style write, then offsetHeight) is stopped by the layout
        // queries' 100 ms per task, before its slice: upstream's words, naming the boot task and the script.
        XCTAssertEqual(layoutLoopReason, "Layout query limit exceeded: host queries blocked the renderer for more than 100 ms in one boot task (script)")
        XCTAssertEqual(RecordingURLProtocol.requests, [], "a widget's URL was requested")
    }
}
