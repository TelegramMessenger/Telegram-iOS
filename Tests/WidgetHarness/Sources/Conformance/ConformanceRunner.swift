import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData
import ChatMessageItemCommon
import ChatMessageWidgetBubbleContentNode
import MessageWidget

/// What one run of a conformance widget recorded: `run.schema.json`'s run before it is encoded.
public struct ConformanceRun {
    /// A bridge call the host accepted after the gesture gate.
    public struct BridgeCall: Equatable {
        public let method: String
        public let args: [String]

        public init(method: String, args: [String]) {
            self.method = method
            self.args = args
        }
    }

    /// What the host saw (CLIENTS.md step 8).
    public struct Observed {
        public var bridge: [BridgeCall] = []
        /// The bubble's height at the end, in CSS px (points).
        public var height: Double = 0.0
        /// Whether the chat input (the runner's stand-in field) still has the focus.
        public var chatFocused = false
        /// True when the input cannot grant a user gesture; the instance's touches carry the tap's permission.
        public var syntheticInput = false
    }

    public let id: String
    public let theme: String
    public let width: CGFloat
    /// The widget was created and its boot published (a widget that failed to start was not loaded).
    public var loaded = false
    /// Why the runtime stopped it, if it did.
    public var dead: String?
    /// The last published `status` (`running`, `awaiting`, `done`); nil when the widget never published.
    public var status: String?
    /// The published `checks`, as published.
    public var checks: [[String]] = []
    /// The published `targets` and `stages`, by name: `[x, y, w, h]` in CSS px.
    public var targets: [String: [Double]] = [:]
    public var stageRects: [String: [Double]] = [:]
    public var observed = Observed()
    /// Indices of the actions the runner could not perform for real (CLIENTS.md step 6).
    public var skippedActions: [Int] = []
    /// Uncaught widget errors, in order.
    public var errors: [String] = []
    /// The manifest's stages for this theme, cropped at 2× before the widget was destroyed: name → PNG.
    public var crops: [String: Data] = [:]

    public init(id: String, theme: String, width: CGFloat) {
        self.id = id
        self.theme = theme
        self.width = width
    }

    /// `"<id>/<theme>"`, the run's key in the baseline and the crop map.
    public var key: String {
        return "\(self.id)/\(self.theme)"
    }
}

/// Runs widget-sandbox v0.1.1's conformance widgets through the app's widget path (CLIENTS.md, "The runner, step by
/// step"): a `MessageWidgetInstance` with the app's pool and wait policy, its view in the harness's window so it is
/// visible and gets its frames, and a stand-in chat input that has the focus before the widget loads. `runAll` runs one
/// widget at a time by default: widgets running together share the pool's two threads, so a timing check (two
/// animationiteration events of a 0.1 s animation) depended on which pages ran beside it rather than on the runtime.
/// Main thread.
public final class ConformanceRunner {
    public static let defaultWidth: CGFloat = 390.0
    public static let defaultTimeout: TimeInterval = 20.0
    /// Main run-loop spins (0.05 s each) between a run being over and its finish: the snapshot's hop and the bridge
    /// call's hop to main.
    static let settleSpins = 2
    /// The scale the pixel stages are cropped at (CLIENTS.md step 7).
    public static let cropScale: CGFloat = 2.0

    private weak var host: UIView?
    private let chatInput = UITextField(frame: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))

    /// One run in progress.
    private final class Active {
        let test: ConformanceTest
        var run: ConformanceRun
        let instance: MessageWidgetInstance?
        let view: UIView?
        let deadline: Date
        var size: CGSize = .zero
        /// The scripted actions ran (once, on the first `awaiting`).
        var performed = false
        /// Spins of the main run loop since the run was over. A finished task's snapshot reaches main, and its bridge
        /// calls `onBridge`, each through a `DispatchQueue.main.async`; finishing at once dropped them (the 20 haptics
        /// of 16-sdk-taps-c's boot went unseen on some runs), so a run is finished `settleSpins` spins after it is over.
        var spinsSinceOver: Int?
        /// The bot this run's requests go to, and the message's state as its edits left it (widget-sandbox v0.2.1).
        let bot: ConformanceMockBot
        var state: MessageWidgetState

        init(test: ConformanceTest, run: ConformanceRun, instance: MessageWidgetInstance?, view: UIView?, deadline: Date, bot: ConformanceMockBot, state: MessageWidgetState) {
            self.test = test
            self.run = run
            self.instance = instance
            self.view = view
            self.deadline = deadline
            self.bot = bot
            self.state = state
        }
    }

    /// Who looks at every run's widget (CLIENTS.md: "a viewer, as you would for such a message").
    public static let viewer = MessageWidgetViewer(id: 777000, firstName: "Conformance", lastName: nil, username: "conformance_runner", isPremium: false)

    /// A test's message context and state (CLIENTS.md, "The message context"): its first spec's kind, else the private
    /// chat's original with no state; an unknown kind runs as the private chat's and is a run error.
    static func message(of test: ConformanceTest) -> (context: MessageWidgetContext, state: MessageWidgetState, error: String?) {
        guard let spec = test.message else {
            return (MessageWidgetMessageKind.private.context(viewer: ConformanceRunner.viewer), .empty, nil)
        }
        let state = MessageWidgetState(chatData: spec.chatData.map { Data($0.utf8) }, publicData: spec.publicData.map { Data($0.utf8) })
        guard let kind = spec.kind else {
            return (MessageWidgetMessageKind.private.context(viewer: ConformanceRunner.viewer), state, "runner: unknown message kind \(spec.kindName); run as the private chat's")
        }
        return (kind.context(viewer: ConformanceRunner.viewer), state, nil)
    }

    /// CLIENTS.md step 1, "the theme as in production" (ruling R6): the app's own theme for a widget in an incoming
    /// bubble of the default chat theme (`messageWidgetTheme`), at the default Text Size in the compact layout.
    public static func theme(_ scheme: String) -> MessageWidgetInstance.Theme {
        return messageWidgetTheme(theme: scheme == "dark" ? defaultDarkPresentationTheme : defaultPresentationTheme, wallpaper: .builtin(WallpaperSettings()), incoming: true, fontSize: .regular, textInsets: ChatMessageItemLayoutConstants.compact.text.bubbleInsets)
    }

    public init(host: UIView) {
        self.host = host
        self.chatInput.alpha = 0.01
        self.chatInput.accessibilityIdentifier = "conformance.chatInput"
        host.addSubview(self.chatInput)
    }

    deinit {
        self.chatInput.removeFromSuperview()
    }

    /// One run of `test` in `theme`: loads it, waits for `done` (or `awaiting` when it has actions) at most `timeout`
    /// seconds, and records what it published and what the host saw.
    public func run(_ test: ConformanceTest, theme: String, width: CGFloat = ConformanceRunner.defaultWidth, timeout: TimeInterval = ConformanceRunner.defaultTimeout) -> ConformanceRun {
        return self.runAll([(test, theme)], width: width, timeout: timeout, concurrency: 1)[0]
    }

    /// Every (test, theme) of `tests`, `concurrency` at a time; the runs in the order given.
    public func runAll(_ tests: [ConformanceTest], width: CGFloat = ConformanceRunner.defaultWidth, timeout: TimeInterval = ConformanceRunner.defaultTimeout, concurrency: Int = 1) -> [ConformanceRun] {
        return self.runAll(tests.flatMap { test in test.themes.map { (test, $0) } }, width: width, timeout: timeout, concurrency: concurrency)
    }

    private func runAll(_ items: [(ConformanceTest, String)], width: CGFloat, timeout: TimeInterval, concurrency: Int) -> [ConformanceRun] {
        dispatchPrecondition(condition: .onQueue(.main))
        var results = [ConformanceRun?](repeating: nil, count: items.count)
        var active: [(index: Int, run: Active)] = []
        var next = 0
        while next < items.count || !active.isEmpty {
            while active.count < max(1, concurrency) && next < items.count {
                active.append((next, self.start(items[next].0, theme: items[next].1, width: width, timeout: timeout)))
                next += 1
            }
            var remaining: [(index: Int, run: Active)] = []
            for entry in active {
                if let spins = entry.run.spinsSinceOver {
                    if spins >= ConformanceRunner.settleSpins {
                        results[entry.index] = self.finish(entry.run)
                    } else {
                        entry.run.spinsSinceOver = spins + 1
                        remaining.append(entry)
                    }
                } else if self.poll(entry.run, width: width) {
                    entry.run.spinsSinceOver = 0
                    remaining.append(entry)
                } else {
                    remaining.append(entry)
                }
            }
            active = remaining
            if !active.isEmpty {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
        }
        return results.map { $0! }
    }

    private func start(_ test: ConformanceTest, theme: String, width: CGFloat, timeout: TimeInterval) -> Active {
        var run = ConformanceRun(id: test.id, theme: theme, width: width)
        // CLIENTS.md step 2: the chat input has the focus before the widget loads.
        self.chatInput.becomeFirstResponder()
        let bot = ConformanceMockBot(table: test.bot, viewer: ConformanceRunner.viewer)
        let message = ConformanceRunner.message(of: test)
        if let error = message.error {
            run.errors.append(error)
        }
        guard let source = try? String(contentsOf: test.fileURL, encoding: .utf8) else {
            run.errors.append("the widget's file could not be read: \(test.fileURL.lastPathComponent)")
            return Active(test: test, run: run, instance: nil, view: nil, deadline: Date(), bot: bot, state: message.state)
        }
        guard let instance = MessageWidgetInstance(source: source, theme: ConformanceRunner.theme(theme), stoppedLabel: "Widget stopped", maxMessageLength: 4096, context: message.context, state: message.state) else {
            run.errors.append("the widget runtime could not be created")
            return Active(test: test, run: run, instance: nil, view: nil, deadline: Date(), bot: bot, state: message.state)
        }
        // widget-sandbox v0.4.0: the band its header gives, before the first layout, as a client passes its own.
        instance.contentSafeArea = test.safeArea
        let view = instance.view
        // In the window: a widget is visible only there, and every auto widget's harness waits for its frames.
        self.host?.insertSubview(view, at: 0)
        let active = Active(test: test, run: run, instance: instance, view: view, deadline: Date(timeIntervalSinceNow: timeout), bot: bot, state: message.state)
        instance.onBridge = { [weak active, weak instance] call in
            switch call {
            case let .wallet(id, _):
                // The set passes no context with the wallet (widget-sandbox v0.5.0 adds no conformance case for it).
                instance?.completeRequest(id: id, outcome: .failed)
            case let .request(id, data, _):
                // The bot edits first, then answers (upstream's test bot): the edit reaches the widget before the result.
                guard let active, let instance else {
                    return
                }
                let reply = active.bot.answer(data, current: active.state)
                if let edit = reply.edit {
                    active.state = edit
                    instance.setState(edit)
                }
                if let repeatAction = reply.repeat, repeatAction.times > 1 {
                    for index in 1 ..< repeatAction.times {
                        DispatchQueue.main.asyncAfter(deadline: .now() + repeatAction.every * Double(index)) { [weak active, weak instance] in
                            guard let active, let instance, let edit = active.bot.repeated(data, current: active.state) else {
                                return
                            }
                            active.state = edit
                            instance.setState(edit)
                        }
                    }
                }
                instance.completeRequest(id: id, outcome: .answered(reply.result))
            case let .copyText(text):
                active?.run.observed.bridge.append(ConformanceRun.BridgeCall(method: "copyText", args: [text]))
            case .watchPublicData:
                break
            case let .openLink(url):
                active?.run.observed.bridge.append(ConformanceRun.BridgeCall(method: "openLink", args: [url]))
            case let .openTelegramLink(url):
                active?.run.observed.bridge.append(ConformanceRun.BridgeCall(method: "openTelegramLink", args: [url]))
            case let .haptic(kind, value):
                active?.run.observed.bridge.append(ConformanceRun.BridgeCall(method: "haptic", args: [kind] + (value.map { [$0] } ?? [])))
            }
        }
        active.size = self.layout(instance, view: view, width: width)
        active.run.loaded = !instance.failedToStart
        return active
    }

    /// Whether the run is over: it published `done` (or `awaiting` with actions to perform), stopped, failed to load, or
    /// ran out of time. A test that must be stopped (`stops`) waits for the stop, whatever it published (CLIENTS.md step 4).
    private func poll(_ active: Active, width: CGFloat) -> Bool {
        guard let instance = active.instance, let view = active.view, active.run.loaded, !active.test.loadOnly else {
            return true
        }
        active.size = self.layout(instance, view: view, width: width)
        if self.read(instance, into: &active.run) {
            if active.run.status == "done" && active.test.stops == nil {
                return true
            }
            if active.run.status == "awaiting" && !active.test.actions.isEmpty && !active.performed {
                active.performed = true
                self.perform(active, instance: instance)
                // Nothing it could perform: the widget waits for input that will not come.
                if active.run.skippedActions.count == active.test.actions.count {
                    return true
                }
            }
        }
        return instance.deadReason != nil || Date() >= active.deadline
    }

    /// CLIENTS.md step 6, in order: a target name is the centre of `targets[name]` in the latest published value, a pair
    /// is a point; both in CSS px from the widget's top-left. Taps, double taps, presses and drags go through the
    /// widget's own touch path (`MessageWidgetInstance.pointer`, the phases its view's recognizer delivers), so a tap
    /// carries its permission; a double tap over the widget is the widget's (v0.1.2), two taps 100 ms apart. They are
    /// injected below the bubble, so what only the bubble does (a hold on auto opening the menu, a drag from the leading
    /// strip going back) fails here, as CLIENTS.md says such a runner reports; `testAuto23ThroughTheRealBubble` runs
    /// them through it. What this runner cannot perform for real goes into `skippedActions`: hover (a touch platform), a
    /// key (no keyboard, D4), a wheel, and a right click (the bubble's, which a widget instance alone cannot reach). A
    /// tap, double tap, press or drag whose target the widget has not published is the widget's failure, not input the
    /// runner cannot deliver: it is an error, and its checks are judged as the widget left them.
    private func perform(_ active: Active, instance: MessageWidgetInstance) {
        for (index, action) in active.test.actions.enumerated() {
            // About 350 ms between actions (CLIENTS.md step 6): two taps in a row are not a double tap.
            if index > 0 {
                self.pump(milliseconds: 350.0)
            }
            _ = self.read(instance, into: &active.run)
            if let kind = ["tap", "dblclick", "press", "drag"].first(where: { action[$0] != nil }), let target = action[kind], self.point(target, in: active.run) == nil || (kind == "drag" && self.dragEnd(action, from: .zero, in: active.run) == nil) {
                let missing = self.point(target, in: active.run) == nil ? target : (action["to"] ?? "(no end)")
                active.run.errors.append("runner: action \(index) (\(kind)): target \(missing) was not published")
            } else if let target = action["tap"], let point = self.point(target, in: active.run) {
                instance.pointer(.down, at: point)
                instance.pointer(.up, at: point)
            } else if let target = action["dblclick"], let point = self.point(target, in: active.run) {
                instance.pointer(.down, at: point)
                instance.pointer(.up, at: point)
                self.pump(milliseconds: 100.0)
                instance.pointer(.down, at: point)
                instance.pointer(.up, at: point)
            } else if let target = action["press"], let point = self.point(target, in: active.run) {
                instance.pointer(.down, at: point)
                self.pump(milliseconds: (action["ms"] as? NSNumber)?.doubleValue ?? 500.0)
                instance.pointer(.up, at: point)
            } else if let target = action["drag"], let from = self.point(target, in: active.run), let to = self.dragEnd(action, from: from, in: active.run) {
                instance.pointer(.down, at: from)
                let steps = max(1, (action["steps"] as? NSNumber)?.intValue ?? 10)
                for step in 1 ... steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    instance.pointer(.move, at: CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
                    self.pump(milliseconds: 16.0)
                }
                instance.pointer(.up, at: to)
            } else if let milliseconds = (action["wait"] as? NSNumber)?.doubleValue {
                self.pump(milliseconds: milliseconds)
            } else if let theme = action["theme"] as? String {
                instance.setTheme(ConformanceRunner.theme(theme))
            } else if let visible = action["visible"] as? Bool {
                instance.setVisible(visible)
            } else {
                active.run.skippedActions.append(index)
            }
        }
    }

    private func point(_ target: Any, in run: ConformanceRun) -> CGPoint? {
        if let name = target as? String, let rect = run.targets[name] {
            return CGPoint(x: rect[0] + rect[2] / 2.0, y: rect[1] + rect[3] / 2.0)
        }
        if let pair = target as? [NSNumber], pair.count == 2 {
            return CGPoint(x: pair[0].doubleValue, y: pair[1].doubleValue)
        }
        return nil
    }

    /// `to` a target or a point, or with `by` a delta from `from`.
    private func dragEnd(_ action: [String: Any], from: CGPoint, in run: ConformanceRun) -> CGPoint? {
        guard let to = action["to"] else {
            return nil
        }
        if (action["by"] as? Bool) == true, let delta = to as? [NSNumber], delta.count == 2 {
            return CGPoint(x: from.x + delta[0].doubleValue, y: from.y + delta[1].doubleValue)
        }
        return self.point(to, in: run)
    }

    private func pump(milliseconds: Double) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: milliseconds / 1000.0))
    }

    private func finish(_ active: Active) -> ConformanceRun {
        var run = active.run
        guard let instance = active.instance else {
            return run
        }
        run.dead = instance.deadReason
        run.errors.append(contentsOf: instance.diagnostics.filter { $0.kind == "uncaught-exception" }.map { $0.detail })
        run.observed.height = Double(MessageWidgetBubbleSize.height(anchors: MessageWidgetAnchors(width: 0, height: 0), reported: active.size.height, cached: nil))
        run.observed.chatFocused = self.chatInput.isFirstResponder
        // CLIENTS.md step 7: the manifest's stages for this theme, at 2×, from the widget's own renderer.
        for stage in active.test.stages where stage.themes.contains(run.theme) {
            if let image = instance.documentImage(rect: stage.rect, scale: ConformanceRunner.cropScale), let png = UIImage(cgImage: image).pngData() {
                run.crops[stage.name] = png
            }
        }
        instance.onBridge = nil
        instance.destroy()
        active.view?.removeFromSuperview()
        return run
    }

    private func layout(_ instance: MessageWidgetInstance, view: UIView, width: CGFloat) -> CGSize {
        let size = instance.layout(width: width)
        view.frame = CGRect(origin: .zero, size: size)
        return size
    }

    /// Reads the widget's `data-conformance` into `run`; whether it had published one.
    private func read(_ instance: MessageWidgetInstance, into run: inout ConformanceRun) -> Bool {
        guard let value = instance.documentElementAttribute("data-conformance"), let data = value.data(using: .utf8), let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return false
        }
        run.status = result["status"] as? String
        run.checks = ((result["checks"] as? [[Any]]) ?? []).map { check in check.map { ($0 as? String) ?? "\($0)" } }
        run.targets = ConformanceRunner.rects(result["targets"])
        run.stageRects = ConformanceRunner.rects(result["stages"])
        return true
    }

    private static func rects(_ value: Any?) -> [String: [Double]] {
        guard let dictionary = value as? [String: Any] else {
            return [:]
        }
        var rects: [String: [Double]] = [:]
        for (name, rect) in dictionary {
            if let numbers = rect as? [NSNumber], numbers.count == 4 {
                rects[name] = numbers.map { $0.doubleValue }
            }
        }
        return rects
    }
}
