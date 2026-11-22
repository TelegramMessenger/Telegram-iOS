import UIKit
import XCTest
@testable import MessageWidget

/// Every MessageWidget test runs its widgets on a pool of its own (two threads, stopped in `tearDown`) and a turn of its
/// own. `make` uses `.unbounded` (spec D9): every wait ends with its task, as when everything ran on main. Tests of the
/// background path pass their own policy.
class MessageWidgetTestCase: XCTestCase {
    private(set) var pool: MessageWidgetPool!
    private(set) var turn: MessageWidgetTurn!
    /// `onWorker`'s queue: its bodies run in order, on the pool.
    private var workerQueue: WidgetTaskQueue!

    override func setUp() {
        super.setUp()
        self.pool = MessageWidgetPool(threadCount: 2)
        self.turn = MessageWidgetTurn()
        self.workerQueue = self.pool.makeQueue()
    }

    override func tearDown() {
        self.workerQueue = nil
        self.pool.stop()
        self.pool = nil
        self.turn = nil
        super.tearDown()
    }

    func fixture(_ name: String, ext: String = "html") -> String {
        let bundle = Bundle(for: MessageWidgetTestCase.self)
        guard let url = bundle.url(forResource: name, withExtension: ext), let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("missing fixture \(name).\(ext)")
            return ""
        }
        return text
    }

    /// Lets main-run-loop timers and deferred main-queue work run.
    func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Bytes allocated through malloc and still live, over every zone. Unlike the physical footprint it does not
    /// depend on what earlier tests freed (malloc keeps those pages, so a later allocation does not grow it).
    func allocatedBytes() -> Int {
        var statistics = malloc_statistics_t()
        malloc_zone_statistics(nil, &statistics)
        return Int(statistics.size_in_use)
    }

    // MARK: instances and views

    /// Runs `body` on the pool and waits for it: a core, an engine and a validator are touched only there.
    func onWorker<T>(_ body: @escaping () -> T) -> T {
        var result: T?
        let done = DispatchSemaphore(value: 0)
        self.workerQueue.enqueue {
            result = body()
            done.signal()
        }
        done.wait()
        return result!
    }

    func make(_ source: String, theme: MessageWidgetInstance.Theme = .light, scale: CGFloat = 1.0, policy: MessageWidgetWaitPolicy = .unbounded, storage: MessageWidgetStorage = .empty, context: MessageWidgetContext = MessageWidgetContext(), state: MessageWidgetState = .empty, cpuLimits: MessageWidgetCpuLimits = .product) -> MessageWidgetInstance {
        guard let instance = MessageWidgetInstance(source: source, theme: theme, stoppedLabel: "Widget stopped", maxMessageLength: 4096, storage: storage, context: context, state: state, pool: self.pool, waitPolicy: policy, turn: self.turn, scale: scale, cpuLimits: cpuLimits) else {
            XCTFail("instance not created")
            fatalError()
        }
        return instance
    }

    /// Runs main's run loop until `condition` holds, for at most `timeout` seconds; whether it held.
    @discardableResult
    func pump(until condition: () -> Bool, timeout: TimeInterval = 10.0) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            if Date() >= deadline {
                return false
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
        return true
    }

    /// The display link's tick (`deliverFrameForTesting`) and, when it queued a frame task, main's run loop until that
    /// task's snapshot is applied: a demoted widget's frames are not waited for (spec D6), and a tick while one is in
    /// flight queues nothing, so ticks in a row would otherwise skip frames.
    func deliverFrame(_ instance: MessageWidgetInstance) {
        func queued() -> Int {
            let frames = instance.queuedForTesting[.frame]
            return (frames?.waited ?? 0) + (frames?.unwaited ?? 0)
        }
        let before = queued()
        instance.deliverFrameForTesting()
        if queued() > before {
            XCTAssertTrue(self.pump(until: { (instance.appliedForTesting[.frame] ?? 0) >= queued() }))
        }
    }

    /// Lays `instance` out at `width` and, when its boot misses the wait, runs main's run loop until the boot's
    /// snapshot is applied; the real size.
    func bootFully(_ instance: MessageWidgetInstance, width: CGFloat) -> CGSize {
        _ = instance.layout(width: width)
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.boot] != nil }))
        // What the boot's snapshot queued on the main queue (its `onLayoutChange`) runs now, not inside the caller's
        // next step, where it would read as that step's.
        self.pump(0.02)
        return instance.layout(width: width)
    }

    /// The widget's document as HTML serializes it ("" once its runtime is gone).
    func renderedHTML(_ instance: MessageWidgetInstance) -> String {
        return instance.evaluateForTesting("'<!doctype html>' + document.documentElement.outerHTML") ?? ""
    }

    /// The loads the widget's renderer refused (nothing is fetched); -1 when it never had a runtime.
    func networkRefusals(_ instance: MessageWidgetInstance) -> Int {
        return instance.onCoreForTesting { $0.refusedLoads } ?? -1
    }

    /// The border box (document coordinates) of the first element `selector` matches, from the widget's render tree,
    /// until M2 gives the widget getBoundingClientRect.
    func borderBox(_ instance: MessageWidgetInstance, _ selector: String) -> CGRect? {
        return instance.onCoreForTesting { $0.borderBox(selector) } ?? nil
    }

    /// Frozen with the stopped badge over its last frame (the badge is drawn, no longer built into the document).
    func isFrozenWithBadge(_ instance: MessageWidgetInstance) -> Bool {
        self.settle(instance)
        return instance.deadReason != nil && (instance.onCoreForTesting { $0.renderer?.frozenLabel } ?? nil) == "Widget stopped" && !instance.currentFrame.tiles.isEmpty
    }

    /// A source no widget can start from once `failUnstartableSources()` has run.
    func unstartableSource(_ markup: String) -> String {
        return markup + MessageWidgetTestCase.unstartableMark
    }

    private static let unstartableMark = "<!--unstartable-->"

    /// Until the test ends, a widget whose source `unstartableSource` made fails to start (`.failedToStart`, the pill).
    func failUnstartableSources() {
        MessageWidgetCore.startFailureForTesting = { $0.hasSuffix(MessageWidgetTestCase.unstartableMark) }
        self.addTeardownBlock {
            MessageWidgetCore.startFailureForTesting = nil
        }
    }

    /// Until the test ends, every session's "CPU" clock is the wall clock (CACurrentMediaTime): a script spinning on
    /// `performance.now()` for N ms spends N ms of it, whatever else the machine is doing.
    func useWallTimeAsCpu() {
        let now: () -> Double = { CACurrentMediaTime() * 1000.0 }
        MessageWidgetCore.cpuClockForTesting = (cpu: now, wall: now)
        self.addTeardownBlock {
            MessageWidgetCore.cpuClockForTesting = nil
        }
    }

    /// A script statement spinning `ms` milliseconds on `performance.now()`.
    static func spin(_ ms: Int) -> String {
        return "{ const t0 = performance.now(); while (performance.now() - t0 < \(ms)) {} }"
    }

    /// The renderer's own image of `rect` (document coordinates), drawn where the widget's work runs.
    func rendererImage(_ instance: MessageWidgetInstance, rect: CGRect, scale: CGFloat) -> CGImage? {
        return instance.onCoreForTesting { $0.renderer?.image(rect: rect, scale: scale) } ?? nil
    }

    /// Runs main's run loop until the tile draws the widget's snapshots asked for have landed (drawing is a task of its
    /// own, never waited for: MessageWidgetInstance.requestDraw).
    func settle(_ instance: MessageWidgetInstance) {
        XCTAssertTrue(self.pump(until: { !instance.isDrawPendingForTesting }), "a tile draw did not land")
    }

    /// Renders over `backdrop` (opaque white by default), so premultiplied alpha cannot hide colours.
    /// 8 bits per channel (`.standard`), which `pixel` assumes, at `scale` pixels per point. A widget's view is settled
    /// first (its pending tile draws land).
    func render(_ view: UIView, backdrop: UIColor = .white, scale: CGFloat = 1.0) -> UIImage {
        if let instance = (view as? MessageWidgetView)?.instance {
            self.settle(instance)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        return renderer.image { ctx in
            backdrop.setFill()
            ctx.fill(view.bounds)
            view.layer.render(in: ctx.cgContext)
        }
    }

    /// Reads a pixel honouring the image's byte order and alpha position.
    func pixel(_ image: UIImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        let scale = Int(image.scale)
        return self.devicePixel(image, x * scale, y * scale)
    }

    /// `pixel` at device pixel (`px`, `py`) rather than at a point.
    func devicePixel(_ image: UIImage, _ px: Int, _ py: Int) -> (r: Int, g: Int, b: Int) {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            return (0, 0, 0)
        }
        // Outside the image: no colour a test expects, rather than a read past the buffer.
        guard px >= 0, py >= 0, px < cg.width, py < cg.height else {
            return (-1, -1, -1)
        }
        let offset = py * cg.bytesPerRow + px * 4
        let info = cg.bitmapInfo
        let alpha = CGImageAlphaInfo(rawValue: info.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
        let alphaFirst = alpha == .premultipliedFirst || alpha == .first || alpha == .noneSkipFirst
        let little = info.contains(.byteOrder32Little)
        let order: (r: Int, g: Int, b: Int)
        switch (little, alphaFirst) {
        case (true, true): order = (2, 1, 0)    // BGRA
        case (true, false): order = (3, 2, 1)   // ABGR
        case (false, true): order = (1, 2, 3)   // ARGB
        case (false, false): order = (0, 1, 2)  // RGBA
        }
        return (Int(bytes[offset + order.r]), Int(bytes[offset + order.g]), Int(bytes[offset + order.b]))
    }

    /// Boots `source` at `width` and gives it a view of the laid-out size. `scale` is the scale the widget's tiles are
    /// drawn at (the hostless test process is 1x, and drawing differs at 2x/3x); render at the same scale.
    func booted(_ source: String, scale: CGFloat = 1.0, width: CGFloat = 360.0) -> (MessageWidgetInstance, MessageWidgetView) {
        let instance = self.make(source, scale: scale)
        let size = instance.layout(width: width)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        self.settle(instance)
        return (instance, view)
    }
}

/// Records every request the process's URL loading system is asked for (register it with URLProtocol.registerClass),
/// and handles none: a widget's URL must never get here.
final class RecordingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [String] = []

    static var requests: [String] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return recorded
    }

    static func reset() {
        lock.lock()
        recorded.removeAll()
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.lock()
        recorded.append(request.url?.absoluteString ?? "?")
        lock.unlock()
        return false
    }
}

