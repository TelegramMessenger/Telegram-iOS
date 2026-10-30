import XCTest
@testable import MessageWidget

class RegistryTests: MessageWidgetTestCase {
    private func makeRegistry() -> MessageWidgetRegistry {
        let pool = self.pool!, turn = self.turn!
        return MessageWidgetRegistry(factory: { source, theme, label, max, locale, storage, context, state, _ in
            MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max, locale: locale, storage: storage, context: context, state: state, pool: pool, waitPolicy: .unbounded, turn: turn, scale: 1.0)
        })
    }

    /// SDK v1 §2.9: the registry's locale reaches the widgets it makes as navigator.language.
    func testTheLocaleReachesTheWidget() {
        let registry = self.makeRegistry()
        registry.locale = "pt-BR"
        let source = "<!doctype html><p>x</p>"
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        XCTAssertEqual(self.instance(in: registry, path: [], source: source)?.evaluateForTesting("navigator.language"), "pt-BR")
        registry.endPass()
        registry.destroyAll()
    }

    /// Review Focus 4 (V2b plan, Task 4): a new palette in the same scheme reaches the running widget, with no rebuild.
    func testAPaletteChangeInTheSameSchemeReachesTheWidget() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><p>x</p>"
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let first = self.instance(in: registry, path: [], source: source)
        var palette = MessageWidgetInstance.Theme.light
        palette.params = ["bg_color": "#102030"]
        palette.button.bg = "#112233"
        registry.beginPass(ownerId: 1, theme: palette)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let instance = self.instance(in: registry, path: [], source: source)
        XCTAssertTrue(first === instance)
        XCTAssertEqual(instance?.evaluateForTesting("TelegramWidget.colorScheme + ':' + TelegramWidget.themeParams.bg_color + ':' + getComputedStyle(document.documentElement).getPropertyValue('--tg-button-bg').trim()"), "light:#102030:#112233")
        registry.destroyAll()
    }

    /// The registry's storage preload is given to the widgets it makes from then on, not to a running one.
    func testTheStoragePreloadIsGivenToNewWidgetsOnly() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><p>x</p>"
        registry.storage = MessageWidgetStorage(local: [.init(key: "k", value: "1")], session: [])
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        registry.storage = MessageWidgetStorage(local: [.init(key: "k", value: "2")], session: [])
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        XCTAssertNotNil(registry.size(path: [1], source: source, width: 300.0))
        registry.endPass()
        XCTAssertEqual(self.instance(in: registry, path: [], source: source)?.evaluateForTesting("localStorage.getItem('k')"), "1")
        XCTAssertEqual(self.instance(in: registry, path: [1], source: source)?.evaluateForTesting("localStorage.getItem('k')"), "2")
        registry.destroyAll()
    }

    /// A widget's commits go to the registry's commit sink as it was when the widget was made (it carries that message's
    /// key), not to a later one: a node recycled for another message must not store this widget's areas under that one.
    func testAWidgetsCommitsGoToTheSinkOfItsCreation() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><p>x</p>"
        var first: [MessageWidgetInstance.StorageCommit] = []
        var later: [MessageWidgetInstance.StorageCommit] = []
        registry.onStorageCommit = { first.append($0) }
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        registry.onStorageCommit = { later.append($0) }
        _ = self.instance(in: registry, path: [], source: source)?.evaluateForTesting("setTimeout(() => localStorage.setItem('k', 'v'), 0); 'ok'")
        XCTAssertTrue(self.pump(until: { !first.isEmpty }, timeout: 5.0))
        XCTAssertTrue(later.isEmpty)
        registry.destroyAll()
    }

    /// widget-sandbox v0.2 (sdk-v1 §2.13): the bot's state is not part of a widget's key. A pass with a new state hands it
    /// to the running widget, which keeps its page.
    func testAStateChangeKeepsTheWidget() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><p>x</p>"
        registry.context = MessageWidgetContext(canQuery: true, chatType: .private)
        registry.state = MessageWidgetState(chatData: Data("c1".utf8), publicData: nil)
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let first = self.instance(in: registry, path: [], source: source)
        _ = first?.evaluateForTesting("window.mark = 7; 1")
        registry.state = MessageWidgetState(chatData: Data("c2".utf8), publicData: Data("p2".utf8))
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let instance = self.instance(in: registry, path: [], source: source)
        XCTAssertTrue(first === instance, "a state change restarted the widget")
        XCTAssertEqual(instance?.evaluateForTesting("[TelegramWidget.chatData, TelegramWidget.publicData, window.mark].join()"), "c2,p2,7")
        registry.destroyAll()
    }

    /// The message's context is fixed for a widget's life (sdk-v1 §2.14): a pass with another context (a forward's echo
    /// replaced by the server's message) makes a new widget.
    func testAContextChangeRestartsTheWidget() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><p>x</p>"
        registry.context = MessageWidgetContext(isCopy: true, chatType: .private)
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let first = self.instance(in: registry, path: [], source: source)
        XCTAssertEqual(first?.evaluateForTesting("String(TelegramWidget.isForward)"), "true")
        registry.context = MessageWidgetContext(isCopy: true, canQuery: true, chatType: .private)
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let instance = self.instance(in: registry, path: [], source: source)
        XCTAssertNotNil(instance)
        XCTAssertFalse(first === instance)
        XCTAssertEqual(registry.layoutVersions.count, 1)
        registry.destroyAll()
    }

    /// widget-sandbox v0.5.0: the wallet is part of the context, so the wallet set up (or removed) makes a new widget, which
    /// sees it.
    func testTheWalletIsPartOfTheContext() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><p>x</p>"
        registry.context = MessageWidgetContext(canQuery: true, chatType: .private)
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let first = self.instance(in: registry, path: [], source: source)
        XCTAssertEqual(first?.evaluateForTesting("String(TelegramWidget.wallet)"), "null")
        registry.context = MessageWidgetContext(canQuery: true, chatType: .private, wallet: true)
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        registry.endPass()
        let instance = self.instance(in: registry, path: [], source: source)
        XCTAssertFalse(first === instance)
        XCTAssertEqual(instance?.evaluateForTesting("typeof TelegramWidget.wallet.sendTransaction"), "function")
        registry.destroyAll()
    }

    private func instance(in registry: MessageWidgetRegistry, path: [Int], source: String) -> MessageWidgetInstance? {
        return (registry.view(path: path, source: source) as? MessageWidgetView)?.instance
    }

    /// A widget bubble in auto height uses the height the widget reported, and the placeholder until it has (widget-sandbox
    /// v0.1.0, integration.md "Bubble sizing"): the registry tells the two apart.
    func testTheReportedHeightIsNilUntilTheWidgetRenders() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><div style=\"height:120px\"></div>"
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.reportedHeight(path: [], source: source))
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        // The box and the host's 8 px body margins.
        XCTAssertEqual(registry.reportedHeight(path: [], source: source), 136.0)
        XCTAssertNil(registry.reportedHeight(path: [], source: source + " "))
        registry.endPass()
        registry.destroyAll()
    }

    /// A bubble's fixed height is its widget's maximum (the V1 final review's I2), handed over when the registry creates
    /// the widget and again when an edit changes only the anchors: the same HTML keeps its runtime, so a maximum read only
    /// at creation stayed stale and cut the widget or left a blank strip (the fix-wave review's N2).
    func testTheMaximumHeightFollowsTheBubblesFixedHeight() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><style>body{margin:0}</style><div style=\"height:400px\"></div>"
        registry.beginPass(ownerId: 1, theme: .light)
        registry.maximumHeight = 120.0
        XCTAssertEqual(registry.size(path: [], source: source, width: 300.0)?.height, 120.0)
        registry.endPass()
        let first = self.instance(in: registry, path: [], source: source)
        XCTAssertNotNil(first)
        // An edit to a fixed 300: the same widget, at most 300 now.
        registry.beginPass(ownerId: 1, theme: .light)
        registry.maximumHeight = 300.0
        XCTAssertEqual(registry.size(path: [], source: source, width: 300.0)?.height, 300.0)
        registry.endPass()
        XCTAssertTrue(self.instance(in: registry, path: [], source: source) === first, "the edit restarted the widget")
        // To auto height: its own 400.
        registry.beginPass(ownerId: 1, theme: .light)
        registry.maximumHeight = 600.0
        XCTAssertEqual(registry.size(path: [], source: source, width: 300.0)?.height, 400.0)
        registry.endPass()
        registry.destroyAll()
    }

    func testFailedToStartWidgetIsNotRecreatedEveryPass() throws {
        self.failUnstartableSources()
        let pool = self.pool!, turn = self.turn!
        var calls = 0
        let registry = MessageWidgetRegistry(factory: { source, theme, label, max, _, _, _, _, _ in
            calls += 1
            return MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max, pool: pool, waitPolicy: .unbounded, turn: turn, scale: 1.0)
        })
        for _ in 0 ..< 3 {
            registry.beginPass(ownerId: 1, theme: .light)
            XCTAssertNil(registry.size(path: [0], source: self.unstartableSource("<!doctype html><p>one</p>"), width: 360.0))
            registry.endPass()
        }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(registry.layoutVersions.isEmpty)
        // An edited source is a new key and gets its own attempt.
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: self.unstartableSource("<!doctype html><p>two</p>"), width: 360.0))
        registry.endPass()
        XCTAssertEqual(calls, 2)
        // A failure is forgotten once a pass does not use its key.
        registry.beginPass(ownerId: 1, theme: .light)
        registry.endPass()
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: self.unstartableSource("<!doctype html><p>two</p>"), width: 360.0))
        registry.endPass()
        XCTAssertEqual(calls, 3)
    }

    /// A bubble's next update reads its widget as the registry has it: the report and the edge once it has run (the
    /// edge from its script), and a start that failed, which the next layout turns into the pill.
    func testTheRunStateFollowsTheWidget() {
        let registry = self.makeRegistry()
        let source = "<!doctype html><script>TelegramWidget.setResizeAnchor('bottom')</script><div style=\"height:120px\"></div>"
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.runState(path: [], source: source))
        XCTAssertNotNil(registry.size(path: [], source: source, width: 300.0))
        XCTAssertEqual(registry.runState(path: [], source: source), MessageWidgetRunState(reportedHeight: 136.0, resizeAnchor: .bottom, failedToStart: false))
        registry.endPass()
        registry.destroyAll()
    }

    func testAFailedStartIsInTheRunState() {
        self.failUnstartableSources()
        let registry = self.makeRegistry()
        let source = self.unstartableSource("<!doctype html><p>one</p>")
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: source, width: 360.0))
        XCTAssertEqual(registry.runState(path: [0], source: source), MessageWidgetRunState(reportedHeight: nil, resizeAnchor: .top, failedToStart: true))
        registry.endPass()
    }

    func testNilFromTheFactoryIsNotRetriedEveryPass() {
        var calls = 0
        let registry = MessageWidgetRegistry(factory: { _, _, _, _, _, _, _, _, _ in
            calls += 1
            return nil
        })
        for _ in 0 ..< 3 {
            registry.beginPass(ownerId: 1, theme: .light)
            XCTAssertNil(registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0))
            registry.endPass()
        }
        XCTAssertEqual(calls, 1)
        registry.destroyAll()
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0))
        XCTAssertEqual(calls, 2)
    }

    func testThemeReachesExistingInstances() throws {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        registry.endPass()
        XCTAssertEqual(self.instance(in: registry, path: [0], source: "<!doctype html><p>one</p>")?.theme, .light)
        registry.beginPass(ownerId: 1, theme: .dark)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        registry.endPass()
        XCTAssertEqual(self.instance(in: registry, path: [0], source: "<!doctype html><p>one</p>")?.theme, .dark)
    }

    func testVisibilityReachesExistingAndNewInstances() throws {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        registry.endPass()
        XCTAssertEqual(self.instance(in: registry, path: [0], source: "<!doctype html><p>one</p>")?.visible, true)
        registry.setVisible(false)
        XCTAssertEqual(self.instance(in: registry, path: [0], source: "<!doctype html><p>one</p>")?.visible, false)
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        _ = registry.size(path: [1], source: "<!doctype html><p>new</p>", width: 360.0)
        registry.endPass()
        XCTAssertEqual(self.instance(in: registry, path: [1], source: "<!doctype html><p>new</p>")?.visible, false)
        registry.setVisible(true)
        XCTAssertEqual(self.instance(in: registry, path: [0], source: "<!doctype html><p>one</p>")?.visible, true)
        XCTAssertEqual(self.instance(in: registry, path: [1], source: "<!doctype html><p>new</p>")?.visible, true)
    }

    /// A bubble runs at most four widgets, in layout order; the blocks past them draw as code, and one of them
    /// becomes a widget once an earlier block goes.
    func testWidgetsPerBubbleAreCapped() throws {
        XCTAssertEqual(MessageWidgetRegistry.maximumWidgets, 4)
        let registry = self.makeRegistry()
        let sources = (0 ..< 6).map { "<!doctype html><p>widget \($0)</p>" }
        registry.beginPass(ownerId: 1, theme: .light)
        let sizes = sources.enumerated().map { registry.size(path: [$0.offset], source: $0.element, width: 360.0) }
        // A layout that asks for a block twice in one pass gets the same answer: the fourth stays a widget.
        XCTAssertNotNil(registry.size(path: [3], source: sources[3], width: 360.0))
        XCTAssertNil(registry.size(path: [4], source: sources[4], width: 360.0))
        registry.endPass()
        XCTAssertEqual(sizes.map { $0 != nil }, [true, true, true, true, false, false])
        XCTAssertEqual(registry.layoutVersions.count, 4)
        XCTAssertNil(registry.view(path: [4], source: sources[4]))
        registry.beginPass(ownerId: 1, theme: .light)
        let later = (1 ..< 6).map { registry.size(path: [$0], source: sources[$0], width: 360.0) }
        registry.endPass()
        XCTAssertEqual(later.map { $0 != nil }, [true, true, true, true, false])
        XCTAssertNotNil(registry.view(path: [4], source: sources[4]))
        XCTAssertNil(registry.view(path: [0], source: sources[0]))
    }

    func testEmptySourceGetsNoWidget() {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: "   \n", width: 360.0))
        registry.endPass()
        XCTAssertTrue(registry.layoutVersions.isEmpty)
    }

    func testTwoPathsGetTwoInstances() throws {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [0], source: self.fixture("02-split-bill"), width: 360.0))
        XCTAssertNotNil(registry.size(path: [2], source: self.fixture("02-split-bill"), width: 360.0))
        registry.endPass()
        XCTAssertEqual(registry.layoutVersions.count, 2)
        let a = registry.view(path: [0], source: self.fixture("02-split-bill"))
        let b = registry.view(path: [2], source: self.fixture("02-split-bill"))
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertFalse(a === b)
    }

    func testEditedSourceReplacesTheInstanceAtEndOfPass() throws {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        registry.endPass()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>two</p>", width: 360.0)
        registry.endPass()
        XCTAssertEqual(registry.layoutVersions.keys.map(\.source), ["<!doctype html><p>two</p>"])
    }

    func testNewOwnerDestroysEverything() throws {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        registry.endPass()
        registry.beginPass(ownerId: 2, theme: .light)
        registry.endPass()
        XCTAssertTrue(registry.layoutVersions.isEmpty)
        XCTAssertFalse(registry.isLive(path: [0]))
    }

    func testDestroyAllDropsViews() throws {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<!doctype html><p>one</p>", width: 360.0)
        registry.endPass()
        registry.destroyAll()
        XCTAssertNil(registry.view(path: [0], source: "<!doctype html><p>one</p>"))
    }

    func testLayoutChangeIsForwarded() throws {
        let registry = self.makeRegistry()
        let changed = self.expectation(description: "forwarded")
        registry.onLayoutChange = { changed.fulfill() }
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: self.fixture("03-faq-accordion"), width: 360.0)
        registry.endPass()
        guard let view = registry.view(path: [0], source: self.fixture("03-faq-accordion")) as? MessageWidgetView,
              let instance = view.instance,
              let rect = self.borderBox(instance, ".q") else {
            return XCTFail("no widget")
        }
        let p = CGPoint(x: rect.minX + 10.0, y: rect.minY + 10.0)
        view.handleTouch(phase: .began, at: p)
        view.handleTouch(phase: .ended, at: p)
        self.wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(registry.layoutVersions.values.first, 1)
    }
}
