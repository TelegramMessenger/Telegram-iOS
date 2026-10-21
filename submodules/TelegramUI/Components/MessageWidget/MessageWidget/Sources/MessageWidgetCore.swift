import Foundation
import MessageWidgetRendering
import QuartzCore
import WidgetRuntimeIOS

/// One message widget, the worker half (spec 2026-10-15 D2), on WidgetRuntime (M1d plan, Task 8): its session
/// (`WRSession`: the runtime, its render tree and its CoreText host), its tree renderer and its tile drawer. Main never
/// calls into it: each method runs inside one of the widget's tasks (`MessageWidgetInstance.perform` → `run`), on the
/// thread running that task, and nothing here calls the host back — bridge calls, the size, the tiles and the state
/// leave in the task's `WidgetSnapshot`.
final class MessageWidgetCore {
    /// The old runtime's budgets, which carry over unchanged: the parse is ours, under its ceiling; the boot's
    /// scripts and lifecycle share one budget; each later runtime step has its own.
    static let parseWorkUnits: UInt64 = 400_000_000
    static let bootWorkUnits: UInt64 = 48_000_000
    static let taskWorkUnits: UInt64 = 28_000_000
    /// The most runtime steps one core task runs: a wake right after it runs the rest, so a widget that keeps a task
    /// runnable cannot hold its queue. A drain also stops once it has spent a task's budget (Task 8 review I1): each
    /// step has its own, so one core task spends at most about two.
    static let maximumStepsPerTask = 256
    /// Tests only: budgets that replace the parse ceiling and the boot and task budgets of every widget booted while
    /// set — the corpus check measures what each widget needs rather than where it is stopped. Nil in the app.
    static var budgetsForTesting: (parse: UInt64, boot: UInt64, task: UInt64)?
    /// The longest bridge method name; a longer one is ignored.
    static let maximumBridgeMethodLength = 64

    private let source: String
    private let stoppedLabel: String
    private let maxMessageLength: Int
    /// SDK v1 §2.9: navigator.language.
    private let locale: String
    private let timers: MessageWidgetTimers
    /// The tiles' scale: the session records its drawing pixel-snapped at it.
    private let scale: CGFloat
    private let drawer: WidgetTileDrawer

    private(set) var renderer: WidgetTreeRenderer?
    private(set) var session: WRSession?
    /// The session's delegate, which it holds weakly.
    private var sessionDelegate: SessionDelegate?
    private var width: CGFloat = 0.0
    private var visible = true
    private var state: WidgetSnapshot.State = .live
    private var tornDown = false
    private var taskBudget = MessageWidgetCore.taskWorkUnits
    private var bootBudget = MessageWidgetCore.bootWorkUnits
    /// The running core task's kind: what a work-limit stop names.
    private var kind: WidgetSnapshot.Kind = .boot
    private var bridgeCalls: [MessageWidgetInstance.BridgeCall] = []
    private var diagnostics: [(kind: String, detail: String)] = []
    private var diagnosticCount = 0
    private var lastError: String?
    private var sequence = 0
    /// The running task's meter (nil between tasks), and the session's work counter as last added to it.
    private var meter: WorkMeter?
    private var meteredUnits: UInt64 = 0
    /// The main-run-loop wake for the session's next runnable task or timer, and when it fires (CACurrentMediaTime s).
    private var wake: MessageWidgetTimerHandle?
    private var wakeAt = Double.infinity

    /// Tests only: the units the parse, the boot (its scripts and lifecycle), the last task and the largest task after
    /// the boot spent.
    private(set) var parseWork: UInt64 = 0
    private(set) var bootWork: UInt64 = 0
    private(set) var lastTaskWork: UInt64 = 0
    private(set) var largestTaskWork: UInt64 = 0
    /// The request number of the draw task running now (MessageWidgetInstance's).
    private var drawRequest = 0
    /// Tests only: the wall time of the last task's runtime work (its steps, publish included) and of its tile drawing.
    private(set) var lastStepMilliseconds: Double = 0.0
    private(set) var lastDrawMilliseconds: Double = 0.0
    /// Tests only: the loads the renderer refused (it fetches nothing), as of the last task; -1 without a session.
    private(set) var refusedLoads = -1

    init(source: String, stoppedLabel: String, maxMessageLength: Int, locale: String = "en-US", timers: MessageWidgetTimers, scale: CGFloat) {
        self.source = source
        self.stoppedLabel = stoppedLabel
        self.maxMessageLength = maxMessageLength
        self.locale = locale
        self.timers = timers
        self.scale = scale
        self.drawer = WidgetTileDrawer(scale: scale)
    }

    // MARK: tasks

    /// One task: `body`, with `meter` counting every unit of its work, then the tree it published and the next wake, then
    /// its snapshot. Tiles are drawn only by a `.draw` task (the user, 2026-10-19: drawing may be async; only the size is
    /// critical), which main queues after a snapshot whose tree changed.
    func run(_ kind: WidgetSnapshot.Kind, meter: WorkMeter, _ body: () -> Void) -> WidgetSnapshot {
        self.kind = kind
        self.meter = meter
        let start = self.session?.workUnits ?? 0
        self.meteredUnits = start
        let stepStart = CACurrentMediaTime()
        if !self.tornDown {
            body()
        }
        if let session = self.session {
            self.addWork(session.workUnits)
            // The boot's own work is its scripts' and lifecycle's (bootWork): the parse is not the widget's.
            self.lastTaskWork = kind == .boot ? self.bootWork : session.workUnits &- start
            if kind != .boot {
                self.largestTaskWork = max(self.largestTaskWork, self.lastTaskWork)
            }
        }
        self.publish()
        var frame: WidgetFrame?
        if kind == .draw {
            let drawStart = CACurrentMediaTime()
            frame = self.renderer.map { self.drawer.draw($0) }
            self.lastDrawMilliseconds = (CACurrentMediaTime() - drawStart) * 1000.0
        } else {
            self.lastStepMilliseconds = (CACurrentMediaTime() - stepStart) * 1000.0
        }
        let needsDraw = kind != .draw && self.renderer.map { self.drawer.needsDraw($0) } == true
        self.scheduleWake()
        self.meter = nil
        self.sequence += 1
        let wantsFrame = self.state == .live && self.session?.wantsAnimationFrame() == true
        let snapshot = WidgetSnapshot(sequence: self.sequence, kind: kind, width: self.width, size: self.renderer?.documentSize, frame: frame, needsDraw: needsDraw, drawRequest: kind == .draw ? self.drawRequest : 0, state: self.state, bridgeCalls: self.bridgeCalls, wantsFrame: wantsFrame, lastError: self.lastError, diagnostics: self.diagnostics, units: meter.spent)
        self.bridgeCalls.removeAll()
        self.diagnostics.removeAll()
        return snapshot
    }

    /// Creates the session and runs the widget's parse and boot. A session that cannot be made or a boot that does not
    /// start (a C++ failure, a parse past its ceiling) is `.failedToStart`; a boot its scripts stopped is `.frozen`, as at
    /// any other time, with its parsed markup.
    func boot(width: CGFloat, maximumHeight: CGFloat = WidgetTreeRenderer.maximumHeight, theme: MessageWidgetInstance.Theme, visible: Bool, budgets: (parse: UInt64, boot: UInt64, task: UInt64)?) {
        self.width = width
        self.visible = visible
        if let budgets {
            self.bootBudget = budgets.boot
            self.taskBudget = budgets.task
        }
        let delegate = SessionDelegate(core: self)
        guard let session = WRSession(width: width, dark: theme == .dark, scale: self.scale, delegate: delegate) else {
            self.appendDiag("core-error", "the widget runtime could not be created")
            self.state = .failedToStart
            return
        }
        self.sessionDelegate = delegate
        session.setLocale(self.locale)
        self.session = session
        self.renderer = WidgetTreeRenderer(width: width, maximumHeight: maximumHeight)
        // A document starts visible; a hidden one is hidden by a task that runs before the boot's scripts.
        if !visible {
            session.setVisible(false)
        }
        let before = session.workUnits
        let started = session.boot(withSource: self.source, parseUnits: budgets?.parse ?? MessageWidgetCore.parseWorkUnits, bootUnits: self.bootBudget)
        self.parseWork = session.parseUnits
        self.bootWork = (session.workUnits &- before) &- session.parseUnits
        if !started {
            self.appendDiag("core-error", session.failed ? "the widget runtime failed" : "the widget did not start")
            self.state = .failedToStart
            self.renderer = nil
            self.dropSession()
        }
    }

    /// A new width (`fill`: exactly that width, for a bubble wider than the widget's own; the session lays out at the
    /// width either way). A frozen widget keeps its last tree, clipped to the new width.
    func setWidth(_ width: CGFloat, fill: Bool) {
        self.width = width
        self.renderer?.setWidth(width)
        guard self.state == .live, let session = self.session else {
            return
        }
        // The rebuild is a step of its own, on a budget of its own (Task 8 review I2).
        session.setWorkLimitAfter(self.taskBudget)
        session.setWidth(width)
        // The width change's rendering update (media changes, ResizeObserver, IntersectionObserver) is a task.
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// The live document's `<html>` attribute `name` (`WRSession.documentElementAttribute`).
    func documentElementAttribute(_ name: String) -> String? {
        return self.session?.documentElementAttribute(name)
    }

    /// The most the document may be tall (`WidgetTreeRenderer.setMaximumHeight`): the next snapshot carries the new size.
    func setMaximumHeight(_ maximumHeight: CGFloat) {
        self.renderer?.setMaximumHeight(maximumHeight)
    }

    /// The theme: the session rebuilds now and queues the TelegramWidget.onTheme callbacks, which run in this task.
    func setTheme(_ theme: MessageWidgetInstance.Theme) {
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setWorkLimitAfter(self.taskBudget)
        session.setDark(theme == .dark)
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// One touch phase, queued as the session's task and run with whatever else is runnable, after what was runnable
    /// before it. The press's permission for a link call is the runtime's (SDK v1 §2.5: one call per press, from the
    /// press's own events only).
    func touch(action: Int32, at point: CGPoint, pointer: Int32, primary: Bool) {
        guard self.state == .live, let session = self.session else {
            return
        }
        let phase: WRPointerPhase
        switch action {
        case 0:
            phase = .down
        case 1:
            phase = .move
        case 2:
            phase = .up
        default:
            phase = .cancel
        }
        let now = CACurrentMediaTime() * 1000.0
        self.drain(at: now)
        guard self.state == .live, !self.isStopped(session) else {
            return
        }
        session.pointer(phase, at: point, pointerId: pointer, primary: primary)
        self.drain(at: now)
    }

    /// One animation frame, while the widget is visible and wants one.
    func frame(time: Double) {
        guard self.state == .live, self.visible, let session = self.session, session.wantsAnimationFrame() else {
            return
        }
        session.setWorkLimitAfter(self.taskBudget)
        _ = session.runAnimationFrame(at: time)
    }

    /// Hidden, the widget gets no frames and its wakes come at most once a second; the visibility change itself is a
    /// task of the session's, which runs now.
    func setVisible(_ visible: Bool) {
        self.visible = visible
        guard self.state == .live, let session = self.session else {
            return
        }
        session.setVisible(visible)
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// A `.draw` task's body: `run` draws the tiles; this records the request it answers.
    func draw(request: Int) {
        self.drawRequest = request
    }

    /// Tests only: `code` in the widget's context as one event-kind task.
    func evaluate(_ code: String) -> String? {
        guard self.state == .live, let session = self.session else {
            return nil
        }
        session.setWorkLimitAfter(self.taskBudget)
        return session.evaluate(forTesting: code)
    }

    /// Tests only: the border box of the first element `selector` matches, at the current layout.
    func borderBox(_ selector: String) -> CGRect? {
        guard self.state == .live, let session = self.session else {
            return nil
        }
        session.setWorkLimitAfter(self.taskBudget)
        let box = session.borderBox(forTesting: selector)
        return box.isNull ? nil : box
    }

    /// After the widget's last task (spec D5): the session goes (main keeps the frame).
    func teardown() {
        self.tornDown = true
        self.cancelWake()
        self.dropSession()
        self.renderer = nil
    }

    // MARK: steps and wakes

    /// The session's runnable tasks at `now`, one step each on its own budget, at most `maximumStepsPerTask` of them and
    /// none once the drain has spent a task's budget. `now` is fixed for the whole drain, so a timer the steps set is not
    /// due within it; what is left is the next wake's.
    private func drain(at now: Double) {
        guard let session = self.session else {
            return
        }
        let start = session.workUnits
        var steps = 0
        while self.state == .live, steps < MessageWidgetCore.maximumStepsPerTask, session.workUnits &- start < self.taskBudget, !self.isStopped(session), session.hasRunnableTask(at: now) {
            session.setWorkLimitAfter(self.taskBudget)
            steps += 1
            if session.runNextTask(at: now) != .ran {
                break
            }
        }
    }

    /// A wake (inside its own task): what is runnable now.
    private func runWake() {
        self.wake = nil
        self.wakeAt = .infinity
        guard self.state == .live else {
            return
        }
        self.drain(at: CACurrentMediaTime() * 1000.0)
    }

    /// One main-run-loop wake for the session's next runnable task or timer deadline; hidden, no sooner than a second
    /// from now (today's 1 Hz). A wake already due earlier stands.
    private func scheduleWake() {
        guard self.state == .live, !self.tornDown, let session = self.session else {
            self.cancelWake()
            return
        }
        let now = CACurrentMediaTime()
        var delay: Double
        if session.hasRunnableTask(at: now * 1000.0) {
            delay = 0.0
        } else if let deadline = session.nextTimerDeadline() {
            delay = max(0.0, (deadline.doubleValue - now * 1000.0) / 1000.0)
        } else {
            self.cancelWake()
            return
        }
        if !self.visible {
            delay = max(delay, 1.0)
        }
        let at = now + delay
        if self.wake != nil, at >= self.wakeAt {
            return
        }
        self.wake?.cancel()
        self.wakeAt = at
        self.wake = self.timers.schedule(after: delay, key: "wake") { [weak self] in
            self?.runWake()
        }
    }

    private func cancelWake() {
        self.wake?.cancel()
        self.wake = nil
        self.wakeAt = .infinity
    }

    // MARK: publishing and freezing

    /// The session's tree and what changed since the last task, to the renderer; then a stop, if one came, freezes.
    private func publish() {
        guard let session = self.session, let renderer = self.renderer else {
            return
        }
        if self.state == .live, let tree = session.tree() {
            let rects = session.changedRects()?.map { value -> CGRect in
                var rect = CGRect.zero
                value.getValue(&rect, size: MemoryLayout<CGRect>.size)
                return rect
            }
            renderer.publish(tree, changed: rects, contentSize: session.contentSize)
        }
        self.refusedLoads = Int(clamping: session.refusedLoads)
        guard self.state == .live, self.isStopped(session) else {
            return
        }
        let reason: String
        switch session.stopReason {
        case .budget:
            let budget = self.kind == .boot ? self.bootBudget : self.taskBudget
            reason = "Work limit exceeded: \(self.kindName) did more than \(budget) units of work"
        case .memory:
            reason = "Memory limit exceeded (64 MB)"
        case .layoutQuery:
            // sdk-v1 §2's own words.
            reason = "Layout query limit exceeded"
        default:
            reason = "Widget core error"
        }
        self.state = .frozen(reason)
        renderer.freeze(label: self.stoppedLabel)
        self.cancelWake()
        self.dropSession()
    }

    private func isStopped(_ session: WRSession) -> Bool {
        return session.failed || session.stopReason != .none
    }

    /// What a work-limit stop says ran: today's task kinds.
    private var kindName: String {
        switch self.kind {
        case .boot:
            return "boot"
        case .frame:
            return "frame"
        case .timer, .wake:
            return "timer"
        default:
            return "event"
        }
    }

    private func dropSession() {
        self.session?.teardown()
        self.session = nil
        self.sessionDelegate = nil
    }

    // MARK: the session's delegate (inside a session call, on this task's thread)

    fileprivate func addWork(_ total: UInt64) {
        guard total > self.meteredUnits else {
            return
        }
        self.meter?.add(total - self.meteredUnits)
        self.meteredUnits = total
    }

    fileprivate func diagnostic(_ kind: String, detail: String) {
        if kind == "uncaught-exception" {
            self.lastError = detail
        }
        self.appendDiag(kind, detail)
    }

    private func appendDiag(_ kind: String, _ detail: String) {
        if self.diagnosticCount < 500 {
            self.diagnosticCount += 1
            self.diagnostics.append((kind: kind, detail: detail))
        }
    }

    /// The runtime posts a link call only once it has checked the URL (SDK v1 §2.5) and the press allowed it; the host
    /// still refuses one longer than `maximumLinkLength`. A haptic arrives checked and rate-limited (§2.6). Any other
    /// method is ignored.
    fileprivate func bridge(_ method: String, argsJson: String) {
        guard method.count <= MessageWidgetCore.maximumBridgeMethodLength else {
            self.appendDiag("bridge-ignored", String(method.prefix(MessageWidgetCore.maximumBridgeMethodLength)))
            return
        }
        let args = (try? JSONSerialization.jsonObject(with: Data(argsJson.utf8), options: [.fragmentsAllowed])) as? [Any] ?? []
        let first = args.first as? String ?? ""
        switch method {
        case "openLink", "openTelegramLink":
            guard !first.isEmpty else {
                return
            }
            guard first.utf8.count <= MessageWidgetInstance.maximumLinkLength else {
                self.appendDiag("bridge-refused", "\(method): URL longer than \(MessageWidgetInstance.maximumLinkLength) bytes")
                return
            }
            self.bridgeCalls.append(method == "openLink" ? .openLink(first) : .openTelegramLink(first))
        case "haptic":
            guard !first.isEmpty else {
                return
            }
            self.bridgeCalls.append(.haptic(kind: first, value: args.count > 1 ? args[1] as? String : nil))
        default:
            self.appendDiag("bridge-ignored", method)
        }
    }

}

/// The session's delegate: forwards to the core, which owns the session (the session holds its delegate weakly).
private final class SessionDelegate: NSObject, WRSessionDelegate {
    weak var core: MessageWidgetCore?

    init(core: MessageWidgetCore) {
        self.core = core
        super.init()
    }

    func session(_ session: WRSession, diagnostic kind: String, detail: String) {
        self.core?.diagnostic(kind, detail: detail)
    }

    func session(_ session: WRSession, log level: Int, text: String) {
    }

    func session(_ session: WRSession, bridge method: String, args argsJson: String) {
        self.core?.bridge(method, argsJson: argsJson)
    }

    func session(_ session: WRSession, didWork totalUnits: UInt64) {
        self.core?.addWork(totalUnits)
    }
}
