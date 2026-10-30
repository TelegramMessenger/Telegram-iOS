import Foundation
import UIKit
import MessageWidget

/// widget-sandbox v0.3.0's stress kit runner (packages/stress CLIENTS.md, "The runner, step by step"), around this
/// client's own renderer: for every widget of the manifest, in order, a widget instance in a stand-in bubble (its
/// `MessageWidgetView` at the kit's width, in `host`, which must be in a window: a widget is visible only there), the
/// boot, the warm-up, a measuring window of its frames, the host's stats and the renderer's own time, then the next one
/// after a pause (a longer one after a load's last level, so the device cools). The run file is `run.schema.json`'s.
///
/// The passes: `measure`, the caps from before v0.3.0 and no stops (`MessageWidgetLimitPolicy.compat`; the task slice
/// stays, as the kit keeps the reference's, and the quotas are out of the way), and `production`, the app's own
/// configuration (strict).
public final class MessageWidgetStressRunner {
    public enum Pass: String {
        case measure
        case production
    }

    public struct Options {
        public var pass: Pass
        /// The kit's own unless set (2 s and 10 s); a smoke run takes shorter ones.
        public var warmupMs: Double?
        public var measureMs: Double?
        /// Between two widgets, and after a load's last level (CLIENTS.md: 1 s and 20 s).
        public var pauseMs: Double = 1000.0
        public var cooldownMs: Double = 20000.0
        public var bootTimeoutMs: Double = 60000.0
        /// Only the entries this takes (all without one).
        public var include: ((MessageWidgetStressKit.Entry) -> Bool)?
        /// The run file's `device.class`: `iphone` on a phone, `other` on the simulator.
        public var deviceClass: String

        public init(pass: Pass) {
            self.pass = pass
            #if targetEnvironment(simulator)
            self.deviceClass = "other"
            #else
            self.deviceClass = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
            #endif
        }
    }

    private let kit: MessageWidgetStressKit
    private weak var host: UIView?
    private let options: Options
    private let entries: [MessageWidgetStressKit.Entry]
    private var runs: [[String: Any]] = []
    private var index = 0
    private var cancelled = false
    private var completion: ((Data) -> Void)?
    /// The widget being measured, held until its run ends.
    private var current: Measurement?
    private let started = Date()
    /// Told each widget's id as it starts, and its result line as it ends.
    public var onProgress: ((String) -> Void)?

    public init(kit: MessageWidgetStressKit, host: UIView, options: Options) {
        self.kit = kit
        self.host = host
        self.options = options
        self.entries = kit.entries.filter { options.include?($0) ?? true }
    }

    /// Runs every entry on the main run loop, never blocking it, then hands over the run file.
    public func start(completion: @escaping (Data) -> Void) {
        self.completion = completion
        self.next()
    }

    public func cancel() {
        self.cancelled = true
    }

    private func next() {
        guard !self.cancelled, self.index < self.entries.count else {
            self.finish()
            return
        }
        let entry = self.entries[self.index]
        self.index += 1
        self.onProgress?(entry.id)
        let measurement = Measurement(runner: self, entry: entry)
        self.current = measurement
        measurement.begin { [weak self] run in
            guard let self else {
                return
            }
            self.current = nil
            self.runs.append(run)
            self.onProgress?(MessageWidgetStressRunner.line(run))
            let lastOfItsLoad = self.index >= self.entries.count || self.entries[self.index].load != entry.load
            let pause = lastOfItsLoad ? self.options.cooldownMs : self.options.pauseMs
            DispatchQueue.main.asyncAfter(deadline: .now() + pause / 1000.0) { [weak self] in
                self?.next()
            }
        }
    }

    private static func line(_ run: [String: Any]) -> String {
        let id = (run["id"] as? String) ?? "?"
        let widget = run["widget"] as? [String: Any]
        let frames = run["frames"] as? [String: Any]
        let fps = (widget?["fps"] as? Double).map { String(format: "%.0f", $0) } ?? "–"
        let p95 = (frames?["p95"] as? Double).map { String(format: "%.1f", $0) } ?? "–"
        let dead = (run["dead"] as? String).map { " dead: \($0)" } ?? ""
        return "\(id): fps \(fps), frame p95 \(p95) ms\(dead)"
    }

    private func finish() {
        let file = self.runFile()
        let data = (try? JSONSerialization.data(withJSONObject: file, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        self.completion?(data)
        self.completion = nil
    }

    // MARK: the run file

    private var widgetWidth: CGFloat {
        return CGFloat(self.kit.width)
    }

    private var policy: MessageWidgetLimitPolicy {
        return self.options.pass == .measure ? .compat : .strict
    }

    /// CLIENTS.md's measure pass takes the quotas out of the way (10,000 ms per 1000 ms window, so every task keeps its
    /// whole slice and none is deferred); production runs the product's.
    fileprivate var cpuLimits: MessageWidgetCpuLimits {
        if self.options.pass == .measure {
            return MessageWidgetCpuLimits(cpuLimitMs: MessageWidgetCpuLimits.product.cpuLimitMs, cpuQuotaMs: 10000.0, cpuQuotaWindowMs: 1000.0, cpuKillAfterMs: 0.0, mainThreadQuotaMs: 10000.0)
        }
        return .product
    }

    private func runFile() -> [String: Any] {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info?["CFBundleVersion"] as? String) ?? "?"
        #if DEBUG
        let configuration = "debug (WidgetRuntime, QuickJS and litehtml at -O2)"
        #else
        let configuration = "release"
        #endif
        let screen = UIScreen.main
        let strict = self.policy == .strict
        let requested: [String: Any] = [
            "policy": strict ? "strict" : "compat",
            "cpuQuotaMs": strict ? 300 : 10000,
            "cpuQuotaWindowMs": 1000,
            "mainThreadQuotaMs": strict ? 100 : 10000,
            "maxTimers": strict ? 64 : 256,
            "memoryLimitBytes": strict ? 8 << 20 : 64 << 20,
            "width": self.kit.width,
            "theme": "light",
            "warmupMs": self.options.warmupMs ?? self.kit.warmupMs,
            "measureMs": self.options.measureMs ?? self.kit.measureMs,
        ]
        // What this host applies: its counted caps (WidgetRuntime's Limits) and widget-sandbox's runtime limits on the
        // widget thread's CPU clock (MessageWidgetCpuLimits), as requested.
        let cpu = self.cpuLimits
        let applied: [String: Any] = [
            "policy": strict ? "strict" : "compat",
            "cpuLimitMs": cpu.cpuLimitMs,
            "cpuQuotaMs": cpu.cpuQuotaMs,
            "cpuQuotaWindowMs": cpu.cpuQuotaWindowMs,
            "cpuKillAfterMs": cpu.cpuKillAfterMs,
            "mainThreadQuotaMs": cpu.mainThreadQuotaMs,
            "maxTimers": strict ? 64 : 256,
            "memoryLimitBytes": strict ? 8 << 20 : 64 << 20,
            "width": Double(self.widgetWidth),
        ]
        let formatter = ISO8601DateFormatter()
        return [
            "kit": ["version": self.kit.version, "commit": "v0.5.0"],
            "platform": "ios",
            "client": "Telegram for iOS",
            "clientBuild": "\(version) (\(build)), \(configuration)",
            "framework": "v0.5.0",
            "renderer": "telegram-native",
            "rendererKind": "own",
            "engine": "WidgetRuntime: a C++ DOM on QuickJS (quickjs-ng fork), laid out by twidget's litehtml fork, drawn by CoreGraphics",
            "device": [
                "model": MessageWidgetStressRunner.model(),
                "os": "iOS \(UIDevice.current.systemVersion)",
                "class": self.options.deviceClass,
                "refreshHz": Double(screen.maximumFramesPerSecond),
                "dpr": Double(screen.scale),
                "ramMb": Double(ProcessInfo.processInfo.physicalMemory / (1024 * 1024)),
                "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            ],
            "pass": self.options.pass.rawValue,
            "config": ["requested": requested, "applied": applied],
            "date": formatter.string(from: self.started),
            "runs": self.runs,
        ]
    }

    /// The display link's rate: the screen's maximum, which CLIENTS.md measures frames against (a link left at its
    /// default runs at 60 Hz on a ProMotion iPhone). The app's Info.plist must also carry
    /// `CADisableMinimumFrameDurationOnPhone`, as Telegram's and the widget harness's do.
    public static func frameRateRange(screen: UIScreen) -> CAFrameRateRange {
        let rate = Float(screen.maximumFramesPerSecond)
        return CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
    }

    private static func model() -> String {
        #if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "simulator (\(simulated))"
        }
        #endif
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
    }

    static func thermal() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }

    // MARK: one widget

    /// One widget's run: CLIENTS.md steps 1–7.
    private final class Measurement {
        private let runner: MessageWidgetStressRunner
        private let entry: MessageWidgetStressKit.Entry
        private var instance: MessageWidgetInstance?
        private var created: CFTimeInterval = 0
        private var bootMs: Double?
        private var diedAtMs: Double?
        private var completion: (([String: Any]) -> Void)?
        private let frames = MessageWidgetStressFrames()
        private var startStats: MessageWidgetStressStats?
        private var startWidget: [String: Any]?
        private var windowStart: CFTimeInterval = 0
        private var maxGap: Double?
        private var errors: [String] = []

        init(runner: MessageWidgetStressRunner, entry: MessageWidgetStressKit.Entry) {
            self.runner = runner
            self.entry = entry
        }

        func begin(completion: @escaping ([String: Any]) -> Void) {
            self.completion = completion
            // Step 1: the host with the pass's configuration, the widget's HTML loaded.
            self.created = CACurrentMediaTime()
            guard let source = try? self.runner.kit.source(of: self.entry) else {
                self.errors.append("the widget's file could not be read: \(self.entry.file)")
                self.end(loaded: false)
                return
            }
            guard let instance = MessageWidgetInstance(source: source, theme: .light, stoppedLabel: "Widget stopped", maxMessageLength: 4096, limits: self.runner.policy, cpuLimits: self.runner.cpuLimits) else {
                self.errors.append("the widget runtime could not be created")
                self.end(loaded: false)
                return
            }
            self.instance = instance
            self.runner.host?.addSubview(instance.view)
            self.layout()
            self.waitForLoad()
        }

        private var elapsedMs: Double {
            return (CACurrentMediaTime() - self.created) * 1000.0
        }

        private func layout() {
            guard let instance = self.instance else {
                return
            }
            let size = instance.layout(width: self.runner.widgetWidth)
            instance.view.frame = CGRect(origin: .zero, size: size)
        }

        private func stress() -> [String: Any]? {
            guard let value = self.instance?.documentElementAttribute("data-stress"), let data = value.data(using: .utf8) else {
                return nil
            }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }

        private func noteDeath() {
            if self.diedAtMs == nil, self.instance?.deadReason != nil {
                self.diedAtMs = self.elapsedMs
            }
        }

        /// Step 2: the widget's scripts ran (its `data-stress` is published at once), at most 60 s.
        private func waitForLoad() {
            guard let instance = self.instance else {
                return
            }
            self.layout()
            self.noteDeath()
            if instance.failedToStart || (instance.deadReason != nil && self.stress() == nil) {
                self.end(loaded: !instance.failedToStart)
                return
            }
            if self.stress() != nil {
                self.bootMs = self.elapsedMs
                // Step 3: the warm-up.
                self.after(self.runner.options.warmupMs ?? self.runner.kit.warmupMs) { [weak self] in
                    self?.beginWindow()
                }
                return
            }
            if self.elapsedMs > self.runner.options.bootTimeoutMs {
                self.errors.append("not loaded in \(Int(self.runner.options.bootTimeoutMs)) ms")
                self.end(loaded: false)
                return
            }
            self.after(50.0) { [weak self] in
                self?.waitForLoad()
            }
        }

        /// Step 4: the window starts; step 5: every 500 ms, the largest maxGap and whether it died.
        private func beginWindow() {
            self.layout()
            self.startStats = self.instance?.stressStats()
            self.startWidget = self.stress()
            self.windowStart = CACurrentMediaTime()
            self.frames.start()
            self.sample()
        }

        private func sample() {
            self.layout()
            self.noteDeath()
            if let gap = (self.stress()?["maxGap"] as? NSNumber)?.doubleValue {
                self.maxGap = max(self.maxGap ?? 0.0, gap)
            }
            let measureMs = self.runner.options.measureMs ?? self.runner.kit.measureMs
            let left = measureMs - (CACurrentMediaTime() - self.windowStart) * 1000.0
            if left <= 0.0 {
                self.end(loaded: true)
                return
            }
            self.after(min(500.0, left)) { [weak self] in
                self?.sample()
            }
        }

        private func after(_ ms: Double, _ body: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + ms / 1000.0, execute: body)
        }

        /// Step 6: the window ends, its entry written; step 7: the widget destroyed.
        private func end(loaded: Bool) {
            self.frames.stop()
            let seconds = max((CACurrentMediaTime() - self.windowStart) * 1000.0, 1.0) / 1000.0
            let endStats = self.instance?.stressStats()
            let endWidget = self.stress()
            var run: [String: Any] = [
                "id": self.entry.id,
                "load": self.entry.load,
                "value": self.entry.value,
                "loaded": loaded,
                "bootMs": self.bootMs.map { round2($0) as Any } ?? NSNull(),
                "dead": self.instance?.deadReason as Any? ?? NSNull(),
                "diedAtMs": self.diedAtMs.map { round2($0) as Any } ?? NSNull(),
                "frames": self.frames.summary(refreshHz: Double(UIScreen.main.maximumFramesPerSecond)),
                "thermal": MessageWidgetStressRunner.thermal(),
            ]
            if let first = self.startStats, let last = endStats {
                let frameTasks = max(last.frameTasks - first.frameTasks, 1)
                let renderMs = (last.flushMilliseconds - first.flushMilliseconds) + (last.drawMilliseconds - first.drawMilliseconds)
                // The renderer's own work: its flushes (style, layout, the layer tree) and its tile draws (the CPU
                // raster), per frame task; no per-frame distribution is kept, and no display list is counted.
                run["renderer"] = [
                    "msPerFrame": round2(renderMs / Double(frameTasks)),
                    "p95Ms": NSNull(),
                    "displayListOps": NSNull(),
                ]
                run["host"] = [
                    // The widget's JS on its thread's CPU clock, what the JS quota records (stats.jsMs).
                    "jsMsPerSec": round2((last.jsMilliseconds - first.jsMilliseconds) / seconds),
                    "opsPerSec": round2(Double(last.totalOps - first.totalOps) / seconds),
                    "queriesPerSec": round2(Double(last.layoutQueries - first.layoutQueries) / seconds),
                    "queryMsPerSec": round2((last.queryMilliseconds - first.queryMilliseconds) / seconds),
                    "nodes": last.nodes,
                    "memoryBytes": last.heapBytes,
                    // The steps either CPU window deferred during the window (none in the measure pass).
                    "throttledTasks": Int(clamping: last.throttledSteps &- first.throttledSteps),
                    "maxBatchOps": last.maxBatchOps,
                ] as [String: Any]
            } else {
                run["renderer"] = NSNull()
                run["host"] = ["jsMsPerSec": NSNull(), "opsPerSec": NSNull(), "queriesPerSec": NSNull(), "queryMsPerSec": NSNull(), "nodes": NSNull(), "memoryBytes": NSNull(), "throttledTasks": NSNull(), "maxBatchOps": NSNull()] as [String: Any]
            }
            var widget: [String: Any] = ["fps": NSNull(), "frames": NSNull(), "maxGap": self.maxGap.map { $0 as Any } ?? NSNull(), "jank": NSNull(), "last": endWidget ?? NSNull()]
            if let first = self.startWidget, let last = endWidget {
                let number = { (value: [String: Any], key: String) -> Double? in (value[key] as? NSNumber)?.doubleValue }
                if let f0 = number(first, "frames"), let f1 = number(last, "frames"), let t0 = number(first, "t"), let t1 = number(last, "t"), t1 > t0 {
                    widget["fps"] = round2((f1 - f0) * 1000.0 / (t1 - t0))
                    widget["frames"] = Int(f1 - f0)
                }
                if let j0 = number(first, "jank"), let j1 = number(last, "jank") {
                    widget["jank"] = Int(j1 - j0)
                }
            }
            run["widget"] = widget
            if let error = self.instance?.lastError {
                self.errors.append(error)
            }
            run["errors"] = self.errors
            var diags: [String: Int] = [:]
            for diagnostic in self.instance?.diagnostics ?? [] {
                diags[diagnostic.kind, default: 0] += 1
            }
            run["diags"] = diags
            if let instance = self.instance {
                instance.view.removeFromSuperview()
                instance.destroy()
            }
            self.instance = nil
            let completion = self.completion
            self.completion = nil
            completion?(run)
        }
    }
}
